#!/usr/bin/env python3
"""Compose source-only four-view assets on CitySim's fixed isometric grid."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
BLENDER_DIR = HERE.parent
PIPELINE_DIR = BLENDER_DIR / "FourViewPipeline"
PRODUCTION_DIR = BLENDER_DIR / "FourViewProduction"
sys.dont_write_bytecode = True
sys.path.insert(0, str(PIPELINE_DIR))

from png_canonical import decode_rgba_png, encode_rgba_png  # noqa: E402


PIVOT = (192, 300)
HALF_TILE = (44, 22)
CAMERA = "camNE"

ASSETS = {
    "copper_finch_house": PIPELINE_DIR / "example/renders/copper_finch_house_camNE.png",
    "marigold_court_house": PRODUCTION_DIR / "ResidentialCivic/renders/marigold_court_house_camNE.png",
    "hearthside_council_hall": PRODUCTION_DIR / "ResidentialCivic/renders/hearthside_council_hall_camNE.png",
    "brickline_rowhouse_apartments": PRODUCTION_DIR / "ResidentialExpansion/brickline_rowhouse_apartments/renders/brickline_rowhouse_apartments_camNE.png",
    "harbor_corner_storefront": PRODUCTION_DIR / "CommercialIndustrial/harbor_corner_storefront/renders/harbor_corner_storefront_camNE.png",
    "ironleaf_service_workshop": PRODUCTION_DIR / "CommercialIndustrial/ironleaf_service_workshop/renders/ironleaf_service_workshop_camNE.png",
    "axis_civic_road": PRODUCTION_DIR / "Environment/assets/axis_civic_road/renders/axis_civic_road_camNE.png",
    "axis_civic_road_dressed": PRODUCTION_DIR / "Environment/assets/axis_civic_road_dressed/renders/axis_civic_road_dressed_camNE.png",
    "pocket_grove_park": PRODUCTION_DIR / "Environment/assets/pocket_grove_park/renders/pocket_grove_park_camNE.png",
}

# Every authored lot declares a 2x2-tile footprint. Adjacent centers therefore
# sit exactly two tile units apart; the two rows touch the one-tile road corridor
# without overlap, sprite scaling, or post-render transforms.
PLACEMENTS = [
    (0, 0, "copper_finch_house"),
    (2, 0, "marigold_court_house"),
    (4, 0, "brickline_rowhouse_apartments"),
    (6, 0, "hearthside_council_hall"),
    (8, 0, "copper_finch_house"),
    (0, 4, "pocket_grove_park"),
    (2, 4, "ironleaf_service_workshop"),
    (4, 4, "harbor_corner_storefront"),
    (6, 4, "marigold_court_house"),
    (8, 4, "hearthside_council_hall"),
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tile_pivot(origin: tuple[int, int], x: int, y: int) -> tuple[int, int]:
    return (
        origin[0] + (x - y) * HALF_TILE[0],
        origin[1] + (x + y) * HALF_TILE[1],
    )


def blend_pixel(buffer: bytearray, width: int, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if x < 0 or y < 0 or x >= width:
        return
    offset = (y * width + x) * 4
    if offset < 0 or offset + 3 >= len(buffer):
        return
    source_alpha = color[3]
    if source_alpha == 0:
        return
    inverse = 255 - source_alpha
    for channel in range(3):
        buffer[offset + channel] = (color[channel] * source_alpha + buffer[offset + channel] * inverse + 127) // 255
    buffer[offset + 3] = 255


def draw_line(buffer: bytearray, width: int, height: int, start: tuple[int, int], end: tuple[int, int], color: tuple[int, int, int, int]) -> None:
    x0, y0 = start
    x1, y1 = end
    dx = abs(x1 - x0)
    sx = 1 if x0 < x1 else -1
    dy = -abs(y1 - y0)
    sy = 1 if y0 < y1 else -1
    error = dx + dy
    while True:
        if 0 <= y0 < height:
            blend_pixel(buffer, width, x0, y0, color)
        if x0 == x1 and y0 == y1:
            break
        twice = 2 * error
        if twice >= dy:
            error += dy
            x0 += sx
        if twice <= dx:
            error += dx
            y0 += sy


def draw_diamond(buffer: bytearray, width: int, height: int, pivot: tuple[int, int], fill: tuple[int, int, int, int]) -> None:
    center_x, center_y = pivot
    for delta_y in range(-HALF_TILE[1], HALF_TILE[1] + 1):
        y = center_y + delta_y
        if y < 0 or y >= height:
            continue
        half_width = round(HALF_TILE[0] * (1.0 - abs(delta_y) / HALF_TILE[1]))
        for x in range(center_x - half_width, center_x + half_width + 1):
            blend_pixel(buffer, width, x, y, fill)
    points = [
        (center_x, center_y - HALF_TILE[1]),
        (center_x + HALF_TILE[0], center_y),
        (center_x, center_y + HALF_TILE[1]),
        (center_x - HALF_TILE[0], center_y),
    ]
    for start, end in zip(points, points[1:] + points[:1]):
        draw_line(buffer, width, height, start, end, (120, 137, 120, 130))


def composite_rgba(destination: bytearray, destination_width: int, destination_height: int, source: bytes, source_width: int, source_height: int, left: int, top: int) -> None:
    for source_y in range(source_height):
        target_y = top + source_y
        if target_y < 0 or target_y >= destination_height:
            continue
        for source_x in range(source_width):
            target_x = left + source_x
            if target_x < 0 or target_x >= destination_width:
                continue
            source_offset = (source_y * source_width + source_x) * 4
            alpha = source[source_offset + 3]
            if alpha == 0:
                continue
            blend_pixel(
                destination,
                destination_width,
                target_x,
                target_y,
                tuple(source[source_offset : source_offset + 4]),
            )


def background(width: int, height: int) -> bytearray:
    top = (35, 45, 47)
    bottom = (20, 27, 29)
    result = bytearray(width * height * 4)
    for y in range(height):
        denominator = max(1, height - 1)
        color = tuple((top[channel] * (denominator - y) + bottom[channel] * y) // denominator for channel in range(3))
        row = bytes((*color, 255)) * width
        start = y * width * 4
        result[start : start + width * 4] = row
    return result


def compose(width: int, height: int, output: Path, sprites: dict[str, tuple[int, int, bytes]]) -> None:
    result = background(width, height)
    origin = (width // 2 - 110, height // 2 - 90)

    for y in range(-1, 6):
        for x in range(-1, 11):
            fill = (73, 76, 74, 255) if y == 2 else (82, 102, 88, 255)
            draw_diamond(result, width, height, tile_pivot(origin, x, y), fill)

    roads = [
        (x, 2, "axis_civic_road_dressed" if x in (-1, 3, 7) else "axis_civic_road")
        for x in range(-1, 10)
    ]
    for x, y, asset_id in sorted(roads, key=lambda item: (item[0] + item[1], item[1], item[0])):
        pivot = tile_pivot(origin, x, y)
        source_width, source_height, rgba = sprites[asset_id]
        composite_rgba(result, width, height, rgba, source_width, source_height, pivot[0] - PIVOT[0], pivot[1] - PIVOT[1])

    for x, y, asset_id in sorted(PLACEMENTS, key=lambda item: (item[0] + item[1], item[1], item[0])):
        pivot = tile_pivot(origin, x, y)
        source_width, source_height, rgba = sprites[asset_id]
        composite_rgba(result, width, height, rgba, source_width, source_height, pivot[0] - PIVOT[0], pivot[1] - PIVOT[1])

    encode_rgba_png(output, width, height, bytes(result))


def main() -> None:
    sprites = {}
    sources = []
    for asset_id, path in ASSETS.items():
        width, height, rgba = decode_rgba_png(path)
        if (width, height) != (384, 384):
            raise RuntimeError(f"SOURCE_CANVAS_MISMATCH: {asset_id}: {(width, height)}")
        sprites[asset_id] = (width, height, rgba)
        sources.append({"assetId": asset_id, "path": path.relative_to(BLENDER_DIR).as_posix(), "sha256": sha256(path)})

    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        path = HERE / f"four-view-source-block-{width}x{height}.png"
        compose(width, height, path, sprites)
        outputs.append({"path": path.name, "dimensions": [width, height], "sha256": sha256(path), "bytes": path.stat().st_size})

    manifest = {
        "schema": "citysim.world-art.four-view-source-integration.v1",
        "status": "source-only-review-evidence-not-live",
        "liveAsset": False,
        "camera": CAMERA,
        "canvasPolicy": "native-sprites-no-scale-no-crop",
        "postRenderCompensation": "none",
        "grid": {"projectedTilePixels": [88, 44], "screenVectors": [[44, 22], [-44, 22]], "footprintPivotPixel": list(PIVOT)},
        "placements": [{"tileCenter": [x, y], "assetId": asset_id} for x, y, asset_id in PLACEMENTS],
        "sources": sources,
        "outputs": outputs,
    }
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("FOUR_VIEW_SOURCE_INTEGRATION_PASS")


if __name__ == "__main__":
    main()
