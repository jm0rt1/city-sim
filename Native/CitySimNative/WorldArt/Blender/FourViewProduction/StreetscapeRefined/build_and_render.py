#!/usr/bin/env python3
"""Build and render CitySim's refined original 16-mask road family."""

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
spec = importlib.util.spec_from_file_location("citysim_streetscape_contract", BASE_PATH)
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

CONFIG = json.loads((HERE / "pipeline.json").read_text())
VIEWS = CONFIG["cameraRig"]["views"]
base.CONFIG = CONFIG
base.VIEWS = VIEWS
sys.dont_write_bytecode = True

DIRECTIONS = {
    "north": {"bit": 1, "point": (-1.0, 0.0, 0.035), "opposite": "south"},
    "east": {"bit": 2, "point": (0.0, -1.0, 0.035), "opposite": "west"},
    "south": {"bit": 4, "point": (1.0, 0.0, 0.035), "opposite": "north"},
    "west": {"bit": 8, "point": (0.0, 1.0, 0.035), "opposite": "east"},
}
SOURCE_DIRECTIONS = {"north": "west", "east": "south", "south": "east", "west": "north"}

material = base.material
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


def mesh_disc(root, name, center, radius, mat, vertices=20, properties=None):
    cx, cy, cz = center
    points = [(cx, cy, cz)]
    points.extend((cx + radius * math.cos(index * 2 * math.pi / vertices), cy + radius * math.sin(index * 2 * math.pi / vertices), cz) for index in range(vertices))
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


def mesh_ring(root, name, center, inner_radius, outer_radius, mat, vertices=20):
    cx, cy, cz = center
    points = []
    for radius in (inner_radius, outer_radius):
        points.extend((cx + radius * math.cos(index * 2 * math.pi / vertices), cy + radius * math.sin(index * 2 * math.pi / vertices), cz) for index in range(vertices))
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
    return obj


