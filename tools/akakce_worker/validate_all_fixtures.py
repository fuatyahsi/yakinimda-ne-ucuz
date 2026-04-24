from __future__ import annotations

import argparse
from pathlib import Path

import market_sources
import validate_fixture


def build_parser() -> argparse.ArgumentParser:
    worker_root = Path(__file__).resolve().parent
    output_root = worker_root / "output"
    parser = argparse.ArgumentParser(
        description="Run all brochure fixture validations and fail if coverage drops below threshold."
    )
    parser.add_argument(
        "--source",
        default="bim",
        help="Market source id. Used to resolve default fixture glob from market_sources.py.",
    )
    parser.add_argument(
        "--fixtures-dir",
        default=str(worker_root / "fixtures"),
    )
    parser.add_argument(
        "--fixture-glob",
        default="",
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
    )
    parser.add_argument(
        "--min-coverage",
        type=float,
        default=1.0,
        help="Minimum required match coverage per fixture. 1.0 means all expected products must match.",
    )
    parser.add_argument(
        "--fail-on-empty-match",
        action="store_true",
        help=(
            "Fail when none of the registered fixtures match brochures in the "
            "current source manifest. By default this exits successfully and "
            "treats the run as skipped."
        ),
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    fixtures_dir = Path(args.fixtures_dir).resolve()
    source_manifest = validate_fixture.load_json(Path(args.source_manifest).resolve())
    feed = validate_fixture.load_json(Path(args.feed).resolve())

    fixture_glob = args.fixture_glob
    if not fixture_glob:
        try:
            fixture_glob = market_sources.get_market_source(args.source).fixture_glob or ""
        except KeyError:
            fixture_glob = ""
    if not fixture_glob:
        raise SystemExit(
            f"No fixture glob is registered for source '{args.source}'. "
            "Pass --fixture-glob explicitly."
        )

    fixture_paths = sorted(fixtures_dir.glob(fixture_glob))
    if not fixture_paths:
        raise SystemExit(f"No fixture files found in {fixtures_dir} matching {fixture_glob}")

    failures: list[str] = []
    validated_count = 0
    print("=== Fixture Validation Matrix ===")
    print(f"Source: {args.source}")
    for fixture_path in fixture_paths:
        fixture = validate_fixture.load_json(fixture_path)
        brochure_ids = validate_fixture.brochure_ids_for_fixture(fixture, source_manifest)
        if not brochure_ids:
            print(
                f"- {fixture_path.name}: skipped "
                "(matching brochure is not present in the current source manifest)"
            )
            continue

        validated_count += 1
        page_index = fixture.get("pageIndex")
        actual_items = validate_fixture.filter_feed_items(feed, brochure_ids, page_index)
        expected_products = list(fixture.get("products", []))
        matches, missing = validate_fixture.match_fixture_products(
            expected_products=expected_products,
            actual_items=actual_items,
            min_score=args.min_score,
        )
        coverage = len(matches) / max(len(expected_products), 1)
        print(
            f"- {fixture_path.name}: matched={len(matches)}/{len(expected_products)} "
            f"coverage={coverage:.1%} brochure_ids={','.join(sorted(brochure_ids)) or '-'}"
        )
        if coverage < args.min_coverage:
            failures.append(f"{fixture_path.name} ({coverage:.1%})")
            if missing:
                print("  Missing:")
                for item in missing:
                    print(f"  - {item['productName']} | {item['price']}")

    if validated_count == 0:
        message = (
            "No registered fixtures matched brochures in the current source "
            "manifest. Treating fixture validation as skipped."
        )
        if args.fail_on_empty_match:
            raise SystemExit(message)
        print(message)
        return

    if failures:
        raise SystemExit(
            "Fixture coverage below threshold for: " + ", ".join(failures)
        )


if __name__ == "__main__":
    main()
