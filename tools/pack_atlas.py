#!/usr/bin/env python3
"""
tools/pack_atlas.py
-------------------
Standalone atlas packing tool for City-Sim (Phase 1B).

Usage (run from the project root)::

    python tools/pack_atlas.py [--source-dir assets/tiles/source]

Reads individual source PNGs from ``assets/tiles/source/``.
Creates colored diamond placeholder PNGs for any sprite IDs that have no
source file yet, so the tool works out-of-the-box without real art.

Resizes each source image to the display tile size (64 × 32 px) and packs
all tiles into two atlas sheets::

    assets/tiles/terrain_atlas.png    — terrain sprites
    assets/tiles/buildings_atlas.png  — building sprites (including damaged)

Emits ``assets/tiles/atlas_manifest.json`` mapping::

    sprite_id → {"atlas_file": "<path>", "col": <int>, "row": <int>}

The manifest is consumed by :class:`src.gui.renderer.tile_atlas.TileAtlas`
(Phase 1C) to load real sprites instead of procedural colored diamonds.

Notes
-----
* This script uses **Pillow** only; it does *not* import pygame or any src module.
* Sprite IDs and placeholder colours must stay in sync with the
  ``_PLACEHOLDER_COLORS`` dict in ``src/gui/renderer/tile_atlas.py``.
* Atlas sheets are 8 columns wide; rows are added as needed.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

TILE_W: int = 64
TILE_H: int = 32
ATLAS_COLS: int = 8  # number of tile columns per atlas sheet

# Sprite IDs and their placeholder fill colours (R, G, B).
# Keep these in sync with _PLACEHOLDER_COLORS in src/gui/renderer/tile_atlas.py.
_TERRAIN_SPRITES: dict[str, tuple[int, int, int]] = {
    "terrain_grass_0":   (106, 168,  79),
    "terrain_park_0":    ( 56, 118,  29),
    "terrain_road_h":    (100, 100, 100),
    "terrain_road_v":    ( 80,  80,  80),
    "terrain_water_0":   ( 66, 133, 244),
}

_BUILDING_SPRITES: dict[str, tuple[int, int, int]] = {
    # Normal variants
    "building_res_small":              (255, 200, 100),
    "building_res_medium":             (255, 153,  51),
    "building_res_large":              (255, 111,   0),
    "building_commercial":             (100, 181, 246),
    "building_industrial":             (158, 158, 158),
    "building_city_hall":              (149, 117, 205),
    "building_hospital":               (239,  83,  80),
    "building_school":                 (255, 238,  88),
    "building_fire_station":           (244,  67,  54),
    "building_police_station":         ( 66,  66, 160),
    "building_power_plant":            ( 78,  52,  46),
    # Damaged variants
    "building_res_small_damaged":      (180, 140,  70),
    "building_res_medium_damaged":     (180, 107,  36),
    "building_res_large_damaged":      (180,  77,   0),
    "building_commercial_damaged":     ( 70, 127, 172),
    "building_industrial_damaged":     (110, 110, 110),
    "building_city_hall_damaged":      (104,  82, 144),
    "building_hospital_damaged":       (167,  58,  56),
    "building_school_damaged":         (178, 167,  62),
    "building_fire_station_damaged":   (171,  47,  38),
    "building_police_station_damaged": ( 46,  46, 112),
    "building_power_plant_damaged":    ( 54,  36,  32),
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_diamond_placeholder(
    color: tuple[int, int, int],
    width: int = TILE_W,
    height: int = TILE_H,
) -> Image.Image:
    """Create a filled isometric diamond placeholder in *color*."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    hw, hh = width // 2, height // 2
    points = [(hw, 0), (width - 1, hh), (hw, height - 1), (0, hh)]
    draw.polygon(points, fill=(*color, 255))
    draw.polygon(points, outline=(0, 0, 0, 180))
    return img


def _load_or_create_tile(
    sprite_id: str,
    color: tuple[int, int, int],
    source_dir: Path,
) -> Image.Image:
    """
    Return a tile image for *sprite_id*.

    If ``<source_dir>/<sprite_id>.png`` exists it is loaded and resized to
    (TILE_W × TILE_H) via LANCZOS downsampling.  Otherwise a procedural
    colored diamond placeholder is returned.
    """
    source_path = source_dir / f"{sprite_id}.png"
    if source_path.exists():
        img = Image.open(source_path).convert("RGBA")
        if img.size != (TILE_W, TILE_H):
            img = img.resize((TILE_W, TILE_H), Image.LANCZOS)
        return img
    return _make_diamond_placeholder(color)


