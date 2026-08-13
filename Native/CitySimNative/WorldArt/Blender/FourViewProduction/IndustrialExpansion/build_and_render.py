#!/usr/bin/env python3
"""Build the original canonical CitySim Copperline machine shop."""

from __future__ import annotations

import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
PRODUCTION = HERE.parent
BLENDER_ROOT = PRODUCTION.parent
CANONICAL = BLENDER_ROOT / "FourViewPipeline"
SERVICES = PRODUCTION / "Services" / "build_and_render.py"
MAIN_STREET = PRODUCTION / "MainStreetCommerce" / "build_and_render.py"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))
from png_canonical import canonicalize_png  # noqa: E402


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


helpers = load_module("citysim_industrial_helpers", SERVICES)
street = load_module("citysim_industrial_street_helpers", MAIN_STREET)
CONFIG = json.loads((HERE / "pipeline.json").read_text())
VIEWS = CONFIG["cameraRig"]["views"]
helpers.HERE = HERE
helpers.CONFIG = CONFIG
helpers.VIEWS = VIEWS
street.HERE = HERE
street.CONFIG = CONFIG
street.VIEWS = VIEWS
street.BLENDER_ROOT = BLENDER_ROOT

material = helpers.material
box = helpers.box
cylinder = helpers.cylinder
sphere = helpers.sphere
gable_roof = helpers.gable_roof
reset = helpers.reset
configure_scene = helpers.configure_scene
canonical_rig = helpers.canonical_rig
render_views = helpers.render_views
contact_sheet = helpers.contact_sheet
artifact_info = helpers.artifact_info
sha256 = helpers.sha256
point_at = helpers.point_at
framed_window = street.framed_window


