#!/usr/bin/env python3
"""Build the original CitySim Four-View neighborhood-service family."""

from __future__ import annotations

import hashlib
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


def cone(root, name, location, radius1, radius2, depth, mat, vertices=24):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    apply(obj)
    soften(obj, 0.014, 1)
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


def gable_roof(root, name, location, dimensions, mat, ridge_axis="X"):
    width, depth, height = dimensions
    if ridge_axis == "X":
        vertices = [
            (-width / 2, -depth / 2, 0), (width / 2, -depth / 2, 0),
            (width / 2, depth / 2, 0), (-width / 2, depth / 2, 0),
            (-width / 2, 0, height), (width / 2, 0, height),
        ]
        faces = [(0, 1, 5, 4), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)]
    else:
        vertices = [
            (-width / 2, -depth / 2, 0), (width / 2, -depth / 2, 0),
            (width / 2, depth / 2, 0), (-width / 2, depth / 2, 0),
            (0, -depth / 2, height), (0, depth / 2, height),
        ]
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
        camera.location = (
            horizontal * math.sin(azimuth),
            horizontal * math.cos(azimuth),
            rig["distance"] * math.sin(elevation),
        )
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
    for index, (x, y) in enumerate(((-1.55, 1.45), (1.55, 1.45))):
        cylinder(root, f"{prefix}Planter{index}", (x, y, 0.20), 0.24, 0.22, mats["walk"], vertices=16)
        sphere(root, f"{prefix}Shrub{index}", (x, y, 0.53), (0.31, 0.28, 0.38), mats["leaf"])


def add_windows(root, prefix, mats, front_y, rear_y, side_xs, z=1.05):
    for index, x in enumerate(side_xs):
        box(root, f"{prefix}FrontWindow{index}", (x, front_y, z), (0.42, 0.055, 0.48), mats["glass"], edge=0.012)
        box(root, f"{prefix}FrontLintel{index}", (x, front_y - 0.025, z + 0.30), (0.52, 0.065, 0.10), mats["stone"], edge=0.008)
        box(root, f"{prefix}RearWindow{index}", (x, rear_y, z), (0.42, 0.055, 0.48), mats["glass"], edge=0.012)
    for index, y in enumerate((-0.52, 0.22, 0.88)):
        for x, side in ((-1.47, "West"), (1.47, "East")):
            box(root, f"{prefix}{side}Window{index}", (x, y, z), (0.055, 0.38, 0.46), mats["glass"], edge=0.012)


def fire_station(root):
    mats = common_materials("Emberline")
    mats["red"] = material("EmberlineEngineRed", (0.63, 0.12, 0.08, 1), roughness=0.52, texture_scale=7.0)
    mats["gold"] = material("EmberlineBrass", (0.78, 0.48, 0.12, 1), roughness=0.38, metallic=0.55, texture_scale=5.0)
    shared_lot(root, "Fire", mats, apron_depth=1.30)
    box(root, "FireStationPlinth", (0, 0.18, 0.18), (3.10, 2.55, 0.26), mats["walk"], edge=0.035)
    box(root, "FireStationBody", (0, 0.22, 1.02), (2.92, 2.36, 1.48), mats["brick"], edge=0.035)
    box(root, "FireStationStoneBelt", (0, 0.22, 1.38), (3.04, 2.46, 0.11), mats["stone"], edge=0.014)
    gable_roof(root, "FireStationRoof", (0, 0.22, 1.79), (3.18, 2.62, 0.62), mats["roof"], ridge_axis="X")
    # Two apparatus bays face the common frontage and remain legible in both side views.
    for bay, x in enumerate((-0.72, 0.72)):
        box(root, f"ApparatusDoor{bay}", (x, -0.985, 0.96), (1.12, 0.065, 1.30), mats["red"], edge=0.025)
        for slat, z in enumerate((0.50, 0.72, 0.94, 1.16, 1.38)):
            box(root, f"ApparatusDoor{bay}Slat{slat}", (x, -1.025, z), (1.00, 0.025, 0.035), mats["gold"], edge=0.004)
        box(root, f"BayArch{bay}", (x, -1.035, 1.66), (1.28, 0.08, 0.16), mats["stone"], edge=0.018)
    for index, x in enumerate((-0.72, 0.72)):
        box(root, f"RearFireWindow{index}", (x, 1.415, 1.04), (0.52, 0.055, 0.55), mats["glass"], edge=0.012)
    for index, y in enumerate((-0.35, 0.45, 1.02)):
        for x, side in ((-1.49, "West"), (1.49, "East")):
            box(root, f"{side}FireWindow{index}", (x, y, 1.05), (0.055, 0.44, 0.48), mats["glass"], edge=0.012)
    # Hose-drying tower gives the station a distinct four-view silhouette.
    box(root, "HoseTower", (-1.05, 0.72, 2.05), (0.72, 0.72, 2.65), mats["brick"], edge=0.035)
    box(root, "HoseTowerCornice", (-1.05, 0.72, 3.35), (0.84, 0.84, 0.16), mats["stone"], edge=0.018)
    gable_roof(root, "HoseTowerRoof", (-1.05, 0.72, 3.43), (0.90, 0.90, 0.46), mats["roof"], ridge_axis="X")
    for side, location, dimensions in (
        ("Front", (-1.05, 0.345, 2.30), (0.28, 0.055, 0.58)),
        ("Rear", (-1.05, 1.095, 2.30), (0.28, 0.055, 0.58)),
        ("West", (-1.425, 0.72, 2.30), (0.055, 0.28, 0.58)),
        ("East", (-0.675, 0.72, 2.30), (0.055, 0.28, 0.58)),
    ):
        box(root, f"HoseTower{side}Louver", location, dimensions, mats["metal"], edge=0.008)
    cylinder(root, "FireHydrant", (1.42, -1.45, 0.42), 0.12, 0.58, mats["red"], vertices=16)
    cylinder(root, "FireHydrantCap", (1.42, -1.45, 0.74), 0.18, 0.12, mats["gold"], vertices=16)
    for index, x in enumerate((-1.30, 1.30)):
        cylinder(root, f"FireBollard{index}", (x, -1.36, 0.38), 0.07, 0.62, mats["gold"], vertices=16)
    root["assetKind"] = "fire-station"


