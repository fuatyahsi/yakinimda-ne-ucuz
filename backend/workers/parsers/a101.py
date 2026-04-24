"""A101 parser — marketfiyati.org.tr uzerinden.

A101 kendi sitesi Next.js RSC payload dokunulebilir (bkz. a101_direct.py —
preserved). Ama kullanici tercihi: butun 6 marketi (a101, bim, carrefoursa,
migros, sok, tarim-kredi) marketfiyati.org.tr'den cekmek — halka acik, tek
kaynak, stor-level fiyatlar. a101_direct.py gerekirse tekrar aktif edilebilir.

Upstream API        : https://api.marketfiyati.org.tr
Bizim filtremiz     : marketAdi == 'a101'
"""

from __future__ import annotations

from ._marketfiyati_base import MarketFiyatiParserBase


class A101Parser(MarketFiyatiParserBase):
    market_id = "a101"
    alias_source = "a101"
    source_label = "a101_via_marketfiyati"
    discovery_notes = (
        "marketfiyati.org.tr API uzerinden. Dogrudan A101 Next.js RSC "
        "scraper'i a101_direct.py olarak korunuyor (daha genis katalog "
        "ama stor-level fiyat yok)."
    )
