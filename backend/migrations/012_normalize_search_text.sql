-- =====================================================================
-- 012_normalize_search_text.sql
--
-- Tier 2 dedupe (brand+search_text+size+unit) icin search_text'in
-- AGRESIF normalize edilmesi gerek. Onceki normalize sadece slugify +
-- whitespace yapiyordu — "0.5 L" / "500 ml", "Lt" / "L", "0,5" / "0.5",
-- "Su 5 L 5L" gibi varyasyonlari ayri search_text olarak birakiyordu.
--
-- Bu migration:
--   1) SQL function `_normalize_search_text(text)` ekler — Python
--      tarafindaki core.normalize_search_text'in eşdeğeri:
--         - lower + Turkce karakter -> ASCII (basitlestirilmis)
--         - decimal: '0,5' -> '0.5'
--         - size+unit -> base unit (L->ml, kg->g)
--         - non-alphanumeric -> space, whitespace collapse
--         - ardisik tekrar token sil ('5000ml 5000ml' -> '5000ml')
--   2) UPDATE products SET search_text = _normalize_search_text(canonical_name)
--   3) Dedupe re-run (brand+search_text+size+unit gruplari) — 011'in
--      mantigi, simdi daha agresif search_text ile daha cok dup yakalar
--   4) latest_prices MV refresh
--
-- IDEMPOTENT.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1) PL/pgSQL normalize function
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _normalize_search_text(s TEXT) RETURNS TEXT AS $$
DECLARE
  t TEXT := lower(coalesce(s, ''));
  m TEXT[];
  num NUMERIC;
  unit TEXT;
  replacement TEXT;
  iterations INT := 0;
BEGIN
  -- Turkce -> ASCII (komple substitution)
  t := translate(t,
    'çğıİöşüâîû',
    'cgiiosuaiu'
  );

  -- Decimal: '0,5' -> '0.5'
  t := regexp_replace(t, '(\d),(\d)', '\1.\2', 'g');

  -- Size+unit -> base unit. PL/pgSQL regex_replace replacement string'inde
  -- arithmetic yok, bu yuzden loop ile her match'i manual islet.
  LOOP
    m := regexp_match(
      t,
      '(\d+(?:\.\d+)?)\s*(lt|litre|kilogram|kg|gram|gr|mililitre|ml|l|g)\b'
    );
    EXIT WHEN m IS NULL;
    iterations := iterations + 1;
    EXIT WHEN iterations > 50; -- defansif: sonsuz dongu olmasin

    BEGIN
      num := m[1]::numeric;
    EXCEPTION WHEN OTHERS THEN
      EXIT;
    END;
    unit := lower(m[2]);

    IF unit IN ('lt', 'litre', 'l') THEN
      replacement := round(num * 1000)::text || 'ml';
    ELSIF unit IN ('kilogram', 'kg') THEN
      replacement := round(num * 1000)::text || 'g';
    ELSIF unit IN ('gram', 'gr', 'g') THEN
      replacement := round(num)::text || 'g';
    ELSIF unit IN ('mililitre', 'ml') THEN
      replacement := round(num)::text || 'ml';
    ELSE
      EXIT;
    END IF;

    -- Sadece ilk match'i degistir (sonraki LOOP iterasyonunda diger
    -- match'ler ele alinir)
    t := regexp_replace(
      t,
      '(\d+(?:\.\d+)?)\s*(lt|litre|kilogram|kg|gram|gr|mililitre|ml|l|g)\b',
      replacement
    );
  END LOOP;

  -- Non-alphanumeric -> space
  t := regexp_replace(t, '[^a-z0-9]+', ' ', 'g');

  -- Whitespace collapse
  t := regexp_replace(t, '\s+', ' ', 'g');
  t := trim(t);

  -- Ardisik tekrar token dedupe ('5000ml 5000ml' -> '5000ml').
  -- regexp_replace ile back-reference: '\\b(\\w+)(?:\\s+\\1)+\\b' -> '\\1'
  t := regexp_replace(t, '(\m\S+)(\s+\1)+\M', '\1', 'g');

  RETURN t;
END $$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION _normalize_search_text(TEXT) IS
  'Tier 2 dedupe icin agresif search_text normalize. ''0.5 L'' / ''500 ml'' '
  'ayni search_text uretir. Python eşdeğeri: core.normalize_search_text.';


-- ---------------------------------------------------------------------
-- 2) Tum products icin search_text'i yeniden hesapla
-- ---------------------------------------------------------------------
DO $$
DECLARE
  affected INT;
BEGIN
  UPDATE products
  SET search_text = _normalize_search_text(canonical_name)
  WHERE search_text IS DISTINCT FROM _normalize_search_text(canonical_name);
  GET DIAGNOSTICS affected = ROW_COUNT;
  RAISE NOTICE '[normalize-v2] products.search_text refreshed: % rows', affected;
END $$;


-- ---------------------------------------------------------------------
-- 3) Dedupe re-run (brand+search_text+size+unit) — 011 mantigi
-- ---------------------------------------------------------------------
DO $$
DECLARE
  affected_prices    INT := 0;
  affected_campaigns INT := 0;
  affected_aliases   INT := 0;
  removed_products   INT := 0;
BEGIN
  CREATE TEMP TABLE _dedupe_v2 ON COMMIT DROP AS
  WITH dup_groups AS (
    SELECT
      brand,
      search_text,
      package_size,
      package_unit,
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

  RAISE NOTICE '[dedupe-v2] mapping rows: %', (SELECT count(*) FROM _dedupe_v2);

  UPDATE prices p SET product_id = m.canonical_id
  FROM _dedupe_v2 m WHERE p.product_id = m.old_id;
  GET DIAGNOSTICS affected_prices = ROW_COUNT;
  RAISE NOTICE '[dedupe-v2] prices remapped: %', affected_prices;

  UPDATE campaigns c SET product_id = m.canonical_id
  FROM _dedupe_v2 m WHERE c.product_id = m.old_id;
  GET DIAGNOSTICS affected_campaigns = ROW_COUNT;
  RAISE NOTICE '[dedupe-v2] campaigns remapped: %', affected_campaigns;

  -- aliases: UNIQUE(alias,source) constraint var
  DELETE FROM product_aliases pa
  USING _dedupe_v2 m, product_aliases pa2
  WHERE pa.product_id = m.old_id
    AND pa2.product_id = m.canonical_id
    AND pa.alias = pa2.alias
    AND COALESCE(pa.source, '') = COALESCE(pa2.source, '');

  UPDATE product_aliases pa SET product_id = m.canonical_id
  FROM _dedupe_v2 m WHERE pa.product_id = m.old_id;
  GET DIAGNOSTICS affected_aliases = ROW_COUNT;
  RAISE NOTICE '[dedupe-v2] aliases remapped: %', affected_aliases;

  DELETE FROM products WHERE id IN (SELECT old_id FROM _dedupe_v2);
  GET DIAGNOSTICS removed_products = ROW_COUNT;
  RAISE NOTICE '[dedupe-v2] products deleted: %', removed_products;
END $$;

COMMIT;

-- 4) MV refresh
SELECT refresh_latest_prices();

-- Final inspeksiyon
DO $$
DECLARE
  total_products BIGINT;
  total_lp       BIGINT;
BEGIN
  SELECT count(*) INTO total_products FROM products;
  SELECT count(*) INTO total_lp FROM latest_prices;
  RAISE NOTICE '[normalize-v2] post-migration: products=%, latest_prices=%',
    total_products, total_lp;
END $$;
