"""SOK parser — marketfiyati.org.tr uzerinden.

SOK Market'in kendi sitesi (sokmarket.com.tr) tam online katalog sunmuyor.
Cozum: marketfiyati.org.tr API'sinden 'sok' filtresiyle cekiyoruz.

Marketfiyati URL'si: https://marketfiyati.org.tr
Upstream API        : https://api.marketfiyati.org.tr
Bizim filtremiz     : marketAdi == 'sok'
"""

from __future__ import annotations

from ._marketfiyati_base import MarketFiyatiParserBase


class SokParser(MarketFiyatiParserBase):
    market_id = "sok"
    alias_source = "sok"
    source_label = "sok_via_marketfiyati"
    discovery_notes = (
        "marketfiyati.org.tr API uzerinden. SOK kendi sitesinde yaygin "
        "online katalog olmadigi icin dolayli kaynak."
    )
