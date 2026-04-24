# Backend — Yakınımda En Ucuz

Bu klasör mobil uygulamanın **veri omurgasını** barındırır. Uygulama artık sadece
tek bir public API'ye (marketfiyati.org.tr) bağımlı değil — kendi veri tabanımız,
kendi scrape worker'larımız ve kendi push notification mekanizmamız var.

## Neden backend?

Uygulamanın temel katma değeri olan iki özelliği sadece backend ile yapabiliyoruz:

1. **Mümkün olan tüm marketlerden ürün/fiyat getirmek.** Tek bir kaynak çökerse
   veya engellenirse kullanıcı etkilenmesin. Market başına adapter yazıyoruz.
2. **Fiyatı düşen fırsat ürünleri için push bildirim.** Kullanıcı uygulamayı
   açmadan, izlediği ürün indirime girdiğinde/aktüel olarak çıktığında
   haberdar olsun. Bu ancak server-side bir kron + FCM ile mümkün.

## Teknoloji seçimi

- **Veritabanı + Auth + Edge Functions:** Supabase (PostgreSQL 15). Frankfurt
  bölgesi seçilecek (KVKK / düşük gecikme).
- **Worker dili:** Python — `tools/akakce_worker/` altındaki BİM adapter'ı
  zaten Python, `requests + beautifulsoup + easyocr` stack'i yerleşik.
- **Push:** Firebase Cloud Messaging (FCM). Supabase Edge Function → FCM HTTP v1.

## Klasör yapısı

```
backend/
├── migrations/
│   └── 001_initial_schema.sql     # tablolar, indexler, trigger'lar
├── seeds/
│   ├── 001_markets.sql            # 25+ market (Tier 1-4)
│   └── 002_categories.sql         # gıda / temizlik / kişisel bakım kategori ağacı
├── workers/                       # Python scrape adapter'ları (BİM, A101, ŞOK, ...)
├── functions/                     # Supabase Edge Functions (FCM, deal detection)
└── README.md                      # bu dosya
```

## Veri modeli özeti

```
markets                (Tier 1-4, website, campaign_schedule)
  └── market_branches  (şubeler, lat/lng, marketfiyati depotId)
categories             (3 seviyeli ağaç: gida/sut-urunleri/sut)
products               (canonical katalog — "Sütaş Tam Yağlı Süt 1L" tek satır)
  └── product_aliases  (her marketin kendine özgü yazımı)
prices                 (zaman serisi: product × market × şube × tarih × fiyat)
  └── scrape_run_id    (hangi tarama sonucu)
campaigns              (aktüel ürünler: valid_from, valid_until, discount_ratio)
scrape_runs            (her worker çalıştırmasının sonucu + metrikler)
user_profiles          (auth.users'a bağlı, fcm_token, tercih şehri)
user_watches           (kullanıcı izleme listesi: ürün + hedef fiyat)
notifications          (gönderilen/bekleyen bildirim kuyruğu)
receipt_submissions    (ikincil kaynak: kullanıcı fişi OCR queue)
```

Ayrıntılar için `migrations/001_initial_schema.sql` başlık yorumlarına bak.

## Design prensipleri

- **Canonical product + alias:** Aynı gerçek ürün (aynı barkod / aynı marka-boyut)
  tek satır. Farklı marketlerin yazım farkları `product_aliases` ile bağlanır.
  Cross-market karşılaştırma bu tasarımın çıktısı.
- **Prices zaman serisidir.** Yeni fiyat üstüne yazmıyoruz, ekliyoruz. Bu sayede
  7 günlük ortalama ↔ bugünkü fiyat karşılaştırıp otomatik "fırsat" tespiti
  yapabiliyoruz.
- **product_id nullable.** Worker her zaman canonical eşleme bulamaz. Eşleşmeyen
  gözlemler yine `prices`'e düşer, arka plan job canonical'e bağlar. Kayıp yok.
- **dedupe_key notifications'ta UNIQUE.** Aynı ürünün aynı kampanyası için aynı
  kullanıcıya iki kez bildirim gitmez. Worker retry güvenli.

## Kurulum (kullanıcı tarafı)

Bu dosya Claude tarafından, Supabase projesi **henüz oluşturulmamışken**
yazıldı. Kullanıcının yapması gerekenler:

### 1. Supabase projesi aç

1. https://supabase.com/dashboard → **New project**
2. Ad: `yakinimda-en-ucuz`
3. Region: **West EU (Frankfurt)**
4. Strong database password oluştur, **şifre yöneticisine kaydet**.
5. Plan: başlangıç için Free. Production'a geçerken Pro.

Proje hazırlandıktan sonra:
- Project Settings → API → **Project URL** ve **anon public key**'i kopyala.
- Project Settings → Database → **Connection string (URI, pooler değil)**'i kopyala.

### 2. Schema'yı uygula

Supabase SQL Editor'de sırayla çalıştır:

```sql
-- 1)
\i backend/migrations/001_initial_schema.sql

-- 2)
\i backend/seeds/001_markets.sql

-- 3)
\i backend/seeds/002_categories.sql
```

(veya SQL Editor'a dosya içeriğini yapıştır → Run.)

### 3. Environment değişkenleri

Proje kökünde `.env.local` oluştur (bu dosya `.gitignore`'da olacak):

```
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...    # sadece worker/Edge Function
SUPABASE_DB_URL=postgres://postgres:...@db.xxxxxxxxxxxx.supabase.co:5432/postgres
```

**Service role key'i asla Flutter tarafına koymayacağız** — sadece worker'lar
ve Edge Functions kullanacak.

### 4. Sonraki adımlar (Claude yapacak)

- [ ] `backend/workers/bim_worker.py` — mevcut `tools/akakce_worker/` BİM hattını
      Supabase'e yazacak şekilde portla.
- [ ] `backend/workers/a101_worker.py`, `sok_worker.py`, `migros_worker.py`.
- [ ] `backend/migrations/002_views.sql` — `latest_prices` materialized view,
      `avg_price_7d` view, `detect_deals()` function.
- [ ] `backend/functions/send_deal_notifications/` — FCM push Edge Function.
- [ ] pg_cron schedule: her saat `detect_deals()` + her market için
      worker tetikleme.
- [ ] Flutter tarafında `SupabaseService` ekle; `MarketFiyatiSourceService`
      ile aynı interface'i sağlasın ki diğer ekranları değiştirmeden geçiş
      yapalım.

## Legal / KVKK notları

- Scrape edilen veriler **fiyat + ürün adı + market adı**'ndan ibaret —
  kişisel veri içermez.
- `user_profiles.fcm_token`, `receipt_submissions.raw_image_url` gibi
  kişisel alanlar **RLS (Row Level Security)** ile korunur: her kullanıcı
  yalnızca kendi satırını okur/yazar. Bu policy'ler 003 migration'da
  eklenecek.
- robots.txt'e ve market sitelerinin ToS'una saygı göstereceğiz; her
  adapter **rate limit** (5s+ bekleme), **User-Agent kimliği**, ve
  **opt-out kanalı** (market bize `support@yakinimda-en-ucuz.app`'den
  yazarsa adapter durdurulur) içerecek.
