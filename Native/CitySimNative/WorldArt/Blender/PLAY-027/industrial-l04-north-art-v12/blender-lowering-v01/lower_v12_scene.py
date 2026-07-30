#!/usr/bin/env python3
"""Pure-data canonical lowering for the frozen PLAY-027 North v12 scene."""

from __future__ import annotations

import copy
import hashlib
import json
import math
import os
import stat
from pathlib import Path
from typing import Any


EXPECTED_PRISM_VERTICES = [
    [3.5, 1, -12.8],
    [3.5, 1, -6.8],
    [9.5, 1, -12.8],
    [3.5, 19, -12.8],
    [3.5, 19, -6.8],
    [9.5, 19, -12.8],
]
EXPECTED_PRISM_FACES = [
    [0, 2, 1],
    [3, 4, 5],
    [0, 1, 4, 3],
    [1, 2, 5, 4],
    [2, 0, 3, 5],
]
BOX_FIELDS = {
    "id", "shape", "group", "dimensions", "position", "materialID", "bevel"
}
BOX_OWNER_FIELDS = BOX_FIELDS | {"semanticOwnerID"}
PRISM_FIELDS = {
    "id", "shape", "group", "footprintXZ", "yBounds", "vertices", "faces",
    "materialID", "bevel", "semanticOwnerID",
}
SOURCE_ROOT_REL = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/blender-lowering-v01"
)
RUN_NEUTRAL_FILES = [
    "CANONICAL-MESH-IR.json",
    "OBJECT-MAPPING.json",
    "PROJECTION.json",
    "TOPOLOGY.json",
    "INPUT-BINDINGS.json",
    "VALIDATION.json",
]


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"JSON object required: {path}")
    return value


def repository_path(root: Path, relative: str) -> Path:
    if Path(relative).is_absolute() or ".." in Path(relative).parts:
        raise RuntimeError(f"repository-relative path required: {relative}")
    root = root.resolve()
    path = root.joinpath(relative)
    current = root
    for part in Path(relative).parts:
        current = current / part
        if current.is_symlink():
            raise RuntimeError(f"symlink path component rejected: {current}")
    resolved = path.resolve(strict=True)
    resolved.relative_to(root)
    if not stat.S_ISREG(resolved.stat().st_mode):
        raise RuntimeError(f"regular input required: {resolved}")
    return resolved


def verify_binding(root: Path, record: dict[str, Any]) -> Path:
    path = repository_path(root, record["file"])
    actual = sha256(path)
    if actual != record["sha256"]:
        raise RuntimeError(
            f"hash drift: {record['file']}: expected {record['sha256']}, got {actual}"
        )
    return path


def basis(vector: list[float]) -> list[float]:
    if len(vector) != 3:
        raise RuntimeError("three-dimensional vector required")
    values = [float(value) for value in vector]
    if not all(math.isfinite(value) for value in values):
        raise RuntimeError("non-finite coordinate")
    return [values[2], values[0], values[1]]


def vector_sub(a: list[float], b: list[float]) -> list[float]:
    return [a[index] - b[index] for index in range(3)]


def cross(a: list[float], b: list[float]) -> list[float]:
    return [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]


def dot(a: list[float], b: list[float]) -> float:
    return sum(a[index] * b[index] for index in range(3))


def length(value: list[float]) -> float:
    return math.sqrt(dot(value, value))


def face_area(vertices: list[list[float]]) -> float:
    origin = vertices[0]
    return sum(
        length(
            cross(
                vector_sub(vertices[index], origin),
                vector_sub(vertices[index + 1], origin),
            )
        ) / 2.0
        for index in range(1, len(vertices) - 1)
    )


def face_normal(vertices: list[list[float]]) -> list[float]:
    raw = cross(
        vector_sub(vertices[1], vertices[0]),
        vector_sub(vertices[2], vertices[0]),
    )
    magnitude = length(raw)
    if magnitude <= 0.0000001:
        raise RuntimeError("degenerate polygon")
    return [value / magnitude for value in raw]


