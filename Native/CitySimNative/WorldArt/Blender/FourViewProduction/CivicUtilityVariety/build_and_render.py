#!/usr/bin/env python3
"""Build three original CitySim civic and utility variety assets."""

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
source_info = kit.source_info
sha256 = kit.sha256


def cedar_arch_council_hall(root):
    m = palette("CedarArch", accent=(0.18, 0.38, 0.35, 1), brick=(0.56, 0.24, 0.14, 1))
    shared_lot(root, "CedarArch", m, 1.12)
    box(root, "CedarPublicPlaza", (0, -1.12, 0.045), (3.64, 1.48, 0.11), m["walk"], edge=0.028)
    for step, (y, z, width) in enumerate(((-1.50, 0.13, 2.30), (-1.36, 0.22, 2.10), (-1.22, 0.31, 1.90))):
        box(root, f"CedarEntryStep{step}", (0, y, z), (width, 0.34, 0.18), m["stone"], edge=0.018)
    box(root, "CedarHallPlinth", (0, 0.18, 0.25), (3.58, 2.92, 0.50), m["stone"], edge=0.05)
    box(root, "CedarMainHall", (0, 0.40, 1.66), (3.34, 2.30, 2.42), m["brick"], edge=0.05)
    box(root, "CedarWestWing", (-1.23, 0.10, 1.42), (0.92, 2.54, 1.94), m["brickDark"], edge=0.045)
    box(root, "CedarEastWing", (1.23, 0.10, 1.42), (0.92, 2.54, 1.94), m["brickDark"], edge=0.045)
    gable_roof(root, "CedarMainRoof", (0, 0.42, 2.88), (3.46, 2.44, 0.68), m["roof"], ridge_axis="X")
    gable_roof(root, "CedarWestRoof", (-1.23, 0.10, 2.40), (1.02, 2.66, 0.48), m["roof"], ridge_axis="Y")
    gable_roof(root, "CedarEastRoof", (1.23, 0.10, 2.40), (1.02, 2.66, 0.48), m["roof"], ridge_axis="Y")
    # A centered clock tower and copper cupola make a civic silhouette distinct from Hearthside.
    box(root, "CedarTowerBase", (0, 0.24, 3.25), (1.14, 1.12, 1.46), m["stone"], edge=0.04)
    box(root, "CedarTowerBrick", (0, 0.24, 4.34), (0.94, 0.92, 0.86), m["brick"], edge=0.035)
    box(root, "CedarTowerCornice", (0, 0.24, 4.83), (1.10, 1.08, 0.14), m["cream"], edge=0.018)
    pyramid_roof(root, "CedarCupolaRoof", (0, 0.24, 4.90), 1.04, 1.02, 0.72, m["copper"])
    cylinder(root, "CedarCupolaFinial", (0, 0.24, 5.83), 0.055, 0.44, m["copper"], vertices=14)
    for face, location, rotation in (
        ("Front", (0, -0.235, 4.35), (math.radians(90), 0, 0)),
        ("Rear", (0, 0.715, 4.35), (math.radians(90), 0, 0)),
        ("West", (-0.495, 0.24, 4.35), (0, math.radians(90), 0)),
        ("East", (0.495, 0.24, 4.35), (0, math.radians(90), 0)),
    ):
        cylinder(root, f"CedarClockFace{face}", location, 0.29, 0.055, m["cream"], vertices=32, rotation=rotation)
        cylinder(root, f"CedarClockHub{face}", location, 0.065, 0.075, m["iron"], vertices=18, rotation=rotation)
    # Deep entrance arcade reads from the live camNE frontage and remains authored on every side.
    box(root, "CedarArcadeBeam", (0, -1.00, 1.70), (2.06, 0.34, 0.20), m["stone"], edge=0.022)
    for index, x in enumerate((-0.82, -0.28, 0.28, 0.82)):
        cylinder(root, f"CedarArcadeColumn{index}", (x, -1.00, 1.02), 0.10, 1.34, m["cream"], vertices=20)
        box(root, f"CedarColumnBase{index}", (x, -1.00, 0.39), (0.28, 0.28, 0.16), m["stone"], edge=0.015)
        box(root, f"CedarColumnCapital{index}", (x, -1.00, 1.66), (0.26, 0.26, 0.14), m["stone"], edge=0.015)
    for index, x in enumerate((-0.55, 0.55)):
        box(root, f"CedarEntryDoor{index}", (x, -1.175, 0.98), (0.52, 0.07, 1.12), m["accent"], edge=0.016)
        box(root, f"CedarEntryTransom{index}", (x, -1.215, 1.47), (0.38, 0.035, 0.18), m["glass"], edge=0.008)
    for floor, z in enumerate((1.15, 2.05), start=1):
        for bay, x in enumerate((-1.28, -0.72, 0.72, 1.28)):
            facade_window(root, f"CedarFrontF{floor}B{bay}", (x, -0.775, z), (0.34, 0.055, 0.48), m)
            facade_window(root, f"CedarRearF{floor}B{bay}", (x, 1.575, z), (0.34, 0.055, 0.48), m)
        for side, x in (("West", -1.72), ("East", 1.72)):
            for bay, y in enumerate((-0.42, 0.18, 0.78)):
                facade_window(root, f"Cedar{side}F{floor}B{bay}", (x, y, z), (0.055, 0.32, 0.46), m, frame_axis="X")
    for index, location in enumerate(((-1.55, -1.58), (1.55, -1.58), (-1.52, 1.55), (1.52, 1.55))):
        planter(root, f"CedarCivicPlanter{index}", location, m, 0.21)
    for index, x in enumerate((-0.58, 0.58)):
        box(root, f"CedarPlazaBench{index}", (x, -1.66, 0.34), (0.72, 0.22, 0.11), m["wood"], edge=0.016)


