#!/usr/bin/env python3
"""Build four original, production-quality CitySim residential sprites."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
PRODUCTION = HERE.parent
BLENDER_ROOT = PRODUCTION.parent
REPO_ROOT = HERE.parents[5]
CANONICAL = BLENDER_ROOT / "FourViewPipeline"
DENSITY_BUILDER = PRODUCTION / "Density" / "build_and_render.py"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))


def load_density_helpers():
    spec = importlib.util.spec_from_file_location("citysim_quality_family_helpers", DENSITY_BUILDER)
    if spec is None or spec.loader is None:
        raise RuntimeError("DENSITY_HELPER_IMPORT_FAILED")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


kit = load_density_helpers()
CONFIG = json.loads((HERE / "pipeline.json").read_text(encoding="utf-8"))
VIEWS = CONFIG["cameraRig"]["views"]
kit.HERE = HERE
kit.CONFIG = CONFIG
kit.VIEWS = VIEWS

material = kit.material
box = kit.box
cylinder = kit.cylinder
cone = kit.cone
sphere = kit.sphere
beam = kit.beam
pyramid_roof = kit.pyramid_roof
gable_roof = kit.gable_roof
reset = kit.reset
configure_scene = kit.configure_scene
canonical_rig = kit.canonical_rig
asset_root = kit.asset_root
render_views = kit.render_views
contact_sheet = kit.contact_sheet
artifact_info = kit.artifact_info
canonicalize_png = kit.canonicalize_png
decode_rgba_png = kit.decode_rgba_png
encode_rgba_png = kit.encode_rgba_png


def residential_palette(
    prefix,
    siding,
    accent,
    roof,
    masonry,
    *,
    trim=(0.94, 0.88, 0.72, 1),
    glass=(0.24, 0.46, 0.58, 1),
    wood=(0.50, 0.29, 0.14, 1),
    grass=(0.35, 0.48, 0.24, 1),
    flower=(0.72, 0.26, 0.20, 1),
):
    return {
        "grass": material(prefix + "GardenGround", grass, roughness=0.84, texture_scale=7.0, bump=0.14),
        "soil": material(prefix + "GardenSoil", (0.24, 0.13, 0.075, 1), roughness=0.88, texture_scale=11.0, bump=0.19),
        "walk": material(prefix + "WarmWalk", (0.78, 0.68, 0.52, 1), roughness=0.74, texture_scale=12.0, bump=0.16),
        "foundation": material(prefix + "FoundationStone", masonry, texture_scale=14.0, bump=0.20),
        "wall": material(prefix + "Siding", siding, roughness=0.68, texture_scale=16.0, bump=0.16),
        "wallDark": material(prefix + "SidingShadow", tuple(value * 0.76 for value in siding[:3]) + (1,), roughness=0.72, texture_scale=17.0, bump=0.16),
        "trim": material(prefix + "ArchitecturalTrim", trim, roughness=0.56, texture_scale=6.0, bump=0.06),
        "roof": material(prefix + "Roof", roof, roughness=0.62, texture_scale=24.0, bump=0.28),
        "roofEdge": material(prefix + "RoofEdge", tuple(min(1.0, value * 1.30) for value in roof[:3]) + (1,), roughness=0.56, texture_scale=18.0, bump=0.14),
        "glassRecess": material(prefix + "WindowRecess", (0.055, 0.075, 0.085, 1), roughness=0.40, texture_scale=0),
        "glass": material(prefix + "WindowGlass", glass, roughness=0.18, metallic=0.08, texture_scale=0),
        "glassHighlight": material(prefix + "WindowHighlight", tuple(min(1.0, value * 1.55) for value in glass[:3]) + (1,), roughness=0.12, metallic=0.12, texture_scale=0),
        "windowWarmth": material(prefix + "WindowWarmth", (0.72, 0.48, 0.23, 1), roughness=0.38, texture_scale=0),
        "door": material(prefix + "Door", accent, roughness=0.48, texture_scale=8.0, bump=0.12),
        "brick": material(prefix + "ChimneyBrick", (0.64, 0.28, 0.15, 1), roughness=0.76, texture_scale=18.0, bump=0.23),
        "wood": material(prefix + "PorchWood", wood, roughness=0.64, texture_scale=11.0, bump=0.18),
        "iron": material(prefix + "Iron", (0.12, 0.15, 0.17, 1), roughness=0.38, metallic=0.62, texture_scale=8.0),
        "brass": material(prefix + "Brass", (0.72, 0.48, 0.16, 1), roughness=0.30, metallic=0.74, texture_scale=0),
        "leaf": material(prefix + "Leaf", (0.20, 0.44, 0.16, 1), roughness=0.78, texture_scale=7.0, bump=0.12),
        "leaf2": material(prefix + "LeafLight", (0.45, 0.64, 0.24, 1), roughness=0.76, texture_scale=6.0, bump=0.10),
        "flower": material(prefix + "Flower", flower, roughness=0.62, texture_scale=0),
        "flower2": material(prefix + "FlowerLight", tuple(min(1.0, value * 1.40) for value in flower[:3]) + (1,), roughness=0.58, texture_scale=0),
    }


def lot_and_foundation(root, prefix, mats, body_center=(0, 0.18), body_size=(2.76, 2.36)):
    lot = box(root, prefix + "LotGround", (0, 0, -0.10), (4, 4, 0.20), mats["grass"], edge=0.055)
    lot["worldFootprintTiles"] = [2, 2]
    lot["exactWorldFootprint"] = [4.0, 4.0]
    box(root, prefix + "FrontWalk", (0, -1.54, 0.025), (3.78, 0.70, 0.08), mats["walk"], edge=0.025)
    box(root, prefix + "EntryPath", (0, -1.24, 0.07), (0.66, 1.18, 0.12), mats["walk"], edge=0.025)
    box(root, prefix + "Foundation", (body_center[0], body_center[1], 0.24), (body_size[0] + 0.18, body_size[1] + 0.18, 0.48), mats["foundation"], edge=0.050)
    for side, y in (("Front", -1.88), ("Rear", 1.88)):
        box(root, prefix + side + "LotEdge", (0, y, 0.03), (3.86, 0.08, 0.08), mats["foundation"], edge=0.015)


def window_y(root, name, x, y, z, mats, width=0.48, height=0.64, shutters=False, outward=-1):
    surface = y + outward * 0.065
    frame = y + outward * 0.092
    box(root, name + "Recess", (x, y - outward * 0.018, z), (width + 0.22, 0.10, height + 0.20), mats["glassRecess"], edge=0.012)
    box(root, name + "WarmInterior", (x, surface - outward * 0.012, z), (width - 0.08, 0.025, height - 0.08), mats["windowWarmth"], edge=0.004)
    box(root, name + "Glass", (x, surface, z), (width, 0.045, height), mats["glass"], edge=0.009)
    box(root, name + "Top", (x, frame, z + height / 2 + 0.055), (width + 0.20, 0.095, 0.11), mats["trim"], edge=0.006)
    box(root, name + "Bottom", (x, frame, z - height / 2 - 0.050), (width + 0.18, 0.105, 0.10), mats["trim"], edge=0.006)
    for side in (-1, 1):
        box(root, name + ("LeftFrame" if side < 0 else "RightFrame"), (x + side * (width / 2 + 0.045), frame, z), (0.09, 0.095, height + 0.10), mats["trim"], edge=0.006)
    box(root, name + "MeetingRail", (x, frame + outward * 0.006, z), (width + 0.02, 0.055, 0.055), mats["trim"], edge=0.004)
    box(root, name + "Mullion", (x, frame + outward * 0.008, z), (0.055, 0.055, height - 0.02), mats["trim"], edge=0.004)
    box(root, name + "GlassGlint", (x - width * 0.22, frame + outward * 0.014, z + height * 0.18), (0.035, 0.025, height * 0.42), mats["glassHighlight"], edge=0.003)
    if shutters:
        for side in (-1, 1):
            shutter_x = x + side * (width / 2 + 0.15)
            box(root, name + ("LeftShutter" if side < 0 else "RightShutter"), (shutter_x, frame, z), (0.15, 0.075, height + 0.10), mats["door"], edge=0.008)
            for slat in (-0.22, 0, 0.22):
                box(root, f"{name}Shutter{side}Slat{slat}", (shutter_x, frame + outward * 0.018, z + slat * height), (0.13, 0.025, 0.035), mats["trim"], edge=0.003)


def window_x(root, name, x, y, z, mats, width=0.48, height=0.64, shutters=False, outward=-1):
    surface = x + outward * 0.065
    frame = x + outward * 0.092
    box(root, name + "Recess", (x - outward * 0.018, y, z), (0.10, width + 0.22, height + 0.20), mats["glassRecess"], edge=0.012)
    box(root, name + "WarmInterior", (surface - outward * 0.012, y, z), (0.025, width - 0.08, height - 0.08), mats["windowWarmth"], edge=0.004)
    box(root, name + "Glass", (surface, y, z), (0.045, width, height), mats["glass"], edge=0.009)
    box(root, name + "Top", (frame, y, z + height / 2 + 0.055), (0.095, width + 0.20, 0.11), mats["trim"], edge=0.006)
    box(root, name + "Bottom", (frame, y, z - height / 2 - 0.050), (0.105, width + 0.18, 0.10), mats["trim"], edge=0.006)
    for side in (-1, 1):
        box(root, name + ("NearFrame" if side < 0 else "FarFrame"), (frame, y + side * (width / 2 + 0.045), z), (0.095, 0.09, height + 0.10), mats["trim"], edge=0.006)
    box(root, name + "MeetingRail", (frame + outward * 0.006, y, z), (0.055, width + 0.02, 0.055), mats["trim"], edge=0.004)
    box(root, name + "Mullion", (frame + outward * 0.008, y, z), (0.055, 0.055, height - 0.02), mats["trim"], edge=0.004)
    box(root, name + "GlassGlint", (frame + outward * 0.014, y - width * 0.22, z + height * 0.18), (0.025, 0.035, height * 0.42), mats["glassHighlight"], edge=0.003)
    if shutters:
        for side in (-1, 1):
            shutter_y = y + side * (width / 2 + 0.15)
            box(root, name + ("NearShutter" if side < 0 else "FarShutter"), (frame, shutter_y, z), (0.075, 0.15, height + 0.10), mats["door"], edge=0.008)
            for slat in (-0.22, 0, 0.22):
                box(root, f"{name}Shutter{side}Slat{slat}", (frame + outward * 0.018, shutter_y, z + slat * height), (0.025, 0.13, 0.035), mats["trim"], edge=0.003)


def door_y(root, name, x, y, z, mats, double=False):
    width = 0.86 if double else 0.56
    box(root, name + "Recess", (x, y + 0.050, z), (width + 0.28, 0.18, 1.36), mats["glassRecess"], edge=0.018)
    box(root, name + "Door", (x, y - 0.070, z), (width, 0.10, 1.18), mats["door"], edge=0.018)
    for side in (-1, 1):
        box(root, f"{name}Jamb{side}", (x + side * (width / 2 + 0.07), y - 0.080, z + 0.04), (0.12, 0.12, 1.32), mats["trim"], edge=0.007)
    panel_centers = (-0.25, 0.22)
    leaf_centers = (-width * 0.24, width * 0.24) if double else (0,)
    for leaf_index, leaf_x in enumerate(leaf_centers):
        for panel_index, panel_z in enumerate(panel_centers):
            box(root, f"{name}Leaf{leaf_index}Panel{panel_index}", (x + leaf_x, y - 0.128, z + panel_z), (width * (0.36 if double else 0.64), 0.035, 0.30), mats["wallDark"], edge=0.010)
    box(root, name + "TransomRecess", (x, y + 0.015, z + 0.72), (width + 0.10, 0.08, 0.24), mats["glassRecess"], edge=0.006)
    box(root, name + "Transom", (x, y - 0.074, z + 0.72), (width, 0.05, 0.20), mats["glass"], edge=0.006)
    box(root, name + "TransomMullion", (x, y - 0.105, z + 0.72), (0.055, 0.035, 0.20), mats["trim"], edge=0.004)
    box(root, name + "Lintel", (x, y - 0.090, z + 0.90), (width + 0.34, 0.13, 0.14), mats["trim"], edge=0.008)
    sphere(root, name + "Knob", (x + width * 0.28, y - 0.145, z + 0.02), (0.055, 0.040, 0.055), mats["brass"], subdivisions=1)


def chimney(root, prefix, location, mats, height=1.36):
    x, y, z = location
    box(root, prefix + "Stack", (x, y, z), (0.38, 0.42, height), mats["brick"], edge=0.025)
    box(root, prefix + "Cap", (x, y, z + height / 2 + 0.06), (0.50, 0.54, 0.12), mats["trim"], edge=0.018)
    for band, band_z in enumerate((z - height * 0.18, z + height * 0.16)):
        box(root, f"{prefix}BrickBand{band}", (x, y - 0.216, band_z), (0.40, 0.025, 0.045), mats["trim"], edge=0.004)


def planter(root, prefix, x, y, mats, scale=0.24, flowers=False):
    box(root, prefix + "Bed", (x, y, 0.22), (0.54, 0.42, 0.28), mats["foundation"], edge=0.028)
    sphere(root, prefix + "Shrub", (x, y, 0.50), (scale, scale * 0.92, scale * 1.16), mats["leaf"])
    sphere(root, prefix + "Highlight", (x - 0.08, y - 0.06, 0.61), (scale * 0.52, scale * 0.46, scale * 0.55), mats["leaf2"])
    if flowers:
        for index, offset in enumerate((-0.16, 0.0, 0.16)):
            sphere(root, f"{prefix}Flower{index}", (x + offset, y - 0.19, 0.43), (0.065, 0.055, 0.075), mats["flower"] if index % 2 == 0 else mats["flower2"], subdivisions=1)


def hedge(root, prefix, start, end, mats, count=5, height=0.52):
    for index in range(count):
        t = index / max(1, count - 1)
        x = start[0] + (end[0] - start[0]) * t
        y = start[1] + (end[1] - start[1]) * t
        sphere(root, f"{prefix}Hedge{index}", (x, y, height * 0.62), (0.26, 0.22, height * 0.52), mats["leaf"] if index % 2 == 0 else mats["leaf2"])


def ornamental_tree(root, prefix, x, y, mats, height=1.65, flowering=False):
    cylinder(root, prefix + "Trunk", (x, y, height * 0.34), 0.085, height * 0.68, mats["wood"], vertices=12, edge=0.012)
    sphere(root, prefix + "CanopyA", (x, y, height * 0.76), (0.44, 0.38, 0.48), mats["leaf"])
    sphere(root, prefix + "CanopyB", (x - 0.22, y + 0.08, height * 0.86), (0.31, 0.28, 0.34), mats["leaf2"])
    if flowering:
        for index, offset in enumerate(((-0.26, -0.18), (0.20, -0.14), (0.08, 0.22))):
            sphere(root, f"{prefix}Blossom{index}", (x + offset[0], y + offset[1], height * (0.82 + index * 0.035)), (0.11, 0.09, 0.10), mats["flower2"], subdivisions=1)


def facade_bands(root, prefix, center, size, mats, levels, front=True, rear=True, sides=True):
    cx, cy = center
    width, depth = size
    for index, z in enumerate(levels):
        if front:
            box(root, f"{prefix}FrontSidingBand{index}", (cx, cy - depth / 2 - 0.026, z), (width - 0.14, 0.045, 0.045), mats["wallDark"], edge=0.004)
        if rear:
            box(root, f"{prefix}RearSidingBand{index}", (cx, cy + depth / 2 + 0.026, z), (width - 0.14, 0.045, 0.045), mats["wallDark"], edge=0.004)
        if sides:
            box(root, f"{prefix}WestSidingBand{index}", (cx - width / 2 - 0.026, cy, z), (0.045, depth - 0.14, 0.045), mats["wallDark"], edge=0.004)
            box(root, f"{prefix}EastSidingBand{index}", (cx + width / 2 + 0.026, cy, z), (0.045, depth - 0.14, 0.045), mats["wallDark"], edge=0.004)


def porch(root, prefix, center_x, front_y, width, depth, roof_z, mats, post_positions):
    box(root, prefix + "Deck", (center_x, front_y + depth * 0.16, 0.43), (width, depth, 0.18), mats["wood"], edge=0.028)
    box(root, prefix + "Step", (center_x, front_y - depth * 0.48, 0.26), (width * 0.58, 0.34, 0.16), mats["foundation"], edge=0.025)
    for board in range(5):
        board_y = front_y - depth * 0.28 + board * depth * 0.13
        box(root, f"{prefix}DeckBoard{board}", (center_x, board_y, 0.535), (width - 0.08, 0.035, 0.025), mats["trim"], edge=0.003)
    for index, x in enumerate(post_positions):
        box(root, f"{prefix}Post{index}", (x, front_y - depth * 0.20, roof_z - 0.70), (0.11, 0.11, 1.38), mats["trim"], edge=0.014)
        box(root, f"{prefix}PostBase{index}", (x, front_y - depth * 0.20, 0.66), (0.22, 0.22, 0.44), mats["foundation"], edge=0.022)
        box(root, f"{prefix}PostCapital{index}", (x, front_y - depth * 0.20, roof_z - 0.08), (0.22, 0.22, 0.13), mats["trim"], edge=0.010)
    box(root, prefix + "Roof", (center_x, front_y - depth * 0.10, roof_z), (width + 0.22, depth + 0.18, 0.16), mats["roof"], rotation=(math.radians(-9), 0, 0), edge=0.024)
    box(root, prefix + "Fascia", (center_x, front_y - depth * 0.48, roof_z - 0.06), (width + 0.25, 0.10, 0.18), mats["trim"], edge=0.012)
    box(root, prefix + "EaveShadow", (center_x, front_y - depth * 0.22, roof_z - 0.12), (width + 0.10, depth + 0.06, 0.055), mats["wallDark"], edge=0.008)
    if len(post_positions) >= 2:
        for rail_index, (left, right) in enumerate(zip(post_positions, post_positions[1:])):
            if left < center_x < right:
                continue
            box(root, f"{prefix}Rail{rail_index}", ((left + right) / 2, front_y - depth * 0.24, 0.88), (right - left, 0.065, 0.07), mats["trim"], edge=0.006)
            for baluster in range(1, 4):
                x = left + (right - left) * baluster / 4
                box(root, f"{prefix}Baluster{rail_index}_{baluster}", (x, front_y - depth * 0.24, 0.70), (0.045, 0.045, 0.34), mats["trim"], edge=0.004)


def roof_ridge(root, name, location, length, mats, axis="X"):
    dimensions = (length, 0.10, 0.12) if axis == "X" else (0.10, length, 0.12)
    box(root, name, location, dimensions, mats["roofEdge"], edge=0.010)


def alder_gable_cottage(root):
    m = residential_palette(
        "Alder",
        (0.55, 0.68, 0.47, 1),
        (0.56, 0.20, 0.13, 1),
        (0.42, 0.19, 0.11, 1),
        (0.56, 0.50, 0.40, 1),
        trim=(0.96, 0.88, 0.68, 1),
        glass=(0.27, 0.49, 0.57, 1),
        wood=(0.53, 0.30, 0.14, 1),
        grass=(0.36, 0.51, 0.25, 1),
        flower=(0.72, 0.22, 0.16, 1),
    )
    lot_and_foundation(root, "Alder", m, body_center=(0.05, 0.26), body_size=(2.74, 2.30))
    box(root, "AlderMainBody", (0.05, 0.27, 1.42), (2.72, 2.28, 2.24), m["wall"], edge=0.045)
    facade_bands(root, "Alder", (0.05, 0.27), (2.72, 2.28), m, (0.86, 1.14, 1.42, 1.70, 1.98))
    box(root, "AlderFrontBay", (0.82, -0.88, 1.34), (0.78, 0.62, 1.78), m["wallDark"], edge=0.040)
    pyramid_roof(root, "AlderBayRoof", (0.82, -0.90, 2.24), 1.02, 0.86, 0.34, m["roof"])
    box(root, "AlderBelt", (0.05, 0.27, 2.08), (2.84, 2.40, 0.12), m["trim"], edge=0.014)
    gable_roof(root, "AlderMainRoof", (0.05, 0.27, 2.52), (3.18, 2.72, 1.02), m["roof"], ridge_axis="X")
    roof_ridge(root, "AlderMainRidge", (0.05, 0.27, 3.56), 3.18, m)
    for side, y in (("Front", -1.13), ("Rear", 1.67)):
        box(root, f"Alder{side}Eave", (0.05, y, 2.48), (3.24, 0.13, 0.16), m["trim"], edge=0.010)
    box(root, "AlderFrontGableWall", (0.74, -1.02, 2.42), (1.16, 0.46, 0.76), m["wall"], edge=0.035)
    gable_roof(root, "AlderCrossGable", (0.74, -1.12, 2.68), (1.54, 0.96, 0.72), m["roof"], ridge_axis="Y")
    roof_ridge(root, "AlderCrossRidge", (0.74, -1.12, 3.42), 0.96, m, axis="Y")
    box(root, "AlderGableFascia", (0.74, -1.63, 2.68), (1.60, 0.12, 0.14), m["trim"], edge=0.008)
    porch(root, "AlderPorch", -0.34, -1.30, 1.62, 0.62, 2.05, m, (-0.96, 0.28))
    door_y(root, "AlderFront", -0.34, -0.91, 1.15, m)
    window_y(root, "AlderBayFront", 0.82, -1.20, 1.48, m, width=0.48, height=0.72)
    window_y(root, "AlderGableWindow", 0.74, -1.255, 2.55, m, width=0.42, height=0.48)
    window_y(root, "AlderRearLeft", -0.62, 1.425, 1.48, m, shutters=True, outward=1)
    window_y(root, "AlderRearRight", 0.60, 1.425, 1.48, m, shutters=True, outward=1)
    window_x(root, "AlderEastFront", 1.425, -0.30, 1.48, m, shutters=True, outward=1)
    window_x(root, "AlderEastRear", 1.425, 0.72, 1.48, m, shutters=True, outward=1)
    window_x(root, "AlderWestFront", -1.325, -0.28, 1.48, m, shutters=True)
    window_x(root, "AlderWestRear", -1.325, 0.72, 1.48, m, shutters=True)
    for x in (-1.28, 1.38):
        for y in (-0.72, 1.30):
            box(root, f"AlderCornerTrim{x}_{y}", (x, y, 1.44), (0.13, 0.13, 2.12), m["trim"], edge=0.010)
    chimney(root, "AlderChimney", (-0.83, 0.62, 3.25), m, height=1.28)
    for index, (x, y) in enumerate(((-1.48, -1.48), (1.48, -1.48), (1.52, 1.38))):
        planter(root, f"AlderGarden{index}", x, y, m, scale=0.22 + index * 0.025, flowers=index < 2)
    hedge(root, "AlderRearHedge", (-0.92, 1.68), (0.84, 1.68), m, count=6, height=0.42)
    ornamental_tree(root, "AlderFloweringTree", -1.42, 1.24, m, height=1.52, flowering=True)
    for index, x in enumerate((-1.72, -1.38, -1.04)):
        box(root, f"AlderPicket{index}", (x, 0.78, 0.44), (0.055, 0.08, 0.62), m["trim"], edge=0.004)
    box(root, "AlderPicketRail", (-1.38, 0.78, 0.48), (0.78, 0.055, 0.07), m["trim"], edge=0.004)
    box(root, "AlderBenchSeat", (-1.08, -1.63, 0.48), (0.74, 0.24, 0.10), m["wood"], edge=0.014)
    for x in (-1.36, -0.80):
        box(root, f"AlderBenchLeg{x}", (x, -1.63, 0.31), (0.07, 0.18, 0.28), m["iron"], edge=0.006)


def birch_lane_bungalow(root):
    m = residential_palette(
        "Birch",
        (0.82, 0.69, 0.39, 1),
        (0.64, 0.18, 0.12, 1),
        (0.24, 0.39, 0.26, 1),
        (0.61, 0.54, 0.43, 1),
        trim=(0.97, 0.92, 0.79, 1),
        glass=(0.30, 0.51, 0.62, 1),
        wood=(0.48, 0.31, 0.16, 1),
        grass=(0.40, 0.54, 0.25, 1),
        flower=(0.72, 0.24, 0.18, 1),
    )
    lot_and_foundation(root, "Birch", m, body_center=(0, 0.30), body_size=(3.12, 2.44))
    box(root, "BirchMainBody", (0, 0.31, 1.30), (3.10, 2.42, 1.94), m["wall"], edge=0.050)
    facade_bands(root, "Birch", (0, 0.31), (3.10, 2.42), m, (0.84, 1.12, 1.40, 1.68, 1.96))
    box(root, "BirchLowerBelt", (0, 0.31, 0.72), (3.20, 2.52, 0.12), m["trim"], edge=0.012)
    pyramid_roof(root, "BirchHipRoof", (0, 0.31, 2.28), 3.58, 2.94, 1.04, m["roof"])
    box(root, "BirchRoofEave", (0, 0.31, 2.25), (3.58, 2.94, 0.14), m["roofEdge"], edge=0.018)
    for side, y in (("Front", -1.20), ("Rear", 1.82)):
        box(root, f"Birch{side}Gutter", (0, y, 2.23), (3.64, 0.10, 0.12), m["trim"], edge=0.008)
    box(root, "BirchDormerBody", (0, -0.86, 2.62), (1.12, 0.52, 0.72), m["wallDark"], edge=0.035)
    gable_roof(root, "BirchDormerRoof", (0, -1.00, 2.94), (1.38, 0.82, 0.54), m["roof"], ridge_axis="Y")
    box(root, "BirchDormerFascia", (0, -1.45, 2.93), (1.44, 0.10, 0.13), m["trim"], edge=0.007)
    window_y(root, "BirchDormer", 0, -1.135, 2.68, m, width=0.46, height=0.42)
    porch(root, "BirchPorch", 0, -1.34, 2.74, 0.68, 1.96, m, (-1.12, -0.38, 0.38, 1.12))
    door_y(root, "BirchFront", 0, -0.93, 1.15, m, double=True)
    window_y(root, "BirchFrontLeft", -0.88, -0.93, 1.40, m, width=0.58, height=0.68, shutters=True)
    window_y(root, "BirchFrontRight", 0.88, -0.93, 1.40, m, width=0.58, height=0.68, shutters=True)
    for index, x in enumerate((-1.00, 0, 1.00)):
        window_y(root, f"BirchRear{index}", x, 1.535, 1.38, m, width=0.52, height=0.66, shutters=True, outward=1)
    for side, x in (("West", -1.575), ("East", 1.575)):
        for index, y in enumerate((-0.38, 0.56)):
            window_x(root, f"Birch{side}{index}", x, y, 1.38, m, width=0.54, height=0.66, shutters=True, outward=1 if x > 0 else -1)
    chimney(root, "BirchChimney", (1.06, 0.76, 2.92), m, height=1.26)
    box(root, "BirchSidePatio", (-1.48, 0.80, 0.13), (0.72, 1.06, 0.12), m["walk"], edge=0.025)
    beam(root, "BirchPergolaFront", (-1.72, 0.34, 1.42), (-1.72, 1.26, 1.42), 0.08, m["wood"])
    beam(root, "BirchPergolaRear", (-1.25, 0.34, 1.42), (-1.25, 1.26, 1.42), 0.08, m["wood"])
    for y in (0.38, 0.68, 0.98, 1.28):
        beam(root, f"BirchPergolaSlat{y}", (-1.78, y, 1.50), (-1.18, y, 1.50), 0.055, m["wood"])
    hedge(root, "BirchFrontHedgeWest", (-1.68, -1.58), (-0.82, -1.58), m, count=4, height=0.46)
    hedge(root, "BirchFrontHedgeEast", (0.82, -1.58), (1.68, -1.58), m, count=4, height=0.46)
    planter(root, "BirchPergolaPot", -1.48, 1.38, m, scale=0.28, flowers=True)
    planter(root, "BirchEntryPot", 1.48, -1.48, m, scale=0.22, flowers=True)
    ornamental_tree(root, "BirchSideTree", 1.48, 1.25, m, height=1.42)
    for index, z in enumerate((0.74, 1.02)):
        beam(root, f"BirchPergolaVine{index}", (-1.70, 0.42, z), (-1.70, 1.24, z + 0.18), 0.055, m["leaf2"])


def rosewood_turret_house(root):
    m = residential_palette(
        "Rosewood",
        (0.38, 0.52, 0.68, 1),
        (0.50, 0.16, 0.25, 1),
        (0.28, 0.31, 0.42, 1),
        (0.52, 0.52, 0.50, 1),
        trim=(0.91, 0.90, 0.84, 1),
        glass=(0.25, 0.48, 0.64, 1),
        wood=(0.50, 0.25, 0.16, 1),
        grass=(0.31, 0.47, 0.28, 1),
        flower=(0.68, 0.18, 0.32, 1),
    )
    lot_and_foundation(root, "Rosewood", m, body_center=(-0.14, 0.30), body_size=(2.70, 2.38))
    box(root, "RosewoodMainBody", (-0.22, 0.31, 1.82), (2.50, 2.34, 3.04), m["wall"], edge=0.045)
    facade_bands(root, "Rosewood", (-0.22, 0.31), (2.50, 2.34), m, (0.86, 1.16, 1.48, 2.28, 2.58, 2.88))
    box(root, "RosewoodRearWing", (-1.12, 0.66, 1.55), (0.86, 1.48, 2.48), m["wallDark"], edge=0.040)
    box(root, "RosewoodFloorBelt", (-0.18, 0.31, 2.08), (2.66, 2.48, 0.14), m["trim"], edge=0.014)
    gable_roof(root, "RosewoodMainRoof", (-0.20, 0.32, 3.36), (2.90, 2.78, 0.96), m["roof"], ridge_axis="X")
    roof_ridge(root, "RosewoodRidge", (-0.20, 0.32, 4.34), 2.90, m)
    for side, y in (("Front", -1.10), ("Rear", 1.74)):
        box(root, f"Rosewood{side}Eave", (-0.20, y, 3.34), (2.98, 0.13, 0.16), m["trim"], edge=0.010)
    cylinder(root, "RosewoodTurret", (1.05, -0.62, 2.22), 0.66, 3.82, m["wallDark"], vertices=32, edge=0.020)
    cylinder(root, "RosewoodTurretBand", (1.05, -0.62, 2.20), 0.72, 0.14, m["trim"], vertices=32, edge=0.010)
    cone(root, "RosewoodTurretRoof", (1.05, -0.62, 4.48), 0.88, 0.08, 1.36, m["roof"], vertices=32)
    cylinder(root, "RosewoodTurretFinial", (1.05, -0.62, 5.30), 0.055, 0.34, m["roofEdge"], vertices=16)
    sphere(root, "RosewoodTurretOrb", (1.05, -0.62, 5.50), (0.10, 0.10, 0.10), m["roofEdge"], subdivisions=1)
    porch(root, "RosewoodPorch", -0.38, -1.30, 1.74, 0.64, 2.12, m, (-1.02, 0.20))
    box(root, "RosewoodSidePorchDeck", (0.66, -0.22, 0.44), (0.74, 1.52, 0.18), m["wood"], edge=0.025)
    for y in (-0.78, -0.20, 0.38):
        box(root, f"RosewoodSidePost{y}", (0.94, y, 1.34), (0.10, 0.10, 1.60), m["trim"], edge=0.012)
    door_y(root, "RosewoodFront", -0.40, -0.92, 1.18, m)
    for floor, z in enumerate((1.34, 2.62), start=1):
        window_y(root, f"RosewoodFrontF{floor}", 0.22, -0.895, z, m, width=0.46, height=0.64, shutters=floor == 1)
        window_y(root, f"RosewoodRearF{floor}", -0.30, 1.505, z, m, width=0.48, height=0.66, shutters=True, outward=1)
        window_x(root, f"RosewoodWestF{floor}", -1.495, 0.02, z, m, width=0.50, height=0.66, shutters=True)
    for index, z in enumerate((1.42, 2.58, 3.45)):
        # Shallow projecting panes make the round tower legible at sprite scale.
        cylinder(root, f"RosewoodTurretWindow{index}", (1.05, -1.295, z), 0.22, 0.05, m["glass"], vertices=18, rotation=(math.radians(90), 0, 0), edge=0.006)
        box(root, f"RosewoodTurretLintel{index}", (1.05, -1.322, z + 0.25), (0.46, 0.08, 0.10), m["trim"], edge=0.006)
        box(root, f"RosewoodTurretSill{index}", (1.05, -1.326, z - 0.25), (0.46, 0.09, 0.10), m["trim"], edge=0.006)
        box(root, f"RosewoodTurretMullion{index}", (1.05, -1.332, z), (0.055, 0.04, 0.42), m["trim"], edge=0.004)
    chimney(root, "RosewoodChimney", (-0.90, 0.72, 4.12), m, height=1.44)
    for index, (x, y) in enumerate(((-1.52, -1.52), (1.56, -1.52), (-1.54, 1.46))):
        planter(root, f"RosewoodGarden{index}", x, y, m, scale=0.22 + index * 0.03, flowers=True)
    ornamental_tree(root, "RosewoodRearTree", 1.46, 1.34, m, height=1.62, flowering=True)
    for index, x in enumerate((-1.74, -1.44, 1.36, 1.66)):
        box(root, f"RosewoodIronFencePost{index}", (x, -1.72, 0.45), (0.045, 0.045, 0.68), m["iron"], edge=0.003)
    box(root, "RosewoodIronFenceWest", (-1.59, -1.72, 0.48), (0.34, 0.04, 0.055), m["iron"], edge=0.003)
    box(root, "RosewoodIronFenceEast", (1.51, -1.72, 0.48), (0.34, 0.04, 0.055), m["iron"], edge=0.003)


def stonebridge_duplex(root):
    m = residential_palette(
        "Stonebridge",
        (0.64, 0.39, 0.25, 1),
        (0.14, 0.29, 0.48, 1),
        (0.31, 0.34, 0.38, 1),
        (0.66, 0.61, 0.51, 1),
        trim=(0.88, 0.78, 0.60, 1),
        glass=(0.28, 0.48, 0.60, 1),
        wood=(0.44, 0.25, 0.15, 1),
        grass=(0.34, 0.48, 0.24, 1),
        flower=(0.70, 0.31, 0.16, 1),
    )
    lot_and_foundation(root, "Stonebridge", m, body_center=(0, 0.28), body_size=(3.24, 2.42))
    box(root, "StonebridgeMainBody", (0, 0.29, 1.76), (3.20, 2.40, 2.88), m["wall"], edge=0.048)
    facade_bands(root, "Stonebridge", (0, 0.29), (3.20, 2.40), m, (0.88, 1.18, 1.48, 2.28, 2.58, 2.88))
    box(root, "StonebridgeStoneBase", (0, 0.29, 0.72), (3.28, 2.48, 0.72), m["foundation"], edge=0.045)
    box(root, "StonebridgeFloorBand", (0, 0.29, 2.06), (3.34, 2.52, 0.13), m["trim"], edge=0.014)
    gable_roof(root, "StonebridgeMainRoof", (0, 0.29, 3.18), (3.62, 2.80, 0.78), m["roof"], ridge_axis="X")
    roof_ridge(root, "StonebridgeRidge", (0, 0.29, 3.98), 3.62, m)
    for side, y in (("Front", -1.15), ("Rear", 1.73)):
        box(root, f"Stonebridge{side}Eave", (0, y, 3.16), (3.70, 0.13, 0.16), m["trim"], edge=0.010)
    for side, x in (("West", -0.86), ("East", 0.86)):
        box(root, f"Stonebridge{side}GableWall", (x, -0.98, 3.02), (1.18, 0.48, 0.72), m["wallDark"], edge=0.032)
        box(root, f"Stonebridge{side}FrontBay", (x + (-0.36 if x < 0 else 0.36), -0.91, 1.54), (0.78, 0.62, 1.82), m["wallDark"], edge=0.032)
        gable_roof(root, f"Stonebridge{side}FrontGable", (x, -1.10, 3.28), (1.48, 0.96, 0.64), m["roof"], ridge_axis="Y")
        roof_ridge(root, f"Stonebridge{side}FrontRidge", (x, -1.10, 3.94), 0.96, m, axis="Y")
        box(root, f"Stonebridge{side}GableFascia", (x, -1.61, 3.26), (1.54, 0.11, 0.14), m["trim"], edge=0.008)
        window_y(root, f"Stonebridge{side}GableWindow", x, -1.245, 3.16, m, width=0.42, height=0.46)
    box(root, "StonebridgeSharedStoop", (0, -1.20, 0.43), (2.22, 0.70, 0.18), m["foundation"], edge=0.028)
    box(root, "StonebridgeSharedStep", (0, -1.58, 0.26), (1.54, 0.30, 0.16), m["walk"], edge=0.022)
    for side, x in (("West", -0.58), ("East", 0.58)):
        door_y(root, f"Stonebridge{side}Entry", x, -0.95, 1.20, m)
        box(root, f"Stonebridge{side}Canopy", (x, -1.24, 2.00), (0.96, 0.62, 0.14), m["roof"], rotation=(math.radians(-8), 0, 0), edge=0.022)
        for post_x in (x - 0.33, x + 0.33):
            box(root, f"Stonebridge{side}CanopyPost{post_x}", (post_x, -1.33, 1.30), (0.08, 0.08, 1.24), m["trim"], edge=0.008)
        for floor, z in enumerate((1.36, 2.52), start=1):
            window_y(root, f"Stonebridge{side}FrontF{floor}", x + (-0.64 if x < 0 else 0.64), -0.925, z, m, width=0.46, height=0.62, shutters=floor == 2)
            window_y(root, f"Stonebridge{side}RearF{floor}", x, 1.525, z, m, width=0.48, height=0.64, shutters=True, outward=1)
    for side_name, x in (("West", -1.625), ("East", 1.625)):
        for floor, z in enumerate((1.36, 2.52), start=1):
            for bay, y in enumerate((-0.34, 0.66)):
                window_x(root, f"Stonebridge{side_name}F{floor}B{bay}", x, y, z, m, width=0.46, height=0.62, shutters=floor == 2, outward=1 if x > 0 else -1)
    for side, x in (("West", -0.92), ("East", 0.92)):
        box(root, f"Stonebridge{side}RearSunroom", (x, 1.32, 1.12), (1.06, 0.62, 1.56), m["wallDark"], edge=0.032)
        window_y(root, f"Stonebridge{side}SunroomRear", x, 1.645, 1.18, m, width=0.56, height=0.64, outward=1)
    chimney(root, "StonebridgeChimney", (0, 0.68, 3.84), m, height=1.34)
    for index, x in enumerate((-1.38, -0.86, 0.86, 1.38)):
        box(root, f"StonebridgeFoundationBlock{index}", (x, -0.96, 0.54), (0.34, 0.12, 0.34), m["trim"], edge=0.014)
    for index, (x, y) in enumerate(((-1.55, -1.56), (1.55, -1.56))):
        planter(root, f"StonebridgeEntryGarden{index}", x, y, m, scale=0.24, flowers=True)
    hedge(root, "StonebridgeRearHedge", (-1.44, 1.62), (1.44, 1.62), m, count=7, height=0.40)
    ornamental_tree(root, "StonebridgeCourtyardTree", -1.55, 1.18, m, height=1.48)
    box(root, "StonebridgeAddressPlaqueWest", (-0.58, -1.075, 1.68), (0.20, 0.035, 0.12), m["brass"], edge=0.005)
    box(root, "StonebridgeAddressPlaqueEast", (0.58, -1.075, 1.68), (0.20, 0.035, 0.12), m["brass"], edge=0.005)


BUILDERS = {
    "alder_gable_cottage": alder_gable_cottage,
    "birch_lane_bungalow": birch_lane_bungalow,
    "rosewood_turret_house": rosewood_turret_house,
    "stonebridge_duplex": stonebridge_duplex,
}


def build_asset(asset):
    scene = reset("CitySimResidentialQuality_" + asset["assetId"])
    configure_scene(scene, transparent=True)
    root = asset_root(asset)
    root["liveAsset"] = True
    root["qualityCandidate"] = True
    root["quarantinedExpansionV1Reused"] = False
    BUILDERS[asset["assetId"]](root)
    cameras = canonical_rig(scene)
    return scene, root, cameras


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_info(path, base=HERE):
    return {"path": path.relative_to(base).as_posix(), "sha256": sha256(path)}


def write_asset_manifest(asset, artifacts):
    output_dir = HERE / asset["assetId"]
    data = {
        "schema": "citysim.world-art.residential-quality-asset.v1",
        "pipelineSchema": CONFIG["schema"],
        "assetId": asset["assetId"],
        "displayName": asset["displayName"],
        "description": asset["description"],
        "zone": asset["zone"],
        "densityLevel": asset["densityLevel"],
        "assetFamily": asset["assetFamily"],
        "status": "quality-candidate-runtime-integrated",
        "liveAsset": True,
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "quarantinedExpansionV1Reused": False,
        "cameraOrder": [view["name"] for view in VIEWS],
        "grid": CONFIG["grid"],
        "canvas": CONFIG["canvas"],
        "cameraRig": CONFIG["cameraRig"],
        "lightingConvention": CONFIG["lighting"],
        "root": CONFIG["root"],
        "worldFootprintTiles": asset["footprintTiles"],
        "postRenderCompensation": "none",
        "perViewCompensation": {"rotationDegrees": 0.0, "skew": [0.0, 0.0], "crop": False, "offsetPixels": [0, 0], "scale": 1.0},
        "contactSheetLayout": [["camNE", "camSE"], ["camSW", "camNW"]],
        "sourceFiles": [source_info(HERE / name) for name in ("build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py")],
        "dependencies": [
            {"path": DENSITY_BUILDER.relative_to(BLENDER_ROOT).as_posix(), "sha256": sha256(DENSITY_BUILDER)},
            {"path": (CANONICAL / "pipeline.json").relative_to(BLENDER_ROOT).as_posix(), "sha256": sha256(CANONICAL / "pipeline.json")},
            {"path": (CANONICAL / "png_canonical.py").relative_to(BLENDER_ROOT).as_posix(), "sha256": sha256(CANONICAL / "png_canonical.py")},
        ],
        "artifacts": [artifact_info(path, output_dir) for path in artifacts],
    }
    path = output_dir / "manifest.json"
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


FONT = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
    "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "J": ["00111", "00010", "00010", "00010", "10010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "11001", "10101", "10011", "10011", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
}


def draw_text(rgba, sheet_width, x, y, value, scale=2, color=(242, 222, 180, 255)):
    cursor = x
    for char in value.upper():
        if char == " ":
            cursor += 4 * scale
            continue
        glyph = FONT[char]
        for row, bits in enumerate(glyph):
            for column, active in enumerate(bits):
                if active != "1":
                    continue
                for yy in range(scale):
                    for xx in range(scale):
                        pixel = ((y + row * scale + yy) * sheet_width + cursor + column * scale + xx) * 4
                        rgba[pixel:pixel + 4] = bytes(color)
        cursor += 6 * scale


def aggregate_contact_sheet(asset_paths):
    image_size, gap, header, label = 384, 12, 34, 210
    width = label + 4 * image_size + 3 * gap
    height = header + 4 * image_size + 3 * gap
    rgba = bytearray(bytes((24, 29, 29, 255)) * (width * height))
    for column, view in enumerate(VIEWS):
        draw_text(rgba, width, label + column * (image_size + gap) + 12, 9, view["name"], scale=2)
    for row, asset in enumerate(CONFIG["assets"]):
        origin_y = header + row * (image_size + gap)
        words = asset["displayName"].upper().split()
        for line, word in enumerate(words):
            draw_text(rgba, width, 12, origin_y + 18 + line * 20, word, scale=2)
        for column, path in enumerate(asset_paths[asset["assetId"]]):
            source_width, source_height, source = decode_rgba_png(path)
            if (source_width, source_height) != (image_size, image_size):
                raise RuntimeError(f"AGGREGATE_SOURCE_SIZE_MISMATCH: {path}")
            origin_x = label + column * (image_size + gap)
            for source_y in range(image_size):
                src = source_y * image_size * 4
                dst = ((origin_y + source_y) * width + origin_x) * 4
                rgba[dst:dst + image_size * 4] = source[src:src + image_size * 4]
    output = HERE / CONFIG["output"]["aggregateContactSheet"]
    encode_rgba_png(output, width, height, bytes(rgba))
    return output


def previous_candidate_paths(temp_root):
    commit = CONFIG["comparisonBaseline"]["commit"]
    paths = {}
    for asset in CONFIG["assets"]:
        relative = (
            HERE / asset["assetId"] / "renders" / f"{asset['assetId']}_camNE.png"
        ).relative_to(REPO_ROOT).as_posix()
        result = subprocess.run(
            ["git", "show", f"{commit}:{relative}"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
        )
        output = temp_root / f"{asset['assetId']}_1cf6e64f_camNE.png"
        output.write_bytes(result.stdout)
        paths[asset["assetId"]] = output
    proof_dir = HERE / "proof"
    proof_dir.mkdir(parents=True, exist_ok=True)
    for size in ("1280x800", "900x600"):
        source = (
            "Native/CitySimNative/WorldArt/Blender/FourViewProduction/"
            "ResidentialQualityFamily/proof/"
            f"residential-quality-saved-city-{size}.png"
        )
        result = subprocess.run(
            ["git", "show", f"{commit}:{source}"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
        )
        (proof_dir / f"baseline-1cf6e64f-saved-city-{size}.png").write_bytes(result.stdout)
    return paths


def refinement_comparison_sheet(asset_paths, previous_paths):
    runtime_assets = BLENDER_ROOT.parents[1] / "Sources" / "CitySimNative" / "Resources" / "FourViewAssets"
    admitted = [
        ("COPPER FINCH", runtime_assets / "copper_finch_house_camNE.png"),
        ("MARIGOLD COURT", runtime_assets / "marigold_court_house_camNE.png"),
        ("BRICKLINE ROWHOUSE", runtime_assets / "brickline_rowhouse_apartments_camNE.png"),
        ("MAPLE COURTYARD", runtime_assets / "maple_courtyard_apartments_camNE.png"),
        ("FOUNDRY CROWN", runtime_assets / "foundry_crown_apartments_camNE.png"),
        ("JUNIPER TERRACE", runtime_assets / "juniper_terrace_tower_camNE.png"),
    ]
    previous = [
        (asset["displayName"].upper(), previous_paths[asset["assetId"]])
        for asset in CONFIG["assets"]
    ]
    refined = [
        (asset["displayName"].upper(), asset_paths[asset["assetId"]][0])
        for asset in CONFIG["assets"]
    ]
    image_size, gap, header, label = 384, 12, 32, 210
    columns = 6
    width = label + columns * image_size + (columns - 1) * gap
    row_height = header + image_size
    height = row_height * 3 + gap * 2
    rgba = bytearray(bytes((24, 29, 29, 255)) * (width * height))

    def paste_row(items, row_y, section_words):
        for line, word in enumerate(section_words):
            draw_text(rgba, width, 12, row_y + header + 18 + line * 20, word, scale=2)
        for column, (title, path) in enumerate(items):
            origin_x = label + column * (image_size + gap)
            draw_text(rgba, width, origin_x + 10, row_y + 9, title, scale=1)
            source_width, source_height, source = decode_rgba_png(path)
            if (source_width, source_height) != (image_size, image_size):
                raise RuntimeError(f"COMPARISON_SOURCE_SIZE_MISMATCH: {path}")
            for source_y in range(image_size):
                src = source_y * image_size * 4
                dst = ((row_y + header + source_y) * width + origin_x) * 4
                rgba[dst:dst + image_size * 4] = source[src:src + image_size * 4]

    paste_row(admitted, 0, ("ADMITTED", "RESIDENTIAL"))
    paste_row(previous, row_height + gap, ("COMMIT", "1CF6E64F"))
    paste_row(refined, (row_height + gap) * 2, ("REFINED", "FAMILY"))
    output = HERE / CONFIG["output"]["refinementComparison"]
    output.parent.mkdir(parents=True, exist_ok=True)
    encode_rgba_png(output, width, height, bytes(rgba))
    return output


def write_family_manifest(asset_manifests, aggregate_path, comparison_path):
    data = {
        "schema": "citysim.world-art.residential-quality-family-manifest.v1",
        "status": "quality-candidate-runtime-integrated",
        "originalGeometry": True,
        "referencePixelsReused": False,
        "quarantinedExpansionV1Reused": False,
        "comparisonBaselineCommit": CONFIG["comparisonBaseline"]["commit"],
        "postRenderCompensation": "none",
        "grid": CONFIG["grid"],
        "canvas": CONFIG["canvas"],
        "cameraRig": CONFIG["cameraRig"],
        "assets": [
            {
                "assetId": asset["assetId"],
                "displayName": asset["displayName"],
                "runtimeRole": "residential-low",
                "manifest": manifest.relative_to(HERE).as_posix(),
                "manifestSha256": sha256(manifest),
            }
            for asset, manifest in zip(CONFIG["assets"], asset_manifests)
        ],
        "aggregateContactSheet": artifact_info(aggregate_path, HERE),
        "refinementComparison": artifact_info(comparison_path, HERE),
        "previousSavedCityProofs": [
            artifact_info(HERE / "proof" / f"baseline-1cf6e64f-saved-city-{size}.png", HERE)
            for size in ("1280x800", "900x600")
        ],
        "sourceFiles": [source_info(HERE / name) for name in ("build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py")],
    }
    path = HERE / "family-manifest.json"
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


def main():
    actual = ".".join(map(str, bpy.app.version))
    if actual != CONFIG["toolchain"]["blenderVersion"]:
        raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    with tempfile.TemporaryDirectory(prefix="citysim-residential-quality-baseline-") as temp_dir:
        previous_paths = previous_candidate_paths(Path(temp_dir))
        asset_manifests = []
        asset_paths = {}
        for asset in CONFIG["assets"]:
            output_dir = HERE / asset["assetId"]
            output_dir.mkdir(parents=True, exist_ok=True)
            scene, _, cameras = build_asset(asset)
            blend_path = output_dir / f"{asset['assetId']}.blend"
            bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
            render_paths = render_views(scene, cameras, asset["assetId"], output_dir / "renders")
            sheet_path = contact_sheet(render_paths, output_dir / f"{asset['assetId']}_contact-sheet.png")
            asset_paths[asset["assetId"]] = render_paths
            asset_manifests.append(write_asset_manifest(asset, [blend_path, *render_paths, sheet_path]))
        aggregate_path = aggregate_contact_sheet(asset_paths)
        comparison_path = refinement_comparison_sheet(asset_paths, previous_paths)
        write_family_manifest(asset_manifests, aggregate_path, comparison_path)
    print("RESIDENTIAL_QUALITY_FAMILY_RENDER_PASS assets=4 views=16")


if __name__ == "__main__":
    main()