def asset_root(asset):
    root = bpy.data.objects.new("AssetRoot", None)
    bpy.context.collection.objects.link(root)
    pivot = bpy.data.objects.new("FootprintPivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.parent = root
    pivot.empty_display_type = "CIRCLE"
    pivot.empty_display_size = 0.2
    root["assetId"] = asset["assetId"]
    root["industrialRole"] = asset["industrialRole"]
    root["serviceRole"] = asset["serviceRole"]
    root["assetKind"] = "industrial-low"
    root["sourcePixelsReused"] = False
    root["cedarMarketReused"] = False
    root["rejectedVectorAssetsReused"] = False
    root["liveAsset"] = False
    root["fixedObjectScale"] = True
    root["postRenderCompensation"] = "none"
    return root


def machine_materials():
    return {
        "ground": material("MachineGround", (0.27, 0.32, 0.23, 1), texture_scale=8, bump=0.13),
        "walk": material("MachineWalk", (0.57, 0.52, 0.43, 1), texture_scale=14, bump=0.16),
        "brick": material("MachineWarmBrick", (0.46, 0.20, 0.12, 1), texture_scale=20, bump=0.22),
        "brickAccent": material("MachineBrickAccent", (0.65, 0.36, 0.19, 1), texture_scale=16, bump=0.18),
        "office": material("MachineOfficePlaster", (0.63, 0.55, 0.38, 1), texture_scale=10, bump=0.12),
        "stone": material("MachineStone", (0.55, 0.49, 0.40, 1), texture_scale=11, bump=0.14),
        "roof": material("MachineWeatheredRoof", (0.16, 0.22, 0.22, 1), roughness=0.62, metallic=0.24, texture_scale=22, bump=0.19),
        "metal": material("MachineDarkMetal", (0.16, 0.17, 0.16, 1), roughness=0.44, metallic=0.62, texture_scale=7),
        "copper": material("MachineCopper", (0.50, 0.27, 0.12, 1), roughness=0.42, metallic=0.52, texture_scale=7),
        "glass": material("MachineBlueGlass", (0.11, 0.31, 0.34, 1), roughness=0.24, texture_scale=0),
        "warmglass": material("MachineWarmGlass", (0.72, 0.43, 0.18, 1), roughness=0.25, texture_scale=0),
        "wood": material("MachineTimber", (0.32, 0.18, 0.09, 1), texture_scale=11, bump=0.16),
        "safety": material("MachineSafetyOchre", (0.80, 0.48, 0.10, 1), roughness=0.56, texture_scale=5),
        "leaf": material("MachineLeaf", (0.18, 0.32, 0.15, 1), texture_scale=6, bump=0.08),
    }


def build_machine_shop(root):
    mats = machine_materials()
    lot = box(root, "MachineLotGround", (0, 0, -0.10), (4, 4, 0.20), mats["ground"], edge=0.055)
    lot["worldFootprintTiles"] = [2, 2]
    lot["exactWorldFootprint"] = [4.0, 4.0]
    box(root, "MachineFrontSidewalk", (0, 1.55, 0.025), (3.82, 0.82, 0.08), mats["walk"], edge=0.025)
    box(root, "MachineServiceApron", (1.46, -0.22, 0.025), (0.78, 2.58, 0.08), mats["walk"], edge=0.02)
    box(root, "MachinePlinth", (-0.22, 0.04, 0.19), (3.36, 2.82, 0.30), mats["stone"], edge=0.035)
    box(root, "MachineHallBody", (-0.42, -0.08, 1.12), (2.74, 2.48, 1.62), mats["brick"], edge=0.045)
    box(root, "MachineHallBelt", (-0.42, 1.17, 1.60), (2.82, 0.13, 0.22), mats["brickAccent"], edge=0.012)
    box(root, "MachineHallRoof", (-0.42, -0.08, 2.00), (2.70, 2.42, 0.18), mats["roof"], edge=0.032)

    # Three axis-aligned clerestory monitors make the industrial silhouette readable in every view.
    for index, x in enumerate((-1.22, -0.42, 0.38)):
        box(root, f"MachineClerestory{index}Body", (x, -0.12, 2.22), (0.62, 1.58, 0.42), mats["brickAccent"], edge=0.022)
        gable_roof(root, f"MachineClerestory{index}Roof", (x, -0.12, 2.48), (0.76, 1.74, 0.34), mats["roof"], ridge_axis="Y")
        for side, y in (("Front", 0.69), ("Rear", -0.93)):
            framed_window(root, f"MachineClerestory{index}{side}Window", (x, y, 2.25), (0.38, 0.06, 0.20), mats)

    # Loading frontage and human-scale office share the canonical +Y road edge.
    for index, x in enumerate((-1.18, -0.28)):
        box(root, f"MachineLoadingDoor{index}", (x, 1.185, 0.95), (0.68, 0.07, 1.18), mats["metal"], edge=0.016)
        for slat in range(5):
            box(root, f"MachineLoadingDoor{index}Slat{slat}", (x, 1.145, 0.53 + slat * 0.22), (0.60, 0.025, 0.025), mats["safety"], edge=0.003)
    box(root, "MachineLoadingCanopy", (-0.73, 1.42, 1.62), (1.90, 0.48, 0.13), mats["copper"], edge=0.018)
    for index, x in enumerate((-1.47, 0.01)):
        cylinder(root, f"MachineCanopyPost{index}", (x, 1.55, 0.80), 0.045, 1.45, mats["metal"], vertices=12)

    box(root, "MachineOfficeBody", (1.08, 0.60, 0.84), (1.06, 1.30, 1.30), mats["office"], edge=0.035)
    box(root, "MachineOfficeRoof", (1.08, 0.60, 1.56), (1.20, 1.44, 0.18), mats["roof"], edge=0.025)
    framed_window(root, "MachineOfficeFrontWindow", (0.96, 1.265, 0.93), (0.56, 0.07, 0.60), mats, warm=True)
    framed_window(root, "MachineOfficeDoor", (1.40, 1.265, 0.80), (0.28, 0.07, 0.92), mats, warm=True, mullions=False)
    framed_window(root, "MachineOfficeSideWindow", (1.625, 0.54, 0.94), (0.07, 0.54, 0.52), mats, warm=True)
    box(root, "MachineOfficeSignBand", (1.08, 1.31, 1.42), (1.04, 0.12, 0.22), mats["copper"], edge=0.012)

    # Side windows, exhaust, and service fixtures keep all camera views authored.
    for index, y in enumerate((-0.80, -0.18, 0.44)):
        framed_window(root, f"MachineWestWindow{index}", (-1.82, y, 1.18), (0.07, 0.36, 0.46), mats)
    for index, x in enumerate((-1.05, -0.30, 0.45)):
        framed_window(root, f"MachineRearWindow{index}", (x, -1.33, 1.18), (0.44, 0.07, 0.46), mats)
    cylinder(root, "MachineExhaustStack", (0.62, -0.58, 2.42), 0.13, 0.92, mats["metal"], vertices=16)
    cylinder(root, "MachineExhaustCap", (0.62, -0.58, 2.90), 0.20, 0.10, mats["copper"], vertices=16)
    box(root, "MachineWallConduit", (1.64, -0.44, 1.12), (0.08, 0.10, 1.30), mats["copper"], edge=0.008)
    for index, z in enumerate((0.62, 1.02, 1.42)):
        box(root, f"MachineConduitClamp{index}", (1.66, -0.44, z), (0.12, 0.18, 0.05), mats["metal"], edge=0.005)

    # The material yard stays within the 4x4 lot and parallel to the shared axes.
    for index, y in enumerate((-1.54, -0.82, -0.10)):
        cylinder(root, f"MachineFencePost{index}", (1.76, y, 0.48), 0.035, 0.90, mats["metal"], vertices=10)
    for index, y in enumerate((-1.18, -0.46)):
        box(root, f"MachineFenceRail{index}Low", (1.76, y, 0.30), (0.05, 0.68, 0.05), mats["metal"], edge=0.005)
        box(root, f"MachineFenceRail{index}High", (1.76, y, 0.66), (0.05, 0.68, 0.05), mats["metal"], edge=0.005)
    for index, location in enumerate(((1.30, -1.38, 0.20), (1.30, -1.06, 0.20), (1.30, -1.22, 0.48))):
        box(root, f"MachineMaterialTimber{index}", location, (0.72, 0.20, 0.18), mats["wood"], edge=0.015)
    for index, x in enumerate((1.08, 1.34, 1.60)):
        cylinder(root, f"MachineMaterialPipe{index}", (x, -0.58, 0.22), 0.09, 0.74, mats["copper"], vertices=12)
    box(root, "MachineMaterialRack", (1.34, -0.58, 0.12), (0.92, 0.34, 0.10), mats["metal"], edge=0.012)

    box(root, "MachinePlanterBox", (1.42, 1.63, 0.17), (0.50, 0.30, 0.24), mats["wood"], edge=0.02)
    for index, x in enumerate((1.27, 1.42, 1.57)):
        sphere(root, f"MachinePlanterLeaf{index}", (x, 1.63, 0.43), (0.13, 0.12, 0.20), mats["leaf"], subdivisions=2)


def build_asset(asset):
    scene = reset("CitySimIndustrialExpansion_" + asset["assetId"])
    configure_scene(scene, transparent=True)
    root = asset_root(asset)
    build_machine_shop(root)
    cameras = canonical_rig(scene)
    return scene, root, cameras


def write_asset_manifest(asset, artifacts):
    output_dir = HERE / asset["assetId"]
    data = {
        "schema": "citysim.world-art.industrial-expansion-asset.v1",
        "pipelineSchema": CONFIG["schema"],
        "assetId": asset["assetId"],
        "industrialRole": asset["industrialRole"],
        "serviceRole": asset["serviceRole"],
        "description": asset["description"],
        "status": "source-only-not-live",
        "liveAsset": False,
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "cedarMarketReused": False,
        "rejectedVectorAssetsReused": False,
        "cameraOrder": [view["name"] for view in VIEWS],
        "grid": CONFIG["grid"],
        "canvas": CONFIG["canvas"],
        "cameraRig": CONFIG["cameraRig"],
        "lightingConvention": CONFIG["lighting"],
        "root": CONFIG["root"],
        "postRenderCompensation": "none",
        "perViewCompensation": {"rotationDegrees": 0.0, "skew": [0.0, 0.0], "crop": False, "offsetPixels": [0, 0], "scale": 1.0},
        "artifacts": [artifact_info(path, output_dir) for path in artifacts],
    }
    path = output_dir / "manifest.json"
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return path


def import_mesh_asset(source, name, location):
    with bpy.data.libraries.load(str(source), link=False) as (data_from, data_to):
        data_to.objects = list(data_from.objects)
    imported = [obj for obj in data_to.objects if obj is not None]
    for obj in imported:
        if not obj.users_collection:
            bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.update()
    matrices = {obj: obj.matrix_world.copy() for obj in imported if obj.type == "MESH"}
    placement = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(placement)
    placement.location = location
    count = 0
    for obj in imported:
        if obj.type == "MESH":
            obj.parent = placement
            obj.matrix_parent_inverse = Matrix.Identity(4)
            obj.matrix_basis = matrices[obj]
            count += 1
        else:
            bpy.data.objects.remove(obj, do_unlink=True)
    placement["perAssetTransformCompensation"] = "none"
    return count


def preview_camera_and_light(scene):
    distance = 42.0
    elevation = math.radians(30)
    azimuth = math.radians(45)
    horizontal = distance * math.cos(elevation)
    data = bpy.data.cameras.new("camNE_IndustrialExpansionPreview")
    data.type = "ORTHO"
    data.ortho_scale = 15.2
    camera = bpy.data.objects.new("camNE_IndustrialExpansionPreview", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation))
    point_at(camera, Vector((0, -1.6, 0.8)))
    lighting = CONFIG["lighting"]
    light_data = bpy.data.lights.new(lighting["name"], lighting["type"])
    light_data.energy = lighting["energy"]
    light_data.shape = "DISK"
    light_data.size = lighting["size"]
    light_data.color = lighting["color"]
    light = bpy.data.objects.new(lighting["name"], light_data)
    bpy.context.collection.objects.link(light)
    light.location = lighting["location"]
    point_at(light)
    scene.camera = camera


