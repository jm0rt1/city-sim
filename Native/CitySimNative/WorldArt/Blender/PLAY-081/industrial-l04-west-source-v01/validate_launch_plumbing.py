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
from west_path_safety import (
    DEFAULT_VALIDATION_OUTPUT,
    PathSafetyError,
    pipeline_relative,
    validate_exact_output,
    validate_pipeline_layout,
    validate_process_layout,
    write_exact_bytes_no_overwrite,
    write_exact_json,
)


PUBLISHED_MERGE = "662bc89d0ad8d1856aabd4a37c9b24b57e34f32b"
APPROVED_CANDIDATE = "135805d9b092d44ea28ff8421cbc70bddd1ac38a"
FIXTURE_ROOT = f"{EVIDENCE_ROOT}/dry-fixtures"
DEFAULT_OUTPUT = DEFAULT_VALIDATION_OUTPUT
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


def command_guard_matrix(root: Path) -> dict[str, dict[str, Any]]:
    commands = {
        **{
            f"render-{process_id}": [
                "python3",
                "-B",
                f"{SOURCE_ROOT}/run_west_source.py",
                "--repository-root",
                ".",
                "--mode",
                process_id,
            ]
            for process_id in ("A", "B", "C")
        },
        "launch-bound": [
            "python3",
            "-B",
            f"{SOURCE_ROOT}/prepare_launch_bound.py",
            "--repository-root",
            ".",
            "--mode",
            "assemble",
        ],
        **{
            mode: [
                "python3",
                "-B",
                f"{SOURCE_ROOT}/post_source_pipeline.py",
                "--repository-root",
                ".",
                "--mode",
                mode,
            ]
            for mode in (
                "normalize-1",
                "normalize-2",
                "validate-repeat",
                "contact-sheet",
                "review-manifest",
                "parallel-receipt",
                "assemble-source",
            )
        },
    }
    matrix: dict[str, dict[str, Any]] = {}
    for name, command in commands.items():
        completed = subprocess.run(
            command,
            cwd=root,
            check=False,
            capture_output=True,
            text=True,
        )
        try:
            payload = json.loads(completed.stdout)
        except json.JSONDecodeError:
            payload = {}
        matrix[name] = {
            "command": command,
            "returnCode": completed.returncode,
            "decision": payload.get("decision"),
            "rejectionStage": payload.get("rejectionStage"),
            "blenderProcessLaunches": payload.get("blenderProcessLaunches"),
            "blenderRenderApiCalls": payload.get("blenderRenderApiCalls"),
            "normalizerInvocations": payload.get("normalizerInvocations", 0),
            "contactSheetInvocations": payload.get(
                "contactSheetInvocations",
                0,
            ),
            "pixelFiles": payload.get(
                "pixelFiles",
                payload.get("pixelFilesWritten"),
            ),
        }
    return matrix


def rejection_result(
    name: str,
    operation: Any,
    *,
    target: Path,
) -> dict[str, Any]:
    error = None
    try:
        operation()
    except PathSafetyError as exception:
        error = str(exception)
    return {
        "name": name,
        "rejected": error is not None,
        "error": error,
        "targetExists": target.exists() or target.is_symlink(),
        "writesToTarget": 1 if target.exists() or target.is_symlink() else 0,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "pixelFiles": 0,
        "passed": (
            error is not None
            and not target.exists()
            and not target.is_symlink()
        ),
    }


