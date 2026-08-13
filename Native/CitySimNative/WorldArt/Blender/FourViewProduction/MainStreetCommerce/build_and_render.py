#!/usr/bin/env python3
"""Build two original CitySim Four-View Main Street shops."""

from __future__ import annotations

import hashlib
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
from png_canonical import canonicalize_png, decode_rgba_png  # noqa: E402

spec = importlib.util.spec_from_file_location("citysim_service_helpers", SERVICES)
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)

CONFIG = json.loads((HERE / "pipeline.json").read_text())
VIEWS = CONFIG["cameraRig"]["views"]
helpers.HERE = HERE
helpers.CONFIG = CONFIG
helpers.VIEWS = VIEWS

material = helpers.material
box = helpers.box
cylinder = helpers.cylinder
sphere = helpers.sphere
gable_roof = helpers.gable_roof
beam = helpers.beam
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
    root["commerceRole"] = asset["commerceRole"]
    # Compatibility field lets the reusable structural validator inspect role identity.
    root["serviceRole"] = asset["commerceRole"]
    root["sourcePixelsReused"] = False
    root["cedarMarketReused"] = False
    root["rejectedVectorAssetsReused"] = False
    root["liveAsset"] = False
    root["fixedObjectScale"] = True
    root["postRenderCompensation"] = "none"
    return root


def materials(prefix, wall_color, accent_color):
    return {
        "ground": material(prefix + "Ground", (0.29, 0.38, 0.22, 1), texture_scale=7, bump=0.11),
        "walk": material(prefix + "Walk", (0.66, 0.58, 0.46, 1), texture_scale=12, bump=0.13),
        "brick": material(prefix + "Brick", wall_color, texture_scale=17, bump=0.19),
        "stucco": material(prefix + "Stucco", (0.82, 0.67, 0.45, 1), texture_scale=9, bump=0.12),
        "accent": material(prefix + "Accent", accent_color, roughness=0.54, texture_scale=8, bump=0.10),
        "stone": material(prefix + "Stone", (0.76, 0.67, 0.54, 1), texture_scale=10, bump=0.12),
        "roof": material(prefix + "Roof", (0.13, 0.21, 0.22, 1), roughness=0.55, texture_scale=19, bump=0.17),
        "glass": material(prefix + "Glass", (0.12, 0.38, 0.42, 1), roughness=0.22, texture_scale=0),
        "warmglass": material(prefix + "WarmGlass", (0.72, 0.43, 0.17, 1), roughness=0.27, texture_scale=0),
        "metal": material(prefix + "Metal", (0.16, 0.18, 0.17, 1), roughness=0.40, metallic=0.58, texture_scale=6),
        "wood": material(prefix + "Wood", (0.39, 0.20, 0.10, 1), texture_scale=10, bump=0.15),
        "leaf": material(prefix + "Leaf", (0.18, 0.35, 0.15, 1), texture_scale=6, bump=0.08),
        "flower": material(prefix + "Flower", (0.86, 0.48, 0.10, 1), texture_scale=4, bump=0.05),
        "cream": material(prefix + "Cream", (0.91, 0.78, 0.56, 1), texture_scale=6, bump=0.08),
    }


def shared_lot(root, prefix, mats):
    lot = box(root, prefix + "LotGround", (0, 0, -0.10), (4, 4, 0.20), mats["ground"], edge=0.055)
    lot["worldFootprintTiles"] = [2, 2]
    lot["exactWorldFootprint"] = [4.0, 4.0]
    box(root, prefix + "FrontSidewalk", (0, -1.55, 0.025), (3.82, 0.82, 0.08), mats["walk"], edge=0.025)
    box(root, prefix + "ServiceWalk", (1.62, 0.25, 0.025), (0.52, 2.72, 0.08), mats["walk"], edge=0.02)


def expose_frontage_to_cam_ne(root):
    """Author both shops toward the canonical camNE-visible +Y edge."""
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj.parent == root:
            obj.location.y = -obj.location.y


