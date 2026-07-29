#!/usr/bin/env python3
"""Blender-side PLAY-081 West source renderer.

This module is never imported by the system-Python guard. The guarded runner
launches it only after the exact v06 coordinate bridge, appearance lock,
material mapping, frozen predesign hashes, commit ancestry, and deterministic
output path all pass. The historical predesign projection adapter is never
loaded here and is not future source authority.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import platform
import sys
from pathlib import Path
from typing import Any

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--runner-contract", required=True)
    parser.add_argument("--locked-materials", required=True)
    parser.add_argument("--process-id", required=True, choices=("A", "B", "C"))
    parser.add_argument("--output-directory", required=True)
    return parser.parse_args(values)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def repository_path(root: Path, relative: str) -> Path:
    resolved = (root / relative).resolve()
    resolved.relative_to(root)
    return resolved


def load_validated_bridge(root: Path, path: str) -> Any:
    bridge_path = repository_path(root, path)
    spec = importlib.util.spec_from_file_location("play081_west_v06_bridge", bridge_path)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load validated West v06 coordinate bridge")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def create_material(name: str, values: dict[str, Any]) -> bpy.types.Material:
    material = bpy.data.materials.new(name=f"PLAY-081-{name}")
    color = values["baseColorSrgb"]
    material.diffuse_color = tuple(color)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = tuple(color)
    principled.inputs["Roughness"].default_value = values["roughness"]
    principled.inputs["Metallic"].default_value = values["metallic"]
    return material


def configure_scene(
    scene: bpy.types.Scene,
    runner: dict[str, Any],
    predesign: dict[str, Any],
    bridge: Any,
) -> bpy.types.Object:
    pipeline = runner["invariants"]["renderPipeline"]
    camera_contract = predesign["camera"]
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = pipeline["samples"]
    scene.cycles.seed = pipeline["seed"]
    scene.cycles.use_adaptive_sampling = pipeline["adaptiveSampling"]
    scene.cycles.use_denoising = pipeline["denoising"]
    scene.render.image_settings.file_format = pipeline.get("fileFormat", "PNG")
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = pipeline["transparentFilm"]
    scene.render.resolution_x = camera_contract["renderViewportPixels"][0]
    scene.render.resolution_y = camera_contract["renderViewportPixels"][1]
    scene.render.resolution_percentage = pipeline["resolutionPercentage"]
    scene.render.pixel_aspect_x = pipeline["pixelAspect"][0]
    scene.render.pixel_aspect_y = pipeline["pixelAspect"][1]
    scene.render.use_file_extension = True
    scene.render.image_settings.color_mode = "RGBA"
    color = pipeline["colorManagement"]
    scene.display_settings.display_device = color["displayDevice"]
    scene.view_settings.view_transform = color["viewTransform"]
    scene.view_settings.look = color["look"]
    scene.view_settings.exposure = color["exposure"]
    scene.view_settings.gamma = color["gamma"]
    scene.sequencer_colorspace_settings.name = color["sequencerColorspace"]

    camera_data = bpy.data.cameras.new("PLAY-081-West-Camera")
    camera = bpy.data.objects.new("PLAY-081-West-Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = bridge.citysim_to_blender(camera_contract["positionWorldXYZ"])
    target = bridge.citysim_to_blender(camera_contract["targetWorldXYZ"])
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = camera_contract["blenderOrthographicScale"]
    camera_data.shift_x = camera_contract["shiftX"]
    camera_data.shift_y = camera_contract["shiftY"]
    scene.camera = camera
    return camera


def add_key_light(bridge: Any, predesign: dict[str, Any]) -> bpy.types.Object:
    data = bpy.data.lights.new(name="PLAY-081-Northwest-Key", type="AREA")
    data.energy = 1600
    data.shape = "DISK"
    data.size = 80
    light = bpy.data.objects.new("PLAY-081-Northwest-Key", data)
    bpy.context.scene.collection.objects.link(light)
    light.location = bridge.citysim_to_blender(
        predesign["lightAndContact"]["keyOriginWorldXYZ"]
    )
    target = Vector((0, 0, 0))
    light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()
    return light


def assign_semantic_materials(
    objects: dict[str, bpy.types.Object],
    component_by_id: dict[str, dict[str, Any]],
) -> None:
    role_names = sorted(
        {component["materialRole"] for component in component_by_id.values()}
    )
    semantic: dict[str, bpy.types.Material] = {}
    for index, role in enumerate(role_names, start=1):
        red = ((index * 53) % 251 + 1) / 255.0
        green = ((index * 97) % 251 + 1) / 255.0
        blue = ((index * 193) % 251 + 1) / 255.0
        semantic[role] = create_material(
            f"semantic-{role}",
            {
                "baseColorSrgb": [red, green, blue, 1.0],
                "roughness": 1.0,
                "metallic": 0.0,
            },
        )
    for component_id, obj in objects.items():
        obj.data.materials.clear()
        obj.data.materials.append(
            semantic[component_by_id[component_id]["materialRole"]]
        )


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    runner_path = repository_path(root, args.runner_contract)
    materials_path = repository_path(root, args.locked_materials)
    output = repository_path(root, args.output_directory)
    runner = load_json(runner_path)
    predesign_path = repository_path(
        root, runner["acceptedPredesign"]["scene"]["path"]
    )
    predesign = load_json(predesign_path)
    material_mapping = load_json(materials_path)
    bridge = load_validated_bridge(
        root, runner["coordinateBridge"]["v06"]["adapterPath"]
    )

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    camera = configure_scene(scene, runner, predesign, bridge)
    add_key_light(bridge, predesign)
    materials = {
        name: create_material(name, values)
        for name, values in material_mapping["roles"].items()
    }
    objects: dict[str, bpy.types.Object] = {}
    component_by_id = {
        component["id"]: component for component in predesign["components"]
    }
    for component in predesign["components"]:
        obj = bridge.create_component(component)
        obj.data.materials.append(materials[component["materialRole"]])
        objects[component["id"]] = obj
    bpy.context.view_layer.update()

    output.mkdir(parents=True, exist_ok=False)
    scene.render.filepath = str(output / "raw.png")
    bpy.ops.render.render(write_still=True)

    assign_semantic_materials(objects, component_by_id)
    scene.render.filepath = str(output / "semantic.png")
    bpy.ops.render.render(write_still=True)

    object_mapping = [
        {
            "id": component_id,
            "materialRole": component_by_id[component_id]["materialRole"],
            "type": objects[component_id].type,
        }
        for component_id in sorted(objects)
    ]
    (output / "object-mapping.json").write_text(
        json.dumps(object_mapping, indent=2, sort_keys=True) + "\n"
    )
    registration = {
        "footprintWorldXZ": runner["invariants"]["registration"][
            "contactPolygonWorldXZ"
        ],
        "pivotWorldXYZ": runner["invariants"]["registration"][
            "groundPivotWorldXYZ"
        ],
        "socketWorldXYZ": runner["invariants"]["registration"][
            "frontageSocketWorldXYZ"
        ],
        "frontage": "west",
        "cameraName": camera.name,
    }
    (output / "registration.json").write_text(
        json.dumps(registration, indent=2, sort_keys=True) + "\n"
    )
    provenance = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "processId": args.process_id,
        "runnerContractSha256": sha256(runner_path),
        "acceptedPredesignSha256": sha256(predesign_path),
        "lockedMaterialMappingSha256": sha256(materials_path),
        "appearanceLock": runner["appearanceLock"],
        "coordinateBridge": runner["coordinateBridge"]["v06"],
        "blenderVersion": bpy.app.version_string,
        "blenderBuildHash": bpy.app.build_hash.decode(),
        "pythonVersion": platform.python_version(),
        "renderEngine": scene.render.engine,
        "cyclesDevice": scene.cycles.device,
        "cyclesSamples": scene.cycles.samples,
        "cyclesSeed": scene.cycles.seed,
        "renderApiCalls": 2,
        "productionSelected": False,
    }
    (output / "provenance.json").write_text(
        json.dumps(provenance, indent=2, sort_keys=True) + "\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
