"""Combined marketfiyati runner — tek API sweep, 6 market paralel yazim.

Neden ayri script?
    run_worker.py market basi tek parser cagirir. Her parser ayni marketfiyati
    keyword sweep'ini yapar — 6 market x 66 subcategory x ~4 sayfa =
    rate-limited API'de sasirtici israf. Bu script bir kere sweep yapar,
    her urun icin productDepotInfoList'i filtreleyip 6 marketin WorkerItem'i
    olarak fan-out eder.

Davranis:
    1. Markette target icin scrape_run ac.
    2. marketfiyati /api/v1/info/categories -> subcategory listesi.
    3. Her keyword icin pages=0..N, size=100 paginate.
    4. Her urun icin:
        a. REGISTRY_TO_MARKETFIYATI'daki her target market icin
           select_price_for_market (min strategy).
        b. Varsa WorkerItem olustur.
        c. find_or_create_product + insert_price + insert_campaign.
        d. Paralel olarak per-market cache'e ekle (-from-cache kurtarma).
    5. Her scrape_run'i success/partial/failed ile kapat.

Resilience:
    - Her batch sonunda per-market cache diske yazilir. Run cokerse
      kullanici `run_worker.py --market <X> --from-cache` ile yazmadigi
      kismi Supabase'e atabilir.
    - Transient HTTP hatalari cache hic kaybetmez — sadece Supabase yazimi
      duser, cache zaten yerel.

Kullanim:
    python backend/workers/run_marketfiyati.py                  # 6 market
    python backend/workers/run_marketfiyati.py --markets bim,a101
    python backend/workers/run_marketfiyati.py --max-keywords 3 # test
    python backend/workers/run_marketfiyati.py --dry-run        # Supabase yok
    python backend/workers/run_marketfiyati.py --delay 2.0      # politeness

Environment:
    SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (dry-run degilse)
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import requests  # noqa: E402

from core import (  # noqa: E402
    RunStats,
    SupabaseClient,
    WorkerItem,
    find_or_create_product,
    finish_scrape_run,
    insert_campaign,
    insert_price,
    start_scrape_run,
)
from parsers import get_parser  # noqa: E402
from parsers._marketfiyati import (  # noqa: E402
    MarketFiyatiClient,
    REGISTRY_TO_MARKETFIYATI,
    select_price_for_market,
)

_CACHE_DIR = _HERE / "cache"

# 6 market marketfiyati kapsami — registry'deki ID'lerle ayni.
DEFAULT_TARGETS: tuple[str, ...] = (
    "a101",
    "bim",
    "carrefoursa",
    "migros",
    "sok",
    "tarim-kredi",
)


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument(
        "--markets",
        default=",".join(DEFAULT_TARGETS),
        help=f"virgulle market_id listesi (default: {','.join(DEFAULT_TARGETS)})",
    )
    p.add_argument("--delay", type=float, default=1.5,
                   help="marketfiyati istekleri arasi gecikme (sn)")
    p.add_argument("--size", type=int, default=100,
                   help="sayfa basi urun (API limit: 100)")
    p.add_argument("--max-pages", type=int, default=None,
                   help="keyword basi max sayfa (test icin)")
    p.add_argument("--max-keywords", type=int, default=None,
                   help="toplam keyword limiti (test icin)")
    p.add_argument("--keywords", default=None,
                   help="virgulle ozel keyword listesi; yoksa categories endpoint")
    p.add_argument("--dry-run", action="store_true",
                   help="Supabase'e yazma, sadece sayac")
    p.add_argument("--no-cache", action="store_true",
                   help="Per-market cache dosyasi yazma")
    p.add_argument("--verbose", action="store_true",
                   help="marketfiyati client log'u gorsun")
    return p


def _resolve_targets(raw: str) -> list[tuple[str, str]]:
    """(market_id, market_adi) tuple listesi; dogrulama yapar."""
    out: list[tuple[str, str]] = []
    for token in raw.split(","):
        mid = token.strip()
        if not mid:
            continue
        if mid not in REGISTRY_TO_MARKETFIYATI:
            raise SystemExit(
                f"HATA: {mid!r} marketfiyati kapsaminda degil. "
                f"Desteklenen: {sorted(REGISTRY_TO_MARKETFIYATI)}"
            )
        out.append((mid, REGISTRY_TO_MARKETFIYATI[mid]))
    if not out:
        raise SystemExit("HATA: --markets bos.")
    return out


def _resolve_keywords(
    client: MarketFiyatiClient,
    raw: str | None,
    *,
    limit: int | None,
) -> list[str]:
    if raw:
        kws = [k.strip() for k in raw.split(",") if k.strip()]
    else:
        cats = client.get_categories()
        # Once main category adlari, sonra subcategory — genel -> spesifik.
        kws = []
        for c in cats:
            kws.append(c.name)
            kws.extend(c.subcategories)
    if limit is not None:
        kws = kws[: int(limit)]
    return kws


def run(args: argparse.Namespace) -> int:
    targets = _resolve_targets(args.markets)
    print(f"[mf] targets: {[m for m, _ in targets]}")

    mf_client = MarketFiyatiClient(
        delay_sec=args.delay,
        verbose=bool(args.verbose),
    )
    keywords = _resolve_keywords(mf_client, args.keywords, limit=args.max_keywords)
    print(f"[mf] {len(keywords)} keyword; delay={args.delay}s size={args.size}")

    # Per-market state
    per_market: dict[str, dict] = {}
    supabase: SupabaseClient | None = None
    if not args.dry_run:
        supabase = SupabaseClient.from_env()

    for market_id, market_adi in targets:
        parser = get_parser(market_id)
        state: dict = {
            "parser": parser,
            "market_adi": market_adi,
            "items": [],          # cache icin
            "stats": RunStats(),
            "run_id": None,
        }
        if supabase is not None:
            state["run_id"] = start_scrape_run(
                supabase,
                market_id=market_id,
                source_type=parser.source_type,
                source_label=parser.source_label,
            )
            print(f"[mf] {market_id}: scrape_run #{state['run_id']} acildi")
        per_market[market_id] = state

    # --------------------------------------------------------------
    # Sweep
    # --------------------------------------------------------------
    started = time.time()
    total_products_seen = 0
    total_writes = 0

    for kw_idx, kw in enumerate(keywords, start=1):
        kw_products = 0
        try:
            for product in mf_client.iter_products_for_keyword(
                kw, size=args.size, max_pages=args.max_pages
            ):
                kw_products += 1
                # ID bazli kesif — marketfiyati icinde dedupe iter_all_products'ta
                # yapiliyordu; burada keyword bazli pagination kullanıyoruz, yani
                # cross-keyword dedupe'u kendimiz yapmaliyiz.
                # Her market icin dedupe ayri tutuluyor — ayni urun 6 markete de
                # yazilabilir.
                for market_id, market_adi in targets:
                    state = per_market[market_id]
                    selected = select_price_for_market(product, market_adi)
                    if selected is None:
                        continue

                    parser = state["parser"]
                    item = parser._product_to_item(product, selected)
                    if item is None:
                        continue

                    # Per-market in-sweep dedupe: ayni product.id'yi bir daha
                    # yazma.
                    seen = state.setdefault("seen_product_ids", set())
                    pid = str(product.get("id") or "")
                    if pid and pid in seen:
                        continue
                    if pid:
                        seen.add(pid)

                    state["items"].append(item)
                    total_products_seen += 1

                    if supabase is not None:
                        try:
                            product_id = find_or_create_product(
                                supabase, item, parser.alias_source, state["stats"]
                            )
                            insert_price(
                                supabase, product_id, item, state["run_id"],
                                parser.source_label, state["stats"],
                            )
                            insert_campaign(
                                supabase, product_id, item, state["stats"]
                            )
                            total_writes += 1
                        except requests.HTTPError as err:
                            state["stats"].errors.append(
                                f"kw={kw!r} pid={pid}: HTTP {err}"
                            )
                        except Exception as err:  # pragma: no cover
                            state["stats"].errors.append(
                                f"kw={kw!r} pid={pid}: "
                                f"{type(err).__name__}: {err}"
                            )
        except Exception as err:
            print(f"[mf] keyword {kw!r} FAILED: {err}")

        elapsed = time.time() - started
        per_market_counts = {
            mid: len(state["items"]) for mid, state in per_market.items()
        }
        print(
            f"[mf] ({kw_idx}/{len(keywords)}) kw={kw!r} "
            f"raw={kw_products} total_writes={total_writes} "
            f"t={elapsed:.0f}s per_market={per_market_counts}"
        )

        # Per-market cache'i her keyword sonunda flush et (kurtarma icin)
        if not args.no_cache:
            _flush_caches(per_market)

    # --------------------------------------------------------------
    # Finalize
    # --------------------------------------------------------------
    if supabase is not None:
        for market_id, state in per_market.items():
            stats: RunStats = state["stats"]
            status = "success" if not stats.errors else (
                "partial" if stats.prices_added > 0 else "failed"
            )
            finish_scrape_run(supabase, state["run_id"], stats, status)
            print(
                f"[mf] {market_id}: run #{state['run_id']} -> {status}  "
                f"added={stats.products_added} matched={stats.products_matched} "
                f"prices={stats.prices_added} errors={len(stats.errors)}"
            )
            if stats.errors[:3]:
                for e in stats.errors[:3]:
                    print(f"    ! {e}")

    elapsed = time.time() - started
    print(f"[mf] TOPLAM: t={elapsed:.0f}s, toplam_writes={total_writes}")

    # Son kez cache yaz
    if not args.no_cache:
        _flush_caches(per_market)
        for mid in per_market:
            print(
                f"[mf] cache: {_cache_path(mid)} "
                f"({len(per_market[mid]['items'])} item)"
            )

    return 0


def _cache_path(market_id: str) -> Path:
    # run_worker.py --from-cache defaultu `{market}_default.json` okur.
    return _CACHE_DIR / f"{market_id}_default.json"


def _flush_caches(per_market: dict[str, dict]) -> None:
    _CACHE_DIR.mkdir(parents=True, exist_ok=True)
    now = datetime.now(timezone.utc).isoformat()
    for market_id, state in per_market.items():
        items: list[WorkerItem] = state["items"]
        payload = {
            "market_id": market_id,
            "mode": None,
            "scraped_at": now,
            "count": len(items),
            "source": "marketfiyati",
            "items": [asdict(it) for it in items],
        }
        _cache_path(market_id).write_text(
            json.dumps(payload, ensure_ascii=False),
            encoding="utf-8",
        )


if __name__ == "__main__":
    sys.exit(run(build_arg_parser().parse_args()))
