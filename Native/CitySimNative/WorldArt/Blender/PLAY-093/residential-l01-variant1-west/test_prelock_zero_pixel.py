#!/usr/bin/env python3
"""Deterministic, zero-pixel Residential L1 West prelock proof."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
REPOSITORY_ROOT = ROOT.parents[5]
SCENE_PATH = ROOT / "scene.json"
REFERENCE_PATH = (
    REPOSITORY_ROOT
    / "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/scenes/"
    "residential_l01/variant-0/west/scene.json"
)
REFERENCE_SHA256 = "be6c207ef15b99dd15b5707eeb21aa674d52fe1df73175f2feab93714a70f288"
EXPECTED_SOCKET_WORLD = [-28, 0, 0]
EXPECTED_SOCKET_SOURCE = [640, 704]
EXPECTED_SOURCE_CENTER = [768, 768]
EXPECTED_FOOTPRINT = [[768, 640], [1024, 768], [768, 896], [512, 768]]
EXPECTED_CONTACT = [[-28, -28], [28, -28], [28, 28], [-28, 28]]
EXPECTED_EXCLUSION = [[-54, -15], [-22, -15], [-22, 15], [-54, 15]]
EXPECTED_CAMERA = {
    "projection": "orthographic-2:1",
    "yawDegrees": 45,
    "elevationDegrees": 30,
    "renderViewportPixels": [1536, 1024],
    "oversamplingFactor": 2,
    "positionWorld": [180, 146.9693845669907, 180],
    "targetWorld": [0, 0, 0],
    "sourceGroundCenter": EXPECTED_SOURCE_CENTER,
    "postProjectionOffsetPixels": [0, 256],
}
EXPECTED_LIGHT = {
    "keyOrigin": [-120, 180, -120],
    "shadowVectorSource": [2, 1],
    "shadowReceiver": "task-owned-transparent-ground-plane",
}
REQUIRED_MATERIAL_ROLES = {
    "wall",
    "trim",
    "roof",
    "foundation",
    "window",
    "door",
    "secondaryVolume",
}


def canonical_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def dot(left: list[float], right: list[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def cross(left: list[float], right: list[float]) -> list[float]:
    return [
        left[1] * right[2] - left[2] * right[1],
        left[2] * right[0] - left[0] * right[2],
        left[0] * right[1] - left[1] * right[0],
    ]


def unit(value: list[float]) -> list[float]:
    length = math.sqrt(dot(value, value))
    if length == 0:
        raise ValueError("zero camera vector")
    return [component / length for component in value]


def close(left: float, right: float, tolerance: float = 1e-6) -> bool:
    return abs(left - right) <= tolerance


def close_vector(left: list[float], right: list[float]) -> bool:
    return len(left) == len(right) and all(close(a, b) for a, b in zip(left, right))


def project_socket(scene: dict) -> dict[str, object]:
    camera = scene["camera"]
    position = [float(value) for value in camera["positionWorld"]]
    target = [float(value) for value in camera["targetWorld"]]
    view = unit([target[index] - position[index] for index in range(3)])
    world_up = [0.0, 1.0, 0.0]
    right = unit(cross(view, world_up))
    true_up = unit(cross(right, view))
    socket = [float(value) for value in scene["registration"]["frontageSocketWorld"]]
    delta = [socket[index] - target[index] for index in range(3)]
    projected_right = dot(delta, right)
    projected_up = dot(delta, true_up)
    source_center = [float(value) for value in camera["sourceGroundCenter"]]
    source_socket = [float(value) for value in scene["registration"]["frontageSocketSource"]]
    if projected_right == 0:
        raise ValueError("socket projects to camera center")
    pixels_per_projected_world = (
        source_socket[0] - source_center[0]
    ) / projected_right
    projected = [
        source_center[0] + projected_right * pixels_per_projected_world,
        source_center[1] - projected_up * pixels_per_projected_world,
    ]
    return {
        "rightBasis": [round(value, 9) for value in right],
        "upBasis": [round(value, 9) for value in true_up],
        "projectedSocket": [round(value, 6) for value in projected],
        "pixelsPerProjectedWorld": round(pixels_per_projected_world, 9),
        "socketWorld": scene["registration"]["frontageSocketWorld"],
        "socketSource": scene["registration"]["frontageSocketSource"],
    }


def validate_scene(scene: dict) -> tuple[list[str], dict[str, object]]:
    errors: list[str] = []
    if scene.get("schema") != 1:
        errors.append("schema")
    for field, expected in (
        ("task", "PLAY-093"),
        ("logicalBuildingID", "residential_l01"),
        ("family", "residential"),
        ("level", 1),
        ("variantID", "variant-1"),
        ("viewDirection", "west"),
        ("sourceRevision", "prelock-v01"),
        ("authoredIndependently", True),
        ("productionSelected", False),
        ("pixelProduction", "not_produced"),
        ("sourceReady", False),
    ):
        if scene.get(field) != expected:
            errors.append(f"identity:{field}")

    derivation = scene.get("derivation", {})
    for field, expected in (
        ("sourceKind", "independent-contract-blockout"),
        ("siblingSource", None),
        ("mirror", False),
        ("rotationDegrees", 0),
        ("transform", "none"),
    ):
        if derivation.get(field) != expected:
            errors.append(f"derivation:{field}")

    registration = scene.get("registration", {})
    for field, expected in (
        ("tileBasisPoints", [72, 36]),
        ("sceneFootprintUnits", [72, 72]),
        ("footprintPolygonSource", EXPECTED_FOOTPRINT),
        ("groundPivotSource", [768, 896]),
        ("contactPolygonWorld", EXPECTED_CONTACT),
        ("frontageEdgeSource", [[512, 768], [768, 640]]),
        ("frontageSocketSource", EXPECTED_SOCKET_SOURCE),
        ("frontageSocketWorld", EXPECTED_SOCKET_WORLD),
        ("frontageNormalWorld", [-1, 0, 0]),
        ("entranceExclusionWorld", EXPECTED_EXCLUSION),
        ("orientationTransform", "none"),
    ):
        if registration.get(field) != expected:
            errors.append(f"registration:{field}")

    camera = scene.get("camera", {})
    for field, expected in EXPECTED_CAMERA.items():
        value = camera.get(field)
        if isinstance(expected, list):
            if value != expected and not close_vector(value or [], expected):
                errors.append(f"camera:{field}")
        elif value != expected:
            errors.append(f"camera:{field}")
    try:
        projection = project_socket(scene)
    except (KeyError, TypeError, ValueError) as error:
        errors.append(f"camera:projection:{error}")
        projection = {}
    else:
        if projection["projectedSocket"] != EXPECTED_SOCKET_SOURCE:
            errors.append("camera:socket-projection")
        if not close(projection["pixelsPerProjectedWorld"], 128 / (28 * math.sqrt(0.5))):
            errors.append("camera:scale")

    light = scene.get("light", {})
    for field, expected in EXPECTED_LIGHT.items():
        if light.get(field) != expected:
            errors.append(f"light:{field}")

    roles = scene.get("materialRoles", {})
    if set(roles) != REQUIRED_MATERIAL_ROLES or len(set(roles.values())) != len(roles):
        errors.append("materials:roles")
    building = scene.get("building", {})
    if building.get("massing") != "offset-cross-gable":
        errors.append("building:massing")
    secondary = building.get("secondaryVolume", {})
    for field in ("id", "kind", "positionWorld", "dimensions", "materialRole"):
        if field not in secondary:
            errors.append(f"building:secondary:{field}")
    if secondary.get("structural") is not True or secondary.get("visibleAtLiteral192") is not True:
        errors.append("building:secondary:visibility")
    if not isinstance(secondary.get("dimensions"), list) or any(
        not isinstance(value, (int, float)) or value <= 0 for value in secondary.get("dimensions", [])
    ):
        errors.append("building:secondary:dimensions")
    silhouette = scene.get("silhouetteBreaks", [])
    if len(silhouette) < 3 or len(set(silhouette)) != len(silhouette):
        errors.append("silhouette:breaks")

    facades = scene.get("facades", [])
    if {facade.get("direction") for facade in facades} != {"north", "east", "south", "west"}:
        errors.append("facades:directions")
    west = next((facade for facade in facades if facade.get("direction") == "west"), None)
    if west is None:
        errors.append("facades:west-missing")
    else:
        if west.get("edgeWorld") != [[-28, 28], [-28, -28]] or not west.get("hasEntrance"):
            errors.append("facades:west-frontage")
        windows = west.get("windowBays", [])
        if len(windows) < 5 or len({window.get("id") for window in windows}) != len(windows):
            errors.append("facades:west-window-rhythm")
        if any(window.get("materialRole") != "window" for window in windows):
            errors.append("facades:west-window-material")

    entrance = scene.get("entrance", {})
    for field, expected in (
        ("facadeID", "west-facade"),
        ("baseWorld", [-28, 3, 0]),
        ("doorMaterialRole", "door"),
        ("surroundMaterialRole", "trim"),
        ("canopyType", "arched-portico"),
    ):
        if entrance.get(field) != expected:
            errors.append(f"entrance:{field}")
    if entrance.get("width", 0) <= 0 or entrance.get("height", 0) <= 0:
        errors.append("entrance:dimensions")
    if scene.get("occlusionExclusions") != [
        {
            "id": "west-entrance-clearance",
            "purpose": "protect declared entrance, steps, and road-facing socket",
            "polygonWorld": EXPECTED_EXCLUSION,
        }
    ]:
        errors.append("occlusion:entrance-clearance")

    if not REFERENCE_PATH.is_file() or REFERENCE_PATH.is_symlink():
        errors.append("reference:missing")
    else:
        reference_bytes = REFERENCE_PATH.read_bytes()
        if sha256_bytes(reference_bytes) != REFERENCE_SHA256:
            errors.append("reference:sha256")
        try:
            reference = json.loads(reference_bytes)
        except json.JSONDecodeError:
            errors.append("reference:json")
        else:
            if reference.get("variantID") != "variant-0" or reference.get("viewDirection") != "west":
                errors.append("reference:identity")
            if scene.get("building") == reference.get("building"):
                errors.append("non-alias:building")
            if scene.get("entrance") == reference.get("entrance"):
                errors.append("non-alias:entrance")

    report = {
        "sceneGeometryID": scene.get("sceneGeometryID"),
        "sceneSHA256": sha256_bytes(SCENE_PATH.read_bytes()),
        "referenceSHA256": REFERENCE_SHA256,
        "cameraSocketProof": projection,
        "footprintPivotProof": {
            "footprintPolygonSource": registration.get("footprintPolygonSource"),
            "groundPivotSource": registration.get("groundPivotSource"),
            "contactPolygonWorld": registration.get("contactPolygonWorld"),
        },
        "silhouetteBreakCount": len(silhouette),
        "westWindowCount": len(west.get("windowBays", [])) if west else 0,
        "zeroPixelBoundary": {
            "blenderProcessStarts": 0,
            "dccInvocations": 0,
            "renderInvocations": 0,
            "pixelFiles": 0,
        },
        "sourceReady": scene.get("sourceReady"),
        "productionSelected": scene.get("productionSelected"),
    }
    return errors, report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeat", type=int, default=2)
    parser.add_argument("--compare-governed-bytes", action="store_true")
    args = parser.parse_args()
    if args.repeat < 2:
        print("FAIL:repeat-must-be-at-least-2")
        return 1
    reports: list[dict[str, object]] = []
    for _ in range(args.repeat):
        try:
            scene = json.loads(SCENE_PATH.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            print(f"FAIL:scene:{error}")
            return 1
        errors, report = validate_scene(scene)
        if errors:
            print(json.dumps({"result": "FAIL", "errors": sorted(set(errors))}, sort_keys=True))
            return 1
        reports.append(report)
    governed_bytes_identical = len({canonical_bytes(report) for report in reports}) == 1
    if args.compare_governed_bytes and not governed_bytes_identical:
        print(json.dumps({"result": "FAIL", "error": "governed-bytes-differ"}, sort_keys=True))
        return 1
    print(
        json.dumps(
            {
                "result": "PASS",
                "repeat": args.repeat,
                "governedBytesIdentical": governed_bytes_identical,
                "report": reports[-1],
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
