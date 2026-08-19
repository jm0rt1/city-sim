#!/usr/bin/env python3
"""Build two original commercial variants in CitySim's approved four-view family."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
PRODUCTION = HERE.parent
BLENDER_ROOT = PRODUCTION.parent
CANONICAL = BLENDER_ROOT / "FourViewPipeline"
DENSITY = PRODUCTION / "Density"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))
from png_canonical import canonicalize_png, decode_rgba_png  # noqa: E402


def load_density_builder():
    spec = importlib.util.spec_from_file_location("citysim_density_builder", DENSITY / "build_and_render.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("APPROVED_BASELINE_HELPERS_UNAVAILABLE")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


baseline = load_density_builder()
CONFIG = json.loads((HERE / "pipeline.json").read_text(encoding="utf-8"))
VIEWS = CONFIG["cameraRig"]["views"]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_info(path: Path) -> dict:
    return {"path": path.relative_to(HERE).as_posix(), "sha256": sha256(path)}


def alpha_metadata(path: Path) -> dict:
    width, height, rgba = decode_rgba_png(path)
    visible = [(index % width, index // width) for index, alpha in enumerate(rgba[3::4]) if alpha]
    if not visible:
        raise RuntimeError(f"EMPTY_ALPHA: {path}")
    xs = [point[0] for point in visible]
    ys = [point[1] for point in visible]
    pivot_x, pivot_y = CONFIG["canvas"]["footprintPivotPixel"]
    return {
        "boundsTopOrigin": {
            "minX": min(xs), "minY": min(ys), "maxX": max(xs), "maxY": max(ys),
            "width": max(xs) - min(xs) + 1, "height": max(ys) - min(ys) + 1,
        },
        "opaquePixelCount": len(visible),
        "lowestOpaqueRowTopOrigin": max(ys),
        "pivotPixelAlpha": rgba[(pivot_y * width + pivot_x) * 4 + 3],
    }


def artifact_info(path: Path, relative_to: Path = HERE) -> dict:
    info = {"path": path.relative_to(relative_to).as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)}
    if path.suffix == ".png":
        width, height, rgba = decode_rgba_png(path)
        info.update(
            dimensions=[width, height],
            decodedRgbaSha256=hashlib.sha256(rgba).hexdigest(),
            alpha=alpha_metadata(path),
        )
    return info


def asset_root(asset: dict):
    root = bpy.data.objects.new("AssetRoot", None)
    bpy.context.collection.objects.link(root)
    pivot = bpy.data.objects.new("FootprintPivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.parent = root
    pivot.empty_display_type = "CIRCLE"
    pivot.empty_display_size = 0.2
    root["assetId"] = asset["assetId"]
    root["assetFamily"] = asset["assetFamily"]
    root["zone"] = asset["zone"]
    root["densityLevel"] = asset["densityLevel"]
    root["worldFootprintTiles"] = asset["footprintTiles"]
    root["sourcePixelsReused"] = False
    root["cedarMarketReused"] = False
    root["liveAsset"] = False
    root["fixedObjectScale"] = True
    root["postRenderCompensation"] = "none"
    return root


def sunbrick_market_lofts(root):
    """A stepped, craft-market loft sibling with a different silhouette from Market Arcade."""
    m = baseline.palette("SunbrickLofts", accent=(0.73, 0.32, 0.12, 1), brick=(0.64, 0.34, 0.18, 1))
    m["sunbrick"] = baseline.material("SunbrickLoftsGoldenBrick", (0.70, 0.40, 0.20, 1), texture_scale=16.0, bump=0.18)
    m["canopy"] = baseline.material("SunbrickLoftsCanvas", (0.84, 0.58, 0.26, 1), roughness=0.72, texture_scale=9.0, bump=0.08)
    baseline.shared_lot(root, "Sunbrick", m, 0.94)
    baseline.box(root, "SunbrickStonePlinth", (0, 0.10, 0.22), (3.56, 3.08, 0.44), m["stone"], edge=0.050)
    baseline.box(root, "SunbrickMarketPodium", (0, 0.08, 1.00), (3.44, 2.96, 1.32), m["stone"], edge=0.048)
    baseline.box(root, "SunbrickLoftBody", (-0.14, 0.19, 3.06), (3.12, 2.60, 2.92), m["sunbrick"], edge=0.050)
    baseline.box(root, "SunbrickUpperSetback", (-0.58, 0.38, 5.00), (1.86, 1.78, 1.18), m["brick"], edge=0.044)
    baseline.box(root, "SunbrickCornerOriel", (1.36, -0.99, 3.43), (0.56, 0.72, 2.30), m["brickDark"], edge=0.038)
    for z in (1.70, 2.60, 3.50, 4.46):
        width = 3.24 if z < 4.4 else 2.02
        center_x = -0.14 if z < 4.4 else -0.58
        depth = 2.72 if z < 4.4 else 1.90
        baseline.box(root, f"SunbrickFloorBelt{z}", (center_x, 0.20 if z < 4.4 else 0.38, z), (width, depth, 0.11), m["cream"], edge=0.012)
    baseline.box(root, "SunbrickMainRoof", (-0.14, 0.19, 4.58), (3.24, 2.72, 0.20), m["roof"], edge=0.028)
    baseline.box(root, "SunbrickSetbackRoof", (-0.58, 0.38, 5.62), (1.98, 1.90, 0.18), m["copper"], edge=0.026)

    # Four deep market bays and a recessed central passage create a distinct ground-floor rhythm.
    for bay, x in enumerate((-1.24, -0.46, 0.46, 1.24)):
        baseline.facade_window(root, f"SunbrickShopfront{bay}", (x, -1.405, 0.94), (0.55, 0.055, 0.86), m, frame=False)
        canopy_mat = m["canopy"] if bay % 2 == 0 else m["accent"]
        baseline.box(root, f"SunbrickStripedAwning{bay}", (x, -1.60, 1.49), (0.64, 0.44, 0.14), canopy_mat, rotation=(math.radians(-11), 0, 0), edge=0.015)
        for stripe, offset in enumerate((-0.20, 0.0, 0.20)):
            baseline.box(root, f"SunbrickAwningStripe{bay}_{stripe}", (x + offset, -1.81, 1.45), (0.07, 0.05, 0.10), m["cream"], rotation=(math.radians(-11), 0, 0), edge=0.006)
    baseline.box(root, "SunbrickPassageRecess", (0, -1.48, 0.90), (0.62, 0.12, 1.18), m["brickDark"], edge=0.018)
    baseline.box(root, "SunbrickDoubleDoor", (0, -1.57, 0.88), (0.50, 0.06, 1.04), m["accent"], edge=0.016)
    baseline.box(root, "SunbrickMarketSign", (0, -1.58, 1.61), (1.18, 0.10, 0.24), m["copper"], edge=0.018)

    # Authored loft windows wrap every facade, with the upper floor visibly stepping back.
    floors = ((2.18, False), (3.06, False), (3.94, False), (4.91, True))
    for floor, (z, upper) in enumerate(floors, start=1):
        xs = (-1.08, -0.38, 0.38, 1.08) if not upper else (-0.96, -0.52, -0.08)
        front_y = -1.115 if not upper else -0.515
        rear_y = 1.495 if not upper else 1.285
        for bay, x in enumerate(xs):
            baseline.facade_window(root, f"SunbrickFrontLoftF{floor}B{bay}", (x, front_y, z), (0.40, 0.055, 0.50), m)
            baseline.facade_window(root, f"SunbrickRearLoftF{floor}B{bay}", (x, rear_y, z), (0.40, 0.055, 0.50), m)
        side_xs = ((1.435, -1.715),) if not upper else ((0.375, -1.535),)
        for east_x, west_x in side_xs:
            for side, x in (("East", east_x), ("West", west_x)):
                for bay, y in enumerate((-0.48, 0.18, 0.82) if not upper else (0.02, 0.72)):
                    baseline.facade_window(root, f"Sunbrick{side}LoftF{floor}B{bay}", (x, y, z), (0.055, 0.36, 0.48), m, frame_axis="X")

    # A real iron fire escape and rooftop conservatory distinguish the loft use at game scale.
    for level, z in enumerate((2.34, 3.24, 4.14)):
        baseline.box(root, f"SunbrickFireEscapeSlab{level}", (-1.75, 0.52, z), (0.42, 0.92, 0.09), m["iron"], edge=0.012)
        for y in (0.14, 0.52, 0.90):
            baseline.box(root, f"SunbrickFireRail{level}_{y}", (-1.97, y, z + 0.24), (0.04, 0.04, 0.43), m["iron"], edge=0.005)
        baseline.box(root, f"SunbrickFireTopRail{level}", (-1.97, 0.52, z + 0.47), (0.04, 0.86, 0.05), m["iron"], edge=0.005)
        if level < 2:
            baseline.beam(root, f"SunbrickFireLadder{level}", (-1.95, 0.88, z + 0.06), (-1.95, 0.16, z + 0.92), 0.045, m["iron"])
    baseline.box(root, "SunbrickConservatoryBase", (0.72, 0.44, 4.82), (1.12, 1.02, 0.15), m["stone"], edge=0.020)
    for index, x in enumerate((0.28, 0.72, 1.16)):
        baseline.beam(root, f"SunbrickConservatoryRib{index}", (x, -0.02, 4.92), (x, 0.90, 5.52), 0.055, m["copper"])
    baseline.box(root, "SunbrickConservatoryGlass", (0.72, 0.44, 5.18), (0.98, 0.88, 0.54), m["glass"], edge=0.025)
    for index, location in enumerate(((-1.52, -1.60), (1.52, -1.60), (-1.52, 1.50), (1.48, 1.50))):
        baseline.planter(root, f"SunbrickStreet{index}", location, m, 0.20)


def copperglass_exchange_annex(root):
    """An asymmetrical stepped copperglass office tower, distinct from Aurora's vertical crown."""
    m = baseline.palette("CopperglassAnnex", accent=(0.10, 0.38, 0.43, 1), brick=(0.46, 0.23, 0.14, 1))
    m["copperBright"] = baseline.material("CopperglassBurnishedCopper", (0.62, 0.38, 0.19, 1), roughness=0.38, metallic=0.56, texture_scale=7.0, bump=0.08)
    m["glassLight"] = baseline.material("CopperglassSunlitGlass", (0.22, 0.52, 0.56, 1), roughness=0.20, texture_scale=0)
    baseline.shared_lot(root, "Copperglass", m, 0.84)
    baseline.box(root, "CopperglassStonePlinth", (0, 0.10, 0.22), (3.58, 3.10, 0.44), m["stone"], edge=0.050)
    baseline.box(root, "CopperglassLobbyPodium", (0, 0.10, 1.08), (3.46, 2.98, 1.44), m["stone"], edge=0.048)
    baseline.box(root, "CopperglassLowerTower", (-0.20, 0.22, 3.72), (2.92, 2.42, 3.92), m["brickDark"], edge=0.048)
    baseline.box(root, "CopperglassMiddleSetback", (0.16, 0.30, 6.10), (2.28, 1.92, 1.38), m["brickDark"], edge=0.043)
    baseline.box(root, "CopperglassUpperLantern", (0.54, 0.34, 7.28), (1.38, 1.34, 1.04), m["glassLight"], edge=0.038)
    baseline.box(root, "CopperglassLanternCap", (0.54, 0.34, 7.86), (1.56, 1.50, 0.18), m["copperBright"], edge=0.026)
    for x in (0.02, 0.54, 1.06):
        baseline.box(root, f"CopperglassCrownPost{x}", (x, 0.34, 8.18), (0.065, 1.34, 0.68), m["copper"], edge=0.008)
    for y in (-0.26, 0.34, 0.94):
        baseline.beam(root, f"CopperglassCrownBeam{y}", (-0.04, y, 8.50), (1.12, y, 8.50), 0.075, m["copperBright"])

    # A broad transparent lobby and corner pavilion make the street edge visibly different.
    for bay, x in enumerate((-1.18, -0.40, 0.40, 1.18)):
        baseline.facade_window(root, f"CopperglassLobbyBay{bay}", (x, -1.405, 0.98), (0.56, 0.055, 0.92), m, frame=False)
        baseline.box(root, f"CopperglassLobbyMullion{bay}", (x, -1.445, 0.98), (0.045, 0.045, 0.86), m["copperBright"], edge=0.005)
    baseline.box(root, "CopperglassCornerVestibule", (1.49, -1.18, 1.00), (0.24, 0.64, 1.28), m["glassLight"], edge=0.018)
    baseline.box(root, "CopperglassEntryCanopy", (1.18, -1.61, 1.66), (1.06, 0.52, 0.13), m["copperBright"], edge=0.018)
    for x in (0.78, 1.56):
        baseline.cylinder(root, f"CopperglassCanopyPost{x}", (x, -1.66, 0.88), 0.04, 1.40, m["iron"], vertices=12)

    # Horizontal copper spandrels and paired glass bays replace Aurora's vertical-fin language.
    levels = (2.12, 2.94, 3.76, 4.58, 5.40, 6.18, 6.86, 7.30)
    for floor, z in enumerate(levels, start=1):
        upper = floor >= 8
        middle = floor >= 7 and not upper
        center_x = 0.54 if upper else 0.16 if middle else -0.20
        half_width = 0.48 if upper else 0.88 if middle else 1.18
        front_y = -0.32 if upper else -0.66 if middle else -0.99
        rear_y = 1.00 if upper else 1.26 if middle else 1.43
        xs = (center_x - half_width, center_x - half_width / 3, center_x + half_width / 3, center_x + half_width)
        for bay, x in enumerate(xs):
            glass = m["glassLight"] if (floor + bay) % 3 == 0 else m["glass"]
            baseline.box(root, f"CopperglassFrontF{floor}B{bay}", (x, front_y, z), (0.38, 0.052, 0.52), glass, edge=0.009)
            baseline.box(root, f"CopperglassRearF{floor}B{bay}", (x, rear_y, z), (0.38, 0.052, 0.52), glass, edge=0.009)
        east_x = center_x + (0.70 if upper else 1.16 if middle else 1.49)
        west_x = center_x - (0.70 if upper else 1.16 if middle else 1.49)
        ys = (0.04, 0.48, 0.88) if upper else (-0.48, 0.14, 0.76)
        for side, x in (("East", east_x), ("West", west_x)):
            for bay, y in enumerate(ys):
                baseline.box(root, f"Copperglass{side}F{floor}B{bay}", (x, y, z), (0.052, 0.34, 0.50), m["glass"], edge=0.009)
        band_width = 1.52 if upper else 2.42 if middle else 3.04
        band_depth = 1.46 if upper else 2.06 if middle else 2.54
        baseline.box(root, f"CopperglassSpandrel{floor}", (center_x, 0.25 if not upper else 0.34, z + 0.36), (band_width, band_depth, 0.10), m["copperBright"], edge=0.010)

    # An external frame and two planted sky terraces emphasize the stepping in all views.
    for side, x in (("East", 1.32), ("West", -1.72)):
        for y in (-0.72, 0.20, 1.12):
            baseline.box(root, f"CopperglassFrame{side}{y}", (x, y, 4.18), (0.065, 0.065, 4.88), m["copper"], edge=0.006)
        for z in (2.38, 4.02, 5.66):
            baseline.beam(root, f"CopperglassFrameTie{side}{z}", (x, -0.72, z), (x, 1.12, z), 0.065, m["copper"])
    for terrace, (x, y, z) in enumerate(((1.14, -0.42, 5.88), (-0.86, 0.92, 6.90))):
        baseline.box(root, f"CopperglassSkyTerrace{terrace}", (x, y, z), (0.72, 0.62, 0.14), m["stone"], edge=0.020)
        baseline.box(root, f"CopperglassTerracePlanter{terrace}", (x, y, z + 0.18), (0.52, 0.34, 0.20), m["walk"], edge=0.018)
        baseline.sphere(root, f"CopperglassTerraceTree{terrace}", (x, y, z + 0.50), (0.22, 0.20, 0.30), m["leaf"])
    baseline.cylinder(root, "CopperglassPlazaSculpture", (-1.30, -1.48, 0.72), 0.16, 0.96, m["copperBright"], vertices=12)
    baseline.sphere(root, "CopperglassPlazaOrb", (-1.30, -1.48, 1.28), (0.25, 0.25, 0.25), m["copper"])
    for index, location in enumerate(((-1.58, -1.64), (0.32, -1.68), (-1.52, 1.52), (1.48, 1.52))):
        baseline.planter(root, f"CopperglassStreet{index}", location, m, 0.19)


