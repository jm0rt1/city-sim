#!/usr/bin/env python3
"""Build CitySim's original Four-View density-progression source family."""

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


def box(root, name, location, dimensions, mat, rotation=(0, 0, 0), edge=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
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


def pyramid_roof(root, name, location, width, depth, height, mat):
    vertices = [
        (-width / 2, -depth / 2, 0), (width / 2, -depth / 2, 0),
        (width / 2, depth / 2, 0), (-width / 2, depth / 2, 0), (0, 0, height),
    ]
    faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (0, 3, 2, 1)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    soften(obj, 0.022, 1)
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
    soften(obj, 0.024, 1)
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


def palette(prefix, accent=(0.20, 0.43, 0.43, 1), brick=(0.55, 0.24, 0.15, 1)):
    return {
        "grass": material(prefix + "SageGround", (0.28, 0.38, 0.23, 1), texture_scale=6.0, bump=0.11),
        "walk": material(prefix + "WarmPaver", (0.64, 0.56, 0.45, 1), texture_scale=11.0, bump=0.14),
        "brick": material(prefix + "WarmBrick", brick, texture_scale=15.0, bump=0.18),
        "brickDark": material(prefix + "DeepBrick", (0.34, 0.13, 0.09, 1), texture_scale=17.0, bump=0.16),
        "stone": material(prefix + "HoneyStone", (0.82, 0.70, 0.50, 1), texture_scale=9.0, bump=0.11),
        "cream": material(prefix + "WindowCream", (0.90, 0.79, 0.58, 1), texture_scale=8.0, bump=0.08),
        "roof": material(prefix + "DeepSlate", (0.12, 0.22, 0.23, 1), roughness=0.55, texture_scale=18.0, bump=0.18),
        "glass": material(prefix + "TealGlass", (0.16, 0.38, 0.43, 1), roughness=0.24, texture_scale=0),
        "accent": material(prefix + "Accent", accent, roughness=0.50, texture_scale=7.0),
        "copper": material(prefix + "AgedCopper", (0.39, 0.50, 0.34, 1), roughness=0.42, metallic=0.48, texture_scale=6.0),
        "iron": material(prefix + "WarmIron", (0.16, 0.17, 0.16, 1), roughness=0.40, metallic=0.62, texture_scale=7.0),
        "leaf": material(prefix + "JuniperLeaf", (0.17, 0.36, 0.15, 1), texture_scale=6.0),
        "leaf2": material(prefix + "LeafHighlight", (0.34, 0.50, 0.19, 1), texture_scale=5.0),
        "wood": material(prefix + "WarmWood", (0.39, 0.20, 0.11, 1), texture_scale=9.0, bump=0.14),
    }


def shared_lot(root, prefix, mats, front_depth=0.78):
    lot = box(root, prefix + "LotGround", (0, 0, -0.10), (4, 4, 0.20), mats["grass"], edge=0.055)
    lot["worldFootprintTiles"] = [2, 2]
    lot["exactWorldFootprint"] = [4.0, 4.0]
    box(root, prefix + "FrontWalk", (0, -1.54, 0.025), (3.78, front_depth, 0.08), mats["walk"], edge=0.025)


def facade_window(root, name, location, dimensions, mats, frame_axis="Y", frame=True):
    box(root, name, location, dimensions, mats["glass"], edge=0.010)
    if not frame:
        return
    x, y, z = location
    dx, dy, dz = dimensions
    if frame_axis == "Y":
        box(root, name + "Lintel", (x, y - 0.015, z + dz / 2 + 0.055), (dx + 0.10, dy + 0.018, 0.10), mats["cream"], edge=0.006)
    else:
        box(root, name + "Lintel", (x - 0.015, y, z + dz / 2 + 0.055), (dx + 0.018, dy + 0.10, 0.10), mats["cream"], edge=0.006)


def planter(root, prefix, location, mats, scale=0.25):
    x, y = location
    box(root, prefix + "Planter", (x, y, 0.24), (0.42, 0.42, 0.30), mats["stone"], edge=0.028)
    sphere(root, prefix + "Shrub", (x, y, 0.53), (scale, scale, scale * 1.22), mats["leaf"])
    sphere(root, prefix + "Highlight", (x - 0.07, y - 0.05, 0.64), (scale * 0.52, scale * 0.48, scale * 0.56), mats["leaf2"])


def foundry_crown_apartments(root):
    m = palette("FoundryCrown", accent=(0.46, 0.18, 0.14, 1), brick=(0.56, 0.22, 0.13, 1))
    shared_lot(root, "Crown", m, 0.72)
    box(root, "CrownStonePlinth", (0, 0.16, 0.22), (3.48, 3.02, 0.44), m["stone"], edge=0.050)
    box(root, "CrownPodium", (0, 0.17, 1.28), (3.36, 2.88, 1.82), m["brick"], edge=0.050)
    box(root, "CrownPodiumRustication", (0, -1.29, 0.82), (3.40, 0.12, 0.92), m["stone"], edge=0.022)
    box(root, "CrownMainTower", (0, 0.26, 4.10), (2.86, 2.36, 3.92), m["brick"], edge=0.050)
    box(root, "CrownUpperSetback", (0, 0.32, 6.28), (2.36, 1.96, 1.24), m["brickDark"], edge=0.045)
    for z in (2.05, 3.16, 4.27, 5.38, 6.90):
        box(root, f"CrownFloorBelt{z}", (0, 0.26, z), (2.98 if z < 6 else 2.48, 2.48 if z < 6 else 2.08, 0.11), m["cream"], edge=0.012)
    box(root, "CrownMainCornice", (0, 0.28, 6.92), (2.56, 2.18, 0.20), m["cream"], edge=0.025)
    pyramid_roof(root, "CrownCopperRoof", (0, 0.32, 7.02), 2.48, 2.08, 0.78, m["copper"])
    cylinder(root, "CrownFinial", (0, 0.32, 7.94), 0.07, 0.44, m["copper"], vertices=16)
    sphere(root, "CrownFinialOrb", (0, 0.32, 8.17), (0.12, 0.12, 0.12), m["copper"])

    # Five fully authored residential floors on all four facades.
    for floor, z in enumerate((1.18, 2.52, 3.63, 4.74, 5.85), start=1):
        width = 0.43 if floor == 1 else 0.38
        front_y = -1.295 if floor == 1 else -0.94
        rear_y = 1.615 if floor == 1 else 1.46
        for bay, x in enumerate((-1.08, -0.54, 0, 0.54, 1.08)):
            if floor > 1 and abs(x) > 0.9:
                continue
            facade_window(root, f"CrownFrontF{floor}B{bay}", (x, front_y, z), (width, 0.055, 0.52), m)
            facade_window(root, f"CrownRearF{floor}B{bay}", (x, rear_y, z), (width, 0.055, 0.52), m)
        for side, x in (("East", 1.455), ("West", -1.455)):
            for bay, y in enumerate((-0.48, 0.15, 0.78)):
                facade_window(root, f"Crown{side}F{floor}B{bay}", (x, y, z), (0.055, 0.36, 0.50), m, frame_axis="X")
    # Stacked iron balconies make the higher density legible without changing the footprint.
    for floor, z in enumerate((2.23, 3.34, 4.45, 5.56)):
        box(root, f"CrownBalconySlab{floor}", (0, -1.22, z), (1.28, 0.48, 0.10), m["stone"], edge=0.016)
        for x in (-0.55, -0.27, 0, 0.27, 0.55):
            box(root, f"CrownBalconyRail{floor}_{x}", (x, -1.46, z + 0.25), (0.035, 0.035, 0.46), m["iron"], edge=0.005)
        box(root, f"CrownBalconyTop{floor}", (0, -1.46, z + 0.48), (1.18, 0.04, 0.05), m["iron"], edge=0.006)
    box(root, "CrownEntryRecess", (0, -1.49, 0.94), (0.78, 0.12, 1.18), m["brickDark"], edge=0.020)
    box(root, "CrownDoubleDoor", (0, -1.57, 0.92), (0.62, 0.07, 1.10), m["accent"], edge=0.018)
    box(root, "CrownEntryCanopy", (0, -1.68, 1.58), (1.18, 0.48, 0.14), m["copper"], edge=0.020)
    for x in (-0.50, 0.50):
        cylinder(root, f"CrownCanopyPost{x}", (x, -1.72, 0.88), 0.04, 1.32, m["iron"], vertices=12)
    # A small shared roof garden reinforces the urban apartment identity.
    for i, x in enumerate((-0.66, 0.66)):
        box(root, f"CrownRoofPlanter{i}", (x, 0.30, 7.14), (0.46, 0.34, 0.22), m["stone"], edge=0.020)
        sphere(root, f"CrownRoofShrub{i}", (x, 0.30, 7.40), (0.22, 0.18, 0.25), m["leaf"])
    for i, location in enumerate(((-1.50, -1.55), (1.50, -1.55), (-1.55, 1.50), (1.55, 1.50))):
        planter(root, f"CrownStreet{i}", location, m, 0.22)


def market_arcade_midrise(root):
    m = palette("MarketArcade", accent=(0.65, 0.25, 0.12, 1), brick=(0.52, 0.25, 0.16, 1))
    shared_lot(root, "Arcade", m, 0.86)
    box(root, "ArcadeStonePlinth", (0, 0.12, 0.22), (3.52, 3.04, 0.44), m["stone"], edge=0.050)
    box(root, "ArcadeRetailPodium", (0, 0.10, 1.02), (3.42, 2.94, 1.34), m["stone"], edge=0.045)
    box(root, "ArcadeOfficeBody", (0, 0.18, 3.12), (3.16, 2.58, 2.88), m["brick"], edge=0.050)
    box(root, "ArcadeCornerBay", (1.34, -1.02, 3.26), (0.64, 0.64, 3.18), m["brickDark"], edge=0.040)
    for z in (1.72, 2.72, 3.72, 4.60):
        box(root, f"ArcadeFloorBelt{z}", (0, 0.17, z), (3.28, 2.70, 0.11), m["cream"], edge=0.012)
    box(root, "ArcadeRoofSlab", (0, 0.18, 4.74), (3.30, 2.72, 0.22), m["roof"], edge=0.030)
    box(root, "ArcadeRoofTerrace", (-0.38, 0.22, 4.92), (2.20, 1.64, 0.14), m["walk"], edge=0.022)

    # Ground-floor arcade: deep storefront rhythm, columns, lintels, and warm awnings.
    for bay, x in enumerate((-1.18, -0.40, 0.40, 1.18)):
        facade_window(root, f"ArcadeStorefront{bay}", (x, -1.395, 0.94), (0.54, 0.06, 0.86), m, frame=False)
        box(root, f"ArcadeAwning{bay}", (x, -1.56, 1.50), (0.66, 0.42, 0.13), m["accent"], rotation=(math.radians(-10), 0, 0), edge=0.015)
    for col, x in enumerate((-1.55, -0.78, 0, 0.78, 1.55)):
        cylinder(root, f"ArcadeColumn{col}", (x, -1.47, 0.88), 0.09, 1.48, m["stone"], vertices=20)
        box(root, f"ArcadeColumnBase{col}", (x, -1.47, 0.20), (0.25, 0.25, 0.14), m["stone"], edge=0.012)
    box(root, "ArcadeEntablature", (0, -1.48, 1.67), (3.50, 0.26, 0.20), m["cream"], edge=0.022)
    box(root, "ArcadeCornerEntry", (1.54, -1.31, 0.92), (0.10, 0.52, 1.02), m["accent"], edge=0.014)
    # Three office floors read on every view.
    for floor, z in enumerate((2.22, 3.18, 4.12), start=1):
        for bay, x in enumerate((-1.12, -0.38, 0.38, 1.12)):
            facade_window(root, f"ArcadeFrontOfficeF{floor}B{bay}", (x, -1.135, z), (0.42, 0.055, 0.50), m)
            facade_window(root, f"ArcadeRearOfficeF{floor}B{bay}", (x, 1.475, z), (0.42, 0.055, 0.50), m)
        for side, x in (("East", 1.605), ("West", -1.605)):
            for bay, y in enumerate((-0.60, 0.10, 0.80)):
                facade_window(root, f"Arcade{side}OfficeF{floor}B{bay}", (x, y, z), (0.055, 0.40, 0.48), m, frame_axis="X")
    # Terrace pergola and corner clock give the mid-rise a distinct roofline.
    for x in (-1.05, -0.40, 0.25):
        cylinder(root, f"ArcadePergolaPost{x}", (x, 0.34, 5.28), 0.045, 0.78, m["iron"], vertices=12)
    for y in (-0.34, 0.34, 0.98):
        beam(root, f"ArcadePergolaBeam{y}", (-1.15, y, 5.68), (0.35, y, 5.68), 0.07, m["wood"])
    cylinder(root, "ArcadeCornerClock", (1.68, -1.36, 4.06), 0.24, 0.08, m["cream"], vertices=24, rotation=(math.radians(90), 0, 0))
    cylinder(root, "ArcadeClockFace", (1.68, -1.41, 4.06), 0.18, 0.025, m["accent"], vertices=24, rotation=(math.radians(90), 0, 0))
    for i, location in enumerate(((-1.55, -1.58), (0.72, -1.62), (-1.48, 1.50), (1.46, 1.50))):
        planter(root, f"ArcadeStreet{i}", location, m, 0.21)


def aurora_exchange_tower(root):
    m = palette("AuroraExchange", accent=(0.10, 0.34, 0.43, 1), brick=(0.48, 0.25, 0.17, 1))
    shared_lot(root, "Aurora", m, 0.82)
    box(root, "AuroraPodiumPlinth", (0, 0.12, 0.22), (3.56, 3.10, 0.44), m["stone"], edge=0.050)
    box(root, "AuroraRetailPodium", (0, 0.10, 1.06), (3.44, 2.98, 1.40), m["stone"], edge=0.048)
    box(root, "AuroraTowerLower", (0, 0.24, 3.68), (2.78, 2.32, 3.84), m["brickDark"], edge=0.048)
    box(root, "AuroraTowerUpper", (0.12, 0.28, 6.23), (2.34, 1.94, 1.44), m["brickDark"], edge=0.043)
    box(root, "AuroraCrownBase", (0.12, 0.28, 7.04), (2.48, 2.08, 0.22), m["stone"], edge=0.025)
    pyramid_roof(root, "AuroraCopperCrown", (0.12, 0.28, 7.15), 2.32, 1.92, 0.70, m["copper"])
    cylinder(root, "AuroraBeaconMast", (0.12, 0.28, 8.02), 0.045, 0.54, m["copper"], vertices=12)
    sphere(root, "AuroraBeacon", (0.12, 0.28, 8.32), (0.11, 0.11, 0.14), m["cream"])

    # Limestone retail base with deep glazing and corner entrance.
    for bay, x in enumerate((-1.18, -0.40, 0.40, 1.18)):
        facade_window(root, f"AuroraShopfront{bay}", (x, -1.395, 0.96), (0.55, 0.055, 0.90), m, frame=False)
        box(root, f"AuroraShopMullion{bay}", (x, -1.435, 0.96), (0.045, 0.045, 0.82), m["copper"], edge=0.005)
    box(root, "AuroraEntryPortal", (1.45, -1.20, 1.00), (0.32, 0.58, 1.30), m["accent"], edge=0.020)
    box(root, "AuroraEntryCanopy", (1.20, -1.55, 1.63), (0.94, 0.52, 0.13), m["copper"], edge=0.018)

    # Seven levels of vertical glass, with real mullions rather than a flat texture.
    floor_heights = (2.10, 2.95, 3.80, 4.65, 5.50, 6.35, 6.92)
    for floor, z in enumerate(floor_heights, start=1):
        upper = floor >= 6
        half_width = 0.88 if upper else 1.08
        front_y = -0.70 if upper else -0.94
        rear_y = 1.26 if upper else 1.42
        for bay, x in enumerate((-half_width, -half_width / 3, half_width / 3, half_width)):
            facade_window(root, f"AuroraFrontF{floor}B{bay}", (x + (0.12 if upper else 0), front_y, z), (0.38, 0.05, 0.56), m, frame=False)
            facade_window(root, f"AuroraRearF{floor}B{bay}", (x + (0.12 if upper else 0), rear_y, z), (0.38, 0.05, 0.56), m, frame=False)
        side_x = 1.29 if upper else 1.41
        for side, x in (("East", side_x), ("West", -side_x + (0.24 if upper else 0))):
            for bay, y in enumerate((-0.46, 0.16, 0.78)):
                facade_window(root, f"Aurora{side}F{floor}B{bay}", (x, y, z), (0.05, 0.34, 0.54), m, frame_axis="X", frame=False)
        box(root, f"AuroraFloorBand{floor}", (0.12 if upper else 0, 0.24, z + 0.38), (2.46 if upper else 2.90, 2.06 if upper else 2.44, 0.09), m["copper"], edge=0.010)
    # Strong vertical fins keep the tower readable at CitySim scale.
    for index, x in enumerate((-1.23, -0.62, 0, 0.62, 1.23)):
        box(root, f"AuroraFrontFin{index}", (x, -0.985, 4.30), (0.055, 0.08, 5.20), m["stone"], edge=0.006)
        box(root, f"AuroraRearFin{index}", (x, 1.465, 4.30), (0.055, 0.08, 5.20), m["stone"], edge=0.006)
    for side, x in (("East", 1.455), ("West", -1.455)):
        for y in (-0.66, 0, 0.66):
            box(root, f"Aurora{side}Fin{y}", (x, y, 4.30), (0.08, 0.055, 5.20), m["stone"], edge=0.006)
    # Two podium terraces with greenery anchor the high-rise to the street.
    for i, (x, y) in enumerate(((-1.35, 1.25), (1.35, 1.25), (-1.35, -1.28))):
        box(root, f"AuroraTerracePlanter{i}", (x, y, 1.88), (0.46, 0.42, 0.24), m["stone"], edge=0.020)
        sphere(root, f"AuroraTerraceTree{i}", (x, y, 2.28), (0.24, 0.22, 0.34), m["leaf"])
    for i, location in enumerate(((-1.55, -1.58), (0.45, -1.66), (-1.50, 1.52), (1.48, 1.52))):
        planter(root, f"AuroraStreet{i}", location, m, 0.20)


def canalworks_factory(root):
    m = palette("Canalworks", accent=(0.47, 0.31, 0.13, 1), brick=(0.48, 0.22, 0.14, 1))
    m["steel"] = material("CanalworksPaintedSteel", (0.24, 0.31, 0.31, 1), roughness=0.46, metallic=0.42, texture_scale=9.0)
    shared_lot(root, "Canal", m, 1.05)
    box(root, "CanalFactoryPlinth", (0, 0.14, 0.20), (3.58, 3.08, 0.40), m["walk"], edge=0.050)
    box(root, "CanalMainHall", (0.42, 0.40, 1.38), (2.54, 2.46, 2.36), m["brick"], edge=0.048)
    box(root, "CanalAdminWing", (-1.15, -0.30, 1.34), (0.92, 1.95, 2.24), m["stone"], edge=0.045)
    # Three genuine sawtooth roof bays step across the production hall.
    for index, x in enumerate((-0.40, 0.42, 1.24)):
        gable_roof(root, f"CanalSawtooth{index}", (x, 0.40, 2.56), (0.86, 2.56, 0.58), m["roof"], ridge_axis="Y")
        box(root, f"CanalRoofLight{index}", (x - 0.36, 0.40, 2.85), (0.055, 1.82, 0.36), m["glass"], rotation=(0, math.radians(-22), 0), edge=0.008)
    box(root, "CanalAdminRoof", (-1.15, -0.30, 2.52), (1.02, 2.06, 0.18), m["roof"], edge=0.025)
    # Loading frontage, dock bumpers, and office windows.
    for bay, x in enumerate((-0.35, 0.52, 1.39)):
        box(root, f"CanalLoadingDoor{bay}", (x, -0.855, 1.05), (0.68, 0.07, 1.36), m["steel"], edge=0.020)
        for slat, z in enumerate((0.55, 0.82, 1.09, 1.36, 1.63)):
            box(root, f"CanalDoor{bay}Slat{slat}", (x, -0.90, z), (0.58, 0.025, 0.035), m["cream"], edge=0.004)
        box(root, f"CanalDock{bay}", (x, -1.18, 0.35), (0.76, 0.56, 0.32), m["walk"], edge=0.025)
        for dx in (-0.27, 0.27):
            box(root, f"CanalDockBumper{bay}{dx}", (x + dx, -1.48, 0.44), (0.10, 0.08, 0.24), m["iron"], edge=0.008)
    for floor, z in enumerate((0.98, 1.76)):
        for bay, y in enumerate((-0.78, -0.22, 0.34)):
            facade_window(root, f"CanalAdminWestF{floor}B{bay}", (-1.62, y, z), (0.055, 0.30, 0.40), m, frame_axis="X")
            facade_window(root, f"CanalAdminEastF{floor}B{bay}", (-0.68, y, z), (0.055, 0.30, 0.40), m, frame_axis="X")
    # Tank yard, pipe bridge, and stack increase capacity beyond Ironleaf.
    for i, y in enumerate((0.98, 1.48)):
        cylinder(root, f"CanalTank{i}", (-1.35, y, 1.00), 0.34, 1.52, m["steel"], vertices=24)
        cone(root, f"CanalTankCap{i}", (-1.35, y, 1.80), 0.34, 0.08, 0.22, m["copper"], vertices=24)
        for ring, z in enumerate((0.55, 1.03, 1.50)):
            cylinder(root, f"CanalTankRing{i}_{ring}", (-1.35, y, z), 0.37, 0.055, m["iron"], vertices=24)
    cylinder(root, "CanalStack", (1.42, 1.25, 4.24), 0.25, 3.82, m["brickDark"], vertices=28)
    cylinder(root, "CanalStackCrown", (1.42, 1.25, 6.18), 0.30, 0.14, m["stone"], vertices=28)
    for z in (3.05, 3.74, 4.43, 5.12):
        cylinder(root, f"CanalStackBand{z}", (1.42, 1.25, z), 0.28, 0.08, m["cream"], vertices=28)
    for i, x in enumerate((-1.35, -0.45, 0.45, 1.35)):
        cylinder(root, f"CanalPipePost{i}", (x, 1.66, 1.18), 0.055, 1.92, m["iron"], vertices=12)
    for z in (1.70, 2.00):
        beam(root, f"CanalPipeRun{z}", (-1.48, 1.66, z), (1.48, 1.66, z), 0.12, m["copper"])
    for i, location in enumerate(((-1.58, -1.55), (1.55, -1.56))):
        planter(root, f"CanalStreet{i}", location, m, 0.18)


def foundry_peak_plant(root):
    m = palette("FoundryPeak", accent=(0.54, 0.28, 0.10, 1), brick=(0.44, 0.19, 0.12, 1))
    m["steel"] = material("FoundryPeakSteel", (0.23, 0.29, 0.29, 1), roughness=0.42, metallic=0.54, texture_scale=9.0)
    m["oxide"] = material("FoundryPeakOxide", (0.49, 0.23, 0.09, 1), roughness=0.57, metallic=0.18, texture_scale=10.0)
    shared_lot(root, "Peak", m, 1.10)
    box(root, "PeakHeavyPlinth", (0, 0.12, 0.22), (3.62, 3.12, 0.44), m["walk"], edge=0.050)
    box(root, "PeakProductionHall", (0.35, 0.25, 1.50), (2.56, 2.48, 2.52), m["brick"], edge=0.050)
    gable_roof(root, "PeakProductionRoof", (0.35, 0.25, 2.76), (2.72, 2.64, 0.62), m["roof"], ridge_axis="Y")
    box(root, "PeakFurnaceTower", (-1.02, 0.45, 3.08), (1.02, 1.42, 5.46), m["brickDark"], edge=0.048)
    box(root, "PeakFurnaceCrown", (-1.02, 0.45, 5.88), (1.16, 1.56, 0.22), m["stone"], edge=0.026)
    pyramid_roof(root, "PeakFurnaceRoof", (-1.02, 0.45, 5.99), 1.10, 1.50, 0.46, m["copper"])
    # Tall paired exhaust stacks establish level-3 capacity.
    for i, x in enumerate((0.72, 1.38)):
        cylinder(root, f"PeakStack{i}", (x, 1.12, 4.66), 0.24, 6.42, m["oxide"], vertices=28)
        cylinder(root, f"PeakStackCap{i}", (x, 1.12, 7.91), 0.30, 0.16, m["stone"], vertices=28)
        for band, z in enumerate((2.35, 3.35, 4.35, 5.35, 6.35, 7.35)):
            cylinder(root, f"PeakStack{i}Band{band}", (x, 1.12, z), 0.27, 0.075, m["cream"], vertices=28)
    # Front loading bays and heavy lintels.
    for bay, x in enumerate((-0.30, 0.48, 1.26)):
        box(root, f"PeakLoadingDoor{bay}", (x, -1.025, 1.18), (0.62, 0.07, 1.48), m["steel"], edge=0.020)
        for slat, z in enumerate((0.58, 0.86, 1.14, 1.42, 1.70)):
            box(root, f"PeakLoadingSlat{bay}_{slat}", (x, -1.07, z), (0.52, 0.025, 0.035), m["cream"], edge=0.004)
        box(root, f"PeakLoadingLintel{bay}", (x, -1.10, 2.02), (0.72, 0.10, 0.18), m["stone"], edge=0.014)
    # Furnace openings and side windows make every orientation authored.
    for floor, z in enumerate((1.25, 2.25, 3.25, 4.25, 5.20)):
        facade_window(root, f"PeakFurnaceFront{floor}", (-1.02, -0.285, z), (0.42, 0.055, 0.50), m)
        facade_window(root, f"PeakFurnaceRear{floor}", (-1.02, 1.185, z), (0.42, 0.055, 0.50), m)
        facade_window(root, f"PeakFurnaceWest{floor}", (-1.555, 0.45, z), (0.055, 0.42, 0.48), m, frame_axis="X")
    for side, x in (("East", 1.665), ("West", -0.965)):
        for bay, y in enumerate((-0.45, 0.22, 0.88)):
            facade_window(root, f"PeakHall{side}{bay}", (x, y, 1.72), (0.055, 0.38, 0.46), m, frame_axis="X")
    # Silo pair and conveyor bridge fill the rear process yard.
    for i, y in enumerate((-0.30, 0.58)):
        cylinder(root, f"PeakSilo{i}", (-1.50, y, 1.28), 0.31, 2.12, m["steel"], vertices=24)
        cone(root, f"PeakSiloCone{i}", (-1.50, y, 2.46), 0.31, 0.06, 0.34, m["copper"], vertices=24)
        for ring, z in enumerate((0.64, 1.18, 1.72, 2.24)):
            cylinder(root, f"PeakSilo{i}Ring{ring}", (-1.50, y, z), 0.34, 0.055, m["iron"], vertices=24)
    beam(root, "PeakConveyor", (-1.50, 0.58, 2.42), (-0.48, 0.45, 4.55), 0.22, m["steel"])
    # Dense pipe rack, valves, and braces reinforce high capacity without fake sprite detail.
    for i, x in enumerate((-1.48, -0.90, -0.32, 0.26, 0.84, 1.42)):
        cylinder(root, f"PeakRackPost{i}", (x, -1.48, 1.24), 0.055, 2.02, m["iron"], vertices=12)
        box(root, f"PeakRackFoot{i}", (x, -1.48, 0.24), (0.18, 0.18, 0.12), m["stone"], edge=0.010)
    for level, z in enumerate((1.62, 1.92, 2.22)):
        beam(root, f"PeakPipeRun{level}", (-1.55, -1.48, z), (1.50, -1.48, z), 0.11, m["copper"] if level == 1 else m["steel"])
        for valve, x in enumerate((-0.72, 0.18, 1.08)):
            cylinder(root, f"PeakValve{level}_{valve}", (x, -1.48, z), 0.15, 0.045, m["accent"], vertices=16, rotation=(math.radians(90), 0, 0))
    for i, location in enumerate(((-1.58, -1.70), (1.55, -1.70))):
        planter(root, f"PeakStreet{i}", location, m, 0.17)


BUILDERS = {
    "foundry_crown_apartments": foundry_crown_apartments,
    "market_arcade_midrise": market_arcade_midrise,
    "aurora_exchange_tower": aurora_exchange_tower,
    "canalworks_factory": canalworks_factory,
    "foundry_peak_plant": foundry_peak_plant,
}


def build_asset(asset):
    scene = reset("CitySimDensity_" + asset["assetId"])
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


def source_info(path):
    return {"path": path.relative_to(HERE).as_posix(), "sha256": sha256(path)}


def write_asset_manifest(asset, artifacts):
    output_dir = HERE / asset["assetId"]
    data = {
        "schema": "citysim.world-art.density-four-view-asset.v1",
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
        "sourceFiles": [source_info(HERE / name) for name in ("build_and_render.py", "pipeline.json", "run_pipeline.sh")],
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
    distance = 48.0
    elevation = math.radians(30.0)
    azimuth = math.radians(45.0)
    horizontal = distance * math.cos(elevation)
    data = bpy.data.cameras.new("camNE_ProgressionPreview")
    data.type = "ORTHO"
    data.ortho_scale = CONFIG["progressionPreview"]["camera"]["orthoScale"]
    camera = bpy.data.objects.new("camNE_ProgressionPreview", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation))
    point_at(camera, Vector((0, 0, 1.45)))
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


def preview_sources():
    return [
        {"assetId": "copper_finch_house", "zone": "residential", "densityLevel": 1, "source": BLENDER_ROOT / "FourViewPipeline/example/copper_finch_house.blend", "origin": (-8.0, 8.0, 0.0)},
        {"assetId": "brickline_rowhouse_apartments", "zone": "residential", "densityLevel": 2, "source": PRODUCTION / "ResidentialExpansion/brickline_rowhouse_apartments/brickline_rowhouse_apartments.blend", "origin": (0.0, 8.0, 0.0)},
        {"assetId": "foundry_crown_apartments", "zone": "residential", "densityLevel": 3, "source": HERE / "foundry_crown_apartments/foundry_crown_apartments.blend", "origin": (8.0, 8.0, 0.0)},
        {"assetId": "harbor_corner_storefront", "zone": "commercial", "densityLevel": 1, "source": PRODUCTION / "CommercialIndustrial/harbor_corner_storefront/harbor_corner_storefront.blend", "origin": (-8.0, 0.0, 0.0)},
        {"assetId": "market_arcade_midrise", "zone": "commercial", "densityLevel": 2, "source": HERE / "market_arcade_midrise/market_arcade_midrise.blend", "origin": (0.0, 0.0, 0.0)},
        {"assetId": "aurora_exchange_tower", "zone": "commercial", "densityLevel": 3, "source": HERE / "aurora_exchange_tower/aurora_exchange_tower.blend", "origin": (8.0, 0.0, 0.0)},
        {"assetId": "ironleaf_service_workshop", "zone": "industrial", "densityLevel": 1, "source": PRODUCTION / "CommercialIndustrial/ironleaf_service_workshop/ironleaf_service_workshop.blend", "origin": (-8.0, -8.0, 0.0)},
        {"assetId": "canalworks_factory", "zone": "industrial", "densityLevel": 2, "source": HERE / "canalworks_factory/canalworks_factory.blend", "origin": (0.0, -8.0, 0.0)},
        {"assetId": "foundry_peak_plant", "zone": "industrial", "densityLevel": 3, "source": HERE / "foundry_peak_plant/foundry_peak_plant.blend", "origin": (8.0, -8.0, 0.0)},
    ]


def build_preview():
    scene = reset("CitySimUptownFoundryProgressionAvenue")
    configure_scene(scene, transparent=False)
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    ground = material("ProgressionGround", (0.27, 0.36, 0.23, 1), texture_scale=6.0, bump=0.11)
    asphalt = material("ProgressionAsphalt", (0.16, 0.19, 0.19, 1), texture_scale=20.0, bump=0.16)
    curb = material("ProgressionCurb", (0.66, 0.59, 0.48, 1), texture_scale=11.0, bump=0.12)
    stripe = material("ProgressionCenterLine", (0.83, 0.57, 0.17, 1), roughness=0.62, texture_scale=4.0)
    box(root, "ProgressionGroundPlane", (0, 0, -0.28), (28, 28, 0.28), ground, edge=0.10)
    # Roads are aligned exactly to world X/Y. No road or lot is independently rotated.
    for axis, center in (("X", -4.0), ("X", 4.0), ("Y", -4.0), ("Y", 4.0)):
        dimensions = (28, 4, 0.12) if axis == "X" else (4, 28, 0.12)
        location = (0, center, -0.075) if axis == "X" else (center, 0, -0.075)
        box(root, f"{axis}AxisRoad{center}", location, dimensions, asphalt, edge=0.025)
        for side in (-1.0, 1.0):
            offset = center + side * 2.08
            curb_location = (0, offset, 0.005) if axis == "X" else (offset, 0, 0.005)
            curb_dimensions = (28, 0.16, 0.14) if axis == "X" else (0.16, 28, 0.14)
            box(root, f"{axis}AxisCurb{center}_{side}", curb_location, curb_dimensions, curb, edge=0.018)
        for index, position in enumerate(range(-12, 13, 3)):
            stripe_location = (position, center, -0.005) if axis == "X" else (center, position, -0.005)
            stripe_dimensions = (1.10, 0.08, 0.035) if axis == "X" else (0.08, 1.10, 0.035)
            box(root, f"{axis}AxisStripe{center}_{index}", stripe_location, stripe_dimensions, stripe, edge=0.006)

    placements = []
    for item in preview_sources():
        source = item["source"]
        if not source.is_file():
            raise RuntimeError(f"MISSING_PREVIEW_SOURCE: {source}")
        _, mesh_count = append_mesh_asset(source, f"Placement_{item['assetId']}", item["origin"])
        placements.append({
            "assetId": item["assetId"],
            "zone": item["zone"],
            "densityLevel": item["densityLevel"],
            "originWorld": list(item["origin"]),
            "footprintTiles": [2, 2],
            "sourceBlend": source.relative_to(BLENDER_ROOT).as_posix(),
            "sourceBlendSha256": sha256(source),
            "meshCount": mesh_count,
            "perAssetTransformCompensation": "none",
        })
    preview_camera_and_light(scene)
    preview_dir = HERE / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    blend_path = preview_dir / "uptown-foundry-progression-avenue.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = preview_dir / f"uptown-foundry-progression-avenue-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    manifest = {
        "schema": "citysim.world-art.density-progression-preview.v1",
        "status": "source-only-review-evidence",
        "liveAsset": False,
        "acceptedFamilyContractOnly": True,
        "cedarMarketReused": False,
        "camera": CONFIG["progressionPreview"]["camera"] | {"perAssetCompensation": "none"},
        "grid": CONFIG["grid"],
        "lightingConvention": CONFIG["lighting"],
        "layout": {"levelColumns": [-8.0, 0.0, 8.0], "zoneRows": [8.0, 0.0, -8.0], "roadAxes": "world-X-and-world-Y"},
        "placements": placements,
        "sourceFiles": [source_info(HERE / name) for name in ("build_and_render.py", "pipeline.json", "run_pipeline.sh")],
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
    print("DENSITY_FOUR_VIEW_RENDER_PASS assets=5 views=20 previews=2")


if __name__ == "__main__":
    main()
