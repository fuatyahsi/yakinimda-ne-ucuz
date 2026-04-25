"""Shared worker core — Supabase REST istemcisi ve upsert yardımcıları.

Her market parser'ı bu modülü import eder. `run_worker.py` bu modülü CLI
etrafında saran ince bir katmandır.

Kullanım:
    from core import SupabaseClient, WorkerItem, RunStats, upsert_item

Environment:
    SUPABASE_URL
    SUPABASE_SERVICE_ROLE_KEY
"""

from __future__ import annotations

import hashlib
import os
import random
import re
import sys
import time
import unicodedata
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

try:
    import requests
except ImportError as error:  # pragma: no cover
    raise SystemExit("`pip install requests` gerekli.") from error


WORKER_VERSION = "generic_worker/0.1.0"


# ---------------------------------------------------------------------
# Retry ayarlari
# ---------------------------------------------------------------------
# Supabase REST'e yazim sirasinda zaman zaman SSLEOFError, ConnectionError
# gibi network hatalari gorulebilir (uzun TCP bekleme + load balancer idle
# timeout). Ayni sekilde Supabase'den transient 5xx/429 donebilir.
# Wrapper davranisi:
#   - Network hatalarinda session'u yeniden kurar (bayat TCP bagini at).
#   - 5xx/429/408 status'larda exponential backoff'la tekrar dener.
#   - Diger HTTPError'lar (401, 4xx) dogrudan yukari propagate.
# Motivasyon: 2026-04-24 live run'da 5528 item icinde 10 tanesi
# SSLEOFError / RemoteDisconnected yuzunden kacti. Session refresh + retry
# bu sinifin tamamini toparlayacak.
_RETRYABLE_EXC: tuple[type[BaseException], ...] = (
    requests.exceptions.SSLError,
    requests.exceptions.ConnectionError,
    requests.exceptions.Timeout,
    requests.exceptions.ChunkedEncodingError,
)
_RETRYABLE_HTTP: set[int] = {408, 429, 500, 502, 503, 504}
_MAX_RETRIES: int = 4
_BACKOFF_BASE_SEC: float = 1.0


# ---------------------------------------------------------------------
# Supabase REST istemcisi
# ---------------------------------------------------------------------
class SupabaseClient:
    def __init__(self, url: str, service_key: str, timeout: int = 30) -> None:
        if not url or not service_key:
            raise ValueError(
                "SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY gereklidir."
            )
        self.rest_url = url.rstrip("/") + "/rest/v1"
        self.timeout = timeout
        self._service_key = service_key
        self._build_session()

    def _build_session(self) -> None:
        """Yeni requests.Session kur. Network hatasi sonrasi cagirilir."""
        self.session = requests.Session()
        self.session.headers.update(
            {
                "apikey": self._service_key,
                "Authorization": f"Bearer {self._service_key}",
                "Content-Type": "application/json",
                "Prefer": "return=representation",
            }
        )

    @classmethod
    def from_env(cls) -> "SupabaseClient":
        return cls(
            url=os.environ.get("SUPABASE_URL", ""),
            service_key=os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""),
        )

    def _request(
        self,
        method: str,
        path: str,
        *,
        extra_headers: dict[str, str] | None = None,
        **kwargs: Any,
    ) -> requests.Response:
        """HTTP istek; transient hatalara karsi retry + session refresh."""
        url = f"{self.rest_url}/{path}"
        last_err: BaseException | None = None
        for attempt in range(_MAX_RETRIES):
            try:
                headers = None
                if extra_headers:
                    headers = {**self.session.headers, **extra_headers}
                response = self.session.request(
                    method,
                    url,
                    headers=headers,
                    timeout=self.timeout,
                    **kwargs,
                )
                if response.status_code in _RETRYABLE_HTTP:
                    last_err = requests.HTTPError(
                        f"{method} {path} -> HTTP {response.status_code}",
                        response=response,
                    )
                else:
                    response.raise_for_status()
                    return response
            except _RETRYABLE_EXC as err:
                last_err = err
                # Bayat TCP: session'u at, yenisini kur.
                self._build_session()
            # Diger HTTPError'lar (4xx gibi) dogrudan yukari cikar.

            if attempt < _MAX_RETRIES - 1:
                sleep = (
                    _BACKOFF_BASE_SEC * (2 ** attempt)
                    + random.random() * 0.5
                )
                print(
                    f"[supabase] {method} {path} attempt "
                    f"{attempt + 1}/{_MAX_RETRIES} failed: "
                    f"{type(last_err).__name__}: {last_err}; "
                    f"retry in {sleep:.1f}s",
                    file=sys.stderr,
                )
                time.sleep(sleep)

        assert last_err is not None
        raise last_err

    def select(self, table: str, params: dict[str, str]) -> list[dict]:
        response = self._request("GET", table, params=params)
        return response.json()

    def insert(self, table: str, rows: list[dict]) -> list[dict]:
        if not rows:
            return []
        response = self._request("POST", table, json=rows)
        return response.json() or []

    def upsert(
        self,
        table: str,
        rows: list[dict],
        on_conflict: str,
    ) -> list[dict]:
        if not rows:
            return []
        response = self._request(
            "POST",
            table,
            json=rows,
            params={"on_conflict": on_conflict},
            extra_headers={
                "Prefer": "resolution=merge-duplicates,return=representation",
            },
        )
        return response.json() or []

    def update(
        self,
        table: str,
        match: dict[str, str],
        patch: dict,
    ) -> list[dict]:
        response = self._request(
            "PATCH",
            table,
            params={k: f"eq.{v}" for k, v in match.items()},
            json=patch,
        )
        return response.json() or []


