-- =====================================================================
-- 020_categorize_remaining_fruit_veg_leaks.sql
-- 019 sonrasi Meyve/Sebze altinda kalan icecek, temizlik, giyim,
-- firin/dondurulmus ve sekerleme sızıntılarını daha once yakala.
-- =====================================================================

ALTER FUNCTION categorize_product(TEXT, TEXT) RENAME TO categorize_product_v019;

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
  a TEXT := translate(
    _norm_tr(p_name) || ' ' || _norm_tr(p_brand),
    'çÇğĞıİöÖşŞüÜâÂîÎûÛ',
    'cCgGiIoOsSuUaAiIuU'
  );
BEGIN
  -- Non-food / household products with fruit aromas or product names.
  IF a ~ 'limonluk|saklama kabi|cam bardak|mutfak gerec' THEN RETURN 'mutfak-esya'; END IF;
  IF a ~ 'sandalet|patik|terlik|ayakkabi|corap|giyim' THEN RETURN 'tekstil'; END IF;
  IF a ~ 'rexona|deodorant' THEN RETURN 'deodorant'; END IF;
  IF a ~ 'vucut spreyi|body sprey|kolonya' THEN RETURN 'kisisel-bakim'; END IF;
  IF a ~ 'yuz temiz|cilt temiz|temizleme kopug|himalaya' THEN RETURN 'cilt-bakim'; END IF;
  IF a ~ 'pril|bulasik|deterjan|yag cozucu|temizlik sivisi|yer temizlik|yuzey temiz|mopa|temizleme havlusu' THEN RETURN 'yuzey-temizleyici'; END IF;

  -- Dairy/probiotic drinks with fruit aromas.
  IF a ~ 'milkshake|probiyotik icecek|icim .*icecek' THEN RETURN 'sut'; END IF;

  -- Gum, candy, bars and biscuit/cake products before fruit words.
  IF a ~ 'sakiz|oneo|first .*sekersiz' THEN RETURN 'sakiz'; END IF;
  IF a ~ 'lolipop|chupa|yupo|cokojelo|sekerleme|jelibon|pestil|meyve bar|piko|patlakli bar|stick .*cilek|vegilet' THEN RETURN 'seker-sekerleme'; END IF;
  -- Flour, yufka and borek should not be pulled into sebze by patates/ispanak.
  IF a ~ 'baklavalik.*un|boreklik.*un|bugday un|(^| )un [0-9]' THEN RETURN 'un'; END IF;
  IF a ~ 'yufka|borek|boregi|boreklik' THEN RETURN 'pizza-hamur'; END IF;
  IF a ~ 'tada .*tavuk|patatesli tavuk|kiymali patatesli' THEN RETURN 'hazir-yemek'; END IF;

  IF a ~ 'hanimeller|kurabiye|biskuvi|biskuv|kraker' THEN RETURN 'bisk-kraker'; END IF;
  IF a ~ 'baklava|churros|milfoy|kek|pasta' THEN RETURN 'pasta-kek'; END IF;

  -- Frozen products belong under Dondurulmus, even when the ingredient is fruit/veg.
  IF a ~ 'dondurulmus|donuk|su buzu|freedo vini' THEN RETURN 'dondurulmus-sebze'; END IF;

  -- Sauces and sweeteners.
  IF a ~ 'nar eksisi|limon sosu|salsa sos|soslu|sos ' THEN RETURN 'sos-soslar'; END IF;
  IF a ~ 'kup seker|toz seker|pudra seker' THEN RETURN 'seker'; END IF;

  -- Drinks: tea/energy/carbonated/water/juice before fresh fruit fallbacks.
  IF a ~ 'fuse tea|ice tea|soguk cay|buzlu cay' THEN RETURN 'soguk-cay'; END IF;
  IF a ~ 'dogadan|teekanne|caykur|poset cay|meyve cayi|yesil cay|beyaz cay|bitki cayi|karisik meyve cayi|form .*cay' THEN RETURN 'cay'; END IF;
  IF a ~ 'red bull|monster|enerji iceceg' THEN RETURN 'enerji-icecek'; END IF;
  IF a ~ 'fanta|sariyer|schweppes|crown|uludag frutti|gazoz|gazli|maltana|bi portakal|portakal [0-9,.]+ ?(l|lt|ml)|mandalina [0-9,.]+ ?(l|lt|ml)' THEN RETURN 'gazli-icecek'; END IF;
  IF a ~ 'elmacik su|(^| )su [0-9,.]+ ?(l|lt|ml)' THEN RETURN 'su'; END IF;
  IF a ~ 'salgam suyu|meyve nektari|meyve iceceg|meyve icecek|meyveli icecek|meyvelim|nektar|dooy|juss|tamek|togo|dimes|cappy|tropicana|meysu|mis .*icecek|will/jusy|lavi .*icecek|sogutlucesme|sizzle-pop|tazeyim .*suyu|mlife .*suyu|greyfurt suyu|ananas .*suyu|armut suyu|visne .*icecek|kayisi .*icecek|seftali .*icecek|karpuz.*icecek|limon .*icecek' THEN RETURN 'meyve-suyu'; END IF;

  RETURN categorize_product_v019(p_name, p_brand);
END;
$$;

DO $$
DECLARE
  v_changed     INT;
  v_before_null INT;
  v_after_null  INT;
BEGIN
  SELECT COUNT(*) INTO v_before_null FROM products WHERE category_id IS NULL;
  RAISE NOTICE '[020] Before re-categorize: NULL=%', v_before_null;

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
  RAISE NOTICE '[020] After re-categorize: NULL=%, changed=%', v_after_null, v_changed;
END $$;
