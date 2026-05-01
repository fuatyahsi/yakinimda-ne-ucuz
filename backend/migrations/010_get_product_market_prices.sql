-- =====================================================================
-- 010_get_product_market_prices.sql
--
-- Frontend "market karşılaştırma" ekranı için EXACT product_id match.
-- Önceki davranış: searchCatalogItems text-FTS fuzzy match yapıyordu —
-- "Bisto Yağlı Gevrek 500g" araması "Lor Peyniri 500g" ve "Salamura
-- Zeytin S-Xs 500g" gibi alakasız ürünleri eşleştiriyordu (paket size
-- ortak olduğu için yüksek skor).
--
-- Bu RPC bir product_id (UUID) alır ve aynı ürünün TÜM marketlerdeki
-- son fiyatını döndürür. Aynı kanonik product → farklı marketler.
-- =====================================================================

CREATE OR REPLACE FUNCTION get_product_market_prices(
  p_product_id UUID,
  p_market_ids TEXT[] DEFAULT NULL
)
RETURNS TABLE (
  product_id        UUID,
  canonical_name    TEXT,
  brand             TEXT,
  package_size      NUMERIC,
  package_unit      TEXT,
  package_count     INT,
  image_url         TEXT,
  category_id       TEXT,
  market_id         TEXT,
  market_name       TEXT,
  market_logo_url   TEXT,
  market_tier       INT,
  price             NUMERIC,
  unit_price        NUMERIC,
  unit_price_label  TEXT,
  currency          TEXT,
  is_on_sale        BOOLEAN,
  observed_at       TIMESTAMPTZ,
  source            TEXT,
  match_score       REAL
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    p.id                       AS product_id,
    p.canonical_name,
    p.brand,
    p.package_size,
    p.package_unit,
    p.package_count,
    p.image_url,
    p.category_id,
    lp.market_id,
    m.display_name             AS market_name,
    m.logo_url                 AS market_logo_url,
    m.tier::integer            AS market_tier,
    lp.price,
    lp.unit_price,
    lp.unit_price_label,
    lp.currency,
    lp.is_on_sale,
    lp.observed_at,
    lp.source,
    1.0::REAL                  AS match_score
  FROM products p
  JOIN latest_prices lp ON lp.product_id = p.id
  JOIN markets m        ON m.id = lp.market_id
  WHERE
    p.id = p_product_id
    AND m.is_active = true
    AND (
      p_market_ids IS NULL
      OR array_length(p_market_ids, 1) IS NULL
      OR lp.market_id = ANY(p_market_ids)
    )
  ORDER BY lp.price ASC;
$$;

GRANT EXECUTE ON FUNCTION get_product_market_prices(UUID, TEXT[])
  TO anon, authenticated;
