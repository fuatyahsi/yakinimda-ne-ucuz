from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass, field
from datetime import date, datetime
from pathlib import Path
from typing import Iterable
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup

AKAKCE_LISTING_URL = "https://www.akakce.com/brosurler/?l=1"
AKAKCE_BASE_URL = "https://www.akakce.com"
DEFAULT_TIMEOUT = 30
DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
)
DEFAULT_HEADERS = {
    "User-Agent": DEFAULT_USER_AGENT,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Cache-Control": "no-cache",
    "Pragma": "no-cache",
    "Referer": AKAKCE_BASE_URL,
}

TURKISH_MONTHS = {
    "ocak": 1,
    "subat": 2,
    "mart": 3,
    "nisan": 4,
    "mayis": 5,
    "haziran": 6,
    "temmuz": 7,
    "agustos": 8,
    "eylul": 9,
    "ekim": 10,
    "kasim": 11,
    "aralik": 12,
}


@dataclass
class BrochureImage:
    page_index: int
    image_url: str
    local_path: str | None = None


@dataclass
class BrochureSource:
    brochure_id: str
    detail_url: str
    title: str
    market_name: str
    slug: str
    discovered_at: str
    catalog_url: str | None = None
    valid_from: str | None = None
    valid_until: str | None = None
    image_count: int = 0
    images: list[BrochureImage] = field(default_factory=list)


def build_parser() -> argparse.ArgumentParser:
    worker_root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Discover Akakce brochure detail pages and page images."
    )
    parser.add_argument("--listing-url", default=AKAKCE_LISTING_URL)
    parser.add_argument("--max-brochures", type=int, default=18)
    parser.add_argument(
        "--seed-urls-file",
        default=str(worker_root / "input" / "seed_urls.txt"),
    )
    parser.add_argument(
        "--output",
        default=str(worker_root / "output" / "source_manifest.json"),
    )
    parser.add_argument(
        "--images-dir",
        default=str(worker_root / "output" / "images"),
    )
    parser.add_argument("--download-images", action="store_true")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    return parser


def fetch_html(session: requests.Session, url: str, timeout: int) -> str:
    payload = fetch_bytes(session, url, timeout)
    return decode_html_bytes(payload)


def decode_html_bytes(payload: bytes) -> str:
    declared = detect_declared_charset(payload)
    candidates = [declared, "utf-8", "windows-1254", "iso-8859-9", "latin-1"]
    seen: set[str] = set()

    for encoding in candidates:
        if not encoding:
            continue
        normalized = encoding.lower().strip()
        if normalized in seen:
            continue
        seen.add(normalized)
        try:
            return payload.decode(normalized)
        except (LookupError, UnicodeDecodeError):
            continue

    return payload.decode("utf-8", errors="replace")


def detect_declared_charset(payload: bytes) -> str | None:
    head = payload[:4096].decode("ascii", errors="ignore")
    charset_match = re.search(r"charset\s*=\s*['\"]?([a-zA-Z0-9._-]+)", head, re.IGNORECASE)
    if charset_match:
        return charset_match.group(1)
    return None


def fetch_bytes(session: requests.Session, url: str, timeout: int) -> bytes:
    response = session.get(url, timeout=timeout, headers=DEFAULT_HEADERS)
    if response.status_code == 403:
        print(f"[fetch_sources] requests got 403 for {url}")
        try:
            fallback_payload = fetch_with_curl_cffi(url, timeout)
            if fallback_payload is not None:
                print(f"[fetch_sources] curl_cffi succeeded for {url}")
                return fallback_payload
        except Exception as error:
            print(f"[fetch_sources] curl_cffi failed for {url}: {error}")

        try:
            browser_payload = fetch_with_playwright(url, timeout)
            if browser_payload is not None:
                print(f"[fetch_sources] Playwright succeeded for {url}")
                return browser_payload
        except Exception as error:
            print(f"[fetch_sources] Playwright failed for {url}: {error}")

    response.raise_for_status()
    return response.content


def fetch_with_curl_cffi(url: str, timeout: int) -> bytes | None:
    try:
        from curl_cffi import requests as curl_requests  # type: ignore
    except ImportError:
        return None

    response = curl_requests.get(
        url,
        headers=DEFAULT_HEADERS,
        timeout=timeout,
        impersonate="chrome124",
    )
    response.raise_for_status()
    return response.content


