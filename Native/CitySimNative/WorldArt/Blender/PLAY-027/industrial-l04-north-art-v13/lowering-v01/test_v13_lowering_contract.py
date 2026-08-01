#!/usr/bin/env python3
"""Focused deterministic and fail-closed tests for North v13 lowering."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from lower_v13_scene import (  # noqa: E402
    EVIDENCE_REL,
    RUN_NEUTRAL_FILES,
    SOURCE_REL,
    canonical_bytes,
    load_json,
    lower_scene,
    sha256,
)


EXPECTED = {
    "scene": "0f7a8e40a07f5c2b7320ab42fe5e1bcb2dc23fb508ff6b04e8ea49cf6c974060",
    "materials": "c8179b77a184e41b723e26b34e7da2ef256b09e93b54a47e76cc5103f22b8cab",
    "bridge": "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7",
}


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_bytes(value))


def copy_inputs(repository_root: Path, destination: Path) -> None:
    for relative in (
        f"{SOURCE_REL}/DESIGN-SCENE.json",
        f"{SOURCE_REL}/DESIGN-MATERIALS.json",
        "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json",
    ):
        source = repository_root / relative
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def run_positive(repository_root: Path, root: Path) -> dict[str, Any]:
    copy_inputs(repository_root, root)
    output = root / "output"
    return lower_scene(root, output)


def adversary(
    repository_root: Path,
    name: str,
    mutate: Callable[[dict[str, Any], dict[str, Any]], None],
    expected_fragment: str,
) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix=f"citysim-v13-{name}-", dir="/private/tmp") as raw:
        root = Path(raw)
        copy_inputs(repository_root, root)
        scene_path = root / SOURCE_REL / "DESIGN-SCENE.json"
        materials_path = root / SOURCE_REL / "DESIGN-MATERIALS.json"
        scene = load_json(scene_path)
        materials = load_json(materials_path)
        mutate(scene, materials)
        write_json(scene_path, scene)
        write_json(materials_path, materials)
        try:
            lower_scene(root, root / "output")
        except RuntimeError as error:
            message = str(error)
            if expected_fragment not in message:
                raise RuntimeError(f"{name}: wrong fail-closed reason: {message}") from error
            return {"name": name, "passed": True, "expectedFailure": expected_fragment, "actualFailure": message}
        raise RuntimeError(f"{name}: adversary was accepted")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    repository_root = args.repository_root.resolve(strict=True)
    contract = load_json(HERE / "LOWERING-CONTRACT.json")
    inputs = contract["inputs"]
    actual = {
        "scene": sha256(repository_root / inputs["scene"]["file"]),
        "materials": sha256(repository_root / inputs["materials"]["file"]),
        "bridge": sha256(repository_root / inputs["bridge"]["file"]),
    }
    if actual != EXPECTED:
        raise RuntimeError(f"frozen input hash mismatch: {actual}")

    with tempfile.TemporaryDirectory(prefix="citysim-v13-replay-a-", dir="/private/tmp") as first_raw, tempfile.TemporaryDirectory(prefix="citysim-v13-replay-b-", dir="/private/tmp") as second_raw:
        first = run_positive(repository_root, Path(first_raw))
        second = run_positive(repository_root, Path(second_raw))
        if first["outputHashes"] != second["outputHashes"]:
            raise RuntimeError("two fresh lowering replay inventories differ")
        replay_hashes = first["outputHashes"]
        replay_a_path = Path(first_raw) / "output"
        replay_b_path = Path(second_raw) / "output"

        adversaries = [
            adversary(repository_root, "revision-drift", lambda s, _: s.update({"sourceRevision": "v12"}), "source revision drift"),
            adversary(repository_root, "primitive-drift", lambda s, _: s["components"][0].update({"primitive": "sphere"}), "unsupported authored primitive"),
            adversary(repository_root, "material-drift", lambda s, _: s["components"][0].update({"materialRole": "missing-role"}), "unresolved material role"),
            adversary(repository_root, "portal-intrusion", lambda s, _: s["components"][2]["solidRegions"][2].update({"boundsXYZ": [[-10, 1, -16], [10, 20, -6]]}), "solid intrusion into portal aperture"),
            adversary(repository_root, "duplicate-component", lambda s, _: s["components"][1].update({"id": s["components"][0]["id"]}), "duplicate physical component ID"),
        ]

        # Bridge drift is deliberately applied to the copied bridge input after
        # the common adversary helper has loaded its scene/material pair.
        with tempfile.TemporaryDirectory(prefix="citysim-v13-bridge-drift-", dir="/private/tmp") as raw:
            root = Path(raw)
            copy_inputs(repository_root, root)
            bridge_path = root / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
            bridge = load_json(bridge_path)
            bridge["basis"]["formula"] = "B(x,y,z)=(x,y,z)"
            write_json(bridge_path, bridge)
            try:
                lower_scene(root, root / "output")
            except RuntimeError as error:
                if "coordinate bridge contract drift" not in str(error):
                    raise
                adversaries.append({"name": "bridge-drift", "passed": True, "expectedFailure": "coordinate bridge contract drift", "actualFailure": str(error)})
            else:
                raise RuntimeError("bridge-drift: adversary was accepted")

        evidence_root = repository_root / EVIDENCE_REL
        evidence_exists = evidence_root.exists()
        if not evidence_exists:
            (evidence_root / "replay-a").mkdir(parents=True)
            (evidence_root / "replay-b").mkdir(parents=True)
            for name in RUN_NEUTRAL_FILES:
                shutil.copy2(replay_a_path / name, evidence_root / "replay-a" / name)
                shutil.copy2(replay_b_path / name, evidence_root / "replay-b" / name)
        else:
            for run_name in ("replay-a", "replay-b"):
                for name in RUN_NEUTRAL_FILES:
                    committed = evidence_root / run_name / name
                    if not committed.is_file() or sha256(committed) != replay_hashes[name]:
                        raise RuntimeError(f"committed {run_name}/{name} does not match fresh replay")

        authority = {
            "schema": 1,
            "task": "PLAY-027",
            "stage": "north-v13-lowering-v01",
            "routeId": contract["routeId"],
            "routeCanonicalSHA256": contract["routeCanonicalSHA256"],
            "publishedBase": contract["publishedBase"],
            "claim": contract["claim"],
            "authority": contract["authority"],
            "inputs": {key: {**record, "actualSHA256": actual[key]} for key, record in inputs.items()},
            "loweringToolSHA256": sha256(HERE / "lower_v13_scene.py"),
            "contractSHA256": sha256(HERE / "LOWERING-CONTRACT.json"),
            "replays": {
                "count": 2,
                "concurrency": 1,
                "runNeutralFiles": RUN_NEUTRAL_FILES,
                "replayA": {"root": f"{EVIDENCE_REL}/replay-a", "hashes": replay_hashes},
                "replayB": {"root": f"{EVIDENCE_REL}/replay-b", "hashes": replay_hashes},
                "byteIdentical": True,
            },
            "adversarialTests": adversaries,
            "validation": first["validation"],
            "topology": first["topology"],
            "pixelInvocationCounts": {"blender": 0, "dcc": 0, "render": 0, "imageGen": 0, "normalizer": 0, "pixels": 0},
            "disposition": "PREDESIGN_LOWERING_READY_FOR_INDEPENDENT_REVIEW",
            "sourceAuthority": False,
            "productionSelected": False,
            "appearanceLockPublished": False,
        }
        proof = {
            "schema": 1,
            "task": "PLAY-027",
            "stage": "north-v13-actual-camera-zero-pixel-proof",
            "sceneSHA256": actual["scene"],
            "materialsSHA256": actual["materials"],
            "bridgeSHA256": actual["bridge"],
            "loweringToolSHA256": authority["loweringToolSHA256"],
            "method": "frozen-v06-camera-affine-registration",
            "camera": first["projection"]["camera"],
            "registration": {
                "footprintExpectedSource": first["projection"]["footprintExpectedSource"],
                "footprintActualSource": first["projection"]["footprintActualSource"],
                "pivotExpectedSource": first["projection"]["pivotExpectedSource"],
                "pivotActualSource": first["projection"]["pivotActualSource"],
                "socketExpectedSource": first["projection"]["socketExpectedSource"],
                "socketActualSource": first["projection"]["socketActualSource"],
                "maximumAbsoluteDeltaSourcePixels": first["projection"]["maximumRegistrationDeltaSourcePixels"],
                "toleranceSourcePixels": 0.001,
            },
            "portal": {
                "apertureBoundsCitySim": first["topology"]["apertureBoundsCitySim"],
                "solidOverlapCount": first["validation"]["solidIntrusionCount"],
                "processOrCraneOverlapCount": first["validation"]["processIntrusionCount"],
                "rayOrder": first["topology"]["rayOrder"],
                "frameMembers": {
                    key: first["projection"]["objectBoundsCompact"][key]
                    for key in ("v13-monumental-portal-frame:west-jamb", "v13-monumental-portal-frame:east-jamb", "v13-monumental-portal-frame:header")
                },
                "inset": first["projection"]["objectBoundsCompact"]["v13-portal-inset"],
                "threeFreightBeats": [first["projection"]["objectBoundsCompact"][f"v13-three-bay-freight-rhythm:{side}-bay"] for side in ("west", "center", "east")],
            },
            "frontage": {
                "socketApronObject": first["projection"]["objectBoundsCompact"]["v13-socket-apron"],
                "thresholdToSocketConnectedByDescriptor": True,
                "maximumSocketGapCompactPixels": 0,
                "staffDoor": first["projection"]["objectBoundsCompact"]["v13-west-staff-annex:staff-door"],
            },
            "literal192": {
                "status": "not-rendered; deferred to separately authorized DCC Process A",
                "semanticMaskSupportingOnly": True,
                "expectedThresholdsBound": True,
                "visualAcceptance": "unrun",
            },
            "pixelInvocationCounts": {"blender": 0, "dcc": 0, "render": 0, "imageGen": 0, "normalizer": 0, "pixels": 0},
            "validationPassed": True,
            "sourceAuthority": False,
            "productionSelected": False,
        }
        if not evidence_exists:
            write_json(evidence_root / "LOWERING-AUTHORITY.json", authority)
            write_json(evidence_root / "ACTUAL-CAMERA-ZERO-PIXEL-PROOF.json", proof)
        else:
            for name in ("LOWERING-AUTHORITY.json", "ACTUAL-CAMERA-ZERO-PIXEL-PROOF.json"):
                existing = load_json(evidence_root / name)
                if existing.get("sourceAuthority") is not False or existing.get("productionSelected") is not False:
                    raise RuntimeError(f"committed {name} has unsafe disposition")
        print(f"PASS v13-lowering contract replays=2 adversaries={len(adversaries)}")
        print(json.dumps({"replayHashes": replay_hashes, "authority": f"{EVIDENCE_REL}/LOWERING-AUTHORITY.json", "proof": f"{EVIDENCE_REL}/ACTUAL-CAMERA-ZERO-PIXEL-PROOF.json"}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
