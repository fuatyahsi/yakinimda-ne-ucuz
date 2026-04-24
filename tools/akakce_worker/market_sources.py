from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class MarketSourceDefinition:
    source_id: str
    label: str
    official_domain: str
    official_listing_url: str | None
    status: str
    discovery_mode: str
    notes: str
    fixture_glob: str | None = None


MARKET_SOURCES: dict[str, MarketSourceDefinition] = {
    "bim": MarketSourceDefinition(
        source_id="bim",
        label="BİM Resmi Afişler",
        official_domain="https://www.bim.com.tr",
        official_listing_url="https://www.bim.com.tr/Categories/680/afisler.aspx",
        status="implemented",
        discovery_mode="official-html+images",
        notes="Structured aktuel pages are validated with brochure fixtures.",
        fixture_glob="bim_*.json",
    ),
    "a101": MarketSourceDefinition(
        source_id="a101",
        label="A101 Resmi Kaynak",
        official_domain="https://www.a101.com.tr",
        official_listing_url="https://www.a101.com.tr/aldin-aldin/",
        status="discovery_pending",
        discovery_mode="official-source-pending",
        notes="Official landing page candidate registered; adapter and fixtures are pending validation.",
    ),
    "sok": MarketSourceDefinition(
        source_id="sok",
        label="ŞOK Resmi Kaynak",
        official_domain="https://www.sokmarket.com.tr",
        official_listing_url="https://www.sokmarket.com.tr/ekstra",
        status="discovery_pending",
        discovery_mode="official-source-pending",
        notes="Official domain registered; brochure/category discovery still needs validation.",
    ),
    "migros": MarketSourceDefinition(
        source_id="migros",
        label="Migros Resmi Kaynak",
        official_domain="https://www.migros.com.tr",
        official_listing_url="https://www.migros.com.tr/kampanyalar",
        status="discovery_pending",
        discovery_mode="official-source-pending",
        notes="Campaign entry point is known; product-source mapping and fixtures are pending validation.",
    ),
}


def get_market_source(source_id: str) -> MarketSourceDefinition:
    try:
        return MARKET_SOURCES[source_id]
    except KeyError as error:
        raise KeyError(f"Unknown market source: {source_id}") from error


def implemented_market_sources() -> list[MarketSourceDefinition]:
    return [
        source
        for source in MARKET_SOURCES.values()
        if source.status == "implemented"
    ]
