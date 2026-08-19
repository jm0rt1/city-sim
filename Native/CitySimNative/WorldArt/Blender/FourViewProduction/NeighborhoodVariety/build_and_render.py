#!/usr/bin/env python3
"""Build four original CitySim residential and industrial variety assets."""

from __future__ import annotations

import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
PRODUCTION = HERE.parent
BLENDER_ROOT = PRODUCTION.parent
CANONICAL = BLENDER_ROOT / "FourViewPipeline"
DENSITY_BUILDER = PRODUCTION / "Density" / "build_and_render.py"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))


def load_density_helpers():
    spec = importlib.util.spec_from_file_location("citysim_density_helpers", DENSITY_BUILDER)
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
palette = kit.palette
shared_lot = kit.shared_lot
facade_window = kit.facade_window
planter = kit.planter
render_views = kit.render_views
contact_sheet = kit.contact_sheet
artifact_info = kit.artifact_info
source_info = kit.source_info
sha256 = kit.sha256


def maple_courtyard_apartments(root):
    m = palette("MapleCourt", accent=(0.34, 0.43, 0.24, 1), brick=(0.60, 0.29, 0.16, 1))
    shared_lot(root, "Maple", m, 0.90)
    box(root, "MapleCourtyardPavers", (0, -0.92, 0.04), (2.08, 1.18, 0.09), m["walk"], edge=0.025)
    box(root, "MapleStonePlinth", (0, 0.22, 0.21), (3.52, 2.98, 0.42), m["stone"], edge=0.05)
    box(root, "MapleRearWing", (0, 0.72, 2.35), (3.30, 1.32, 4.28), m["brick"], edge=0.05)
    box(root, "MapleWestWing", (-1.17, -0.18, 2.35), (0.96, 1.58, 4.28), m["brick"], edge=0.05)
    box(root, "MapleEastWing", (1.17, -0.18, 2.35), (0.96, 1.58, 4.28), m["brick"], edge=0.05)
    box(root, "MapleRearRoof", (0, 0.72, 4.57), (3.40, 1.42, 0.18), m["roof"], edge=0.03)
    gable_roof(root, "MapleWestRoof", (-1.17, -0.18, 4.64), (1.06, 1.70, 0.46), m["roof"], ridge_axis="Y")
    gable_roof(root, "MapleEastRoof", (1.17, -0.18, 4.64), (1.06, 1.70, 0.46), m["roof"], ridge_axis="Y")
    for floor, z in enumerate((1.05, 2.05, 3.05, 4.05), start=1):
        box(root, f"MapleRearBelt{floor}", (0, 0.72, z + 0.42), (3.40, 1.42, 0.10), m["cream"], edge=0.012)
        for bay, x in enumerate((-1.25, -0.62, 0, 0.62, 1.25)):
            facade_window(root, f"MapleRearFrontF{floor}B{bay}", (x, 0.035, z), (0.38, 0.055, 0.52), m)
            facade_window(root, f"MapleRearBackF{floor}B{bay}", (x, 1.405, z), (0.38, 0.055, 0.52), m)
        for side_name, x in (("West", -1.665), ("East", 1.665)):
            for bay, y in enumerate((-0.62, 0.02, 0.72)):
                facade_window(root, f"Maple{side_name}F{floor}B{bay}", (x, y, z), (0.055, 0.36, 0.50), m, frame_axis="X")
        for wing_name, x in (("WestWing", -1.17), ("EastWing", 1.17)):
            facade_window(root, f"Maple{wing_name}FrontF{floor}", (x, -1.005, z), (0.42, 0.055, 0.52), m)
    for wing_name, x in (("West", -1.17), ("East", 1.17)):
        box(root, f"Maple{wing_name}EntryRecess", (x, -1.015, 0.82), (0.52, 0.12, 1.12), m["brickDark"], edge=0.018)
        box(root, f"Maple{wing_name}Door", (x, -1.09, 0.80), (0.40, 0.07, 1.02), m["accent"], edge=0.016)
        box(root, f"Maple{wing_name}Canopy", (x, -1.30, 1.43), (0.78, 0.52, 0.12), m["copper"], edge=0.018)
    for index, x in enumerate((-0.62, 0, 0.62)):
        box(root, f"MapleCourtyardBench{index}", (x, -0.77, 0.32), (0.44, 0.20, 0.10), m["wood"], edge=0.016)
    for index, location in enumerate(((-1.56, -1.55), (1.56, -1.55), (-0.72, -0.82), (0.72, -0.82), (-1.55, 1.55), (1.55, 1.55))):
        planter(root, f"MaplePlanter{index}", location, m, 0.20)


