#!/usr/bin/env python3
"""Compile deterministic road topology from the accepted road material source."""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageStat


ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / "GeneratedV4"
PACKAGE = ROOT.parent
ATLAS = PACKAGE / "Sources" / "CitySimNative" / "Resources" / "WorldAssets.atlas"
SOURCE = GENERATED / "normalized" / "calibration" / "road_material" / "generated_v4_road_material_block.png"
OUTPUT = GENERATED / "compiled" / "calibration-network"
LODS = {"block": (512, 256), "neighborhood": (256, 128), "city": (128, 64)}
EDGES = ((384, 64), (384, 192), (128, 192), (128, 64))
AUTHORING_SIZE = (1536, 1024)
AUTHORING_MATERIAL_BOUNDS = (512, 640, 1024, 896)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def median_rgb(image: Image.Image, box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    rgb = ImageStat.Stat(image.crop(box).convert("RGB")).median
    return (int(rgb[0]), int(rgb[1]), int(rgb[2]), 255)


def draw_mask(mask_value: int, asphalt: tuple[int, ...], curb: tuple[int, ...], walk: tuple[int, ...]) -> Image.Image:
    image = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    center = (256, 128)
    endpoints = [EDGES[index] for index in range(4) if mask_value & (1 << index)]
    if not endpoints:
        endpoints = [(256, 128)]
        draw.ellipse((196, 98, 316, 158), fill=walk)
        draw.ellipse((204, 102, 308, 154), fill=curb)
        draw.ellipse((214, 107, 298, 149), fill=asphalt)
        return image
    for endpoint in endpoints:
        draw.line((center, endpoint), fill=walk, width=116, joint="curve")
    draw.ellipse((198, 99, 314, 157), fill=walk)
    for endpoint in endpoints:
        draw.line((center, endpoint), fill=curb, width=94, joint="curve")
    draw.ellipse((209, 104, 303, 152), fill=curb)
    for endpoint in endpoints:
        draw.line((center, endpoint), fill=asphalt, width=76, joint="curve")
    draw.ellipse((218, 109, 294, 147), fill=asphalt)

    if len(endpoints) >= 3:
        for endpoint in endpoints:
            dx, dy = endpoint[0] - center[0], endpoint[1] - center[1]
            length = max(abs(dx), abs(dy))
            ux, uy = dx / length, dy / length
            px, py = -uy, ux
            base_x, base_y = center[0] + dx * 0.48, center[1] + dy * 0.48
            for stripe in (-24, -8, 8, 24):
                cx, cy = base_x + ux * stripe, base_y + uy * stripe
                draw.line((cx - px * 25, cy - py * 25, cx + px * 25, cy + py * 25), fill=(229, 221, 196, 235), width=5)
    elif len(endpoints) == 2:
        for endpoint in endpoints:
            dx, dy = endpoint[0] - center[0], endpoint[1] - center[1]
            draw.line((center[0] + dx * 0.24, center[1] + dy * 0.24, center[0] + dx * 0.82, center[1] + dy * 0.82), fill=(196, 151, 55, 220), width=4)
    return image


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    scale_x = source.width / AUTHORING_SIZE[0]
    scale_y = source.height / AUTHORING_SIZE[1]
    material_bounds = (
        round(AUTHORING_MATERIAL_BOUNDS[0] * scale_x),
        round(AUTHORING_MATERIAL_BOUNDS[1] * scale_y),
        round(AUTHORING_MATERIAL_BOUNDS[2] * scale_x),
        round(AUTHORING_MATERIAL_BOUNDS[3] * scale_y),
    )
    material = source.crop(material_bounds).resize(LODS["block"], Image.Resampling.LANCZOS)
    asphalt = median_rgb(material, (60, 10, 452, 105))
    curb = median_rgb(material, (10, 105, 248, 175))
    walk = median_rgb(material, (264, 105, 502, 175))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    inventory = []
    for mask_value in range(16):
        block = draw_mask(mask_value, asphalt, curb, walk)
        for lod, size in LODS.items():
            image = block if lod == "block" else block.resize(size, Image.Resampling.LANCZOS)
            name = f"generated_v4_road_mask_{mask_value:02d}_{lod}.png"
            output = OUTPUT / name
            image.save(output, optimize=True)
            destination = ATLAS / name
            shutil.copyfile(output, destination)
            inventory.append({
                "file": name,
                "sha256": digest(destination),
                "pixels": list(size),
                "decoded_byte_estimate": size[0] * size[1] * 4,
            })

    manifest_path = ATLAS / "generated-v4-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["compiled_network"] = {
        "source_logical_id": "road_material",
        "compiler": "WorldArt/GeneratedV4/tools/compile_calibration_network.py",
        "connection_masks": 16,
        "lods": {
            lod: {
                "pixels": list(size),
                "world_size": [74.0, 37.0],
                "decoded_bytes_per_texture": size[0] * size[1] * 4,
            }
            for lod, size in LODS.items()
        },
        "topology_authority": "RoadConnectionMask",
    }
    previous = {item["file"]: item for item in manifest["inventory"] if not item["file"].startswith("generated_v4_road_mask_")}
    previous.update({item["file"]: item for item in inventory})
    manifest["inventory"] = [previous[name] for name in sorted(previous)]
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
