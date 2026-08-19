#!/usr/bin/env python3
"""Build and render CitySim's original 16-mask Four-View streetscape family."""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
BLENDER_ROOT = HERE.parents[1]
CANONICAL = BLENDER_ROOT / "FourViewPipeline"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))
from png_canonical import canonicalize_png, decode_rgba_png, encode_rgba_png  # noqa: E402

CONFIG = json.loads((HERE / "pipeline.json").read_text())
VIEWS = CONFIG["cameraRig"]["views"]
DIRECTIONS = {
    # CitySim grid x projects down-right and grid y projects down-left. Under
    # camNE, those screen axes correspond to Blender -Y and -X respectively.
    "north": {"bit": 1, "point": (-1.0, 0.0, 0.035), "opposite": "south"},
    "east": {"bit": 2, "point": (0.0, -1.0, 0.035), "opposite": "west"},
    "south": {"bit": 4, "point": (1.0, 0.0, 0.035), "opposite": "north"},
    "west": {"bit": 8, "point": (0.0, 1.0, 0.035), "opposite": "east"},
}
SOURCE_DIRECTIONS = {"north": "west", "east": "south", "south": "east", "west": "north"}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def material(name, color, roughness=0.72, metallic=0.0, texture_scale=0.0, bump=0.0):
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
        noise.inputs["Roughness"].default_value = 0.66
        ramp.color_ramp.elements[0].position = 0.24
        ramp.color_ramp.elements[0].color = tuple(max(0.0, c * 0.72) for c in color[:3]) + (color[3],)
        ramp.color_ramp.elements[1].position = 0.78
        ramp.color_ramp.elements[1].color = tuple(min(1.0, c * 1.16 + 0.012) for c in color[:3]) + (color[3],)
        bump_node.inputs["Strength"].default_value = bump
        bump_node.inputs["Distance"].default_value = 0.025
        links.new(coordinates.outputs["Generated"], noise.inputs["Vector"])
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], shader.inputs["Base Color"])
        links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], shader.inputs["Normal"])
    return mat


def mesh_box(root, name, center, dimensions, mat, properties=None):
    cx, cy, cz = center
    dx, dy, dz = (value / 2.0 for value in dimensions)
    vertices = [
        (cx - dx, cy - dy, cz - dz), (cx + dx, cy - dy, cz - dz),
        (cx + dx, cy + dy, cz - dz), (cx - dx, cy + dy, cz - dz),
        (cx - dx, cy - dy, cz + dz), (cx + dx, cy - dy, cz + dz),
        (cx + dx, cy + dy, cz + dz), (cx - dx, cy + dy, cz + dz),
    ]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (4, 0, 3, 7)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    if properties:
        for key, value in properties.items():
            obj[key] = value
    return obj


def mesh_plane(root, name, center, dimensions, mat, properties=None):
    """Create a shadow-seam-free registered road surface."""
    cx, cy, cz = center
    dx, dy = (value / 2.0 for value in dimensions)
    vertices = [
        (cx - dx, cy - dy, cz),
        (cx + dx, cy - dy, cz),
        (cx + dx, cy + dy, cz),
        (cx - dx, cy + dy, cz),
    ]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], [(0, 1, 2, 3)])
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    if properties:
        for key, value in properties.items():
            obj[key] = value
    return obj


