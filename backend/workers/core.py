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


_SIZE_UNIT_RE = re.compile(
    r"(\d+(?:[.,]\d+)?)\s*"
    r"(lt|litre|l|kilogram|kg|gram|gr|g|mililitre|ml)\b",
    re.IGNORECASE,
)


def _normalize_size_unit(match: "re.Match[str]") -> str:
    """Match'i base unit'e cevir.

    L  -> ml (size *= 1000)
    kg -> g  (size *= 1000)
    g  -> g
    ml -> ml

    Boylelikle '0.5 l' ve '500 ml' ayni 'search_text'e dusup dedupe olabilir.
    """
    try:
        num = float(match.group(1).replace(",", "."))
    except (TypeError, ValueError):
        return match.group(0)
    unit = match.group(2).lower()
    if unit in ("lt", "litre", "l"):
        return f"{round(num * 1000)}ml"
    if unit in ("kilogram", "kg"):
        return f"{round(num * 1000)}g"
    if unit in ("gram", "gr", "g"):
        return f"{round(num)}g"
    if unit in ("mililitre", "ml"):
        return f"{round(num)}ml"
    return match.group(0)


def normalize_search_text(value: str) -> str:
    """Aggressive normalize — Tier 2 dedupe icin search_text uretir.

    1. Lower + Turkce karakter -> ASCII
    2. Decimal: '0,5' -> '0.5'
    3. Size+unit -> base unit (L->ml, kg->g)
    4. Non-alphanumeric -> space
    5. Whitespace collapse + ardisik tekrar word dedupe ('5L 5L' -> '5000ml')

    Garantiler:
        normalize('Saka Su 0.5 L')  == normalize('Saka Su 500 ml')
        normalize('Eti 100 gr')     == normalize('Eti 100g')   == normalize('Eti 0.1 KG')
        normalize('Sut 1 Lt')       == normalize('Sut 1L')     == normalize('Sut 1000 ml')
    """
    text = (value or "").lower()
    # Turkish chars -> ASCII (slugify mantigi ama dot korunur ki decimal gitmesin)
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = text.replace("ı", "i")
    # Decimal: 0,5 -> 0.5
    text = re.sub(r"(\d),(\d)", r"\1.\2", text)
    # Size+unit -> base unit
    text = _SIZE_UNIT_RE.sub(_normalize_size_unit, text)
    # Non-alphanumeric -> space
    text = re.sub(r"[^a-z0-9]+", " ", text)
    # Whitespace collapse
    text = re.sub(r"\s+", " ", text).strip()
    # Ardisik tekrar tokenleri sil ('5000ml 5000ml' -> '5000ml')
    parts = text.split(" ")
    if len(parts) > 1:
        out = [parts[0]]
        for p in parts[1:]:
            if p != out[-1]:
                out.append(p)
        text = " ".join(out)
    return text


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
    # Tier 1 dedupe icin EAN-13 barkod. sok_direct + hakmar_express RSC'den
    # geliyor; marketfiyati genelde dondurmaz. None ise Tier 2 (brand+size+unit)
    # ya da Tier 3 (alias-source) yoluyla match dener.
    barcode: str | None = None
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
    """Item icin Supabase product_id bul/yarat.

    Match tier'lari (yukaridan asagi, ilk basari kazanir):
      0. (alias, source) ciftti — bu marketin daha once gordugu ayni urun
      1. barcode UNIQUE — markets ARASI kesin dedupe (Su 0.5L != Su 500ml farki)
      2. brand + search_text + package_size + package_unit — kanonik match
      3. canonical_name exact — eski davranis (legacy fallback)
      4. yeni urun INSERT
    Match basarili olursa alias kaydi UPSERT edilir (Tier 0 disindaki
    tier'lar icin yeni alias yazilir; ayni source icin ayri product yaratmaz).
    """
    alias = item.canonical_key()

    # Tier 0: bu market'in alias'i
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

    product_id: str | None = None

    # Tier 1: barcode UNIQUE
    if item.barcode:
        rows = client.select(
            "products",
            {
                "barcode": f"eq.{item.barcode}",
                "select": "id",
                "limit": "1",
            },
        )
        if rows:
            product_id = rows[0]["id"]
            stats.products_matched += 1

    # Tier 2: brand + search_text + package_size + package_unit
    if product_id is None and item.brand:
        normalized_search = normalize_search_text(item.product_name)
        size, unit = extract_package(item.product_name)
        if normalized_search:
            params: dict[str, str] = {
                "brand": f"eq.{item.brand}",
                "search_text": f"eq.{normalized_search}",
                "select": "id",
                "limit": "1",
            }
            if size is not None:
                params["package_size"] = f"eq.{size}"
            if unit:
                params["package_unit"] = f"eq.{unit}"
            rows = client.select("products", params)
            if rows:
                product_id = rows[0]["id"]
                stats.products_matched += 1

    # Tier 3: canonical_name exact (legacy)
    if product_id is None:
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

    # Tier 4: yeni product INSERT
    if product_id is None:
        size, unit = extract_package(item.product_name)
        payload: dict[str, Any] = {
            "canonical_name": item.product_name,
            "brand": item.brand,
            "package_size": size,
            "package_unit": unit,
            "search_text": normalize_search_text(item.product_name),
            "image_url": item.image_url,
        }
        if item.barcode:
            payload["barcode"] = item.barcode
        created = client.insert("products", [payload])
        if not created:
            stats.errors.append(f"product insert failed: {item.product_name}")
            return None
        product_id = created[0]["id"]
        stats.products_added += 1

    # Tier 1-3'te product bulunup ama o source icin alias'i yoksa, alias yaz
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


