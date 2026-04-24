from __future__ import annotations

import argparse
import json
import re
import unicodedata
from datetime import date, datetime
from pathlib import Path
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

import fetch_sources as shared

BIM_BASE_URL = "https://www.bim.com.tr"
BIM_LISTING_URL = f"{BIM_BASE_URL}/Categories/680/afisler.aspx"
DEFAULT_TIMEOUT = 30

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

GROUP_LABELS = {
    1: "Akt\u00fcel",
    2: "\u0130ndirim",
    3: "Eve Teslim",
    4: "Bayram",
}

GROUP_ALIASES = {
    "aktuel urunler": "aktuel",
    "aktuel": "aktuel",
    "indirim": "indirim",
    "ramazan": "ramazan",
    "bayram": "bayram",
    "eve teslim": "eve teslim",
}


def build_parser() -> argparse.ArgumentParser:
    worker_root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Discover official B\u0130M brochure page images."
    )
    parser.add_argument("--listing-url", default=BIM_LISTING_URL)
    parser.add_argument("--max-brochures", type=int, default=18)
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


def normalize_url(url: str) -> str:
    if url.startswith("//"):
        return f"https:{url}"
    return urljoin(BIM_BASE_URL, url)


def normalize_text(value: str) -> str:
    translation = str.maketrans(
        {
            "\u0131": "i",
            "\u011f": "g",
            "\u00fc": "u",
            "\u015f": "s",
            "\u00f6": "o",
            "\u00e7": "c",
            "\u0130": "i",
            "\u011e": "g",
            "\u00dc": "u",
            "\u015e": "s",
            "\u00d6": "o",
            "\u00c7": "c",
        }
    )
    normalized = value.translate(translation).lower()
    normalized = unicodedata.normalize("NFKD", normalized)
    return "".join(char for char in normalized if not unicodedata.combining(char))


def slugify(value: str) -> str:
    normalized = normalize_text(value)
    normalized = re.sub(r"[^a-z0-9]+", "-", normalized)
    normalized = re.sub(r"-{2,}", "-", normalized)
    return normalized.strip("-")


def canonical_group_label(value: str) -> str:
    return GROUP_ALIASES.get(normalize_text(value), normalize_text(value))


def build_catalog_lookup_keys(group_label: str, title: str) -> list[tuple[str, str]]:
    group_key = canonical_group_label(group_label)
    title_key = normalize_text(title)
    keys = [(group_key, title_key)]

    stripped = re.sub(rf"\b{re.escape(group_key)}\b", " ", title_key).strip()
    stripped = re.sub(r"\s+", " ", stripped)
    if stripped and stripped != title_key:
        keys.append((group_key, stripped))
    return keys


def parse_date_window(label: str, default_year: int) -> tuple[date | None, date | None]:
    normalized = normalize_text(label)

    compact_range_match = re.search(r"(\d{1,2})\s*-\s*(\d{1,2})\s+([a-z]+)", normalized)
    if compact_range_match:
        start_day, end_day, month_name = compact_range_match.groups()
        start = build_date(default_year, month_name, start_day)
        end = build_date(default_year, month_name, end_day)
        return start, end

    range_match = re.search(r"(\d{1,2})\s+([a-z]+)\s*-\s*(\d{1,2})\s+([a-z]+)", normalized)
    if range_match:
        start_day, start_month, end_day, end_month = range_match.groups()
        start = build_date(default_year, start_month, start_day)
        end = build_date(default_year, end_month, end_day)
        return start, end

    single_match = re.search(r"(\d{1,2})\s+([a-z]+)", normalized)
    if single_match:
        day, month = single_match.groups()
        moment = build_date(default_year, month, day)
        return moment, moment

    return None, None


def build_date(year: int, month_name: str, day: str) -> date | None:
    month = TURKISH_MONTHS.get(month_name)
    if month is None:
        return None
    try:
        return date(year, month, int(day))
    except ValueError:
        return None


def extract_group_number(section: BeautifulSoup) -> int:
    classes = " ".join(section.get("class", []))
    match = re.search(r"\bgrup(\d+)\b", classes)
    if not match:
        return 1
    return int(match.group(1))


