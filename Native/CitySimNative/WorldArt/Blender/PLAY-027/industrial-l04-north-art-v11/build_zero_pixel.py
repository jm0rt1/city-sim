#!/usr/bin/env python3
"""Fail-closed zero-pixel validator for the single PLAY-027 North v11 hypothesis."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import struct
import types
import zlib
from pathlib import Path
from typing import Any

from sealed_io import (
    SealedDirectory,
    create_exact_directory,
    reject_symlink_or_missing_chain,
)


AUTHORITY_COMMIT = "ce9a8c633dd07148d6439ca42248890a3fa62a01"
REJECTED_PARENT = "7042f0934903ca54e360725251a96205a347af4e"
V09_SCENE_SHA = "50db925c32c442d5c30ee17d4cb74f50c4623c060354d45cf99500f0feb96a87"
V09_MATERIALS_SHA = "243b1bd05b9db036f5350d0f2efab311d6f627702a3fda501959dfac6a7590a0"
V09_BUILDER_SHA = "b09bd1e809e55ae360eee14b5b96a8e85c168a83a1fbd78b90295e0d00ab50b0"
V10_SCENE_SHA = "0f572b80ec8d17f23e8569816e9a1f17502b114c1a4e361ea582d4ca388f8459"
V10_MATERIALS_SHA = "e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09"
V10_PREVIEW_SHA = "4555aad01bb3cba86f7a26f16c12bf8165463cfe70a6c4553b3f3aa423c2c235"
V11_SCENE_SHA = "814d9c2c86a740f04622f4ac47718c14d8f92d090fb127d921270e96ef1921c3"
V11_MATERIALS_SHA = V10_MATERIALS_SHA
V09_PREVIEW_SHA = "f8f0ea0cf01264731ceef5271789615809a51a0b9d3419301b6330d088ac3ecb"
FROZEN_INPUT_MANIFEST_SHA = (
    "93a6e4a19c5cbec956a970df9529608d65ffa76f39a249cc0fa4766c8458edc6"
)

SOURCE_REL = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v11"
)
EVIDENCE_REL = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v11"
)
FROZEN_INPUT_REL = SOURCE_REL / "frozen-inputs"
V09_SOURCE_REL = FROZEN_INPUT_REL / "v09"
V10_SOURCE_REL = FROZEN_INPUT_REL / "v10"
V09_PREVIEW_REL = FROZEN_INPUT_REL / "v09/EXACT-192-COLOR.png"
V10_PREVIEW_REL = FROZEN_INPUT_REL / "v10/EXACT-192-COLOR.png"

FILES = [
    "SCENE.json",
    "MATERIALS.json",
    "FIELD-DIFF.json",
    "VALIDATION.json",
    "EXACT-192-COLOR.png",
    "EXACT-192-GRAYSCALE.png",
    "EXACT-192-SEMANTIC.png",
    "V09-V10-V11-COMPARISON.png",
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


def import_v09_builder(path: Path) -> Any:
    module = types.ModuleType("play027_v09_builder")
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


def validate_frozen_bundle(bundle_root: Path) -> dict[str, Any]:
    manifest_path = bundle_root / "MANIFEST.json"
    assert_regular(manifest_path, FROZEN_INPUT_MANIFEST_SHA)
    manifest = load_json(manifest_path)
    expected_paths = sorted(item["path"] for item in manifest["files"])
    actual_paths = sorted(
        str(path.relative_to(bundle_root))
        for path in bundle_root.rglob("*")
        if path.is_file()
    )
    if actual_paths != sorted(["MANIFEST.json", *expected_paths]):
        raise RuntimeError(
            f"frozen input inventory drift: expected {expected_paths}, got {actual_paths}"
        )
    for item in manifest["files"]:
        path = bundle_root / item["path"]
        assert_regular(path, item["sha256"])
        if path.stat().st_size != item["bytes"]:
            raise RuntimeError(f"frozen input byte-count drift: {path}")
    return manifest


def component(scene: dict[str, Any], component_id: str) -> dict[str, Any]:
    matches = [
        item for item in scene["components"] if item["id"] == component_id
    ]
    if len(matches) != 1:
        raise RuntimeError(f"component identity mismatch: {component_id}")
    return matches[0]


def material(materials: dict[str, Any], material_id: str) -> dict[str, Any]:
    matches = [
        item for item in materials["materials"] if item["id"] == material_id
    ]
    if len(matches) != 1:
        raise RuntimeError(f"material identity mismatch: {material_id}")
    return matches[0]


def expected_scene(
    v10: dict[str, Any],
    v11_material_sha: str,
) -> dict[str, Any]:
    expected = copy.deepcopy(v10)
    expected["sourceRevision"] = "blender-art-v11-prepixel"
    expected["sceneGeometryID"] = "industrial-l04-north-v11-outward-west-jamb"
    expected["materialLibrary"] = {
        "file": str(SOURCE_REL / "MATERIALS.json"),
        "sha256": v11_material_sha,
    }
    west = component(expected, "north-v09-portal-jamb-west")
    west["dimensions"][0] = 6.0
    west["position"][0] = 6.5
    header = component(expected, "north-v09-portal-header")
    header["dimensions"][0] = 23.5
    header["position"][0] = 15.25
    return expected


def aabb(item: dict[str, Any]) -> tuple[list[float], list[float]]:
    low = [
        float(item["position"][axis])
        - float(item["dimensions"][axis]) / 2.0
        for axis in range(3)
    ]
    high = [
        float(item["position"][axis])
        + float(item["dimensions"][axis]) / 2.0
        for axis in range(3)
    ]
    return low, high


def positive_overlap(
    first: tuple[list[float], list[float]],
    second: tuple[list[float], list[float]],
) -> list[float]:
    return [
        min(first[1][axis], second[1][axis])
        - max(first[0][axis], second[0][axis])
        for axis in range(3)
    ]


def eroded_count(indices: list[int], width: int, height: int) -> int:
    mask = set(indices)
    count = 0
    for index in indices:
        x = index % width
        y = index // width
        if x == 0 or y == 0 or x == width - 1 or y == height - 1:
            continue
        neighbors = [
            (y + dy) * width + x + dx
            for dy in (-1, 0, 1)
            for dx in (-1, 0, 1)
        ]
        if all(neighbor in mask for neighbor in neighbors):
            count += 1
    return count


def luma_median(legacy: Any, rgba: bytes, indices: list[int]) -> int:
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
        raise RuntimeError("repository root must be canonical")
    source_root = repository / SOURCE_REL
    evidence_root = repository / EVIDENCE_REL
    expected_output = evidence_root / f"replay-{args.replay_id}"
    output = args.output_root
    if not output.is_absolute() or output.parts != expected_output.parts:
        raise RuntimeError(
            f"output root is not exact whitelist target: {output}"
        )
    reject_symlink_or_missing_chain(repository)
    reject_symlink_or_missing_chain(source_root)
    if args.replay_id == "a":
        if os.path.lexists(evidence_root):
            raise RuntimeError("evidence root must be absent before replay-a")
        allowed_new_directories = (evidence_root, output)
    else:
        replay_a = evidence_root / "replay-a"
        reject_symlink_or_missing_chain(evidence_root)
        if not replay_a.is_dir() or replay_a.is_symlink():
            raise RuntimeError("complete replay-a required before replay-b")
        if sorted(path.name for path in replay_a.iterdir()) != sorted(FILES):
            raise RuntimeError("replay-a inventory drift before replay-b")
        allowed_new_directories = (output,)

    v09_scene_path = repository / V09_SOURCE_REL / "SCENE.json"
    v09_materials_path = repository / V09_SOURCE_REL / "MATERIALS.json"
    v09_builder_path = repository / V09_SOURCE_REL / "build_prepixel.py"
    v10_scene_path = repository / V10_SOURCE_REL / "SCENE.json"
    v10_materials_path = repository / V10_SOURCE_REL / "MATERIALS.json"
    v11_scene_path = source_root / "SCENE.json"
    v11_materials_path = source_root / "MATERIALS.json"
    v09_preview_path = repository / V09_PREVIEW_REL
    v10_preview_path = repository / V10_PREVIEW_REL
    frozen_manifest = validate_frozen_bundle(
        repository / FROZEN_INPUT_REL
    )
    assert_regular(v09_scene_path, V09_SCENE_SHA)
    assert_regular(v09_materials_path, V09_MATERIALS_SHA)
    assert_regular(v09_builder_path, V09_BUILDER_SHA)
    assert_regular(v10_scene_path, V10_SCENE_SHA)
    assert_regular(v10_materials_path, V10_MATERIALS_SHA)
    assert_regular(v11_scene_path, V11_SCENE_SHA)
    assert_regular(v11_materials_path, V11_MATERIALS_SHA)
    assert_regular(v09_preview_path, V09_PREVIEW_SHA)
    assert_regular(v10_preview_path, V10_PREVIEW_SHA)

    v09_scene = load_json(v09_scene_path)
    v09_materials = load_json(v09_materials_path)
    v10_scene = load_json(v10_scene_path)
    v10_materials = load_json(v10_materials_path)
    v11_scene = load_json(v11_scene_path)
    v11_materials = load_json(v11_materials_path)
    if v11_scene != expected_scene(v10_scene, V11_MATERIALS_SHA):
        raise RuntimeError("v11 scene contains a non-whitelisted field change")
    if v11_materials != v10_materials:
        raise RuntimeError("v11 materials differ from frozen v10 bytes")

    field_diff = {
        "task": "PLAY-027",
        "authorityCommit": AUTHORITY_COMMIT,
        "rejectedParent": REJECTED_PARENT,
        "hypothesisCount": 1,
        "sceneChanges": [
            {
                "path": "sourceRevision",
                "old": "blender-art-v10-prepixel",
                "new": "blender-art-v11-prepixel",
                "classification": "mechanical-binding",
            },
            {
                "path": "sceneGeometryID",
                "old": "industrial-l04-north-v10-local-portal-repair",
                "new": "industrial-l04-north-v11-outward-west-jamb",
                "classification": "mechanical-binding",
            },
            {
                "path": "materialLibrary",
                "classification": "mechanical-binding",
                "oldSHA256": V10_MATERIALS_SHA,
                "newSHA256": V11_MATERIALS_SHA,
            },
            {
                "path": "components[north-v09-portal-jamb-west].dimensions.x",
                "old": 3.0,
                "new": 6.0,
                "classification": "authorized-geometry-hypothesis",
            },
            {
                "path": "components[north-v09-portal-jamb-west].position.x",
                "old": 8.0,
                "new": 6.5,
                "classification": "authorized-geometry-hypothesis",
            },
            {
                "path": "components[north-v09-portal-header].dimensions.x",
                "old": 22.0,
                "new": 23.5,
                "classification": "authorized-geometry-hypothesis",
            },
            {
                "path": "components[north-v09-portal-header].position.x",
                "old": 16.0,
                "new": 15.25,
                "classification": "authorized-geometry-hypothesis",
            },
        ],
        "materialChanges": [],
        "nonWhitelistedChangeCount": 0,
    }

    legacy = import_v09_builder(v09_builder_path)
    literal, owners, groups = legacy.render(v11_scene, v11_materials, 192, 128)
    _, v09_owners, _ = legacy.render(v09_scene, v09_materials, 192, 128)
    structural = legacy.structural_validation(v11_scene)
    component_pixels = {
        item["id"]: [
            index for index, owner in enumerate(owners) if owner == item["id"]
        ]
        for item in v11_scene["components"]
    }
    group_pixels = {
        group: [index for index, value in enumerate(groups) if value == group]
        for group in sorted({value for value in groups if value is not None})
    }
    west_id = "north-v09-portal-jamb-west"
    west_indices = component_pixels[west_id]
    west_bounds = legacy.bounds_for(west_indices, 192)
    if west_bounds is None:
        west_size = [0, 0]
    else:
        west_size = [
            west_bounds[2] - west_bounds[0],
            west_bounds[3] - west_bounds[1],
        ]
    west_eroded = eroded_count(west_indices, 192, 128)

    portal_ids = {
        "westJamb": west_id,
        "eastJamb": "north-v09-portal-jamb-east",
        "header": "north-v09-portal-header",
        "inset": "north-v09-portal-inset",
    }
    portal = {
        name: {
            "exactSemanticCorePixels": len(component_pixels[item_id]),
            "bounds": legacy.bounds_for(component_pixels[item_id], 192),
        }
        for name, item_id in portal_ids.items()
    }
    portal["westJamb"]["onePixelErodedCorePixels"] = west_eroded

    west = component(v11_scene, west_id)
    east = component(v11_scene, portal_ids["eastJamb"])
    header = component(v11_scene, portal_ids["header"])
    hall = component(v11_scene, "north-v09-main-foundry-hall")
    west_low, west_high = aabb(west)
    east_low, _ = aabb(east)
    header_low, header_high = aabb(header)
    _, hall_high = aabb(hall)
    clear_width = (
        east_low[0] - west_high[0]
    )
    hall_clearance = min(west_low[0], header_low[0]) - hall_high[0]
    empty_aperture = (
        [9.5, 1.2, -12.8],
        [24.0, 17.0, -10.4],
    )
    overlap_violations = []
    for item in v11_scene["components"]:
        if item["id"] == portal_ids["inset"]:
            continue
        amount = positive_overlap(empty_aperture, aabb(item))
        if min(amount) > 0.000001:
            overlap_violations.append(
                {"componentID": item["id"], "overlap": amount}
            )
    center_x = (empty_aperture[0][0] + empty_aperture[1][0]) / 2.0
    center_y = (empty_aperture[0][1] + empty_aperture[1][1]) / 2.0
    ray_hits = []
    for item in v11_scene["components"]:
        low, high = aabb(item)
        if low[0] <= center_x <= high[0] and low[1] <= center_y <= high[1]:
            ray_hits.append(
                {
                    "componentID": item["id"],
                    "entryZ": low[2],
                    "exitZ": high[2],
                }
            )
    ray_hits.sort(key=lambda item: item["entryZ"])
    first_after_frame = [
        hit for hit in ray_hits if hit["entryZ"] >= empty_aperture[0][2]
    ]
    ray_order_passed = bool(first_after_frame) and (
        first_after_frame[0]["componentID"] == portal_ids["inset"]
        and abs(first_after_frame[0]["entryZ"] - empty_aperture[1][2])
        <= 0.000001
    )

    occupied = [index for index, owner in enumerate(owners) if owner is not None]
    occupied_bounds = legacy.bounds_for(occupied, 192)
    if occupied_bounds is None:
        raise RuntimeError("empty v11 analytic preview")
    occupied_size = [
        occupied_bounds[2] - occupied_bounds[0],
        occupied_bounds[3] - occupied_bounds[1],
    ]
    v11_mask = {index for index, owner in enumerate(owners) if owner is not None}
    v09_mask = {
        index for index, owner in enumerate(v09_owners) if owner is not None
    }
    intersection = len(v11_mask & v09_mask)
    union = len(v11_mask | v09_mask)
    silhouette_iou = float(intersection) / float(union)

    hot_luma = luma_median(
        legacy,
        literal,
        group_pixels.get("hot-process", []),
    )
    primary_luma = luma_median(
        legacy,
        literal,
        group_pixels.get("primary-mass", []),
    )
    component_by_id = {
        item["id"]: item for item in v11_scene["components"]
    }
    tier_materials = {
        "primaryFacade": {"v09-warm-foundry-masonry"},
        "roofHighBay": {"v09-bluegreen-roof", "v09-roof-edge"},
        "equipmentProcess": {"v09-oxidized-machinery"},
    }
    tiers = {}
    for name, material_ids in tier_materials.items():
        indices = [
            index
            for index, owner in enumerate(owners)
            if owner is not None
            and component_by_id[owner]["materialID"] in material_ids
        ]
        tiers[name] = luma_median(legacy, literal, indices)
    tier_values = sorted(tiers.values())
    tier_gaps = [
        tier_values[index + 1] - tier_values[index]
        for index in range(len(tier_values) - 1)
    ]

    hidden_rgb = 0
    exact_chroma = 0
    near_chroma = 0
    for index in range(0, len(literal), 4):
        red, green, blue, alpha = literal[index : index + 4]
        if alpha == 0 and (red != 0 or green != 0 or blue != 0):
            hidden_rgb += 1
        if alpha > 0 and (red, green, blue) == (255, 0, 255):
            exact_chroma += 1
        if alpha > 0 and red >= 240 and green <= 16 and blue >= 240:
            near_chroma += 1

    gates = {
        "westJambUnErodedCoreAtLeast12": len(west_indices) >= 12,
        "westJambOnePixelErodedCoreAtLeast8": west_eroded >= 8,
        "westJambBoundsAtLeast3x4": west_size[0] >= 3 and west_size[1] >= 4,
        "eastJambNoRegression": len(
            component_pixels[portal_ids["eastJamb"]]
        )
        >= 38,
        "headerNoRegression": len(component_pixels[portal_ids["header"]]) >= 46,
        "insetNoRegression": len(component_pixels[portal_ids["inset"]]) >= 95,
        "westJambBoundsExact": (
            abs(west_low[0] - 3.5) <= 0.000001
            and abs(west_high[0] - 9.5) <= 0.000001
        ),
        "headerBoundsExact": (
            abs(header_low[0] - 3.5) <= 0.000001
            and abs(header_high[0] - 27.0) <= 0.000001
        ),
        "westInnerFaceExact": abs(west_high[0] - 9.5) <= 0.000001,
        "eastInnerFaceExact": abs(east_low[0] - 24.0) <= 0.000001,
        "clearApertureExactly14Point5": abs(clear_width - 14.5) <= 0.000001,
        "mainHallClearanceAtLeast1Point7": hall_clearance >= 1.7 - 0.000001,
        "zeroSolidApertureOverlap": not overlap_violations,
        "emptyThenInsetRayOrder": ray_order_passed,
        "hotProcessMinusPrimaryAtLeast60": hot_luma - primary_luma >= 60,
        "allGrayscaleTierGapsAtLeast15": min(tier_gaps) >= 15,
        "compactEnvelopeAtMost64x60": (
            occupied_size[0] <= 64 and occupied_size[1] <= 60
        ),
        "v09SilhouetteIoUAtLeast0Point98": silhouette_iou >= 0.98,
        "structuralValidation": structural["passed"],
        "pivotExact": (
            v11_scene["registration"]["groundPivotSource"] == [768, 896]
        ),
        "socketExact": (
            v11_scene["registration"]["frontageSocketSource"] == [896, 704]
        ),
        "footprintExact": (
            v11_scene["registration"]["footprintPolygonSource"]
            == [[768, 640], [1024, 768], [768, 896], [512, 768]]
        ),
        "zeroHiddenRGB": hidden_rgb == 0,
        "zeroExactChroma": exact_chroma == 0,
        "zeroNearChroma": near_chroma == 0,
        "pixelProductionFrozen": (
            v11_scene["pixelProduction"] == "not_produced"
            and v11_scene["processes"]
            == {"A": "not_produced", "B": "not_produced", "C": "not_produced"}
        ),
    }

    validation = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v11-zero-pixel",
        "replayID": args.replay_id,
        "authorityCommit": AUTHORITY_COMMIT,
        "rejectedParent": REJECTED_PARENT,
        "analyticOnly": True,
        "analyticEmissionConsumed": False,
        "emissionHypothesis": {
            "materialID": "v10-freight-frame",
            "emissionStrength": 0.30,
            "cyclesLumaProof": "PENDING_ACTUAL_PROCESS_A",
            "pendingActualTargets": {
                "freightFrameMedian": [62, 78],
                "freightFrameMinusPrimaryMassMinimum": 18,
                "hotProcessMinusFreightFrameMinimum": 35,
                "nonNeonAppearance": "PENDING_ACTUAL_PROCESS_A",
            },
        },
        "sceneSHA256": V11_SCENE_SHA,
        "materialsSHA256": V11_MATERIALS_SHA,
        "frozenInputHashes": {
            "manifest": FROZEN_INPUT_MANIFEST_SHA,
            "v09Scene": V09_SCENE_SHA,
            "v09Materials": V09_MATERIALS_SHA,
            "v09Builder": V09_BUILDER_SHA,
            "v09Preview": V09_PREVIEW_SHA,
            "v10Scene": V10_SCENE_SHA,
            "v10Materials": V10_MATERIALS_SHA,
            "v10Preview": V10_PREVIEW_SHA,
        },
        "frozenInputSourceCommits": sorted(
            {item["sourceCommit"] for item in frozen_manifest["files"]}
        ),
        "portal": portal,
        "clearApertureWorldUnits": clear_width,
        "authorizedGeometry": {
            "westJambXBounds": [west_low[0], west_high[0]],
            "headerXBounds": [header_low[0], header_high[0]],
            "eastJambInnerFaceX": east_low[0],
            "mainHallPositiveX": hall_high[0],
            "minimumHallClearance": hall_clearance,
        },
        "effectiveEmptyApertureAABB": empty_aperture,
        "apertureOverlapViolations": overlap_violations,
        "roadToInsetRayHits": ray_hits,
        "occupied": {
            "bounds": occupied_bounds,
            "size": occupied_size,
            "pixels": len(occupied),
        },
        "silhouette": {
            "intersectionPixels": intersection,
            "unionPixels": union,
            "iouAgainstV09": silhouette_iou,
        },
        "analyticHierarchy": {
            "hotProcessMedianLuma": hot_luma,
            "primaryMassMedianLuma": primary_luma,
            "hotProcessMinusPrimaryMass": hot_luma - primary_luma,
            "grayscaleTiers": tiers,
            "grayscaleTierGaps": tier_gaps,
            "note": (
                "The frozen v09 analytic model ignores emissionStrength; "
                "freight-frame Cycles luma remains unproved."
            ),
        },
        "pixelSafety": {
            "hiddenRGB": hidden_rgb,
            "exactChromaAtNonzeroAlpha": exact_chroma,
            "nearChromaAtNonzeroAlpha": near_chroma,
        },
        "structuralValidation": structural,
        "gates": gates,
        "validationPassed": all(gates.values()),
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
        "hardEnvelope": {
            "maximumConcurrency": 1,
            "combinedWallSeconds": 120,
            "peakMemoryMiB": 512,
        },
        "sourceAuthority": False,
        "productionSelected": False,
    }

    _, _, v09_preview = legacy.read_png(v09_preview_path)
    _, _, v10_preview = legacy.read_png(v10_preview_path)
    output_payloads = {
        "EXACT-192-COLOR.png": png_payload(
            legacy,
            192,
            128,
            literal,
        ),
        "EXACT-192-GRAYSCALE.png": png_payload(
            legacy,
            192,
            128,
            legacy.grayscale(literal),
        ),
        "EXACT-192-SEMANTIC.png": png_payload(
            legacy,
            192,
            128,
            legacy.semantic_image(groups),
        ),
        "V09-V10-V11-COMPARISON.png": png_payload(
            legacy,
            576,
            128,
            horizontal_strip([v09_preview, v10_preview, literal], 192, 128),
        ),
    }
    create_exact_directory(
        output,
        expected_output,
        allowed_new_directories,
    )
    sealed = SealedDirectory(output, FILES)
    sealed.copy_regular("SCENE.json", v11_scene_path)
    sealed.copy_regular("MATERIALS.json", v11_materials_path)
    sealed.write_json("FIELD-DIFF.json", field_diff)
    sealed.write_json("VALIDATION.json", validation)
    for name, payload in output_payloads.items():
        sealed.write_bytes(name, payload)
    if sorted(path.name for path in output.iterdir()) != sorted(FILES):
        raise RuntimeError("generated output inventory drift")
    if not validation["validationPassed"]:
        failed = [name for name, passed in gates.items() if not passed]
        raise RuntimeError(f"v11 zero-pixel hypothesis failed: {failed}")


if __name__ == "__main__":
    main()
