# Yakınımda En Ucuz 

Yakındaki market ve kozmetik mağazalarında aynı ürünü karşılaştırıp en uygun fiyatı bulan Flutter uygulaması.

Find the cheapest price for the same product across nearby supermarkets and drugstores.

## Ne yapar?

- **Konum + market seçimi** → kullanıcı hangi zincirleri takip ettiğini seçer (A101, BİM, Migros, ŞOK, CarrefourSA, Tarım Kredi)
- **Fiyat karşılaştırma** → aynı ürünün seçili zincirlerdeki güncel fiyatını yan yana gösterir
- **Alışveriş listesi** → kullanıcı kararlı liste, barkod taramayla ekleme
- **Aktüel broşürler** → A101/BİM/ŞOK haftalık indirim kataloglarını inline olarak okur
- **Kozmetik keşfi** → Gratis, Rossmann vb. mağazalar için ayrı akış

## Mimari

```
┌─────────────────────┐       ┌──────────────────────┐
│  Flutter app (iOS/  │  ──▶  │  Supabase (primary)  │
│  Android/Desktop)   │       │  prices, products,   │
└─────────────────────┘       │  markets, runs       │
         │                    └──────────────────────┘
         │ fallback                       ▲
         ▼                                │ REST upsert
┌─────────────────────┐       ┌──────────────────────┐
│  marketfiyati.org.  │  ◀──  │  backend/workers/    │
│  tr public API      │       │  (Python scrapers)   │
└─────────────────────┘       └──────────────────────┘
                                         ▲
                                         │ 2x/day cron
                              ┌──────────────────────┐
                              │  GitHub Actions      │
                              └──────────────────────┘
```

**Primary source:** Supabase `prices` tablosu, GitHub Actions cron'u ile günde 2 kez doldurulur.

**Fallback:** [marketfiyati.org.tr](https://marketfiyati.org.tr) — TÜBİTAK destekli public aggregator, 6 zincir için sorgu; Supabase boş döner veya offline ise kullanılır.

## Proje yapısı

```
lib/                            # Flutter uygulaması
├── config/
│   └── supabase_config.dart    # Build-time dart-define ile okunur
├── screens/
│   ├── home_shell_screen.dart
│   ├── smart_actueller_screen.dart
│   ├── market_shopping_list_screen.dart
│   ├── cosmetic_discovery_screen.dart
│   ├── supabase_markets_screen.dart
│   └── barcode_scanner_screen.dart
├── providers/                  # Provider pattern
├── services/                   # Supabase + marketfiyati client
└── models/

backend/workers/                # Python scraperlar + Supabase writer
├── core.py                     # SupabaseClient (retry + session refresh)
├── run_marketfiyati.py         # 6 markete fan-out sweep
├── run_worker.py               # Tek market parser runner
├── sanity_check.py             # Post-run delta alarmı
└── parsers/                    # Market-bazlı parserlar

tools/akakce_worker/            # Yedek fiyat kaynağı (akakce.com)
.github/workflows/              # Cron + CI
```

## Kurulum

### Gereksinimler
- Flutter SDK >= 3.2.0
- Python 3.11 (backend scraperlar için)
- Supabase projesi (URL + anon key + service role key)

### Flutter uygulaması

Supabase bağlantı bilgilerini `--dart-define` ile ver — **ASLA repo'ya commit etme**:

```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx

# Android release
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

`SUPABASE_ANON_KEY` = `sb_publishable_*` formatındaki public key. Service role key **kesinlikle** client'a konmamalı — RLS sadece anon key ile uygulanır.

### Backend scraperlar

```bash
cd backend/workers
pip install requests

# Tek market
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
  python run_worker.py --market a101

# Tüm 6 market sweep (marketfiyati üzerinden)
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
  python run_marketfiyati.py --markets a101,bim,migros,sok,carrefoursa,tarim-kredi

# Önceki run'ın cache'inden kurtarma
python run_worker.py --market a101 --from-cache
```

### Cron + GitHub Actions

`.github/workflows/marketfiyati-sweep.yml` günde 2 kez (TR 08:00 + 20:00) otomatik çalışır. Repo secret'ları:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (⚠ anon değil, service_role)

Her sweep sonunda `sanity_check.py` son 7 günlük ortalamayla kıyaslama yapar; %50'den fazla düşüş veya 0 yazım olursa job fail olur.

## Veri akışı — bir sweep'in ömrü

1. Cron tetikler → `run_marketfiyati.py`
2. Keyword listesi için `POST /api/v2/search` → marketfiyati
3. Response 6 markete fan-out, her biri `backend/workers/core.py::SupabaseClient.upsert` ile `prices` tablosuna yazılır
4. Retry + session refresh: SSL/ConnectionError'da exponential backoff + session rebuild
5. `scrape_runs` tablosuna bu sweep için row insert edilir (`prices_added`, `status`)
6. Cache (`backend/workers/cache/*.json`) artifact olarak upload edilir — kaçan kayıtlar için `--from-cache` kurtarma yolu
7. `sanity_check.py` delta kontrolü yapar

## Desteklenen zincirler

| Zincir         | Kapsam           | 
|----------------|------------------|
| A101           |  primary         | 
| BİM            |  primary         | 
| Migros         |  primary         | 
| ŞOK            |  primary         | 
| CarrefourSA    |  primary         | 
| Tarım Kredi    |  primary         |


## Lisans

Private project. © Fuat Yahşi, 2026.
