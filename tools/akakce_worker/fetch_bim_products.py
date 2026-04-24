from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

import extract_items
import fetch_sources as shared

BIM_BASE_URL = "https://www.bim.com.tr"


def build_parser() -> argparse.ArgumentParser:
    worker_root = Path(__file__).resolve().parent
    output_root = worker_root / "output"
    parser = argparse.ArgumentParser(
        description="Extract BİM products from structured catalog pages with poster OCR fallback."
    )
    parser.add_argument(
        "--source-manifest",
        default=str(output_root / "source_manifest.json"),
    )
    parser.add_argument(
        "--output",
        default=str(output_root / "extracted_products.json"),
    )
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--max-brochures", type=int, default=24)
    parser.add_argument("--max-images-per-brochure", type=int, default=8)
    parser.add_argument(
        "--ocr-fallback-limit",
        type=int,
        default=12,
        help="Maximum poster-only OCR products to add per brochure.",
    )
    parser.add_argument(
        "--ocr-attempt-limit",
        type=int,
        default=24,
        help="Maximum OCR title attempts per brochure for poster fallback.",
    )
    parser.add_argument(
        "--enable-ocr-fallback",
        action="store_true",
        default=True,
        help="Use brochure images to add poster-only products missing from structured HTML.",
    )
    parser.add_argument(
        "--disable-ocr-fallback",
        action="store_false",
        dest="enable_ocr_fallback",
    )
    return parser


def normalize_url(url: str) -> str:
    if url.startswith("//"):
        return f"https:{url}"
    return urljoin(BIM_BASE_URL, url)


def normalize_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip()


def normalize_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value or "")
    normalized = "".join(char for char in normalized if not unicodedata.combining(char))
    normalized = normalized.replace("ı", "i").replace("İ", "i")
    normalized = normalized.lower()
    normalized = re.sub(r"[^a-z0-9]+", " ", normalized)
    return re.sub(r"\s+", " ", normalized).strip()


def tokenize_title(value: str) -> list[str]:
    tokens = [token for token in normalize_text(value).split(" ") if token]
    return [
        token
        for token in tokens
        if token not in {"adet", "gram", "gr", "kg", "ml", "lt", "l", "cc"}
    ]


def parse_price(major: str, minor: str) -> float | None:
    raw = f"{major}{minor}"
    cleaned = raw.replace(".", "").replace(",", ".")
    try:
        return float(cleaned)
    except ValueError:
        return None


def extract_image_url(product_node: BeautifulSoup) -> str | None:
    image = product_node.select_one(".imageArea img")
    if image is None:
        return None
    for attribute in ("src", "xsrc", "data-src"):
        value = image.get(attribute)
        if value:
            return normalize_url(value)
    return None


def extract_tags(product_node: BeautifulSoup) -> list[str]:
    tags: list[str] = []
    for item in product_node.select(".textArea li .text"):
        text = normalize_whitespace(item.get_text(" ", strip=True))
        if text:
            tags.append(text)
    return tags


def structured_product_from_node(
    node: BeautifulSoup,
    *,
    index: int,
    brochure_id: str,
    brochure_url: str,
    market_name: str,
    valid_from: str | None,
    valid_until: str | None,
) -> dict | None:
    classes = set(node.get("class", []))
    if "justImage" in classes:
        return None

    title_tag = node.select_one(".descArea .title")
    if title_tag is None:
        return None

    title = normalize_whitespace(title_tag.get_text(" ", strip=True))
    if not title:
        return None

    major_tag = node.select_one(".priceArea .text.quantify")
    minor_tag = node.select_one(".priceArea .kusurArea .number")
    if major_tag is None:
        return None

    price = parse_price(
        normalize_whitespace(major_tag.get_text(" ", strip=True)),
        normalize_whitespace(minor_tag.get_text(" ", strip=True)) if minor_tag else "00",
    )
    if price is None:
        return None

    detail_anchor = node.select_one(".imageArea a[href]")
    detail_url = normalize_url(detail_anchor.get("href")) if detail_anchor else brochure_url
    image_url = extract_image_url(node)
    brand_tag = node.select_one(".descArea .subTitle")
    brand = normalize_whitespace(brand_tag.get_text(" ", strip=True)) if brand_tag else ""

    return {
        "id": f"{brochure_id}-p{index:03d}",
        "brochureId": brochure_id,
        "brochureUrl": brochure_url,
        "marketName": market_name,
        "pageIndex": 1,
        "productName": title,
        "brand": brand or None,
        "discountPrice": price,
        "currency": "TRY",
        "confidence": 1.0,
        "imageUrl": image_url,
        "detailUrl": detail_url,
        "sourceLabel": "BİM Structured Catalog",
        "validFrom": valid_from,
        "validUntil": valid_until,
        "ocrText": title,
        "tags": extract_tags(node),
    }


