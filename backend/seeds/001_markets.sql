-- =====================================================================
-- seed: markets
-- Yakınımda En Ucuz - market kataloğu
-- =====================================================================
--
-- Tier tanımları:
--   1 = ulusal büyük zincir (A101, BİM, ŞOK, Migros, CarrefourSA)
--   2 = ulusal ama daha küçük / hipermarket odaklı (Metro, File, Macrocenter, Hakmar)
--   3 = bölgesel zincir (Yunus, Çağdaş, Altunbilekler, Bildirici, Akyurt...)
--   4 = online / q-commerce / kurye (Getir, Yemeksepeti Market, Migros Hemen, İstegelsin)
--
-- Notlar:
--   * campaign_schedule sadece pattern; gerçek doğrulama worker'da yapılacak.
--   * website alanı official source adapter'ının başlangıç noktasıdır.
--   * coverage_regions boş bırakıldıysa "ulusal" varsayılır.
--
-- Idempotent: ON CONFLICT ile çakışmayı görmezden geliyoruz, böylece seed
-- tekrar çalıştırılabilir (ör. CI, yeni environment).
-- =====================================================================

INSERT INTO markets (id, display_name, tier, website, campaign_schedule, coverage_regions, notes) VALUES

-- ------------------------ Tier 1: ulusal büyük zincir ------------------------
('bim', 'BİM', 1,
  'https://www.bim.com.tr',
  '{"weekly_release":"tuesday_friday_10_00","source":"aktuel_afis","listing_url":"https://www.bim.com.tr/Categories/680/afisler.aspx"}'::jsonb,
  NULL,
  'Haftada 2 kez aktüel (Salı/Cuma). Resmi afiş + resmi aktüel ürün HTML ile çalışan hat kurulu. Ana pilot.'
),
('a101', 'A101', 1,
  'https://www.a101.com.tr',
  '{"weekly_release":"wednesday_10_00","source":"aldin_aldin","listing_url":"https://www.a101.com.tr/aldin-aldin/"}'::jsonb,
  NULL,
  'Aldın Aldın kataloğu haftalık. Adapter discovery_pending.'
),
('sok', 'ŞOK', 1,
  'https://www.sokmarket.com.tr',
  '{"weekly_release":"wednesday_10_00","source":"ekstra","listing_url":"https://www.sokmarket.com.tr/ekstra"}'::jsonb,
  NULL,
  'ŞOK Ekstra kataloğu. Adapter discovery_pending.'
),
('migros', 'Migros', 1,
  'https://www.migros.com.tr',
  '{"weekly_release":"thursday_10_00","source":"kampanyalar","listing_url":"https://www.migros.com.tr/kampanyalar"}'::jsonb,
  NULL,
  'Kampanya sayfası + Migroskop. Ürün-source eşlemesi pending.'
),
('carrefoursa', 'CarrefourSA', 1,
  'https://www.carrefoursa.com',
  '{"weekly_release":"thursday_10_00","source":"kampanyalar"}'::jsonb,
  NULL,
  'Kampanyalar sayfası + katalog. Adapter henüz yok.'
),

-- ------------------------ Tier 2: orta ölçek / hipermarket ------------------------
('metro', 'Metro Türkiye', 2,
  'https://www.metro-tr.com',
  '{"weekly_release":"monthly","source":"katalog"}'::jsonb,
  NULL,
  'B2B ağırlıklı, aylık katalog.'
),
('hakmar', 'Hakmar', 2,
  'https://www.hakmar.com.tr',
  '{"weekly_release":"friday_10_00","source":"aktuel"}'::jsonb,
  ARRAY['TR-34','TR-41','TR-59'],
  'Marmara ağırlıklı, hızlı büyüyor.'
),
('hakmar-express', 'Hakmar Express', 2,
  'https://www.hakmarexpress.com.tr',
  '{"weekly_release":"friday_10_00","source":"aktuel"}'::jsonb,
  ARRAY['TR-34','TR-41','TR-59'],
  'Hakmar alt markası, küçük format.'
),
('file', 'File Market', 2,
  'https://www.filemarket.com.tr',
  '{"weekly_release":"weekly","source":"kampanyalar"}'::jsonb,
  NULL,
  'Migros bünyesinde premium segment.'
),
('macrocenter', 'Macrocenter', 2,
  'https://www.macrocenter.com.tr',
  '{"weekly_release":"weekly","source":"kampanyalar"}'::jsonb,
  NULL,
  'Migros bünyesinde premium segment.'
),
('gimsa', 'GİMSA', 2,
  'https://www.gimsa.com.tr',
  NULL,
  ARRAY['TR-54'],
  'Sakarya ve çevresi ağırlıklı.'
),
('kipa', 'Kipa', 2,
  NULL,
  NULL,
  ARRAY['TR-35'],
  'Tarihsel kayıt; aktif olmayabilir, doğrulama gerekli.'
),