def box_mesh(item: dict[str, Any]) -> tuple[list[list[float]], list[list[int]]]:
    px, py, pz = (float(value) for value in item["position"])
    dx, dy, dz = (float(value) / 2.0 for value in item["dimensions"])
    if min(dx, dy, dz) <= 0.0:
        raise RuntimeError(f"non-positive box dimension: {item['id']}")
    vertices = [
        [px - dx, py - dy, pz - dz],
        [px + dx, py - dy, pz - dz],
        [px + dx, py - dy, pz + dz],
        [px - dx, py - dy, pz + dz],
        [px - dx, py + dy, pz - dz],
        [px + dx, py + dy, pz - dz],
        [px + dx, py + dy, pz + dz],
        [px - dx, py + dy, pz + dz],
    ]
    faces = [
        [0, 1, 2, 3],
        [4, 7, 6, 5],
        [0, 4, 5, 1],
        [1, 5, 6, 2],
        [2, 6, 7, 3],
        [3, 7, 4, 0],
    ]
    return vertices, faces


def octagonal_mesh(
    item: dict[str, Any],
) -> tuple[list[list[float]], list[list[int]]]:
    px, py, pz = (float(value) for value in item["position"])
    dx, dy, dz = (float(value) / 2.0 for value in item["dimensions"])
    if min(dx, dy, dz) <= 0.0:
        raise RuntimeError(f"non-positive octagonal dimension: {item['id']}")
    vertices = []
    for height in (py - dy, py + dy):
        for index in range(8):
            angle = 2.0 * math.pi * float(index) / 8.0
            vertices.append([
                px + math.cos(angle) * dx,
                height,
                pz + math.sin(angle) * dz,
            ])
    faces = [list(range(8)), list(range(15, 7, -1))]
    for index in range(8):
        following = (index + 1) % 8
        faces.append([index, index + 8, following + 8, following])
    return vertices, faces


def component_mesh(
    item: dict[str, Any],
) -> tuple[list[list[float]], list[list[int]]]:
    shape = item["shape"]
    allowed = (
        PRISM_FIELDS if shape == "triangular-prism"
        else BOX_OWNER_FIELDS if "semanticOwnerID" in item
        else BOX_FIELDS
    )
    if set(item) != allowed:
        raise RuntimeError(f"unsupported or extra component fields: {item['id']}")
    if shape == "box":
        return box_mesh(item)
    if shape == "octagonal-prism":
        return octagonal_mesh(item)
    if shape != "triangular-prism":
        raise RuntimeError(f"unsupported physical shape: {shape}")
    if (
        item["id"] != "v12-west-pier-camera-reveal"
        or item["vertices"] != EXPECTED_PRISM_VERTICES
        or item["faces"] != EXPECTED_PRISM_FACES
        or item["footprintXZ"] != [[3.5, -12.8], [3.5, -6.8], [9.5, -12.8]]
        or item["yBounds"] != [1, 19]
    ):
        raise RuntimeError("authorized triangular-prism mesh/order drift")
    return copy.deepcopy(item["vertices"]), copy.deepcopy(item["faces"])


def source_faces(item: dict[str, Any]) -> list[dict[str, Any]]:
    vertices, faces = component_mesh(item)
    center = [
        sum(vertex[index] for vertex in vertices) / len(vertices)
        for index in range(3)
    ]
    result = []
    for source_index, face in enumerate(faces):
        polygon = [vertices[index] for index in face]
        normal = face_normal(polygon)
        face_center = [
            sum(vertex[index] for vertex in polygon) / len(polygon)
            for index in range(3)
        ]
        if dot(normal, vector_sub(face_center, center)) <= 0.0000001:
            raise RuntimeError(
                f"non-outward winding: {item['id']}:{source_index}"
            )
        result.append({
            "physicalComponentID": item["id"],
            "semanticOwnerID": item.get("semanticOwnerID", item["id"]),
            "sourceFaceIndex": source_index,
            "verticesCitySim": polygon,
            "normalCitySim": normal,
            "sourceArea": face_area(polygon),
            "materialID": item["materialID"],
        })
    return result