def fetch_with_playwright(url: str, timeout: int) -> bytes | None:
    try:
        from playwright.sync_api import sync_playwright  # type: ignore
    except ImportError:
        return None

    timeout_ms = timeout * 1000
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            args=[
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
            ],
        )
        context = browser.new_context(
            user_agent=DEFAULT_USER_AGENT,
            locale="tr-TR",
            extra_http_headers={
                "Accept-Language": DEFAULT_HEADERS["Accept-Language"],
                "Cache-Control": DEFAULT_HEADERS["Cache-Control"],
                "Pragma": DEFAULT_HEADERS["Pragma"],
            },
            viewport={"width": 1440, "height": 2400},
        )
        page = context.new_page()
        page.goto(url, wait_until="domcontentloaded", timeout=timeout_ms)
        page.wait_for_load_state("networkidle", timeout=timeout_ms)
        page.wait_for_timeout(2000)
        html = page.content()
        context.close()
        browser.close()
        return html.encode("utf-8", errors="ignore")


def extract_detail_urls_with_playwright(url: str, timeout: int) -> list[str]:
    try:
        from playwright.sync_api import sync_playwright  # type: ignore
    except ImportError:
        return []

    timeout_ms = timeout * 1000
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            args=[
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
            ],
        )
        context = browser.new_context(
            user_agent=DEFAULT_USER_AGENT,
            locale="tr-TR",
            extra_http_headers={
                "Accept-Language": DEFAULT_HEADERS["Accept-Language"],
                "Cache-Control": DEFAULT_HEADERS["Cache-Control"],
                "Pragma": DEFAULT_HEADERS["Pragma"],
            },
            viewport={"width": 1440, "height": 2400},
        )
        page = context.new_page()
        page.goto(url, wait_until="domcontentloaded", timeout=timeout_ms)
        page.wait_for_load_state("networkidle", timeout=timeout_ms)
        page.mouse.wheel(0, 6000)
        page.wait_for_timeout(1500)
        title = page.title()
        hrefs = page.eval_on_selector_all(
            "a[href]",
            "elements => elements.map(element => element.href)",
        )
        html = page.content()
        context.close()
        browser.close()

    print(f"[fetch_sources] Playwright page title: {title}")
    print(f"[fetch_sources] Playwright href count: {len(hrefs)}")
    print(f"[fetch_sources] Playwright html snippet: {html[:400].replace(chr(10), ' ')}")

    urls: list[str] = []
    seen: set[str] = set()
    for href in hrefs:
        url = normalize_url(str(href))
        if not is_brochure_detail_url(url):
            continue
        if url in seen:
            continue
        seen.add(url)
        urls.append(url)
    return urls


def extract_detail_urls(listing_html: str) -> list[str]:
    soup = BeautifulSoup(listing_html, "html.parser")
    urls: list[str] = []
    seen: set[str] = set()

    for anchor in soup.find_all("a", href=True):
        href = anchor["href"].strip()
        if "/brosurler/" not in href:
            continue
        url = normalize_url(href)
        if not is_brochure_detail_url(url):
            continue
        if url in seen:
            continue
        seen.add(url)
        urls.append(url)

    if urls:
        return urls

    normalized_html = (
        listing_html.replace("\\/", "/")
        .replace("\\u002F", "/")
        .replace("&quot;", '"')
    )
    for match in re.findall(r"https://www\.akakce\.com/brosurler/[a-z0-9-]+-\d+", normalized_html):
        url = normalize_url(match)
        if not is_brochure_detail_url(url):
            continue
        if url in seen:
            continue
        seen.add(url)
        urls.append(url)

    for match in re.findall(r"/brosurler/[a-z0-9-]+-\d+", normalized_html):
        url = normalize_url(match)
        if not is_brochure_detail_url(url):
            continue
        if url in seen:
            continue
        seen.add(url)
        urls.append(url)

    return urls


def parse_detail_page(
    detail_url: str,
    detail_html: str,
    discovered_at: datetime,
) -> BrochureSource:
    soup = BeautifulSoup(detail_html, "html.parser")
    title = extract_title(soup, detail_url)
    image_urls = extract_brochure_image_urls(soup)
    brochure_id = extract_brochure_id(detail_url)
    slug = Path(urlparse(detail_url).path).name
    market_name = detect_market_name(title=title, slug=slug)
    valid_from, valid_until = parse_date_window(title)

    images = [
        BrochureImage(
            page_index=index + 1,
            image_url=image_url,
        )
        for index, image_url in enumerate(image_urls)
    ]

    return BrochureSource(
        brochure_id=brochure_id,
        detail_url=detail_url,
        title=title,
        market_name=market_name,
        slug=slug,
        discovered_at=discovered_at.isoformat(),
        valid_from=valid_from.isoformat() if valid_from else None,
        valid_until=valid_until.isoformat() if valid_until else None,
        image_count=len(images),
        images=images,
    )


