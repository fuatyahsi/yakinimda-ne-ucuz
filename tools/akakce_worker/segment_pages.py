from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


@dataclass
class TileSpec:
    tile_id: str
    brochure_id: str
    page_index: int
    image_path: str
    x: int
    y: int
    width: int
    height: int


def build_parser() -> argparse.ArgumentParser:
    worker_root = Path(__file__).resolve().parent
    output_root = worker_root / "output"
    parser = argparse.ArgumentParser(
        description="Split brochure pages into reusable OCR tiles."
    )
    parser.add_argument(
        "--source-manifest",
        default=str(output_root / "source_manifest.json"),
    )
    parser.add_argument(
        "--output",
        default=str(output_root / "tile_manifest.json"),
    )
    parser.add_argument("--tile-width", type=int, default=1400)
    parser.add_argument("--tile-height", type=int, default=1400)
    parser.add_argument("--overlap", type=int, default=180)
    return parser


def build_tiles_for_image(
    *,
    brochure_id: str,
    page_index: int,
    image_path: Path,
    tile_width: int,
    tile_height: int,
    overlap: int,
) -> list[TileSpec]:
    with Image.open(image_path) as image:
        width, height = image.size

    step_x = max(tile_width - overlap, 1)
    step_y = max(tile_height - overlap, 1)

    xs = compute_starts(width, tile_width, step_x)
    ys = compute_starts(height, tile_height, step_y)

    tiles: list[TileSpec] = []
    tile_number = 1
    for y in ys:
        for x in xs:
            current_width = min(tile_width, width - x)
            current_height = min(tile_height, height - y)
            tiles.append(
                TileSpec(
                    tile_id=f"{brochure_id}_p{page_index:02d}_t{tile_number:03d}",
                    brochure_id=brochure_id,
                    page_index=page_index,
                    image_path=str(image_path.resolve()),
                    x=x,
                    y=y,
                    width=current_width,
                    height=current_height,
                )
            )
            tile_number += 1
    return tiles


def compute_starts(total: int, window: int, step: int) -> list[int]:
    if total <= window:
        return [0]

    starts = list(range(0, total - window + 1, step))
    last_start = total - window
    if starts[-1] != last_start:
        starts.append(last_start)
    return starts


def main() -> None:
    args = build_parser().parse_args()
    source_manifest_path = Path(args.source_manifest).resolve()
    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    source_manifest = json.loads(source_manifest_path.read_text(encoding="utf-8"))
    brochures = source_manifest.get("brochures", [])

    tiles_payload: list[dict] = []
    for brochure in brochures:
        brochure_id = str(brochure.get("brochure_id", "unknown"))
        for image in brochure.get("images", []):
            local_path = image.get("local_path")
            if not local_path:
                continue
            image_path = Path(local_path)
            if not image_path.exists():
                continue
            page_index = int(image.get("page_index", 1))
            tiles = build_tiles_for_image(
                brochure_id=brochure_id,
                page_index=page_index,
                image_path=image_path,
                tile_width=args.tile_width,
                tile_height=args.tile_height,
                overlap=args.overlap,
            )
            tiles_payload.extend(tile.__dict__ for tile in tiles)

    payload = {
        "generatedFrom": str(source_manifest_path),
        "tileCount": len(tiles_payload),
        "tileWidth": args.tile_width,
        "tileHeight": args.tile_height,
        "overlap": args.overlap,
        "tiles": tiles_payload,
    }
    output_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {len(tiles_payload)} tiles to {output_path}")


if __name__ == "__main__":
    main()
