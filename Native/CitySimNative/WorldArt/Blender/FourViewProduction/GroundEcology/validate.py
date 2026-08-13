#!/usr/bin/env python3
"""Independently validate Greenworks Nursery sources and byte-identical renders."""

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
from png_canonical import canonicalize_png, decode_rgba_png  # noqa: E402

CONFIG = json.loads((HERE / "pipeline.json").read_text())
VIEWS = CONFIG["cameraRig"]["views"]


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


def object_bounds(obj):
    vertices = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    return {
        "minX": min(vertex.x for vertex in vertices), "maxX": max(vertex.x for vertex in vertices),
        "minY": min(vertex.y for vertex in vertices), "maxY": max(vertex.y for vertex in vertices),
        "minZ": min(vertex.z for vertex in vertices), "maxZ": max(vertex.z for vertex in vertices),
    }


def projected_pixel(scene, camera, point):
    projected = world_to_camera_view(scene, camera, Vector(point))
    return Vector((projected.x * 384, (1.0 - projected.y) * 384))


def validate_camera_contract(scene):
    cameras = [obj for obj in bpy.data.objects if obj.type == "CAMERA"]
    expected_names = [view["name"] for view in VIEWS]
    require(sorted(obj.name for obj in cameras) == sorted(expected_names), "CAMERA_SET_MISMATCH", [obj.name for obj in cameras])
    signatures = {}
    for view in VIEWS:
        camera = bpy.data.objects[view["name"]]
        require(camera.data.type == "ORTHO", "CAMERA_NOT_ORTHO", camera.name)
        close(camera.data.ortho_scale, 12.341995, 1e-6, camera.name + ".orthoScale")
        close(camera.data.shift_y, 0.28125, 1e-6, camera.name + ".shiftY")
        origin = projected_pixel(scene, camera, (0, 0, 0))
        vector(origin, (192, 300), 0.01, camera.name + ".pivotTopOrigin")
        horizontal = math.hypot(camera.location.x, camera.location.y)
        close(math.degrees(math.atan2(camera.location.z, horizontal)), 30.0, 0.0001, camera.name + ".elevation")
        close(math.degrees(math.atan2(camera.location.x, camera.location.y)) % 360, view["azimuthDegrees"], 0.0001, camera.name + ".azimuth")
        x_axis = projected_pixel(scene, camera, (2, 0, 0)) - origin
        y_axis = projected_pixel(scene, camera, (0, 2, 0)) - origin
        vector((abs(x_axis.x), abs(x_axis.y)), (44, 22), 0.01, camera.name + ".worldXAxisPixels")
        vector((abs(y_axis.x), abs(y_axis.y)), (44, 22), 0.01, camera.name + ".worldYAxisPixels")
        corners = [projected_pixel(scene, camera, point) for point in ((-1, -1, 0), (1, -1, 0), (1, 1, 0), (-1, 1, 0))]
        width = max(point.x for point in corners) - min(point.x for point in corners)
        height = max(point.y for point in corners) - min(point.y for point in corners)
        vector((width, height), (88, 44), 0.01, camera.name + ".projectedWorldCell")
        signatures[camera.name] = [[round(x_axis.x), round(x_axis.y)], [round(y_axis.x), round(y_axis.y)]]
    require(len({str(signature) for signature in signatures.values()}) == 4, "VIEW_ORIENTATIONS_NOT_UNIQUE", signatures)
    return signatures


def validate_key_light():
    lights = [obj for obj in bpy.data.objects if obj.type == "LIGHT"]
    require(len(lights) == 1 and lights[0].name == "CitySimKey", "LIGHT_SET_MISMATCH", [obj.name for obj in lights])
    light = lights[0]
    vector(light.location, CONFIG["lighting"]["location"], 1e-6, "CitySimKey.location")
    close(light.data.energy, CONFIG["lighting"]["energy"], 1e-6, "CitySimKey.energy")
    close(light.data.size, CONFIG["lighting"]["size"], 1e-6, "CitySimKey.size")
    vector(light.data.color, CONFIG["lighting"]["color"], 1e-6, "CitySimKey.color")


