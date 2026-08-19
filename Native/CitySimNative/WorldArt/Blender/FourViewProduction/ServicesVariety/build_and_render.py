#!/usr/bin/env python3
"""Build original CitySim four-view service-building variants."""

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


def material(name, color, roughness=0.72, metallic=0.0, texture_scale=8.0, bump=0.10):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    shader = nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if texture_scale > 0:
        coordinates = nodes.new("ShaderNodeTexCoord")
        noise = nodes.new("ShaderNodeTexNoise")
        ramp = nodes.new("ShaderNodeValToRGB")
        bump_node = nodes.new("ShaderNodeBump")
        noise.inputs["Scale"].default_value = texture_scale
        noise.inputs["Detail"].default_value = 3.0
        noise.inputs["Roughness"].default_value = 0.62
        ramp.color_ramp.elements[0].position = 0.28
        ramp.color_ramp.elements[0].color = tuple(max(0.0, c * 0.72) for c in color[:3]) + (color[3],)
        ramp.color_ramp.elements[1].position = 0.75
        ramp.color_ramp.elements[1].color = tuple(min(1.0, c * 1.14 + 0.018) for c in color[:3]) + (color[3],)
        bump_node.inputs["Strength"].default_value = bump
        bump_node.inputs["Distance"].default_value = 0.035
        links.new(coordinates.outputs["Generated"], noise.inputs["Vector"])
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], shader.inputs["Base Color"])
        links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], shader.inputs["Normal"])
    return mat