def juniper_terrace_tower(root):
    m = palette("JuniperTerrace", accent=(0.18, 0.42, 0.36, 1), brick=(0.52, 0.21, 0.13, 1))
    shared_lot(root, "Juniper", m, 0.82)
    box(root, "JuniperStonePlinth", (0, 0.18, 0.22), (3.56, 3.06, 0.44), m["stone"], edge=0.05)
    box(root, "JuniperPodium", (0, 0.18, 1.18), (3.42, 2.92, 1.62), m["brick"], edge=0.05)
    box(root, "JuniperLowerTower", (-0.12, 0.24, 3.82), (2.92, 2.38, 3.72), m["brick"], edge=0.05)
    box(root, "JuniperUpperTower", (0.22, 0.28, 6.18), (2.30, 1.86, 1.34), m["brickDark"], edge=0.045)
    box(root, "JuniperRoofTerrace", (-0.28, 0.25, 6.94), (2.82, 2.20, 0.18), m["walk"], edge=0.025)
    box(root, "JuniperRoofPavilion", (0.38, 0.30, 7.26), (1.26, 1.08, 0.62), m["stone"], edge=0.032)
    pyramid_roof(root, "JuniperCopperPavilionRoof", (0.38, 0.30, 7.57), 1.42, 1.22, 0.48, m["copper"])
    cylinder(root, "JuniperFinial", (0.38, 0.30, 8.24), 0.055, 0.44, m["copper"], vertices=14)
    for floor, z in enumerate((1.02, 2.08, 3.02, 3.94, 4.86, 5.78, 6.50), start=1):
        upper = floor >= 7
        center_x = 0.22 if upper else -0.12 if floor >= 3 else 0
        width = 2.42 if upper else 3.02 if floor >= 3 else 3.48
        depth = 1.98 if upper else 2.48 if floor >= 3 else 3.00
        front_y = -0.65 if upper else -0.95 if floor >= 3 else -1.30
        rear_y = 1.23 if upper else 1.43 if floor >= 3 else 1.66
        for bay, fraction in enumerate((-0.36, -0.12, 0.12, 0.36)):
            x = center_x + width * fraction
            facade_window(root, f"JuniperFrontF{floor}B{bay}", (x, front_y, z), (0.40, 0.055, 0.54), m)
            facade_window(root, f"JuniperRearF{floor}B{bay}", (x, rear_y, z), (0.40, 0.055, 0.54), m)
        side_x = center_x + width / 2
        for side_name, x in (("East", side_x), ("West", center_x - width / 2)):
            for bay, y in enumerate((-0.40, 0.22, 0.84)):
                facade_window(root, f"Juniper{side_name}F{floor}B{bay}", (x, y, z), (0.055, 0.34, 0.52), m, frame_axis="X")
        box(root, f"JuniperFloorBand{floor}", (center_x, 0.24, z + 0.42), (width + 0.12, depth + 0.12, 0.09), m["cream"], edge=0.010)
    for floor, z in enumerate((2.52, 3.44, 4.36, 5.28), start=1):
        box(root, f"JuniperTerraceSlab{floor}", (0.58, -1.22, z), (1.18, 0.50, 0.10), m["stone"], edge=0.016)
        for x in (0.08, 0.33, 0.58, 0.83, 1.08):
            box(root, f"JuniperTerraceRail{floor}_{x}", (x, -1.46, z + 0.27), (0.035, 0.035, 0.48), m["iron"], edge=0.005)
        box(root, f"JuniperTerraceTop{floor}", (0.58, -1.46, z + 0.50), (1.12, 0.04, 0.05), m["iron"], edge=0.005)
    box(root, "JuniperEntryPortal", (-0.68, -1.36, 0.90), (0.72, 0.18, 1.18), m["brickDark"], edge=0.020)
    box(root, "JuniperEntryDoor", (-0.68, -1.48, 0.88), (0.56, 0.07, 1.06), m["accent"], edge=0.016)
    box(root, "JuniperEntryCanopy", (-0.68, -1.66, 1.52), (1.10, 0.50, 0.13), m["copper"], edge=0.018)
    for index, location in enumerate(((-1.58, -1.58), (1.55, -1.58), (-1.54, 1.54), (1.52, 1.54), (-0.54, 0.20), (0.54, 0.20))):
        z = 7.12 if index >= 4 else 0
        if z:
            x, y = location
            box(root, f"JuniperRoofPlanter{index}", (x, y, z), (0.40, 0.34, 0.22), m["stone"], edge=0.018)
            sphere(root, f"JuniperRoofShrub{index}", (x, y, z + 0.27), (0.18, 0.16, 0.22), m["leaf"])
        else:
            planter(root, f"JuniperStreet{index}", location, m, 0.20)


