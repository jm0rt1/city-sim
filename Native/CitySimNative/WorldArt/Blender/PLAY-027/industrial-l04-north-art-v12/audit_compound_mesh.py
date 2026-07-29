#!/usr/bin/env python3
"""Mechanically audit v12 same-owner internal-face removal without rendering."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
from typing import Any

from sealed_io import SealedDirectory, create_exact_directory, reject_symlink_or_missing_chain


SCENE_SHA = "dad20722f4770c82992040861074188c604b46cd226e5f739291ac22683594e2"
MATERIALS_SHA = "e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09"
REPLAY_IDENTITY_SHA = "791cdaef240baed03a7a8a380b8fddb50f4039f375a1022ce7eaa7003a28c99e"
SOURCE_REL = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12"
)
EVIDENCE_REL = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12"
)
REPAIR_REL = EVIDENCE_REL / "boundary-proof-repair-v01"
OUTPUT_FILES = {
    "ADVERSARIAL-RESULTS.json",
    "COMPOUND-MESH-AUDIT.json",
    "DISPOSITION.json",
    "REPLAY-PRESERVATION.json",
}
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
INTERFACES = [
    {
        "name": "west-pier-exterior-camera-reveal",
        "components": ["v12-west-pier-exterior", "v12-west-pier-camera-reveal"],
        "semanticOwnerID": "v12-west-portal-pier",
        "axis": 2,
        "plane": -12.8,
        "expectedSharedArea": 108.0,
    },
    {
        "name": "portal-inset-east-west-lower",
        "components": ["v12-portal-inset-east", "v12-portal-inset-west-lower"],
        "semanticOwnerID": "v12-portal-inset",
        "axis": 0,
        "plane": 14.0,
        "expectedSharedArea": 4.5,
    },
    {
        "name": "raised-high-bay-main-east-upper",
        "components": ["v12-raised-high-bay-main", "v12-raised-high-bay-east-upper"],
        "semanticOwnerID": "north-v09-raised-high-bay",
        "axis": 0,
        "plane": 12.0,
        "expectedSharedArea": 399.0,
    },
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def vector_sub(a: list[float], b: list[float]) -> list[float]:
    return [a[index] - b[index] for index in range(3)]


def cross(a: list[float], b: list[float]) -> list[float]:
    return [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]


def length(value: list[float]) -> float:
    return math.sqrt(sum(item * item for item in value))


def face_area(vertices: list[list[float]]) -> float:
    origin = vertices[0]
    return sum(
        length(
            cross(
                vector_sub(vertices[index], origin),
                vector_sub(vertices[index + 1], origin),
            )
        )
        / 2.0
        for index in range(1, len(vertices) - 1)
    )


def box_mesh(item: dict[str, Any]) -> tuple[list[list[float]], list[list[int]]]:
    px, py, pz = (float(value) for value in item["position"])
    dx, dy, dz = (float(value) / 2.0 for value in item["dimensions"])
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
        [0, 3, 2, 1],
        [4, 5, 6, 7],
        [0, 1, 5, 4],
        [1, 2, 6, 5],
        [2, 3, 7, 6],
        [3, 0, 4, 7],
    ]
    return vertices, faces


def octagonal_mesh(item: dict[str, Any]) -> tuple[list[list[float]], list[list[int]]]:
    px, py, pz = (float(value) for value in item["position"])
    dx, dy, dz = (float(value) / 2.0 for value in item["dimensions"])
    vertices = []
    for height in (py - dy, py + dy):
        for index in range(8):
            angle = 2.0 * math.pi * float(index) / 8.0
            vertices.append(
                [
                    px + math.cos(angle) * dx,
                    height,
                    pz + math.sin(angle) * dz,
                ]
            )
    faces = [list(range(7, -1, -1)), list(range(8, 16))]
    for index in range(8):
        following = (index + 1) % 8
        faces.append([index, following, following + 8, index + 8])
    return vertices, faces


def component_mesh(item: dict[str, Any]) -> tuple[list[list[float]], list[list[int]]]:
    if item["shape"] == "box":
        return box_mesh(item)
    if item["shape"] == "octagonal-prism":
        return octagonal_mesh(item)
    if item["shape"] != "triangular-prism":
        raise RuntimeError(f"unsupported physical shape: {item['shape']}")
    if (
        item["id"] != "v12-west-pier-camera-reveal"
        or item["vertices"] != EXPECTED_PRISM_VERTICES
        or item["faces"] != EXPECTED_PRISM_FACES
    ):
        raise RuntimeError("authorized triangular-prism mesh/order drift")
    return copy.deepcopy(item["vertices"]), copy.deepcopy(item["faces"])


def mesh_faces(item: dict[str, Any]) -> list[dict[str, Any]]:
    vertices, faces = component_mesh(item)
    result = []
    for index, face in enumerate(faces):
        polygon = [vertices[vertex_index] for vertex_index in face]
        raw_normal = cross(
            vector_sub(polygon[1], polygon[0]),
            vector_sub(polygon[2], polygon[0]),
        )
        magnitude = length(raw_normal)
        if magnitude <= 0.000001:
            raise RuntimeError(f"degenerate face: {item['id']}:{index}")
        normal = [value / magnitude for value in raw_normal]
        result.append(
            {
                "componentID": item["id"],
                "semanticOwnerID": item.get("semanticOwnerID", item["id"]),
                "faceIndex": index,
                "vertexIndices": face,
                "vertices": polygon,
                "normal": normal,
                "area": face_area(polygon),
            }
        )
    return result


def axis_face(
    face: dict[str, Any],
    axis: int,
    plane: float,
) -> bool:
    if abs(abs(face["normal"][axis]) - 1.0) > 0.000001:
        return False
    if any(
        abs(face["normal"][other]) > 0.000001
        for other in range(3)
        if other != axis
    ):
        return False
    return all(abs(vertex[axis] - plane) <= 0.000001 for vertex in face["vertices"])


def rectangular_bounds(face: dict[str, Any], axis: int) -> tuple[list[float], list[float]]:
    projected_axes = [value for value in range(3) if value != axis]
    lows = [
        min(vertex[value] for vertex in face["vertices"])
        for value in projected_axes
    ]
    highs = [
        max(vertex[value] for vertex in face["vertices"])
        for value in projected_axes
    ]
    bounding_area = (highs[0] - lows[0]) * (highs[1] - lows[1])
    if abs(face["area"] - bounding_area) > 0.000001:
        raise RuntimeError(
            f"interface face is not one exact rectangle: "
            f"{face['componentID']}:{face['faceIndex']}"
        )
    return lows, highs


def shared_rectangle(
    first: dict[str, Any],
    second: dict[str, Any],
    axis: int,
) -> tuple[list[float], list[float], float]:
    first_low, first_high = rectangular_bounds(first, axis)
    second_low, second_high = rectangular_bounds(second, axis)
    low = [max(first_low[index], second_low[index]) for index in range(2)]
    high = [min(first_high[index], second_high[index]) for index in range(2)]
    lengths = [high[index] - low[index] for index in range(2)]
    area = lengths[0] * lengths[1] if min(lengths) > 0.000001 else 0.0
    return low, high, area


def component(scene: dict[str, Any], component_id: str) -> dict[str, Any]:
    matches = [item for item in scene["components"] if item["id"] == component_id]
    if len(matches) != 1:
        raise RuntimeError(f"component identity mismatch: {component_id}")
    return matches[0]


def audit_interface(scene: dict[str, Any], specification: dict[str, Any]) -> dict[str, Any]:
    first_item = component(scene, specification["components"][0])
    second_item = component(scene, specification["components"][1])
    first_faces = [
        face
        for face in mesh_faces(first_item)
        if axis_face(face, specification["axis"], specification["plane"])
    ]
    second_faces = [
        face
        for face in mesh_faces(second_item)
        if axis_face(face, specification["axis"], specification["plane"])
    ]
    if len(first_faces) != 1 or len(second_faces) != 1:
        raise RuntimeError(
            f"{specification['name']}: exactly one interface face per component required"
        )
    first = first_faces[0]
    second = second_faces[0]
    if first["semanticOwnerID"] != specification["semanticOwnerID"]:
        raise RuntimeError(f"{specification['name']}: first semantic owner drift")
    if second["semanticOwnerID"] != specification["semanticOwnerID"]:
        raise RuntimeError(f"{specification['name']}: second semantic owner drift")
    low, high, shared_area = shared_rectangle(first, second, specification["axis"])
    if abs(shared_area - specification["expectedSharedArea"]) > 0.000001:
        raise RuntimeError(
            f"{specification['name']}: expected shared area "
            f"{specification['expectedSharedArea']}, got {shared_area}"
        )
    return {
        "name": specification["name"],
        "physicalComponents": specification["components"],
        "semanticOwnerID": specification["semanticOwnerID"],
        "axis": specification["axis"],
        "plane": specification["plane"],
        "faceA": {
            "componentID": first["componentID"],
            "faceIndex": first["faceIndex"],
            "normal": first["normal"],
            "area": first["area"],
        },
        "faceB": {
            "componentID": second["componentID"],
            "faceIndex": second["faceIndex"],
            "normal": second["normal"],
            "area": second["area"],
        },
        "sharedRectangle": {"low": low, "high": high, "area": shared_area},
        "normalRelation": (
            "opposed"
            if first["normal"][specification["axis"]]
            * second["normal"][specification["axis"]]
            < 0
            else "same-winding"
        ),
        "mechanicalOperation": (
            "cancel-both-coplanar-same-owner-face-fragments-by-geometric-occupancy"
        ),
        "removedFaceFragmentCount": 2,
        "removedInternalFaceArea": 2.0 * shared_area,
        "remainingInternalFaceArea": 0.0,
        "passed": True,
    }


def audit_scene(scene: dict[str, Any]) -> dict[str, Any]:
    physical_ids = [item["id"] for item in scene["components"]]
    duplicates = sorted({item for item in physical_ids if physical_ids.count(item) > 1})
    if duplicates:
        raise RuntimeError(f"duplicate physical IDs: {duplicates}")
    all_faces = [
        face
        for item in scene["components"]
        for face in mesh_faces(item)
    ]
    input_area = sum(face["area"] for face in all_faces)
    interfaces = [audit_interface(scene, specification) for specification in INTERFACES]
    removed_area = sum(item["removedInternalFaceArea"] for item in interfaces)

    exterior = component(scene, "v12-west-pier-exterior")
    header = component(scene, "north-v09-portal-header")
    exterior_face = [
        face for face in mesh_faces(exterior) if axis_face(face, 1, 19.0)
    ]
    header_face = [
        face for face in mesh_faces(header) if axis_face(face, 1, 19.0)
    ]
    if len(exterior_face) != 1 or len(header_face) != 1:
        raise RuntimeError("exterior/header contact faces missing")
    _, _, contact_area = shared_rectangle(exterior_face[0], header_face[0], 1)
    if abs(contact_area - 18.0) > 0.000001:
        raise RuntimeError(f"exterior/header contact area drift: {contact_area}")

    return {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v12-compound-mesh-internal-face-audit",
        "sceneSHA256": SCENE_SHA,
        "materialsSHA256": MATERIALS_SHA,
        "physicalComponentCount": len(physical_ids),
        "uniquePhysicalIDCount": len(set(physical_ids)),
        "duplicatePhysicalIDs": duplicates,
        "sourceFaceCount": len(all_faces),
        "sourceSurfaceArea": input_area,
        "interfaceAudits": interfaces,
        "removedInternalFaceFragmentCount": sum(
            item["removedFaceFragmentCount"] for item in interfaces
        ),
        "removedInternalFaceArea": removed_area,
        "compoundBoundarySurfaceArea": input_area - removed_area,
        "remainingInternalFaceArea": sum(
            item["remainingInternalFaceArea"] for item in interfaces
        ),
        "intentionalDifferentOwnerContact": {
            "components": ["v12-west-pier-exterior", "north-v09-portal-header"],
            "axis": 1,
            "plane": 19.0,
            "sharedArea": contact_area,
            "classification": "contact-not-union",
        },
        "literalInternalSharedFaceRemovedFlagsConsumed": 0,
        "derivation": (
            "Actual component vertices and face order are reconstructed; "
            "opposite coplanar same-owner face fragments are intersected and "
            "subtracted from the compound boundary surface."
        ),
        "passed": all(item["passed"] for item in interfaces),
    }


def rejected_case(label: str, scene: dict[str, Any]) -> dict[str, Any]:
    try:
        report = audit_scene(scene)
    except (KeyError, RuntimeError, TypeError, ValueError) as error:
        return {"case": label, "result": "PASS_REJECTED", "error": str(error)}
    return {
        "case": label,
        "result": "FAIL_ACCEPTED",
        "auditPassed": report["passed"],
    }


def run_adversarial(scene: dict[str, Any]) -> dict[str, Any]:
    cases = []

    missing_face = copy.deepcopy(scene)
    reveal = component(missing_face, "v12-west-pier-camera-reveal")
    reveal["faces"].remove([2, 0, 3, 5])
    reveal["internalSharedFaceRemoved"] = True
    cases.append(rejected_case("forged-true-with-missing-reveal-face", missing_face))

    wrong_orientation = copy.deepcopy(scene)
    reveal = component(wrong_orientation, "v12-west-pier-camera-reveal")
    reveal["faces"][-1] = list(reversed(reveal["faces"][-1]))
    cases.append(rejected_case("unauthorized-prism-face-order-reversal", wrong_orientation))

    reveal_gap = copy.deepcopy(scene)
    reveal = component(reveal_gap, "v12-west-pier-camera-reveal")
    for vertex in reveal["vertices"]:
        vertex[2] += 0.1
    cases.append(rejected_case("reveal-plane-gap", reveal_gap))

    semantic_split = copy.deepcopy(scene)
    component(semantic_split, "v12-west-pier-camera-reveal")["semanticOwnerID"] = "forged-owner"
    cases.append(rejected_case("semantic-owner-split", semantic_split))

    inset_gap = copy.deepcopy(scene)
    component(inset_gap, "v12-portal-inset-west-lower")["position"][0] -= 0.1
    cases.append(rejected_case("inset-interface-gap", inset_gap))

    high_bay_gap = copy.deepcopy(scene)
    component(high_bay_gap, "v12-raised-high-bay-east-upper")["position"][0] += 0.1
    cases.append(rejected_case("high-bay-interface-gap", high_bay_gap))

    all_rejected = all(item["result"] == "PASS_REJECTED" for item in cases)
    return {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v12-compound-mesh-adversarial-proof",
        "caseCount": len(cases),
        "cases": cases,
        "literalTrueCannotPass": cases[0]["result"] == "PASS_REJECTED",
        "allAdversarialCasesRejected": all_rejected,
        "passed": all_rejected,
    }


def replay_preservation(evidence_root: Path) -> dict[str, Any]:
    identity_path = evidence_root / "REPLAY-IDENTITY.json"
    if sha256(identity_path) != REPLAY_IDENTITY_SHA:
        raise RuntimeError("sealed replay identity receipt drift")
    identity = load_json(identity_path)
    result = {}
    for replay_name, inventory_key in (("replay-a", "runA"), ("replay-b", "runB")):
        replay_root = evidence_root / replay_name
        reject_symlink_or_missing_chain(replay_root)
        expected = identity[inventory_key]
        actual_files = sorted(
            path.name for path in replay_root.iterdir() if path.is_file()
        )
        if actual_files != sorted(expected):
            raise RuntimeError(f"{replay_name} inventory drift")
        actual = {name: sha256(replay_root / name) for name in sorted(expected)}
        if actual != expected:
            raise RuntimeError(f"{replay_name} byte identity drift")
        result[replay_name] = actual
    return {
        "schema": 1,
        "task": "PLAY-027",
        "sealedReplayIdentitySHA256": REPLAY_IDENTITY_SHA,
        "replayAUnchanged": True,
        "replayBUnchanged": True,
        "aggregateIdentityStillValid": result["replay-a"] == result["replay-b"],
        "inventories": result,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()

    repository = args.repository_root
    if not repository.is_absolute() or repository.resolve() != repository:
        raise RuntimeError("repository root must be exact and canonical")
    source_root = repository / SOURCE_REL
    evidence_root = repository / EVIDENCE_REL
    expected_output = repository / REPAIR_REL
    if not args.output_root.is_absolute() or args.output_root.parts != expected_output.parts:
        raise RuntimeError("repair output root must match the exact whitelist")
    reject_symlink_or_missing_chain(source_root)
    reject_symlink_or_missing_chain(evidence_root)
    if os.path.lexists(expected_output):
        raise RuntimeError("repair evidence root must be absent")

    scene_path = source_root / "SCENE.json"
    materials_path = source_root / "MATERIALS.json"
    if sha256(scene_path) != SCENE_SHA or sha256(materials_path) != MATERIALS_SHA:
        raise RuntimeError("v12 immutable input hash drift")
    scene = load_json(scene_path)
    first_audit = audit_scene(scene)
    second_audit = audit_scene(copy.deepcopy(scene))
    if canonical_bytes(first_audit) != canonical_bytes(second_audit):
        raise RuntimeError("compound mesh audit is not deterministic")
    adversarial = run_adversarial(scene)
    if not first_audit["passed"] or not adversarial["passed"]:
        raise RuntimeError("compound mesh proof failed")
    preservation = replay_preservation(evidence_root)

    tool_path = source_root / "audit_compound_mesh.py"
    disposition = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v12-boundary-proof-repair",
        "sceneSHA256": SCENE_SHA,
        "materialsSHA256": MATERIALS_SHA,
        "auditToolSHA256": sha256(tool_path),
        "compoundMeshAudit": "PASS",
        "adversarialProof": "PASS",
        "sealedReplayContentIdentity": "PRESERVED",
        "zeroPixelGateDisposition": "BOUNDARY_PROOF_PASSED_ENVELOPE_UNVERIFIED",
        "envelopeDisposition": "UNVERIFIED",
        "envelopeReason": (
            "The retained assembler accepted caller-supplied timing and RSS "
            "arguments. Replay A's time wrapper failed after sealed output and "
            "Replay B's separate native observation does not constitute a "
            "trustworthy same-process two-replay envelope measurement."
        ),
        "existingReplayReceiptMutated": False,
        "candidateReadyForIndependentReview": False,
        "sourceAuthority": False,
        "productionSelected": False,
        "processCounts": {
            "compoundMeshAudit": 1,
            "blender": 0,
            "cycles": 0,
            "sourceA": 0,
            "sourceB": 0,
            "sourceC": 0,
            "siblings": 0,
            "normalizer": 0,
        },
    }

    create_exact_directory(
        expected_output,
        expected_output,
        (expected_output,),
    )
    writer = SealedDirectory(expected_output, OUTPUT_FILES)
    writer.write_json("COMPOUND-MESH-AUDIT.json", first_audit)
    writer.write_json("ADVERSARIAL-RESULTS.json", adversarial)
    writer.write_json("REPLAY-PRESERVATION.json", preservation)
    writer.write_json("DISPOSITION.json", disposition)
    if sorted(path.name for path in expected_output.iterdir()) != sorted(OUTPUT_FILES):
        raise RuntimeError("repair evidence inventory drift")


if __name__ == "__main__":
    main()
