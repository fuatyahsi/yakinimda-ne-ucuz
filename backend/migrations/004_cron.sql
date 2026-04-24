-- =====================================================================
-- 004_cron.sql — scheduled maintenance via pg_cron
-- =====================================================================
-- Bu migration backend'in "yaşayan" kısmı:
--   1) latest_prices materialized view'ı 15 dakikada bir CONCURRENTLY
--      refresh et (Flutter tarafında fiyat listesi hep taze olsun).
--   2) mark_expired_campaigns() fonksiyonunu günlük 03:00 UTC'de çalıştır
--      (valid_until geçmiş kampanyaları 'expired' statüsüne alır).
--
-- Prereq:
--   - pg_cron extension "pg_catalog" altında kurulu olmalı.
--     Supabase Dashboard → Database → Extensions → pg_cron ara, Enable et.
--     (Bu migration extension'ı kendi kurmaya çalışmaz çünkü cloud'da
--     extension install Dashboard üzerinden yapılıyor, SQL ile değil.)
--
-- Rollback:
--   SELECT cron.unschedule('refresh-latest-prices');
--   SELECT cron.unschedule('expire-old-campaigns');
-- =====================================================================

-- Güvenlik kontrolü: extension yoksa hata ver, manual enable iste.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE EXCEPTION
      'pg_cron extension kurulu değil. Supabase Dashboard → Database → '
      'Extensions → "pg_cron" ara ve Enable et, sonra bu migration''ı '
      'tekrar çalıştır.';
  END IF;
END$$;

-- ---------------------------------------------------------------------
-- Eski job'ları sil (idempotent re-run için).
-- cron.unschedule yoksa sessizce geç.
-- ---------------------------------------------------------------------
DO $$
BEGIN
  PERFORM cron.unschedule('refresh-latest-prices');
EXCEPTION WHEN OTHERS THEN
  NULL;
END$$;

DO $$
BEGIN
  PERFORM cron.unschedule('expire-old-campaigns');
EXCEPTION WHEN OTHERS THEN
  NULL;
END$$;

-- ---------------------------------------------------------------------
-- Job 1: latest_prices MV'yi 15 dakikada bir refresh et.
-- CONCURRENTLY kullanılıyor — okuma sorguları bloklanmaz.
-- CONCURRENTLY için UNIQUE INDEX şart (002_views.sql'de kuruldu).
-- ---------------------------------------------------------------------
SELECT cron.schedule(
  'refresh-latest-prices',
  '*/15 * * * *',                   -- her 15 dakikada bir
  $$SELECT refresh_latest_prices();$$
);

-- ---------------------------------------------------------------------
-- Job 2: günlük 03:00 UTC'de expired kampanyaları işaretle.
-- Türkiye saati 06:00, app trafiği düşük — güvenli zaman.
-- ---------------------------------------------------------------------
SELECT cron.schedule(
  'expire-old-campaigns',
  '0 3 * * *',                      -- her gün 03:00 UTC
  $$SELECT mark_expired_campaigns();$$
);

-- ---------------------------------------------------------------------
-- Doğrulama: kayıtlı job'ları listele.
-- Migration sonunda bu sorgunun çıktısını operasyon logu için görürsün.
-- ---------------------------------------------------------------------
SELECT
  jobid,
  schedule,
  jobname,
  database,
  active
FROM cron.job
WHERE jobname IN ('refresh-latest-prices', 'expire-old-campaigns')
ORDER BY jobname;
