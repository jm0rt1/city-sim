#!/usr/bin/env python3
"""Validate CitySim's density family, progression massing, and clean rerenders."""

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
BLENDER_ROOT = HERE.parents[1]
CANONICAL = BLENDER_ROOT / "FourViewPipeline"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))
sys.path.insert(0, str(HERE))
from png_canonical import canonicalize_png, decode_rgba_png  # noqa: E402
import build_and_render as builder  # noqa: E402

CONFIG = json.loads((HERE / "pipeline.json").read_text())


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


def projected_pixel(scene, camera, point):
    projected = world_to_camera_view(scene, camera, Vector(point))
    return Vector((projected.x * 384, (1 - projected.y) * 384))


def mesh_bounds(meshes):
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    require(points, "EMPTY_GEOMETRY", "no mesh bounds")
    return {
        "minimum": [min(point[axis] for point in points) for axis in range(3)],
        "maximum": [max(point[axis] for point in points) for axis in range(3)],
    }


def validate_scene(asset):
    path = HERE / asset["assetId"] / f"{asset['assetId']}.blend"
    require(path.is_file(), "MISSING_BLEND", path)
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    require(scene.render.engine == CONFIG["toolchain"]["renderEngine"], "ENGINE_MISMATCH", scene.render.engine)
    require((scene.render.resolution_x, scene.render.resolution_y) == (384, 384), "CANVAS_MISMATCH", asset["assetId"])
    require(scene.render.film_transparent, "CANVAS_NOT_TRANSPARENT", asset["assetId"])
    require(scene.get("postRenderCompensation") == "none", "POST_RENDER_COMPENSATION_FORBIDDEN", asset["assetId"])
    root = bpy.data.objects.get("AssetRoot")
    pivot = bpy.data.objects.get("FootprintPivot")
    require(root is not None and pivot is not None, "MISSING_ROOT_OR_PIVOT", asset["assetId"])
    vector(root.location, (0, 0, 0), 1e-5, "root.location")
    vector(root.rotation_euler, (0, 0, 0), 1e-5, "root.rotation")
    vector(root.scale, (1, 1, 1), 1e-5, "root.scale")
    require(pivot.parent == root, "PIVOT_PARENT_MISMATCH", asset["assetId"])
    require(root.get("assetFamily") == asset["assetFamily"], "ASSET_FAMILY_MISMATCH", asset["assetId"])
    require(root.get("zone") == asset["zone"], "ZONE_MISMATCH", asset["assetId"])
    require(root.get("densityLevel") == asset["densityLevel"], "DENSITY_LEVEL_MISMATCH", asset["assetId"])
    require(list(root.get("worldFootprintTiles")) == asset["footprintTiles"], "ROOT_FOOTPRINT_MISMATCH", asset["assetId"])
    require(root.get("sourcePixelsReused") is False and root.get("cedarMarketReused") is False, "PROVENANCE_MISMATCH", asset["assetId"])
    require(root.get("postRenderCompensation") == "none", "ROOT_COMPENSATION_FORBIDDEN", asset["assetId"])
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    require(len(meshes) >= asset["minimumMeshCount"], "GEOMETRY_TOO_SIMPLE", f"{asset['assetId']}: {len(meshes)} < {asset['minimumMeshCount']}")
    for obj in meshes:
        require(obj.parent == root, "MESH_OUTSIDE_ROOT", obj.name)
        vector(obj.scale, (1, 1, 1), 1e-5, obj.name + ".scale")
        vector(obj.rotation_euler, (0, 0, 0), 1e-5, obj.name + ".rotation")
    bounds = mesh_bounds(meshes)
    require(bounds["maximum"][2] >= asset["minimumHeight"], "INSUFFICIENT_DENSITY_HEIGHT", f"{asset['assetId']}: {bounds['maximum'][2]}")
    require(bounds["maximum"][2] <= 8.7, "ASSET_TOO_TALL_FOR_CANVAS", f"{asset['assetId']}: {bounds['maximum'][2]}")
    ground = next((obj for obj in meshes if obj.name.endswith("LotGround")), None)
    require(ground is not None, "MISSING_GROUNDED_LOT", asset["assetId"])
    require(list(ground.get("worldFootprintTiles")) == [2, 2], "FOOTPRINT_TILE_MISMATCH", asset["assetId"])
    require(list(ground.get("exactWorldFootprint")) == [4.0, 4.0], "WORLD_FOOTPRINT_MISMATCH", asset["assetId"])

    lights = [obj for obj in bpy.data.objects if obj.type == "LIGHT"]
    require(len(lights) == 1 and lights[0].name == "CitySimKey", "LIGHT_CONVENTION_MISMATCH", [obj.name for obj in lights])
    vector(lights[0].location, CONFIG["lighting"]["location"], 1e-5, "light.location")
    close(lights[0].data.energy, 1100, 1e-5, "light.energy")
    close(lights[0].data.size, 5, 1e-5, "light.size")
    vector(lights[0].data.color, CONFIG["lighting"]["color"], 1e-5, "light.color")

    cameras = [obj for obj in bpy.data.objects if obj.type == "CAMERA"]
    expected_names = [view["name"] for view in CONFIG["cameraRig"]["views"]]
    require(sorted(obj.name for obj in cameras) == sorted(expected_names), "CAMERA_SET_MISMATCH", [obj.name for obj in cameras])
    axis_signatures = {}
    for view in CONFIG["cameraRig"]["views"]:
        camera = bpy.data.objects[view["name"]]
        require(camera.data.type == "ORTHO", "CAMERA_NOT_ORTHO", camera.name)
        close(camera.data.ortho_scale, 12.341995, 1e-5, camera.name + ".orthoScale")
        close(camera.data.shift_y, 0.28125, 1e-5, camera.name + ".shiftY")
        origin = projected_pixel(scene, camera, (0, 0, 0))
        vector(origin, (192, 300), 0.01, camera.name + ".pivotPixel")
        horizontal = math.hypot(camera.location.x, camera.location.y)
        close(math.degrees(math.atan2(camera.location.z, horizontal)), 30, 0.0001, camera.name + ".elevation")
        close(math.degrees(math.atan2(camera.location.x, camera.location.y)) % 360, view["azimuthDegrees"], 0.0001, camera.name + ".azimuth")
        x_axis = projected_pixel(scene, camera, (2, 0, 0)) - origin
        y_axis = projected_pixel(scene, camera, (0, 2, 0)) - origin
        vector((abs(x_axis.x), abs(x_axis.y)), (44, 22), 0.01, camera.name + ".xAxisPixels")
        vector((abs(y_axis.x), abs(y_axis.y)), (44, 22), 0.01, camera.name + ".yAxisPixels")
        close(abs(x_axis.dot(y_axis)), (44 * 44) - (22 * 22), 0.2, camera.name + ".axisDotMagnitude")
        axis_signatures[camera.name] = [[round(x_axis.x), round(x_axis.y)], [round(y_axis.x), round(y_axis.y)]]
        corners = [projected_pixel(scene, camera, point) for point in ((-1, -1, 0), (1, -1, 0), (1, 1, 0), (-1, 1, 0))]
        width = max(point.x for point in corners) - min(point.x for point in corners)
        height = max(point.y for point in corners) - min(point.y for point in corners)
        vector((width, height), (88, 44), 0.01, camera.name + ".projectedTilePixels")
    require(len({str(value) for value in axis_signatures.values()}) == 4, "VIEW_ORIENTATION_NOT_UNIQUE", axis_signatures)
    return len(meshes), bounds, axis_signatures


