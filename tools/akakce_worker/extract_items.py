from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


def build_parser() -> argparse.ArgumentParser:
    worker_root = Path(__file__).resolve().parent
    output_root = worker_root / "output"
    parser = argparse.ArgumentParser(
        description="Detect brochure product candidates and OCR product crops."
    )
    parser.add_argument(
        "--source-manifest",
        default=str(output_root / "source_manifest.json"),
    )
    parser.add_argument(
        "--output",
        default=str(output_root / "extracted_products.json"),
    )
    parser.add_argument(
        "--crops-dir",
        default=str(output_root / "crops"),
    )
    parser.add_argument("--max-images-per-brochure", type=int, default=8)
    parser.add_argument("--languages", nargs="+", default=["tr", "en"])
    return parser


@dataclass
class ProductCandidate:
    brochureId: str
    brochureUrl: str
    marketName: str
    pageIndex: int
    productName: str
    brand: str | None
    price: float
    confidence: float
    cropPath: str
    priceCropPath: str
    imageUrl: str | None
    imagePath: str
    ocrText: str
    priceOcrText: str
    bbox: dict
    priceBox: dict


def ensure_cv_stack():
    try:
        import cv2  # type: ignore
    except ImportError as error:  # pragma: no cover - runtime guidance
        raise SystemExit(
            "OCR stack missing. Install with: "
            ".\\.venv\\Scripts\\python.exe -m pip install -r "
            "tools\\akakce_worker\\requirements-ocr.txt"
        ) from error
    return cv2


def ensure_rapidocr():
    try:
        from rapidocr import (  # type: ignore
            EngineType,
            LangDet,
            LangRec,
            OCRVersion,
            RapidOCR,
        )
    except ImportError as error:  # pragma: no cover - runtime guidance
        raise SystemExit(
            "RapidOCR missing. Install with: "
            ".\\.venv\\Scripts\\python.exe -m pip install -r "
            "tools\\akakce_worker\\requirements-ocr.txt"
        ) from error
    try:
        return RapidOCR(
            params={
                "Global.use_cls": False,
                "Det.engine_type": EngineType.ONNXRUNTIME,
                "Det.lang_type": LangDet.CH,
                "Det.ocr_version": OCRVersion.PPOCRV4,
                "Rec.engine_type": EngineType.ONNXRUNTIME,
                "Rec.lang_type": LangRec.LATIN,
                "Rec.ocr_version": OCRVersion.PPOCRV4,
            }
        )
    except (ImportError, OSError) as error:  # pragma: no cover - runtime guidance
        raise SystemExit(
            "RapidOCR native runtime could not start. Reinstall OCR deps with "
            "`msvc-runtime` included: "
            ".\\.venv\\Scripts\\python.exe -m pip install --upgrade -r "
            "tools\\akakce_worker\\requirements-ocr.txt"
        ) from error


def detect_price_boxes(cv2, image) -> list[tuple[int, int, int, int]]:
    import numpy as np  # type: ignore

    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    masks = []

    red_lower_1 = np.array([0, 80, 90], dtype=np.uint8)
    red_upper_1 = np.array([12, 255, 255], dtype=np.uint8)
    red_lower_2 = np.array([165, 80, 90], dtype=np.uint8)
    red_upper_2 = np.array([180, 255, 255], dtype=np.uint8)
    yellow_lower = np.array([15, 80, 110], dtype=np.uint8)
    yellow_upper = np.array([40, 255, 255], dtype=np.uint8)

    masks.append(cv2.inRange(hsv, red_lower_1, red_upper_1))
    masks.append(cv2.inRange(hsv, red_lower_2, red_upper_2))
    masks.append(cv2.inRange(hsv, yellow_lower, yellow_upper))

    mask = masks[0]
    for extra in masks[1:]:
        mask = cv2.bitwise_or(mask, extra)

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 9))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    mask = cv2.dilate(mask, kernel, iterations=1)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    image_area = image.shape[0] * image.shape[1]
    boxes: list[tuple[int, int, int, int]] = []

    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        area = w * h
        if area < image_area * 0.00008:
            continue
        if area > image_area * 0.04:
            continue
        if w < 28 or h < 24:
            continue
        ratio = w / max(h, 1)
        if ratio < 0.35 or ratio > 4.8:
            continue
        if y < image.shape[0] * 0.03:
            continue
        boxes.append((x, y, w, h))

    return dedupe_boxes(boxes)