# ---------------------------------------------------------------------
# Bulk product/alias resolver (Step 5b)
# ---------------------------------------------------------------------
# Performans notu — find_or_create_product item basi 1-4 RTT yapiyordu
# (alias SELECT, products SELECT, INSERT, alias UPSERT). 5528 item × ~1.5
# RTT × 400ms ≈ 55dk. BulkProductResolver bu adimlarin her birini "batch
# halinde" calistirarak per-batch (50 item) 4 RTT'e indirir:
#
#   1. SELECT product_aliases WHERE alias=in.(...) AND source=eq.X
#   2. SELECT products       WHERE canonical_name=in.(...)   (sadece eksikler)
#   3. INSERT products       (canonical_name'i hala olmayan kalan)
#   4. UPSERT product_aliases (eksik alias'lari product_id'ye bagla)
#
# Beklenti: 5528 item / 50 = ~110 batch × 4 RTT = ~440 RTT (~3dk).
#
# Hata durumu — graceful fallback: batch operasyonlari herhangi bir
# noktada exception firlattigi durumda, resolver o batch'in items'larini
# tek tek find_or_create_product ile dener. Item kacirilmaz, sadece
# yavaslar.
def _postgrest_in_value(value: str) -> str:
    """PostgREST 'in.(...)' filter'i icin tek bir degeri quote+escape eder."""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def _build_in_filter(values: list[str]) -> str:
    """PostgREST in.(...) sag tarafini olustur. Caller value setini dedupe etmis olmali."""
    return f"in.({','.join(_postgrest_in_value(v) for v in values)})"


