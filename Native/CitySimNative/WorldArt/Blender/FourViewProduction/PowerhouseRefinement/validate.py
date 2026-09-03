#!/usr/bin/env python3
"""Focused structural and deterministic validation for the Powerhouse refinement."""

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
ASSET = CONFIG["assets"][0]


def require(condition, code, detail):
    if not condition:
        raise RuntimeError(f"{code}: {detail}")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_existing_validator():
    spec = importlib.util.spec_from_file_location("citysim_powerhouse_density_validator", DENSITY_VALIDATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError("DENSITY_VALIDATOR_IMPORT_FAILED")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.HERE = HERE
    module.BLENDER_ROOT = BLENDER_ROOT
    module.CONFIG = CONFIG
    module.builder = builder
    return module


validator = load_existing_validator()


def validate_refinement_structure():
    blend = HERE / ASSET["assetId"] / f"{ASSET['assetId']}.blend"
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    required = {
        "CopperArcRoofMonitorBase", "CopperArcRoofMonitorNorthGlass", "CopperArcRoofMonitorSouthGlass",
        "CopperArcStack0OpenThroat", "CopperArcStack1OpenThroat", "CopperArcWestHallBay0TallGlass",
        "CopperArcWestHallBay1TallGlass", "CopperArcWestHallBay2TallGlass", "CopperArcServicePipe",
        "CopperArcEastUpperClerestory0", "CopperArcEastUpperClerestory1", "CopperArcEastUpperClerestory2",
        "CopperArcRoofMonitorCopperEdge-0.82", "CopperArcRoofMonitorCopperEdge-0.18",
    }
    missing = sorted(name for name in required if bpy.data.objects.get(name) is None)
    require(not missing, "REFINEMENT_GEOMETRY_MISSING", missing)
    for index in (0, 1):
        rim = bpy.data.objects[f"CopperArcStack{index}Rim"]
        throat = bpy.data.objects[f"CopperArcStack{index}OpenThroat"]
        require(throat.dimensions.x < rim.dimensions.x and throat.dimensions.y < rim.dimensions.y, "STACK_THROAT_NOT_INSET", index)
        require(throat.location.z >= rim.location.z, "STACK_THROAT_NOT_TOP_FACING", index)
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    bounds = validator.mesh_bounds(meshes)
    require(bounds["minimum"][0] >= -2.001 and bounds["maximum"][0] <= 2.001, "FOOTPRINT_X_DRIFT", bounds)
    require(bounds["minimum"][1] >= -2.001 and bounds["maximum"][1] <= 2.001, "FOOTPRINT_Y_DRIFT", bounds)
    require(bounds["minimum"][2] <= -0.199 and bounds["maximum"][2] <= 7.501, "VERTICAL_BOUND_DRIFT", bounds)
    return {"worldBounds": bounds, "meshCount": len(meshes), "requiredGeometry": sorted(required)}


def validate_source_manifest():
    path = HERE / "source-manifest.json"
    require(path.is_file(), "MISSING_SOURCE_MANIFEST", path)
    data = json.loads(path.read_text(encoding="utf-8"))
    require(data["assetId"] == "copper_arc_powerhouse", "SOURCE_MANIFEST_IDENTITY_MISMATCH", path)
    require(data["originalGeometry"] is True and data["sourcePixelsReused"] is False and data["baseGeometryReused"] is True and data["baselineGeometryAdapted"] is True, "SOURCE_PROVENANCE_MISMATCH", path)
    require(len(data["dependencies"]) == 6, "DEPENDENCY_PROVENANCE_COUNT_MISMATCH", path)
    for item in data["sourceFiles"] + data["dependencies"]:
        source = HERE / item["path"]
        require(source.is_file() and sha256(source) == item["sha256"], "DEPENDENCY_HASH_DRIFT", source)
    return data


def parse_report_path():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return Path(args[args.index("--report") + 1]) if "--report" in args else HERE / "validation" / "validator-output.txt"


def main():
    actual = ".".join(map(str, bpy.app.version))
    require(actual == CONFIG["toolchain"]["blenderVersion"], "BLENDER_VERSION_MISMATCH", actual)
    with tempfile.TemporaryDirectory(prefix="citysim-powerhouse-refinement-") as temp_dir:
        mesh_count, bounds, axes = validator.validate_scene(ASSET)
        manifest_hashes = validator.validate_manifest(ASSET)
        rerender_hashes = validator.deterministic_rerender(ASSET, Path(temp_dir))
        require(manifest_hashes == rerender_hashes, "MANIFEST_RERENDER_HASH_SET_MISMATCH", ASSET["assetId"])
        structure = validate_refinement_structure()
    source_manifest = validate_source_manifest()
    results = {
        "schema": "citysim.world-art.copper-arc-powerhouse-refinement-validation.v1",
        "status": "PASS",
        "blenderVersion": actual,
        "asset": {"assetId": ASSET["assetId"], "meshCount": mesh_count, "worldBounds": bounds, "projectedAxisPixels": axes, "deterministicCanonicalPngSha256": rerender_hashes},
        "refinement": structure,
        "sourceManifestDependencies": [item["path"] for item in source_manifest["dependencies"]],
        "contract": {"projectedTilePixels": [88, 44], "pivotPixels": [192, 300], "cameraOrder": [view["name"] for view in CONFIG["cameraRig"]["views"]], "postRenderCompensation": "none", "deterministicRerender": "byte-identical canonical PNGs"},
    }
    report_path = parse_report_path()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = "POWERHOUSE_REFINEMENT_VALIDATION_PASS\n" + json.dumps(results, indent=2, sort_keys=True) + "\n"
    report_path.write_text(report, encoding="utf-8")
    print(report, end="")


if __name__ == "__main__":
    main()