def pipeline_redirect_dynamic_tests(
    fixture: Path,
    contract: dict[str, Any],
) -> dict[str, Any]:
    """Prove every downstream writer class rejects symlink redirects."""
    cases = (
        (
            "launch-bound-receipt-redirect",
            "launchBound.guardReceipt",
            "leaf",
            False,
        ),
        (
            "launch-bound-packet-dangling-leaf",
            "launchBound.packet",
            "leaf",
            True,
        ),
        (
            "normalization-run-1-shared-root-redirect",
            "postSource.normalizationRun1Root",
            "root",
            False,
        ),
        (
            "normalization-run-2-outside-root-redirect",
            "postSource.normalizationRun2Root",
            "root",
            False,
        ),
        (
            "review-root-redirect",
            "postSource.reviewRoot",
            "root",
            False,
        ),
        (
            "normalization-repeat-receipt-redirect",
            "postSource.normalizationRepeatReceipt",
            "leaf",
            False,
        ),
        (
            "parallel-receipt-dangling-leaf",
            "postSource.parallelExecutionReceipt",
            "leaf",
            True,
        ),
        (
            "source-candidate-packet-redirect",
            "postSource.sourceCandidatePacket",
            "leaf",
            False,
        ),
        (
            "source-validation-output-redirect",
            "validation.sourceValidation",
            "leaf",
            False,
        ),
        (
            "rejection-inventory-redirect",
            "rejections",
            "leaf",
            False,
        ),
    )
    tests: list[dict[str, Any]] = []
    for index, (name, identity, kind, dangling) in enumerate(cases):
        repository = fixture / f"pipeline-{index:02d}-repository"
        repository.mkdir()
        relative = pipeline_relative(contract, identity)
        redirect = fixture / f"pipeline-{index:02d}-redirect"
        redirect.mkdir()
        exact = repository.joinpath(*relative.split("/"))
        exact.parent.mkdir(parents=True)
        target_file = redirect / "redirected-output.bin"
        sentinel = b"PLAY-081-REDIRECT-SENTINEL\n"
        if kind == "root":
            exact.symlink_to(redirect, target_is_directory=True)
            attempted_relative = f"{relative}/probe-output.bin"
        else:
            if not dangling:
                target_file.write_bytes(sentinel)
            exact.symlink_to(target_file)
            attempted_relative = relative
        layout = validate_pipeline_layout(repository, copy.deepcopy(contract))
        error = None
        try:
            write_exact_bytes_no_overwrite(
                repository,
                attempted_relative,
                b"MUST-NOT-WRITE",
                expected=attempted_relative,
            )
        except PathSafetyError as exception:
            error = str(exception)
        target_unchanged = (
            not target_file.exists()
            if dangling or kind == "root"
            else target_file.read_bytes() == sentinel
        )
        redirect_entries = sorted(
            str(path.relative_to(redirect)) for path in redirect.rglob("*")
        )
        expected_entries = (
            [] if dangling or kind == "root" else ["redirected-output.bin"]
        )
        tests.append(
            {
                "name": name,
                "identity": identity,
                "kind": kind,
                "danglingLeaf": dangling,
                "rejectedByLayout": not layout["passed"],
                "layoutErrors": layout["errors"],
                "writerError": error,
                "redirectEntries": redirect_entries,
                "redirectTargetUnchanged": target_unchanged,
                "writesToRedirectTarget": 0,
                "blenderProcessLaunches": 0,
                "blenderRenderApiCalls": 0,
                "normalizerInvocations": 0,
                "contactSheetInvocations": 0,
                "pixelFiles": 0,
                "passed": (
                    not layout["passed"]
                    and error is not None
                    and "SYMLINK_COMPONENT" in error
                    and target_unchanged
                    and redirect_entries == expected_entries
                ),
            }
        )
    return {
        "fixtureOnly": True,
        "tests": tests,
        "testCount": len(tests),
        "allRedirectTargetsUnwritten": all(
            test["writesToRedirectTarget"] == 0
            and test["redirectTargetUnchanged"]
            for test in tests
        ),
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "pixelFiles": 0,
        "passed": all(test["passed"] for test in tests),
    }


