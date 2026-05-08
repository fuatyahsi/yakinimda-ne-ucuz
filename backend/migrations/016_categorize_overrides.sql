-- =====================================================================
-- 016_categorize_overrides.sql
-- 015 sonrasi kalan yanlis kategorilemeleri duzelt
-- =====================================================================
-- Tespit edilen sorunlar:
--   - "Cikolatali Cilekli Kek" -> "cilek" matches -> 'meyve' (YANLIS)
--                                Olmali: 'pasta-kek'
--   - "Muzlu Kek 55g" -> "muz" matches -> 'meyve' (YANLIS)
--   - "Akdo Tahinli Dondurma" -> dondurma kuralina dustu ama bazi
--                                "cilekli dondurma" 'meyve'ye dusebiliyor
--   - "Aci Biber Turşusu" -> "biber" matches -> 'sebze' (YANLIS)
--                            Olmali: 'konserve' (turşu kategorisi yok, konserve altinda)
--   - "Aksh Kola Aromali Patlayan Seker" -> 'şeker' matches 'şekerleme'
--                            ama o doğru. Sorun "Akşeker Beyaz Kristal Toz Seker"
--                            -> "şeker" kelimesi 'şekerleme'ye düşüp 'seker-sekerleme'
--                            atanıyor. 'toz şeker' kuralı sonra geliyor + asla match.
--                            Olmali: 'seker' (gida/temel-gida/seker)
--
-- Cozum: Spesifik kelimeler (kek, pasta, dondurma, bar, tursu, toz seker)
-- meyve/sebze/sekerleme kurallarindan ONCE match etmeli.
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
  -- ============ ONCELIKLI: spesifik forma overrides ============

  -- KEK / PASTA / MUFFIN — meyve adi iceren ama kek olan urunler
  IF n ~ '(^|\s)kek(\s|$|li|si)|pasta\s|muffin|cupcake|rulo kek|pandispanya|tart(\s|$)' THEN RETURN 'pasta-kek'; END IF;

  -- DONDURMA — "cilekli dondurma" gibi varyantlar
  IF n ~ 'dondurma|magnum|cornetto|algida|maraş baton|maras baton|frozen yog' THEN RETURN 'dondurma'; END IF;

  -- BAR (protein bar, granola bar) — meyve adi geçen barlar
  IF n ~ 'protein bar|granola bar|müsli bar|musli bar|enerji bar|sporbar|fitbar' THEN RETURN 'bisk-kraker'; END IF;

  -- TURSU — "biber tursusu" sebze degil
  IF n ~ 'turşu|tursu|salamura|kornişon|kornison' THEN RETURN 'konserve'; END IF;

  -- TOZ / KRISTAL ŞEKER — gida/seker (sekerlemeden ONCE)
  IF n ~ 'toz şeker|toz seker|kesme şeker|kesme seker|pudra şeker|pudra seker|kahverengi şeker|kahverengi seker|kristal şeker|kristal seker|brown sugar|granulated sugar' THEN RETURN 'seker'; END IF;

  -- Bitkisel sutler/icecekler (Alpro vs) - kuruyemis'ten ONCE
  IF n ~ 'alpro|bademli (icecek|içecek|sut|süt)|badem (sutu|sütü|icecek|içecek)|hindistan cevizi (sutu|sütü|icecek|içecek)|soya (sutu|sütü|icecek|içecek)|yulaf (sutu|sütü|icecek|içecek)|pirinc (sutu|sütü)|coconut (milk|drink)|almond (milk|drink)|soy (milk|drink)|oat (milk|drink)' THEN RETURN 'bitkisel-icecek'; END IF;

  -- Bitkisel yaglar - kuruyemis'ten ONCE
  IF n ~ 'hindistan cevizi (yagi|yağı)|coconut oil|fistik yagi|fıstık yağı|peanut oil|argan (yagi|yağı)|susam yagi|susam yağı' THEN RETURN 'yag'; END IF;

  -- Yumurta
  IF n ~ '(^|\s)yumurta|köy yumurta|koy yumurta|organik yumurta|kafessiz yumurta|tavuk yumurta|(10|15|30)\s*l[uü] yumurta' THEN RETURN 'yumurta'; END IF;

  -- Tereyagi (peynirden ayir)
  IF n ~ 'tereyağ|tereyag|sade yağ|sade yag|gold tereya|köy tereya|koy tereya|kahvaltilik tereyag|kahvaltilik tereyağ' THEN RETURN 'tereyagi'; END IF;

  -- Camasir suyu (deterjandan ayir)
  IF n ~ '(çamaşır|camasir) suyu|domestos|sodyum hipoklorit|hipoklorit' THEN RETURN 'camasir-suyu'; END IF;

  -- Cop poseti (kagit'ten ayir)
  IF n ~ '(çöp|cop)\s*(poş|pos|torba)|cop\s*torbasi' THEN RETURN 'cop-poseti'; END IF;

  -- Yumusatici (deterjandan ayir)
  IF n ~ 'yumuşatıcı|yumusatici|softex|comfort|lenor|silan' THEN RETURN 'yumusatici'; END IF;

  -- ============ Taze meyve (sıkı: kek/dondurma/şurup/aromalı zaten yukarıda yakalandı) ============
  IF n ~ '(^|\s)elma(\s|$)|(^|\s)portakal|(^|\s)mandalina|(^|\s)muz(\s|$)|(^|\s)armut|(^|\s)kavun|(^|\s)karpuz|kayısı|kayisi|şeftali|seftali|nektarin|kiraz|vişne|visne|üzüm|uzum|incir|ananas|kivi|(^|\s)nar(\s|$)|hurma|yaban mersini|böğürtlen|bogurtlen|(^|\s)çilek(\s|$)|(^|\s)cilek(\s|$)|greyfurt|limon|ahududu|frenk üzüm|frenk uzum|avokado|pomelo' THEN
    -- üzüm sirkesi/kuru üzüm/reçel olmamalı
    IF n !~ 'sirke|(^|\s)kuru|reçel|recel|marmelat|krem(a)?|şurup|surup|aroma|likör|likor' THEN
      RETURN 'meyve';
    END IF;
  END IF;

  -- ============ Taze sebze (turşu yukarıda yakalandı) ============
  IF n ~ '(^|\s)domates|salatalık|salatalik|sivri biber|kapya|çarliston|carliston|yeşil biber|yesil biber|kırmızı biber|kirmizi biber|dolma biber|(^|\s)biber(\s|$)|(^|\s)soğan|(^|\s)sogan|sarımsak|sarimsak|patates|havuç|havuc|lahana|brokoli|karnabahar|(^|\s)kabak|patlıcan|patlican|bamya|bezelye|taze fasulye|barbunya taze|enginar|pırasa|pirasa|ıspanak|ispanak|pancar|şalgam|salgam|(^|\s)turp|kereviz|tatlı mısır|tatli misir|bakla|kıvırcık|kivircik|marul|göbek|gobek|roka' THEN
    -- ketçap/sos/konserve/baharat olmamalı
    IF n !~ 'salça|salca|ketçap|ketcap|sos\s|konserve|salata sosu|biber salça|kara biber|kırmızı pul|pul biber' THEN
      RETURN 'sebze';
    END IF;
  END IF;

  -- ============ Mantar ============
  IF n ~ '(^|\s)mantar|kültür mantar|kultur mantar|istiridye mantar|portobello|champignon' THEN RETURN 'mantar'; END IF;

  -- ============ Bebek ============
  IF n ~ 'bebek bezi|bebek bez\s|bebek iç çamaşı|pull.?up|pants' THEN RETURN 'bebek-bezi'; END IF;
  IF n ~ 'islak mendil|islak havlu|baby wipe' THEN RETURN 'islak-mendil'; END IF;
  IF n ~ 'bebek mama|devam süt|devam sut|bebek kava|hipp|aptamil|bebelac|bebek püre|bebek pure' THEN RETURN 'bebek-mama'; END IF;
  IF n ~ 'bebek (şamp|sampuan|sabun|krem|yağ|yag)' THEN RETURN 'bebek-bakim'; END IF;

  -- ============ Evcil hayvan ============
  IF n ~ 'kedi kumu' THEN RETURN 'kedi-kumu'; END IF;
  IF n ~ 'kedi (mama|maması|yem)' THEN RETURN 'kedi-mama'; END IF;
  IF n ~ 'köpek (mama|maması|yem)|kopek (mama|yem)' THEN RETURN 'kopek-mama'; END IF;

  -- ============ Kagit urunleri ============
  IF n ~ 'tuvalet (kağıdı|kagidi|kağıt|kagit)' THEN RETURN 'kagit'; END IF;
  IF n ~ '(kağıt|kagit) havlu|peçete|pecete|kolay sil|ıslak temizleme mendili' THEN RETURN 'kagit'; END IF;
  IF n ~ 'el (havlu|yuz havlu|yüz havlu)|yuz havlu|yüz havlu|yüzey.*havlu|yuzey.*havlu' THEN RETURN 'kagit'; END IF;

  -- ============ Temizlik ============
  IF n ~ 'toz deterjan|sıvı deterjan|sivi deterjan|çamaşır (deter|toz)|camasir (deter|toz)|persil|ariel|omo|peros' THEN RETURN 'camasir-deterjan'; END IF;
  IF n ~ 'bulaşık (deter|makine|tablet|kapsül|kapsul)|bulasik (deter|makine|tablet|kapsul)|makine tableti|sıvı bulaşık|fairy|finish' THEN RETURN 'bulasik-deterjan'; END IF;
  IF n ~ 'yer (temiz|sil)|banyo temiz|wc |cif |ajax |yüzey temiz|yuzey temiz|çok amaçlı temiz|cok amacli temiz|bitkisel.*temiz' THEN RETURN 'temizlik'; END IF;
  IF n ~ 'oda kokusu|hava spreyi|airwick|air.?wick|glade' THEN RETURN 'temizlik'; END IF;

  -- ============ Kisisel bakim ============
  IF n ~ 'diş macun|dis macun|diş fırça|dis firca|ağız (bakım|gargara|suy)|agiz (bakim|gargara|suy)|ipana|colgate|signal|listerine' THEN RETURN 'dis-bakim'; END IF;
  IF n ~ 'şampuan|sampuan|elseve|pantene|head.?shoulder|clear ' THEN RETURN 'sampuan'; END IF;
  IF n ~ 'saç kremi|sac kremi|saç boyası|sac boyasi|saç maskesi|sac maskesi' THEN RETURN 'sac-bakim'; END IF;
  IF n ~ 'duş jeli|dus jeli|banyo sabun|el sabun|sıvı sabun|sivi sabun|katı sabun|duru |dalan ' THEN RETURN 'dus-jeli'; END IF;
  IF n ~ 'deodorant|roll.?on|sprey koku|rexona|nivea.*spray' THEN RETURN 'deodorant'; END IF;
  IF n ~ 'ped |hijyenik ped|tampon|orkid|molfix.*hijyen' THEN RETURN 'kadin-hijyen'; END IF;
  IF n ~ 'yetişkin bez|yetiskin bez|adult diaper' THEN RETURN 'yetiskin-bezi'; END IF;
  IF n ~ 'tıraş|tiras|jilet|köpük|kopuk|gillette' THEN RETURN 'tras-bakim'; END IF;
  IF n ~ 'yüz (bakım|temizle|toni|krem|serum)|yuz (bakim|temizle|toni|krem|serum)|nemlendirici|cilt bakım|cilt bakim|nivea (krem|cilt)' THEN RETURN 'cilt-bakim'; END IF;
  IF n ~ 'oje |ruj |maskara|makyaj|fondöten|fondoten|allık|allik|eyeliner' THEN RETURN 'kozmetik'; END IF;

  -- ============ Atistirmalik (kek/dondurma/bar/tursu/toz-seker yukarida ele alindi) ============
  IF n ~ 'çikolata|cikolata|gofret|milka|toblerone|tadelle|ülker çik|nestle çik|snickers|mars |bounty|twix' THEN RETURN 'cikolata'; END IF;
  IF n ~ 'cips |çerez|cerez|leblebi|patlamış|patlamis|ay çekirde|ay cekirde|lay.?s|doritos|mısır çerezi|misir cerezi' THEN RETURN 'cips-cerezler'; END IF;
  IF n ~ 'sakız|sakiz|first |falım|falim' THEN RETURN 'sakiz'; END IF;
  IF n ~ 'şekerleme|sekerleme|jelibon|draje|lokum|akide|haribo|helva|patlayan şeker|patlayan seker' THEN RETURN 'seker-sekerleme'; END IF;

  -- ============ Firin / pastane ============
  IF n ~ 'ekmek$|beyaz ekmek|tost ekmek|sandviç ekmek|sandvic ekmek|bazlama|lavaş|lavas' THEN RETURN 'ekmek'; END IF;
  IF n ~ 'bisküvi|biskuvi|kraker|eti cin|eti petit|halley|lu |kurabiye|brownie|browni' THEN RETURN 'bisk-kraker'; END IF;
  IF n ~ 'simit|poğaça|pogaca|açma|acma' THEN RETURN 'simit-poğaca'; END IF;

  -- ============ Sut urunleri ============
  IF n ~ 'ayran|yayık ayranı|yayik ayrani' THEN RETURN 'ayran'; END IF;
  IF n ~ 'kaymak' THEN RETURN 'kaymak'; END IF;
  IF n ~ 'kefir|probiyotik (içe|ice)|probiyotik süt|probiyotik sut' THEN RETURN 'kefir'; END IF;
  IF n ~ 'krem peynir|labne|kaşar|kasar|beyaz peynir|peynir' THEN RETURN 'peynir'; END IF;
  IF n ~ 'yoğurt|yogurt|süzme|suzme|quark' THEN RETURN 'yogurt'; END IF;
  IF n ~ '(tam yağlı |yarım yağlı |sütaş |pınar |sek |laktoz|içme sütü|icme sutu| süt | sutü| sütü|^süt | sut |^sut )' THEN RETURN 'sut'; END IF;
  IF n ~ 'krema |şekerli krema|sekerli krema' THEN RETURN 'krem'; END IF;

  -- ============ Icecek ============
  IF n ~ '(siyah |yeşil |yesil |bitki |bergamot )?çay|^cay| cay |çaykur|doğuş|dogus.*çay' THEN RETURN 'cay'; END IF;
  IF n ~ 'kahve|nescafe|jacobs|türk kahvesi|turk kahvesi' THEN RETURN 'kahve'; END IF;
  IF n ~ 'kola|pepsi|cola|gazoz|fanta|sprite|soda|uludağ|uludag.*gazoz' THEN RETURN 'gazli-icecek'; END IF;
  IF n ~ 'meyve suyu|cappy|dimes|tamek.*meyve|tropicana' THEN RETURN 'meyve-suyu'; END IF;
  IF n ~ 'red bull|burn |monster .*enerji|enerji içec|enerji icec' THEN RETURN 'enerji-icecek'; END IF;
  IF n ~ 'ice tea|soğuk çay|soguk cay|lipton.*ice' THEN RETURN 'soguk-cay'; END IF;
  IF n ~ '(damacana|doğal kaynak su|dogal kaynak su|içme suyu|icme suyu|hayat su|pınar su|pinar su|erikli)' THEN RETURN 'su'; END IF;

  -- ============ Kahvaltilik ============
  IF n ~ 'bal\s|süzme bal|suzme bal|çiçek balı|cam kavanoz bal' THEN RETURN 'bal'; END IF;
  IF n ~ 'fıstık ezmesi|fistik ezmesi' THEN RETURN 'fistik-ezmesi'; END IF;
  IF n ~ 'kakao(lu)? krem|nutella|sarelle|fındık kreması|findik kremasi' THEN RETURN 'kakaolu-krem'; END IF;
  IF n ~ 'gevrek|müsli|musli|kellogg|cornflakes|granola|yulaflı|yulafli' THEN RETURN 'gevrek'; END IF;
  IF n ~ 'pekmez' THEN RETURN 'pekmez'; END IF;
  IF n ~ 'reçel|recel|marmelat' THEN RETURN 'recel'; END IF;
  IF n ~ 'tahin' THEN RETURN 'tahin'; END IF;

  -- ============ Et tavuk ============
  IF n ~ 'sucuk' THEN RETURN 'sucuk'; END IF;
  IF n ~ 'salam|sosis|jambon|pastırma|pastirma|kavurma' THEN RETURN 'salam-sosis'; END IF;
  IF n ~ 'kıyma|kiyma|hamburger kıyma' THEN RETURN 'kiyma'; END IF;
  IF n ~ 'dana |kuzu |biftek|antrikot|kırmızı et|kirmizi et' THEN RETURN 'kirmizi-et'; END IF;
  IF n ~ 'hindi göğüs|hindi but|hindi file' THEN RETURN 'hindi'; END IF;
  IF n ~ '(tavuk|piliç|pilic)(\s|$)|tavuk (göğ|but|file|pirzola|kanat|şiş|sis)|piliç (bonfile|but|file|kanat|göğüs)' THEN RETURN 'tavuk'; END IF;
  IF n ~ 'balık|balik|hamsi|somon|levrek|çipura|cipura' THEN RETURN 'balik'; END IF;
  IF n ~ 'karides|midye|kalamar|deniz ürünü|deniz urunu' THEN RETURN 'deniz-urunu'; END IF;

  -- ============ Temel gida ============
  IF n ~ 'makarna|spagetti|fusilli|penne|erişte|eriste' THEN RETURN 'makarna'; END IF;
  IF n ~ 'pirinç|pirinc|basmati|osmancık|bulgur' THEN RETURN 'pirinc-bulgur'; END IF;
  IF n ~ 'mercimek|nohut|kuru fasulye|barbunya|börülce|borulce' THEN RETURN 'bakliyat'; END IF;
  IF n ~ 'un(\s|\.|$)|buğday unu|bugday unu|mısır unu|misir unu' THEN RETURN 'un'; END IF;
  IF n ~ '(sofra tuz|iyotlu tuz|kaya tuz|ince tuz|tuz$)' THEN RETURN 'tuz'; END IF;
  IF n ~ 'sirke|elma sirkesi|üzüm sirkesi|uzum sirkesi' THEN RETURN 'sirke'; END IF;
  IF n ~ 'zeytinyağı|zeytinyagi|riviera|naturel sızma|sizma' THEN RETURN 'zeytinyagi'; END IF;
  IF n ~ 'ayçiçek|aycicek|mısırözü|misirozu|bitkisel yağ|sıvı yağ|sivi yag' THEN RETURN 'yag'; END IF;
  IF n ~ 'salça|salca|domates püre|ketçap|ketcap|mayonez|hardal|sos\s' THEN RETURN 'sos-soslar'; END IF;
  IF n ~ 'ton balığı|ton baligi|konserve|bezelye konserve|mısır konserve|misir konserve' THEN RETURN 'konserve'; END IF;
  IF n ~ 'karabiber|kimyon|pul biber|sumak|kekik|nane|köri|kori|tarçın|tarcin|baharat|çeşni|cesni' THEN RETURN 'bahorat-cesni'; END IF;

  -- ============ Yesillik (otlar - diger sebzelerden sonra; baharatlardan sonra) ============
  IF n ~ 'maydanoz|dereotu|fesleğen|fesleg|roka|tere(\s|$)|^tere|biberiye|adaçayı|adacayi|nane(\s|$)|^nane' THEN RETURN 'yesillik'; END IF;

  -- ============ Dondurulmus ============
  IF n ~ 'dondurulmuş pizza|donma pizza|hamur yufka' THEN RETURN 'pizza-hamur'; END IF;
  IF n ~ 'dondurulmuş sebze|donma sebze|donmuş sebze' THEN RETURN 'dondurulmus-sebze'; END IF;
  IF n ~ 'mantı|manti|hamur işi|hamur isi' THEN RETURN 'mantici'; END IF;
  IF n ~ 'hazır yemek|hazir yemek|mikrodalga yemek' THEN RETURN 'hazir-yemek'; END IF;

  -- ============ Kuru meyve / kuruyemis ============
  IF n ~ 'kuru meyve|kuru kayısı|kuru incir|kuru üzüm|uzum kurusu' THEN RETURN 'kuru-meyve'; END IF;
  IF n ~ 'kuruyemis|kuruyemiş|fıstık|fistik|fındık|findik|ceviz|badem|antep' THEN RETURN 'kuruyemis'; END IF;

  -- ============ Ev yasam ============
  IF n ~ 'ampul|led ampul|floresan' THEN RETURN 'ampul'; END IF;
  IF n ~ 'pil |kalem pil|aa pil|aaa pil|duracell|varta' THEN RETURN 'pil-batarya'; END IF;
  IF n ~ 'saklama kabı|saklama kabi|cam kavanoz|plastik kutu' THEN RETURN 'saklama-kaplari'; END IF;

  RETURN NULL;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- Tum products icin yeniden kategorize (yanlis atanmislar duzelir)
-- ─────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_changed     INT;
  v_before_null INT;
  v_after_null  INT;
BEGIN
  SELECT COUNT(*) INTO v_before_null FROM products WHERE category_id IS NULL;
  RAISE NOTICE '[016] Before re-categorize: NULL=%', v_before_null;

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
  RAISE NOTICE '[016] After re-categorize: NULL=%, changed=%', v_after_null, v_changed;
END $$;
