#!/usr/bin/env python3
"""Pure-data South v14 compatibility and lowering proof.

This validator consumes only published semantic/material-role authorities. It
never opens sibling scene geometry, launches Blender, creates pixels, or writes
evidence. The packet is a design/lowering candidate, not source authority.
"""

from __future__ import annotations

import hashlib
import copy
import itertools
import json
import math
import os
from pathlib import Path
from pathlib import PurePosixPath
import subprocess
import sys
import unittest


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parents[6]
PACKET = ROOT
SCENE_PATH = PACKET / "SCENE.json"
MATERIALS_PATH = ROOT.parent / "v13-compatibility-v01" / "MATERIALS.json"
V14_AUTHORITY_PATH = REPO_ROOT / "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-NORTH-V14-HERO-REBUILD-AUTHORITY-V1.md"
V14_TARGET_PATH = REPO_ROOT / "docs/production/evidence/INTEGRATION/industrial-l04-north-v14-hero-target-v1.json"
NORTH_AUTHORITY_PATH = (
    REPO_ROOT
    / "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v13/design-authority-v01/DESIGN-AUTHORITY.json"
)
NORTH_MATERIALS_PATH = (
    REPO_ROOT
    / "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v13/DESIGN-MATERIALS.json"
)
MAPPING_PATH = (
    REPO_ROOT
    / "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
)
RESULT_RELATIVE_PATH = (
    "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/"
    "v14-compatibility-v01/V14-COMPATIBILITY-RESULT.json"
)
SOURCE_ROOT = "Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01"
EVIDENCE_ROOT = "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/v14-compatibility-v01"
NON_ALIAS_PROOF = {
    "sourceKey": "industrial_l04/variant-0/south/blender-art-v14-south-compatibility-v01",
    "viewDirection": "south",
    "orientationTransform": "none",
    "siblingGeometryConsumed": False,
    "geometryAlias": None,
    "proof": "explicit_no_alias",
}
PORTAL_CONTENT_ALLOWLIST = {
    "south-portal-deep-void",
    "south-freight-beat-a",
    "south-freight-beat-b",
    "south-freight-beat-c",
}
PORTAL_SYSTEM_IDS = PORTAL_CONTENT_ALLOWLIST | {
    "south-portal-left-jamb",
    "south-portal-right-jamb",
    "south-portal-header",
}
SOUTH_FRONTAGE_PLANE_IDS = PORTAL_SYSTEM_IDS | {
    "south-staff-entry",
}
SOUTH_FRONTAGE_AXIS_CITYSIM = 2
SOUTH_FRONTAGE_AXIS_BLENDER = 0
FRONTAGE_WORLD_TOLERANCE = 1e-9
FRONTAGE_SOURCE_TOLERANCE_PIXELS = 0.001

ROLES = {
    "v13-grounded-foundation": "grounded-foundation",
    "v13-integrated-operating-apron": "integrated-operating-apron",
    "v13-warm-foundry-masonry": "warm-foundry-masonry",
    "v13-warm-control-masonry": "warm-control-masonry",
    "v13-charcoal-structural-steel": "charcoal-structural-steel",
    "v13-portal-crown-steel": "portal-crown-steel",
    "v13-weathered-bluegreen-roof": "weathered-bluegreen-roof",
    "v13-clerestory-and-roof-edge": "clerestory-and-roof-edge",
    "v13-deep-freight-void": "deep-freight-void",
    "v13-oxidized-process-machinery": "oxidized-process-machinery",
    "v13-restrained-hot-process": "restrained-hot-process",
    "v13-warm-staff-glazing": "warm-staff-glazing",
}

EXPECTED_SCENE_IDENTITY = {
    "schema": "citysim.world-art.blender-compatibility-design.v14",
    "task": "PLAY-080",
    "logicalBuildingID": "industrial_l04",
    "variant": "variant-0",
    "revision": "south-compatibility-v14",
    "sourceKey": "industrial_l04/variant-0/south/blender-art-v14-south-compatibility-v01",
    "direction": "south",
    "orientationTransform": "none",
}
EXPECTED_PUBLISHED_SEMANTIC_INPUTS = [
    "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-NORTH-V14-HERO-REBUILD-AUTHORITY-V1.md",
    "docs/production/evidence/INTEGRATION/industrial-l04-north-v14-hero-target-v1.json",
    "docs/production/decisions/CONTRACT-010-directional-building-art.md",
]
EXPECTED_MATERIAL_AUTHORITY = {
    "path": "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/DESIGN-MATERIALS.json",
    "sha256": "c8179b77a184e41b723e26b34e7da2ef256b09e93b54a47e76cc5103f22b8cab",
    "numericValuesConsumed": False,
}
EXPECTED_COMPONENT_KEYS = {"id", "geometry", "center", "size", "materialRole", "tags"}
EXPECTED_COMPONENT_MATERIAL_ROLES = {
    "south-foundation-plinth": "v13-grounded-foundation",
    "south-integrated-apron": "v13-integrated-operating-apron",
    "south-foundry-hall": "v13-warm-foundry-masonry",
    "south-control-wing": "v13-warm-control-masonry",
    "south-staff-entry": "v13-warm-staff-glazing",
    "south-portal-left-jamb": "v13-charcoal-structural-steel",
    "south-portal-right-jamb": "v13-charcoal-structural-steel",
    "south-portal-header": "v13-portal-crown-steel",
    "south-portal-deep-void": "v13-deep-freight-void",
    "south-freight-beat-a": "v13-deep-freight-void",
    "south-freight-beat-b": "v13-deep-freight-void",
    "south-freight-beat-c": "v13-deep-freight-void",
    "south-crown-low": "v13-portal-crown-steel",
    "south-crown-mid": "v13-clerestory-and-roof-edge",
    "south-crown-high": "v13-weathered-bluegreen-roof",
    "south-rear-process-spine": "v13-oxidized-process-machinery",
    "south-offset-stack": "v13-charcoal-structural-steel",
    "south-gantry": "v13-charcoal-structural-steel",
    "south-process-machine": "v13-oxidized-process-machinery",
    "south-hot-process-cue": "v13-restrained-hot-process",
    "south-roof-tier-west": "v13-weathered-bluegreen-roof",
    "south-roof-tier-east": "v13-weathered-bluegreen-roof",
    "south-clerestory-band": "v13-clerestory-and-roof-edge",
    "south-crane-lantern": "v13-charcoal-structural-steel",
    "south-process-vessel": "v13-oxidized-process-machinery",
    "south-pipe-run-north": "v13-oxidized-process-machinery",
    "south-pipe-run-east": "v13-oxidized-process-machinery",
    "south-boiler-stack": "v13-charcoal-structural-steel",
    "south-staff-annex": "v13-warm-control-masonry",
    "south-loading-markings": "v13-integrated-operating-apron",
    "south-braced-truss": "v13-charcoal-structural-steel",
    "south-service-door-bank": "v13-warm-staff-glazing",
}
V14_REQUIRED_COMPONENTS = {
    "south-roof-tier-west", "south-roof-tier-east", "south-clerestory-band",
    "south-crane-lantern", "south-process-vessel", "south-pipe-run-north",
    "south-pipe-run-east", "south-boiler-stack", "south-staff-annex",
    "south-loading-markings", "south-braced-truss", "south-service-door-bank",
}
V14_FAMILY_VOCABULARY = {
    "warm-masonry", "charcoal-structural-steel", "weathered-blue-green-roof-metal",
    "oxidized-process-machinery", "concrete-apron", "dark-freight-depth",
    "warm-glazing", "restrained-amber-heat",
}
EXPECTED_RAW_GEOMETRY_SIGNATURES = {
    "south-foundation-plinth": "c3ce05ee8d5c96455a1f39d416af00a16d1c80ef128d7a8394db9ffc321486e0",
    "south-integrated-apron": "51b7681ca41fc09b4d3470d4eace0bafba618c13a7bfa92543a14d99c123744b",
    "south-foundry-hall": "e71d214d82d4c5ba8b4ac3f10bd7564428d7829b725cc10e3c6f7559284f4e9e",
    "south-control-wing": "e984c2698b540511180fb26d36daf47f57974a047f1ec41bed084e2c8559f9b3",
    "south-staff-entry": "c732e5cc1d6447b6106adf00b7885500b70405d53ad55d56f0f2e71f8a425246",
    "south-portal-left-jamb": "4da38b2a0a4f3430a94bc9abb58221ff785f43245855576e2f05095b4386ffb5",
    "south-portal-right-jamb": "805596a542dbb6ddd4c93538e3ea58f125f64b783564a96a8be5eb4e600ad53d",
    "south-portal-header": "d001c6e5576879ae5d331dcf43d25e13cd1d1e58f0f84d6214398bad7787579c",
    "south-portal-deep-void": "c4f05b228a221108d1038bec2650294970a350ec4153ce68bfd614806ff4f7e0",
    "south-freight-beat-a": "d67d5f231ecd173c8578f59f78085ae23e8138ef427918f1943b4a1b89ca0c3b",
    "south-freight-beat-b": "25d92f25ece17e5e31af11b57cb7c284ff7acb387e20c4870d3e29f48c944281",
    "south-freight-beat-c": "bca607ea441c63069da3ba894269c4ebb083c92079fabc50dc19329c5587e28f",
    "south-crown-low": "810f6544c39ba49cef9dfb1bcf864c0f64d5a3c3486eb6121a9d3c94f19efe41",
    "south-crown-mid": "94fb81c69a2a75302b1232d63bf509ceac6bd0b753f33c4d9533e7e55d9341db",
    "south-crown-high": "9c1aca97301b12a7a1ce090b5d3f69a86cba7d30423dbc4750cef1860e4bf5dc",
    "south-rear-process-spine": "5b7965ebd132a9723767a9f8408b6c37ca697dac1704e12978d33e882930ba36",
    "south-offset-stack": "08639d0b10d746e6ae5dc461fe5d94025c57368e01f0615ea89a0083f5e45d9f",
    "south-gantry": "c322cb00c6b62201c7567087bb79e066f9bf14bd8df03d3b8056bc7de3025865",
    "south-process-machine": "1801e28c2a300aae9023d9498da89f3d4100a66c788b2c32aebef12cd18da407",
    "south-hot-process-cue": "73b64f10353f3cb8666113be29c7c036445bed542f89ed30e62cd1118f8ab252",
    "south-roof-tier-west": "319c88e41e0adf5f39661576f19ae515b292afd44c4bcd188f44cf70efa514dd",
    "south-roof-tier-east": "dca0479f2e0978b54e3ad0bcee0ee37d7ca8c43aaca7824ec8fd83eb315c11ae",
    "south-clerestory-band": "bd93ac3e9a423af9b675a7d441dd4fc98d26625f3dec83f0a8451090db5bcf76",
    "south-crane-lantern": "a399dc0ff20b63a2e444dff3cea87429f70fcf3773e6595ccccff9224f648483",
    "south-process-vessel": "c56558f658df33a9b79fe352499fc0737cd1261320b5105833da5a2ecebbe578",
    "south-pipe-run-north": "a050089dd4b40c0eb582817ef4823f04307d3a21541b8fd13acc91d09ece6ecd",
    "south-pipe-run-east": "cc6e1ca4df3a7a6180cd706e8f388f72c9103e0e47f7944247b39c6892231472",
    "south-boiler-stack": "b9512d454b74eaa2d2a95facfdc94ada6827bd416e5bdb5e93be7d834efbac64",
    "south-staff-annex": "7e5419ae18d0c2a29c0c9dee114fea4561d37f65e7a2085699a8d8dfa3cb4411",
    "south-loading-markings": "0b2c86f21d6486d9731cdc4a68d99b275fdbe081449aea3969fcaa94d791f0e6",
    "south-braced-truss": "8b5ded5883d288c30f98056fdfaa12299c889bff8d1aa1aef6794ada6f468ade",
    "south-service-door-bank": "351b07b82e61d63223a65ad24d30317e3a060c2c0d4049648f56369298e4fd6d",
}
EXPECTED_RAW_GEOMETRY_SET_SHA256 = "ffab787e8e24e9f832d5e0a62922788d84d5e9b0e06e1ecd3b900d54e9a75cc4"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bounds(component: dict) -> tuple[float, float, float, float, float, float]:
    cx, cy, cz = component["center"]
    sx, sy, sz = component["size"]
    return (cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2, cz - sz / 2, cz + sz / 2)