# ---------------------------------------------------------------------
# Bulk insert writer
# ---------------------------------------------------------------------
# Performans notu — 2026-04-24 live run'da 5528 fiyat satiri tek tek
# POST edildigi icin sweep ~86dk surdu (RTT ~400ms ortalama × ~16k call).
# PostgREST tek POST govdesinde array kabul ediyor; insert_price /
# insert_campaign cagri sayisini 500'luk chunk yazarak ~5528'den ~12'ye
# dusurebiliriz. Beklenti: prices+campaigns uzerinde ~30dk net kazanc.
# (find_or_create_product hala satir basi calisir — onun bulk hali Step 5b.)
#
# Kullanim:
#     writer = BulkWriter(client, flush_size=500)
#     ...
#     insert_price(writer, ...)            # buffered
#     insert_campaign(writer, ...)         # buffered
#     ...
#     writer.flush_all()                   # finish_scrape_run'dan ONCE
#     finish_scrape_run(client, ...)       # client (raw) — buffer disi
#
# Onemli: BulkWriter SADECE INSERT'i bufferlar. SELECT/UPSERT/UPDATE
# pass-through degil; bunlar icin raw SupabaseClient kullan.
class BulkWriter:
    """Buffered drop-in for SupabaseClient.insert(table, rows)."""

    def __init__(
        self,
        client: SupabaseClient,
        *,
        flush_size: int = 500,
    ) -> None:
        if flush_size <= 0:
            raise ValueError("flush_size > 0 olmali.")
        self._client = client
        self._flush_size = flush_size
        self._buffers: dict[str, list[dict]] = {}
        self.batches_flushed: int = 0
        self.rows_flushed: int = 0

    def insert(self, table: str, rows: list[dict]) -> list[dict]:
        """Buffered insert. Caller donus degerine GUVENMEMELI;
        flush sonradan olabilir, bos liste donulur."""
        if not rows:
            return []
        buf = self._buffers.setdefault(table, [])
        buf.extend(rows)
        # Birikim flush_size'a ulastiysa hemen yaz (bellek + run_id delta
        # cikarsa erken hata gorulsun).
        while len(buf) >= self._flush_size:
            chunk = buf[: self._flush_size]
            del buf[: self._flush_size]
            self._flush_chunk(table, chunk)
        return []

    def _flush_chunk(self, table: str, chunk: list[dict]) -> None:
        if not chunk:
            return
        self._client.insert(table, chunk)
        self.batches_flushed += 1
        self.rows_flushed += len(chunk)

    def flush(self, table: str) -> None:
        """Bir tablonun bekleyen butun satirlarini yaz."""
        chunk = self._buffers.pop(table, [])
        self._flush_chunk(table, chunk)

    def flush_all(self) -> None:
        """Tum tablolarda bekleyenleri yaz. finish_scrape_run'dan ONCE cagir."""
        # Determinizm icin sirali flush.
        for table in sorted(self._buffers):
            self.flush(table)

    def __len__(self) -> int:
        """Bekleyen toplam satir sayisi (debug)."""
        return sum(len(rows) for rows in self._buffers.values())