def validate_asset_scene(asset):
    asset_id = asset["assetId"]
    path = HERE / asset_id / f"{asset_id}.blend"
    require(path.is_file(), "MISSING_BLEND", path)
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    require(scene.render.engine == CONFIG["toolchain"]["renderEngine"], "ENGINE_MISMATCH", asset_id)
    require((scene.render.resolution_x, scene.render.resolution_y) == (384, 384), "CANVAS_MISMATCH", asset_id)
    require(scene.render.film_transparent, "TRANSPARENT_CANVAS_REQUIRED", asset_id)
    require(scene.get("postRenderCompensation") == "none", "SCENE_COMPENSATION_FORBIDDEN", asset_id)
    root = bpy.data.objects.get("AssetRoot")
    pivot = bpy.data.objects.get("FootprintPivot")
    require(root is not None and pivot is not None, "MISSING_ROOT_OR_PIVOT", asset_id)
    vector(root.location, (0, 0, 0), 1e-7, asset_id + ".root.location")
    vector(root.rotation_euler, (0, 0, 0), 1e-7, asset_id + ".root.rotation")
    vector(root.scale, (1, 1, 1), 1e-7, asset_id + ".root.scale")
    vector(pivot.location, (0, 0, 0), 1e-7, asset_id + ".pivot.location")
    require(pivot.parent == root, "PIVOT_PARENT_MISMATCH", asset_id)
    require(root.get("assetId") == asset_id and root.get("assetKind") == asset["assetKind"], "ROOT_IDENTITY_MISMATCH", asset_id)
    require(root.get("originalGeometry") is True and root.get("billboardGeometry") is False, "MODELING_PROVENANCE_MISMATCH", asset_id)
    require(root.get("sourcePixelsReused") is False and root.get("cedarMarketReused") is False and root.get("rejectedVectorAssetsReused") is False, "SOURCE_PROVENANCE_MISMATCH", asset_id)
    require(root.get("postRenderCompensation") == "none" and root.get("perAssetTransformCompensation") == "none", "ROOT_COMPENSATION_FORBIDDEN", asset_id)

    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    minimum_meshes = 9 if asset["assetKind"] == "ground-treatment" else 8
    require(len(meshes) >= minimum_meshes, "GEOMETRY_TOO_SIMPLE", f"{asset_id}: {len(meshes)}")
    for obj in meshes:
        require(obj.parent == root, "MESH_OUTSIDE_ASSET_ROOT", obj.name)
        vector(obj.scale, (1, 1, 1), 1e-6, obj.name + ".scale")
        vector(obj.rotation_euler, (0, 0, 0), 1e-6, obj.name + ".rotation")
        bounds = object_bounds(obj)
        require(bounds["maxZ"] - bounds["minZ"] > 0.002, "FLAT_OR_BILLBOARD_MESH", obj.name)

    geometry = {}
    if asset["assetKind"] == "ground-treatment":
        cell = bpy.data.objects.get("ExactGroundCell")
        require(cell is not None, "MISSING_EXACT_GROUND_CELL", asset_id)
        bounds = object_bounds(cell)
        vector((bounds["minX"], bounds["maxX"], bounds["minY"], bounds["maxY"], bounds["minZ"], bounds["maxZ"]), (-1, 1, -1, 1, -0.1, 0), 1e-6, asset_id + ".exactCellBounds")
        require(list(cell.get("exactCellBounds")) == [-1.0, 1.0, -1.0, 1.0], "CELL_METADATA_MISMATCH", asset_id)
        require(cell.get("edgeAlignment") == "world-x-y" and cell.get("arbitraryPad") is False, "GROUND_ALIGNMENT_MISMATCH", asset_id)
        for obj in meshes:
            bounds = object_bounds(obj)
            require(bounds["minX"] >= -1.000001 and bounds["maxX"] <= 1.000001 and bounds["minY"] >= -1.000001 and bounds["maxY"] <= 1.000001, "GROUND_DECORATION_OUTSIDE_CELL", obj.name)
        geometry["exactGroundCellBounds"] = bounds
    else:
        contact = bpy.data.objects.get("GroundContact")
        require(contact is not None, "MISSING_VEGETATION_GROUND_CONTACT", asset_id)
        bounds = object_bounds(contact)
        close(bounds["minZ"], 0.0, 1e-6, asset_id + ".groundContactZ")
        require(bounds["minX"] <= 0 <= bounds["maxX"] and bounds["minY"] <= 0 <= bounds["maxY"], "PIVOT_NOT_INSIDE_GROUND_CONTACT", asset_id)
        require(contact.get("groundContactZ") == 0.0 and list(contact.get("pivotXY")) == [0.0, 0.0], "GROUND_CONTACT_METADATA_MISMATCH", asset_id)
        family_bounds = [object_bounds(obj) for obj in meshes]
        require(max(item["maxZ"] for item in family_bounds) >= 0.45, "VEGETATION_DEPTH_UNREADABLE", asset_id)
        geometry["groundContactBounds"] = bounds
        geometry["modeledHeight"] = max(item["maxZ"] for item in family_bounds)

    validate_key_light()
    axes = validate_camera_contract(scene)
    return {"meshCount": len(meshes), "geometry": geometry, "projectedAxisPixels": axes}