def component_map(scene: dict) -> dict[str, dict]:
    return {component["id"]: component for component in scene["components"]}


def boxes_overlap(a: tuple[float, ...], b: tuple[float, ...]) -> bool:
    return (
        a[0] < b[1] and a[1] > b[0]
        and a[2] < b[3] and a[3] > b[2]
        and a[4] < b[5] and a[5] > b[4]
    )


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
        raise ValueError("camera direction cannot be normalized")
    return [value / length for value in vector]


def box_corners(component: dict) -> list[list[float]]:
    half = [value / 2 for value in component["size"]]
    return [
        [component["center"][index] + signs[index] * half[index] for index in range(3)]
        for signs in itertools.product((-1, 1), repeat=3)
    ]


def matrix_vector(matrix: list[list[float]], vector: list[float]) -> list[float]:
    return [dot(row, vector) for row in matrix]


def matrix_determinant(matrix: list[list[float]]) -> float:
    return (
        matrix[0][0] * (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1])
        - matrix[0][1] * (matrix[1][0] * matrix[2][2] - matrix[1][2] * matrix[2][0])
        + matrix[0][2] * (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0])
    )


def invert_matrix(matrix: list[list[float]]) -> list[list[float]]:
    determinant = matrix_determinant(matrix)
    if not math.isclose(determinant, 1.0):
        raise ValueError("coordinate bridge determinant is not one")
    return [
        [
            matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1],
            matrix[0][2] * matrix[2][1] - matrix[0][1] * matrix[2][2],
            matrix[0][1] * matrix[1][2] - matrix[0][2] * matrix[1][1],
        ],
        [
            matrix[1][2] * matrix[2][0] - matrix[1][0] * matrix[2][2],
            matrix[0][0] * matrix[2][2] - matrix[0][2] * matrix[2][0],
            matrix[0][2] * matrix[1][0] - matrix[0][0] * matrix[1][2],
        ],
        [
            matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0],
            matrix[0][1] * matrix[2][0] - matrix[0][0] * matrix[2][1],
            matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0],
        ],
    ]


def transform_size(matrix: list[list[float]], size: list[float]) -> list[float]:
    return [sum(abs(matrix[row][column]) * size[column] for column in range(3)) for row in range(3)]


def raw_geometry_signature(component: dict) -> str:
    """Hash structural coordinates only, excluding all labels and role metadata."""
    payload = {"center": component["center"], "size": component["size"]}
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def derive_raw_geometry_identity(scene: dict) -> dict:
    signatures = {
        component["id"]: raw_geometry_signature(component)
        for component in scene["components"]
    }
    ordered_signatures = sorted(signatures.values())
    set_payload = json.dumps(ordered_signatures, separators=(",", ":")).encode("utf-8")
    return {
        "perComponent": signatures,
        "componentCount": len(signatures),
        "uniqueSignatureCount": len(set(signatures.values())),
        "rawGeometrySetSha256": hashlib.sha256(set_payload).hexdigest(),
        "signatureInputs": ["center", "size"],
        "excludedMetadata": ["id", "geometry", "materialRole", "tags"],
    }


def polygon_signed_area(polygon: list[list[float]]) -> float:
    if len(polygon) < 3:
        return 0.0
    return sum(
        polygon[index][0] * polygon[(index + 1) % len(polygon)][1]
        - polygon[(index + 1) % len(polygon)][0] * polygon[index][1]
        for index in range(len(polygon))
    ) / 2


def polygon_area(polygon: list[list[float]]) -> float:
    return abs(polygon_signed_area(polygon))


def convex_hull_2d(points: list[list[float]]) -> list[list[float]]:
    unique = sorted(set((float(point[0]), float(point[1])) for point in points))
    if len(unique) <= 1:
        return [list(point) for point in unique]

    def turn(origin: tuple[float, float], left: tuple[float, float], right: tuple[float, float]) -> float:
        return (
            (left[0] - origin[0]) * (right[1] - origin[1])
            - (left[1] - origin[1]) * (right[0] - origin[0])
        )

    lower: list[tuple[float, float]] = []
    for point in unique:
        while len(lower) >= 2 and turn(lower[-2], lower[-1], point) <= 1e-12:
            lower.pop()
        lower.append(point)
    upper: list[tuple[float, float]] = []
    for point in reversed(unique):
        while len(upper) >= 2 and turn(upper[-2], upper[-1], point) <= 1e-12:
            upper.pop()
        upper.append(point)
    return [list(point) for point in lower[:-1] + upper[:-1]]


def clip_convex_polygon(subject: list[list[float]], clipper: list[list[float]]) -> list[list[float]]:
    """Return the deterministic convex intersection of two source-space polygons."""
    if polygon_signed_area(clipper) < 0:
        clipper = list(reversed(clipper))
    output = [list(point) for point in subject]
    for index, edge_start in enumerate(clipper):
        edge_end = clipper[(index + 1) % len(clipper)]
        input_polygon = output
        output = []
        if not input_polygon:
            break

        def inside(point: list[float]) -> bool:
            return (
                (edge_end[0] - edge_start[0]) * (point[1] - edge_start[1])
                - (edge_end[1] - edge_start[1]) * (point[0] - edge_start[0])
            ) >= -1e-9

        def intersection(start: list[float], end: list[float]) -> list[float]:
            ray = [end[0] - start[0], end[1] - start[1]]
            edge = [edge_end[0] - edge_start[0], edge_end[1] - edge_start[1]]
            denominator = ray[0] * edge[1] - ray[1] * edge[0]
            if abs(denominator) < 1e-12:
                return list(end)
            distance = (
                (edge_start[0] - start[0]) * edge[1]
                - (edge_start[1] - start[1]) * edge[0]
            ) / denominator
            return [start[0] + distance * ray[0], start[1] + distance * ray[1]]

        previous = input_polygon[-1]
        for current in input_polygon:
            if inside(current):
                if not inside(previous):
                    output.append(intersection(previous, current))
                output.append(current)
            elif inside(previous):
                output.append(intersection(previous, current))
            previous = current
    return output


def lower_scene(scene: dict, mapping: dict | None = None) -> dict:
    """Lower CitySim-authored geometry through the published v06 bridge."""
    mapping = mapping or load(MAPPING_PATH)
    basis = mapping["basis"]["matrixRows"]
    if mapping["basis"]["formula"] != "B(CitySim[x,y,z])=Blender[z,x,y]":
        raise ValueError("unexpected coordinate bridge formula")
    if mapping["basis"]["sourceOrder"] != [0, 1, 2, 3] or mapping["basis"]["perDirectionTransforms"]:
        raise ValueError("coordinate bridge source order or transform drift")
    lowered_components = []
    for component in scene["components"]:
        lowered_components.append(
            {
                "id": component["id"],
                "geometry": component["geometry"],
                "center": matrix_vector(basis, component["center"]),
                "size": transform_size(basis, component["size"]),
                "materialRole": component["materialRole"],
                "tags": list(component.get("tags", [])),
            }
        )
    registration = scene["registration"]
    return {
        "basis": basis,
        "components": lowered_components,
        "registration": {
            "groundOrigin": matrix_vector(basis, registration["groundOrigin"]),
            "groundPivot": matrix_vector(basis, registration["groundPivot"]),
            "frontageSocket": matrix_vector(basis, registration["frontageSocket"]["position"]),
            "footprintCorners": [matrix_vector(basis, point) for point in registration["footprintWorld"]["corners"]],
        },
    }


