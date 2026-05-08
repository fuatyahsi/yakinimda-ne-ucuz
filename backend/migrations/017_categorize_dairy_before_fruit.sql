-- =====================================================================
-- 017_categorize_dairy_before_fruit.sql
-- Meyve aromali sut urunleri meyve/sebze kategorisine dusmesin.
-- Ornek: "Activia Ahududu ... Yogurt", "Activia Mix&Go Cilek".
-- =====================================================================

ALTER FUNCTION categorize_product(TEXT, TEXT) RENAME TO categorize_product_v016;

CREATE OR REPLACE FUNCTION categorize_product(
  p_name  TEXT,
  p_brand TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  n TEXT := _norm_tr(p_name) || ' ' || _norm_tr(p_brand);
BEGIN
  -- 016'nin bitkisel sut ozel durumunu koru; Alpro/Badem sutu normal sut
  -- urunu degil, bitkisel icecek olarak kalmali.
  IF n ~ 'alpro|bademli (icecek|içecek|sut|süt)|badem (sutu|sütü|icecek|içecek)|hindistan cevizi (sutu|sütü|icecek|içecek)|soya (sutu|sütü|icecek|içecek)|yulaf (sutu|sütü|icecek|içecek)|pirinc (sutu|sütü)|coconut (milk|drink)|almond (milk|drink)|soy (milk|drink)|oat (milk|drink)' THEN RETURN 'bitkisel-icecek'; END IF;

  -- Meyve adlari (cilek, ahududu, muz...) 016'da sut urunlerinden once
  -- calistigi icin aromali yogurt/kefir/sut yanlislikla meyve oluyordu.
  IF n ~ 'kefir' THEN RETURN 'kefir'; END IF;
  IF n ~ 'ayran|yayık ayranı|yayik ayrani' THEN RETURN 'ayran'; END IF;
  IF n ~ 'kaymak' THEN RETURN 'kaymak'; END IF;
  IF n ~ 'krem peynir|labne|kaşar|kasar|beyaz peynir|peynir' THEN RETURN 'peynir'; END IF;
  IF n ~ 'activia|actimel|yoğurt|yogurt|süzme|suzme|quark' THEN RETURN 'yogurt'; END IF;
  IF n ~ '(çilekli|cilekli|muzlu|kakaolu|tam yağlı |yarım yağlı |sütaş |pınar |sek |laktoz|içme sütü|icme sutu| süt | sutü| sütü|^süt | sut |^sut )' THEN RETURN 'sut'; END IF;
  IF n ~ 'krema |şekerli krema|sekerli krema' THEN RETURN 'krem'; END IF;

  RETURN categorize_product_v016(p_name, p_brand);
END;
$$;

DO $$
DECLARE
  v_changed     INT;
  v_before_null INT;
  v_after_null  INT;
BEGIN
  SELECT COUNT(*) INTO v_before_null FROM products WHERE category_id IS NULL;
  RAISE NOTICE '[017] Before re-categorize: NULL=%', v_before_null;

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
  RAISE NOTICE '[017] After re-categorize: NULL=%, changed=%', v_after_null, v_changed;
END $$;