def validate_png_artifact(path, artifact, expected_dimensions, canonical_view=False):
    require(path.is_file(), "MISSING_ARTIFACT", path)
    require(path.stat().st_size == artifact["bytes"] and sha256(path) == artifact["sha256"], "ARTIFACT_HASH_DRIFT", path)
    width, height, rgba = decode_rgba_png(path)
    require((width, height) == expected_dimensions and artifact["dimensions"] == [width, height], "PNG_DIMENSION_MISMATCH", path)
    require(hashlib.sha256(rgba).hexdigest() == artifact["decodedRgbaSha256"], "RGBA_HASH_DRIFT", path)
    alpha = rgba[3::4]
    require(any(alpha), "EMPTY_ALPHA", path)
    if canonical_view:
        require(any(value == 0 for value in alpha), "CANONICAL_BACKGROUND_NOT_TRANSPARENT", path)
        pivot_x, pivot_y = CONFIG["canvas"]["footprintPivotPixelTopOrigin"]
        require(rgba[(pivot_y * width + pivot_x) * 4 + 3] > 0, "PIVOT_PIXEL_HAS_NO_GROUND_CONTACT", path)


def validate_asset_manifest(asset):
    asset_dir = HERE / asset["assetId"]
    path = asset_dir / "manifest.json"
    require(path.is_file(), "MISSING_ASSET_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["assetId"] == asset["assetId"] and data["assetKind"] == asset["assetKind"], "MANIFEST_IDENTITY_MISMATCH", path)
    require(data["status"] == "source-only-not-live" and data["liveAsset"] is False, "MANIFEST_STATUS_MISMATCH", path)
    require(data["originalGeometry"] is True and data["billboardGeometry"] is False, "MANIFEST_MODELING_PROVENANCE_MISMATCH", path)
    require(data["sourcePixelsReused"] is False and data["cedarMarketReused"] is False and data["rejectedVectorAssetsReused"] is False, "MANIFEST_SOURCE_PROVENANCE_MISMATCH", path)
    require(data["postRenderCompensation"] == "none", "MANIFEST_COMPENSATION_FORBIDDEN", path)
    require(data["perAssetCompensation"] == {"crop": False, "offsetPixels": [0, 0], "rotationDegrees": 0.0, "scale": 1.0, "skew": [0.0, 0.0]}, "PER_ASSET_COMPENSATION_FORBIDDEN", path)
    render_names = {f"{asset['assetId']}_{view['name']}.png" for view in VIEWS}
    seen_renders = set()
    for artifact in data["artifacts"]:
        artifact_path = asset_dir / artifact["path"]
        if artifact_path.suffix != ".png":
            require(artifact_path.is_file() and artifact_path.stat().st_size == artifact["bytes"] and sha256(artifact_path) == artifact["sha256"], "ARTIFACT_HASH_DRIFT", artifact_path)
            continue
        is_contact = "contact-sheet" in artifact_path.name
        dimensions = (784, 840) if is_contact else (384, 384)
        validate_png_artifact(artifact_path, artifact, dimensions, canonical_view=not is_contact)
        if not is_contact:
            seen_renders.add(artifact_path.name)
    require(seen_renders == render_names, "FOUR_VIEW_RENDER_SET_MISMATCH", sorted(seen_renders))
    if asset["assetKind"] == "ground-treatment":
        require(data["groundContract"] == {"arbitraryPad": False, "edgeAlignment": "world-x-y", "exactWorldBoundsXY": [-1.0, 1.0, -1.0, 1.0]}, "GROUND_MANIFEST_CONTRACT_MISMATCH", path)
    else:
        require(data["vegetationContract"] == {"billboard": False, "groundContactZ": 0.0, "modeled3D": True, "pivotWorld": [0.0, 0.0, 0.0]}, "VEGETATION_MANIFEST_CONTRACT_MISMATCH", path)


def rerender_asset_from_blend(asset, temp_root):
    asset_id = asset["assetId"]
    bpy.ops.wm.open_mainfile(filepath=str(HERE / asset_id / f"{asset_id}.blend"))
    scene = bpy.context.scene
    output_dir = temp_root / asset_id
    output_dir.mkdir(parents=True, exist_ok=True)
    hashes = {}
    for view in VIEWS:
        output = output_dir / f"{asset_id}_{view['name']}.png"
        scene.camera = bpy.data.objects[view["name"]]
        scene.render.resolution_x = 384
        scene.render.resolution_y = 384
        scene.render.filepath = str(output)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(output)
        original = HERE / asset_id / "renders" / output.name
        require(output.read_bytes() == original.read_bytes(), "DETERMINISTIC_CANONICAL_RERENDER_MISMATCH", output.name)
        hashes[output.name] = sha256(output)
    return hashes


def validate_preview_scene_and_manifest(temp_root):
    preview_dir = HERE / "preview"
    manifest_path = preview_dir / "manifest.json"
    require(manifest_path.is_file(), "MISSING_PREVIEW_MANIFEST", manifest_path)
    data = json.loads(manifest_path.read_text())
    require(data["singleGrid"] is True and data["gridSpacingWorld"] == 2.0, "PREVIEW_SINGLE_GRID_MISMATCH", manifest_path)
    require(data["perAssetTransformCompensation"] == "none", "PREVIEW_COMPENSATION_FORBIDDEN", manifest_path)
    require(data["originalGeometry"] is True and data["sourcePixelsReused"] is False and data["cedarMarketReused"] is False, "PREVIEW_PROVENANCE_MISMATCH", manifest_path)
    blend_path = preview_dir / "greenworks-neighborhood-ground.blend"
    bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    scene = bpy.context.scene
    require(scene.get("singleGrid") is True and scene.get("gridSpacingWorld") == 2.0, "PREVIEW_SCENE_GRID_MISMATCH", blend_path)
    require(scene.get("perAssetTransformCompensation") == "none", "PREVIEW_SCENE_COMPENSATION_FORBIDDEN", blend_path)
    preview_root = bpy.data.objects.get("PreviewRoot")
    require(preview_root is not None, "MISSING_PREVIEW_ROOT", blend_path)
    vector(preview_root.location, (0, 0, 0), 1e-7, "PreviewRoot.location")
    vector(preview_root.rotation_euler, (0, 0, 0), 1e-7, "PreviewRoot.rotation")
    vector(preview_root.scale, (1, 1, 1), 1e-7, "PreviewRoot.scale")
    cameras = [obj for obj in bpy.data.objects if obj.type == "CAMERA"]
    require(len(cameras) == 1 and cameras[0].name == "DistrictPreviewCamera" and cameras[0].data.type == "ORTHO", "PREVIEW_CAMERA_SET_MISMATCH", [obj.name for obj in cameras])
    horizontal = math.hypot(cameras[0].location.x, cameras[0].location.y)
    close(math.degrees(math.atan2(cameras[0].location.z, horizontal)), 30.0, 0.0001, "preview.elevation")
    close(math.degrees(math.atan2(cameras[0].location.x, cameras[0].location.y)) % 360, 45.0, 0.0001, "preview.azimuth")
    validate_key_light()
    expected_assets = {asset["assetId"] for asset in CONFIG["assets"]}
    placements = {obj.name.removeprefix("Placement_"): obj for obj in bpy.data.objects if obj.name.startswith("Placement_")}
    require(set(placements) == expected_assets, "PREVIEW_ASSET_SET_MISMATCH", sorted(placements))
    manifest_placements = {item["assetId"]: item for item in data["placements"]}
    require(set(manifest_placements) == expected_assets, "PREVIEW_MANIFEST_ASSET_SET_MISMATCH", sorted(manifest_placements))
    for asset_id, placement in placements.items():
        vector(placement.rotation_euler, (0, 0, 0), 1e-7, placement.name + ".rotation")
        vector(placement.scale, (1, 1, 1), 1e-7, placement.name + ".scale")
        require(placement.get("perAssetTransformCompensation") == "none", "PREVIEW_PLACEMENT_COMPENSATION_FORBIDDEN", asset_id)
        close((placement.location.x - 1.0) / 2.0, round((placement.location.x - 1.0) / 2.0), 1e-7, placement.name + ".gridX")
        close((placement.location.y - 1.0) / 2.0, round((placement.location.y - 1.0) / 2.0), 1e-7, placement.name + ".gridY")
        item = manifest_placements[asset_id]
        vector(placement.location, item["originWorld"], 1e-7, placement.name + ".manifestLocation")
        source = HERE.parents[1] / item["sourceBlend"]
        require(source.is_file() and sha256(source) == item["sourceBlendSha256"], "PREVIEW_SOURCE_HASH_DRIFT", source)
        require(item["rotationEuler"] == [0.0, 0.0, 0.0] and item["scale"] == [1.0, 1.0, 1.0] and item["perAssetTransformCompensation"] == "none", "PREVIEW_MANIFEST_TRANSFORM_MISMATCH", asset_id)

    manifest_artifacts = {Path(item["path"]).name: item for item in data["artifacts"]}
    expected_pngs = {f"greenworks-neighborhood-ground-{width}x{height}.png": (width, height) for width, height in CONFIG["preview"]["dimensions"]}
    for name, dimensions in expected_pngs.items():
        path = preview_dir / name
        require(name in manifest_artifacts, "PREVIEW_ARTIFACT_NOT_MANIFESTED", name)
        validate_png_artifact(path, manifest_artifacts[name], dimensions)
    blend_artifact = manifest_artifacts.get(blend_path.name)
    require(blend_artifact is not None and sha256(blend_path) == blend_artifact["sha256"] and blend_path.stat().st_size == blend_artifact["bytes"], "PREVIEW_BLEND_HASH_DRIFT", blend_path)

    rerender_hashes = {}
    for width, height in CONFIG["preview"]["dimensions"]:
        output = temp_root / f"greenworks-neighborhood-ground-{width}x{height}.png"
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        scene.render.filepath = str(output)
        bpy.ops.render.render(write_still=True)
        canonicalize_png(output)
        original = preview_dir / output.name
        require(output.read_bytes() == original.read_bytes(), "DETERMINISTIC_PREVIEW_RERENDER_MISMATCH", output.name)
        rerender_hashes[output.name] = sha256(output)
    return rerender_hashes


def validate_family_manifest():
    path = HERE / "family-manifest.json"
    require(path.is_file(), "MISSING_FAMILY_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["familyId"] == "greenworks-nursery-ground-ecology", "FAMILY_ID_MISMATCH", path)
    require(data["assetCount"] == 7 and data["canonicalViewCount"] == 28 and data["previewCount"] == 2, "FAMILY_COUNT_MISMATCH", path)
    require(data["status"] == "source-only-not-live", "FAMILY_STATUS_MISMATCH", path)
    provenance = data["provenance"]
    require(provenance["originalGeometry"] is True and provenance["sourcePixelsReused"] is False and provenance["cedarMarketReused"] is False and provenance["rejectedVectorAssetsReused"] is False, "FAMILY_PROVENANCE_MISMATCH", path)
    entries = data["members"] + [data["previewManifest"]] + data["sourceArtifacts"]
    for entry in entries:
        artifact = entry["manifest"] if "manifest" in entry else entry
        artifact_path = HERE / artifact["path"]
        require(artifact_path.is_file() and artifact_path.stat().st_size == artifact["bytes"] and sha256(artifact_path) == artifact["sha256"], "FAMILY_ARTIFACT_HASH_DRIFT", artifact_path)
    return sha256(path)


def parse_report_path():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if "--report" not in args:
        return HERE / "validation" / "validator-output.txt"
    return Path(args[args.index("--report") + 1])


def main():
    actual = ".".join(map(str, bpy.app.version))
    require(actual == CONFIG["toolchain"]["blenderVersion"], "BLENDER_VERSION_MISMATCH", actual)
    results = {
        "schema": "citysim.world-art.ground-ecology-validation.v1",
        "status": "PASS",
        "blenderVersion": actual,
        "assets": {},
    }
    with tempfile.TemporaryDirectory(prefix="citysim-ground-ecology-determinism-") as temp_dir:
        temp_root = Path(temp_dir)
        for asset in CONFIG["assets"]:
            inspection = validate_asset_scene(asset)
            validate_asset_manifest(asset)
            inspection["deterministicCanonicalPngSha256"] = rerender_asset_from_blend(asset, temp_root)
            results["assets"][asset["assetId"]] = inspection
        results["deterministicPreviewPngSha256"] = validate_preview_scene_and_manifest(temp_root)
    results["familyManifestSha256"] = validate_family_manifest()
    results["contract"] = {
        "projection": "orthographic-2:1-dimetric",
        "cameraOrder": [view["name"] for view in VIEWS],
        "azimuthDegrees": 45.0,
        "elevationDegrees": 30.0,
        "projectedWorldCellPixels": [88, 44],
        "pivotPixelTopOrigin": [192, 300],
        "orthoScale": 12.341995,
        "shiftY": 0.28125,
        "postRenderCompensation": "none",
        "canonicalRerenders": 28,
        "previewRerenders": 2,
        "determinism": "byte-identical canonical PNG files",
    }
    report_path = parse_report_path()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = "GROUND_ECOLOGY_FOUR_VIEW_VALIDATION_PASS\n" + json.dumps(results, indent=2, sort_keys=True) + "\n"
    report_path.write_text(report)
    print(report, end="")


if __name__ == "__main__":
    main()
