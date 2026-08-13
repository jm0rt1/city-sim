#!/usr/bin/env python3
"""Build and render CitySim's deterministic four-view Blender reference asset."""

from __future__ import annotations

import hashlib
import json
import math
import sys
from array import array
from pathlib import Path

import bpy
from mathutils import Vector


PIPELINE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = PIPELINE_DIR / "pipeline.json"
EXAMPLE_DIR = PIPELINE_DIR / "example"
RENDER_DIR = EXAMPLE_DIR / "renders"
sys.dont_write_bytecode = True
sys.path.insert(0, str(PIPELINE_DIR))

from png_canonical import canonicalize_png, decode_rgba_png  # noqa: E402


def read_config() -> dict:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def require_toolchain(config: dict) -> None:
    expected = config["toolchain"]["blenderVersion"]
    actual = ".".join(str(value) for value in bpy.app.version)
    if actual != expected:
        raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual} != {expected}")


def reset_scene() -> bpy.types.Scene:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for block in list(collection):
            collection.remove(block)
    scene = bpy.context.scene
    scene.name = "CitySimFourView"
    return scene


def make_material(name: str, rgba: tuple[float, float, float, float], roughness: float = 0.72) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = rgba
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = rgba
    principled.inputs["Roughness"].default_value = roughness
    lowered = name.lower()
    if not any(token in lowered for token in ("glass", "clockface")):
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        coordinates = nodes.new("ShaderNodeTexCoord")
        noise = nodes.new("ShaderNodeTexNoise")
        ramp = nodes.new("ShaderNodeValToRGB")
        bump_node = nodes.new("ShaderNodeBump")
        scale = 18.0 if "roof" in lowered else 10.0 if "brick" in lowered else 6.0
        noise.inputs["Scale"].default_value = scale
        noise.inputs["Detail"].default_value = 3.0
        noise.inputs["Roughness"].default_value = 0.62
        low = tuple(max(0.0, channel * 0.76) for channel in rgba[:3]) + (rgba[3],)
        high = tuple(min(1.0, channel * 1.12 + 0.018) for channel in rgba[:3]) + (rgba[3],)
        ramp.color_ramp.elements[0].position = 0.28
        ramp.color_ramp.elements[0].color = low
        ramp.color_ramp.elements[1].position = 0.74
        ramp.color_ramp.elements[1].color = high
        bump_node.inputs["Strength"].default_value = 0.20 if "roof" in lowered else 0.11
        bump_node.inputs["Distance"].default_value = 0.045
        links.new(coordinates.outputs["Generated"], noise.inputs["Vector"])
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], principled.inputs["Base Color"])
        links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], principled.inputs["Normal"])
    return material


