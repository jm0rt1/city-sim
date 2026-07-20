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
    "asphalt": "#2e3438",
    "asphalt_light": "#474e50",
    "curb": "#aaa68f",
    "sidewalk": "#c4bba4",
    "lane": "#e9c55f",
    "crosswalk": "#eee9d6",
}

ROAD_ENDPOINTS = {
    1: (108, 18),  # north
    2: (108, 54),  # east
    4: (36, 54),   # south
    8: (36, 18),   # west
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


def dashed_line(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], color, width: int) -> None:
    x1, y1 = start
    x2, y2 = end
    distance = max(abs(x2 - x1), abs(y2 - y1))
    if distance == 0:
        return
    for step in range(4, distance, 13):
        next_step = min(distance, step + 6)
        a = step / distance
        b = next_step / distance
        draw.line(
            (x1 + (x2 - x1) * a, y1 + (y2 - y1) * a,
             x1 + (x2 - x1) * b, y1 + (y2 - y1) * b),
            fill=color,
            width=width,
        )


def road_asset(mask_value: int) -> Image.Image:
    image = Image.new("RGBA", TILE_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    center = (72, 36)
    edges = [bit for bit in ROAD_ENDPOINTS if mask_value & bit]

    if not edges:
        for radius, color in [
            (26, PALETTE["sidewalk"]),
            (22, PALETTE["curb"]),
            (18, PALETTE["asphalt"]),
        ]:
            draw.ellipse((72 - radius, 36 - radius // 2, 72 + radius, 36 + radius // 2), fill=rgba(color))
    else:
        for bit in edges:
            draw.line((center, ROAD_ENDPOINTS[bit]), fill=rgba(PALETTE["sidewalk"]), width=50)
        for bit in edges:
            draw.line((center, ROAD_ENDPOINTS[bit]), fill=rgba(PALETTE["curb"]), width=42)
        for bit in edges:
            draw.line((center, ROAD_ENDPOINTS[bit]), fill=rgba(PALETTE["asphalt"]), width=34)

        for radius, color in [
            (25, PALETTE["sidewalk"]),
            (21, PALETTE["curb"]),
            (17, PALETTE["asphalt"]),
        ]:
            draw.ellipse((72 - radius, 36 - radius // 2, 72 + radius, 36 + radius // 2), fill=rgba(color))

        for bit in edges:
            dashed_line(draw, center, ROAD_ENDPOINTS[bit], rgba(PALETTE["lane"], 225), 3)

        if len(edges) >= 3:
            for bit in edges:
                x, y = ROAD_ENDPOINTS[bit]
                vx, vy = x - 72, y - 36
                length = max(1.0, (vx * vx + vy * vy) ** 0.5)
                nx, ny = -vy / length, vx / length
                cx, cy = 72 + vx * 0.48, 36 + vy * 0.48
                for offset in (-7, -2, 3, 8):
                    px, py = cx + vx / length * offset, cy + vy / length * offset
                    draw.line(
                        (px - nx * 7, py - ny * 7, px + nx * 7, py + ny * 7),
                        fill=rgba(PALETTE["crosswalk"], 218),
                        width=2,
                    )

    # Surface wear is intentionally decorative and stable; it claims no traffic state.
    rng = random.Random(3100 + mask_value)
    for _ in range(10):
        x = rng.randint(45, 99)
        y = rng.randint(24, 48)
        draw.line((x, y, x + rng.randint(2, 7), y + rng.choice([-1, 0, 1])), fill=rgba(PALETTE["asphalt_light"], 45), width=1)

    clipped = Image.new("RGBA", TILE_SIZE, (0, 0, 0, 0))
    clipped.paste(image, (0, 0), diamond_mask())
    clipped.save(OUTPUT / f"road_mask_{mask_value:02d}.png", optimize=True)
    return clipped


def frontage_asset(family: str) -> Image.Image:
    image = Image.new("RGBA", TILE_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    accents = {
        "residential": ("#d7c493", "#496f48"),
        "commercial": ("#b8ad99", "#4c7370"),
        "industrial": ("#8c806b", "#d2a44d"),
        "park": ("#ceb983", "#5b9258"),
        "civic": ("#d2c7ae", "#4f7771"),
    }
    paving, accent = accents[family]
    draw.line((36, 54, 54, 45, 72, 40), fill=rgba(paving, 225), width=7)
    draw.line((37, 54, 55, 45, 72, 40), fill=rgba("#fff8dc", 68), width=2)
    draw.line(DIAMOND + [DIAMOND[0]], fill=rgba(paving, 96), width=2)

    if family == "residential":
        draw.ellipse((18, 34, 31, 42), fill=rgba(accent, 220))
        draw.ellipse((112, 31, 127, 40), fill=rgba(accent, 210))
    elif family == "commercial":
        draw.rectangle((20, 31, 38, 36), fill=rgba(accent, 190))
        draw.rectangle((104, 37, 123, 42), fill=rgba(accent, 180))
    elif family == "industrial":
        for x in (22, 31, 111, 120):
            draw.line((x, 29, x + 8, 39), fill=rgba(accent, 190), width=3)
    elif family == "park":
        draw.arc((18, 12, 126, 63), 10, 172, fill=rgba(paving, 180), width=5)
    else:
        draw.polygon([(52, 46), (72, 35), (92, 46), (72, 56)], fill=rgba(paving, 155))
        draw.line((52, 46, 72, 35, 92, 46), fill=rgba(accent, 170), width=2)

    image.save(OUTPUT / f"frontage_{family}.png", optimize=True)
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
    for mask_value in range(16):
        road_asset(mask_value)
        generated.append(OUTPUT / f"road_mask_{mask_value:02d}.png")
    for family in ("residential", "commercial", "industrial", "park", "civic"):
        frontage_asset(family)
        generated.append(OUTPUT / f"frontage_{family}.png")
    write_manifest(generated)


if __name__ == "__main__":
    main()
