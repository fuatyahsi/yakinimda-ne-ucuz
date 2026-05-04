-- =====================================================================
-- 013_canonicalization_indexes.sql
--
-- core.find_or_create_product Tier 2/3 lookups icin eksik indexleri ekler.
-- BulkProductResolver de ayni sorgulari yaptigi icin bulk yazim hizi da
-- kazanir. Cron sweep boyunca her item icin 2 ek SELECT geliyor; 15k row
-- product tablosu uzerinde seq scan ms cinsinden tracker. Bu indexler
-- sweep suresini tipik %30-50 dusurur.
--
-- Mevcut UNIQUE constraint'lerden gelen ototomatik indexler:
--   products(barcode)       -> Tier 1 (UNIQUE constraint)
--   product_aliases(alias,source) -> Tier 0 (UNIQUE constraint)
--
-- Bu migration ekler:
--   1) (brand, search_text)    -> Tier 2 composite (brand+search prefix
--      ile matching; size+unit eq olarak takip eder, planner birlestirir)
--   2) canonical_name btree    -> Tier 3 exact match
--   3) brand alone btree (var) idx_products_brand zaten var
--
-- IDEMPOTENT (IF NOT EXISTS).
-- =====================================================================

-- Tier 2: brand + search_text composite (size+unit ek filter olarak takipli)
CREATE INDEX IF NOT EXISTS idx_products_brand_search
  ON products (brand, search_text)
  WHERE brand IS NOT NULL AND search_text IS NOT NULL;

-- Tier 3: canonical_name exact match
CREATE INDEX IF NOT EXISTS idx_products_canonical_name
  ON products (canonical_name);

-- Bonus: latest_prices'da product+market filtreleme zaten idx_latest_prices_pk
-- (UNIQUE) ile karsilanyor. browse_category_products RPC'si products.category_id
-- (idx_products_category zaten var) + lp.market_id (idx_latest_prices_market
-- zaten var) ile JOIN yapar. Ek index gerek yok.

-- Sanity: yeni indexlerin kullanilabilir oldugunu dogrulamak icin ANALYZE.
ANALYZE products;

DO $$
DECLARE
  idx_count INT;
BEGIN
  SELECT count(*) INTO idx_count
  FROM pg_indexes
  WHERE tablename = 'products';
  RAISE NOTICE '[indexes] products tablosu icin toplam % index var', idx_count;
END $$;