def utility_palette(prefix, accent, brick):
    m = palette(prefix, accent=accent, brick=brick)
    m["steel"] = material(prefix + "PaintedSteel", (0.20, 0.26, 0.27, 1), roughness=0.43, metallic=0.54, texture_scale=8.0)
    m["oxide"] = material(prefix + "Oxide", (0.48, 0.22, 0.09, 1), roughness=0.57, metallic=0.20, texture_scale=10.0)
    m["ceramic"] = material(prefix + "Ceramic", (0.76, 0.48, 0.25, 1), roughness=0.42, texture_scale=5.0)
    return m


def copper_arc_powerhouse(root):
    m = utility_palette("CopperArc", (0.68, 0.42, 0.12, 1), (0.49, 0.20, 0.12, 1))
    shared_lot(root, "CopperArc", m, 0.82)
    box(root, "CopperArcServiceApron", (0, 0.15, 0.04), (3.62, 3.22, 0.10), m["walk"], edge=0.028)
    box(root, "CopperArcPlinth", (-0.28, 0.30, 0.24), (3.18, 2.72, 0.42), m["stone"], edge=0.05)
    box(root, "CopperArcTurbineHall", (-0.50, 0.40, 1.98), (2.26, 2.30, 3.16), m["brick"], edge=0.05)
    gable_roof(root, "CopperArcTurbineRoof", (-0.50, 0.40, 3.58), (2.40, 2.44, 0.62), m["roof"], ridge_axis="Y")
    box(root, "CopperArcControlWing", (1.02, -0.12, 1.36), (1.02, 2.70, 1.92), m["brickDark"], edge=0.045)
    box(root, "CopperArcControlRoof", (1.02, -0.12, 2.39), (1.14, 2.82, 0.17), m["roof"], edge=0.022)
    box(root, "CopperArcDecoCrown", (-0.50, -0.80, 3.20), (1.76, 0.22, 0.32), m["stone"], edge=0.018)
    for tier, (z, width) in enumerate(((3.44, 1.34), (3.66, 0.94))):
        box(root, f"CopperArcSteppedParapet{tier}", (-0.50, -0.82, z), (width, 0.20, 0.22), m["cream"], edge=0.014)
    for index, x in enumerate((-0.86, -0.14)):
        cylinder(root, f"CopperArcStack{index}", (x, 1.20, 4.52), 0.25, 5.70, m["oxide"], vertices=30)
        cylinder(root, f"CopperArcStackCap{index}", (x, 1.20, 7.42), 0.31, 0.14, m["stone"], vertices=30)
        for band, z in enumerate((2.48, 3.42, 4.36, 5.30, 6.24)):
            cylinder(root, f"CopperArcStack{index}Band{band}", (x, 1.20, z), 0.28, 0.07, m["cream"], vertices=30)
    for floor, z in enumerate((1.10, 2.03, 2.94), start=1):
        for bay, x in enumerate((-1.20, -0.58, 0.04)):
            facade_window(root, f"CopperArcHallFrontF{floor}B{bay}", (x, -0.77, z), (0.36, 0.055, 0.54), m)
            facade_window(root, f"CopperArcHallRearF{floor}B{bay}", (x, 1.57, z), (0.36, 0.055, 0.54), m)
    for floor, z in enumerate((1.04, 1.82), start=1):
        for side, x in (("East", 1.55), ("West", 0.49)):
            for bay, y in enumerate((-0.92, -0.28, 0.36, 1.00)):
                facade_window(root, f"CopperArcControl{side}F{floor}B{bay}", (x, y, z), (0.055, 0.34, 0.46), m, frame_axis="X")
    box(root, "CopperArcMainDoor", (0.98, -1.50, 0.92), (0.58, 0.07, 1.08), m["accent"], edge=0.018)
    box(root, "CopperArcDoorCanopy", (0.98, -1.66, 1.50), (0.88, 0.42, 0.13), m["copper"], edge=0.016)
    # Compact transformer court and exposed buswork keep the function legible.
    for unit, y in enumerate((-0.86, 0.06, 0.98)):
        box(root, f"CopperArcTransformerPad{unit}", (1.60, y, 0.20), (0.52, 0.64, 0.20), m["stone"], edge=0.018)
        box(root, f"CopperArcTransformer{unit}", (1.60, y, 0.70), (0.44, 0.54, 0.80), m["steel"], edge=0.055)
        for fin, x in enumerate((1.43, 1.52, 1.68, 1.77)):
            box(root, f"CopperArcTransformer{unit}Fin{fin}", (x, y - 0.30, 0.70), (0.035, 0.08, 0.56), m["iron"], edge=0.004)
        for phase, x in enumerate((1.48, 1.60, 1.72)):
            cylinder(root, f"CopperArcBushing{unit}_{phase}", (x, y, 1.20), 0.055, 0.30, m["ceramic"], vertices=14)
    for index, x in enumerate((1.28, 1.86)):
        box(root, f"CopperArcGantryPost{index}", (x, 1.42, 1.25), (0.10, 0.10, 2.18), m["steel"], edge=0.010)
    beam(root, "CopperArcGantryBeam", (1.28, 1.42, 2.30), (1.86, 1.42, 2.30), 0.11, m["steel"])
    for phase, x in enumerate((1.36, 1.57, 1.78)):
        beam(root, f"CopperArcBus{phase}", (x, -0.86, 1.28), (x, 1.42, 2.32), 0.038, m["copper"])
    for index, location in enumerate(((-1.62, -1.62), (1.60, -1.62))):
        planter(root, f"CopperArcStreetPlanter{index}", location, m, 0.17)


