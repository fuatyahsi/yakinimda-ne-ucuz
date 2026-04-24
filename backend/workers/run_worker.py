"""Generic CLI — hangi marketi çekeceğimizi --market ile seçer.

Örnekler:
    # BİM fixture'dan Supabase'e yaz:
    python backend/workers/run_worker.py \\
        --market bim \\
        --fixture tools/akakce_worker/output/extracted_products.json

    # BİM fixture'ını dry-run ile test et:
    python backend/workers/run_worker.py --market bim \\
        --fixture tools/akakce_worker/output/extracted_products.json \\
        --dry-run

    # Canlı fetch (implemented parser'larda):
    python backend/workers/run_worker.py --market bim --live

    # Desteklenen marketleri listele:
    python backend/workers/run_worker.py --list

Environment:
    SUPABASE_URL
    SUPABASE_SERVICE_ROLE_KEY
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
    SupabaseClient,
    RunStats,
    WorkerItem,
    find_or_create_product,
    finish_scrape_run,
    insert_campaign,
    insert_price,
    start_scrape_run,
)
from parsers import get_parser, list_markets  # noqa: E402


# ---------------------------------------------------------------------
# On-disk scrape cache
# ---------------------------------------------------------------------
# Her canli fetch sonucu diskte JSON olarak saklanir. Boylece Supabase
# yazim asamasi patlarsa (network, paused project, transient 5xx),
# bir sonraki run `--from-cache` ile ayni item'lari A101'e tekrar
# gitmeden dogrudan Supabase'e yazabilir.
_CACHE_DIR = _HERE / "cache"


def _cache_path(market_id: str, mode: str | None) -> Path:
    suffix = mode or "default"
    return _CACHE_DIR / f"{market_id}_{suffix}.json"


def _save_cache(
    path: Path,
    *,
    market_id: str,
    mode: str | None,
    items: list[WorkerItem],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "market_id": market_id,
        "mode": mode,
        "scraped_at": datetime.now(timezone.utc).isoformat(),
        "count": len(items),
        "items": [asdict(it) for it in items],
    }
    path.write_text(
        json.dumps(payload, ensure_ascii=False),
        encoding="utf-8",
    )


def _load_cache(path: Path) -> tuple[list[WorkerItem], str, str | None]:
    data = json.loads(path.read_text(encoding="utf-8"))
    items = [WorkerItem(**row) for row in data.get("items", [])]
    return items, data.get("scraped_at", "?"), data.get("mode")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generic market worker — parser → Supabase"
    )
    parser.add_argument("--market", help="market_id (ör. bim, a101, sok)")
    parser.add_argument(
        "--fixture",
        help="yerel fixture JSON (parser.read_fixture)",
    )
    parser.add_argument(
        "--live",
        action="store_true",
        help="parser.fetch_items() kullan (implemented parser gerekir)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Supabase'e yazma, sadece özet bas",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="maksimum item sayısı (test için)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="desteklenen market_id'leri listele",
    )
    parser.add_argument(
        "--mode",
        default=None,
        help=(
            "Parser'a aktarılan fetch modu (örn. A101 için 'campaign', "
            "'catalog' veya 'all'). Parser destekliyorsa kullanılır."
        ),
    )
    parser.add_argument(
        "--max-urls",
        type=int,
        default=None,
        help="catalog/sitemap bazlı parser'lar için URL sayısı limiti (test)",
    )
    parser.add_argument(
        "--from-cache",
        action="store_true",
        help=(
            "Canlı fetch yerine en son saved cache'ten oku "
            "(backend/workers/cache/<market>_<mode>.json). "
            "Supabase yazımı önceki run'da patladıysa kurtarıcı."
        ),
    )
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Canlı fetch sonrası cache'e yazma (nadir; genelde bırak).",
    )
    return parser


def run(args: argparse.Namespace) -> int:
    if args.list:
        print("Desteklenen marketler (module → status):")
        for market_id in list_markets():
            try:
                parser = get_parser(market_id)
            except Exception as error:
                print(f"  ! {market_id}: LOAD ERROR — {error}")
                continue
            print(f"  {market_id:22s}  status={parser.status:18s}"
                  f"  type={parser.source_type}")
        return 0

    if not args.market:
        print("HATA: --market gereklidir (veya --list).", file=sys.stderr)
        return 2

    parser = get_parser(args.market)
    print(f"[run_worker] market={parser.market_id}  status={parser.status}")

    # Item kaynağını belirle
    cache_path = _cache_path(parser.market_id, args.mode)
    if args.from_cache:
        if not cache_path.exists():
            print(
                f"HATA: cache bulunamadi: {cache_path}",
                file=sys.stderr,
            )
            return 2
        items, scraped_at, cached_mode = _load_cache(cache_path)
        kind = "cache"
        print(
            f"[run_worker] cache: {len(items)} item yuklendi "
            f"(scraped_at={scraped_at}, mode={cached_mode}, "
            f"path={cache_path})"
        )
    elif args.fixture:
        items_iter = parser.read_fixture(args.fixture)
        items = list(items_iter)
        kind = "fixture"
        print(f"[run_worker] {kind}: {len(items)} item yüklendi")
    elif args.live:
        fetch_kwargs: dict = {}
        if args.mode:
            fetch_kwargs["mode"] = args.mode
        if args.max_urls is not None:
            fetch_kwargs["max_urls"] = args.max_urls
        try:
            items_iter = parser.fetch_items(**fetch_kwargs)
        except NotImplementedError as error:
            print(f"[run_worker] {error}", file=sys.stderr)
            return 3
        kind = "live"
        if fetch_kwargs:
            kw_summary = ", ".join(f"{k}={v}" for k, v in fetch_kwargs.items())
            print(f"[run_worker] fetch_items kwargs: {kw_summary}")
        items = list(items_iter)
        print(f"[run_worker] {kind}: {len(items)} item yüklendi")
        # Cache'e yaz — Supabase patlarsa kurtarici olsun.
        if items and not args.no_cache:
            try:
                _save_cache(
                    cache_path,
                    market_id=parser.market_id,
                    mode=args.mode,
                    items=items,
                )
                print(f"[run_worker] cache yazildi: {cache_path}")
            except Exception as cache_err:
                print(
                    f"[run_worker] cache yazilamadi (ignore): {cache_err}",
                    file=sys.stderr,
                )
    else:
        print(
            "HATA: --fixture, --live veya --from-cache belirt.",
            file=sys.stderr,
        )
        return 2

    if args.limit:
        items = items[: args.limit]

    if args.dry_run:
        for item in items[:5]:
            print(
                f"  - {item.product_name!r:60s}"
                f"  {item.discount_price}"
                f"  valid={item.valid_from}..{item.valid_until}"
            )
        print("[run_worker] dry-run, yazma atlandı.")
        return 0

    # Supabase'e yaz
    client = SupabaseClient.from_env()
    run_id = start_scrape_run(
        client,
        market_id=parser.market_id,
        source_type=parser.source_type,
        source_label=parser.source_label,
    )
    stats = RunStats()

    started = time.time()
    for index, item in enumerate(items, start=1):
        try:
            product_id = find_or_create_product(
                client, item, parser.alias_source, stats
            )
            insert_price(client, product_id, item, run_id,
                         parser.source_label, stats)
            insert_campaign(client, product_id, item, stats)
        except requests.HTTPError as error:
            stats.errors.append(f"item {index}: HTTP {error}")
        except Exception as error:  # pragma: no cover
            stats.errors.append(
                f"item {index}: {type(error).__name__}: {error}"
            )
        if index % 25 == 0:
            print(
                f"  .. {index}/{len(items)} — "
                f"match={stats.products_matched}  new={stats.products_added}"
            )

    elapsed = time.time() - started
    final_status = "success" if not stats.errors else (
        "partial" if stats.prices_added > 0 else "failed"
    )
    finish_scrape_run(client, run_id, stats, final_status)
    print(
        f"[run_worker] done in {elapsed:.1f}s — "
        f"products_added={stats.products_added}, "
        f"products_matched={stats.products_matched}, "
        f"prices_added={stats.prices_added}, "
        f"campaigns_added={stats.campaigns_added}, "
        f"errors={len(stats.errors)} → status={final_status}"
    )
    if stats.errors:
        print("[run_worker] ilk 5 hata:")
        for err in stats.errors[:5]:
            print(f"  ! {err}")
    return 0 if final_status != "failed" else 1


if __name__ == "__main__":
    sys.exit(run(build_parser().parse_args()))
