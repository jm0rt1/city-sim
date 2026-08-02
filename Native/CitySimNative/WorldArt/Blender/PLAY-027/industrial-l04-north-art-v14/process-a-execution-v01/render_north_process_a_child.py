#!/usr/bin/env python3
"""Blender child entrypoint for North v14; never imported by prelaunch tests."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import os
import sys
from pathlib import Path
from typing import Any

SOURCE_ROOT = Path("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14")
ALLOWED_OUTPUTS = {"raw.png", "semantic.png", "north-v14-process-a.blend", "OBJECT-MANIFEST.json", "GROUND-PROJECTION.json", "INPUT-BINDINGS.json", "provenance.json", "PROCESS-RECEIPT.json"}


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


def mesh_object(bpy: Any, name: str, vertices: list[list[float]], faces: list[list[int]], material: Any) -> Any:
    require(vertices and faces, f"empty mesh: {name}")
    mesh = bpy.data.meshes.new(f"{name}-mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def box_mesh(b: list[list[float]]) -> tuple[list[list[float]], list[list[int]]]:
    x0, y0, z0 = b[0]
    x1, y1, z1 = b[1]
    vertices = [[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0], [x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]]
    faces = [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [4, 0, 3, 7]]
    return vertices, faces


def wedge_mesh(b: list[list[float]]) -> tuple[list[list[float]], list[list[int]]]:
    x0, y0, z0 = b[0]
    x1, y1, z1 = b[1]
    xm = (x0 + x1) / 2
    vertices = [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1], [x0, y1, z0], [xm, y1, z0], [x1, y1, z1], [x0, y1, z1]]
    faces = [[0, 1, 2, 3], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0], [4, 7, 6, 5]]
    return vertices, faces


def cylinder_between(bpy: Any, name: str, start: list[float], end: list[float], radius: float, material: Any) -> Any:
    from mathutils import Vector
    a, z = Vector(start), Vector(end)
    delta = z - a
    require(delta.length > 0, f"zero length cylinder: {name}")
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=delta.length, location=(a + z) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    return obj


def materialize_parameterized_object(bpy: Any, item: dict[str, Any], material: Any) -> Any:
    """Lower one semantic geometry kind to explicit Blender mesh/primitives."""
    kind = item["geometryKind"]
    if kind == "void":
        return None
    b = item["boundsXYZ"]
    if kind in {"pipe-segment", "truss-chord", "truss-diagonal"}:
        if "start" in item["parameters"]:
            return cylinder_between(bpy, item["id"], item["parameters"]["start"], item["parameters"]["end"], 0.22, material)
        return cylinder_between(bpy, item["id"], b[0], b[1], 0.22, material)
    if kind == "pipe-elbow":
        center = item["parameters"]["joint"]
        bpy.ops.mesh.primitive_torus_add(major_radius=0.35, minor_radius=0.12, major_segments=12, minor_segments=6, location=center)
        obj = bpy.context.object
        obj.name = item["id"]
        obj.data.materials.append(material)
        return obj
    if kind in {"octagonal-body", "octagonal-shoulder", "octagonal-rim", "cylindrical-shaft", "stack-bands"}:
        bpy.ops.mesh.primitive_cylinder_add(vertices=item["parameters"].get("sides", 12), radius=max(b[1][0] - b[0][0], b[1][2] - b[0][2]) / 2, depth=b[1][1] - b[0][1], location=[(b[0][0] + b[1][0]) / 2, (b[0][1] + b[1][1]) / 2, (b[0][2] + b[1][2]) / 2])
        obj = bpy.context.object
        obj.name = item["id"]
        obj.data.materials.append(material)
        return obj
    if kind in {"sawtooth-peak", "sawtooth-slope-face"}:
        vertices, faces = wedge_mesh(b)
        return mesh_object(bpy, item["id"], vertices, faces, material)
    vertices, faces = box_mesh(b)
    return mesh_object(bpy, item["id"], vertices, faces, material)


def configure_scene(bpy: Any, packet: dict[str, Any], scene_data: dict[str, Any], materials: dict[str, Any], lighting: dict[str, Any]) -> dict[str, Any]:
    """Apply exact camera, registration, materials, world, key/fill and Cycles settings."""
    from mathutils import Vector
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = lighting["device"]
    scene.cycles.samples = lighting["samples"]
    scene.cycles.use_adaptive_sampling = lighting["adaptiveSampling"]
    scene.cycles.use_denoising = lighting["denoising"]
    scene.cycles.seed = 17
    scene.render.film_transparent = lighting["transparentFilm"]
    scene.render.resolution_x, scene.render.resolution_y = lighting["resolution"]
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x, scene.render.pixel_aspect_y = lighting["pixelAspect"]
    scene.view_settings.view_transform = lighting["colorManagement"]["viewTransform"]
    scene.view_settings.look = lighting["colorManagement"]["look"]
    scene.view_settings.exposure = lighting["colorManagement"]["exposure"]
    scene.view_settings.gamma = lighting["colorManagement"]["gamma"]
    material_by_role = {}
    for role in materials["materials"]:
        mat = bpy.data.materials.new(role["id"])
        mat.use_nodes = True
        node = mat.node_tree.nodes.get("Principled BSDF")
        node.inputs["Base Color"].default_value = role["baseColorRGBA"]
        node.inputs["Roughness"].default_value = role["roughness"]
        node.inputs["Metallic"].default_value = role["metalness"]
        if "emissionStrength" in role:
            node.inputs["Emission Color"].default_value = role["baseColorRGBA"]
            node.inputs["Emission Strength"].default_value = role["emissionStrength"]
        material_by_role[role["role"]] = mat
    world = bpy.data.worlds.new("v14-north-world")
    world.use_nodes = True
    scene.world = world
    world_nodes = world.node_tree.nodes
    world_nodes.clear()
    background = world_nodes.new("ShaderNodeBackground")
    background.inputs["Color"].default_value = lighting["world"]["backgroundColorRGBA"]
    background.inputs["Strength"].default_value = lighting["world"]["backgroundStrength"]
    world_output = world_nodes.new("ShaderNodeOutputWorld")
    world.node_tree.links.new(background.outputs["Background"], world_output.inputs["Surface"])
    camera_data = bpy.data.cameras.new("v14-north-camera")
    camera = bpy.data.objects.new("v14-north-camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 237.5878601074218
    camera_data.shift_x = scene_data["camera"]["postProjectionOffsetPixels"][0] / scene_data["camera"]["renderViewportPixels"][0]
    camera_data.shift_y = scene_data["camera"]["postProjectionOffsetPixels"][1] / scene_data["camera"]["renderViewportPixels"][0]
    camera.location = scene_data["camera"]["positionWorld"]
    camera.rotation_euler = (Vector(scene_data["camera"]["targetWorld"]) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    key = lighting["key"]
    light_data = bpy.data.lights.new("v14-north-key", type=key["type"])
    light_data.energy = key["energyWatts"]
    light_data.shape = key["shape"]
    light_data.size = key["sizeWorld"]
    light_data.color = key["colorRGB"]
    light = bpy.data.objects.new("v14-north-key", light_data)
    bpy.context.collection.objects.link(light)
    light.location = key["originWorld"]
    light.rotation_euler = (Vector(key["targetWorld"]) - light.location).to_track_quat("-Z", "Y").to_euler()
    fill = lighting["optionalFill"]
    fill_data = bpy.data.lights.new("v14-north-fill", type=fill["type"])
    fill_data.energy = fill["energyWatts"]
    fill_data.shape = fill["shape"] if "shape" in fill else "DISK"
    fill_data.size = fill["sizeWorld"]
    fill_data.color = fill["colorRGB"]
    fill_obj = bpy.data.objects.new("v14-north-fill", fill_data)
    bpy.context.collection.objects.link(fill_obj)
    fill_obj.location = [70, 70, 40]
    fill_obj.rotation_euler = (Vector(scene_data["camera"]["targetWorld"]) - fill_obj.location).to_track_quat("-Z", "Y").to_euler()
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
    material_by_role = configure_scene(bpy, packet, scene, materials, lighting)
    for item in packet["manifest"]["objects"]:
        materialize_parameterized_object(bpy, item, material_by_role[item["materialRole"]])
    output.mkdir(parents=True, exist_ok=False)
    scene.render.filepath = str(output / "raw.png")
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / "north-v14-process-a.blend"))
    (output / "OBJECT-MANIFEST.json").write_text(json.dumps(packet["manifest"], sort_keys=True, indent=2) + "\n")
    (output / "GROUND-PROJECTION.json").write_text(json.dumps(packet["report"]["registration"], sort_keys=True, indent=2) + "\n")
    (output / "INPUT-BINDINGS.json").write_text(json.dumps(contract["frozenInputs"], sort_keys=True, indent=2) + "\n")
    (output / "provenance.json").write_text(json.dumps({"task": "PLAY-027", "direction": "north", "process": "A", "inputHashes": packet["inputHashes"], "childStarts": 1, "dccProcessCount": 1, "sourceAuthority": False, "productionSelected": False}, sort_keys=True, indent=2) + "\n")
    (output / "PROCESS-RECEIPT.json").write_text(json.dumps({"status": "PROCESS_A_COMPLETE", "direction": "north", "renderPath": "raw.png", "blendPath": "north-v14-process-a.blend"}, sort_keys=True, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
