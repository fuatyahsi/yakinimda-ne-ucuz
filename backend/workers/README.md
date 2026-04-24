# Workers

Market scrape adapter'ları. Ortak çekirdek + parser-per-market mimarisi.

## Klasör yapısı

```
backend/workers/
├── core.py              # SupabaseClient + upsert yardımcıları
├── run_worker.py        # generic CLI (--market, --fixture, --live)
├── parsers/
│   ├── base.py          # BaseParser ABC
│   ├── __init__.py      # market_id → parser registry
│   ├── bim.py           # implemented
│   ├── a101.py          # discovery_pending
│   ├── sok.py           # discovery_pending
│   ├── migros.py        # discovery_pending
│   ├── ... (25 market toplam)
└── README.md            # bu dosya
```

## Hızlı bakış

```bash
# Desteklenen marketleri listele:
python backend/workers/run_worker.py --list

# BİM fixture'ından dry-run (Supabase'e yazmaz):
python backend/workers/run_worker.py --market bim \
  --fixture tools/akakce_worker/output/extracted_products.json \
  --dry-run

# BİM fixture'ından Supabase'e yaz (gerçek):
export SUPABASE_URL=https://<proj>.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=eyJ...
python backend/workers/run_worker.py --market bim \
  --fixture tools/akakce_worker/output/extracted_products.json

# Canlı fetch (şu anda sadece bim implemented):
python backend/workers/run_worker.py --market bim --live
```

## Parser statüleri (Nisan 2026 itibarıyla)

| Market                 | Status               | Source type |
| ---------------------- | -------------------- | ----------- |
| bim                    | **implemented**      | brochure    |
| a101                   | discovery_pending    | brochure    |
| sok                    | discovery_pending    | brochure    |
| migros                 | discovery_pending    | brochure    |
| carrefoursa            | discovery_pending    | brochure    |
| metro                  | discovery_pending    | brochure    |
| hakmar / hakmar-express| discovery_pending    | brochure    |
| file / macrocenter     | discovery_pending    | brochure    |
| gimsa / yunus / cagdas | discovery_pending    | brochure    |
| onur / altunbilekler   | discovery_pending    | brochure    |
| bildirici / akyurt     | discovery_pending    | brochure    |
| bizim / tarim-kredi    | discovery_pending    | brochure    |
| getir                  | discovery_pending    | api         |
| yemeksepeti-market     | discovery_pending    | api         |
| migros-hemen           | discovery_pending    | api         |
| istegelsin             | discovery_pending    | api         |
| trendyol-yemek-market  | discovery_pending    | api         |
| hepsiburada-hizli      | discovery_pending    | api         |

## Yeni bir parser'ı "implemented" yapma

Her discovery_pending parser bir iskeletle geliyor: market config (website,
listing_url, source_label), fixture okuyucu (`read_fixture()` + `_row_to_item()`),
ve henüz yazılmamış `fetch_items()`.

Canlı hale getirmek için:

1. **Discovery:** `listing_url`'i tarayıcıda aç. Brochure/katalog listesini
   HTML'den nasıl çıkaracağımızı belirle. Rate limit, robots.txt, User-Agent
   politikasını kontrol et.
2. **Fetch:** `fetch_items()` implemente et. `requests.Session` kullan,
   5s+ arayla istek at, hata durumunda backoff. Her istek `source_url`'i
   `WorkerItem.source_url`'e yaz.
3. **Parse:** `BeautifulSoup` ya da `lxml` ile ürün adını, fiyatı, tarih
   aralığını çıkar. Eşleşmeyenler `raw_payload`'a ham halde düşsün.
4. **Fixture:** Bir haftalık brochure için fixture üret
   (`parsers/fixtures/<market>_<tarih>.json`) ki gelecekte regresyon testi
   için referansımız olsun.
5. **Status:** Parser'daki `status = "implemented"` yap. README'deki tabloyu
   güncelle.
6. **Test:** `--dry-run` ile fixture'dan sağlama yap. Sonra gerçek
   Supabase'e yaz ve `scrape_runs` tablosunda bir başarılı satır gör.

## Yazma davranışı (Supabase tarafı)

Her `run_worker.py` çalıştırması şu 4 tabloya yazar:

1. **scrape_runs** — başta bir `running` satır açılır, bitimde `success` /
   `partial` / `failed` yapılır. Sayaçlar (products_added, prices_added…)
   doldurulur. Gözlem + audit için.
2. **products / product_aliases** — canonical eşleme bulunursa
   `products_matched` artar; bulunmazsa yeni `products` satırı eklenir,
   alias kaydedilir.
3. **prices** — her item için bir zaman serisi satırı. `scrape_run_id` ile
   hangi run'dan geldiği izlenir. `product_id` eşleşme yoksa `NULL` kalır
   ve ham isim `raw_product_name` + `raw_payload` içinde saklanır.
4. **campaigns** — `valid_from` + `valid_until` varsa kampanya satırı
   eklenir. `discount_ratio` generated column olarak otomatik hesaplanır.

## Operasyonel notlar

- **Rate limiting:** Her parser kendi içinde `time.sleep(5)` veya benzeri
  ile yavaşlamalı. Market siteleri bizi engellerse hiçbir veri gelmez.
- **User-Agent:** Parser'lar `Yakinimda-En-Ucuz/0.1 (+https://yakinimda-en-ucuz.app)`
  gibi kimlik bırakır. Böylece market bizi opt-out edebilir.
- **robots.txt:** Her fetch öncesi ilk çalıştırmada `/robots.txt` okunup
  ilgili path'in izni doğrulanmalı.
- **Hata toleransı:** Tek item hatası tüm run'ı batırmaz — `RunStats.errors`
  listesine eklenir, `scrape_runs.error_message` ilk 5 hatayı saklar,
  `status=partial` olur.

## Yeni bir market ekleme

1. `markets` seed'ine satır ekle (`backend/seeds/001_markets.sql`).
2. `parsers/<module>.py` dosyası oluştur, `BaseParser`'ı extend et.
3. `parsers/__init__.py` içindeki `_REGISTRY`'ye kaydet.
4. `python run_worker.py --list` çıktısında yeni marketi gör.
