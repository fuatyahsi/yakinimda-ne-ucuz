from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path


def build_parser() -> argparse.ArgumentParser:
    worker_root = Path(__file__).resolve().parent
    output_root = worker_root / "output"
    parser = argparse.ArgumentParser(
        description="Export brochure products into the app feed format."
    )
    parser.add_argument(
        "--source-manifest",
        default=str(output_root / "source_manifest.json"),
    )
    parser.add_argument(
        "--extracted-products",
        default=str(output_root / "extracted_products.json"),
    )
    parser.add_argument(
        "--output",
        default=str(output_root / "actueller_feed.json"),
    )
    return parser


def normalize_product(raw: dict, brochures_by_id: dict[str, dict]) -> dict | None:
    brochure_id = str(raw.get("brochureId") or raw.get("brochure_id") or "").strip()
    product_name = str(
        raw.get("productName") or raw.get("product_title") or raw.get("name") or ""
    ).strip()
    if not brochure_id or not product_name:
        return None

    brochure = brochures_by_id.get(brochure_id, {})
    price_value = raw.get("discountPrice", raw.get("price"))
    if price_value is None:
        return None

    try:
        price = float(price_value)
    except (TypeError, ValueError):
        return None

    product_id = str(
        raw.get("id")
        or f"{brochure_id}-{int(raw.get('pageIndex', raw.get('page_index', 1))):02d}-"
        f"{product_name.lower().replace(' ', '-')[:60]}"
    )

    image_url = raw.get("imageUrl") or raw.get("image_url")
    if not image_url:
        page_index = int(raw.get("pageIndex", raw.get("page_index", 1)))
        brochure_images = brochure.get("images", [])
        if 0 < page_index <= len(brochure_images):
            image_url = brochure_images[page_index - 1].get("image_url")

    return {
        "id": product_id,
        "brochureId": brochure_id,
        "brochureUrl": brochure.get("detail_url"),
        "marketName": raw.get("marketName") or brochure.get("market_name") or "Akakce",
        "pageIndex": int(raw.get("pageIndex", raw.get("page_index", 1))),
        "productName": product_name,
        "brand": raw.get("brand"),
        "discountPrice": price,
        "regularPrice": raw.get("regularPrice", raw.get("regular_price")),
        "currency": raw.get("currency", "TRY"),
        "confidence": float(raw.get("confidence", 0.0)),
        "imageUrl": image_url,
        "sourceLabel": raw.get("sourceLabel", "Akakce Worker Feed"),
        "validFrom": raw.get("validFrom") or brochure.get("valid_from"),
        "validUntil": raw.get("validUntil") or brochure.get("valid_until"),
        "ocrText": raw.get("ocrText") or raw.get("rawBlock"),
        "tags": list(raw.get("tags", [])),
    }


def main() -> None:
    args = build_parser().parse_args()
    source_manifest_path = Path(args.source_manifest).resolve()
    extracted_products_path = Path(args.extracted_products).resolve()
    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    manifest = json.loads(source_manifest_path.read_text(encoding="utf-8"))
    brochures = manifest.get("brochures", [])
    brochures_by_id = {
        str(brochure.get("brochure_id")): brochure
        for brochure in brochures
        if brochure.get("brochure_id")
    }

    extracted_items = []
    if extracted_products_path.exists():
        extracted_payload = json.loads(
            extracted_products_path.read_text(encoding="utf-8")
        )
        if isinstance(extracted_payload, dict):
            extracted_items = extracted_payload.get("items", [])
        elif isinstance(extracted_payload, list):
            extracted_items = extracted_payload

    items: list[dict] = []
    seen_ids: set[str] = set()
    for raw in extracted_items:
        if not isinstance(raw, dict):
            continue
        normalized = normalize_product(raw, brochures_by_id)
        if normalized is None:
            continue
        if normalized["id"] in seen_ids:
            continue
        seen_ids.add(normalized["id"])
        items.append(normalized)

    feed = {
        "sourceLabel": manifest.get("sourceLabel", "Akakce Daily Brochures"),
        "updatedAt": datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
        "brochureCount": len(brochures),
        "itemCount": len(items),
        "brochures": [
            {
                "id": brochure.get("brochure_id"),
                "detailUrl": brochure.get("detail_url"),
                "title": brochure.get("title"),
                "marketName": brochure.get("market_name"),
                "validFrom": brochure.get("valid_from"),
                "validUntil": brochure.get("valid_until"),
                "imageUrls": [
                    image.get("image_url")
                    for image in brochure.get("images", [])
                    if image.get("image_url")
                ],
            }
            for brochure in brochures
        ],
        "items": items,
    }
    output_path.write_text(
        json.dumps(feed, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {len(items)} feed items to {output_path}")


if __name__ == "__main__":
    main()
