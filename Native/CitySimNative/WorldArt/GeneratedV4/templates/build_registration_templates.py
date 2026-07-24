#!/usr/bin/env python3
"""Build exact transparent registration guides for generated-v4 calibration art."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
CANVAS = (1536, 1024)
TILE = (512, 256)
PIVOT = (768, 896)
FOOTPRINTS = {"1x1": (1, 1), "2x1": (2, 1), "2x2": (2, 2)}


def projected(i: int, j: int) -> tuple[int, int]:
    return ((i - j) * TILE[0] // 2, (i + j) * TILE[1] // 2)


def geometry(width: int, depth: int) -> dict[str, object]:
    raw = [projected(0, 0), projected(width, 0), projected(width, depth), projected(0, depth)]
    min_x = min(point[0] for point in raw)
    max_x = max(point[0] for point in raw)
    max_y = max(point[1] for point in raw)
    offset = (PIVOT[0] - (min_x + max_x) // 2, PIVOT[1] - max_y)
    footprint = [(x + offset[0], y + offset[1]) for x, y in raw]
    sockets = {
        "north": midpoint(footprint[0], footprint[1]),
        "east": midpoint(footprint[1], footprint[2]),
        "south": midpoint(footprint[2], footprint[3]),
        "west": midpoint(footprint[3], footprint[0]),
    }
    return {
        "footprint": footprint,
        "sockets": sockets,
        "ground_pivot": PIVOT,
        "height_bounds": [256, 96, 1280, PIVOT[1]],
        "shadow_bounds": [PIVOT[0], 512, 1456, 976],
        "northwest_light_origin": [176, 128],
    }


def midpoint(a: tuple[int, int], b: tuple[int, int]) -> tuple[int, int]:
    return ((a[0] + b[0]) // 2, (a[1] + b[1]) // 2)


def draw_template(name: str, width: int, depth: int) -> dict[str, object]:
    spec = geometry(width, depth)
    image = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    footprint = [tuple(point) for point in spec["footprint"]]
    draw.polygon(footprint, fill=(40, 208, 255, 24), outline=(40, 208, 255, 255), width=6)

    height = tuple(spec["height_bounds"])
    shadow = tuple(spec["shadow_bounds"])
    draw.rectangle(height, outline=(255, 210, 64, 220), width=4)
    draw.rectangle(shadow, outline=(128, 92, 255, 180), width=4)

    socket_colors = {
        "north": (255, 255, 255, 255),
        "east": (255, 176, 64, 255),
        "south": (255, 96, 96, 255),
        "west": (96, 255, 160, 255),
    }
    for socket_name, point in spec["sockets"].items():
        x, y = point
        color = socket_colors[socket_name]
        draw.ellipse((x - 12, y - 12, x + 12, y + 12), fill=color, outline=(20, 24, 28, 255), width=3)
        draw.line((x - 28, y, x + 28, y), fill=color, width=5)

    px, py = PIVOT
    draw.line((px - 20, py, px + 20, py), fill=(255, 0, 255, 255), width=5)
    draw.line((px, py - 20, px, py + 20), fill=(255, 0, 255, 255), width=5)
    lx, ly = spec["northwest_light_origin"]
    draw.line((lx, ly, lx + 180, ly + 90), fill=(255, 238, 150, 255), width=8)
    draw.polygon([(lx + 180, ly + 90), (lx + 145, ly + 84), (lx + 164, ly + 60)], fill=(255, 238, 150, 255))

    path = ROOT / f"registration-{name}.png"
    image.save(path, optimize=True)
    spec.update(
        {
            "id": name,
            "canvas_pixels": list(CANVAS),
            "tile_source_pixels": list(TILE),
            "footprint_tiles": [width, depth],
            "transparent_background": True,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
    )
    return spec


def main() -> None:
    templates = [draw_template(name, *size) for name, size in FOOTPRINTS.items()]
    manifest = {
        "schema": 1,
        "projection": "orthographic 2:1 isometric",
        "world_tile_points": [72, 36],
        "authoring_tile_pixels": list(TILE),
        "ground_pivot": list(PIVOT),
        "light_direction": "northwest key",
        "shadow_direction": "southeast at 2:1",
        "templates": templates,
    }
    (ROOT / "registration-templates.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
