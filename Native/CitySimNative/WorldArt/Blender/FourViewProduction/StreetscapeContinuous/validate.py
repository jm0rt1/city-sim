#!/usr/bin/env python3
"""Validate CitySim's continuous 16-mask roadway and deterministic evidence."""

from __future__ import annotations

import hashlib
import json
import math
import sys
import tempfile
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE = Path(__file__).resolve().parent
CANONICAL = HERE.parents[1] / "FourViewPipeline"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))
sys.path.insert(0, str(HERE))
from png_canonical import decode_rgba_png  # noqa: E402
import build_and_render as builder  # noqa: E402

CONFIG = json.loads((HERE / "pipeline.json").read_text())
DIRECTIONS = builder.DIRECTIONS
SURFACE = CONFIG["surface"]


def require(condition, code, detail):
    if not condition:
        raise RuntimeError(f"{code}: {detail}")


def close(actual, expected, tolerance, label):
    require(abs(float(actual) - float(expected)) <= tolerance, "VALUE_MISMATCH", f"{label}: {actual} != {expected}")


def vector(actual, expected, tolerance, label):
    require(len(actual) == len(expected), "VECTOR_LENGTH_MISMATCH", label)
    for index, (actual_value, expected_value) in enumerate(zip(actual, expected)):
        close(actual_value, expected_value, tolerance, f"{label}[{index}]")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def mesh_bounds(obj):
    vertices = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    return {
        "minX": min(vertex.x for vertex in vertices), "maxX": max(vertex.x for vertex in vertices),
        "minY": min(vertex.y for vertex in vertices), "maxY": max(vertex.y for vertex in vertices),
        "minZ": min(vertex.z for vertex in vertices), "maxZ": max(vertex.z for vertex in vertices),
    }


def dimensions(bounds):
    return bounds["maxX"] - bounds["minX"], bounds["maxY"] - bounds["minY"]


def validate_projected_contract(scene, cameras):
    for view in CONFIG["cameraRig"]["views"]:
        camera = cameras[view["name"]]
        require(camera.data.type == "ORTHO", "CAMERA_NOT_ORTHO", camera.name)
        close(camera.data.ortho_scale, 12.341995, 1e-6, camera.name + ".orthoScale")
        close(camera.data.shift_y, 0.28125, 1e-6, camera.name + ".shiftY")
        projected = world_to_camera_view(scene, camera, Vector((0.0, 0.0, 0.0)))
        vector((projected.x * 384, (1.0 - projected.y) * 384), (192, 300), 0.01, camera.name + ".pivotPixel")
        horizontal = math.hypot(camera.location.x, camera.location.y)
        close(math.degrees(math.atan2(camera.location.z, horizontal)), 30.0, 0.0001, camera.name + ".elevation")
        close(math.degrees(math.atan2(camera.location.x, camera.location.y)) % 360, view["azimuthDegrees"], 0.0001, camera.name + ".azimuth")
        points = []
        for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            projected = world_to_camera_view(scene, camera, Vector((x, y, 0.0)))
            points.append((projected.x * 384, (1.0 - projected.y) * 384))
        width = max(point[0] for point in points) - min(point[0] for point in points)
        height = max(point[1] for point in points) - min(point[1] for point in points)
        vector((width, height), (88, 44), 0.01, camera.name + ".projectedTilePixels")


def connected_edge_extreme(bounds, direction):
    if direction == "north":
        return bounds["minX"]
    if direction == "east":
        return bounds["minY"]
    if direction == "south":
        return bounds["maxX"]
    return bounds["maxY"]


def boundary_cross_width(bounds, direction):
    if direction in ("north", "south"):
        return bounds["maxY"] - bounds["minY"]
    return bounds["maxX"] - bounds["minX"]


def expected_edge(direction):
    return -1.0 - SURFACE["socketBleedWorld"] if direction in ("north", "east") else 1.0 + SURFACE["socketBleedWorld"]


