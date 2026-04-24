-- =====================================================================
-- 008_category_rules_v2.sql — categorize_product kural eklemesi
-- =====================================================================
-- 007 ilk backfill 135/293 urun kategorize etti. Kalan 158'de belirgin
-- desenler var (piliç, çamaşır suyu, yüz bakım, protein bar, vs.).
-- Bu migration:
--   1) categorize_product fonksiyonunu ek kurallarla gunceller
--   2) Hala NULL olan urunleri tekrar kategorize eder
--   3) trigger zaten var, degismiyor
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
  -- ============ Bebek ============
  IF n ~ 'bebek bezi|bebek bez\s|bebek iç çamaşı|pull.?up|pants' THEN RETURN 'bebek-bezi'; END IF;
  IF n ~ 'islak mendil|islak havlu|baby wipe' THEN RETURN 'islak-mendil'; END IF;
  IF n ~ 'bebek mama|devam süt|devam sut|bebek kava|hipp|aptamil|bebelac' THEN RETURN 'bebek-mama'; END IF;
  IF n ~ 'bebek (şamp|sampuan|sabun|krem|yağ|yag)' THEN RETURN 'bebek-bakim'; END IF;

  -- ============ Evcil hayvan ============
  IF n ~ 'kedi kumu' THEN RETURN 'kedi-kumu'; END IF;
  IF n ~ 'kedi (mama|maması|yem)' THEN RETURN 'kedi-mama'; END IF;
  IF n ~ 'köpek (mama|maması|yem)|kopek (mama|yem)' THEN RETURN 'kopek-mama'; END IF;

  -- ============ Kagit urunleri (cok yaygin) ============
  IF n ~ 'tuvalet (kağıdı|kagidi|kağıt|kagit)' THEN RETURN 'kagit'; END IF;
  IF n ~ '(kağıt|kagit) havlu|peçete|pecete|kolay sil|ıslak temizleme mendili' THEN RETURN 'kagit'; END IF;
  IF n ~ 'el (havlu|yuz havlu|yüz havlu)|yuz havlu|yüz havlu|yüzey.*havlu|yuzey.*havlu' THEN RETURN 'kagit'; END IF;
  IF n ~ 'çöp poşet|cop poset|çöp torba|cop torba' THEN RETURN 'kagit'; END IF;

  -- ============ Temizlik ============
  IF n ~ 'çamaşır suyu|camasir suyu|domestos' THEN RETURN 'camasir-deterjan'; END IF;
  IF n ~ 'toz deterjan|sıvı deterjan|sivi deterjan|çamaşır (deter|toz)|camasir (deter|toz)|persil|ariel|omo|peros' THEN RETURN 'camasir-deterjan'; END IF;
  IF n ~ 'yumuşatıcı|yumusatici|softex|comfort' THEN RETURN 'camasir-deterjan'; END IF;
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

  -- ============ Atistirmalik ============
  IF n ~ 'çikolata|cikolata|gofret|milka|toblerone|tadelle|ülker çik|nestle çik|snickers|mars |bounty|twix' THEN RETURN 'cikolata'; END IF;
  IF n ~ 'cips |çerez|cerez|leblebi|patlamış|patlamis|ay çekirde|ay cekirde|lay.?s|doritos|mısır çerezi|misir cerezi' THEN RETURN 'cips-cerezler'; END IF;
  IF n ~ 'dondurma|magnum|cornetto|algida' THEN RETURN 'dondurma'; END IF;
  IF n ~ 'sakız|sakiz|first |falım|falim' THEN RETURN 'sakiz'; END IF;
  IF n ~ 'şeker(leme)?|sekerleme|jelibon|draje|lokum|şekerli|haribo|helva' THEN RETURN 'seker-sekerleme'; END IF;

  -- ============ Firin / pastane ============
  IF n ~ 'ekmek$|beyaz ekmek|tost ekmek|sandviç ekmek|sandvic ekmek|bazlama|lavaş|lavas' THEN RETURN 'ekmek'; END IF;
  IF n ~ 'bisküvi|biskuvi|kraker|eti cin|eti petit|halley|lu |kurabiye|brownie|browni|protein bar|granola bar|müsli bar|musli bar|bar$|\s+bar\s' THEN RETURN 'bisk-kraker'; END IF;
  IF n ~ 'pasta |kek |muffin|cupcake|rulo kek' THEN RETURN 'pasta-kek'; END IF;
  IF n ~ 'simit|poğaça|pogaca|açma|acma' THEN RETURN 'simit-poğaca'; END IF;

  -- ============ Sut urunleri ============
  IF n ~ 'ayran|yayık ayranı|yayik ayrani' THEN RETURN 'ayran'; END IF;
  IF n ~ 'kaymak' THEN RETURN 'kaymak'; END IF;
  IF n ~ 'kefir|probiyotik (içe|ice)|probiyotik süt|probiyotik sut' THEN RETURN 'kefir'; END IF;
  IF n ~ 'tereyağ|tereyag|krem peynir|labne|kaşar|kasar|beyaz peynir|peynir' THEN RETURN 'peynir'; END IF;
  IF n ~ 'yoğurt|yogurt|süzme|suzme|quark' THEN RETURN 'yogurt'; END IF;
  IF n ~ '(tam yağlı |yarım yağlı |sütaş |pınar |sek |laktoz|içme sütü|icme sutu| süt |^süt | sut |^sut )' THEN RETURN 'sut'; END IF;
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
  IF n ~ 'toz şeker|toz seker|kesme şeker|kesme seker|pudra şeker|pudra seker|kahverengi şeker' THEN RETURN 'seker'; END IF;
  IF n ~ '(sofra tuz|iyotlu tuz|kaya tuz|ince tuz|tuz$)' THEN RETURN 'tuz'; END IF;
  IF n ~ 'sirke|elma sirkesi|üzüm sirkesi|uzum sirkesi' THEN RETURN 'sirke'; END IF;
  IF n ~ 'zeytinyağı|zeytinyagi|riviera|naturel sızma|sizma' THEN RETURN 'zeytinyagi'; END IF;
  IF n ~ 'ayçiçek|aycicek|mısırözü|misirozu|bitkisel yağ|sıvı yağ|sivi yag' THEN RETURN 'yag'; END IF;
  IF n ~ 'salça|salca|domates püre|ketçap|ketcap|mayonez|hardal|sos\s' THEN RETURN 'sos-soslar'; END IF;
  IF n ~ 'ton balığı|ton baligi|konserve|bezelye konserve|mısır konserve|misir konserve' THEN RETURN 'konserve'; END IF;
  IF n ~ 'karabiber|kimyon|pul biber|sumak|kekik|nane|köri|kori|tarçın|tarcin|baharat|çeşni|cesni' THEN RETURN 'bahorat-cesni'; END IF;

  -- ============ Dondurulmus ============
  IF n ~ 'dondurulmuş pizza|donma pizza|hamur yufka' THEN RETURN 'pizza-hamur'; END IF;
  IF n ~ 'dondurulmuş sebze|donma sebze|donmuş sebze' THEN RETURN 'dondurulmus-sebze'; END IF;
  IF n ~ 'mantı|manti|hamur işi|hamur isi' THEN RETURN 'mantici'; END IF;
  IF n ~ 'hazır yemek|hazir yemek|mikrodalga yemek' THEN RETURN 'hazir-yemek'; END IF;

  -- ============ Meyve sebze ============
  IF n ~ 'kuru meyve|kuru kayısı|kuru incir|kuru üzüm|uzum kurusu' THEN RETURN 'kuru-meyve'; END IF;
  IF n ~ 'kuruyemis|kuruyemiş|fıstık|fistik|fındık|findik|ceviz|badem|antep' THEN RETURN 'kuruyemis'; END IF;

  -- ============ Ev yasam ============
  IF n ~ 'ampul|led ampul|floresan' THEN RETURN 'ampul'; END IF;
  IF n ~ 'pil |kalem pil|aa pil|aaa pil|duracell|varta' THEN RETURN 'pil-batarya'; END IF;
  IF n ~ 'saklama kabı|saklama kabi|cam kavanoz|plastik kutu' THEN RETURN 'saklama-kaplari'; END IF;

  RETURN NULL;
END;
$$;

-- Sadece hala NULL olanlari tekrar kategorize et
UPDATE products
SET category_id = c.id,
    updated_at  = now()
FROM (
  SELECT id, categorize_product(canonical_name, brand) AS cat
  FROM products
  WHERE category_id IS NULL
) AS new_cats
JOIN categories c ON c.id = new_cats.cat
WHERE products.id = new_cats.id;
