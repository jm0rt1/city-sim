#!/usr/bin/env python3
"""Build and render CitySim's original continuous 16-mask roadway family."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
BASE_PATH = HERE.parent / "Streetscape" / "build_and_render.py"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("citysim_streetscape_contract", BASE_PATH)
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

CONFIG = json.loads((HERE / "pipeline.json").read_text())
VIEWS = CONFIG["cameraRig"]["views"]
base.CONFIG = CONFIG
base.VIEWS = VIEWS

DIRECTIONS = {
    "north": {"bit": 1, "vector": (-1.0, 0.0), "point": (-1.0, 0.0, 0.035), "opposite": "south"},
    "east": {"bit": 2, "vector": (0.0, -1.0), "point": (0.0, -1.0, 0.035), "opposite": "west"},
    "south": {"bit": 4, "vector": (1.0, 0.0), "point": (1.0, 0.0, 0.035), "opposite": "north"},
    "west": {"bit": 8, "vector": (0.0, 1.0), "point": (0.0, 1.0, 0.035), "opposite": "east"},
}

mesh_box = base.mesh_box
mesh_plane = base.mesh_plane
mesh_cylinder = base.mesh_cylinder
reset = base.reset
configure_scene = base.configure_scene
canonical_rig = base.canonical_rig
point_at = base.point_at
canonicalize_png = base.canonicalize_png
decode_rgba_png = base.decode_rgba_png
encode_rgba_png = base.encode_rgba_png


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def periodic_material(name, dark, light, roughness, period_scale=2.6, bump=0.035):
    """World-position material with a two-world-unit periodic boundary phase."""
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = light
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    shader = nodes["Principled BSDF"]
    shader.inputs["Roughness"].default_value = roughness

    geometry = nodes.new("ShaderNodeNewGeometry")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geometry.outputs["Position"], separate.inputs["Vector"])

    channels = []
    for source_name, phase in (("X", 0.0), ("X", math.pi / 2.0), ("Y", 0.0), ("Y", math.pi / 2.0)):
        multiply = nodes.new("ShaderNodeMath")
        multiply.operation = "MULTIPLY"
        multiply.inputs[1].default_value = math.pi
        links.new(separate.outputs[source_name], multiply.inputs[0])
        current = multiply
        if phase:
            add = nodes.new("ShaderNodeMath")
            add.operation = "ADD"
            add.inputs[1].default_value = phase
            links.new(current.outputs[0], add.inputs[0])
            current = add
        sine = nodes.new("ShaderNodeMath")
        sine.operation = "SINE"
        links.new(current.outputs[0], sine.inputs[0])
        channels.append(sine)

    combine = nodes.new("ShaderNodeCombineXYZ")
    links.new(channels[0].outputs[0], combine.inputs["X"])
    links.new(channels[1].outputs[0], combine.inputs["Y"])
    links.new(channels[2].outputs[0], combine.inputs["Z"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.noise_dimensions = "4D"
    noise.inputs["Scale"].default_value = period_scale
    noise.inputs["Detail"].default_value = 4.0
    noise.inputs["Roughness"].default_value = 0.72
    links.new(combine.outputs["Vector"], noise.inputs["Vector"])
    links.new(channels[3].outputs[0], noise.inputs["W"])

    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.22
    ramp.color_ramp.elements[0].color = dark
    ramp.color_ramp.elements[1].position = 0.78
    ramp.color_ramp.elements[1].color = light
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], shader.inputs["Base Color"])

    bump_node = nodes.new("ShaderNodeBump")
    bump_node.inputs["Strength"].default_value = bump
    bump_node.inputs["Distance"].default_value = 0.018
    links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
    links.new(bump_node.outputs["Normal"], shader.inputs["Normal"])
    return mat


def flat_material(name, color, roughness=0.8, metallic=0.0):
    return base.material(name, color, roughness=roughness, metallic=metallic)


def palette():
    return {
        "asphalt": periodic_material(
            "ContinuousRichCharcoalAsphalt",
            (0.105, 0.122, 0.115, 1),
            (0.205, 0.225, 0.205, 1),
            roughness=0.87,
            period_scale=3.4,
            bump=0.055,
        ),
        "sidewalk": periodic_material(
            "ContinuousWarmConcreteSidewalk",
            (0.39, 0.37, 0.33, 1),
            (0.54, 0.505, 0.44, 1),
            roughness=0.91,
            period_scale=2.1,
            bump=0.025,
        ),
        "curb": flat_material("ContinuousCutStoneCurb", (0.62, 0.56, 0.46, 1), roughness=0.88),
        "yellow": flat_material("ContinuousWarmOchreCenterMarking", (0.82, 0.49, 0.07, 1), roughness=0.72),
        "white": flat_material("ContinuousWarmWhiteMarking", (0.82, 0.80, 0.72, 1), roughness=0.75),
        "iron": flat_material("ContinuousRoadIron", (0.09, 0.105, 0.11, 1), roughness=0.54, metallic=0.58),
        "patch": flat_material("ContinuousAsphaltRepair", (0.135, 0.145, 0.15, 1), roughness=0.91),
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
    root["surfaceFamily"] = "continuous-rich-charcoal-v2"
    root["boundaryMarkingPhase"] = "ochre-dash-centered-on-every-tile-boundary"
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
    socket["socketWidthWorld"] = CONFIG["surface"]["roadWidthWorld"]
    socket["materialOverlapWorld"] = CONFIG["surface"]["socketBleedWorld"]
    socket["markingPhase"] = "dash-center-at-boundary"


def mesh_disc(root, name, center, radius, mat, vertices=40, properties=None):
    cx, cy, cz = center
    points = [(cx, cy, cz)]
    points.extend(
        (cx + radius * math.cos(index * 2 * math.pi / vertices), cy + radius * math.sin(index * 2 * math.pi / vertices), cz)
        for index in range(vertices)
    )
    faces = [(0, index + 1, (index + 1) % vertices + 1) for index in range(vertices)]
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


def mesh_ring(root, name, center, inner_radius, outer_radius, z, mat, vertices=40, properties=None):
    cx, cy = center
    points = []
    for radius in (inner_radius, outer_radius):
        points.extend(
            (cx + radius * math.cos(index * 2 * math.pi / vertices), cy + radius * math.sin(index * 2 * math.pi / vertices), z)
            for index in range(vertices)
        )
    faces = []
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


def mesh_arc_strip(root, name, center, radius, start_angle, end_angle, width, z, mat, segments=16, properties=None):
    while end_angle - start_angle > math.pi:
        end_angle -= 2 * math.pi
    while end_angle - start_angle < -math.pi:
        end_angle += 2 * math.pi
    inner = max(0.012, radius - width / 2.0)
    outer = radius + width / 2.0
    points = []
    for index in range(segments + 1):
        angle = start_angle + (end_angle - start_angle) * index / segments
        points.append((center[0] + inner * math.cos(angle), center[1] + inner * math.sin(angle), z))
        points.append((center[0] + outer * math.cos(angle), center[1] + outer * math.sin(angle), z))
    faces = [(index * 2, index * 2 + 1, index * 2 + 3, index * 2 + 2) for index in range(segments)]
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


def direction_basis(direction):
    dx, dy = DIRECTIONS[direction]["vector"]
    return (dx, dy), (-dy, dx)


def mesh_strip_along(root, name, direction, start, end, lateral, width, z, mat, properties=None):
    (dx, dy), (px, py) = direction_basis(direction)
    center_distance = (start + end) / 2.0
    cx = dx * center_distance + px * lateral
    cy = dy * center_distance + py * lateral
    length = end - start
    dimensions = (length, width) if dx else (width, length)
    return mesh_plane(root, name, (cx, cy, z), dimensions, mat, properties)


def curb_box_along(root, name, direction, start, end, lateral, mats):
    (dx, dy), (px, py) = direction_basis(direction)
    center_distance = (start + end) / 2.0
    cx = dx * center_distance + px * lateral
    cy = dy * center_distance + py * lateral
    length = end - start
    width = CONFIG["surface"]["curbWidthWorld"]
    dimensions = (length, width, 0.062) if dx else (width, length, 0.062)
    return mesh_box(root, name, (cx, cy, 0.071), dimensions, mats["curb"], {"modeledCurbFace": True})


def add_arm_surfaces(root, direction, mats, prefix=""):
    surface = CONFIG["surface"]
    outer = 1.0 + surface["socketBleedWorld"]
    mesh_strip_along(
        root,
        prefix + "WalkArm" + direction.capitalize(),
        direction,
        0.0,
        outer,
        0.0,
        surface["walkWidthWorld"],
        0.040,
        mats["sidewalk"],
        {"roadDirection": direction, "reachesBoundary": True},
    )
    mesh_strip_along(
        root,
        prefix + "RoadArm" + direction.capitalize(),
        direction,
        0.0,
        outer,
        0.0,
        surface["roadWidthWorld"],
        0.055,
        mats["asphalt"],
        {
            "roadDirection": direction,
            "connectionBit": DIRECTIONS[direction]["bit"],
            "reachesBoundary": True,
            "bleedBoundaryWorld": outer,
        },
    )


def add_arm_curbs(root, direction, mats, start, prefix=""):
    surface = CONFIG["surface"]
    outer = 1.0 + surface["socketBleedWorld"]
    lateral = surface["roadWidthWorld"] / 2.0 + surface["curbWidthWorld"] / 2.0
    for side in (-1.0, 1.0):
        curb_box_along(
            root,
            f"{prefix}Curb{direction.capitalize()}{'Left' if side < 0 else 'Right'}",
            direction,
            start,
            outer,
            side * lateral,
            mats,
        )


def add_centerline_arm(root, direction, mats, start, prefix=""):
    surface = CONFIG["surface"]
    outer = 1.0 + surface["socketBleedWorld"]
    line_width = surface["centerlineWidthWorld"]
    dash_half = 0.13
    dash_period = 0.50
    for dash_index, center in enumerate((0.0, 0.5, 1.0)):
        dash_start = max(start, center - dash_half)
        dash_end = min(outer, center + dash_half)
        if dash_end - dash_start < 0.025:
            continue
        mesh_strip_along(
            root,
            f"{prefix}Centerline{direction.capitalize()}Dash{dash_index}",
            direction,
            dash_start,
            dash_end,
            0.0,
            line_width,
            0.073,
            mats["yellow"],
            {
                "boundaryPhase": "dash-center-at-boundary",
                "dashPeriodWorld": dash_period,
                "reachesBoundary": center == 1.0,
            },
        )


def add_corner_centerlines(root, directions, mats, prefix=""):
    radius = CONFIG["surface"]["cornerRadiusWorld"]
    d1 = Vector((*DIRECTIONS[directions[0]]["vector"], 0.0))
    d2 = Vector((*DIRECTIONS[directions[1]]["vector"], 0.0))
    center = radius * (d1 + d2)
    p1 = radius * d1
    p2 = radius * d2
    a1 = math.atan2(p1.y - center.y, p1.x - center.x)
    a2 = math.atan2(p2.y - center.y, p2.x - center.x)
    mesh_arc_strip(
        root,
        prefix + "CornerCenterlineContinuation",
        (center.x, center.y),
        radius,
        a1,
        a2,
        CONFIG["surface"]["centerlineWidthWorld"],
        0.073,
        mats["yellow"],
        segments=18,
        properties={"boundaryPhase": "registered-arms-solid-corner-transition", "cornerContinuation": True},
    )


def add_corner_curbs(root, directions, mats, prefix=""):
    surface = CONFIG["surface"]
    radius = surface["cornerRadiusWorld"]
    d1 = Vector((*DIRECTIONS[directions[0]]["vector"], 0.0))
    d2 = Vector((*DIRECTIONS[directions[1]]["vector"], 0.0))
    center = radius * (d1 + d2)
    p1 = radius * d1
    p2 = radius * d2
    a1 = math.atan2(p1.y - center.y, p1.x - center.x)
    a2 = math.atan2(p2.y - center.y, p2.x - center.x)
    for index, curve_radius in enumerate((radius - surface["roadWidthWorld"] / 2.0, radius + surface["roadWidthWorld"] / 2.0)):
        mesh_arc_strip(
            root,
            f"{prefix}CornerCurb{'Inner' if index == 0 else 'Outer'}",
            (center.x, center.y),
            curve_radius,
            a1,
            a2,
            surface["curbWidthWorld"],
            0.102,
            mats["curb"],
            segments=20,
            properties={"modeledCurbFace": True, "cornerContinuation": True},
        )


def add_stop_bar(root, direction, mats, prefix=""):
    surface = CONFIG["surface"]
    mesh_strip_along(
        root,
        prefix + "StopBar" + direction.capitalize(),
        direction,
        0.585,
        0.635,
        0.0,
        surface["roadWidthWorld"] * 0.80,
        0.074,
        mats["white"],
        {"junctionDetail": True},
    )


def add_crosswalk(root, direction, mats, prefix=""):
    surface = CONFIG["surface"]
    for index, distance in enumerate((0.70, 0.79, 0.88)):
        mesh_strip_along(
            root,
            f"{prefix}Crosswalk{direction.capitalize()}{index}",
            direction,
            distance - 0.027,
            distance + 0.027,
            0.0,
            surface["roadWidthWorld"] * 0.72,
            0.074,
            mats["white"],
            {"junctionDetail": True},
        )


def add_sparse_road_detail(root, mask_data, mats, prefix=""):
    """Central-only detail avoids exposing the repeated socket grid."""
    raw = mask_data["rawValue"]
    if raw in (7, 11, 13, 14):
        direction = mask_data["directions"][raw % 3]
        (dx, dy), (px, py) = direction_basis(direction)
        x = dx * 0.45 + px * 0.42
        y = dy * 0.45 + py * 0.42
        dimensions = (0.16, 0.055) if dx else (0.055, 0.16)
        mesh_box(root, prefix + "CatchBasin", (x, y, 0.074), (*dimensions, 0.014), mats["iron"], {"topologyPermitsDetail": True})
    elif raw == 15:
        mesh_disc(root, prefix + "JunctionManhole", (0.18, -0.16, 0.074), 0.105, mats["iron"], vertices=24, properties={"topologyPermitsDetail": True})
    elif raw == 0:
        mesh_disc(root, prefix + "TurnaroundRepair", (0.0, 0.0, 0.072), 0.22, mats["patch"], vertices=28, properties={"topologyPermitsDetail": True})


def build_road_geometry(root, mask_data, mats, center=(0.0, 0.0), prefix="", include_sockets=True):
    """Create one topology from registered corridor pieces with no tile plate."""
    ox, oy = center
    holder = root
    if center != (0.0, 0.0):
        holder = bpy.data.objects.new(prefix + "RegisteredTileRoot", None)
        bpy.context.collection.objects.link(holder)
        holder.parent = root
        holder.location = (ox, oy, 0.0)
        holder["registeredWorldOrigin"] = [ox, oy, 0.0]

    surface = CONFIG["surface"]
    directions = mask_data["directions"]
    topology = mask_data["topologyClass"]
    if not directions:
        mesh_disc(holder, prefix + "WalkCore", (0.0, 0.0, 0.040), surface["walkWidthWorld"] / 2.0, mats["sidewalk"], vertices=44)
        mesh_disc(holder, prefix + "AsphaltCore", (0.0, 0.0, 0.055), surface["roadWidthWorld"] / 2.0, mats["asphalt"], vertices=44)
        mesh_ring(
            holder,
            prefix + "TurnaroundCurb",
            (0.0, 0.0),
            surface["roadWidthWorld"] / 2.0,
            surface["roadWidthWorld"] / 2.0 + surface["curbWidthWorld"],
            0.102,
            mats["curb"],
            vertices=40,
            properties={"modeledCurbFace": True},
        )
        add_sparse_road_detail(holder, mask_data, mats, prefix)
        return

    for direction in directions:
        add_arm_surfaces(holder, direction, mats, prefix)
        if include_sockets:
            add_socket(holder, direction)

    if topology == "straight":
        curb_start = 0.0
    elif topology == "corner":
        curb_start = surface["cornerRadiusWorld"]
    elif topology in ("tee", "crossing"):
        curb_start = 0.62
    else:
        curb_start = 0.0
    for direction in directions:
        add_arm_curbs(holder, direction, mats, curb_start, prefix)

    if topology == "end":
        mesh_disc(holder, prefix + "EndpointWalkCap", (0.0, 0.0, 0.040), surface["walkWidthWorld"] / 2.0, mats["sidewalk"], vertices=40)
        mesh_disc(holder, prefix + "EndpointAsphaltCap", (0.0, 0.0, 0.055), surface["roadWidthWorld"] / 2.0, mats["asphalt"], vertices=40)
        add_centerline_arm(holder, directions[0], mats, 0.14, prefix)
        add_stop_bar(holder, directions[0], mats, prefix)
    elif topology == "straight":
        for direction in directions:
            add_centerline_arm(holder, direction, mats, 0.0, prefix)
    elif topology == "corner":
        radius = surface["cornerRadiusWorld"]
        for direction in directions:
            add_centerline_arm(holder, direction, mats, radius, prefix)
        add_corner_centerlines(holder, directions, mats, prefix)
        add_corner_curbs(holder, directions, mats, prefix)
    else:
        for direction in directions:
            add_centerline_arm(holder, direction, mats, surface["junctionLineStopWorld"], prefix)
            add_stop_bar(holder, direction, mats, prefix)
        crossing_direction = directions[mask_data["rawValue"] % len(directions)]
        add_crosswalk(holder, crossing_direction, mats, prefix)
        if topology == "crossing":
            add_crosswalk(holder, DIRECTIONS[crossing_direction]["opposite"], mats, prefix)
    add_sparse_road_detail(holder, mask_data, mats, prefix)


def build_asset(mask_data):
    scene = reset("CitySimContinuousStreet_" + mask_data["assetId"])
    configure_scene(scene, transparent=True)
    scene["surfaceFamily"] = "continuous-rich-charcoal-v2"
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
    pivot = CONFIG["canvas"]["footprintPivotPixel"]
    return {
        "boundsTopOrigin": {
            "minX": min(point[0] for point in opaque), "minY": min(point[1] for point in opaque),
            "maxX": max(point[0] for point in opaque), "maxY": max(point[1] for point in opaque),
        },
        "opaquePixelCount": len(opaque),
        "lowestOpaqueRowTopOrigin": max(point[1] for point in opaque),
        "pivotPixelAlpha": rgba[(pivot[1] * width + pivot[0]) * 4 + 3],
    }


def artifact_info(path, relative_to=HERE):
    info = {"path": path.relative_to(relative_to).as_posix(), "bytes": path.stat().st_size, "sha256": sha256(path)}
    if path.suffix == ".png":
        width, height, rgba = decode_rgba_png(path)
        info.update({"dimensions": [width, height], "decodedRgbaSha256": hashlib.sha256(rgba).hexdigest(), "alpha": alpha_metadata(path)})
    return info


def source_info(path):
    return {"path": path.relative_to(HERE).as_posix(), "sha256": sha256(path)}


def source_files():
    return [source_info(HERE / name) for name in ("build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py")]


def write_asset_manifest(mask_data, artifacts):
    output_dir = HERE / mask_data["assetId"]
    data = {
        "schema": "citysim.world-art.streetscape-continuous-mask.v1",
        "pipelineSchema": CONFIG["schema"],
        "assetId": mask_data["assetId"],
        "roadConnectionMask": {"rawValue": mask_data["rawValue"], "bits": CONFIG["roadBits"], "directions": mask_data["directions"], "topologyClass": mask_data["topologyClass"]},
        "status": "source-only-candidate",
        "liveAsset": False,
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "cedarMarketReused": False,
        "grid": CONFIG["grid"],
        "surface": CONFIG["surface"],
        "boundarySockets": {name: CONFIG["grid"]["boundaryMidpoints"][name] for name in mask_data["directions"]},
        "absentBoundarySockets": [name for name in DIRECTIONS if name not in mask_data["directions"]],
        "boundaryMaterialContract": "identical-periodic-asphalt-sidewalk-curb-and-ochre-dash-boundary-phase",
        "canvas": CONFIG["canvas"],
        "cameraOrder": [view["name"] for view in VIEWS],
        "cameraRig": CONFIG["cameraRig"],
        "lightingConvention": CONFIG["lighting"],
        "root": CONFIG["root"],
        "transforms": {"assetRoot": "identity", "meshObjects": "identity", "perMaskCompensation": "none"},
        "postRenderCompensation": "none",
        "perViewCompensation": {"rotationDegrees": 0.0, "skew": [0.0, 0.0], "crop": False, "offsetPixels": [0, 0], "scale": 1.0},
        "validation": {"status": "pending-validator", "socketGeometry": "source-mesh-bounds", "deterministicRerender": "required-byte-identical"},
        "sourceFiles": source_files(),
        "artifacts": [artifact_info(path, output_dir) for path in artifacts],
    }
    path = output_dir / "manifest.json"
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return path


def preview_network():
    coords = set((x, 0) for x in range(-5, 6))
    coords.update((0, y) for y in range(-4, 5))
    coords.update((x, 3) for x in range(-4, 5))
    coords.update((x, -3) for x in range(-4, 5))
    coords.update((-4, y) for y in range(-3, 4))
    coords.update((4, y) for y in range(-3, 4))
    coords.update(
        {
            (-2, 1),
            (-2, 2),
            (2, -1),
            (2, -2),
            (-5, 1),
            (5, -1),
            (6, 3),
            (-5, -2),
            (5, 2),
        }
    )
    offsets = {"north": (0, 1), "east": (1, 0), "south": (0, -1), "west": (-1, 0)}
    placements = []
    for x, y in sorted(coords, key=lambda point: (-point[1], point[0])):
        raw = sum(spec["bit"] for name, spec in DIRECTIONS.items() if (x + offsets[name][0], y + offsets[name][1]) in coords)
        placements.append({"coordinate": [x, y], "originWorld": [-y * 2.0, -x * 2.0, 0.0], "rawValue": raw})
    return placements


def topology_for(raw):
    return next(item for item in CONFIG["masks"] if item["rawValue"] == raw)


def mesh_hip_roof(root, name, center, footprint, height, mat):
    cx, cy, cz = center
    dx, dy = footprint[0] / 2.0, footprint[1] / 2.0
    vertices = [(cx - dx, cy - dy, cz), (cx + dx, cy - dy, cz), (cx + dx, cy + dy, cz), (cx - dx, cy + dy, cz), (cx, cy, cz + height)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (0, 3, 2, 1)])
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    return obj


def add_preview_building(root, index, grid_coordinate, mats):
    gx, gy = grid_coordinate
    x, y = -gy * 2.0, -gx * 2.0
    facade = mats["brick"] if index % 2 == 0 else mats["stone"]
    height = 1.35 + (index % 3) * 0.24
    mesh_box(root, f"ContextBuilding{index}", (x, y, height / 2.0), (1.18, 1.18, height), facade)
    mesh_hip_roof(root, f"ContextRoof{index}", (x, y, height), (1.38, 1.38), 0.44, mats["roof"])
    for level in (0.48, 0.92):
        if level < height:
            mesh_box(root, f"ContextWindowX{index}_{level}", (x + 0.596, y, level), (0.018, 0.50, 0.18), mats["window"])
            mesh_box(root, f"ContextWindowY{index}_{level}", (x, y + 0.596, level), (0.50, 0.018, 0.18), mats["window"])


def preview_rig(scene):
    distance = 50.0
    elevation = math.radians(30.0)
    azimuth = math.radians(45.0)
    horizontal = distance * math.cos(elevation)
    data = bpy.data.cameras.new("camNE_ContinuousConnectedDistrict")
    data.type = "ORTHO"
    data.ortho_scale = 25.0
    camera = bpy.data.objects.new("camNE_ContinuousConnectedDistrict", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation))
    point_at(camera, Vector((0.0, -1.0, 0.0)))
    base.add_light(scene)
    scene.camera = camera


def build_preview(output_dir=None, write_evidence=True):
    scene = reset("CitySimContinuousConnectedDistrict")
    configure_scene(scene, transparent=False)
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    road_mats = palette()
    context = {
        "ground": periodic_material("ContinuousDistrictGround", (0.16, 0.235, 0.13, 1), (0.275, 0.37, 0.225, 1), 0.94, 1.8, 0.025),
        "brick": flat_material("ContinuousWarmBrickContext", (0.43, 0.235, 0.16, 1), 0.80),
        "stone": flat_material("ContinuousWarmStoneContext", (0.49, 0.42, 0.32, 1), 0.84),
        "roof": flat_material("ContinuousWeatheredSlateContext", (0.18, 0.16, 0.15, 1), 0.79),
        "window": flat_material("ContinuousDeepBlueWindowContext", (0.07, 0.12, 0.14, 1), 0.36, 0.10),
        "trunk": flat_material("ContinuousStreetTreeBark", (0.25, 0.14, 0.08, 1), 0.88),
        "leaf": flat_material("ContinuousStreetTreeCanopy", (0.18, 0.32, 0.14, 1), 0.83),
    }
    mesh_box(root, "DistrictGround", (0.0, -1.0, -0.14), (31.0, 31.0, 0.20), context["ground"])
    placements = preview_network()
    observed = set()
    for placement in placements:
        mask_data = topology_for(placement["rawValue"])
        observed.add(mask_data["rawValue"])
        x, y, _ = placement["originWorld"]
        build_road_geometry(root, mask_data, road_mats, (x, y), f"Tile_{placement['coordinate'][0]}_{placement['coordinate'][1]}_", include_sockets=False)
        placement.update({"assetId": mask_data["assetId"], "topologyClass": mask_data["topologyClass"], "perAssetTransformCompensation": "none"})
    building_coords = ((-3, 2), (3, 2), (-3, -2), (3, -2), (-1, -1), (1, 1), (-2, -1), (2, 1))
    for index, coordinate in enumerate(building_coords):
        add_preview_building(root, index, coordinate, context)
    for index, (x, y) in enumerate(((-6.5, 5.5), (6.5, 5.5), (-6.5, -7.0), (6.5, -7.0), (3.0, -9.5), (-3.0, 8.0))):
        mesh_cylinder(root, f"TreeTrunk{index}", (x, y, 0.34), 0.10, 0.68, context["trunk"], vertices=14)
        mesh_cylinder(root, f"TreeCanopy{index}", (x, y, 0.88), 0.42, 0.62, context["leaf"], vertices=18)
    preview_rig(scene)
    preview_dir = output_dir if output_dir is not None else HERE / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    blend_path = preview_dir / "continuous-connected-district.blend"
    if write_evidence:
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = preview_dir / f"continuous-connected-district-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    if not write_evidence:
        return outputs
    manifest = {
        "schema": "citysim.world-art.streetscape-continuous-connected-district-preview.v1",
        "status": "source-only-review-evidence",
        "liveAsset": False,
        "originalGeometry": True,
        "cedarMarketReused": False,
        "camera": {"projection": "orthographic", "azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none"},
        "grid": CONFIG["grid"],
        "surface": CONFIG["surface"],
        "lightingConvention": CONFIG["lighting"],
        "observedRawValues": sorted(observed),
        "placements": placements,
        "artifacts": [artifact_info(blend_path), *[artifact_info(path) for path in outputs]],
    }
    (preview_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return outputs


def write_family_manifest(mask_manifests):
    data = {
        "schema": "citysim.world-art.streetscape-continuous-family-manifest.v1",
        "status": "source-only-candidate",
        "liveAsset": False,
        "familyId": "continuous-marked-road-connection-masks",
        "maskCount": 16,
        "canonicalViewCount": 64,
        "contactSheetCount": 16,
        "previewCount": 2,
        "roadBits": CONFIG["roadBits"],
        "grid": CONFIG["grid"],
        "surface": CONFIG["surface"],
        "canvas": CONFIG["canvas"],
        "cameraRig": CONFIG["cameraRig"],
        "lightingConvention": CONFIG["lighting"],
        "postRenderCompensation": "none",
        "boundaryMaterialContract": "identical-periodic-asphalt-sidewalk-curb-and-ochre-dash-boundary-phase",
        "provenance": CONFIG["provenance"],
        "sourceFiles": source_files(),
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
    print("STREETSCAPE_CONTINUOUS_RENDER_PASS masks=16 views=64 contactSheets=16 previews=2")


if __name__ == "__main__":
    main()
