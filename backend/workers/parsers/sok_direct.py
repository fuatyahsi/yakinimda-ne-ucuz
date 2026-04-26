"""SOK parser — canlı fetch (Next.js RSC payload decode), kategori-bazlı.

Neden bu parser?
    Marketfiyati.org.tr'nin SOK kapsami sistematik olarak zayif (~%0.2;
    21295 katalog urunlerinden sweep'imizde 43 dusuyor). Diger marketler
    icin marketfiyati ~%5 coverage veriyor — SOK icin 25 kat dusuk.
    Cozum: SOK'un kendi sitesinden (sokmarket.com.tr) dogrudan parse.

Kaynaklar:
    website  : https://www.sokmarket.com.tr
    URL formati :
        kategori sayfasi : https://www.sokmarket.com.tr/{slug}-c-{id}
        urun sayfasi     : https://www.sokmarket.com.tr/{slug}-p-{id}

Kategori kesfi:
    Resmi sitemap (/sitemap/market-category_1.xml ~934 URL) ESKIYMIS — 30
    URL ornekleminde sadece 5'i (~%17) 200 donuyor, geri kalan 404 (silinmis
    ya da yeniden adlandirilmis). Sitemap'a guvenmek HTTP israfi.

    Alternatif: ANA SAYFA NAVIGATION'i kullaniyoruz. www.sokmarket.com.tr/
    RSC payload'inda canli kategori menusu var (~120 unique `-c-NNN` path).
    Bunlar guncel ve genelde 200 donuyor. Recursive olarak bir kategori
    sayfasinda gorulen yeni `-c-NNN` linklerini de queue'ye ekleyerek BFS
    benzeri bir kesif yapiyoruz — yeni alt-kategoriler de yakalanir.

Strateji:
    SOK sitesi Next.js App Router. Veri sunucuda render edilip
    `self.__next_f.push([1, "..."])` chunk'lariyla stream ediliyor. Her
    chunk `[tag, "string"]` formatinda; json.loads ile decode edince
    UTF-8 + escape'leri dogru cozulur (manuel `unicode_escape` denemeleri
    multi-byte karakterleri "PEKI" -> "PEKÄ°" tarzi corrupt eder).

    KATEGORI SAYFASI yaklasimi (urun sayfasi yerine): tek bir kategori
    sayfasi ortalama 20-50 urunu ayni payload icinde tasiyor (her urun
    kendi `{"id":"...","prices":{...},"product":{...}}` JSON objesinde).
    Yani 1 fetch = 20-50 urun.

    Urun objesinin sekli:
        {
          "id": "8739.1.1.13412",
          "hotProductId": null,
          "sku": {"id": "8739.1", "breadCrumbs": [...], "privateLabel": ...},
          "product": {
            "id": "8739",
            "name": "Peki Mozaik Kek 200 g",
            "images": [{"host": "...", "path": "..."}, ...],
            "brand": {"name": "PEKİ", "code": "peki"},
            "path": "peki-mozaik-kek-200-g-p-8739"
          },
          "hasStock": true,
          "prices": {
            "discounted": {"value": 34, "text": "34,00", "currency": "TRY"},
            "original":   {"value": 34, "text": "34,00", "currency": "TRY"}
          },
          "promotions": [...],
          "serviceType": "MARKET"
        }

    Parser, her ürünü `{"id":"<digits.dots>","hotProductId":` regex'iyle
    bulup brace-balanced JSON parse ediyor.

Modlar (fetch_items(mode=...)):
    "discover" (default): Ana sayfadan kategori URL'lerini al (~120) ve
                          1-seviye recursive olarak alt-kategorileri de
                          takip et. Her kategori sayfasinda hem ürünleri
                          parse hem yeni `-c-NNN` linklerini queue'ye ekle.
    "homepage"          : Sadece ana sayfanin verdigi 120 path'i sweep et,
                          recursive degil. Daha hizli, daha az kapsamli.
"""

from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path
from typing import Iterable, Iterator

from .base import BaseParser

_THIS = Path(__file__).resolve()
if str(_THIS.parent.parent) not in sys.path:
    sys.path.insert(0, str(_THIS.parent.parent))

from core import WorkerItem  # noqa: E402

try:
    import requests  # noqa: E402
except ImportError as error:  # pragma: no cover
    raise SystemExit("`pip install requests` gerekli.") from error


_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
)