def mesh_cylinder(root, name, center, radius, depth, mat, vertices=20, properties=None):
    cx, cy, cz = center
    half = depth / 2.0
    points = []
    for z in (cz - half, cz + half):
        points.extend((cx + radius * math.cos(index * 2 * math.pi / vertices), cy + radius * math.sin(index * 2 * math.pi / vertices), z) for index in range(vertices))
    faces = [tuple(range(vertices - 1, -1, -1)), tuple(range(vertices, vertices * 2))]
    for index in range(vertices):
        nxt = (index + 1) % vertices
        faces.append((index, nxt, vertices + nxt, vertices + index))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(points, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    if properties:
        for key, value in properties.items():
            obj[key] = value
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
    scene.world = bpy.data.worlds.new("CitySimWorld")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = CONFIG["lighting"]["worldColor"]
    background.inputs["Strength"].default_value = CONFIG["lighting"]["worldStrength"]
    scene["pipelineSchema"] = CONFIG["schema"]
    scene["postRenderCompensation"] = "none"
    scene["projectedTilePixels"] = CONFIG["grid"]["projectedTilePixels"]


def point_at(obj, target=Vector((0.0, 0.0, 0.0))):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def add_light(scene):
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
    return light


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
    add_light(scene)
    scene.camera = cameras[0]
    return cameras


def palette():
    return {
        # Reusable road sprites must meet as one material plane. Generated
        # coordinates restart in every sprite, so color noise creates visible
        # checkerboard seams even when the socket geometry is exact.
        "asphalt": material("CivicAsphalt", (0.165, 0.165, 0.155, 1), roughness=0.84),
        "patch": material("AsphaltWearPatch", (0.125, 0.128, 0.120, 1), texture_scale=17.0, bump=0.08),
        "sidewalk": material("WarmAggregateSidewalk", (0.365, 0.35, 0.31, 1), roughness=0.86),
        "curb": material("GraniteCurb", (0.405, 0.385, 0.34, 1), roughness=0.82),
        "yellow": material("RestrainedOchreLanePaint", (0.62, 0.40, 0.11, 1), roughness=0.69),
        "white": material("WarmWhiteRoadPaint", (0.73, 0.70, 0.62, 1), roughness=0.72),
        "iron": material("DrainageIron", (0.105, 0.12, 0.115, 1), roughness=0.48, metallic=0.62, texture_scale=8.0, bump=0.08),
        "brick": material("CivicPaverAccent", (0.48, 0.25, 0.17, 1), texture_scale=17.0, bump=0.16),
        "green": material("PlanterSage", (0.22, 0.34, 0.17, 1), texture_scale=7.0, bump=0.11),
    }


def add_root(mask_data):
    root = bpy.data.objects.new("AssetRoot", None)
    bpy.context.collection.objects.link(root)
    pivot = bpy.data.objects.new("FootprintPivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.parent = root
    pivot.empty_display_type = "CIRCLE"
    pivot.empty_display_size = 0.12
    root["assetId"] = mask_data["assetId"]
    root["roadMaskRawValue"] = mask_data["rawValue"]
    root["topologyClass"] = mask_data["topologyClass"]
    root["directions"] = mask_data["directions"]
    root["sourcePixelsReused"] = False
    root["cedarMarketReused"] = False
    root["liveAsset"] = False
    root["postRenderCompensation"] = "none"
    root["worldCell"] = [2.0, 2.0]
    return root


def add_socket(root, direction):
    point = DIRECTIONS[direction]["point"]
    socket = bpy.data.objects.new("Socket_" + direction.capitalize(), None)
    bpy.context.collection.objects.link(socket)
    socket.parent = root
    socket.location = point
    socket.empty_display_type = "PLAIN_AXES"
    socket.empty_display_size = 0.10
    socket["direction"] = direction
    socket["bit"] = DIRECTIONS[direction]["bit"]
    socket["boundaryMidpoint"] = list(point)
    socket["socketWidthWorld"] = 0.72


def add_arm(root, direction, mats, center=(0.0, 0.0), prefix=""):
    ox, oy = center
    road_width = 0.72
    shoulder_width = 0.94
    curb_offset = 0.375
    curb_width = 0.03
    inner = 0.32
    # Keep the logical socket at exactly +/-1.0 but let identical surface
    # geometry bleed slightly past it. Linear SpriteKit filtering otherwise
    # samples transparent edge pixels and exposes a bright bar between two
    # perfectly registered reusable sprites.
    outer = 1.08
    length = outer - inner
    source_direction = SOURCE_DIRECTIONS[direction]
    if source_direction == "north":
        arm_center, dimensions = (ox, oy + (inner + outer) / 2.0, 0.035), (road_width, length, 0.07)
        shoulder_dimensions = (shoulder_width, length, 0.055)
        curb_specs = [((ox - curb_offset, arm_center[1], 0.076), (curb_width, length)), ((ox + curb_offset, arm_center[1], 0.076), (curb_width, length))]
    elif source_direction == "south":
        arm_center, dimensions = (ox, oy - (inner + outer) / 2.0, 0.035), (road_width, length, 0.07)
        shoulder_dimensions = (shoulder_width, length, 0.055)
        curb_specs = [((ox - curb_offset, arm_center[1], 0.076), (curb_width, length)), ((ox + curb_offset, arm_center[1], 0.076), (curb_width, length))]
    elif source_direction == "east":
        arm_center, dimensions = (ox + (inner + outer) / 2.0, oy, 0.035), (length, road_width, 0.07)
        shoulder_dimensions = (length, shoulder_width, 0.055)
        curb_specs = [((arm_center[0], oy - curb_offset, 0.076), (length, curb_width)), ((arm_center[0], oy + curb_offset, 0.076), (length, curb_width))]
    else:
        arm_center, dimensions = (ox - (inner + outer) / 2.0, oy, 0.035), (length, road_width, 0.07)
        shoulder_dimensions = (length, shoulder_width, 0.055)
        curb_specs = [((arm_center[0], oy - curb_offset, 0.076), (length, curb_width)), ((arm_center[0], oy + curb_offset, 0.076), (length, curb_width))]
    properties = {"roadDirection": direction, "connectionBit": DIRECTIONS[direction]["bit"], "reachesBoundary": True}
    mesh_plane(root, prefix + "RoadShoulder" + direction.capitalize(), (arm_center[0], arm_center[1], 0.039), shoulder_dimensions[:2], mats["sidewalk"])
    mesh_plane(root, prefix + "RoadArm" + direction.capitalize(), (arm_center[0], arm_center[1], 0.07), dimensions[:2], mats["asphalt"], properties)
    for index, (location, size) in enumerate(curb_specs):
        mesh_plane(root, f"{prefix}Curb{direction.capitalize()}{index}", location, size, mats["curb"])


def add_crosswalk(root, direction, mats, center=(0.0, 0.0), prefix=""):
    """Add one restrained stop/crossing bar registered to a road approach."""
    ox, oy = center
    offset = 0.53
    source_direction = SOURCE_DIRECTIONS[direction]
    if source_direction == "north":
        location, dimensions = (ox, oy + offset, 0.102), (0.50, 0.035)
    elif source_direction == "south":
        location, dimensions = (ox, oy - offset, 0.102), (0.50, 0.035)
    elif source_direction == "east":
        location, dimensions = (ox + offset, oy, 0.102), (0.035, 0.50)
    else:
        location, dimensions = (ox - offset, oy, 0.102), (0.035, 0.50)
    mesh_plane(root, f"{prefix}Crosswalk{direction.capitalize()}", location, dimensions, mats["white"])


def add_catch_basin(root, direction, mats, center=(0.0, 0.0), prefix=""):
    """Place one low-contrast drainage grate against the curb, off the lane."""
    ox, oy = center
    source_direction = SOURCE_DIRECTIONS[direction]
    if source_direction == "north":
        location, dimensions = (ox + 0.325, oy + 0.67, 0.103), (0.055, 0.17)
    elif source_direction == "south":
        location, dimensions = (ox - 0.325, oy - 0.67, 0.103), (0.055, 0.17)
    elif source_direction == "east":
        location, dimensions = (ox + 0.67, oy - 0.325, 0.103), (0.17, 0.055)
    else:
        location, dimensions = (ox - 0.67, oy + 0.325, 0.103), (0.17, 0.055)
    mesh_plane(root, f"{prefix}CatchBasin{direction.capitalize()}", location, dimensions, mats["iron"])


def build_road_geometry(root, mask_data, mats, center=(0.0, 0.0), prefix="", include_sockets=True):
    ox, oy = center
    raw = mask_data["rawValue"]
    directions = mask_data["directions"]
    # Roads are transparent socket pieces, not opaque square plates. A compact
    # shoulder follows the corridor while the renderer-owned terrain remains
    # visible between streets, removing the repeated checkerboard effect.
    mesh_plane(root, prefix + "RoadShoulderCore", (ox, oy, 0.039), (0.94, 0.94), mats["sidewalk"], {"worldCell": [2.0, 2.0]})
    mesh_plane(root, prefix + "AsphaltCore", (ox, oy, 0.07), (0.72, 0.72), mats["asphalt"], {"roadMaskRawValue": raw})
    for direction in directions:
        add_arm(root, direction, mats, center, prefix)
        if include_sockets:
            add_socket(root, direction)
    # Cap only the central roadbed on closed sides. Full-cell boundary scoring
    # made adjacent tiles read as a collage and is intentionally absent.
    absent = [name for name in DIRECTIONS if name not in directions]
    for direction in absent:
        source_direction = SOURCE_DIRECTIONS[direction]
        if source_direction in ("north", "south"):
            y = oy + (0.375 if source_direction == "north" else -0.375)
            mesh_plane(root, f"{prefix}ClosedEdge{direction.capitalize()}", (ox, y, 0.076), (0.75, 0.03), mats["curb"], {"closedBoundary": direction})
        else:
            x = ox + (0.375 if source_direction == "east" else -0.375)
            mesh_plane(root, f"{prefix}ClosedEdge{direction.capitalize()}", (x, oy, 0.076), (0.03, 0.75), mats["curb"], {"closedBoundary": direction})
    if raw == 0:
        # Deliberate isolated paved turnaround, not an accidental missing road.
        for index, (x, y) in enumerate(((-0.50, -0.50), (0.50, -0.50), (-0.50, 0.50), (0.50, 0.50))):
            mesh_cylinder(root, f"{prefix}IsolationBollard{index}", (ox + x, oy + y, 0.17), 0.055, 0.25, mats["yellow"], vertices=12)
    if raw == 15:
        for direction in directions:
            add_crosswalk(root, direction, mats, center, prefix)
    if raw in (7, 11, 13, 14, 15):
        # One grate is enough to break repetition while keeping topology clear.
        add_catch_basin(root, directions[0], mats, center, prefix)


def build_asset(mask_data):
    scene = reset("CitySimStreet_" + mask_data["assetId"])
    configure_scene(scene, transparent=True)
    root = add_root(mask_data)
    mats = palette()
    build_road_geometry(root, mask_data, mats)
    cameras = canonical_rig(scene)
    return scene, root, cameras


def render_views(scene, cameras, asset_id, output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for camera in cameras:
        scene.camera = camera
        path = output_dir / f"{asset_id}_{camera.name}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        paths.append(path)
    return paths


def contact_sheet(paths, output_path):
    width, height = 784, 840
    rgba = bytearray(width * height * 4)
    for index, path in enumerate(paths):
        source_width, source_height, source = decode_rgba_png(path)
        x0 = 8 + (index % 2) * 392
        y0 = 24 + (index // 2) * 408
        for y in range(source_height):
            destination = ((y0 + y) * width + x0) * 4
            source_offset = y * source_width * 4
            rgba[destination:destination + source_width * 4] = source[source_offset:source_offset + source_width * 4]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    encode_rgba_png(output_path, width, height, bytes(rgba))
    return output_path


def alpha_metadata(path):
    width, height, rgba = decode_rgba_png(path)
    opaque = [(index % width, index // width) for index, alpha in enumerate(rgba[3::4]) if alpha]
    min_x = min(point[0] for point in opaque)
    max_x = max(point[0] for point in opaque)
    min_y = min(point[1] for point in opaque)
    max_y = max(point[1] for point in opaque)
    pivot = CONFIG["canvas"]["footprintPivotPixel"]
    pivot_alpha = rgba[(pivot[1] * width + pivot[0]) * 4 + 3]
    return {
        "boundsTopOrigin": {"minX": min_x, "minY": min_y, "maxX": max_x, "maxY": max_y, "width": max_x - min_x + 1, "height": max_y - min_y + 1},
        "opaquePixelCount": len(opaque),
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


def write_asset_manifest(mask_data, artifacts):
    output_dir = HERE / mask_data["assetId"]
    sockets = {name: CONFIG["grid"]["boundaryMidpoints"][name] for name in mask_data["directions"]}
    data = {
        "schema": "citysim.world-art.streetscape-four-view-mask.v1",
        "pipelineSchema": CONFIG["schema"],
        "assetId": mask_data["assetId"],
        "roadConnectionMask": {"rawValue": mask_data["rawValue"], "bits": CONFIG["roadBits"], "directions": mask_data["directions"], "topologyClass": mask_data["topologyClass"]},
        "status": "live-game-catalog",
        "liveAsset": True,
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "cedarMarketReused": False,
        "grid": CONFIG["grid"],
        "boundarySockets": sockets,
        "absentBoundarySockets": [name for name in DIRECTIONS if name not in mask_data["directions"]],
        "canvas": CONFIG["canvas"],
        "cameraOrder": [view["name"] for view in VIEWS],
        "cameraRig": CONFIG["cameraRig"],
        "lightingConvention": CONFIG["lighting"],
        "root": CONFIG["root"],
        "transforms": {"assetRoot": "identity", "meshObjects": "identity", "perMaskCompensation": "none"},
        "postRenderCompensation": "none",
        "perViewCompensation": {"rotationDegrees": 0.0, "skew": [0.0, 0.0], "crop": False, "offsetPixels": [0, 0], "scale": 1.0},
        "validation": {"socketGeometry": "source-mesh-bounds", "deterministicRerender": "required-byte-identical", "status": "pending-validator"},
        "sourceFiles": [source_info(HERE / name) for name in ("build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py")],
        "artifacts": [artifact_info(path, output_dir) for path in artifacts],
    }
    path = output_dir / "manifest.json"
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return path


def preview_network():
    coordinates = set((x, 0) for x in range(-3, 4))
    coordinates.update((0, y) for y in range(-3, 4))
    coordinates.update({(-2, 1), (-1, 1), (2, -1), (1, -1)})
    isolated = (4, 2)
    coordinates.add(isolated)
    placements = []
    for x, y in sorted(coordinates, key=lambda item: (item[1], item[0])):
        raw = 0
        if (x, y + 1) in coordinates and (x, y) != isolated:
            raw |= 1
        if (x + 1, y) in coordinates and (x, y) != isolated:
            raw |= 2
        if (x, y - 1) in coordinates and (x, y) != isolated:
            raw |= 4
        if (x - 1, y) in coordinates and (x, y) != isolated:
            raw |= 8
        placements.append({"coordinate": [x, y], "originWorld": [-y * 2.0, -x * 2.0, 0.0], "rawValue": raw})
    return placements


def topology_for(raw):
    return next(item for item in CONFIG["masks"] if item["rawValue"] == raw)


def preview_rig(scene):
    distance = 48.0
    elevation = math.radians(30.0)
    azimuth = math.radians(45.0)
    horizontal = distance * math.cos(elevation)
    data = bpy.data.cameras.new("camNE_ConnectedDistrict")
    data.type = "ORTHO"
    data.ortho_scale = 22.0
    camera = bpy.data.objects.new("camNE_ConnectedDistrict", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation))
    point_at(camera, Vector((0.5, 0.0, 0.0)))
    add_light(scene)
    scene.camera = camera


def build_preview(output_dir=None, write_evidence=True):
    scene = reset("CitySimCivicWorksConnectedDistrict")
    configure_scene(scene, transparent=False)
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    mats = palette()
    ground = material("DistrictSageGround", (0.25, 0.34, 0.20, 1), texture_scale=8.0, bump=0.12)
    trunk = material("StreetTreeBark", (0.25, 0.14, 0.08, 1), texture_scale=9.0, bump=0.10)
    leaf = material("StreetTreeCanopy", (0.18, 0.32, 0.14, 1), texture_scale=7.0, bump=0.10)
    mesh_box(root, "DistrictGround", (1.0, 0.0, -0.16), (20.0, 16.0, 0.20), ground)
    placements = preview_network()
    topology_classes = set()
    for placement in placements:
        mask_data = topology_for(placement["rawValue"])
        topology_classes.add(mask_data["topologyClass"])
        x, y, _ = placement["originWorld"]
        build_road_geometry(root, mask_data, mats, (x, y), f"Tile_{placement['coordinate'][0]}_{placement['coordinate'][1]}_", include_sockets=False)
        placement["assetId"] = mask_data["assetId"]
        placement["topologyClass"] = mask_data["topologyClass"]
        placement["perAssetTransformCompensation"] = "none"
    # Original public-realm context stays on the same two-unit grid and never overlays road sockets.
    for index, (x, y) in enumerate(((-5, 3), (-3, -3), (3, 3), (5, -3), (7, 1))):
        mesh_cylinder(root, f"TreeTrunk{index}", (x, y, 0.35), 0.11, 0.70, trunk, vertices=14)
        mesh_cylinder(root, f"TreeCanopy{index}", (x, y, 0.88), 0.42, 0.58, leaf, vertices=18)
    preview_rig(scene)
    preview_dir = output_dir if output_dir is not None else HERE / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    blend_path = preview_dir / "civic-works-connected-district.blend"
    if write_evidence:
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = preview_dir / f"civic-works-connected-district-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    if not write_evidence:
        return outputs
    manifest = {
        "schema": "citysim.world-art.streetscape-connected-district-preview.v1",
        "status": "source-only-review-evidence",
        "liveAsset": False,
        "originalGeometry": True,
        "cedarMarketReused": False,
        "camera": {"projection": "orthographic", "azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none"},
        "grid": CONFIG["grid"],
        "lightingConvention": CONFIG["lighting"],
        "requiredTopologyClasses": ["isolated", "end", "straight", "corner", "tee", "crossing"],
        "observedTopologyClasses": sorted(topology_classes),
        "placements": placements,
        "artifacts": [artifact_info(blend_path), *[artifact_info(path) for path in outputs]],
    }
    (preview_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return outputs


def write_family_manifest(mask_manifests):
    data = {
        "schema": "citysim.world-art.streetscape-family-manifest.v1",
        "status": "live-game-catalog",
        "liveAsset": True,
        "familyId": "civic-works-yard-road-connection-masks",
        "maskCount": 16,
        "canonicalViewCount": 64,
        "roadBits": CONFIG["roadBits"],
        "grid": CONFIG["grid"],
        "canvas": CONFIG["canvas"],
        "cameraRig": CONFIG["cameraRig"],
        "lightingConvention": CONFIG["lighting"],
        "postRenderCompensation": "none",
        "provenance": CONFIG["provenance"],
        "sourceFiles": [source_info(HERE / name) for name in ("build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py")],
        "masks": [{"rawValue": item["rawValue"], "assetId": item["assetId"], "topologyClass": item["topologyClass"], "directions": item["directions"], "manifest": path.relative_to(HERE).as_posix(), "manifestSha256": sha256(path)} for item, path in zip(CONFIG["masks"], mask_manifests)],
        "previewManifest": "preview/manifest.json",
    }
    (HERE / "family-manifest.json").write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def main():
    actual = ".".join(map(str, bpy.app.version))
    if actual != CONFIG["toolchain"]["blenderVersion"]:
        raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    manifests = []
    for mask_data in CONFIG["masks"]:
        output_dir = HERE / mask_data["assetId"]
        output_dir.mkdir(parents=True, exist_ok=True)
        scene, _, cameras = build_asset(mask_data)
        blend_path = output_dir / f"{mask_data['assetId']}.blend"
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
        render_paths = render_views(scene, cameras, mask_data["assetId"], output_dir / "renders")
        sheet_path = contact_sheet(render_paths, output_dir / f"{mask_data['assetId']}_contact-sheet.png")
        manifests.append(write_asset_manifest(mask_data, [blend_path, *render_paths, sheet_path]))
    build_preview()
    write_family_manifest(manifests)
    print("STREETSCAPE_FOUR_VIEW_RENDER_PASS masks=16 views=64 previews=2")


if __name__ == "__main__":
    main()
