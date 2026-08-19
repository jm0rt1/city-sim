#!/usr/bin/env python3
"""Validate CitySim's refined 16-mask streetscape and deterministic renders."""

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
    require(scene.get("surfaceFamily") == "foundry-warm-charcoal-v1", "SURFACE_FAMILY_MISMATCH", asset_id)
    root = bpy.data.objects.get("AssetRoot")
    pivot = bpy.data.objects.get("FootprintPivot")
    require(root is not None and pivot is not None, "MISSING_ROOT_OR_PIVOT", asset_id)
    vector(root.location, (0, 0, 0), 1e-7, "root.location")
    vector(root.rotation_euler, (0, 0, 0), 1e-7, "root.rotation")
    vector(root.scale, (1, 1, 1), 1e-7, "root.scale")
    require(pivot.parent == root, "PIVOT_PARENT_MISMATCH", asset_id)
    require(root.get("roadMaskRawValue") == mask_data["rawValue"], "ROOT_MASK_MISMATCH", asset_id)
    require(root.get("topologyClass") == mask_data["topologyClass"], "ROOT_TOPOLOGY_MISMATCH", asset_id)
    require(root.get("liveAsset") is False and root.get("sourcePixelsReused") is False and root.get("cedarMarketReused") is False, "PROVENANCE_MISMATCH", asset_id)

    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    require(len(meshes) >= 6, "GEOMETRY_TOO_SIMPLE", f"{asset_id}: {len(meshes)}")
    for obj in meshes:
        require(obj.parent == root, "MESH_OUTSIDE_ROOT", obj.name)
        vector(obj.location, (0, 0, 0), 1e-7, obj.name + ".location")
        vector(obj.rotation_euler, (0, 0, 0), 1e-7, obj.name + ".rotation")
        vector(obj.scale, (1, 1, 1), 1e-7, obj.name + ".scale")
        bounds = mesh_bounds(obj)
        width, depth = bounds["maxX"] - bounds["minX"], bounds["maxY"] - bounds["minY"]
        require(not (width >= 1.90 and depth >= 1.90), "RAISED_TILE_PLATE_FORBIDDEN", obj.name)
    walk = bpy.data.objects.get("WalkCore")
    asphalt = bpy.data.objects.get("AsphaltCore")
    require(walk is not None and asphalt is not None, "MISSING_CORE_SURFACES", asset_id)
    walk_bounds = mesh_bounds(walk)
    asphalt_bounds = mesh_bounds(asphalt)
    vector((walk_bounds["minX"], walk_bounds["maxX"], walk_bounds["minY"], walk_bounds["maxY"]), (-0.64, 0.64, -0.64, 0.64), 1e-7, "walkCoreBounds")
    vector((asphalt_bounds["minX"], asphalt_bounds["maxX"], asphalt_bounds["minY"], asphalt_bounds["maxY"]), (-0.46, 0.46, -0.46, 0.46), 1e-7, "asphaltCoreBounds")
    require(asphalt.data.materials[0].name == "FoundryWarmCharcoalAsphalt", "ASPHALT_MATERIAL_MISMATCH", asset_id)
    require(walk.data.materials[0].name == "QuietWarmGrayAggregate", "SIDEWALK_MATERIAL_MISMATCH", asset_id)

    socket_report = {}
    for direction, spec in DIRECTIONS.items():
        connected = direction in mask_data["directions"]
        socket = bpy.data.objects.get("Socket_" + direction.capitalize())
        arm = bpy.data.objects.get("RoadArm" + direction.capitalize())
        walk_arm = bpy.data.objects.get("WalkArm" + direction.capitalize())
        closed = bpy.data.objects.get("ClosedCurb" + direction.capitalize())
        if connected:
            require(socket is not None and arm is not None and walk_arm is not None, "MISSING_CONNECTED_SOCKET", f"{asset_id}:{direction}")
            require(closed is None, "CONNECTED_EDGE_MARKED_CLOSED", f"{asset_id}:{direction}")
            vector(socket.location, spec["point"], 1e-7, direction + ".socket")
            close(socket.get("socketWidthWorld"), 0.92, 1e-7, direction + ".socketWidth")
            close(socket.get("materialOverlapWorld"), 0.10, 1e-7, direction + ".overlap")
            require(socket.get("bit") == spec["bit"] and socket.get("direction") == direction, "SOCKET_METADATA_MISMATCH", f"{asset_id}:{direction}")
            bounds = mesh_bounds(arm)
            walk_arm_bounds = mesh_bounds(walk_arm)
            point = spec["point"]
            if point[0] > 0:
                close(bounds["maxX"], 1.10, 1e-7, direction + ".roadBleed")
                close(walk_arm_bounds["maxX"], 1.10, 1e-7, direction + ".walkBleed")
            elif point[0] < 0:
                close(bounds["minX"], -1.10, 1e-7, direction + ".roadBleed")
                close(walk_arm_bounds["minX"], -1.10, 1e-7, direction + ".walkBleed")
            elif point[1] > 0:
                close(bounds["maxY"], 1.10, 1e-7, direction + ".roadBleed")
                close(walk_arm_bounds["maxY"], 1.10, 1e-7, direction + ".walkBleed")
            else:
                close(bounds["minY"], -1.10, 1e-7, direction + ".roadBleed")
                close(walk_arm_bounds["minY"], -1.10, 1e-7, direction + ".walkBleed")
            require(arm.data.materials[0].name == "FoundryWarmCharcoalAsphalt", "ARM_ASPHALT_MATERIAL_MISMATCH", arm.name)
            require(walk_arm.data.materials[0].name == "QuietWarmGrayAggregate", "ARM_WALK_MATERIAL_MISMATCH", walk_arm.name)
            socket_report[direction] = {"bit": spec["bit"], "point": list(spec["point"]), "roadArmBounds": bounds, "walkArmBounds": walk_arm_bounds}
        else:
            require(socket is None and arm is None and walk_arm is None, "ABSENT_SOCKET_PRESENT", f"{asset_id}:{direction}")
            if mask_data["rawValue"] == 0:
                require(closed is None, "ISOLATED_TURNAROUND_SQUARE_CURB_FORBIDDEN", direction)
            else:
                require(closed is not None and closed.get("closedBoundary") == direction, "ABSENT_EDGE_NOT_CLOSED", f"{asset_id}:{direction}")

    repeated_markings = [obj.name for obj in meshes if obj.name.startswith("LaneDash") or obj.name.startswith("CenterLine")]
    require(not repeated_markings, "REPEATED_TILE_MARKING_FORBIDDEN", repeated_markings)
    if mask_data["topologyClass"] in ("straight", "corner"):
        decorative = [obj.name for obj in meshes if any(token in obj.name for token in ("Crossing", "Bollard", "CatchBasin", "Paver"))]
        require(not decorative, "QUIET_TOPOLOGY_HAS_REPEATED_DETAIL", decorative)

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
    require(data["surface"] == CONFIG["surface"], "SURFACE_CONTRACT_MISMATCH", path)
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


