# Yakınımda En Ucuz — Durum Raporu

**Tarih:** 2026-04-27
**Repo:** https://github.com/fuatyahsi/yakinimda-ne-ucuz
**Son commit:** `5f24b95` (ci(akakce): cron devre disi)

---

## Mimari özet

Üç katman tutuyor:

**Frontend (Flutter)** — `lib/` altında 6 ekranlı uygulama, Supabase Flutter SDK ile primary data source, marketfiyati fallback. Konum + market seçimi → fiyat karşılaştırma → kullanıcı kararlı liste akışı. Provider tabanlı state, shared_preferences ile lokal cache.

**Backend (Python workers)** — `backend/workers/`. Parser registry pattern, `BaseParser` arayüzü, market başına ayrı modül. Ortak `core.py` Supabase REST client (retry + session refresh), bulk writer ve bulk product resolver. 25 parser tanımlı, 6'sı production'a hazır (`status="implemented"`), 19'u keşif aşamasında (placeholder).

**Infrastructure (GitHub Actions + Supabase)** — Günde 2 kez (TR 08:00 ve 20:00) cron sweep. Postgres + RLS + cron + RPC, 8 migration dosyası. Cache fallback paterniyle kurtarma garantili (`--from-cache`).

---

## Çalışan özellikler

### Veri toplama — 6 market production'da

| Market | Kaynak | Parser | Tipik ürün/sweep |
|---|---|---|---:|
| A101 | marketfiyati API | `a101.py` (base = MarketFiyatiParserBase) | ~1,034 |
| BIM | marketfiyati API | `bim.py` | ~725 |
| CarrefourSA | marketfiyati API | `carrefoursa.py` | ~1,718 |
| Migros | marketfiyati API | `migros.py` | ~1,605 |
| Tarım Kredi Koop | marketfiyati API | `tarim_kredi.py` | ~434 |
| **ŞOK** | **sokmarket.com.tr direct (RSC)** | **`sok_direct.py`** | ~3,000-4,000 (yeni) |

