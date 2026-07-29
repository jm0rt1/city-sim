#!/usr/bin/env python3
"""Render the one authorized PLAY-027 Industrial L4 North v07 process A."""

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


def fail(message: str) -> None:
    raise RuntimeError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def inside(root: Path, relative: str) -> Path:
    path = (root / relative).resolve()
    path.relative_to(root)
    return path


def arguments() -> argparse.Namespace:
    if "--" not in sys.argv:
        fail("script arguments must follow Blender's -- separator")
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--process-id", choices=["PREFLIGHT", "A"], required=True)
    parser.add_argument("--preflight-only", action="store_true")
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def load_bridge_helper(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("play027_v07_bridge", path)
    if spec is None or spec.loader is None:
        fail("could not load accepted v07 bridge helper")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def clean_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)


def material_from(record: dict[str, Any]) -> Any:
    material = bpy.data.materials.new(record["id"])
    material.use_nodes = True
    material.diffuse_color = tuple(record["baseColorRGBA"])
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    rgba = tuple(float(value) for value in record["baseColorRGBA"])
    shader.inputs["Base Color"].default_value = rgba
    shader.inputs["Metallic"].default_value = float(record["metalness"])
    shader.inputs["Roughness"].default_value = float(record["roughness"])
    shader.inputs["Alpha"].default_value = rgba[3]
    emission = float(record.get("emissionStrength", 0.0))
    if emission > 0.0:
        shader.inputs["Emission Color"].default_value = rgba
        shader.inputs["Emission Strength"].default_value = emission
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def add_bevel(obj: Any, width: float) -> None:
    if width <= 0.0:
        return
    modifier = obj.modifiers.new(name="authored-bevel", type="BEVEL")
    modifier.width = width
    modifier.segments = 2
    modifier.limit_method = "ANGLE"


def shadow_material(opacity: float) -> Any:
    material = bpy.data.materials.new("north-v07-authored-contact-shadow")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    diffuse.inputs["Color"].default_value = (0.025, 0.031, 0.029, 1.0)
    diffuse.inputs["Roughness"].default_value = 1.0
    mix = nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = opacity
    material.node_tree.links.new(transparent.outputs[0], mix.inputs[1])
    material.node_tree.links.new(diffuse.outputs[0], mix.inputs[2])
    material.node_tree.links.new(mix.outputs[0], output.inputs["Surface"])
    return material


