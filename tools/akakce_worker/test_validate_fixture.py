from __future__ import annotations

import sys
import unittest
from pathlib import Path

WORKER_ROOT = Path(__file__).resolve().parent
if str(WORKER_ROOT) not in sys.path:
    sys.path.insert(0, str(WORKER_ROOT))

import validate_fixture


class ValidateFixtureTest(unittest.TestCase):
    def test_brochure_ids_for_fixture_filters_title_and_market(self) -> None:
        fixture = {
            "marketName": "BIM",
            "brochureTitleContains": "10 Mart Sali",
        }
        source_manifest = {
            "brochures": [
                {
                    "brochure_id": "bim-10-mart",
                    "title": "Aktuel | 10 Mart Sali",
                    "market_name": "BIM",
                },
                {
                    "brochure_id": "bim-13-mart",
                    "title": "Aktuel | 13 Mart Cuma",
                    "market_name": "BIM",
                },
            ]
        }

        brochure_ids = validate_fixture.brochure_ids_for_fixture(fixture, source_manifest)

        self.assertEqual({"bim-10-mart"}, brochure_ids)

    def test_match_fixture_products_uses_price_and_similarity(self) -> None:
        expected = [
            {"productName": "Dana Kangal Sucuk Torku 500 g", "price": 299.0},
            {"productName": "Tereyagi Torku 500 g", "price": 349.0},
        ]
        actual = [
            {"id": "1", "productName": "DANA KANGAL SUCUK", "discountPrice": 299.0},
            {"id": "2", "productName": "TEREYAGI", "discountPrice": 349.0},
            {"id": "3", "productName": "Ayran", "discountPrice": 14.5},
        ]

        matches, missing = validate_fixture.match_fixture_products(
            expected_products=expected,
            actual_items=actual,
            min_score=0.45,
        )

        self.assertEqual(2, len(matches))
        self.assertEqual([], missing)

    def test_filter_feed_items_returns_empty_when_brochure_ids_missing(self) -> None:
        feed = {
            "items": [
                {"brochureId": "bim-17-mart", "pageIndex": 1, "productName": "Ayran"},
            ]
        }

        items = validate_fixture.filter_feed_items(feed, set(), page_index=1)

        self.assertEqual([], items)


if __name__ == "__main__":
    unittest.main()
