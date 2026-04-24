-- =====================================================================
-- seed: categories
-- Yakınımda En Ucuz - kategori ağacı
-- =====================================================================
--
-- Yapı 3 seviye:
--   L1: ana bölüm  (örn. 'gida')
--   L2: alt grup   (örn. 'sut-urunleri')
--   L3: yaprak     (örn. 'sut')   -- ürünlerin doğrudan bağlanacağı seviye
--
-- path alanı '/' ile ayrılmış slug zincirini tutar; kategori gezinmede
-- ve FTS'te prefix aramayı ucuzlatır.
--
-- Idempotent. Tekrar çalıştırıldığında isim/sıra güncellenir, parent
-- ilişkisi aynı kalır.
-- =====================================================================

-- ------------------ L1: ana bölümler ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('gida',        NULL, 'Gıda',                  'Food',           'gida',        10),
  ('icecek',      NULL, 'İçecek',                'Beverage',       'icecek',      20),
  ('sut-urunleri',NULL, 'Süt Ürünleri',          'Dairy',          'sut-urunleri',30),
  ('et-tavuk',    NULL, 'Et, Tavuk ve Balık',    'Meat & Poultry', 'et-tavuk',    40),
  ('meyve-sebze', NULL, 'Meyve ve Sebze',        'Produce',        'meyve-sebze', 50),
  ('firin',       NULL, 'Fırın ve Pastane',      'Bakery',         'firin',       60),
  ('atistirmalik',NULL, 'Atıştırmalık',          'Snacks',         'atistirmalik',70),
  ('kahvaltilik', NULL, 'Kahvaltılık',           'Breakfast',      'kahvaltilik', 80),
  ('dondurulmus', NULL, 'Dondurulmuş',           'Frozen',         'dondurulmus', 90),
  ('bebek',       NULL, 'Bebek',                 'Baby',           'bebek',      100),
  ('kisisel-bakim',NULL,'Kişisel Bakım',         'Personal Care',  'kisisel-bakim',110),
  ('temizlik',    NULL, 'Temizlik',              'Cleaning',       'temizlik',   120),
  ('ev-yasam',    NULL, 'Ev ve Yaşam',           'Home',           'ev-yasam',   130),
  ('evcil-hayvan',NULL, 'Evcil Hayvan',          'Pet',            'evcil-hayvan',140),
  ('tekstil',     NULL, 'Tekstil ve Giyim',      'Apparel',        'tekstil',    150),
  ('elektronik',  NULL, 'Elektronik ve Aksesuar','Electronics',    'elektronik', 160),
  ('kirtasiye',   NULL, 'Kırtasiye ve Hobi',     'Stationery',     'kirtasiye',  170)
ON CONFLICT (id) DO UPDATE SET
  name_tr = EXCLUDED.name_tr,
  name_en = EXCLUDED.name_en,
  path = EXCLUDED.path,
  sort_order = EXCLUDED.sort_order;

-- ------------------ L2/L3: gida ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('temel-gida',        'gida',          'Temel Gıda',            'Pantry',       'gida/temel-gida',         10),
    ('un',              'temel-gida',    'Un',                    'Flour',        'gida/temel-gida/un',      11),
    ('seker',           'temel-gida',    'Şeker',                 'Sugar',        'gida/temel-gida/seker',   12),
    ('tuz',             'temel-gida',    'Tuz',                   'Salt',         'gida/temel-gida/tuz',     13),
    ('yag',             'temel-gida',    'Yağ',                   'Oil',          'gida/temel-gida/yag',     14),
    ('zeytinyagi',      'temel-gida',    'Zeytinyağı',            'Olive Oil',    'gida/temel-gida/zeytinyagi',15),
    ('sirke',           'temel-gida',    'Sirke',                 'Vinegar',      'gida/temel-gida/sirke',   16),
    ('sos-soslar',      'temel-gida',    'Sos ve Soslar',         'Sauces',       'gida/temel-gida/sos',     17),
    ('konserve',        'temel-gida',    'Konserve',              'Canned',       'gida/temel-gida/konserve',18),
    ('bakliyat',        'temel-gida',    'Bakliyat',              'Legumes',      'gida/temel-gida/bakliyat',19),
    ('pirinc-bulgur',   'temel-gida',    'Pirinç ve Bulgur',      'Rice & Bulgur','gida/temel-gida/pirinc-bulgur',20),
    ('makarna',         'temel-gida',    'Makarna',               'Pasta',        'gida/temel-gida/makarna', 21),
    ('bahorat-cesni',   'temel-gida',    'Baharat ve Çeşni',      'Spices',       'gida/temel-gida/baharat', 22)