def verify_periodic_material(mat, name):
    require(mat is not None and mat.name == name, "MATERIAL_MISMATCH", getattr(mat, "name", None))
    nodes = mat.node_tree.nodes if mat.use_nodes else []
    require(any(node.bl_idname == "ShaderNodeTexNoise" and getattr(node, "noise_dimensions", "") == "4D" for node in nodes), "PERIODIC_NOISE_MISSING", name)
    require(sum(1 for node in nodes if node.bl_idname == "ShaderNodeMath" and node.operation == "SINE") == 4, "PERIODIC_PHASE_NODE_MISMATCH", name)


def validate_scene(mask_data):
    asset_id = mask_data["assetId"]
    path = HERE / asset_id / f"{asset_id}.blend"
    require(path.is_file(), "MISSING_BLEND", path)
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    require(scene.render.engine == CONFIG["toolchain"]["renderEngine"], "ENGINE_MISMATCH", scene.render.engine)
    require((scene.render.resolution_x, scene.render.resolution_y) == (384, 384), "CANVAS_MISMATCH", asset_id)
    require(scene.render.film_transparent, "CANVAS_NOT_TRANSPARENT", asset_id)
    require(scene.get("postRenderCompensation") == "none", "POST_RENDER_COMPENSATION_FORBIDDEN", asset_id)
    require(scene.get("surfaceFamily") == "continuous-rich-charcoal-v2", "SURFACE_FAMILY_MISMATCH", asset_id)
    root = bpy.data.objects.get("AssetRoot")
    pivot = bpy.data.objects.get("FootprintPivot")
    require(root is not None and pivot is not None, "MISSING_ROOT_OR_PIVOT", asset_id)
    vector(root.location, (0, 0, 0), 1e-7, "root.location")
    vector(root.rotation_euler, (0, 0, 0), 1e-7, "root.rotation")
    vector(root.scale, (1, 1, 1), 1e-7, "root.scale")
    require(pivot.parent == root, "PIVOT_PARENT_MISMATCH", asset_id)
    require(root.get("roadMaskRawValue") == mask_data["rawValue"], "ROOT_MASK_MISMATCH", asset_id)
    require(root.get("topologyClass") == mask_data["topologyClass"], "ROOT_TOPOLOGY_MISMATCH", asset_id)
    require(root.get("boundaryMarkingPhase") == "ochre-dash-centered-on-every-tile-boundary", "MARKING_PHASE_MISMATCH", asset_id)
    require(root.get("liveAsset") is False and root.get("sourcePixelsReused") is False and root.get("cedarMarketReused") is False, "PROVENANCE_MISMATCH", asset_id)

    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    require(len(meshes) >= 4, "GEOMETRY_TOO_SIMPLE", f"{asset_id}: {len(meshes)}")
    for obj in meshes:
        require(obj.parent == root, "MESH_OUTSIDE_ROOT", obj.name)
        vector(obj.location, (0, 0, 0), 1e-7, obj.name + ".location")
        vector(obj.rotation_euler, (0, 0, 0), 1e-7, obj.name + ".rotation")
        vector(obj.scale, (1, 1, 1), 1e-7, obj.name + ".scale")
        width, depth = dimensions(mesh_bounds(obj))
        require(not (width >= 1.90 and depth >= 1.90), "FULL_TILE_PLATE_FORBIDDEN", obj.name)

    asphalt = bpy.data.materials.get("ContinuousRichCharcoalAsphalt")
    sidewalk = bpy.data.materials.get("ContinuousWarmConcreteSidewalk")
    verify_periodic_material(asphalt, "ContinuousRichCharcoalAsphalt")
    verify_periodic_material(sidewalk, "ContinuousWarmConcreteSidewalk")
    curb = bpy.data.materials.get("ContinuousCutStoneCurb")
    yellow = bpy.data.materials.get("ContinuousWarmOchreCenterMarking")
    require(curb is not None, "ROAD_MATERIAL_SET_INCOMPLETE", asset_id)
    if mask_data["rawValue"] != 0:
        require(yellow is not None, "ROAD_MARKING_MATERIAL_MISSING", asset_id)

    socket_report = {}
    for direction, spec in DIRECTIONS.items():
        connected = direction in mask_data["directions"]
        socket = bpy.data.objects.get("Socket_" + direction.capitalize())
        arm = bpy.data.objects.get("RoadArm" + direction.capitalize())
        walk_arm = bpy.data.objects.get("WalkArm" + direction.capitalize())
        dash = bpy.data.objects.get("Centerline" + direction.capitalize() + "Dash2")
        curbs = [bpy.data.objects.get("Curb" + direction.capitalize() + side) for side in ("Left", "Right")]
        if connected:
            require(socket is not None and arm is not None and walk_arm is not None, "MISSING_CONNECTED_SOCKET", f"{asset_id}:{direction}")
            require(dash is not None, "MISSING_BOUNDARY_CENTERLINE_DASH", f"{asset_id}:{direction}")
            require(all(curbs), "MISSING_MODELED_BOUNDARY_CURB", f"{asset_id}:{direction}")
            vector(socket.location, spec["point"], 1e-7, direction + ".socket")
            close(socket.get("socketWidthWorld"), SURFACE["roadWidthWorld"], 1e-7, direction + ".socketWidth")
            close(socket.get("materialOverlapWorld"), SURFACE["socketBleedWorld"], 1e-7, direction + ".overlap")
            require(socket.get("markingPhase") == "dash-center-at-boundary", "SOCKET_MARKING_PHASE_MISMATCH", direction)
            arm_bounds = mesh_bounds(arm)
            walk_bounds = mesh_bounds(walk_arm)
            dash_bounds = mesh_bounds(dash)
            close(connected_edge_extreme(arm_bounds, direction), expected_edge(direction), 1e-7, direction + ".roadBleed")
            close(connected_edge_extreme(walk_bounds, direction), expected_edge(direction), 1e-7, direction + ".walkBleed")
            close(connected_edge_extreme(dash_bounds, direction), expected_edge(direction), 1e-7, direction + ".markingBleed")
            close(boundary_cross_width(arm_bounds, direction), SURFACE["roadWidthWorld"], 1e-7, direction + ".roadWidth")
            close(boundary_cross_width(walk_bounds, direction), SURFACE["walkWidthWorld"], 1e-7, direction + ".walkWidth")
            close(boundary_cross_width(dash_bounds, direction), SURFACE["centerlineWidthWorld"], 1e-7, direction + ".lineWidth")
            require(arm.data.materials[0] == asphalt and walk_arm.data.materials[0] == sidewalk and dash.data.materials[0] == yellow, "BOUNDARY_MATERIAL_MISMATCH", direction)
            for curb_obj in curbs:
                require(curb_obj.data.materials[0] == curb and curb_obj.get("modeledCurbFace") is True, "CURB_CONTRACT_MISMATCH", curb_obj.name)
                close(connected_edge_extreme(mesh_bounds(curb_obj), direction), expected_edge(direction), 1e-7, direction + ".curbBleed")
            socket_report[direction] = {
                "bit": spec["bit"],
                "point": list(spec["point"]),
                "roadArmBounds": arm_bounds,
                "walkArmBounds": walk_bounds,
                "markingBounds": dash_bounds,
                "markingPhase": "dash-center-at-boundary",
            }
        else:
            require(socket is None and arm is None and walk_arm is None and dash is None, "ABSENT_SOCKET_GEOMETRY_PRESENT", f"{asset_id}:{direction}")

    centerlines = [obj for obj in meshes if obj.name.startswith("Centerline") or obj.name.startswith("CornerCenterline")]
    if mask_data["rawValue"] != 0:
        require(centerlines, "CENTERLINE_LANGUAGE_MISSING", asset_id)
    if mask_data["topologyClass"] == "corner":
        require(bpy.data.objects.get("CornerCenterlineContinuation") is not None, "CORNER_MARKING_CONTINUATION_MISSING", asset_id)
        require(bpy.data.objects.get("CornerCurbInner") is not None and bpy.data.objects.get("CornerCurbOuter") is not None, "CORNER_CURB_CONTINUATION_MISSING", asset_id)
    if mask_data["topologyClass"] in ("tee", "crossing"):
        for obj in centerlines:
            bounds = mesh_bounds(obj)
            direction = next(
                name
                for name in DIRECTIONS
                if obj.name.startswith("Centerline" + name.capitalize())
            )
            along_axis = "X" if direction in ("north", "south") else "Y"
            min_axis_distance = min(
                abs(bounds["min" + along_axis]),
                abs(bounds["max" + along_axis]),
            )
            require(min_axis_distance >= 0.88, "JUNCTION_CENTERLINE_TANGLE", f"{asset_id}:{obj.name}:{bounds}")
        stop_bars = [obj for obj in meshes if obj.name.startswith("StopBar")]
        crosswalks = [obj for obj in meshes if obj.name.startswith("Crosswalk")]
        require(len(stop_bars) == len(mask_data["directions"]), "JUNCTION_STOP_BAR_COUNT_MISMATCH", asset_id)
        require(len(crosswalks) in (3, 6), "JUNCTION_CROSSWALK_COUNT_MISMATCH", asset_id)

    lights = [obj for obj in bpy.data.objects if obj.type == "LIGHT"]
    require(len(lights) == 1 and lights[0].name == "CitySimKey", "LIGHT_CONVENTION_MISMATCH", [obj.name for obj in lights])
    light = lights[0]
    vector(light.location, CONFIG["lighting"]["location"], 1e-7, "light.location")
    close(light.data.energy, 1100, 1e-7, "light.energy")
    close(light.data.size, 5, 1e-7, "light.size")
    vector(light.data.color, CONFIG["lighting"]["color"], 1e-7, "light.color")
    cameras = {obj.name: obj for obj in bpy.data.objects if obj.type == "CAMERA"}
    require(sorted(cameras) == sorted(view["name"] for view in CONFIG["cameraRig"]["views"]), "CAMERA_SET_MISMATCH", sorted(cameras))
    validate_projected_contract(scene, cameras)
    return len(meshes), socket_report


