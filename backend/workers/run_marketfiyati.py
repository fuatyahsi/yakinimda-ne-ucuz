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
    BulkProductResolver,
    BulkWriter,
    RunStats,
    SupabaseClient,
    WorkerItem,
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

# 5 market marketfiyati kapsami. (sok 2026-04-26'da cutover edildi — artik
# sokmarket.com.tr direct parser kullaniyor, run_marketfiyati'a dahil degil.
# Bkz. parsers/sok_direct.py)
DEFAULT_TARGETS: tuple[str, ...] = (
    "a101",
    "bim",
    "carrefoursa",
    "migros",
    "tarim-kredi",
)

# Step 5b: per-market kac item biriktirip toplu resolve+yazim yapacak.
# 50: PostgREST `in.()` URL'i ~6KB civari (alias slug ~80ch + canonical_name
# ~100ch x 50). 4-8KB nginx default'una guvenli mesafe. Dusuk olursa per-batch
# overhead artiyor, yuksek olursa URL too long riski.
RESOLVE_BATCH_SIZE = 50


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
    writer: BulkWriter | None = None
    if not args.dry_run:
        supabase = SupabaseClient.from_env()
        # Tek BulkWriter tum marketler arasinda paylasilir; prices ve
        # campaigns tablolari icin ayri buffer'lar tutulur. 500'luk chunk =
        # ~12 bulk POST (5528 satir icin) yerine ~5528 tekil POST.
        writer = BulkWriter(supabase, flush_size=500)

    for market_id, market_adi in targets:
        parser = get_parser(market_id)
        state: dict = {
            "parser": parser,
            "market_adi": market_adi,
            "items": [],          # cache icin (sweep boyunca tum item'lar)
            "pending": [],        # Step 5b: resolver'a verilecek bekleyenler
            "resolver": None,     # Supabase yazimi varsa init edilir
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
            state["resolver"] = BulkProductResolver(
                supabase, parser.alias_source, state["stats"]
            )
            print(f"[mf] {market_id}: scrape_run #{state['run_id']} acildi")
        per_market[market_id] = state

    # --------------------------------------------------------------
    # Sweep
    # --------------------------------------------------------------
    started = time.time()
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

                    if supabase is not None:
                        # Step 5b: anlik find_or_create_product yerine
                        # pending buffer'a koy. Buffer dolunca toplu resolve+yaz.
                        state["pending"].append(item)
                        if len(state["pending"]) >= RESOLVE_BATCH_SIZE:
                            total_writes += _flush_pending(
                                state, writer, kw_label=kw
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
        # Once her marketin pending buffer'ini son kez bosalt — bunlar henuz
        # resolve edilmemis item'lar. Sonra BulkWriter'i flush et.
        for market_id, state in per_market.items():
            if state["pending"]:
                wrote = _flush_pending(state, writer, kw_label="<final>")
                total_writes += wrote
                print(
                    f"[mf] {market_id}: final pending flush, "
                    f"{wrote} item resolved+yazildi"
                )

        # ONCE bekleyen tum bulk insert'leri yaz — finish_scrape_run sayaci
        # bu flush'tan sonraki gercek sayilarla esitlenecek. Ayni anda hata
        # cikarsa tum marketlerin scrape_run'ina partial/failed yansir.
        if writer is not None:
            try:
                writer.flush_all()
                print(
                    f"[mf] bulk flush: {writer.batches_flushed} batch, "
                    f"{writer.rows_flushed} satir"
                )
            except Exception as flush_err:
                print(f"[mf] HATA: flush_all patladi — {flush_err}")
                # Hatayi tum marketlerin stats'ina yaz
                for state in per_market.values():
                    state["stats"].errors.append(
                        f"bulk flush_all: "
                        f"{type(flush_err).__name__}: {flush_err}"
                    )

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


def _flush_pending(
    state: dict,
    writer: BulkWriter | None,
    *,
    kw_label: str,
) -> int:
    """state['pending']'i resolver ile coz, prices+campaigns yaz, buffer'i bosalt.

    Donen deger: yazilan item sayisi (insert_price tetiklenen).
    """
    pending: list[WorkerItem] = state["pending"]
    if not pending or writer is None:
        return 0

    resolver: BulkProductResolver | None = state["resolver"]
    parser = state["parser"]
    stats: RunStats = state["stats"]
    run_id = state["run_id"]

    if resolver is None:
        # supabase=None senaryosu — buraya gelmemeli ama defansif.
        state["pending"] = []
        return 0

    try:
        mapping = resolver.resolve_batch(pending)
    except Exception as err:  # pragma: no cover
        # resolve_batch zaten kendi icinde fallback ediyor; buraya genelde
        # ulasilmaz. Yine de defansif: tum batch'i kayip say, devam et.
        stats.errors.append(
            f"resolve_batch unexpected ({kw_label}): "
            f"{type(err).__name__}: {err}"
        )
        state["pending"] = []
        return 0

    written = 0
    for idx, item in enumerate(pending):
        product_id = mapping.get(idx)
        try:
            insert_price(
                writer, product_id, item, run_id,
                parser.source_label, stats,
            )
            insert_campaign(writer, product_id, item, stats)
            written += 1
        except requests.HTTPError as err:
            stats.errors.append(
                f"insert ({kw_label}) idx={idx}: HTTP {err}"
            )
        except Exception as err:  # pragma: no cover
            stats.errors.append(
                f"insert ({kw_label}) idx={idx}: "
                f"{type(err).__name__}: {err}"
            )
    state["pending"] = []
    return written


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
