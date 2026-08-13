#!/usr/bin/env python3
"""Build Greenworks Nursery's original CitySim Four-View ground ecology family."""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
BLENDER_ROOT = HERE.parents[1]
CANONICAL = BLENDER_ROOT / "FourViewPipeline"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))
from png_canonical import canonicalize_png, decode_rgba_png, encode_rgba_png  # noqa: E402

CONFIG = json.loads((HERE / "pipeline.json").read_text())
VIEWS = CONFIG["cameraRig"]["views"]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def material(name, color, roughness=0.78, metallic=0.0, texture_scale=0.0, bump=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    shader = nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if texture_scale:
        coordinates = nodes.new("ShaderNodeTexCoord")
        noise = nodes.new("ShaderNodeTexNoise")
        ramp = nodes.new("ShaderNodeValToRGB")
        bump_node = nodes.new("ShaderNodeBump")
        noise.inputs["Scale"].default_value = texture_scale
        noise.inputs["Detail"].default_value = 3.0
        noise.inputs["Roughness"].default_value = 0.64
        ramp.color_ramp.elements[0].position = 0.27
        ramp.color_ramp.elements[0].color = tuple(max(0.0, component * 0.72) for component in color[:3]) + (color[3],)
        ramp.color_ramp.elements[1].position = 0.76
        ramp.color_ramp.elements[1].color = tuple(min(1.0, component * 1.15 + 0.015) for component in color[:3]) + (color[3],)
        bump_node.inputs["Strength"].default_value = bump
        bump_node.inputs["Distance"].default_value = 0.025
        links.new(coordinates.outputs["Generated"], noise.inputs["Vector"])
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], shader.inputs["Base Color"])
        links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], shader.inputs["Normal"])
    return mat


