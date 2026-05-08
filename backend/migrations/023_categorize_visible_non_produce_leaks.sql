-- =====================================================================
-- 023_categorize_visible_non_produce_leaks.sql
-- Meyve/Sebze ilk sayfada goze carpan ev esyasi, tekstil, kagit,
-- tatli/atistirmalik, margarin, konserve ve mantı kacislarini ayir.
-- =====================================================================

ALTER FUNCTION categorize_product(TEXT, TEXT) RENAME TO categorize_product_v022;

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
  -- Household, textile and paper products with fruit words.
  IF a ~ 'narenciye sikacagi|limon sikacagi|salata makinesi|sikacak' THEN RETURN 'mutfak-esya'; END IF;
  IF a ~ 'kiwi kcj|kiwi kim|otomatik narenciye' THEN RETURN 'kucuk-ev-aletleri'; END IF;
  IF a ~ 'testere seti' THEN RETURN 'kirtasiye'; END IF;
  IF a ~ 'kadin desenli slip|slip limon|koza .*slip' THEN RETURN 'tekstil'; END IF;
  IF a ~ 'sleepy .*mutfak havlusu|mutfak havlusu|islak havlu' THEN RETURN 'kagit'; END IF;

  -- Desserts, bakery and snack balls.
  IF a ~ 'tiramisu|revani|portakalli revani' THEN RETURN 'pasta-kek'; END IF;
  IF a ~ 'puffkins|meyve topu|zuber .*meyve|trio move' THEN RETURN 'seker-sekerleme'; END IF;
  IF a ~ 'granola|tahin.*hurma granola|musli|gevrek' THEN RETURN 'gevrek'; END IF;

  -- Drinks still carrying fruit-only category ids.
  IF a ~ 'meyve icecegi|mis visne|migros visne|organik yaban mersini suyu|sade .*suyu' THEN RETURN 'meyve-suyu'; END IF;

  -- Pantry / prepared food.
  IF a ~ 'margarin|terem|teremyag' THEN RETURN 'yag'; END IF;
  IF a ~ 'cam bezelye|konserve bezelye|tukas .*bezelye' THEN RETURN 'konserve'; END IF;
  IF a ~ 'manti|hingel' THEN RETURN 'mantici'; END IF;

  RETURN categorize_product_v022(p_name, p_brand);
END;
$$;

DO $$
DECLARE
  v_changed     INT;
  v_before_null INT;
  v_after_null  INT;
BEGIN
  SELECT COUNT(*) INTO v_before_null FROM products WHERE category_id IS NULL;
  RAISE NOTICE '[023] Before re-categorize: NULL=%', v_before_null;

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
  RAISE NOTICE '[023] After re-categorize: NULL=%, changed=%', v_after_null, v_changed;
END $$;