def derive_projection_metrics(scene: dict, mapping: dict | None = None) -> dict:
    """Derive source and literal-192 values from lowered geometry and v06 camera."""
    mapping = mapping or load(MAPPING_PATH)
    lowered = lower_scene(scene, mapping)
    components = component_map(lowered)
    camera = mapping["camera"]
    render_width, render_height = camera["renderViewportPixels"]
    literal_width, literal_height = scene["camera"]["literalViewportPixels"]
    scale_x = render_width / literal_width
    scale_y = render_height / literal_height
    if not math.isclose(scale_x, scale_y):
        raise ValueError("literal viewport scales must match")
    forward = normalize(subtract(camera["blenderTarget"], camera["blenderPosition"]))
    right = normalize(cross(forward, [0.0, 0.0, 1.0]))
    up = normalize(cross(right, forward))
    source_scale = render_width / camera["blenderOrthographicScale"]
    source_ground_center = camera["sourceGroundCenter"]
    basis = mapping["basis"]["matrixRows"]

    def project_blender(point: list[float]) -> list[float]:
        return [
            source_ground_center[0] + dot(point, right) * source_scale,
            source_ground_center[1] - dot(point, up) * source_scale,
        ]

    def project_citysim(point: list[float]) -> list[float]:
        return project_blender(matrix_vector(basis, point))

    def projected_bounds(component: dict) -> tuple[float, float, float, float]:
        projected = [project_blender(point) for point in box_corners(component)]
        xs = [point[0] for point in projected]
        ys = [point[1] for point in projected]
        return (min(xs), min(ys), max(xs), max(ys))

    def union_bounds(ids: list[str]) -> tuple[float, float, float, float]:
        projected = [projected_bounds(components[component_id]) for component_id in ids]
        return (
            min(item[0] for item in projected),
            min(item[1] for item in projected),
            max(item[2] for item in projected),
            max(item[3] for item in projected),
        )

    def literal_size(projected: tuple[float, float, float, float]) -> tuple[float, float]:
        return ((projected[2] - projected[0]) / scale_x, (projected[3] - projected[1]) / scale_y)

    def projected_hull(component: dict) -> list[list[float]]:
        return convex_hull_2d([project_blender(point) for point in box_corners(component)])

    def ray_point(source_point: list[float]) -> list[float]:
        camera_right = (source_point[0] - source_ground_center[0]) / source_scale
        camera_up = -(source_point[1] - source_ground_center[1]) / source_scale
        return [right[index] * camera_right + up[index] * camera_up for index in range(3)]

    def ray_box_depth_interval(source_point: list[float], component: dict) -> tuple[float, float] | None:
        point = ray_point(source_point)
        component_bounds = bounds(component)
        minimums = [component_bounds[0], component_bounds[2], component_bounds[4]]
        maximums = [component_bounds[1], component_bounds[3], component_bounds[5]]
        near = -math.inf
        far = math.inf
        for axis in range(3):
            if abs(forward[axis]) < 1e-12:
                if point[axis] < minimums[axis] or point[axis] > maximums[axis]:
                    return None
                continue
            first = (minimums[axis] - point[axis]) / forward[axis]
            second = (maximums[axis] - point[axis]) / forward[axis]
            near = max(near, min(first, second))
            far = min(far, max(first, second))
        return None if near > far else (near, far)

    def closest_face(component: dict) -> tuple[int, float, list[list[float]]]:
        thin_axis = min(range(3), key=lambda axis: component["size"][axis])
        candidates = [
            component["center"][thin_axis] - component["size"][thin_axis] / 2,
            component["center"][thin_axis] + component["size"][thin_axis] / 2,
        ]
        face_value = min(
            candidates,
            key=lambda value: dot(
                subtract(
                    [value if axis == thin_axis else component["center"][axis] for axis in range(3)],
                    camera["blenderPosition"],
                ),
                forward,
            ),
        )
        other_axes = [axis for axis in range(3) if axis != thin_axis]
        corners = []
        for first_sign, second_sign in itertools.product((-1, 1), repeat=2):
            point = list(component["center"])
            point[thin_axis] = face_value
            point[other_axes[0]] += first_sign * component["size"][other_axes[0]] / 2
            point[other_axes[1]] += second_sign * component["size"][other_axes[1]] / 2
            corners.append(point)
        return thin_axis, face_value, corners

    jamb_ids = ["south-portal-left-jamb", "south-portal-right-jamb"]
    frame_bounds = union_bounds(jamb_ids + ["south-portal-header"])
    void_component = components["south-portal-deep-void"]
    void_bounds_source = projected_bounds(void_component)
    jamb_bounds_source = [projected_bounds(components[component_id]) for component_id in jamb_ids]
    jamb_sizes = [literal_size(item) for item in jamb_bounds_source]
    header_bounds_source = projected_bounds(components["south-portal-header"])
    crown_ids = [
        component["id"]
        for component in lowered["components"]
        if "portal-crown" in component.get("tags", [])
    ]
    crown_bounds = union_bounds(crown_ids)
    silhouette_rows = []
    for component in lowered["components"]:
        if "silhouette-break" not in component.get("tags", []):
            continue
        top_center = [
            component["center"][0],
            component["center"][1],
            component["center"][2] + component["size"][2] / 2,
        ]
        silhouette_rows.append(project_blender(top_center)[1] / scale_y)
    silhouette_clusters: list[float] = []
    for row in sorted(silhouette_rows):
        if not silhouette_clusters or abs(row - silhouette_clusters[-1]) >= 2:
            silhouette_clusters.append(row)
    void_world_bounds = bounds(void_component)
    non_aperture_intrusions = [
        component["id"]
        for component in lowered["components"]
        if component["id"] not in PORTAL_CONTENT_ALLOWLIST
        and boxes_overlap(bounds(component), void_world_bounds)
    ]
    aperture_axis, aperture_face_value, aperture_face = closest_face(void_component)
    aperture_polygon_source = convex_hull_2d([project_blender(point) for point in aperture_face])
    aperture_area_source = polygon_area(aperture_polygon_source)
    if aperture_area_source <= 0:
        raise ValueError("portal aperture source polygon has no area")

    def aperture_depth(source_point: list[float]) -> float:
        point = ray_point(source_point)
        if abs(forward[aperture_axis]) < 1e-12:
            raise ValueError("camera is parallel to portal aperture plane")
        return (aperture_face_value - point[aperture_axis]) / forward[aperture_axis]

    source_space_occluders = []
    for component in lowered["components"]:
        if component["id"] in PORTAL_SYSTEM_IDS:
            continue
        overlap_polygon = clip_convex_polygon(projected_hull(component), aperture_polygon_source)
        overlap_area = polygon_area(overlap_polygon)
        if overlap_area <= 1e-7:
            continue
        centroid = [
            sum(point[axis] for point in overlap_polygon) / len(overlap_polygon)
            for axis in range(2)
        ]
        samples = list(overlap_polygon)
        samples.extend(
            [
                (overlap_polygon[index][axis] + overlap_polygon[(index + 1) % len(overlap_polygon)][axis]) / 2
                for axis in range(2)
            ]
            for index in range(len(overlap_polygon))
        )
        samples.append(centroid)
        depth_margins = []
        for sample in samples:
            depth_interval = ray_box_depth_interval(sample, component)
            if depth_interval is None:
                continue
            margin = aperture_depth(sample) - depth_interval[0]
            if margin > 1e-7:
                depth_margins.append(margin)
        if depth_margins:
            source_space_occluders.append(
                {
                    "id": component["id"],
                    "projectedOverlapAreaSourcePixels": overlap_area,
                    "projectedOverlapShare": min(1.0, overlap_area / aperture_area_source),
                    "nearestDepthMarginWorld": max(depth_margins),
                }
            )
    process_components = [component for component in lowered["components"] if "process" in component.get("tags", [])]
    intrusive_process = [component["id"] for component in process_components if component["id"] in non_aperture_intrusions]
    portal_frame_components = [component for component in lowered["components"] if "portal-frame" in component.get("tags", [])]
    intrusive_portal_frame = [component["id"] for component in portal_frame_components if component["id"] in non_aperture_intrusions]
    stack = components["south-offset-stack"]
    footprint = scene["registration"]["footprintWorld"]["size"]
    stack_share = (stack["size"][0] * stack["size"][1]) / (footprint[0] * footprint[1])
    all_bounds = union_bounds([component["id"] for component in lowered["components"]])
    freight_components = [component for component in lowered["components"] if "freight-opening" in component.get("tags", [])]
    freight_bounds = [projected_bounds(component) for component in freight_components]
    freight_sizes = [literal_size(item) for item in freight_bounds]
    freight_order = sorted(zip(freight_components, freight_bounds), key=lambda item: item[1][0])
    freight_gaps = [
        (freight_order[index + 1][1][0] - freight_order[index][1][2]) / scale_x
        for index in range(len(freight_order) - 1)
    ]
    staff_bounds = projected_bounds(components["south-staff-entry"])
    registration = lowered["registration"]
    actual_registration = {
        "footprint": [project_citysim(point) for point in scene["registration"]["footprintWorld"]["corners"]],
        "groundOrigin": project_blender(registration["groundOrigin"]),
        "groundPivot": project_blender(registration["groundPivot"]),
        "frontageSocket": project_blender(registration["frontageSocket"]),
    }
    south_mapping = mapping["directions"]["south"]
    citysim_components = component_map(scene)
    canonical_socket = south_mapping["socketCitySim"]
    canonical_outward = south_mapping["outwardCitySim"]
    if canonical_outward != [0, 0, 1]:
        raise ValueError("published South outward normal is not +z")
    component_plane_distances = {}
    for component_id in sorted(SOUTH_FRONTAGE_PLANE_IDS):
        component = citysim_components[component_id]
        thin_axis = min(range(3), key=lambda axis: component["size"][axis])
        if thin_axis != SOUTH_FRONTAGE_AXIS_CITYSIM:
            raise ValueError(f"South frontage thin axis mismatch: {component_id}")
        outward_face = component["center"][SOUTH_FRONTAGE_AXIS_CITYSIM] + component["size"][SOUTH_FRONTAGE_AXIS_CITYSIM] / 2
        component_plane_distances[component_id] = outward_face - canonical_socket[SOUTH_FRONTAGE_AXIS_CITYSIM]
        if abs(component_plane_distances[component_id]) > FRONTAGE_WORLD_TOLERANCE:
            raise ValueError(f"South frontage plane distance mismatch: {component_id}")

    apron = citysim_components["south-integrated-apron"]
    apron_bounds_citysim = bounds(apron)
    apron_road_edge = apron_bounds_citysim[5]
    if abs(apron_road_edge - canonical_socket[SOUTH_FRONTAGE_AXIS_CITYSIM]) > FRONTAGE_WORLD_TOLERANCE:
        raise ValueError("South apron road edge does not terminate at the socket plane")
    if not (apron_bounds_citysim[0] <= canonical_socket[0] <= apron_bounds_citysim[1]):
        raise ValueError("South apron does not span the socket threshold")

    contact_polygon = scene["registration"]["contactPolygon"]
    if any(point[1] != 0 for point in contact_polygon):
        raise ValueError("South contact polygon is not grounded")
    if not math.isclose(max(point[2] for point in contact_polygon), canonical_socket[2], abs_tol=FRONTAGE_WORLD_TOLERANCE):
        raise ValueError("South contact polygon misses the socket plane")
    if not (min(point[0] for point in contact_polygon) <= canonical_socket[0] <= max(point[0] for point in contact_polygon)):
        raise ValueError("South contact polygon does not span the socket")

    entrance_zone = scene["registration"]["entranceExclusionZone"]
    if entrance_zone["z"] != [27.5, 28] or entrance_zone["x"] != [-13, 13]:
        raise ValueError("South entrance exclusion zone is not coupled to the portal threshold")
    threshold_citysim = [
        citysim_components["south-portal-deep-void"]["center"][0],
        0,
        canonical_socket[2],
    ]
    if threshold_citysim != canonical_socket:
        raise ValueError("South entrance threshold does not equal the canonical socket")
    threshold_blender = matrix_vector(basis, threshold_citysim)
    blender_outward = matrix_vector(basis, canonical_outward)
    if threshold_blender != south_mapping["socketBlender"]:
        raise ValueError("South threshold does not lower to the canonical Blender socket")
    if blender_outward != [1, 0, 0]:
        raise ValueError("South outward normal does not lower to Blender +x")
    if SOUTH_FRONTAGE_AXIS_BLENDER != blender_outward.index(1):
        raise ValueError("South Blender frontage axis mismatch")

    threshold_source = project_blender(threshold_blender)
    expected_socket_source = south_mapping["socketSource"]
    if any(abs(actual - expected) > FRONTAGE_SOURCE_TOLERANCE_PIXELS for actual, expected in zip(threshold_source, expected_socket_source)):
        raise ValueError("South threshold source projection misses the canonical socket")
    aperture_centroid_source = [
        sum(point[axis] for point in aperture_polygon_source) / len(aperture_polygon_source)
        for axis in range(2)
    ]
    portal_centroid_horizontal_delta = aperture_centroid_source[0] - expected_socket_source[0]
    if abs(portal_centroid_horizontal_delta) > FRONTAGE_SOURCE_TOLERANCE_PIXELS:
        raise ValueError("South portal projected centroid misses the source socket axis")
    aperture_x = [point[0] for point in aperture_polygon_source]
    if not (min(aperture_x) <= expected_socket_source[0] <= max(aperture_x)):
        raise ValueError("South portal projection does not overlap the source socket axis")
    apron_bounds_source = projected_bounds(components["south-integrated-apron"])
    if not (apron_bounds_source[0] <= expected_socket_source[0] <= apron_bounds_source[2]):
        raise ValueError("South apron projection does not overlap the source socket axis")

    frontage_coupling = {
        "citySimPlaneAxis": "z",
        "citySimPlaneCoordinate": canonical_socket[2],
        "citySimOutwardNormal": canonical_outward,
        "blenderPlaneAxis": "x",
        "blenderPlaneCoordinate": south_mapping["socketBlender"][0],
        "blenderOutwardNormal": blender_outward,
        "thresholdCitySim": threshold_citysim,
        "thresholdBlender": threshold_blender,
        "thresholdSource": threshold_source,
        "expectedSourceSocket": expected_socket_source,
        "portalProjectedCentroidSource": aperture_centroid_source,
        "portalProjectedCentroidHorizontalDeltaPixels": portal_centroid_horizontal_delta,
        "portalProjectedContainsSocketX": True,
        "apronProjectedContainsSocketX": True,
        "apronRoadEdgeCitySim": apron_road_edge,
        "componentOuterPlaneDistancesWorld": component_plane_distances,
        "worldTolerance": FRONTAGE_WORLD_TOLERANCE,
        "sourceTolerancePixels": FRONTAGE_SOURCE_TOLERANCE_PIXELS,
    }
    return {
        "projection": {
            "sourceScaleRenderPixelsPerWorld": source_scale,
            "literalViewportPixels": [literal_width, literal_height],
            "cameraRight": [round(value, 9) for value in right],
            "cameraUp": [round(value, 9) for value in up],
            "sourceGroundCenter": source_ground_center,
            "shiftX": camera["shiftX"],
            "shiftY": camera["shiftY"],
            "postProjectionOffsetPixels": camera["postProjectionOffsetPixels"],
            "basis": basis,
        },
        "registration": actual_registration,
        "expectedRegistration": {
            "footprint": mapping["registration"]["footprintSource"],
            "groundOrigin": mapping["registration"]["originSource"],
            "groundPivot": mapping["registration"]["pivotSource"],
            "frontageSocket": south_mapping["socketSource"],
        },
        "frontageCoupling": frontage_coupling,
        "outerWidthPixels": literal_size(frame_bounds)[0],
        "outerHeightPixels": literal_size(frame_bounds)[1],
        "clearInsetWidthPixels": literal_size(void_bounds_source)[0],
        "clearInsetHeightPixels": literal_size(void_bounds_source)[1],
        "jambWidthPixelsEach": min(item[0] for item in jamb_sizes),
        "jambHeightPixelsEach": min(item[1] for item in jamb_sizes),
        "headerWidthPixels": literal_size(header_bounds_source)[0],
        "headerThicknessPixels": literal_size(header_bounds_source)[1],
        "insetAreaPixels": literal_size(void_bounds_source)[0] * literal_size(void_bounds_source)[1],
        "crownWidthPixels": literal_size(crown_bounds)[0],
        "distinctRoofHeightBreaks": len(silhouette_clusters),
        "silhouetteRowsPixels": silhouette_clusters,
        "stackSilhouetteShare": stack_share,
        "intrusiveProcessComponents": intrusive_process,
        "intrusivePortalFrameComponents": intrusive_portal_frame,
        "intrusiveNonApertureSolids": non_aperture_intrusions,
        "sourceAperturePolygonPixels": aperture_polygon_source,
        "sourceApertureAreaPixels": aperture_area_source,
        "sourceSpacePortalOccluders": source_space_occluders,
        "intrusiveSourceProjectedSolids": [item["id"] for item in source_space_occluders],
        "portalOccludedShare": max(
            [1.0 if non_aperture_intrusions else 0.0]
            + [item["projectedOverlapShare"] for item in source_space_occluders]
        ),
        "processOrCranePixelsInsideInset": len(
            set(non_aperture_intrusions)
            | {item["id"] for item in source_space_occluders}
        ),
        "freightBeatCount": len(freight_components),
        "freightBeatMinimumPixelsEach": [min(item[0] for item in freight_sizes), min(item[1] for item in freight_sizes)],
        "freightSeparatorPixels": min(freight_gaps),
        "staffEntryPixels": list(literal_size(staff_bounds)),
        "assignedMaterialRoles": sorted({component["materialRole"] for component in scene["components"]}),
        "occupiedEnvelopeWidthPixels": literal_size(all_bounds)[0],
        "occupiedEnvelopeHeightPixels": literal_size(all_bounds)[1],
    }


