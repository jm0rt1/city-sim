#!/usr/bin/env python3
"""Validate CitySim NeighborhoodVariety sources and deterministic renders."""

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
BLENDER_ROOT = PRODUCTION.parent
DENSITY_VALIDATOR = PRODUCTION / "Density" / "validate.py"
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE))
import build_and_render as builder  # noqa: E402

CONFIG = json.loads((HERE / "pipeline.json").read_text(encoding="utf-8"))


def load_density_validator():
    spec = importlib.util.spec_from_file_location("citysim_density_validator", DENSITY_VALIDATOR)
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


def validate_family_manifest():
    path = HERE / "family-manifest.json"
    require(path.is_file(), "MISSING_FAMILY_MANIFEST", path)
    data = json.loads(path.read_text(encoding="utf-8"))
    require(data["status"] == "source-only-not-live", "FAMILY_STATUS_MISMATCH", path)
    require(data["approvedLiveFamilyIsBaseline"] is True, "BASELINE_POLICY_MISMATCH", path)
    require(data["originalGeometry"] is True and data["cedarMarketReused"] is False, "FAMILY_PROVENANCE_MISMATCH", path)
    require(data["postRenderCompensation"] == "none", "FAMILY_COMPENSATION_FORBIDDEN", path)
    require(data["grid"]["projectedTilePixels"] == [88, 44], "FAMILY_GRID_MISMATCH", path)
    require(data["canvas"]["footprintPivotPixel"] == [192, 300], "FAMILY_PIVOT_MISMATCH", path)
    expected = {asset["assetId"] for asset in CONFIG["assets"]}
    require({asset["assetId"] for asset in data["assets"]} == expected, "FAMILY_ASSET_SET_MISMATCH", path)
    for asset in data["assets"]:
        manifest = HERE / asset["assetId"] / "manifest.json"
        require(manifest.is_file() and sha256(manifest) == asset["manifestSha256"], "ASSET_MANIFEST_HASH_DRIFT", manifest)
    for source in data["sourceFiles"]:
        source_path = HERE / source["path"]
        require(source_path.is_file() and sha256(source_path) == source["sha256"], "FAMILY_SOURCE_HASH_DRIFT", source_path)


def parse_report_path():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if "--report" not in args:
        return HERE / "validation" / "validator-output.txt"
    return Path(args[args.index("--report") + 1])


def main():
    actual = ".".join(map(str, bpy.app.version))
    require(actual == CONFIG["toolchain"]["blenderVersion"], "BLENDER_VERSION_MISMATCH", actual)
    results = {
        "schema": "citysim.world-art.neighborhood-variety-validation.v1",
        "status": "PASS",
        "blenderVersion": actual,
        "assets": {},
    }
    with tempfile.TemporaryDirectory(prefix="citysim-neighborhood-variety-") as temp_dir:
        temp_root = Path(temp_dir)
        for asset in CONFIG["assets"]:
            mesh_count, bounds, axes = validator.validate_scene(asset)
            manifest_hashes = validator.validate_manifest(asset)
            rerender_hashes = validator.deterministic_rerender(asset, temp_root)
            require(manifest_hashes == rerender_hashes, "MANIFEST_RERENDER_HASH_SET_MISMATCH", asset["assetId"])
            results["assets"][asset["assetId"]] = {
                "zone": asset["zone"],
                "densityLevel": asset["densityLevel"],
                "meshCount": mesh_count,
                "worldBounds": bounds,
                "projectedAxisPixels": axes,
                "deterministicCanonicalPngSha256": rerender_hashes,
            }
    validate_family_manifest()
    results["contract"] = {
        "projectedTilePixels": [88, 44],
        "pivotPixels": [192, 300],
        "cameraOrder": [view["name"] for view in CONFIG["cameraRig"]["views"]],
        "postRenderCompensation": "none",
        "approvedLiveFamilyIsBaseline": True,
        "deterministicRerender": "byte-identical canonical PNGs",
    }
    report_path = parse_report_path()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = "NEIGHBORHOOD_VARIETY_VALIDATION_PASS\n" + json.dumps(results, indent=2, sort_keys=True) + "\n"
    report_path.write_text(report, encoding="utf-8")
    print(report, end="")


if __name__ == "__main__":
    main()
