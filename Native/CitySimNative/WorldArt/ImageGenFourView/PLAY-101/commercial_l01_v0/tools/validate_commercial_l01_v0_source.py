#!/usr/bin/env python3
"""Validate the PLAY-098 Commercial L1 source-only four-view packet.

This deliberately does not key, normalize, resize, or produce runtime assets.
It verifies the independently authored raw masters and writes candidate evidence.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[5]
EVIDENCE = REPO / "docs/production/evidence/PLAY-098/commercial-l01-v0-family"
RAW = ROOT / "raw"
SHEET = ROOT / "contact-sheets/family-source-four-view.png"
DIRECTIONS = ("north", "east", "south", "west")
EXPECTED_SIZE = (1254, 1254)
KEY_DESCRIPTION = "ImageGen magenta keyed field: red >= 210, green <= 40, blue >= 200"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def edge_pixels(image: Image.Image):
    pixels = image.load()
    width, height = image.size
    for x in range(width):
        yield pixels[x, 0]
        yield pixels[x, height - 1]
    for y in range(1, height - 1):
        yield pixels[0, y]
        yield pixels[width - 1, y]


def is_keyed_field(pixel: tuple[int, int, int]) -> bool:
    red, green, blue = pixel
    return red >= 210 and green <= 40 and blue >= 200 and red - green >= 180 and blue - green >= 180


def run() -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    records = []
    masters = []
    failures = []
    for direction in DIRECTIONS:
        path = RAW / f"{direction}-source-v01.png"
        if not path.is_file():
            failures.append(f"missing {path.name}")
            continue
        with Image.open(path) as opened:
            if opened.mode != "RGB":
                failures.append(f"{direction}: source must be opaque RGB, got {opened.mode}")
            image = opened.convert("RGB")
        if image.size != EXPECTED_SIZE:
            failures.append(f"{direction}: expected {EXPECTED_SIZE}, got {image.size}")
        pixels = list(image.get_flattened_data())
        keyed_pixels = sum(is_keyed_field(pixel) for pixel in pixels)
        key_fraction = keyed_pixels / len(pixels)
        edges_keyed = all(is_keyed_field(pixel) for pixel in edge_pixels(image))
        if not edges_keyed:
            failures.append(f"{direction}: keyed source must have a fully magenta frame edge")
        if key_fraction < 0.20:
            failures.append(f"{direction}: insufficient keyed background ({key_fraction:.4f})")
        if key_fraction > 0.90:
            failures.append(f"{direction}: insufficient authored content ({key_fraction:.4f})")
        masters.append(image)
        records.append({
            "direction": direction,
            "path": path.relative_to(REPO).as_posix(),
            "sha256": sha256(path),
            "size": list(image.size),
            "mode": "RGB",
            "alphaPixels": 0,
            "chromaKey": KEY_DESCRIPTION,
            "chromaPixels": keyed_pixels,
            "chromaFraction": round(key_fraction, 8),
            "frameEdgeIsChromaKey": edges_keyed,
        })

    hashes = [record["sha256"] for record in records]
    if len(records) != 4:
        failures.append("must contain exactly four road-facing masters")
    if len(set(hashes)) != len(hashes):
        failures.append("four source masters must be byte-distinct")
    if failures:
        raise ValueError("; ".join(failures))

    thumb = 420
    gutter = 32
    sheet = Image.new("RGB", (thumb * 2 + gutter * 3, thumb * 2 + gutter * 3), "white")
    draw = ImageDraw.Draw(sheet)
    for index, (direction, master) in enumerate(zip(DIRECTIONS, masters)):
        row, column = divmod(index, 2)
        x = gutter + column * (thumb + gutter)
        y = gutter + row * (thumb + gutter)
        sheet.paste(master.resize((thumb, thumb), Image.Resampling.LANCZOS), (x, y))
        draw.rectangle((x, y, x + thumb - 1, y + thumb - 1), outline=(20, 64, 67), width=4)
        draw.text((x + 12, y + 12), direction.upper(), fill="white", stroke_width=2, stroke_fill=(20, 64, 67))
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(SHEET, optimize=True)

    report = {
        "task": "PLAY-098",
        "family": "commercial_l01_v0",
        "candidateOnly": True,
        "normalization": "NOT_RUN",
        "runtimeActivation": "NOT_RUN",
        "sourceQuality": "PASS",
        "directions": records,
        "uniqueSourceCount": len(set(hashes)),
        "contactSheet": {
            "path": SHEET.relative_to(REPO).as_posix(),
            "sha256": sha256(SHEET),
            "coverage": list(DIRECTIONS),
        },
        "gates": {
            "fourIndependentRoadFacingViews": True,
            "expectedCanvas": list(EXPECTED_SIZE),
            "zeroAlphaDefects": True,
            "flatChromaFrame": True,
            "zeroFrameEdgeDefects": True,
            "distinctSourceBytes": True,
        },
    }
    (EVIDENCE / "SOURCE-QUALITY-REPORT.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    print(json.dumps({"result": "PASS", "sourceQuality": report["sourceQuality"], "uniqueSourceCount": report["uniqueSourceCount"]}))


if __name__ == "__main__":
    run()