Toplam **~8,500-9,500 ürün/sweep** beklentisi (önceki marketfiyati-only 5,559'a karşı sok cutover sonrası ek 3,000+ ürün).

### Performans — sweep süresi 86dk → ~15-20dk

Üç adımda optimize edildi:
- **Step 5a — `BulkWriter`** (commit `906bd2b`): prices + campaigns için 500'lü chunk'larda toplu POST. ~16,000 tekil HTTP çağrısı → ~12 batch çağrısı.
- **Step 5b — `BulkProductResolver`** (commit `778b66d`): `find_or_create_product`'ı 50-item batch'lere indiren bulk lookup/upsert. Per-item 1-4 RTT yerine per-batch 4 RTT.
- **Cutover** (commit `16340c7`): SOK marketfiyati'dan direct'e geçti, paralel job ile toplam süre maksimum job süresine indirildi.

Tam sweep son ölçüm: **5dk 15s** (2026-04-27 smoke), 5559 item, 0 hata.

### Parser arsenali

`status="implemented"` olanlar canlıda kullanılır:
- `a101.py`, `bim.py`, `carrefoursa.py`, `migros.py`, `tarim_kredi.py` — marketfiyati üzerinden
- `sok_direct.py` — sokmarket.com.tr direct
- `a101_direct.py` — A101 direct (yedek; aktif değil)
- `bim_akakce.py` — BIM broşür OCR (yedek; aktif değil)
- `sok_marketfiyati.py` — SOK marketfiyati (yedek; aktif değil)

Yedeklerin korunma sebebi: marketfiyati kapsamı düşerse rollback hattı.

### CI/CD

İki workflow:
- **`marketfiyati-sweep.yml`** (commit `c74acfe`): 3 paralel job — `marketfiyati` (5 market), `sok-direct` (1 market), `sanity` (delta alarm). Cache artifact'lar ayrı yüklenir, 14 gün retention.
- **`akakce-actueller-feed.yml`**: Cron kapalı (commit `5f24b95`). `workflow_dispatch` ile manuel trigger mümkün, geri açmak için `schedule:` bloku yorumlu.
- **`android-build.yml`**: Android APK build (durum bilinmiyor, son test edilmedi).

### Frontend ekranlar

`lib/screens/` altında 6 ekran:
- `home_shell_screen` — ana navigation kabuk
- `supabase_markets_screen` — market seçimi (Supabase'den listeli)
- `market_shopping_list_screen` — kullanıcı alışveriş listesi
- `smart_actueller_screen` — akıllı kampanya/aktüel ekranı
- `barcode_scanner_screen` — `mobile_scanner` ile barkod tarama
- `cosmetic_discovery_screen` — kozmetik özel keşif (cosmetics feature)

### Veritabanı şeması

8 migration: temel şema (products, product_aliases, prices, campaigns, markets, scrape_runs, categories), view'lar, RLS politikaları, cron, app search RPC'si, kategori backfill, kategori kuralları v2.

---

## Bekleyen / kalan iş

### Yakın iş

**HAKMAR alternatif veri kaynağı (#30, pending)** — marketfiyati HAKMAR'ı kapsamıyor. Şu an parser stub'u var ama veri akmıyor. ŞOK'ta yaptığımız gibi (kendi sitesi araştır → direct parser yaz) bir yol. Kapsamı küçük (İstanbul yoğunluklu zincir) ama coverage'imiz için %0.

**Cache'ten 10 atlayan item'ı Supabase'e yaz (#32, pending)** — Önceki bir sweep'te 10 item Supabase'e yazılmamıştı (transient hata). Cache'te duruyor; `run_worker.py --from-cache` ile yazılabilir. Mekanik bir kalıntı, kritik değil.

**`run_worker.py --max-depth` parametresi** — `sok_direct.py` BFS depth'i için kontrol. Şu an parser default'una güveniyor (`_MAX_DISCOVER_DEPTH=2`). Eğer SOK kapsamını agresif genişletmek istersek bu lazım. Workflow yml'de TODO comment olarak duruyor.

**Manuel workflow doğrulaması** — yeni `marketfiyati-sweep.yml` üç-job yapısı henüz GitHub Actions'ta canlı koşmadı. Push'tan sonra `Run workflow` ile küçük parametrelerle (max_keywords=3, sok_max_urls=20) test atılmalı; cache artifact'lar düşüyor mu, sanity check çalışıyor mu doğrulanmalı.

### Orta vade

**HAKMAR Express ayrı kaynak** — `hakmar_express.py` registry'de var ama placeholder. HAKMAR ile aynı sahibin online sınıfı.

**Hızlı teslimat servisleri** — `getir.py`, `migros_hemen.py`, `istegelsin.py`, `yemeksepeti_market.py`, `trendyol_market.py`, `hepsiburada_hizli.py`. Hepsi placeholder. Bu kategori uygulamanın "yakınımda en ucuz" tezini güçlendirir ama kapsam genişliği API erişiminde sıkıntılı.

**Daha küçük zincirler** — `bizim`, `cagdas`, `onur`, `altunbilekler`, `bildirici`, `akyurt`, `yunus`, `gimsa`, `metro`, `macrocenter`, `file_market`. Bölgesel ya da niş; iş önceliği düşük.

**Performans — bulk product resolution v2** — Şu an 50'lik batch URL length'e göre güvenli. Postgres-side bir `find_or_create_product_bulk(jsonb_array)` function yazılırsa 1 RTT'de batch tamamlanır. Migration gerek, ama kazanç dramatik (50-item batch için 4 RTT → 1 RTT).

### Uzun vade

**Mobil yayın** — Android APK build workflow'u mevcut, son durumu test edilmemiş. iOS için Apple Developer hesabı + sertifika sürecine girilmemiş.

**Kullanıcı arayüzü iyileştirmeleri** — fiyat geçmişi grafiği, bildirim sistemi (fiyat düşüşü alarmı), kullanıcı yorumu/puan, market sadakatı (favori marketler). Bunlar app-side feature'lar, backend hazır.

**Veri kalitesi** — şu an `confidence` her item için statik (0.85-0.95). Ürün eşleştirme (brand+name → canonical product) heuristic; hatalı eşlemeler olabilir. Manual review queue ya da crowdsource fix ekranı.

**Coğrafi fiyat farkı** — marketfiyati store-level fiyat veriyor (`depotId`, `latitude`, `longitude` ham payload'da var). Şu an `min` strategy kullanıyoruz; "kullanıcının konumuna en yakın store" stratejisi bu veriyi UI'a getirebilir.

---

## Yol haritası (öneri sıralaması)

**Faz 1 — Doğrulama (1-2 hafta)** — ŞOK direct cutover'ın ilk haftalık döngüsü. Sweep süresi tutarlı mı, hata profili nasıl, sok kapsamı gerçekten 3000+ mi. `marketfiyati-sweep.yml` yeni 3-job yapısının manuel testi. Sanity check delta alarm'larını gözle.

**Faz 2 — HAKMAR (2-3 hafta)** — HAKMAR'ı tek başına ele al. Site keşfi → varsa direct parser → registry update. ŞOK pattern'i emsal.

**Faz 3 — Hızlı teslimat (4-6 hafta)** — Getir, Migros Hemen, Yemeksepeti Market'tan en az birini ekle. Bu kategori uygulamanın "yakınımda" tezi için kritik. API/web access stratejisi her birinde farklı; öncelikle keşif raporu gerekebilir.

**Faz 4 — Frontend olgunlaştırma** — Bildirim sistemi, fiyat geçmişi grafiği, fiyat düşüşü alarmı. Backend hazır, app-side iş.

**Faz 5 — Yayın hazırlık** — Android Play Store başvurusu, iOS sertifikalı build, beta kanal, kullanıcı geri bildirim toplama.

---

## Önemli karar noktaları

- **Akakçe**: cron kapatıldı, dosyalar yedek (commit `5f24b95`). Aktif değil.
- **ŞOK kaynak**: sokmarket.com.tr direct. Marketfiyati versiyonu yedek (`sok_marketfiyati.py`), rollback için registry tek satırlık değişiklik.
- **A101 kaynak**: marketfiyati. `a101_direct.py` yedek. Kapsam düşerse swap.
- **BIM kaynak**: marketfiyati. `bim_akakce.py` yedek (broşür OCR akışı).
