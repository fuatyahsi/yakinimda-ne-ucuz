"""Shared marketfiyati.org.tr client.

marketfiyati.org.tr TUBITAK destekli, halka acik bir Turk zincir market fiyat
karsilastirma servisi. 6 buyuk zinciri kapsiyor:
    a101, bim, carrefour, migros, sok, tarim_kredi

HAKMAR kapsamda DEGIL. Onu ayri bir kaynakla halletmemiz gerekiyor.

Upstream API sozlesmesi (yibudak/marketfiyati_mcp kaynak kodu analiziyle
teyit edildi, 2026-04):
    GET  /api/v1/info/categories
    POST /api/v2/nearest
         body = {latitude, longitude, distance}
    POST /api/v2/search
         body = {keywords, pages, size, latitude?, longitude?, distance?,
                 depots?, menuCategory?}

SearchResponse:
    {
      numberOfFound: int,
      searchResultType: int,
      content: [Product],
      facetMap: { main_category[], sub_category[], brand[], market_names[],
                  refined_quantity_unit[], refined_volume_weight[] }
    }

Product:
    {
      id, title, brand, imageUrl, refinedQuantityUnit?, refinedVolumeOrWeight?,
      categories: [str],
      productDepotInfoList: [
        {
          depotId, depotName, price, unitPrice, marketAdi,
          percentage, longitude, latitude, indexTime,
          (opsiyonel: unitPriceValue, discount, discountRatio, promotionText)
        }
      ]
    }

Enumerasyon stratejisi:
    1) /api/v1/info/categories cagir → 7 main, 66 subcategory.
    2) Her subcategory adini 'keywords' olarak search'e ver.
       Alternatif: fallback olarak main category adini da tara.
    3) size=100 ile paginate; pages 0..N kadar, numberOfFound'u tuketene kadar.
    4) Product.id ile dedupe.
    5) productDepotInfoList'i marketAdi ile filtreleyip min-price depot sec.

Rate limit:
    Servis 4-6 ardisik istek sonrasi 418 I'm a Teapot donebiliyor. Exponential
    backoff + istekler arasi sabit gecikme (DEFAULT_DELAY_SEC).

NOT: marketAdi degerleri (bizim registry ID'lerinden farkli olabilir):
    registry 'a101'        -> marketAdi 'a101'
    registry 'bim'         -> marketAdi 'bim'
    registry 'migros'      -> marketAdi 'migros'
    registry 'sok'         -> marketAdi 'sok'
    registry 'carrefoursa' -> marketAdi 'carrefour'        (!)
    registry 'tarim-kredi' -> marketAdi 'tarim_kredi'      (!)
"""

from __future__ import annotations

import json
import random
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Iterable, Iterator

BASE_URL = "https://api.marketfiyati.org.tr"

DEFAULT_DELAY_SEC = 1.5           # istekler arasi politeness gecikmesi
DEFAULT_SIZE = 100                # sayfa basi max urun (API limit: 100)
DEFAULT_TIMEOUT = 30
MAX_RETRIES = 6                   # 418 / 5xx icin toplam deneme
BACKOFF_BASE_SEC = 4.0            # 4, 8, 16, 32, 64, 120

_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
)


# Registry ID -> marketfiyati marketAdi
REGISTRY_TO_MARKETFIYATI: dict[str, str] = {
    "a101": "a101",
    "bim": "bim",
    "migros": "migros",
    "sok": "sok",
    "carrefoursa": "carrefour",
    "tarim-kredi": "tarim_kredi",
    "tarim_kredi": "tarim_kredi",
}


@dataclass
class Category:
    name: str
    subcategories: list[str]


@dataclass
class SelectedPrice:
    """Bir urun icin tek bir depot'tan secilmis fiyat (genelde min).

    Yalnizca code path'te ihtiyac olan 3 alani tutar; geri kalan ham depot
    payload'i `raw` icinde kalir (debug + future-proof).
    """
    price: float
    percentage: float
    raw: dict


class MarketFiyatiError(RuntimeError):
    pass