def extract_products_from_html(
    html: str,
    *,
    brochure_id: str,
    brochure_url: str,
    market_name: str,
    valid_from: str | None,
    valid_until: str | None,
) -> list[dict]:
    soup = BeautifulSoup(html, "html.parser")
    items: list[dict] = []

    for index, node in enumerate(soup.select(".productArea .product"), start=1):
        item = structured_product_from_node(
            node,
            index=index,
            brochure_id=brochure_id,
            brochure_url=brochure_url,
            market_name=market_name,
            valid_from=valid_from,
            valid_until=valid_until,
        )
        if item is not None:
            items.append(item)

    return items


def title_similarity(left: str, right: str) -> float:
    left_tokens = tokenize_title(left)
    right_tokens = tokenize_title(right)
    if not left_tokens or not right_tokens:
        return 0.0

    left_set = set(left_tokens)
    right_set = set(right_tokens)
    overlap = len(left_set & right_set)
    union = len(left_set | right_set)
    jaccard = overlap / union if union else 0.0

    left_text = " ".join(left_tokens)
    right_text = " ".join(right_tokens)
    contains = 1.0 if left_text in right_text or right_text in left_text else 0.0
    return max(jaccard, contains)


def looks_like_product_name(title: str) -> bool:
    cleaned = normalize_whitespace(title)
    if len(cleaned) < 4:
        return False

    alnum_count = sum(1 for char in cleaned if char.isalnum())
    alpha_count = sum(1 for char in cleaned if char.isalpha())
    if alnum_count < 4 or alpha_count < 3:
        return False

    if alpha_count / max(len(cleaned.replace(" ", "")), 1) < 0.45:
        return False

    tokens = tokenize_title(cleaned)
    if not tokens:
        return False

    return any(len(token) >= 3 for token in tokens)


def is_duplicate_candidate(candidate: dict, existing_items: list[dict]) -> bool:
    candidate_name = str(candidate.get("productName") or "")
    try:
        candidate_price = float(candidate.get("discountPrice"))
    except (TypeError, ValueError):
        return True

    for existing in existing_items:
        try:
            existing_price = float(existing.get("discountPrice"))
        except (TypeError, ValueError):
            continue
        if abs(existing_price - candidate_price) > 0.01:
            continue
        similarity = title_similarity(candidate_name, str(existing.get("productName") or ""))
        if similarity >= 0.45:
            return True
    return False


def build_price_counter(items: list[dict]) -> Counter[float]:
    prices: Counter[float] = Counter()
    for item in items:
        try:
            prices[round(float(item.get("discountPrice")), 2)] += 1
        except (TypeError, ValueError):
            continue
    return prices


def build_ocr_fallback_item(
    *,
    brochure: dict,
    image: dict,
    page_index: int,
    fallback_index: int,
    title: str,
    price: float,
    product_text: str,
    price_text: str,
    confidence: float,
) -> dict:
    brochure_id = str(brochure.get("brochure_id", "unknown"))
    return {
        "id": f"{brochure_id}-ocr-p{page_index:02d}-{fallback_index:03d}",
        "brochureId": brochure_id,
        "brochureUrl": brochure.get("catalog_url") or brochure.get("detail_url"),
        "marketName": brochure.get("market_name") or "BİM",
        "pageIndex": page_index,
        "productName": title,
        "brand": title.split(" ", 1)[0] if title else None,
        "discountPrice": price,
        "currency": "TRY",
        "confidence": round(confidence, 4),
        "imageUrl": image.get("image_url"),
        "detailUrl": brochure.get("catalog_url") or brochure.get("detail_url"),
        "sourceLabel": "BİM Poster OCR Fallback",
        "validFrom": brochure.get("valid_from"),
        "validUntil": brochure.get("valid_until"),
        "ocrText": normalize_whitespace(product_text),
        "tags": ["poster-ocr-fallback", "bim-hybrid"],
        "priceOcrText": normalize_whitespace(price_text),
    }