def apply_transforms(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def soften(obj, width=0.018, segments=2):
    modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def box(root, name, location, dimensions, mat, edge=0.015, properties=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    apply_transforms(obj)
    if edge:
        soften(obj, edge)
    obj.data.materials.append(mat)
    obj.parent = root
    if properties:
        for key, value in properties.items():
            obj[key] = value
    return obj


def cylinder(root, name, location, radius, depth, mat, vertices=20, edge=0.01, properties=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    apply_transforms(obj)
    if edge:
        soften(obj, edge, 1)
    obj.data.materials.append(mat)
    obj.parent = root
    if properties:
        for key, value in properties.items():
            obj[key] = value
    return obj


def cone(root, name, location, radius1, radius2, depth, mat, vertices=16):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    apply_transforms(obj)
    soften(obj, min(0.012, radius1 * 0.12), 1)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def sphere(root, name, location, scale, mat, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    apply_transforms(obj)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def beam(root, name, start, end, width, mat):
    a, b = Vector(start), Vector(end)
    direction = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=width, depth=direction.length, location=(a + b) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    apply_transforms(obj)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def reset(scene_name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = scene_name
    bpy.context.preferences.filepaths.save_version = 0
    return scene


def configure_scene(scene, transparent=True):
    canvas = CONFIG["canvas"]
    scene.render.engine = CONFIG["toolchain"]["renderEngine"]
    scene.render.resolution_x = canvas["width"]
    scene.render.resolution_y = canvas["height"]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = transparent
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.use_file_extension = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.world = bpy.data.worlds.new("CitySimWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = CONFIG["lighting"]["worldColor"]
    background.inputs["Strength"].default_value = CONFIG["lighting"]["worldStrength"]
    scene["pipelineSchema"] = CONFIG["schema"]
    scene["postRenderCompensation"] = "none"
    scene["projectedTilePixels"] = CONFIG["grid"]["projectedTilePixels"]
    scene["sourcePixelsReused"] = False


def point_at(obj, target=Vector((0.0, 0.0, 0.0))):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def add_key_light():
    spec = CONFIG["lighting"]
    data = bpy.data.lights.new(spec["name"], spec["type"])
    data.energy = spec["energy"]
    data.shape = "DISK"
    data.size = spec["size"]
    data.color = spec["color"]
    light = bpy.data.objects.new(spec["name"], data)
    bpy.context.collection.objects.link(light)
    light.location = spec["location"]
    point_at(light)
    return light


def canonical_rig(scene):
    rig = CONFIG["cameraRig"]
    elevation = math.radians(CONFIG["grid"]["elevationDegrees"])
    horizontal = rig["distance"] * math.cos(elevation)
    cameras = []
    for view in VIEWS:
        azimuth = math.radians(view["azimuthDegrees"])
        data = bpy.data.cameras.new(view["name"])
        data.type = "ORTHO"
        data.ortho_scale = rig["orthoScale"]
        data.shift_y = rig["shiftY"]
        camera = bpy.data.objects.new(view["name"], data)
        bpy.context.collection.objects.link(camera)
        camera.location = (
            horizontal * math.sin(azimuth),
            horizontal * math.cos(azimuth),
            rig["distance"] * math.sin(elevation),
        )
        point_at(camera)
        cameras.append(camera)
    add_key_light()
    scene.camera = cameras[0]
    return cameras


def asset_root(asset):
    root = bpy.data.objects.new("AssetRoot", None)
    bpy.context.collection.objects.link(root)
    pivot = bpy.data.objects.new("FootprintPivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.parent = root
    pivot.empty_display_type = "CIRCLE"
    pivot.empty_display_size = 0.10
    root["assetId"] = asset["assetId"]
    root["assetKind"] = asset["assetKind"]
    root["originalGeometry"] = True
    root["sourcePixelsReused"] = False
    root["cedarMarketReused"] = False
    root["rejectedVectorAssetsReused"] = False
    root["billboardGeometry"] = False
    root["postRenderCompensation"] = "none"
    root["perAssetTransformCompensation"] = "none"
    root["worldCell"] = [2.0, 2.0]
    return root


def ecology_palette():
    return {
        "meadow": material("WarmMeadowGrass", (0.34, 0.43, 0.19, 1), texture_scale=12.0, bump=0.19),
        "meadow_light": material("SunlitMeadowTuft", (0.49, 0.55, 0.24, 1), texture_scale=7.0, bump=0.08),
        "soil": material("WarmLoam", (0.34, 0.20, 0.105, 1), texture_scale=15.0, bump=0.17),
        "worn": material("WornBuffEarth", (0.53, 0.39, 0.21, 1), texture_scale=18.0, bump=0.12),
        "park": material("ParkGroveTurf", (0.25, 0.39, 0.17, 1), texture_scale=10.0, bump=0.17),
        "path": material("WarmParkAggregate", (0.61, 0.51, 0.34, 1), texture_scale=22.0, bump=0.12),
        "gravel": material("UtilityAggregate", (0.42, 0.42, 0.34, 1), texture_scale=28.0, bump=0.24),
        "sage": material("SageLeaf", (0.34, 0.48, 0.37, 1), texture_scale=5.0, bump=0.08),
        "sage_light": material("SageLeafLight", (0.48, 0.58, 0.43, 1), texture_scale=4.0, bump=0.07),
        "bark": material("MapleBark", (0.26, 0.135, 0.07, 1), texture_scale=9.0, bump=0.22),
        "leaf": material("MapleLeafGreen", (0.25, 0.44, 0.17, 1), texture_scale=5.0, bump=0.09),
        "leaf_light": material("MapleLeafSunlit", (0.43, 0.57, 0.20, 1), texture_scale=5.0, bump=0.08),
        "leaf_warm": material("MapleLeafWarm", (0.54, 0.43, 0.12, 1), texture_scale=5.0, bump=0.08),
        "terracotta": material("PlanterTerracotta", (0.58, 0.245, 0.105, 1), texture_scale=10.0, bump=0.12),
        "terracotta_rim": material("PlanterTerracottaRim", (0.72, 0.34, 0.14, 1), texture_scale=8.0, bump=0.09),
        "marigold": material("MarigoldPetal", (0.95, 0.48, 0.055, 1), roughness=0.66),
        "marigold_gold": material("MarigoldGold", (0.98, 0.67, 0.08, 1), roughness=0.62),
        "stem": material("FlowerStem", (0.20, 0.38, 0.13, 1), roughness=0.82),
        "stone": material("WarmFieldStone", (0.50, 0.43, 0.32, 1), texture_scale=14.0, bump=0.13),
    }


def exact_ground_cell(root, mat):
    return box(
        root,
        "ExactGroundCell",
        (0, 0, -0.05),
        (2.0, 2.0, 0.10),
        mat,
        edge=0,
        properties={
            "exactCellBounds": [-1.0, 1.0, -1.0, 1.0],
            "edgeAlignment": "world-x-y",
            "worldCell": [2.0, 2.0],
            "arbitraryPad": False,
        },
    )


def add_tuft(root, index, x, y, mats, scale=1.0):
    cone(root, f"GrassBlade{index}A", (x, y, 0.075 * scale), 0.045 * scale, 0.008, 0.15 * scale, mats["meadow_light"], 8)
    cone(root, f"GrassBlade{index}B", (x + 0.045 * scale, y - 0.025 * scale, 0.06 * scale), 0.035 * scale, 0.006, 0.12 * scale, mats["meadow"], 8)


def civic_meadow(root, mats):
    exact_ground_cell(root, mats["meadow"])
    box(root, "LoamRibbonWest", (-0.71, 0.0, 0.008), (0.34, 1.82, 0.016), mats["soil"], edge=0.07)
    box(root, "LoamRibbonSouth", (0.27, -0.73, 0.010), (1.24, 0.30, 0.020), mats["soil"], edge=0.07)
    tufts = [(-0.82, -0.68), (-0.78, 0.63), (-0.46, 0.28), (-0.18, 0.72), (0.12, 0.43), (0.34, -0.42), (0.58, 0.70), (0.78, -0.12), (0.66, -0.70)]
    for index, (x, y) in enumerate(tufts):
        add_tuft(root, index, x, y, mats, 0.78 + (index % 3) * 0.12)
    for index, (x, y, radius) in enumerate(((-0.54, -0.22, 0.09), (0.52, 0.22, 0.075), (0.12, -0.78, 0.06))):
        sphere(root, f"MeadowStone{index}", (x, y, radius * 0.36), (radius, radius * 0.78, radius * 0.36), mats["stone"], 1)


def worn_neighborhood(root, mats):
    exact_ground_cell(root, mats["meadow"])
    box(root, "FootWearNorthSouth", (0.16, 0.0, 0.009), (0.42, 1.90, 0.018), mats["worn"], edge=0.11)
    box(root, "FootWearEastWest", (0.43, -0.48, 0.011), (1.02, 0.32, 0.022), mats["worn"], edge=0.10)
    for index, (x, y) in enumerate(((-0.76, -0.68), (-0.68, 0.58), (-0.42, 0.78), (0.64, 0.70), (0.79, 0.18), (0.76, -0.78), (-0.60, -0.05))):
        add_tuft(root, 20 + index, x, y, mats, 0.65 + (index % 2) * 0.16)
    for index, (x, y) in enumerate(((0.12, 0.62), (0.22, 0.08), (0.14, -0.72), (0.66, -0.48))):
        sphere(root, f"PressedEarth{index}", (x, y, 0.017), (0.105, 0.07, 0.017), mats["soil"], 1)


def park_grove(root, mats):
    exact_ground_cell(root, mats["park"])
    box(root, "ParkPathNorthSouth", (0.0, 0.0, 0.012), (0.38, 1.92, 0.024), mats["path"], edge=0.06)
    box(root, "ParkPathEastWest", (0.0, 0.0, 0.014), (1.92, 0.38, 0.028), mats["path"], edge=0.06)
    for index, (x, y) in enumerate(((-0.72, -0.72), (-0.72, 0.72), (0.72, -0.72), (0.72, 0.72))):
        cylinder(root, f"GroveBedEdge{index}", (x, y, 0.028), 0.21, 0.056, mats["soil"], vertices=20, edge=0.008)
        for offset, (dx, dy) in enumerate(((-0.07, -0.03), (0.05, 0.02), (0.0, 0.08))):
            sphere(root, f"GrovePlant{index}_{offset}", (x + dx, y + dy, 0.09 + 0.02 * offset), (0.10, 0.085, 0.09), mats["sage" if offset != 1 else "sage_light"], 1)


def utility_service(root, mats):
    exact_ground_cell(root, mats["meadow"])
    box(root, "ServiceAggregateBand", (0.20, 0.0, 0.015), (1.18, 1.88, 0.030), mats["gravel"], edge=0.035)
    box(root, "PlantedVergeWest", (-0.70, 0.0, 0.019), (0.42, 1.84, 0.038), mats["soil"], edge=0.045)
    for index, y in enumerate((-0.70, -0.35, 0.0, 0.35, 0.70)):
        sphere(root, f"UtilitySage{index}", (-0.70, y, 0.105), (0.15, 0.12, 0.105), mats["sage" if index % 2 == 0 else "sage_light"], 1)
    for index, (x, y) in enumerate(((-0.28, -0.72), (0.14, -0.42), (0.48, -0.08), (0.02, 0.24), (0.62, 0.54), (-0.16, 0.73))):
        sphere(root, f"AggregateStone{index}", (x, y, 0.045), (0.09, 0.07, 0.045), mats["stone"], 1)


def maple_street_tree(root, mats):
    cylinder(root, "GroundContact", (0.0, 0.0, 0.62), 0.16, 1.24, mats["bark"], 18, 0.012, {"groundContactZ": 0.0, "pivotXY": [0.0, 0.0]})
    beam(root, "MapleBranchNorth", (0, 0, 0.82), (-0.34, 0.10, 1.64), 0.075, mats["bark"])
    beam(root, "MapleBranchEast", (0.02, 0, 0.94), (0.38, -0.16, 1.72), 0.068, mats["bark"])
    beam(root, "MapleBranchCrown", (0, 0, 1.03), (0.05, 0.24, 1.92), 0.065, mats["bark"])
    crowns = [
        (-0.36, 0.10, 1.72, 0.52, "leaf"),
        (0.38, -0.14, 1.78, 0.50, "leaf_light"),
        (0.04, 0.26, 2.00, 0.56, "leaf"),
        (-0.12, -0.28, 1.94, 0.47, "leaf_warm"),
        (0.26, 0.22, 2.18, 0.44, "leaf_light"),
        (-0.34, -0.18, 2.20, 0.40, "leaf"),
        (0.02, 0.00, 2.32, 0.46, "leaf_warm"),
    ]
    for index, (x, y, z, scale, key) in enumerate(crowns):
        sphere(root, f"MapleCrown{index}", (x, y, z), (scale, scale * 0.88, scale * 0.72), mats[key], 2)
    for index, angle in enumerate((0, math.pi / 2, math.pi, math.pi * 1.5)):
        x, y = math.cos(angle) * 0.21, math.sin(angle) * 0.21
        beam(root, f"RootFlare{index}", (0, 0, 0.08), (x, y, 0.015), 0.045, mats["bark"])


def sage_shrub_cluster(root, mats):
    cylinder(root, "GroundContact", (0, 0, 0.12), 0.055, 0.24, mats["bark"], 12, 0.004, {"groundContactZ": 0.0, "pivotXY": [0.0, 0.0]})
    stems = [(-0.38, -0.18, 0.38), (-0.18, 0.26, 0.48), (0.0, 0.0, 0.55), (0.30, -0.12, 0.44), (0.34, 0.28, 0.37), (-0.42, 0.30, 0.34)]
    for index, (x, y, z) in enumerate(stems):
        beam(root, f"SageStem{index}", (0, 0, 0.06), (x, y, z), 0.025, mats["bark"])
        sphere(root, f"SageCrown{index}", (x, y, z), (0.30, 0.24, 0.23), mats["sage" if index % 2 == 0 else "sage_light"], 2)
        sphere(root, f"SageTip{index}", (x * 1.04, y * 1.04, z + 0.16), (0.16, 0.13, 0.16), mats["sage_light" if index % 2 == 0 else "sage"], 1)


def marigold_planter(root, mats):
    box(root, "GroundContact", (0.0, 0.0, 0.08), (0.74, 0.54, 0.16), mats["terracotta"], edge=0.035, properties={"groundContactZ": 0.0, "pivotXY": [0.0, 0.0]})
    planter_specs = [(0.0, 0.0, 0.0), (-0.52, 0.32, -0.03), (0.52, 0.30, -0.03)]
    for planter_index, (px, py, z_offset) in enumerate(planter_specs):
        if planter_index:
            box(root, f"PlanterBase{planter_index}", (px, py, 0.07), (0.54, 0.40, 0.14), mats["terracotta"], edge=0.03)
        box(root, f"PlanterRim{planter_index}", (px, py, 0.19 + z_offset), (0.82 if planter_index == 0 else 0.61, 0.62 if planter_index == 0 else 0.47, 0.13), mats["terracotta_rim"], edge=0.025)
        box(root, f"PlanterSoil{planter_index}", (px, py, 0.262 + z_offset), (0.62 if planter_index == 0 else 0.44, 0.42 if planter_index == 0 else 0.30, 0.035), mats["soil"], edge=0.025)
        offsets = ((-0.18, -0.09), (0.0, 0.08), (0.18, -0.06)) if planter_index == 0 else ((-0.11, 0.0), (0.10, 0.02))
        for flower_index, (dx, dy) in enumerate(offsets):
            height = 0.44 + 0.06 * ((flower_index + planter_index) % 2) + z_offset
            cylinder(root, f"FlowerStem{planter_index}_{flower_index}", (px + dx, py + dy, (0.27 + height) / 2), 0.018, height - 0.27, mats["stem"], 10, 0)
            sphere(root, f"FlowerHead{planter_index}_{flower_index}", (px + dx, py + dy, height), (0.115, 0.105, 0.075), mats["marigold" if flower_index % 2 == 0 else "marigold_gold"], 2)
            sphere(root, f"FlowerCenter{planter_index}_{flower_index}", (px + dx, py + dy, height + 0.06), (0.043, 0.043, 0.036), mats["soil"], 1)


BUILDERS = {
    "civic_meadow_ground": civic_meadow,
    "worn_neighborhood_ground": worn_neighborhood,
    "park_grove_ground": park_grove,
    "utility_service_ground": utility_service,
    "maple_street_tree": maple_street_tree,
    "sage_shrub_cluster": sage_shrub_cluster,
    "marigold_planter_cluster": marigold_planter,
}


def build_asset(asset):
    scene = reset("CitySimGroundEcology_" + asset["assetId"])
    configure_scene(scene, transparent=True)
    root = asset_root(asset)
    BUILDERS[asset["assetId"]](root, ecology_palette())
    cameras = canonical_rig(scene)
    return scene, root, cameras


def render_views(scene, cameras, asset_id, output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for camera in cameras:
        path = output_dir / f"{asset_id}_{camera.name}.png"
        scene.camera = camera
        scene.render.resolution_x = 384
        scene.render.resolution_y = 384
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        paths.append(path)
    return paths


FONT = {
    "A": ["01110", "10001", "11111", "10001", "10001"],
    "C": ["01111", "10000", "10000", "10000", "01111"],
    "E": ["11111", "10000", "11110", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001"],
    "S": ["01111", "10000", "01110", "00001", "11110"],
    "W": ["10001", "10001", "10101", "11011", "10001"],
}


def contact_sheet(paths, output_path):
    width = height = 384
    gap, label_height = 16, 28
    sheet_width = width * 2 + gap
    sheet_height = (height + label_height) * 2 + gap
    rgba = bytearray(sheet_width * sheet_height * 4)
    for index, path in enumerate(paths):
        _, _, source = decode_rgba_png(path)
        column, row = index % 2, index // 2
        origin_x = column * (width + gap)
        origin_y = row * (height + label_height + gap)
        for y in range(height):
            source_start = y * width * 4
            dest_start = ((origin_y + y) * sheet_width + origin_x) * 4
            rgba[dest_start : dest_start + width * 4] = source[source_start : source_start + width * 4]
        for y in range(origin_y + height, origin_y + height + label_height):
            for x in range(origin_x, origin_x + width):
                pixel = (y * sheet_width + x) * 4
                rgba[pixel : pixel + 4] = bytes((45, 52, 46, 255))
        label = VIEWS[index]["name"].upper()
        scale, text_x, text_y = 3, origin_x + 12, origin_y + height + 6
        for char_index, char in enumerate(label):
            for row_index, bits in enumerate(FONT[char]):
                for column_index, active in enumerate(bits):
                    if active == "1":
                        for yy in range(scale):
                            for xx in range(scale):
                                x = text_x + char_index * 18 + column_index * scale + xx
                                y = text_y + row_index * scale + yy
                                pixel = (y * sheet_width + x) * 4
                                rgba[pixel : pixel + 4] = bytes((244, 215, 151, 255))
    encode_rgba_png(output_path, sheet_width, sheet_height, bytes(rgba))
    return output_path


def alpha_metadata(path):
    width, height, rgba = decode_rgba_png(path)
    opaque = [(index % width, index // width) for index, alpha in enumerate(rgba[3::4]) if alpha]
    if not opaque:
        raise RuntimeError(f"EMPTY_ALPHA: {path}")
    xs, ys = [point[0] for point in opaque], [point[1] for point in opaque]
    pivot_x, pivot_y = CONFIG["canvas"]["footprintPivotPixelTopOrigin"]
    return {
        "boundsTopOrigin": {
            "minX": min(xs), "minY": min(ys), "maxX": max(xs), "maxY": max(ys),
            "width": max(xs) - min(xs) + 1, "height": max(ys) - min(ys) + 1,
        },
        "opaquePixelCount": len(opaque),
        "lowestOpaqueRowTopOrigin": max(ys),
        "pivotPixelAlpha": rgba[(pivot_y * width + pivot_x) * 4 + 3],
    }


def artifact_info(path, relative_to=HERE):
    info = {"path": path.relative_to(relative_to).as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)}
    if path.suffix == ".png":
        width, height, rgba = decode_rgba_png(path)
        info["dimensions"] = [width, height]
        info["decodedRgbaSha256"] = hashlib.sha256(rgba).hexdigest()
        info["alpha"] = alpha_metadata(path)
    return info


def write_asset_manifest(asset, artifacts):
    output_dir = HERE / asset["assetId"]
    data = {
        "schema": "citysim.world-art.ground-ecology-asset.v1",
        "pipelineSchema": CONFIG["schema"],
        "assetId": asset["assetId"],
        "assetKind": asset["assetKind"],
        "description": asset["description"],
        "status": "source-only-not-live",
        "liveAsset": False,
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "cedarMarketReused": False,
        "rejectedVectorAssetsReused": False,
        "billboardGeometry": False,
        "cameraOrder": [view["name"] for view in VIEWS],
        "grid": CONFIG["grid"],
        "canvas": CONFIG["canvas"],
        "cameraRig": CONFIG["cameraRig"],
        "lightingConvention": CONFIG["lighting"],
        "root": CONFIG["root"],
        "postRenderCompensation": "none",
        "perAssetCompensation": {"rotationDegrees": 0.0, "skew": [0.0, 0.0], "crop": False, "offsetPixels": [0, 0], "scale": 1.0},
        "contactSheetLayout": [["camNE", "camSE"], ["camSW", "camNW"]],
        "groundContract": {"exactWorldBoundsXY": [-1.0, 1.0, -1.0, 1.0], "edgeAlignment": "world-x-y", "arbitraryPad": False} if asset["assetKind"] == "ground-treatment" else None,
        "vegetationContract": {"pivotWorld": [0.0, 0.0, 0.0], "groundContactZ": 0.0, "modeled3D": True, "billboard": False} if asset["assetKind"] == "vegetation-dressing" else None,
        "artifacts": [artifact_info(path, output_dir) for path in artifacts],
    }
    path = output_dir / "manifest.json"
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return path


def append_mesh_asset(source, placement_name, location):
    with bpy.data.libraries.load(str(source), link=False) as (data_from, data_to):
        data_to.objects = list(data_from.objects)
    imported = [obj for obj in data_to.objects if obj is not None]
    for obj in imported:
        if not obj.users_collection:
            bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.update()
    source_matrices = {obj: obj.matrix_world.copy() for obj in imported if obj.type == "MESH"}
    placement = bpy.data.objects.new(placement_name, None)
    bpy.context.collection.objects.link(placement)
    placement.location = location
    placement["sourceBlend"] = str(source.relative_to(BLENDER_ROOT))
    placement["gridPlacement"] = list(location)
    placement["perAssetTransformCompensation"] = "none"
    mesh_count = 0
    for obj in imported:
        if obj.type != "MESH":
            continue
        obj.parent = placement
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = source_matrices[obj]
        mesh_count += 1
    for obj in imported:
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    return placement, mesh_count


def preview_camera(scene):
    distance = 42.0
    elevation = math.radians(30.0)
    azimuth = math.radians(45.0)
    horizontal = distance * math.cos(elevation)
    data = bpy.data.cameras.new("DistrictPreviewCamera")
    data.type = "ORTHO"
    data.ortho_scale = 14.4
    camera = bpy.data.objects.new("DistrictPreviewCamera", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation))
    point_at(camera, Vector((0.0, 0.0, 0.55)))
    add_key_light()
    scene.camera = camera
    return camera


def add_neutral_buildings(root, mats):
    wall = material("PreviewWarmMassing", (0.56, 0.40, 0.26, 1), texture_scale=9.0, bump=0.10)
    wall_light = material("PreviewCivicMassing", (0.64, 0.56, 0.42, 1), texture_scale=8.0, bump=0.08)
    roof = material("PreviewMassingRoof", (0.25, 0.20, 0.16, 1), texture_scale=12.0, bump=0.12)
    glass = material("PreviewWindow", (0.18, 0.30, 0.31, 1), roughness=0.40, metallic=0.10)
    for index, (x, y, height, width, depth) in enumerate(((-5, -3, 1.50, 1.55, 1.42), (-3, -3, 1.15, 1.45, 1.38), (3, -3, 1.78, 1.58, 1.46), (5, -3, 1.28, 1.50, 1.40))):
        selected = wall if index % 2 == 0 else wall_light
        box(root, f"NeighborhoodMassing{index}", (x, y, height / 2), (width, depth, height), selected, edge=0.055)
        box(root, f"NeighborhoodRoof{index}", (x, y, height + 0.10), (width + 0.12, depth + 0.12, 0.20), roof, edge=0.035)
        for window_index, wx in enumerate((-0.38, 0.0, 0.38)):
            box(root, f"MassingWindow{index}_{window_index}", (x + wx, y + depth / 2 + 0.012, height * 0.58), (0.22, 0.035, 0.34), glass, edge=0.012)
    return mats


def build_preview():
    scene = reset("CitySimGreenworksNeighborhoodGround")
    configure_scene(scene, transparent=False)
    scene["singleGrid"] = True
    scene["gridSpacingWorld"] = 2.0
    scene["perAssetTransformCompensation"] = "none"
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    base = material("PreviewDistrictSoil", (0.30, 0.31, 0.18, 1), texture_scale=11.0, bump=0.14)
    asphalt = material("PreviewRoadAsphalt", (0.15, 0.17, 0.16, 1), texture_scale=25.0, bump=0.17)
    sidewalk = material("PreviewSidewalk", (0.62, 0.55, 0.42, 1), texture_scale=17.0, bump=0.11)
    lane = material("PreviewLaneOchre", (0.84, 0.57, 0.15, 1), roughness=0.66)
    grid = material("PreviewGridJoint", (0.18, 0.22, 0.14, 1), roughness=0.86)
    box(root, "UnifiedDistrictGround", (0, 0, -0.14), (16, 12, 0.28), base, edge=0.04)
    box(root, "RoadEastWest", (0, 0, -0.015), (16, 1.55, 0.12), asphalt, edge=0.025)
    box(root, "RoadNorthSouth", (0, 0, -0.012), (1.55, 12, 0.125), asphalt, edge=0.025)
    for y in (-0.91, 0.91):
        box(root, f"SidewalkEW{y}", (0, y, 0.025), (16, 0.26, 0.15), sidewalk, edge=0.025)
    for x in (-0.91, 0.91):
        box(root, f"SidewalkNS{x}", (x, 0, 0.028), (0.26, 12, 0.15), sidewalk, edge=0.025)
    for x in range(-7, 8, 2):
        box(root, f"LaneMarkEW{x}", (x, 0, 0.052), (0.78, 0.06, 0.018), lane, edge=0.005)
    for y in range(-5, 6, 2):
        box(root, f"LaneMarkNS{y}", (0, y, 0.055), (0.06, 0.78, 0.018), lane, edge=0.005)
    for x in (-8, -6, -4, -2, 2, 4, 6, 8):
        box(root, f"GridX{x}", (x, 0, -0.031), (0.026, 12, 0.018), grid, edge=0)
    for y in (-6, -4, -2, 2, 4, 6):
        box(root, f"GridY{y}", (0, y, -0.029), (16, 0.026, 0.018), grid, edge=0)

    placements_spec = [
        ("civic_meadow_ground", (-5.0, 3.0, 0.10)),
        ("worn_neighborhood_ground", (-3.0, 3.0, 0.10)),
        ("park_grove_ground", (3.0, 3.0, 0.10)),
        ("utility_service_ground", (5.0, 3.0, 0.10)),
        ("maple_street_tree", (3.0, 3.0, 0.10)),
        ("sage_shrub_cluster", (5.0, 3.0, 0.10)),
        ("marigold_planter_cluster", (-5.0, 3.0, 0.10)),
    ]
    placements = []
    for asset_id, location in placements_spec:
        source = HERE / asset_id / f"{asset_id}.blend"
        _, mesh_count = append_mesh_asset(source, "Placement_" + asset_id, location)
        placements.append({
            "assetId": asset_id,
            "originWorld": list(location),
            "sourceBlend": source.relative_to(BLENDER_ROOT).as_posix(),
            "sourceBlendSha256": sha256(source),
            "meshCount": mesh_count,
            "perAssetTransformCompensation": "none",
            "rotationEuler": [0.0, 0.0, 0.0],
            "scale": [1.0, 1.0, 1.0],
        })
    add_neutral_buildings(root, {})
    preview_camera(scene)
    preview_dir = HERE / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    blend_path = preview_dir / "greenworks-neighborhood-ground.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in CONFIG["preview"]["dimensions"]:
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = preview_dir / f"greenworks-neighborhood-ground-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    data = {
        "schema": "citysim.world-art.ground-ecology-preview.v1",
        "status": "source-only-review-evidence",
        "liveAsset": False,
        "singleGrid": True,
        "gridSpacingWorld": 2.0,
        "camera": {"name": "DistrictPreviewCamera", "projection": "orthographic", "azimuthDegrees": 45.0, "elevationDegrees": 30.0},
        "lightingConvention": CONFIG["lighting"],
        "perAssetTransformCompensation": "none",
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "cedarMarketReused": False,
        "placements": placements,
        "artifacts": [artifact_info(blend_path), *[artifact_info(path) for path in outputs]],
    }
    manifest_path = preview_dir / "manifest.json"
    manifest_path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return manifest_path


def write_family_manifest(asset_manifests, preview_manifest):
    source_paths = [HERE / "pipeline.json", HERE / "build_and_render.py", HERE / "validate.py", HERE / "run_pipeline.sh", HERE / "README.md"]
    data = {
        "schema": "citysim.world-art.ground-ecology-family.v1",
        "familyId": "greenworks-nursery-ground-ecology",
        "status": "source-only-not-live",
        "assetCount": len(CONFIG["assets"]),
        "canonicalViewCount": len(CONFIG["assets"]) * len(VIEWS),
        "previewCount": len(CONFIG["preview"]["dimensions"]),
        "contract": {
            "grid": CONFIG["grid"], "canvas": CONFIG["canvas"], "cameraRig": CONFIG["cameraRig"],
            "lighting": CONFIG["lighting"], "postRenderCompensation": "none",
        },
        "provenance": CONFIG["provenance"],
        "members": [{"assetId": asset["assetId"], "assetKind": asset["assetKind"], "manifest": artifact_info(path)} for asset, path in zip(CONFIG["assets"], asset_manifests)],
        "previewManifest": artifact_info(preview_manifest),
        "sourceArtifacts": [artifact_info(path) for path in source_paths],
    }
    path = HERE / "family-manifest.json"
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return path


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
        render_paths = render_views(scene, cameras, asset["assetId"], output_dir / "renders")
        sheet_path = contact_sheet(render_paths, output_dir / f"{asset['assetId']}_contact-sheet.png")
        manifests.append(write_asset_manifest(asset, [blend_path, *render_paths, sheet_path]))
    preview_manifest = build_preview()
    write_family_manifest(manifests, preview_manifest)
    print("GROUND_ECOLOGY_FOUR_VIEW_RENDER_PASS assets=7 views=28 previews=2")


if __name__ == "__main__":
    main()