def validate_preview(temp_root):
    path = HERE / "preview" / "manifest.json"
    require(path.is_file(), "MISSING_PREVIEW_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["liveAsset"] is False and data["originalGeometry"] is True and data["cedarMarketReused"] is False, "PREVIEW_PROVENANCE_MISMATCH", path)
    require(data["camera"] == {"projection": "orthographic", "azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none"}, "PREVIEW_CAMERA_MISMATCH", data["camera"])
    require(data["observedRawValues"] == list(range(16)), "PREVIEW_MASK_COVERAGE_MISMATCH", data["observedRawValues"])
    require(data["surface"] == CONFIG["surface"], "PREVIEW_SURFACE_MISMATCH", data["surface"])
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
    horizontal_straights = {coordinate for coordinate, placement in by_coordinate.items() if placement["rawValue"] == 10}
    require(any((x + 1, y) in horizontal_straights and (x + 2, y) in horizontal_straights for x, y in horizontal_straights), "PREVIEW_MISSING_ADJACENT_STRAIGHT_RUN", sorted(horizontal_straights))
    blend_path = HERE / "preview" / "foundry-connected-district.blend"
    bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    require(bpy.context.scene.name == "CitySimFoundryConnectedDistrict", "PREVIEW_BLEND_SCENE_MISMATCH", bpy.context.scene.name)
    require(bpy.data.objects.get("camNE_RefinedConnectedDistrict") is not None, "PREVIEW_CAMERA_MISSING", blend_path)
    dimensions = set()
    original_hashes = {}
    for artifact in data["artifacts"]:
        artifact_path = HERE / "preview" / Path(artifact["path"]).name
        require(artifact_path.is_file() and sha256(artifact_path) == artifact["sha256"], "PREVIEW_ARTIFACT_DRIFT", artifact_path)
        if artifact_path.suffix == ".png":
            width, height, rgba = decode_rgba_png(artifact_path)
            dimensions.add((width, height))
            require(hashlib.sha256(rgba).hexdigest() == artifact["decodedRgbaSha256"], "PREVIEW_RGBA_HASH_DRIFT", artifact_path)
            original_hashes[artifact_path.name] = artifact["sha256"]
    require(dimensions == {(1280, 800), (900, 600)}, "PREVIEW_DIMENSIONS_MISMATCH", sorted(dimensions))
    rerenders = builder.build_preview(temp_root / "preview", write_evidence=False)
    for rerender in rerenders:
        require(sha256(rerender) == original_hashes[rerender.name], "PREVIEW_DETERMINISTIC_RERENDER_MISMATCH", rerender.name)
    return original_hashes


def validate_family_manifest():
    path = HERE / "family-manifest.json"
    require(path.is_file(), "MISSING_FAMILY_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["maskCount"] == 16 and data["canonicalViewCount"] == 64, "FAMILY_CARDINALITY_MISMATCH", path)
    require(data["status"] == "source-only-candidate" and data["liveAsset"] is False, "FAMILY_STATUS_MISMATCH", path)
    require([item["rawValue"] for item in data["masks"]] == list(range(16)), "FAMILY_MASK_COVERAGE_MISMATCH", path)
    require(data["surface"] == CONFIG["surface"], "FAMILY_SURFACE_MISMATCH", path)
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
            "deterministicRerender": "64-canonical-views-byte-identical",
        }
        path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    for entry in family["masks"]:
        manifest_path = HERE / entry["manifest"]
        entry["manifestSha256"] = sha256(manifest_path)
    family["validation"] = {"status": "PASS", "report": "validation/validator-output.txt", "deterministicRerender": "64-canonical-views-and-two-preview-proofs-byte-identical"}
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
    require(CONFIG["surface"] == {"roadWidthWorld": 0.92, "walkWidthWorld": 1.28, "socketBleedWorld": 0.10, "curbWidthWorld": 0.025}, "SURFACE_CONTRACT_MISMATCH", CONFIG["surface"])
    results = {"schema": "citysim.world-art.streetscape-refined-validation.v1", "status": "PASS", "blenderVersion": actual, "masks": {}}
    with tempfile.TemporaryDirectory(prefix="citysim-streetscape-refined-determinism-") as temp_dir:
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
        "surface": CONFIG["surface"],
        "postRenderCompensation": "none",
        "deterministicRerender": "64 canonical views and two district proofs byte-identical",
    }
    report_path = parse_report_path()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = "STREETSCAPE_REFINED_VALIDATION_PASS\n" + json.dumps(results, indent=2, sort_keys=True) + "\n"
    report_path.write_text(report)
    print(report, end="")


if __name__ == "__main__":
    main()