def police_station(root):
    mats = common_materials("Bluecrest")
    mats["blue"] = material("BluecrestCivicBlue", (0.10, 0.25, 0.38, 1), roughness=0.52, texture_scale=7.0)
    mats["bronze"] = material("BluecrestBronze", (0.50, 0.31, 0.14, 1), roughness=0.38, metallic=0.58, texture_scale=5.0)
    shared_lot(root, "Police", mats, apron_depth=0.92)
    box(root, "PoliceStationPlinth", (0, 0.18, 0.18), (3.12, 2.62, 0.26), mats["walk"], edge=0.035)
    box(root, "PoliceStationBody", (0, 0.20, 1.02), (2.94, 2.42, 1.48), mats["brick"], edge=0.035)
    box(root, "PoliceLimestoneBase", (0, 0.20, 0.52), (3.04, 2.52, 0.34), mats["stone"], edge=0.020)
    box(root, "PoliceCornice", (0, 0.20, 1.75), (3.08, 2.56, 0.18), mats["stone"], edge=0.022)
    box(root, "PoliceRoof", (0, 0.20, 1.92), (3.18, 2.66, 0.22), mats["roof"], edge=0.035)
    # Civic entrance projects from the exact building footprint, with no render-space compensation.
    box(root, "PoliceEntryPavilion", (0, -1.15, 1.15), (1.16, 0.42, 1.70), mats["stone"], edge=0.028)
    box(root, "PoliceEntryDoor", (0, -1.385, 0.92), (0.52, 0.055, 1.02), mats["blue"], edge=0.018)
    for index, x in enumerate((-0.44, 0.44)):
        cylinder(root, f"PoliceEntryColumn{index}", (x, -1.40, 1.12), 0.105, 1.56, mats["stone"], vertices=20)
        box(root, f"PoliceColumnBase{index}", (x, -1.40, 0.34), (0.26, 0.26, 0.14), mats["stone"], edge=0.012)
    box(root, "PoliceEntryCanopy", (0, -1.40, 1.92), (1.25, 0.62, 0.16), mats["roof"], edge=0.022)
    # A raised bronze shield reads as a civic crest rather than signage text.
    sphere(root, "PoliceShieldCrest", (0, -1.735, 1.54), (0.23, 0.045, 0.29), mats["bronze"], subdivisions=2)
    for index, x in enumerate((-1.03, -0.58, 0.58, 1.03)):
        box(root, f"PoliceFrontWindow{index}", (x, -1.025, 1.10), (0.30, 0.055, 0.52), mats["glass"], edge=0.012)
    for index, x in enumerate((-1.02, -0.34, 0.34, 1.02)):
        box(root, f"PoliceRearWindow{index}", (x, 1.435, 1.08), (0.38, 0.055, 0.52), mats["glass"], edge=0.012)
    for side, x in (("West", -1.495), ("East", 1.495)):
        for index, y in enumerate((-0.50, 0.22, 0.90)):
            box(root, f"Police{side}Window{index}", (x, y, 1.08), (0.055, 0.38, 0.50), mats["glass"], edge=0.012)
    # Rooftop communications mast and symmetric radio panels remain coherent in all views.
    cylinder(root, "PoliceMast", (0.92, 0.56, 2.72), 0.045, 1.55, mats["metal"], vertices=12)
    for ring, z in enumerate((2.24, 2.58, 2.92)):
        cylinder(root, f"PoliceMastRing{ring}", (0.92, 0.56, z), 0.11, 0.035, mats["bronze"], vertices=12)
    beam(root, "PoliceAntennaBraceA", (0.62, 0.38, 2.03), (0.92, 0.56, 2.38), 0.035, mats["metal"])
    beam(root, "PoliceAntennaBraceB", (1.22, 0.38, 2.03), (0.92, 0.56, 2.38), 0.035, mats["metal"])
    for index, x in enumerate((-1.25, 1.25)):
        box(root, f"PoliceBenchSeat{index}", (x, -1.52, 0.38), (0.72, 0.24, 0.10), mats["wood"], edge=0.018)
        for leg, dx in enumerate((-0.25, 0.25)):
            box(root, f"PoliceBench{index}Leg{leg}", (x + dx, -1.52, 0.22), (0.07, 0.07, 0.28), mats["metal"], edge=0.008)
    root["assetKind"] = "police-station"


