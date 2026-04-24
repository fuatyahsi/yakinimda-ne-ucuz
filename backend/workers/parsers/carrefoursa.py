"""CarrefourSA parser — marketfiyati.org.tr uzerinden.

CarrefourSA'nin resmi sitesi SAP Commerce (Hybris) uzerine kurulu, ve genel
katalog cekimi icin auth/CSRF akislari veya widget-based JSON'lar var.
Cozum: marketfiyati.org.tr API'sinden 'carrefour' filtresiyle cekiyoruz.

NOT: marketfiyati'da marketAdi 'carrefoursa' DEGIL 'carrefour' olarak gecer.
Bizim registry ID'miz 'carrefoursa' — mapping _marketfiyati.py'de yapiliyor.
"""

from __future__ import annotations

from ._marketfiyati_base import MarketFiyatiParserBase


class CarrefourSAParser(MarketFiyatiParserBase):
    market_id = "carrefoursa"
    alias_source = "carrefoursa"
    source_label = "carrefoursa_via_marketfiyati"
    discovery_notes = (
        "marketfiyati.org.tr API uzerinden. Upstream'de marketAdi='carrefour'; "
        "bizim registry ID'miz 'carrefoursa' — mapping REGISTRY_TO_MARKETFIYATI'da."
    )