def palette():
    """Quiet contiguous materials; road-facing materials never use per-object noise."""
    return {
        "asphalt": material("FoundryWarmCharcoalAsphalt", (0.205, 0.192, 0.178, 1), roughness=0.88),
        "sidewalk": material("QuietWarmGrayAggregate", (0.405, 0.382, 0.345, 1), roughness=0.91),
        "curb": material("LowContrastSandstoneCurb", (0.438, 0.410, 0.365, 1), roughness=0.88),
        "paint": material("AgedWarmRoadPaint", (0.665, 0.620, 0.500, 1), roughness=0.82),
        "paver": material("BurnishedClayPaver", (0.405, 0.225, 0.155, 1), roughness=0.84),
        "iron": material("DrainageIron", (0.115, 0.112, 0.105, 1), roughness=0.60, metallic=0.48),
        "bollard": material("MutedOchreBollard", (0.46, 0.31, 0.12, 1), roughness=0.76),
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
    root["surfaceFamily"] = "foundry-warm-charcoal-v1"
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


def add_arm(root, direction, mats, center=(0.0, 0.0), prefix=""):
    ox, oy = center
    road_width = CONFIG["surface"]["roadWidthWorld"]
    walk_width = CONFIG["surface"]["walkWidthWorld"]
    curb_width = CONFIG["surface"]["curbWidthWorld"]
    curb_offset = road_width / 2.0 + curb_width / 2.0
    inner = road_width / 2.0 - 0.04
    outer = 1.0 + CONFIG["surface"]["socketBleedWorld"]
    length = outer - inner
    source_direction = SOURCE_DIRECTIONS[direction]
    if source_direction == "north":
        center2 = (ox, oy + (inner + outer) / 2.0)
        road_size, walk_size = (road_width, length), (walk_width, length)
        curbs = [((ox - curb_offset, center2[1], 0.062), (curb_width, length)), ((ox + curb_offset, center2[1], 0.062), (curb_width, length))]
    elif source_direction == "south":
        center2 = (ox, oy - (inner + outer) / 2.0)
        road_size, walk_size = (road_width, length), (walk_width, length)
        curbs = [((ox - curb_offset, center2[1], 0.062), (curb_width, length)), ((ox + curb_offset, center2[1], 0.062), (curb_width, length))]
    elif source_direction == "east":
        center2 = (ox + (inner + outer) / 2.0, oy)
        road_size, walk_size = (length, road_width), (length, walk_width)
        curbs = [((center2[0], oy - curb_offset, 0.062), (length, curb_width)), ((center2[0], oy + curb_offset, 0.062), (length, curb_width))]
    else:
        center2 = (ox - (inner + outer) / 2.0, oy)
        road_size, walk_size = (length, road_width), (length, walk_width)
        curbs = [((center2[0], oy - curb_offset, 0.062), (length, curb_width)), ((center2[0], oy + curb_offset, 0.062), (length, curb_width))]
    properties = {
        "roadDirection": direction,
        "connectionBit": DIRECTIONS[direction]["bit"],
        "reachesBoundary": True,
        "bleedBoundaryWorld": outer,
    }
    mesh_plane(root, prefix + "WalkArm" + direction.capitalize(), (center2[0], center2[1], 0.042), walk_size, mats["sidewalk"])
    mesh_plane(root, prefix + "RoadArm" + direction.capitalize(), (center2[0], center2[1], 0.054), road_size, mats["asphalt"], properties)
    for index, (location, size) in enumerate(curbs):
        mesh_plane(root, f"{prefix}Curb{direction.capitalize()}{index}", location, size, mats["curb"])


def detail_location(direction, center, along=0.67, lateral=0.40, z=0.068):
    ox, oy = center
    source = SOURCE_DIRECTIONS[direction]
    if source == "north":
        return (ox + lateral, oy + along, z)
    if source == "south":
        return (ox - lateral, oy - along, z)
    if source == "east":
        return (ox + along, oy - lateral, z)
    return (ox - along, oy + lateral, z)


def add_catch_basin(root, direction, mats, center=(0.0, 0.0), prefix=""):
    location = detail_location(direction, center)
    source = SOURCE_DIRECTIONS[direction]
    dimensions = (0.055, 0.16) if source in ("north", "south") else (0.16, 0.055)
    mesh_plane(root, prefix + "CatchBasin" + direction.capitalize(), location, dimensions, mats["iron"])


def add_crossing_bar(root, direction, mats, center=(0.0, 0.0), prefix=""):
    ox, oy = center
    source = SOURCE_DIRECTIONS[direction]
    offset = 0.60
    if source == "north":
        location, dimensions = (ox, oy + offset, 0.068), (0.58, 0.030)
    elif source == "south":
        location, dimensions = (ox, oy - offset, 0.068), (0.58, 0.030)
    elif source == "east":
        location, dimensions = (ox + offset, oy, 0.068), (0.030, 0.58)
    else:
        location, dimensions = (ox - offset, oy, 0.068), (0.030, 0.58)
    mesh_plane(root, prefix + "CrossingBar" + direction.capitalize(), location, dimensions, mats["paint"])


def add_endpoint_detail(root, connected_direction, mats, center=(0.0, 0.0), prefix=""):
    terminal = DIRECTIONS[connected_direction]["opposite"]
    source = SOURCE_DIRECTIONS[terminal]
    ox, oy = center
    if source in ("north", "south"):
        sign = 1 if source == "north" else -1
        positions = ((ox - 0.25, oy + sign * 0.48), (ox + 0.25, oy + sign * 0.48))
    else:
        sign = 1 if source == "east" else -1
        positions = ((ox + sign * 0.48, oy - 0.25), (ox + sign * 0.48, oy + 0.25))
    for index, (x, y) in enumerate(positions):
        mesh_cylinder(root, f"{prefix}TerminalBollard{index}", (x, y, 0.135), 0.035, 0.14, mats["bollard"], vertices=12)


def build_road_geometry(root, mask_data, mats, center=(0.0, 0.0), prefix="", include_sockets=True):
    ox, oy = center
    raw = mask_data["rawValue"]
    directions = mask_data["directions"]
    road_width = CONFIG["surface"]["roadWidthWorld"]
    walk_width = CONFIG["surface"]["walkWidthWorld"]
    curb_width = CONFIG["surface"]["curbWidthWorld"]
    curb_offset = road_width / 2.0 + curb_width / 2.0
    if raw == 0:
        mesh_disc(root, prefix + "WalkCore", (ox, oy, 0.042), walk_width / 2.0, mats["sidewalk"], properties={"worldCell": [2.0, 2.0]})
        mesh_disc(root, prefix + "AsphaltCore", (ox, oy, 0.054), road_width / 2.0, mats["asphalt"], properties={"roadMaskRawValue": raw})
        mesh_ring(root, prefix + "TurnaroundCurb", (ox, oy, 0.062), road_width / 2.0, road_width / 2.0 + curb_width, mats["curb"])
        mesh_disc(root, prefix + "TurnaroundPaver", (ox, oy, 0.066), 0.17, mats["paver"], vertices=16)
        for index, (x, y) in enumerate(((-0.34, -0.34), (0.34, 0.34))):
            mesh_cylinder(root, f"{prefix}TurnaroundBollard{index}", (ox + x, oy + y, 0.14), 0.035, 0.15, mats["bollard"], vertices=12)
        return
    mesh_plane(root, prefix + "WalkCore", (ox, oy, 0.042), (walk_width, walk_width), mats["sidewalk"], {"worldCell": [2.0, 2.0]})
    mesh_plane(root, prefix + "AsphaltCore", (ox, oy, 0.054), (road_width, road_width), mats["asphalt"], {"roadMaskRawValue": raw})
    for direction in directions:
        add_arm(root, direction, mats, center, prefix)
        if include_sockets:
            add_socket(root, direction)
    for direction in (name for name in DIRECTIONS if name not in directions):
        source = SOURCE_DIRECTIONS[direction]
        if source in ("north", "south"):
            y = oy + (curb_offset if source == "north" else -curb_offset)
            mesh_plane(root, prefix + "ClosedCurb" + direction.capitalize(), (ox, y, 0.062), (road_width + curb_width * 2, curb_width), mats["curb"], {"closedBoundary": direction})
        else:
            x = ox + (curb_offset if source == "east" else -curb_offset)
            mesh_plane(root, prefix + "ClosedCurb" + direction.capitalize(), (x, oy, 0.062), (curb_width, road_width + curb_width * 2), mats["curb"], {"closedBoundary": direction})
    if mask_data["topologyClass"] == "end":
        add_endpoint_detail(root, directions[0], mats, center, prefix)
    elif mask_data["topologyClass"] == "tee":
        add_catch_basin(root, directions[(raw * 3) % len(directions)], mats, center, prefix)
    elif raw == 15:
        add_crossing_bar(root, "north", mats, center, prefix)
        add_crossing_bar(root, "south", mats, center, prefix)
        add_catch_basin(root, "east", mats, center, prefix)


def build_asset(mask_data):
    scene = reset("CitySimFoundryStreet_" + mask_data["assetId"])
    configure_scene(scene, transparent=True)
    scene["surfaceFamily"] = "foundry-warm-charcoal-v1"
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
        "schema": "citysim.world-art.streetscape-refined-mask.v1",
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
    coords = set((x, 0) for x in range(-4, 5))
    coords.update((0, y) for y in range(-4, 5))
    coords.update((x, 3) for x in range(-4, 5))
    coords.update((x, -3) for x in range(-4, 5))
    coords.update((-4, y) for y in range(-3, 4))
    coords.update((4, y) for y in range(-3, 4))
    coords.update({(-2, 1), (-2, 2), (2, -1), (2, -2), (-5, 1), (5, -1), (6, 3)})
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
    mesh_box(root, f"ContextBuilding{index}", (x, y, 0.72), (1.22, 1.22, 1.44), facade)
    mesh_hip_roof(root, f"ContextRoof{index}", (x, y, 1.44), (1.42, 1.42), 0.48, mats["roof"])
    for level in (0.52, 1.02):
        mesh_box(root, f"ContextWindowX{index}_{level}", (x + 0.616, y, level), (0.018, 0.50, 0.20), mats["window"])
        mesh_box(root, f"ContextWindowY{index}_{level}", (x, y + 0.616, level), (0.50, 0.018, 0.20), mats["window"])


def preview_rig(scene):
    distance = 50.0
    elevation = math.radians(30.0)
    azimuth = math.radians(45.0)
    horizontal = distance * math.cos(elevation)
    data = bpy.data.cameras.new("camNE_RefinedConnectedDistrict")
    data.type = "ORTHO"
    data.ortho_scale = 25.5
    camera = bpy.data.objects.new("camNE_RefinedConnectedDistrict", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (horizontal * math.sin(azimuth), horizontal * math.cos(azimuth), distance * math.sin(elevation))
    point_at(camera, Vector((0.5, -1.0, 0.0)))
    base.add_light(scene)
    scene.camera = camera


def build_preview(output_dir=None, write_evidence=True):
    scene = reset("CitySimFoundryConnectedDistrict")
    configure_scene(scene, transparent=False)
    root = bpy.data.objects.new("PreviewRoot", None)
    bpy.context.collection.objects.link(root)
    road_mats = palette()
    context = {
        "ground": material("FoundryDistrictGround", (0.245, 0.315, 0.205, 1), roughness=0.92, texture_scale=7.0, bump=0.06),
        "brick": material("WarmBrickContext", (0.43, 0.235, 0.16, 1), roughness=0.80, texture_scale=12.0, bump=0.10),
        "stone": material("WarmStoneContext", (0.49, 0.42, 0.32, 1), roughness=0.84, texture_scale=10.0, bump=0.08),
        "roof": material("WeatheredSlateContext", (0.18, 0.16, 0.15, 1), roughness=0.79, texture_scale=9.0, bump=0.08),
        "window": material("DeepBlueWindowContext", (0.07, 0.12, 0.14, 1), roughness=0.36, metallic=0.10),
        "trunk": material("StreetTreeBark", (0.25, 0.14, 0.08, 1), roughness=0.88),
        "leaf": material("StreetTreeCanopy", (0.18, 0.32, 0.14, 1), roughness=0.83, texture_scale=7.0, bump=0.08),
    }
    mesh_box(root, "DistrictGround", (0.0, -1.0, -0.14), (30.0, 30.0, 0.20), context["ground"])
    placements = preview_network()
    observed = set()
    for placement in placements:
        mask_data = topology_for(placement["rawValue"])
        observed.add(mask_data["rawValue"])
        x, y, _ = placement["originWorld"]
        build_road_geometry(root, mask_data, road_mats, (x, y), f"Tile_{placement['coordinate'][0]}_{placement['coordinate'][1]}_", include_sockets=False)
        placement.update({"assetId": mask_data["assetId"], "topologyClass": mask_data["topologyClass"], "perAssetTransformCompensation": "none"})
    for index, coordinate in enumerate(((-3, 2), (3, 2), (-3, -2), (3, -2), (-1, -1), (1, 1))):
        add_preview_building(root, index, coordinate, context)
    for index, (x, y) in enumerate(((-6.5, 5.5), (6.5, 5.5), (-6.5, -7.0), (6.5, -7.0), (3.0, -9.5), (-3.0, 8.0))):
        mesh_cylinder(root, f"TreeTrunk{index}", (x, y, 0.34), 0.10, 0.68, context["trunk"], vertices=14)
        mesh_cylinder(root, f"TreeCanopy{index}", (x, y, 0.88), 0.42, 0.62, context["leaf"], vertices=18)
    preview_rig(scene)
    preview_dir = output_dir if output_dir is not None else HERE / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    blend_path = preview_dir / "foundry-connected-district.blend"
    if write_evidence:
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    outputs = []
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        path = preview_dir / f"foundry-connected-district-{width}x{height}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(path)
        outputs.append(path)
    if not write_evidence:
        return outputs
    manifest = {
        "schema": "citysim.world-art.streetscape-refined-connected-district-preview.v1",
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
        "schema": "citysim.world-art.streetscape-refined-family-manifest.v1",
        "status": "source-only-candidate",
        "liveAsset": False,
        "familyId": "foundry-refined-road-connection-masks",
        "maskCount": 16,
        "canonicalViewCount": 64,
        "roadBits": CONFIG["roadBits"],
        "grid": CONFIG["grid"],
        "surface": CONFIG["surface"],
        "canvas": CONFIG["canvas"],
        "cameraRig": CONFIG["cameraRig"],
        "lightingConvention": CONFIG["lighting"],
        "postRenderCompensation": "none",
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
    print("STREETSCAPE_REFINED_RENDER_PASS masks=16 views=64 contactSheets=16 previews=2")


if __name__ == "__main__":
    main()
