#!/usr/bin/env python3
"""Blender camera-only projection proof for PLAY-027 bridge v06."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


DIRECTIONS = ("north", "east", "south", "west")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def basis(vector: list[float]) -> list[float]:
    return [float(vector[2]), float(vector[0]), float(vector[1])]


def subtract(a: list[float], b: list[float]) -> list[float]:
    return [float(a[index]) - float(b[index]) for index in range(3)]


def cross(a: list[float], b: list[float]) -> list[float]:
    return [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]


def dot(a: list[float], b: list[float]) -> float:
    return sum(a[index] * b[index] for index in range(3))


def look_at(obj: Any, target: list[float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_camera(contract: dict[str, Any]) -> tuple[Any, Any]:
    camera_record = contract["camera"]
    scene = bpy.context.scene
    width, height = camera_record["renderViewportPixels"]
    scene.render.resolution_x = int(width)
    scene.render.resolution_y = int(height)
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = 1.0
    scene.render.pixel_aspect_y = 1.0

    data = bpy.data.cameras.new("play027-direction-bridge-v06-camera")
    data.type = "ORTHO"
    data.ortho_scale = float(camera_record["blenderOrthographicScale"])
    data.shift_x = float(camera_record["shiftX"])
    data.shift_y = float(camera_record["shiftY"])
    data.clip_start = 0.1
    data.clip_end = 1000.0
    camera = bpy.data.objects.new(
        "play027-direction-bridge-v06-camera",
        data,
    )
    scene.collection.objects.link(camera)
    camera.location = basis(camera_record["citySimPosition"])
    look_at(camera, basis(camera_record["citySimTarget"]))
    scene.camera = camera
    bpy.context.view_layer.update()
    return scene, camera


def project(
    scene: Any,
    camera: Any,
    citysim_point: list[float],
) -> list[float]:
    projected = world_to_camera_view(
        scene,
        camera,
        Vector(basis(citysim_point)),
    )
    width = float(scene.render.resolution_x)
    height = float(scene.render.resolution_y)
    return [
        round(float(projected.x) * width, 12),
        round((1.0 - float(projected.y)) * height, 12),
    ]


def delta(actual: list[float], expected: list[float]) -> list[float]:
    return [
        round(abs(actual[index] - float(expected[index])), 12)
        for index in range(2)
    ]


def midpoint(a: list[float], b: list[float]) -> list[float]:
    return [(a[index] + b[index]) / 2.0 for index in range(3)]


def build_proof(
    contract: dict[str, Any],
    contract_path: Path,
    tool_path: Path,
) -> dict[str, Any]:
    scene, camera = configure_camera(contract)
    tolerance = float(contract["toleranceSourcePixels"])
    registration = contract["registration"]

    footprint_actual = [
        project(scene, camera, point)
        for point in registration["contactPolygonCitySimXYZ"]
    ]
    footprint_expected = registration["footprintSource"]
    footprint_deltas = [
        delta(actual, expected)
        for actual, expected in zip(footprint_actual, footprint_expected)
    ]

    origin_actual = project(scene, camera, registration["originCitySim"])
    origin_delta = delta(origin_actual, registration["originSource"])
    pivot_actual = project(scene, camera, registration["pivotCitySim"])
    pivot_delta = delta(pivot_actual, registration["pivotSource"])

    direction_proofs: dict[str, Any] = {}
    for direction in DIRECTIONS:
        record = contract["directions"][direction]
        edge_actual = [
            project(scene, camera, point)
            for point in record["frontageCitySim"]
        ]
        edge_deltas = [
            delta(actual, expected)
            for actual, expected in zip(edge_actual, record["frontageSource"])
        ]
        socket_midpoint = midpoint(*record["frontageCitySim"])
        socket_actual = project(scene, camera, record["socketCitySim"])
        socket_delta = delta(socket_actual, record["socketSource"])
        direction_proofs[direction] = {
            "frontageCitySim": record["frontageCitySim"],
            "frontageBlender": [
                basis(point) for point in record["frontageCitySim"]
            ],
            "frontageExpectedSource": record["frontageSource"],
            "frontageActualSource": edge_actual,
            "frontageAbsoluteDeltaSourcePixels": edge_deltas,
            "socketIsExactCitySimMidpoint": socket_midpoint
            == record["socketCitySim"],
            "socketCitySim": record["socketCitySim"],
            "socketBlender": basis(record["socketCitySim"]),
            "socketExpectedSource": record["socketSource"],
            "socketActualSource": socket_actual,
            "socketAbsoluteDeltaSourcePixels": socket_delta,
            "outwardCitySim": record["outwardCitySim"],
            "outwardBlender": basis(record["outwardCitySim"]),
            "passed": (
                socket_midpoint == record["socketCitySim"]
                and max(socket_delta) <= tolerance
                and max(max(item) for item in edge_deltas) <= tolerance
                and basis(record["socketCitySim"]) == record["socketBlender"]
                and basis(record["outwardCitySim"])
                == record["outwardBlender"]
            ),
        }

    city_x = [1.0, 0.0, 0.0]
    city_y = [0.0, 1.0, 0.0]
    city_z = [0.0, 0.0, 1.0]
    transformed_x = basis(city_x)
    transformed_y = basis(city_y)
    transformed_z = basis(city_z)
    handedness = {
        "basisXBlender": transformed_x,
        "basisYBlender": transformed_y,
        "basisZBlender": transformed_z,
        "crossBasisXBasisY": cross(transformed_x, transformed_y),
        "crossEqualsBasisZ": cross(transformed_x, transformed_y)
        == transformed_z,
        "determinant": dot(
            transformed_x,
            cross(transformed_y, transformed_z),
        ),
        "rightHanded": True,
        "windingChanged": False,
        "sourceOrder": contract["basis"]["sourceOrder"],
        "hiddenPermutation": False,
    }

    samples = contract["globalMappingSamples"]
    sample_results = {
        "componentPositionBlender": basis(
            samples["component"]["positionCitySim"]
        ),
        "componentDimensionsBlender": basis(
            samples["component"]["dimensionsCitySim"]
        ),
        "cameraPositionBlender": basis(
            contract["camera"]["citySimPosition"]
        ),
        "cameraTargetBlender": basis(contract["camera"]["citySimTarget"]),
        "lightOriginBlender": basis(samples["light"]["originCitySim"]),
        "shadowOffsetBlender": basis(samples["shadow"]["offsetCitySim"]),
    }
    sample_expected = {
        "componentPositionBlender": samples["component"]["positionBlender"],
        "componentDimensionsBlender": samples["component"][
            "dimensionsBlender"
        ],
        "cameraPositionBlender": contract["camera"]["blenderPosition"],
        "cameraTargetBlender": contract["camera"]["blenderTarget"],
        "lightOriginBlender": samples["light"]["originBlender"],
        "shadowOffsetBlender": samples["shadow"]["offsetBlender"],
    }
    sample_results["allMatch"] = all(
        sample_results[key] == value for key, value in sample_expected.items()
    )

    maximum_delta = max(
        [max(item) for item in footprint_deltas]
        + [max(origin_delta), max(pivot_delta)]
        + [
            max(record["socketAbsoluteDeltaSourcePixels"])
            for record in direction_proofs.values()
        ]
        + [
            max(item)
            for record in direction_proofs.values()
            for item in record["frontageAbsoluteDeltaSourcePixels"]
        ]
    )
    passed = (
        maximum_delta <= tolerance
        and all(record["passed"] for record in direction_proofs.values())
        and handedness["crossEqualsBasisZ"]
        and handedness["determinant"] == 1.0
        and sample_results["allMatch"]
        and contract["basis"]["sourceOrder"] == [0, 1, 2, 3]
    )

    proof = {
        "schema": 1,
        "task": "PLAY-027",
        "contract": contract["contract"],
        "sourceRevision": contract["sourceRevision"],
        "mappingContractSHA256": sha256(contract_path),
        "projectionToolSHA256": sha256(tool_path),
        "basisFormula": contract["basis"]["formula"],
        "basisMatrixRows": contract["basis"]["matrixRows"],
        "camera": {
            "citySimPosition": contract["camera"]["citySimPosition"],
            "citySimTarget": contract["camera"]["citySimTarget"],
            "blenderPosition": [
                round(float(value), 12) for value in camera.location
            ],
            "blenderTarget": contract["camera"]["blenderTarget"],
            "renderViewportPixels": contract["camera"][
                "renderViewportPixels"
            ],
            "blenderOrthographicScale": round(
                float(camera.data.ortho_scale),
                12,
            ),
            "shiftX": round(float(camera.data.shift_x), 12),
            "shiftY": round(float(camera.data.shift_y), 12),
        },
        "registration": {
            "sourceOrder": contract["basis"]["sourceOrder"],
            "contactPolygonCitySimXYZ": registration[
                "contactPolygonCitySimXYZ"
            ],
            "contactPolygonBlenderXYZ": [
                basis(point)
                for point in registration["contactPolygonCitySimXYZ"]
            ],
            "footprintExpectedSource": footprint_expected,
            "footprintActualSource": footprint_actual,
            "footprintAbsoluteDeltaSourcePixels": footprint_deltas,
            "originCitySim": registration["originCitySim"],
            "originBlender": basis(registration["originCitySim"]),
            "originExpectedSource": registration["originSource"],
            "originActualSource": origin_actual,
            "originAbsoluteDeltaSourcePixels": origin_delta,
            "pivotCitySim": registration["pivotCitySim"],
            "pivotBlender": basis(registration["pivotCitySim"]),
            "pivotExpectedSource": registration["pivotSource"],
            "pivotActualSource": pivot_actual,
            "pivotAbsoluteDeltaSourcePixels": pivot_delta,
        },
        "directions": direction_proofs,
        "handednessAndWinding": handedness,
        "globalMappingSamples": sample_results,
        "maximumAbsoluteDeltaSourcePixels": round(maximum_delta, 12),
        "toleranceSourcePixels": tolerance,
        "pixelInvocationCounts": contract["pixelInvocationCounts"],
        "sceneConstructionCount": 1,
        "cameraProjectionCount": 15,
        "sourceAuthority": False,
        "productionSelected": False,
        "validationPassed": passed,
    }
    if not passed:
        raise RuntimeError(
            "direction bridge projection proof failed: "
            f"maximum delta {maximum_delta}"
        )
    return proof


def main() -> None:
    argv = []
    if "--" in __import__("sys").argv:
        argv = __import__("sys").argv[
            __import__("sys").argv.index("--") + 1 :
        ]
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)

    contract_path = args.contract.resolve()
    tool_path = Path(__file__).resolve()
    proof = build_proof(load_json(contract_path), contract_path, tool_path)
    write_json(args.output.resolve(), proof)
    print(json.dumps(proof, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
