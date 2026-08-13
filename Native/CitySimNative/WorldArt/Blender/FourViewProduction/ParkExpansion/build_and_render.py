#!/usr/bin/env python3
"""Build the original canonical CitySim Canal Lantern park."""

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
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))
from png_canonical import canonicalize_png  # noqa: E402


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


helpers = load_module("citysim_park_helpers", SERVICES)
CONFIG = json.loads((HERE / "pipeline.json").read_text())
VIEWS = CONFIG["cameraRig"]["views"]
helpers.HERE = HERE
helpers.CONFIG = CONFIG
helpers.VIEWS = VIEWS

material = helpers.material
box = helpers.box
cylinder = helpers.cylinder
sphere = helpers.sphere
reset = helpers.reset
configure_scene = helpers.configure_scene
canonical_rig = helpers.canonical_rig
render_views = helpers.render_views
contact_sheet = helpers.contact_sheet
artifact_info = helpers.artifact_info
sha256 = helpers.sha256
point_at = helpers.point_at


def asset_root(asset):
    root = bpy.data.objects.new("AssetRoot", None)
    bpy.context.collection.objects.link(root)
    pivot = bpy.data.objects.new("FootprintPivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.parent = root
    pivot.empty_display_type = "CIRCLE"
    pivot.empty_display_size = 0.2
    root["assetId"] = asset["assetId"]
    root["parkRole"] = asset["parkRole"]
    root["serviceRole"] = asset["serviceRole"]
    root["assetKind"] = "park"
    root["sourcePixelsReused"] = False
    root["cedarMarketReused"] = False
    root["rejectedVectorAssetsReused"] = False
    root["liveAsset"] = False
    root["fixedObjectScale"] = True
    root["postRenderCompensation"] = "none"
    return root


def park_materials():
    return {
        "grass": material("ParkMeadowGrass", (0.27, 0.40, 0.22, 1), texture_scale=9, bump=0.14),
        "path": material("ParkWarmPath", (0.66, 0.56, 0.40, 1), texture_scale=13, bump=0.15),
        "brick": material("ParkPlanterBrick", (0.54, 0.25, 0.14, 1), texture_scale=18, bump=0.20),
        "stone": material("ParkBasinStone", (0.66, 0.60, 0.49, 1), texture_scale=11, bump=0.13),
        "water": material("ParkBasinWater", (0.16, 0.44, 0.48, 1), roughness=0.22, texture_scale=3, bump=0.04),
        "wood": material("ParkPergolaTimber", (0.38, 0.20, 0.10, 1), texture_scale=12, bump=0.17),
        "metal": material("ParkLanternMetal", (0.13, 0.15, 0.14, 1), roughness=0.42, metallic=0.58, texture_scale=6),
        "light": material("ParkLanternGlow", (0.90, 0.61, 0.22, 1), roughness=0.26, texture_scale=0),
        "soil": material("ParkPlantingSoil", (0.31, 0.21, 0.13, 1), texture_scale=8, bump=0.16),
        "trunk": material("ParkTreeBark", (0.30, 0.18, 0.10, 1), texture_scale=10, bump=0.17),
        "leaf": material("ParkDeepLeaf", (0.18, 0.35, 0.15, 1), texture_scale=7, bump=0.09),
        "leafLight": material("ParkSunlitLeaf", (0.37, 0.52, 0.21, 1), texture_scale=7, bump=0.08),
        "shrub": material("ParkSageShrub", (0.34, 0.43, 0.24, 1), texture_scale=6, bump=0.08),
        "flower": material("ParkTerracottaFlower", (0.78, 0.31, 0.15, 1), texture_scale=5, bump=0.05),
    }


def tree(root, stem, location, mats, size=1.0):
    x, y = location
    cylinder(root, stem + "Trunk", (x, y, 0.48 * size), 0.09 * size, 0.96 * size, mats["trunk"], vertices=12)
    sphere(root, stem + "CrownA", (x, y, 1.18 * size), (0.42 * size, 0.38 * size, 0.50 * size), mats["leaf"], subdivisions=2)
    sphere(root, stem + "CrownB", (x - 0.16 * size, y + 0.08 * size, 1.34 * size), (0.27 * size, 0.25 * size, 0.30 * size), mats["leafLight"], subdivisions=2)


def planter(root, index, location, dimensions, mats):
    x, y = location
    width, depth = dimensions
    box(root, f"ParkPlanter{index}Base", (x, y, 0.16), (width, depth, 0.28), mats["brick"], edge=0.025)
    box(root, f"ParkPlanter{index}Soil", (x, y, 0.315), (width - 0.16, depth - 0.16, 0.06), mats["soil"], edge=0.012)
    count = max(3, int(width / 0.30))
    for item in range(count):
        offset = (item - (count - 1) / 2) * min(0.30, (width - 0.28) / max(1, count - 1))
        sphere(root, f"ParkPlanter{index}Shrub{item}", (x + offset, y, 0.53), (0.14, 0.13, 0.20), mats["shrub"], subdivisions=2)
        if item % 2 == 0:
            sphere(root, f"ParkPlanter{index}Flower{item}", (x + offset, y - 0.03, 0.70), (0.055, 0.055, 0.07), mats["flower"], subdivisions=1)


def bench(root, index, location, along_x, mats):
    x, y = location
    seat_dims = (0.78, 0.22, 0.10) if along_x else (0.22, 0.78, 0.10)
    back_dims = (0.78, 0.08, 0.34) if along_x else (0.08, 0.78, 0.34)
    box(root, f"ParkBench{index}Seat", (x, y, 0.38), seat_dims, mats["wood"], edge=0.018)
    back_location = (x, y + 0.12, 0.58) if along_x else (x + 0.12, y, 0.58)
    box(root, f"ParkBench{index}Back", back_location, back_dims, mats["wood"], edge=0.015)
    for leg_index, offset in enumerate((-0.27, 0.27)):
        leg_location = (x + offset, y, 0.20) if along_x else (x, y + offset, 0.20)
        box(root, f"ParkBench{index}Leg{leg_index}", leg_location, (0.08, 0.10, 0.32), mats["metal"], edge=0.008)


def lantern(root, index, location, mats):
    x, y = location
    cylinder(root, f"ParkLantern{index}Pole", (x, y, 0.67), 0.032, 1.28, mats["metal"], vertices=12)
    box(root, f"ParkLantern{index}Glow", (x, y, 1.36), (0.18, 0.18, 0.22), mats["light"], edge=0.025)
    box(root, f"ParkLantern{index}Cap", (x, y, 1.50), (0.24, 0.24, 0.08), mats["metal"], edge=0.015)


def build_park(root):
    mats = park_materials()
    lot = box(root, "ParkLotGround", (0, 0, -0.05), (4, 4, 0.10), mats["grass"], edge=0.045)
    lot["worldFootprintTiles"] = [2, 2]
    lot["exactWorldFootprint"] = [4.0, 4.0]
    box(root, "ParkEastWestPath", (0, 1.48, 0.025), (4, 0.54, 0.06), mats["path"], edge=0.018)
    box(root, "ParkNorthSouthPath", (1.46, 0, 0.028), (0.56, 4, 0.06), mats["path"], edge=0.018)
    box(root, "ParkBasinPlaza", (-0.48, 0.02, 0.025), (1.70, 2.66, 0.06), mats["path"], edge=0.025)
    box(root, "ParkBasinCoping", (-0.48, 0.02, 0.16), (1.28, 2.24, 0.26), mats["stone"], edge=0.055)
    box(root, "ParkBasinWater", (-0.48, 0.02, 0.30), (1.02, 1.98, 0.05), mats["water"], edge=0.05)
    for index, y in enumerate((-0.66, 0.02, 0.70)):
        cylinder(root, f"ParkBasinReed{index}Stem", (-0.83, y, 0.53), 0.025, 0.48, mats["shrub"], vertices=8)
        sphere(root, f"ParkBasinReed{index}Head", (-0.83, y, 0.78), (0.055, 0.055, 0.12), mats["flower"], subdivisions=1)
    for index, (x, y) in enumerate(((-0.30, -0.64), (-0.62, -0.18), (-0.30, 0.28), (-0.64, 0.70))):
        cylinder(root, f"ParkBasinLilyPad{index}", (x, y, 0.34), 0.10, 0.025, mats["leaf"], vertices=12)
    for index, (x, y) in enumerate(((-0.94, 1.12), (0.02, 1.12), (-0.94, -1.12), (0.02, -1.12))):
        cylinder(root, f"ParkPathBollard{index}Post", (x, y, 0.25), 0.045, 0.44, mats["metal"], vertices=10)
        box(root, f"ParkPathBollard{index}Light", (x, y, 0.50), (0.14, 0.14, 0.12), mats["light"], edge=0.018)

    # Axis-aligned pergola frames the east promenade without any object rotation.
    for index, (x, y) in enumerate(((0.72, -0.82), (1.62, -0.82), (0.72, 0.52), (1.62, 0.52))):
        box(root, f"ParkPergolaPost{index}", (x, y, 0.86), (0.12, 0.12, 1.64), mats["wood"], edge=0.014)
    for index, y in enumerate((-0.82, 0.52)):
        box(root, f"ParkPergolaLongBeam{index}", (1.17, y, 1.70), (1.12, 0.16, 0.18), mats["wood"], edge=0.018)
    for index, x in enumerate((0.72, 0.95, 1.18, 1.41, 1.62)):
        box(root, f"ParkPergolaRoofSlat{index}", (x, -0.15, 1.84), (0.10, 1.58, 0.12), mats["wood"], edge=0.012)
    for index, y in enumerate((-0.60, -0.22, 0.16, 0.42)):
        sphere(root, f"ParkPergolaVine{index}", (0.76, y, 1.48), (0.16, 0.20, 0.22), mats["leaf"], subdivisions=2)

    planter(root, 0, (-1.30, 1.48), (1.02, 0.38), mats)
    planter(root, 1, (-1.30, -1.48), (1.02, 0.38), mats)
    planter(root, 2, (0.42, -1.48), (1.26, 0.38), mats)
    bench(root, 0, (-0.48, 1.50), True, mats)
    bench(root, 1, (1.48, 0.92), False, mats)
    bench(root, 2, (1.48, -1.10), False, mats)
    lantern(root, 0, (-1.72, 1.68), mats)
    lantern(root, 1, (1.70, 1.68), mats)
    lantern(root, 2, (-1.72, -1.68), mats)
    tree(root, "ParkTree0", (-1.42, 0.72), mats, size=0.94)
    tree(root, "ParkTree1", (-1.42, -0.76), mats, size=0.82)
    tree(root, "ParkTree2", (0.48, 0.92), mats, size=0.72)


def build_asset(asset):
    scene = reset("CitySimParkExpansion_" + asset["assetId"])
    configure_scene(scene, transparent=True)
    root = asset_root(asset)
    build_park(root)
    cameras = canonical_rig(scene)
    return scene, root, cameras


def write_asset_manifest(asset, artifacts):
    output_dir = HERE / asset["assetId"]
    data = {
        "schema": "citysim.world-art.park-expansion-asset.v1",
        "pipelineSchema": CONFIG["schema"],
        "assetId": asset["assetId"],
        "parkRole": asset["parkRole"],
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
    data = bpy.data.cameras.new("camNE_ParkExpansionPreview")
    data.type = "ORTHO"
    data.ortho_scale = 15.2
    camera = bpy.data.objects.new("camNE_ParkExpansionPreview", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation))
    point_at(camera, Vector((0, -1.6, 0.7)))
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
    scene = reset("CitySimParkExpansionPreview")
    configure_scene(scene, transparent=False)
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    ground = material("ParkPreviewGround", (0.27, 0.37, 0.22, 1), texture_scale=8, bump=0.13)
    asphalt = material("ParkPreviewRoad", (0.17, 0.19, 0.18, 1), texture_scale=20, bump=0.16)
    curb = material("ParkPreviewCurb", (0.66, 0.58, 0.46, 1), texture_scale=12, bump=0.13)
    stripe = material("ParkPreviewStripe", (0.82, 0.56, 0.17, 1), roughness=0.62, texture_scale=4)
    box(root, "ParkPreviewDistrictGround", (0, -1, -0.24), (18, 10, 0.24), ground, edge=0.10)
    box(root, "ParkPreviewAxisRoad", (0, 0, -0.07), (18, 2, 0.10), asphalt, edge=0.025)
    for y in (-1.08, 1.08):
        box(root, f"ParkPreviewCurb{y}", (0, y, 0.005), (18, 0.16, 0.14), curb, edge=0.018)
    for x in (-7, -5, -3, -1, 1, 3, 5, 7):
        box(root, f"ParkPreviewStripe{x}", (x, 0, -0.005), (0.90, 0.08, 0.035), stripe, edge=0.006)
    sources = [
        ("canal_lantern_park", HERE / "canal_lantern_park" / "canal_lantern_park.blend", (-3.0, -3.0, 0.0)),
        ("pocket_grove_park", PRODUCTION / "Environment" / "assets" / "pocket_grove_park" / "pocket_grove_park.blend", (3.0, -3.0, 0.0)),
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
    preview_camera_and_light(scene)
    output_dir = HERE / "preview"
    output_dir.mkdir(parents=True, exist_ok=True)
    blend_path = output_dir / "canal-lantern-green-corridor.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = output_dir / f"canal-lantern-green-corridor-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    manifest = {
        "schema": "citysim.world-art.park-expansion-preview.v1",
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
        "schema": "citysim.world-art.park-expansion-family.v1",
        "pipelineSchema": CONFIG["schema"],
        "status": "source-only-not-live",
        "assetIds": ["canal_lantern_park"],
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
    print("PARK_EXPANSION_FOUR_VIEW_RENDER_PASS assets=1 views=4 previews=2")


if __name__ == "__main__":
    main()