def serialize_lowered_packet(scene: dict, mapping: dict | None = None) -> str:
    mapping = mapping or load(MAPPING_PATH)
    payload = {"lowered": lower_scene(scene, mapping), "metrics": derive_projection_metrics(scene, mapping)}
    return json.dumps(payload, sort_keys=True, separators=(",", ":"))


def run_fresh_lowering_process() -> tuple[int, bytes]:
    environment = dict(os.environ)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    process = subprocess.Popen(
        [sys.executable, str(Path(__file__).resolve()), "--emit-lowering"],
        cwd=REPO_ROOT,
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, stderr = process.communicate()
    if process.returncode != 0:
        raise RuntimeError(stderr.decode("utf-8", errors="replace"))
    return process.pid, stdout


def compare_fresh_replays(first_pid: int, first: bytes, second_pid: int, second: bytes) -> str:
    if first_pid == second_pid:
        raise ValueError("replay processes are not distinct")
    if first != second:
        raise ValueError("fresh lowering outputs differ")
    return hashlib.sha256(first).hexdigest()


def validate_owned_path(path: str) -> None:
    value = PurePosixPath(path)
    if value.is_absolute() or "." in value.parts or ".." in value.parts:
        raise ValueError("unsafe path component")
    if not (path == EVIDENCE_ROOT or path.startswith(EVIDENCE_ROOT + "/")):
        raise ValueError("path escapes South v14 evidence root")


def camera_matches_mapping(scene: dict, mapping: dict) -> bool:
    scene_camera = scene["camera"]
    frozen_camera = mapping["camera"]
    return (
        scene_camera["type"] == "ORTHO"
        and scene_camera["citysimPosition"] == frozen_camera["citySimPosition"]
        and scene_camera["citysimTarget"] == frozen_camera["citySimTarget"]
        and scene_camera["orthoScale"] == frozen_camera["blenderOrthographicScale"]
        and scene_camera["shiftX"] == frozen_camera["shiftX"]
        and scene_camera["shiftY"] == frozen_camera["shiftY"]
        and scene_camera["renderViewportPixels"] == frozen_camera["renderViewportPixels"]
    )


def validate_declared_literal_metrics(scene: dict, metrics: dict) -> list[str]:
    targets = scene.get("literal192Targets", {})
    portal = targets.get("portal", {})
    freight = targets.get("freightAndStaff", {})
    expected = {
        "occupiedBoundsPixels.width": (targets.get("occupiedBoundsPixels", {}).get("width"), metrics["occupiedEnvelopeWidthPixels"]),
        "occupiedBoundsPixels.height": (targets.get("occupiedBoundsPixels", {}).get("height"), metrics["occupiedEnvelopeHeightPixels"]),
        "measuredDistinctRoofHeightBreaks": (targets.get("measuredDistinctRoofHeightBreaks"), metrics["distinctRoofHeightBreaks"]),
        "portalCrownWidthPixels": (targets.get("portalCrownWidthPixels"), metrics["crownWidthPixels"]),
        "stackSilhouetteShare": (targets.get("stackSilhouetteShare"), metrics["stackSilhouetteShare"]),
        "portal.outerWidthPixels": (portal.get("outerWidthPixels"), metrics["outerWidthPixels"]),
        "portal.outerHeightPixels": (portal.get("outerHeightPixels"), metrics["outerHeightPixels"]),
        "portal.clearInsetWidthPixels": (portal.get("clearInsetWidthPixels"), metrics["clearInsetWidthPixels"]),
        "portal.clearInsetHeightPixels": (portal.get("clearInsetHeightPixels"), metrics["clearInsetHeightPixels"]),
        "portal.jambWidthPixelsEach": (portal.get("jambWidthPixelsEach"), metrics["jambWidthPixelsEach"]),
        "portal.jambHeightPixelsEach": (portal.get("jambHeightPixelsEach"), metrics["jambHeightPixelsEach"]),
        "portal.headerWidthPixels": (portal.get("headerWidthPixels"), metrics["headerWidthPixels"]),
        "portal.headerThicknessPixels": (portal.get("headerThicknessPixels"), metrics["headerThicknessPixels"]),
        "portal.insetAreaPixels": (portal.get("insetAreaPixels"), metrics["insetAreaPixels"]),
        "portal.occludedShare": (portal.get("occludedShare"), metrics["portalOccludedShare"]),
        "portal.processOrCranePixelsInsideInset": (portal.get("processOrCranePixelsInsideInset"), metrics["processOrCranePixelsInsideInset"]),
        "freightAndStaff.freightBeatCount": (freight.get("freightBeatCount"), metrics["freightBeatCount"]),
        "freightAndStaff.freightBeatMinimumPixelsEach[0]": (freight.get("freightBeatMinimumPixelsEach", [None, None])[0], metrics["freightBeatMinimumPixelsEach"][0]),
        "freightAndStaff.freightBeatMinimumPixelsEach[1]": (freight.get("freightBeatMinimumPixelsEach", [None, None])[1], metrics["freightBeatMinimumPixelsEach"][1]),
        "freightAndStaff.freightSeparatorPixels": (freight.get("freightSeparatorPixels"), metrics["freightSeparatorPixels"]),
        "freightAndStaff.staffEntryPixels[0]": (freight.get("staffEntryPixels", [None, None])[0], metrics["staffEntryPixels"][0]),
        "freightAndStaff.staffEntryPixels[1]": (freight.get("staffEntryPixels", [None, None])[1], metrics["staffEntryPixels"][1]),
    }
    mismatches = []
    for name, (declared, derived) in expected.items():
        if declared is None or not math.isclose(float(declared), float(derived), rel_tol=0.0, abs_tol=1e-5):
            mismatches.append(name)
    if targets.get("occupiedBoundsPixels", {}).get("opaquePixels") is not None:
        mismatches.append("occupiedBoundsPixels.opaquePixels must remain null without pixels")
    if targets.get("measurementMethod") != "analytic-camera-lowering-no-pixels":
        mismatches.append("measurementMethod")
    return mismatches


def validate_exact_authority_bindings(scene: dict, materials: dict) -> tuple[list[str], dict]:
    errors: list[str] = []
    for name, expected in EXPECTED_SCENE_IDENTITY.items():
        if scene.get(name) != expected:
            errors.append(f"scene identity mismatch: {name}")
    if scene.get("sourceAuthority") is not False:
        errors.append("scene sourceAuthority must remain false")
    if scene.get("productionSelected") is not False:
        errors.append("scene productionSelected must remain false")
    if scene.get("pixelRenderAuthorized") is not False:
        errors.append("scene pixelRenderAuthorized must remain false")
    authorship = scene.get("authorship", {})
    if authorship.get("method") != "independent-south-v14-compatibility-design":
        errors.append("authorship method mismatch")
    if authorship.get("publishedSemanticInputs") != EXPECTED_PUBLISHED_SEMANTIC_INPUTS:
        errors.append("published semantic inputs mismatch")
    if set(scene.get("semanticDesign", {}).get("familyVocabulary", [])) != V14_FAMILY_VOCABULARY:
        errors.append("v14 family vocabulary mismatch")

    expected_material_identity = {
        "schema": "citysim.world-art.material-role-bindings.v13",
        "task": "PLAY-080",
        "direction": "south",
        "revision": "south-compatibility-v13",
    }
    for name, expected in expected_material_identity.items():
        if materials.get(name) != expected:
            errors.append(f"material identity mismatch: {name}")
    if materials.get("publishedRoleAuthority") != EXPECTED_MATERIAL_AUTHORITY:
        errors.append("published material role authority mismatch")
    if materials.get("requiredRoles") != list(ROLES):
        errors.append("material required-role sequence mismatch")
    if materials.get("roleSources") != ROLES:
        errors.append("material role source mapping mismatch")
    if materials.get("numericValuesRequireIntegrationReconciliation") is not True:
        errors.append("material numeric reconciliation boundary mismatch")
    for name in ("sourceAuthority", "pixelRenderAuthorized", "renderAuthority", "productionSelected"):
        if materials.get(name) is not False:
            errors.append(f"material {name} must remain false")

    components = scene.get("components", [])
    component_ids = [component.get("id") for component in components]
    if len(component_ids) != len(set(component_ids)):
        errors.append("duplicate component id")
    if set(component_ids) != set(EXPECTED_COMPONENT_MATERIAL_ROLES):
        errors.append("component identity set mismatch")
    if not V14_REQUIRED_COMPONENTS.issubset(set(component_ids)):
        errors.append("v14 semantic component coverage incomplete")
    for component in components:
        component_id = component.get("id")
        unexpected_fields = set(component) - EXPECTED_COMPONENT_KEYS
        missing_fields = EXPECTED_COMPONENT_KEYS - set(component)
        if unexpected_fields or missing_fields:
            errors.append(
                f"unexpected component fields: {component_id}: "
                f"extra={sorted(unexpected_fields)} missing={sorted(missing_fields)}"
            )
        if component.get("geometry") != "box":
            errors.append(f"component geometry kind mismatch: {component_id}")
        if component.get("materialRole") != EXPECTED_COMPONENT_MATERIAL_ROLES.get(component_id):
            errors.append(f"component material binding mismatch: {component_id}")
        if component_id in EXPECTED_COMPONENT_MATERIAL_ROLES:
            _, _, _, y1, _, _ = bounds(component)
            maximum = 44 if any("stack" in tag for tag in component.get("tags", [])) else 40
            if y1 > maximum:
                errors.append(f"vertical envelope exceeds v14 limit: {component_id}")

    try:
        geometry_identity = derive_raw_geometry_identity(scene)
        if geometry_identity["perComponent"] != EXPECTED_RAW_GEOMETRY_SIGNATURES:
            errors.append("raw geometry signature mismatch")
        if geometry_identity["rawGeometrySetSha256"] != EXPECTED_RAW_GEOMETRY_SET_SHA256:
            errors.append("raw geometry set signature mismatch")
        if geometry_identity["uniqueSignatureCount"] != geometry_identity["componentCount"]:
            errors.append("raw geometry alias detected")
    except (KeyError, TypeError, ValueError) as exc:
        errors.append(f"raw geometry derivation failed: {exc}")
        geometry_identity = {}
    return errors, geometry_identity


def validate_packet(scene: dict, materials: dict, evidence_path: str = RESULT_RELATIVE_PATH, mapping: dict | None = None) -> dict:
    errors: list[str] = []
    mapping = mapping or load(MAPPING_PATH)
    binding_errors, geometry_identity = validate_exact_authority_bindings(scene, materials)
    errors.extend(binding_errors)
    try:
        validate_owned_path(evidence_path)
    except ValueError as exc:
        errors.append(f"path: {exc}")
    if scene.get("direction") != "south":
        errors.append("wrong direction")
    if scene.get("orientationTransform") != "none":
        errors.append("orientation transform is not none")
    if scene.get("sourceKey") != "industrial_l04/variant-0/south/blender-art-v14-south-compatibility-v01":
        errors.append("source alias")
    authorship = scene.get("authorship", {})
    if authorship.get("geometryAlias") is not None:
        errors.append("geometry alias is present")
    if authorship.get("siblingGeometryConsumed") or authorship.get("siblingSceneCopied") or authorship.get("siblingSceneOpened"):
        errors.append("sibling geometry was consumed")
    if authorship.get("nonAliasProof") != NON_ALIAS_PROOF:
        errors.append("explicit non-alias proof is missing or malformed")
    registration = scene.get("registration", {})
    if registration.get("frontageSocket", {}).get("position") != mapping["directions"]["south"]["socketCitySim"]:
        errors.append("South socket drift")
    if registration.get("frontageSocket", {}).get("outwardVector") != mapping["directions"]["south"]["outwardCitySim"]:
        errors.append("South outward-vector drift")
    camera = scene.get("camera", {})
    if not camera_matches_mapping(scene, mapping):
        errors.append("camera drift")
    components = scene.get("components", [])
    component_ids = {component.get("id") for component in components}
    required_components = {
        "south-portal-left-jamb", "south-portal-right-jamb", "south-portal-header",
        "south-portal-deep-void", "south-crown-low", "south-crown-mid", "south-crown-high",
    }
    if not required_components.issubset(component_ids):
        errors.append("missing portal/crown geometry")
    try:
        metrics = derive_projection_metrics(scene, mapping)
        tolerance = mapping["toleranceSourcePixels"]
        for name in ("groundOrigin", "groundPivot", "frontageSocket"):
            actual = metrics["registration"][name]
            expected = metrics["expectedRegistration"][name]
            if any(abs(a - e) > tolerance for a, e in zip(actual, expected)):
                errors.append(f"registration projection drift: {name}")
        if any(
            abs(actual - expected) > tolerance
            for actual_point, expected_point in zip(metrics["registration"]["footprint"], metrics["expectedRegistration"]["footprint"])
            for actual, expected in zip(actual_point, expected_point)
        ):
            errors.append("footprint projection drift")
        if metrics["clearInsetWidthPixels"] <= 14 or metrics["clearInsetHeightPixels"] <= 12:
            errors.append("collapsed portal aperture")
        if metrics["intrusiveNonApertureSolids"]:
            errors.append("non-aperture solid intrudes into portal aperture")
        if metrics["intrusiveSourceProjectedSolids"]:
            errors.append("source-space portal occlusion by non-aperture solid")
        if metrics["distinctRoofHeightBreaks"] < 3:
            errors.append("insufficient silhouette breaks")
        if metrics["freightBeatCount"] != 3:
            errors.append("freight beat count mismatch")
        if metrics["freightBeatMinimumPixelsEach"][0] < 4 or metrics["freightBeatMinimumPixelsEach"][1] < 8:
            errors.append("freight beat below 4x8 source pixels")
        if metrics["staffEntryPixels"][0] < 5 or metrics["staffEntryPixels"][1] < 8:
            errors.append("staff entry below 5x8 source pixels")
        errors.extend(f"literal declaration mismatch: {name}" for name in validate_declared_literal_metrics(scene, metrics))
    except (KeyError, TypeError, ValueError) as exc:
        errors.append(f"geometry derivation failed: {exc}")
        metrics = {}
    if set(materials.get("requiredRoles", [])) != set(ROLES):
        errors.append("material role set mismatch")
    if not set(ROLES).issubset({component.get("materialRole") for component in components}):
        errors.append("material role coverage incomplete")
    if errors:
        raise ValueError("; ".join(errors))
    metrics["rawGeometryIdentity"] = geometry_identity
    return metrics


class SouthV14CompatibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.scene = load(SCENE_PATH)
        cls.materials = load(MATERIALS_PATH)
        cls.north_authority = load(NORTH_AUTHORITY_PATH)
        cls.north_materials = load(NORTH_MATERIALS_PATH)
        cls.v14_target = load(V14_TARGET_PATH)

    def test_published_inputs_are_exact_and_semantic_only(self) -> None:
        self.assertEqual(
            "e439d9f8de08474bbaf31c2308491dad486ec953bf45605c043731f68b44edbb",
            sha256(V14_AUTHORITY_PATH),
        )
        self.assertEqual(
            "bd9df3b979eb521af9823de19063c39ece702648736eddb79e6a6e498fbf713d",
            sha256(V14_TARGET_PATH),
        )
        self.assertEqual("industrial_l04", self.v14_target["family"])
        self.assertFalse(self.v14_target["output"]["sourceAuthority"])
        self.assertEqual(
            "1b1006403081c3933c54451b6c506af74493a2ac3b253fdd9f1f79098d7c1bed",
            sha256(NORTH_AUTHORITY_PATH),
        )
        self.assertEqual(
            "c8179b77a184e41b723e26b34e7da2ef256b09e93b54a47e76cc5103f22b8cab",
            sha256(NORTH_MATERIALS_PATH),
        )
        self.assertEqual(
            "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7",
            sha256(MAPPING_PATH),
        )
        self.assertEqual([], self.scene["authorship"]["geometryAlias"] or [])
        self.assertEqual(NON_ALIAS_PROOF, self.scene["authorship"]["nonAliasProof"])
        self.assertFalse(self.scene["authorship"]["siblingSceneOpened"])
        self.assertFalse(self.scene["authorship"]["siblingSceneCopied"])
        self.assertFalse(self.scene["authorship"]["siblingGeometryConsumed"])

    def test_direction_identity_and_no_render_authority(self) -> None:
        self.assertEqual("PLAY-080", self.scene["task"])
        self.assertEqual("south", self.scene["direction"])
        self.assertEqual("industrial_l04/variant-0/south/blender-art-v14-south-compatibility-v01", self.scene["sourceKey"])
        self.assertEqual("none", self.scene["orientationTransform"])
        self.assertFalse(self.scene["sourceAuthority"])
        self.assertFalse(self.scene["productionSelected"])
        self.assertFalse(self.scene["pixelRenderAuthorized"])
        self.assertFalse(self.materials["sourceAuthority"])
        self.assertFalse(self.materials["pixelRenderAuthorized"])
        self.assertFalse(self.materials["productionSelected"])

    def test_south_registration_bridge_and_camera(self) -> None:
        registration = self.scene["registration"]
        self.assertEqual([56, 56], registration["footprintWorld"]["size"])
        self.assertEqual([28, 0, 28], registration["groundPivot"])
        self.assertEqual("south", registration["frontageSocket"]["direction"])
        self.assertEqual([0, 0, 28], registration["frontageSocket"]["position"])
        self.assertEqual([0, 0, 1], registration["frontageSocket"]["outwardVector"])
        bridge = self.scene["coordinateBridge"]
        self.assertEqual("B(CitySim[x,y,z])=Blender[z,x,y]", bridge["formula"])
        self.assertEqual([0, 0, 28], bridge["canonicalCitySimSouthSocket"])
        self.assertEqual([28, 0, 0], bridge["blenderSouthSocket"])
        self.assertEqual([640, 832], bridge["sourceSouthSocket"])
        self.assertEqual("none", bridge["orientationTransform"])
        camera = self.scene["camera"]
        self.assertEqual("ORTHO", camera["type"])
        mapping = load(MAPPING_PATH)
        self.assertTrue(camera_matches_mapping(self.scene, mapping))
        self.assertEqual([192, 128], camera["literalViewportPixels"])
        self.assertEqual([640, 832], camera["projectionTargets"]["frontageSocket"])
        self.assertEqual([768, 896], camera["projectionTargets"]["groundPivot"])

    def test_component_bounds_ids_and_process_clearance(self) -> None:
        components = self.scene["components"]
        ids = [component["id"] for component in components]
        self.assertEqual(len(ids), len(set(ids)))
        for component in components:
            self.assertEqual("box", component["geometry"])
            self.assertIn(component["materialRole"], ROLES)
            self.assertNotIn("transform", component)
            x0, x1, y0, y1, z0, z1 = bounds(component)
            self.assertGreater(x1, x0)
            self.assertGreater(y1, y0)
            self.assertGreater(z1, z0)
            self.assertGreaterEqual(x0, -28)
            self.assertLessEqual(x1, 28)
            self.assertGreaterEqual(z0, -28)
            self.assertLessEqual(z1, 28)
            self.assertLessEqual(y1, 44 if any("stack" in tag for tag in component["tags"]) else 40)
        aperture = bounds(next(component for component in components if component["id"] == "south-portal-deep-void"))
        for component in components:
            if component["id"] in PORTAL_CONTENT_ALLOWLIST:
                continue
            x0, x1, y0, y1, z0, z1 = bounds(component)
            overlaps = x0 < aperture[1] and x1 > aperture[0] and y0 < aperture[3] and y1 > aperture[2] and z0 < aperture[5] and z1 > aperture[4]
            self.assertFalse(overlaps, component["id"])

    def test_portal_crown_and_literal192_feasibility(self) -> None:
        metrics = validate_packet(self.scene, self.materials)
        targets = self.scene["literal192Targets"]
        self.assertGreaterEqual(metrics["outerWidthPixels"], 20)
        self.assertGreaterEqual(metrics["outerHeightPixels"], 18)
        self.assertGreaterEqual(metrics["clearInsetWidthPixels"], 14)
        self.assertGreaterEqual(metrics["clearInsetHeightPixels"], 12)
        self.assertGreaterEqual(metrics["jambWidthPixelsEach"], 3)
        self.assertGreaterEqual(metrics["headerThicknessPixels"], 3)
        self.assertGreaterEqual(metrics["crownWidthPixels"], 20)
        self.assertGreaterEqual(metrics["distinctRoofHeightBreaks"], 3)
        self.assertLessEqual(metrics["stackSilhouetteShare"], 0.06)
        self.assertEqual([], metrics["intrusiveProcessComponents"])
        self.assertEqual([], metrics["intrusivePortalFrameComponents"])
        self.assertEqual([], metrics["intrusiveNonApertureSolids"])
        self.assertEqual([], metrics["intrusiveSourceProjectedSolids"])
        self.assertEqual([], metrics["sourceSpacePortalOccluders"])
        self.assertGreater(metrics["sourceApertureAreaPixels"], 0)
        self.assertEqual(0, metrics["portalOccludedShare"])
        self.assertEqual(0, metrics["processOrCranePixelsInsideInset"])
        self.assertGreaterEqual(metrics["freightBeatMinimumPixelsEach"][0], 4)
        self.assertGreaterEqual(metrics["freightBeatMinimumPixelsEach"][1], 8)
        self.assertGreaterEqual(metrics["staffEntryPixels"][0], 5)
        self.assertGreaterEqual(metrics["staffEntryPixels"][1], 8)
        coupling = metrics["frontageCoupling"]
        self.assertEqual("z", coupling["citySimPlaneAxis"])
        self.assertEqual(28, coupling["citySimPlaneCoordinate"])
        self.assertEqual([0, 0, 1], coupling["citySimOutwardNormal"])
        self.assertEqual("x", coupling["blenderPlaneAxis"])
        self.assertEqual(28, coupling["blenderPlaneCoordinate"])
        self.assertEqual([1, 0, 0], coupling["blenderOutwardNormal"])
        self.assertEqual([0, 0, 28], coupling["thresholdCitySim"])
        self.assertEqual([28, 0, 0], coupling["thresholdBlender"])
        self.assertTrue(coupling["portalProjectedContainsSocketX"])
        self.assertTrue(coupling["apronProjectedContainsSocketX"])
        self.assertLessEqual(abs(coupling["portalProjectedCentroidHorizontalDeltaPixels"]), 0.001)
        self.assertTrue(all(abs(distance) <= 1e-9 for distance in coupling["componentOuterPlaneDistancesWorld"].values()))
        self.assertEqual(3, metrics["freightBeatCount"])
        self.assertEqual([192, 128], metrics["projection"]["literalViewportPixels"])
        self.assertGreaterEqual(targets["minimumDistinctRoofHeightBreaks"], 3)
        self.assertTrue(targets["portal"]["nameableWithoutOverlay"])
        self.assertTrue(targets["feasibilityOnly"])
        self.assertEqual(0, targets["pixelFilesProduced"])

    def test_material_roles_complete_against_published_v13_roles(self) -> None:
        published_roles = {item["role"] for item in self.north_materials["materials"]}
        self.assertEqual(set(ROLES.values()), published_roles)
        self.assertEqual(set(ROLES), set(self.materials["requiredRoles"]))
        self.assertEqual(ROLES, self.materials["roleSources"])
        assigned = {component["materialRole"] for component in self.scene["components"]}
        self.assertEqual(set(ROLES), assigned)
        self.assertEqual(
            "c8179b77a184e41b723e26b34e7da2ef256b09e93b54a47e76cc5103f22b8cab",
            self.materials["publishedRoleAuthority"]["sha256"],
        )
        self.assertTrue(self.materials["numericValuesRequireIntegrationReconciliation"])

    def test_exact_identity_material_geometry_and_raw_non_alias_bindings(self) -> None:
        metrics = validate_packet(self.scene, self.materials)
        for name, expected in EXPECTED_SCENE_IDENTITY.items():
            self.assertEqual(expected, self.scene[name])
        self.assertEqual(EXPECTED_MATERIAL_AUTHORITY, self.materials["publishedRoleAuthority"])
        self.assertEqual(ROLES, self.materials["roleSources"])
        component_bindings = {
            component["id"]: component["materialRole"]
            for component in self.scene["components"]
        }
        component_kinds = {
            component["id"]: component["geometry"]
            for component in self.scene["components"]
        }
        self.assertEqual(EXPECTED_COMPONENT_MATERIAL_ROLES, component_bindings)
        self.assertEqual(set(EXPECTED_COMPONENT_MATERIAL_ROLES), set(component_kinds))
        self.assertEqual({"box"}, set(component_kinds.values()))
        identity = metrics["rawGeometryIdentity"]
        self.assertEqual(EXPECTED_RAW_GEOMETRY_SIGNATURES, identity["perComponent"])
        self.assertEqual(EXPECTED_RAW_GEOMETRY_SET_SHA256, identity["rawGeometrySetSha256"])
        self.assertEqual(identity["componentCount"], identity["uniqueSignatureCount"])
        self.assertEqual(["center", "size"], identity["signatureInputs"])

    def test_design_semantics_are_independent_of_north_geometry(self) -> None:
        north_design = self.north_authority["design"]
        self.assertTrue(north_design["materiallyDifferentFromV12"])
        self.assertIn("monumental portal", north_design["functionalHierarchy"][0])
        self.assertNotEqual(self.scene["semanticDesign"]["massing"], north_design["oneSentenceRead"])
        self.assertNotIn("north", self.scene["sourceKey"])
        self.assertNotIn("mirror", self.scene["semanticDesign"]["massing"])
        self.assertNotIn("rotate", self.scene["semanticDesign"]["massing"])

    def test_deterministic_packet_identity(self) -> None:
        first_packet = {
            "scene": load(SCENE_PATH),
            "materials": load(MATERIALS_PATH),
        }
        second_packet = {
            "scene": load(SCENE_PATH),
            "materials": load(MATERIALS_PATH),
        }
        first_bytes = json.dumps(first_packet, sort_keys=True, separators=(",", ":")).encode("utf-8")
        second_bytes = json.dumps(second_packet, sort_keys=True, separators=(",", ":")).encode("utf-8")
        self.assertEqual(hashlib.sha256(first_bytes).hexdigest(), hashlib.sha256(second_bytes).hexdigest())
        self.assertEqual(0, self.scene["literal192Targets"]["pixelFilesProduced"])

    def test_independent_geometry_replays_are_fresh_process_and_byte_identical(self) -> None:
        first_pid, first = run_fresh_lowering_process()
        second_pid, second = run_fresh_lowering_process()
        replay_hash = compare_fresh_replays(first_pid, first, second_pid, second)
        self.assertNotEqual(first_pid, second_pid)
        self.assertTrue(replay_hash)
        with self.assertRaises(ValueError):
            compare_fresh_replays(os.getpid(), first, os.getpid(), second)

    def test_derived_proof_adversaries_fail_closed(self) -> None:
        cases: list[tuple[str, object]] = []

        missing = copy.deepcopy(self.scene)
        missing["components"] = [
            component for component in missing["components"]
            if component["id"] != "south-portal-deep-void"
        ]
        cases.append(("missing-portal", lambda: validate_packet(missing, self.materials)))

        collapsed = copy.deepcopy(self.scene)
        next(component for component in collapsed["components"] if component["id"] == "south-portal-deep-void")["size"][2] = 0
        cases.append(("collapsed-portal", lambda: validate_packet(collapsed, self.materials)))

        occluded = copy.deepcopy(self.scene)
        next(component for component in occluded["components"] if component["id"] == "south-process-machine")["center"] = [0, 12, 27]
        cases.append(("occluded-portal", lambda: validate_packet(occluded, self.materials)))

        intrusive_frame = copy.deepcopy(self.scene)
        next(component for component in intrusive_frame["components"] if component["id"] == "south-portal-header")["center"] = [0, 12, 27.5]
        cases.append(("intrusive-portal-frame", lambda: validate_packet(intrusive_frame, self.materials)))

        generic_occluder = copy.deepcopy(self.scene)
        generic_occluder["components"].append({
            "id": "generic-full-aperture-solid",
            "geometry": "box",
            "center": [0, 12, 27],
            "size": [26, 20, 2],
            "materialRole": "v13-deep-freight-void",
            "tags": ["generic-solid"],
        })
        cases.append(("generic-full-aperture-solid", lambda: validate_packet(generic_occluder, self.materials)))

        camera_drift = copy.deepcopy(self.scene)
        camera_drift["camera"]["orthoScale"] += 1
        cases.append(("camera-drift", lambda: validate_packet(camera_drift, self.materials)))

        mapping_camera_drift = load(MAPPING_PATH)
        mapping_camera_drift["camera"]["blenderOrthographicScale"] += 1
        cases.append(("frozen-mapping-camera-drift", lambda: validate_packet(self.scene, self.materials, mapping=mapping_camera_drift)))

        socket_drift = copy.deepcopy(self.scene)
        socket_drift["registration"]["frontageSocket"]["position"] = [28, 0, 0]
        cases.append(("socket-drift", lambda: validate_packet(socket_drift, self.materials)))

        pivot_drift = copy.deepcopy(self.scene)
        pivot_drift["registration"]["groundPivot"] = [28, 0, 27]
        cases.append(("pivot-drift", lambda: validate_packet(pivot_drift, self.materials)))

        declaration_mismatch = copy.deepcopy(self.scene)
        declaration_mismatch["literal192Targets"]["portal"]["clearInsetWidthPixels"] += 1
        cases.append(("literal-declaration-mismatch", lambda: validate_packet(declaration_mismatch, self.materials)))

        alias = copy.deepcopy(self.scene)
        alias["authorship"]["nonAliasProof"]["geometryAlias"] = "north-v13"
        cases.append(("alias-proof", lambda: validate_packet(alias, self.materials)))

        malformed_proof = copy.deepcopy(self.scene)
        malformed_proof["authorship"]["nonAliasProof"]["proof"] = "copied"
        cases.append(("malformed-non-alias-proof", lambda: validate_packet(malformed_proof, self.materials)))

        missing_freight = copy.deepcopy(self.scene)
        missing_freight["components"] = [
            component for component in missing_freight["components"]
            if component["id"] != "south-freight-beat-c"
        ]
        cases.append(("missing-freight-beat", lambda: validate_packet(missing_freight, self.materials)))

        below_freight = copy.deepcopy(self.scene)
        next(component for component in below_freight["components"] if component["id"] == "south-freight-beat-a")["size"][0] = 4
        cases.append(("below-freight-threshold", lambda: validate_packet(below_freight, self.materials)))

        missing_measurement = copy.deepcopy(self.scene)
        del missing_measurement["literal192Targets"]["freightAndStaff"]["freightBeatMinimumPixelsEach"]
        cases.append(("missing-freight-measurement", lambda: validate_packet(missing_measurement, self.materials)))

        stale_measurement = copy.deepcopy(self.scene)
        stale_measurement["literal192Targets"]["freightAndStaff"]["staffEntryPixels"] = [4.0, 8.998543]
        cases.append(("stale-staff-measurement", lambda: validate_packet(stale_measurement, self.materials)))

        wrong_family = copy.deepcopy(self.scene)
        wrong_family["logicalBuildingID"] = "industrial-l04"
        wrong_family["sourceKey"] = "industrial-l04/variant-0/south/blender-art-v13-south-compatibility"
        wrong_family["authorship"]["nonAliasProof"]["sourceKey"] = wrong_family["sourceKey"]
        cases.append(("wrong-family-identity", lambda: validate_packet(wrong_family, self.materials)))

        east_facing_under_south_hashes = copy.deepcopy(self.scene)
        east_components = component_map(east_facing_under_south_hashes)
        east_geometry = {
            "south-integrated-apron": ([25, 0.15, 0], [6, 0.3, 48]),
            "south-staff-entry": ([27, 5, -22], [2, 10, 5]),
            "south-portal-left-jamb": ([26.5, 12, -15], [3, 24, 4]),
            "south-portal-right-jamb": ([26.5, 12, 15], [3, 24, 4]),
            "south-portal-header": ([26.5, 25, 0], [3, 4, 34]),
            "south-portal-deep-void": ([25, 12, 0], [1, 20, 26]),
            "south-freight-beat-a": ([24, 6, -9], [1, 10, 4]),
            "south-freight-beat-b": ([24, 6, 0], [1, 10, 4]),
            "south-freight-beat-c": ([24, 6, 9], [1, 10, 4]),
        }
        for component_id, (center, size) in east_geometry.items():
            east_components[component_id]["center"] = center
            east_components[component_id]["size"] = size
        east_facing_under_south_hashes["registration"]["contactPolygon"] = [
            [16, 0, -24], [28, 0, -24], [28, 0, 24], [16, 0, 24]
        ]
        east_facing_under_south_hashes["registration"]["entranceExclusionZone"] = {
            "x": [27.5, 28], "y": [0, 26], "z": [-13, 13]
        }
        cases.append((
            "coherent-east-facing-under-south-hashes",
            lambda: validate_packet(east_facing_under_south_hashes, self.materials),
        ))

        camera_axis_occluder = copy.deepcopy(self.scene)
        frozen_mapping = load(MAPPING_PATH)
        camera_forward = normalize(
            subtract(
                frozen_mapping["camera"]["blenderTarget"],
                frozen_mapping["camera"]["blenderPosition"],
            )
        )
        citysim_shift = matrix_vector(
            invert_matrix(frozen_mapping["basis"]["matrixRows"]),
            [-value * 100 for value in camera_forward],
        )
        aperture_source = next(
            component for component in camera_axis_occluder["components"]
            if component["id"] == "south-portal-deep-void"
        )
        camera_axis_occluder["components"].append(
            {
                "id": "generic-camera-axis-full-aperture-solid",
                "geometry": "box",
                "center": [
                    aperture_source["center"][axis] + citysim_shift[axis]
                    for axis in range(3)
                ],
                "size": copy.deepcopy(aperture_source["size"]),
                "materialRole": "v13-warm-foundry-masonry",
                "tags": ["generic-solid"],
                "flags": {"portal": {"apertureContent": True}},
            }
        )
        cases.append(("camera-axis-world-disjoint-occluder", lambda: validate_packet(camera_axis_occluder, self.materials)))

        nested_flag = copy.deepcopy(self.scene)
        next(
            component for component in nested_flag["components"]
            if component["id"] == "south-foundry-hall"
        )["flags"] = {"portal": {"apertureContent": True}}
        cases.append(("nested-aperture-flag", lambda: validate_packet(nested_flag, self.materials)))

        logical_identity = copy.deepcopy(self.scene)
        logical_identity["logicalBuildingID"] = "commercial-l04"
        cases.append(("logical-building-identity", lambda: validate_packet(logical_identity, self.materials)))

        variant_identity = copy.deepcopy(self.scene)
        variant_identity["variant"] = "variant-forged"
        cases.append(("variant-identity", lambda: validate_packet(variant_identity, self.materials)))

        role_source = copy.deepcopy(self.materials)
        role_source["roleSources"]["v13-grounded-foundation"] = "forged-source"
        cases.append(("material-role-source", lambda: validate_packet(self.scene, role_source)))

        component_binding = copy.deepcopy(self.scene)
        component_binding["components"][0]["materialRole"], component_binding["components"][1]["materialRole"] = (
            component_binding["components"][1]["materialRole"],
            component_binding["components"][0]["materialRole"],
        )
        cases.append(("component-material-binding", lambda: validate_packet(component_binding, self.materials)))

        geometry_kind = copy.deepcopy(self.scene)
        geometry_kind["components"][0]["geometry"] = "sphere"
        cases.append(("geometry-kind", lambda: validate_packet(geometry_kind, self.materials)))

        geometry_alias = copy.deepcopy(self.scene)
        alias_components = component_map(geometry_alias)
        alias_components["south-hot-process-cue"]["center"] = copy.deepcopy(
            alias_components["south-process-machine"]["center"]
        )
        alias_components["south-hot-process-cue"]["size"] = copy.deepcopy(
            alias_components["south-process-machine"]["size"]
        )
        cases.append(("raw-geometry-alias", lambda: validate_packet(geometry_alias, self.materials)))

        cases.append(("path-escape", lambda: validate_packet(self.scene, self.materials, "../INTEGRATION/evil.json")))

        expected_errors = {
            "below-freight-threshold": "freight beat below 4x8 source pixels",
            "wrong-family-identity": "scene identity mismatch: logicalBuildingID",
            "coherent-east-facing-under-south-hashes": "South frontage thin axis mismatch",
            "camera-axis-world-disjoint-occluder": "source-space portal occlusion",
            "nested-aperture-flag": "unexpected component fields",
            "logical-building-identity": "scene identity mismatch: logicalBuildingID",
            "variant-identity": "scene identity mismatch: variant",
            "material-role-source": "material role source mapping mismatch",
            "component-material-binding": "component material binding mismatch",
            "geometry-kind": "component geometry kind mismatch",
            "raw-geometry-alias": "raw geometry alias detected",
        }
        for name, operation in cases:
            with self.subTest(name=name):
                with self.assertRaisesRegex(ValueError, expected_errors.get(name, ".+")):
                    operation()

    def test_v14_family_semantic_adversaries_fail_closed(self) -> None:
        missing = copy.deepcopy(self.scene)
        missing["components"] = [
            component for component in missing["components"]
            if component["id"] != "south-process-vessel"
        ]
        with self.assertRaisesRegex(ValueError, "component identity set mismatch"):
            validate_packet(missing, self.materials)

        envelope = copy.deepcopy(self.scene)
        next(component for component in envelope["components"] if component["id"] == "south-crane-lantern")["center"][1] = 40
        with self.assertRaisesRegex(ValueError, "vertical envelope exceeds v14 limit"):
            validate_packet(envelope, self.materials)

        stack = copy.deepcopy(self.scene)
        next(component for component in stack["components"] if component["id"] == "south-boiler-stack")["center"][1] = 25
        with self.assertRaisesRegex(ValueError, "vertical envelope exceeds v14 limit"):
            validate_packet(stack, self.materials)

        vocabulary = copy.deepcopy(self.scene)
        vocabulary["semanticDesign"]["familyVocabulary"] = ["generic-warehouse"]
        with self.assertRaisesRegex(ValueError, "v14 family vocabulary mismatch"):
            validate_packet(vocabulary, self.materials)

    def test_result_binds_repair_route_and_claim_revision(self) -> None:
        result = load(REPO_ROOT / RESULT_RELATIVE_PATH)
        self.assertEqual("quality-v1:play-080-industrial-l04-v14-south-prelock-v1", result["route"]["routeId"])
        self.assertEqual("276b05f46471742320c2930c2d0b5e7fed07e70f16a855b3a22aa3942edaa282", result["route"]["routeSha256"])
        self.assertEqual("2b2558835d5382d15f92f58a538c5795f82d3875867e17dd686b23dc8d738e00", result["route"]["receiptSha256"])
        self.assertEqual(9, result["claim"]["revision"])
        self.assertEqual("05518763984850e3cb12fb4b89234802cd66dba4", result["candidateProjection"]["observedHead"])
        self.assertEqual("05518763984850e3cb12fb4b89234802cd66dba4", result["candidateProjection"]["requiredDirectParent"])
        self.assertEqual(sha256(SCENE_PATH), result["packet"]["scene"]["sha256"])
        self.assertEqual(sha256(MATERIALS_PATH), result["packet"]["materials"]["sha256"])
        self.assertEqual(sha256(Path(__file__).resolve()), result["packet"]["validator"]["sha256"])
        self.assertEqual(
            EXPECTED_RAW_GEOMETRY_SET_SHA256,
            result["derivedProof"]["rawGeometryNonAlias"]["rawGeometrySetSha256"],
        )
        self.assertEqual(0, result["zeroPixelBoundary"]["dccInvocations"])
        self.assertEqual(0, result["zeroPixelBoundary"]["pixelFiles"])


if __name__ == "__main__":
    if "--emit-lowering" in sys.argv:
        print(serialize_lowered_packet(load(SCENE_PATH), load(MAPPING_PATH)))
        raise SystemExit(0)
    unittest.main(verbosity=2)
