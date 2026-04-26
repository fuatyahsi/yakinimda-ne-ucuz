"""SOK parser (yedek) — marketfiyati.org.tr uzerinden.

YEDEK / DEPRECATED — aktif kaynak `sok_direct.py` (sokmarket.com.tr).
2026-04-26'da yapilan kesifte marketfiyati'nin SOK kapsami sistematik olarak
zayif: 30-keyword orneklemesinde diger marketler %18-35 coverage verirken
SOK %0.9'da kalir; tam sweep'te 5559 itemden sadece 43'u (%0.77) SOK'tu.

Bu dosya rollback / fallback icin saklaniyor; registry artik bu siniftan
istemiyor. Tekrar etkinlestirmek istersen __init__.py'da
"sok": ("sok_marketfiyati", "SokParser") olarak yonlendirebilirsin.

Marketfiyati URL'si: https://marketfiyati.org.tr
Upstream API        : https://api.marketfiyati.org.tr
Bizim filtremiz     : marketAdi == 'sok'
"""

from __future__ import annotations

from ._marketfiyati_base import MarketFiyatiParserBase


class SokParser(MarketFiyatiParserBase):
    """DEPRECATED — bkz. sok_direct.SokDirectParser (aktif kaynak)."""

    market_id = "sok"
    alias_source = "sok"
    source_label = "sok_via_marketfiyati"
    discovery_notes = (
        "marketfiyati.org.tr API uzerinden. KAPSAM ZAYIF (~%1) — "
        "yedek; aktif kaynak sok_direct.SokDirectParser."
    )
