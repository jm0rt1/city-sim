#!/usr/bin/env python3
"""Validate the PLAY-081 pre-lock handoff and zero-pixel boundary."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import jsonschema


SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01"
)
EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01"
)
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument(
        "--contract", default=f"{SOURCE_ROOT}/RUNNER-CONTRACT.json"
    )
    parser.add_argument(
        "--schema",
        default=(
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-prelock-runner-handoff-schema-v1.json"
        ),
    )
    parser.add_argument(
        "--handoff",
        default=f"{EVIDENCE_ROOT}/PRELOCK-RUNNER-HANDOFF.json",
    )
    return parser.parse_args()


def repository_path(root: Path, relative: str) -> Path:
    resolved = (root / relative).resolve()
    resolved.relative_to(root)
    return resolved


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract_path = repository_path(root, args.contract)
    schema_path = repository_path(root, args.schema)
    handoff_path = repository_path(root, args.handoff)
    contract = load_json(contract_path)
    handoff = load_json(handoff_path)
    schema = load_json(schema_path)
    failures: list[str] = []

    if (
        contract.get("handoffSchema", {}).get("path") != args.schema
        or contract.get("handoffSchema", {}).get("sha256")
        != sha256(schema_path)
    ):
        failures.append("integration-schema-binding")

    try:
        jsonschema.Draft202012Validator(schema).validate(handoff)
    except jsonschema.ValidationError as error:
        failures.append(f"schema:{error.json_path}:{error.message}")

    if handoff["runner"]["contractSha256"] != sha256(contract_path):
        failures.append("runner-contract-sha256")
    driver_path = repository_path(root, handoff["runner"]["driverPath"])
    if (
        not driver_path.is_file()
        or handoff["runner"]["driverSha256"] != sha256(driver_path)
    ):
        failures.append("runner-driver-sha256")
    for relative, expected in handoff["runner"]["validatorHashes"].items():
        path = repository_path(root, f"{SOURCE_ROOT}/{relative}")
        if not path.is_file() or sha256(path) != expected:
            failures.append(f"validator-sha256:{relative}")
    if handoff["acceptedPredesign"]["handoffSha256"] != contract[
        "acceptedPredesign"
    ]["handoff"]["sha256"]:
        failures.append("accepted-predesign-handoff-sha256")
    expected_input_hashes = {
        "scene": contract["acceptedPredesign"]["scene"]["sha256"],
        "materials": contract["acceptedPredesign"]["materials"]["sha256"],
        "validator": contract["acceptedPredesign"]["validator"]["sha256"],
        "actualCameraProofScript": contract["acceptedPredesign"][
            "actualCameraProofScript"
        ]["sha256"],
        "staticProof": contract["acceptedPredesign"]["staticProof"]["sha256"],
        "actualCameraProof": contract["acceptedPredesign"]["actualCameraProof"][
            "sha256"
        ],
        "repeatIdentity": contract["acceptedPredesign"]["repeatIdentity"][
            "sha256"
        ],
    }
    if handoff["acceptedPredesign"]["inputHashes"] != expected_input_hashes:
        failures.append("accepted-predesign-input-hashes")
    if handoff["runner"]["sourceRoot"] != f"{SOURCE_ROOT}/":
        failures.append("source-root")
    if handoff["runner"]["evidenceRoot"] != f"{EVIDENCE_ROOT}/":
        failures.append("evidence-root")

    evidence_reports = {
        "runner-static": repository_path(
            root, f"{EVIDENCE_ROOT}/RUNNER-STATIC-VALIDATION.json"
        ),
        "missing-lock": repository_path(
            root, f"{EVIDENCE_ROOT}/MISSING-LOCK-REJECTION.json"
        ),
        "wrong-lock": repository_path(
            root, f"{EVIDENCE_ROOT}/WRONG-LOCK-REJECTION.json"
        ),
        "repeat-identity": repository_path(
            root, f"{EVIDENCE_ROOT}/RUNNER-REPEAT-IDENTITY.json"
        ),
        "coordinate-bridge-blocker": repository_path(
            root, f"{EVIDENCE_ROOT}/COORDINATE-BRIDGE-BLOCKER.json"
        ),
        "bridge-actual-camera-run-a": repository_path(
            root, f"{EVIDENCE_ROOT}/BRIDGE-ACTUAL-CAMERA-RUN-A.json"
        ),
        "bridge-actual-camera-run-b": repository_path(
            root, f"{EVIDENCE_ROOT}/BRIDGE-ACTUAL-CAMERA-RUN-B.json"
        ),
        "bridge-repeat-identity": repository_path(
            root, f"{EVIDENCE_ROOT}/BRIDGE-REPEAT-IDENTITY.json"
        ),
    }
    for name, path in evidence_reports.items():
        if not path.is_file() or load_json(path).get("passed") is not True:
            failures.append(f"evidence-report:{name}")
    blocker = load_json(evidence_reports["coordinate-bridge-blocker"])
    blocker_canonical = blocker.get("canonicalCitySim", {})
    if (
        blocker.get("disposition")
        != "V06_BRIDGE_ADOPTED_APPEARANCE_LOCK_PENDING"
        or blocker.get("holdIsStop") is not False
        or blocker_canonical.get("frontageSocketWorldXYZ") != [-28, 0, 0]
        or blocker_canonical.get("frontageSocketExpectedSource") != [640, 704]
        or blocker_canonical.get("blenderNativeDirectionalSocket")
        != [0, -28, 0]
        or blocker.get("sourceReady") is not False
    ):
        failures.append("coordinate-bridge-blocker-content")

    pixel_files: list[str] = []
    generated_cache: list[str] = []
    for relative in (SOURCE_ROOT, EVIDENCE_ROOT):
        directory = repository_path(root, relative)
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES:
                pixel_files.append(str(path.relative_to(root)))
            if "__pycache__" in path.parts:
                generated_cache.append(str(path.relative_to(root)))
    if pixel_files:
        failures.append("pixel-files-present")
    if generated_cache:
        failures.append("generated-python-cache-present")

    expected_zero = {
        "blenderProcessLaunches",
        "blenderRenderApiCalls",
        "imageGenInvocations",
        "normalizerInvocations",
        "contactSheetInvocations",
    }
    if any(handoff["guardEvidence"][key] != 0 for key in expected_zero):
        failures.append("guard-invocation-counts")
    if handoff["renderInvocations"] != 0 or handoff["pixelFiles"] != 0:
        failures.append("render-or-pixel-count")
    if any(
        handoff["validation"][key] != "not_run"
        for key in ("rgba", "literal192", "abcIdentity", "normalization")
    ):
        failures.append("pixel-validation-state")
    bridge = contract.get("coordinateBridge", {})
    canonical = bridge.get("canonicalCitySim", {})
    bridge_v06 = bridge.get("v06", {})
    if (
        bridge.get("state") != "validated_v06"
        or bridge.get("holdIsStop") is not False
        or canonical.get("frontageSocketWorldXYZ") != [-28, 0, 0]
        or canonical.get("frontageSocketExpectedSource") != [640, 704]
        or bridge_v06.get("authorityCommit")
        != "3e01ca6738d7574718f9aeff4b66771eee109feb"
        or bridge_v06.get("mappingContractSha256")
        != "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
        or bridge_v06.get("frontageSocketCitySimXYZ") != [-28, 0, 0]
        or bridge_v06.get("frontageSocketBlenderXYZ") != [0, -28, 0]
        or bridge_v06.get("frontageSocketSourceXY") != [640, 704]
        or bridge_v06.get("sourceOrder") != [0, 1, 2, 3]
        or bridge_v06.get("perDirectionTransform") is not False
        or bridge_v06.get("windingChange") is not False
    ):
        failures.append("coordinate-bridge-adoption")
    if handoff["state"] != "prelock_runner_ready" or handoff["sourceReady"] is not False:
        failures.append("handoff-runner-readiness-boundary")

    result = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "schemaSha256": sha256(schema_path),
        "handoffSha256": sha256(handoff_path),
        "acceptedBridgeCandidate": bridge_v06.get("authorityCommit"),
        "mappingContractSha256": bridge_v06.get("mappingContractSha256"),
        "blenderProjectionProcessLaunches": 2,
        "blenderRenderApiCalls": 0,
        "renderInvocations": 0,
        "pixelFiles": sorted(pixel_files),
        "generatedCaches": sorted(generated_cache),
        "failures": failures,
        "passed": not failures,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
