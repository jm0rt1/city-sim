#!/usr/bin/env python3
"""Build target-face-dominant PLAY-027 references without rejected pixels."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = ROOT.parents[4]
TEMPLATE_OUTPUT = ROOT / "templates" / "directional-v3"
ANCHOR_OUTPUT = ROOT / "anchors" / "residential-v3"
CANVAS = (1536, 1024)
BACKGROUND = (255, 0, 255)
TARGET = (42, 236, 116)
WHITE = (245, 255, 247)
PIVOT = (768, 896)
FOOTPRINT = [
    (768, 640),
    (1024, 768),
    (768, 896),
    (512, 768),
]
EDGES = {
    "north": (FOOTPRINT[0], FOOTPRINT[1]),
    "east": (FOOTPRINT[1], FOOTPRINT[2]),
    "south": (FOOTPRINT[2], FOOTPRINT[3]),
    "west": (FOOTPRINT[3], FOOTPRINT[0]),
}
PRISM_HEIGHT = 360
FAMILY_ANCHOR = (
    REPOSITORY_ROOT
    / "Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration"
    / "residential_l01/source-v01.png"
)
FAMILY_ANCHOR_SHA256 = (
    "e15a388c2a1a0a55488457211c23939f70eca255cbae733ee0f7b39b141c962e"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def midpoint(a: tuple[int, int], b: tuple[int, int]) -> tuple[int, int]:
    return ((a[0] + b[0]) // 2, (a[1] + b[1]) // 2)


def segment(
    a: tuple[int, int], b: tuple[int, int], half_width: float
) -> tuple[tuple[int, int], tuple[int, int]]:
    center = midpoint(a, b)
    dx = b[0] - a[0]
    dy = b[1] - a[1]
    length = math.hypot(dx, dy)
    unit = (dx / length, dy / length)
    return (
        (
            round(center[0] - unit[0] * half_width),
            round(center[1] - unit[1] * half_width),
        ),
        (
            round(center[0] + unit[0] * half_width),
            round(center[1] + unit[1] * half_width),
        ),
    )


def outward_arrow_points(
    socket: tuple[int, int],
) -> tuple[tuple[int, int], tuple[int, int]]:
    center = (768, 768)
    vector = (socket[0] - center[0], socket[1] - center[1])
    length = math.hypot(*vector)
    unit = (vector[0] / length, vector[1] / length)
    return (
        (
            round(socket[0] + unit[0] * 190),
            round(socket[1] + unit[1] * 190),
        ),
        (
            round(socket[0] + unit[0] * 35),
            round(socket[1] + unit[1] * 35),
        ),
    )


def draw_arrow(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
) -> None:
    draw.line((start, end), fill=TARGET, width=14)
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
    draw.polygon((end, left, right), fill=TARGET)


def build_directional_template(direction: str) -> dict[str, object]:
    image = Image.new("RGB", CANVAS, BACKGROUND)
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    top = [(x, y - PRISM_HEIGHT) for x, y in FOOTPRINT]
    face_indices = {
        "north": (0, 1),
        "east": (1, 2),
        "south": (2, 3),
        "west": (3, 0),
    }

    draw.polygon(FOOTPRINT, fill=(38, 176, 214), outline=WHITE, width=8)
    for name, (first, second) in face_indices.items():
        if name == direction:
            continue
        face = (FOOTPRINT[first], FOOTPRINT[second], top[second], top[first])
        draw.polygon(face, fill=(57, 65, 78), outline=(138, 148, 164), width=4)

    draw.polygon(top, fill=(36, 42, 52), outline=(138, 148, 164), width=5)

    first, second = face_indices[direction]
    target_face = (
        FOOTPRINT[first],
        FOOTPRINT[second],
        top[second],
        top[first],
    )
    draw.polygon(target_face, fill=TARGET, outline=WHITE, width=9)

    edge = EDGES[direction]
    socket = midpoint(*edge)
    door_start, door_end = segment(*edge, half_width=42)
    door_top_start = (door_start[0], door_start[1] - 126)
    door_top_end = (door_end[0], door_end[1] - 126)
    draw.polygon(
        (door_start, door_end, door_top_end, door_top_start),
        fill=WHITE,
        outline=(24, 72, 48),
        width=7,
    )
    draw.line(edge, fill=TARGET, width=20)
    draw.ellipse(
        (socket[0] - 20, socket[1] - 20, socket[0] + 20, socket[1] + 20),
        fill=TARGET,
        outline=WHITE,
        width=5,
    )
    arrow_start, arrow_end = outward_arrow_points(socket)
    draw_arrow(draw, arrow_start, arrow_end)

    draw.line(
        (PIVOT[0] - 24, PIVOT[1], PIVOT[0] + 24, PIVOT[1]),
        fill=WHITE,
        width=6,
    )
    draw.line(
        (PIVOT[0], PIVOT[1] - 24, PIVOT[0], PIVOT[1] + 24),
        fill=WHITE,
        width=6,
    )

    title = f"{direction.upper()} TARGET FRONTAGE PLANE"
    draw.rectangle(
        (56, 46, 740, 104),
        fill=(30, 34, 42),
        outline=WHITE,
        width=3,
    )
    draw.text((78, 67), title, fill=WHITE, font=font)
    draw.text(
        (78, 118),
        "The dominant green plane is the only entrance-bearing facade. "
        "Guide marks are not artwork.",
        fill=WHITE,
        font=font,
    )

    TEMPLATE_OUTPUT.mkdir(parents=True, exist_ok=True)
    path = TEMPLATE_OUTPUT / f"registration-{direction}.png"
    image.save(path, optimize=True)
    non_door_edge_sample = segment(*edge, half_width=104)[0]
    return {
        "viewDirection": direction,
        "file": str(path.relative_to(REPOSITORY_ROOT)),
        "sha256": sha256(path),
        "canvasPixels": list(CANVAS),
        "footprintTiles": [1, 1],
        "footprintPolygonSource": [list(point) for point in FOOTPRINT],
        "groundPivotSource": list(PIVOT),
        "targetFacePolygonSource": [list(point) for point in target_face],
        "frontageEdgeSource": [list(point) for point in edge],
        "frontageSocketSource": list(socket),
        "doorBaseSource": [list(door_start), list(door_end)],
        "targetEdgePixelSample": list(non_door_edge_sample),
        "orientationTransform": "none",
        "productionSelected": False,
    }


def build_material_board() -> dict[str, object]:
    if sha256(FAMILY_ANCHOR) != FAMILY_ANCHOR_SHA256:
        raise SystemExit("residential family anchor hash changed")
    source = Image.open(FAMILY_ANCHOR).convert("RGB")
    if source.size != CANVAS:
        raise SystemExit(f"unexpected residential family anchor size {source.size}")

    crops = [
        ("charcoal slate roof", (620, 190, 930, 390)),
        ("warm brick wall", (790, 390, 1010, 630)),
        ("limestone trim", (520, 390, 690, 640)),
        ("door and stoop scale", (650, 560, 850, 850)),
        ("divided-light window scale", (520, 390, 800, 650)),
    ]
    board = Image.new("RGB", CANVAS, BACKGROUND)
    draw = ImageDraw.Draw(board)
    font = ImageFont.load_default()
    draw.rectangle(
        (56, 46, 1320, 104),
        fill=(30, 34, 42),
        outline=WHITE,
        width=3,
    )
    draw.text(
        (78, 67),
        "RESIDENTIAL MATERIAL AND SCALE SWATCHES — NO CAMERA OR COMPOSITION AUTHORITY",
        fill=WHITE,
        font=font,
    )

    records = []
    panel_width = 272
    panel_height = 560
    for index, (name, crop_box) in enumerate(crops):
        x = 56 + index * 292
        y = 176
        crop = source.crop(crop_box)
        crop.thumbnail((panel_width - 24, panel_height - 72), Image.Resampling.LANCZOS)
        panel = Image.new("RGB", (panel_width, panel_height), (30, 34, 42))
        panel_draw = ImageDraw.Draw(panel)
        panel_draw.rectangle(
            (0, 0, panel_width - 1, panel_height - 1),
            outline=WHITE,
            width=3,
        )
        panel_draw.text((12, 14), name, fill=WHITE, font=font)
        origin = (
            (panel_width - crop.width) // 2,
            52 + (panel_height - 64 - crop.height) // 2,
        )
        panel.paste(crop, origin)
        board.paste(panel, (x, y))
        records.append(
            {
                "name": name,
                "sourceCropPixels": list(crop_box),
                "boardPanelPixels": [x, y, panel_width, panel_height],
            }
        )

    ANCHOR_OUTPUT.mkdir(parents=True, exist_ok=True)
    path = ANCHOR_OUTPUT / "material-scale-board.png"
    board.save(path, optimize=True)
    return {
        "file": str(path.relative_to(REPOSITORY_ROOT)),
        "sha256": sha256(path),
        "sourceFamilyAnchorFile": str(FAMILY_ANCHOR.relative_to(REPOSITORY_ROOT)),
        "sourceFamilyAnchorSHA256": FAMILY_ANCHOR_SHA256,
        "cameraCompositionAuthority": False,
        "registrationAuthority": False,
        "orientationTransform": "none",
        "crops": records,
        "productionSelected": False,
    }


def main() -> None:
    material_board = build_material_board()
    templates = [
        build_directional_template(direction)
        for direction in ("north", "east", "south", "west")
    ]
    manifest = {
        "schema": 1,
        "task": "PLAY-027",
        "treatmentID": "play-027-rci-reference-treatment-v3",
        "purpose": "target-face-dominant non-shipping ImageGen references",
        "diagnosis": {
            "v2NearFacePrivileged": True,
            "v2PainterOrder": [
                "north",
                "west",
                "east",
                "south",
            ],
            "fullFamilyAnchorNearEntrancePrivileged": True,
            "repair": "draw target face last and replace full family anchor with deterministic material and scale swatches",
        },
        "projection": "orthographic 2:1 isometric",
        "canvasPixels": list(CANVAS),
        "footprintTiles": [1, 1],
        "groundPivotSource": list(PIVOT),
        "materialScaleBoard": material_board,
        "generatedPixelsAreGeometryAuthority": False,
        "rejectedPixelsUsed": False,
        "productionSelected": False,
        "templates": templates,
    }
    manifest_path = TEMPLATE_OUTPUT / "reference-treatment-manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
