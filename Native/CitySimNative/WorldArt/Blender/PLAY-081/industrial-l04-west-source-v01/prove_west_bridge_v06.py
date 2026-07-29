#!/usr/bin/env python3
"""Camera-only, zero-pixel proof for PLAY-081 West bridge adoption."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--runner-contract", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(values)


def repository_path(root: Path, relative: str) -> Path:
    if not relative or Path(relative).is_absolute():
        raise ValueError(f"path must be repository-relative: {relative!r}")
    path = (root / relative).resolve()
    path.relative_to(root)
    return path


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_bridge(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("play081_west_bridge_v06", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load PLAY-081 v06 bridge")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def configure_camera(mapping: dict[str, Any], bridge: Any) -> tuple[Any, Any]:
    camera_record = mapping["camera"]
    scene = bpy.context.scene
    width, height = camera_record["renderViewportPixels"]
    scene.render.resolution_x = int(width)
    scene.render.resolution_y = int(height)
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = 1.0
    scene.render.pixel_aspect_y = 1.0

    data = bpy.data.cameras.new("PLAY-081-West-v06-Proof-Camera")
    data.type = "ORTHO"
    data.ortho_scale = float(camera_record["blenderOrthographicScale"])
    data.shift_x = float(camera_record["shiftX"])
    data.shift_y = float(camera_record["shiftY"])
    data.clip_start = 0.1
    data.clip_end = 1000.0
    camera = bpy.data.objects.new("PLAY-081-West-v06-Proof-Camera", data)
    scene.collection.objects.link(camera)
    camera.location = bridge.citysim_to_blender(camera_record["citySimPosition"])
    target = bridge.citysim_to_blender(camera_record["citySimTarget"])
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    bpy.context.view_layer.update()
    return scene, camera


def project(scene: Any, camera: Any, point: list[float], bridge: Any) -> list[float]:
    projected = world_to_camera_view(
        scene,
        camera,
        Vector(bridge.citysim_to_blender(point)),
    )
    return [
        round(float(projected.x) * float(scene.render.resolution_x), 12),
        round((1.0 - float(projected.y)) * float(scene.render.resolution_y), 12),
    ]


def delta(actual: list[float], expected: list[float]) -> list[float]:
    return [
        round(abs(float(actual[index]) - float(expected[index])), 12)
        for index in range(2)
    ]


def midpoint(a: list[float], b: list[float]) -> list[float]:
    return [(float(a[index]) + float(b[index])) / 2.0 for index in range(3)]


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    runner_path = repository_path(root, args.runner_contract)
    runner = load_json(runner_path)
    binding = runner["coordinateBridge"]["v06"]
    mapping_path = repository_path(root, binding["mappingContractPath"])
    adapter_path = repository_path(root, binding["adapterPath"])
    mapping = load_json(mapping_path)
    bridge = load_bridge(adapter_path)

    if sha256(mapping_path) != binding["mappingContractSha256"]:
        raise RuntimeError("accepted v06 mapping contract hash mismatch")
    if sha256(adapter_path) != binding["adapterSha256"]:
        raise RuntimeError("West v06 adapter hash mismatch")
    if mapping["basis"]["formula"] != bridge.BASIS_FORMULA:
        raise RuntimeError("v06 basis formula mismatch")
    if tuple(mapping["basis"]["sourceOrder"]) != bridge.SOURCE_ORDER:
        raise RuntimeError("v06 source order mismatch")

    scene, camera = configure_camera(mapping, bridge)
    registration = mapping["registration"]
    west = mapping["directions"]["west"]
    tolerance = float(mapping["toleranceSourcePixels"])

    footprint_actual = [
        project(scene, camera, point, bridge)
        for point in registration["contactPolygonCitySimXYZ"]
    ]
    footprint_delta = [
        delta(actual, expected)
        for actual, expected in zip(
            footprint_actual,
            registration["footprintSource"],
        )
    ]
    origin_actual = project(scene, camera, registration["originCitySim"], bridge)
    origin_delta = delta(origin_actual, registration["originSource"])
    pivot_actual = project(scene, camera, registration["pivotCitySim"], bridge)
    pivot_delta = delta(pivot_actual, registration["pivotSource"])
    frontage_actual = [
        project(scene, camera, point, bridge) for point in west["frontageCitySim"]
    ]
    frontage_delta = [
        delta(actual, expected)
        for actual, expected in zip(frontage_actual, west["frontageSource"])
    ]
    socket_actual = project(scene, camera, west["socketCitySim"], bridge)
    socket_delta = delta(socket_actual, west["socketSource"])
    maximum_delta = max(
        [max(item) for item in footprint_delta]
        + [max(origin_delta), max(pivot_delta), max(socket_delta)]
        + [max(item) for item in frontage_delta]
    )

    checks = {
        "acceptedCandidate": (
            binding["authorityCommit"]
            == "3e01ca6738d7574718f9aeff4b66771eee109feb"
        ),
        "mappingContractSha256": (
            binding["mappingContractSha256"]
            == "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
        ),
        "basisFormula": bridge.BASIS_FORMULA == "B(CitySim[x,y,z])=Blender[z,x,y]",
        "sourceOrder": list(bridge.SOURCE_ORDER) == [0, 1, 2, 3],
        "noPerDirectionTransform": mapping["basis"]["perDirectionTransforms"] is False,
        "noWindingChange": mapping["basis"]["windingChange"] is False,
        "westSocketIsFrontageMidpoint": (
            midpoint(*west["frontageCitySim"]) == west["socketCitySim"]
        ),
        "westSocketCitySim": west["socketCitySim"] == [-28, 0, 0],
        "westSocketBlender": (
            list(bridge.citysim_to_blender(west["socketCitySim"]))
            == [0.0, -28.0, 0.0]
            == [float(value) for value in west["socketBlender"]]
        ),
        "westSocketSource": west["socketSource"] == [640, 704],
        "projectionWithinTolerance": maximum_delta <= tolerance,
        "renderApiCalls": 0,
        "pixelFiles": 0,
    }
    passed = all(
        value is True for value in checks.values() if isinstance(value, bool)
    )
    proof = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "proof": "V06_ACTUAL_CAMERA_ZERO_PIXEL",
        "acceptedBridgeCandidate": binding["authorityCommit"],
        "acceptanceSha256": binding["acceptanceSha256"],
        "authoritySha256": binding["authoritySha256"],
        "mappingContractPath": binding["mappingContractPath"],
        "mappingContractSha256": binding["mappingContractSha256"],
        "runnerContractSha256": sha256(runner_path),
        "adapterSha256": sha256(adapter_path),
        "proofToolSha256": sha256(Path(__file__).resolve()),
        "basisFormula": bridge.BASIS_FORMULA,
        "sourceOrder": list(bridge.SOURCE_ORDER),
        "camera": {
            "citySimPosition": mapping["camera"]["citySimPosition"],
            "citySimTarget": mapping["camera"]["citySimTarget"],
            "blenderPosition": [
                round(float(value), 12) for value in camera.location
            ],
            "blenderTarget": mapping["camera"]["blenderTarget"],
            "renderViewportPixels": mapping["camera"]["renderViewportPixels"],
            "blenderOrthographicScale": round(float(camera.data.ortho_scale), 12),
            "shiftX": round(float(camera.data.shift_x), 12),
            "shiftY": round(float(camera.data.shift_y), 12),
        },
        "registration": {
            "contactPolygonCitySimXYZ": registration["contactPolygonCitySimXYZ"],
            "contactPolygonBlenderXYZ": [
                list(bridge.citysim_to_blender(point))
                for point in registration["contactPolygonCitySimXYZ"]
            ],
            "footprintExpectedSource": registration["footprintSource"],
            "footprintActualSource": footprint_actual,
            "footprintAbsoluteDeltaSourcePixels": footprint_delta,
            "originExpectedSource": registration["originSource"],
            "originActualSource": origin_actual,
            "originAbsoluteDeltaSourcePixels": origin_delta,
            "pivotExpectedSource": registration["pivotSource"],
            "pivotActualSource": pivot_actual,
            "pivotAbsoluteDeltaSourcePixels": pivot_delta,
        },
        "west": {
            "frontageCitySim": west["frontageCitySim"],
            "frontageBlender": [
                list(bridge.citysim_to_blender(point))
                for point in west["frontageCitySim"]
            ],
            "frontageExpectedSource": west["frontageSource"],
            "frontageActualSource": frontage_actual,
            "frontageAbsoluteDeltaSourcePixels": frontage_delta,
            "socketCitySim": west["socketCitySim"],
            "socketBlender": list(bridge.citysim_to_blender(west["socketCitySim"])),
            "socketExpectedSource": west["socketSource"],
            "socketActualSource": socket_actual,
            "socketAbsoluteDeltaSourcePixels": socket_delta,
            "outwardCitySim": west["outwardCitySim"],
            "outwardBlender": list(
                bridge.citysim_to_blender(west["outwardCitySim"])
            ),
        },
        "maximumAbsoluteDeltaSourcePixels": round(maximum_delta, 12),
        "toleranceSourcePixels": tolerance,
        "checks": checks,
        "invocations": {
            "blenderProjectionProcesses": 1,
            "blenderRenderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "renderInvocations": 0,
            "pixelFiles": 0,
        },
        "sourceReady": False,
        "productionSelected": False,
        "passed": passed,
    }
    output = repository_path(root, args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(proof, indent=2, sort_keys=True) + "\n")
    print(json.dumps(proof, indent=2, sort_keys=True))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