def axis_rectangle(face: dict[str, Any], axis: int, plane: float) -> dict[str, Any]:
    vertices = face["verticesCitySim"]
    if any(abs(vertex[axis] - plane) > 0.000001 for vertex in vertices):
        raise RuntimeError("interface face plane drift")
    normal = face["normalCitySim"]
    if abs(abs(normal[axis]) - 1.0) > 0.000001:
        raise RuntimeError("axis-aligned interface required")
    other = [index for index in range(3) if index != axis]
    low = [min(vertex[index] for vertex in vertices) for index in other]
    high = [max(vertex[index] for vertex in vertices) for index in other]
    if abs(face["sourceArea"] - (high[0] - low[0]) * (high[1] - low[1])) > 0.000001:
        raise RuntimeError("rectangular interface face required")
    return {"other": other, "low": low, "high": high, "normal": normal}


def shared_rectangle(
    first: dict[str, Any], second: dict[str, Any], axis: int, plane: float
) -> dict[str, Any]:
    a = axis_rectangle(first, axis, plane)
    b = axis_rectangle(second, axis, plane)
    low = [max(a["low"][index], b["low"][index]) for index in range(2)]
    high = [min(a["high"][index], b["high"][index]) for index in range(2)]
    if high[0] <= low[0] or high[1] <= low[1]:
        raise RuntimeError("same-owner interface gap")
    return {
        "axis": axis,
        "plane": plane,
        "other": a["other"],
        "low": low,
        "high": high,
        "area": (high[0] - low[0]) * (high[1] - low[1]),
    }


def rectangle_polygon(
    axis: int,
    plane: float,
    other: list[int],
    low: list[float],
    high: list[float],
    expected_normal: list[float],
) -> list[list[float]]:
    points = []
    for first, second in (
        (low[0], low[1]),
        (high[0], low[1]),
        (high[0], high[1]),
        (low[0], high[1]),
    ):
        point = [0.0, 0.0, 0.0]
        point[axis] = plane
        point[other[0]] = first
        point[other[1]] = second
        points.append(point)
    if dot(face_normal(points), expected_normal) < 0.0:
        points.reverse()
    return points


def subtract_rectangle(
    face: dict[str, Any], shared: dict[str, Any]
) -> list[dict[str, Any]]:
    rectangle = axis_rectangle(face, shared["axis"], shared["plane"])
    low, high = rectangle["low"], rectangle["high"]
    cut_low, cut_high = shared["low"], shared["high"]
    fragments: list[tuple[list[float], list[float]]] = []
    if cut_low[1] > low[1]:
        fragments.append(([low[0], low[1]], [high[0], cut_low[1]]))
    if cut_high[1] < high[1]:
        fragments.append(([low[0], cut_high[1]], [high[0], high[1]]))
    if cut_low[0] > low[0]:
        fragments.append(([low[0], cut_low[1]], [cut_low[0], cut_high[1]]))
    if cut_high[0] < high[0]:
        fragments.append(([cut_high[0], cut_low[1]], [high[0], cut_high[1]]))
    result = []
    for fragment_index, (fragment_low, fragment_high) in enumerate(fragments):
        if min(
            fragment_high[index] - fragment_low[index] for index in range(2)
        ) <= 0.0000001:
            continue
        value = copy.deepcopy(face)
        value["verticesCitySim"] = rectangle_polygon(
            shared["axis"],
            shared["plane"],
            shared["other"],
            fragment_low,
            fragment_high,
            face["normalCitySim"],
        )
        value["fragmentIndex"] = fragment_index
        value["area"] = face_area(value["verticesCitySim"])
        result.append(value)
    return result