_HEIGHT_TILES: dict[str, int] = {
    # Terrain tiles — always 1
    "terrain_grass_0":   1,
    "terrain_park_0":    1,
    "terrain_road_h":    1,
    "terrain_road_v":    1,
    "terrain_water_0":   1,
    # Small buildings — 1
    "building_res_small":              1,
    "building_res_small_damaged":      1,
    # Medium buildings — 2
    "building_res_medium":             2,
    "building_res_medium_damaged":     2,
    "building_commercial":             2,
    "building_commercial_damaged":     2,
    # Large buildings — 3
    "building_res_large":              3,
    "building_res_large_damaged":      3,
    "building_industrial":             3,
    "building_industrial_damaged":     3,
    "building_city_hall":              3,
    "building_city_hall_damaged":      3,
    "building_hospital":               2,
    "building_hospital_damaged":       2,
    "building_school":                 2,
    "building_school_damaged":         2,
    "building_fire_station":           1,
    "building_fire_station_damaged":   1,
    "building_police_station":         2,
    "building_police_station_damaged": 2,
    "building_power_plant":            3,
    "building_power_plant_damaged":    3,
}


def _pack_sprites(
    sprites: dict[str, tuple[int, int, int]],
    source_dir: Path,
    atlas_path: Path,
) -> dict[str, dict[str, object]]:
    """
    Pack *sprites* into a single atlas PNG at *atlas_path*.

    Returns a partial manifest dict mapping each sprite_id to its atlas
    location entry.
    """
    sprite_ids = list(sprites.keys())
    n = len(sprite_ids)
    rows = max(1, (n + ATLAS_COLS - 1) // ATLAS_COLS)

    atlas_img = Image.new("RGBA", (ATLAS_COLS * TILE_W, rows * TILE_H), (0, 0, 0, 0))
    manifest_entries: dict[str, dict[str, object]] = {}

    for idx, sprite_id in enumerate(sprite_ids):
        col = idx % ATLAS_COLS
        row = idx // ATLAS_COLS
        tile_img = _load_or_create_tile(sprite_id, sprites[sprite_id], source_dir)
        atlas_img.paste(tile_img, (col * TILE_W, row * TILE_H))
        manifest_entries[sprite_id] = {
            "atlas_file": str(atlas_path),
            "col": col,
            "row": row,
            "height_tiles": _HEIGHT_TILES.get(sprite_id, 1),
        }

    atlas_path.parent.mkdir(parents=True, exist_ok=True)
    atlas_img.save(str(atlas_path))
    return manifest_entries


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------


def pack(source_dir: Path = Path("assets/tiles/source")) -> None:
    """Run the full atlas packing pipeline."""
    source_dir.mkdir(parents=True, exist_ok=True)

    terrain_atlas = Path("assets/tiles/terrain_atlas.png")
    buildings_atlas = Path("assets/tiles/buildings_atlas.png")
    manifest_path = Path("assets/tiles/atlas_manifest.json")

    manifest: dict[str, dict[str, object]] = {}

    print(f"Packing {len(_TERRAIN_SPRITES)} terrain sprites → {terrain_atlas}")
    manifest.update(_pack_sprites(_TERRAIN_SPRITES, source_dir, terrain_atlas))

    print(f"Packing {len(_BUILDING_SPRITES)} building sprites → {buildings_atlas}")
    manifest.update(_pack_sprites(_BUILDING_SPRITES, source_dir, buildings_atlas))

    manifest_path.write_text(json.dumps(manifest, indent=2))
    print(f"Manifest written → {manifest_path}  ({len(manifest)} entries)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="City-Sim sprite atlas packer (Phase 1B)"
    )
    parser.add_argument(
        "--source-dir",
        default="assets/tiles/source",
        help="Directory containing source PNG files (default: assets/tiles/source)",
    )
    args = parser.parse_args()
    pack(source_dir=Path(args.source_dir))
