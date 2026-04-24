"""Macrocenter parser — discovery_pending.

Discovery notes:
    Migros bünyesi premium segment.

Kaynak:
    website     : https://www.macrocenter.com.tr
    listing_url : https://www.macrocenter.com.tr/kampanyalar
"""

from __future__ import annotations

import sys
from pathlib import Path

from .base import BaseParser

_THIS = Path(__file__).resolve()
if str(_THIS.parent.parent) not in sys.path:
    sys.path.insert(0, str(_THIS.parent.parent))

from core import WorkerItem  # noqa: E402


class MacrocenterParser(BaseParser):
    market_id = "macrocenter"
    alias_source = "macrocenter"
    source_label = "macrocenter_kampanya"
    source_type = "brochure"
    status = "discovery_pending"
    discovery_notes = (
        "Migros bünyesi premium segment."
    )

    website = "https://www.macrocenter.com.tr"
    listing_url = "https://www.macrocenter.com.tr/kampanyalar"

    def _row_to_item(self, row: dict) -> WorkerItem:
        """Ortak fixture shape'ine uyuyor. Canlı fetch implemente edilene
        kadar fixture'dan test için kullanılabilir."""
        return WorkerItem(
            market_id=self.market_id,
            product_name=(row.get("productName") or "").strip(),
            brand=(row.get("brand") or "").strip() or None,
            discount_price=_as_float(row.get("discountPrice")),
            regular_price=_as_float(row.get("regularPrice")),
            currency=row.get("currency") or "TRY",
            valid_from=row.get("validFrom"),
            valid_until=row.get("validUntil"),
            image_url=row.get("imageUrl"),
            source_url=row.get("sourceUrl") or self.listing_url,
            ocr_text=row.get("ocrText"),
            confidence=float(row.get("confidence") or 0.8),
            raw=row,
        )

    def fetch_items(self, **kwargs):
        raise NotImplementedError(
            f"{self.__class__.__name__}.fetch_items henüz implemente degil. "
            f"Discovery pending: {self.listing_url or self.website}"
        )


def _as_float(value) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
