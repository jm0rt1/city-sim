#!/usr/bin/env python3
"""Authenticated West Process-A Blender child entrypoint.

This module is intentionally not imported or launched by the prelaunch tests.
It contains explicit semantic builders for every frozen v14 component and a
single Blender scene construction boundary for a future Integration grant.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[8]
PACKAGE = Path(__file__).resolve().parent
CONTRACT = PACKAGE / "PROCESS-A-CONTRACT.json"
DESIGN = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/WEST-V14-DESIGN.json"
LOWERING = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/WEST-V14-LOWERING.json"


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def semantic_manifest() -> dict[str, Any]:
    contract, design, lowering = load(CONTRACT), load(DESIGN), load(LOWERING)
    if digest(DESIGN) != contract["designSHA256"] or digest(LOWERING) != contract["loweringSHA256"]:
        raise ValueError("frozen v14 input hash drift")
    components = design["components"]
    lowered = {item["id"]: item for item in lowering["componentLowering"]["components"]}
    if set(lowered) != {item["id"] for item in components}:
        raise ValueError("incomplete semantic component coverage")
    objects: list[dict[str, Any]] = []
    for component in components:
        item = lowered[component["id"]]
        if item["objects"] != component["builderObjects"] or item["builder"] not in contract["builderKinds"]:
            raise ValueError("generic or missing semantic builder")
        for object_id in item["objects"]:
            objects.append({"id": object_id, "component": component["id"], "builder": item["builder"], "role": component["role"], "aabb": component["aabb"]})
    if len({item["id"] for item in objects}) != len(objects):
        raise ValueError("duplicate Blender object identity")
    return {"task": contract["task"], "direction": contract["direction"], "processID": contract["processID"], "camera": contract["camera"], "registration": contract["registration"], "materialRoles": contract["materialRoles"], "objects": objects, "componentCount": len(components), "objectCount": len(objects)}


def _make_materials(bpy: Any, roles: list[str]) -> dict[str, Any]:
    materials = {}
    for role in roles:
        material = bpy.data.materials.new(name=f"PLAY081-{role}")
        material.diffuse_color = (0.35, 0.35, 0.35, 1.0)
        materials[role] = material
    return materials


def _add_box(bpy: Any, name: str, center: tuple[float, float, float], size: tuple[float, float, float], material: Any) -> Any:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    obj.data.materials.append(material)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def _add_cylinder(bpy: Any, name: str, center: tuple[float, float, float], size: tuple[float, float, float], material: Any) -> Any:
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.5, depth=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    obj.data.materials.append(material)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def _build_component(bpy: Any, component: dict[str, Any], material: Any) -> list[Any]:
    lower, upper = component["aabb"]["min"], component["aabb"]["max"]
    center = tuple((float(a) + float(b)) / 2.0 for a, b in zip(lower, upper))
    size = tuple(float(b) - float(a) for a, b in zip(lower, upper))
    shape = component["shape"]
    if shape in {"box", "roof-wedge", "void-content", "surface-detail", "railing", "pipe-run"}:
        return [_add_box(bpy, object_id, center, size, material) for object_id in component["builderObjects"]]
    if shape == "cylinder":
        return [_add_cylinder(bpy, object_id, center, size, material) for object_id in component["builderObjects"]]
    if shape == "void":
        return []
    raise ValueError(f"unsupported semantic shape: {shape}")


def build_scene() -> dict[str, Any]:
    if os.environ.get("PLAY081_PROCESS_A_AUTHENTICATED") != "1":
        raise PermissionError("authenticated Integration grant required")
    import bpy
    contract, design = load(CONTRACT), load(DESIGN)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = _make_materials(bpy, contract["materialRoles"])
    for component in design["components"]:
        if component["shape"] == "void":
            continue
        _build_component(bpy, component, materials[component["role"]])
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = contract["camera"]["renderViewportPixels"]
    scene.camera = bpy.data.objects.new("PLAY081-west-v14-camera", None)
    scene.world.color = (0.08, 0.08, 0.08)
    return semantic_manifest()


def main() -> int:
    if "--emit-manifest" in sys.argv[1:]:
        sys.stdout.write(json.dumps(semantic_manifest(), sort_keys=True, separators=(",", ":")) + "\n")
        return 0
    build_scene()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
