# Market Worker

Bu klasor, `Smart Aktuel Asistani` icin merkezi brosur ve kampanya isleme hattini tutar.

Amac:
- resmi veya dogrulanmis listing sayfalarini taramak
- brosur veya kampanya kaynaklarini manifest haline getirmek
- urunleri structured HTML veya hedefli OCR ile cikarmak
- uygulamanin tuketecegi `actueller_feed.json` dosyasini uretmek
- gorselle elle dogrulanmis fixture'larla kaliteyi sabitlemek

Not:
- Akakce hattinda Cloudflare engeli olabilir.
- BİM hatti resmi afis + resmi aktuel urun HTML ile calisir.
- Fixture dogrulamasi su an BİM icin aktiftir.

## Klasor yapisi

- `fetch_sources.py`
  - Akakce listing ve detay sayfalarini okur
- `fetch_bim_sources.py`
  - BİM resmi afis sayfasini okur
- `fetch_bim_products.py`
  - BİM resmi aktuel urun HTML'inden urunleri ceker
  - gerekirse poster fallback katmani icin temel hazirlar
- `market_sources.py`
  - resmi market kaynak registry'sini tutar
  - BİM dogrulanmis, diger marketler discovery bekliyor
- `segment_pages.py`
  - sayfa gorsellerini tile manifestine donusturur
- `extract_items.py`
  - genel OCR / price-box denemeleri icin yardimci katman
- `export_feed.py`
  - cikarilan urunleri uygulama feed formatina cevirir
- `run_pipeline.py`
  - tum adimlari sirayla calistirir
- `fixtures/*.json`
  - elle dogrulanmis brosur sayfa fixture'lari
- `validate_fixture.py`
  - tek fixture'i mevcut feed'e karsi dogrular
- `validate_all_fixtures.py`
  - tum fixture'lari topluca dogrular

## Kurulum

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r tools/akakce_worker/requirements.txt
pip install -r tools/akakce_worker/requirements-ocr.txt
```

## Calistirma

BİM resmi kaynak hattini calistirmak:

```bash
python tools/akakce_worker/run_pipeline.py --source bim --max-brochures 24 --download-images
```

Akakce iskelet hattini calistirmak:

```bash
python tools/akakce_worker/run_pipeline.py --source akakce --max-brochures 24 --download-images --extract-items
```

Tek fixture dogrulamasi:

```bash
python tools/akakce_worker/validate_fixture.py --fixture tools/akakce_worker/fixtures/bim_2026_03_10_dairy_page.json
```

Tum BİM fixture'larini dogrulamak:

```bash
python tools/akakce_worker/validate_all_fixtures.py --fixture-glob "bim_*.json"
```

## Uretilen dosyalar

Varsayilan olarak su dosyalar `tools/akakce_worker/output/` altina yazilir:

- `source_manifest.json`
- `tile_manifest.json`
- `extracted_products.json`
- `actueller_feed.json`
- `images/<brochure_id>/page_XX.jpg`
- `crops/<brochure_id>/page_XX/product_YYY.jpg`

## Resmi market kaynagi durumu

- `bim`
  - durum: implemented
  - kaynak: resmi afis + resmi aktuel urun HTML
  - fixture: var
- `a101`
  - durum: discovery_pending
  - hedef: resmi kampanya / afis kaynagi
- `sok`
  - durum: discovery_pending
  - hedef: resmi katalog / ekstra kaynagi
- `migros`
  - durum: discovery_pending
  - hedef: resmi kampanya / Migroskop benzeri kaynak