def framed_window(root, name, location, dimensions, mats, warm=False, mullions=True):
    glass = mats["warmglass"] if warm else mats["glass"]
    box(root, name, location, dimensions, glass, edge=0.012)
    x, y, z = location
    w, d, h = dimensions
    frame = mats["metal"]
    if d < w:
        for index, dx in enumerate((-w / 2, w / 2)):
            box(root, f"{name}FrameV{index}", (x + dx, y - 0.01, z), (0.055, d + 0.025, h + 0.10), frame, edge=0.006)
        for index, dz in enumerate((-h / 2, h / 2)):
            box(root, f"{name}FrameH{index}", (x, y - 0.01, z + dz), (w + 0.10, d + 0.025, 0.055), frame, edge=0.006)
        if mullions:
            box(root, name + "Mullion", (x, y - 0.018, z), (0.04, d + 0.035, h), frame, edge=0.004)
    else:
        for index, dy in enumerate((-d / 2, d / 2)):
            box(root, f"{name}FrameV{index}", (x, y + dy, z), (w + 0.025, 0.055, h + 0.10), frame, edge=0.006)
        for index, dz in enumerate((-h / 2, h / 2)):
            box(root, f"{name}FrameH{index}", (x, y, z + dz), (w + 0.025, d + 0.10, 0.055), frame, edge=0.006)


def planter(root, name, location, mats, flowers=False):
    x, y, _ = location
    box(root, name + "Box", (x, y, 0.18), (0.52, 0.34, 0.26), mats["wood"], edge=0.025)
    for index, dx in enumerate((-0.16, 0, 0.16)):
        sphere(root, f"{name}Leaf{index}", (x + dx, y, 0.46), (0.16, 0.14, 0.22), mats["leaf"], subdivisions=2)
        if flowers:
            sphere(root, f"{name}Flower{index}", (x + dx, y - 0.02, 0.64), (0.07, 0.07, 0.07), mats["flower"], subdivisions=2)


def lantern_row_bakery(root):
    mats = materials("Lantern", (0.55, 0.25, 0.16, 1), (0.18, 0.42, 0.34, 1))
    shared_lot(root, "Bakery", mats)
    box(root, "BakeryPlinth", (-0.12, 0.16, 0.20), (3.25, 2.72, 0.28), mats["stone"], edge=0.035)
    box(root, "BakeryShopBody", (-0.18, 0.20, 1.10), (3.05, 2.52, 1.62), mats["brick"], edge=0.04)
    box(root, "BakeryStuccoUpper", (-0.18, 0.22, 1.86), (3.10, 2.56, 0.52), mats["stucco"], edge=0.03)
    gable_roof(root, "BakeryRoof", (-0.18, 0.22, 2.14), (3.38, 2.84, 0.72), mats["roof"], ridge_axis="X")
    box(root, "BakeryCornice", (-0.18, -1.095, 1.66), (3.22, 0.12, 0.16), mats["cream"], edge=0.015)
    for index, x in enumerate((-1.05, -0.27, 0.51)):
        framed_window(root, f"BakeryShopWindow{index}", (x, -1.075, 0.92), (0.58, 0.07, 0.78), mats, warm=True)
    framed_window(root, "BakeryEntryDoor", (1.10, -1.075, 0.86), (0.48, 0.07, 1.12), mats, warm=True)
    # A striped, dimensional awning faces the canonical frontage.
    for index, x in enumerate((-1.22, -0.89, -0.56, -0.23, 0.10, 0.43, 0.76)):
        awning_mat = mats["accent"] if index % 2 == 0 else mats["cream"]
        box(root, f"BakeryAwningStripe{index}", (x, -1.32, 1.40), (0.31, 0.54, 0.11), awning_mat, edge=0.018)
    for side, x in (("West", -1.73), ("East", 1.37)):
        for index, y in enumerate((-0.48, 0.32, 0.96)):
            framed_window(root, f"Bakery{side}Window{index}", (x, y, 1.18), (0.07, 0.42, 0.56), mats)
    for index, x in enumerate((-0.98, -0.18, 0.62)):
        framed_window(root, f"BakeryRearWindow{index}", (x, 1.485, 1.22), (0.48, 0.07, 0.58), mats)
    box(root, "BakeryServiceDoor", (1.375, 0.72, 0.78), (0.07, 0.58, 1.02), mats["accent"], edge=0.018)
    box(root, "BakeryServiceCrate0", (1.60, 1.16, 0.24), (0.42, 0.42, 0.42), mats["wood"], edge=0.018)
    box(root, "BakeryServiceCrate1", (1.58, 1.18, 0.61), (0.34, 0.34, 0.30), mats["wood"], edge=0.018)
    cylinder(root, "BakeryChimney", (-0.92, 0.64, 2.72), 0.20, 0.92, mats["brick"], vertices=20)
    box(root, "BakeryChimneyCap", (-0.92, 0.64, 3.18), (0.50, 0.50, 0.14), mats["stone"], edge=0.018)
    cylinder(root, "BakeryLanternPost", (1.54, -1.45, 0.74), 0.045, 1.20, mats["metal"], vertices=12)
    box(root, "BakeryLantern", (1.54, -1.45, 1.36), (0.26, 0.26, 0.34), mats["warmglass"], edge=0.025)
    gable_roof(root, "BakeryLanternRoof", (1.54, -1.45, 1.55), (0.36, 0.36, 0.18), mats["metal"], ridge_axis="X")
    planter(root, "BakeryPlanter0", (-1.46, -1.54, 0), mats, flowers=True)
    planter(root, "BakeryPlanter1", (0.82, -1.54, 0), mats, flowers=True)
    root["assetKind"] = "commercial-low"


