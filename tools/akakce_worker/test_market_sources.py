from __future__ import annotations

import unittest

import market_sources


class MarketSourcesTest(unittest.TestCase):
    def test_bim_source_is_implemented_and_fixture_backed(self) -> None:
        source = market_sources.get_market_source("bim")

        self.assertEqual("implemented", source.status)
        self.assertEqual("official-html+images", source.discovery_mode)
        self.assertEqual("bim_*.json", source.fixture_glob)

    def test_future_market_sources_are_registered(self) -> None:
        self.assertIn("a101", market_sources.MARKET_SOURCES)
        self.assertIn("sok", market_sources.MARKET_SOURCES)
        self.assertIn("migros", market_sources.MARKET_SOURCES)
        self.assertTrue(
            all(
                market_sources.MARKET_SOURCES[source_id].status == "discovery_pending"
                for source_id in ("a101", "sok", "migros")
            )
        )


if __name__ == "__main__":
    unittest.main()
