"""BIM parser — `tools/akakce_worker/` çıktısındaki extracted_products.json'ı okur."""

from __future__ import annotations

from .base import BaseParser

import sys
from pathlib import Path
_THIS = Path(__file__).resolve()
if str(_THIS.parent.parent) not in sys.path:
    sys.path.insert(0, str(_THIS.parent.parent))
from core import WorkerItem  # noqa: E402


class BimParser(BaseParser):
    market_id = "bim"
    alias_source = "bim"
    source_label = "bim_official_brochure"
    source_type = "brochure"
    status = "implemented"
    discovery_notes = (
        "Resmi afis + resmi aktuel urun HTML. Pipeline: "
        "tools/akakce_worker/run_pipeline.py --source bim"
    )

    def _row_to_item(self, row: dict) -> WorkerItem:
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
            source_url=row.get("brochureUrl"),
            ocr_text=row.get("ocrText"),
            confidence=float(row.get("confidence") or 0.9),
            raw=row,
        )


def _as_float(value) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