def validate_png_artifact(artifact, artifact_path):
    require(artifact_path.is_file(), "MISSING_ARTIFACT", artifact_path)
    require(artifact_path.stat().st_size == artifact["bytes"], "ARTIFACT_SIZE_DRIFT", artifact_path)
    require(sha256(artifact_path) == artifact["sha256"], "ARTIFACT_HASH_DRIFT", artifact_path)
    if artifact_path.suffix != ".png":
        return
    width, height, rgba = decode_rgba_png(artifact_path)
    require([width, height] == artifact["dimensions"], "PNG_DIMENSION_DRIFT", artifact_path)
    require(hashlib.sha256(rgba).hexdigest() == artifact["decodedRgbaSha256"], "RGBA_HASH_DRIFT", artifact_path)
    expected = (784, 840) if "contact-sheet" in artifact_path.name else (384, 384)
    require((width, height) == expected, "PNG_CANVAS_MISMATCH", f"{artifact_path}:{width}x{height}")
    alpha = rgba[3::4]
    require(any(alpha) and any(value == 0 for value in alpha), "ALPHA_POLICY_MISMATCH", artifact_path)
    require(artifact["alpha"]["opaquePixelCount"] > 0, "EMPTY_ALPHA_BOUNDS", artifact_path)


def validate_manifest(mask_data):
    output_dir = HERE / mask_data["assetId"]
    path = output_dir / "manifest.json"
    require(path.is_file(), "MISSING_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["assetId"] == mask_data["assetId"], "MANIFEST_IDENTITY_MISMATCH", path)
    require(data["roadConnectionMask"]["rawValue"] == mask_data["rawValue"], "MANIFEST_MASK_MISMATCH", path)
    require(data["roadConnectionMask"]["directions"] == mask_data["directions"], "MANIFEST_DIRECTIONS_MISMATCH", path)
    require(data["roadConnectionMask"]["topologyClass"] == mask_data["topologyClass"], "MANIFEST_TOPOLOGY_MISMATCH", path)
    require(data["status"] == "source-only-candidate" and data["liveAsset"] is False, "MANIFEST_STATUS_MISMATCH", path)
    require(data["originalGeometry"] is True and data["sourcePixelsReused"] is False and data["cedarMarketReused"] is False, "MANIFEST_PROVENANCE_MISMATCH", path)
    require(data["postRenderCompensation"] == "none" and data["transforms"]["perMaskCompensation"] == "none", "MANIFEST_COMPENSATION_FORBIDDEN", path)
    require(data["perViewCompensation"] == {"crop": False, "offsetPixels": [0, 0], "rotationDegrees": 0.0, "scale": 1.0, "skew": [0.0, 0.0]}, "PER_VIEW_COMPENSATION_FORBIDDEN", path)
    require(data["surface"] == SURFACE, "SURFACE_CONTRACT_MISMATCH", path)
    require(data["boundaryMaterialContract"] == "identical-periodic-asphalt-sidewalk-curb-and-ochre-dash-boundary-phase", "BOUNDARY_MATERIAL_CONTRACT_MISMATCH", path)
    expected_sockets = {name: CONFIG["grid"]["boundaryMidpoints"][name] for name in mask_data["directions"]}
    require(data["boundarySockets"] == expected_sockets, "MANIFEST_SOCKET_MISMATCH", path)
    require(data["absentBoundarySockets"] == [name for name in DIRECTIONS if name not in mask_data["directions"]], "MANIFEST_ABSENT_SOCKET_MISMATCH", path)
    for source in data["sourceFiles"]:
        source_path = HERE / source["path"]
        require(source_path.is_file() and sha256(source_path) == source["sha256"], "SOURCE_HASH_DRIFT", source_path)
    for artifact in data["artifacts"]:
        validate_png_artifact(artifact, output_dir / artifact["path"])


def deterministic_rerender(mask_data, temp_root):
    scene, _, cameras = builder.build_asset(mask_data)
    rerenders = builder.render_views(scene, cameras, mask_data["assetId"], temp_root / mask_data["assetId"])
    hashes = {}
    for rerender in rerenders:
        original = HERE / mask_data["assetId"] / "renders" / rerender.name
        require(sha256(rerender) == sha256(original), "DETERMINISTIC_RERENDER_MISMATCH", rerender.name)
        hashes[rerender.name] = sha256(rerender)
    return hashes


def preview_marking_reaches_boundary(coordinate, direction):
    x, y = coordinate
    prefix = f"Tile_{x}_{y}_Centerline{direction.capitalize()}Dash2"
    obj = bpy.data.objects.get(prefix)
    require(obj is not None, "PREVIEW_BOUNDARY_MARKING_MISSING", prefix)
    expected_world = {
        "north": -y * 2.0 - 1.0,
        "south": -y * 2.0 + 1.0,
        "east": -x * 2.0 - 1.0,
        "west": -x * 2.0 + 1.0,
    }[direction]
    bounds = mesh_bounds(obj)
    if direction in ("north", "south"):
        require(bounds["minX"] - 0.13 <= expected_world <= bounds["maxX"] + 0.13, "PREVIEW_MARKING_PHASE_GAP", f"{prefix}:{bounds}")
    else:
        require(bounds["minY"] - 0.13 <= expected_world <= bounds["maxY"] + 0.13, "PREVIEW_MARKING_PHASE_GAP", f"{prefix}:{bounds}")


def validate_preview(temp_root):
    path = HERE / "preview" / "manifest.json"
    require(path.is_file(), "MISSING_PREVIEW_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["liveAsset"] is False and data["originalGeometry"] is True and data["cedarMarketReused"] is False, "PREVIEW_PROVENANCE_MISMATCH", path)
    require(data["camera"] == {"projection": "orthographic", "azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none"}, "PREVIEW_CAMERA_MISMATCH", data["camera"])
    require(data["observedRawValues"] == list(range(16)), "PREVIEW_MASK_COVERAGE_MISMATCH", data["observedRawValues"])
    require(data["surface"] == SURFACE, "PREVIEW_SURFACE_MISMATCH", data["surface"])
    by_coordinate = {tuple(item["coordinate"]): item for item in data["placements"]}
    offsets = {"north": (0, 1), "east": (1, 0), "south": (0, -1), "west": (-1, 0)}
    for coordinate, placement in by_coordinate.items():
        require(placement["perAssetTransformCompensation"] == "none", "PREVIEW_COMPENSATION_FORBIDDEN", placement)
        vector(placement["originWorld"], (-coordinate[1] * 2.0, -coordinate[0] * 2.0, 0), 1e-7, "preview.gridOrigin")
        raw = placement["rawValue"]
        for direction, spec in DIRECTIONS.items():
            dx, dy = offsets[direction]
            neighbor = by_coordinate.get((coordinate[0] + dx, coordinate[1] + dy))
            connected = bool(raw & spec["bit"])
            require(connected == (neighbor is not None and bool(neighbor["rawValue"] & DIRECTIONS[spec["opposite"]]["bit"])), "PREVIEW_NONRECIPROCAL_SOCKET", f"{coordinate}:{direction}")
    horizontal_straights = {coordinate for coordinate, placement in by_coordinate.items() if placement["rawValue"] & 10 == 10}
    vertical_straights = {coordinate for coordinate, placement in by_coordinate.items() if placement["rawValue"] & 5 == 5}
    require(any((x + 1, y) in horizontal_straights and (x + 2, y) in horizontal_straights for x, y in horizontal_straights), "PREVIEW_MISSING_LONG_HORIZONTAL_STRAIGHT", sorted(horizontal_straights))
    require(any((x, y + 1) in vertical_straights and (x, y + 2) in vertical_straights for x, y in vertical_straights), "PREVIEW_MISSING_LONG_VERTICAL_STRAIGHT", sorted(vertical_straights))
    blend_path = HERE / "preview" / "continuous-connected-district.blend"
    bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    require(bpy.context.scene.name == "CitySimContinuousConnectedDistrict", "PREVIEW_BLEND_SCENE_MISMATCH", bpy.context.scene.name)
    require(bpy.data.objects.get("camNE_ContinuousConnectedDistrict") is not None, "PREVIEW_CAMERA_MISSING", blend_path)
    for coordinate, placement in by_coordinate.items():
        for direction in topology_for(placement["rawValue"])["directions"]:
            preview_marking_reaches_boundary(coordinate, direction)
    require(any(obj.name.endswith("CornerCenterlineContinuation") or "CornerCenterlineContinuation" in obj.name for obj in bpy.data.objects), "PREVIEW_CORNER_MARKINGS_MISSING", blend_path)
    require(any("Crosswalk" in obj.name for obj in bpy.data.objects), "PREVIEW_JUNCTION_MARKINGS_MISSING", blend_path)
    dimensions_seen = set()
    original_hashes = {}
    for artifact in data["artifacts"]:
        artifact_path = HERE / "preview" / Path(artifact["path"]).name
        require(artifact_path.is_file() and sha256(artifact_path) == artifact["sha256"], "PREVIEW_ARTIFACT_DRIFT", artifact_path)
        if artifact_path.suffix == ".png":
            width, height, rgba = decode_rgba_png(artifact_path)
            dimensions_seen.add((width, height))
            require(hashlib.sha256(rgba).hexdigest() == artifact["decodedRgbaSha256"], "PREVIEW_RGBA_HASH_DRIFT", artifact_path)
            original_hashes[artifact_path.name] = artifact["sha256"]
    require(dimensions_seen == {(1280, 800), (900, 600)}, "PREVIEW_DIMENSIONS_MISMATCH", sorted(dimensions_seen))
    rerenders = builder.build_preview(temp_root / "preview", write_evidence=False)
    for rerender in rerenders:
        require(sha256(rerender) == original_hashes[rerender.name], "PREVIEW_DETERMINISTIC_RERENDER_MISMATCH", rerender.name)
    return original_hashes


def topology_for(raw):
    return next(item for item in CONFIG["masks"] if item["rawValue"] == raw)


def validate_family_manifest():
    path = HERE / "family-manifest.json"
    require(path.is_file(), "MISSING_FAMILY_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["maskCount"] == 16 and data["canonicalViewCount"] == 64 and data["contactSheetCount"] == 16 and data["previewCount"] == 2, "FAMILY_CARDINALITY_MISMATCH", path)
    require(data["status"] == "source-only-candidate" and data["liveAsset"] is False, "FAMILY_STATUS_MISMATCH", path)
    require([item["rawValue"] for item in data["masks"]] == list(range(16)), "FAMILY_MASK_COVERAGE_MISMATCH", path)
    require(data["surface"] == SURFACE, "FAMILY_SURFACE_MISMATCH", path)
    require(data["boundaryMaterialContract"] == "identical-periodic-asphalt-sidewalk-curb-and-ochre-dash-boundary-phase", "FAMILY_BOUNDARY_CONTRACT_MISMATCH", path)
    for source in data["sourceFiles"]:
        source_path = HERE / source["path"]
        require(source_path.is_file() and sha256(source_path) == source["sha256"], "FAMILY_SOURCE_HASH_DRIFT", source_path)
    return data


def mark_manifests_validated():
    family_path = HERE / "family-manifest.json"
    family = json.loads(family_path.read_text())
    for item in CONFIG["masks"]:
        path = HERE / item["assetId"] / "manifest.json"
        data = json.loads(path.read_text())
        data["validation"] = {
            "status": "PASS",
            "report": "../validation/validator-output.txt",
            "socketGeometry": "source-mesh-bounds",
            "boundaryMarkingPhase": "dash-center-at-boundary",
            "deterministicRerender": "64-canonical-views-byte-identical",
        }
        path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    for entry in family["masks"]:
        manifest_path = HERE / entry["manifest"]
        entry["manifestSha256"] = sha256(manifest_path)
    family["validation"] = {
        "status": "PASS",
        "report": "validation/validator-output.txt",
        "boundaryMarkingPhase": "dash-center-at-boundary",
        "deterministicRerender": "64-canonical-views-and-two-preview-proofs-byte-identical",
    }
    family_path.write_text(json.dumps(family, indent=2, sort_keys=True) + "\n")


def parse_report_path():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--report" not in args:
        return HERE / "validation" / "validator-output.txt"
    return Path(args[args.index("--report") + 1])


def main():
    actual = ".".join(map(str, bpy.app.version))
    require(actual == CONFIG["toolchain"]["blenderVersion"], "BLENDER_VERSION_MISMATCH", actual)
    require(CONFIG["roadBits"] == {"north": 1, "east": 2, "south": 4, "west": 8}, "ROAD_BIT_CONTRACT_MISMATCH", CONFIG["roadBits"])
    require([item["rawValue"] for item in CONFIG["masks"]] == list(range(16)), "CONFIG_MASK_COVERAGE_MISMATCH", CONFIG["masks"])
    require(CONFIG["grid"]["projectedTilePixels"] == [88, 44] and CONFIG["canvas"]["footprintPivotPixel"] == [192, 300], "LOCKED_PROJECTION_CONTRACT_MISMATCH", CONFIG)
    results = {"schema": "citysim.world-art.streetscape-continuous-validation.v1", "status": "PASS", "blenderVersion": actual, "masks": {}}
    with tempfile.TemporaryDirectory(prefix="citysim-streetscape-continuous-determinism-") as temp_dir:
        temp_root = Path(temp_dir)
        for mask_data in CONFIG["masks"]:
            mesh_count, sockets = validate_scene(mask_data)
            validate_manifest(mask_data)
            render_hashes = deterministic_rerender(mask_data, temp_root)
            results["masks"][f"{mask_data['rawValue']:02d}"] = {
                "assetId": mask_data["assetId"],
                "topologyClass": mask_data["topologyClass"],
                "directions": mask_data["directions"],
                "meshCount": mesh_count,
                "boundarySockets": sockets,
                "deterministicCanonicalPngSha256": render_hashes,
            }
        results["previewPngSha256"] = validate_preview(temp_root)
    validate_family_manifest()
    mark_manifests_validated()
    results["familyManifestSha256"] = sha256(HERE / "family-manifest.json")
    results["contract"] = {
        "roadBits": CONFIG["roadBits"],
        "worldCell": [2.0, 2.0],
        "projectedTilePixels": [88, 44],
        "pivotPixels": [192, 300],
        "cameraOrder": [view["name"] for view in CONFIG["cameraRig"]["views"]],
        "surface": SURFACE,
        "boundaryMarkingPhase": "dash-center-at-boundary",
        "postRenderCompensation": "none",
        "deterministicRerender": "64 canonical views and two connected-network proofs byte-identical",
    }
    report_path = parse_report_path()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = "STREETSCAPE_CONTINUOUS_VALIDATION_PASS\n" + json.dumps(results, indent=2, sort_keys=True) + "\n"
    report_path.write_text(report)
    print(report, end="")


if __name__ == "__main__":
    main()
