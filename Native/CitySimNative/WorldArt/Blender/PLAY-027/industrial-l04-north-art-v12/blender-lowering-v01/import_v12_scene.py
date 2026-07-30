#!/usr/bin/env python3
"""Static Blender import for the frozen PLAY-027 North v12 lowering."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

from lower_v12_scene import (
    canonical_bytes,
    load_json,
    lower_scene,
    sha256,
)


STATIC_CHILD_FILES = [
    "BLENDER-OBJECT-MANIFEST.json",
    "MATERIAL-MANIFEST.json",
    "PROJECTION.json",
    "TOPOLOGY.json",
    "INPUT-BINDINGS.json",
    "VALIDATION.json",
]


def arguments() -> argparse.Namespace:
    values = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument(
        "--process-id", choices=("static-a", "static-b"), required=True
    )
    return parser.parse_args(values)


def exact_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    process_id: str,
    requested: Path,
) -> Path:
    expected = (repository_root / contract["evidenceRoot"] / process_id).absolute()
    if requested.absolute() != expected:
        raise RuntimeError("exact static output root required")
    if requested.is_symlink() or not requested.is_dir():
        raise RuntimeError("launcher-created regular output root required")
    if any(requested.iterdir()):
        raise RuntimeError("static output root must be empty")
    requested.resolve().relative_to(repository_root.resolve())
    return requested


def exclusive_write(root: Path, name: str, value: Any) -> None:
    if name not in STATIC_CHILD_FILES:
        raise RuntimeError(f"unapproved static child output: {name}")
    if root.is_symlink() or not root.is_dir():
        raise RuntimeError("static output root drift")
    path = root / name
    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
        0o644,
    )
    try:
        os.write(descriptor, canonical_bytes(value))
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def look_at(item: Any, target: list[float]) -> None:
    direction = Vector(target) - item.location
    item.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def clear_factory_scene() -> None:
    for item in list(bpy.data.objects):
        bpy.data.objects.remove(item, do_unlink=True)
    for item in list(bpy.data.meshes):
        if item.users == 0:
            bpy.data.meshes.remove(item)
    for item in list(bpy.data.materials):
        if item.users == 0:
            bpy.data.materials.remove(item)


def create_materials(records: list[dict[str, Any]]) -> dict[str, Any]:
    result = {}
    for record in records:
        material = bpy.data.materials.new(record["id"])
        material.diffuse_color = tuple(float(value) for value in record["baseColorRGBA"])
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled is None:
            raise RuntimeError(f"Principled node unavailable: {record['id']}")
        principled.inputs["Base Color"].default_value = tuple(
            float(value) for value in record["baseColorRGBA"]
        )
        principled.inputs["Roughness"].default_value = float(record["roughness"])
        principled.inputs["Metallic"].default_value = float(record["metalness"])
        if "emissionStrength" in record:
            principled.inputs["Emission Color"].default_value = tuple(
                float(value) for value in record["baseColorRGBA"]
            )
            principled.inputs["Emission Strength"].default_value = float(
                record["emissionStrength"]
            )
        result[record["id"]] = material
    return result


def create_mesh_objects(
    mesh_ir: dict[str, Any],
    materials: dict[str, Any],
) -> list[dict[str, Any]]:
    manifest = []
    for record in mesh_ir["objects"]:
        mesh = bpy.data.meshes.new(f"{record['objectName']}-mesh")
        mesh.from_pydata(
            record["verticesBlenderWorld"],
            [],
            record["polygons"],
        )
        mesh.update(calc_edges=True)
        item = bpy.data.objects.new(record["objectName"], mesh)
        bpy.context.scene.collection.objects.link(item)
        item.data.materials.append(materials[record["materialID"]])
        item.location = (0.0, 0.0, 0.0)
        item.rotation_euler = (0.0, 0.0, 0.0)
        item.scale = (1.0, 1.0, 1.0)
        item["play027_semantic_owner_id"] = record["semanticOwnerID"]
        item["play027_physical_component_ids"] = json.dumps(
            record["physicalComponentIDs"], separators=(",", ":")
        )
        manifest.append({
            "objectName": item.name,
            "meshName": mesh.name,
            "semanticOwnerID": record["semanticOwnerID"],
            "physicalComponentIDs": record["physicalComponentIDs"],
            "materialID": record["materialID"],
            "vertexCount": len(mesh.vertices),
            "edgeCount": len(mesh.edges),
            "polygonCount": len(mesh.polygons),
            "identityTransform": (
                list(item.location) == [0.0, 0.0, 0.0]
                and list(item.rotation_euler) == [0.0, 0.0, 0.0]
                and list(item.scale) == [1.0, 1.0, 1.0]
            ),
            "modifierCount": len(item.modifiers),
        })
    return manifest


def create_authored_shadow(mesh_ir: dict[str, Any]) -> dict[str, Any]:
    record = mesh_ir["authoredShadow"]
    mesh = bpy.data.meshes.new(f"{record['id']}-mesh")
    mesh.from_pydata(record["verticesBlenderWorld"], [], [[0, 1, 2, 3]])
    mesh.update(calc_edges=True)
    item = bpy.data.objects.new(record["id"], mesh)
    bpy.context.scene.collection.objects.link(item)
    item["play027_authored_shadow_opacity"] = float(record["opacity"])
    return {
        "objectName": item.name,
        "vertexCount": len(mesh.vertices),
        "polygonCount": len(mesh.polygons),
        "materialCount": len(mesh.materials),
        "identityTransform": True,
    }


def configure_camera(projection: dict[str, Any]) -> tuple[Any, Any]:
    scene = bpy.context.scene
    width, height = projection["resolution"]
    scene.render.resolution_x = int(width)
    scene.render.resolution_y = int(height)
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = 1.0
    scene.render.pixel_aspect_y = 1.0
    data = bpy.data.cameras.new("play027-v12-static-camera")
    data.type = "ORTHO"
    data.ortho_scale = float(projection["orthographicScaleBlender"])
    data.shift_x = float(projection["shiftX"])
    data.shift_y = float(projection["shiftY"])
    data.clip_start = 0.1
    data.clip_end = 1000.0
    camera = bpy.data.objects.new("play027-v12-static-camera", data)
    scene.collection.objects.link(camera)
    camera.location = projection["cameraLocationBlender"]
    look_at(camera, projection["cameraTargetBlender"])
    scene.camera = camera
    bpy.context.view_layer.update()
    return scene, camera


def create_light(mesh_ir: dict[str, Any]) -> dict[str, Any]:
    record = mesh_ir["light"]
    data = bpy.data.lights.new("play027-v12-static-key", "SUN")
    item = bpy.data.objects.new("play027-v12-static-key", data)
    bpy.context.scene.collection.objects.link(item)
    item.location = record["locationBlender"]
    look_at(item, record["targetBlender"])
    return {
        "objectName": item.name,
        "locationBlender": [float(value) for value in item.location],
        "shadowDirection": record["shadowDirection"],
        "shadowVectorSource": record["shadowVectorSource"],
    }


def project(
    scene: Any,
    camera: Any,
    blender_point: list[float],
) -> list[float]:
    result = world_to_camera_view(scene, camera, Vector(blender_point))
    return [
        round(float(result.x) * float(scene.render.resolution_x), 12),
        round(
            (1.0 - float(result.y)) * float(scene.render.resolution_y),
            12,
        ),
    ]


def delta(actual: list[float], expected: list[float]) -> list[float]:
    return [
        round(abs(float(actual[index]) - float(expected[index])), 12)
        for index in range(2)
    ]


def projection_proof(
    scene: Any,
    camera: Any,
    mesh_ir: dict[str, Any],
) -> dict[str, Any]:
    registration = mesh_ir["registration"]
    contact_citysim = [
        [point[0], 0.0, point[1]]
        for point in registration["contactPolygonWorld"]
    ]
    contact_blender = [
        [point[2], point[0], point[1]] for point in contact_citysim
    ]
    footprint = [project(scene, camera, point) for point in contact_blender]
    footprint_deltas = [
        delta(actual, expected)
        for actual, expected in zip(
            footprint, registration["footprintPolygonSource"]
        )
    ]
    pivot_citysim = registration["groundPivotWorld"]
    pivot = project(
        scene, camera,
        [pivot_citysim[2], pivot_citysim[0], pivot_citysim[1]],
    )
    socket_citysim = registration["frontageSocketWorld"]
    socket = project(
        scene, camera,
        [socket_citysim[2], socket_citysim[0], socket_citysim[1]],
    )
    origin = project(scene, camera, [0.0, 0.0, 0.0])
    pivot_delta = delta(pivot, registration["groundPivotSource"])
    socket_delta = delta(socket, registration["frontageSocketSource"])
    origin_delta = delta(origin, mesh_ir["camera"]["originExpectedSource"])
    maximum = max(
        [value for pair in footprint_deltas for value in pair]
        + pivot_delta + socket_delta + origin_delta
    )
    tolerance = float(mesh_ir["camera"]["maximumAllowedErrorSourcePixels"])
    if maximum > tolerance:
        raise RuntimeError(
            f"actual Blender camera registration drift: {maximum}"
        )
    return {
        "footprintActualSource": footprint,
        "footprintExpectedSource": registration["footprintPolygonSource"],
        "footprintAbsoluteDeltaSourcePixels": footprint_deltas,
        "pivotActualSource": pivot,
        "pivotExpectedSource": registration["groundPivotSource"],
        "pivotAbsoluteDeltaSourcePixels": pivot_delta,
        "socketActualSource": socket,
        "socketExpectedSource": registration["frontageSocketSource"],
        "socketAbsoluteDeltaSourcePixels": socket_delta,
        "originActualSource": origin,
        "originExpectedSource": mesh_ir["camera"]["originExpectedSource"],
        "originAbsoluteDeltaSourcePixels": origin_delta,
        "maximumAbsoluteDeltaSourcePixels": maximum,
        "maximumAllowedDeltaSourcePixels": tolerance,
        "passed": True,
    }


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    contract_path = Path(options.contract).resolve(strict=True)
    contract = load_json(contract_path)
    actual_version = bpy.app.version_string
    actual_build_hash = (
        bpy.app.build_hash.decode("utf-8")
        if isinstance(bpy.app.build_hash, bytes)
        else str(bpy.app.build_hash)
    )
    if (
        actual_version != contract["blender"]["version"]
        or actual_build_hash != contract["blender"]["buildHash"]
    ):
        raise RuntimeError(
            f"Blender fingerprint drift: {actual_version} {actual_build_hash}"
        )
    output_root = exact_output_root(
        repository_root,
        contract,
        options.process_id,
        Path(options.output_root),
    )
    lowered = lower_scene(repository_root, contract)
    mesh_ir = lowered["CANONICAL-MESH-IR.json"]
    clear_factory_scene()
    materials = create_materials(mesh_ir["materials"])
    objects = create_mesh_objects(mesh_ir, materials)
    shadow = create_authored_shadow(mesh_ir)
    scene, camera = configure_camera(mesh_ir["camera"])
    light = create_light(mesh_ir)
    bpy.context.view_layer.update()
    projection = projection_proof(scene, camera, mesh_ir)
    if len(objects) != contract["expected"]["semanticObjectCount"]:
        raise RuntimeError("Blender semantic object count drift")
    if any(not item["identityTransform"] for item in objects):
        raise RuntimeError("non-identity imported object transform")
    if any(item["modifierCount"] != 0 for item in objects):
        raise RuntimeError("imported modifier prohibited")
    object_manifest = {
        "schema": 1,
        "task": "PLAY-027",
        "semanticObjectCount": len(objects),
        "physicalComponentCount": contract["expected"]["physicalComponentCount"],
        "objects": objects,
        "authoredShadow": shadow,
        "cameraObject": camera.name,
        "light": light,
        "allIdentityTransforms": True,
        "bevelModifierCount": 0,
        "renderInvocationCount": 0,
    }
    material_manifest = {
        "schema": 1,
        "task": "PLAY-027",
        "materialCount": len(mesh_ir["materials"]),
        "materials": mesh_ir["materials"],
        "allMaterialsMapped": True,
    }
    topology = dict(lowered["TOPOLOGY.json"])
    topology["blenderSemanticMeshObjectCount"] = len(objects)
    topology["blenderMeshPolygonCount"] = sum(
        item["polygonCount"] for item in objects
    )
    topology["blenderBevelModifierCount"] = 0
    input_bindings = dict(lowered["INPUT-BINDINGS.json"])
    input_bindings["staticImporter"] = {
        "file": str(Path(__file__).resolve().relative_to(repository_root)),
        "sha256": sha256(Path(__file__).resolve()),
    }
    input_bindings["loweringTool"] = {
        "file": str(
            (Path(__file__).resolve().parent / "lower_v12_scene.py")
            .relative_to(repository_root)
        ),
        "sha256": sha256(
            Path(__file__).resolve().parent / "lower_v12_scene.py"
        ),
    }
    input_bindings["blenderApplication"] = {
        "version": actual_version,
        "buildHash": actual_build_hash,
        "executableSHA256": contract["blender"]["executableSHA256"],
    }
    validation = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": contract["stage"],
        "gates": {
            "canonicalLoweringReproduced": True,
            "semanticObjectCountExact": True,
            "physicalMappingComplete": True,
            "materialsExact": True,
            "identityObjectTransforms": True,
            "bevelDisabled": True,
            "actualBlenderCameraRegistrationExact": True,
            "blenderFingerprintExact": True,
            "renderDisabled": True,
            "pixelsAbsent": True,
            "blendFilesAbsent": True,
        },
        "validationPassed": True,
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "blendFiles": [],
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    outputs = {
        "BLENDER-OBJECT-MANIFEST.json": object_manifest,
        "MATERIAL-MANIFEST.json": material_manifest,
        "PROJECTION.json": projection,
        "TOPOLOGY.json": topology,
        "INPUT-BINDINGS.json": input_bindings,
        "VALIDATION.json": validation,
    }
    for name in STATIC_CHILD_FILES:
        exclusive_write(output_root, name, outputs[name])
    print(json.dumps({
        "processID": options.process_id,
        "semanticObjectCount": len(objects),
        "materialCount": len(mesh_ir["materials"]),
        "maximumRegistrationDelta": projection[
            "maximumAbsoluteDeltaSourcePixels"
        ],
        "validationPassed": True,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