def extract_title(soup: BeautifulSoup, detail_url: str) -> str:
    meta_title = soup.find("meta", attrs={"property": "og:title"})
    if meta_title and meta_title.get("content"):
        return meta_title["content"].strip()

    title_tag = soup.find("title")
    if title_tag and title_tag.text.strip():
        return title_tag.text.strip()

    return Path(urlparse(detail_url).path).name.replace("-", " ").strip()


def extract_brochure_image_urls(soup: BeautifulSoup) -> list[str]:
    candidates: list[str] = []
    seen: set[str] = set()

    for tag in soup.find_all(["meta", "img", "source"]):
        for attribute in ("content", "src", "data-src", "data-original", "srcset"):
            raw = tag.get(attribute)
            if not raw:
                continue
            for piece in split_src_candidate(raw):
                if "cdn.akakce.com/_bro/" not in piece:
                    continue
                url = canonicalize_brochure_image_url(normalize_url(piece))
                if url in seen:
                    continue
                seen.add(url)
                candidates.append(url)

    return candidates


def split_src_candidate(raw: str) -> Iterable[str]:
    if "," in raw and " " in raw:
        for part in raw.split(","):
            token = part.strip().split(" ")[0]
            if token:
                yield token
        return

    yield raw.strip()


def normalize_url(url: str) -> str:
    if url.startswith("//"):
        return f"https:{url}"
    return urljoin(AKAKCE_BASE_URL, url)


def is_brochure_detail_url(url: str) -> bool:
    parsed = urlparse(url)
    path = parsed.path.rstrip("/")
    if path == "/brosurler":
        return False
    return bool(re.search(r"/brosurler/[^/]+-\d+$", path))


def canonicalize_brochure_image_url(url: str) -> str:
    return url.replace("/_bro/y/", "/_bro/u/")


def is_brochure_image_url(url: str) -> bool:
    return "cdn.akakce.com/_bro/" in url


def extract_brochure_id(detail_url: str) -> str:
    match = re.search(r"-(\d+)(?:/)?$", detail_url)
    if match:
        return match.group(1)
    return Path(urlparse(detail_url).path).name


def detect_market_name(*, title: str, slug: str) -> str:
    title_normalized = normalize_text(title)
    slug_normalized = normalize_text(slug.replace("-", " "))
    known_names = [
        "A101",
        "BIM",
        "SOK",
        "Migros",
        "Esenlik",
        "Metro",
        "Kipa",
        "CarrefourSA",
        "Onur Market",
        "Bizim Toptan",
        "Hakmar",
        "Baris Gross",
        "Furpa",
        "Show Hipermarket",
        "Cagri",
        "MopaS",
    ]

    for known_name in known_names:
        token = normalize_text(known_name)
        if token in title_normalized or token in slug_normalized:
            return known_name

    first_token = slug.split("-")[0].strip()
    if not first_token:
        return "Akakce"
    return first_token.replace("_", " ").title()


def parse_date_window(title: str) -> tuple[date | None, date | None]:
    normalized = normalize_text(title)

    range_match = re.search(
        r"(\d{1,2})\s+([a-z]+)\s*-\s*(\d{1,2})\s+([a-z]+)\s+(\d{4})",
        normalized,
    )
    if range_match:
        start_day, start_month, end_day, end_month, year = range_match.groups()
        start = build_date(year, start_month, start_day)
        end = build_date(year, end_month, end_day)
        return start, end

    single_match = re.search(r"(\d{1,2})\s+([a-z]+)\s+(\d{4})", normalized)
    if single_match:
        day, month, year = single_match.groups()
        moment = build_date(year, month, day)
        return moment, moment

    return None, None


def build_date(year: str, month_name: str, day: str) -> date | None:
    month = TURKISH_MONTHS.get(month_name)
    if month is None:
        return None
    try:
        return date(int(year), month, int(day))
    except ValueError:
        return None


def normalize_text(value: str) -> str:
    return (
        value.lower()
        .replace("ı", "i")
        .replace("ğ", "g")
        .replace("ü", "u")
        .replace("ş", "s")
        .replace("ö", "o")
        .replace("ç", "c")
    )


def download_images(
    session: requests.Session,
    brochure: BrochureSource,
    images_root: Path,
    timeout: int,
) -> BrochureSource:
    brochure_dir = images_root / brochure.brochure_id
    brochure_dir.mkdir(parents=True, exist_ok=True)

    for image in brochure.images:
        extension = Path(urlparse(image.image_url).path).suffix or ".jpg"
        image_path = brochure_dir / f"page_{image.page_index:02d}{extension}"
        image_path.write_bytes(fetch_bytes(session, image.image_url, timeout))
        image.local_path = str(image_path.resolve())

    return brochure


