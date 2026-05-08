-- =====================================================================
-- 022_categorize_baby_drink_pantry_leaks.sql
-- Bebek puresi, probiyotik/fruit drinks, pekmez and frozen-brand
-- leftovers that can still look like fruit/veg by ingredient words.
-- =====================================================================

ALTER FUNCTION categorize_product(TEXT, TEXT) RENAME TO categorize_product_v021;

CREATE OR REPLACE FUNCTION categorize_product(
  p_name  TEXT,
  p_brand TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  a TEXT := regexp_replace(
    translate(
      _norm_tr(p_name) || ' ' || _norm_tr(p_brand),
      'çÇğĞıİöÖşŞüÜâÂîÎûÛ',
      'cCgGiIoOsSuUaAiIuU'
    ),
    U&'\0307',
    '',
    'g'
  );
BEGIN
  -- Pantry/sauce forms before generic puree/baby rules.
  IF a ~ 'domates puresi|domates pure' THEN RETURN 'sos-soslar'; END IF;
  IF a ~ 'pekmez' THEN RETURN 'pekmez'; END IF;

  -- Baby purees and baby meals.
  IF a ~ 'hipp|gurvita baby|bebek mamasi|bebek puresi|pureli kavanoz|organik .*pure' THEN RETURN 'bebek-mama'; END IF;

  -- Dairy/probiotic and other fruit-flavored drinks missed by dotted-I forms.
  IF a ~ 'probiyotik|icim .*icecek' THEN RETURN 'sut'; END IF;
  IF a ~ 'jantea|mis .*icecek|mis portakalli|mis elmali|meyveli icecek|aromali icecek' THEN RETURN 'meyve-suyu'; END IF;

  -- Frozen/private-label vegetables and fries without the explicit frozen word.
  IF a ~ 'inci .*patates|inci .*bezelye|inci .*fasulye|inci .*sogan' THEN RETURN 'dondurulmus-sebze'; END IF;

  -- Bakery/snack leftovers.
  IF a ~ 'grissini|humm .*pancar' THEN RETURN 'bisk-kraker'; END IF;

  RETURN categorize_product_v021(p_name, p_brand);
END;
$$;

DO $$
DECLARE
  v_changed     INT;
  v_before_null INT;
  v_after_null  INT;
BEGIN
  SELECT COUNT(*) INTO v_before_null FROM products WHERE category_id IS NULL;
  RAISE NOTICE '[022] Before re-categorize: NULL=%', v_before_null;

  WITH new_cats AS (
    SELECT id,
           categorize_product(canonical_name, brand) AS cat,
           category_id AS old_cat
    FROM products
  )
  UPDATE products p
  SET category_id = c.id, updated_at = now()
  FROM new_cats nc
  JOIN categories c ON c.id = nc.cat
  WHERE p.id = nc.id
    AND (nc.old_cat IS NULL OR nc.old_cat IS DISTINCT FROM nc.cat);
  GET DIAGNOSTICS v_changed = ROW_COUNT;

  SELECT COUNT(*) INTO v_after_null FROM products WHERE category_id IS NULL;
  RAISE NOTICE '[022] After re-categorize: NULL=%, changed=%', v_after_null, v_changed;
END $$;
