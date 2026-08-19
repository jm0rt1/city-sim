#!/usr/bin/env python3
"""Independently validate CitySim service variants and every PNG rerender."""

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
from png_canonical import decode_rgba_png  # noqa: E402
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


def validate_scene(asset):
    path = HERE / asset["assetId"] / f"{asset['assetId']}.blend"
    require(path.is_file(), "MISSING_BLEND", path)
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    require(scene.render.engine == CONFIG["toolchain"]["renderEngine"], "ENGINE_MISMATCH", scene.render.engine)
    require((scene.render.resolution_x, scene.render.resolution_y) == (384, 384), "CANVAS_MISMATCH", asset["assetId"])
    require(scene.render.film_transparent, "CANVAS_NOT_TRANSPARENT", asset["assetId"])
    require(scene.get("postRenderCompensation") == "none", "POST_RENDER_COMPENSATION_FORBIDDEN", asset["assetId"])
    root, pivot = bpy.data.objects.get("AssetRoot"), bpy.data.objects.get("FootprintPivot")
    require(root is not None and pivot is not None, "MISSING_ROOT_OR_PIVOT", asset["assetId"])
    vector(root.location, (0, 0, 0), 1e-5, "root.location")
    vector(root.rotation_euler, (0, 0, 0), 1e-5, "root.rotation")
    vector(root.scale, (1, 1, 1), 1e-5, "root.scale")
    vector(pivot.location, (0, 0, 0), 1e-5, "pivot.location")
    require(pivot.parent == root, "PIVOT_PARENT_MISMATCH", asset["assetId"])
    require(root.get("assetId") == asset["assetId"] and root.get("serviceRole") == asset["serviceRole"], "ASSET_IDENTITY_MISMATCH", asset["assetId"])
    require(root.get("sourcePixelsReused") is False and root.get("cedarMarketReused") is False, "PROVENANCE_MISMATCH", asset["assetId"])
    require(root.get("postRenderCompensation") == "none" and root.get("fixedObjectScale") is True, "ROOT_COMPENSATION_FORBIDDEN", asset["assetId"])
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    require(len(meshes) >= 55, "GEOMETRY_TOO_SIMPLE", f"{asset['assetId']}: {len(meshes)} meshes")
    for obj in meshes:
        require(obj.parent == root, "MESH_OUTSIDE_ROOT", obj.name)
        vector(obj.scale, (1, 1, 1), 1e-5, obj.name + ".scale")
        vector(obj.rotation_euler, (0, 0, 0), 1e-5, obj.name + ".rotation")
    ground = next((obj for obj in meshes if obj.name.endswith("LotGround")), None)
    require(ground is not None, "MISSING_GROUNDED_LOT", asset["assetId"])
    require(list(ground.get("worldFootprintTiles")) == [2, 2], "FOOTPRINT_TILE_MISMATCH", asset["assetId"])
    require(list(ground.get("exactWorldFootprint")) == [4.0, 4.0], "WORLD_FOOTPRINT_MISMATCH", asset["assetId"])

    lights = [obj for obj in bpy.data.objects if obj.type == "LIGHT"]
    require(len(lights) == 1 and lights[0].name == "CitySimKey", "LIGHT_CONVENTION_MISMATCH", [obj.name for obj in lights])
    vector(lights[0].location, CONFIG["lighting"]["location"], 1e-5, "light.location")
    close(lights[0].data.energy, CONFIG["lighting"]["energy"], 1e-5, "light.energy")
    close(lights[0].data.size, CONFIG["lighting"]["size"], 1e-5, "light.size")
    vector(lights[0].data.color, CONFIG["lighting"]["color"], 1e-5, "light.color")

    cameras = [obj for obj in bpy.data.objects if obj.type == "CAMERA"]
    expected_names = [view["name"] for view in CONFIG["cameraRig"]["views"]]
    require(sorted(obj.name for obj in cameras) == sorted(expected_names), "CAMERA_SET_MISMATCH", [obj.name for obj in cameras])
    axis_signatures = {}
    for view in CONFIG["cameraRig"]["views"]:
        camera = bpy.data.objects[view["name"]]
        require(camera.data.type == "ORTHO", "CAMERA_NOT_ORTHO", camera.name)
        close(camera.data.ortho_scale, CONFIG["cameraRig"]["orthoScale"], 1e-5, camera.name + ".orthoScale")
        close(camera.data.shift_y, CONFIG["cameraRig"]["shiftY"], 1e-5, camera.name + ".shiftY")
        origin = projected_pixel(scene, camera, (0, 0, 0))
        vector(origin, CONFIG["canvas"]["footprintPivotPixel"], 0.01, camera.name + ".pivotPixel")
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
    return len(meshes), axis_signatures