def apply_mesh_transform(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def bevel(obj: bpy.types.Object, width: float = 0.045, segments: int = 2) -> None:
    modifier = obj.modifiers.new(name="EdgeSoftening", type="BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def parent_to(obj: bpy.types.Object, root: bpy.types.Object) -> bpy.types.Object:
    obj.parent = root
    return obj


def add_box(
    root: bpy.types.Object,
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    material: bpy.types.Material,
    *,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    edge: float = 0.035,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    apply_mesh_transform(obj)
    if edge > 0:
        bevel(obj, edge)
    obj.data.materials.append(material)
    return parent_to(obj, root)


def add_uv_sphere(
    root: bpy.types.Object,
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    apply_mesh_transform(obj)
    obj.data.materials.append(material)
    return parent_to(obj, root)


def add_gable_prism(
    root: bpy.types.Object,
    name: str,
    location: tuple[float, float, float],
    width: float,
    depth: float,
    eave_height: float,
    ridge_height: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    x = width / 2.0
    y = depth / 2.0
    vertices = [
        (-x, -y, 0.0), (x, -y, 0.0), (-x, y, 0.0), (x, y, 0.0),
        (-x, -y, eave_height), (x, -y, eave_height),
        (-x, y, eave_height), (x, y, eave_height),
        (0.0, -y, ridge_height), (0.0, y, ridge_height),
    ]
    faces = [
        (0, 1, 3, 2), (0, 4, 5, 1), (2, 3, 7, 6),
        (0, 2, 6, 4), (1, 5, 7, 3),
        (4, 8, 5), (6, 7, 9), (4, 6, 9, 8), (8, 9, 7, 5),
    ]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    bevel(obj, 0.025, 1)
    obj.data.materials.append(material)
    return parent_to(obj, root)


def add_roof_seams(
    root: bpy.types.Object,
    prefix: str,
    location: tuple[float, float, float],
    width: float,
    depth: float,
    eave_height: float,
    ridge_height: float,
    material: bpy.types.Material,
) -> None:
    """Add modeled standing seams and a ridge cap without changing roof massing."""
    slope_angle = math.atan2(ridge_height - eave_height, width / 2.0)
    for index, fraction in enumerate((-0.72, -0.42, 0.42, 0.72), start=1):
        x = fraction * width / 2.0
        z = location[2] + eave_height + (ridge_height - eave_height) * (1.0 - abs(fraction)) + 0.035
        add_box(
            root,
            f"{prefix}Seam_{index:02d}",
            (location[0] + x, location[1], z),
            (0.045, depth + 0.08, 0.045),
            material,
            rotation=(0.0, slope_angle if x > 0 else -slope_angle, 0.0),
            edge=0.008,
        )
    add_box(
        root,
        f"{prefix}RidgeCap",
        (location[0], location[1], location[2] + ridge_height + 0.045),
        (0.16, depth + 0.12, 0.13),
        material,
        edge=0.018,
    )


def add_window(
    root: bpy.types.Object,
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    glass_material: bpy.types.Material,
    trim_material: bpy.types.Material,
) -> None:
    frame = add_box(root, f"{name}_Frame", location, dimensions, trim_material, edge=0.018)
    frame["reusablePart"] = "window"
    inset = tuple(max(0.025, value - 0.12) for value in dimensions)
    add_box(root, f"{name}_Glass", location, inset, glass_material, edge=0.008)
    if dimensions[1] < dimensions[0]:
        add_box(root, f"{name}_VerticalMuntin", location, (0.045, dimensions[1] + .025, max(.10, dimensions[2] - .08)), trim_material, edge=.006)
        add_box(root, f"{name}_HorizontalMuntin", location, (max(.10, dimensions[0] - .08), dimensions[1] + .025, .045), trim_material, edge=.006)
        add_box(root, f"{name}_Sill", (location[0], location[1], location[2] - dimensions[2] / 2 - .045), (dimensions[0] + .14, dimensions[1] + .08, .09), trim_material, edge=.012)
    else:
        add_box(root, f"{name}_VerticalMuntin", location, (dimensions[0] + .025, .045, max(.10, dimensions[2] - .08)), trim_material, edge=.006)
        add_box(root, f"{name}_HorizontalMuntin", location, (dimensions[0] + .025, max(.10, dimensions[1] - .08), .045), trim_material, edge=.006)
        add_box(root, f"{name}_Sill", (location[0], location[1], location[2] - dimensions[2] / 2 - .045), (dimensions[0] + .08, dimensions[1] + .14, .09), trim_material, edge=.012)


def build_reference_house(root: bpy.types.Object) -> None:
    """Create the original Copper Finch House from reusable primitive parts."""
    mat = {
        "foundation": make_material("FoundationWarmStone", (0.48, 0.40, 0.31, 1.0)),
        "ground": make_material("LotSage", (0.28, 0.39, 0.25, 1.0)),
        "path": make_material("PathSand", (0.70, 0.58, 0.40, 1.0)),
        "walls": make_material("WallOchre", (0.72, 0.43, 0.19, 1.0)),
        "trim": make_material("TrimCream", (0.91, 0.81, 0.60, 1.0)),
        "roof": make_material("RoofVerdigris", (0.11, 0.33, 0.34, 1.0), 0.55),
        "door": make_material("DoorPlum", (0.34, 0.10, 0.16, 1.0)),
        "glass": make_material("WindowBlue", (0.20, 0.48, 0.58, 1.0), 0.32),
        "foliage": make_material("ShrubGreen", (0.16, 0.35, 0.12, 1.0)),
        "foliage_light": make_material("LeafHighlight", (0.34, 0.52, 0.18, 1.0)),
        "flower": make_material("CopperFinchFlower", (0.72, 0.22, 0.25, 1.0)),
        "chimney": make_material("ChimneyBrick", (0.47, 0.20, 0.12, 1.0)),
    }

    lot = add_box(root, "LotDiamond", (0.0, 0.0, -0.11), (4.0, 4.0, 0.22), mat["ground"], edge=0.07)
    lot["worldFootprintTiles"] = [2, 2]
    add_box(root, "FrontPath", (0.25, -1.46, 0.035), (0.62, 1.05, 0.07), mat["path"], edge=0.02)
    add_box(root, "Foundation", (0.0, 0.12, 0.18), (2.95, 2.55, 0.36), mat["foundation"], edge=0.06)
    add_box(root, "HouseBody", (0.0, 0.22, 1.25), (2.72, 2.30, 1.90), mat["walls"], edge=0.055)
    add_box(root, "CornerBay", (0.92, -0.74, 1.16), (0.72, 0.62, 1.55), mat["walls"], edge=0.05)
    add_box(root, "BodyTrim", (0.0, 0.22, 2.08), (2.82, 2.39, 0.16), mat["trim"], edge=0.025)
    add_gable_prism(root, "MainGableRoof", (0.0, 0.22, 2.16), 3.18, 2.72, 0.16, 1.02, mat["roof"])
    add_roof_seams(root, "MainRoof", (0.0, 0.22, 2.16), 3.18, 2.72, 0.16, 1.02, mat["roof"])
    # Cross-gable and dormer give the reference a distinctive silhouette in all four views.
    add_box(root, "FrontGableWall", (0.72, -0.90, 2.22), (1.12, .42, .72), mat["walls"], edge=.04)
    add_gable_prism(root, "FrontGableRoof", (0.72, -1.02, 2.49), 1.42, .82, .10, .55, mat["roof"])
    add_window(root, "FrontDormerWindow", (0.72, -1.445, 2.48), (.50, .05, .47), mat["glass"], mat["trim"])
    add_box(root, "RearDormerWall", (-.58, 1.18, 2.36), (.92, .35, .58), mat["walls"], edge=.035)
    add_gable_prism(root, "RearDormerRoof", (-.58, 1.32, 2.56), 1.15, .66, .08, .43, mat["roof"])
    add_window(root, "RearDormerWindow", (-.58, 1.525, 2.44), (.46, .05, .40), mat["glass"], mat["trim"])

    add_box(root, "PorchDeck", (-0.32, -1.16, 0.34), (1.55, 0.62, 0.16), mat["trim"], edge=0.035)
    for x in (-0.90, 0.24):
        add_box(root, f"PorchPost_{x:+.2f}", (x, -1.39, 1.14), (0.10, 0.10, 1.52), mat["trim"], edge=0.018)
    add_box(
        root,
        "PorchRoof",
        (-0.32, -1.27, 1.92),
        (1.74, 0.82, 0.16),
        mat["roof"],
        rotation=(math.radians(-8.0), 0.0, 0.0),
        edge=0.025,
    )
    add_box(root, "FrontDoor", (-0.33, -0.945, 1.12), (0.58, 0.07, 1.34), mat["door"], edge=0.025)
    add_window(root, "SouthWindow", (0.77, -0.962, 1.42), (0.60, 0.06, 0.72), mat["glass"], mat["trim"])
    add_window(root, "NorthWindow", (-0.62, 1.382, 1.43), (0.72, 0.06, 0.70), mat["glass"], mat["trim"])
    add_window(root, "EastWindow", (1.382, 0.42, 1.45), (0.06, 0.70, 0.72), mat["glass"], mat["trim"])
    add_window(root, "WestWindow", (-1.382, 0.28, 1.45), (0.06, 0.72, 0.72), mat["glass"], mat["trim"])
    # Corner boards and a stone belt add facade depth without changing footprint or pivot.
    for x in (-1.34, 1.34):
        for y in (-.88, 1.31):
            add_box(root, f"CornerTrim_{x}_{y}", (x, y, 1.27), (.13, .13, 1.84), mat["trim"], edge=.014)
    for x in (-1.08, -.54, 0, .54, 1.08):
        add_box(root, f"FoundationStone_{x}", (x, -1.18, .31), (.40, .12, .28), mat["foundation"], edge=.025)
    add_box(root, "Chimney", (-0.78, 0.60, 3.05), (0.36, 0.42, 1.12), mat["chimney"], edge=0.035)
    add_box(root, "ChimneyCap", (-0.78, 0.60, 3.64), (0.46, 0.52, 0.12), mat["trim"], edge=0.025)

    for index, location in enumerate(((-1.42, -1.42, 0.31), (1.44, -1.38, 0.34), (1.45, 1.32, 0.36), (-1.45, 1.28, 0.32))):
        add_uv_sphere(root, f"Shrub_{index + 1:02d}", location, (0.34, 0.30, 0.38), mat["foliage"])
        add_uv_sphere(root, f"ShrubHighlight_{index + 1:02d}", (location[0]-.06, location[1]-.05, location[2]+.15), (.18,.16,.18), mat["foliage_light"])
    # Flower box, small ornamental tree, and bench establish the canonical lot-dressing density.
    add_box(root, "FlowerBox", (.77,-1.02,.94), (.72,.20,.16), mat["foundation"], edge=.025)
    for index,x in enumerate((.55,.77,.99)):
        add_uv_sphere(root, f"Flower_{index}", (x,-1.06,1.08), (.10,.09,.12), mat["flower"])
    add_box(root, "TreeTrunk", (-1.18,1.24,.70), (.18,.18,1.18), mat["chimney"], edge=.025)
    for index,loc in enumerate(((-1.18,1.24,1.45),(-1.43,1.19,1.32),(-.95,1.16,1.36))):
        add_uv_sphere(root, f"TreeCrown_{index}", loc, (.48,.43,.55), mat["foliage"] if index == 0 else mat["foliage_light"])
    add_box(root, "GardenBenchSeat", (-.74,-1.55,.46), (.78,.28,.10), mat["chimney"], edge=.02)
    for x in (-1.02,-.46):
        add_box(root, f"GardenBenchLeg_{x}", (x,-1.55,.29), (.07,.20,.28), mat["chimney"], edge=.01)

    root["assetId"] = "copper_finch_house"
    root["assetDescription"] = "Original modest gable house assembled from reusable procedural parts"
    root["sourcePixelsReused"] = False
    root["liveAsset"] = False


def configure_scene(scene: bpy.types.Scene, config: dict) -> None:
    canvas = config["canvas"]
    bpy.context.preferences.filepaths.save_version = 0
    scene.render.engine = config["toolchain"]["renderEngine"]
    scene.render.resolution_x = canvas["width"]
    scene.render.resolution_y = canvas["height"]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.use_file_extension = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.16, 0.19, 0.22, 1.0)
    background.inputs["Strength"].default_value = config["lighting"]["worldStrength"]
    scene["pipelineSchema"] = config["schema"]
    scene["postRenderCompensation"] = "none"
    scene["projectedTilePixels"] = config["grid"]["projectedTilePixels"]


def create_root(config: dict) -> tuple[bpy.types.Object, bpy.types.Object]:
    root = bpy.data.objects.new(config["root"]["name"], None)
    root.empty_display_type = "PLAIN_AXES"
    root.location = config["root"]["location"]
    root.rotation_euler = config["root"]["rotationEuler"]
    root.scale = config["root"]["scale"]
    bpy.context.collection.objects.link(root)

    pivot = bpy.data.objects.new(config["root"]["pivotName"], None)
    pivot.empty_display_type = "CIRCLE"
    pivot.empty_display_size = 0.25
    pivot.location = (0.0, 0.0, 0.0)
    pivot.parent = root
    bpy.context.collection.objects.link(pivot)
    return root, pivot


def point_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def create_camera_rig(config: dict) -> list[bpy.types.Object]:
    elevation = math.radians(config["grid"]["elevationDegrees"])
    distance = config["cameraRig"]["distance"]
    horizontal = distance * math.cos(elevation)
    cameras = []
    for view in config["cameraRig"]["views"]:
        azimuth = math.radians(view["azimuthDegrees"])
        location = (
            horizontal * math.sin(azimuth),
            horizontal * math.cos(azimuth),
            distance * math.sin(elevation),
        )
        data = bpy.data.cameras.new(view["name"])
        data.type = "ORTHO"
        data.ortho_scale = config["cameraRig"]["orthoScale"]
        data.shift_x = 0.0
        data.shift_y = config["cameraRig"]["shiftY"]
        camera = bpy.data.objects.new(view["name"], data)
        bpy.context.collection.objects.link(camera)
        camera.location = location
        point_at(camera, Vector((0.0, 0.0, 0.0)))
        camera["azimuthDegrees"] = view["azimuthDegrees"]
        camera["elevationDegrees"] = config["grid"]["elevationDegrees"]
        camera["sharedPivot"] = config["root"]["pivotName"]
        cameras.append(camera)
    return cameras


def create_lighting(config: dict) -> bpy.types.Object:
    light_config = config["lighting"]
    data = bpy.data.lights.new(light_config["name"], type=light_config["type"])
    data.energy = light_config["energy"]
    data.shape = "DISK"
    data.size = light_config["size"]
    light = bpy.data.objects.new(light_config["name"], data)
    bpy.context.collection.objects.link(light)
    light.location = light_config["location"]
    point_at(light, Vector((0.0, 0.0, 0.0)))
    return light


def render_views(scene: bpy.types.Scene, cameras: list[bpy.types.Object], config: dict) -> list[Path]:
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    paths = []
    for camera in cameras:
        path = RENDER_DIR / config["output"]["filePattern"].format(camera=camera.name)
        scene.camera = camera
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        paths.append(path)
    return paths


def make_contact_sheet(paths: list[Path], config: dict) -> Path:
    width = config["canvas"]["width"]
    height = config["canvas"]["height"]
    gutter = 16
    sheet_width = width * 2 + gutter
    sheet_height = height * 2 + gutter
    pixels = array("f", [0.0]) * (sheet_width * sheet_height * 4)
    placements = ((0, height + gutter), (width + gutter, height + gutter), (0, 0), (width + gutter, 0))
    for path, (offset_x, offset_y) in zip(paths, placements):
        image = bpy.data.images.load(str(path), check_existing=False)
        source = array("f", image.pixels[:])
        if tuple(image.size) != (width, height):
            raise RuntimeError(f"RENDER_SIZE_MISMATCH: {path.name}: {tuple(image.size)}")
        for row in range(height):
            src_start = row * width * 4
            dst_start = ((row + offset_y) * sheet_width + offset_x) * 4
            pixels[dst_start : dst_start + width * 4] = source[src_start : src_start + width * 4]
        bpy.data.images.remove(image)
    sheet = bpy.data.images.new("FourViewContactSheet", width=sheet_width, height=sheet_height, alpha=True)
    sheet.pixels[:] = pixels
    sheet.file_format = "PNG"
    output = EXAMPLE_DIR / config["output"]["contactSheet"]
    sheet.filepath_raw = str(output)
    sheet.save()
    bpy.data.images.remove(sheet)
    canonicalize_png(output)
    return output


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_manifest(blend_path: Path, render_paths: list[Path], contact_sheet: Path, config: dict) -> Path:
    artifacts = [blend_path, *render_paths, contact_sheet]
    manifest = {
        "schema": "citysim.world-art.blender-four-view-example.v1",
        "pipelineSchema": config["schema"],
        "assetId": config["output"]["assetId"],
        "status": "source-example-only-not-live",
        "toolchain": {
            "blenderVersion": ".".join(str(value) for value in bpy.app.version),
            "renderEngine": config["toolchain"]["renderEngine"],
        },
        "cameraOrder": [view["name"] for view in config["cameraRig"]["views"]],
        "cameraAzimuthDegrees": {view["name"]: view["azimuthDegrees"] for view in config["cameraRig"]["views"]},
        "elevationDegrees": config["grid"]["elevationDegrees"],
        "projection": config["grid"]["projection"],
        "projectedTilePixels": config["grid"]["projectedTilePixels"],
        "canvas": config["canvas"],
        "rootPivotWorld": config["root"]["location"],
        "lightingConvention": config["lighting"],
        "postRenderCompensation": "none",
        "contactSheetLayout": [["camNE", "camSE"], ["camSW", "camNW"]],
        "researchReference": config["researchReference"],
        "originalGeometry": True,
        "liveAsset": False,
        "artifacts": [],
    }
    for path in artifacts:
        artifact = {
            "path": path.relative_to(PIPELINE_DIR).as_posix(),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        }
        if path.suffix.lower() == ".png":
            width, height, rgba = decode_rgba_png(path)
            artifact["decodedRgbaSha256"] = hashlib.sha256(rgba).hexdigest()
            artifact["dimensions"] = [width, height]
        manifest["artifacts"].append(artifact)
    path = EXAMPLE_DIR / config["output"]["manifest"]
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


def main() -> None:
    config = read_config()
    require_toolchain(config)
    EXAMPLE_DIR.mkdir(parents=True, exist_ok=True)
    scene = reset_scene()
    configure_scene(scene, config)
    root, _pivot = create_root(config)
    build_reference_house(root)
    cameras = create_camera_rig(config)
    create_lighting(config)
    scene.camera = cameras[0]

    blend_path = EXAMPLE_DIR / config["output"]["sourceBlend"]
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    renders = render_views(scene, cameras, config)
    contact_sheet = make_contact_sheet(renders, config)
    manifest = write_manifest(blend_path, renders, contact_sheet, config)
    print(f"FOUR_VIEW_PIPELINE_RENDERED: {len(renders)} views")
    print(f"FOUR_VIEW_PIPELINE_MANIFEST: {manifest}")


if __name__ == "__main__":
    main()