def collect_big_image_urls(section: BeautifulSoup) -> list[str]:
    urls: list[str] = []
    seen: set[str] = set()

    def add(raw: str | None) -> None:
        if not raw:
            return
        url = normalize_url(raw.strip())
        if url in seen:
            return
        seen.add(url)
        urls.append(url)

    download_anchor = section.select_one("a.download[href]")
    add(download_anchor.get("href") if download_anchor else None)

    for anchor in section.select("a.fancyboxImage[href]"):
        add(anchor.get("href"))

    for anchor in section.select("a.small[data-bigimg]"):
        add(anchor.get("data-bigimg"))

    return urls


def extract_bim_catalog_url_map(soup: BeautifulSoup) -> dict[tuple[str, str], str]:
    table = soup.select_one("div.subMenu.aktuelsubmenu table")
    if table is None:
        return {}

    headers = [
        canonical_group_label(cell.get_text(" ", strip=True))
        for cell in table.select("tr th.title")
    ]
    mapping: dict[tuple[str, str], str] = {}

    for row in table.select("tr")[1:]:
        for index, cell in enumerate(row.select("td.link")):
            anchor = cell.select_one("a[href]")
            if anchor is None or index >= len(headers):
                continue
            href = anchor.get("href", "").strip()
            label = anchor.get_text(" ", strip=True)
            if not href or not label:
                continue
            mapping[(headers[index], normalize_text(label))] = normalize_url(href)

    return mapping


def extract_bim_brochures(
    listing_html: str,
    *,
    listing_url: str,
    discovered_at: datetime,
) -> list[shared.BrochureSource]:
    soup = BeautifulSoup(listing_html, "html.parser")
    sections = soup.select("div.posterArea div.genelgrup")
    product_catalog_urls = extract_bim_catalog_url_map(soup)
    brochures: list[shared.BrochureSource] = []
    seen_ids: set[str] = set()

    for index, section in enumerate(sections, start=1):
        title_tag = section.select_one("a.subTabArea span.text")
        title = title_tag.get_text(" ", strip=True) if title_tag else ""
        image_urls = collect_big_image_urls(section)
        if not title or not image_urls:
            continue

        group_label = GROUP_LABELS.get(extract_group_number(section), "Akt\u00fcel")
        base_id = slugify(f"bim-{group_label}-{title}") or f"bim-{index:03d}"
        brochure_id = base_id
        dedupe_counter = 2
        while brochure_id in seen_ids:
            brochure_id = f"{base_id}-{dedupe_counter}"
            dedupe_counter += 1
        seen_ids.add(brochure_id)

        valid_from, valid_until = parse_date_window(title, discovered_at.year)
        images = [
            shared.BrochureImage(page_index=image_index, image_url=image_url)
            for image_index, image_url in enumerate(image_urls, start=1)
        ]

        catalog_url = None
        for lookup_key in build_catalog_lookup_keys(group_label, title):
            catalog_url = product_catalog_urls.get(lookup_key)
            if catalog_url:
                break

        brochures.append(
            shared.BrochureSource(
                brochure_id=brochure_id,
                detail_url=image_urls[0] or listing_url,
                title=f"{group_label} | {title}",
                market_name="B\u0130M",
                slug=brochure_id,
                discovered_at=discovered_at.isoformat(),
                catalog_url=catalog_url,
                valid_from=valid_from.isoformat() if valid_from else None,
                valid_until=valid_until.isoformat() if valid_until else None,
                image_count=len(images),
                images=images,
            )
        )

    return brochures


def main() -> None:
    args = build_parser().parse_args()

    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    images_root = Path(args.images_dir).resolve()

    session = requests.Session()
    session.headers.update(shared.DEFAULT_HEADERS)

    generated_at = datetime.utcnow().replace(microsecond=0)
    listing_html = shared.fetch_html(session, args.listing_url, args.timeout)
    brochures = extract_bim_brochures(
        listing_html,
        listing_url=args.listing_url,
        discovered_at=generated_at,
    )[: args.max_brochures]

    if args.download_images:
        brochures = [
            shared.download_images(
                session=session,
                brochure=brochure,
                images_root=images_root,
                timeout=args.timeout,
            )
            for brochure in brochures
        ]

    manifest = {
        "sourceLabel": "B\u0130M Resmi Afi\u015fler",
        "listingUrl": args.listing_url,
        "generatedAt": generated_at.isoformat() + "Z",
        "brochureCount": len(brochures),
        "brochures": [shared.brochure_to_json(brochure) for brochure in brochures],
    }
    output_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {len(brochures)} brochure manifests to {output_path}")


if __name__ == "__main__":
    main()