-- ------------------------ Tier 3: bölgesel zincirler ------------------------
('yunus', 'Yunus Market', 3,
  'https://www.yunus.com.tr',
  '{"weekly_release":"weekly","source":"katalog"}'::jsonb,
  ARRAY['TR-34'],
  'İstanbul odaklı bölgesel zincir.'
),
('cagdas', 'Çağdaş', 3,
  'https://www.cagdaslar.com.tr',
  NULL,
  ARRAY['TR-34','TR-41'],
  'Marmara bölgesi bölgesel zincir.'
),
('bizim', 'Bizim Toptan', 3,
  'https://www.bizimtoptan.com.tr',
  '{"weekly_release":"weekly","source":"firsat"}'::jsonb,
  NULL,
  'Toptan + perakende karma.'
),
('altunbilekler', 'Altunbilekler', 3,
  'https://www.altunbilekler.com',
  '{"weekly_release":"weekly","source":"katalog"}'::jsonb,
  ARRAY['TR-06'],
  'Ankara merkezli bölgesel zincir.'
),
('bildirici', 'Bildirici', 3,
  'https://www.bildirici.com.tr',
  NULL,
  ARRAY['TR-34','TR-41'],
  'Kocaeli/İstanbul bölgesi.'
),
('akyurt', 'Akyurt', 3,
  'https://www.akyurt.com.tr',
  NULL,
  ARRAY['TR-06'],
  'Ankara bölgesi.'
),
('onur', 'Onur Market', 3,
  'https://www.onurmarket.com.tr',
  NULL,
  ARRAY['TR-34'],
  'İstanbul/Anadolu yakası ağırlıklı.'
),
('beypazari', 'Beypazarı Halk Market', 3,
  NULL,
  NULL,
  ARRAY['TR-06'],
  'Ankara bölgesi bölgesel zincir.'
),
('snowy', 'Snowy Market', 3,
  NULL,
  NULL,
  ARRAY['TR-16'],
  'Bursa ve çevresi.'
),
('tarim-kredi', 'Tarım Kredi Kooperatif', 3,
  'https://www.tkkmarket.com.tr',
  '{"weekly_release":"weekly","source":"kampanya"}'::jsonb,
  NULL,
  'Tarım Kredi Kooperatif marketleri. Ulusal, ancak perakende hacmi tier 3.'
),
('pehlivanoglu', 'Pehlivanoğlu', 3,
  NULL,
  NULL,
  ARRAY['TR-34'],
  'İstanbul semt zinciri.'
),
('kilic', 'Kılıç Market', 3,
  NULL,
  NULL,
  ARRAY['TR-41','TR-54'],
  'Kocaeli/Sakarya.'
),
('gurme-market', 'Gürme', 3,
  NULL,
  NULL,
  ARRAY['TR-34'],
  'İstanbul.'
),

-- ------------------------ Tier 4: online / q-commerce / kurye ------------------------
('getir', 'Getir', 4,
  'https://getir.com',
  '{"weekly_release":"dynamic","source":"app"}'::jsonb,
  NULL,
  'Kurye q-commerce. API reverse engineering gerekir.'
),
('yemeksepeti-market', 'Yemeksepeti Market', 4,
  'https://www.yemeksepeti.com/market',
  '{"weekly_release":"dynamic","source":"app"}'::jsonb,
  NULL,
  'Market kategorisi. Çok fazla 3. parti market entegre ediyor.'
),
('migros-hemen', 'Migros Hemen', 4,
  'https://www.migros.com.tr',
  '{"weekly_release":"dynamic","source":"migros-hemen"}'::jsonb,
  NULL,
  'Migros bünyesi, hızlı teslimat kolu. Fiyatlar fiziksel Migros''tan farklı olabilir.'
),
('istegelsin', 'İstegelsin', 4,
  'https://www.istegelsin.com',
  '{"weekly_release":"dynamic","source":"app"}'::jsonb,
  NULL,
  'Migros bünyesi q-commerce.'
),
('trendyol-yemek-market', 'Trendyol Yemek Market', 4,
  'https://www.trendyol.com/yemek',
  '{"weekly_release":"dynamic","source":"app"}'::jsonb,
  NULL,
  'Pazaryeri, market kategorisi.'
),
('hepsiburada-hizli', 'Hepsiburada Hızlı Market', 4,
  'https://www.hepsiburada.com',
  '{"weekly_release":"dynamic","source":"app"}'::jsonb,
  NULL,
  'Hepsiburada hızlı market kolu.'
)

ON CONFLICT (id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  tier = EXCLUDED.tier,
  website = EXCLUDED.website,
  campaign_schedule = EXCLUDED.campaign_schedule,
  coverage_regions = EXCLUDED.coverage_regions,
  notes = EXCLUDED.notes,
  updated_at = now();

-- Sanity check
SELECT tier, COUNT(*) AS market_count
FROM markets
GROUP BY tier
ORDER BY tier;