BUILDERS = {
    "sunbrick_market_lofts": sunbrick_market_lofts,
    "copperglass_exchange_annex": copperglass_exchange_annex,
}


def build_asset(asset: dict):
    scene = baseline.reset("CitySimCommercialVariety_" + asset["assetId"])
    baseline.configure_scene(scene, transparent=True)
    scene["pipelineSchema"] = CONFIG["schema"]
    root = asset_root(asset)
    BUILDERS[asset["assetId"]](root)
    cameras = baseline.canonical_rig(scene)
    return scene, root, cameras


def write_asset_manifest(asset: dict, artifacts: list[Path]) -> Path:
    output_dir = HERE / asset["assetId"]
    manifest = {
        "schema": "citysim.world-art.commercial-variety-asset.v1",
        "pipelineSchema": CONFIG["schema"],
        "assetId": asset["assetId"],
        "description": asset["description"],
        "zone": asset["zone"],
        "densityLevel": asset["densityLevel"],
        "assetFamily": asset["assetFamily"],
        "status": "source-only-not-live",
        "liveAsset": False,
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "cedarMarketReused": False,
        "approvedStyleBaseline": CONFIG["provenance"]["approvedStyleBaseline"],
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
        "artifacts": [artifact_info(path, output_dir) for path in artifacts],
    }
    path = output_dir / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


