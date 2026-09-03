#!/usr/bin/env python3
"""Original street-maple geometry using the unchanged GroundEcology rig."""

from __future__ import annotations

import importlib.util
import json
import math
import os
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
BASE = HERE.parent / "GroundEcology"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("maple_ground_ecology_helpers", BASE / "build_and_render.py")
kit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kit)
CONFIG = kit.CONFIG
ASSET = next(dict(asset) for asset in CONFIG["assets"] if asset["assetId"] == "maple_street_tree")
ASSET["description"] = "Street maple with tapered branching trunk, visible forks and an irregular warm-green crown"
kit.HERE = HERE


def tapered_branch(root, name, start, end, radius_start, radius_end, mat):
    a, b = Vector(start), Vector(end)
    direction = b - a
    bpy.ops.mesh.primitive_cone_add(
        vertices=12, radius1=radius_start, radius2=radius_end,
        depth=direction.length, location=(a + b) / 2,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    kit.apply_transforms(obj)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def leaf_lobe(root, name, position, radius, mat, seed):
    obj = kit.sphere(root, name, position, (radius, radius * 0.93, radius * 0.88), mat, 2)
    rng = random.Random(seed)
    # Uneven modeled lobes break the smooth ball silhouette; mesh transforms stay identity.
    for vertex in obj.data.vertices:
        vertex.co *= rng.uniform(0.91, 1.09)
    return obj


def maple(root, mats):
    contact = kit.cone(root, "GroundContact", (0, 0, 0.18), 0.16, 0.108, 0.36, mats["bark"], 16)
    contact["groundContactZ"] = 0.0
    contact["pivotXY"] = [0.0, 0.0]
    trunk = [(0, 0, 0.22), (0.035, -0.012, 0.64), (-0.018, 0.018, 1.06), (0.035, 0.035, 1.48), (0.0, 0.07, 1.96)]
    radii = [0.116, 0.097, 0.074, 0.048, 0.022]
    for index, (start, end) in enumerate(zip(trunk, trunk[1:])):
        tapered_branch(root, f"MapleTrunk{index}", start, end, radii[index], radii[index + 1], mats["bark"])

    branches = [
        ((0.025, 0, 0.62), (-0.20, 0.035, 1.04), (-0.53, 0.12, 1.54)),
        ((0, 0, 0.78), (0.22, -0.11, 1.20), (0.52, -0.25, 1.68)),
        ((-0.018, 0.018, 1.03), (0.035, 0.31, 1.46), (-0.12, 0.48, 1.91)),
        ((0.0, 0.03, 1.23), (-0.21, -0.24, 1.55), (-0.34, -0.38, 1.98)),
        ((0.03, 0.04, 1.45), (0.28, 0.17, 1.76), (0.36, 0.25, 2.10)),
    ]
    for index, (start, elbow, tip) in enumerate(branches):
        tapered_branch(root, f"MapleFork{index}", start, elbow, 0.065 - index * 0.006, 0.034, mats["bark"])
        tapered_branch(root, f"MapleTwig{index}", elbow, tip, 0.034, 0.011, mats["bark"])
    for index in range(5):
        angle = index * math.tau / 5 + 0.2
        tapered_branch(root, f"MapleRootFlare{index}", (0, 0, 0.16),
                       (math.cos(angle) * 0.20, math.sin(angle) * 0.20, 0.03), 0.05, 0.025, mats["bark"])

    crowns = [
        (-0.48, 0.10, 1.38, 0.29, "leaf"),
        (0.44, -0.25, 1.48, 0.29, "leaf"),
        (-0.34, -0.28, 1.62, 0.34, "leaf"),
        (0.13, 0.39, 1.68, 0.31, "leaf"),
        (-0.42, 0.25, 1.78, 0.33, "leaf_light"),
        (0.41, 0.10, 1.85, 0.33, "leaf_light"),
        (0.0, -0.33, 1.91, 0.34, "leaf"),
        (-0.26, -0.16, 2.13, 0.34, "leaf_light"),
        (0.13, 0.27, 2.16, 0.32, "leaf"),
        (0.29, -0.17, 2.17, 0.29, "leaf_light"),
        (-0.02, 0.035, 2.36, 0.27, "leaf_light"),
    ]
    for index, (x, y, z, radius, key) in enumerate(crowns):
        leaf_lobe(root, f"MapleCrownCore{index}", (x, y, z), radius, mats[key], index * 100)
        rng = random.Random(4200 + index)
        for leaf in range(6):
            angle = leaf * math.tau / 6 + index * 0.57
            offset = radius * rng.uniform(0.59, 0.74)
            location = (x + math.cos(angle) * offset, y + math.sin(angle) * offset,
                        z + rng.uniform(-0.12, 0.15))
            color = "leaf_warm" if (index * 6 + leaf) % 17 == 0 else key
            leaf_lobe(root, f"MapleFoliage{index}_{leaf}", location, radius * rng.uniform(0.39, 0.52),
                      mats[color], 8100 + index * 6 + leaf)


def main():
    if ".".join(map(str, bpy.app.version)) != CONFIG["toolchain"]["blenderVersion"]:
        raise RuntimeError("BLENDER_VERSION_MISMATCH")
    scene = kit.reset("CitySimStreetMapleRefinement")
    kit.configure_scene(scene, transparent=True)
    root = kit.asset_root(ASSET)
    maple(root, kit.ecology_palette())
    cameras = kit.canonical_rig(scene)
    output = HERE / ASSET["assetId"]
    output.mkdir(parents=True, exist_ok=True)
    blend = output / "maple_street_tree.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    renders = kit.render_views(scene, cameras, ASSET["assetId"], output / "renders")
    sheet = kit.contact_sheet(renders, output / "maple_street_tree_contact-sheet.png")
    kit.write_asset_manifest(ASSET, [blend, *renders, sheet])
    dependencies = [BASE / "build_and_render.py", BASE / "pipeline.json", BASE / "validate.py",
                    BASE.parent.parent / "FourViewPipeline" / "png_canonical.py"]
    sources = [HERE / name for name in ("build_and_render.py", "validate.py", "README.md")]
    payload = {"assetId": ASSET["assetId"], "originalGeometry": True, "sourcePixelsReused": False,
               "baselineReference": "../GroundEcology/maple_street_tree",
               "files": [{"path": os.path.relpath(path, HERE), "sha256": kit.sha256(path)} for path in sources + dependencies]}
    (HERE / "source-manifest.json").write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print("STREET_MAPLE_REFINEMENT_RENDER_PASS assets=1 views=4")


if __name__ == "__main__":
    main()
