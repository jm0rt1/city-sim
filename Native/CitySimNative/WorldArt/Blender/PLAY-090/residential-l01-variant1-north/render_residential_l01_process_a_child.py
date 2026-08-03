"""Integration-owned Blender child for Residential L1 North Process A.

The module performs authority validation before importing ``bpy``. Worker
contained-smoke tests call ``validate_launch`` and ``build_scene_spec`` only;
they never start Blender or create pixels.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

import launch_residential_l01_process_a as runner


def build_scene_spec(root: Path) -> dict:
    scene = runner.load_json(root / runner.SOURCE_ROOT / "DESIGN-SCENE.json")
    materials = runner.load_json(root / runner.SOURCE_ROOT / "MATERIALS.json")
    components = scene.get("components", [])
    if not components or len({c.get("id") for c in components}) != len(components):
        raise ValueError("scene components must have unique IDs")
    material_ids = {m.get("id") for m in materials.get("materials", [])}
    if any(c.get("materialID") not in material_ids for c in components):
        raise ValueError("scene references an unknown material")
    return {
        "sceneGeometryID": scene["sceneGeometryID"],
        "componentCount": len(components),
        "componentIDs": [c["id"] for c in components],
        "materialIDs": sorted(material_ids),
        "camera": scene["camera"],
        "registration": scene["registration"],
        "light": scene["light"],
    }


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--integration-direct", action="store_true")
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--schedule-path", required=True)
    parser.add_argument("--grant-path", required=True)
    parser.add_argument("--process-receipt-path", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(argv)


def validate_launch(args: argparse.Namespace) -> dict:
    if not args.integration_direct or os.environ.get("CITYSIM_INTEGRATION_DIRECT") != "1":
        raise ValueError("direct child requires Integration capability")
    root = runner.exact_repository_root(args.repository_root)
    contract = runner.validate_contract(root, args.contract)
    binding = runner.validate_direct_documents(root, contract, args.schedule_path, args.grant_path,
                                               args.process_receipt_path, False)
    if args.output_root != runner.FUTURE_PROCESS_ROOT:
        raise ValueError("child output root mismatch")
    output = runner.safe_path(root, runner.FUTURE_PROCESS_ROOT)
    if output.exists():
        raise ValueError("child output root must be absent before launch")
    return {"binding": binding, "scene": build_scene_spec(root), "workerHead": binding["currentHead"]}


def render_process(validated: dict, args: argparse.Namespace) -> int:
    # bpy is intentionally imported only after all authority checks pass.
    import bpy  # type: ignore  # pragma: no cover

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 64
    scene.cycles.use_adaptive_sampling = False
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1536
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.use_motion_blur = False
    scene.world.color = (0.05, 0.05, 0.05)
    # Geometry/material lowering is owned by the future Integration launch;
    # this worker child does not write output or claim source authority.
    scene.render.filepath = str(Path(args.output_root) / "raw.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.output_root) / "scene.blend"))
    bpy.ops.render.render(write_still=True)
    return 0


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    validated = validate_launch(args)
    return render_process(validated, args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