def path_safety_dynamic_tests(contract: dict[str, Any]) -> dict[str, Any]:
    """Exercise exact/shared/outside/symlink paths in disposable repositories."""
    tests: list[dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="play081-path-safety-") as temp:
        fixture = Path(temp)

        exact_root = fixture / "exact-repository"
        exact_root.mkdir()
        exact_path = write_exact_json(
            exact_root,
            DEFAULT_OUTPUT,
            {"fixtureOnly": True},
        )
        tests.append(
            {
                "name": "exact-task-owned-validator-output",
                "accepted": exact_path.is_file(),
                "path": DEFAULT_OUTPUT,
                "fixtureWrites": 1,
                "productionWrites": 0,
                "blenderProcessLaunches": 0,
                "pixelFiles": 0,
                "passed": exact_path.is_file(),
            }
        )

        shared_root = fixture / "shared-output-repository"
        shared_root.mkdir()
        shared_relative = (
            "docs/production/evidence/INTEGRATION/"
            "PLAY-081-WEST-SHOULD-NOT-EXIST.json"
        )
        shared_target = shared_root / shared_relative
        shared_result = rejection_result(
            "shared-validator-output",
            lambda: write_exact_json(
                shared_root,
                shared_relative,
                {"mustNotWrite": True},
            ),
            target=shared_target,
        )
        shared_result["directoriesCreated"] = int(
            shared_target.parent.exists()
        )
        shared_result["passed"] = (
            shared_result["passed"]
            and shared_result["directoriesCreated"] == 0
        )
        tests.append(shared_result)

        outside_root = fixture / "outside-output-repository"
        outside_root.mkdir()
        outside_target = Path(
            "/private/tmp/"
            "PLAY-081-WEST-PATH-SAFETY-REJECTION-PROBE-DO-NOT-CREATE.json"
        )
        tests.append(
            rejection_result(
                "outside-validator-output",
                lambda: write_exact_json(
                    outside_root,
                    str(outside_target),
                    {"mustNotWrite": True},
                ),
                target=outside_target,
            )
        )

        symlink_output_root = fixture / "symlink-output-repository"
        symlink_output_root.mkdir()
        symlink_target = fixture / "symlink-output-target"
        symlink_target.mkdir()
        symlink_parent = symlink_output_root / "docs/production/evidence"
        symlink_parent.mkdir(parents=True)
        (symlink_parent / "PLAY-081").symlink_to(
            symlink_target,
            target_is_directory=True,
        )
        redirected_output = (
            symlink_target
            / "industrial-l04-west-source-v01"
            / "PRELOCK-LAUNCH-PLUMBING-VALIDATION.json"
        )
        symlink_result = rejection_result(
            "symlink-validator-output",
            lambda: write_exact_json(
                symlink_output_root,
                DEFAULT_OUTPUT,
                {"mustNotWrite": True},
            ),
            target=redirected_output,
        )
        symlink_result["directoriesCreatedInRedirect"] = int(
            redirected_output.parent.exists()
        )
        symlink_result["passed"] = (
            symlink_result["passed"]
            and symlink_result["directoriesCreatedInRedirect"] == 0
        )
        tests.append(symlink_result)

        exact_layout_root = fixture / "exact-layout-repository"
        exact_layout_root.mkdir()
        exact_layout = validate_process_layout(
            exact_layout_root,
            copy.deepcopy(contract),
            require_absent=True,
        )
        tests.append(
            {
                "name": "exact-abc-layout",
                "accepted": exact_layout["passed"],
                "errors": exact_layout["errors"],
                "productionWrites": 0,
                "blenderProcessLaunches": 0,
                "pixelFiles": 0,
                "passed": exact_layout["passed"],
            }
        )

        for name, process_id, target_kind in (
            ("shared-root-redirect", "A", "shared"),
            ("outside-root-redirect", "B", "outside"),
            ("leaf-root-redirect", "C", "leaf"),
        ):
            repository = fixture / f"{name}-repository"
            repository.mkdir()
            if target_kind == "shared":
                redirect_target = (
                    repository
                    / "docs/production/evidence/INTEGRATION/shared-target"
                )
            else:
                redirect_target = fixture / f"{name}-target"
            redirect_target.mkdir(parents=True)
            process_directory = (
                repository
                / "docs/production/evidence/PLAY-081"
                / f"industrial-l04-west-source-v01/process-{process_id}"
            )
            process_directory.parent.mkdir(parents=True)
            if target_kind == "leaf":
                process_directory.mkdir()
                (process_directory / "raw").symlink_to(
                    redirect_target,
                    target_is_directory=True,
                )
            else:
                process_directory.symlink_to(
                    redirect_target,
                    target_is_directory=True,
                )
            layout = validate_process_layout(
                repository,
                copy.deepcopy(contract),
                require_absent=True,
            )
            downstream = validate_process_layout(
                repository,
                copy.deepcopy(contract),
                require_absent=False,
            )
            guard = evaluate_render_guard(
                repository,
                copy.deepcopy(contract),
                process_id,
            )
            _, downstream_preflight_errors = post_source_preflight(
                repository,
                copy.deepcopy(contract),
            )
            redirected_entries = list(redirect_target.rglob("*"))
            tests.append(
                {
                    "name": name,
                    "rejectedBeforeLaunch": not layout["passed"],
                    "rejectedDownstream": not downstream["passed"],
                    "outerGuardDecision": guard["decision"],
                    "outerGuardReasonCodes": guard["reasonCodes"],
                    "downstreamPreflightErrors": downstream_preflight_errors,
                    "errors": layout["errors"],
                    "downstreamErrors": downstream["errors"],
                    "writesToRedirectTarget": len(redirected_entries),
                    "blenderProcessLaunches": guard["blenderProcessLaunches"],
                    "blenderRenderApiCalls": guard["blenderRenderApiCalls"],
                    "normalizerInvocations": guard["normalizerInvocations"],
                    "contactSheetInvocations": guard[
                        "contactSheetInvocations"
                    ],
                    "pixelFiles": guard["pixelFiles"],
                    "passed": (
                        not layout["passed"]
                        and not downstream["passed"]
                        and guard["decision"] == "reject"
                        and guard["blenderProcessLaunches"] == 0
                        and guard["blenderRenderApiCalls"] == 0
                        and guard["normalizerInvocations"] == 0
                        and guard["contactSheetInvocations"] == 0
                        and guard["pixelFiles"] == 0
                        and any(
                            "SYMLINK_COMPONENT" in error
                            for error in guard["reasonCodes"]
                        )
                        and any(
                            "SYMLINK_COMPONENT" in error
                            for error in downstream_preflight_errors
                        )
                        and not redirected_entries
                        and any(
                            "SYMLINK_COMPONENT" in error
                            for error in layout["errors"]
                        )
                    ),
                }
            )

        mismatch_contract = copy.deepcopy(contract)
        mismatch_contract["outputInventory"]["processes"]["A"]["rawRoot"] = (
            "docs/production/evidence/INTEGRATION/raw"
        )
        mismatch_root = fixture / "lexical-mismatch-repository"
        mismatch_root.mkdir()
        mismatch = validate_process_layout(
            mismatch_root,
            mismatch_contract,
            require_absent=True,
        )
        tests.append(
            {
                "name": "lexical-abc-identity-mismatch",
                "rejectedBeforeLaunch": not mismatch["passed"],
                "errors": mismatch["errors"],
                "productionWrites": 0,
                "blenderProcessLaunches": 0,
                "pixelFiles": 0,
                "passed": (
                    not mismatch["passed"]
                    and "process-A:rawRoot:lexical-identity"
                    in mismatch["errors"]
                ),
            }
        )
        pipeline_redirects = pipeline_redirect_dynamic_tests(
            fixture,
            contract,
        )
    return {
        "fixtureOnly": True,
        "tests": tests,
        "testCount": len(tests),
        "allRejectedTargetsUnwritten": all(
            test.get("writesToTarget", 0) == 0
            and test.get("writesToRedirectTarget", 0) == 0
            for test in tests
        ),
        "invocations": {
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "pixelFiles": 0,
        },
        "pipelineRedirects": pipeline_redirects,
        "passed": (
            all(test["passed"] for test in tests)
            and pipeline_redirects["passed"]
        ),
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    try:
        validate_exact_output(root, args.output)
    except PathSafetyError as error:
        result = {
            "schemaVersion": 1,
            "taskId": "PLAY-081",
            "direction": "west",
            "decision": "reject",
            "rejectionStage": "before_output_write",
            "error": str(error),
            "requestedOutput": args.output,
            "outputWritten": False,
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "pixelFiles": 0,
            "passed": False,
        }
        print(json.dumps(result, indent=2, sort_keys=True))
        return 3
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
    pipeline_layout = validate_pipeline_layout(root, contract)
    if not pipeline_layout["passed"]:
        failures.append("pipeline-output-isolation")
    path_safety = path_safety_dynamic_tests(contract)
    if not path_safety["passed"]:
        failures.append("path-safety-dynamic-tests")

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
    commands = command_guard_matrix(root)
    if any(
        result["returnCode"] != 3
        or result["decision"] not in {"reject", "BLOCKED"}
        or result["rejectionStage"]
        not in {
            "before_renderer_launch",
            "before_blender_process",
            "before_pixel_read_or_write",
        }
        or any(
            result[field] != 0
            for field in (
                "blenderProcessLaunches",
                "blenderRenderApiCalls",
                "normalizerInvocations",
                "contactSheetInvocations",
                "pixelFiles",
            )
        )
        for result in commands.values()
    ):
        failures.append("command-surface-guard-matrix")

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
        "pipelineOutputIsolation": pipeline_layout,
        "pathSafetyDynamicTests": path_safety,
        "launchBoundProductionAttempt": assemble_result,
        "postSourceBlockers": post_errors,
        "commandGuardMatrix": commands,
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
    write_exact_json(root, args.output, result)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
