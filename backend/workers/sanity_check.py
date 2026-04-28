"""Post-run sanity check — scrape_runs delta alarmi.

Amac: gunluk scrape'ten sonra, her aktif market icin BUGUNKU son run'un
prices_added sayacini son N gunluk ortalamayla kiyasla. Belirli esikten
fazla dusus (default %50) veya 0 yazim varsa, non-zero exit code donup
GitHub Actions bildirim yollayabilsin.

Kullanim:
    SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \\
      python backend/workers/sanity_check.py
    python backend/workers/sanity_check.py --threshold 0.5
    python backend/workers/sanity_check.py --markets a101,bim
    python backend/workers/sanity_check.py --skip-if-empty  # hic run yoksa
                                                            # alarm verme
"""

from __future__ import annotations

import argparse
import json
import os
import statistics
import sys
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode
from urllib.request import Request, urlopen


DEFAULT_TARGETS: tuple[str, ...] = (
    "a101",
    "bim",
    "carrefoursa",
    "migros",
    "sok",
    "tarim-kredi",
    "hakmar-express",
)


def _supabase_select(table: str, params: dict) -> list[dict]:
    url = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/" + table
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    query = urlencode(params, safe="")
    req = Request(
        f"{url}?{query}",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Accept": "application/json",
        },
    )
    with urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument(
        "--markets",
        default=",".join(DEFAULT_TARGETS),
        help="virgulle market_id listesi",
    )
    p.add_argument(
        "--threshold",
        type=float,
        default=0.5,
        help="izin verilen max dusus orani (default 0.5 = %50)",
    )
    p.add_argument(
        "--window-days",
        type=int,
        default=7,
        help="gecmis kars. icin pencere (gun)",
    )
    p.add_argument(
        "--skip-if-empty",
        action="store_true",
        help=(
            "gecmis veri hic yoksa (yeni market) o marketi atla, "
            "alarm verme"
        ),
    )
    return p


def run(args: argparse.Namespace) -> int:
    markets = [m.strip() for m in args.markets.split(",") if m.strip()]

    window_start = (
        datetime.now(timezone.utc) - timedelta(days=args.window_days + 1)
    ).date().isoformat()

    rows = _supabase_select(
        "scrape_runs",
        {
            "select": "market_id,status,prices_added,started_at",
            "started_at": f"gte.{window_start}",
            "order": "started_at.desc",
        },
    )

    today = datetime.now(timezone.utc).date().isoformat()
    fails: list[str] = []
    print(
        f"[sanity] window_days={args.window_days} "
        f"threshold={args.threshold:.0%} today={today}"
    )
    print(f"[sanity] {'market':<14} {'bugun':>6} {'7g_avg':>7} {'status':<10}")

    for market in markets:
        mr = [r for r in rows if r.get("market_id") == market]
        latest = next(
            (
                r for r in mr
                if (r.get("started_at") or "").startswith(today)
                and r.get("status") != "running"
            ),
            None,
        )
        historic = [
            int(r.get("prices_added") or 0)
            for r in mr
            if r.get("status") in ("success", "partial")
            and not (r.get("started_at") or "").startswith(today)
        ]
        avg = statistics.mean(historic) if historic else 0.0

        if latest is None:
            if args.skip_if_empty and not historic:
                print(f"[sanity] {market:<14} (gecmis yok, atlandi)")
                continue
            fails.append(f"{market}: bugun scrape_run yok")
            continue

        latest_prices = int(latest.get("prices_added") or 0)
        status = str(latest.get("status") or "?")
        print(
            f"[sanity] {market:<14} {latest_prices:>6} "
            f"{avg:>7.0f} {status:<10}"
        )

        if latest_prices == 0:
            fails.append(
                f"{market}: bugun 0 fiyat yazildi "
                f"(started_at={latest.get('started_at')})"
            )
            continue

        if avg > 0:
            drop = (avg - latest_prices) / avg
            if drop > args.threshold:
                fails.append(
                    f"{market}: bugun={latest_prices} 7g_avg={avg:.0f} "
                    f"dusus={drop:.0%} (threshold {args.threshold:.0%})"
                )

    if fails:
        print("\n[sanity] ALARM — su market(ler) beklenenin altinda:")
        for f in fails:
            print(f"  ! {f}")
        return 1

    print("\n[sanity] OK — tum marketler saglam.")
    return 0


if __name__ == "__main__":
    sys.exit(run(build_arg_parser().parse_args()))
