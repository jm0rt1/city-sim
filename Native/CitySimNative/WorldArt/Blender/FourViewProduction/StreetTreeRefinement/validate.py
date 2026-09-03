#!/usr/bin/env python3
"""Reopen and independently validate the single refined street-maple source."""

import importlib.util
import json
import sys
import tempfile
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
BASE = HERE.parent / "GroundEcology"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("maple_ground_ecology_validator", BASE / "validate.py")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)
validator.HERE = HERE
ASSET = next(asset for asset in validator.CONFIG["assets"] if asset["assetId"] == "maple_street_tree")


def main():
    require = validator.require
    require(".".join(map(str, bpy.app.version)) == "4.5.12", "BLENDER_VERSION_MISMATCH", bpy.app.version)
    inspection = validator.validate_asset_scene(ASSET)
    validator.validate_asset_manifest(ASSET)
    for name in ["MapleTrunk0", "MapleTrunk3", "MapleFork0", "MapleFork4", "MapleTwig0", "MapleRootFlare0"]:
        require(bpy.data.objects.get(name) is not None, "MISSING_MODELED_BRANCH", name)
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    bounds = [validator.object_bounds(obj) for obj in meshes]
    require(all(item["minX"] >= -1 and item["maxX"] <= 1 and item["minY"] >= -1 and item["maxY"] <= 1
                for item in bounds), "PLANTING_FOOTPRINT_DRIFT", bounds)
    require(max(item["maxZ"] for item in bounds) <= 2.70, "TREE_HEIGHT_DRIFT", bounds)
    foliage = [obj for obj in meshes if obj.name.startswith("MapleFoliage")]
    require(len(foliage) == 66, "LAYERED_CANOPY_MISSING", len(foliage))
    require(min(validator.object_bounds(obj)["minZ"] for obj in foliage) < 1.20,
            "LOWER_BRANCH_CANOPY_MISSING", "Former bare-pole silhouette must not return")
    source = json.loads((HERE / "source-manifest.json").read_text())
    for item in source["files"]:
        require(validator.sha256(HERE / item["path"]) == item["sha256"], "SOURCE_DEPENDENCY_DRIFT", item["path"])
    with tempfile.TemporaryDirectory(prefix="citysim-maple-rerender-") as temp:
        hashes = validator.rerender_asset_from_blend(ASSET, Path(temp))
    result = {"status": "PASS", "inspection": inspection, "deterministicCanonicalPngSha256": hashes,
              "postRenderCompensation": "none", "sourcePixelsReused": False}
    print("STREET_MAPLE_REFINEMENT_VALIDATION_PASS\n" + json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
