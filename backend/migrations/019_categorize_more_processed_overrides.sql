-- =====================================================================
-- 019_categorize_more_processed_overrides.sql
-- 018 sonrasi Meyve/Sebze altinda kalan belirgin islenmis urun tipleri:
-- buzlu cay, portakal suyu, deterjan, kurabiye/cikolata/gofret,
-- toz biber/baharat, zeytin, dondurma markalari.
-- =====================================================================

ALTER FUNCTION categorize_product(TEXT, TEXT) RENAME TO categorize_product_v018;

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
  -- Icecek varyantlari: meyve adi aroma/urun cesidi, taze meyve degil.
  IF n ~ 'buzlu çay|buzlu cay|soğuk çay|soguk cay|ice tea' THEN RETURN 'soguk-cay'; END IF;
  IF n ~ 'gazl|gazoz|maden suyu|soda|sparkling|tonik' THEN RETURN 'gazli-icecek'; END IF;
  IF n ~ 'domates suyu' THEN RETURN 'sos-soslar'; END IF;
  IF n ~ 'meyve suyu|limonata|cappy|dimes|tropicana|meyveli içecek|meyveli icecek|((portakal|elma|üzüm|uzum|şeftali|seftali|kayısı|kayisi|vişne|visne|nar|limon|karışık|karisik).{0,35}suyu)' THEN RETURN 'meyve-suyu'; END IF;
  IF n ~ 'frappe|soğuk kahve|soguk kahve|kahve' THEN RETURN 'kahve'; END IF;
  IF n ~ 'çaykur|yeşil çay|yesil cay|bitki çayı|bitki cayi|bergamot.*çay|bergamot.*cay' THEN RETURN 'cay'; END IF;

  -- Temizlik ve kisisel bakim.
  IF n ~ 'bulaşık.*deterjan|bulasik.*deterjan|bulaşık deterjanı|bulasik deterjani|fairy|finish' THEN RETURN 'bulasik-deterjan'; END IF;
  IF n ~ 'çamaşır.*deterjan|camasir.*deterjan|deterjan|yüzey temiz|yuzey temiz|temizleyici' THEN RETURN 'temizlik'; END IF;

  -- Atistirmalik, tatli, firin/pastane.
  IF n ~ 'carte d.?or|algida|magnum|cornetto|dondurma' THEN RETURN 'dondurma'; END IF;
  IF n ~ 'çikolata|cikolata|tablet çik|tablet cik|gofret|toblerone|milka|snickers|bounty|twix' THEN RETURN 'cikolata'; END IF;
  IF n ~ 'kurabiye|bisküvi|biskuvi|kraker|eti cin|halley|brownie|browni' THEN RETURN 'bisk-kraker'; END IF;
  IF n ~ 'cheesecake|pasta|kek|cake time|mochi' THEN RETURN 'pasta-kek'; END IF;
  IF n ~ 'sert şeker|sert seker|yumuşak şeker|yumusak seker|marshmallow|jelibon|licorice|candy pop|bebeto|haribo' THEN RETURN 'seker-sekerleme'; END IF;

  -- Temel gida / kahvaltilik / konserve.
  IF n ~ 'makarna|spagetti|fusilli|penne|erişte|eriste' THEN RETURN 'makarna'; END IF;
  IF n ~ 'zeytin' THEN RETURN 'kahvaltilik'; END IF;
  IF n ~ 'konserve|közlenmiş|kozlenmis|köz |koz |domates rende|domates rendesi|patlıcan salatası|patlican salatasi|dilimli mantar' THEN RETURN 'konserve'; END IF;

  -- Baharat/sos: biber/sogan sebze adi olarak degil, islenmis urun tipi.
  IF n ~ 'sriracha|biber sosu|acı sos|aci sos|salça|salca|ketçap|ketcap|mayonez|hardal|sos\s' THEN RETURN 'sos-soslar'; END IF;
  IF n ~ 'baharat|toz .*biber|pul .*biber|biber .*toz|kırmızı biber .*gr|kirmizi biber .*gr|soğan tozu|sogan tozu|karabiber|kimyon|sumak|kekik|köri|kori|tarçın|tarcin|çeşni|cesni' THEN RETURN 'bahorat-cesni'; END IF;

  RETURN categorize_product_v018(p_name, p_brand);
END;
$$;

DO $$
DECLARE
  v_changed     INT;
  v_before_null INT;
  v_after_null  INT;
BEGIN
  SELECT COUNT(*) INTO v_before_null FROM products WHERE category_id IS NULL;
  RAISE NOTICE '[019] Before re-categorize: NULL=%', v_before_null;

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
  RAISE NOTICE '[019] After re-categorize: NULL=%, changed=%', v_after_null, v_changed;
END $$;
