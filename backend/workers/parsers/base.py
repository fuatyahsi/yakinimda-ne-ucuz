"""Parser base — her market parser'ının implemente etmesi gereken arayüz.

Parser = bir marketin kaynak sayfasından WorkerItem üretir. Sadece okuma
yapar, Supabase'e yazmaz. Yazma `run_worker.py` tarafının işi.

Parser'lar üç kipten birini destekler:
    - "fetch"   : canlı HTTP fetch + parse (prod)
    - "fixture" : yerel JSON/HTML fixture oku (test, offline dev)
    - "feed"    : başka bir worker'ın ürettiği JSON'ı oku
                  (ör. tools/akakce_worker çıktısı)

Status değerleri:
    "implemented"       : prod'da güvenle koşar
    "discovery_pending" : kaynak URL belli ama parse kodu yok
    "fixture_only"      : yalnızca fixture'dan okuyabilir
"""

from __future__ import annotations

import json
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Iterable

import sys

_THIS = Path(__file__).resolve()
if str(_THIS.parent.parent) not in sys.path:
    sys.path.insert(0, str(_THIS.parent.parent))

from core import WorkerItem  # noqa: E402


class BaseParser(ABC):
    market_id: str = ""
    alias_source: str = ""
    source_label: str = ""
    source_type: str = "brochure"        # brochure / api / ocr / feed
    status: str = "discovery_pending"    # implemented / discovery_pending / fixture_only
    discovery_notes: str = ""

    def fetch_items(self, **kwargs) -> Iterable[WorkerItem]:
        """Canlı fetch. Implemente edilmemişse NotImplementedError."""
        raise NotImplementedError(
            f"{self.__class__.__name__}.fetch_items henüz implemente değil. "
            f"status={self.status}. Notlar: {self.discovery_notes}"
        )

    def read_fixture(self, path: str | Path) -> Iterable[WorkerItem]:
        """Yerel fixture'dan oku. Default: generic JSON reader."""
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        items = data.get("items") if isinstance(data, dict) else data
        if not isinstance(items, list):
            raise ValueError(f"Fixture list bekleniyor: {type(items)}")
        for row in items:
            yield self._row_to_item(row)

    @abstractmethod
    def _row_to_item(self, row: dict) -> WorkerItem:
        """Parser-spesifik: ham satırı WorkerItem'a çevir."""