def apply(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def soften(obj, width=0.025, segments=2):
    modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def box(root, name, location, dimensions, mat, edge=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    apply(obj)
    if edge:
        soften(obj, edge)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def cylinder(root, name, location, radius, depth, mat, vertices=24, rotation=(0, 0, 0), edge=0.012):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    apply(obj)
    if edge:
        soften(obj, edge, 1)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def sphere(root, name, location, scale, mat, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    apply(obj)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def cone(root, name, location, radius1, radius2, depth, mat, vertices=24):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    apply(obj)
    soften(obj, 0.014, 1)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def gable_roof(root, name, location, dimensions, mat, ridge_axis="X"):
    width, depth, height = dimensions
    if ridge_axis == "X":
        vertices = [(-width/2, -depth/2, 0), (width/2, -depth/2, 0), (width/2, depth/2, 0), (-width/2, depth/2, 0), (-width/2, 0, height), (width/2, 0, height)]
        faces = [(0, 1, 5, 4), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)]
    else:
        vertices = [(-width/2, -depth/2, 0), (width/2, -depth/2, 0), (width/2, depth/2, 0), (-width/2, depth/2, 0), (0, -depth/2, height), (0, depth/2, height)]
        faces = [(0, 1, 4), (3, 5, 2), (0, 4, 5, 3), (1, 2, 5, 4), (0, 3, 2, 1)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    soften(obj, 0.025, 1)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def beam(root, name, start, end, width, mat):
    a, b = Vector(start), Vector(end)
    direction = b - a
    bpy.ops.mesh.primitive_cube_add(size=1, location=(a + b) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (width, width, direction.length)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    apply(obj)
    soften(obj, min(width * 0.18, 0.015), 1)
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
    scene.render.engine = CONFIG["toolchain"]["renderEngine"]
    scene.render.resolution_x = CONFIG["canvas"]["width"]
    scene.render.resolution_y = CONFIG["canvas"]["height"]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = transparent
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("CitySimWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = CONFIG["lighting"]["worldColor"]
    background.inputs["Strength"].default_value = CONFIG["lighting"]["worldStrength"]
    scene["pipelineSchema"] = CONFIG["schema"]
    scene["postRenderCompensation"] = "none"
    scene["projectedTilePixels"] = CONFIG["grid"]["projectedTilePixels"]


def point_at(obj, target=Vector((0, 0, 0))):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def canonical_rig(scene):
    cameras = []
    rig = CONFIG["cameraRig"]
    elevation = math.radians(CONFIG["grid"]["elevationDegrees"])
    horizontal = rig["distance"] * math.cos(elevation)
    for view in VIEWS:
        azimuth = math.radians(view["azimuthDegrees"])
        data = bpy.data.cameras.new(view["name"])
        data.type = "ORTHO"
        data.ortho_scale = rig["orthoScale"]
        data.shift_y = rig["shiftY"]
        camera = bpy.data.objects.new(view["name"], data)
        bpy.context.collection.objects.link(camera)
        camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), rig["distance"] * math.sin(elevation))
        point_at(camera)
        cameras.append(camera)
    lighting = CONFIG["lighting"]
    data = bpy.data.lights.new(lighting["name"], lighting["type"])
    data.energy = lighting["energy"]
    data.shape = "DISK"
    data.size = lighting["size"]
    data.color = lighting["color"]
    light = bpy.data.objects.new(lighting["name"], data)
    bpy.context.collection.objects.link(light)
    light.location = lighting["location"]
    point_at(light)
    scene.camera = cameras[0]
    return cameras


def asset_root(asset):
    root = bpy.data.objects.new("AssetRoot", None)
    bpy.context.collection.objects.link(root)
    pivot = bpy.data.objects.new("FootprintPivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.parent = root
    pivot.empty_display_type = "CIRCLE"
    pivot.empty_display_size = 0.2
    root["assetId"] = asset["assetId"]
    root["serviceRole"] = asset["serviceRole"]
    root["sourcePixelsReused"] = False
    root["cedarMarketReused"] = False
    root["liveAsset"] = False
    root["fixedObjectScale"] = True
    root["postRenderCompensation"] = "none"
    return root


def common_materials(prefix):
    return {
        "grass": material(prefix + "SageLawn", (0.29, 0.39, 0.23, 1), texture_scale=6.0, bump=0.11),
        "walk": material(prefix + "WarmConcrete", (0.62, 0.55, 0.45, 1), texture_scale=11.0, bump=0.14),
        "brick": material(prefix + "WarmBrick", (0.55, 0.25, 0.17, 1), texture_scale=15.0, bump=0.18),
        "stone": material(prefix + "HoneyLimestone", (0.84, 0.72, 0.52, 1), texture_scale=9.0, bump=0.11),
        "roof": material(prefix + "DeepSlate", (0.13, 0.22, 0.23, 1), roughness=0.55, texture_scale=18.0, bump=0.18),
        "glass": material(prefix + "WindowGlass", (0.18, 0.40, 0.44, 1), roughness=0.24, texture_scale=0),
        "metal": material(prefix + "WarmIron", (0.17, 0.19, 0.18, 1), roughness=0.40, metallic=0.62, texture_scale=7.0),
        "leaf": material(prefix + "JuniperLeaf", (0.18, 0.36, 0.16, 1), texture_scale=6.0),
        "wood": material(prefix + "WarmWood", (0.39, 0.20, 0.11, 1), texture_scale=9.0, bump=0.14),
    }


def shared_lot(root, prefix, mats, apron_depth=1.05):
    lot = box(root, prefix + "LotGround", (0, 0, -0.10), (4, 4, 0.20), mats["grass"], edge=0.055)
    lot["worldFootprintTiles"] = [2, 2]
    lot["exactWorldFootprint"] = [4.0, 4.0]
    box(root, prefix + "FrontWalk", (0, -1.48, 0.025), (3.72, apron_depth, 0.08), mats["walk"], edge=0.025)
    for index, (x, y) in enumerate(((-1.56, 1.48), (1.56, 1.48))):
        cylinder(root, f"{prefix}Planter{index}", (x, y, 0.20), 0.24, 0.22, mats["walk"], vertices=16)
        sphere(root, f"{prefix}Shrub{index}", (x, y, 0.53), (0.31, 0.28, 0.38), mats["leaf"])


def framed_window(root, name, location, dimensions, facing, mats):
    box(root, name, location, dimensions, mats["glass"], edge=0.010)
    x, y, z = location
    w, d, h = dimensions
    if facing == "front":
        box(root, name + "Lintel", (x, y - 0.025, z + h/2 + 0.07), (w + 0.12, d + 0.02, 0.10), mats["stone"], edge=0.006)
    elif facing == "rear":
        box(root, name + "Lintel", (x, y + 0.025, z + h/2 + 0.07), (w + 0.12, d + 0.02, 0.10), mats["stone"], edge=0.006)


def harborwatch_police(root):
    mats = common_materials("Harborwatch")
    mats["blue"] = material("HarborwatchBeaconBlue", (0.08, 0.25, 0.43, 1), roughness=0.34, texture_scale=5.0)
    mats["bronze"] = material("HarborwatchCivicBronze", (0.52, 0.32, 0.13, 1), roughness=0.38, metallic=0.58, texture_scale=5.0)
    shared_lot(root, "Harborwatch", mats, 0.94)
    box(root, "PrecinctPlinth", (0, 0.22, 0.17), (3.28, 2.66, 0.24), mats["walk"], edge=0.035)
    box(root, "PrecinctWestWing", (-0.91, 0.28, 0.98), (1.24, 2.32, 1.46), mats["brick"], edge=0.035)
    box(root, "PrecinctEastWing", (0.91, 0.28, 0.98), (1.24, 2.32, 1.46), mats["brick"], edge=0.035)
    box(root, "PrecinctCentralTower", (0, 0.24, 1.48), (0.76, 2.44, 2.42), mats["stone"], edge=0.035)
    box(root, "PrecinctWingBelt", (0, 0.28, 1.36), (3.18, 2.42, 0.12), mats["stone"], edge=0.014)
    box(root, "PrecinctWestRoof", (-0.91, 0.28, 1.76), (1.36, 2.48, 0.20), mats["roof"], edge=0.035)
    box(root, "PrecinctEastRoof", (0.91, 0.28, 1.76), (1.36, 2.48, 0.20), mats["roof"], edge=0.035)
    gable_roof(root, "PrecinctTowerRoof", (0, 0.24, 2.70), (0.94, 2.62, 0.48), mats["roof"], ridge_axis="Y")
    box(root, "PrecinctEntryDoor", (0, -1.005, 0.91), (0.46, 0.055, 1.02), mats["blue"], edge=0.015)
    box(root, "PrecinctEntryCanopy", (0, -1.26, 1.52), (0.88, 0.60, 0.15), mats["bronze"], edge=0.018)
    for index, x in enumerate((-0.34, 0.34)):
        cylinder(root, f"PrecinctEntryLanternPost{index}", (x, -1.325, 1.30), 0.035, 0.28, mats["bronze"], vertices=12)
        sphere(root, f"PrecinctEntryLanternGlow{index}", (x, -1.325, 1.47), (0.075, 0.075, 0.10), mats["stone"], subdivisions=2)
    for index, x in enumerate((-1.18, -0.70, 0.70, 1.18)):
        framed_window(root, f"PrecinctFrontWindow{index}", (x, -0.90, 1.04), (0.30, 0.055, 0.52), "front", mats)
        framed_window(root, f"PrecinctRearWindow{index}", (x, 1.46, 1.04), (0.30, 0.055, 0.52), "rear", mats)
    for side, x in (("West", -1.55), ("East", 1.55)):
        for index, y in enumerate((-0.40, 0.32, 1.00)):
            box(root, f"Precinct{side}Window{index}", (x, y, 1.05), (0.055, 0.36, 0.48), mats["glass"], edge=0.010)
    for side, x in (("West", -0.405), ("East", 0.405)):
        for index, z in enumerate((1.62, 2.16)):
            box(root, f"Tower{side}Window{index}", (x, -0.48, z), (0.055, 0.42, 0.38), mats["blue"], edge=0.010)
    cylinder(root, "BlueBeaconBase", (0, 0.24, 3.28), 0.19, 0.12, mats["bronze"], vertices=20)
    sphere(root, "BlueBeaconLens", (0, 0.24, 3.42), (0.17, 0.17, 0.20), mats["blue"], subdivisions=2)
    cylinder(root, "PrecinctRadioMast", (1.04, 0.60, 2.55), 0.035, 1.34, mats["metal"], vertices=12)
    for ring, z in enumerate((2.12, 2.44, 2.78)):
        cylinder(root, f"PrecinctRadioRing{ring}", (1.04, 0.60, z), 0.10, 0.030, mats["bronze"], vertices=12)
    for index, x in enumerate((-1.20, 1.20)):
        box(root, f"PrecinctBenchSeat{index}", (x, -1.52, 0.38), (0.62, 0.22, 0.10), mats["wood"], edge=0.014)
        for leg, dx in enumerate((-0.20, 0.20)):
            box(root, f"PrecinctBench{index}Leg{leg}", (x + dx, -1.52, 0.22), (0.06, 0.06, 0.28), mats["metal"], edge=0.006)
    root["assetKind"] = "police-station"


def lantern_gate_fire(root):
    mats = common_materials("LanternGate")
    mats["red"] = material("LanternGateEngineRed", (0.65, 0.11, 0.07, 1), roughness=0.50, texture_scale=7.0)
    mats["gold"] = material("LanternGateBrass", (0.79, 0.49, 0.12, 1), roughness=0.36, metallic=0.57, texture_scale=5.0)
    shared_lot(root, "LanternGate", mats, 1.30)
    box(root, "FireHousePlinth", (0, 0.20, 0.17), (3.34, 2.64, 0.24), mats["walk"], edge=0.035)
    box(root, "FireHouseMainBody", (0, 0.22, 1.02), (3.14, 2.42, 1.48), mats["brick"], edge=0.035)
    box(root, "FireHouseStoneBase", (0, 0.22, 0.46), (3.24, 2.52, 0.28), mats["stone"], edge=0.018)
    box(root, "FireHouseCornice", (0, 0.22, 1.74), (3.26, 2.54, 0.16), mats["stone"], edge=0.020)
    box(root, "FireHouseFlatRoof", (0, 0.22, 1.90), (3.30, 2.58, 0.20), mats["roof"], edge=0.032)
    for bay, x in enumerate((-1.02, 0, 1.02)):
        box(root, f"FireBayDoor{bay}", (x, -1.015, 0.96), (0.82, 0.065, 1.22), mats["red"], edge=0.020)
        for slat, z in enumerate((0.52, 0.72, 0.92, 1.12, 1.32)):
            box(root, f"FireBay{bay}Slat{slat}", (x, -1.055, z), (0.72, 0.025, 0.030), mats["gold"], edge=0.004)
        box(root, f"FireBayLintel{bay}", (x, -1.065, 1.63), (0.94, 0.08, 0.14), mats["stone"], edge=0.012)
    for index, x in enumerate((-1.12, -0.38, 0.38, 1.12)):
        framed_window(root, f"FireRearWindow{index}", (x, 1.45, 1.04), (0.34, 0.055, 0.50), "rear", mats)
    for side, x in (("West", -1.60), ("East", 1.60)):
        for index, y in enumerate((-0.36, 0.38, 0.98)):
            box(root, f"Fire{side}Window{index}", (x, y, 1.03), (0.055, 0.34, 0.46), mats["glass"], edge=0.010)
    box(root, "RearHoseTower", (1.08, 0.78, 2.20), (0.78, 0.78, 2.86), mats["brick"], edge=0.035)
    box(root, "RearHoseTowerBelt", (1.08, 0.78, 3.28), (0.90, 0.90, 0.14), mats["stone"], edge=0.015)
    gable_roof(root, "RearHoseTowerRoof", (1.08, 0.78, 3.61), (1.02, 1.02, 0.52), mats["roof"], ridge_axis="X")
    for side, location, dimensions in (
        ("Front", (1.08, 0.365, 2.45), (0.30, 0.055, 0.64)),
        ("Rear", (1.08, 1.195, 2.45), (0.30, 0.055, 0.64)),
        ("West", (0.665, 0.78, 2.45), (0.055, 0.30, 0.64)),
        ("East", (1.495, 0.78, 2.45), (0.055, 0.30, 0.64)),
    ):
        box(root, f"HoseTower{side}Louver", location, dimensions, mats["metal"], edge=0.008)
    cylinder(root, "RoofSirenPost", (-0.88, 0.50, 2.34), 0.045, 0.72, mats["metal"], vertices=12)
    cone(root, "RoofSirenHorn", (-0.88, 0.50, 2.72), 0.22, 0.08, 0.42, mats["red"], vertices=20)
    cylinder(root, "FireHydrant", (-1.48, -1.48, 0.42), 0.12, 0.58, mats["red"], vertices=16)
    cylinder(root, "FireHydrantCap", (-1.48, -1.48, 0.74), 0.18, 0.12, mats["gold"], vertices=16)
    for index, x in enumerate((-1.36, 1.36)):
        cylinder(root, f"FireBollard{index}", (x, -1.42, 0.38), 0.07, 0.62, mats["gold"], vertices=16)
    root["assetKind"] = "fire-station"


def oakridge_school(root):
    mats = common_materials("Oakridge")
    mats["green"] = material("OakridgeSchoolGreen", (0.12, 0.31, 0.24, 1), roughness=0.52, texture_scale=7.0)
    mats["ochre"] = material("OakridgePlayOchre", (0.82, 0.52, 0.13, 1), roughness=0.58, texture_scale=5.0)
    shared_lot(root, "Oakridge", mats, 0.86)
    box(root, "SchoolPlinth", (0, 0.26, 0.17), (3.30, 2.70, 0.24), mats["walk"], edge=0.035)
    box(root, "SchoolRearHall", (0, 0.78, 0.96), (3.10, 1.12, 1.38), mats["brick"], edge=0.035)
    box(root, "SchoolWestWing", (-1.02, 0.02, 0.91), (1.02, 1.58, 1.28), mats["brick"], edge=0.035)
    box(root, "SchoolEastWing", (1.02, 0.02, 0.91), (1.02, 1.58, 1.28), mats["brick"], edge=0.035)
    box(root, "SchoolEntryHall", (0, 0.20, 1.20), (0.82, 2.18, 1.82), mats["stone"], edge=0.035)
    gable_roof(root, "SchoolRearRoof", (0, 0.78, 1.65), (3.28, 1.30, 0.46), mats["green"], ridge_axis="X")
    gable_roof(root, "SchoolWestRoof", (-1.02, 0.02, 1.55), (1.18, 1.78, 0.43), mats["green"], ridge_axis="Y")
    gable_roof(root, "SchoolEastRoof", (1.02, 0.02, 1.55), (1.18, 1.78, 0.43), mats["green"], ridge_axis="Y")
    gable_roof(root, "SchoolEntryRoof", (0, 0.20, 2.11), (1.00, 2.36, 0.50), mats["roof"], ridge_axis="Y")
    box(root, "SchoolEntryDoor", (0, -0.915, 0.92), (0.48, 0.055, 1.00), mats["green"], edge=0.016)
    box(root, "SchoolEntryCanopy", (0, -1.20, 1.50), (0.94, 0.62, 0.15), mats["ochre"], edge=0.018)
    for index, x in enumerate((-0.35, 0.35)):
        cylinder(root, f"SchoolEntryColumn{index}", (x, -1.22, 0.92), 0.075, 1.08, mats["stone"], vertices=18)
        box(root, f"SchoolEntryColumnBase{index}", (x, -1.22, 0.34), (0.20, 0.20, 0.14), mats["stone"], edge=0.010)
    for index, x in enumerate((-1.30, -0.76, 0.76, 1.30)):
        framed_window(root, f"SchoolRearWindow{index}", (x, 1.355, 1.00), (0.32, 0.055, 0.50), "rear", mats)
    for side, x in (("West", -1.55), ("East", 1.55)):
        for index, y in enumerate((-0.42, 0.16, 0.74, 1.14)):
            box(root, f"School{side}Window{index}", (x, y, 1.00), (0.055, 0.30, 0.46), mats["glass"], edge=0.010)
    for index, x in enumerate((-1.02, 1.02)):
        framed_window(root, f"SchoolCourtyardWindow{index}", (x, -0.79, 1.00), (0.34, 0.055, 0.50), "front", mats)
    box(root, "SchoolClockCupola", (0, 0.20, 2.75), (0.58, 0.58, 0.70), mats["stone"], edge=0.026)
    for side, location, dimensions in (
        ("Front", (0, -0.105, 2.78), (0.30, 0.055, 0.30)),
        ("Rear", (0, 0.505, 2.78), (0.30, 0.055, 0.30)),
        ("West", (-0.305, 0.20, 2.78), (0.055, 0.30, 0.30)),
        ("East", (0.305, 0.20, 2.78), (0.055, 0.30, 0.30)),
    ):
        box(root, f"ClockFace{side}", location, dimensions, mats["ochre"], edge=0.008)
    gable_roof(root, "SchoolClockRoof", (0, 0.20, 3.10), (0.80, 0.80, 0.42), mats["green"], ridge_axis="X")
    cylinder(root, "SchoolFlagPole", (1.58, -1.38, 1.24), 0.035, 2.30, mats["metal"], vertices=12)
    box(root, "SchoolFlag", (1.43, -1.38, 2.02), (0.34, 0.025, 0.20), mats["ochre"], edge=0.004)
    for index, x in enumerate((-1.34, -0.90)):
        cylinder(root, f"PlayPost{index}", (x, 1.58, 0.50), 0.045, 0.82, mats["green"], vertices=12)
    beam(root, "PlayCrossbar", (-1.34, 1.58, 0.90), (-0.90, 1.58, 0.90), 0.055, mats["green"])
    for index, x in enumerate((-1.24, -1.00)):
        beam(root, f"SwingChain{index}", (x, 1.58, 0.86), (x - 0.04, 1.58, 0.44), 0.018, mats["metal"])
        box(root, f"SwingSeat{index}", (x - 0.04, 1.58, 0.40), (0.20, 0.14, 0.045), mats["wood"], edge=0.006)
    root["assetKind"] = "school"


BUILDERS = {
    "harborwatch_police_precinct": harborwatch_police,
    "lantern_gate_fire_house": lantern_gate_fire,
    "oakridge_courtyard_school": oakridge_school,
}


def build_asset(asset):
    scene = reset("CitySimServicesVariety_" + asset["assetId"])
    configure_scene(scene, transparent=True)
    root = asset_root(asset)
    BUILDERS[asset["assetId"]](root)
    return scene, root, canonical_rig(scene)


def render_views(scene, cameras, asset_id, output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for camera in cameras:
        path = output_dir / f"{asset_id}_{camera.name}.png"
        scene.camera = camera
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
    sheet_width, sheet_height = width * 2 + gap, (height + label_height) * 2 + gap
    rgba = bytearray(sheet_width * sheet_height * 4)
    for index, path in enumerate(paths):
        _, _, source = decode_rgba_png(path)
        column, row = index % 2, index // 2
        origin_x, origin_y = column * (width + gap), row * (height + label_height + gap)
        for y in range(height):
            source_start = y * width * 4
            dest_start = ((origin_y + y) * sheet_width + origin_x) * 4
            rgba[dest_start:dest_start + width * 4] = source[source_start:source_start + width * 4]
        for y in range(origin_y + height, origin_y + height + label_height):
            for x in range(origin_x, origin_x + width):
                pixel = (y * sheet_width + x) * 4
                rgba[pixel:pixel + 4] = bytes((37, 43, 43, 255))
        label, scale = VIEWS[index]["name"].upper(), 3
        for char_index, char in enumerate(label):
            for row_index, bits in enumerate(FONT[char]):
                for column_index, active in enumerate(bits):
                    if active == "1":
                        for yy in range(scale):
                            for xx in range(scale):
                                x = origin_x + 12 + char_index * 18 + column_index * scale + xx
                                y = origin_y + height + 6 + row_index * scale + yy
                                pixel = (y * sheet_width + x) * 4
                                rgba[pixel:pixel + 4] = bytes((238, 213, 164, 255))
    encode_rgba_png(output_path, sheet_width, sheet_height, bytes(rgba))
    return output_path


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def alpha_metadata(path):
    width, height, rgba = decode_rgba_png(path)
    opaque = [(index % width, index // width) for index, alpha in enumerate(rgba[3::4]) if alpha]
    if not opaque:
        raise RuntimeError(f"EMPTY_ALPHA: {path}")
    xs, ys = [point[0] for point in opaque], [point[1] for point in opaque]
    pivot_x, pivot_y = CONFIG["canvas"]["footprintPivotPixel"]
    return {
        "boundsTopOrigin": {"minX": min(xs), "minY": min(ys), "maxX": max(xs), "maxY": max(ys), "width": max(xs)-min(xs)+1, "height": max(ys)-min(ys)+1},
        "opaquePixelCount": len(opaque),
        "lowestOpaqueRowTopOrigin": max(ys),
        "pivotPixelAlpha": rgba[(pivot_y * width + pivot_x) * 4 + 3],
    }


def artifact_info(path, relative_to):
    info = {"path": path.relative_to(relative_to).as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)}
    if path.suffix == ".png":
        width, height, rgba = decode_rgba_png(path)
        info.update({"dimensions": [width, height], "decodedRgbaSha256": hashlib.sha256(rgba).hexdigest(), "alpha": alpha_metadata(path)})
    return info


def write_asset_manifest(asset, artifacts, output_dir):
    data = {
        "schema": "citysim.world-art.service-variety-four-view-asset.v1",
        "pipelineSchema": CONFIG["schema"], "assetId": asset["assetId"], "description": asset["description"],
        "serviceRole": asset["serviceRole"], "status": "source-only-not-live", "liveAsset": False,
        "originalGeometry": True, "sourcePixelsReused": False, "cedarMarketReused": False,
        "cameraOrder": [view["name"] for view in VIEWS], "grid": CONFIG["grid"], "canvas": CONFIG["canvas"],
        "cameraRig": CONFIG["cameraRig"], "lightingConvention": CONFIG["lighting"], "root": CONFIG["root"],
        "postRenderCompensation": "none",
        "perViewCompensation": {"rotationDegrees": 0.0, "skew": [0.0, 0.0], "crop": False, "offsetPixels": [0, 0], "scale": 1.0},
        "contactSheetLayout": [["camNE", "camSE"], ["camSW", "camNW"]],
        "artifacts": [artifact_info(path, output_dir) for path in artifacts],
    }
    path = output_dir / "manifest.json"
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return path


def append_mesh_asset(source, placement_name, location):
    before = set(bpy.data.objects)
    with bpy.data.libraries.load(str(source), link=False) as (data_from, data_to):
        data_to.objects = list(data_from.objects)
    imported = [obj for obj in data_to.objects if obj is not None and obj not in before]
    for obj in imported:
        if not obj.users_collection:
            bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.update()
    matrices = {obj: obj.matrix_world.copy() for obj in imported if obj.type == "MESH"}
    placement = bpy.data.objects.new(placement_name, None)
    bpy.context.collection.objects.link(placement)
    placement.location = location
    mesh_count = 0
    for obj in imported:
        if obj.type != "MESH":
            continue
        obj.parent = placement
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = matrices[obj]
        mesh_count += 1
    for obj in imported:
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    placement["sourceBlend"] = str(source.relative_to(BLENDER_ROOT))
    placement["gridPlacement"] = list(location)
    placement["perAssetTransformCompensation"] = "none"
    return placement, mesh_count


def preview_camera_and_light(scene):
    distance, elevation, azimuth = 40.0, math.radians(30.0), math.radians(45.0)
    horizontal = distance * math.cos(elevation)
    data = bpy.data.cameras.new("camNE_BlockPreview")
    data.type = "ORTHO"
    data.ortho_scale = 13.2
    camera = bpy.data.objects.new("camNE_BlockPreview", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation))
    point_at(camera, Vector((-1.0, 2.0, 1.0)))
    lighting = CONFIG["lighting"]
    light_data = bpy.data.lights.new(lighting["name"], lighting["type"])
    light_data.energy, light_data.shape, light_data.size, light_data.color = lighting["energy"], "DISK", lighting["size"], lighting["color"]
    light = bpy.data.objects.new(lighting["name"], light_data)
    bpy.context.collection.objects.link(light)
    light.location = lighting["location"]
    point_at(light)
    scene.camera = camera


def build_preview(output_root=HERE, save_blend=True):
    scene = reset("CitySimServicesVarietyBlock")
    configure_scene(scene, transparent=False)
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    ground = material("ServiceVarietyGround", (0.28, 0.37, 0.23, 1), texture_scale=6.0, bump=0.11)
    asphalt = material("ServiceVarietyAsphalt", (0.17, 0.20, 0.20, 1), texture_scale=20.0, bump=0.16)
    curb = material("ServiceVarietyCurb", (0.65, 0.58, 0.48, 1), texture_scale=11.0, bump=0.12)
    stripe = material("ServiceVarietyCenterLine", (0.83, 0.57, 0.17, 1), roughness=0.62, texture_scale=4.0)
    box(root, "ServiceVarietyGroundPlane", (-1, 2, -0.24), (16, 8, 0.24), ground, edge=0.10)
    box(root, "AxisAlignedServiceRoad", (-1, 0, -0.075), (16, 2, 0.10), asphalt, edge=0.025)
    for index, y in enumerate((-1.08, 1.08)):
        box(root, f"RoadCurb{index}", (-1, y, 0.005), (16, 0.16, 0.14), curb, edge=0.018)
    for index, x in enumerate((-7, -5, -3, -1, 1, 3, 5)):
        box(root, f"RoadStripe{index}", (x, 0, -0.005), (0.90, 0.08, 0.035), stripe, edge=0.006)
    layout = [(CONFIG["assets"][0], (-5.0, 3.0, 0.0)), (CONFIG["assets"][1], (-1.0, 3.0, 0.0)), (CONFIG["assets"][2], (3.0, 3.0, 0.0))]
    placements = []
    for asset, location in layout:
        source = HERE / asset["assetId"] / f"{asset['assetId']}.blend"
        if not source.is_file():
            raise RuntimeError(f"MISSING_PREVIEW_SOURCE: {source}")
        _, mesh_count = append_mesh_asset(source, f"Placement_{asset['assetId']}", location)
        placements.append({"assetId": asset["assetId"], "serviceRole": asset["serviceRole"], "originWorld": list(location), "footprintTiles": asset["footprintTiles"], "sourceBlend": source.relative_to(BLENDER_ROOT).as_posix(), "sourceBlendSha256": sha256(source), "meshCount": mesh_count, "perAssetTransformCompensation": "none"})
    preview_camera_and_light(scene)
    preview_dir = output_root / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    blend_path = preview_dir / "service-variety-block.blend"
    if save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x, scene.render.resolution_y = width, height
        path = preview_dir / f"service-variety-block-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    if save_blend:
        artifacts = [artifact_info(blend_path, output_root), *[artifact_info(path, output_root) for path in outputs]]
        manifest = {
            "schema": "citysim.world-art.service-variety-preview.v1", "status": "source-only-review-evidence", "liveAsset": False,
            "acceptedFamilyContractOnly": True, "cedarMarketReused": False,
            "camera": {"projection": "orthographic", "azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none"},
            "grid": CONFIG["grid"], "lightingConvention": CONFIG["lighting"], "placements": placements, "artifacts": artifacts,
        }
        (preview_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return outputs


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
        write_asset_manifest(asset, [blend_path, *render_paths, sheet_path], output_dir)
    build_preview()
    print("SERVICE_VARIETY_RENDER_PASS assets=3 views=12 contactSheets=3 previews=2")


if __name__ == "__main__":
    main()