def dedupe_boxes(boxes: Iterable[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
    sorted_boxes = sorted(boxes, key=lambda box: (box[1], box[0]))
    merged: list[tuple[int, int, int, int]] = []
    for candidate in sorted_boxes:
        if any(iou(candidate, existing) > 0.35 for existing in merged):
            continue
        merged.append(candidate)
    return merged


def iou(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> float:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    x1 = max(ax, bx)
    y1 = max(ay, by)
    x2 = min(ax + aw, bx + bw)
    y2 = min(ay + ah, by + bh)
    if x2 <= x1 or y2 <= y1:
        return 0.0
    intersection = (x2 - x1) * (y2 - y1)
    union = aw * ah + bw * bh - intersection
    return intersection / max(union, 1)


def expand_product_box(
    *,
    x: int,
    y: int,
    w: int,
    h: int,
    image_width: int,
    image_height: int,
) -> tuple[int, int, int, int]:
    left = max(0, int(x - w * 2.8))
    top = max(0, int(y - h * 3.2))
    right = min(image_width, int(x + w * 2.0))
    bottom = min(image_height, int(y + h * 2.2))
    return left, top, right - left, bottom - top


def run_reader(engine, image) -> tuple[str, float]:
    result = engine(image)
    if result is None:
        return "", 0.0

    payload = result[0] if isinstance(result, tuple) and result else result
    if payload is None:
        return "", 0.0

    texts: list[str] = []
    confidences: list[float] = []

    if hasattr(payload, "txts"):
        raw_texts = getattr(payload, "txts", None) or []
        raw_scores = getattr(payload, "scores", None) or []
        texts = [str(text).strip() for text in raw_texts if text is not None and str(text).strip()]
        confidences = [
            float(score)
            for score in raw_scores
            if score is not None
        ]
    elif isinstance(payload, list):
        for item in payload:
            if not isinstance(item, (list, tuple)) or len(item) < 3:
                continue
            texts.append(str(item[1]).strip())
            try:
                confidences.append(float(item[2]))
            except (TypeError, ValueError):
                continue

    if not texts:
        return "", 0.0

    merged_text = " ".join(text for text in texts if text)
    confidence = sum(confidences) / len(confidences) if confidences else 0.0
    return merged_text.strip(), confidence


def parse_price(text: str) -> float | None:
    for match in re.findall(r"\d{1,3}(?:[.,]\d{3})+(?:,\d{2})?|\d{1,4}(?:,\d{2})", text):
        cleaned = match.replace(".", "").replace(",", ".")
        try:
            value = float(cleaned)
        except ValueError:
            continue
        if 0.1 <= value <= 999999:
            return value
    return None


def clean_title(text: str) -> str:
    cleaned = text
    cleaned = re.sub(r"\d{1,3}(?:[.,]\d{3})+(?:,\d{2})?", " ", cleaned)
    cleaned = re.sub(r"\d+(?:,\d{2})?", " ", cleaned)
    cleaned = re.sub(r"\bTL\b", " ", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bADET\b", " ", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bTAKSIT\b", " ", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bPESIN\b", " ", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned.strip(" -.,:")


def guess_brand(product_name: str) -> str | None:
    tokens = [token for token in re.split(r"\s+", product_name) if token]
    if not tokens:
        return None
    first = tokens[0]
    if len(first) < 2:
        return None
    return first


def write_crop(cv2, crop, path: Path) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(path), crop)
    return str(path.resolve())


def should_ocr_crop(cv2, crop, *, min_stddev: float, min_foreground_ratio: float) -> bool:
    if crop is None or crop.size == 0:
        return False

    height, width = crop.shape[:2]
    if height < 18 or width < 18:
        return False

    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    stddev = float(gray.std())
    if stddev < min_stddev:
        return False

    _, binary = cv2.threshold(
        gray,
        0,
        255,
        cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU,
    )
    foreground_ratio = float(binary.mean() / 255.0)
    if foreground_ratio < min_foreground_ratio:
        return False

    return True


def prepare_crop_for_ocr(cv2, crop):
    if crop is None or crop.size == 0:
        return crop

    height, width = crop.shape[:2]
    scale = 1
    if max(height, width) < 220:
        scale = 2
    if max(height, width) < 120:
        scale = 3

    if scale > 1:
        crop = cv2.resize(
            crop,
            (width * scale, height * scale),
            interpolation=cv2.INTER_CUBIC,
        )

    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)
    return cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)


def main() -> None:
    args = build_parser().parse_args()
    cv2 = ensure_cv_stack()
    reader = ensure_rapidocr()

    source_manifest_path = Path(args.source_manifest).resolve()
    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    crops_dir = Path(args.crops_dir).resolve()
    crops_dir.mkdir(parents=True, exist_ok=True)

    manifest = json.loads(source_manifest_path.read_text(encoding="utf-8"))
    brochures = manifest.get("brochures", [])
    items: list[dict] = []

    for brochure in brochures:
        brochure_id = str(brochure.get("brochure_id", "unknown"))
        market_name = brochure.get("market_name") or "Akakce"
        brochure_url = brochure.get("detail_url") or ""
        images = brochure.get("images", [])[: args.max_images_per_brochure]

        for image in images:
            image_path = image.get("local_path")
            if not image_path:
                continue

            bgr = cv2.imread(image_path)
            if bgr is None:
                continue

            page_index = int(image.get("page_index", 1))
            page_height, page_width = bgr.shape[:2]
            price_boxes = detect_price_boxes(cv2, bgr)

            for index, (x, y, w, h) in enumerate(price_boxes, start=1):
                px, py, pw, ph = expand_product_box(
                    x=x,
                    y=y,
                    w=w,
                    h=h,
                    image_width=page_width,
                    image_height=page_height,
                )
                product_crop = bgr[py : py + ph, px : px + pw]
                price_crop = bgr[y : y + h, x : x + w]

                product_text = ""
                product_confidence = 0.0
                price_text = ""
                price_confidence = 0.0

                if should_ocr_crop(
                    cv2,
                    product_crop,
                    min_stddev=18.0,
                    min_foreground_ratio=0.012,
                ):
                    product_text, product_confidence = run_reader(
                        reader,
                        prepare_crop_for_ocr(cv2, product_crop),
                    )

                if should_ocr_crop(
                    cv2,
                    price_crop,
                    min_stddev=14.0,
                    min_foreground_ratio=0.02,
                ):
                    price_text, price_confidence = run_reader(
                        reader,
                        prepare_crop_for_ocr(cv2, price_crop),
                    )

                price = parse_price(price_text) or parse_price(product_text)
                title = clean_title(product_text)

                if not title or price is None:
                    continue

                product_crop_path = write_crop(
                    cv2,
                    product_crop,
                    crops_dir
                    / brochure_id
                    / f"page_{page_index:02d}"
                    / f"product_{index:03d}.jpg",
                )
                price_crop_path = write_crop(
                    cv2,
                    price_crop,
                    crops_dir
                    / brochure_id
                    / f"page_{page_index:02d}"
                    / f"price_{index:03d}.jpg",
                )

                candidate = ProductCandidate(
                    brochureId=brochure_id,
                    brochureUrl=brochure_url,
                    marketName=market_name,
                    pageIndex=page_index,
                    productName=title,
                    brand=guess_brand(title),
                    price=price,
                    confidence=round((product_confidence + price_confidence) / 2, 4),
                    cropPath=product_crop_path,
                    priceCropPath=price_crop_path,
                    imageUrl=image.get("image_url"),
                    imagePath=image_path,
                    ocrText=product_text,
                    priceOcrText=price_text,
                    bbox={"x": px, "y": py, "width": pw, "height": ph},
                    priceBox={"x": x, "y": y, "width": w, "height": h},
                )
                items.append(asdict(candidate))

    payload = {
        "generatedFrom": str(source_manifest_path),
        "itemCount": len(items),
        "items": items,
    }
    output_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {len(items)} extracted product candidates to {output_path}")


if __name__ == "__main__":
    main()