def build_preview():
    scene = reset("CitySimIndustrialExpansionPreview")
    configure_scene(scene, transparent=False)
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    ground = material("IndustrialPreviewGround", (0.27, 0.32, 0.23, 1), texture_scale=8, bump=0.13)
    asphalt = material("IndustrialPreviewAsphalt", (0.16, 0.18, 0.18, 1), texture_scale=20, bump=0.17)
    curb = material("IndustrialPreviewCurb", (0.58, 0.52, 0.43, 1), texture_scale=12, bump=0.14)
    stripe = material("IndustrialPreviewStripe", (0.78, 0.48, 0.12, 1), roughness=0.62, texture_scale=4)
    mass = material("IndustrialNeighborBrick", (0.39, 0.22, 0.15, 1), texture_scale=15, bump=0.18)
    roof = material("IndustrialNeighborRoof", (0.15, 0.20, 0.20, 1), texture_scale=19, bump=0.17)
    box(root, "IndustrialDistrictGround", (0, -1, -0.24), (18, 10, 0.24), ground, edge=0.10)
    box(root, "AxisAlignedIndustrialRoad", (0, 0, -0.07), (18, 2, 0.10), asphalt, edge=0.025)
    for y in (-1.08, 1.08):
        box(root, f"IndustrialRoadCurb{y}", (0, y, 0.005), (18, 0.16, 0.14), curb, edge=0.018)
    for x in (-7, -5, -3, -1, 1, 3, 5, 7):
        box(root, f"IndustrialRoadStripe{x}", (x, 0, -0.005), (0.90, 0.08, 0.035), stripe, edge=0.006)

    sources = [
        ("copperline_machine_shop", HERE / "copperline_machine_shop" / "copperline_machine_shop.blend", (-3.0, -3.0, 0.0)),
        ("ironleaf_service_workshop", PRODUCTION / "CommercialIndustrial" / "ironleaf_service_workshop" / "ironleaf_service_workshop.blend", (3.0, -3.0, 0.0)),
    ]
    placements = []
    for asset_id, source, location in sources:
        count = import_mesh_asset(source, "Placement_" + asset_id, location)
        placements.append({
            "assetId": asset_id,
            "originWorld": list(location),
            "footprintTiles": [2, 2],
            "sourceBlend": source.relative_to(BLENDER_ROOT).as_posix(),
            "sourceBlendSha256": sha256(source),
            "meshCount": count,
            "perAssetTransformCompensation": "none",
        })
    for index, x in enumerate((-6.5, 0.0, 6.5)):
        box(root, f"IndustrialNeighborPlinth{index}", (x, -5.6, 0.15), (3.4, 2.7, 0.26), curb, edge=0.035)
        box(root, f"IndustrialNeighborBody{index}", (x, -5.6, 1.05), (3.15, 2.45, 1.55), mass, edge=0.04)
        gable_roof(root, f"IndustrialNeighborRoof{index}", (x, -5.6, 1.82), (3.4, 2.7, 0.62), roof, ridge_axis="X")
    preview_camera_and_light(scene)
    output_dir = HERE / "preview"
    output_dir.mkdir(parents=True, exist_ok=True)
    blend_path = output_dir / "copperline-industrial-edge.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = output_dir / f"copperline-industrial-edge-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    manifest = {
        "schema": "citysim.world-art.industrial-expansion-preview.v1",
        "status": "source-only-review-evidence",
        "liveAsset": False,
        "acceptedFamilyContractOnly": True,
        "cedarMarketReused": False,
        "rejectedVectorAssetsReused": False,
        "camera": {"projection": "orthographic", "azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none"},
        "grid": CONFIG["grid"],
        "lightingConvention": CONFIG["lighting"],
        "placements": placements,
        "artifacts": [artifact_info(blend_path, HERE), *[artifact_info(path, HERE) for path in outputs]],
    }
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


