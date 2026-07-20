#!/usr/bin/env python3
"""Generate CitySim's original deterministic 2× isometric world atlas."""

from __future__ import annotations

import hashlib
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Sources" / "CitySimNative" / "Resources" / "WorldAssets.atlas"
TILE_SIZE = (144, 72)
DIAMOND = [(72, 1), (143, 36), (72, 71), (1, 36)]

PALETTE = {
    "grass": ["#5c8654", "#5f8956", "#598351", "#618a57", "#5b8450", "#638b59"],
    "grass_dark": "#3c6642",
    "grass_light": "#85a867",
    "soil": "#74543a",
    "soil_dark": "#4b382b",
    "park": "#4f8a55",
    "park_light": "#7eaa68",
    "stone": "#a49b86",
    "stone_light": "#c4bba4",
    "yard": "#766b58",
    "line": "#2f5940",
}


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_color.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def diamond_mask() -> Image.Image:
    mask = Image.new("L", TILE_SIZE, 0)
    ImageDraw.Draw(mask).polygon(DIAMOND, fill=255)
    return mask


def seeded_ground(name: str, base: str, seed: int, material: str) -> Image.Image:
    rng = random.Random(seed)
    image = Image.new("RGBA", TILE_SIZE, (0, 0, 0, 0))
    mask = diamond_mask()
    field = Image.new("RGBA", TILE_SIZE, rgba(base))
    texture = Image.new("RGBA", TILE_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(texture, "RGBA")

    for _ in range(46):
        x = rng.randint(5, 138)
        y = rng.randint(6, 66)
        width = rng.randint(3, 13)
        height = rng.randint(1, 4)
        if material in {"plaza", "yard"}:
            color = rgba(PALETTE["soil_dark"], rng.randint(12, 30))
        else:
            color = rgba(rng.choice([PALETTE["grass_dark"], PALETTE["grass_light"]]), rng.randint(10, 32))
        draw.ellipse((x - width, y - height, x + width, y + height), fill=color)

    if material == "grass":
        for _ in range(10):
            x = rng.randint(12, 132)
            y = rng.randint(12, 60)
            draw.line((x, y, x + rng.choice([-3, 3]), y - 3), fill=rgba(PALETTE["grass_light"], 58), width=1)
    elif material == "park":
        draw.arc((26, 16, 118, 58), 14, 174, fill=rgba("#c9b47b", 120), width=5)
        draw.arc((18, 18, 100, 64), 188, 338, fill=rgba("#c9b47b", 92), width=4)
    elif material == "plaza":
        for x in range(18, 132, 18):
            draw.line((x, 21, x - 28, 53), fill=rgba(PALETTE["stone_light"], 35), width=1)
        draw.line((18, 36, 72, 63), fill=rgba(PALETTE["stone_light"], 48), width=2)
        draw.line((126, 36, 72, 63), fill=rgba(PALETTE["stone_light"], 48), width=2)
    elif material == "yard":
        for _ in range(7):
            x = rng.randint(22, 122)
            y = rng.randint(20, 52)
            draw.rectangle((x, y, x + rng.randint(4, 12), y + 2), fill=rgba("#d1c4a0", 35))

    field = Image.alpha_composite(field, texture.filter(ImageFilter.GaussianBlur(0.45)))
    image.paste(field, (0, 0), mask)
    if material not in {"grass"}:
        edge = ImageDraw.Draw(image, "RGBA")
        edge.line(DIAMOND + [DIAMOND[0]], fill=rgba(PALETTE["line"], 76), width=2, joint="curve")
    image.save(OUTPUT / f"{name}.png", optimize=True)
    return image


def write_manifest(files: list[Path]) -> None:
    assets = []
    for path in sorted(files):
        assets.append(
            {
                "name": path.stem,
                "file": path.name,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "pixels": list(Image.open(path).size),
            }
        )
    manifest = {
        "schema": 1,
        "title": "CitySim Golden Neighborhood World Atlas",
        "authoring": "Original deterministic Pillow geometry and seeded raster texture",
        "source": "Native/CitySimNative/WorldArt/generate_world_assets.py",
        "external_sources": [],
        "concept_reference_sampled": False,
        "license": "Copyright JFM Systems; original repository artwork",
        "projection": "2:1 isometric",
        "scale": "2x",
        "filtering": "linear",
        "light_direction": "northwest key, southeast shadow",
        "palette": PALETTE,
        "assets": assets,
    }
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    generated: list[Path] = []
    for index, color in enumerate(PALETTE["grass"]):
        seeded_ground(f"terrain_grass_{index}", color, 2100 + index, "grass")
        generated.append(OUTPUT / f"terrain_grass_{index}.png")
    specifications = [
        ("terrain_park", PALETTE["park"], 2201, "park"),
        ("terrain_lawn", "#628a54", 2202, "grass"),
        ("terrain_plaza", PALETTE["stone"], 2203, "plaza"),
        ("terrain_yard", PALETTE["yard"], 2204, "yard"),
    ]
    for name, color, seed, material in specifications:
        seeded_ground(name, color, seed, material)
        generated.append(OUTPUT / f"{name}.png")
    write_manifest(generated)


if __name__ == "__main__":
    main()