def ironwood_hardware_shop(root):
    mats = materials("Hardware", (0.35, 0.42, 0.36, 1), (0.69, 0.30, 0.12, 1))
    shared_lot(root, "Hardware", mats)
    box(root, "HardwarePlinth", (-0.12, 0.16, 0.20), (3.34, 2.76, 0.28), mats["stone"], edge=0.035)
    box(root, "HardwareShopBody", (-0.15, 0.20, 1.10), (3.16, 2.58, 1.68), mats["brick"], edge=0.04)
    box(root, "HardwareParapet", (-0.15, 0.20, 2.02), (3.34, 2.76, 0.36), mats["accent"], edge=0.03)
    box(root, "HardwareSignBand", (-0.15, -1.205, 1.77), (2.96, 0.14, 0.38), mats["cream"], edge=0.02)
    box(root, "HardwareRoof", (-0.15, 0.20, 2.24), (3.10, 2.52, 0.20), mats["roof"], edge=0.035)
    for index, x in enumerate((-1.02, -0.28, 0.46)):
        framed_window(root, f"HardwareDisplayWindow{index}", (x, -1.115, 0.94), (0.58, 0.07, 0.86), mats, warm=True)
    framed_window(root, "HardwareEntryDoor", (1.13, -1.115, 0.86), (0.46, 0.07, 1.12), mats, warm=False)
    for side, x in (("West", -1.76), ("East", 1.46)):
        for index, y in enumerate((-0.54, 0.20, 0.94)):
            framed_window(root, f"Hardware{side}Window{index}", (x, y, 1.18), (0.07, 0.38, 0.50), mats)
    for index, x in enumerate((-0.92, -0.18, 0.56)):
        framed_window(root, f"HardwareRearWindow{index}", (x, 1.525, 1.16), (0.44, 0.07, 0.48), mats)
    box(root, "HardwareServiceDoor", (1.465, 0.62, 0.82), (0.07, 0.62, 1.08), mats["accent"], edge=0.018)
    box(root, "HardwareServiceCanopy", (1.66, 0.62, 1.47), (0.46, 0.92, 0.12), mats["metal"], edge=0.015)
    for index, location in enumerate(((1.62, 1.25, 0.25), (1.60, 0.90, 0.25), (1.58, 1.22, 0.66))):
        box(root, f"HardwareCrate{index}", location, (0.40, 0.34, 0.40), mats["wood"], edge=0.018)
    box(root, "HardwareRoofMonitor", (-0.58, 0.30, 2.49), (1.02, 0.82, 0.44), mats["stone"], edge=0.025)
    gable_roof(root, "HardwareRoofMonitorCap", (-0.58, 0.30, 2.72), (1.18, 0.98, 0.30), mats["roof"], ridge_axis="X")
    for index, y in enumerate((0.04, 0.34, 0.64)):
        box(root, f"HardwareMonitorLouver{index}", (-1.105, y, 2.50), (0.06, 0.19, 0.18), mats["metal"], edge=0.006)
    cylinder(root, "HardwareVent", (0.72, 0.58, 2.58), 0.13, 0.64, mats["metal"], vertices=16)
    cylinder(root, "HardwareVentCap", (0.72, 0.58, 2.91), 0.20, 0.08, mats["metal"], vertices=16)
    for index, x in enumerate((-1.12, -0.76, -0.40, -0.04, 0.32, 0.68)):
        box(root, f"HardwareCanopySlat{index}", (x, -1.34, 1.47), (0.31, 0.48, 0.10), mats["accent"], edge=0.015)
    planter(root, "HardwarePlanter0", (-1.50, -1.54, 0), mats)
    planter(root, "HardwarePlanter1", (0.88, -1.54, 0), mats)
    root["assetKind"] = "commercial-low"


