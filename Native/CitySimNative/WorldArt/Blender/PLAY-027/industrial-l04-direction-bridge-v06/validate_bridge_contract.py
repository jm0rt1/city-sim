#!/usr/bin/env python3
"""Fail-closed static validation for the PLAY-027 v06 coordinate bridge."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


DIRECTIONS = ("north", "east", "south", "west")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def basis(vector: list[float]) -> list[float]:
    if len(vector) != 3:
        raise ValueError("basis requires exactly three coordinates")
    return [vector[2], vector[0], vector[1]]


def midpoint(a: list[float], b: list[float]) -> list[float]:
    return [(a[index] + b[index]) / 2.0 for index in range(3)]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, required=True)
    args = parser.parse_args()

    contract = load_json(args.contract)
    require(contract["schema"] == 1, "unexpected schema")
    require(contract["task"] == "PLAY-027", "unexpected task")
    require(
        contract["basis"]["formula"]
        == "B(CitySim[x,y,z])=Blender[z,x,y]",
        "basis formula drift",
    )
    require(
        contract["basis"]["matrixRows"]
        == [[0, 0, 1], [1, 0, 0], [0, 1, 0]],
        "basis matrix drift",
    )
    require(contract["basis"]["determinant"] == 1, "basis must be right-handed")
    require(
        contract["basis"]["sourceOrder"] == [0, 1, 2, 3],
        "hidden footprint permutation",
    )
    require(
        contract["basis"]["perDirectionTransforms"] is False,
        "per-direction transform forbidden",
    )
    require(
        contract["basis"]["windingChange"] is False,
        "winding change forbidden",
    )

    camera = contract["camera"]
    require(
        basis(camera["citySimPosition"]) == camera["blenderPosition"],
        "camera position does not use global basis",
    )
    require(
        basis(camera["citySimTarget"]) == camera["blenderTarget"],
        "camera target does not use global basis",
    )
    width, height = camera["renderViewportPixels"]
    expected_ortho = (
        2.0
        * camera["sceneKitOrthographicScale"]
        * (float(width) / float(height))
    )
    require(
        abs(expected_ortho - camera["blenderOrthographicScale"]) <= 1.0e-12,
        "orthographic scale formula drift",
    )
    require(
        abs(camera["shiftX"]) <= 1.0e-15
        and abs(
            camera["shiftY"]
            - camera["postProjectionOffsetPixels"][1] / float(width)
        )
        <= 1.0e-15,
        "camera shift formula drift",
    )

    registration = contract["registration"]
    expanded = [[pair[0], 0, pair[1]] for pair in registration["contactPolygonCitySimXZ"]]
    require(
        expanded == registration["contactPolygonCitySimXYZ"],
        "contact pairs must expand without reorder",
    )
    require(
        [basis(point) for point in expanded]
        == registration["contactPolygonBlenderXYZ"],
        "contact polygon does not use global basis",
    )
    require(
        basis(registration["pivotCitySim"]) == registration["pivotBlender"],
        "pivot does not use global basis",
    )
    require(
        basis(registration["originCitySim"]) == registration["originBlender"],
        "origin does not use global basis",
    )

    require(
        tuple(contract["directions"]) == DIRECTIONS,
        "directions must retain canonical N/E/S/W order",
    )
    for direction in DIRECTIONS:
        record = contract["directions"][direction]
        require(
            midpoint(*record["frontageCitySim"]) == record["socketCitySim"],
            f"{direction} socket is not frontage midpoint",
        )
        require(
            basis(record["socketCitySim"]) == record["socketBlender"],
            f"{direction} socket does not use global basis",
        )
        require(
            basis(record["outwardCitySim"]) == record["outwardBlender"],
            f"{direction} normal does not use global basis",
        )

    samples = contract["globalMappingSamples"]
    component = samples["component"]
    require(
        basis(component["positionCitySim"]) == component["positionBlender"],
        "component position does not use global basis",
    )
    require(
        basis(component["dimensionsCitySim"]) == component["dimensionsBlender"],
        "component dimensions do not use global basis",
    )
    require(
        basis(samples["light"]["originCitySim"])
        == samples["light"]["originBlender"],
        "light does not use global basis",
    )
    require(
        basis(samples["shadow"]["offsetCitySim"])
        == samples["shadow"]["offsetBlender"],
        "shadow does not use global basis",
    )
    require(
        all(value == 0 for value in contract["pixelInvocationCounts"].values()),
        "pixel invocation count must remain zero",
    )
    require(contract["sourceAuthority"] is False, "source authority forbidden")
    require(
        contract["productionSelected"] is False,
        "production selection forbidden",
    )

    result = {
        "schema": 1,
        "task": "PLAY-027",
        "contractSHA256": sha256(args.contract),
        "basisValidated": True,
        "cameraValidated": True,
        "registrationValidated": True,
        "directionCount": len(DIRECTIONS),
        "globalMappingSamplesValidated": True,
        "pixelInvocationCount": 0,
        "sourceAuthority": False,
        "productionSelected": False,
        "validationPassed": True,
    }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
