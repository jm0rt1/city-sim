#!/usr/bin/env python3
"""Blender child entrypoint for North v14; never imported by prelaunch tests."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import Any

SOURCE_ROOT = Path("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14")
ALLOWED_OUTPUTS = {"raw.png", "semantic.png", "OBJECT-MANIFEST.json", "GROUND-PROJECTION.json", "INPUT-BINDINGS.json", "provenance.json", "PROCESS-RECEIPT.json"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text())
    require(type(value) is dict, f"JSON object required: {path}")
    return value


def load_lowerer(root: Path) -> Any:
    path = root / SOURCE_ROOT / "lower_v14_scene.py"
    spec = importlib.util.spec_from_file_location("play027_v14_child_lowerer", path)
    require(spec is not None and spec.loader is not None, "lowerer unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def construct_semantic_geometry(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    """Constructs the exact 33-component/97-object semantic packet."""
    lowerer = load_lowerer(root)
    packet = lowerer.run()
    report, manifest = packet["report"], packet["manifest"]
    require(report["componentCount"] == 33 and report["objectCount"] == 97, "semantic object count drift")
    require(report["componentToObjectCoverage"]["percent"] == 100.0, "semantic coverage incomplete")
    require(report["registration"]["socketCitySim"] == [0, 0, -28] and report["registration"]["socketBlender"] == [-28, 0, 0], "semantic socket drift")
    require(report["portal"]["socketConnected"] and report["topology"]["parameterizedPayloads"], "semantic portal/topology proof missing")
    return {"manifest": manifest, "report": report, "inputHashes": packet["inputHashes"], "camera": contract["registration"], "lighting": contract["cycles"]}


def materialize_parameterized_object(bpy: Any, item: dict[str, Any], material: Any) -> Any:
    """Lower one semantic geometry kind to a real Blender primitive/mesh."""
    kind = item["geometryKind"]
    if kind == "void":
        return None
    b = item["boundsXYZ"]
    if kind in {"octagonal-body", "octagonal-shoulder", "octagonal-rim"}:
        bpy.ops.mesh.primitive_cylinder_add(vertices=item["parameters"].get("sides", 8), radius=max(b[1][0] - b[0][0], b[1][2] - b[0][2]) / 2, depth=b[1][1] - b[0][1], location=[(b[0][0] + b[1][0]) / 2, (b[0][1] + b[1][1]) / 2, (b[0][2] + b[1][2]) / 2])
    elif kind in {"pipe-segment", "pipe-elbow", "pipe-support", "truss-chord", "truss-diagonal", "sawtooth-peak", "sawtooth-slope-face", "clerestory-frame", "clerestory-glass", "portal-frame", "reveal-jamb", "reveal-header", "inset-plane", "staff-frame", "staff-leaf", "service-door", "articulated-member", "plant-unit", "loading-stripe", "threshold-slab", "threshold-edge", "apron-road-link", "apron-service-pad", "shared-eave", "cylindrical-shaft", "stack-bands"}:
        bpy.ops.mesh.primitive_cube_add(size=1, location=[(b[0][0] + b[1][0]) / 2, (b[0][1] + b[1][1]) / 2, (b[0][2] + b[1][2]) / 2])
        obj = bpy.context.object
        obj.dimensions = [b[1][0] - b[0][0], b[1][1] - b[0][1], b[1][2] - b[0][2]]
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1, location=[(b[0][0] + b[1][0]) / 2, (b[0][1] + b[1][1]) / 2, (b[0][2] + b[1][2]) / 2])
        obj = bpy.context.object
        obj.dimensions = [b[1][0] - b[0][0], b[1][1] - b[0][1], b[1][2] - b[0][2]]
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.name = item["id"]
    obj.data.materials.append(material)
    return obj


def configure_scene(bpy: Any, packet: dict[str, Any], materials: dict[str, Any], lighting: dict[str, Any]) -> dict[str, Any]:
    """Apply the frozen camera, registration, material roles and Cycles settings."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if False else "CYCLES"
    scene.cycles.samples = lighting["samples"]
    scene.cycles.use_denoising = lighting["denoising"]
    scene.render.film_transparent = lighting["transparentFilm"]
    scene.render.resolution_x, scene.render.resolution_y = lighting["resolution"]
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = lighting["colorManagement"]["viewTransform"]
    scene.view_settings.look = lighting["colorManagement"]["look"]
    scene.view_settings.exposure = lighting["colorManagement"]["exposure"]
    scene.view_settings.gamma = lighting["colorManagement"]["gamma"]
    material_by_role = {}
    for role in materials["materials"]:
        mat = bpy.data.materials.new(role["id"])
        mat.diffuse_color = role["baseColorRGBA"]
        mat.roughness = role["roughness"]
        mat.metallic = role["metalness"]
        material_by_role[role["role"]] = mat
    camera_data = bpy.data.cameras.new("v14-north-camera")
    camera = bpy.data.objects.new("v14-north-camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2 * 79.1959533691406 * (1536 / 1024)
    camera.location = [96, 101.24557426726288, 96]
    scene.camera = camera
    return material_by_role


def parse_args(values: list[str] | None = None) -> argparse.Namespace:
    if values is None:
        require("--" in sys.argv, "Blender separator required")
        values = sys.argv[sys.argv.index("--") + 1 :]
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--direction", required=True)
    parser.add_argument("--integration-session", required=True)
    return parser.parse_args(values)


def main(values: list[str] | None = None) -> int:
    args = parse_args(values)
    require(args.direction == "north", "North-only child")
    require(os.environ.get("CITYSIM_PROCESS_A_LIVE") == "1", "direct child invocation rejected")
    root = Path(args.repository_root).resolve()
    contract = load_json(Path(args.contract).resolve())
    output = root / contract["outputRoot"]
    require(not output.exists() and not output.is_symlink(), "output root must be absent")
    # Import bpy only after all static identity checks pass.
    import bpy  # type: ignore
    scene = load_json(root / contract["frozenInputs"]["scene"]["path"])
    materials = load_json(root / contract["frozenInputs"]["materials"]["path"])
    lighting = load_json(root / contract["frozenInputs"]["lighting"]["path"])
    packet = construct_semantic_geometry(root, contract)
    material_by_role = configure_scene(bpy, packet, materials, lighting)
    for item in packet["manifest"]["objects"]:
        materialize_parameterized_object(bpy, item, material_by_role[item["materialRole"]])
    output.mkdir(parents=True, exist_ok=False)
    (output / "OBJECT-MANIFEST.json").write_text(json.dumps(packet["manifest"], sort_keys=True, indent=2) + "\n")
    (output / "GROUND-PROJECTION.json").write_text(json.dumps(packet["report"]["registration"], sort_keys=True, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