def brochure_to_json(brochure: BrochureSource) -> dict:
    payload = asdict(brochure)
    payload["images"] = [asdict(image) for image in brochure.images]
    return payload


def load_seed_lines(seed_urls_path: Path) -> list[str]:
    if not seed_urls_path.exists():
        return []

    lines = []
    for raw_line in seed_urls_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        lines.append(line)
    return lines


def build_brochures_from_seed_lines(
    *,
    seed_lines: list[str],
    discovered_at: datetime,
) -> list[BrochureSource]:
    direct_images_by_brochure: dict[str, list[str]] = {}
    detail_urls: list[str] = []

    for line in seed_lines:
        url = normalize_url(line)
        if is_brochure_detail_url(url):
            detail_urls.append(url)
            continue
        if is_brochure_image_url(url):
            brochure_id = extract_brochure_id(url)
            direct_images_by_brochure.setdefault(brochure_id, []).append(
                canonicalize_brochure_image_url(url)
            )

    brochures: list[BrochureSource] = []
    for detail_url in detail_urls:
        brochure_id = extract_brochure_id(detail_url)
        slug = Path(urlparse(detail_url).path).name
        title = slug.replace("-", " ").strip()
        market_name = detect_market_name(title=title, slug=slug)
        images = [
            BrochureImage(page_index=index + 1, image_url=image_url)
            for index, image_url in enumerate(direct_images_by_brochure.pop(brochure_id, []))
        ]
        brochures.append(
            BrochureSource(
                brochure_id=brochure_id,
                detail_url=detail_url,
                title=title,
                market_name=market_name,
                slug=slug,
                discovered_at=discovered_at.isoformat(),
                image_count=len(images),
                images=images,
            )
        )

    for brochure_id, image_urls in direct_images_by_brochure.items():
        slug = brochure_id
        images = [
            BrochureImage(page_index=index + 1, image_url=image_url)
            for index, image_url in enumerate(image_urls)
        ]
        brochures.append(
            BrochureSource(
                brochure_id=brochure_id,
                detail_url="",
                title=f"Seed brochure {brochure_id}",
                market_name="Akakce Seed",
                slug=slug,
                discovered_at=discovered_at.isoformat(),
                image_count=len(images),
                images=images,
            )
        )

    return brochures


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    images_root = Path(args.images_dir).resolve()
    seed_urls_path = Path(args.seed_urls_file).resolve()

    session = requests.Session()
    session.headers.update(DEFAULT_HEADERS)

    generated_at = datetime.utcnow().replace(microsecond=0)
    listing_html = fetch_html(session, args.listing_url, args.timeout)
    detail_urls = extract_detail_urls(listing_html)
    if not detail_urls:
        print(
            "[fetch_sources] HTML parse returned 0 brochure links, trying "
            "Playwright DOM extraction"
        )
        detail_urls = extract_detail_urls_with_playwright(
            args.listing_url,
            args.timeout,
        )
    print(f"[fetch_sources] discovered {len(detail_urls)} brochure link(s)")
    detail_urls = detail_urls[: args.max_brochures]

    brochures: list[BrochureSource] = []
    if detail_urls:
        for detail_url in detail_urls:
            detail_html = fetch_html(session, detail_url, args.timeout)
            brochure = parse_detail_page(
                detail_url=detail_url,
                detail_html=detail_html,
                discovered_at=generated_at,
            )
            if args.download_images and brochure.images:
                brochure = download_images(
                    session=session,
                    brochure=brochure,
                    images_root=images_root,
                    timeout=args.timeout,
                )
            brochures.append(brochure)
    else:
        seed_lines = load_seed_lines(seed_urls_path)
        if seed_lines:
            print(
                f"[fetch_sources] using {len(seed_lines)} seed URL(s) from "
                f"{seed_urls_path}"
            )
            brochures = build_brochures_from_seed_lines(
                seed_lines=seed_lines,
                discovered_at=generated_at,
            )
            brochures = brochures[: args.max_brochures]
            if args.download_images:
                brochures = [
                    download_images(
                        session=session,
                        brochure=brochure,
                        images_root=images_root,
                        timeout=args.timeout,
                    )
                    if brochure.images
                    else brochure
                    for brochure in brochures
                ]
        else:
            print(
                "[fetch_sources] no brochure links discovered and no seed URL "
                f"file found at {seed_urls_path}"
            )

    manifest = {
        "sourceLabel": "Akakce Daily Brochures",
        "listingUrl": args.listing_url,
        "generatedAt": generated_at.isoformat() + "Z",
        "brochureCount": len(brochures),
        "brochures": [brochure_to_json(brochure) for brochure in brochures],
    }
    output_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {len(brochures)} brochure manifests to {output_path}")


if __name__ == "__main__":
    main()
