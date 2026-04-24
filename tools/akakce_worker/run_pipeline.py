from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run the market brochure worker pipeline skeleton."
    )
    parser.add_argument("--source", choices=["akakce", "bim"], default="akakce")
    parser.add_argument("--listing-url")
    parser.add_argument("--max-brochures", type=int, default=18)
    parser.add_argument("--download-images", action="store_true")
    parser.add_argument("--extract-items", action="store_true")
    return parser


def run_step(script_name: str, *extra_args: str) -> None:
    script_path = Path(__file__).resolve().parent / script_name
    command = [sys.executable, str(script_path), *extra_args]
    subprocess.run(command, check=True)


def main() -> None:
    args = build_parser().parse_args()

    fetch_args = ["--max-brochures", str(args.max_brochures)]
    if args.listing_url:
        fetch_args.extend(["--listing-url", args.listing_url])
    if args.download_images:
        fetch_args.append("--download-images")

    fetch_script = "fetch_bim_sources.py" if args.source == "bim" else "fetch_sources.py"
    run_step(fetch_script, *fetch_args)

    if args.source == "bim":
        run_step("fetch_bim_products.py", "--max-brochures", str(args.max_brochures))
    elif args.download_images:
        run_step("segment_pages.py")
        if args.extract_items:
            run_step("extract_items.py")

    run_step("export_feed.py")
    print(f"{args.source} worker pipeline finished.")


if __name__ == "__main__":
    main()