BUILDERS = {
    "lantern_row_bakery": lantern_row_bakery,
    "ironwood_hardware_shop": ironwood_hardware_shop,
}


def build_asset(asset):
    scene = reset("CitySimMainStreet_" + asset["assetId"])
    configure_scene(scene, transparent=True)
    root = asset_root(asset)
    BUILDERS[asset["assetId"]](root)
    expose_frontage_to_cam_ne(root)
    cameras = canonical_rig(scene)
    return scene, root, cameras


def write_asset_manifest(asset, artifacts):
    output_dir = HERE / asset["assetId"]
    data = {
        "schema": "citysim.world-art.main-street-commerce-asset.v1",
        "pipelineSchema": CONFIG["schema"],
        "assetId": asset["assetId"],
        "commerceRole": asset["commerceRole"],
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


def append_mesh_asset(source, name, location):
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
    data = bpy.data.cameras.new("camNE_MainStreetPreview")
    data.type = "ORTHO"
    data.ortho_scale = 15.2
    camera = bpy.data.objects.new("camNE_MainStreetPreview", data)
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
    scene = reset("CitySimMainStreetCommercePreview")
    configure_scene(scene, transparent=False)
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    ground = material("MainStreetGround", (0.29, 0.37, 0.22, 1), texture_scale=7, bump=0.11)
    asphalt = material("MainStreetAsphalt", (0.17, 0.19, 0.19, 1), texture_scale=20, bump=0.16)
    curb = material("MainStreetCurb", (0.67, 0.59, 0.47, 1), texture_scale=11, bump=0.12)
    stripe = material("MainStreetStripe", (0.82, 0.57, 0.18, 1), roughness=0.62, texture_scale=4)
    mass = material("NeighborMassing", (0.43, 0.32, 0.24, 1), texture_scale=12, bump=0.12)
    roof = material("NeighborRoof", (0.14, 0.21, 0.21, 1), texture_scale=18, bump=0.15)
    box(root, "DistrictGround", (0, -1, -0.24), (18, 10, 0.24), ground, edge=0.1)
    box(root, "AxisAlignedMainStreet", (0, 0, -0.07), (18, 2, 0.10), asphalt, edge=0.025)
    for y in (-1.08, 1.08):
        box(root, f"MainStreetCurb{y}", (0, y, 0.005), (18, 0.16, 0.14), curb, edge=0.018)
    for x in (-7, -5, -3, -1, 1, 3, 5, 7):
        box(root, f"MainStreetStripe{x}", (x, 0, -0.005), (0.9, 0.08, 0.035), stripe, edge=0.006)
    placements = []
    for asset, location in zip(CONFIG["assets"], [(-3.0, -3.0, 0.0), (3.0, -3.0, 0.0)]):
        source = HERE / asset["assetId"] / f"{asset['assetId']}.blend"
        count = append_mesh_asset(source, "Placement_" + asset["assetId"], location)
        placements.append({
            "assetId": asset["assetId"], "commerceRole": asset["commerceRole"],
            "originWorld": list(location), "footprintTiles": [2, 2],
            "sourceBlend": source.relative_to(BLENDER_ROOT).as_posix(),
            "sourceBlendSha256": sha256(source), "meshCount": count,
            "perAssetTransformCompensation": "none",
        })
    # Neutral massing provides one neighborhood rather than an isolated asset sheet.
    for index, x in enumerate((-6.5, 0.0, 6.5)):
        box(root, f"NeighborPlinth{index}", (x, -5.6, 0.15), (3.4, 2.7, 0.26), curb, edge=0.035)
        box(root, f"NeighborBody{index}", (x, -5.6, 1.05), (3.15, 2.45, 1.55), mass, edge=0.04)
        gable_roof(root, f"NeighborRoof{index}", (x, -5.6, 1.82), (3.4, 2.7, 0.62), roof, ridge_axis="X")
    preview_camera_and_light(scene)
    output_dir = HERE / "preview"
    output_dir.mkdir(parents=True, exist_ok=True)
    blend_path = output_dir / "lantern-ironwood-main-street.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = output_dir / f"lantern-ironwood-main-street-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    manifest = {
        "schema": "citysim.world-art.main-street-commerce-preview.v1",
        "status": "source-only-review-evidence", "liveAsset": False,
        "acceptedFamilyContractOnly": True, "cedarMarketReused": False,
        "rejectedVectorAssetsReused": False,
        "camera": {"projection": "orthographic", "azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none"},
        "grid": CONFIG["grid"], "lightingConvention": CONFIG["lighting"],
        "placements": placements,
        "artifacts": [artifact_info(blend_path, HERE), *[artifact_info(path, HERE) for path in outputs]],
    }
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


def write_family_manifest(asset_manifests):
    data = {
        "schema": "citysim.world-art.main-street-commerce-family.v1",
        "pipelineSchema": CONFIG["schema"], "status": "source-only-not-live",
        "assetIds": [asset["assetId"] for asset in CONFIG["assets"]],
        "cameraOrder": [view["name"] for view in VIEWS],
        "projectedTilePixels": [88, 44], "pivotPixelTopOrigin": [192, 300],
        "postRenderCompensation": "none", "cedarMarketReused": False,
        "artifacts": [artifact_info(path, HERE) for path in asset_manifests],
    }
    (HERE / "family-manifest.json").write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def main():
    actual = ".".join(map(str, bpy.app.version))
    if actual != CONFIG["toolchain"]["blenderVersion"]:
        raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    manifests = []
    for asset in CONFIG["assets"]:
        output_dir = HERE / asset["assetId"]
        output_dir.mkdir(parents=True, exist_ok=True)
        scene, _, cameras = build_asset(asset)
        blend_path = output_dir / f"{asset['assetId']}.blend"
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
        renders = render_views(scene, cameras, asset["assetId"], output_dir / "renders")
        sheet = contact_sheet(renders, output_dir / f"{asset['assetId']}_contact-sheet.png")
        manifests.append(write_asset_manifest(asset, [blend_path, *renders, sheet]))
    write_family_manifest(manifests)
    build_preview()
    print("MAIN_STREET_COMMERCE_FOUR_VIEW_RENDER_PASS assets=2 views=8 previews=2")


if __name__ == "__main__":
    main()