# self.__next_f.push([ 1, "....string literal...." ])
# group(1) tum [tag, "string"] array'i — json.loads UTF-8 + escape'leri tek
# pas'ta dogru handle eder; manuel `unicode_escape` denemesi multi-byte UTF-8
# karakterlerini Latin-1 yorumladigi icin "PEKÄ°" tipi corruption uretir.
_CHUNK_RE = re.compile(
    r"self\.__next_f\.push\((\[\s*\d+\s*,\s*\".+?\"\s*\])\)",
    re.DOTALL,
)

# Ürün objesinin top-level başlangıcı: {"id":"<dotted-id>","hotProductId":
_PRODUCT_START_RE = re.compile(
    r'\{"id":"[\d.]+","hotProductId":(?:null|"[^"]*")'
)

# Kategori URL pattern'i — payload icinde "path":"slug-c-NNN" geciyor.
# Sadece valid kategori path'lerini (-c-) yakalar; urun path'leri (-p-) skip.
_CATEGORY_PATH_RE = re.compile(r'"path":"([\w\-]+-c-\d+)"')

_BASE_URL = "https://www.sokmarket.com.tr"

# BFS recursive crawl icin max alt seviye sayisi.
# Ana sayfa = depth 0; ana sayfanin kategorilerinde gorulen alt-kategoriler
# = depth 1; vb. Pratik kapsamda 2 seviye yeter.
_MAX_DISCOVER_DEPTH = 2

# Politeness delay (saniye) — kategori sayfaları arası.
_CATEGORY_DELAY_SEC = 1.0


