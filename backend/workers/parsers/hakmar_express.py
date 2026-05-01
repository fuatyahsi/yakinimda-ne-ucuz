"""HakmarExpress parser — canlı fetch (Angular SSR + window.__SSR_DATA__).

Neden bu parser?
    HAKMAR ve HAKMAR Express marketfiyati.org.tr'da KAPSAMDA DEGIL.
    Cozum: hakmarexpress.com.tr'den dogrudan parse. Angular SPA, ama her
    sayfa Server-Side Render edilip `<script>window.__SSR_DATA__={...}`
    inline JSON ile state'i sayfaya gomuyor. Tek `json.loads` ile tum
    sayfa data'sina erisilir.

Kaynaklar:
    website          : https://www.hakmarexpress.com.tr
    AWS S3 sitemap   : https://eticaret.s3.us-east-1.amazonaws.com/seo/sitemap.xml
                       (4,460 urun URL'i; full katalog yedek)
    URL formati      :
        kategori sayfasi : https://www.hakmarexpress.com.tr/{slug}-c
        urun sayfasi     : https://www.hakmarexpress.com.tr/{slug}-{id}-p

Strateji (default mode=category):
    HAKMAR Express ana sayfasinin __SSR_DATA__'si config.header altinda
    NAVIGATION'i tasiyor — tum kategorilerin slug + name listesi
    (~193 kategori). Bu listeden alinan slug'lar ile her kategori
    sayfasini tek tek fetch ediyoruz.

    Her kategori sayfasinda __SSR_DATA__ icinde 17-25 urun bulunuyor
    (initialSlugData.page[..].columns[..].contents[..].columns[..]
     .content.products). Path'i defansif olarak recursive arama ile
    buluyoruz — site yapisi degisirse path da degisir, bu yuzden
    brittle deep-key access yerine "name+price iceren list" pattern'i.

    Toplam: 193 kategori × 1.5s (fetch + delay) ≈ ~5dk full sweep.
    Tahmini ürün: ~4,000+ unique (sitemap'taki 4,460'a yakin).

Strateji yedek (mode=catalog):
    AWS S3'teki resmi sitemap'tan urun URL'lerini al, her birini fetch
    et, urun sayfasinda __SSR_DATA__ icindeki tek urun verisini parse
    et. 4,460 fetch — ~75dk full sweep. Sadece kategori sweep'i
    yetmezse fallback.

Urun objesinin sekli:
    {
      "id": 18596,
      "name": "Göynük Süt Doğal %1,5 Yağlı 1000 ml",
      "slug": "...",
      "price": 43.9,                  # mevcut/indirimli fiyat
      "oldPrice": null,               # indirim oncesi (varsa)
      "discountRate": null,           # indirim yuzdesi (varsa)
      "pricePerKg": null,             # birim fiyat
      "packageWeight": ...,
      "barcode": "...",
      "imageUrl": "https://eticaret.s3...",
      "outOfStock": false,
      "campaignDescription": "...",
      ...
    }

Modlar (fetch_items(mode=...)):
    "category" (default) : Ana sayfa nav -> 193 kategori sweep. ~5dk.
    "catalog"            : S3 sitemap -> 4,460 urun-URL sweep. ~75dk.
"""

from __future__ import annotations

import json
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

_BASE_URL = "https://www.hakmarexpress.com.tr"
_S3_SITEMAP = "https://eticaret.s3.us-east-1.amazonaws.com/seo/sitemap.xml"

_SSR_KEY = "window.__SSR_DATA__="

# Kategori sayfasi arası delay (saniye) — politeness.
_CATEGORY_DELAY_SEC = 1.0


