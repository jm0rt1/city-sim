#!/usr/bin/env python3
"""Independently validate Canal Lantern park and clean-rerender determinism."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
PRODUCTION = HERE.parent
SERVICES_VALIDATOR = PRODUCTION / "Services" / "validate.py"
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE))
import build_and_render as builder  # noqa: E402


spec = importlib.util.spec_from_file_location("citysim_park_validator", SERVICES_VALIDATOR)
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)
CONFIG = json.loads((HERE / "pipeline.json").read_text())
common.HERE = HERE
common.CONFIG = CONFIG
common.builder = builder


def require(condition, code, detail):
    if not condition:
        raise RuntimeError(f"{code}: {detail}")


def validate_park_geometry(asset):
    root = bpy.data.objects.get("AssetRoot")
    require(root is not None, "MISSING_ASSET_ROOT", asset["assetId"])
    require(root.get("parkRole") == asset["parkRole"], "PARK_ROLE_MISMATCH", asset["assetId"])
    require(root.get("assetKind") == "park", "ASSET_KIND_MISMATCH", asset["assetId"])
    require(root.get("rejectedVectorAssetsReused") is False, "REJECTED_VECTOR_PROVENANCE_MISMATCH", asset["assetId"])
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    require(len(meshes) >= asset["minimumMeshCount"], "GEOMETRY_TOO_SIMPLE", f"{asset['assetId']}: {len(meshes)}")
    for prefix in asset["requiredObjectPrefixes"]:
        require(any(obj.name.startswith(prefix) for obj in meshes), "REQUIRED_GEOMETRY_MISSING", f"{asset['assetId']}: {prefix}")


def validate_family_manifest():
    path = HERE / "family-manifest.json"
    require(path.is_file(), "MISSING_FAMILY_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["assetIds"] == [asset["assetId"] for asset in CONFIG["assets"]], "FAMILY_ASSET_SET_MISMATCH", data.get("assetIds"))
    require(data["projectedTilePixels"] == [88, 44], "FAMILY_GRID_MISMATCH", data.get("projectedTilePixels"))
    require(data["pivotPixelTopOrigin"] == [192, 300], "FAMILY_PIVOT_MISMATCH", data.get("pivotPixelTopOrigin"))
    require(data["postRenderCompensation"] == "none", "FAMILY_COMPENSATION_FORBIDDEN", path)
    require(data["cedarMarketReused"] is False, "FAMILY_PROVENANCE_MISMATCH", path)
    for artifact in data["artifacts"]:
        artifact_path = HERE / artifact["path"]
        require(artifact_path.is_file(), "FAMILY_ARTIFACT_MISSING", artifact_path)
        require(common.sha256(artifact_path) == artifact["sha256"], "FAMILY_ARTIFACT_DRIFT", artifact_path)
    return common.sha256(path)


def validate_preview():
    path = HERE / "preview" / "manifest.json"
    require(path.is_file(), "MISSING_PREVIEW_MANIFEST", path)
    data = json.loads(path.read_text())
    require(data["acceptedFamilyContractOnly"] is True, "PREVIEW_FAMILY_POLICY_MISMATCH", path)
    require(data["cedarMarketReused"] is False and data["rejectedVectorAssetsReused"] is False, "PREVIEW_PROVENANCE_MISMATCH", path)
    require(data["camera"] == {"azimuthDegrees": 45.0, "elevationDegrees": 30.0, "perAssetCompensation": "none", "projection": "orthographic"}, "PREVIEW_CAMERA_MISMATCH", path)
    require({placement["assetId"] for placement in data["placements"]} == {"canal_lantern_park", "pocket_grove_park"}, "PREVIEW_ASSET_SET_MISMATCH", path)
    blender_root = HERE.parents[1]
    for placement in data["placements"]:
        require(placement["perAssetTransformCompensation"] == "none", "PREVIEW_PLACEMENT_COMPENSATION_FORBIDDEN", placement["assetId"])
        for axis in range(2):
            origin = float(placement["originWorld"][axis])
            footprint_world = float(placement["footprintTiles"][axis]) * 2.0
            minimum_edge = origin - footprint_world / 2.0
            require(abs(((minimum_edge - 1.0) / 2.0) - round((minimum_edge - 1.0) / 2.0)) < 1e-6, "PREVIEW_OFF_GRID_PLACEMENT", placement)
        source = blender_root / placement["sourceBlend"]
        require(source.is_file() and common.sha256(source) == placement["sourceBlendSha256"], "PREVIEW_SOURCE_DRIFT", source)
    dimensions = set()
    hashes = {}
    for artifact in data["artifacts"]:
        artifact_path = HERE / artifact["path"]
        require(artifact_path.is_file() and common.sha256(artifact_path) == artifact["sha256"], "PREVIEW_ARTIFACT_DRIFT", artifact_path)
        if artifact_path.suffix == ".png":
            width, height, rgba = common.decode_rgba_png(artifact_path)
            dimensions.add((width, height))
            require(hashlib.sha256(rgba).hexdigest() == artifact["decodedRgbaSha256"], "PREVIEW_RGBA_HASH_DRIFT", artifact_path)
            hashes[artifact["path"]] = artifact["sha256"]
    require(dimensions == {(1280, 800), (900, 600)}, "PREVIEW_DIMENSIONS_MISMATCH", sorted(dimensions))
    return hashes


def parse_report_path():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if "--report" not in args:
        return HERE / "validation" / "validator-output.txt"
    return Path(args[args.index("--report") + 1])


def main():
    actual = ".".join(map(str, bpy.app.version))
    require(actual == CONFIG["toolchain"]["blenderVersion"], "BLENDER_VERSION_MISMATCH", actual)
    results = {
        "schema": "citysim.world-art.park-expansion-validation.v1",
        "status": "PASS",
        "blenderVersion": actual,
        "assets": {},
    }
    with tempfile.TemporaryDirectory(prefix="citysim-park-expansion-determinism-") as temp_dir:
        temp_root = Path(temp_dir)
        for asset in CONFIG["assets"]:
            mesh_count, axes = common.validate_scene(asset)
            validate_park_geometry(asset)
            common.validate_manifest(asset)
            render_hashes = common.deterministic_rerender(asset, temp_root)
            results["assets"][asset["assetId"]] = {
                "meshCount": mesh_count,
                "requiredObjectPrefixes": asset["requiredObjectPrefixes"],
                "projectedAxisPixels": axes,
                "deterministicCanonicalPngSha256": render_hashes,
            }
    results["familyManifestSha256"] = validate_family_manifest()
    results["previewPngSha256"] = validate_preview()
    results["contract"] = {
        "projectedTilePixels": [88, 44],
        "pivotPixels": [192, 300],
        "cameraOrder": [view["name"] for view in CONFIG["cameraRig"]["views"]],
        "azimuthDegrees": 45.0,
        "elevationDegrees": 30.0,
        "orthoScale": 12.341995,
        "shiftY": 0.28125,
        "postRenderCompensation": "none",
        "deterministicRerender": "byte-identical canonical PNGs",
    }
    report_path = parse_report_path()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = "PARK_EXPANSION_FOUR_VIEW_VALIDATION_PASS\n" + json.dumps(results, indent=2, sort_keys=True) + "\n"
    report_path.write_text(report)
    print(report, end="")


if __name__ == "__main__":
    main()