def validate_manifest(asset):
    output_dir = HERE / asset["assetId"]
    path = output_dir / "manifest.json"
    require(path.is_file(), "MISSING_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["assetId"] == asset["assetId"] and data["assetFamily"] == asset["assetFamily"], "MANIFEST_IDENTITY_MISMATCH", path)
    require(data["zone"] == asset["zone"] and data["densityLevel"] == asset["densityLevel"], "MANIFEST_PROGRESSION_MISMATCH", path)
    require(data["status"] == "source-only-not-live" and data["liveAsset"] is False, "MANIFEST_STATUS_MISMATCH", path)
    require(data["originalGeometry"] is True and data["sourcePixelsReused"] is False and data["cedarMarketReused"] is False, "MANIFEST_PROVENANCE_MISMATCH", path)
    require(data["postRenderCompensation"] == "none", "MANIFEST_COMPENSATION_FORBIDDEN", path)
    require(data["perViewCompensation"] == {"crop": False, "offsetPixels": [0, 0], "rotationDegrees": 0.0, "scale": 1.0, "skew": [0.0, 0.0]}, "PER_VIEW_COMPENSATION_FORBIDDEN", path)
    expected_sources = {"build_and_render.py", "pipeline.json", "run_pipeline.sh"}
    require({item["path"] for item in data["sourceFiles"]} == expected_sources, "SOURCE_FILE_SET_MISMATCH", path)
    for source in data["sourceFiles"]:
        source_path = HERE / source["path"]
        require(source_path.is_file() and sha256(source_path) == source["sha256"], "SOURCE_HASH_DRIFT", source_path)
    render_count = 0
    png_hashes = {}
    for artifact in data["artifacts"]:
        artifact_path = output_dir / artifact["path"]
        require(artifact_path.is_file(), "MISSING_ARTIFACT", artifact_path)
        require(artifact_path.stat().st_size == artifact["bytes"] and sha256(artifact_path) == artifact["sha256"], "ARTIFACT_HASH_DRIFT", artifact_path)
        if artifact_path.suffix != ".png":
            continue
        width, height, rgba = decode_rgba_png(artifact_path)
        require([width, height] == artifact["dimensions"], "PNG_DIMENSION_DRIFT", artifact_path)
        require(hashlib.sha256(rgba).hexdigest() == artifact["decodedRgbaSha256"], "RGBA_HASH_DRIFT", artifact_path)
        expected = (784, 840) if "contact-sheet" in artifact_path.name else (384, 384)
        require((width, height) == expected, "PNG_CANVAS_MISMATCH", f"{artifact_path}: {(width, height)}")
        alpha = rgba[3::4]
        require(any(alpha) and any(value == 0 for value in alpha), "ALPHA_POLICY_MISMATCH", artifact_path)
        if expected == (384, 384):
            render_count += 1
            metadata = artifact["alpha"]
            opaque = [(index % width, index // width) for index, value in enumerate(alpha) if value]
            xs, ys = [p[0] for p in opaque], [p[1] for p in opaque]
            actual_bounds = {"minX": min(xs), "minY": min(ys), "maxX": max(xs), "maxY": max(ys), "width": max(xs)-min(xs)+1, "height": max(ys)-min(ys)+1}
            require(actual_bounds == metadata["boundsTopOrigin"], "ALPHA_BOUNDS_DRIFT", artifact_path)
            require(min(ys) >= 2 and max(xs) <= 381 and min(xs) >= 2, "CANVAS_CLIPPING", f"{artifact_path}: {actual_bounds}")
            pivot_alpha = rgba[(300 * width + 192) * 4 + 3]
            require(pivot_alpha == metadata["pivotPixelAlpha"] and pivot_alpha > 0, "PIVOT_CONTACT_MISSING", artifact_path)
            require(330 <= max(ys) <= 350, "GROUND_CONTACT_ROW_MISMATCH", f"{artifact_path}: {max(ys)}")
            png_hashes[artifact_path.name] = artifact["sha256"]
    require(render_count == 4, "FOUR_VIEW_RENDER_COUNT_MISMATCH", render_count)
    return png_hashes


def deterministic_rerender(asset, temp_root):
    scene, _, cameras = builder.build_asset(asset)
    rerenders = builder.render_views(scene, cameras, asset["assetId"], temp_root / asset["assetId"])
    hashes = {}
    for rerender in rerenders:
        original = HERE / asset["assetId"] / "renders" / rerender.name
        require(sha256(rerender) == sha256(original), "DETERMINISTIC_RERENDER_MISMATCH", rerender.name)
        hashes[rerender.name] = sha256(rerender)
    return hashes


def source_height(path):
    require(path.is_file(), "MISSING_PROGRESSION_SOURCE", path)
    bpy.ops.wm.open_mainfile(filepath=str(path))
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    return mesh_bounds(meshes)["maximum"][2]


def validate_progression_heights():
    measured = {}
    for item in builder.preview_sources():
        measured.setdefault(item["zone"], {})[item["densityLevel"]] = {
            "assetId": item["assetId"],
            "maximumWorldZ": source_height(item["source"]),
        }
    for zone, levels in measured.items():
        require(set(levels) == {1, 2, 3}, "PROGRESSION_LEVEL_SET_MISMATCH", zone)
        heights = [levels[level]["maximumWorldZ"] for level in (1, 2, 3)]
        require(heights[0] + 0.35 < heights[1] and heights[1] + 0.55 < heights[2], "DENSITY_MASSING_NOT_STEPWISE", f"{zone}: {heights}")
    return measured


def validate_preview(temp_root):
    path = HERE / "preview" / "manifest.json"
    require(path.is_file(), "MISSING_PREVIEW_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["acceptedFamilyContractOnly"] is True and data["cedarMarketReused"] is False, "PREVIEW_FAMILY_POLICY_MISMATCH", path)
    require(data["camera"] == {"azimuthDegrees": 45.0, "elevationDegrees": 30.0, "orthoScale": CONFIG["progressionPreview"]["camera"]["orthoScale"], "perAssetCompensation": "none", "projection": "orthographic"}, "PREVIEW_CAMERA_MISMATCH", data["camera"])
    require(len(data["placements"]) == 9, "PREVIEW_ASSET_COUNT_MISMATCH", len(data["placements"]))
    require({(p["zone"], p["densityLevel"]) for p in data["placements"]} == {(zone, level) for zone in ("residential", "commercial", "industrial") for level in (1, 2, 3)}, "PREVIEW_PROGRESSION_MATRIX_MISMATCH", data["placements"])
    for placement in data["placements"]:
        require(placement["perAssetTransformCompensation"] == "none", "PREVIEW_PLACEMENT_COMPENSATION_FORBIDDEN", placement["assetId"])
        for axis in range(2):
            origin = float(placement["originWorld"][axis])
            require(abs(origin / 2.0 - round(origin / 2.0)) < 1e-6, "PREVIEW_OFF_GRID_ORIGIN", placement)
            footprint_world = float(placement["footprintTiles"][axis]) * 2.0
            minimum_edge = origin - footprint_world / 2.0
            require(abs(minimum_edge / 2.0 - round(minimum_edge / 2.0)) < 1e-6, "PREVIEW_OFF_GRID_EDGE", placement)
        source = BLENDER_ROOT / placement["sourceBlend"]
        require(source.is_file() and sha256(source) == placement["sourceBlendSha256"], "PREVIEW_SOURCE_DRIFT", source)
    for source in data["sourceFiles"]:
        source_path = HERE / source["path"]
        require(source_path.is_file() and sha256(source_path) == source["sha256"], "PREVIEW_SOURCE_SCRIPT_DRIFT", source_path)
    dimensions = set()
    hashes = {}
    for artifact in data["artifacts"]:
        artifact_path = HERE / artifact["path"]
        require(artifact_path.is_file() and sha256(artifact_path) == artifact["sha256"], "PREVIEW_ARTIFACT_DRIFT", artifact_path)
        if artifact_path.suffix == ".png":
            width, height, rgba = decode_rgba_png(artifact_path)
            dimensions.add((width, height))
            require(hashlib.sha256(rgba).hexdigest() == artifact["decodedRgbaSha256"], "PREVIEW_RGBA_HASH_DRIFT", artifact_path)
            hashes[artifact["path"]] = artifact["sha256"]
    require(dimensions == {(1280, 800), (900, 600)}, "PREVIEW_DIMENSIONS_MISMATCH", sorted(dimensions))

    blend_path = HERE / "preview" / "uptown-foundry-progression-avenue.blend"
    bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    scene = bpy.context.scene
    camera = bpy.data.objects.get("camNE_ProgressionPreview")
    require(camera is not None and camera.data.type == "ORTHO", "PREVIEW_CAMERA_MISSING", blend_path)
    close(camera.data.ortho_scale, CONFIG["progressionPreview"]["camera"]["orthoScale"], 1e-5, "preview.orthoScale")
    horizontal = math.hypot(camera.location.x, camera.location.y)
    close(math.degrees(math.atan2(camera.location.z, horizontal)), 30, 0.0001, "preview.elevation")
    close(math.degrees(math.atan2(camera.location.x, camera.location.y)) % 360, 45, 0.0001, "preview.azimuth")
    for placement in data["placements"]:
        obj = bpy.data.objects.get("Placement_" + placement["assetId"])
        require(obj is not None, "PREVIEW_PLACEMENT_MISSING", placement["assetId"])
        vector(obj.location, placement["originWorld"], 1e-5, obj.name + ".location")
        vector(obj.rotation_euler, (0, 0, 0), 1e-5, obj.name + ".rotation")
        vector(obj.scale, (1, 1, 1), 1e-5, obj.name + ".scale")
    road_objects = [obj for obj in bpy.data.objects if "AxisRoad" in obj.name]
    require(len(road_objects) == 4, "PREVIEW_ROAD_SET_MISMATCH", [obj.name for obj in road_objects])
    for road in road_objects:
        vector(road.rotation_euler, (0, 0, 0), 1e-5, road.name + ".rotation")
        vector(road.scale, (1, 1, 1), 1e-5, road.name + ".scale")

    rerender_hashes = {}
    for width, height in ((1280, 800), (900, 600)):
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        rerender = temp_root / f"uptown-foundry-progression-avenue-{width}x{height}.png"
        scene.render.filepath = str(rerender)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(rerender)
        original = HERE / "preview" / rerender.name
        require(sha256(rerender) == sha256(original), "PREVIEW_DETERMINISTIC_RERENDER_MISMATCH", rerender.name)
        rerender_hashes[rerender.name] = sha256(rerender)
    return hashes, rerender_hashes


def parse_report_path():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if "--report" not in args:
        return HERE / "validation" / "validator-output.txt"
    return Path(args[args.index("--report") + 1])


def main():
    actual = ".".join(map(str, bpy.app.version))
    require(actual == CONFIG["toolchain"]["blenderVersion"], "BLENDER_VERSION_MISMATCH", actual)
    results = {"schema": "citysim.world-art.density-validation.v1", "status": "PASS", "blenderVersion": actual, "assets": {}}
    with tempfile.TemporaryDirectory(prefix="citysim-density-determinism-") as temp_dir:
        temp_root = Path(temp_dir)
        for asset in CONFIG["assets"]:
            mesh_count, bounds, axes = validate_scene(asset)
            manifest_hashes = validate_manifest(asset)
            rerender_hashes = deterministic_rerender(asset, temp_root)
            require(manifest_hashes == rerender_hashes, "MANIFEST_RERENDER_HASH_SET_MISMATCH", asset["assetId"])
            results["assets"][asset["assetId"]] = {
                "zone": asset["zone"],
                "densityLevel": asset["densityLevel"],
                "meshCount": mesh_count,
                "worldBounds": bounds,
                "projectedAxisPixels": axes,
                "deterministicCanonicalPngSha256": rerender_hashes,
            }
        results["progressionWorldHeights"] = validate_progression_heights()
        preview_hashes, preview_rerenders = validate_preview(temp_root)
        results["previewPngSha256"] = preview_hashes
        results["previewDeterministicRerenderSha256"] = preview_rerenders
    results["contract"] = {
        "projectedTilePixels": [88, 44],
        "pivotPixels": [192, 300],
        "cameraOrder": [view["name"] for view in CONFIG["cameraRig"]["views"]],
        "postRenderCompensation": "none",
        "deterministicRerender": "byte-identical canonical asset and preview PNGs",
        "densityProgression": "strictly increasing source world height for each zone",
    }
    report_path = parse_report_path()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = "DENSITY_FOUR_VIEW_VALIDATION_PASS\n" + json.dumps(results, indent=2, sort_keys=True) + "\n"
    report_path.write_text(report)
    print(report, end="")


if __name__ == "__main__":
    main()