class HakmarExpressParser(BaseParser):
    market_id = "hakmar-express"
    alias_source = "hakmar-express"
    source_label = "hakmar_express_direct"
    source_type = "catalog"
    status = "implemented"
    discovery_notes = (
        "hakmarexpress.com.tr Angular SSR — window.__SSR_DATA__ "
        "inline JSON. 193 kategori sweep ~5dk; AWS S3 sitemap "
        "yedek (mode=catalog, ~75dk)."
    )

    website = _BASE_URL
    listing_url = _BASE_URL

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def fetch_items(self, **kwargs) -> Iterable[WorkerItem]:
        mode = (kwargs.get("mode") or "category").lower()
        timeout = int(kwargs.get("timeout") or 30)
        max_urls = kwargs.get("max_urls")
        delay = float(kwargs.get("delay") or _CATEGORY_DELAY_SEC)

        if mode == "category":
            yield from self._iter_categories(
                timeout=timeout, max_urls=max_urls, delay=delay
            )
            return
        if mode == "catalog":
            yield from self._iter_catalog(
                timeout=timeout, max_urls=max_urls, delay=delay
            )
            return
        raise ValueError(
            f"Unknown HakmarExpress fetch mode={mode!r}. "
            f"Desteklenen: category, catalog."
        )

    # ------------------------------------------------------------------
    # Fixture: ham HTML verilirse SSR decode et, aksi halde JSON.
    # ------------------------------------------------------------------
    def read_fixture(self, path: str | Path) -> Iterable[WorkerItem]:
        raw = Path(path).read_text(encoding="utf-8")
        if raw.lstrip().startswith("<"):
            data = self._parse_ssr(raw)
            if data is not None:
                for product in self._iter_products(data):
                    item = self._product_to_item(product, source_url=None)
                    if item is not None:
                        yield item
        else:
            yield from super().read_fixture(path)

    # ------------------------------------------------------------------
    # Mode: category (default)
    # ------------------------------------------------------------------
    def _iter_categories(
        self,
        *,
        timeout: int,
        max_urls,
        delay: float,
    ) -> Iterator[WorkerItem]:
        """Ana sayfadan kategori slug'larini topla, her birini fetch et."""
        seen_product_ids: set[str] = set()

        # 1) Ana sayfayi cek, kategori slug'larini cikar.
        try:
            home_html = self._fetch_html(_BASE_URL + "/", timeout=timeout)
        except Exception as err:
            print(f"[hakmar_express.category] homepage FETCH FAIL: {err}")
            return
        home_data = self._parse_ssr(home_html)
        if home_data is None:
            print("[hakmar_express.category] homepage __SSR_DATA__ yok")
            return

        slugs = sorted(set(self._iter_category_slugs(home_data)))
        # Kategori URL'i {slug} formatinda (slug zaten "-c" ile bitiyor).
        urls = [f"{_BASE_URL}/{slug}" for slug in slugs]
        if max_urls is not None:
            urls = urls[: int(max_urls)]
        total = len(urls)
        print(f"[hakmar_express.category] {total} kategori URL'i toplandi")

        # 2) Her kategori sayfasini fetch et, urun listesini parse et.
        for idx, url in enumerate(urls, start=1):
            try:
                html = self._fetch_html(url, timeout=timeout)
            except Exception as err:
                msg = str(err)
                if "404" in msg:
                    print(f"[hakmar_express.category] ({idx}/{total}) 404 {url}")
                else:
                    print(f"[hakmar_express.category] ({idx}/{total}) FAIL {url}: {err}")
                continue
            data = self._parse_ssr(html)
            if data is None:
                continue
            # Sadece sayfanin gerceK icerigi (initialSlugData) — config/header
            # icindeki global showcase'leri skip. Aksi halde ana sayfa
            # showcase'leri her kategoriye ait gibi yazilirdi.
            scope = data.get("initialSlugData") or data
            yielded = 0
            new_unique = 0
            for product in self._iter_products(scope):
                pid = self._product_unique_key(product)
                if pid is None or pid in seen_product_ids:
                    continue
                seen_product_ids.add(pid)
                new_unique += 1
                item = self._product_to_item(product, source_url=url)
                if item is not None:
                    yielded += 1
                    yield item
            print(
                f"[hakmar_express.category] ({idx}/{total}) {url} "
                f"new_unique={new_unique} yielded={yielded}"
            )
            if delay and idx < total:
                time.sleep(delay)

    # ------------------------------------------------------------------
    # Mode: catalog (yedek — S3 sitemap'tan tum urun URL'leri)
    # ------------------------------------------------------------------
    def _iter_catalog(
        self,
        *,
        timeout: int,
        max_urls,
        delay: float,
    ) -> Iterator[WorkerItem]:
        seen_product_ids: set[str] = set()
        urls = list(self._load_sitemap_urls(timeout=timeout))
        if max_urls is not None:
            urls = urls[: int(max_urls)]
        total = len(urls)
        print(f"[hakmar_express.catalog] sitemap loaded: {total} urun URL'i")

        for idx, url in enumerate(urls, start=1):
            try:
                html = self._fetch_html(url, timeout=timeout)
            except Exception as err:
                msg = str(err)
                if "404" in msg:
                    print(f"[hakmar_express.catalog] ({idx}/{total}) 404 {url}")
                else:
                    print(f"[hakmar_express.catalog] ({idx}/{total}) FAIL {url}: {err}")
                continue
            data = self._parse_ssr(html)
            if data is None:
                continue
            # initialSlugData -> sadece bu urunun verisi (config showcase'i atla)
            scope = data.get("initialSlugData") or data
            for product in self._iter_products(scope):
                pid = self._product_unique_key(product)
                if pid is None or pid in seen_product_ids:
                    continue
                seen_product_ids.add(pid)
                item = self._product_to_item(product, source_url=url)
                if item is not None:
                    yield item
            if idx % 25 == 0:
                print(
                    f"[hakmar_express.catalog] ({idx}/{total}) "
                    f"seen={len(seen_product_ids)}"
                )
            if delay and idx < total:
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
        response = requests.get(url, headers=self._http_headers(), timeout=timeout)
        response.raise_for_status()
        return response.text

    def _fetch_xml(self, url: str, timeout: int = 30) -> str:
        response = requests.get(
            url, headers=self._http_headers(accept_xml=True), timeout=timeout
        )
        response.raise_for_status()
        return response.text

    def _load_sitemap_urls(self, *, timeout: int) -> Iterator[str]:
        """S3 sitemap'i fetch et, urun URL'lerini yield et."""
        ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
        try:
            xml_text = self._fetch_xml(_S3_SITEMAP, timeout=timeout)
        except Exception as err:
            print(f"[hakmar_express.catalog] S3 sitemap FETCH FAIL: {err}")
            return
        try:
            root = ET.fromstring(xml_text)
        except ET.ParseError as err:
            print(f"[hakmar_express.catalog] sitemap PARSE FAIL: {err}")
            return
        for loc in root.findall(".//sm:url/sm:loc", ns):
            if loc.text:
                yield loc.text.strip()

    # ------------------------------------------------------------------
    # SSR payload extraction
    # ------------------------------------------------------------------
    @staticmethod
    def _parse_ssr(html: str) -> dict | None:
        """`window.__SSR_DATA__={...}` JSON'unu cikar, parse et.

        Brace-balanced parse — string literal'lerinin icindeki `{` `}`
        karakterleri sayilmaz. Hatali yapida None doner.
        """
        idx = html.find(_SSR_KEY)
        if idx < 0:
            return None
        start = idx + len(_SSR_KEY)
        if start >= len(html) or html[start] != "{":
            return None
        depth = 0
        in_str = False
        escape = False
        k = start
        while k < len(html):
            ch = html[k]
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
                    try:
                        return json.loads(html[start: k + 1])
                    except json.JSONDecodeError:
                        return None
            k += 1
        return None

    # ------------------------------------------------------------------
    # Recursive walker'lar — defansif: site yapisi degisirse de calisir
    # ------------------------------------------------------------------
    @classmethod
    def _iter_category_slugs(cls, obj, depth: int = 0) -> Iterator[str]:
        """SSR data icindeki kategori slug'larini topla.

        Heuristic: 'slug' + 'name' icerip 'price' ICERMEYEN dict'leri
        kategori say. Slug kuralı: '-c' ile biter (HAKMAR Express convention).
        """
        if depth > 12 or not isinstance(obj, (dict, list)):
            return
        if isinstance(obj, dict):
            slug = obj.get("slug")
            name = obj.get("name")
            if (
                isinstance(slug, str)
                and slug.endswith("-c")
                and isinstance(name, str)
                and "price" not in obj
            ):
                yield slug
            for v in obj.values():
                yield from cls._iter_category_slugs(v, depth + 1)
        else:
            for v in obj:
                yield from cls._iter_category_slugs(v, depth + 1)

    @classmethod
    def _iter_products(cls, obj, depth: int = 0) -> Iterator[dict]:
        """SSR data icinde 'urun' icerigine sahip dict'leri yield et.

        Heuristic: name + price + id alanlari ile dolu dict'ler. Kategori
        sayfasinda urunler genelde [{product: {...}}, {product: {...}}, ...]
        wrapper icinde geliyor — bu durumda product dict'ini cikar.
        """
        if depth > 14 or not isinstance(obj, (dict, list)):
            return
        if isinstance(obj, dict):
            # Wrapper dict: { "product": {...} }
            inner = obj.get("product")
            if (
                isinstance(inner, dict)
                and "name" in inner
                and "price" in inner
                and "id" in inner
            ):
                yield inner
                return
            # Direkt product dict mi (name + price + id)
            if (
                "name" in obj
                and "price" in obj
                and "id" in obj
                and isinstance(obj.get("price"), (int, float))
                and isinstance(obj.get("name"), str)
            ):
                yield obj
                return
            for v in obj.values():
                yield from cls._iter_products(v, depth + 1)
        else:
            for v in obj:
                yield from cls._iter_products(v, depth + 1)

    @staticmethod
    def _product_unique_key(product: dict) -> str | None:
        pid = product.get("id")
        return str(pid) if pid is not None else None

    # ------------------------------------------------------------------
    # Product -> WorkerItem
    # ------------------------------------------------------------------
    def _product_to_item(
        self,
        product: dict,
        *,
        source_url: str | None,
    ) -> WorkerItem | None:
        name = (product.get("name") or "").strip()
        if not name:
            return None

        price = _as_float(product.get("price"))
        old_price = _as_float(product.get("oldPrice"))

        if price is None:
            return None
        # discount_price = guncel fiyat; regular_price = liste fiyati
        # HAKMAR'da `price` her zaman mevcut/guncel; `oldPrice` sadece
        # indirim varsa dolu.
        regular_price = old_price if old_price is not None else price

        image_url = (product.get("imageUrl") or "").strip() or None

        # Slug HAKMAR Express'te zaten "{name}-{baseId}-p" formatinda;
        # tekrar `-{id}-p` eklemeyelim. Eger slug `-p` ile bitmiyorsa
        # legacy fallback olarak suffix ekle.
        slug = (product.get("slug") or "").strip()
        product_id = product.get("id")
        if slug.endswith("-p"):
            final_source_url = f"{_BASE_URL}/{slug}"
        elif slug and product_id is not None:
            final_source_url = f"{_BASE_URL}/{slug}-{product_id}-p"
        else:
            final_source_url = source_url or _BASE_URL

        return WorkerItem(
            market_id=self.market_id,
            product_name=name,
            brand=None,  # HAKMAR Express SSR'da brand alani yok
            discount_price=price,
            regular_price=regular_price,
            currency="TRY",
            valid_from=None,
            valid_until=None,
            image_url=image_url,
            source_url=final_source_url,
            ocr_text=None,
            confidence=0.95,
            raw=product,
        )

    # ------------------------------------------------------------------
    # BaseParser sozlesmesi — fixture okumada kullanilabilir
    # ------------------------------------------------------------------
    def _row_to_item(self, row: dict) -> WorkerItem:
        return WorkerItem(
            market_id=self.market_id,
            product_name=(row.get("productName") or row.get("name") or "").strip(),
            brand=(row.get("brand") or "").strip() or None,
            discount_price=_as_float(
                row.get("discountPrice") or row.get("price")
            ),
            regular_price=_as_float(
                row.get("regularPrice") or row.get("oldPrice") or row.get("price")
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
