-- =====================================================================
-- 006_app_search_rpc_fix.sql — markets.tier SMALLINT cast düzeltmesi
-- =====================================================================
-- 005'te RETURNS TABLE'da market_tier INT olarak tanımlanmıştı, ancak
-- markets.tier kolonu SMALLINT. Postgres dönüş tipi uyuşmazlığı verdi.
-- Bu migration SELECT içinde m.tier::integer cast yapar, böylece dönüş
-- şeması INT kalır ve app katmanı değişmez.
-- =====================================================================

CREATE OR REPLACE FUNCTION search_products_with_prices(
  p_query      TEXT,
  p_market_ids TEXT[] DEFAULT NULL,
  p_limit      INT    DEFAULT 80
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
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_term TEXT := trim(lower(coalesce(p_query, '')));
BEGIN
  IF v_term = '' THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH matched AS (
    SELECT
      p.id,
      GREATEST(
        similarity(lower(p.canonical_name), v_term),
        COALESCE(similarity(lower(p.search_text), v_term), 0),
        COALESCE((
          SELECT MAX(similarity(lower(pa.alias), v_term))
          FROM product_aliases pa
          WHERE pa.product_id = p.id
        ), 0)
      )::REAL AS score
    FROM products p
    WHERE
      p.canonical_name ILIKE '%' || v_term || '%'
      OR p.search_text ILIKE '%' || v_term || '%'
      OR EXISTS (
        SELECT 1 FROM product_aliases pa
        WHERE pa.product_id = p.id
          AND pa.alias ILIKE '%' || v_term || '%'
      )
    ORDER BY score DESC
    LIMIT 150
  )
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
    mt.score                   AS match_score
  FROM matched mt
  JOIN products p       ON p.id = mt.id
  JOIN latest_prices lp ON lp.product_id = mt.id
  JOIN markets m        ON m.id = lp.market_id
  WHERE
    m.is_active = true
    AND (
      p_market_ids IS NULL
      OR array_length(p_market_ids, 1) IS NULL
      OR lp.market_id = ANY(p_market_ids)
    )
  ORDER BY mt.score DESC, lp.price ASC
  LIMIT p_limit;
END;
$$;

-- ---------------------------------------------------------------------
-- browse_category_products — aynı cast düzeltmesi
-- ---------------------------------------------------------------------
-- Ek iyilestirme: path LIKE ile alt-kategorileri de dahil et.
-- "kagit" parent'i altindaki tum alt-kategorilerdeki urunler de gelsin
-- diye p_category_ids'e path prefix eslesmesi ekledim.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION browse_category_products(
  p_category_ids TEXT[],
  p_market_ids   TEXT[] DEFAULT NULL,
  p_limit        INT    DEFAULT 200
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
  WITH target_categories AS (
    -- Verilen ID'lerin kendileri + onların path'inin altındaki tüm alt kategoriler.
    -- Ör: p_category_ids = ['kagit'] ise path = 'temizlik/kagit' ve
    -- altındaki tüm 'temizlik/kagit/*' satırları da dahil.
    SELECT DISTINCT c.id
    FROM categories c
    WHERE p_category_ids IS NOT NULL
      AND array_length(p_category_ids, 1) IS NOT NULL
      AND (
        c.id = ANY(p_category_ids)
        OR EXISTS (
          SELECT 1 FROM categories root
          WHERE root.id = ANY(p_category_ids)
            AND c.path LIKE root.path || '/%'
        )
      )
  )
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
    m.is_active = true
    AND p.category_id IN (SELECT id FROM target_categories)
    AND (
      p_market_ids IS NULL
      OR array_length(p_market_ids, 1) IS NULL
      OR lp.market_id = ANY(p_market_ids)
    )
  ORDER BY p.canonical_name ASC, lp.price ASC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION search_products_with_prices(TEXT, TEXT[], INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION browse_category_products(TEXT[], TEXT[], INT)   TO anon, authenticated;