def clip_box(
    *,
    x: int,
    y: int,
    width: int,
    height: int,
    image_width: int,
    image_height: int,
) -> tuple[int, int, int, int] | None:
    left = max(0, x)
    top = max(0, y)
    right = min(image_width, x + width)
    bottom = min(image_height, y + height)
    if right - left < 18 or bottom - top < 18:
        return None
    return left, top, right - left, bottom - top


def build_title_crop_boxes(
    *,
    x: int,
    y: int,
    w: int,
    h: int,
    image_width: int,
    image_height: int,
) -> list[tuple[int, int, int, int]]:
    candidates = [
        clip_box(
            x=int(x - w * 0.25),
            y=int(y - h * 3.2),
            width=int(w * 2.8),
            height=int(h * 2.7),
            image_width=image_width,
            image_height=image_height,
        ),
        clip_box(
            x=int(x - w * 2.7),
            y=int(y - h * 1.0),
            width=int(w * 2.5),
            height=int(h * 1.7),
            image_width=image_width,
            image_height=image_height,
        ),
        clip_box(
            x=int(x + w * 0.85),
            y=int(y - h * 1.0),
            width=int(w * 2.4),
            height=int(h * 1.8),
            image_width=image_width,
            image_height=image_height,
        ),
    ]
    unique: list[tuple[int, int, int, int]] = []
    for candidate in candidates:
        if candidate is None or candidate in unique:
            continue
        unique.append(candidate)
    return unique


def read_best_title_from_boxes(
    *,
    cv2,
    reader,
    image,
    boxes: list[tuple[int, int, int, int]],
) -> tuple[str, str, float]:
    best_title = ""
    best_raw = ""
    best_score = 0.0

    for bx, by, bw, bh in boxes:
        crop = image[by : by + bh, bx : bx + bw]
        if not extract_items.should_ocr_crop(
            cv2,
            crop,
            min_stddev=16.0,
            min_foreground_ratio=0.01,
        ):
            continue

        raw_text, confidence = extract_items.run_reader(
            reader,
            extract_items.prepare_crop_for_ocr(cv2, crop),
        )
        title = extract_items.clean_title(raw_text)
        if not looks_like_product_name(title):
            continue

        score = confidence + min(len(tokenize_title(title)) * 0.08, 0.4)
        if score > best_score:
            best_title = title
            best_raw = raw_text
            best_score = score

    return best_title, best_raw, best_score


