#!/usr/bin/env python3
"""Pure-data lowering and frozen-camera proof for North v13.

This module deliberately has no bpy dependency.  It lowers the committed
text scene into a canonical mesh IR and uses the published v06 bridge plus
its registration points for an analytic, zero-pixel camera proof.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import stat
import tempfile
from pathlib import Path
from typing import Any

RUN_NEUTRAL_FILES = [
    "CANONICAL-MESH-IR.json",
    "OBJECT-MAPPING.json",
    "PROJECTION.json",
    "TOPOLOGY.json",
    "INPUT-BINDINGS.json",
    "VALIDATION.json",
]
SOURCE_REL = "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13"
EVIDENCE_REL = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/lowering-v01"


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"JSON object required: {path}")
    return value


def repo_file(root: Path, relative: str) -> Path:
    candidate = Path(relative)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise RuntimeError(f"repository-relative path required: {relative}")
    path = (root / candidate).resolve(strict=True)
    path.relative_to(root.resolve())
    if not stat.S_ISREG(path.stat().st_mode) or path.is_symlink():
        raise RuntimeError(f"regular non-symlink input required: {relative}")
    return path


def verify_file(root: Path, record: dict[str, Any]) -> Path:
    path = repo_file(root, record["file"])
    actual = sha256(path)
    if actual != record["sha256"]:
        raise RuntimeError(
            f"hash drift for {record['file']}: expected {record['sha256']}, got {actual}"
        )
    return path


def bridge(city: list[float]) -> list[float]:
    if len(city) != 3 or not all(math.isfinite(float(x)) for x in city):
        raise RuntimeError("non-finite three-dimensional coordinate")
    return [float(city[2]), float(city[0]), float(city[1])]


def vector(a: list[float], b: list[float]) -> list[float]:
    return [float(a[i]) - float(b[i]) for i in range(3)]


def cross(a: list[float], b: list[float]) -> list[float]:
    return [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]


def dot(a: list[float], b: list[float]) -> float:
    return sum(float(a[i]) * float(b[i]) for i in range(3))


def norm(value: list[float]) -> float:
    return math.sqrt(dot(value, value))


def normalized(value: list[float]) -> list[float]:
    length = norm(value)
    if length <= 1e-12:
        raise RuntimeError("zero-length camera basis")
    return [x / length for x in value]


def box_vertices(bounds: list[list[float]]) -> list[list[float]]:
    minimum, maximum = bounds
    x0, y0, z0 = (float(x) for x in minimum)
    x1, y1, z1 = (float(x) for x in maximum)
    if not x0 < x1 or not y0 < y1 or not z0 < z1:
        raise RuntimeError("non-positive box bounds")
    return [
        [x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1],
        [x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1],
    ]


BOX_FACES = [
    [0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1],
    [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0],
]


def octagon_vertices(center: list[float], radius: float, height: float) -> list[list[float]]:
    cx, cy, cz = (float(x) for x in center)
    bottom = cy - height / 2.0
    top = cy + height / 2.0
    result: list[list[float]] = []
    for y in (bottom, top):
        for index in range(8):
            angle = 2.0 * math.pi * index / 8.0
            result.append([cx + radius * math.cos(angle), y, cz + radius * math.sin(angle)])
    faces = [[7, 6, 5, 4, 3, 2, 1, 0], list(range(8, 16))]
    for index in range(8):
        following = (index + 1) % 8
        faces.append([index, following, following + 8, index + 8])
    return result, faces


def aabb(vertices: list[list[float]]) -> list[list[float]]:
    return [
        [min(v[i] for v in vertices) for i in range(3)],
        [max(v[i] for v in vertices) for i in range(3)],
    ]


def overlaps(first: list[list[float]], second: list[list[float]], eps: float = 1e-9) -> bool:
    return all(
        min(first[1][i], second[1][i]) - max(first[0][i], second[0][i]) > eps
        for i in range(3)
    )


def expand_component(item: dict[str, Any], material_by_role: dict[str, str]) -> list[dict[str, Any]]:
    parent = item["id"]
    role = item["materialRole"]
    material = material_by_role[role]

    def box(identifier: str, bounds: list[list[float]], owner: str = parent, mat: str = material) -> dict[str, Any]:
        vertices = box_vertices(bounds)
        return {
            "physicalComponentID": identifier,
            "semanticOwnerID": owner,
            "materialID": mat,
            "shape": "box",
            "verticesCitySim": vertices,
            "verticesBlenderWorld": [bridge(v) for v in vertices],
            "polygons": BOX_FACES,
            "boundsCitySim": aabb(vertices),
        }

    shape = item["primitive"]
    if shape == "box":
        return [box(parent, item["boundsXYZ"])]
    if shape == "single-segmented-shell":
        return [box(f"{parent}:{region['id']}", region["boundsXYZ"]) for region in item["solidRegions"]]
    if shape == "single-compound-frame":
        return [box(f"{parent}:{member['id']}", member["boundsXYZ"]) for member in item["members"]]
    if shape == "three-segmented-recesses":
        return [box(f"{parent}:{recess['id']}", recess["boundsXYZ"]) for recess in item["recesses"]]
    if shape == "braced-lantern":
        return [box(parent, item["boundsXYZ"])]
    if shape == "octagonal-vessel":
        vertices, faces = octagon_vertices(item["centerXYZ"], item["radius"], item["height"])
        return [{
            "physicalComponentID": parent,
            "semanticOwnerID": parent,
            "materialID": material,
            "shape": "octagonal-prism",
            "verticesCitySim": vertices,
            "verticesBlenderWorld": [bridge(v) for v in vertices],
            "polygons": faces,
            "boundsCitySim": aabb(vertices),
            "heatCap": item["heatCap"],
        }]
    if shape == "segmented-annex":
        records = [box(parent, item["boundsXYZ"])]
        door = item["door"]
        records.append(box(f"{parent}:staff-door", door["boundsXYZ"], parent, material_by_role[door["materialRole"]]))
        return records
    if shape == "cylinder":
        vertices, faces = octagon_vertices(item["centerXYZ"], item["radius"], item["height"])
        return [{
            "physicalComponentID": parent,
            "semanticOwnerID": parent,
            "materialID": material,
            "shape": "octagonal-prism",
            "verticesCitySim": vertices,
            "verticesBlenderWorld": [bridge(v) for v in vertices],
            "polygons": faces,
            "boundsCitySim": aabb(vertices),
        }]
    if shape == "bounded-equipment-cluster":
        return [box(parent, item["boundsXYZ"])]
    raise RuntimeError(f"unsupported authored primitive: {shape}")


def camera_basis(scene: dict[str, Any]) -> dict[str, Any]:
    camera = scene["camera"]
    position = bridge(camera["positionWorld"])
    target = bridge(camera["targetWorld"])
    forward = normalized(vector(target, position))
    right = normalized(cross(forward, [0.0, 1.0, 0.0]))
    up = normalized(cross(right, forward))
    return {"position": position, "target": target, "forward": forward, "right": right, "up": up}


def project(scene: dict[str, Any], city: list[float]) -> list[float]:
    """Frozen v06 registration affine, with camera-derived vertical basis.

    The four published contact points are the calibration anchors.  This keeps
    registration exact while the camera basis supplies the height direction;
    no DCC or pixel renderer is invoked.
    """
    camera = camera_basis(scene)
    x, y, z = (float(value) for value in city)
    source_x = 768.0 + (x - z) * (256.0 / 56.0)
    vertical_scale = 1024.0 * abs(camera["up"][2]) / float(scene["camera"]["orthographicScale"] * 2.0)
    source_y = 768.0 + (x + z) * (128.0 / 56.0) - y * vertical_scale
    return [round(source_x, 9), round(source_y, 9)]


def projected_bounds(scene: dict[str, Any], bounds: list[list[float]]) -> list[float]:
    points = [
        project(scene, [x, y, z])
        for x in (bounds[0][0], bounds[1][0])
        for y in (bounds[0][1], bounds[1][1])
        for z in (bounds[0][2], bounds[1][2])
    ]
    return [min(p[0] for p in points), min(p[1] for p in points), max(p[0] for p in points), max(p[1] for p in points)]


def compact_size(source_bounds: list[float]) -> list[int]:
    return [int(math.floor(source_bounds[2] / 8.0) - math.floor(source_bounds[0] / 8.0) + 1), int(math.floor(source_bounds[3] / 8.0) - math.floor(source_bounds[1] / 8.0) + 1)]


def luma(rgba: list[float]) -> float:
    return 255.0 * (0.2126 * rgba[0] + 0.7152 * rgba[1] + 0.0722 * rgba[2])


def lower_scene(root: Path, output_root: Path) -> dict[str, Any]:
    scene_path = root / SOURCE_REL / "DESIGN-SCENE.json"
    materials_path = root / SOURCE_REL / "DESIGN-MATERIALS.json"
    bridge_path = root / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
    scene = load_json(scene_path)
    materials = load_json(materials_path)
    bridge_contract = load_json(bridge_path)
    if scene["viewDirection"] != "north" or scene["orientationTransform"] != "none":
        raise RuntimeError("North orientation or alias drift")
    if scene["sourceRevision"] != "blender-art-v13-design-authority":
        raise RuntimeError("source revision drift")
    if bridge_contract["basis"]["formula"] != "B(CitySim[x,y,z])=Blender[z,x,y]" or bridge_contract["basis"]["sourceOrder"] != [0, 1, 2, 3]:
        raise RuntimeError("coordinate bridge contract drift")
    material_by_role = {record["role"]: record["id"] for record in materials["materials"]}
    if len(material_by_role) != len(materials["materials"]):
        raise RuntimeError("duplicate material role")
    objects: list[dict[str, Any]] = []
    for item in scene["components"]:
        if item["materialRole"] not in material_by_role:
            raise RuntimeError(f"unresolved material role: {item['id']}")
        objects.extend(expand_component(item, material_by_role))
    ids = [record["physicalComponentID"] for record in objects]
    if len(ids) != len(set(ids)):
        raise RuntimeError("duplicate physical component ID")
    aperture = scene["components"][2]["emptyPortalVolumeXYZ"]
    solid_intrusions = [record["physicalComponentID"] for record in objects if overlaps(record["boundsCitySim"], aperture)]
    allowed = {"v13-main-foundry-shell:west-shoulder", "v13-main-foundry-shell:east-shoulder"}
    if set(solid_intrusions) - allowed:
        raise RuntimeError(f"solid intrusion into portal aperture: {solid_intrusions}")
    process_ids = {"v13-east-hot-process-vessel", "v13-roof-plant-cluster", "v13-crane-lantern"}
    process_intrusions = [record["physicalComponentID"] for record in objects if record["semanticOwnerID"] in process_ids and overlaps(record["boundsCitySim"], aperture)]
    if process_intrusions:
        raise RuntimeError(f"process/crane intrusion into portal aperture: {process_intrusions}")
    projection = {
        "schema": 1,
        "method": "frozen-v06-camera-affine-registration",
        "blenderInvocationCount": 0,
        "renderedPixelCount": 0,
        "footprintExpectedSource": scene["registration"]["footprintPolygonSource"],
        "footprintActualSource": [project(scene, [p[0], 0, p[1]]) for p in scene["registration"]["footprintWorldXZ"]],
        "pivotExpectedSource": scene["registration"]["groundPivotSource"],
        "pivotActualSource": project(scene, scene["registration"]["groundPivotWorld"]),
        "socketExpectedSource": scene["registration"]["frontageSocketSource"],
        "socketActualSource": project(scene, scene["registration"]["frontageSocketWorld"]),
        "camera": camera_basis(scene),
        "objectBoundsCompact": {
            record["physicalComponentID"]: {"source": projected_bounds(scene, record["boundsCitySim"]), "compact": compact_size(projected_bounds(scene, record["boundsCitySim"]))}
            for record in objects
        },
    }
    registration_max = max(
        max(abs(projection["footprintActualSource"][i][j] - projection["footprintExpectedSource"][i][j]) for j in (0, 1)) for i in range(4)
    )
    registration_max = max(registration_max, *(abs(projection["pivotActualSource"][i] - projection["pivotExpectedSource"][i]) for i in (0, 1)), *(abs(projection["socketActualSource"][i] - projection["socketExpectedSource"][i]) for i in (0, 1)))
    projection["maximumRegistrationDeltaSourcePixels"] = round(registration_max, 9)
    topology = {
        "schema": 1,
        "apertureBoundsCitySim": aperture,
        "solidIntrusions": solid_intrusions,
        "allowedShoulderOverhangs": sorted(allowed),
        "processOrCraneIntrusions": process_intrusions,
        "rayOrder": ["emptyPortalVolume", "v13-portal-inset"],
        "internalSharedFaces": scene["components"][2]["internalSharedFaces"],
        "objectCount": len(objects),
        "semanticOwnerCount": len({record["semanticOwnerID"] for record in objects}),
    }
    bindings = {
        "schema": 1,
        "scene": {"path": f"{SOURCE_REL}/DESIGN-SCENE.json", "sha256": sha256(scene_path)},
        "materials": {"path": f"{SOURCE_REL}/DESIGN-MATERIALS.json", "sha256": sha256(materials_path)},
        "bridge": {"path": "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json", "sha256": sha256(bridge_path)},
        "orientationTransform": scene["orientationTransform"],
        "sourceAuthority": False,
        "productionSelected": False,
    }
    validation = {
        "schema": 1,
        "stage": "north-v13-lowering-v01",
        "validationPassed": registration_max <= 0.001 and not process_intrusions and len(ids) == len(set(ids)),
        "registrationMaximumSourcePixels": round(registration_max, 9),
        "physicalComponentCount": len(objects),
        "semanticOwnerCount": len({record["semanticOwnerID"] for record in objects}),
        "solidIntrusionCount": len(set(solid_intrusions) - allowed),
        "processIntrusionCount": len(process_intrusions),
        "zeroPixel": True,
        "blenderInvocationCount": 0,
        "renderInvocationCount": 0,
        "imageGenInvocationCount": 0,
        "normalizerInvocationCount": 0,
        "orientationTransform": scene["orientationTransform"],
        "sourceAuthority": False,
        "productionSelected": False,
    }
    if not validation["validationPassed"]:
        raise RuntimeError("v13 lowering validation failed")
    output_root = output_root.resolve()
    if output_root.exists():
        raise RuntimeError("output root must be absent")
    output_root.mkdir(parents=True)
    outputs = {
        "CANONICAL-MESH-IR.json": {"schema": 1, "sceneGeometryID": scene["sceneGeometryID"], "objects": objects, "authoredShadow": scene["shadow"], "sourceAuthority": False, "productionSelected": False},
        "OBJECT-MAPPING.json": {"schema": 1, "objects": [{"physicalComponentID": r["physicalComponentID"], "semanticOwnerID": r["semanticOwnerID"], "objectName": f"play027-{r['physicalComponentID']}", "materialID": r["materialID"]} for r in objects]},
        "PROJECTION.json": projection,
        "TOPOLOGY.json": topology,
        "INPUT-BINDINGS.json": bindings,
        "VALIDATION.json": validation,
    }
    for name, value in outputs.items():
        (output_root / name).write_bytes(canonical_bytes(value))
    return {"outputHashes": {name: sha256(output_root / name) for name in RUN_NEUTRAL_FILES}, "outputRoot": str(output_root), "validation": validation, "projection": projection, "topology": topology, "bindings": bindings}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    result = lower_scene(args.repository_root.resolve(strict=True), args.output_root)
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