def write_family_manifest(asset_manifest):
    data = {
        "schema": "citysim.world-art.industrial-expansion-family.v1",
        "pipelineSchema": CONFIG["schema"],
        "status": "source-only-not-live",
        "assetIds": ["copperline_machine_shop"],
        "cameraOrder": [view["name"] for view in VIEWS],
        "projectedTilePixels": [88, 44],
        "pivotPixelTopOrigin": [192, 300],
        "postRenderCompensation": "none",
        "cedarMarketReused": False,
        "artifacts": [artifact_info(asset_manifest, HERE)],
    }
    (HERE / "family-manifest.json").write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def main():
    actual = ".".join(map(str, bpy.app.version))
    if actual != CONFIG["toolchain"]["blenderVersion"]:
        raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    asset = CONFIG["assets"][0]
    output_dir = HERE / asset["assetId"]
    output_dir.mkdir(parents=True, exist_ok=True)
    scene, _, cameras = build_asset(asset)
    blend_path = output_dir / f"{asset['assetId']}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    renders = render_views(scene, cameras, asset["assetId"], output_dir / "renders")
    sheet = contact_sheet(renders, output_dir / f"{asset['assetId']}_contact-sheet.png")
    manifest = write_asset_manifest(asset, [blend_path, *renders, sheet])
    write_family_manifest(manifest)
    build_preview()
    print("INDUSTRIAL_EXPANSION_FOUR_VIEW_RENDER_PASS assets=1 views=4 previews=2")


if __name__ == "__main__":
    main()
