#!/usr/bin/env python3
"""Build and render the original CitySim Four-View utility family."""

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


def cone(root, name, location, radius1, radius2, depth, mat, vertices=32):
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
    midpoint = (a + b) / 2
    direction = b - a
    bpy.ops.mesh.primitive_cube_add(size=1, location=midpoint)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (width, width, direction.length)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    apply(obj)
    soften(obj, min(width * 0.18, 0.018), 1)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def reset(scene_name="CitySimUtilitiesFourView"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = scene_name
    bpy.context.preferences.filepaths.save_version = 0
    return scene


def configure_asset_scene(scene):
    canvas = CONFIG["canvas"]
    scene.render.engine = CONFIG["toolchain"]["renderEngine"]
    scene.render.resolution_x = canvas["width"]
    scene.render.resolution_y = canvas["height"]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
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
    root["assetDescription"] = asset["description"]
    root["sourcePixelsReused"] = False
    root["cedarMarketReused"] = False
    root["liveAsset"] = False
    root["fixedObjectScale"] = True
    root["postRenderCompensation"] = "none"
    return root


def shared_lot(root, prefix, grass, concrete, fence_metal):
    lot = box(root, prefix + "LotGround", (0, 0, -0.10), (4, 4, 0.20), grass, edge=0.055)
    lot["worldFootprintTiles"] = [2, 2]
    lot["exactWorldFootprint"] = [4.0, 4.0]
    box(root, prefix + "ServiceApron", (0, -0.10, 0.025), (3.50, 3.10, 0.08), concrete, edge=0.025)
    # Four gate posts and low rails provide a grounded boundary without hiding equipment.
    for index, (x, y) in enumerate(((-1.72, -1.70), (1.72, -1.70), (-1.72, 1.70), (1.72, 1.70))):
        box(root, f"{prefix}FencePost{index}", (x, y, 0.48), (0.08, 0.08, 0.92), fence_metal, edge=0.01)
    for y in (-1.70, 1.70):
        for x in (-0.88, 0.88):
            box(root, f"{prefix}FenceRailY{y}_{x}", (x, y, 0.52), (1.58, 0.055, 0.055), fence_metal, edge=0.008)
    for x in (-1.72, 1.72):
        box(root, f"{prefix}FenceRailX{x}", (x, 0, 0.52), (0.055, 3.32, 0.055), fence_metal, edge=0.008)


def water_tower(root):
    mats = {
        "grass": material("WaterworksSageGround", (0.28, 0.37, 0.23, 1), texture_scale=5.0),
        "concrete": material("WaterworksWarmConcrete", (0.58, 0.50, 0.39, 1), texture_scale=10.0, bump=0.14),
        "brick": material("PumpHouseBrick", (0.52, 0.23, 0.15, 1), texture_scale=14.0, bump=0.16),
        "cream": material("PumpHouseLimestone", (0.84, 0.72, 0.53, 1), texture_scale=9.0),
        "roof": material("PumpHouseSlate", (0.13, 0.23, 0.25, 1), roughness=0.58, texture_scale=18.0, bump=0.18),
        "tank": material("RivetedCopperPatina", (0.24, 0.46, 0.43, 1), roughness=0.48, metallic=0.48, texture_scale=7.0, bump=0.12),
        "steel": material("TowerWarmIron", (0.17, 0.18, 0.17, 1), roughness=0.42, metallic=0.62, texture_scale=6.0),
        "pipe": material("WaterworksPipe", (0.28, 0.31, 0.28, 1), roughness=0.45, metallic=0.50, texture_scale=6.0),
        "door": material("PumpHouseJuniperDoor", (0.12, 0.28, 0.25, 1), texture_scale=7.0),
        "glass": material("PumpHouseGlass", (0.20, 0.43, 0.47, 1), roughness=0.26, texture_scale=0),
        "warning": material("MunicipalOchre", (0.84, 0.55, 0.13, 1), roughness=0.58, texture_scale=4.0),
        "leaf": material("WaterworksShrub", (0.20, 0.36, 0.16, 1), texture_scale=5.0),
    }
    shared_lot(root, "Water", mats["grass"], mats["concrete"], mats["steel"])
    # Four concrete footings and tapered-looking braced steel legs.
    leg_xy = ((-0.75, -0.62), (0.75, -0.62), (-0.75, 0.62), (0.75, 0.62))
    for index, (x, y) in enumerate(leg_xy):
        box(root, f"TowerFooting{index}", (x, y, 0.18), (0.48, 0.48, 0.28), mats["concrete"], edge=0.035)
        beam(root, f"TowerLeg{index}", (x, y, 0.30), (x * 0.72, y * 0.72, 3.55), 0.12, mats["steel"])
    # X bracing on all four sides keeps the silhouette readable from every canonical view.
    braces = [
        ((-0.75, -0.62, 0.72), (0.54, -0.45, 2.75)), ((0.75, -0.62, 0.72), (-0.54, -0.45, 2.75)),
        ((-0.75, 0.62, 0.72), (0.54, 0.45, 2.75)), ((0.75, 0.62, 0.72), (-0.54, 0.45, 2.75)),
        ((-0.75, -0.62, 0.72), (-0.54, 0.45, 2.75)), ((-0.75, 0.62, 0.72), (-0.54, -0.45, 2.75)),
        ((0.75, -0.62, 0.72), (0.54, 0.45, 2.75)), ((0.75, 0.62, 0.72), (0.54, -0.45, 2.75)),
    ]
    for index, (start, end) in enumerate(braces):
        beam(root, f"CrossBrace{index}", start, end, 0.055, mats["steel"])
    # Elevated municipal tank: belly, banding, conical roof, finial, catwalk, and ladder.
    cone(root, "TankLowerBowl", (0, 0, 3.58), 0.98, 0.82, 0.58, mats["tank"], vertices=40)
    cylinder(root, "TankBarrel", (0, 0, 4.18), 0.98, 0.82, mats["tank"], vertices=40)
    cone(root, "TankShoulder", (0, 0, 4.70), 0.98, 0.72, 0.24, mats["tank"], vertices=40)
    cone(root, "TankRoof", (0, 0, 5.05), 0.78, 0.08, 0.62, mats["roof"], vertices=40)
    cylinder(root, "TankFinial", (0, 0, 5.45), 0.055, 0.30, mats["steel"], vertices=12)
    for index, z in enumerate((3.72, 4.05, 4.38, 4.70)):
        cylinder(root, f"TankRivetBand{index}", (0, 0, z), 1.00 if z < 4.7 else 0.90, 0.055, mats["steel"], vertices=40, edge=0.006)
    cylinder(root, "TankCatwalk", (0, 0, 3.50), 1.13, 0.075, mats["steel"], vertices=40, edge=0.006)
    for index in range(12):
        angle = index * math.tau / 12
        x, y = 1.10 * math.cos(angle), 1.10 * math.sin(angle)
        box(root, f"CatwalkRailPost{index}", (x, y, 3.82), (0.035, 0.035, 0.58), mats["steel"], edge=0.004)
    # Ladder and safety hoop on the east leg.
    for x in (0.96, 1.10):
        beam(root, f"LadderRail{x}", (x, 0.02, 0.48), (x * 0.70, 0.02, 3.48), 0.035, mats["steel"])
    for index, z in enumerate([0.62 + i * 0.28 for i in range(10)]):
        box(root, f"LadderRung{index}", (0.98 - z * 0.085, 0.02, z), (0.30, 0.035, 0.035), mats["steel"], edge=0.004)
    # Grounded pump house, avoiding the floating-tower read.
    box(root, "PumpHousePlinth", (-0.92, -0.98, 0.20), (1.55, 1.28, 0.28), mats["concrete"], edge=0.035)
    box(root, "PumpHouseBody", (-0.92, -0.98, 0.88), (1.38, 1.12, 1.12), mats["brick"], edge=0.035)
    box(root, "PumpHouseCornice", (-0.92, -0.98, 1.48), (1.50, 1.24, 0.12), mats["cream"], edge=0.018)
    cone(root, "PumpHouseRoof", (-0.92, -0.98, 1.67), 0.95, 0.12, 0.38, mats["roof"], vertices=4)
    box(root, "PumpHouseDoor", (-0.92, -1.55, 0.87), (0.52, 0.06, 0.90), mats["door"], edge=0.018)
    box(root, "PumpHouseTransom", (-0.92, -1.59, 1.28), (0.40, 0.035, 0.18), mats["glass"], edge=0.008)
    box(root, "PumpHouseWindow", (-0.21, -0.98, 1.00), (0.055, 0.48, 0.46), mats["glass"], edge=0.012)
    # Visible manifold, valves, and hydrant-colored caps distinguish the service function.
    cylinder(root, "MainRiser", (0.58, -0.86, 0.72), 0.115, 1.20, mats["pipe"], vertices=20)
    cylinder(root, "MainValve", (0.58, -0.86, 1.14), 0.24, 0.12, mats["warning"], vertices=20)
    cylinder(root, "GroundManifold", (0.96, -0.86, 0.45), 0.105, 0.78, mats["pipe"], vertices=20, rotation=(0, math.radians(90), 0))
    for index, x in enumerate((0.75, 1.15)):
        cylinder(root, f"ValveWheel{index}", (x, -0.86, 0.68), 0.17, 0.055, mats["warning"], vertices=16, rotation=(math.radians(90), 0, 0))
    for index, (x, y) in enumerate(((1.45, -1.30), (-1.45, 1.22))):
        cylinder(root, f"ServicePlanter{index}", (x, y, 0.24), 0.28, 0.26, mats["concrete"], vertices=16)
        sphere(root, f"ServiceShrub{index}", (x, y, 0.56), (0.31, 0.28, 0.38), mats["leaf"])
    root["assetKind"] = "municipal-water-utility"


def substation(root):
    mats = {
        "gravel": material("SubstationGravel", (0.40, 0.37, 0.31, 1), texture_scale=18.0, bump=0.20),
        "concrete": material("SubstationConcrete", (0.59, 0.52, 0.42, 1), texture_scale=10.0, bump=0.14),
        "brick": material("SubstationWarmBrick", (0.55, 0.24, 0.16, 1), texture_scale=15.0, bump=0.18),
        "cream": material("SubstationLimestone", (0.84, 0.73, 0.54, 1), texture_scale=9.0),
        "roof": material("SubstationRoof", (0.14, 0.22, 0.23, 1), roughness=0.56, texture_scale=16.0),
        "steel": material("SubstationSteel", (0.18, 0.20, 0.19, 1), roughness=0.40, metallic=0.68, texture_scale=7.0),
        "transformer": material("TransformerJuniper", (0.16, 0.34, 0.31, 1), roughness=0.48, metallic=0.42, texture_scale=8.0),
        "ceramic": material("InsulatorCeramic", (0.73, 0.43, 0.22, 1), roughness=0.42, texture_scale=4.0),
        "copper": material("BusCopper", (0.60, 0.29, 0.14, 1), roughness=0.35, metallic=0.70, texture_scale=4.0),
        "door": material("SubstationDoor", (0.12, 0.28, 0.26, 1), texture_scale=7.0),
        "warning": material("ElectricalWarning", (0.88, 0.61, 0.12, 1), roughness=0.58, texture_scale=4.0),
    }
    shared_lot(root, "Grid", mats["gravel"], mats["concrete"], mats["steel"])
    # Compact brick control building with four-sided facade detail.
    box(root, "ControlBuildingPlinth", (-0.78, 0.55, 0.19), (2.02, 1.52, 0.28), mats["concrete"], edge=0.035)
    box(root, "ControlBuilding", (-0.78, 0.55, 0.92), (1.84, 1.34, 1.22), mats["brick"], edge=0.035)
    box(root, "LimestoneBelt", (-0.78, 0.55, 1.20), (1.94, 1.44, 0.11), mats["cream"], edge=0.014)
    box(root, "RoofSlab", (-0.78, 0.55, 1.58), (2.04, 1.54, 0.16), mats["roof"], edge=0.025)
    for x, y, name in ((-0.78, -0.145, "Front"), (-0.78, 1.245, "Rear")):
        box(root, f"{name}ServiceDoor", (x, y, 0.87), (0.58, 0.055, 0.92), mats["door"], edge=0.016)
        box(root, f"{name}WarningPlate", (x, y - 0.035 if y < 0 else y + 0.035, 1.08), (0.22, 0.025, 0.20), mats["warning"], edge=0.006)
    for side, x in (("West", -1.72), ("East", 0.16)):
        for index, y in enumerate((0.28, 0.82)):
            box(root, f"{side}Vent{index}", (x, y, 0.91), (0.055, 0.35, 0.42), mats["steel"], edge=0.010)
            for slat in (-0.11, 0, 0.11):
                box(root, f"{side}VentSlat{index}_{slat}", (x - 0.035 if x < 0 else x + 0.035, y + slat, 0.91), (0.025, 0.05, 0.33), mats["cream"], edge=0.004)
    # Two pad-mounted transformers with cooling fins, bushings, and cable cabinets.
    for unit, x in enumerate((0.62, 1.28)):
        box(root, f"TransformerPad{unit}", (x, -0.72, 0.18), (0.56, 0.72, 0.22), mats["concrete"], edge=0.025)
        box(root, f"TransformerTank{unit}", (x, -0.72, 0.76), (0.48, 0.58, 0.92), mats["transformer"], edge=0.075)
        box(root, f"TransformerCap{unit}", (x, -0.72, 1.25), (0.54, 0.64, 0.10), mats["steel"], edge=0.020)
        for fin in (-0.17, -0.06, 0.06, 0.17):
            box(root, f"TransformerFin{unit}_{fin}", (x + fin, -1.035, 0.76), (0.045, 0.10, 0.68), mats["steel"], edge=0.006)
        for bushing, y in enumerate((-0.86, -0.58)):
            cylinder(root, f"TransformerBushing{unit}_{bushing}", (x, y, 1.43), 0.07, 0.34, mats["ceramic"], vertices=16)
            for ring, z in enumerate((1.34, 1.43, 1.52)):
                cylinder(root, f"BushingRing{unit}_{bushing}_{ring}", (x, y, z), 0.105, 0.035, mats["ceramic"], vertices=16, edge=0.004)
    # Gantry and exposed bus work make the electrical use legible at CitySim scale.
    for index, x in enumerate((0.45, 1.48)):
        box(root, f"GantryPost{index}", (x, 0.72, 1.23), (0.10, 0.10, 2.20), mats["steel"], edge=0.010)
    box(root, "GantryCrossbar", (0.965, 0.72, 2.20), (1.20, 0.11, 0.11), mats["steel"], edge=0.012)
    for phase, x in enumerate((0.62, 0.96, 1.30)):
        cylinder(root, f"GantryInsulator{phase}", (x, 0.72, 1.88), 0.07, 0.48, mats["ceramic"], vertices=16)
        for ring, z in enumerate((1.72, 1.88, 2.04)):
            cylinder(root, f"GantryInsulatorRing{phase}_{ring}", (x, 0.72, z), 0.11, 0.038, mats["ceramic"], vertices=16, edge=0.004)
        beam(root, f"CopperBus{phase}", (x, -0.70, 1.62), (x, 0.72, 2.13), 0.038, mats["copper"])
    # Outdoor switchgear and disconnect blades occupy the remaining service apron.
    box(root, "SwitchgearCabinet", (0.88, 1.26, 0.74), (1.15, 0.42, 1.14), mats["steel"], edge=0.045)
    for index, x in enumerate((0.52, 0.88, 1.24)):
        box(root, f"SwitchgearDoor{index}", (x, 1.485, 0.77), (0.29, 0.035, 0.94), mats["transformer"], edge=0.012)
        box(root, f"SwitchgearHandle{index}", (x + 0.09, 1.512, 0.78), (0.025, 0.025, 0.18), mats["warning"], edge=0.004)
    for index, x in enumerate((0.46, 0.96, 1.46)):
        cylinder(root, f"DisconnectBase{index}", (x, 0.05, 0.38), 0.08, 0.42, mats["ceramic"], vertices=16)
        beam(root, f"DisconnectBlade{index}", (x, 0.05, 0.59), (x + 0.24, 0.05, 0.92), 0.04, mats["copper"])
    # Entrance gate and warning sign face the road.
    for x in (-0.34, 0.34):
        box(root, f"GatePost{x}", (x, -1.72, 0.58), (0.08, 0.08, 1.10), mats["steel"], edge=0.009)
    box(root, "SafetyGate", (0, -1.72, 0.60), (0.62, 0.055, 0.90), mats["steel"], edge=0.010)
    box(root, "HighVoltageSign", (0, -1.76, 0.78), (0.30, 0.025, 0.24), mats["warning"], edge=0.006)
    root["assetKind"] = "electrical-distribution-utility"


BUILDERS = {
    "municipal_water_tower": water_tower,
    "brick_grid_substation": substation,
}


def build_asset(asset):
    scene = reset("CitySimUtility_" + asset["assetId"])
    configure_asset_scene(scene)
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


def artifact_info(path, relative_to=HERE):
    info = {
        "path": path.relative_to(relative_to).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
    }
    if path.suffix == ".png":
        width, height, rgba = decode_rgba_png(path)
        info["dimensions"] = [width, height]
        info["decodedRgbaSha256"] = hashlib.sha256(rgba).hexdigest()
    return info


def write_asset_manifest(asset, artifacts):
    output_dir = HERE / asset["assetId"]
    data = {
        "schema": "citysim.world-art.utility-four-view-asset.v1",
        "pipelineSchema": CONFIG["schema"],
        "assetId": asset["assetId"],
        "description": asset["description"],
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
        "perViewCompensation": {
            "rotationDegrees": 0.0,
            "skew": [0.0, 0.0],
            "crop": False,
            "offsetPixels": [0, 0],
            "scale": 1.0,
        },
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
    # Every accepted source owns an identity AssetRoot. Capture each evaluated
    # source-local matrix before removing source cameras/lights/empties, then
    # re-parent the mesh directly under one exact-grid placement empty.
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
    if mesh_count == 0:
        raise RuntimeError(f"NO_MESHES_APPENDED: {source}")
    placement["sourceBlend"] = str(source.relative_to(BLENDER_ROOT))
    placement["gridPlacement"] = list(location)
    placement["perAssetTransformCompensation"] = "none"
    return placement, mesh_count


def configure_preview_scene(scene):
    configure_asset_scene(scene)
    scene.render.film_transparent = False
    scene["previewCameraAzimuthDegrees"] = 45.0
    scene["previewCameraElevationDegrees"] = 30.0
    scene["perAssetTransformCompensation"] = "none"


def preview_rig(scene):
    distance = 40.0
    elevation = math.radians(30.0)
    azimuth = math.radians(45.0)
    horizontal = distance * math.cos(elevation)
    data = bpy.data.cameras.new("camNE_BlockPreview")
    data.type = "ORTHO"
    data.ortho_scale = 15.8
    camera = bpy.data.objects.new("camNE_BlockPreview", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation))
    point_at(camera, Vector((-0.5, 0, 0.85)))
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
    return camera


def build_preview():
    scene = reset("CitySimUtilitiesNeighborhoodEdge")
    configure_preview_scene(scene)
    ground_mat = material("NeighborhoodGround", (0.27, 0.35, 0.23, 1), texture_scale=5.0, bump=0.10)
    preview_root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(preview_root)
    box(preview_root, "NeighborhoodGroundPlane", (0, 0, -0.18), (16, 12, 0.22), ground_mat, edge=0.10)

    accepted = {
        "marigold_court_house": PRODUCTION / "ResidentialCivic" / "marigold_court_house.blend",
        "harbor_corner_storefront": PRODUCTION / "CommercialIndustrial" / "harbor_corner_storefront" / "harbor_corner_storefront.blend",
        "ironleaf_service_workshop": PRODUCTION / "CommercialIndustrial" / "ironleaf_service_workshop" / "ironleaf_service_workshop.blend",
        "axis_civic_road": PRODUCTION / "Environment" / "assets" / "axis_civic_road" / "axis_civic_road.blend",
        "axis_civic_road_dressed": PRODUCTION / "Environment" / "assets" / "axis_civic_road_dressed" / "axis_civic_road_dressed.blend",
    }
    utility_sources = {asset["assetId"]: HERE / asset["assetId"] / f"{asset['assetId']}.blend" for asset in CONFIG["assets"]}
    for path in [*accepted.values(), *utility_sources.values()]:
        if not path.is_file():
            raise RuntimeError(f"MISSING_PREVIEW_SOURCE: {path}")

    placements = []
    # Exact 2-unit lattice placements. One-tile roads use even centers; the
    # adjacent two-by-two lots use odd centers so every footprint edge lands on
    # the same odd-coordinate tile boundary with no half-tile compensation.
    layout = [
        ("municipal_water_tower", utility_sources["municipal_water_tower"], (-3.0, 3.0, 0.0), [2, 2]),
        ("brick_grid_substation", utility_sources["brick_grid_substation"], (3.0, 3.0, 0.0), [2, 2]),
        ("marigold_court_house", accepted["marigold_court_house"], (-5.0, -3.0, 0.0), [2, 2]),
        ("harbor_corner_storefront", accepted["harbor_corner_storefront"], (-1.0, -3.0, 0.0), [2, 2]),
        ("ironleaf_service_workshop", accepted["ironleaf_service_workshop"], (3.0, -3.0, 0.0), [2, 2]),
    ]
    for asset_id, source, location, footprint_tiles in layout:
        placement, count = append_mesh_asset(source, f"Placement_{asset_id}", location)
        placements.append({
            "assetId": asset_id,
            "originWorld": list(location),
            "footprintTiles": footprint_tiles,
            "sourceBlend": source.relative_to(BLENDER_ROOT).as_posix(),
            "sourceBlendSha256": sha256(source),
            "meshCount": count,
            "perAssetTransformCompensation": "none",
        })
    for index, x in enumerate((-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0)):
        road_id = "axis_civic_road_dressed" if index in (1, 5) else "axis_civic_road"
        source = accepted[road_id]
        placement, count = append_mesh_asset(source, f"RoadPlacement_{index}", (x, 0.0, 0.0))
        placements.append({
            "assetId": road_id,
            "originWorld": [x, 0.0, 0.0],
            "footprintTiles": [1, 1],
            "sourceBlend": source.relative_to(BLENDER_ROOT).as_posix(),
            "sourceBlendSha256": sha256(source),
            "meshCount": count,
            "perAssetTransformCompensation": "none",
        })

    preview_rig(scene)
    blend_path = HERE / "preview" / "utilities-neighborhood-edge.blend"
    blend_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = HERE / "preview" / f"utilities-neighborhood-edge-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    manifest = {
        "schema": "citysim.world-art.utility-neighborhood-edge-preview.v1",
        "status": "source-only-review-evidence",
        "liveAsset": False,
        "acceptedFamilyOnly": True,
        "cedarMarketReused": False,
        "camera": {"projection": "orthographic", "azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none"},
        "grid": CONFIG["grid"],
        "lightingConvention": CONFIG["lighting"],
        "placements": placements,
        "artifacts": [artifact_info(blend_path), *[artifact_info(path) for path in outputs]],
    }
    manifest_path = HERE / "preview" / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return blend_path, outputs, manifest_path


def main():
    actual = ".".join(map(str, bpy.app.version))
    if actual != CONFIG["toolchain"]["blenderVersion"]:
        raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    for asset in CONFIG["assets"]:
        output_dir = HERE / asset["assetId"]
        renders_dir = output_dir / "renders"
        scene, _, cameras = build_asset(asset)
        blend_path = output_dir / f"{asset['assetId']}.blend"
        output_dir.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
        render_paths = render_views(scene, cameras, asset["assetId"], renders_dir)
        sheet_path = contact_sheet(render_paths, output_dir / f"{asset['assetId']}_contact-sheet.png")
        write_asset_manifest(asset, [blend_path, *render_paths, sheet_path])
    build_preview()
    print("UTILITY_FOUR_VIEW_RENDER_PASS assets=2 views=8 previews=2")


if __name__ == "__main__":
    main()
