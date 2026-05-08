-- =====================================================================
-- 021_categorize_final_fruit_veg_leaks.sql
-- 020 sonrasi Meyve/Sebze altinda kalan son belirgin urun aileleri.
-- =====================================================================

ALTER FUNCTION categorize_product(TEXT, TEXT) RENAME TO categorize_product_v020;

CREATE OR REPLACE FUNCTION categorize_product(
  p_name  TEXT,
  p_brand TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  a TEXT := translate(
    _norm_tr(p_name) || ' ' || _norm_tr(p_brand),
    'çÇğĞıİöÖşŞüÜâÂîÎûÛ',
    'cCgGiIoOsSuUaAiIuU'
  );
BEGIN
  -- Pet and baby food with fruit/veg flavor words.
  IF a ~ 'kedi mamasi|yas kedi|kuru kedi|whiskas|felix' THEN RETURN 'kedi-mama'; END IF;
  IF a ~ 'kopek mamasi|yas kopek|kuru kopek|friskies' THEN RETURN 'kopek-mama'; END IF;
  IF a ~ 'bebek mamasi|hero baby|hero goodies|hero pouch|pureli kavanoz|kavanoz mama' THEN RETURN 'bebek-mama'; END IF;

  -- Snacks, gum and cereal bars.
  IF a ~ 'doritos|hashas domates|hasas domates|cips' THEN RETURN 'cips-cerezler'; END IF;
  IF a ~ 'first|sakiz' THEN RETURN 'sakiz'; END IF;
  IF a ~ 'yulaf.*bar|granio|lifalif.*bar' THEN RETURN 'gevrek'; END IF;

  -- Powder drinks and missed juice brands.
  IF a ~ 'toz icecek|nazo|dr. oetker .*icecek|oetker toz|lavi' THEN RETURN 'meyve-suyu'; END IF;

  -- Soup and ready-food names should not inherit tomato/mushroom categories.
  IF a ~ 'corba|corbasi|knorr|piyale|ferr .*hazir|the lifeco .*pancar' THEN RETURN 'hazir-yemek'; END IF;

  -- Frozen/fried potato-onion products missing the explicit frozen word.
  IF a ~ 'patates parmak|sogan halka|inci sogan|feast patates|feast sogan' THEN RETURN 'dondurulmus-sebze'; END IF;

  -- Household items with fruit/veg-shaped names.
  IF a ~ 'masa lambasi|lamba|led|ampul' THEN RETURN 'ampul'; END IF;
  IF a ~ 'nargile komuru|komur' THEN RETURN 'ev-yasam'; END IF;

  -- Pantry items whose cultivar/flavor contains fruit words.
  IF a ~ 'limon tuzu' THEN RETURN 'tuz'; END IF;
  IF a ~ 'barbunya|hasata .*fasulye|kuru fasulye' THEN RETURN 'bakliyat'; END IF;

  RETURN categorize_product_v020(p_name, p_brand);
END;
$$;

DO $$
DECLARE
  v_changed     INT;
  v_before_null INT;
  v_after_null  INT;
BEGIN
  SELECT COUNT(*) INTO v_before_null FROM products WHERE category_id IS NULL;
  RAISE NOTICE '[021] Before re-categorize: NULL=%', v_before_null;

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
  RAISE NOTICE '[021] After re-categorize: NULL=%, changed=%', v_after_null, v_changed;
END $$;