def industrial_palette(prefix, brick):
    m = palette(prefix, accent=(0.70, 0.38, 0.10, 1), brick=brick)
    m["steel"] = material(prefix + "PaintedSteel", (0.22, 0.29, 0.29, 1), roughness=0.44, metallic=0.50, texture_scale=9.0)
    m["oxide"] = material(prefix + "Oxide", (0.48, 0.22, 0.08, 1), roughness=0.58, metallic=0.18, texture_scale=10.0)
    return m


def riverbend_textile_works(root):
    m = industrial_palette("Riverbend", (0.50, 0.23, 0.14, 1))
    shared_lot(root, "Riverbend", m, 1.02)
    box(root, "RiverbendPlinth", (0, 0.14, 0.20), (3.58, 3.08, 0.40), m["walk"], edge=0.05)
    box(root, "RiverbendWeavingHall", (0.34, 0.34, 1.38), (2.68, 2.48, 2.36), m["brick"], edge=0.048)
    box(root, "RiverbendOfficeWing", (-1.16, -0.16, 1.45), (0.96, 2.10, 2.52), m["stone"], edge=0.045)
    box(root, "RiverbendOfficeRoof", (-1.16, -0.16, 2.80), (1.06, 2.20, 0.18), m["roof"], edge=0.024)
    for index, x in enumerate((-0.62, 0.03, 0.68, 1.33)):
        gable_roof(root, f"RiverbendSawtooth{index}", (x, 0.34, 2.56), (0.70, 2.58, 0.56), m["roof"], ridge_axis="Y")
        box(root, f"RiverbendRoofLight{index}", (x - 0.29, 0.34, 2.84), (0.055, 1.84, 0.34), m["glass"], rotation=(0, math.radians(-22), 0), edge=0.008)
    for bay, x in enumerate((-0.48, 0.28, 1.04)):
        box(root, f"RiverbendLoadingDoor{bay}", (x, -0.925, 1.06), (0.58, 0.07, 1.34), m["steel"], edge=0.018)
        for slat, z in enumerate((0.54, 0.80, 1.06, 1.32, 1.58)):
            box(root, f"RiverbendDoor{bay}Slat{slat}", (x, -0.97, z), (0.50, 0.025, 0.030), m["cream"], edge=0.004)
        box(root, f"RiverbendLoadingDock{bay}", (x, -1.22, 0.34), (0.66, 0.52, 0.30), m["walk"], edge=0.022)
    for floor, z in enumerate((1.02, 1.92), start=1):
        for bay, y in enumerate((-0.72, -0.12, 0.48)):
            facade_window(root, f"RiverbendOfficeWestF{floor}B{bay}", (-1.66, y, z), (0.055, 0.34, 0.46), m, frame_axis="X")
        for bay, x in enumerate((-1.36, -0.94)):
            facade_window(root, f"RiverbendOfficeFrontF{floor}B{bay}", (x, -1.225, z), (0.30, 0.055, 0.46), m)
    for bay, y in enumerate((-0.54, 0.06, 0.66)):
        facade_window(root, f"RiverbendHallEast{bay}", (1.705, y, 1.62), (0.055, 0.34, 0.52), m, frame_axis="X")
    cylinder(root, "RiverbendWaterTank", (-1.24, 1.25, 2.34), 0.45, 1.48, m["steel"], vertices=28)
    cone(root, "RiverbendWaterTankRoof", (-1.24, 1.25, 3.16), 0.48, 0.08, 0.34, m["copper"], vertices=28)
    for z in (1.80, 2.26, 2.72):
        cylinder(root, f"RiverbendTankBand{z}", (-1.24, 1.25, z), 0.48, 0.055, m["iron"], vertices=28)
    cylinder(root, "RiverbendDyeStack", (1.40, 1.30, 4.02), 0.22, 3.34, m["brickDark"], vertices=26)
    cylinder(root, "RiverbendDyeStackCap", (1.40, 1.30, 5.74), 0.28, 0.14, m["stone"], vertices=26)
    for index, x in enumerate((-1.40, -0.62, 0.16, 0.94, 1.50)):
        cylinder(root, f"RiverbendPipePost{index}", (x, 1.64, 1.06), 0.045, 1.72, m["iron"], vertices=12)
    for z in (1.52, 1.82):
        beam(root, f"RiverbendPipeRun{z}", (-1.48, 1.64, z), (1.52, 1.64, z), 0.10, m["copper"])
    for index, location in enumerate(((-1.58, -1.58), (1.56, -1.58))):
        planter(root, f"RiverbendStreet{index}", location, m, 0.18)