def school(root):
    mats = common_materials("Maplewood")
    mats["green"] = material("MaplewoodSchoolGreen", (0.12, 0.31, 0.24, 1), roughness=0.52, texture_scale=7.0)
    mats["ochre"] = material("MaplewoodPlayOchre", (0.82, 0.52, 0.13, 1), roughness=0.58, texture_scale=5.0)
    shared_lot(root, "School", mats, apron_depth=0.88)
    # Classroom wings and central hall form a readable, welcoming school footprint.
    box(root, "SchoolPlinth", (0, 0.24, 0.18), (3.20, 2.58, 0.26), mats["walk"], edge=0.035)
    box(root, "SchoolWestWing", (-0.92, 0.30, 0.92), (1.18, 2.30, 1.26), mats["brick"], edge=0.035)
    box(root, "SchoolEastWing", (0.92, 0.30, 0.92), (1.18, 2.30, 1.26), mats["brick"], edge=0.035)
    box(root, "SchoolCentralHall", (0, 0.18, 1.14), (0.78, 2.48, 1.70), mats["stone"], edge=0.035)
    gable_roof(root, "SchoolWestRoof", (-0.92, 0.30, 1.55), (1.35, 2.52, 0.47), mats["green"], ridge_axis="Y")
    gable_roof(root, "SchoolEastRoof", (0.92, 0.30, 1.55), (1.35, 2.52, 0.47), mats["green"], ridge_axis="Y")
    gable_roof(root, "SchoolCentralRoof", (0, 0.18, 1.99), (0.98, 2.68, 0.55), mats["roof"], ridge_axis="Y")
    box(root, "SchoolEntryDoor", (0, -1.085, 0.92), (0.48, 0.055, 1.00), mats["green"], edge=0.018)
    box(root, "SchoolEntryCanopy", (0, -1.30, 1.52), (0.86, 0.52, 0.16), mats["ochre"], edge=0.020)
    for index, x in enumerate((-1.20, -0.72, 0.72, 1.20)):
        box(root, f"SchoolFrontWindow{index}", (x, -0.865, 1.00), (0.30, 0.055, 0.50), mats["glass"], edge=0.012)
        box(root, f"SchoolRearWindow{index}", (x, 1.465, 1.00), (0.30, 0.055, 0.50), mats["glass"], edge=0.012)
    for side, x in (("West", -1.535), ("East", 1.535)):
        for index, y in enumerate((-0.48, 0.22, 0.92)):
            box(root, f"School{side}Window{index}", (x, y, 1.00), (0.055, 0.36, 0.48), mats["glass"], edge=0.012)
    # Cupola and school bell provide an unmistakable civic silhouette.
    box(root, "SchoolCupola", (0, 0.18, 2.70), (0.52, 0.52, 0.62), mats["stone"], edge=0.025)
    for side, location, dimensions in (
        ("Front", (0, -0.095, 2.72), (0.24, 0.055, 0.30)),
        ("Rear", (0, 0.455, 2.72), (0.24, 0.055, 0.30)),
        ("West", (-0.275, 0.18, 2.72), (0.055, 0.24, 0.30)),
        ("East", (0.275, 0.18, 2.72), (0.055, 0.24, 0.30)),
    ):
        box(root, f"Cupola{side}Opening", location, dimensions, mats["green"], edge=0.008)
    gable_roof(root, "SchoolCupolaRoof", (0, 0.18, 3.01), (0.72, 0.72, 0.38), mats["green"], ridge_axis="X")
    sphere(root, "SchoolBell", (0, -0.11, 2.70), (0.12, 0.06, 0.13), mats["ochre"], subdivisions=2)
    # Small play yard details sit within the same lot and reinforce neighborhood scale.
    for index, x in enumerate((-1.18, -0.72)):
        cylinder(root, f"PlayPost{index}", (x, 1.55, 0.48), 0.045, 0.78, mats["green"], vertices=12)
    beam(root, "PlayCrossbar", (-1.18, 1.55, 0.86), (-0.72, 1.55, 0.86), 0.055, mats["green"])
    for index, x in enumerate((-1.08, -0.82)):
        beam(root, f"SwingChainA{index}", (x, 1.55, 0.82), (x - 0.06, 1.55, 0.42), 0.018, mats["metal"])
        box(root, f"SwingSeat{index}", (x - 0.06, 1.55, 0.38), (0.22, 0.14, 0.045), mats["wood"], edge=0.006)
    cylinder(root, "SchoolFlagPole", (1.56, -1.35, 1.22), 0.035, 2.25, mats["metal"], vertices=12)
    box(root, "SchoolFlag", (1.42, -1.35, 1.98), (0.32, 0.025, 0.20), mats["ochre"], edge=0.004)
    root["assetKind"] = "school"