def rivermark_standpipe_waterworks(root):
    m = utility_palette("Rivermark", (0.16, 0.42, 0.40, 1), (0.53, 0.23, 0.14, 1))
    shared_lot(root, "Rivermark", m, 0.92)
    box(root, "RivermarkServiceCourt", (0, 0.10, 0.04), (3.58, 3.22, 0.10), m["walk"], edge=0.028)
    # A masonry standpipe replaces the current open-leg tank silhouette.
    cylinder(root, "RivermarkTowerPlinth", (-0.30, 0.34, 0.28), 1.08, 0.50, m["stone"], vertices=32)
    cylinder(root, "RivermarkBrickShaft", (-0.30, 0.34, 3.12), 0.86, 5.30, m["brick"], vertices=32)
    for tier, (z, radius) in enumerate(((0.72, 0.94), (2.00, 0.90), (3.30, 0.88), (4.56, 0.92), (5.70, 1.02))):
        cylinder(root, f"RivermarkStoneBand{tier}", (-0.30, 0.34, z), radius, 0.13, m["cream"], vertices=32)
    cone(root, "RivermarkTankShoulder", (-0.30, 0.34, 6.04), 1.04, 0.88, 0.56, m["copper"], vertices=36)
    cylinder(root, "RivermarkTankBarrel", (-0.30, 0.34, 6.55), 0.88, 0.58, m["copper"], vertices=36)
    cone(root, "RivermarkTankDome", (-0.30, 0.34, 7.08), 0.92, 0.08, 0.72, m["roof"], vertices=36)
    cylinder(root, "RivermarkFinial", (-0.30, 0.34, 7.62), 0.055, 0.36, m["copper"], vertices=14)
    for floor, z in enumerate((1.08, 2.10, 3.12, 4.14, 5.16), start=1):
        for face, location, rotation in (
            ("Front", (-0.30, -0.535, z), (math.radians(90), 0, 0)),
            ("Rear", (-0.30, 1.215, z), (math.radians(90), 0, 0)),
            ("West", (-1.175, 0.34, z), (0, math.radians(90), 0)),
            ("East", (0.575, 0.34, z), (0, math.radians(90), 0)),
        ):
            box(root, f"RivermarkWindowFrame{face}{floor}", location, (0.34, 0.08, 0.52) if face in ("Front", "Rear") else (0.08, 0.34, 0.52), m["cream"], rotation=rotation, edge=0.010)
            box(root, f"RivermarkWindowGlass{face}{floor}", location, (0.24, 0.09, 0.40) if face in ("Front", "Rear") else (0.09, 0.24, 0.40), m["glass"], rotation=rotation, edge=0.007)
    # Four buttresses visually tie the tall shaft into its exact lot footprint.
    for index, (x, y) in enumerate(((-0.94, -0.30), (0.34, -0.30), (-0.94, 0.98), (0.34, 0.98))):
        box(root, f"RivermarkButtress{index}", (x, y, 1.18), (0.32, 0.32, 1.92), m["stone"], edge=0.035)
        pyramid_roof(root, f"RivermarkButtressCap{index}", (x, y, 2.14), 0.38, 0.38, 0.30, m["copper"])
    box(root, "RivermarkPumpPlinth", (1.05, -0.66, 0.22), (1.38, 1.52, 0.34), m["stone"], edge=0.04)
    box(root, "RivermarkPumpHouse", (1.05, -0.66, 1.00), (1.22, 1.34, 1.28), m["brickDark"], edge=0.04)
    gable_roof(root, "RivermarkPumpRoof", (1.05, -0.66, 1.64), (1.36, 1.48, 0.46), m["roof"], ridge_axis="Y")
    box(root, "RivermarkPumpDoor", (1.05, -1.345, 0.89), (0.50, 0.07, 0.98), m["accent"], edge=0.016)
    facade_window(root, "RivermarkPumpEastWindow", (1.68, -0.66, 1.06), (0.055, 0.38, 0.44), m, frame_axis="X")
    facade_window(root, "RivermarkPumpWestWindow", (0.42, -0.66, 1.06), (0.055, 0.38, 0.44), m, frame_axis="X")
    # Ground-level manifolds, gauges, and a ladder communicate water infrastructure.
    cylinder(root, "RivermarkMainRiser", (1.30, 0.72, 0.76), 0.12, 1.24, m["steel"], vertices=20)
    beam(root, "RivermarkMainPipe", (0.40, 0.72, 0.52), (1.62, 0.72, 0.52), 0.13, m["copper"])
    for index, x in enumerate((0.62, 1.02, 1.42)):
        cylinder(root, f"RivermarkValve{index}", (x, 0.72, 0.78), 0.16, 0.055, m["oxide"], vertices=18, rotation=(math.radians(90), 0, 0))
    for rail_x in (-0.05, 0.10):
        beam(root, f"RivermarkLadderRail{rail_x}", (rail_x, -0.54, 0.72), (rail_x, -0.54, 5.62), 0.034, m["iron"])
    for rung, z in enumerate([0.88 + i * 0.34 for i in range(14)]):
        box(root, f"RivermarkLadderRung{rung}", (0.025, -0.56, z), (0.28, 0.035, 0.035), m["iron"], edge=0.004)
    for index, location in enumerate(((-1.58, -1.58), (1.55, -1.58), (1.52, 1.50))):
        planter(root, f"RivermarkGarden{index}", location, m, 0.18)


BUILDERS = {
    "cedar_arch_council_hall": cedar_arch_council_hall,
    "copper_arc_powerhouse": copper_arc_powerhouse,
    "rivermark_standpipe_waterworks": rivermark_standpipe_waterworks,
}


def build_asset(asset):
    scene = reset("CitySimCivicUtilityVariety_" + asset["assetId"])
    configure_scene(scene, transparent=True)
    root = asset_root(asset)
    BUILDERS[asset["assetId"]](root)
    cameras = canonical_rig(scene)
    return scene, root, cameras


def write_family_manifest():
    data = {
        "schema": "citysim.world-art.civic-utility-variety-family.v1",
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
    print("CIVIC_UTILITY_VARIETY_RENDER_PASS assets=3 views=12")


if __name__ == "__main__":
    main()
