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
BUILDING_SIZE = (160, 192)
DIAMOND = [(72, 1), (143, 36), (72, 71), (1, 36)]

PALETTE = {
    "grass": ["#5e8754", "#5f8855", "#5d8653", "#608956", "#5e8652", "#608856"],
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
            draw.line((center, ROAD_ENDPOINTS[bit]), fill=rgba(PALETTE["sidewalk"]), width=42)
        for bit in edges:
            draw.line((center, ROAD_ENDPOINTS[bit]), fill=rgba(PALETTE["curb"]), width=36)
        for bit in edges:
            draw.line((center, ROAD_ENDPOINTS[bit]), fill=rgba(PALETTE["asphalt"]), width=30)

        if len(edges) >= 3:
            for radius, color in [
                (21, PALETTE["sidewalk"]),
                (18, PALETTE["curb"]),
                (15, PALETTE["asphalt"]),
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


def iso_prism(
    draw: ImageDraw.ImageDraw,
    center_x: int,
    ground_y: int,
    width: int,
    depth: int,
    height: int,
    base: str,
    roof: str,
) -> dict[str, tuple[int, int]]:
    roof_y = ground_y - height
    n = (center_x, roof_y - depth // 2)
    e = (center_x + width // 2, roof_y)
    s = (center_x, roof_y + depth // 2)
    w = (center_x - width // 2, roof_y)
    be = (e[0], e[1] + height)
    bs = (s[0], s[1] + height)
    bw = (w[0], w[1] + height)
    base_rgb = rgba(base)
    left = tuple(max(0, int(channel * 0.82)) for channel in base_rgb[:3]) + (255,)
    right = tuple(max(0, int(channel * 0.64)) for channel in base_rgb[:3]) + (255,)
    outline = rgba("#283536", 220)
    draw.polygon([w, s, bs, bw], fill=left, outline=outline)
    draw.polygon([s, e, be, bs], fill=right, outline=outline)
    draw.polygon([n, e, s, w], fill=rgba(roof), outline=outline)
    draw.line([n, e, s, w, n], fill=rgba("#f4e4bd", 64), width=2)
    return {"n": n, "e": e, "s": s, "w": w, "be": be, "bs": bs, "bw": bw}


def cast_shadow(layer: Image.Image, center_x: int, ground_y: int, width: int, depth: int, reach: int = 18) -> None:
    draw = ImageDraw.Draw(layer, "RGBA")
    draw.polygon(
        [
            (center_x - width // 2 + 8, ground_y - depth // 2 + 4),
            (center_x + width // 2 + reach, ground_y + 3),
            (center_x + reach, ground_y + depth // 2 + 12),
            (center_x - width // 2, ground_y + 3),
        ],
        fill=(19, 30, 29, 96),
    )


def windows(draw: ImageDraw.ImageDraw, x: int, y: int, columns: int, rows: int, spacing_x: int, spacing_y: int, color: str) -> None:
    for row in range(rows):
        for column in range(columns):
            left = x + column * spacing_x
            top = y + row * spacing_y
            draw.rounded_rectangle((left, top, left + 7, top + 8), radius=1, fill=rgba(color, 228), outline=rgba("#fff5d6", 90), width=1)


def tree(draw: ImageDraw.ImageDraw, x: int, y: int, scale: float, variant: int) -> None:
    trunk = rgba("#614832")
    greens = ["#3f774a", "#4f8750", "#67975a"]
    draw.rounded_rectangle((x - 2, y - int(16 * scale), x + 2, y), radius=1, fill=trunk)
    radius_x = int(12 * scale)
    radius_y = int(15 * scale)
    draw.ellipse((x - radius_x, y - int(27 * scale), x + radius_x, y - int(27 * scale) + radius_y), fill=rgba(greens[variant % 3]), outline=rgba("#284b35", 220), width=2)
    draw.ellipse((x - radius_x // 2 - 4, y - int(25 * scale), x + 1, y - int(18 * scale)), fill=rgba("#afc977", 78))


def place_asset(family: str, variant: int) -> Image.Image:
    image = Image.new("RGBA", BUILDING_SIZE, (0, 0, 0, 0))
    shadow = Image.new("RGBA", BUILDING_SIZE, (0, 0, 0, 0))
    cast_shadow(shadow, 80, 164, 72, 30, 21)
    shadow = shadow.filter(ImageFilter.GaussianBlur(3.0))
    image = Image.alpha_composite(image, shadow)
    draw = ImageDraw.Draw(image, "RGBA")

    if family == "residential":
        bases = ["#d8a45f", "#d9c28a", "#9db77e"]
        if variant == 0:
            iso_prism(draw, 80, 160, 72, 32, 58, bases[0], "#954b36")
            draw.polygon([(47, 101), (80, 80), (113, 101), (80, 116)], fill=rgba("#a6543d"), outline=rgba("#4c3430"))
            windows(draw, 54, 116, 3, 2, 20, 17, "#f2d17d")
            draw.rounded_rectangle((76, 139, 88, 160), radius=2, fill=rgba("#5e4438"))
            tree(draw, 36, 161, 0.92, variant)
        elif variant == 1:
            for index, x in enumerate((58, 83, 108)):
                iso_prism(draw, x, 161 - index * 2, 36, 22, 54 + index * 5, ["#d4b377", "#c98162", "#e0caa1"][index], "#51494a")
                windows(draw, x - 13, 121 - index * 5, 2, 2, 13, 17, "#f4d58b")
            draw.line((43, 164, 125, 164), fill=rgba("#ede2c2", 170), width=4)
        else:
            iso_prism(draw, 80, 162, 72, 32, 90, bases[2], "#3c4b4c")
            windows(draw, 50, 86, 4, 4, 17, 17, "#f0d18a")
            for y in (112, 132):
                draw.line((48, y, 108, y), fill=rgba("#efe6d1", 180), width=3)
            tree(draw, 34, 163, 0.78, variant)
        draw.ellipse((113, 151, 138, 166), fill=rgba("#4e854c"), outline=rgba("#2b5536"), width=2)

    elif family == "commercial":
        if variant == 0:
            iso_prism(draw, 80, 163, 86, 34, 64, "#b5654f", "#454b4d")
            draw.rounded_rectangle((46, 135, 116, 158), radius=3, fill=rgba("#4d8d91"), outline=rgba("#d7f2e7", 160), width=2)
            for x in (58, 76, 94):
                draw.line((x, 137, x, 157), fill=rgba("#253b41", 170), width=2)
            draw.polygon([(43, 132), (120, 132), (113, 143), (50, 143)], fill=rgba("#d09b4e"), outline=rgba("#604334"))
            windows(draw, 50, 108, 4, 1, 18, 14, "#9ed4cf")
        elif variant == 1:
            iso_prism(draw, 80, 163, 65, 30, 112, "#5b8587", "#8eb9b0")
            for y in range(66, 145, 16):
                draw.rectangle((54, y, 110, y + 7), fill=rgba("#8fc8ca", 210), outline=rgba("#d7f3ea", 100), width=1)
            draw.rectangle((70, 145, 91, 162), fill=rgba("#314a4f"))
        else:
            iso_prism(draw, 80, 163, 92, 38, 50, "#d4a44e", "#744738")
            draw.polygon([(40, 128), (119, 128), (110, 143), (49, 143)], fill=rgba("#e9c968"), outline=rgba("#5a4034"))
            draw.rounded_rectangle((48, 142, 112, 160), radius=2, fill=rgba("#5d9390"), outline=rgba("#d8eee4", 150), width=2)
            draw.line((80, 142, 80, 160), fill=rgba("#30464a"), width=2)
        for x in (32, 128):
            draw.ellipse((x - 7, 151, x + 7, 164), fill=rgba("#4f824d"), outline=rgba("#31583a"), width=2)

    elif family == "industrial":
        if variant == 0:
            iso_prism(draw, 76, 164, 96, 38, 56, "#9c6448", "#53595a")
            for x in (42, 64, 86, 108):
                draw.polygon([(x, 108), (x + 10, 96), (x + 20, 108)], fill=rgba("#9da19b"), outline=rgba("#3b4142"))
            draw.rectangle((51, 139, 73, 163), fill=rgba("#3c4445"), outline=rgba("#c1bba6", 130), width=2)
            draw.rectangle((84, 139, 106, 163), fill=rgba("#3c4445"), outline=rgba("#c1bba6", 130), width=2)
            draw.polygon([(119, 122), (132, 122), (128, 64), (122, 64)], fill=rgba("#6f4537"), outline=rgba("#30393a"))
            draw.rectangle((120, 75, 131, 82), fill=rgba("#d39b49"))
        elif variant == 1:
            iso_prism(draw, 72, 164, 94, 38, 48, "#7d827c", "#abb0a7")
            for x in (43, 70, 97):
                draw.rectangle((x, 140, x + 20, 163), fill=rgba("#3d4546"), outline=rgba("#c7c1ad", 130), width=2)
            for x, y, r in ((121, 137, 16), (134, 149, 11)):
                draw.ellipse((x - r, y - r // 2, x + r, y + r // 2), fill=rgba("#a8aaa1"), outline=rgba("#444d4d"), width=2)
                draw.rectangle((x - r, y, x + r, y + 14), fill=rgba("#8b8f89"))
        else:
            iso_prism(draw, 67, 164, 70, 34, 70, "#b4834d", "#43494a")
            iso_prism(draw, 116, 164, 44, 26, 38, "#747b76", "#aeb2a8")
            draw.rectangle((44, 140, 67, 163), fill=rgba("#343d3e"), outline=rgba("#d0c7ac", 125), width=2)
            draw.polygon([(83, 119), (95, 119), (92, 72), (86, 72)], fill=rgba("#6f4537"), outline=rgba("#313a3b"))
        draw.rectangle((25, 154, 40, 165), fill=rgba("#8a5e35"), outline=rgba("#493929"), width=2)

    elif family == "park":
        # Park art is an authored place composition rather than a building icon.
        draw.ellipse((34, 135, 126, 172), fill=rgba("#4b8451", 190), outline=rgba("#315c3c", 220), width=2)
        if variant == 0:
            for index, (x, y) in enumerate(((44, 157), (68, 144), (100, 151), (124, 160))):
                tree(draw, x, y, 0.88 + (index % 2) * 0.12, index)
            draw.line((58, 165, 102, 143), fill=rgba("#d2b980", 220), width=7)
            draw.rectangle((79, 153, 101, 158), fill=rgba("#6f4c32"))
        elif variant == 1:
            draw.ellipse((52, 141, 113, 165), fill=rgba("#5c9da0"), outline=rgba("#b8dbd0", 180), width=3)
            tree(draw, 38, 159, 0.98, 1)
            tree(draw, 124, 158, 0.84, 2)
            draw.arc((60, 146, 103, 160), 10, 170, fill=rgba("#e8f2d8", 120), width=2)
        else:
            for index, (x, y) in enumerate(((38, 161), (121, 160), (56, 143))):
                tree(draw, x, y, 0.82, index)
            draw.polygon([(65, 139), (86, 126), (108, 139), (86, 151)], fill=rgba("#a65b42"), outline=rgba("#493b35"), width=2)
            for x in (70, 102):
                draw.rectangle((x, 139, x + 4, 161), fill=rgba("#6c5137"))
            for x in range(61, 116, 10):
                draw.ellipse((x, 162, x + 5, 167), fill=rgba(["#e9c656", "#d77a85", "#886da8"][x % 3]))

    else:  # civic
        stones = ["#c9c1a7", "#b8c5bd", "#d1bfa0"]
        if variant == 0:
            iso_prism(draw, 80, 164, 84, 36, 70, stones[0], "#47756e")
            for x in (53, 66, 94, 107):
                draw.rectangle((x, 119, x + 5, 160), fill=rgba("#ede4ca"), outline=rgba("#777366", 100), width=1)
            draw.ellipse((61, 67, 99, 104), fill=rgba("#4f867d"), outline=rgba("#d7e3d4", 130), width=2)
            draw.polygon([(80, 54), (86, 69), (74, 69)], fill=rgba("#d6b85e"))
        elif variant == 1:
            iso_prism(draw, 80, 164, 90, 38, 58, stones[1], "#4f6663")
            iso_prism(draw, 80, 112, 34, 24, 60, stones[1], "#476f69")
            draw.ellipse((72, 66, 88, 82), fill=rgba("#f0d27a"), outline=rgba("#505653"), width=2)
            windows(draw, 48, 126, 4, 1, 18, 14, "#95bdba")
        else:
            iso_prism(draw, 80, 164, 94, 40, 62, stones[2], "#765143")
            draw.polygon([(38, 102), (80, 75), (122, 102)], fill=rgba("#d9c9a8"), outline=rgba("#67594c"), width=2)
            for x in (50, 65, 90, 105):
                draw.rectangle((x, 117, x + 5, 160), fill=rgba("#efe3c8"), outline=rgba("#756957", 100), width=1)
            draw.line((38, 164, 122, 164), fill=rgba("#f4ead1"), width=6)
        draw.line((47, 167, 113, 167), fill=rgba("#e4d7bc", 190), width=5)

    image.save(OUTPUT / f"place_{family}_{variant}.png", optimize=True)
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
        for variant in range(3):
            place_asset(family, variant)
            generated.append(OUTPUT / f"place_{family}_{variant}.png")
    write_manifest(generated)


if __name__ == "__main__":
    main()
