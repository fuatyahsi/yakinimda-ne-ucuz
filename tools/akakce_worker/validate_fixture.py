from __future__ import annotations

import argparse
import json
from pathlib import Path

import fetch_bim_products


def build_parser() -> argparse.ArgumentParser:
    worker_root = Path(__file__).resolve().parent
    output_root = worker_root / "output"
    parser = argparse.ArgumentParser(
        description="Validate extracted market feed items against a manually curated brochure fixture."
    )
    parser.add_argument(
        "--fixture",
        default=str(worker_root / "fixtures" / "bim_2026_03_10_dairy_page.json"),
    )
    parser.add_argument(
        "--source-manifest",
        default=str(output_root / "source_manifest.json"),
    )
    parser.add_argument(
        "--feed",
        default=str(output_root / "actueller_feed.json"),
    )
    parser.add_argument(
        "--min-score",
        type=float,
        default=0.45,
        help="Minimum title similarity score for a price-matched item to count as a match.",
    )
    return parser


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def brochure_ids_for_fixture(fixture: dict, source_manifest: dict) -> set[str]:
    title_filter = fetch_bim_products.normalize_text(
        str(fixture.get("brochureTitleContains") or "").strip()
    )
    market_name = fetch_bim_products.normalize_text(
        str(fixture.get("marketName") or "").strip()
    )
    brochure_ids: set[str] = set()

    for brochure in source_manifest.get("brochures", []):
        brochure_title = fetch_bim_products.normalize_text(
            str(brochure.get("title") or "")
        )
        brochure_market = fetch_bim_products.normalize_text(
            str(brochure.get("market_name") or "")
        )
        if title_filter and title_filter not in brochure_title:
            continue
        if market_name and market_name not in brochure_market:
            continue
        brochure_ids.add(str(brochure.get("brochure_id")))

    return brochure_ids


def filter_feed_items(feed: dict, brochure_ids: set[str], page_index: int | None) -> list[dict]:
    if not brochure_ids:
        return []

    items: list[dict] = []
    for item in feed.get("items", []):
        if brochure_ids and str(item.get("brochureId")) not in brochure_ids:
            continue
        if page_index is not None and int(item.get("pageIndex", 0) or 0) != page_index:
            continue
        items.append(item)
    return items


def match_fixture_products(
    *,
    expected_products: list[dict],
    actual_items: list[dict],
    min_score: float,
) -> tuple[list[dict], list[dict]]:
    available = list(actual_items)
    matches: list[dict] = []
    missing: list[dict] = []

    for expected in expected_products:
        expected_name = str(expected.get("productName") or "")
        expected_price = float(expected.get("price"))
        best_index = -1
        best_score = 0.0

        for index, actual in enumerate(available):
            try:
                actual_price = float(actual.get("discountPrice"))
            except (TypeError, ValueError):
                continue
            if abs(actual_price - expected_price) > 0.01:
                continue

            similarity = fetch_bim_products.title_similarity(
                expected_name,
                str(actual.get("productName") or ""),
            )
            if similarity > best_score:
                best_score = similarity
                best_index = index

        if best_index >= 0 and best_score >= min_score:
            actual = available.pop(best_index)
            matches.append(
                {
                    "expected": expected,
                    "actual": actual,
                    "score": round(best_score, 4),
                }
            )
        else:
            missing.append(expected)

    return matches, missing


def main() -> None:
    args = build_parser().parse_args()

    fixture = load_json(Path(args.fixture).resolve())
    source_manifest = load_json(Path(args.source_manifest).resolve())
    feed = load_json(Path(args.feed).resolve())

    brochure_ids = brochure_ids_for_fixture(fixture, source_manifest)
    page_index = fixture.get("pageIndex")
    actual_items = filter_feed_items(feed, brochure_ids, page_index)
    expected_products = list(fixture.get("products", []))

    matches, missing = match_fixture_products(
        expected_products=expected_products,
        actual_items=actual_items,
        min_score=args.min_score,
    )

    coverage = len(matches) / max(len(expected_products), 1)
    print("=== Fixture Validation ===")
    print(f"Fixture: {Path(args.fixture).name}")
    print(f"Brochure ids: {', '.join(sorted(brochure_ids)) or '-'}")
    print(f"Expected products: {len(expected_products)}")
    print(f"Actual filtered items: {len(actual_items)}")
    print(f"Matched products: {len(matches)}")
    print(f"Coverage: {coverage:.1%}")

    if missing:
        print("Missing:")
        for item in missing:
            print(f"- {item['productName']} | {item['price']}")

    unmatched_actual = [
        item for item in actual_items
        if not any(match["actual"].get("id") == item.get("id") for match in matches)
    ]
    if unmatched_actual:
        print("Unmatched actual items:")
        for item in unmatched_actual[:20]:
            print(f"- {item.get('productName')} | {item.get('discountPrice')}")


if __name__ == "__main__":
    main()
