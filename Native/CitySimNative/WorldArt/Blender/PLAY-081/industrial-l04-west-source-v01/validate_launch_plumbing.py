#!/usr/bin/env python3
"""Validate PLAY-081 launch plumbing with zero-pixel dry fixtures."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

from post_source_pipeline import preflight as post_source_preflight
from prepare_launch_bound import (
    DEFAULT_CONTRACT,
    EVIDENCE_ROOT,
    SOURCE_ROOT,
    assemble,
    build_packet,
)
from run_west_source import evaluate_render_guard
from west_launch_authority import (
    SOURCE_SCHEMA_PATH,
    SOURCE_SCHEMA_SHA256,
    load_json,
    repository_path,
    sha256,
    validate_future_authorities,
    validate_output_root_isolation,
)


PUBLISHED_MERGE = "662bc89d0ad8d1856aabd4a37c9b24b57e34f32b"
APPROVED_CANDIDATE = "135805d9b092d44ea28ff8421cbc70bddd1ac38a"
FIXTURE_ROOT = f"{EVIDENCE_ROOT}/dry-fixtures"
DEFAULT_OUTPUT = f"{EVIDENCE_ROOT}/PRELOCK-LAUNCH-PLUMBING-VALIDATION.json"
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    return parser.parse_args()


def git_output(root: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def is_ancestor(root: Path, older: str, newer: str = "HEAD") -> bool:
    return (
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", older, newer],
            cwd=root,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def fixture_binding(
    root: Path,
    filename: str,
    *,
    appearance: bool = False,
) -> dict[str, Any]:
    relative = f"{FIXTURE_ROOT}/{filename}"
    value: dict[str, Any] = {
        "path": relative,
        "commit": PUBLISHED_MERGE,
        "sha256": sha256(repository_path(root, relative)),
    }
    if appearance:
        document = load_json(repository_path(root, relative))
        authority = document["appearanceLockBinding"]
        value = {
            "documentPath": relative,
            "commit": authority["commit"],
            "documentSha256": value["sha256"],
            "northProcessASourceSha256": authority[
                "northProcessASourceSha256"
            ],
            "northProcessADecodedRgbaSha256": authority[
                "northProcessADecodedRgbaSha256"
            ],
        }
    return value


def fixture_contract(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(contract)
    appearance = fixture_binding(
        root,
        "APPEARANCE-LOCK.json",
        appearance=True,
    )
    material = fixture_binding(root, "LOCKED-MATERIALS.json")
    material["requiredSchema"] = copy.deepcopy(
        contract["lockedMaterialMapping"]["requiredSchema"]
    )
    profile = fixture_binding(root, "SOURCE-PRODUCTION-PROFILE.json")
    profile["state"] = "bound_integration_profile"
    value["futureProductionAuthority"]["state"] = "bound"
    value["futureProductionAuthority"]["originMasterCommit"] = PUBLISHED_MERGE
    value["appearanceLock"] = appearance
    value["appearanceLockCommit"] = appearance["commit"]
    value["appearanceLockSha256"] = appearance["documentSha256"]
    value["lockedMaterialMapping"] = material
    value["sourceStage"]["sourceProductionProfile"] = profile
    value["sourceStage"]["state"] = "fixture_bound_not_production"
    value["state"] = "ready_for_source_render"
    return value


def artifact(root: Path, relative: str) -> dict[str, str]:
    path = repository_path(root, relative)
    return {"path": relative, "sha256": sha256(path)}


def semantic_dry_rejection(
    root: Path,
    packet: dict[str, Any],
) -> dict[str, Any]:
    validator = (
        "Native/CitySimNative/WorldArt/Shared/"
        "validate_source_stage_handoff_v2.py"
    )
    with tempfile.TemporaryDirectory(prefix="play081-launch-bound-dry-") as temp:
        path = Path(temp) / "LAUNCH-BOUND-DRY-FIXTURE.json"
        path.write_text(json.dumps(packet, indent=2, sort_keys=True) + "\n")
        result = subprocess.run(
            [
                "python3",
                "-B",
                validator,
                str(path),
                "--repo-root",
                str(root),
                "--schema",
                SOURCE_SCHEMA_PATH,
                "--expected-schema-sha256",
                SOURCE_SCHEMA_SHA256,
            ],
            cwd=root,
            check=False,
            capture_output=True,
            text=True,
        )
    output = result.stdout.strip()
    parsed = json.loads(output) if output else {}
    return {
        "returnCode": result.returncode,
        "result": parsed,
        "rejected": result.returncode != 0 and parsed.get("result") == "FAIL",
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract = load_json(repository_path(root, args.contract))
    failures: list[str] = []

    published_ancestor = is_ancestor(root, PUBLISHED_MERGE)
    candidate_ancestor = is_ancestor(root, APPROVED_CANDIDATE)
    if not published_ancestor:
        failures.append("published-merge-ancestry")
    if not candidate_ancestor:
        failures.append("approved-candidate-ancestry")

    actual_authority = validate_future_authorities(root, contract)
    expected_missing = {
        "appearance-lock:not-bound",
        "future-authority:not-bound",
        "locked-materials:not-bound",
        "origin-master:missing-binding",
        "source-profile:not-bound",
    }
    if not expected_missing.issubset(actual_authority["errors"]):
        failures.append("missing-authority-rejection")

    isolation = validate_output_root_isolation(
        root,
        contract,
        require_absent=True,
    )
    if not isolation["passed"]:
        failures.append("output-root-isolation")

    guard_results = {
        process_id: evaluate_render_guard(root, contract, process_id)
        for process_id in ("A", "B", "C")
    }
    if any(
        result["decision"] != "reject"
        or result["rejectionStage"] != "before_renderer_launch"
        or result["blenderProcessLaunches"] != 0
        for result in guard_results.values()
    ):
        failures.append("render-guard-rejection")

    assemble_code, assemble_result = assemble(root, args.contract, contract)
    if (
        assemble_code != 3
        or assemble_result.get("decision") != "BLOCKED"
        or assemble_result.get("packetWritten") is not False
    ):
        failures.append("launch-bound-production-block")

    _, post_errors = post_source_preflight(root, contract)
    expected_process_errors = {
        f"process-{process_id}:missing-{name}"
        for process_id in ("A", "B", "C")
        for name in (
            "raw",
            "semantic",
            "provenance",
            "registration",
            "objectMapping",
            "freshInvocationReceipt",
        )
    }
    if not expected_process_errors.issubset(post_errors):
        failures.append("post-source-input-block")

    dry_contract = fixture_contract(root, contract)
    fixture_authority = validate_future_authorities(root, dry_contract)
    expected_unpublished = {
        "appearance-lock:unpublished-path",
        "locked-materials:unpublished-path",
        "source-profile:unpublished-path",
    }
    if fixture_authority["passed"] or not expected_unpublished.issubset(
        fixture_authority["errors"]
    ):
        failures.append("fixture-unpublished-authority-rejection")

    stale = copy.deepcopy(dry_contract)
    stale["futureProductionAuthority"]["originMasterCommit"] = "0" * 40
    stale_result = validate_future_authorities(root, stale)
    if "origin-master:stale-binding" not in stale_result["errors"]:
        failures.append("stale-origin-master-rejection")

    mismatch = copy.deepcopy(dry_contract)
    mismatch["lockedMaterialMapping"]["sha256"] = "f" * 64
    mismatch_result = validate_future_authorities(root, mismatch)
    if "locked-materials:working-tree-sha256" not in mismatch_result["errors"]:
        failures.append("mismatched-material-rejection")

    guard_fixture = artifact(root, f"{FIXTURE_ROOT}/LAUNCH-GUARD-RECEIPT.json")
    isolation_fixture = artifact(
        root,
        f"{FIXTURE_ROOT}/OUTPUT-ROOT-ISOLATION-RECEIPT.json",
    )
    dry_packet = build_packet(
        root,
        args.contract,
        dry_contract,
        guard_fixture,
        isolation_fixture,
    )
    schema_path = repository_path(root, SOURCE_SCHEMA_PATH)
    schema = load_json(schema_path)
    schema_errors = list(Draft202012Validator(schema).iter_errors(dry_packet))
    if schema_errors or dry_packet.get("stage") != "launch_bound":
        failures.append("launch-bound-v2-structural-fixture")
    semantic_rejection = semantic_dry_rejection(root, dry_packet)
    if not semantic_rejection["rejected"]:
        failures.append("launch-bound-v2-semantic-fixture-rejection")

    pixel_files: list[str] = []
    caches: list[str] = []
    for relative in (SOURCE_ROOT, EVIDENCE_ROOT):
        directory = repository_path(root, relative)
        for path in directory.rglob("*"):
            if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES:
                pixel_files.append(str(path.relative_to(root)))
            if "__pycache__" in path.parts:
                caches.append(str(path.relative_to(root)))
    if pixel_files:
        failures.append("pixel-files")
    if caches:
        failures.append("generated-caches")

    result = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "approvedCandidate": APPROVED_CANDIDATE,
        "approvedCandidateAncestor": candidate_ancestor,
        "publishedMerge": PUBLISHED_MERGE,
        "publishedMergeAncestor": published_ancestor,
        "head": git_output(root, "rev-parse", "HEAD"),
        "actualMissingAuthorityRejection": actual_authority,
        "guardResults": guard_results,
        "outputRootIsolation": isolation,
        "launchBoundProductionAttempt": assemble_result,
        "postSourceBlockers": post_errors,
        "dryFixture": {
            "structuralStage": dry_packet["stage"],
            "structuralSchemaPassed": not schema_errors,
            "fixtureAuthorityRejection": fixture_authority,
            "staleOriginMasterRejection": stale_result,
            "mismatchedMaterialRejection": mismatch_result,
            "semanticRejection": semantic_rejection,
            "productionAuthority": False,
        },
        "pixelFiles": sorted(pixel_files),
        "generatedCaches": sorted(caches),
        "invocations": {
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "dccProcesses": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "renderInvocations": 0,
            "pixelFiles": 0,
        },
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "failures": failures,
        "passed": not failures,
    }
    output = repository_path(root, args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
