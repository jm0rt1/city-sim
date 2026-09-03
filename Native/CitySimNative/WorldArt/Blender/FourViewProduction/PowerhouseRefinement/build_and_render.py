#!/usr/bin/env python3
"""Build one original, source-only Copper Arc Powerhouse refinement."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import os
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
PRODUCTION = HERE.parent
BLENDER_ROOT = PRODUCTION.parent
DENSITY_BUILDER = PRODUCTION / "Density" / "build_and_render.py"
CANONICAL_PNG = BLENDER_ROOT / "FourViewPipeline" / "png_canonical.py"
BASELINE_DIR = PRODUCTION / "CivicUtilityVariety" / "copper_arc_powerhouse"
BASELINE_BUILDER = PRODUCTION / "CivicUtilityVariety" / "build_and_render.py"
BASELINE_PIPELINE = PRODUCTION / "CivicUtilityVariety" / "pipeline.json"
sys.dont_write_bytecode = True


def load_density_helpers():
    spec = importlib.util.spec_from_file_location("citysim_powerhouse_density_helpers", DENSITY_BUILDER)
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
beam = kit.beam
gable_roof = kit.gable_roof
reset = kit.reset
configure_scene = kit.configure_scene
canonical_rig = kit.canonical_rig
asset_root = kit.asset_root
palette = kit.palette
shared_lot = kit.shared_lot
facade_window = kit.facade_window
planter = kit.planter
render_views = kit.render_views
contact_sheet = kit.contact_sheet
sha256 = kit.sha256


def utility_palette():
    mats = palette("CopperArcRefined", accent=(0.68, 0.42, 0.12, 1), brick=(0.49, 0.20, 0.12, 1))
    mats["steel"] = material("CopperArcRefinedPaintedSteel", (0.20, 0.26, 0.27, 1), roughness=0.43, metallic=0.54, texture_scale=8.0)
    mats["oxide"] = material("CopperArcRefinedOxide", (0.48, 0.22, 0.09, 1), roughness=0.57, metallic=0.20, texture_scale=10.0)
    mats["ceramic"] = material("CopperArcRefinedCeramic", (0.76, 0.48, 0.25, 1), roughness=0.42, texture_scale=5.0)
    mats["void"] = material("CopperArcRefinedStackVoid", (0.035, 0.028, 0.022, 1), roughness=0.92, metallic=0.0, texture_scale=0)
    return mats


def tall_side_bay(root, prefix, x, y, mats):
    """A shallow framed bay turns the former blank hall elevation into real depth."""
    box(root, prefix + "StoneSill", (x, y, 0.72), (0.09, 0.62, 0.14), mats["stone"], edge=0.010)
    facade_window(root, prefix + "TallGlass", (x, y, 1.84), (0.065, 0.48, 1.90), mats, frame_axis="X")
    box(root, prefix + "Mullion", (x - 0.018, y, 1.84), (0.085, 0.045, 1.74), mats["cream"], edge=0.005)
    box(root, prefix + "Pier", (x + 0.035, y, 2.48), (0.12, 0.70, 0.16), mats["stone"], edge=0.010)


def stack_with_open_mouth(root, index, x, mats):
    cylinder(root, f"CopperArcStack{index}", (x, 1.20, 4.52), 0.25, 5.70, mats["oxide"], vertices=30)
    for band, z in enumerate((2.48, 3.42, 4.36, 5.30, 6.24)):
        cylinder(root, f"CopperArcStack{index}Band{band}", (x, 1.20, z), 0.28, 0.07, mats["cream"], vertices=30)
    # The cap and inset dark disk are actual modeled pieces; their 7.497 top stays inside the explicit 7.50 tolerance.
    cylinder(root, f"CopperArcStack{index}Rim", (x, 1.20, 7.42), 0.31, 0.14, mats["stone"], vertices=30)
    cylinder(root, f"CopperArcStack{index}OpenThroat", (x, 1.20, 7.491), 0.215, 0.012, mats["void"], vertices=30, edge=0)


def copper_arc_powerhouse(root):
    mats = utility_palette()
    shared_lot(root, "CopperArc", mats, 0.82)
    box(root, "CopperArcServiceApron", (0, 0.15, 0.04), (3.62, 3.22, 0.10), mats["walk"], edge=0.028)
    box(root, "CopperArcPlinth", (-0.28, 0.30, 0.24), (3.18, 2.72, 0.42), mats["stone"], edge=0.05)
    box(root, "CopperArcTurbineHall", (-0.50, 0.40, 1.98), (2.26, 2.30, 3.16), mats["brick"], edge=0.05)
    gable_roof(root, "CopperArcTurbineRoof", (-0.50, 0.40, 3.58), (2.40, 2.44, 0.62), mats["roof"], ridge_axis="Y")
    box(root, "CopperArcControlWing", (1.02, -0.12, 1.36), (1.02, 2.70, 1.92), mats["brickDark"], edge=0.045)
    box(root, "CopperArcControlRoof", (1.02, -0.12, 2.39), (1.14, 2.82, 0.17), mats["roof"], edge=0.022)

    # Preserved Deco frontage, now with real projecting piers and a clear vertical hierarchy.
    box(root, "CopperArcDecoCrown", (-0.50, -0.80, 3.20), (1.76, 0.22, 0.32), mats["stone"], edge=0.018)
    for tier, (z, width) in enumerate(((3.44, 1.34), (3.66, 0.94))):
        box(root, f"CopperArcSteppedParapet{tier}", (-0.50, -0.82, z), (width, 0.20, 0.22), mats["cream"], edge=0.014)
    for index, x in enumerate((-1.42, -0.92, -0.42, 0.08, 0.53)):
        box(root, f"CopperArcFrontPier{index}", (x, -0.795, 2.00), (0.105, 0.13, 2.82), mats["stone"], edge=0.009)
        box(root, f"CopperArcRearPier{index}", (x, 1.595, 2.00), (0.105, 0.13, 2.82), mats["brickDark"], edge=0.009)
    for belt, z in enumerate((0.76, 2.66)):
        box(root, f"CopperArcHallBelt{belt}", (-0.50, 0.40, z), (2.36, 2.38, 0.115), mats["stone"], edge=0.009)
    for floor, z in enumerate((1.10, 2.03, 2.94), start=1):
        for bay, x in enumerate((-1.20, -0.58, 0.04)):
            facade_window(root, f"CopperArcHallFrontF{floor}B{bay}", (x, -0.77, z), (0.36, 0.055, 0.54), mats)
            facade_window(root, f"CopperArcHallRearF{floor}B{bay}", (x, 1.57, z), (0.36, 0.055, 0.54), mats)

    # The formerly blank west wall receives three deep, tall generating-hall window bays.
    for bay, y in enumerate((-0.45, 0.38, 1.18)):
        tall_side_bay(root, f"CopperArcWestHallBay{bay}", -1.655, y, mats)
        box(root, f"CopperArcWestButtress{bay}", (-1.60, y + 0.34, 1.78), (0.18, 0.13, 2.56), mats["brickDark"], edge=0.015)
    for bay, y in enumerate((-0.48, 0.33, 1.05)):
        facade_window(root, f"CopperArcEastHallBay{bay}", (0.665, y, 2.10), (0.055, 0.30, 1.28), mats, frame_axis="X")
    # This upper east clerestory intentionally clears the control-wing roof, so the live camNE face has a readable industrial rhythm.
    for bay, y in enumerate((-0.40, 0.28, 0.96)):
        facade_window(root, f"CopperArcEastUpperClerestory{bay}", (0.665, y, 3.03), (0.055, 0.28, 0.42), mats, frame_axis="X")
        box(root, f"CopperArcEastUpperSill{bay}", (0.682, y, 2.76), (0.085, 0.39, 0.08), mats["stone"], edge=0.006)

    # A low roof monitor and ventilators supply a readable industrial crown without growing the lot or silhouette beyond the stacks.
    box(root, "CopperArcRoofMonitorBase", (-0.50, 0.40, 4.17), (0.62, 1.42, 0.15), mats["steel"], edge=0.014)
    box(root, "CopperArcRoofMonitorNorthGlass", (-0.50, 1.02, 4.34), (0.48, 0.06, 0.28), mats["glass"], edge=0.008)
    box(root, "CopperArcRoofMonitorSouthGlass", (-0.50, -0.22, 4.34), (0.48, 0.06, 0.28), mats["glass"], edge=0.008)
    box(root, "CopperArcRoofMonitorCap", (-0.50, 0.40, 4.50), (0.68, 1.48, 0.10), mats["steel"], edge=0.012)
    for edge_x in (-0.82, -0.18):
        box(root, f"CopperArcRoofMonitorCopperEdge{edge_x}", (edge_x, 0.40, 4.56), (0.035, 1.44, 0.035), mats["copper"], edge=0.004)
    for index, y in enumerate((-0.25, 0.85)):
        cylinder(root, f"CopperArcRoofVent{index}", (-1.18, y, 4.02), 0.11, 0.32, mats["steel"], vertices=16)
        cylinder(root, f"CopperArcRoofVentCap{index}", (-1.18, y, 4.22), 0.16, 0.08, mats["copper"], vertices=16)

    for index, x in enumerate((-0.86, -0.14)):
        stack_with_open_mouth(root, index, x, mats)

    for floor, z in enumerate((1.04, 1.82), start=1):
        for side, x in (("East", 1.55), ("West", 0.49)):
            for bay, y in enumerate((-0.92, -0.28, 0.36, 1.00)):
                facade_window(root, f"CopperArcControl{side}F{floor}B{bay}", (x, y, z), (0.055, 0.34, 0.46), mats, frame_axis="X")
    box(root, "CopperArcMainDoorRecess", (0.98, -1.47, 0.92), (0.72, 0.13, 1.18), mats["brickDark"], edge=0.018)
    box(root, "CopperArcMainDoor", (0.98, -1.55, 0.92), (0.58, 0.07, 1.08), mats["accent"], edge=0.018)
    box(root, "CopperArcDoorCanopy", (0.98, -1.66, 1.50), (0.88, 0.42, 0.13), mats["copper"], edge=0.016)
    for x in (0.70, 1.26):
        cylinder(root, f"CopperArcCanopyPost{x}", (x, -1.77, 0.87), 0.035, 1.20, mats["iron"], vertices=12)

    # Retained transformer court is made more legible with pads, fins, bushing caps, and a restrained pipe rail.
    for unit, y in enumerate((-0.86, 0.06, 0.98)):
        box(root, f"CopperArcTransformerPad{unit}", (1.60, y, 0.20), (0.52, 0.64, 0.20), mats["stone"], edge=0.018)
        box(root, f"CopperArcTransformer{unit}", (1.60, y, 0.70), (0.44, 0.54, 0.80), mats["steel"], edge=0.055)
        for fin, x in enumerate((1.43, 1.52, 1.68, 1.77)):
            box(root, f"CopperArcTransformer{unit}Fin{fin}", (x, y - 0.30, 0.70), (0.035, 0.08, 0.56), mats["iron"], edge=0.004)
        for phase, x in enumerate((1.48, 1.60, 1.72)):
            cylinder(root, f"CopperArcBushing{unit}_{phase}", (x, y, 1.20), 0.055, 0.30, mats["ceramic"], vertices=14)
    for index, x in enumerate((1.28, 1.86)):
        box(root, f"CopperArcGantryPost{index}", (x, 1.42, 1.25), (0.10, 0.10, 2.18), mats["steel"], edge=0.010)
    beam(root, "CopperArcGantryBeam", (1.28, 1.42, 2.30), (1.86, 1.42, 2.30), 0.11, mats["steel"])
    for phase, x in enumerate((1.36, 1.57, 1.78)):
        beam(root, f"CopperArcBus{phase}", (x, -0.86, 1.28), (x, 1.42, 2.32), 0.038, mats["copper"])
    for post, x in enumerate((-1.72, -1.40, -1.08, -0.76)):
        cylinder(root, f"CopperArcServiceRailPost{post}", (x, 1.64, 0.58), 0.025, 0.62, mats["iron"], vertices=10)
    beam(root, "CopperArcServiceRailTop", (-1.72, 1.64, 0.88), (-0.76, 1.64, 0.88), 0.035, mats["iron"])
    beam(root, "CopperArcServicePipe", (-1.72, 1.44, 0.58), (-0.76, 1.44, 0.58), 0.09, mats["copper"])
    for index, location in enumerate(((-1.62, -1.62), (1.60, -1.62))):
        planter(root, f"CopperArcStreetPlanter{index}", location, mats, 0.17)


ASSET = CONFIG["assets"][0]


def build_asset(asset=ASSET):
    scene = reset("CitySimPowerhouseRefinement_" + asset["assetId"])
    configure_scene(scene, transparent=True)
    root = asset_root(asset)
    copper_arc_powerhouse(root)
    cameras = canonical_rig(scene)
    return scene, root, cameras


def dependency(path):
    return {"path": Path(os.path.relpath(path, HERE)).as_posix(), "sha256": sha256(path)}


def write_source_manifest():
    source_files = [HERE / name for name in ("README.md", "build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py")]
    dependencies = [DENSITY_BUILDER, CANONICAL_PNG, BASELINE_BUILDER, BASELINE_PIPELINE, BASELINE_DIR / "copper_arc_powerhouse.blend", BASELINE_DIR / "copper_arc_powerhouse_contact-sheet.png"]
    payload = {
        "schema": "citysim.world-art.source-dependency-manifest.v1",
        "assetId": ASSET["assetId"],
        "status": "source-only-not-live",
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "baseGeometryReused": True,
        "baselineGeometryAdapted": True,
        "baselineReference": "../CivicUtilityVariety/copper_arc_powerhouse",
        "sourceFiles": [dependency(path) for path in source_files],
        "dependencies": [dependency(path) for path in dependencies],
    }
    (HERE / "source-manifest.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main():
    actual = ".".join(map(str, bpy.app.version))
    if actual != CONFIG["toolchain"]["blenderVersion"]:
        raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    output_dir = HERE / ASSET["assetId"]
    output_dir.mkdir(parents=True, exist_ok=True)
    scene, _, cameras = build_asset()
    blend_path = output_dir / f"{ASSET['assetId']}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    render_paths = render_views(scene, cameras, ASSET["assetId"], output_dir / "renders")
    sheet_path = contact_sheet(render_paths, output_dir / f"{ASSET['assetId']}_contact-sheet.png")
    kit.write_asset_manifest(ASSET, [blend_path, *render_paths, sheet_path])
    write_source_manifest()
    print("POWERHOUSE_REFINEMENT_RENDER_PASS assets=1 views=4")


if __name__ == "__main__":
    main()
