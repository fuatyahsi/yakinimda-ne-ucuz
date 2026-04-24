"""A101 parser — canlı fetch (Next.js RSC payload decode).

Kaynaklar:
    website          : https://www.a101.com.tr
    campaign_url     : https://www.a101.com.tr/aldin-aldin/
    catalog_sitemaps :
        - https://www.a101.com.tr/sitemaps/categories-kapida.xml  (~159 URL)
          Kapıya teslim edilebilen dayanıklı ürünler (ambalajlı gıda,
          atıştırmalık, temizlik, non-food…). Taze meyve/sebze YOK.
        - https://www.a101.com.tr/sitemaps/categories-ecom.xml    (~385 URL)
          Tam online mağaza. Taze meyve/sebze, süt/peynir, dondurulmuş
          vb. kapida'da olmayan kategoriler buradan gelir.
        Iki sitemap URL-level dedupe ile birlestirilir; ayni urun iki
        sitemap'te de geciyor olabilir, _iter_products'un seen_ids
        set'i product-level dedupe'u saglar.

Strateji:
    A101 sitesi Next.js App Router; ürün verisi sunucuda render edilip
    `self.__next_f.push([1, "..."])` chunk'lariyla stream ediliyor. Her
    chunk'in ikinci elemani bir JS string literal'i — json.loads ile
    unescape edilince okunabilir RSC payload'ina donusuyor.

    Payload icinde `"products":[{...}, ...]` array'ini bulup brace-balanced
    ayrıştırıyoruz. Her ürün su alanlari tasiyor:
      - id, baseId, channel, inStock
      - images[0].url
      - price.normal / price.normalStr / price.discounted / price.discountedStr
        (normal ve discounted integer kurus — 8900 = 89.00 TL)
      - attributes.name, attributes.url
      - promotions[] (isim, kod, badge)

Modlar (fetch_items(mode=...)):
    "campaign" (default) : Sadece /aldin-aldin/ haftalik kampanyasi (~40 urun)
    "catalog"            : Kapida + ecom sitemap'i (toplam ~544 URL,
                            URL-level dedupe sonrasi genelde ~500) — A101'in
                            tum online urun uzayini dokuyoruz
    "all"                : campaign + catalog, sirayla, cross-page dedupe ile
"""

from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path
from typing import Iterable, Iterator
from xml.etree import ElementTree as ET

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
_CHUNK_RE = re.compile(
    r"self\.__next_f\.push\((\[\s*\d+\s*,\s*\".+?\"\s*\])\)",
    re.DOTALL,
)

_CAMPAIGN_URL = "https://www.a101.com.tr/aldin-aldin/"
# Kapida = kapiya teslim dayanikli katalog (~159 URL).
# Ecom    = tam online magaza, taze meyve/sebze dahil (~385 URL).
# Ikisini birlikte tarayarak A101'in satistaki urun uzayini kapsiyoruz.
_CATALOG_SITEMAP_URLS: tuple[str, ...] = (
    "https://www.a101.com.tr/sitemaps/categories-kapida.xml",
    "https://www.a101.com.tr/sitemaps/categories-ecom.xml",
)

# Politeness delay between catalog fetches (saniye).
_CATALOG_DELAY_SEC = 0.8