def extract_ocr_fallback_items(
    *,
    brochure: dict,
    structured_items: list[dict],
    max_images_per_brochure: int,
    ocr_fallback_limit: int,
    ocr_attempt_limit: int,
    cv2,
    reader,
) -> tuple[list[dict], dict]:
    local_images = [
        image for image in brochure.get("images", [])[:max_images_per_brochure] if image.get("local_path")
    ]
    if not local_images:
        return [], {
            "brochureId": brochure.get("brochure_id"),
            "structuredCount": len(structured_items),
            "posterPriceBoxCount": 0,
            "ocrFallbackCount": 0,
        }

    remaining_structured_prices = build_price_counter(structured_items)
    fallback_items: list[dict] = []
    poster_price_box_count = 0
    ocr_attempts = 0

    for image in local_images:
        if len(fallback_items) >= ocr_fallback_limit or ocr_attempts >= ocr_attempt_limit:
            break

        image_path = str(image.get("local_path"))
        bgr = cv2.imread(image_path)
        if bgr is None:
            continue

        page_index = int(image.get("page_index", 1))
        page_height, page_width = bgr.shape[:2]
        price_boxes = extract_items.detect_price_boxes(cv2, bgr)
        poster_price_box_count += len(price_boxes)

        candidate_boxes: list[tuple[tuple[int, int, int, int], float, str, float]] = []
        for (x, y, w, h) in sorted(price_boxes, key=lambda box: (box[1], box[0])):
            price_crop = bgr[y : y + h, x : x + w]
            if not extract_items.should_ocr_crop(
                cv2,
                price_crop,
                min_stddev=14.0,
                min_foreground_ratio=0.02,
            ):
                continue

            price_text, price_confidence = extract_items.run_reader(
                reader,
                extract_items.prepare_crop_for_ocr(cv2, price_crop),
            )
            price = extract_items.parse_price(price_text)
            if price is None or price_confidence < 0.35:
                continue

            price_key = round(price, 2)
            if remaining_structured_prices[price_key] > 0:
                remaining_structured_prices[price_key] -= 1
                continue

            candidate_boxes.append(((x, y, w, h), price, price_text, price_confidence))

        for fallback_index, (box, price, price_text, price_confidence) in enumerate(
            candidate_boxes,
            start=1,
        ):
            if len(fallback_items) >= ocr_fallback_limit or ocr_attempts >= ocr_attempt_limit:
                break

            x, y, w, h = box
            title_boxes = build_title_crop_boxes(
                x=x,
                y=y,
                w=w,
                h=h,
                image_width=page_width,
                image_height=page_height,
            )
            if not title_boxes:
                continue

            ocr_attempts += 1
            title, product_text, title_score = read_best_title_from_boxes(
                cv2=cv2,
                reader=reader,
                image=bgr,
                boxes=title_boxes,
            )
            if not title:
                continue

            candidate = build_ocr_fallback_item(
                brochure=brochure,
                image=image,
                page_index=page_index,
                fallback_index=fallback_index,
                title=title,
                price=price,
                product_text=product_text,
                price_text=price_text,
                confidence=(title_score + price_confidence) / 2,
            )
            if is_duplicate_candidate(candidate, structured_items + fallback_items):
                continue
            fallback_items.append(candidate)

    stats = {
        "brochureId": brochure.get("brochure_id"),
        "structuredCount": len(structured_items),
        "posterPriceBoxCount": poster_price_box_count,
        "ocrFallbackCount": len(fallback_items),
    }
    return fallback_items, stats


def main() -> None:
    args = build_parser().parse_args()
    source_manifest_path = Path(args.source_manifest).resolve()
    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    session = requests.Session()
    session.headers.update(shared.DEFAULT_HEADERS)

    manifest = json.loads(source_manifest_path.read_text(encoding="utf-8"))
    brochures = manifest.get("brochures", [])[: args.max_brochures]

    extracted_items: list[dict] = []
    brochure_stats: list[dict] = []
    cv2 = None
    reader = None
    if args.enable_ocr_fallback:
        cv2 = extract_items.ensure_cv_stack()
        reader = extract_items.ensure_rapidocr()

    for brochure in brochures:
        catalog_url = brochure.get("catalog_url") or brochure.get("detail_url")
        if not catalog_url:
            continue
        html = shared.fetch_html(session, catalog_url, args.timeout)
        structured_items = extract_products_from_html(
            html,
            brochure_id=str(brochure.get("brochure_id", "")),
            brochure_url=str(catalog_url),
            market_name=str(brochure.get("market_name") or "BİM"),
            valid_from=brochure.get("valid_from"),
            valid_until=brochure.get("valid_until"),
        )
        extracted_items.extend(structured_items)

        stats = {
            "brochureId": brochure.get("brochure_id"),
            "structuredCount": len(structured_items),
            "posterPriceBoxCount": 0,
            "ocrFallbackCount": 0,
        }
        if args.enable_ocr_fallback:
            fallback_items, stats = extract_ocr_fallback_items(
                brochure=brochure,
                structured_items=structured_items,
                max_images_per_brochure=args.max_images_per_brochure,
                ocr_fallback_limit=args.ocr_fallback_limit,
                ocr_attempt_limit=args.ocr_attempt_limit,
                cv2=cv2,
                reader=reader,
            )
            extracted_items.extend(fallback_items)
        brochure_stats.append(stats)

    payload = {
        "itemCount": len(extracted_items),
        "structuredItemCount": sum(stat["structuredCount"] for stat in brochure_stats),
        "ocrFallbackItemCount": sum(stat["ocrFallbackCount"] for stat in brochure_stats),
        "brochureStats": brochure_stats,
        "items": extracted_items,
    }
    output_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {len(extracted_items)} extracted product candidates to {output_path}")


if __name__ == "__main__":
    main()
