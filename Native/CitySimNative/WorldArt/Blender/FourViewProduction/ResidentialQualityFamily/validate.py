#!/usr/bin/env python3
"""Validate the residential quality family sources, rasters, and rerenders."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import sys
import tempfile
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
PRODUCTION = HERE.parent
BLENDER_ROOT = PRODUCTION.parent
CANONICAL = BLENDER_ROOT / "FourViewPipeline"
DENSITY_VALIDATOR = PRODUCTION / "Density" / "validate.py"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))
sys.path.insert(0, str(HERE))
from png_canonical import decode_rgba_png  # noqa: E402
import build_and_render as builder  # noqa: E402

CONFIG = json.loads((HERE / "pipeline.json").read_text(encoding="utf-8"))


def load_density_validator():
    spec = importlib.util.spec_from_file_location("citysim_quality_family_validator", DENSITY_VALIDATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError("DENSITY_VALIDATOR_IMPORT_FAILED")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.HERE = HERE
    module.BLENDER_ROOT = BLENDER_ROOT
    module.CONFIG = CONFIG
    module.builder = builder
    return module


validator = load_density_validator()


def require(condition, code, detail):
    if not condition:
        raise RuntimeError(f"{code}: {detail}")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def alpha_metadata(path):
    width, height, rgba = decode_rgba_png(path)
    alpha = rgba[3::4]
    occupied = [(index % width, index // width) for index, value in enumerate(alpha) if value]
    require(occupied, "EMPTY_ALPHA", path)
    xs = [point[0] for point in occupied]
    ys = [point[1] for point in occupied]
    pivot_x, pivot_y = CONFIG["canvas"]["footprintPivotPixel"]
    return {
        "boundsTopOrigin": {
            "minX": min(xs),
            "minY": min(ys),
            "maxX": max(xs),
            "maxY": max(ys),
            "width": max(xs) - min(xs) + 1,
            "height": max(ys) - min(ys) + 1,
        },
        "opaquePixelCount": len(occupied),
        "lowestOpaqueRowTopOrigin": max(ys),
        "pivotPixelAlpha": alpha[pivot_y * width + pivot_x],
    }


def validate_manifest(asset):
    output_dir = HERE / asset["assetId"]
    path = output_dir / "manifest.json"
    require(path.is_file(), "MISSING_MANIFEST", path)
    data = json.loads(path.read_text(encoding="utf-8"))
    require(data["schema"] == "citysim.world-art.residential-quality-asset.v1", "MANIFEST_SCHEMA_MISMATCH", path)
    require(data["assetId"] == asset["assetId"], "MANIFEST_IDENTITY_MISMATCH", path)
    require(data["assetFamily"] == asset["assetFamily"], "MANIFEST_FAMILY_MISMATCH", path)
    require(data["status"] == "quality-candidate-runtime-integrated" and data["liveAsset"] is True, "MANIFEST_STATUS_MISMATCH", path)
    require(data["originalGeometry"] is True and data["sourcePixelsReused"] is False, "MANIFEST_PROVENANCE_MISMATCH", path)
    require(data["quarantinedExpansionV1Reused"] is False, "QUARANTINED_BASELINE_REUSED", path)
    require(data["cameraOrder"] == [view["name"] for view in CONFIG["cameraRig"]["views"]], "CAMERA_ORDER_MISMATCH", path)
    require(data["postRenderCompensation"] == "none", "POST_RENDER_COMPENSATION_FORBIDDEN", path)
    require(data["perViewCompensation"] == {"crop": False, "offsetPixels": [0, 0], "rotationDegrees": 0.0, "scale": 1.0, "skew": [0.0, 0.0]}, "PER_VIEW_COMPENSATION_FORBIDDEN", path)

    expected_sources = {"build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py"}
    require({item["path"] for item in data["sourceFiles"]} == expected_sources, "SOURCE_FILE_SET_MISMATCH", path)
    for source in data["sourceFiles"]:
        source_path = HERE / source["path"]
        require(source_path.is_file() and sha256(source_path) == source["sha256"], "SOURCE_HASH_DRIFT", source_path)
    for dependency in data["dependencies"]:
        dependency_path = BLENDER_ROOT / dependency["path"]
        require(dependency_path.is_file() and sha256(dependency_path) == dependency["sha256"], "DEPENDENCY_HASH_DRIFT", dependency_path)

    render_hashes = {}
    render_masks = {}
    render_count = 0
    for artifact in data["artifacts"]:
        artifact_path = output_dir / artifact["path"]
        require(artifact_path.is_file(), "MISSING_ARTIFACT", artifact_path)
        require(artifact_path.stat().st_size == artifact["bytes"] and sha256(artifact_path) == artifact["sha256"], "ARTIFACT_HASH_DRIFT", artifact_path)
        if artifact_path.suffix.lower() != ".png":
            continue
        width, height, rgba = decode_rgba_png(artifact_path)
        require([width, height] == artifact["dimensions"], "PNG_DIMENSION_DRIFT", artifact_path)
        require(hashlib.sha256(rgba).hexdigest() == artifact["decodedRgbaSha256"], "RGBA_HASH_DRIFT", artifact_path)
        expected_size = (784, 840) if "contact-sheet" in artifact_path.name else (384, 384)
        require((width, height) == expected_size, "PNG_CANVAS_MISMATCH", f"{artifact_path}: {(width, height)}")
        alpha = rgba[3::4]
        require(any(alpha) and any(value == 0 for value in alpha), "ALPHA_POLICY_MISMATCH", artifact_path)
        if expected_size != (384, 384):
            continue
        render_count += 1
        actual_alpha = alpha_metadata(artifact_path)
        require(actual_alpha == artifact["alpha"], "ALPHA_METADATA_DRIFT", artifact_path)
        bounds = actual_alpha["boundsTopOrigin"]
        require(bounds["minX"] >= 2 and bounds["maxX"] <= 381 and bounds["minY"] >= 2, "CANVAS_CLIPPING", f"{artifact_path}: {bounds}")
        require(330 <= bounds["maxY"] <= 350, "GROUND_CONTACT_ROW_MISMATCH", f"{artifact_path}: {bounds['maxY']}")
        require(actual_alpha["pivotPixelAlpha"] > 0, "PIVOT_CONTACT_MISSING", artifact_path)
        require(bounds["width"] >= 110 and bounds["height"] >= 112, "SPRITE_READABILITY_BOUNDS_TOO_SMALL", f"{artifact_path}: {bounds}")
        render_hashes[artifact_path.name] = artifact["sha256"]
        render_masks[artifact_path.name] = frozenset(
            index for index, value in enumerate(alpha) if value and index // width < 286
        )
    require(render_count == 4, "FOUR_VIEW_RENDER_COUNT_MISMATCH", render_count)
    require(len(set(render_hashes.values())) == 4, "DUPLICATE_VIEW_RASTERS", asset["assetId"])
    return render_hashes, render_masks


def validate_family_manifest(asset_manifests):
    path = HERE / "family-manifest.json"
    require(path.is_file(), "MISSING_FAMILY_MANIFEST", path)
    data = json.loads(path.read_text(encoding="utf-8"))
    require(data["status"] == "quality-candidate-runtime-integrated", "FAMILY_STATUS_MISMATCH", path)
    require(data["originalGeometry"] is True and data["referencePixelsReused"] is False, "FAMILY_PROVENANCE_MISMATCH", path)
    require(data["quarantinedExpansionV1Reused"] is False, "FAMILY_QUARANTINE_MISMATCH", path)
    require(data["postRenderCompensation"] == "none", "FAMILY_COMPENSATION_FORBIDDEN", path)
    require(data["grid"]["projectedTilePixels"] == [88, 44], "FAMILY_GRID_MISMATCH", path)
    require(data["canvas"]["footprintPivotPixel"] == [192, 300], "FAMILY_PIVOT_MISMATCH", path)
    require({item["assetId"] for item in data["assets"]} == {asset["assetId"] for asset in CONFIG["assets"]}, "FAMILY_ASSET_SET_MISMATCH", path)
    for item in data["assets"]:
        manifest = HERE / item["manifest"]
        require(manifest in asset_manifests and sha256(manifest) == item["manifestSha256"], "FAMILY_MANIFEST_HASH_DRIFT", manifest)
        require(item["runtimeRole"] == "residential-low", "FAMILY_RUNTIME_ROLE_MISMATCH", item["assetId"])
    aggregate = data["aggregateContactSheet"]
    aggregate_path = HERE / aggregate["path"]
    require(aggregate_path.is_file() and sha256(aggregate_path) == aggregate["sha256"], "AGGREGATE_CONTACT_SHEET_DRIFT", aggregate_path)
    width, height, rgba = decode_rgba_png(aggregate_path)
    require((width, height) == (1782, 1606), "AGGREGATE_CONTACT_SHEET_SIZE_MISMATCH", (width, height))
    require(hashlib.sha256(rgba).hexdigest() == aggregate["decodedRgbaSha256"], "AGGREGATE_RGBA_HASH_DRIFT", aggregate_path)
    comparison = data["admittedBaselineComparison"]
    comparison_path = HERE / comparison["path"]
    require(comparison_path.is_file() and sha256(comparison_path) == comparison["sha256"], "BASELINE_COMPARISON_DRIFT", comparison_path)
    comparison_width, comparison_height, comparison_rgba = decode_rgba_png(comparison_path)
    require((comparison_width, comparison_height) == (2_574, 844), "BASELINE_COMPARISON_SIZE_MISMATCH", (comparison_width, comparison_height))
    require(hashlib.sha256(comparison_rgba).hexdigest() == comparison["decodedRgbaSha256"], "BASELINE_COMPARISON_RGBA_DRIFT", comparison_path)
    for source in data["sourceFiles"]:
        source_path = HERE / source["path"]
        require(source_path.is_file() and sha256(source_path) == source["sha256"], "FAMILY_SOURCE_HASH_DRIFT", source_path)
    return aggregate_path


def deterministic_rerender(asset, temp_root):
    scene, _, cameras = builder.build_asset(asset)
    rerenders = builder.render_views(scene, cameras, asset["assetId"], temp_root / asset["assetId"])
    hashes = {}
    for rerender in rerenders:
        original = HERE / asset["assetId"] / "renders" / rerender.name
        require(sha256(rerender) == sha256(original), "DETERMINISTIC_RERENDER_MISMATCH", rerender.name)
        hashes[rerender.name] = sha256(rerender)
    return hashes


def validate_distinct_silhouettes(cam_ne_masks):
    pairwise = {}
    asset_ids = list(cam_ne_masks)
    for left_index, left_id in enumerate(asset_ids):
        for right_id in asset_ids[left_index + 1:]:
            left = cam_ne_masks[left_id]
            right = cam_ne_masks[right_id]
            union = left | right
            iou = len(left & right) / max(1, len(union))
            pairwise[f"{left_id}__{right_id}"] = round(iou, 4)
            require(iou < 0.90, "RESIDENTIAL_SILHOUETTES_TOO_SIMILAR", f"{left_id} vs {right_id}: {iou:.4f}")
    return pairwise


def parse_report_path():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--report" not in args:
        return HERE / "validation" / "validator-output.txt"
    return Path(args[args.index("--report") + 1])


def main():
    actual = ".".join(map(str, bpy.app.version))
    require(actual == CONFIG["toolchain"]["blenderVersion"], "BLENDER_VERSION_MISMATCH", actual)
    results = {
        "schema": "citysim.world-art.residential-quality-validation.v1",
        "status": "PASS",
        "blenderVersion": actual,
        "assets": {},
    }
    asset_manifests = []
    cam_ne_masks = {}
    with tempfile.TemporaryDirectory(prefix="citysim-residential-quality-") as temp_dir:
        temp_root = Path(temp_dir)
        for asset in CONFIG["assets"]:
            mesh_count, bounds, axes = validator.validate_scene(asset)
            source_path = HERE / asset["assetId"] / f"{asset['assetId']}.blend"
            bpy.ops.wm.open_mainfile(filepath=str(source_path))
            root = bpy.data.objects["AssetRoot"]
            require(root.get("liveAsset") is True and root.get("qualityCandidate") is True, "SOURCE_STATUS_MISMATCH", asset["assetId"])
            require(root.get("quarantinedExpansionV1Reused") is False, "SOURCE_QUARANTINE_MISMATCH", asset["assetId"])
            material_count = len(bpy.data.materials)
            require(material_count >= 12, "MATERIAL_DIFFERENTIATION_TOO_LOW", f"{asset['assetId']}: {material_count}")
            manifest_hashes, masks = validate_manifest(asset)
            rerender_hashes = deterministic_rerender(asset, temp_root)
            require(manifest_hashes == rerender_hashes, "MANIFEST_RERENDER_HASH_SET_MISMATCH", asset["assetId"])
            cam_ne_masks[asset["assetId"]] = masks[f"{asset['assetId']}_camNE.png"]
            asset_manifests.append(HERE / asset["assetId"] / "manifest.json")
            results["assets"][asset["assetId"]] = {
                "meshCount": mesh_count,
                "materialCount": material_count,
                "worldBounds": bounds,
                "projectedAxisPixels": axes,
                "deterministicCanonicalPngSha256": rerender_hashes,
            }
        results["pairwiseCamNESilhouetteIoUAboveGround"] = validate_distinct_silhouettes(cam_ne_masks)
    aggregate_path = validate_family_manifest(asset_manifests)
    results["aggregateContactSheet"] = {
        "path": aggregate_path.relative_to(HERE).as_posix(),
        "sha256": sha256(aggregate_path),
    }
    results["contract"] = {
        "projectedTilePixels": [88, 44],
        "pivotPixels": [192, 300],
        "cameraOrder": [view["name"] for view in CONFIG["cameraRig"]["views"]],
        "postRenderCompensation": "none",
        "deterministicRerender": "byte-identical canonical PNGs",
        "quarantinedExpansionV1Reused": False,
    }
    report_path = parse_report_path()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = "RESIDENTIAL_QUALITY_FAMILY_VALIDATION_PASS\n" + json.dumps(results, indent=2, sort_keys=True) + "\n"
    report_path.write_text(report, encoding="utf-8")
    print(report, end="")


if __name__ == "__main__":
    main()
