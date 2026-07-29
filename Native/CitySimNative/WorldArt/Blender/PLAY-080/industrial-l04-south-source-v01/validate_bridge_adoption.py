#!/usr/bin/env python3
"""Validate PLAY-080 South adoption of the accepted v06 coordinate bridge.

Both modes are zero-pixel. The actual-camera mode may run inside Blender only
to construct an orthographic camera and call world_to_camera_view.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import platform
import sys
from pathlib import Path
from typing import Any


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
DEFAULT_CONTRACT = SOURCE_DIR / "runner-contract.json"


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("static", "actual-camera"), required=True)
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def repository_path(display_path: str) -> Path:
    path = (REPOSITORY_ROOT / display_path).resolve()
    path.relative_to(REPOSITORY_ROOT)
    return path


def add_check(
    checks: list[dict[str, Any]], name: str, passed: bool, details: Any
) -> None:
    checks.append({"name": name, "pass": bool(passed), "details": details})


def bridge_point(point: list[float], bridge: dict[str, Any]) -> list[float]:
    order = bridge["citysimToBlenderAxisOrder"]
    signs = bridge["citysimToBlenderAxisSigns"]
    return [point[order[index]] * signs[index] for index in range(3)]


def common_report(contract: dict[str, Any], mode: str) -> dict[str, Any]:
    return {
        "schema": "citysim.play-080.south-bridge-adoption-proof.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "mode": mode,
        "baselineCommit": contract["baselineCommit"],
        "renderInvocations": 0,
        "blenderRenderApiCalls": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "pixelFiles": 0,
        "processA": "not_run",
        "processB": "not_run",
        "processC": "not_run",
    }


def static_proof(contract: dict[str, Any]) -> dict[str, Any]:
    checks: list[dict[str, Any]] = []
    bridge = contract["coordinateBridge"]
    authorities = contract["authorities"]
    mapping_path = repository_path(bridge["mappingContractPath"])
    mapping = load_json(mapping_path)
    south = mapping["directions"]["south"]

    add_check(
        checks,
        "accepted-v06-candidate-binding",
        bridge.get("state") == "v06_revalidated"
        and bridge.get("acceptedCandidateCommit")
        == "3e01ca6738d7574718f9aeff4b66771eee109feb"
        and bridge.get("mappingContractSha256")
        == "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
        and sha256(mapping_path) == bridge.get("mappingContractSha256"),
        {
            "state": bridge.get("state"),
            "acceptedCandidateCommit": bridge.get("acceptedCandidateCommit"),
            "mappingContractSha256": sha256(mapping_path),
        },
    )
    add_check(
        checks,
        "versioned-integration-schema-binding",
        authorities["handoffSchema"]["path"]
        == "docs/production/evidence/INTEGRATION/industrial-l04-prelock-runner-handoff-schema-v1.json"
        and authorities["handoffSchema"]["sha256"]
        == "05a4a5027a677536ed3370c51ccfcb0a9435c6c4cac5c47bf193377cc5af4951"
        and sha256(repository_path(authorities["handoffSchema"]["path"]))
        == authorities["handoffSchema"]["sha256"],
        authorities["handoffSchema"],
    )
    add_check(
        checks,
        "accepted-global-basis",
        bridge.get("formula") == "B(CitySim[x,y,z])=Blender[z,x,y]"
        and bridge.get("matrixRows") == [[0, 0, 1], [1, 0, 0], [0, 1, 0]]
        and bridge.get("determinant") == 1
        and bridge.get("sourceOrder") == [0, 1, 2, 3]
        and bridge.get("citysimToBlenderAxisOrder") == [2, 0, 1]
        and bridge.get("citysimToBlenderAxisSigns") == [1, 1, 1],
        {
            "formula": bridge.get("formula"),
            "matrixRows": bridge.get("matrixRows"),
            "determinant": bridge.get("determinant"),
            "sourceOrder": bridge.get("sourceOrder"),
        },
    )
    add_check(
        checks,
        "canonical-south-bridge",
        south.get("socketCitySim") == [0, 0, 28]
        and south.get("socketBlender") == [28, 0, 0]
        and south.get("socketSource") == [640, 832]
        and south.get("outwardCitySim") == [0, 0, 1]
        and south.get("outwardBlender") == [1, 0, 0]
        and bridge_point(south["socketCitySim"], bridge) == south["socketBlender"],
        south,
    )
    add_check(
        checks,
        "camera-and-registration-bound-to-v06",
        contract["invariants"]["camera"]["citysimPosition"]
        == [96, 101.24557426726288, 96]
        and contract["invariants"]["camera"]["citysimTarget"]
        == [0, 22.861902498201186, 0]
        and contract["invariants"]["registration"]["canonicalCitySimFrontage"][
            "socket"
        ]
        == [0, 0, 28]
        and contract["invariants"]["registration"]["blenderNativeFrontage"]["socket"]
        == [28, 0, 0],
        {
            "camera": contract["invariants"]["camera"],
            "registration": contract["invariants"]["registration"],
        },
    )
    add_check(
        checks,
        "historical-predesign-adapter-not-source-authority",
        contract["acceptedPredesign"]["authorityScope"]
        == "historical-zero-pixel-predesign-only"
        and contract["acceptedPredesign"]["projectionAdapterSourceAuthority"] is False
        and bridge["historicalPredesignProjectionAdapterSourceAuthority"] is False,
        {
            "acceptedPredesign": contract["acceptedPredesign"]["authorityScope"],
            "projectionAdapterSourceAuthority": contract["acceptedPredesign"][
                "projectionAdapterSourceAuthority"
            ],
        },
    )
    report = common_report(contract, "static-zero-pixel")
    report["blenderProcessLaunches"] = 0
    report["checks"] = checks
    report["result"] = "PASS" if all(check["pass"] for check in checks) else "FAIL"
    return report


def actual_camera_proof(contract: dict[str, Any]) -> dict[str, Any]:
    import bpy
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector

    bridge = contract["coordinateBridge"]
    mapping = load_json(repository_path(bridge["mappingContractPath"]))
    camera_contract = mapping["camera"]
    registration = mapping["registration"]
    south = mapping["directions"]["south"]
    tolerance = mapping["toleranceSourcePixels"]

    scene = bpy.context.scene
    scene.render.resolution_x = camera_contract["renderViewportPixels"][0]
    scene.render.resolution_y = camera_contract["renderViewportPixels"][1]
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = 1
    scene.render.pixel_aspect_y = 1

    camera_data = bpy.data.cameras.new("PLAY080SouthBridgeCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = camera_contract["blenderOrthographicScale"]
    camera_data.shift_x = camera_contract["shiftX"]
    camera_data.shift_y = camera_contract["shiftY"]
    camera = bpy.data.objects.new("PLAY080SouthBridgeCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = camera_contract["blenderPosition"]
    target = Vector(camera_contract["blenderTarget"])
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    bpy.context.view_layer.update()

    width, height = camera_contract["renderViewportPixels"]

    def project(citysim_point: list[float]) -> list[float]:
        blender_point = Vector(bridge_point(citysim_point, bridge))
        projected = world_to_camera_view(scene, camera, blender_point)
        return [projected.x * width, (1 - projected.y) * height]

    def max_delta(actual: list[list[float]], expected: list[list[float]]) -> float:
        return max(
            abs(actual[index][axis] - expected[index][axis])
            for index in range(len(expected))
            for axis in range(2)
        )

    footprint_actual = [
        project(point) for point in registration["contactPolygonCitySimXYZ"]
    ]
    footprint_expected = registration["footprintSource"]
    origin_actual = project(registration["originCitySim"])
    pivot_actual = project(registration["pivotCitySim"])
    socket_actual = project(south["socketCitySim"])
    frontage_actual = [project(point) for point in south["frontageCitySim"]]

    checks: list[dict[str, Any]] = []
    add_check(
        checks,
        "actual-camera-unpermuted-footprint",
        max_delta(footprint_actual, footprint_expected) <= tolerance,
        {
            "actual": footprint_actual,
            "expected": footprint_expected,
            "maximumDeltaSourcePixels": max_delta(
                footprint_actual, footprint_expected
            ),
            "toleranceSourcePixels": tolerance,
            "sourceOrder": bridge["sourceOrder"],
        },
    )
    for name, actual, expected in (
        ("origin", origin_actual, registration["originSource"]),
        ("pivot", pivot_actual, registration["pivotSource"]),
        ("south-socket", socket_actual, south["socketSource"]),
    ):
        delta = max(abs(actual[index] - expected[index]) for index in range(2))
        add_check(
            checks,
            f"actual-camera-{name}",
            delta <= tolerance,
            {
                "actual": actual,
                "expected": expected,
                "maximumDeltaSourcePixels": delta,
                "toleranceSourcePixels": tolerance,
            },
        )
    add_check(
        checks,
        "actual-camera-south-frontage",
        max_delta(frontage_actual, south["frontageSource"]) <= tolerance,
        {
            "actual": frontage_actual,
            "expected": south["frontageSource"],
            "maximumDeltaSourcePixels": max_delta(
                frontage_actual, south["frontageSource"]
            ),
            "toleranceSourcePixels": tolerance,
        },
    )

    report = common_report(contract, "blender-actual-camera-zero-pixel")
    report["blenderProcessLaunches"] = 1
    report["blenderVersion"] = bpy.app.version_string
    report["blenderBuildHash"] = bpy.app.build_hash.decode("utf-8")
    report["pythonVersion"] = platform.python_version()
    report["camera"] = camera_contract
    report["checks"] = checks
    report["result"] = "PASS" if all(check["pass"] for check in checks) else "FAIL"
    return report


def main() -> int:
    args = parse_args()
    contract = load_json(args.contract)
    report = (
        static_proof(contract)
        if args.mode == "static"
        else actual_camera_proof(contract)
    )
    report["inputs"] = {
        "contractPath": args.contract.resolve().relative_to(REPOSITORY_ROOT).as_posix(),
        "contractSha256": sha256(args.contract),
        "validatorPath": Path(__file__).resolve().relative_to(REPOSITORY_ROOT).as_posix(),
        "validatorSha256": sha256(Path(__file__).resolve()),
        "mappingContractPath": contract["coordinateBridge"]["mappingContractPath"],
        "mappingContractSha256": sha256(
            repository_path(contract["coordinateBridge"]["mappingContractPath"])
        ),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"mode": args.mode, "result": report["result"], "output": str(args.output)}))
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
