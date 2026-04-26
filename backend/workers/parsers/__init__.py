"""Parser registry. Yeni market eklenince burada register edilir."""

from __future__ import annotations

from typing import Type

from .base import BaseParser


def _load_parser(module: str, cls_name: str) -> Type[BaseParser]:
    import importlib

    return getattr(importlib.import_module(f"parsers.{module}"), cls_name)


# market_id → parser class loader
_REGISTRY: dict[str, tuple[str, str]] = {
    "bim":                   ("bim",                   "BimParser"),
    "a101":                  ("a101",                  "A101Parser"),
    # 2026-04-26 cutover: sok artik sokmarket.com.tr direct (RSC).
    # Yedek (marketfiyati): ("sok_marketfiyati", "SokParser")
    "sok":                   ("sok_direct",            "SokDirectParser"),
    "migros":                ("migros",                "MigrosParser"),
    "carrefoursa":           ("carrefoursa",           "CarrefourSAParser"),
    "metro":                 ("metro",                 "MetroParser"),
    "hakmar":                ("hakmar",                "HakmarParser"),
    "hakmar-express":        ("hakmar_express",        "HakmarExpressParser"),
    "file":                  ("file_market",           "FileMarketParser"),
    "macrocenter":           ("macrocenter",           "MacrocenterParser"),
    "gimsa":                 ("gimsa",                 "GimsaParser"),
    "yunus":                 ("yunus",                 "YunusParser"),
    "cagdas":                ("cagdas",                "CagdasParser"),
    "onur":                  ("onur",                  "OnurParser"),
    "altunbilekler":         ("altunbilekler",         "AltunbileklerParser"),
    "bildirici":             ("bildirici",             "BildiriciParser"),
    "akyurt":                ("akyurt",                "AkyurtParser"),
    "bizim":                 ("bizim",                 "BizimParser"),
    "tarim-kredi":           ("tarim_kredi",           "TarimKrediParser"),
    "getir":                 ("getir",                 "GetirParser"),
    "yemeksepeti-market":    ("yemeksepeti_market",    "YemeksepetiMarketParser"),
    "migros-hemen":          ("migros_hemen",          "MigrosHemenParser"),
    "istegelsin":            ("istegelsin",            "IsteGelsinParser"),
    "trendyol-yemek-market": ("trendyol_market",       "TrendyolMarketParser"),
    "hepsiburada-hizli":     ("hepsiburada_hizli",     "HepsiburadaHizliParser"),
}


def get_parser(market_id: str) -> BaseParser:
    if market_id not in _REGISTRY:
        known = ", ".join(sorted(_REGISTRY))
        raise KeyError(f"Unknown market_id '{market_id}'. Known: {known}")
    module, cls_name = _REGISTRY[market_id]
    cls = _load_parser(module, cls_name)
    return cls()


def list_markets() -> list[str]:
    return sorted(_REGISTRY)
