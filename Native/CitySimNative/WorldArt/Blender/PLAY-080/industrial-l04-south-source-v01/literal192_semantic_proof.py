#!/usr/bin/env python3
"""Measure the South literal-192 contract from semantic scene geometry.

This module performs analytic orthographic projection and virtual 192x128
semantic-cell sampling. It does not import Blender, call a renderer, or write
pixel files.
"""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path
from typing import Any


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
DEFAULT_CONTRACT = SOURCE_DIR / "runner-contract.json"


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repository_path(display_path: str) -> Path:
    path = (REPOSITORY_ROOT / display_path).resolve()
    path.relative_to(REPOSITORY_ROOT)
    return path


def dot(left: list[float], right: list[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def subtract(left: list[float], right: list[float]) -> list[float]:
    return [a - b for a, b in zip(left, right)]


def cross(left: list[float], right: list[float]) -> list[float]:
    return [
        left[1] * right[2] - left[2] * right[1],
        left[2] * right[0] - left[0] * right[2],
        left[0] * right[1] - left[1] * right[0],
    ]


def normalize(vector: list[float]) -> list[float]:
    length = math.sqrt(dot(vector, vector))
    if length == 0:
        raise ValueError("cannot normalize a zero-length vector")
    return [value / length for value in vector]


def box_corners(component: dict[str, Any]) -> list[list[float]]:
    center = component["center"]
    half = [value / 2 for value in component["size"]]
    return [
        [center[index] + signs[index] * half[index] for index in range(3)]
        for signs in itertools.product((-1, 1), repeat=3)
    ]


def convex_hull(points: list[list[float]]) -> list[list[float]]:
    unique = sorted({(point[0], point[1]) for point in points})
    if len(unique) <= 1:
        return [list(point) for point in unique]

    def turn(
        origin: tuple[float, float],
        left: tuple[float, float],
        right: tuple[float, float],
    ) -> float:
        return (left[0] - origin[0]) * (right[1] - origin[1]) - (
            left[1] - origin[1]
        ) * (right[0] - origin[0])

    lower: list[tuple[float, float]] = []
    for point in unique:
        while len(lower) >= 2 and turn(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    upper: list[tuple[float, float]] = []
    for point in reversed(unique):
        while len(upper) >= 2 and turn(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    return [list(point) for point in lower[:-1] + upper[:-1]]


def point_in_polygon(point: tuple[float, float], polygon: list[list[float]]) -> bool:
    inside = False
    x, y = point
    previous = polygon[-1]
    for current in polygon:
        x1, y1 = previous
        x2, y2 = current
        if (y1 > y) != (y2 > y):
            crossing_x = (x2 - x1) * (y - y1) / (y2 - y1) + x1
            if x < crossing_x:
                inside = not inside
        previous = current
    return inside


def measurement_passes(
    metrics: dict[str, Any], targets: dict[str, Any]
) -> bool:
    portal = metrics["primaryPortalPixels"]
    freight = metrics["freightOpeningWidthsPixels"]
    return (
        portal[0] >= targets["literal192PrimaryPortalMinimumPixels"][0]
        and portal[1] >= targets["literal192PrimaryPortalMinimumPixels"][1]
        and len(freight) == 3
        and min(freight) >= targets["literal192FreightOpeningMinimumWidthPixels"]
        and metrics["frameMinimumThicknessPixels"]
        >= targets["literal192FrameMinimumThicknessPixels"]
        and metrics["silhouetteBreaks"] >= targets["minimumSilhouetteBreaks"]
        and metrics["processOcclusionPixels"]
        == targets["maximumProcessOcclusionPixels"]
    )


def measure_literal192_semantic_proof(
    scene_descriptor: dict[str, Any], contract: dict[str, Any]
) -> dict[str, Any]:
    camera = contract["invariants"]["camera"]
    bridge = contract["coordinateBridge"]
    mapping = load_json(repository_path(bridge["mappingContractPath"]))
    ground_center = mapping["camera"]["sourceGroundCenter"]
    render_width, render_height = camera["renderViewportPixels"]
    literal_width, literal_height = camera["literalViewportPixels"]
    scale_x = render_width / literal_width
    scale_y = render_height / literal_height
    if not math.isclose(scale_x, scale_y):
        raise ValueError("literal viewport must use one uniform scale")

    forward = normalize(
        subtract(camera["citysimTarget"], camera["citysimPosition"])
    )
    right = normalize(cross(forward, [0.0, 1.0, 0.0]))
    up = normalize(cross(right, forward))
    source_scale = render_width / camera["orthoScale"]

    def project(point: list[float]) -> list[float]:
        return [
            (ground_center[0] + dot(point, right) * source_scale) / scale_x,
            (ground_center[1] - dot(point, up) * source_scale) / scale_y,
        ]

    def projected(component: dict[str, Any]) -> dict[str, Any]:
        points = [project(point) for point in box_corners(component)]
        xs = [point[0] for point in points]
        ys = [point[1] for point in points]
        return {
            "bounds": [min(xs), min(ys), max(xs), max(ys)],
            "hull": convex_hull(points),
        }

    by_id = {component["id"]: component for component in scene_descriptor["components"]}
    portal_projection = projected(by_id["monumental-portal-inset"])
    portal_bounds = portal_projection["bounds"]
    primary_portal = [
        portal_bounds[2] - portal_bounds[0],
        portal_bounds[3] - portal_bounds[1],
    ]

    freight_components = [
        component
        for component in scene_descriptor["components"]
        if "freight-opening" in component.get("tags", [])
    ]
    freight_widths = [
        projected(component)["bounds"][2] - projected(component)["bounds"][0]
        for component in freight_components
    ]

    jamb_ids = (
        "monumental-portal-west-jamb",
        "monumental-portal-east-jamb",
    )
    jamb_widths = [
        projected(by_id[component_id])["bounds"][2]
        - projected(by_id[component_id])["bounds"][0]
        for component_id in jamb_ids
    ]
    header_bounds = projected(by_id["monumental-portal-header"])["bounds"]
    header_height = header_bounds[3] - header_bounds[1]
    frame_minimum = min(jamb_widths + [header_height])

    silhouette_rows: list[dict[str, Any]] = []
    for component in scene_descriptor["components"]:
        if "silhouette-break" not in component.get("tags", []):
            continue
        top_center = [
            component["center"][0],
            component["center"][1] + component["size"][1] / 2,
            component["center"][2],
        ]
        silhouette_rows.append(
            {"id": component["id"], "literalRow": project(top_center)[1]}
        )
    silhouette_clusters: list[float] = []
    for row in sorted(item["literalRow"] for item in silhouette_rows):
        if not silhouette_clusters or abs(row - silhouette_clusters[-1]) >= 2:
            silhouette_clusters.append(row)

    occluder_hulls = [
        projected(component)["hull"]
        for component in scene_descriptor["components"]
        if "process-occluder" in component.get("tags", [])
    ]
    occluded_cells = 0
    portal_hull = portal_projection["hull"]
    for y in range(literal_height):
        for x in range(literal_width):
            center = (x + 0.5, y + 0.5)
            if point_in_polygon(center, portal_hull) and any(
                point_in_polygon(center, hull) for hull in occluder_hulls
            ):
                occluded_cells += 1

    return {
        "measurementMethod": "analytic-v06-camera-semantic-cells-v1",
        "primaryPortalPixels": [round(value, 6) for value in primary_portal],
        "freightOpeningWidthsPixels": [
            round(value, 6) for value in freight_widths
        ],
        "frameMinimumThicknessPixels": round(frame_minimum, 6),
        "silhouetteBreaks": len(silhouette_clusters),
        "processOcclusionPixels": occluded_cells,
        "semanticEvidence": {
            "literalViewportPixels": [literal_width, literal_height],
            "freightOpeningIds": [
                component["id"] for component in freight_components
            ],
            "jambProjectedWidthsPixels": [
                round(value, 6) for value in jamb_widths
            ],
            "headerProjectedHeightPixels": round(header_height, 6),
            "silhouetteRows": [
                {
                    "id": item["id"],
                    "literalRow": round(item["literalRow"], 6),
                }
                for item in silhouette_rows
            ],
            "distinctSilhouetteRowsAtLeastTwoPixelsApart": [
                round(value, 6) for value in silhouette_clusters
            ],
            "processOccluderCount": len(occluder_hulls),
            "virtualSemanticCellSamples": literal_width * literal_height,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    contract = load_json(args.contract)
    scene_record = contract["acceptedPredesign"]["scene"]
    scene_path = repository_path(scene_record["path"])
    if sha256(scene_path) != scene_record["sha256"]:
        raise ValueError("accepted South scene hash mismatch")
    mapping_record = contract["coordinateBridge"]
    mapping_path = repository_path(mapping_record["mappingContractPath"])
    if sha256(mapping_path) != mapping_record["mappingContractSha256"]:
        raise ValueError("accepted v06 mapping hash mismatch")

    metrics = measure_literal192_semantic_proof(load_json(scene_path), contract)
    passed = measurement_passes(
        metrics, contract["invariants"]["pixelValidation"]
    )
    report = {
        "schema": "citysim.play-080.literal-192-semantic-proof.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "mode": "analytic-zero-pixel",
        "result": "PASS" if passed else "FAIL",
        "inputs": {
            "runnerContract": {
                "path": args.contract.resolve().relative_to(REPOSITORY_ROOT).as_posix(),
                "sha256": sha256(args.contract),
            },
            "acceptedSouthScene": scene_record,
            "coordinateBridgeMapping": {
                "path": mapping_record["mappingContractPath"],
                "sha256": mapping_record["mappingContractSha256"],
            },
        },
        "metrics": metrics,
        "thresholds": contract["invariants"]["pixelValidation"],
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "renderInvocations": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "pixelFiles": 0,
        "processA": "not_run",
        "processB": "not_run",
        "processC": "not_run",
        "sourceReady": False,
        "productionSelected": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"result": report["result"], "output": str(args.output)}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
