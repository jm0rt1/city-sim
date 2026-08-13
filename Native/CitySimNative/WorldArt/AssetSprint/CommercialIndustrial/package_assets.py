#!/usr/bin/env python3
"""Normalize approved alpha masters onto Cedar Market pivot-aware canvases."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


ASSETS = {
    "cedar-corner-shop": {"category": "commercial", "footprint": [2, 2], "canvas": [512, 512], "art_width": 410},
    "cedar-cafe": {"category": "commercial", "footprint": [2, 2], "canvas": [512, 512], "art_width": 410},
    "cedar-mixed-use": {"category": "commercial", "footprint": [2, 2], "canvas": [512, 576], "art_width": 410},
    "cedar-workshop": {"category": "industrial", "footprint": [2, 3], "canvas": [640, 576], "art_width": 520},
    "cedar-factory": {"category": "industrial", "footprint": [3, 3], "canvas": [768, 640], "art_width": 620},
    "cedar-utility-industry": {"category": "industrial", "footprint": [2, 3], "canvas": [640, 576], "art_width": 520},
}

PIVOT_X = 0.5
PIVOT_Y = 0.18


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def package_asset(alpha_path: Path, output_path: Path, canvas_size: tuple[int, int], art_width: int) -> None:
    image = Image.open(alpha_path).convert("RGBA")
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"{alpha_path} contains no visible pixels")

    art = image.crop(bounds)
    scale = art_width / art.width
    art_height = round(art.height * scale)
    art = art.resize((art_width, art_height), Image.Resampling.LANCZOS)

    canvas_width, canvas_height = canvas_size
    pivot_from_top = round(canvas_height * (1 - PIVOT_Y))
    left = round(canvas_width * PIVOT_X - art.width / 2)
    top = pivot_from_top - art.height
    if left < 0 or top < 0 or left + art.width > canvas_width:
        raise ValueError(f"{alpha_path} does not fit its canonical canvas")

    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    canvas.alpha_composite(art, (left, top))
    canvas.save(output_path, format="PNG", compress_level=9, optimize=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--alpha-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--source-dir", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    manifest_assets = []
    for name, spec in ASSETS.items():
        alpha_path = args.alpha_dir / f"{name}-alpha.png"
        output_path = args.output_dir / f"{name}.png"
        package_asset(alpha_path, output_path, tuple(spec["canvas"]), spec["art_width"])
        source_path = args.source_dir / f"{name}-source.png"
        manifest_assets.append(
            {
                "id": name,
                "category": spec["category"],
                "footprint_tiles": spec["footprint"],
                "pixel_size": spec["canvas"],
                "file": output_path.name,
                "source_file": source_path.name,
                "source_sha256": sha256(source_path),
                "packaged_sha256": sha256(output_path),
                "renderer_rotation_degrees": 0,
                "renderer_skew": 0,
                "renderer_scale_override": 1,
            }
        )

    manifest = {
        "schema": 1,
        "family_id": "cedar-market-commercial-industrial-v1",
        "license": "Copyright JFM Systems; original project-bound generated artwork",
        "generation_mode": "OpenAI built-in image_gen, separate generation per asset, chroma-key alpha workflow",
        "projection": {
            "id": "citysim-isometric-2to1-southeast-v1",
            "tile_width": 88,
            "tile_height": 44,
            "elevation_step": 22,
            "visible_facades": ["southwest", "southeast"],
        },
        "ground_contract": {
            "pivot_x": PIVOT_X,
            "pivot_y": PIVOT_Y,
            "key_light": "northwest",
            "shadow_direction": "southeast",
            "shadow_offset_pixels": [16, -10],
        },
        "assets": manifest_assets,
        "representative_renders": [
            "cedar-market-commercial-industrial-block-1280x800.png",
            "cedar-market-commercial-industrial-block-900x600.png",
        ],
    }
    (args.output_dir / "family.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