def approved_sibling_sources() -> dict[str, Path]:
    return {
        "market_arcade_midrise": DENSITY / "market_arcade_midrise/market_arcade_midrise.blend",
        "aurora_exchange_tower": DENSITY / "aurora_exchange_tower/aurora_exchange_tower.blend",
    }


def preview_camera_and_light(scene):
    camera_config = CONFIG["preview"]["camera"]
    distance = 42.0
    elevation = math.radians(camera_config["elevationDegrees"])
    azimuth = math.radians(camera_config["azimuthDegrees"])
    target = Vector(camera_config["targetWorld"])
    horizontal = distance * math.cos(elevation)
    camera_data = bpy.data.cameras.new("camNE_CommercialBlockPreview")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = camera_config["orthoScale"]
    camera = bpy.data.objects.new("camNE_CommercialBlockPreview", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = target + Vector((horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation)))
    baseline.point_at(camera, target)
    lighting = CONFIG["lighting"]
    light_data = bpy.data.lights.new(lighting["name"], lighting["type"])
    light_data.energy = lighting["energy"]
    light_data.shape = "DISK"
    light_data.size = lighting["size"]
    light_data.color = lighting["color"]
    light = bpy.data.objects.new(lighting["name"], light_data)
    bpy.context.collection.objects.link(light)
    light.location = lighting["location"]
    baseline.point_at(light)
    scene.camera = camera


