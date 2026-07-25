#!/usr/bin/env python3
"""Build deterministic non-shipping template/source comparison sheets."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


REPOSITORY_ROOT = Path(__file__).resolve().parents[6]
SOURCE_CANVAS = (1536, 1024)
SOURCE_DIAMOND_WIDTH = 512
ACTUAL_TILE_WIDTH_PIXELS = 144
ACTUAL_SCALE = ACTUAL_TILE_WIDTH_PIXELS / SOURCE_DIAMOND_WIDTH


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--source-sheet", required=True, type=Path)
    parser.add_argument("--actual-sheet", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()

    template = Image.open(args.template).convert("RGB")
    source = Image.open(args.source).convert("RGB")
    if template.size != SOURCE_CANVAS or source.size != SOURCE_CANVAS:
        raise SystemExit(
            f"expected two {SOURCE_CANVAS} images, got "
            f"{template.size} and {source.size}"
        )

    source_sheet = Image.new(
        "RGB",
        (SOURCE_CANVAS[0] * 2, SOURCE_CANVAS[1]),
    )
    source_sheet.paste(template, (0, 0))
    source_sheet.paste(source, (SOURCE_CANVAS[0], 0))
    args.source_sheet.parent.mkdir(parents=True, exist_ok=True)
    source_sheet.save(args.source_sheet, optimize=True)

    actual_size = (
        round(SOURCE_CANVAS[0] * ACTUAL_SCALE),
        round(SOURCE_CANVAS[1] * ACTUAL_SCALE),
    )
    actual_sheet = Image.new("RGB", (actual_size[0] * 2, actual_size[1]))
    actual_sheet.paste(
        template.resize(actual_size, Image.Resampling.LANCZOS),
        (0, 0),
    )
    actual_sheet.paste(
        source.resize(actual_size, Image.Resampling.LANCZOS),
        (actual_size[0], 0),
    )
    args.actual_sheet.parent.mkdir(parents=True, exist_ok=True)
    actual_sheet.save(args.actual_sheet, optimize=True)

    samples = [
        (0, 0),
        (1535, 0),
        (0, 1023),
        (1535, 1023),
        (768, 64),
        (64, 512),
        (1472, 512),
        (768, 960),
    ]
    report = {
        "schema": 1,
        "task": "PLAY-027",
        "sourceKey": "residential_l01/variant-0/north/source-v03",
        "layout": "authoritative north template left; raw probe right",
        "templateFile": str(args.template.resolve().relative_to(REPOSITORY_ROOT)),
        "templateSHA256": sha256(args.template),
        "rawSourceFile": str(args.source.resolve().relative_to(REPOSITORY_ROOT)),
        "rawSourceSHA256": sha256(args.source),
        "sourceScaleSheetFile": str(
            args.source_sheet.resolve().relative_to(REPOSITORY_ROOT)
        ),
        "sourceScaleSheetSHA256": sha256(args.source_sheet),
        "sourceScaleSheetPixels": list(source_sheet.size),
        "actualScale": ACTUAL_SCALE,
        "actualScaleBasis": {
            "authoritativeSourceDiamondWidthPixels": SOURCE_DIAMOND_WIDTH,
            "native2xTileWidthPixels": ACTUAL_TILE_WIDTH_PIXELS,
        },
        "actualScaleSheetFile": str(
            args.actual_sheet.resolve().relative_to(REPOSITORY_ROOT)
        ),
        "actualScaleSheetSHA256": sha256(args.actual_sheet),
        "actualScaleSheetPixels": list(actual_sheet.size),
        "rawBackgroundSamples": [
            {
                "point": list(point),
                "rgb": list(source.getpixel(point)),
            }
            for point in samples
        ],
        "flatChromaExpectedRGB": [255, 0, 255],
        "flatChromaSamplesPassed": all(
            source.getpixel(point) == (255, 0, 255) for point in samples
        ),
        "orientationTransform": "none",
        "productionSelected": False,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