def ember_rail_foundry(root):
    m = industrial_palette("EmberRail", (0.43, 0.18, 0.11, 1))
    shared_lot(root, "EmberRail", m, 1.10)
    box(root, "EmberHeavyPlinth", (0, 0.12, 0.22), (3.62, 3.12, 0.44), m["walk"], edge=0.05)
    box(root, "EmberCastingHall", (0.34, 0.20, 1.58), (2.58, 2.52, 2.68), m["brick"], edge=0.05)
    gable_roof(root, "EmberCastingRoof", (0.34, 0.20, 2.92), (2.74, 2.68, 0.68), m["roof"], ridge_axis="Y")
    box(root, "EmberFurnaceTower", (-1.08, 0.42, 3.18), (1.02, 1.46, 5.68), m["brickDark"], edge=0.048)
    box(root, "EmberFurnaceCrown", (-1.08, 0.42, 6.10), (1.16, 1.60, 0.22), m["stone"], edge=0.025)
    pyramid_roof(root, "EmberFurnaceRoof", (-1.08, 0.42, 6.21), 1.10, 1.52, 0.48, m["copper"])
    for index, x in enumerate((0.70, 1.38)):
        cylinder(root, f"EmberStack{index}", (x, 1.10, 4.70), 0.24, 6.48, m["oxide"], vertices=28)
        cylinder(root, f"EmberStackCap{index}", (x, 1.10, 7.99), 0.30, 0.16, m["stone"], vertices=28)
        for band, z in enumerate((2.34, 3.34, 4.34, 5.34, 6.34, 7.34)):
            cylinder(root, f"EmberStack{index}Band{band}", (x, 1.10, z), 0.27, 0.075, m["cream"], vertices=28)
    for bay, x in enumerate((-0.34, 0.42, 1.18)):
        box(root, f"EmberLoadingDoor{bay}", (x, -1.075, 1.18), (0.58, 0.07, 1.50), m["steel"], edge=0.018)
        for slat, z in enumerate((0.56, 0.84, 1.12, 1.40, 1.68)):
            box(root, f"EmberLoadingSlat{bay}_{slat}", (x, -1.12, z), (0.50, 0.025, 0.032), m["cream"], edge=0.004)
        box(root, f"EmberLoadingLintel{bay}", (x, -1.14, 2.08), (0.68, 0.11, 0.18), m["stone"], edge=0.012)
    for floor, z in enumerate((1.18, 2.18, 3.18, 4.18, 5.18), start=1):
        facade_window(root, f"EmberFurnaceFront{floor}", (-1.08, -0.335, z), (0.40, 0.055, 0.50), m)
        facade_window(root, f"EmberFurnaceRear{floor}", (-1.08, 1.175, z), (0.40, 0.055, 0.50), m)
        facade_window(root, f"EmberFurnaceWest{floor}", (-1.615, 0.42, z), (0.055, 0.40, 0.48), m, frame_axis="X")
    for side_name, x in (("East", 1.665), ("West", -0.975)):
        for bay, y in enumerate((-0.50, 0.18, 0.86)):
            facade_window(root, f"EmberHall{side_name}{bay}", (x, y, 1.76), (0.055, 0.36, 0.48), m, frame_axis="X")
    # Axis-aligned overhead crane and process yard create a silhouette unlike Foundry Peak.
    for x in (-0.72, 1.38):
        for y in (-0.72, 0.92):
            box(root, f"EmberCraneColumn{x}_{y}", (x, y, 2.20), (0.12, 0.12, 3.64), m["steel"], edge=0.010)
    beam(root, "EmberCraneWestRail", (-0.72, -0.72, 3.92), (-0.72, 0.92, 3.92), 0.14, m["steel"])
    beam(root, "EmberCraneEastRail", (1.38, -0.72, 3.92), (1.38, 0.92, 3.92), 0.14, m["steel"])
    beam(root, "EmberCraneBridge", (-0.72, 0.12, 4.08), (1.38, 0.12, 4.08), 0.18, m["copper"])
    cylinder(root, "EmberCraneHookCable", (0.34, 0.12, 3.34), 0.035, 1.26, m["iron"], vertices=10)
    for index, y in enumerate((-0.46, 0.40)):
        cylinder(root, f"EmberSilo{index}", (-1.52, y, 1.38), 0.30, 2.28, m["steel"], vertices=24)
        cone(root, f"EmberSiloRoof{index}", (-1.52, y, 2.64), 0.31, 0.06, 0.34, m["copper"], vertices=24)
        for ring, z in enumerate((0.66, 1.22, 1.78, 2.34)):
            cylinder(root, f"EmberSilo{index}Ring{ring}", (-1.52, y, z), 0.33, 0.055, m["iron"], vertices=24)
    for index, x in enumerate((-1.48, -0.88, -0.28, 0.32, 0.92, 1.48)):
        cylinder(root, f"EmberRackPost{index}", (x, -1.50, 1.22), 0.05, 1.96, m["iron"], vertices=12)
    for level, z in enumerate((1.58, 1.88, 2.18)):
        beam(root, f"EmberPipeRun{level}", (-1.52, -1.50, z), (1.52, -1.50, z), 0.105, m["copper"] if level == 1 else m["steel"])
    for index, location in enumerate(((-1.58, -1.72), (1.56, -1.72))):
        planter(root, f"EmberStreet{index}", location, m, 0.17)