def interface_faces(
    faces_by_component: dict[str, list[dict[str, Any]]],
    specification: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    matches = []
    for component_id in specification["components"]:
        component_matches = []
        for face in faces_by_component[component_id]:
            try:
                axis_rectangle(face, specification["axis"], specification["plane"])
                component_matches.append(face)
            except RuntimeError:
                continue
        if len(component_matches) != 1:
            raise RuntimeError(
                f"{specification['name']}: exactly one interface face required"
            )
        if component_matches[0]["semanticOwnerID"] != specification["semanticOwnerID"]:
            raise RuntimeError(f"{specification['name']}: semantic owner drift")
        matches.append(component_matches[0])
    shared = shared_rectangle(
        matches[0], matches[1], specification["axis"], specification["plane"]
    )
    if abs(shared["area"] * 2.0 - specification["removedArea"]) > 0.000001:
        raise RuntimeError(f"{specification['name']}: removed area drift")
    return matches[0], matches[1], shared


def canonical_face_key(face: dict[str, Any]) -> str:
    payload = {
        "physicalComponentID": face["physicalComponentID"],
        "sourceFaceIndex": face["sourceFaceIndex"],
        "fragmentIndex": face.get("fragmentIndex", 0),
        "verticesCitySim": face["verticesCitySim"],
    }
    return sha256_bytes(canonical_bytes(payload))


def split_t_junction_edges(
    vertices: list[list[float]], polygons: list[list[int]]
) -> tuple[list[list[int]], int]:
    """Split polygon edges at every existing collinear vertex, then audit closure."""
    result = []
    for polygon in polygons:
        split_polygon: list[int] = []
        for edge_index, start_index in enumerate(polygon):
            end_index = polygon[(edge_index + 1) % len(polygon)]
            start = vertices[start_index]
            end = vertices[end_index]
            direction = vector_sub(end, start)
            denominator = dot(direction, direction)
            if denominator <= 0.0000001:
                raise RuntimeError("zero-length polygon edge")
            interior = []
            for candidate_index, candidate in enumerate(vertices):
                if candidate_index in (start_index, end_index):
                    continue
                relative = vector_sub(candidate, start)
                parameter = dot(relative, direction) / denominator
                if parameter <= 0.0000001 or parameter >= 0.9999999:
                    continue
                nearest = [
                    start[coordinate] + parameter * direction[coordinate]
                    for coordinate in range(3)
                ]
                if length(vector_sub(candidate, nearest)) <= 0.0000001:
                    interior.append((parameter, candidate_index))
            split_polygon.append(start_index)
            split_polygon.extend(
                candidate_index for _, candidate_index in sorted(interior)
            )
        if len(split_polygon) != len(set(split_polygon)):
            raise RuntimeError("polygon edge split introduced duplicate vertex")
        result.append(split_polygon)
    incidences: dict[tuple[int, int], int] = {}
    for polygon in result:
        for edge_index, start_index in enumerate(polygon):
            end_index = polygon[(edge_index + 1) % len(polygon)]
            edge = tuple(sorted((start_index, end_index)))
            incidences[edge] = incidences.get(edge, 0) + 1
    non_manifold = sum(1 for count in incidences.values() if count != 2)
    return result, non_manifold


def lower_scene(
    repository_root: Path, contract: dict[str, Any]
) -> dict[str, Any]:
    bindings = {}
    for key in (
        "claim", "authority", "scene", "materials", "bridge",
        "compoundAuditTool", "analyticReplayIdentity", "compoundAudit",
        "compoundAdversaries", "compoundDisposition", "replayPreservation",
    ):
        path = verify_binding(repository_root, contract[key])
        bindings[key] = {
            "file": contract[key]["file"],
            "sha256": sha256(path),
        }
    bridge = load_json(
        repository_path(repository_root, contract["bridge"]["file"])
    )
    if (
        contract["bridge"]["formula"]
        != "B(CitySim[x,y,z])=Blender[z,x,y]"
        or contract["bridge"]["determinant"] != 1
        or bridge["basis"]["formula"] != contract["bridge"]["formula"]
        or bridge["basis"]["determinant"] != 1
        or bridge["basis"]["matrixRows"]
        != [[0, 0, 1], [1, 0, 0], [0, 1, 0]]
        or bridge["basis"]["perDirectionTransforms"] is not False
        or bridge["basis"]["windingChange"] is not False
        or basis([1, 0, 0]) != [0.0, 1.0, 0.0]
        or basis([0, 1, 0]) != [0.0, 0.0, 1.0]
        or basis([0, 0, 1]) != [1.0, 0.0, 0.0]
    ):
        raise RuntimeError("coordinate basis contract drift")
    scene = load_json(repository_path(repository_root, contract["scene"]["file"]))
    materials = load_json(
        repository_path(repository_root, contract["materials"]["file"])
    )
    expected = contract["expected"]
    identity = {
        "logicalBuildingID": scene["logicalBuildingID"],
        "variantID": scene["variantID"],
        "viewDirection": scene["viewDirection"],
        "sourceRevision": scene["sourceRevision"],
        "sceneGeometryID": scene["sceneGeometryID"],
        "orientationTransform": scene["orientationTransform"],
    }
    for key, value in identity.items():
        if value != expected[key]:
            raise RuntimeError(f"scene identity drift: {key}")
    if scene["pixelProduction"] != "not_produced":
        raise RuntimeError("pixel production must remain frozen")
    physical_ids = [item["id"] for item in scene["components"]]
    if len(physical_ids) != expected["physicalComponentCount"]:
        raise RuntimeError("physical component count drift")
    if len(set(physical_ids)) != len(physical_ids):
        raise RuntimeError("duplicate physical component ID")
    material_ids = [item["id"] for item in materials["materials"]]
    if len(material_ids) != expected["materialCount"] or len(set(material_ids)) != len(material_ids):
        raise RuntimeError("material inventory drift")
    unresolved = sorted({
        item["materialID"] for item in scene["components"]
        if item["materialID"] not in set(material_ids)
    })
    if unresolved:
        raise RuntimeError(f"unresolved materials: {unresolved}")
    shape_counts: dict[str, int] = {}
    faces_by_component = {}
    for item in scene["components"]:
        shape_counts[item["shape"]] = shape_counts.get(item["shape"], 0) + 1
        faces_by_component[item["id"]] = source_faces(item)
    if shape_counts != expected["shapeCounts"]:
        raise RuntimeError("shape inventory drift")
    source_face_count = sum(len(value) for value in faces_by_component.values())
    if source_face_count != expected["sourceFaceCount"]:
        raise RuntimeError("source face count drift")

    removed_keys: set[tuple[str, int]] = set()
    replacement_faces: list[dict[str, Any]] = []
    interface_reports = []
    removed_area = 0.0
    for specification in contract["compoundInterfaces"]:
        first, second, shared = interface_faces(faces_by_component, specification)
        for face in (first, second):
            removed_keys.add(
                (face["physicalComponentID"], face["sourceFaceIndex"])
            )
            replacement_faces.extend(subtract_rectangle(face, shared))
        removed = shared["area"] * 2.0
        removed_area += removed
        interface_reports.append({
            "name": specification["name"],
            "semanticOwnerID": specification["semanticOwnerID"],
            "physicalComponents": specification["components"],
            "axis": specification["axis"],
            "plane": specification["plane"],
            "sharedRectangle": {
                "low": shared["low"],
                "high": shared["high"],
                "area": shared["area"],
            },
            "removedInternalFaceArea": removed,
            "remainingInternalFaceArea": 0.0,
            "passed": True,
        })
    output_faces = [
        copy.deepcopy(face)
        for component_faces in faces_by_component.values()
        for face in component_faces
        if (face["physicalComponentID"], face["sourceFaceIndex"]) not in removed_keys
    ] + replacement_faces
    for face in output_faces:
        face.setdefault("fragmentIndex", 0)
        face["area"] = face_area(face["verticesCitySim"])
        face["canonicalFaceKey"] = canonical_face_key(face)
        face["verticesBlender"] = [basis(vertex) for vertex in face["verticesCitySim"]]

    objects = []
    mapping = []
    for owner in sorted({face["semanticOwnerID"] for face in output_faces}):
        owner_faces = sorted(
            [face for face in output_faces if face["semanticOwnerID"] == owner],
            key=lambda item: item["canonicalFaceKey"],
        )
        material_set = {face["materialID"] for face in owner_faces}
        if len(material_set) != 1:
            raise RuntimeError(f"semantic compound material split: {owner}")
        vertex_lookup: dict[tuple[float, float, float], int] = {}
        vertices: list[list[float]] = []
        polygons = []
        for polygon_index, face in enumerate(owner_faces):
            indices = []
            for vertex in face["verticesBlender"]:
                key = tuple(round(value, 12) for value in vertex)
                if key not in vertex_lookup:
                    vertex_lookup[key] = len(vertices)
                    vertices.append([float(value) for value in key])
                indices.append(vertex_lookup[key])
            polygons.append(indices)
            mapping.append({
                "objectName": owner,
                "polygonIndex": polygon_index,
                "physicalComponentID": face["physicalComponentID"],
                "sourceFaceIndex": face["sourceFaceIndex"],
                "fragmentIndex": face["fragmentIndex"],
                "canonicalFaceKey": face["canonicalFaceKey"],
            })
        members = sorted({
            face["physicalComponentID"] for face in owner_faces
        })
        polygons, non_manifold = split_t_junction_edges(vertices, polygons)
        if non_manifold:
            raise RuntimeError(
                f"non-manifold semantic compound: {owner}: {non_manifold} edges"
            )
        objects.append({
            "objectName": owner,
            "physicalComponentIDs": members,
            "semanticOwnerID": owner,
            "materialID": next(iter(material_set)),
            "verticesBlenderWorld": vertices,
            "polygons": polygons,
            "identityTransform": True,
            "applyBevel": False,
        })
    if len(objects) != expected["semanticObjectCount"]:
        raise RuntimeError("semantic object count drift")
    mapped_ids = sorted({
        record["physicalComponentID"] for record in mapping
    })
    if mapped_ids != sorted(physical_ids):
        raise RuntimeError("physical component mapping incomplete")

    boundary_area = sum(face["area"] for face in output_faces)
    if abs(removed_area - expected["removedInternalFaceArea"]) > 0.000001:
        raise RuntimeError("removed internal area drift")
    if abs(boundary_area - expected["compoundBoundarySurfaceArea"]) > 0.000001:
        raise RuntimeError(
            f"compound boundary area drift: {boundary_area}"
        )
    audit = load_json(
        repository_path(repository_root, contract["compoundAudit"]["file"])
    )
    if (
        audit["remainingInternalFaceArea"] != 0.0
        or audit["removedInternalFaceArea"] != expected["removedInternalFaceArea"]
        or audit["intentionalDifferentOwnerContact"]["sharedArea"]
        != expected["differentOwnerContactArea"]
    ):
        raise RuntimeError("bound compound audit drift")

    camera = scene["camera"]
    projection = {
        "projection": camera["projection"],
        "resolution": camera["renderViewportPixels"],
        "cameraLocationBlender": basis(camera["positionWorld"]),
        "cameraTargetBlender": basis(camera["targetWorld"]),
        "orthographicScaleBlender": (
            2.0 * float(camera["orthographicScale"])
            * float(camera["renderViewportPixels"][0])
            / float(camera["renderViewportPixels"][1])
        ),
        "shiftX": (
            float(camera["postProjectionOffsetPixels"][0])
            / float(camera["renderViewportPixels"][0])
        ),
        "shiftY": (
            float(camera["postProjectionOffsetPixels"][1])
            / float(camera["renderViewportPixels"][0])
        ),
        "footprintExpectedSource": scene["registration"]["footprintPolygonSource"],
        "pivotExpectedSource": scene["registration"]["groundPivotSource"],
        "socketExpectedSource": scene["registration"]["frontageSocketSource"],
        "originExpectedSource": camera["sourceGroundCenter"],
        "maximumAllowedErrorSourcePixels": expected[
            "maximumRegistrationErrorSourcePixels"
        ],
    }
    authored_shadow_vertices = [
        basis([
            point[0] + scene["shadow"]["offsetWorldXZ"][0],
            0.025,
            point[1] + scene["shadow"]["offsetWorldXZ"][1],
        ])
        for point in scene["shadow"]["polygonWorldXZ"]
    ]
    topology = {
        "physicalComponentCount": len(physical_ids),
        "semanticObjectCount": len(objects),
        "sourceFaceCount": source_face_count,
        "outputPolygonCount": len(mapping),
        "shapeCounts": shape_counts,
        "interfaceAudits": interface_reports,
        "removedInternalFaceFragmentCount": expected[
            "removedInternalFaceFragmentCount"
        ],
        "removedInternalFaceArea": removed_area,
        "remainingInternalFaceArea": 0.0,
        "compoundBoundarySurfaceArea": boundary_area,
        "differentOwnerPierHeaderContactArea": expected[
            "differentOwnerContactArea"
        ],
        "nonManifoldEdgeCount": 0,
        "bevelModifierCount": 0,
        "passed": True,
    }
    mesh_ir = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": contract["stage"],
        "coordinateBasis": contract["bridge"]["formula"],
        "basisDeterminant": contract["bridge"]["determinant"],
        "identity": identity,
        "objects": objects,
        "materials": sorted(materials["materials"], key=lambda item: item["id"]),
        "camera": projection,
        "light": {
            "locationBlender": basis(scene["light"]["keyOrigin"]),
            "targetBlender": basis([0.0, 0.0, 0.0]),
            "shadowDirection": scene["light"]["shadowDirection"],
            "shadowVectorSource": scene["light"]["shadowVectorSource"],
        },
        "authoredShadow": {
            "id": scene["shadow"]["id"],
            "verticesBlenderWorld": authored_shadow_vertices,
            "opacity": scene["shadow"]["opacity"],
        },
        "registration": copy.deepcopy(scene["registration"]),
        "cyclesProvenanceOnly": copy.deepcopy(scene["cycles"]),
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    object_mapping = {
        "schema": 1,
        "task": "PLAY-027",
        "physicalComponentCount": len(physical_ids),
        "semanticObjectCount": len(objects),
        "entries": sorted(
            mapping,
            key=lambda item: (item["objectName"], item["polygonIndex"]),
        ),
        "allPhysicalComponentsMapped": True,
        "duplicatePhysicalIDs": [],
    }
    input_bindings = {
        "schema": 1,
        "task": "PLAY-027",
        "bindings": bindings,
        "contractSHA256": sha256_bytes(canonical_bytes(contract)),
    }
    validation = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": contract["stage"],
        "gates": {
            "inputBindingsExact": True,
            "identityExact": True,
            "shapeInventoryExact": True,
            "physicalIDsUnique": True,
            "materialsResolved": True,
            "mappingComplete": True,
            "basisAppliedExactlyOnce": True,
            "basisDeterminantPositive": True,
            "triangularPrismExact": True,
            "sixInternalFragmentsRemoved": True,
            "remainingInternalAreaZero": True,
            "boundaryAreaExact": True,
            "differentOwnerContactPreserved": True,
            "identityObjectTransforms": True,
            "bevelDisabled": True,
            "renderDisabled": True,
            "pixelsAbsent": True,
        },
        "validationPassed": True,
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "bevelModifierCount": 0,
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    return {
        "CANONICAL-MESH-IR.json": mesh_ir,
        "OBJECT-MAPPING.json": object_mapping,
        "PROJECTION.json": projection,
        "TOPOLOGY.json": topology,
        "INPUT-BINDINGS.json": input_bindings,
        "VALIDATION.json": validation,
    }


def ensure_absent_output_root(path: Path) -> Path:
    if not path.is_absolute():
        raise RuntimeError("absolute output root required")
    if path.exists() or path.is_symlink():
        raise RuntimeError(f"output root must be absent: {path}")
    parent = path.parent.resolve(strict=True)
    if parent.is_symlink() or not parent.is_dir():
        raise RuntimeError("regular output parent required")
    path.mkdir(mode=0o755)
    return path


def exclusive_write_json(root: Path, name: str, value: Any) -> None:
    if name not in RUN_NEUTRAL_FILES:
        raise RuntimeError(f"unapproved pure output: {name}")
    if root.is_symlink() or not root.is_dir():
        raise RuntimeError("output root drift")
    path = root / name
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(path, flags, 0o644)
    try:
        os.write(descriptor, canonical_bytes(value))
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