def add_shadow(record: dict[str, Any], bridge: Any) -> Any:
    offset_x, offset_z = record["offsetWorldXZ"]
    vertices = [
        bridge.basis(
            [
                float(point[0]) + float(offset_x),
                0.025,
                float(point[1]) + float(offset_z),
            ]
        )
        for point in record["polygonWorldXZ"]
    ]
    mesh = bpy.data.meshes.new(f"{record['id']}-mesh")
    mesh.from_pydata(vertices, [], [[0, 1, 2, 3]])
    mesh.update()
    obj = bpy.data.objects.new(record["id"], mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(shadow_material(float(record["opacity"])))
    return obj


def add_light(scene_record: dict[str, Any], bridge: Any) -> Any:
    data = bpy.data.lights.new("north-v07-northwest-key", type="SUN")
    data.energy = float(scene_record["cycles"]["northwestSunEnergy"])
    data.angle = float(scene_record["cycles"]["northwestSunAngleRadians"])
    obj = bpy.data.objects.new("north-v07-northwest-key", data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = bridge.basis(scene_record["light"]["keyOrigin"])
    bridge.look_at(obj, bridge.basis([0.0, 0.0, 0.0]))
    return obj


def configure_cycles(
    scene: Any,
    scene_record: dict[str, Any],
    output: Path,
) -> None:
    settings = scene_record["cycles"]
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.threads_mode = "FIXED"
    scene.render.threads = int(settings["threads"])
    scene.cycles.seed = int(settings["seed"])
    scene.cycles.samples = int(settings["samples"])
    scene.cycles.use_adaptive_sampling = False
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = int(settings["maxBounces"])
    scene.render.use_motion_blur = False
    scene.render.film_transparent = True
    scene.render.resolution_x = int(settings["resolution"][0])
    scene.render.resolution_y = int(settings["resolution"][1])
    scene.render.resolution_percentage = int(settings["resolutionPercentage"])
    scene.render.pixel_aspect_x = float(settings["pixelAspect"][0])
    scene.render.pixel_aspect_y = float(settings["pixelAspect"][1])
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.filepath = str(output)
    colors = settings["colorManagement"]
    scene.display_settings.display_device = colors["displayDevice"]
    scene.view_settings.view_transform = colors["viewTransform"]
    scene.view_settings.look = colors["look"]
    scene.view_settings.exposure = float(colors["exposure"])
    scene.view_settings.gamma = float(colors["gamma"])
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.18, 0.22, 0.20, 1.0)
    background.inputs["Strength"].default_value = float(settings["worldStrength"])


def projection_report(
    scene: Any,
    camera: Any,
    scene_record: dict[str, Any],
    bridge: Any,
) -> dict[str, Any]:
    registration = scene_record["registration"]
    actual = [
        bridge.source_pixel(scene, camera, [point[0], 0.0, point[1]])
        for point in registration["contactPolygonWorld"]
    ]
    expected = registration["footprintPolygonSource"]
    pivot = bridge.source_pixel(
        scene,
        camera,
        registration["groundPivotWorld"],
    )
    socket = bridge.source_pixel(
        scene,
        camera,
        registration["frontageSocketWorld"],
    )
    deltas = [
        abs(actual_item[index] - expected_item[index])
        for actual_item, expected_item in zip(actual, expected)
        for index in range(2)
    ]
    deltas.extend(
        abs(pivot[index] - registration["groundPivotSource"][index])
        for index in range(2)
    )
    deltas.extend(
        abs(socket[index] - registration["frontageSocketSource"][index])
        for index in range(2)
    )
    maximum = max(deltas)
    if maximum > 0.001:
        fail(f"registration drift: {maximum}")
    return {
        "schema": 1,
        "descriptorOrder": scene_record["coordinateBridge"]["descriptorOrder"],
        "basis": scene_record["coordinateBridge"]["formula"],
        "footprintExpectedSource": expected,
        "footprintActualSource": actual,
        "pivotExpectedSource": registration["groundPivotSource"],
        "pivotActualSource": pivot,
        "socketExpectedSource": registration["frontageSocketSource"],
        "socketActualSource": socket,
        "maximumAbsoluteDeltaSourcePixels": maximum,
        "passed": True,
    }


def object_manifest(
    components: list[dict[str, Any]],
    objects: list[Any],
    material_ids: list[str],
) -> dict[str, Any]:
    return {
        "schema": 1,
        "task": "PLAY-027",
        "componentCount": len(components),
        "materialCount": len(material_ids),
        "components": [
            {
                "id": component["id"],
                "shape": component["shape"],
                "group": component["group"],
                "dimensionsCitySimXYZ": component["dimensions"],
                "positionCitySimXYZ": component["position"],
                "materialID": component["materialID"],
                "bevelWorldUnits": component.get("bevel", 0.0),
                "blenderObjectName": obj.name,
            }
            for component, obj in zip(components, objects)
        ],
        "materialIDs": sorted(material_ids),
        "allComponentsMapped": len(components) == len(objects),
    }


def main() -> None:
    args = arguments()
    root = args.repository_root.resolve()
    contract_path = inside(root, args.contract)
    contract = load_json(contract_path)
    output_root = args.output_root.resolve()
    if output_root.exists():
        fail(f"output root must be absent: {output_root}")
    output_root.mkdir(parents=True)

    script_path = Path(__file__).resolve()
    scene_path = inside(root, contract["scene"]["file"])
    materials_path = inside(root, contract["materials"]["file"])
    bridge_path = inside(root, contract["bridge"]["file"])
    helper_path = inside(root, contract["bridgeHelper"]["file"])
    accepted_proof_path = inside(root, contract["acceptedProof"]["file"])
    expected = {
        script_path: contract["runner"]["sha256"],
        scene_path: contract["scene"]["sha256"],
        materials_path: contract["materials"]["sha256"],
        bridge_path: contract["bridge"]["sha256"],
        helper_path: contract["bridgeHelper"]["sha256"],
        accepted_proof_path: contract["acceptedProof"]["sha256"],
    }
    for path, digest in expected.items():
        if sha256(path) != digest:
            fail(f"hash drift: {path}")
    if contract["authority"] != "b8a779ad2a25e60aec1b9c6f765027b2ad904db2":
        fail("authority drift")
    if args.preflight_only != (args.process_id == "PREFLIGHT"):
        fail("preflight/process ID mismatch")

    scene_record = load_json(scene_path)
    material_root = load_json(materials_path)
    if scene_record["sourceRevision"] != "blender-art-v07-prepixel-r3":
        fail("source revision drift")
    if scene_record["viewDirection"] != "north":
        fail("direction drift")
    if scene_record["orientationTransform"] != "none":
        fail("orientation drift")
    if scene_record["cycles"] != contract["cycles"]:
        fail("Cycles settings drift")
    if int(scene_record["cycles"]["samples"]) != 64:
        fail("sample count drift")

    bridge = load_bridge_helper(helper_path)
    clean_scene()
    materials = {
        record["id"]: material_from(record)
        for record in material_root["materials"]
    }
    objects = []
    for component in scene_record["components"]:
        material = materials.get(component["materialID"])
        if material is None:
            fail(f"unresolved material: {component['materialID']}")
        obj = bridge.add_component(component)
        obj["play027_group"] = component["group"]
        obj["play027_material_id"] = component["materialID"]
        obj.data.materials.append(material)
        add_bevel(obj, float(component.get("bevel", 0.0)))
        objects.append(obj)

    scene, camera = bridge.configure_camera(scene_record)
    add_light(scene_record, bridge)
    add_shadow(scene_record["shadow"], bridge)
    configure_cycles(scene, scene_record, output_root / "raw.png")
    bpy.context.view_layer.update()
    mapping = object_manifest(
        scene_record["components"],
        objects,
        list(materials),
    )
    projection = projection_report(scene, camera, scene_record, bridge)
    write_json(output_root / "OBJECT-MANIFEST.json", mapping)
    write_json(output_root / "GROUND-PROJECTION.json", projection)

    preflight = {
        "schema": 1,
        "task": "PLAY-027",
        "processID": args.process_id,
        "authority": contract["authority"],
        "sceneSHA256": sha256(scene_path),
        "materialLibrarySHA256": sha256(materials_path),
        "coordinateBridgeSHA256": sha256(bridge_path),
        "acceptedActualCameraProofSHA256": sha256(accepted_proof_path),
        "runnerSHA256": sha256(script_path),
        "contractSHA256": sha256(contract_path),
        "componentCount": mapping["componentCount"],
        "materialCount": mapping["materialCount"],
        "registrationPassed": projection["passed"],
        "renderInvocationCount": 0,
        "sourceAuthority": False,
        "productionSelected": False,
        "passed": True,
    }
    write_json(output_root / "PREFLIGHT.json", preflight)
    if args.preflight_only:
        return
    if args.process_id != "A":
        fail("only process A is authorized")

    bpy.ops.render.render(write_still=True)
    raw_path = output_root / "raw.png"
    provenance = {
        "schema": 1,
        "task": "PLAY-027",
        "contract": "CONTRACT-020",
        "processID": "A",
        "authority": contract["authority"],
        "blender": {
            "version": bpy.app.version_string,
            "buildHash": bpy.app.build_hash.decode("utf-8"),
            "executableSHA256": contract["blender"]["executableSHA256"],
            "pythonVersion": platform.python_version(),
            "machineArchitecture": platform.machine(),
        },
        "inputs": {
            "sceneSHA256": sha256(scene_path),
            "materialLibrarySHA256": sha256(materials_path),
            "coordinateBridgeSHA256": sha256(bridge_path),
            "bridgeHelperSHA256": sha256(helper_path),
            "acceptedActualCameraProofSHA256": sha256(accepted_proof_path),
            "runnerSHA256": sha256(script_path),
            "contractSHA256": sha256(contract_path),
        },
        "cycles": scene_record["cycles"],
        "componentCount": mapping["componentCount"],
        "materialCount": mapping["materialCount"],
        "projectionProofSHA256": sha256(
            output_root / "GROUND-PROJECTION.json"
        ),
        "objectManifestSHA256": sha256(output_root / "OBJECT-MANIFEST.json"),
        "rawFileSHA256": sha256(raw_path),
        "renderInvocationCount": 1,
        "sourceAuthority": False,
        "productionSelected": False,
    }
    write_json(output_root / "provenance.json", provenance)


if __name__ == "__main__":
    main()
