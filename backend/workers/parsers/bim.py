"""BIM parser — marketfiyati.org.tr uzerinden.

BIM'in kendi sitesi sadece haftalik aktuel broşür PDF'i sunuyor (OCR
gerektirir). Daha once `tools/akakce_worker` pipeline'i OCR + extraction
yapiyordu (bkz. bim_akakce.py — preserved) ama bu sadece haftalik kampanya
urunlerini kapsiyor.

Marketfiyati.org.tr BIM'in tum aktif fiyatlarini aggrege ediyor (~30K+ SKU
katalog boyu). Dolayisiyla marketfiyati canonical kaynagimiz. Yedek olarak
bim_akakce.py saklandi — haftalik OCR akisi yeniden istenirse kullanilir.

Upstream API        : https://api.marketfiyati.org.tr
Bizim filtremiz     : marketAdi == 'bim'
"""

from __future__ import annotations

from ._marketfiyati_base import MarketFiyatiParserBase


class BimParser(MarketFiyatiParserBase):
    market_id = "bim"
    alias_source = "bim"
    source_label = "bim_via_marketfiyati"
    discovery_notes = (
        "marketfiyati.org.tr API uzerinden. Eski OCR tabanli BIM parser'i "
        "bim_akakce.py olarak korunuyor."
    )