def preview_placements() -> list[dict]:
    approved = approved_sibling_sources()
    return [
        {"assetId": "market_arcade_midrise", "role": "approved-medium-sibling", "source": approved["market_arcade_midrise"], "origin": (-4.0, 4.0, 0.0)},
        {"assetId": "sunbrick_market_lofts", "role": "new-medium-candidate", "source": HERE / "sunbrick_market_lofts/sunbrick_market_lofts.blend", "origin": (4.0, 4.0, 0.0)},
        {"assetId": "aurora_exchange_tower", "role": "approved-high-sibling", "source": approved["aurora_exchange_tower"], "origin": (-4.0, -4.0, 0.0)},
        {"assetId": "copperglass_exchange_annex", "role": "new-high-candidate", "source": HERE / "copperglass_exchange_annex/copperglass_exchange_annex.blend", "origin": (4.0, -4.0, 0.0)},
    ]


def build_preview(output_root: Path = HERE) -> list[Path]:
    scene = baseline.reset("CitySimCopperRowCommercialBlock")
    baseline.configure_scene(scene, transparent=False)
    scene["pipelineSchema"] = CONFIG["schema"]
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    ground = baseline.material("CopperRowGround", (0.27, 0.36, 0.23, 1), texture_scale=6.0, bump=0.11)
    asphalt = baseline.material("CopperRowAsphalt", (0.15, 0.18, 0.18, 1), texture_scale=20.0, bump=0.15)
    curb = baseline.material("CopperRowCurb", (0.66, 0.59, 0.48, 1), texture_scale=11.0, bump=0.12)
    stripe = baseline.material("CopperRowLaneMark", (0.82, 0.58, 0.20, 1), roughness=0.64, texture_scale=4.0)
    baseline.box(root, "CommercialBlockGround", (0, 0, -0.30), (16, 16, 0.30), ground, edge=0.08)
    for axis in ("X", "Y"):
        dimensions = (16, 3.2, 0.12) if axis == "X" else (3.2, 16, 0.12)
        baseline.box(root, f"{axis}AxisRoad", (0, 0, -0.07), dimensions, asphalt, edge=0.020)
        for side in (-1, 1):
            location = (0, side * 1.68, 0.01) if axis == "X" else (side * 1.68, 0, 0.01)
            curb_dimensions = (16, 0.16, 0.14) if axis == "X" else (0.16, 16, 0.14)
            baseline.box(root, f"{axis}AxisCurb{side}", location, curb_dimensions, curb, edge=0.014)
        for index, position in enumerate((-6.0, -3.0, 3.0, 6.0)):
            location = (position, 0, 0.005) if axis == "X" else (0, position, 0.005)
            dash_dimensions = (1.0, 0.07, 0.025) if axis == "X" else (0.07, 1.0, 0.025)
            baseline.box(root, f"{axis}AxisDash{index}", location, dash_dimensions, stripe, edge=0.004)
    placements = []
    for item in preview_placements():
        if not item["source"].is_file():
            raise RuntimeError(f"MISSING_PREVIEW_SOURCE: {item['source']}")
        placement, mesh_count = baseline.append_mesh_asset(item["source"], "Placement_" + item["assetId"], item["origin"])
        placement["role"] = item["role"]
        placements.append({
            "assetId": item["assetId"],
            "role": item["role"],
            "originWorld": list(item["origin"]),
            "footprintTiles": [2, 2],
            "sourceBlend": item["source"].relative_to(BLENDER_ROOT).as_posix(),
            "sourceBlendSha256": sha256(item["source"]),
            "meshCount": mesh_count,
            "perAssetTransformCompensation": "none",
        })
    preview_camera_and_light(scene)
    preview_dir = output_root / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    blend_path = preview_dir / "copper-row-commercial-block.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in CONFIG["preview"]["sizes"]:
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = preview_dir / f"copper-row-commercial-block-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    manifest = {
        "schema": "citysim.world-art.commercial-variety-preview.v1",
        "status": "source-only-review-evidence-not-live",
        "liveAsset": False,
        "approvedFamilyContractOnly": True,
        "cedarMarketReused": False,
        "camera": CONFIG["preview"]["camera"] | {"perAssetCompensation": "none"},
        "grid": CONFIG["grid"],
        "lightingConvention": CONFIG["lighting"],
        "layout": {"placementCenters": [[-4, 4], [4, 4], [-4, -4], [4, -4]], "roadAxes": "world-X-and-world-Y"},
        "placements": placements,
        "sourceFiles": [source_info(HERE / name) for name in ("build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py")],
        "artifacts": [artifact_info(blend_path, output_root), *[artifact_info(path, output_root) for path in outputs]],
    }
    manifest_path = preview_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return [blend_path, *outputs, manifest_path]


