"""Tarim Kredi parser — marketfiyati.org.tr uzerinden.

Tarim Kredi Kooperatif Marketleri (TKK). Kendi siteleri (tkkmarket.com.tr)
kampanya PDF'leriyle dagitiyor ve tam online katalog yok.
Cozum: marketfiyati.org.tr API'sinden 'tarim_kredi' filtresiyle cekiyoruz.

NOT: Bizim registry'miz 'tarim-kredi' (dash) — marketfiyati 'tarim_kredi'
(underscore). Mapping REGISTRY_TO_MARKETFIYATI'da.
"""

from __future__ import annotations

from ._marketfiyati_base import MarketFiyatiParserBase


class TarimKrediParser(MarketFiyatiParserBase):
    market_id = "tarim-kredi"
    alias_source = "tarim-kredi"
    source_label = "tarim_kredi_via_marketfiyati"
    discovery_notes = (
        "marketfiyati.org.tr API uzerinden. Registry 'tarim-kredi' ↔ "
        "upstream marketAdi 'tarim_kredi' mapping REGISTRY_TO_MARKETFIYATI'da."
    )
