#!/usr/bin/env python3
"""Sealed zero-pixel replay for the authorized PLAY-027 North v12 topology."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
import struct
import types
import zlib
from pathlib import Path
from typing import Any

from sealed_io import SealedDirectory, create_exact_directory, reject_symlink_or_missing_chain


AUTHORITY_COMMIT = "1bdf858181f720a0d30aacf142a219c79a3425f9"
AUTHORITY_SHA = "9fe208800078421303165087cbc0cd638bf870a8c0434e3ef374df1220c621fc"
CLAIM_SHA = "21885dc5de1ab89f0d9316c564bc0dab06f136924aac396f9743ebdb3b2004fe"
FROZEN_HEAD = "10df430ca1f6c0f26eb2082766791c39f9a18eab"
V11_SCENE_SHA = "814d9c2c86a740f04622f4ac47718c14d8f92d090fb127d921270e96ef1921c3"
MATERIALS_SHA = "e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09"
ANALYTIC_SHA = "b09bd1e809e55ae360eee14b5b96a8e85c168a83a1fbd78b90295e0d00ab50b0"
V11_PREVIEW_SHA = "c5c2679d4d88c67c6809016cb13443f6aac2fcd4958f1755534b992a43b36897"
MANIFEST_SHA = "6971bb3abe5d84e6bb351f47ddc2f18cd0f211c5f0784172557659e30e71dd8e"
BRIDGE_SHA = "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"

SOURCE_REL = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12"
)
EVIDENCE_REL = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12"
)
FILES = [
    "COMPONENT-OWNERS.json",
    "EXACT-192-COLOR.png",
    "EXACT-192-GRAYSCALE.png",
    "EXACT-192-SEMANTIC.png",
    "FIELD-DIFF.json",
    "MATERIALS.json",
    "PHYSICAL-BOUNDARIES.json",
    "PORTABILITY.json",
    "SCENE.json",
    "V11-V12-COMPARISON.png",
    "VALIDATION.json",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def assert_regular(path: Path, expected_sha: str) -> None:
    reject_symlink_or_missing_chain(path.parent)
    if not path.is_file() or path.is_symlink():
        raise RuntimeError(f"regular non-symlink input required: {path}")
    actual = sha256(path)
    if actual != expected_sha:
        raise RuntimeError(
            f"input hash drift: {path}: expected {expected_sha}, got {actual}"
        )


def import_analytic(path: Path) -> Any:
    module = types.ModuleType("play027_v12_analytic")
    source = path.read_bytes()
    exec(compile(source, str(path), "exec"), module.__dict__)
    return module


def png_payload(legacy: Any, width: int, height: int, rgba: bytes) -> bytes:
    rows = bytearray()
    stride = width * 4
    for y in range(height):
        rows.append(0)
        rows.extend(rgba[y * stride : (y + 1) * stride])
    return (
        b"\x89PNG\r\n\x1a\n"
        + legacy.png_chunk(
            b"IHDR",
            struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0),
        )
        + legacy.png_chunk(b"IDAT", zlib.compress(bytes(rows), level=9))
        + legacy.png_chunk(b"IEND", b"")
    )


def component(scene: dict[str, Any], component_id: str) -> dict[str, Any]:
    matches = [item for item in scene["components"] if item["id"] == component_id]
    if len(matches) != 1:
        raise RuntimeError(f"component identity mismatch: {component_id}")
    return matches[0]


def replace_component(
    scene: dict[str, Any],
    old_id: str,
    replacements: list[dict[str, Any]],
) -> None:
    indices = [
        index
        for index, item in enumerate(scene["components"])
        if item["id"] == old_id
    ]
    if len(indices) != 1:
        raise RuntimeError(f"replace target mismatch: {old_id}")
    index = indices[0]
    scene["components"][index : index + 1] = replacements


def expected_scene(v11: dict[str, Any]) -> dict[str, Any]:
    expected = copy.deepcopy(v11)
    expected["sourceRevision"] = "blender-art-v12-prepixel"
    expected["sceneGeometryID"] = "industrial-l04-north-v12-compound-west-pier"
    expected["materialLibrary"]["file"] = str(SOURCE_REL / "MATERIALS.json")

    architecture = expected["architecture"]
    architecture["primaryMassComponentIDs"] = [
        "north-v09-main-foundry-hall",
        "north-v09-rear-process-hall",
        "north-v09-rear-loading-link",
        "v12-east-assembly-return",
        "v12-raised-high-bay-main",
        "v12-raised-high-bay-east-upper",
    ]
    architecture["portalFrameComponentIDs"] = [
        "v12-west-pier-exterior",
        "v12-west-pier-camera-reveal",
        "north-v09-portal-jamb-east",
        "north-v09-portal-header",
        "v12-portal-inset-east",
        "v12-portal-inset-west-lower",
    ]
    architecture["gantryComponentIDs"] = [
        "north-v09-gantry-pier-west",
        "v12-gantry-pier-east",
        "v12-gantry-girder-a",
        "north-v09-gantry-girder-b",
        "north-v09-gantry-trolley",
    ]

    replace_component(
        expected,
        "north-v09-east-assembly-return",
        [{
            "id": "v12-east-assembly-return",
            "shape": "box",
            "group": "primary-mass",
            "dimensions": [9.6, 20, 21.4],
            "position": [23.2, 11, 16.7],
            "materialID": "v09-warm-foundry-masonry",
            "bevel": 0.30,
        }],
    )
    replace_component(
        expected,
        "north-v09-raised-high-bay",
        [
            {
                "id": "v12-raised-high-bay-main",
                "shape": "box",
                "group": "primary-mass",
                "dimensions": [40, 17.3, 30],
                "position": [-8, 33.85, 7],
                "materialID": "v09-bluegreen-roof",
                "bevel": 0.26,
                "semanticOwnerID": "north-v09-raised-high-bay",
            },
            {
                "id": "v12-raised-high-bay-east-upper",
                "shape": "box",
                "group": "primary-mass",
                "dimensions": [4, 13.3, 30],
                "position": [14, 35.85, 7],
                "materialID": "v09-bluegreen-roof",
                "bevel": 0.26,
                "semanticOwnerID": "north-v09-raised-high-bay",
            },
        ],
    )
    replace_component(
        expected,
        "north-v09-east-return-cap",
        [{
            "id": "v12-east-return-cap",
            "shape": "box",
            "group": "roof-edge",
            "dimensions": [9.2, 1.0, 20.2],
            "position": [23.2, 21.7, 17.1],
            "materialID": "v09-roof-edge",
            "bevel": 0.10,
        }],
    )
    replace_component(
        expected,
        "north-v09-portal-jamb-west",
        [
            {
                "id": "v12-west-pier-exterior",
                "shape": "box",
                "group": "integrated-portal",
                "dimensions": [6, 18, 3],
                "position": [6.5, 10, -14.3],
                "materialID": "v10-freight-frame",
                "bevel": 0.18,
                "semanticOwnerID": "v12-west-portal-pier",
            },
            {
                "id": "v12-west-pier-camera-reveal",
                "shape": "triangular-prism",
                "group": "integrated-portal",
                "footprintXZ": [[3.5, -12.8], [3.5, -6.8], [9.5, -12.8]],
                "yBounds": [1, 19],
                "vertices": [
                    [3.5, 1, -12.8],
                    [3.5, 1, -6.8],
                    [9.5, 1, -12.8],
                    [3.5, 19, -12.8],
                    [3.5, 19, -6.8],
                    [9.5, 19, -12.8],
                ],
                "faces": [
                    [0, 2, 1],
                    [3, 4, 5],
                    [0, 1, 4, 3],
                    [1, 2, 5, 4],
                    [2, 0, 3, 5],
                ],
                "materialID": "v10-freight-frame",
                "bevel": 0.18,
                "semanticOwnerID": "v12-west-portal-pier",
            },
        ],
    )
    replace_component(
        expected,
        "north-v09-portal-inset",
        [
            {
                "id": "v12-portal-inset-east",
                "shape": "box",
                "group": "integrated-portal",
                "dimensions": [10, 16, 0.5],
                "position": [19, 9, -10.15],
                "materialID": "v09-deep-freight-void",
                "bevel": 0.03,
                "semanticOwnerID": "v12-portal-inset",
            },
            {
                "id": "v12-portal-inset-west-lower",
                "shape": "box",
                "group": "integrated-portal",
                "dimensions": [4.5, 9, 0.5],
                "position": [11.75, 5.5, -10.15],
                "materialID": "v09-deep-freight-void",
                "bevel": 0.03,
                "semanticOwnerID": "v12-portal-inset",
            },
        ],
    )
    replace_component(
        expected,
        "north-v09-gantry-pier-east",
        [{
            "id": "v12-gantry-pier-east",
            "shape": "box",
            "group": "subordinate-gantry",
            "dimensions": [1, 20, 1.7],
            "position": [17.55, 11, 4.15],
            "materialID": "v09-charcoal-steel",
            "bevel": 0.14,
        }],
    )
    replace_component(
        expected,
        "north-v09-gantry-girder-a",
        [{
            "id": "v12-gantry-girder-a",
            "shape": "box",
            "group": "subordinate-gantry",
            "dimensions": [16.1, 2, 0.5],
            "position": [10, 22, 3.45],
            "materialID": "v09-charcoal-steel",
            "bevel": 0.14,
        }],
    )
    return expected


def validate_bundle(bundle: Path) -> dict[str, Any]:
    manifest_path = bundle / "MANIFEST.json"
    assert_regular(manifest_path, MANIFEST_SHA)
    manifest = load_json(manifest_path)
    expected = sorted(["MANIFEST.json", *[item["path"] for item in manifest["files"]]])
    actual = sorted(
        str(path.relative_to(bundle))
        for path in bundle.rglob("*")
        if path.is_file()
    )
    if actual != expected:
        raise RuntimeError(f"frozen input inventory drift: {actual}")
    for item in manifest["files"]:
        path = bundle / item["path"]
        assert_regular(path, item["sha256"])
        if path.stat().st_size != item["bytes"]:
            raise RuntimeError(f"frozen input byte-count drift: {path}")
    return manifest


def install_prism_mesh(legacy: Any) -> None:
    original = legacy.component_mesh

    def component_mesh(item: dict[str, Any]) -> tuple[list[tuple[float, float, float]], list[tuple[int, ...]]]:
        if item["shape"] != "triangular-prism":
            return original(item)
        expected_vertices = [
            [3.5, 1, -12.8],
            [3.5, 1, -6.8],
            [9.5, 1, -12.8],
            [3.5, 19, -12.8],
            [3.5, 19, -6.8],
            [9.5, 19, -12.8],
        ]
        expected_faces = [
            [0, 2, 1],
            [3, 4, 5],
            [0, 1, 4, 3],
            [1, 2, 5, 4],
            [2, 0, 3, 5],
        ]
        if (
            item["id"] != "v12-west-pier-camera-reveal"
            or item["footprintXZ"] != [[3.5, -12.8], [3.5, -6.8], [9.5, -12.8]]
            or item["yBounds"] != [1, 19]
            or item["vertices"] != expected_vertices
            or item["faces"] != expected_faces
        ):
            raise RuntimeError("triangular prism vertex/face order drift")
        return (
            [tuple(float(value) for value in vertex) for vertex in expected_vertices],
            [tuple(face) for face in expected_faces],
        )

    legacy.component_mesh = component_mesh


def bounds3(item: dict[str, Any]) -> tuple[list[float], list[float]]:
    if item["shape"] == "triangular-prism":
        vertices = item["vertices"]
        return (
            [min(float(v[axis]) for v in vertices) for axis in range(3)],
            [max(float(v[axis]) for v in vertices) for axis in range(3)],
        )
    return (
        [
            float(item["position"][axis]) - float(item["dimensions"][axis]) / 2.0
            for axis in range(3)
        ],
        [
            float(item["position"][axis]) + float(item["dimensions"][axis]) / 2.0
            for axis in range(3)
        ],
    )


def overlap_amount(first: dict[str, Any], second: dict[str, Any]) -> list[float]:
    a_low, a_high = bounds3(first)
    b_low, b_high = bounds3(second)
    return [
        min(a_high[axis], b_high[axis]) - max(a_low[axis], b_low[axis])
        for axis in range(3)
    ]


def positive_overlap_pairs(scene: dict[str, Any]) -> dict[tuple[str, str], list[float]]:
    result = {}
    items = scene["components"]
    for first_index, first in enumerate(items):
        for second in items[first_index + 1 :]:
            overlap = overlap_amount(first, second)
            if min(overlap) > 0.000001:
                result[tuple(sorted((first["id"], second["id"])))] = overlap
    return result


def physical_boundary_report(v11: dict[str, Any], v12: dict[str, Any]) -> dict[str, Any]:
    old_for_new = {
        "v12-west-pier-exterior": "north-v09-portal-jamb-west",
        "v12-west-pier-camera-reveal": "north-v09-portal-jamb-west",
        "v12-portal-inset-east": "north-v09-portal-inset",
        "v12-portal-inset-west-lower": "north-v09-portal-inset",
        "v12-raised-high-bay-main": "north-v09-raised-high-bay",
        "v12-raised-high-bay-east-upper": "north-v09-raised-high-bay",
        "v12-east-return-cap": "north-v09-east-return-cap",
        "v12-gantry-girder-a": "north-v09-gantry-girder-a",
        "v12-gantry-pier-east": "north-v09-gantry-pier-east",
        "v12-east-assembly-return": "north-v09-east-assembly-return",
    }
    ids = [item["id"] for item in v12["components"]]
    duplicate_ids = sorted({item for item in ids if ids.count(item) > 1})
    old_overlaps = positive_overlap_pairs(v11)
    new_overlaps = positive_overlap_pairs(v12)
    unexpected = []
    for pair, overlap in new_overlaps.items():
        mapped = tuple(sorted(old_for_new.get(value, value) for value in pair))
        if mapped[0] == mapped[1] or mapped in old_overlaps:
            continue
        unexpected.append({"componentIDs": list(pair), "overlap": overlap})
    interfaces = [
        {
            "components": ["v12-west-pier-exterior", "v12-west-pier-camera-reveal"],
            "axis": "z",
            "plane": -12.8,
            "semanticOwnerID": "v12-west-portal-pier",
            "internalSharedFaceRemoved": True,
        },
        {
            "components": ["v12-portal-inset-east", "v12-portal-inset-west-lower"],
            "axis": "x",
            "plane": 14,
            "yRange": [1, 10],
            "semanticOwnerID": "v12-portal-inset",
            "internalSharedFaceRemoved": True,
        },
        {
            "components": ["v12-raised-high-bay-main", "v12-raised-high-bay-east-upper"],
            "axis": "x",
            "plane": 12,
            "yRange": [29.2, 42.5],
            "semanticOwnerID": "north-v09-raised-high-bay",
            "internalSharedFaceRemoved": True,
        },
        {
            "components": ["v12-west-pier-exterior", "north-v09-portal-header"],
            "axis": "y",
            "plane": 19,
            "classification": "intentional-contact",
        },
    ]
    return {
        "schema": 1,
        "physicalIDCount": len(ids),
        "uniquePhysicalIDCount": len(set(ids)),
        "duplicatePhysicalIDs": duplicate_ids,
        "depthResolutionOrder": "physical-component-first",
        "semanticAggregationOrder": "after-physical-depth-resolution",
        "booleanUnionDeclarations": interfaces[:3],
        "intentionalContacts": interfaces,
        "baselinePositiveOverlapPairCount": len(old_overlaps),
        "v12PositiveOverlapPairCount": len(new_overlaps),
        "unexpectedNewPositiveOverlaps": unexpected,
        "unchangedEastJambHeaderContactPreserved": True,
        "passed": not duplicate_ids and not unexpected,
    }


def semantic_owners(
    scene: dict[str, Any],
    physical_owners: list[str | None],
) -> list[str | None]:
    mapping = {
        item["id"]: item.get("semanticOwnerID", item["id"])
        for item in scene["components"]
    }
    return [mapping[owner] if owner is not None else None for owner in physical_owners]


def semantic_image(owners: list[str | None]) -> bytes:
    result = bytearray((48, 52, 50, 255) * len(owners))
    palette = {
        "v12-west-portal-pier": (214, 151, 68, 255),
        "north-v09-portal-jamb-east": (90, 168, 180, 255),
        "north-v09-portal-header": (203, 101, 73, 255),
        "v12-portal-inset": (49, 69, 76, 255),
    }
    for index, owner in enumerate(owners):
        if owner is None:
            continue
        color = palette.get(owner)
        if color is None:
            digest = hashlib.sha256(owner.encode("utf-8")).digest()
            color = (
                48 + digest[0] % 144,
                48 + digest[1] % 144,
                48 + digest[2] % 144,
                255,
            )
        result[index * 4 : index * 4 + 4] = bytes(color)
    return bytes(result)


def eroded_indices(indices: list[int], width: int, height: int) -> list[int]:
    mask = set(indices)
    result = []
    for index in indices:
        x = index % width
        y = index // width
        if x == 0 or y == 0 or x == width - 1 or y == height - 1:
            continue
        if all(
            (y + dy) * width + x + dx in mask
            for dy in (-1, 0, 1)
            for dx in (-1, 0, 1)
        ):
            result.append(index)
    return result


def filled_rectangles(
    indices: list[int],
    width: int,
    height: int,
    rectangle_width: int,
    rectangle_height: int,
) -> list[list[int]]:
    mask = set(indices)
    result = []
    for y in range(height - rectangle_height + 1):
        for x in range(width - rectangle_width + 1):
            if all(
                (y + dy) * width + x + dx in mask
                for dy in range(rectangle_height)
                for dx in range(rectangle_width)
            ):
                result.append([x, y, x + rectangle_width - 1, y + rectangle_height - 1])
    return result


def median_luma(legacy: Any, rgba: bytes, indices: list[int]) -> int:
    return legacy.median(legacy.luma_values(rgba, indices))


def horizontal_strip(images: list[bytes], width: int, height: int) -> bytes:
    result = bytearray()
    stride = width * 4
    for y in range(height):
        for image in images:
            result.extend(image[y * stride : (y + 1) * stride])
    return bytes(result)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--replay-id", choices=("a", "b"), required=True)
    args = parser.parse_args()

    repository = args.repository_root
    if not repository.is_absolute() or repository.resolve() != repository:
        raise RuntimeError("repository root must be exact and canonical")
    source_root = repository / SOURCE_REL
    evidence_root = repository / EVIDENCE_REL
    output = args.output_root
    expected_output = evidence_root / f"replay-{args.replay_id}"
    if not output.is_absolute() or output.parts != expected_output.parts:
        raise RuntimeError(f"output root is not exact whitelist target: {output}")
    reject_symlink_or_missing_chain(repository)
    reject_symlink_or_missing_chain(source_root)
    if args.replay_id == "a":
        if os.path.lexists(evidence_root):
            raise RuntimeError("evidence root must be absent before replay-a")
        allowed_directories = (evidence_root, output)
    else:
        replay_a = evidence_root / "replay-a"
        reject_symlink_or_missing_chain(evidence_root)
        if (
            not replay_a.is_dir()
            or replay_a.is_symlink()
            or sorted(path.name for path in replay_a.iterdir()) != sorted(FILES)
        ):
            raise RuntimeError("sealed replay-a inventory required before replay-b")
        allowed_directories = (output,)

    authority_path = (
        repository
        / "docs/production/evidence/INTEGRATION/"
        "INDUSTRIAL-L04-NORTH-V12-ZERO-PIXEL-AUTHORITY.md"
    )
    claim_path = repository / "docs/production/claims/PLAY-027.world-art.md"
    assert_regular(authority_path, AUTHORITY_SHA)
    assert_regular(claim_path, CLAIM_SHA)

    bundle = source_root / "frozen-inputs"
    manifest = validate_bundle(bundle)
    v11_scene_path = bundle / "v11/SCENE.json"
    v11_materials_path = bundle / "v11/MATERIALS.json"
    v11_preview_path = bundle / "v11/EXACT-192-COLOR.png"
    analytic_path = bundle / "analytic/build_prepixel.py"
    scene_path = source_root / "SCENE.json"
    materials_path = source_root / "MATERIALS.json"
    portability_path = source_root / "PORTABILITY.json"
    assert_regular(v11_scene_path, V11_SCENE_SHA)
    assert_regular(v11_materials_path, MATERIALS_SHA)
    assert_regular(v11_preview_path, V11_PREVIEW_SHA)
    assert_regular(analytic_path, ANALYTIC_SHA)
    assert_regular(materials_path, MATERIALS_SHA)
    reject_symlink_or_missing_chain(portability_path.parent)
    if not portability_path.is_file() or portability_path.is_symlink():
        raise RuntimeError("sealed portability receipt required before replay")

    v11_scene = load_json(v11_scene_path)
    v12_scene = load_json(scene_path)
    materials = load_json(materials_path)
    if v12_scene != expected_scene(v11_scene):
        raise RuntimeError("v12 scene contains a non-whitelisted change")
    if materials_path.read_bytes() != v11_materials_path.read_bytes():
        raise RuntimeError("v12 material bytes differ from frozen v11")

    legacy = import_analytic(analytic_path)
    install_prism_mesh(legacy)
    literal, physical_owners, groups = legacy.render(v12_scene, materials, 192, 128)
    _, v11_physical_owners, _ = legacy.render(v11_scene, materials, 192, 128)
    owners = semantic_owners(v12_scene, physical_owners)
    semantic_rgba = semantic_image(owners)

    owner_ids = sorted({owner for owner in owners if owner is not None})
    owner_pixels = {
        owner: [index for index, value in enumerate(owners) if value == owner]
        for owner in owner_ids
    }
    physical_ids = sorted({owner for owner in physical_owners if owner is not None})
    physical_pixels = {
        owner: [index for index, value in enumerate(physical_owners) if value == owner]
        for owner in physical_ids
    }
    west = owner_pixels.get("v12-west-portal-pier", [])
    eroded = eroded_indices(west, 192, 128)
    rectangles = filled_rectangles(west, 192, 128, 4, 6)
    selected_cells = [
        y * 192 + x
        for y in range(82, 88)
        for x in range(105, 109)
    ]
    selected_passed = all(owners[index] == "v12-west-portal-pier" for index in selected_cells)
    guard_coordinates = [
        [x, y]
        for y in range(81, 89)
        for x in range(104, 110)
        if not (105 <= x <= 108 and 82 <= y <= 87)
    ]
    if len(guard_coordinates) != 24:
        raise RuntimeError("selected rectangle guard cardinality drift")
    required_header = {(108, 81), (109, 81)}
    guard_results = []
    guard_passed = True
    for x, y in guard_coordinates:
        owner = owners[y * 192 + x]
        expected = "north-v09-portal-header" if (x, y) in required_header else "background-or-west"
        passed = (
            owner == "north-v09-portal-header"
            if (x, y) in required_header
            else owner in (None, "v12-west-portal-pier")
        )
        guard_passed = guard_passed and passed
        guard_results.append({"coordinate": [x, y], "owner": owner, "expected": expected, "passed": passed})

    occupied = [index for index, owner in enumerate(physical_owners) if owner is not None]
    occupied_bounds = legacy.bounds_for(occupied, 192)
    v12_mask = set(occupied)
    v11_mask = {index for index, owner in enumerate(v11_physical_owners) if owner is not None}
    intersection = len(v12_mask & v11_mask)
    union = len(v12_mask | v11_mask)
    silhouette_iou = float(intersection) / float(union)

    group_pixels = {
        group: [index for index, value in enumerate(groups) if value == group]
        for group in sorted({value for value in groups if value is not None})
    }
    hot_luma = median_luma(legacy, literal, group_pixels["hot-process"])
    primary_luma = median_luma(legacy, literal, group_pixels["primary-mass"])
    component_by_id = {item["id"]: item for item in v12_scene["components"]}
    tier_materials = {
        "primaryFacade": {"v09-warm-foundry-masonry"},
        "roofHighBay": {"v09-bluegreen-roof", "v09-roof-edge"},
        "equipmentProcess": {"v09-oxidized-machinery"},
    }
    tiers = {}
    for name, material_ids in tier_materials.items():
        indices = [
            index
            for index, owner in enumerate(physical_owners)
            if owner is not None
            and component_by_id[owner]["materialID"] in material_ids
        ]
        tiers[name] = median_luma(legacy, literal, indices)
    tier_values = sorted(tiers.values())
    tier_gaps = [
        tier_values[index + 1] - tier_values[index]
        for index in range(len(tier_values) - 1)
    ]

    hidden_rgb = 0
    exact_chroma = 0
    near_chroma = 0
    for offset in range(0, len(literal), 4):
        red, green, blue, alpha = literal[offset : offset + 4]
        hidden_rgb += int(alpha == 0 and (red != 0 or green != 0 or blue != 0))
        exact_chroma += int(alpha > 0 and (red, green, blue) == (255, 0, 255))
        near_chroma += int(alpha > 0 and red >= 240 and green <= 16 and blue >= 240)

    boundaries = physical_boundary_report(v11_scene, v12_scene)
    semantic_digest = hashlib.sha256(
        ("\n".join(owner or "" for owner in owners) + "\n").encode("utf-8")
    ).hexdigest()
    component_owners = {
        "schema": 1,
        "physicalDepthResolvedBeforeSemanticAggregation": True,
        "physicalToSemanticOwner": {
            item["id"]: item.get("semanticOwnerID", item["id"])
            for item in v12_scene["components"]
        },
        "physicalVisiblePixels": {
            owner: len(indices) for owner, indices in sorted(physical_pixels.items())
        },
        "semanticVisiblePixels": {
            owner: len(indices) for owner, indices in sorted(owner_pixels.items())
        },
        "postDepthSemanticOwnerSHA256": semantic_digest,
    }

    gates = {
        "westOwnerAtLeast24": len(west) >= 24,
        "westErodedCoreAtLeast8": len(eroded) >= 8,
        "westHasRealFilled4x6": bool(rectangles),
        "selectedRectangleFilled": selected_passed,
        "selectedRectangleGuardExact": guard_passed,
        "eastJambAtLeast38": len(owner_pixels.get("north-v09-portal-jamb-east", [])) >= 38,
        "headerAtLeast55": len(owner_pixels.get("north-v09-portal-header", [])) >= 55,
        "insetAtLeast78": len(owner_pixels.get("v12-portal-inset", [])) >= 78,
        "occupiedPixelsExact2277": len(occupied) == 2277,
        "occupiedBoundsExact": occupied_bounds == [64, 53, 128, 112],
        "v11SilhouetteIoUExact": math.isclose(silhouette_iou, 1.0, abs_tol=0.0),
        "hotProcessMinusPrimaryAtLeast60": hot_luma - primary_luma >= 60,
        "grayscaleTierGapsAtLeast15": min(tier_gaps) >= 15,
        "physicalBoundariesPassed": boundaries["passed"],
        "cameraExact": v12_scene["camera"] == v11_scene["camera"],
        "registrationExact": v12_scene["registration"] == v11_scene["registration"],
        "contactExact": v12_scene["shadow"] == v11_scene["shadow"],
        "lightExact": v12_scene["light"] == v11_scene["light"],
        "samplingExact": v12_scene["cycles"] == v11_scene["cycles"],
        "coordinateBridgeExact": v12_scene["coordinateBridge"] == v11_scene["coordinateBridge"],
        "pivotExact": v12_scene["registration"]["groundPivotSource"] == [768, 896],
        "socketExact": v12_scene["registration"]["frontageSocketSource"] == [896, 704],
        "footprintExact": v12_scene["registration"]["footprintPolygonSource"] == [[768, 640], [1024, 768], [768, 896], [512, 768]],
        "zeroHiddenRGB": hidden_rgb == 0,
        "zeroExactChroma": exact_chroma == 0,
        "zeroNearChroma": near_chroma == 0,
        "pixelProductionFrozen": (
            v12_scene["pixelProduction"] == "not_produced"
            and v12_scene["processes"] == {"A": "not_produced", "B": "not_produced", "C": "not_produced"}
        ),
    }

    field_diff = {
        "schema": 1,
        "task": "PLAY-027",
        "authorityCommit": AUTHORITY_COMMIT,
        "frozenHead": FROZEN_HEAD,
        "authorizedHypothesisCount": 1,
        "sceneSHA256": sha256(scene_path),
        "materialsSHA256": sha256(materials_path),
        "materialChanges": [],
        "mechanicalBindings": [
            "sourceRevision",
            "sceneGeometryID",
            "materialLibrary.file",
            "architecture component ID arrays",
            "unique physical and semantic owner declarations",
        ],
        "authorizedGeometryChanges": [
            "compound west portal pier: exterior box plus exact ordered triangular prism",
            "portal inset segmented at x=14",
            "raised high bay segmented at x=12 with east lower relief",
            "east-return cap low-z 4.6 to 7.0",
            "gantry girder A low-z 2.7 to 3.2",
            "gantry pier east low-z 3.0 to 3.3",
            "east assembly return low-z 4.4 to 6.0",
        ],
        "nonWhitelistedChangeCount": 0,
    }
    validation = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v12-zero-pixel",
        "authorityCommit": AUTHORITY_COMMIT,
        "authorityFileSHA256": AUTHORITY_SHA,
        "claimSHA256": CLAIM_SHA,
        "frozenHead": FROZEN_HEAD,
        "sceneSHA256": sha256(scene_path),
        "materialsSHA256": sha256(materials_path),
        "analyticBuilderSHA256": sha256(analytic_path),
        "frozenInputManifestSHA256": MANIFEST_SHA,
        "frozenInputSourceCommits": sorted({item["sourceCommit"] for item in manifest["files"]}),
        "analyticOnly": True,
        "semanticEvaluationOrder": "physical-depth-then-semantic-owner",
        "portal": {
            "westOwnerPixels": len(west),
            "westBounds": legacy.bounds_for(west, 192),
            "westErodedCorePixels": len(eroded),
            "filled4x6Rectangles": rectangles,
            "selectedInclusiveRectangle": [105, 82, 108, 87],
            "selectedRectangleFilled": selected_passed,
            "guardCellCount": len(guard_coordinates),
            "guard": guard_results,
            "eastJambPixels": len(owner_pixels.get("north-v09-portal-jamb-east", [])),
            "headerPixels": len(owner_pixels.get("north-v09-portal-header", [])),
            "insetPixels": len(owner_pixels.get("v12-portal-inset", [])),
        },
        "occupied": {"pixels": len(occupied), "bounds": occupied_bounds},
        "silhouette": {
            "intersectionPixels": intersection,
            "unionPixels": union,
            "iouAgainstV11": silhouette_iou,
        },
        "hierarchy": {
            "hotProcessMedianLuma": hot_luma,
            "primaryMassMedianLuma": primary_luma,
            "hotProcessMinusPrimary": hot_luma - primary_luma,
            "grayscaleTiers": tiers,
            "grayscaleTierGaps": tier_gaps,
            "actualProcessAPending": [
                "freight-frame median",
                "freight-frame minus primary mass",
                "hot-process minus freight-frame",
                "non-neon appearance",
            ],
        },
        "pixelSafety": {
            "hiddenRGB": hidden_rgb,
            "exactChromaAtNonzeroAlpha": exact_chroma,
            "nearChromaAtNonzeroAlpha": near_chroma,
        },
        "physicalBoundaries": boundaries,
        "postDepthSemanticOwnerSHA256": semantic_digest,
        "prepublicationReferencesNonAuthoritative": {
            "rgbaSHA256": "c8edec18ff9937228aca6a2296f5d5bef47dec4d9712b9e238ed408abe1a41a5",
            "semanticOwnerSHA256": "9270a4c358678da8ff7a964c092c8cfcea5f67281d5abf2b857ceb04ff5acf4e",
            "reportSHA256": "a6a52786185db5ce136e58a7bec547988f4331d213224e99f73832714270dc96",
        },
        "gates": gates,
        "validationPassed": all(gates.values()),
        "hardEnvelope": {"maximumConcurrency": 1, "combinedWallSeconds": 120, "peakMemoryMiB": 512},
        "processCounts": {
            "analytic": 1,
            "blender": 0,
            "cycles": 0,
            "sceneKit": 0,
            "metal": 0,
            "imageGen": 0,
            "normalizer": 0,
            "A": 0,
            "B": 0,
            "C": 0,
            "siblings": 0,
        },
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }

    _, _, v11_preview = legacy.read_png(v11_preview_path)
    outputs = {
        "EXACT-192-COLOR.png": png_payload(legacy, 192, 128, literal),
        "EXACT-192-GRAYSCALE.png": png_payload(legacy, 192, 128, legacy.grayscale(literal)),
        "EXACT-192-SEMANTIC.png": png_payload(legacy, 192, 128, semantic_rgba),
        "V11-V12-COMPARISON.png": png_payload(
            legacy,
            384,
            128,
            horizontal_strip([v11_preview, literal], 192, 128),
        ),
    }
    create_exact_directory(output, expected_output, allowed_directories)
    sealed = SealedDirectory(output, FILES)
    sealed.copy_regular("SCENE.json", scene_path)
    sealed.copy_regular("MATERIALS.json", materials_path)
    sealed.copy_regular("PORTABILITY.json", portability_path)
    sealed.write_json("COMPONENT-OWNERS.json", component_owners)
    sealed.write_json("FIELD-DIFF.json", field_diff)
    sealed.write_json("PHYSICAL-BOUNDARIES.json", boundaries)
    sealed.write_json("VALIDATION.json", validation)
    for name, payload in outputs.items():
        sealed.write_bytes(name, payload)
    actual_files = sorted(path.name for path in output.iterdir())
    if actual_files != sorted(FILES):
        raise RuntimeError(f"generated output inventory drift: {actual_files}")
    if not validation["validationPassed"]:
        failed = [name for name, passed in gates.items() if not passed]
        raise RuntimeError(f"v12 zero-pixel hypothesis failed: {failed}")


if __name__ == "__main__":
    main()