BUILDERS = {
    "emberline_fire_station": fire_station,
    "bluecrest_police_station": police_station,
    "maplewood_neighborhood_school": school,
}


def build_asset(asset):
    scene = reset("CitySimService_" + asset["assetId"])
    configure_scene(scene, transparent=True)
    root = asset_root(asset)
    BUILDERS[asset["assetId"]](root)
    cameras = canonical_rig(scene)
    return scene, root, cameras


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
                rgba[pixel : pixel + 4] = bytes((37, 43, 43, 255))
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
                                rgba[pixel : pixel + 4] = bytes((238, 213, 164, 255))
    encode_rgba_png(output_path, sheet_width, sheet_height, bytes(rgba))
    return output_path


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def alpha_metadata(path):
    width, height, rgba = decode_rgba_png(path)
    pixels = [(index % width, index // width, alpha) for index, alpha in enumerate(rgba[3::4]) if alpha]
    if not pixels:
        raise RuntimeError(f"EMPTY_ALPHA: {path}")
    xs = [pixel[0] for pixel in pixels]
    ys = [pixel[1] for pixel in pixels]
    min_x, max_x, min_y, max_y = min(xs), max(xs), min(ys), max(ys)
    pivot_x, pivot_y = CONFIG["canvas"]["footprintPivotPixel"]
    pivot_alpha = rgba[(pivot_y * width + pivot_x) * 4 + 3]
    return {
        "boundsTopOrigin": {
            "minX": min_x, "minY": min_y, "maxX": max_x, "maxY": max_y,
            "width": max_x - min_x + 1, "height": max_y - min_y + 1,
        },
        "opaquePixelCount": len(pixels),
        "lowestOpaqueRowTopOrigin": max_y,
        "pivotPixelAlpha": pivot_alpha,
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
        "schema": "citysim.world-art.service-four-view-asset.v1",
        "pipelineSchema": CONFIG["schema"],
        "assetId": asset["assetId"],
        "description": asset["description"],
        "serviceRole": asset["serviceRole"],
        "status": "source-only-not-live",
        "liveAsset": False,
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "cedarMarketReused": False,
        "cameraOrder": [view["name"] for view in VIEWS],
        "grid": CONFIG["grid"],
        "canvas": CONFIG["canvas"],
        "cameraRig": CONFIG["cameraRig"],
        "lightingConvention": CONFIG["lighting"],
        "root": CONFIG["root"],
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
    mesh_matrices = {obj: obj.matrix_world.copy() for obj in imported if obj.type == "MESH"}
    placement = bpy.data.objects.new(placement_name, None)
    bpy.context.collection.objects.link(placement)
    placement.location = location
    mesh_count = 0
    for obj in imported:
        if obj.type != "MESH":
            continue
        obj.parent = placement
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = mesh_matrices[obj]
        mesh_count += 1
    for obj in imported:
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    placement["sourceBlend"] = str(source.relative_to(BLENDER_ROOT))
    placement["gridPlacement"] = list(location)
    placement["perAssetTransformCompensation"] = "none"
    return placement, mesh_count


def preview_camera_and_light(scene):
    distance = 40.0
    elevation = math.radians(30.0)
    azimuth = math.radians(45.0)
    horizontal = distance * math.cos(elevation)
    data = bpy.data.cameras.new("camNE_BlockPreview")
    data.type = "ORTHO"
    data.ortho_scale = 12.8
    camera = bpy.data.objects.new("camNE_BlockPreview", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation))
    point_at(camera, Vector((-1.0, 2.0, 0.85)))
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
    scene = reset("CitySimNeighborhoodServicesBlock")
    configure_scene(scene, transparent=False)
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    ground = material("ServicesBlockGround", (0.28, 0.37, 0.23, 1), texture_scale=6.0, bump=0.11)
    asphalt = material("ServicesBlockAsphalt", (0.17, 0.20, 0.20, 1), texture_scale=20.0, bump=0.16)
    curb = material("ServicesBlockCurb", (0.65, 0.58, 0.48, 1), texture_scale=11.0, bump=0.12)
    stripe = material("ServicesBlockCenterLine", (0.83, 0.57, 0.17, 1), roughness=0.62, texture_scale=4.0)
    box(root, "NeighborhoodGroundPlane", (-1, 2, -0.24), (16, 8, 0.24), ground, edge=0.10)
    box(root, "AxisAlignedServiceRoad", (-1, 0, -0.075), (16, 2, 0.10), asphalt, edge=0.025)
    for y in (-1.08, 1.08):
        box(root, f"RoadCurb{y}", (-1, y, 0.005), (16, 0.16, 0.14), curb, edge=0.018)
    for x in (-7, -5, -3, -1, 1, 3, 5):
        box(root, f"RoadStripe{x}", (x, 0, -0.005), (0.90, 0.08, 0.035), stripe, edge=0.006)

    layout = [
        (CONFIG["assets"][0], (-5.0, 3.0, 0.0)),
        (CONFIG["assets"][1], (-1.0, 3.0, 0.0)),
        (CONFIG["assets"][2], (3.0, 3.0, 0.0)),
    ]
    placements = []
    for asset, location in layout:
        source = HERE / asset["assetId"] / f"{asset['assetId']}.blend"
        if not source.is_file():
            raise RuntimeError(f"MISSING_PREVIEW_SOURCE: {source}")
        _, mesh_count = append_mesh_asset(source, f"Placement_{asset['assetId']}", location)
        placements.append({
            "assetId": asset["assetId"],
            "serviceRole": asset["serviceRole"],
            "originWorld": list(location),
            "footprintTiles": asset["footprintTiles"],
            "sourceBlend": source.relative_to(BLENDER_ROOT).as_posix(),
            "sourceBlendSha256": sha256(source),
            "meshCount": mesh_count,
            "perAssetTransformCompensation": "none",
        })
    preview_camera_and_light(scene)
    preview_dir = HERE / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    blend_path = preview_dir / "neighborhood-services-block.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = preview_dir / f"neighborhood-services-block-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    manifest = {
        "schema": "citysim.world-art.neighborhood-services-preview.v1",
        "status": "source-only-review-evidence",
        "liveAsset": False,
        "acceptedFamilyContractOnly": True,
        "cedarMarketReused": False,
        "camera": {"projection": "orthographic", "azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none"},
        "grid": CONFIG["grid"],
        "lightingConvention": CONFIG["lighting"],
        "placements": placements,
        "artifacts": [artifact_info(blend_path), *[artifact_info(path) for path in outputs]],
    }
    path = preview_dir / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


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
        write_asset_manifest(asset, [blend_path, *render_paths, sheet_path])
    build_preview()
    print("SERVICE_FOUR_VIEW_RENDER_PASS assets=3 views=12 previews=2")


if __name__ == "__main__":
    main()
