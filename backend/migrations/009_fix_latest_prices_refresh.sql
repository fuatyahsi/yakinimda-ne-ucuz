-- =====================================================================
-- 009_fix_latest_prices_refresh.sql
--
-- 2026-04-29 itibarıyla `latest_prices` MV stale (293 satır), oysa
-- `prices` tablosunda son 24 saatte ~16k satır yazılıyor. Sebep:
-- 002_views.sql'deki `refresh_latest_prices()` fonksiyonu
-- `REFRESH MATERIALIZED VIEW CONCURRENTLY` kullanıyor ve unique index
-- `idx_latest_prices_pk` `COALESCE(branch_id, 0)` expression'i içerdiği
-- için PostgreSQL CONCURRENTLY refresh'i reddediyor:
--   "Create a unique index with no WHERE clause on one or more columns
--    of the materialized view." (SQLSTATE 55000)
--
-- Bu migration:
--   1) refresh_latest_prices() fonksiyonunu non-concurrently REFRESH
--      kullanacak şekilde günceller. Tablo kısa süreli locklanır
--      (~3-5sn 14k urun icin) ama refresh garantili çalışır.
--   2) Hemen bir refresh tetikler — frontend'in browseCategoryItems
--      RPC'si dolu MV gorur, urun sayisi 158 → 11k+'a sicrar.
--
-- Notlar:
-- - CONCURRENTLY'yi geri istemek icin unique index'i `COALESCE` yerine
--   `NULLS NOT DISTINCT` (PG 15+) ile yeniden olustur, sonra
--   CONCURRENTLY'i geri ac.
-- - pg_cron schedule (004_cron.sql) bu fonksiyonu cagiriyor;
--   bu committen sonra cron sweep'leri sonrasi MV otomatik dolmali.
-- =====================================================================

CREATE OR REPLACE FUNCTION refresh_latest_prices()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Non-concurrent refresh: kisa table lock ama refresh garantili.
  -- 14k urun icin ~3-5sn surer; user-facing query'ler bu sirada
  -- bekler ama tamamen kapanmaz (pgsql lock semantics).
  REFRESH MATERIALIZED VIEW latest_prices;
END;
$$;

-- Hemen bir refresh — migration'in etkisini gormek icin.
SELECT refresh_latest_prices();

-- Sanity check (migration log'unda gorunsun): kac satir var
DO $$
DECLARE
  n BIGINT;
BEGIN
  SELECT count(*) INTO n FROM latest_prices;
  RAISE NOTICE 'latest_prices row count after refresh: %', n;
END $$;