# ---------------------------------------------------------------------
# Normalleştirme yardımcıları
# ---------------------------------------------------------------------
def slugify(value: str) -> str:
    text = unicodedata.normalize("NFKD", value or "")
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = text.replace("ı", "i").replace("İ", "i").lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


def normalize_search_text(value: str) -> str:
    return re.sub(r"\s+", " ", slugify(value).replace("-", " ")).strip()


PACKAGE_PATTERNS = [
    # kg: "500kg", "500 kg", "500 Kg" — ama "5KG" network olamaz, risk düşük
    (re.compile(r"(\d+(?:[.,]\d+)?)\s*(kg|kilogram)\b", re.I), "kg"),
    # gram: "gr"/"gram" her durumda; tek "g" SADECE küçük harf
    # (aksi halde "5G Cep Telefonu" → 5 gram false positive)
    (re.compile(r"(\d+(?:[.,]\d+)?)\s*(gr|gram)\b", re.I), "g"),
    (re.compile(r"(\d+(?:[.,]\d+)?)\s*g\b"), "g"),
    # litre: "lt"/"litre"/"L"/"l" — tek "L" network conflict'i yok, case-insensitive
    (re.compile(r"(\d+(?:[.,]\d+)?)\s*(lt|litre)\b", re.I), "L"),
    (re.compile(r"(\d+(?:[.,]\d+)?)\s*l\b", re.I), "L"),
    # mililitre
    (re.compile(r"(\d+(?:[.,]\d+)?)\s*(ml|mililitre)\b", re.I), "ml"),
    # çoklu paket
    (re.compile(r"(\d+)\s*(adet|li|lü|lu)\b", re.I), "adet"),
]


def extract_package(name: str) -> tuple[float | None, str | None]:
    for pattern, unit in PACKAGE_PATTERNS:
        match = pattern.search(name)
        if not match:
            continue
        try:
            size = float(match.group(1).replace(",", "."))
        except ValueError:
            continue
        return size, unit
    return None, None


# ---------------------------------------------------------------------
# Worker I/O tipleri
# ---------------------------------------------------------------------
@dataclass
class WorkerItem:
    """Parser'ların ürettiği tek gözlem. Tüm marketler için ortak shape."""

    market_id: str
    product_name: str
    brand: str | None = None
    discount_price: float | None = None
    regular_price: float | None = None
    currency: str = "TRY"
    valid_from: str | None = None       # ISO date 'YYYY-MM-DD'
    valid_until: str | None = None
    image_url: str | None = None
    source_url: str | None = None
    ocr_text: str | None = None
    confidence: float = 0.9
    raw: dict[str, Any] = field(default_factory=dict)

    def canonical_key(self) -> str:
        slug = slugify(f"{self.brand or ''} {self.product_name}")
        return slug[:200] or hashlib.sha1(
            self.product_name.encode()
        ).hexdigest()[:16]


@dataclass
class RunStats:
    products_added: int = 0
    products_matched: int = 0
    prices_added: int = 0
    campaigns_added: int = 0
    errors: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------
