#!/usr/bin/env python3
"""Assemble two identical sequential PLAY-027 North v12 analytic replays."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from sealed_io import SealedDirectory, reject_symlink_or_missing_chain


AUTHORITY_COMMIT = "1bdf858181f720a0d30aacf142a219c79a3425f9"
AUTHORITY_SHA = "9fe208800078421303165087cbc0cd638bf870a8c0434e3ef374df1220c621fc"
CLAIM_SHA = "21885dc5de1ab89f0d9316c564bc0dab06f136924aac396f9743ebdb3b2004fe"
FROZEN_HEAD = "10df430ca1f6c0f26eb2082766791c39f9a18eab"
SOURCE_REL = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12"
)
EVIDENCE_REL = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12"
)
REPLAY_FILES = [
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
SOURCE_FILES = [
    "MATERIALS.json",
    "PORTABILITY.json",
    "SCENE.json",
    "assemble_zero_pixel.py",
    "build_zero_pixel.py",
    "frozen-inputs/MANIFEST.json",
    "frozen-inputs/analytic/build_prepixel.py",
    "frozen-inputs/v11/EXACT-192-COLOR.png",
    "frozen-inputs/v11/MATERIALS.json",
    "frozen-inputs/v11/SCENE.json",
    "sealed_io.py",
    "validate_portability.py",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def inventory(root: Path, names: list[str]) -> dict[str, str]:
    actual = sorted(
        str(path.relative_to(root))
        for path in root.rglob("*")
        if path.is_file()
    )
    if actual != sorted(names):
        raise RuntimeError(f"inventory drift at {root}: {actual}")
    result = {}
    for name in sorted(names):
        path = root / name
        reject_symlink_or_missing_chain(path.parent)
        if not path.is_file() or path.is_symlink():
            raise RuntimeError(f"regular file required: {path}")
        result[name] = sha256(path)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--run-a-wall-seconds", type=float, required=True)
    parser.add_argument("--run-b-wall-seconds", type=float, required=True)
    parser.add_argument("--run-a-peak-rss-bytes", type=int, required=True)
    parser.add_argument("--run-b-peak-rss-bytes", type=int, required=True)
    args = parser.parse_args()

    repository = args.repository_root
    if not repository.is_absolute() or repository.resolve() != repository:
        raise RuntimeError("repository root must be canonical")
    source_root = repository / SOURCE_REL
    evidence_root = repository / EVIDENCE_REL
    replay_a = evidence_root / "replay-a"
    replay_b = evidence_root / "replay-b"
    for path in (repository, source_root, evidence_root, replay_a, replay_b):
        reject_symlink_or_missing_chain(path)
    if sorted(path.name for path in evidence_root.iterdir()) != ["replay-a", "replay-b"]:
        raise RuntimeError("pre-assembly evidence root inventory drift")

    source_inventory = inventory(source_root, SOURCE_FILES)
    inventory_a = inventory(replay_a, REPLAY_FILES)
    inventory_b = inventory(replay_b, REPLAY_FILES)
    equality = {
        name: inventory_a[name] == inventory_b[name]
        for name in REPLAY_FILES
    }
    if not all(equality.values()) or inventory_a != inventory_b:
        raise RuntimeError("complete analytic replay inventory mismatch")
    validation_a = load_json(replay_a / "VALIDATION.json")
    validation_b = load_json(replay_b / "VALIDATION.json")
    if validation_a != validation_b:
        raise RuntimeError("validation content mismatch")
    if not validation_a["validationPassed"]:
        raise RuntimeError("cannot assemble failed v12 validation")

    combined_wall = args.run_a_wall_seconds + args.run_b_wall_seconds
    peak_rss = max(args.run_a_peak_rss_bytes, args.run_b_peak_rss_bytes)
    if combined_wall > 120.0:
        raise RuntimeError(f"combined wall envelope exceeded: {combined_wall}")
    if peak_rss > 512 * 1024 * 1024:
        raise RuntimeError(f"memory envelope exceeded: {peak_rss}")

    receipt = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v12-zero-pixel-replay-identity",
        "authorityCommit": AUTHORITY_COMMIT,
        "authorityFileSHA256": AUTHORITY_SHA,
        "claimSHA256": CLAIM_SHA,
        "frozenHead": FROZEN_HEAD,
        "replayCount": 2,
        "freshSequentialProcessCount": 2,
        "maximumConcurrency": 1,
        "processOrder": ["replay-a", "replay-b"],
        "runA": inventory_a,
        "runB": inventory_b,
        "perFileEquality": equality,
        "aggregateEquality": True,
        "sourceInventory": source_inventory,
        "commands": [
            (
                "/usr/bin/time -lp python3 -B "
                f"{source_root / 'build_zero_pixel.py'} "
                f"--repository-root {repository} "
                f"--output-root {replay_a} --replay-id a"
            ),
            (
                "/usr/bin/time -lp python3 -B "
                f"{source_root / 'build_zero_pixel.py'} "
                f"--repository-root {repository} "
                f"--output-root {replay_b} --replay-id b"
            ),
        ],
        "observedEnvelope": {
            "runAWallSeconds": args.run_a_wall_seconds,
            "runBWallSeconds": args.run_b_wall_seconds,
            "combinedWallSeconds": combined_wall,
            "runAPeakRSSBytes": args.run_a_peak_rss_bytes,
            "runBPeakRSSBytes": args.run_b_peak_rss_bytes,
            "peakRSSBytes": peak_rss,
            "hardWallSeconds": 120,
            "hardPeakMemoryBytes": 512 * 1024 * 1024,
            "passed": True,
        },
        "processCounts": {
            "analytic": 2,
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
    handoff = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v12-zero-pixel",
        "direction": "north",
        "sourceRevision": "blender-art-v12-prepixel",
        "sceneGeometryID": "industrial-l04-north-v12-compound-west-pier",
        "authorityCommit": AUTHORITY_COMMIT,
        "frozenHead": FROZEN_HEAD,
        "sceneSHA256": inventory_a["SCENE.json"],
        "materialsSHA256": inventory_a["MATERIALS.json"],
        "builderSHA256": source_inventory["build_zero_pixel.py"],
        "assemblerSHA256": source_inventory["assemble_zero_pixel.py"],
        "validationSHA256": inventory_a["VALIDATION.json"],
        "componentOwnersSHA256": inventory_a["COMPONENT-OWNERS.json"],
        "physicalBoundariesSHA256": inventory_a["PHYSICAL-BOUNDARIES.json"],
        "coordinateBridgeSHA256": "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7",
        "pixelProduction": "not_produced",
        "processes": {"A": "not_produced", "B": "not_produced", "C": "not_produced"},
        "validationPassed": True,
        "candidateReadyForIndependentReview": False,
        "disposition": "PENDING_INDEPENDENT_ZERO_PIXEL_REVIEW",
        "sourceAuthority": False,
        "integrationAdmitted": False,
        "productionSelected": False,
    }
    sealed = SealedDirectory(
        evidence_root,
        {"HANDOFF.json", "REPLAY-IDENTITY.json"},
    )
    sealed.write_json("REPLAY-IDENTITY.json", receipt)
    sealed.write_json("HANDOFF.json", handoff)
    if sorted(path.name for path in evidence_root.iterdir()) != [
        "HANDOFF.json",
        "REPLAY-IDENTITY.json",
        "replay-a",
        "replay-b",
    ]:
        raise RuntimeError("final evidence root inventory drift")


if __name__ == "__main__":
    main()
