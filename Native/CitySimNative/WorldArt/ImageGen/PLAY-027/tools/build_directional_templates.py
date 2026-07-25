#!/usr/bin/env python3
"""Build task-owned PLAY-027 directional registration references."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "templates" / "directional-v2"
CANVAS = (1536, 1024)
BACKGROUND = (255, 0, 255)
PIVOT = (768, 896)
FOOTPRINT = {
    "northwest": (768, 640),
    "northeast": (1024, 768),
    "southeast": (768, 896),
    "southwest": (512, 768),
}
EDGES = {
    "north": (FOOTPRINT["northwest"], FOOTPRINT["northeast"]),
    "east": (FOOTPRINT["northeast"], FOOTPRINT["southeast"]),
    "south": (FOOTPRINT["southeast"], FOOTPRINT["southwest"]),
    "west": (FOOTPRINT["southwest"], FOOTPRINT["northwest"]),
}
SOCKETS = {
    name: ((start[0] + end[0]) // 2, (start[1] + end[1]) // 2)
    for name, (start, end) in EDGES.items()
}
PRISM_HEIGHT = 360


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def midpoint(a: tuple[int, int], b: tuple[int, int]) -> tuple[int, int]:
    return ((a[0] + b[0]) // 2, (a[1] + b[1]) // 2)


def segment_around_midpoint(
    a: tuple[int, int], b: tuple[int, int], half_width: float
) -> tuple[tuple[int, int], tuple[int, int]]:
    center = midpoint(a, b)
    dx = b[0] - a[0]
    dy = b[1] - a[1]
    length = math.hypot(dx, dy)
    ux = dx / length
    uy = dy / length
    return (
        (round(center[0] - ux * half_width), round(center[1] - uy * half_width)),
        (round(center[0] + ux * half_width), round(center[1] + uy * half_width)),
    )


def arrow(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
    color: tuple[int, int, int],
) -> None:
    draw.line((start, end), fill=color, width=14)
    angle = math.atan2(end[1] - start[1], end[0] - start[0])
    head = 30
    left = (
        round(end[0] - head * math.cos(angle - math.pi / 6)),
        round(end[1] - head * math.sin(angle - math.pi / 6)),
    )
    right = (
        round(end[0] - head * math.cos(angle + math.pi / 6)),
        round(end[1] - head * math.sin(angle + math.pi / 6)),
    )
    draw.polygon((end, left, right), fill=color)


def build(direction: str) -> dict[str, object]:
    image = Image.new("RGB", CANVAS, BACKGROUND)
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()

    ordered = [
        FOOTPRINT["northwest"],
        FOOTPRINT["northeast"],
        FOOTPRINT["southeast"],
        FOOTPRINT["southwest"],
    ]
    top = [(x, y - PRISM_HEIGHT) for x, y in ordered]

    draw.polygon(ordered, fill=(38, 176, 214), outline=(225, 252, 255), width=8)
    face_colors = {
        "north": (118, 133, 150),
        "east": (86, 99, 116),
        "south": (178, 155, 124),
        "west": (151, 132, 108),
    }
    index_edges = {
        "north": (0, 1),
        "east": (1, 2),
        "south": (2, 3),
        "west": (3, 0),
    }
    for name in ("north", "west", "east", "south"):
        first, second = index_edges[name]
        draw.polygon(
            (ordered[first], ordered[second], top[second], top[first]),
            fill=face_colors[name],
            outline=(238, 234, 218),
            width=5,
        )

    draw.polygon(top, fill=(60, 70, 82), outline=(238, 234, 218), width=7)
    ridge_start = midpoint(top[0], top[3])
    ridge_end = midpoint(top[1], top[2])
    draw.line((ridge_start, ridge_end), fill=(226, 199, 143), width=8)

    edge = EDGES[direction]
    socket = SOCKETS[direction]
    door_a, door_b = segment_around_midpoint(*edge, half_width=38)
    door_top_a = (door_a[0], door_a[1] - 116)
    door_top_b = (door_b[0], door_b[1] - 116)
    draw.polygon(
        (door_a, door_b, door_top_b, door_top_a),
        fill=(42, 236, 116),
        outline=(245, 255, 247),
        width=6,
    )
    draw.line(edge, fill=(42, 236, 116), width=18)
    draw.ellipse(
        (socket[0] - 18, socket[1] - 18, socket[0] + 18, socket[1] + 18),
        fill=(42, 236, 116),
        outline=(245, 255, 247),
        width=5,
    )

    center = (768, 768)
    outward_x = socket[0] - center[0]
    outward_y = socket[1] - center[1]
    outward_length = math.hypot(outward_x, outward_y)
    unit = (outward_x / outward_length, outward_y / outward_length)
    arrow_start = (
        round(socket[0] + unit[0] * 190),
        round(socket[1] + unit[1] * 190),
    )
    arrow_end = (
        round(socket[0] + unit[0] * 35),
        round(socket[1] + unit[1] * 35),
    )
    arrow(draw, arrow_start, arrow_end, (42, 236, 116))

    draw.line((PIVOT[0] - 24, PIVOT[1], PIVOT[0] + 24, PIVOT[1]), fill=(255, 255, 255), width=6)
    draw.line((PIVOT[0], PIVOT[1] - 24, PIVOT[0], PIVOT[1] + 24), fill=(255, 255, 255), width=6)

    title = f"{direction.upper()} FRONTAGE — ORTHOGRAPHIC 2:1 ISOMETRIC, NEVER FRONT ELEVATION"
    draw.rectangle((56, 46, 1110, 104), fill=(30, 34, 42), outline=(245, 255, 247), width=3)
    draw.text((78, 67), title, fill=(245, 255, 247), font=font)
    draw.text(
        (78, 118),
        "Green edge, door, socket, and arrow define the required road-facing frontage. Do not render guide marks.",
        fill=(245, 255, 247),
        font=font,
    )

    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / f"registration-{direction}.png"
    image.save(path, optimize=True)
    return {
        "viewDirection": direction,
        "file": str(path.relative_to(ROOT.parents[4])),
        "sha256": sha256(path),
        "canvasPixels": list(CANVAS),
        "footprintTiles": [1, 1],
        "groundPivotSource": list(PIVOT),
        "frontageSocketSource": list(socket),
        "orientationTransform": "none",
        "productionSelected": False,
    }


def main() -> None:
    records = [build(direction) for direction in ("north", "east", "south", "west")]
    manifest = {
        "schema": 1,
        "task": "PLAY-027",
        "templateID": "play-027-rci-directional-v2",
        "purpose": "task-owned non-shipping ImageGen directional registration reference",
        "projection": "orthographic 2:1 isometric",
        "canvasPixels": list(CANVAS),
        "footprintTiles": [1, 1],
        "groundPivotSource": list(PIVOT),
        "generatedPixelsAreGeometryAuthority": False,
        "productionSelected": False,
        "templates": records,
    }
    (OUTPUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
