-- =====================================================================
-- 011_dedupe_products.sql
--
-- 2026-04-30 itibari ile products tablosunda kanonik dedupe yok:
-- aynı ürün farklı marketlerden farklı canonical_name ile yazılınca
-- ayrı product_id olusuyor. Örnek: "Saka Su 0.5 L" (ŞOK) vs
-- "Saka Su 500 ml" (A101) vs "Saka Doğal Kaynak Suyu 500ML" (BİM)
-- → 3 ayrı product. Frontend exact match → tek satır gosterir, kullanici
-- "Su 5L" 3 kez goruyor.
--
-- Bu migration mevcut duplicate'leri tek seferlik temizler:
--   1) Aynı (brand, search_text, package_size, package_unit) gruplari bul
--   2) Her grup icin canonical secim: is_verified=true ise tercih,
--      sonra en eski created_at
--   3) Diger product_id'lerin prices/campaigns/aliases'larini canonical'a
--      yonlendir
--   4) Eski product satirlarini sil
--   5) latest_prices MV refresh
--
-- Sonraki cron sweep'lerinde core.find_or_create_product Tier 2
-- (brand+search_text+size+unit match) sayesinde duplicate yeniden
-- olusmaz.
--
-- IDEMPOTENT: tekrar koşturulabilir (zaten dedupe edilmislerse no-op).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- Dedupe — PL/pgSQL ile transactional
-- ---------------------------------------------------------------------
DO $$
DECLARE
  affected_prices    INT := 0;
  affected_campaigns INT := 0;
  affected_aliases   INT := 0;
  removed_products   INT := 0;
BEGIN
  -- Mapping table'i geçici olarak materialize et (CTE'leri DO içinde
  -- birden fazla statement'ta paylasamayiz, bu yuzden temp table)
  CREATE TEMP TABLE _dedupe_mapping ON COMMIT DROP AS
  WITH dup_groups AS (
    SELECT
      brand, search_text, package_size, package_unit,
      array_agg(id ORDER BY is_verified DESC, created_at ASC) AS ids
    FROM products
    WHERE brand IS NOT NULL
      AND search_text IS NOT NULL AND search_text <> ''
    GROUP BY brand, search_text, package_size, package_unit
    HAVING count(*) > 1
  )
  SELECT
    unnest(ids[2:]) AS old_id,
    ids[1]          AS canonical_id
  FROM dup_groups;

  RAISE NOTICE '[dedupe] mapping rows: %', (SELECT count(*) FROM _dedupe_mapping);

  -- 2) prices.product_id -> canonical_id
  UPDATE prices p
  SET product_id = m.canonical_id
  FROM _dedupe_mapping m
  WHERE p.product_id = m.old_id;
  GET DIAGNOSTICS affected_prices = ROW_COUNT;
  RAISE NOTICE '[dedupe] prices remapped: %', affected_prices;

  -- 3) campaigns.product_id -> canonical_id
  UPDATE campaigns c
  SET product_id = m.canonical_id
  FROM _dedupe_mapping m
  WHERE c.product_id = m.old_id;
  GET DIAGNOSTICS affected_campaigns = ROW_COUNT;
  RAISE NOTICE '[dedupe] campaigns remapped: %', affected_campaigns;

  -- 4) product_aliases — UNIQUE (alias, source) constraint var:
  --    canonical zaten ayni alias+source'a sahipse old_id'in alias'i silinmeli,
  --    aksi halde update edilebilir.
  DELETE FROM product_aliases pa
  USING _dedupe_mapping m, product_aliases pa2
  WHERE pa.product_id = m.old_id
    AND pa2.product_id = m.canonical_id
    AND pa.alias = pa2.alias
    AND COALESCE(pa.source, '') = COALESCE(pa2.source, '');

  UPDATE product_aliases pa
  SET product_id = m.canonical_id
  FROM _dedupe_mapping m
  WHERE pa.product_id = m.old_id;
  GET DIAGNOSTICS affected_aliases = ROW_COUNT;
  RAISE NOTICE '[dedupe] aliases remapped: %', affected_aliases;

  -- 5) Eski product satirlarini sil
  DELETE FROM products
  WHERE id IN (SELECT old_id FROM _dedupe_mapping);
  GET DIAGNOSTICS removed_products = ROW_COUNT;
  RAISE NOTICE '[dedupe] products deleted: %', removed_products;
END $$;

COMMIT;

-- 6) MV refresh — latest_prices'in canonical product_id'leri yansitsin
SELECT refresh_latest_prices();

-- Final sanity (manuel inspeksiyon icin)
DO $$
DECLARE
  total_products BIGINT;
  total_prices   BIGINT;
  total_aliases  BIGINT;
BEGIN
  SELECT count(*) INTO total_products FROM products;
  SELECT count(*) INTO total_prices FROM prices;
  SELECT count(*) INTO total_aliases FROM product_aliases;
  RAISE NOTICE '[dedupe] post-migration: products=%, prices=%, aliases=%',
    total_products, total_prices, total_aliases;
END $$;