def validate_manifest(asset):
    output_dir = HERE / asset["assetId"]
    path = output_dir / "manifest.json"
    require(path.is_file(), "MISSING_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["assetId"] == asset["assetId"] and data["serviceRole"] == asset["serviceRole"], "MANIFEST_IDENTITY_MISMATCH", path)
    require(data["status"] == "source-only-not-live" and data["liveAsset"] is False, "MANIFEST_STATUS_MISMATCH", path)
    require(data["originalGeometry"] is True and data["sourcePixelsReused"] is False and data["cedarMarketReused"] is False, "MANIFEST_PROVENANCE_MISMATCH", path)
    require(data["cameraOrder"] == ["camNE", "camSE", "camSW", "camNW"], "CAMERA_ORDER_MISMATCH", path)
    require(data["postRenderCompensation"] == "none", "MANIFEST_COMPENSATION_FORBIDDEN", path)
    require(data["perViewCompensation"] == {"crop": False, "offsetPixels": [0, 0], "rotationDegrees": 0.0, "scale": 1.0, "skew": [0.0, 0.0]}, "PER_VIEW_COMPENSATION_FORBIDDEN", path)
    render_count, sheet_count = 0, 0
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
        if expected == (784, 840):
            sheet_count += 1
            continue
        render_count += 1
        opaque = [(index % width, index // width) for index, value in enumerate(alpha) if value]
        xs, ys = [point[0] for point in opaque], [point[1] for point in opaque]
        bounds = {"minX": min(xs), "minY": min(ys), "maxX": max(xs), "maxY": max(ys), "width": max(xs)-min(xs)+1, "height": max(ys)-min(ys)+1}
        require(bounds == artifact["alpha"]["boundsTopOrigin"], "ALPHA_BOUNDS_DRIFT", artifact_path)
        pivot_alpha = rgba[(300 * width + 192) * 4 + 3]
        require(pivot_alpha == artifact["alpha"]["pivotPixelAlpha"] and pivot_alpha > 0, "PIVOT_CONTACT_MISSING", artifact_path)
        require(330 <= max(ys) <= 350, "GROUND_CONTACT_ROW_MISMATCH", f"{artifact_path}: {max(ys)}")
    require(render_count == 4 and sheet_count == 1, "ASSET_PNG_COUNT_MISMATCH", (render_count, sheet_count))


def deterministic_asset_rerender(asset, temp_root):
    scene, _, cameras = builder.build_asset(asset)
    output_dir = temp_root / asset["assetId"]
    render_paths = builder.render_views(scene, cameras, asset["assetId"], output_dir / "renders")
    sheet_path = builder.contact_sheet(render_paths, output_dir / f"{asset['assetId']}_contact-sheet.png")
    hashes = {}
    for rerender in [*render_paths, sheet_path]:
        relative = rerender.relative_to(output_dir)
        original = HERE / asset["assetId"] / relative
        require(sha256(rerender) == sha256(original), "DETERMINISTIC_RERENDER_MISMATCH", relative)
        hashes[relative.as_posix()] = sha256(rerender)
    return hashes


def validate_preview_structure():
    blend_path = HERE / "preview" / "service-variety-block.blend"
    require(blend_path.is_file(), "MISSING_PREVIEW_BLEND", blend_path)
    bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    scene = bpy.context.scene
    require(scene.render.engine == CONFIG["toolchain"]["renderEngine"], "PREVIEW_ENGINE_MISMATCH", scene.render.engine)
    require(not scene.render.film_transparent, "PREVIEW_MUST_BE_OPAQUE", blend_path)
    cameras = [obj for obj in bpy.data.objects if obj.type == "CAMERA"]
    require(len(cameras) == 1 and cameras[0].name == "camNE_BlockPreview" and cameras[0].data.type == "ORTHO", "PREVIEW_CAMERA_SET_MISMATCH", [obj.name for obj in cameras])
    close(cameras[0].data.ortho_scale, 13.2, 1e-5, "preview.orthoScale")
    lights = [obj for obj in bpy.data.objects if obj.type == "LIGHT"]
    require(len(lights) == 1 and lights[0].name == "CitySimKey", "PREVIEW_LIGHT_MISMATCH", [obj.name for obj in lights])
    vector(lights[0].location, CONFIG["lighting"]["location"], 1e-5, "preview.light.location")
    placements = {obj.name: obj for obj in bpy.data.objects if obj.name.startswith("Placement_")}
    expected = {f"Placement_{asset['assetId']}" for asset in CONFIG["assets"]}
    require(set(placements) == expected, "PREVIEW_PLACEMENT_SET_MISMATCH", sorted(placements))
    for placement in placements.values():
        vector(placement.rotation_euler, (0, 0, 0), 1e-5, placement.name + ".rotation")
        vector(placement.scale, (1, 1, 1), 1e-5, placement.name + ".scale")
        require(placement.get("perAssetTransformCompensation") == "none", "PREVIEW_PLACEMENT_COMPENSATION_FORBIDDEN", placement.name)


def validate_preview_manifest(temp_root):
    path = HERE / "preview" / "manifest.json"
    require(path.is_file(), "MISSING_PREVIEW_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["acceptedFamilyContractOnly"] is True and data["cedarMarketReused"] is False, "PREVIEW_FAMILY_POLICY_MISMATCH", path)
    require(data["camera"] == {"azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none", "projection": "orthographic"}, "PREVIEW_CAMERA_MISMATCH", path)
    require({placement["assetId"] for placement in data["placements"]} == {asset["assetId"] for asset in CONFIG["assets"]}, "PREVIEW_ASSET_SET_MISMATCH", path)
    for placement in data["placements"]:
        require(placement["perAssetTransformCompensation"] == "none", "PREVIEW_PLACEMENT_COMPENSATION_FORBIDDEN", placement["assetId"])
        for axis in range(2):
            origin = float(placement["originWorld"][axis])
            footprint_world = float(placement["footprintTiles"][axis]) * 2.0
            minimum_edge = origin - footprint_world / 2.0
            require(abs(((minimum_edge - 1.0) / 2.0) - round((minimum_edge - 1.0) / 2.0)) < 1e-6, "PREVIEW_OFF_GRID_PLACEMENT", placement)
        source = BLENDER_ROOT / placement["sourceBlend"]
        require(source.is_file() and sha256(source) == placement["sourceBlendSha256"], "PREVIEW_SOURCE_DRIFT", source)
    dimensions, original_hashes = set(), {}
    for artifact in data["artifacts"]:
        artifact_path = HERE / artifact["path"]
        require(artifact_path.is_file() and sha256(artifact_path) == artifact["sha256"], "PREVIEW_ARTIFACT_DRIFT", artifact_path)
        if artifact_path.suffix == ".png":
            width, height, rgba = decode_rgba_png(artifact_path)
            dimensions.add((width, height))
            require(hashlib.sha256(rgba).hexdigest() == artifact["decodedRgbaSha256"], "PREVIEW_RGBA_HASH_DRIFT", artifact_path)
            original_hashes[artifact_path.name] = artifact["sha256"]
    require(dimensions == {(1280, 800), (900, 600)}, "PREVIEW_DIMENSIONS_MISMATCH", sorted(dimensions))
    rerenders = builder.build_preview(temp_root, save_blend=False)
    for rerender in rerenders:
        require(sha256(rerender) == original_hashes[rerender.name], "DETERMINISTIC_PREVIEW_MISMATCH", rerender.name)
    return original_hashes


def parse_report_path():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--report" not in args:
        return HERE / "validation" / "validator-output.txt"
    return Path(args[args.index("--report") + 1])


def main():
    actual = ".".join(map(str, bpy.app.version))
    require(actual == CONFIG["toolchain"]["blenderVersion"], "BLENDER_VERSION_MISMATCH", actual)
    results = {"schema": "citysim.world-art.services-variety-validation.v1", "status": "PASS", "blenderVersion": actual, "assets": {}}
    with tempfile.TemporaryDirectory(prefix="citysim-services-variety-determinism-") as temp_dir:
        temp_root = Path(temp_dir)
        for asset in CONFIG["assets"]:
            mesh_count, axes = validate_scene(asset)
            validate_manifest(asset)
            hashes = deterministic_asset_rerender(asset, temp_root)
            results["assets"][asset["assetId"]] = {"meshCount": mesh_count, "projectedAxisPixels": axes, "deterministicCanonicalPngSha256": hashes}
        results["previewPngSha256"] = validate_preview_manifest(temp_root)
    validate_preview_structure()
    results["contract"] = {
        "projectedTilePixels": [88, 44], "pivotPixels": [192, 300],
        "cameraOrder": [view["name"] for view in CONFIG["cameraRig"]["views"]],
        "postRenderCompensation": "none", "deterministicRerender": "byte-identical canonical PNGs",
        "deterministicPngCount": 17, "reopenedBlendStructuralValidation": "PASS",
    }
    report_path = parse_report_path()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = "SERVICES_VARIETY_VALIDATION_PASS\n" + json.dumps(results, indent=2, sort_keys=True) + "\n"
    report_path.write_text(report)
    print(report, end="")


if __name__ == "__main__":
    main()