class A101Parser(BaseParser):
    market_id = "a101"
    alias_source = "a101"
    source_label = "a101_official"
    source_type = "brochure"
    status = "implemented"
    discovery_notes = (
        "campaign mode: aldin-aldin kampanyasi. "
        "catalog mode: /kapida/* sitemap'i (~159 URL) uzerinden tum grocery "
        "katalogunu RSC decode ile dokuyoruz."
    )

    website = "https://www.a101.com.tr"
    listing_url = _CAMPAIGN_URL  # default; campaign mode icin

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def fetch_items(self, **kwargs) -> Iterable[WorkerItem]:
        mode = (kwargs.get("mode") or "campaign").lower()
        timeout = int(kwargs.get("timeout") or 30)
        max_urls = kwargs.get("max_urls")  # opsiyonel — test icin
        delay = float(kwargs.get("delay") or _CATALOG_DELAY_SEC)

        if mode == "campaign":
            yield from self._iter_campaign(timeout=timeout)
            return
        if mode == "catalog":
            yield from self._iter_catalog(
                timeout=timeout, max_urls=max_urls, delay=delay
            )
            return
        if mode == "all":
            seen_cross: set[str] = set()
            yield from self._iter_campaign(timeout=timeout, seen_ids=seen_cross)
            yield from self._iter_catalog(
                timeout=timeout,
                max_urls=max_urls,
                delay=delay,
                seen_ids=seen_cross,
            )
            return
        raise ValueError(
            f"Unknown A101 fetch mode={mode!r}. Desteklenen: campaign, catalog, all."
        )

    # ------------------------------------------------------------------
    # Fixture: üst sınıfın default json-list reader'ı yerine kendi formatımız.
    # ------------------------------------------------------------------
    def read_fixture(self, path: str | Path) -> Iterable[WorkerItem]:
        raw = Path(path).read_text(encoding="utf-8")
        # Fixture = ham HTML ise onu da decode et; degilse default reader.
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
    def _iter_campaign(
        self,
        *,
        timeout: int,
        seen_ids: set[str] | None = None,
    ) -> Iterator[WorkerItem]:
        html = self._fetch_html(_CAMPAIGN_URL, timeout=timeout)
        payload = self._collect_rsc_payload(html)
        for product in self._iter_products(payload, seen_ids=seen_ids):
            item = self._product_to_item(product, source_url=_CAMPAIGN_URL)
            if item is not None:
                yield item

    def _iter_catalog(
        self,
        *,
        timeout: int,
        max_urls=None,
        delay: float = _CATALOG_DELAY_SEC,
        seen_ids: set[str] | None = None,
    ) -> Iterator[WorkerItem]:
        if seen_ids is None:
            seen_ids = set()

        urls = list(self._load_catalog_urls(timeout=timeout))
        # En derin (leaf) kategoriler once islensin ki her urun kendi
        # alt-kategori URL'ine tagged olsun. Parent sayfasi calistiginda
        # zaten seen_ids'de olan urunler atlanir, parent sadece residual
        # (hic bir cocukta olmayan) urunleri tutar.
        # Sort key: (depth desc, url asc) — derinlik icinde alfabetik.
        urls.sort(key=lambda u: (-u.count('/'), u))
        if max_urls is not None:
            urls = urls[: int(max_urls)]

        total = len(urls)
        for idx, url in enumerate(urls, start=1):
            try:
                html = self._fetch_html(url, timeout=timeout)
            except Exception as err:
                print(f"[a101.catalog] ({idx}/{total}) FAIL {url}: {err}")
                continue
            payload = self._collect_rsc_payload(html)
            before = len(seen_ids)
            yielded = 0
            for product in self._iter_products(payload, seen_ids=seen_ids):
                item = self._product_to_item(product, source_url=url)
                if item is not None:
                    yielded += 1
                    yield item
            new_unique = len(seen_ids) - before
            print(
                f"[a101.catalog] ({idx}/{total}) {url} "
                f"new_unique={new_unique} yielded={yielded}"
            )
            if delay and idx < total:
                time.sleep(delay)

    # ------------------------------------------------------------------
    # HTTP helpers
    # ------------------------------------------------------------------
    def _fetch_html(self, url: str, timeout: int = 30) -> str:
        response = requests.get(
            url,
            headers={
                "User-Agent": _UA,
                "Accept-Language": "tr,en-US;q=0.9,en;q=0.8",
                "Accept": (
                    "text/html,application/xhtml+xml,application/xml;q=0.9,"
                    "image/avif,image/webp,*/*;q=0.8"
                ),
                "Referer": "https://www.a101.com.tr/",
            },
            timeout=timeout,
        )
        response.raise_for_status()
        return response.text

    def _fetch_xml(self, url: str, timeout: int = 30) -> str:
        response = requests.get(
            url,
            headers={
                "User-Agent": _UA,
                "Accept-Language": "tr,en-US;q=0.9,en;q=0.8",
                "Accept": "application/xml,text/xml;q=0.9,*/*;q=0.8",
                "Referer": "https://www.a101.com.tr/",
            },
            timeout=timeout,
        )
        response.raise_for_status()
        return response.text

    def _load_catalog_urls(self, *, timeout: int) -> Iterator[str]:
        """Butun kayitli sitemap'leri yukle, URL-level dedupe ile yield et.

        Bir sitemap fetch/parse edilemezse diger sitemap'lere bakmaya
        devam ederiz — kismi basari iyidir, tam hata degil.
        """
        ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
        seen_urls: set[str] = set()
        for sitemap_url in _CATALOG_SITEMAP_URLS:
            try:
                xml_text = self._fetch_xml(sitemap_url, timeout=timeout)
            except Exception as err:
                print(
                    f"[a101.catalog] sitemap FETCH FAIL {sitemap_url}: {err}"
                )
                continue
            try:
                root = ET.fromstring(xml_text)
            except ET.ParseError as err:
                print(
                    f"[a101.catalog] sitemap PARSE FAIL {sitemap_url}: {err}"
                )
                continue
            new_count = 0
            total = 0
            for loc in root.findall(".//sm:url/sm:loc", ns):
                if not loc.text:
                    continue
                total += 1
                url = loc.text.strip()
                if url in seen_urls:
                    continue
                seen_urls.add(url)
                new_count += 1
                yield url
            print(
                f"[a101.catalog] sitemap loaded {sitemap_url} "
                f"total={total} new_unique={new_count}"
            )

    # ------------------------------------------------------------------
    # RSC payload extraction (shared by campaign + catalog)
    # ------------------------------------------------------------------
    @staticmethod
    def _collect_rsc_payload(html: str) -> str:
        """Tum __next_f.push chunk'larinin string degerlerini birlestir."""
        pieces: list[str] = []
        for match in _CHUNK_RE.finditer(html):
            try:
                arr = json.loads(match.group(1))
            except json.JSONDecodeError:
                continue
            if isinstance(arr, list) and len(arr) >= 2 and isinstance(arr[1], str):
                pieces.append(arr[1])
        return "".join(pieces)

    @classmethod
    def _iter_products(
        cls, payload: str, *, seen_ids: set[str] | None = None
    ) -> Iterable[dict]:
        """Payload icinde gecen tum `"products":[...]` array'lerini cikar.

        seen_ids verilirse cross-page dedupe saglar.
        """
        if seen_ids is None:
            seen_ids = set()
        for array_text in cls._find_products_arrays(payload):
            try:
                products = json.loads(array_text)
            except json.JSONDecodeError:
                continue
            if not isinstance(products, list):
                continue
            for obj in products:
                if not isinstance(obj, dict):
                    continue
                pid = str(obj.get("id") or "")
                if not pid or pid in seen_ids:
                    continue
                # basit sanity check: price + attributes olmali
                if "price" not in obj or "attributes" not in obj:
                    continue
                seen_ids.add(pid)
                yield obj

    @staticmethod
    def _find_products_arrays(payload: str) -> Iterable[str]:
        """`"products":[...]` pattern'ini brace/bracket-balanced olarak cikar."""
        key = '"products":['
        i = 0
        length = len(payload)
        while True:
            idx = payload.find(key, i)
            if idx < 0:
                return
            start = idx + len(key) - 1  # `[` uzerinde
            k = start
            depth = 0
            in_str = False
            escape = False
            while k < length:
                ch = payload[k]
                if in_str:
                    if escape:
                        escape = False
                    elif ch == "\\":
                        escape = True
                    elif ch == '"':
                        in_str = False
                elif ch == '"':
                    in_str = True
                elif ch == "[":
                    depth += 1
                elif ch == "]":
                    depth -= 1
                    if depth == 0:
                        yield payload[start:k + 1]
                        i = k + 1
                        break
                k += 1
            else:
                return  # hatali yapi — dur

    # ------------------------------------------------------------------
    # Product -> WorkerItem
    # ------------------------------------------------------------------
    def _product_to_item(
        self,
        product: dict,
        *,
        source_url: str | None,
    ) -> WorkerItem | None:
        attributes = product.get("attributes") or {}
        name = (attributes.get("name") or "").strip()
        if not name:
            return None

        price = product.get("price") or {}
        normal = _kurus_to_try(price.get("normal"))
        discounted = _kurus_to_try(price.get("discounted"))

        # `discount_price` alaninin "gecerli/guncel fiyat" oldugunu kabul
        # ediyoruz — core.insert_price bu alana bakarak satir yaziyor.
        # A101'de cogu urunde normal==discounted; gercek indirim oldugunda
        # discounted < normal olur. is_on_sale kontrolu core tarafinda
        # regular_price > discount_price karsilastirmasiyla yapiliyor.
        current_price = discounted if discounted is not None else normal
        if current_price is None:
            return None
        discount_price = current_price
        regular_price = normal if normal is not None else current_price

        image_url = None
        images = product.get("images") or []
        if isinstance(images, list) and images:
            first = images[0]
            if isinstance(first, dict):
                image_url = first.get("url")

        # Ürünün kendi canonical URL'i varsa onu kullan; yoksa çağıranın
        # verdigi kategori URL'ine fallback.
        own_url = attributes.get("url") or None
        final_source_url = own_url or source_url or _CAMPAIGN_URL

        promotions = product.get("promotions") or []
        primary_promo = None
        if isinstance(promotions, list) and promotions:
            first_promo = promotions[0]
            if isinstance(first_promo, dict):
                primary_promo = first_promo.get("name")

        return WorkerItem(
            market_id=self.market_id,
            product_name=name,
            brand=None,  # A101 kendi feed'inde brand field'i saglamiyor
            discount_price=discount_price,
            regular_price=regular_price,
            currency="TRY",
            valid_from=None,
            valid_until=None,
            image_url=image_url,
            source_url=final_source_url,
            ocr_text=None,
            confidence=0.95 if primary_promo == "aldin-aldin" else 0.9,
            raw=product,
        )

    def _row_to_item(self, row: dict) -> WorkerItem:
        """BaseParser sozlesmesinin basit implementasyonu — duz JSON fixture
        okumasinda kullanilabilir (attr/name/discountPrice/... sahalari)."""
        return WorkerItem(
            market_id=self.market_id,
            product_name=(row.get("productName") or row.get("name") or "").strip(),
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


def _as_float(value) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _kurus_to_try(value) -> float | None:
    """A101 fiyatlari 'integer kurus' olarak gonderiyor: 8900 -> 89.00 TL."""
    if value is None:
        return None
    try:
        return round(float(value) / 100.0, 2)
    except (TypeError, ValueError):
        return None