BUILDERS = {
    "maple_courtyard_apartments": maple_courtyard_apartments,
    "juniper_terrace_tower": juniper_terrace_tower,
    "riverbend_textile_works": riverbend_textile_works,
    "ember_rail_foundry": ember_rail_foundry,
}


def build_asset(asset):
    scene = reset("CitySimNeighborhoodVariety_" + asset["assetId"])
    configure_scene(scene, transparent=True)
    root = asset_root(asset)
    BUILDERS[asset["assetId"]](root)
    cameras = canonical_rig(scene)
    return scene, root, cameras


def write_family_manifest():
    data = {
        "schema": "citysim.world-art.neighborhood-variety-family.v1",
        "status": "source-only-not-live",
        "approvedLiveFamilyIsBaseline": True,
        "originalGeometry": True,
        "cedarMarketReused": False,
        "postRenderCompensation": "none",
        "grid": CONFIG["grid"],
        "canvas": CONFIG["canvas"],
        "cameraRig": CONFIG["cameraRig"],
        "lightingConvention": CONFIG["lighting"],
        "assets": [
            {
                "assetId": asset["assetId"],
                "zone": asset["zone"],
                "densityLevel": asset["densityLevel"],
                "assetFamily": asset["assetFamily"],
                "manifestSha256": sha256(HERE / asset["assetId"] / "manifest.json"),
            }
            for asset in CONFIG["assets"]
        ],
        "sourceFiles": [source_info(HERE / name) for name in ("build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py")],
    }
    (HERE / "family-manifest.json").write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main():
    actual = ".".join(map(str, bpy.app.version))
    if actual != CONFIG["toolchain"]["blenderVersion"]:
        raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    for asset in CONFIG["assets"]:
        output_dir = HERE / asset["assetId"]
        output_dir.mkdir(parents=True, exist_ok=True)
        scene, _, cameras = build_asset(asset)
        blend_path = output_dir / f"{asset['assetId']}.blend"
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
        render_paths = render_views(scene, cameras, asset["assetId"], output_dir / "renders")
        sheet_path = contact_sheet(render_paths, output_dir / f"{asset['assetId']}_contact-sheet.png")
        kit.write_asset_manifest(asset, [blend_path, *render_paths, sheet_path])
    write_family_manifest()
    print("NEIGHBORHOOD_VARIETY_RENDER_PASS assets=4 views=16")


if __name__ == "__main__":
    main()
