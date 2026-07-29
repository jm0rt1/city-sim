#!/usr/bin/env python3
"""Assemble the two sequential PLAY-027 North v10 analytic replays."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
from pathlib import Path
from typing import Any


AUTHORITY_COMMIT = "9e5b4a59f7346cd89e7b9e9cd3bbc65643d66a24"
AUTHORITY_SHA = "9422a068cd6f6c136758442a31b2e44040940f1259dd37cd46368aaba036c016"
REJECTED_PARENT = "4255b021f743281b60cfdf8cff896235d405be23"
SOURCE_REL = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v10"
)
EVIDENCE_REL = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v10"
)
REPLAY_FILES = [
    "EXACT-192-COLOR.png",
    "EXACT-192-GRAYSCALE.png",
    "EXACT-192-SEMANTIC.png",
    "FIELD-DIFF.json",
    "MATERIALS.json",
    "SCENE.json",
    "V08-V09-V10-COMPARISON.png",
    "VALIDATION.json",
]
SOURCE_FILES = [
    "MATERIALS.json",
    "SCENE.json",
    "assemble_zero_pixel.py",
    "build_zero_pixel.py",
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
        if stat.S_ISLNK(os.lstat(current).st_mode):
            raise RuntimeError(f"symlink path component forbidden: {current}")


def inventory(root: Path, names: list[str]) -> dict[str, str]:
    actual_names = sorted(path.name for path in root.iterdir())
    if actual_names != sorted(names):
        raise RuntimeError(
            f"inventory drift at {root}: expected {sorted(names)}, got {actual_names}"
        )
    result = {}
    for name in sorted(names):
        path = root / name
        assert_no_symlink_chain(path)
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

    repository = args.repository_root.absolute()
    if repository.resolve() != repository:
        raise RuntimeError("repository root must be canonical")
    source_root = repository / SOURCE_REL
    evidence_root = repository / EVIDENCE_REL
    run_a = evidence_root / "replay-a"
    run_b = evidence_root / "replay-b"
    for path in (repository, source_root, evidence_root, run_a, run_b):
        assert_no_symlink_chain(path)
    if not evidence_root.is_dir() or evidence_root.is_symlink():
        raise RuntimeError("exact evidence root required")
    root_names = sorted(path.name for path in evidence_root.iterdir())
    if root_names != ["replay-a", "replay-b"]:
        raise RuntimeError(f"pre-assembly evidence root drift: {root_names}")

    source_inventory = inventory(source_root, SOURCE_FILES)
    inventory_a = inventory(run_a, REPLAY_FILES)
    inventory_b = inventory(run_b, REPLAY_FILES)
    equality = {
        name: inventory_a[name] == inventory_b[name]
        for name in REPLAY_FILES
    }
    if not all(equality.values()):
        raise RuntimeError("analytic replay inventory mismatch")
    validation_a = load_json(run_a / "VALIDATION.json")
    validation_b = load_json(run_b / "VALIDATION.json")
    if not validation_a["validationPassed"] or not validation_b["validationPassed"]:
        raise RuntimeError("cannot assemble failed v10 hypothesis")
    comparison = dict(validation_b)
    comparison["replayID"] = "a"
    if validation_a != comparison:
        raise RuntimeError("validation content drift beyond replay identity")

    combined_wall = args.run_a_wall_seconds + args.run_b_wall_seconds
    peak_rss = max(
        args.run_a_peak_rss_bytes,
        args.run_b_peak_rss_bytes,
    )
    if combined_wall > 120.0:
        raise RuntimeError(f"combined 120-second envelope exceeded: {combined_wall}")
    if peak_rss > 512 * 1024 * 1024:
        raise RuntimeError(f"512 MiB memory envelope exceeded: {peak_rss}")

    receipt = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v10-zero-pixel",
        "authorityCommit": AUTHORITY_COMMIT,
        "authorityFileSHA256": AUTHORITY_SHA,
        "rejectedParent": REJECTED_PARENT,
        "replayCount": 2,
        "freshSequentialProcessCount": 2,
        "maximumConcurrency": 1,
        "processOrder": ["replay-a", "replay-b"],
        "runA": inventory_a,
        "runB": inventory_b,
        "perFileEquality": equality,
        "aggregateEquality": inventory_a == inventory_b,
        "sourceInventory": source_inventory,
        "commands": [
            (
                "python3 build_zero_pixel.py --repository-root "
                f"{repository} --output-root {run_a} --replay-id a"
            ),
            (
                "python3 build_zero_pixel.py --repository-root "
                f"{repository} --output-root {run_b} --replay-id b"
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
        "analyticOnly": True,
        "analyticEmissionConsumed": False,
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
        "productionSelected": False,
    }
    handoff = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "predesign",
        "family": "industrial",
        "level": 4,
        "direction": "north",
        "sourceRevision": "blender-art-v10-prepixel",
        "sceneGeometryID": "industrial-l04-north-v10-local-portal-repair",
        "authorityCommit": AUTHORITY_COMMIT,
        "rejectedParent": REJECTED_PARENT,
        "sceneSHA256": inventory_a["SCENE.json"],
        "materialsSHA256": inventory_a["MATERIALS.json"],
        "builderSHA256": source_inventory["build_zero_pixel.py"],
        "assemblerSHA256": source_inventory["assemble_zero_pixel.py"],
        "validationSHA256": inventory_a["VALIDATION.json"],
        "fieldDiffSHA256": inventory_a["FIELD-DIFF.json"],
        "coordinateBridgeSHA256": (
            "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
        ),
        "pivotSource": [768, 896],
        "socketSource": [896, 704],
        "pixelProduction": "not_produced",
        "processes": {
            "A": "not_produced",
            "B": "not_produced",
            "C": "not_produced",
        },
        "analyticEmissionConsumed": False,
        "cyclesLumaProof": "PENDING_ACTUAL_PROCESS_A",
        "validationPassed": True,
        "candidateReadyForIndependentPrepixelReview": True,
        "reviewPaths": [
            f"replay-a/{name}" for name in REPLAY_FILES
        ],
        "replayIdentity": "REPLAY-IDENTITY.json",
        "disposition": "PENDING_INDEPENDENT_ZERO_PIXEL_REVIEW",
        "sourceAuthority": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }
    write_json(evidence_root / "REPLAY-IDENTITY.json", receipt)
    write_json(evidence_root / "HANDOFF.json", handoff)
    final_names = sorted(path.name for path in evidence_root.iterdir())
    if final_names != [
        "HANDOFF.json",
        "REPLAY-IDENTITY.json",
        "replay-a",
        "replay-b",
    ]:
        raise RuntimeError(f"final evidence root drift: {final_names}")


if __name__ == "__main__":
    main()