class SokDirectParser(BaseParser):
    market_id = "sok"
    alias_source = "sok"
    source_label = "sok_direct"
    source_type = "catalog"
    status = "implemented"
    discovery_notes = (
        "sokmarket.com.tr resmi sitesinden Next.js RSC decode. "
        "market-category sitemap'i (~934 URL) ile kategori sayfalari "
        "tek tek fetch edilir; her sayfada 20-50 urun bulunur."
    )

    website = _BASE_URL
    listing_url = _BASE_URL

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def fetch_items(self, **kwargs) -> Iterable[WorkerItem]:
        mode = (kwargs.get("mode") or "discover").lower()
        timeout = int(kwargs.get("timeout") or 30)
        max_urls = kwargs.get("max_urls")
        delay = float(kwargs.get("delay") or _CATEGORY_DELAY_SEC)
        max_depth = int(
            kwargs.get("max_depth")
            if kwargs.get("max_depth") is not None
            else _MAX_DISCOVER_DEPTH
        )

        if mode == "discover":
            yield from self._iter_discover(
                timeout=timeout,
                max_urls=max_urls,
                delay=delay,
                max_depth=max_depth,
            )
            return
        if mode == "homepage":
            # Sadece ana sayfanin direkt linklerini sweep et (recursive degil).
            yield from self._iter_discover(
                timeout=timeout,
                max_urls=max_urls,
                delay=delay,
                max_depth=0,  # 0 → sadece seed URL'leri, expand yok
            )
            return
        raise ValueError(
            f"Unknown SOK fetch mode={mode!r}. Desteklenen: discover, homepage."
        )

    # ------------------------------------------------------------------
    # Fixture: ham HTML verilirse decode et; aksi halde JSON.
    # ------------------------------------------------------------------
    def read_fixture(self, path: str | Path) -> Iterable[WorkerItem]:
        raw = Path(path).read_text(encoding="utf-8")
        if raw.lstrip().startswith("<"):
            payload = self._collect_rsc_payload(raw)
            for product in self._iter_products(payload):
                item = self._product_to_item(product, source_url=None)
                if item is not None:
                    yield item
        else:
            yield from super().read_fixture(path)

    # ------------------------------------------------------------------
    # Mode implementations
    # ------------------------------------------------------------------
    def _iter_discover(
        self,
        *,
        timeout: int,
        max_urls,
        delay: float,
        max_depth: int,
    ) -> Iterator[WorkerItem]:
        """BFS kategori kesfi: ana sayfadan baslar, her sayfada gorulen
        yeni `-c-NNN` linklerini queue'ye ekler. max_depth=0 ise sadece
        ana sayfanin direkt linkleri sweep edilir (expand yok).
        """
        seen_product_ids: set[str] = set()
        seen_urls: set[str] = set()

        # 1. Ana sayfayi cek, kategori path'lerini cikar.
        try:
            home_html = self._fetch_html(_BASE_URL + "/", timeout=timeout)
        except Exception as err:
            print(f"[sok.discover] homepage FETCH FAIL: {err}")
            return
        home_payload = self._collect_rsc_payload(home_html)
        seed_paths = sorted(set(_CATEGORY_PATH_RE.findall(home_payload)))
        print(
            f"[sok.discover] homepage seed: {len(seed_paths)} kategori path"
        )

        # depth=0 olan seed'ler — BFS queue'ya tuple (url, depth) olarak gir.
        from collections import deque
        queue: deque[tuple[str, int]] = deque()
        for path in seed_paths:
            url = f"{_BASE_URL}/{path}"
            if url not in seen_urls:
                seen_urls.add(url)
                queue.append((url, 0))

        processed = 0
        while queue:
            if max_urls is not None and processed >= int(max_urls):
                break
            url, depth = queue.popleft()
            processed += 1
            try:
                html = self._fetch_html(url, timeout=timeout)
            except Exception as err:
                # 404 olabilir (eski kategori) — sessizce skip
                msg = str(err)
                if "404" not in msg:
                    print(
                        f"[sok.discover] ({processed}) FAIL {url}: {err}"
                    )
                continue
            payload = self._collect_rsc_payload(html)
            yielded = 0
            new_unique = 0
            for product in self._iter_products(payload):
                pid = self._product_unique_key(product)
                if pid is None or pid in seen_product_ids:
                    continue
                seen_product_ids.add(pid)
                new_unique += 1
                item = self._product_to_item(product, source_url=url)
                if item is not None:
                    yielded += 1
                    yield item

            # Discovery: bu sayfada gorulen yeni kategori path'lerini queue'ye
            # ekle (recursive crawl). Sadece depth < max_depth ise.
            new_links = 0
            if depth < max_depth:
                for path in _CATEGORY_PATH_RE.findall(payload):
                    next_url = f"{_BASE_URL}/{path}"
                    if next_url not in seen_urls:
                        seen_urls.add(next_url)
                        queue.append((next_url, depth + 1))
                        new_links += 1

            print(
                f"[sok.discover] ({processed}) d={depth} {url} "
                f"new_unique={new_unique} yielded={yielded} "
                f"new_links={new_links} queue={len(queue)}"
            )
            if delay and queue:
                time.sleep(delay)

    # ------------------------------------------------------------------
    # HTTP helpers
    # ------------------------------------------------------------------
    @staticmethod
    def _http_headers(*, accept_xml: bool = False) -> dict[str, str]:
        accept = (
            "application/xml,text/xml;q=0.9,*/*;q=0.8"
            if accept_xml
            else "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        )
        return {
            "User-Agent": _UA,
            "Accept-Language": "tr,en-US;q=0.9,en;q=0.8",
            "Accept": accept,
            "Referer": _BASE_URL + "/",
        }

    def _fetch_html(self, url: str, timeout: int = 30) -> str:
        response = requests.get(
            url, headers=self._http_headers(), timeout=timeout
        )
        response.raise_for_status()
        return response.text

    def _fetch_xml(self, url: str, timeout: int = 30) -> str:
        response = requests.get(
            url, headers=self._http_headers(accept_xml=True), timeout=timeout
        )
        response.raise_for_status()
        return response.text

    # ------------------------------------------------------------------
    # RSC payload extraction
    # ------------------------------------------------------------------
    @staticmethod
    def _collect_rsc_payload(html: str) -> str:
        """Tum __next_f.push chunk'larinin string degerlerini birlestir.

        Her chunk `[tag, "string"]` formatinda. json.loads tum array'i
        Python list'e cevirir; arr[1] zaten escape-decoded ve UTF-8'de
        dogru string.
        """
        pieces: list[str] = []
        for match in _CHUNK_RE.finditer(html):
            try:
                arr = json.loads(match.group(1))
            except json.JSONDecodeError:
                continue
            if (
                isinstance(arr, list)
                and len(arr) >= 2
                and isinstance(arr[1], str)
            ):
                pieces.append(arr[1])
        return "".join(pieces)

    @classmethod
    def _iter_products(cls, payload: str) -> Iterable[dict]:
        """Payload icinde gecen tum ürün JSON objelerini cikar.

        Strateji: `{"id":"<digits>","hotProductId":` regex'iyle ürün
        baslangiclari bulunur, oradan brace-balanced parse ile JSON.loads
        edilir. `"prices"` ve `"product"` key'lerini iceren dict ürün sayilir.
        """
        for m in _PRODUCT_START_RE.finditer(payload):
            start = m.start()
            obj_text = cls._extract_balanced_object(payload, start)
            if not obj_text:
                continue
            try:
                obj = json.loads(obj_text)
            except json.JSONDecodeError:
                continue
            if (
                isinstance(obj, dict)
                and "prices" in obj
                and "product" in obj
                and isinstance(obj.get("product"), dict)
            ):
                yield obj

    @staticmethod
    def _extract_balanced_object(text: str, start: int) -> str | None:
        """text[start] == '{' kabulu ile brace-balanced object'i cikar.

        String literal'lerin icindeki '{' '}' karakterleri sayilmaz.
        Hatali yapida None doner.
        """
        if start >= len(text) or text[start] != "{":
            return None
        depth = 0
        in_str = False
        escape = False
        k = start
        while k < len(text):
            ch = text[k]
            if in_str:
                if escape:
                    escape = False
                elif ch == "\\":
                    escape = True
                elif ch == '"':
                    in_str = False
            elif ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return text[start: k + 1]
            k += 1
        return None

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    @staticmethod
    def _product_unique_key(product: dict) -> str | None:
        """Sweep boyunca dedupe icin kullanilan stable urun anahtari.

        Variant-level id ('8739.1.1.13412') yerine product-level
        'product.id' ('8739') kullanilir — ayni urunun farkli paket/varyant
        gosterimleri tek satir olarak yazilsin.
        """
        prod = product.get("product") or {}
        pid = prod.get("id")
        if pid is None:
            return None
        return str(pid)

    # ------------------------------------------------------------------
    # Product -> WorkerItem
    # ------------------------------------------------------------------
    def _product_to_item(
        self,
        product: dict,
        *,
        source_url: str | None,
    ) -> WorkerItem | None:
        prod = product.get("product") or {}
        name = (prod.get("name") or "").strip()
        if not name:
            return None

        prices = product.get("prices") or {}
        discounted_price = _price_value(prices.get("discounted"))
        original_price = _price_value(prices.get("original"))

        # discount_price = guncel fiyat (ne odersin); regular_price = liste
        # fiyati. Aksi halde core.insert_price atlar (None yazmiyor).
        current_price = (
            discounted_price if discounted_price is not None else original_price
        )
        if current_price is None:
            return None
        regular_price = (
            original_price if original_price is not None else current_price
        )

        brand_obj = prod.get("brand") or {}
        brand = (brand_obj.get("name") or "").strip() or None

        image_url: str | None = None
        images = prod.get("images") or []
        if isinstance(images, list) and images:
            first = images[0]
            if isinstance(first, dict):
                host = (first.get("host") or "").rstrip("/")
                path = (first.get("path") or "").lstrip("/")
                if host and path:
                    image_url = f"{host}/{path}"

        # Kanonik urun URL'i: product.path -> /{path}
        own_path = (prod.get("path") or "").strip()
        if own_path:
            final_source_url = f"{_BASE_URL}/{own_path.lstrip('/')}"
        else:
            final_source_url = source_url or _BASE_URL

        # Stok yoksa item'i yine yazariz (fiyat halen anlamli) ama not olarak
        # raw'a girer; gerekirse downstream filtrelenebilir.
        return WorkerItem(
            market_id=self.market_id,
            product_name=name,
            brand=brand,
            discount_price=current_price,
            regular_price=regular_price,
            currency="TRY",
            valid_from=None,
            valid_until=None,
            image_url=image_url,
            source_url=final_source_url,
            ocr_text=None,
            confidence=0.95,  # resmi kaynak, fiyat dogrudan API'den
            raw=product,
        )

    # ------------------------------------------------------------------
    # BaseParser sozlesmesi — fixture okumada kullanilabilir
    # ------------------------------------------------------------------
    def _row_to_item(self, row: dict) -> WorkerItem:
        # Klasik duz fixture (productName/discountPrice/...)
        return WorkerItem(
            market_id=self.market_id,
            product_name=(
                row.get("productName") or row.get("name") or ""
            ).strip(),
            brand=(row.get("brand") or "").strip() or None,
            discount_price=_as_float(
                row.get("discountPrice") or row.get("price")
            ),
            regular_price=_as_float(
                row.get("regularPrice") or row.get("price")
            ),
            currency=row.get("currency") or "TRY",
            valid_from=row.get("validFrom"),
            valid_until=row.get("validUntil"),
            image_url=row.get("imageUrl"),
            source_url=row.get("sourceUrl") or self.listing_url,
            ocr_text=row.get("ocrText"),
            confidence=float(row.get("confidence") or 0.85),
            raw=row,
        )


# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------
def _as_float(value) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _price_value(price_obj) -> float | None:
    """SOK fiyat objesi: {"value": 34, "text": "34,00", ...} → 34.0."""
    if not isinstance(price_obj, dict):
        return None
    v = price_obj.get("value")
    if v is None:
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None