class BulkProductResolver:
    """Batch halinde alias→product_id resolve eder.

    Bir market icin tek instance. `alias_source` parser'in alias_source'u
    olmali (ornek: 'marketfiyati', 'a101', 'bim').

    Kullanim:
        resolver = BulkProductResolver(client, parser.alias_source, stats)
        for chunk in chunks_of_size(items, 50):
            mapping = resolver.resolve_batch(chunk)
            for idx, item in enumerate(chunk):
                pid = mapping.get(idx)
                insert_price(writer, pid, item, run_id, ..., stats)
                insert_campaign(writer, pid, item, stats)
    """

    def __init__(
        self,
        client: SupabaseClient,
        alias_source: str,
        stats: RunStats,
    ) -> None:
        self._client = client
        self._alias_source = alias_source
        self._stats = stats
        self.batches_resolved: int = 0
        self.fallback_items: int = 0

    def resolve_batch(self, items: list[WorkerItem]) -> dict[int, str | None]:
        """Batch'in her item'i icin index → product_id mapping'i dondur.

        None → resolve fail (item insert_price'a None product_id ile gidebilir;
        prices.product_id NULL allowed, campaigns degil — caller filtrelemeli).
        """
        if not items:
            return {}
        try:
            return self._resolve_batch_fast(items)
        except Exception as err:
            # Bulk path patladi — tek tek fallback. find_or_create_product
            # zaten try/except ile sarili degil, caller'in halletmesi lazim.
            self._stats.errors.append(
                f"bulk resolve fell back: {type(err).__name__}: {err}"
            )
            return self._resolve_batch_fallback(items)

    # ----- iç akış -----------------------------------------------------
    def _resolve_batch_fast(
        self, items: list[WorkerItem]
    ) -> dict[int, str | None]:
        # 1) Her item icin alias topla.
        aliases_by_idx: dict[int, str] = {
            idx: item.canonical_key() for idx, item in enumerate(items)
        }
        unique_aliases = sorted({a for a in aliases_by_idx.values() if a})
        alias_to_pid: dict[str, str] = {}

        if unique_aliases:
            rows = self._client.select(
                "product_aliases",
                {
                    "alias": _build_in_filter(unique_aliases),
                    "source": f"eq.{self._alias_source}",
                    "select": "alias,product_id",
                },
            )
            for r in rows:
                alias_to_pid[r["alias"]] = r["product_id"]

        # 2) Tier 1: Bulk barcode lookup. Markets ARASI kesin dedupe icin.
        #    Eksik alias'i olan item'larin barkodlarini topla, products
        #    tablosundan barcode=in.(...) ile match et.
        missing_idxs = [
            idx
            for idx, a in aliases_by_idx.items()
            if a and a not in alias_to_pid
        ]
        barcodes_by_idx: dict[int, str] = {
            idx: items[idx].barcode
            for idx in missing_idxs
            if items[idx].barcode
        }
        unique_barcodes = sorted(set(barcodes_by_idx.values()))
        barcode_to_pid: dict[str, str] = {}
        if unique_barcodes:
            rows = self._client.select(
                "products",
                {
                    "barcode": _build_in_filter(unique_barcodes),
                    "select": "id,barcode",
                },
            )
            for r in rows:
                bc = r.get("barcode")
                if bc:
                    barcode_to_pid[str(bc)] = r["id"]
            # Barcode hit'lerini alias mapping'e bagla
            for idx, bc in barcodes_by_idx.items():
                pid = barcode_to_pid.get(bc)
                if pid:
                    alias_to_pid[aliases_by_idx[idx]] = pid

        # 2b) Hala eksik kalanlar (barcode hit etmedi veya barcode yok):
        #     canonical_name lookup (Tier 3).
        missing_idxs = [
            idx
            for idx, a in aliases_by_idx.items()
            if a and a not in alias_to_pid
        ]
        names_by_idx: dict[int, str] = {
            idx: items[idx].product_name for idx in missing_idxs
        }
        unique_names = sorted({n for n in names_by_idx.values() if n})
        name_to_pid: dict[str, str] = {}

        if unique_names:
            rows = self._client.select(
                "products",
                {
                    "canonical_name": _build_in_filter(unique_names),
                    "select": "id,canonical_name",
                },
            )
            for r in rows:
                name_to_pid[r["canonical_name"]] = r["id"]

        # 3) Hala yoklari INSERT et. Barcode varsa payload'a ekle —
        #    UNIQUE constraint sayesinde duplicate barcode atilamaz, sonraki
        #    sweep'lerde Tier 1 lookup'la merge gerceklesir.
        names_to_create = [n for n in unique_names if n not in name_to_pid]
        if names_to_create:
            first_item_for_name: dict[str, WorkerItem] = {}
            for idx in missing_idxs:
                n = names_by_idx[idx]
                if n in names_to_create and n not in first_item_for_name:
                    first_item_for_name[n] = items[idx]

            payloads = []
            for name in names_to_create:
                it = first_item_for_name[name]
                size, unit = extract_package(name)
                payload = {
                    "canonical_name": name,
                    "brand": it.brand,
                    "package_size": size,
                    "package_unit": unit,
                    "search_text": normalize_search_text(name),
                    "image_url": it.image_url,
                }
                if it.barcode:
                    payload["barcode"] = it.barcode
                payloads.append(payload)
            created = self._client.insert("products", payloads)
            for row in created:
                name_to_pid[row["canonical_name"]] = row["id"]
            self._stats.products_added += len(created)

        # 4) Eksik (alias,source) ciftlerini product_id'ye bagla, bulk UPSERT.
        new_alias_rows: list[dict] = []
        seen_alias: set[tuple[str, str]] = set()
        for idx in missing_idxs:
            a = aliases_by_idx[idx]
            n = names_by_idx[idx]
            pid = name_to_pid.get(n)
            if pid is None:
                continue
            alias_to_pid[a] = pid
            key = (a, self._alias_source)
            if key in seen_alias:
                continue
            seen_alias.add(key)
            new_alias_rows.append(
                {
                    "product_id": pid,
                    "alias": a,
                    "source": self._alias_source,
                    "confidence": items[idx].confidence,
                }
            )

        if new_alias_rows:
            try:
                self._client.upsert(
                    "product_aliases",
                    new_alias_rows,
                    on_conflict="alias,source",
                )
            except requests.HTTPError as err:
                # Alias UPSERT patlasa bile alias_to_pid mapping zaten elimizde —
                # mevcut item'lar product_id'lerini alabilir; sadece alias kaydi
                # eksik (gelecek run aynisini cozer).
                self._stats.errors.append(f"bulk alias upsert: {err}")

        # 5) products_matched: alias path'i ile match olan item sayisi
        #    (zaten alias_to_pid'de olanlar — yani missing_idxs'te olmayanlar).
        matched_via_alias = len(items) - len(missing_idxs)
        self._stats.products_matched += matched_via_alias

        # 6) Result mapping
        self.batches_resolved += 1
        return {
            idx: alias_to_pid.get(a) for idx, a in aliases_by_idx.items()
        }

    def _resolve_batch_fallback(
        self, items: list[WorkerItem]
    ) -> dict[int, str | None]:
        """Batch operasyonu patladiginda tek tek find_or_create_product kullan."""
        result: dict[int, str | None] = {}
        for idx, item in enumerate(items):
            try:
                result[idx] = find_or_create_product(
                    self._client, item, self._alias_source, self._stats
                )
            except requests.HTTPError as err:
                self._stats.errors.append(
                    f"fallback resolve item {idx}: {err}"
                )
                result[idx] = None
            except Exception as err:  # pragma: no cover
                self._stats.errors.append(
                    f"fallback resolve item {idx}: "
                    f"{type(err).__name__}: {err}"
                )
                result[idx] = None
            self.fallback_items += 1
        return result


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
