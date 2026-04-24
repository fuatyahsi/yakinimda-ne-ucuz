"""Migros parser — marketfiyati.org.tr uzerinden.

Migros'un kendi /hermes/api/* endpointleri auth duvariyla korumali (403).
Kendi web sitesi tamamen dinamik XHR (Next.js RSC yok, JSON-LD yok, OG yok).
Cozum: TUBITAK destekli halka acik marketfiyati.org.tr API'sini kullan.

Marketfiyati URL'si: https://marketfiyati.org.tr
Upstream API        : https://api.marketfiyati.org.tr
Bizim filtremiz     : marketAdi == 'migros'

Detaylar icin: ./_marketfiyati.py
"""

from __future__ import annotations

from ._marketfiyati_base import MarketFiyatiParserBase


class MigrosParser(MarketFiyatiParserBase):
    market_id = "migros"
    alias_source = "migros"
    source_label = "migros_via_marketfiyati"
    discovery_notes = (
        "marketfiyati.org.tr API uzerinden. Migros kendi sitesi fully "
        "dynamic/auth-gated oldugu icin dolayli kaynak."
    )
