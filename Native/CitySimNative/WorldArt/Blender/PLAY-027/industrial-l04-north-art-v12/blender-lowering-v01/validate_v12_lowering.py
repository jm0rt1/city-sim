#!/usr/bin/env python3
"""Run one sealed pure-data PLAY-027 North v12 lowering replay."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from lower_v12_scene import (
    RUN_NEUTRAL_FILES,
    canonical_bytes,
    ensure_absent_output_root,
    exclusive_write_json,
    load_json,
    lower_scene,
    sha256,
)

STATIC_CHILD_FILES = [
    "BLENDER-OBJECT-MANIFEST.json",
    "MATERIAL-MANIFEST.json",
    "PROJECTION.json",
    "TOPOLOGY.json",
    "INPUT-BINDINGS.json",
    "VALIDATION.json",
]


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--run", choices=("pure-a", "pure-b"))
    action.add_argument("--finalize", action="store_true")
    return parser.parse_args()


def inventory(root: Path, names: list[str]) -> dict[str, str]:
    if root.is_symlink() or not root.is_dir():
        raise RuntimeError(f"sealed evidence root required: {root}")
    actual_names = sorted(path.name for path in root.iterdir() if path.is_file())
    allowed = sorted(
        names + (["PROCESS-PROVENANCE.json"] if root.name.startswith("static-") else [])
    )
    if actual_names != allowed:
        raise RuntimeError(
            f"sealed evidence inventory drift: {root}: {actual_names}"
        )
    return {name: sha256(root / name) for name in names}


def write_top_level(root: Path, name: str, value: object) -> None:
    if name not in ("REPLAY-IDENTITY.json", "DISPOSITION.json"):
        raise RuntimeError("unapproved final evidence output")
    path = root / name
    if path.exists() or path.is_symlink():
        raise RuntimeError(f"final evidence output must be absent: {path}")
    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
        0o644,
    )
    try:
        os.write(descriptor, canonical_bytes(value))
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def finalize(repository_root: Path, contract: dict[str, object]) -> None:
    evidence_root = repository_root / str(contract["evidenceRoot"])
    pure_a = inventory(evidence_root / "pure-a", RUN_NEUTRAL_FILES)
    pure_b = inventory(evidence_root / "pure-b", RUN_NEUTRAL_FILES)
    static_a = inventory(evidence_root / "static-a", STATIC_CHILD_FILES)
    static_b = inventory(evidence_root / "static-b", STATIC_CHILD_FILES)
    if pure_a != pure_b:
        raise RuntimeError("pure replay identity failure")
    if static_a != static_b:
        raise RuntimeError("static replay identity failure")
    provenance = {
        run: load_json(
            evidence_root / run / "PROCESS-PROVENANCE.json"
        )
        for run in ("static-a", "static-b")
    }
    if any(
        item["renderInvocationCount"] != 0
        or item["pixelFiles"]
        or item["blendFiles"]
        for item in provenance.values()
    ):
        raise RuntimeError("static process provenance drift")
    adversarial = load_json(evidence_root / "ADVERSARIAL-RESULTS.json")
    if not adversarial["allAdversariesRejected"]:
        raise RuntimeError("adversarial gate failed")
    replay = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": contract["stage"],
        "pureReplayCount": 2,
        "pureRunNeutralFileCount": len(RUN_NEUTRAL_FILES),
        "pureAInventory": pure_a,
        "pureBInventory": pure_b,
        "pureInventoriesByteIdentical": True,
        "staticReplayCount": 2,
        "staticRunNeutralFileCount": len(STATIC_CHILD_FILES),
        "staticAInventory": static_a,
        "staticBInventory": static_b,
        "staticInventoriesByteIdentical": True,
        "staticProcessProvenanceSHA256": {
            run: sha256(
                evidence_root / run / "PROCESS-PROVENANCE.json"
            )
            for run in ("static-a", "static-b")
        },
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "blendFiles": [],
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    disposition = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": contract["stage"],
        "disposition": "PASS_STATIC_LOWERING_FOR_INDEPENDENT_REVIEW",
        "canonicalLoweringPassed": True,
        "pureReplayIdentityPassed": True,
        "adversarialGatePassed": True,
        "staticReplayIdentityPassed": True,
        "staticProcessCount": 2,
        "maximumStaticConcurrency": 1,
        "renderInvocationCount": 0,
        "rawProcessCount": 0,
        "normalizerProcessCount": 0,
        "pixelFiles": [],
        "blendFiles": [],
        "appearanceReviewed": False,
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
        "nextGate": "independent Integration review; no Process A authority",
    }
    write_top_level(evidence_root, "REPLAY-IDENTITY.json", replay)
    write_top_level(evidence_root, "DISPOSITION.json", disposition)
    print(json.dumps({
        "disposition": disposition["disposition"],
        "pureInventoriesByteIdentical": True,
        "staticInventoriesByteIdentical": True,
        "replayIdentitySHA256": sha256(
            evidence_root / "REPLAY-IDENTITY.json"
        ),
        "dispositionSHA256": sha256(
            evidence_root / "DISPOSITION.json"
        ),
    }, sort_keys=True))


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    contract_path = Path(options.contract).resolve(strict=True)
    expected_contract = (
        repository_root
        / "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
        "industrial-l04-north-art-v12/blender-lowering-v01/"
        "LOWERING-CONTRACT.json"
    ).resolve(strict=True)
    if contract_path != expected_contract:
        raise RuntimeError("exact task-local lowering contract required")
    contract = load_json(contract_path)
    if options.finalize:
        finalize(repository_root, contract)
        return
    evidence_root = repository_root / contract["evidenceRoot"]
    if evidence_root.is_symlink():
        raise RuntimeError("symlink evidence root rejected")
    if not evidence_root.exists():
        evidence_root.mkdir(mode=0o755)
    if not evidence_root.is_dir():
        raise RuntimeError("regular task evidence root required")
    evidence_root.resolve().relative_to(repository_root)
    output_root = evidence_root / options.run
    ensure_absent_output_root(output_root)
    outputs = lower_scene(repository_root, contract)
    if set(outputs) != set(RUN_NEUTRAL_FILES):
        raise RuntimeError("pure output inventory drift")
    for name in RUN_NEUTRAL_FILES:
        exclusive_write_json(output_root, name, outputs[name])
    inventory = {
        name: sha256(output_root / name)
        for name in RUN_NEUTRAL_FILES
    }
    print(json.dumps({
        "run": options.run,
        "files": len(inventory),
        "inventory": inventory,
        "validationPassed": True,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