ON CONFLICT (id) DO UPDATE SET
  name_tr = EXCLUDED.name_tr,
  parent_id = EXCLUDED.parent_id,
  path = EXCLUDED.path,
  sort_order = EXCLUDED.sort_order;

-- ------------------ L2/L3: icecek ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('su',                'icecek',        'Su',                    'Water',        'icecek/su',                10),
  ('meyve-suyu',        'icecek',        'Meyve Suyu',            'Juice',        'icecek/meyve-suyu',        20),
  ('gazli-icecek',      'icecek',        'Gazlı İçecek',          'Soda',         'icecek/gazli-icecek',      30),
  ('enerji-icecek',     'icecek',        'Enerji İçeceği',        'Energy',       'icecek/enerji-icecek',     40),
  ('soguk-cay',         'icecek',        'Soğuk Çay',             'Iced Tea',     'icecek/soguk-cay',         50),
  ('cay',               'icecek',        'Çay',                   'Tea',          'icecek/cay',               60),
  ('kahve',             'icecek',        'Kahve',                 'Coffee',       'icecek/kahve',             70),
  ('sicak-icecek-diger','icecek',        'Diğer Sıcak İçecekler', 'Hot Drinks',   'icecek/sicak-icecek-diger',80)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: sut-urunleri ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('sut',               'sut-urunleri',  'Süt',                   'Milk',         'sut-urunleri/sut',         10),
  ('yogurt',            'sut-urunleri',  'Yoğurt',                'Yogurt',       'sut-urunleri/yogurt',      20),
  ('ayran',             'sut-urunleri',  'Ayran',                 'Ayran',        'sut-urunleri/ayran',       30),
  ('kefir',             'sut-urunleri',  'Kefir',                 'Kefir',        'sut-urunleri/kefir',       40),
  ('peynir',            'sut-urunleri',  'Peynir',                'Cheese',       'sut-urunleri/peynir',      50),
  ('tereyagi',          'sut-urunleri',  'Tereyağı',              'Butter',       'sut-urunleri/tereyagi',    60),
  ('kaymak',            'sut-urunleri',  'Kaymak',                'Clotted Cream','sut-urunleri/kaymak',      70),
  ('krem',              'sut-urunleri',  'Krem ve Krema',         'Cream',        'sut-urunleri/krem',        80),
  ('yumurta',           'sut-urunleri',  'Yumurta',               'Eggs',         'sut-urunleri/yumurta',     90)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: et-tavuk ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('kirmizi-et',        'et-tavuk',      'Kırmızı Et',            'Red Meat',     'et-tavuk/kirmizi-et',      10),
  ('tavuk',             'et-tavuk',      'Tavuk',                 'Chicken',      'et-tavuk/tavuk',           20),
  ('hindi',             'et-tavuk',      'Hindi',                 'Turkey',       'et-tavuk/hindi',           30),
  ('balik',             'et-tavuk',      'Balık',                 'Fish',         'et-tavuk/balik',           40),
  ('deniz-urunu',       'et-tavuk',      'Deniz Ürünleri',        'Seafood',      'et-tavuk/deniz-urunu',     50),
  ('sarkuteri',         'et-tavuk',      'Şarküteri',             'Deli',         'et-tavuk/sarkuteri',       60),
  ('sucuk',             'et-tavuk',      'Sucuk',                 'Sucuk',        'et-tavuk/sucuk',           70),
  ('salam-sosis',       'et-tavuk',      'Salam ve Sosis',        'Sausage',      'et-tavuk/salam-sosis',     80),
  ('kiyma',             'et-tavuk',      'Kıyma',                 'Mince',        'et-tavuk/kiyma',           90)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: meyve-sebze ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('meyve',             'meyve-sebze',   'Meyve',                 'Fruit',        'meyve-sebze/meyve',        10),
  ('sebze',             'meyve-sebze',   'Sebze',                 'Vegetable',    'meyve-sebze/sebze',        20),
  ('yesillik',          'meyve-sebze',   'Yeşillik',              'Herbs',        'meyve-sebze/yesillik',     30),
  ('organik',           'meyve-sebze',   'Organik',               'Organic',      'meyve-sebze/organik',      40),
  ('mantar',            'meyve-sebze',   'Mantar',                'Mushroom',     'meyve-sebze/mantar',       50),
  ('kuruyemis',         'meyve-sebze',   'Kuruyemiş',             'Nuts',         'meyve-sebze/kuruyemis',    60),
  ('kuru-meyve',        'meyve-sebze',   'Kuru Meyve',            'Dried Fruit',  'meyve-sebze/kuru-meyve',   70)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: firin ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('ekmek',             'firin',         'Ekmek',                 'Bread',        'firin/ekmek',              10),
  ('pasta-kek',         'firin',         'Pasta ve Kek',          'Cake',         'firin/pasta-kek',          20),
  ('bisk-kraker',       'firin',         'Bisküvi ve Kraker',     'Biscuits',     'firin/biskuvi-kraker',     30),
  ('simit-poğaca',      'firin',         'Simit ve Poğaça',       'Simit',        'firin/simit-pogaca',       40)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: atistirmalik ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('cikolata',          'atistirmalik',  'Çikolata',              'Chocolate',    'atistirmalik/cikolata',    10),
  ('seker-sekerleme',   'atistirmalik',  'Şekerleme',             'Candy',        'atistirmalik/sekerleme',   20),
  ('cips-cerezler',     'atistirmalik',  'Cips ve Çerezler',      'Chips',        'atistirmalik/cips',        30),
  ('sakiz',             'atistirmalik',  'Sakız',                 'Gum',          'atistirmalik/sakiz',       40),
  ('dondurma',          'atistirmalik',  'Dondurma',              'Ice Cream',    'atistirmalik/dondurma',    50)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: kahvaltilik ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('recel',             'kahvaltilik',   'Reçel',                 'Jam',          'kahvaltilik/recel',        10),
  ('bal',               'kahvaltilik',   'Bal',                   'Honey',        'kahvaltilik/bal',          20),
  ('pekmez',            'kahvaltilik',   'Pekmez',                'Molasses',     'kahvaltilik/pekmez',       30),
  ('tahin',             'kahvaltilik',   'Tahin',                 'Tahini',       'kahvaltilik/tahin',        40),
  ('fistik-ezmesi',     'kahvaltilik',   'Fıstık Ezmesi',         'Peanut Butter','kahvaltilik/fistik-ezmesi',50),
  ('gevrek',            'kahvaltilik',   'Gevrek ve Müsli',       'Cereal',       'kahvaltilik/gevrek',       60),
  ('kakaolu-krem',      'kahvaltilik',   'Kakaolu Krem',          'Cocoa Spread', 'kahvaltilik/kakaolu-krem', 70)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: dondurulmus ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('dondurulmus-et',    'dondurulmus',   'Dondurulmuş Et/Tavuk',  'Frozen Meat',  'dondurulmus/et',           10),
  ('dondurulmus-sebze', 'dondurulmus',   'Dondurulmuş Sebze',     'Frozen Veg',   'dondurulmus/sebze',        20),
  ('hazir-yemek',       'dondurulmus',   'Hazır Yemek',           'Ready Meals',  'dondurulmus/hazir-yemek',  30),
  ('mantici',           'dondurulmus',   'Mantı ve Hamur İşi',    'Dumplings',    'dondurulmus/manti',        40),
  ('pizza-hamur',       'dondurulmus',   'Pizza ve Hamur',        'Pizza',        'dondurulmus/pizza',        50)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: bebek ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('bebek-bezi',        'bebek',         'Bebek Bezi',            'Diaper',       'bebek/bez',                10),
  ('bebek-mama',        'bebek',         'Bebek Maması',          'Baby Food',    'bebek/mama',               20),
  ('bebek-bakim',       'bebek',         'Bebek Bakım',           'Baby Care',    'bebek/bakim',              30),
  ('islak-mendil',      'bebek',         'Islak Mendil',          'Wipes',        'bebek/islak-mendil',       40)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: kisisel-bakim ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('sampuan',           'kisisel-bakim', 'Şampuan',               'Shampoo',      'kisisel-bakim/sampuan',    10),
  ('sac-bakim',         'kisisel-bakim', 'Saç Bakım',             'Hair Care',    'kisisel-bakim/sac-bakim',  20),
  ('dus-jeli',          'kisisel-bakim', 'Duş Jeli ve Sabun',     'Body Wash',    'kisisel-bakim/dus-jeli',   30),
  ('dis-bakim',         'kisisel-bakim', 'Diş Bakımı',            'Oral Care',    'kisisel-bakim/dis-bakim',  40),
  ('deodorant',         'kisisel-bakim', 'Deodorant',             'Deodorant',    'kisisel-bakim/deodorant',  50),
  ('tras-bakim',        'kisisel-bakim', 'Tıraş Bakım',           'Shaving',      'kisisel-bakim/tras',       60),
  ('cilt-bakim',        'kisisel-bakim', 'Cilt Bakımı',           'Skin Care',    'kisisel-bakim/cilt-bakim', 70),
  ('kadin-hijyen',      'kisisel-bakim', 'Kadın Hijyen',          'Feminine',     'kisisel-bakim/kadin-hijyen',80),
  ('yetiskin-bezi',     'kisisel-bakim', 'Yetişkin Bezi',         'Adult Diaper', 'kisisel-bakim/yetiskin-bezi',90),
  ('kozmetik',          'kisisel-bakim', 'Kozmetik',              'Cosmetics',    'kisisel-bakim/kozmetik',  100)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: temizlik ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('camasir-deterjan',  'temizlik',      'Çamaşır Deterjanı',     'Laundry',      'temizlik/camasir-deterjan',10),
  ('yumusatici',        'temizlik',      'Yumuşatıcı',            'Softener',     'temizlik/yumusatici',      20),
  ('bulasik-deterjan',  'temizlik',      'Bulaşık Deterjanı',     'Dish Soap',    'temizlik/bulasik',         30),
  ('bulasik-makinesi',  'temizlik',      'Bulaşık Makinesi Ürünleri','Dishwasher','temizlik/bulasik-makinesi',40),
  ('yuzey-temizleyici', 'temizlik',      'Yüzey Temizleyici',     'Surface',      'temizlik/yuzey',           50),
  ('camasir-suyu',      'temizlik',      'Çamaşır Suyu',          'Bleach',       'temizlik/camasir-suyu',    60),
  ('kagit',             'temizlik',      'Kağıt Ürünleri',        'Paper',        'temizlik/kagit',           70),
  ('cop-poseti',        'temizlik',      'Çöp Poşeti',            'Trash Bag',    'temizlik/cop-poseti',      80)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: ev-yasam ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('mutfak-esya',       'ev-yasam',      'Mutfak Eşyası',         'Kitchenware',  'ev-yasam/mutfak',          10),
  ('saklama-kaplari',   'ev-yasam',      'Saklama Kapları',       'Storage',      'ev-yasam/saklama',         20),
  ('kucuk-ev-aletleri', 'ev-yasam',      'Küçük Ev Aletleri',     'Small Appliance','ev-yasam/kucuk-ev-aletleri',30),
  ('ampul',             'ev-yasam',      'Ampul ve Aydınlatma',   'Lighting',     'ev-yasam/ampul',           40),
  ('pil-batarya',       'ev-yasam',      'Pil ve Batarya',        'Batteries',    'ev-yasam/pil',             50)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- ------------------ L2/L3: evcil-hayvan ------------------
INSERT INTO categories (id, parent_id, name_tr, name_en, path, sort_order) VALUES
  ('kedi-mama',         'evcil-hayvan',  'Kedi Maması',           'Cat Food',     'evcil-hayvan/kedi-mama',   10),
  ('kopek-mama',        'evcil-hayvan',  'Köpek Maması',          'Dog Food',     'evcil-hayvan/kopek-mama',  20),
  ('kedi-kumu',         'evcil-hayvan',  'Kedi Kumu',             'Cat Litter',   'evcil-hayvan/kedi-kumu',   30),
  ('evcil-aksesuar',    'evcil-hayvan',  'Evcil Hayvan Aksesuarı','Pet Accessory','evcil-hayvan/aksesuar',    40)
ON CONFLICT (id) DO UPDATE SET name_tr=EXCLUDED.name_tr, parent_id=EXCLUDED.parent_id, path=EXCLUDED.path, sort_order=EXCLUDED.sort_order;

-- Sanity check
SELECT parent_id IS NULL AS is_root, COUNT(*) AS category_count
FROM categories
GROUP BY parent_id IS NULL
ORDER BY is_root DESC;