def write_family_manifest(asset_artifacts: list[Path], preview_artifacts: list[Path]) -> Path:
    approved = approved_sibling_sources()
    artifacts = [*asset_artifacts, *preview_artifacts]
    manifest = {
        "schema": "citysim.world-art.commercial-variety-family.v1",
        "status": "source-only-not-live",
        "assetIds": [asset["assetId"] for asset in CONFIG["assets"]],
        "assetCount": 2,
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "cedarMarketReused": False,
        "liveAsset": False,
        "approvedStyleBaseline": [
            {"assetId": asset_id, "sourceBlend": path.relative_to(BLENDER_ROOT).as_posix(), "sha256": sha256(path)}
            for asset_id, path in approved.items()
        ],
        "lockedContract": {key: CONFIG[key] for key in ("toolchain", "grid", "canvas", "cameraRig", "root", "lighting")},
        "postRenderCompensation": "none",
        "sourceFiles": [source_info(HERE / name) for name in ("build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py")],
        "artifacts": [artifact_info(path) for path in artifacts],
    }
    path = HERE / "family-manifest.json"
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


def main():
    actual = ".".join(map(str, bpy.app.version))
    if actual != CONFIG["toolchain"]["blenderVersion"]:
        raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    asset_artifacts = []
    for asset in CONFIG["assets"]:
        output_dir = HERE / asset["assetId"]
        output_dir.mkdir(parents=True, exist_ok=True)
        scene, _, cameras = build_asset(asset)
        blend_path = output_dir / f"{asset['assetId']}.blend"
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
        render_paths = baseline.render_views(scene, cameras, asset["assetId"], output_dir / "renders")
        sheet_path = baseline.contact_sheet(render_paths, output_dir / f"{asset['assetId']}_contact-sheet.png")
        manifest_path = write_asset_manifest(asset, [blend_path, *render_paths, sheet_path])
        asset_artifacts.extend([blend_path, *render_paths, sheet_path, manifest_path])
    preview_artifacts = build_preview(HERE)
    write_family_manifest(asset_artifacts, preview_artifacts)
    print("COMMERCIAL_VARIETY_RENDER_PASS assets=2 views=8 previews=2")


if __name__ == "__main__":
    main()
