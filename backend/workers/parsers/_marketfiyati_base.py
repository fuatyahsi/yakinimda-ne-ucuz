"""Marketfiyati-backed parser mixin.

6 market (a101, bim, migros, sok, carrefoursa, tarim-kredi) ayni
marketfiyati.org.tr kaynagini kullaniyor. Tek fark: marketAdi filtresi.

Bu mixin:
    - /api/v1/info/categories'den tum (main + sub) keyword listesini cikarir
    - iter_all_products ile dedupe dolanir
    - her urun icin SelectedPrice secer (min strategy)
    - WorkerItem olarak yield eder

Kwargs (fetch_items):
    keywords       : opsiyonel liste, default = tum subcategories
    max_pages      : keyword basi max sayfa (test icin)
    size           : sayfa boyutu (default 100)
    strategy       : 'min' (default) veya 'first'
    verbose        : client log (default True)
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Iterable, Iterator

from .base import BaseParser
from ._marketfiyati import (
    MarketFiyatiClient,
    REGISTRY_TO_MARKETFIYATI,
    select_price_for_market,
    product_url,
)

_THIS = Path(__file__).resolve()
if str(_THIS.parent.parent) not in sys.path:
    sys.path.insert(0, str(_THIS.parent.parent))

from core import WorkerItem  # noqa: E402


class MarketFiyatiParserBase(BaseParser):
    """Subclass'larda sadece market_id ve (gerekirse) market_adi set et.

    market_adi verilmezse REGISTRY_TO_MARKETFIYATI'dan otomatik cozulur.
    """

    source_type = "api"
    status = "implemented"

    market_adi: str | None = None  # override istenirse

    website = "https://marketfiyati.org.tr"
    listing_url = "https://marketfiyati.org.tr"

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------
    def _resolve_market_adi(self) -> str:
        if self.market_adi:
            return self.market_adi
        mapped = REGISTRY_TO_MARKETFIYATI.get(self.market_id)
        if not mapped:
            raise ValueError(
                f"{self.__class__.__name__}: registry market_id={self.market_id!r} "
                f"icin marketfiyati marketAdi haritasi yok. "
                f"REGISTRY_TO_MARKETFIYATI'a ekle veya market_adi alanini override et."
            )
        return mapped

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def fetch_items(self, **kwargs) -> Iterable[WorkerItem]:
        market_adi = self._resolve_market_adi()
        keywords = kwargs.get("keywords")  # Iterable[str] | None
        size = int(kwargs.get("size") or 100)
        max_pages = kwargs.get("max_pages")
        strategy = kwargs.get("strategy") or "min"
        delay = float(kwargs.get("delay") or 1.5)
        verbose = bool(kwargs.get("verbose", True))

        client = MarketFiyatiClient(delay_sec=delay, verbose=verbose)

        products_seen = 0
        products_matched_to_market = 0

        for product in client.iter_all_products(
            keywords=keywords,
            size=size,
            max_pages_per_keyword=max_pages,
        ):
            products_seen += 1
            selected = select_price_for_market(product, market_adi, strategy=strategy)
            if selected is None:
                continue
            products_matched_to_market += 1
            item = self._product_to_item(product, selected)
            if item is not None:
                yield item

        if verbose:
            print(
                f"[mf.{self.market_id}] done seen={products_seen} "
                f"matched={products_matched_to_market}"
            )

    # ------------------------------------------------------------------
    # Product -> WorkerItem
    # ------------------------------------------------------------------
    def _product_to_item(self, product: dict, selected) -> WorkerItem | None:
        name = (product.get("title") or "").strip()
        if not name:
            return None

        brand_raw = product.get("brand")
        brand = (brand_raw or "").strip() or None

        # percentage > 0 ise indirim var → discount_price olarak kullan,
        # regular_price'i tahmin et (price / (1 - pct/100)). Kesin regular
        # fiyat API'den gelmedigi icin bu yaklasim. Aksi halde regular = price.
        pct = selected.percentage or 0.0
        price = selected.price
        if pct and pct > 0.0 and pct < 100.0:
            try:
                regular = round(price / (1.0 - pct / 100.0), 2)
            except ZeroDivisionError:
                regular = price
        else:
            regular = price

        image_url = product.get("imageUrl") or None

        pid = str(product.get("id") or "")
        source = product_url(pid) if pid else self.listing_url

        return WorkerItem(
            market_id=self.market_id,
            product_name=name,
            brand=brand,
            discount_price=price,
            regular_price=regular,
            currency="TRY",
            valid_from=None,
            valid_until=None,
            image_url=image_url,
            source_url=source,
            ocr_text=None,
            confidence=0.85,
            raw={
                "product": product,
                "selected_depot": selected.raw,
                "source": "marketfiyati",
            },
        )

    # ------------------------------------------------------------------
    # BaseParser sozlesmesi — fixture okumada kullanilabilir
    # ------------------------------------------------------------------
    def _row_to_item(self, row: dict) -> WorkerItem:
        # Fixture JSON "marketfiyati product" seklinde verilirse parse et.
        if "productDepotInfoList" in row:
            selected = select_price_for_market(row, self._resolve_market_adi())
            if selected is None:
                # fallback: raw fiyat ile
                from ._marketfiyati import SelectedPrice
                selected = SelectedPrice(
                    depot_id="", depot_name="", price=0.0,
                    unit_price=None, percentage=0.0,
                    longitude=None, latitude=None, index_time=None, raw={},
                )
            item = self._product_to_item(row, selected)
            if item is not None:
                return item

        # Klasik duz fixture shape
        def _as_float(v):
            if v is None:
                return None
            try:
                return float(v)
            except (TypeError, ValueError):
                return None

        return WorkerItem(
            market_id=self.market_id,
            product_name=(row.get("productName") or row.get("title") or "").strip(),
            brand=(row.get("brand") or "").strip() or None,
            discount_price=_as_float(row.get("discountPrice") or row.get("price")),
            regular_price=_as_float(row.get("regularPrice") or row.get("price")),
            currency=row.get("currency") or "TRY",
            valid_from=row.get("validFrom"),
            valid_until=row.get("validUntil"),
            image_url=row.get("imageUrl"),
            source_url=row.get("sourceUrl") or self.listing_url,
            ocr_text=row.get("ocrText"),
            confidence=float(row.get("confidence") or 0.85),
            raw=row,
        )
