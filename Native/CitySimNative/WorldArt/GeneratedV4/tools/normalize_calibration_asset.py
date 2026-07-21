#!/usr/bin/env python3
"""Normalize one retained ImageGen calibration source into explicit LOD PNGs."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image


CANVAS = (1536, 1024)
LODS = {"block": (1536, 1024), "neighborhood": (768, 512), "city": (384, 256)}
SURFACE_BOUNDS = {
    "grass_material": (512, 640, 1024, 896),
    "road_material": (512, 640, 1024, 896),
    "residential_frontage": (512, 640, 1024, 896),
    "park_l01": (256, 384, 1280, 896),
}
OBJECT_WIDTHS = {
    "residential_l01": 390,
    "commercial_l01": 410,
    "industrial_l01": 710,
    "city_hall_l01": 820,
    "water_tower_l01": 360,
}
GROUND_PIVOT = (768, 896)


def is_matte(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 0 and r >= 180 and b >= 150 and g <= 110 and r + b >= g * 4


def remove_border_matte(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not is_matte(pixels[x, y]):
            continue
        seen.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        if x > 0: queue.append((x - 1, y))
        if x + 1 < width: queue.append((x + 1, y))
        if y > 0: queue.append((x, y - 1))
        if y + 1 < height: queue.append((x, y + 1))
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                pixels[x, y] = (0, 0, 0, 0)
            elif r > g * 1.35 and b > g * 1.25:
                spill = min(r, b) - g
                pixels[x, y] = (max(g, r - spill), g, max(g, b - spill), a)
    return rgba


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def register_subject(image: Image.Image, asset_id: str) -> tuple[Image.Image, dict[str, object]]:
    source_bbox = image.getbbox()
    if source_bbox is None:
        raise SystemExit("normalization rejected: source contains no non-matte pixels")
    subject = image.crop(source_bbox)
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    if asset_id in SURFACE_BOUNDS:
        target = SURFACE_BOUNDS[asset_id]
        subject = subject.resize((target[2] - target[0], target[3] - target[1]), Image.Resampling.LANCZOS)
        canvas.alpha_composite(subject, (target[0], target[1]))
        transform = {"mode": "exact-footprint", "source_bbox": list(source_bbox), "target_bbox": list(target)}
    elif asset_id in OBJECT_WIDTHS:
        width = OBJECT_WIDTHS[asset_id]
        height = round(subject.height * width / subject.width)
        if height > 790:
            height = 790
            width = round(subject.width * height / subject.height)
        subject = subject.resize((width, height), Image.Resampling.LANCZOS)
        origin = (GROUND_PIVOT[0] - width // 2, GROUND_PIVOT[1] - height)
        canvas.alpha_composite(subject, origin)
        transform = {
            "mode": "uniform-object-registration",
            "source_bbox": list(source_bbox),
            "target_size": [width, height],
            "target_ground_pivot": list(GROUND_PIVOT),
            "target_origin": list(origin),
        }
    else:
        raise SystemExit(f"normalization rejected: no registration rule for {asset_id}")
    return canvas, transform


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--record", required=True, type=Path)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    if source.size != CANVAS:
        source = source.resize(CANVAS, Image.Resampling.LANCZOS)
    cleaned = remove_border_matte(source)
    normalized, registration = register_subject(cleaned, args.asset_id)
    bbox = normalized.getbbox()
    if bbox[0] <= 2 or bbox[1] <= 2 or bbox[2] >= CANVAS[0] - 2 or bbox[3] >= CANVAS[1] - 2:
        raise SystemExit(f"normalization rejected: inadequate transparent padding {bbox}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    outputs = []
    for lod, size in LODS.items():
        image = normalized if size == CANVAS else normalized.resize(size, Image.Resampling.LANCZOS)
        path = args.output_dir / f"generated_v4_{args.asset_id}_{lod}.png"
        image.save(path, optimize=True)
        outputs.append({"lod": lod, "file": path.name, "pixels": list(size), "sha256": sha256(path)})

    record = {
        "asset_id": args.asset_id,
        "source_file": str(args.input),
        "source_sha256": sha256(args.input),
        "cleanup_command": " ".join(("normalize_calibration_asset.py", "--asset-id", args.asset_id, "--input", str(args.input), "--output-dir", str(args.output_dir), "--record", str(args.record))),
        "normalization": "8-bit sRGB RGBA; border-connected #ff00ff removal; edge despill; zero hidden RGB; Lanczos explicit LOD exports",
        "registration": registration,
        "source_bbox": list(bbox),
        "ground_pivot_source": [768, 896],
        "outputs": outputs,
    }
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