class MarketFiyatiClient:
    """Senkron HTTP client — stdlib urllib ustunde.

    requests paketini kullanmiyoruz ki bu modul minimal bagimlilikla da kossun.
    """

    def __init__(
        self,
        *,
        base_url: str = BASE_URL,
        delay_sec: float = DEFAULT_DELAY_SEC,
        timeout: int = DEFAULT_TIMEOUT,
        verbose: bool = True,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.delay_sec = delay_sec
        self.timeout = timeout
        self.verbose = verbose
        self._last_request_at: float = 0.0

    # ------------------------------------------------------------------
    # HTTP primitives
    # ------------------------------------------------------------------
    def _sleep_between_requests(self) -> None:
        if self.delay_sec <= 0:
            return
        now = time.monotonic()
        elapsed = now - self._last_request_at
        wait = self.delay_sec - elapsed
        if wait > 0:
            time.sleep(wait)

    def _request(
        self,
        method: str,
        path: str,
        *,
        json_body: dict | None = None,
    ) -> dict | list:
        url = self.base_url + path
        headers = {
            "User-Agent": _UA,
            "Accept": "application/json",
            "Accept-Language": "tr,en-US;q=0.9,en;q=0.8",
            "Origin": "https://marketfiyati.org.tr",
            "Referer": "https://marketfiyati.org.tr/",
        }
        data = None
        if json_body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(json_body).encode("utf-8")

        last_err: Exception | None = None
        for attempt in range(MAX_RETRIES):
            self._sleep_between_requests()
            req = urllib.request.Request(url, data=data, method=method, headers=headers)
            try:
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    self._last_request_at = time.monotonic()
                    payload = resp.read()
                    try:
                        return json.loads(payload.decode("utf-8"))
                    except json.JSONDecodeError as err:
                        raise MarketFiyatiError(
                            f"JSON decode error on {path}: {err}"
                        ) from err
            except urllib.error.HTTPError as err:
                self._last_request_at = time.monotonic()
                status = err.code
                # 418 = aggressive rate limit; 5xx = transient server
                if status in (418, 429, 500, 502, 503, 504):
                    wait = BACKOFF_BASE_SEC * (2 ** attempt) + random.random()
                    if self.verbose:
                        print(
                            f"[mf] {method} {path} -> {status}, "
                            f"retry {attempt+1}/{MAX_RETRIES} after {wait:.1f}s"
                        )
                    time.sleep(wait)
                    last_err = err
                    continue
                # other error — raise body for diagnosis
                body = err.read()[:400].decode("utf-8", errors="replace")
                raise MarketFiyatiError(
                    f"HTTP {status} on {method} {path}: {body}"
                ) from err
            except urllib.error.URLError as err:
                self._last_request_at = time.monotonic()
                wait = BACKOFF_BASE_SEC * (2 ** attempt) + random.random()
                if self.verbose:
                    print(
                        f"[mf] {method} {path} URLError={err.reason!r}, "
                        f"retry {attempt+1}/{MAX_RETRIES} after {wait:.1f}s"
                    )
                time.sleep(wait)
                last_err = err
                continue

        raise MarketFiyatiError(
            f"Max retries exhausted on {method} {path}: {last_err}"
        )

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def get_categories(self) -> list[Category]:
        data = self._request("GET", "/api/v1/info/categories")
        if not isinstance(data, dict):
            raise MarketFiyatiError(f"Unexpected categories shape: {type(data)}")
        content = data.get("content") or []
        out: list[Category] = []
        for c in content:
            name = (c.get("name") or "").strip()
            subs_raw = c.get("subcategories") or []
            subs = [s.strip() for s in subs_raw if isinstance(s, str) and s.strip()]
            if name:
                out.append(Category(name=name, subcategories=subs))
        return out

    def search(
        self,
        keywords: str,
        *,
        pages: int = 0,
        size: int = DEFAULT_SIZE,
        latitude: float | None = None,
        longitude: float | None = None,
        distance: int | None = None,
        depots: list[str] | None = None,
    ) -> dict:
        body: dict = {"keywords": keywords, "pages": pages, "size": size}
        if latitude is not None and longitude is not None:
            body["latitude"] = latitude
            body["longitude"] = longitude
            body["distance"] = distance or 1
        if depots:
            body["depots"] = depots
        data = self._request("POST", "/api/v2/search", json_body=body)
        if not isinstance(data, dict):
            raise MarketFiyatiError(f"Unexpected search shape: {type(data)}")
        return data

    def iter_products_for_keyword(
        self,
        keyword: str,
        *,
        size: int = DEFAULT_SIZE,
        max_pages: int | None = None,
    ) -> Iterator[dict]:
        """Bir keyword icin butun sayfalari dolan, her urunu yield et."""
        pages = 0
        total = None
        yielded = 0
        while True:
            data = self.search(keyword, pages=pages, size=size)
            total = data.get("numberOfFound", 0)
            content = data.get("content") or []
            if not content:
                break
            for p in content:
                yield p
                yielded += 1
            pages += 1
            if max_pages is not None and pages >= max_pages:
                break
            # numberOfFound — marketfiyati bazen ayni content'i sonsuza tekrar
            # eder; guvenlik icin: yielded >= total oldugunda dur.
            if total is not None and yielded >= total:
                break
            # ek guvenlik: cok yuksek sayfa sayisina girme
            if pages > 200:
                break

    def iter_all_products(
        self,
        *,
        keywords: Iterable[str] | None = None,
        size: int = DEFAULT_SIZE,
        max_pages_per_keyword: int | None = None,
        on_keyword_done=None,
    ) -> Iterator[dict]:
        """Butun subcategories uzerinde dolan, duplike urunleri dedup et.

        keywords None ise /api/v1/info/categories'den elde edilen tum
        subcategory isimleriyle arama yapilir.
        """
        if keywords is None:
            cats = self.get_categories()
            kws: list[str] = []
            for c in cats:
                # Subcategory spesifik aramalari; her zaman main + tum subs.
                # Main category adi daha genel eslesme icin de islevsel.
                kws.append(c.name)
                for s in c.subcategories:
                    kws.append(s)
        else:
            kws = list(keywords)

        seen_ids: set[str] = set()
        for idx, kw in enumerate(kws, start=1):
            kw_yielded = 0
            try:
                for product in self.iter_products_for_keyword(
                    kw, size=size, max_pages=max_pages_per_keyword
                ):
                    pid = str(product.get("id") or "")
                    if not pid or pid in seen_ids:
                        continue
                    seen_ids.add(pid)
                    kw_yielded += 1
                    yield product
            except MarketFiyatiError as err:
                if self.verbose:
                    print(f"[mf] keyword {kw!r} FAILED: {err}")
            if self.verbose:
                print(
                    f"[mf] ({idx}/{len(kws)}) keyword={kw!r} "
                    f"new={kw_yielded} cumulative={len(seen_ids)}"
                )
            if on_keyword_done is not None:
                on_keyword_done(kw, kw_yielded, len(seen_ids))


# ---------------------------------------------------------------------
# Utility: select best depot entry for a given marketAdi
# ---------------------------------------------------------------------
def select_price_for_market(
    product: dict,
    market_adi: str,
    *,
    strategy: str = "min",
) -> SelectedPrice | None:
    """Bir urun icin ilgili marketAdi'ye ait depot girdilerinden birini sec.

    strategy:
      'min'   : en dusuk fiyatli depot (tipik kullanim — kullaniciya en iyi
                fiyati gostermek istiyoruz)
      'first' : ilk rastlanan
    """
    depots = product.get("productDepotInfoList") or []
    candidates = [d for d in depots if (d.get("marketAdi") or "").lower() == market_adi]
    if not candidates:
        return None

    if strategy == "min":
        def _price(d: dict) -> float:
            try:
                return float(d.get("price"))
            except (TypeError, ValueError):
                return float("inf")
        chosen = min(candidates, key=_price)
    else:
        chosen = candidates[0]

    try:
        price = float(chosen.get("price"))
    except (TypeError, ValueError):
        return None

    try:
        pct = float(chosen.get("percentage") or 0.0)
    except (TypeError, ValueError):
        pct = 0.0

    return SelectedPrice(
        price=price,
        percentage=pct,
        raw=chosen,
    )


def product_url(product_id: str) -> str:
    """marketfiyati.org.tr urun detay URL'i — best effort slug yok."""
    return f"https://marketfiyati.org.tr/product?id={product_id}"