# Supabase upsert yardımcıları
# ---------------------------------------------------------------------
def find_or_create_product(
    client: SupabaseClient,
    item: WorkerItem,
    alias_source: str,
    stats: RunStats,
) -> str | None:
    alias = item.canonical_key()

    rows = client.select(
        "product_aliases",
        {
            "alias": f"eq.{alias}",
            "source": f"eq.{alias_source}",
            "select": "product_id",
        },
    )
    if rows:
        stats.products_matched += 1
        return rows[0]["product_id"]

    rows = client.select(
        "products",
        {
            "canonical_name": f"eq.{item.product_name}",
            "select": "id",
            "limit": "1",
        },
    )
    if rows:
        product_id = rows[0]["id"]
        stats.products_matched += 1
    else:
        size, unit = extract_package(item.product_name)
        created = client.insert(
            "products",
            [
                {
                    "canonical_name": item.product_name,
                    "brand": item.brand,
                    "package_size": size,
                    "package_unit": unit,
                    "search_text": normalize_search_text(item.product_name),
                    "image_url": item.image_url,
                }
            ],
        )
        if not created:
            stats.errors.append(f"product insert failed: {item.product_name}")
            return None
        product_id = created[0]["id"]
        stats.products_added += 1

    try:
        client.upsert(
            "product_aliases",
            [
                {
                    "product_id": product_id,
                    "alias": alias,
                    "source": alias_source,
                    "confidence": item.confidence,
                }
            ],
            on_conflict="alias,source",
        )
    except requests.HTTPError as error:
        stats.errors.append(f"alias upsert failed: {error}")

    return product_id


def insert_price(
    inserter: "SupabaseClient | BulkWriter",
    product_id: str | None,
    item: WorkerItem,
    run_id: int,
    source_label: str,
    stats: RunStats,
) -> None:
    """Tek fiyat satirini yaz. `inserter` SupabaseClient ise tek POST,
    BulkWriter ise buffered (flush_size'a ulasinca toplu POST)."""
    if item.discount_price is None:
        return
    payload = {
        "product_id": product_id,
        "market_id": item.market_id,
        "price": item.discount_price,
        "currency": item.currency,
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "source": source_label,
        "source_url": item.source_url,
        "raw_product_name": item.product_name,
        "raw_brand": item.brand,
        "raw_payload": item.raw,
        "is_on_sale": (
            item.regular_price is not None
            and item.regular_price > (item.discount_price or 0)
        ),
        "scrape_run_id": run_id,
    }
    try:
        inserter.insert("prices", [payload])
        stats.prices_added += 1
    except requests.HTTPError as error:
        stats.errors.append(f"price insert failed: {error}")


def insert_campaign(
    inserter: "SupabaseClient | BulkWriter",
    product_id: str | None,
    item: WorkerItem,
    stats: RunStats,
) -> None:
    """Tek kampanya satirini yaz. inserter parametresi insert_price ile ayni
    semantige sahip (raw client veya BulkWriter)."""
    if (
        not item.valid_from
        or not item.valid_until
        or item.discount_price is None
    ):
        return
    payload = {
        "market_id": item.market_id,
        "product_id": product_id,
        "raw_product_name": item.product_name,
        "brand": item.brand,
        "discount_price": item.discount_price,
        "regular_price": item.regular_price,
        "valid_from": item.valid_from,
        "valid_until": item.valid_until,
        "source_url": item.source_url,
        "brochure_image_url": item.image_url,
        "ocr_text": item.ocr_text,
        "confidence": item.confidence,
        "raw_payload": item.raw,
    }
    try:
        inserter.insert("campaigns", [payload])
        stats.campaigns_added += 1
    except requests.HTTPError as error:
        stats.errors.append(f"campaign insert failed: {error}")


def start_scrape_run(
    client: SupabaseClient,
    market_id: str,
    source_type: str,
    source_label: str,
) -> int:
    created = client.insert(
        "scrape_runs",
        [
            {
                "market_id": market_id,
                "source_type": source_type,
                "source_label": source_label,
                "status": "running",
                "worker_version": WORKER_VERSION,
            }
        ],
    )
    return int(created[0]["id"])


def finish_scrape_run(
    client: SupabaseClient,
    run_id: int,
    stats: RunStats,
    status: str,
) -> None:
    client.update(
        "scrape_runs",
        {"id": str(run_id)},
        {
            "finished_at": datetime.now(timezone.utc).isoformat(),
            "products_added": stats.products_added,
            "products_matched": stats.products_matched,
            "prices_added": stats.prices_added,
            "campaigns_added": stats.campaigns_added,
            "status": status,
            "error_message": (
                "; ".join(stats.errors[:5]) if stats.errors else None
            ),
        },
    )
