-- =====================================================================
-- 018_categorize_processed_before_fresh.sql
-- Meyve/sebze kelimesi veya meyve-sebze adi gecen islenmis urunler
-- taze meyve/sebze rafina dusmesin.
-- Ornek: limonlu gazoz, maden suyu, patates cipsi, biber sosu,
-- limon kolonyasi, kabak lifli sabun, kirmizi biber kaplamali jambon.
-- =====================================================================

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
  -- Bitkisel sut ozel durumunu normal sut kurallarindan once koru.
  IF n ~ 'alpro|bademli (icecek|içecek|sut|süt)|badem (sutu|sütü|icecek|içecek)|hindistan cevizi (sutu|sütü|icecek|içecek)|soya (sutu|sütü|icecek|içecek)|yulaf (sutu|sütü|icecek|içecek)|pirinc (sutu|sütü)|coconut (milk|drink)|almond (milk|drink)|soy (milk|drink)|oat (milk|drink)' THEN RETURN 'bitkisel-icecek'; END IF;

  -- Icecekler: limon/elma/cilek vb. aromalar taze meyve sayilmamali.
  IF n ~ 'maden suyu|soda|gazoz|gazlı içecek|gazli icecek|sparkling|tonik' THEN RETURN 'gazli-icecek'; END IF;
  IF n ~ 'soğuk çay|soguk cay|ice tea' THEN RETURN 'soguk-cay'; END IF;
  IF n ~ 'meyve suyu|nar suyu|limonata|cappy|dimes|tropicana|meyveli içecek|meyveli icecek' THEN RETURN 'meyve-suyu'; END IF;

  -- Atistirmalik/sekerleme: patates/kabak/cilek gibi kelimeler taze urun
  -- degil, urun formu baskin.
  IF n ~ 'cips|cipsi|patlamış mısır|patlamis misir|popcorn' THEN RETURN 'cips-cerezler'; END IF;
  IF n ~ 'çekirdeği|cekirdegi|ay çekirde|ay cekirde|kabak çekirde|kabak cekirde|kuruyemiş|kuruyemis|fındık|findik|fıstık|fistik|ceviz|badem|antep' THEN RETURN 'kuruyemis'; END IF;
  IF n ~ 'marshmallow|yumuşak şeker|yumusak seker|licorice|jelibon|draje|akide|bebeto|haribo|freeze crunchy|patlayan şeker|patlayan seker' THEN RETURN 'seker-sekerleme'; END IF;

  -- Sos/baharat: biber/sogan gibi sebze adlari islenmis forma ait.
  IF n ~ 'sriracha|biber sosu|acı sos|aci sos|salça|salca|ketçap|ketcap|mayonez|hardal|sos\s' THEN RETURN 'sos-soslar'; END IF;
  IF n ~ 'baharat|toz biber|kırmızı toz|kirmizi toz|pul biber|tatlı toz biber|tatli toz biber|soğan tozu|sogan tozu|karabiber|kimyon|sumak|kekik|köri|kori|tarçın|tarcin|çeşni|cesni' THEN RETURN 'bahorat-cesni'; END IF;

  -- Sarkiuteri/et: biber kaplama veya kekik aromasi et urununu sebze yapmasin.
  IF n ~ 'jambon|salam|sosis|pastırma|pastirma|kavurma' THEN RETURN 'salam-sosis'; END IF;

  -- Kisisel bakim/temizlik: limon, biberiye, kabak lifi vb. sadece aroma/icerik.
  IF n ~ 'kolonya' THEN RETURN 'kisisel-bakim'; END IF;
  IF n ~ 'saç toniği|sac tonigi|saç bakım|sac bakim|saç kremi|sac kremi|saç maskesi|sac maskesi|şampuan|sampuan' THEN RETURN 'sac-bakim'; END IF;
  IF n ~ 'sabun|duş jeli|dus jeli|banyo jeli' THEN RETURN 'dus-jeli'; END IF;
  IF n ~ 'cilt bakım|cilt bakim|yüz bakım|yuz bakim|nemlendirici|losyon|güneş kremi|gunes kremi|el kremi|vücut kremi|vucut kremi' THEN RETURN 'cilt-bakim'; END IF;

  -- 017: aromali sut urunleri meyve olmamali.
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
  RAISE NOTICE '[018] Before re-categorize: NULL=%', v_before_null;

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
  RAISE NOTICE '[018] After re-categorize: NULL=%, changed=%', v_after_null, v_changed;
END $$;
