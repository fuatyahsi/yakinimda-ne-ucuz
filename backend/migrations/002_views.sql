-- =====================================================================
-- 002_views.sql — aggregation layer
-- =====================================================================
-- Bu migration üç şey verir:
--   1) latest_prices              MATERIALIZED VIEW — her (product,market,branch) için en güncel fiyat
--   2) price_stats_7d / price_stats_30d  VIEW — ürün bazlı hareketli ortalama
--   3) detect_deals(window_hours) FUNCTION — indirime giren ürünleri tespit eder
--   4) current_campaigns          VIEW — şu an geçerli olan aktüel kampanyalar
-- =====================================================================

-- ---------------------------------------------------------------------
-- latest_prices: her (product,market,branch) kombinasyonu için en son gözlem.
-- Flutter tarafı "şu anki fiyat" sorgusunda tek satırda çekilebilsin diye MV.
-- pg_cron ile her 15 dakikada bir refresh edilecek (003'te eklenir).
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW latest_prices AS
SELECT DISTINCT ON (p.product_id, p.market_id, p.branch_id)
  p.product_id,
  p.market_id,
  p.branch_id,
  p.price,
  p.unit_price,
  p.unit_price_label,
  p.currency,
  p.is_on_sale,
  p.observed_at,
  p.source,
  p.source_url
FROM prices p
WHERE p.product_id IS NOT NULL
ORDER BY p.product_id, p.market_id, p.branch_id, p.observed_at DESC;

CREATE UNIQUE INDEX idx_latest_prices_pk
  ON latest_prices(product_id, market_id, COALESCE(branch_id, 0));
CREATE INDEX idx_latest_prices_market ON latest_prices(market_id);
CREATE INDEX idx_latest_prices_product ON latest_prices(product_id);

-- ---------------------------------------------------------------------
-- price_stats_7d / price_stats_30d: ürün bazlı hareketli ortalama.
-- "Fiyat düşürenler" algoritması bunu referans alacak.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW price_stats_7d AS
SELECT
  p.product_id,
  p.market_id,
  COUNT(*)                                         AS sample_count,
  AVG(p.price)::numeric(12,2)                      AS avg_price,
  MIN(p.price)::numeric(12,2)                      AS min_price,
  MAX(p.price)::numeric(12,2)                      AS max_price,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY p.price)::numeric(12,2) AS median_price
FROM prices p
WHERE p.product_id IS NOT NULL
  AND p.observed_at >= now() - interval '7 days'
GROUP BY p.product_id, p.market_id;

CREATE OR REPLACE VIEW price_stats_30d AS
SELECT
  p.product_id,
  p.market_id,
  COUNT(*)                                         AS sample_count,
  AVG(p.price)::numeric(12,2)                      AS avg_price,
  MIN(p.price)::numeric(12,2)                      AS min_price,
  MAX(p.price)::numeric(12,2)                      AS max_price
FROM prices p
WHERE p.product_id IS NOT NULL
  AND p.observed_at >= now() - interval '30 days'
GROUP BY p.product_id, p.market_id;

-- ---------------------------------------------------------------------
-- current_campaigns: şu an geçerli aktüel/kampanya satırları (tarih bazlı).
-- Flutter "fırsat ürünleri" ekranı bunu okuyacak.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW current_campaigns AS
SELECT
  c.*,
  (c.valid_until - CURRENT_DATE) AS days_remaining
FROM campaigns c
WHERE c.status = 'active'
  AND c.valid_from <= CURRENT_DATE
  AND c.valid_until >= CURRENT_DATE;

-- ---------------------------------------------------------------------
-- detect_deals(threshold_ratio, lookback_hours)
--   Son `lookback_hours` içinde düşmüş fiyatları bulur.
--   Çıktı: insert kuyruğu — notifications tablosuna feed olarak kullanılır.
--
--   threshold_ratio örn. 0.10 = "%10 veya daha fazla düşüş"
--   lookback_hours  örn. 6    = "son 6 saat içinde gözlenmiş düşüş"
--
--   Referans: 7 günlük ortalama. Bugünkü en son fiyat ortalamadan
--   threshold_ratio kadar düşükse "deal".
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION detect_deals(
  threshold_ratio NUMERIC DEFAULT 0.10,
  lookback_hours  INTEGER DEFAULT 24
)
RETURNS TABLE (
  product_id     UUID,
  market_id      TEXT,
  current_price  NUMERIC,
  avg_price_7d   NUMERIC,
  drop_ratio     NUMERIC,
  observed_at    TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    lp.product_id,
    lp.market_id,
    lp.price                                   AS current_price,
    s.avg_price                                AS avg_price_7d,
    ((s.avg_price - lp.price) / NULLIF(s.avg_price, 0))::numeric(6,4) AS drop_ratio,
    lp.observed_at
  FROM latest_prices lp
  JOIN price_stats_7d s
    ON s.product_id = lp.product_id
   AND s.market_id  = lp.market_id
  WHERE s.sample_count >= 3                    -- istatistiksel gürültü filtresi
    AND lp.observed_at >= now() - make_interval(hours => lookback_hours)
    AND s.avg_price > 0
    AND lp.price < s.avg_price
    AND ((s.avg_price - lp.price) / s.avg_price) >= threshold_ratio;
$$;

-- ---------------------------------------------------------------------
-- products_matching_watches(p_user_id)
--   Bir kullanıcının watch listesine göre, tetiklenmesi gereken
--   product+market+price satırlarını döndürür.
--   FCM gönderimini yapan Edge Function bu fonksiyonu çağıracak.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION watches_to_trigger(p_user_id UUID DEFAULT NULL)
RETURNS TABLE (
  watch_id       BIGINT,
  user_id        UUID,
  product_id     UUID,
  market_id      TEXT,
  current_price  NUMERIC,
  target_price   NUMERIC,
  original_price NUMERIC,
  product_name   TEXT,
  market_name    TEXT,
  observed_at    TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    w.id            AS watch_id,
    w.user_id,
    lp.product_id,
    lp.market_id,
    lp.price        AS current_price,
    w.target_price,
    w.original_price,
    pr.canonical_name AS product_name,
    m.display_name    AS market_name,
    lp.observed_at
  FROM user_watches w
  JOIN latest_prices lp
    ON lp.product_id = w.product_id
   AND (w.market_id IS NULL OR lp.market_id = w.market_id)
  JOIN products pr ON pr.id = lp.product_id
  JOIN markets  m  ON m.id  = lp.market_id
  WHERE w.is_active = true
    AND (p_user_id IS NULL OR w.user_id = p_user_id)
    AND (
      (w.target_price IS NOT NULL AND lp.price <= w.target_price)
      OR
      (w.target_price IS NULL AND w.original_price IS NOT NULL AND lp.price < w.original_price)
    )
    -- 24 saat içinde zaten bildirim gitmediyse
    AND (w.last_notified_at IS NULL OR w.last_notified_at < now() - interval '24 hours');
$$;

-- ---------------------------------------------------------------------
-- refresh_latest_prices(): MV refresh helper (pg_cron tarafından çağrılır)
-- CONCURRENTLY ile lock almaz, sorguları bloklamaz.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION refresh_latest_prices()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY latest_prices;
END;
$$;

-- ---------------------------------------------------------------------
-- mark_expired_campaigns(): valid_until geçmiş kampanyaları 'expired'a alır
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_expired_campaigns()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  affected INTEGER;
BEGIN
  UPDATE campaigns
  SET status = 'expired'
  WHERE status = 'active'
    AND valid_until < CURRENT_DATE;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;
