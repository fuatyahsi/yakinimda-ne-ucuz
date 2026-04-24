from __future__ import annotations

import sys
import unittest
from pathlib import Path

WORKER_ROOT = Path(__file__).resolve().parent
if str(WORKER_ROOT) not in sys.path:
    sys.path.insert(0, str(WORKER_ROOT))

import market_sources


class ValidateAllFixturesTest(unittest.TestCase):
    def test_bim_has_registered_fixture_glob(self) -> None:
        self.assertEqual(
            "bim_*.json",
            market_sources.get_market_source("bim").fixture_glob,
        )

    def test_future_sources_do_not_require_fixtures_yet(self) -> None:
        self.assertIsNone(market_sources.get_market_source("a101").fixture_glob)
        self.assertIsNone(market_sources.get_market_source("sok").fixture_glob)
        self.assertIsNone(market_sources.get_market_source("migros").fixture_glob)


if __name__ == "__main__":
    unittest.main()
