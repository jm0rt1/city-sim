#!/usr/bin/env python3
"""Fail-closed zero-pixel validator for the single PLAY-027 North v10 hypothesis."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
import shutil
import stat
from pathlib import Path
from typing import Any


AUTHORITY_COMMIT = "9e5b4a59f7346cd89e7b9e9cd3bbc65643d66a24"
REJECTED_PARENT = "4255b021f743281b60cfdf8cff896235d405be23"
V09_SCENE_SHA = "50db925c32c442d5c30ee17d4cb74f50c4623c060354d45cf99500f0feb96a87"
V09_MATERIALS_SHA = "243b1bd05b9db036f5350d0f2efab311d6f627702a3fda501959dfac6a7590a0"
V09_BUILDER_SHA = "b09bd1e809e55ae360eee14b5b96a8e85c168a83a1fbd78b90295e0d00ab50b0"
V10_SCENE_SHA = "0f572b80ec8d17f23e8569816e9a1f17502b114c1a4e361ea582d4ca388f8459"
V10_MATERIALS_SHA = "e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09"
V08_PREVIEW_SHA = "404a7322fcf78e2de5ccd1e5c4cb4ef74eff2314b42f885484f66c0731020f28"
V09_PREVIEW_SHA = "f8f0ea0cf01264731ceef5271789615809a51a0b9d3419301b6330d088ac3ecb"

SOURCE_REL = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v10"
)
EVIDENCE_REL = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v10"
)
V09_SOURCE_REL = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v09"
)
V08_PREVIEW_REL = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v08/replay-a/NON-SOURCE-SEMANTIC-192-COLOR.png"
)
V09_PREVIEW_REL = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v09/review/EXACT-192-COLOR.png"
)

FILES = [
    "SCENE.json",
    "MATERIALS.json",
    "FIELD-DIFF.json",
    "VALIDATION.json",
    "EXACT-192-COLOR.png",
    "EXACT-192-GRAYSCALE.png",
    "EXACT-192-SEMANTIC.png",
    "V08-V09-V10-COMPARISON.png",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: Any) -> None:
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def assert_no_symlink_chain(path: Path) -> None:
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current /= part
        if not os.path.lexists(current):
            continue
        mode = os.lstat(current).st_mode
        if stat.S_ISLNK(mode):
            raise RuntimeError(f"symlink path component forbidden: {current}")


def assert_regular(path: Path, expected_sha: str) -> None:
    assert_no_symlink_chain(path)
    if not path.is_file() or path.is_symlink():
        raise RuntimeError(f"regular non-symlink input required: {path}")
    actual = sha256(path)
    if actual != expected_sha:
        raise RuntimeError(
            f"input hash drift: {path}: expected {expected_sha}, got {actual}"
        )


def import_v09_builder(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("play027_v09_builder", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load frozen v09 analytic builder")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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
    v09: dict[str, Any],
    v10_material_sha: str,
) -> dict[str, Any]:
    expected = copy.deepcopy(v09)
    expected["sourceRevision"] = "blender-art-v10-prepixel"
    expected["sceneGeometryID"] = "industrial-l04-north-v10-local-portal-repair"
    expected["materialLibrary"] = {
        "file": str(SOURCE_REL / "MATERIALS.json"),
        "sha256": v10_material_sha,
    }
    component(
        expected,
        "north-v09-portal-jamb-west",
    )["position"][0] = 8.0
    expected["visibilityTargets"]["portalApertureCitySimAABB"][0][0] = 9.5
    for item in expected["components"]:
        if item["materialID"] == "v09-freight-frame":
            item["materialID"] = "v10-freight-frame"
    return expected


def expected_materials(v09: dict[str, Any]) -> dict[str, Any]:
    expected = copy.deepcopy(v09)
    expected["libraryID"] = (
        "industrial-l04-north-v10-local-portal-repair-materials"
    )
    frame = material(expected, "v09-freight-frame")
    frame["id"] = "v10-freight-frame"
    frame["emissionStrength"] = 0.30
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

    repository = args.repository_root.absolute()
    if repository.resolve() != repository:
        raise RuntimeError("repository root must be canonical")
    source_root = repository / SOURCE_REL
    evidence_root = repository / EVIDENCE_REL
    expected_output = evidence_root / f"replay-{args.replay_id}"
    output = args.output_root.absolute()
    if output != expected_output:
        raise RuntimeError(
            f"output root is not exact whitelist target: {output}"
        )
    assert_no_symlink_chain(repository)
    assert_no_symlink_chain(source_root)
    assert_no_symlink_chain(evidence_root)
    assert_no_symlink_chain(output)
    if output.exists() or output.is_symlink():
        raise RuntimeError(f"output root must be absent: {output}")
    if args.replay_id == "a":
        if evidence_root.exists() or evidence_root.is_symlink():
            raise RuntimeError("evidence root must be absent before replay-a")
    else:
        replay_a = evidence_root / "replay-a"
        if not replay_a.is_dir() or replay_a.is_symlink():
            raise RuntimeError("complete replay-a required before replay-b")
        if sorted(path.name for path in replay_a.iterdir()) != sorted(FILES):
            raise RuntimeError("replay-a inventory drift before replay-b")

    v09_scene_path = repository / V09_SOURCE_REL / "SCENE.json"
    v09_materials_path = repository / V09_SOURCE_REL / "MATERIALS.json"
    v09_builder_path = repository / V09_SOURCE_REL / "build_prepixel.py"
    v10_scene_path = source_root / "SCENE.json"
    v10_materials_path = source_root / "MATERIALS.json"
    v08_preview_path = repository / V08_PREVIEW_REL
    v09_preview_path = repository / V09_PREVIEW_REL
    assert_regular(v09_scene_path, V09_SCENE_SHA)
    assert_regular(v09_materials_path, V09_MATERIALS_SHA)
    assert_regular(v09_builder_path, V09_BUILDER_SHA)
    assert_regular(v10_scene_path, V10_SCENE_SHA)
    assert_regular(v10_materials_path, V10_MATERIALS_SHA)
    assert_regular(v08_preview_path, V08_PREVIEW_SHA)
    assert_regular(v09_preview_path, V09_PREVIEW_SHA)

    v09_scene = load_json(v09_scene_path)
    v09_materials = load_json(v09_materials_path)
    v10_scene = load_json(v10_scene_path)
    v10_materials = load_json(v10_materials_path)
    if v10_scene != expected_scene(v09_scene, V10_MATERIALS_SHA):
        raise RuntimeError("v10 scene contains a non-whitelisted field change")
    if v10_materials != expected_materials(v09_materials):
        raise RuntimeError("v10 materials contain a non-whitelisted field change")

    field_diff = {
        "task": "PLAY-027",
        "authorityCommit": AUTHORITY_COMMIT,
        "rejectedParent": REJECTED_PARENT,
        "hypothesisCount": 1,
        "sceneChanges": [
            {
                "path": "sourceRevision",
                "old": "blender-art-v09-prepixel",
                "new": "blender-art-v10-prepixel",
                "classification": "mechanical-binding",
            },
            {
                "path": "sceneGeometryID",
                "old": "industrial-l04-north-v09-monumental-high-bay-foundry",
                "new": "industrial-l04-north-v10-local-portal-repair",
                "classification": "mechanical-binding",
            },
            {
                "path": "materialLibrary",
                "classification": "mechanical-binding",
                "newSHA256": V10_MATERIALS_SHA,
            },
            {
                "path": "components[north-v09-portal-jamb-west].position.x",
                "old": 6.5,
                "new": 8.0,
                "classification": "authorized-geometry-hypothesis",
            },
            {
                "path": "visibilityTargets.portalApertureCitySimAABB.min.x",
                "old": 8,
                "new": 9.5,
                "classification": "derived-clear-aperture-binding",
            },
            {
                "path": "components[*].materialID",
                "old": "v09-freight-frame",
                "new": "v10-freight-frame",
                "affectedCount": sum(
                    item["materialID"] == "v09-freight-frame"
                    for item in v09_scene["components"]
                ),
                "classification": "mechanical-material-binding",
            },
        ],
        "materialChanges": [
            {
                "path": "libraryID",
                "classification": "mechanical-binding",
            },
            {
                "path": "materials[v09-freight-frame].id",
                "old": "v09-freight-frame",
                "new": "v10-freight-frame",
                "classification": "mechanical-binding",
            },
            {
                "path": "materials[v10-freight-frame].emissionStrength",
                "old": "absent",
                "new": 0.30,
                "classification": "frozen-material-hypothesis",
                "analyticConsumption": False,
            },
        ],
        "nonWhitelistedChangeCount": 0,
    }

    legacy = import_v09_builder(v09_builder_path)
    literal, owners, groups = legacy.render(v10_scene, v10_materials, 192, 128)
    _, v09_owners, _ = legacy.render(v09_scene, v09_materials, 192, 128)
    structural = legacy.structural_validation(v10_scene)
    component_pixels = {
        item["id"]: [
            index for index, owner in enumerate(owners) if owner == item["id"]
        ]
        for item in v10_scene["components"]
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

    west = component(v10_scene, west_id)
    east = component(v10_scene, portal_ids["eastJamb"])
    clear_width = (
        float(east["position"][0]) - float(east["dimensions"][0]) / 2.0
        - (
            float(west["position"][0])
            + float(west["dimensions"][0]) / 2.0
        )
    )
    empty_aperture = (
        [9.5, 1.2, -12.8],
        [24.0, 17.0, -10.4],
    )
    overlap_violations = []
    for item in v10_scene["components"]:
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
    for item in v10_scene["components"]:
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
        raise RuntimeError("empty v10 analytic preview")
    occupied_size = [
        occupied_bounds[2] - occupied_bounds[0],
        occupied_bounds[3] - occupied_bounds[1],
    ]
    v10_mask = {index for index, owner in enumerate(owners) if owner is not None}
    v09_mask = {
        index for index, owner in enumerate(v09_owners) if owner is not None
    }
    intersection = len(v10_mask & v09_mask)
    union = len(v10_mask | v09_mask)
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
        item["id"]: item for item in v10_scene["components"]
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
        "headerNoRegression": len(component_pixels[portal_ids["header"]]) >= 40,
        "insetNoRegression": len(component_pixels[portal_ids["inset"]]) >= 91,
        "clearApertureExactly14Point5": abs(clear_width - 14.5) <= 0.000001,
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
            v10_scene["registration"]["groundPivotSource"] == [768, 896]
        ),
        "socketExact": (
            v10_scene["registration"]["frontageSocketSource"] == [896, 704]
        ),
        "footprintExact": (
            v10_scene["registration"]["footprintPolygonSource"]
            == [[768, 640], [1024, 768], [768, 896], [512, 768]]
        ),
        "zeroHiddenRGB": hidden_rgb == 0,
        "zeroExactChroma": exact_chroma == 0,
        "zeroNearChroma": near_chroma == 0,
        "pixelProductionFrozen": (
            v10_scene["pixelProduction"] == "not_produced"
            and v10_scene["processes"]
            == {"A": "not_produced", "B": "not_produced", "C": "not_produced"}
        ),
    }

    validation = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v10-zero-pixel",
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
        "sceneSHA256": V10_SCENE_SHA,
        "materialsSHA256": V10_MATERIALS_SHA,
        "frozenInputHashes": {
            "v09Scene": V09_SCENE_SHA,
            "v09Materials": V09_MATERIALS_SHA,
            "v09Builder": V09_BUILDER_SHA,
            "v08Preview": V08_PREVIEW_SHA,
            "v09Preview": V09_PREVIEW_SHA,
        },
        "portal": portal,
        "clearApertureWorldUnits": clear_width,
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

    output.mkdir(parents=True, exist_ok=False)
    assert_no_symlink_chain(output)
    shutil.copyfile(v10_scene_path, output / "SCENE.json")
    shutil.copyfile(v10_materials_path, output / "MATERIALS.json")
    write_json(output / "FIELD-DIFF.json", field_diff)
    write_json(output / "VALIDATION.json", validation)
    legacy.write_png(output / "EXACT-192-COLOR.png", 192, 128, literal)
    legacy.write_png(
        output / "EXACT-192-GRAYSCALE.png",
        192,
        128,
        legacy.grayscale(literal),
    )
    legacy.write_png(
        output / "EXACT-192-SEMANTIC.png",
        192,
        128,
        legacy.semantic_image(groups),
    )
    _, _, v08_preview = legacy.read_png(v08_preview_path)
    _, _, v09_preview = legacy.read_png(v09_preview_path)
    legacy.write_png(
        output / "V08-V09-V10-COMPARISON.png",
        576,
        128,
        horizontal_strip([v08_preview, v09_preview, literal], 192, 128),
    )
    if sorted(path.name for path in output.iterdir()) != sorted(FILES):
        raise RuntimeError("generated output inventory drift")
    if not validation["validationPassed"]:
        failed = [name for name, passed in gates.items() if not passed]
        raise RuntimeError(f"v10 zero-pixel hypothesis failed: {failed}")


if __name__ == "__main__":
    main()
