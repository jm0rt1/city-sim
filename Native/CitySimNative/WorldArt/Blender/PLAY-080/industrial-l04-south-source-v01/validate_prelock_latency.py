#!/usr/bin/env python3
"""Dry structural validation for the PLAY-080 South launch boundary."""

from __future__ import annotations

import ast
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

import prepare_candidate_outputs
import prepare_launch_binding
import literal192_semantic_proof
import run_production
from validate_source_outputs import decode_rgba_png


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
CONTRACT_PATH = SOURCE_DIR / "runner-contract.json"
EVIDENCE_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/"
    "PRELOCK-LATENCY-VALIDATION.json"
)
EXPECTED_MODES = {
    "normalize-repeat",
    "lods",
    "contact-sheet",
    "parallel-receipt",
    "review-manifest",
    "assemble",
}


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def run_rejected(command: list[str], expected_code: str) -> dict[str, Any]:
    result = subprocess.run(
        command,
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    output = json.loads(result.stdout)
    if result.returncode != 2 or output.get("code") != expected_code:
        raise AssertionError(
            {
                "command": command,
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "expectedCode": expected_code,
            }
        )
    return {
        "returnCode": result.returncode,
        "result": output["result"],
        "code": output["code"],
    }


def prelock_report_write_rejection_check() -> dict[str, Any]:
    results: dict[str, Any] = {}
    with tempfile.TemporaryDirectory(
        prefix="play-080-south-report-guard-"
    ) as directory:
        temporary_root = Path(directory)
        for mode in ("A", "B", "C"):
            report_path = (
                temporary_root / f"process-{mode}" / "runner-result.json"
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(SOURCE_DIR / "run_production.py"),
                    "--mode",
                    mode,
                    "--report",
                    str(report_path),
                ],
                cwd=REPOSITORY_ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
            output = json.loads(result.stdout)
            expected_zero = {
                "blenderProcessLaunches": 0,
                "blenderRenderApiCalls": 0,
                "renderInvocations": 0,
                "pixelFiles": 0,
            }
            if (
                result.returncode != 2
                or output.get("result") != "REJECTED"
                or output.get("rejection", {}).get("code")
                != "MISSING_SOURCE_PRODUCTION_PROFILE"
                or output.get("rejectionStage") != "before_renderer_launch"
                or any(
                    output.get(key) != value
                    for key, value in expected_zero.items()
                )
                or report_path.exists()
                or report_path.parent.exists()
                or result.stderr
            ):
                raise AssertionError(
                    {
                        "mode": mode,
                        "returncode": result.returncode,
                        "stdout": result.stdout,
                        "stderr": result.stderr,
                        "reportWritten": report_path.exists(),
                        "reportParentCreated": report_path.parent.exists(),
                    }
                )
            results[mode] = {
                "returnCode": result.returncode,
                "result": output["result"],
                "rejectionCode": output["rejection"]["code"],
                "rejectionStage": output["rejectionStage"],
                "reportSupplied": True,
                "reportWritten": False,
                "reportParentCreated": False,
                **expected_zero,
            }
        if list(temporary_root.iterdir()):
            raise AssertionError("prelock report guard created a file or directory")
    return {
        "result": "PASS",
        "destination": "stdout_only",
        "processes": results,
    }


def synthetic_packet_check(contract: dict[str, Any]) -> dict[str, Any]:
    sha_a = "a" * 64
    commit_a = "a" * 40
    appearance = {
        "documentPath": "docs/production/evidence/INTEGRATION/fixture-lock.json",
        "commit": commit_a,
        "documentSha256": sha_a,
        "northProcessASourceSha256": sha_a,
        "northProcessADecodedRgbaSha256": sha_a,
    }
    material = {
        "path": "docs/production/evidence/INTEGRATION/fixture-material.json",
        "commit": commit_a,
        "sha256": sha_a,
    }
    profile = {
        "path": "docs/production/evidence/INTEGRATION/fixture-profile.json",
        "commit": commit_a,
        "sha256": sha_a,
    }
    fixture_artifact = {
        "path": (
            "docs/production/evidence/PLAY-080/"
            "industrial-l04-south-source-v01/fixture.json"
        ),
        "sha256": sha_a,
    }
    packet = prepare_launch_binding.build_packet(
        contract,
        "b" * 40,
        appearance,
        material,
        profile,
        fixture_artifact,
        fixture_artifact,
        fixture_artifact,
    )
    schema_path = prepare_launch_binding.repo_path(
        prepare_launch_binding.SCHEMA_PATH
    )
    schema_bytes = schema_path.read_bytes()
    if sha256_bytes(schema_bytes) != prepare_launch_binding.SCHEMA_SHA256:
        raise AssertionError("source-stage v2 schema SHA drift")
    schema = json.loads(schema_bytes)
    Draft202012Validator.check_schema(schema)
    errors = list(Draft202012Validator(schema).iter_errors(packet))
    if errors:
        raise AssertionError(errors[0].message)
    return {
        "result": "PASS",
        "schemaPath": prepare_launch_binding.SCHEMA_PATH,
        "schemaSha256": prepare_launch_binding.SCHEMA_SHA256,
        "stage": packet["stage"],
        "sourceReady": packet["sourceReady"],
        "productionSelected": packet["productionSelected"],
    }


def deterministic_fixture_check() -> dict[str, Any]:
    rgba = bytes(
        (
            0,
            0,
            0,
            0,
            255,
            0,
            0,
            255,
            0,
            255,
            0,
            255,
            0,
            0,
            255,
            255,
        )
    )
    first = prepare_candidate_outputs.encode_png(2, 2, rgba)
    second = prepare_candidate_outputs.encode_png(2, 2, rgba)
    if first != second:
        raise AssertionError("fixture normalization repeat mismatch")
    with tempfile.TemporaryDirectory(prefix="play-080-south-dry-") as directory:
        fixture_path = Path(directory) / "fixture.png"
        fixture_path.write_bytes(first)
        width, height, decoded = decode_rgba_png(fixture_path)
    if (width, height, decoded) != (2, 2, rgba):
        raise AssertionError("fixture canonical decode mismatch")
    resized_first = prepare_candidate_outputs.resize_nearest(2, 2, rgba, 3, 3)
    resized_second = prepare_candidate_outputs.resize_nearest(2, 2, rgba, 3, 3)
    if resized_first != resized_second:
        raise AssertionError("fixture LOD repeat mismatch")
    return {
        "result": "PASS",
        "fixtureOnly": True,
        "repositoryPixelFilesWritten": 0,
        "normalizationRepeatSha256": sha256_bytes(first),
        "lodRepeatDecodedRgbaSha256": sha256_bytes(resized_first),
    }


def literal192_check(contract: dict[str, Any]) -> dict[str, Any]:
    scene = literal192_semantic_proof.load_json(
        literal192_semantic_proof.repository_path(
            contract["acceptedPredesign"]["scene"]["path"]
        )
    )
    metrics = literal192_semantic_proof.measure_literal192_semantic_proof(
        scene, contract
    )
    if not literal192_semantic_proof.measurement_passes(
        metrics, contract["invariants"]["pixelValidation"]
    ):
        raise AssertionError({"literal192Metrics": metrics})
    return {
        "result": "PASS",
        "measurementMethod": metrics["measurementMethod"],
        "primaryPortalPixels": metrics["primaryPortalPixels"],
        "freightOpeningWidthsPixels": metrics["freightOpeningWidthsPixels"],
        "frameMinimumThicknessPixels": metrics["frameMinimumThicknessPixels"],
        "silhouetteBreaks": metrics["silhouetteBreaks"],
        "processOcclusionPixels": metrics["processOcclusionPixels"],
        "pixelFiles": 0,
    }


def static_guard_order_check() -> dict[str, Any]:
    tree = ast.parse((SOURCE_DIR / "run_production.py").read_text(encoding="utf-8"))
    main = next(
        node
        for node in tree.body
        if isinstance(node, ast.FunctionDef) and node.name == "main"
    )
    calls = [
        node.func.id
        for node in sorted(
            (
                node
                for node in ast.walk(main)
                if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
            ),
            key=lambda node: (node.lineno, node.col_offset),
        )
    ]
    required = [
        "require_source_production_profile",
        "require_lock",
        "require_coordinate_bridge",
        "require_launch_plan",
        "require_launch_bundle",
        "render_source",
    ]
    positions = [calls.index(name) for name in required]
    if positions != sorted(positions):
        raise AssertionError({"guardOrder": calls, "required": required})
    bpy_lines = [
        node.lineno
        for node in ast.walk(tree)
        if isinstance(node, ast.Import)
        and any(alias.name == "bpy" for alias in node.names)
    ]
    render = next(
        node
        for node in tree.body
        if isinstance(node, ast.FunctionDef) and node.name == "render_source"
    )
    if any(
        line < render.lineno or line > render.end_lineno for line in bpy_lines
    ):
        raise AssertionError({"bpyImportLines": bpy_lines})
    guard_handlers = [
        node
        for node in ast.walk(main)
        if isinstance(node, ast.ExceptHandler)
        and isinstance(node.type, ast.Name)
        and node.type.id == "GuardRejected"
    ]
    guard_write_calls = [
        node
        for handler in guard_handlers
        for node in ast.walk(handler)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id == "write_report"
    ]
    if (
        len(guard_handlers) != 1
        or len(guard_write_calls) != 1
        or not guard_write_calls[0].args
        or not isinstance(guard_write_calls[0].args[0], ast.Constant)
        or guard_write_calls[0].args[0].value is not None
    ):
        raise AssertionError("GuardRejected report destination is not stdout")
    return {
        "result": "PASS",
        "guardOrder": required,
        "bpyImportInsideRenderOnly": True,
        "guardRejectedReportDestination": "stdout_only",
    }


def repository_pixel_files() -> list[str]:
    roots = [
        SOURCE_DIR / "outputs",
        EVIDENCE_PATH.parent / "process-A",
        EVIDENCE_PATH.parent / "process-B",
        EVIDENCE_PATH.parent / "process-C",
        EVIDENCE_PATH.parent / "contact-sheet",
    ]
    suffixes = {".png", ".jpg", ".jpeg", ".webp"}
    return sorted(
        path.relative_to(REPOSITORY_ROOT).as_posix()
        for root in roots
        if root.exists()
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in suffixes
    )


def main() -> int:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    run_production.validate_contract_shape(contract)
    plan = run_production.require_launch_plan(contract)
    output_roots = list(plan["isolatedOutputRoots"].values())
    evidence_roots = list(plan["isolatedEvidenceRoots"].values())
    if len(set(output_roots)) != 3 or len(set(evidence_roots)) != 3:
        raise AssertionError("process roots are not distinct")
    if set(prepare_candidate_outputs.COMMANDS) != EXPECTED_MODES:
        raise AssertionError("candidate command surface drift")
    before_pixels = repository_pixel_files()
    if before_pixels:
        raise AssertionError({"unexpectedPixelFiles": before_pixels})

    launch_rejection = run_rejected(
        [sys.executable, str(SOURCE_DIR / "prepare_launch_binding.py")],
        "RUNNER_NOT_APPEARANCE_LOCK_BOUND",
    )
    candidate_rejections = {
        mode: run_rejected(
            [
                sys.executable,
                str(SOURCE_DIR / "prepare_candidate_outputs.py"),
                "--mode",
                mode,
            ],
            "RUNNER_NOT_APPEARANCE_LOCK_BOUND",
        )
        for mode in sorted(EXPECTED_MODES)
    }
    try:
        prepare_candidate_outputs.require_exact_abc_products(contract)
    except prepare_candidate_outputs.CandidatePreparationRejected as rejection:
        if rejection.code != "MISSING_ABC_PRODUCTS":
            raise
        abc_rejection = {
            "result": "REJECTED",
            "code": rejection.code,
            "missingArtifactCount": len(rejection.detail),
        }
    else:
        raise AssertionError("A/B/C guard unexpectedly passed")

    future_outputs = [
        contract["outputInventory"][name]
        for name in (
            "frozenInputManifest",
            "launchGuardReceipt",
            "outputRootIsolationReceipt",
            "launchBoundHandoff",
        )
    ]
    unexpected_outputs = [
        path for path in future_outputs if prepare_launch_binding.repo_path(path).exists()
    ]
    if unexpected_outputs:
        raise AssertionError({"unexpectedLaunchOutputs": unexpected_outputs})
    after_pixels = repository_pixel_files()
    if after_pixels != before_pixels:
        raise AssertionError({"pixelMutation": after_pixels})

    evidence = {
        "schema": "citysim.play-080.prelock-latency-validation.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "branch": "codex/citysim-world-art-south",
        "approvedCandidateAncestor": (
            "148261e482b4faea468dffcebd2d96ca3dfdec19"
        ),
        "publishedBaseline": contract["baselineCommit"],
        "sourceStageV2": synthetic_packet_check(contract),
        "launchPlan": {
            "authorizedProcesses": plan["authorizedProcesses"],
            "maximumConcurrentDccProcesses": plan[
                "maximumConcurrentDccProcesses"
            ],
            "noOverwrite": plan["noOverwrite"],
            "isolatedOutputRoots": plan["isolatedOutputRoots"],
            "isolatedEvidenceRoots": plan["isolatedEvidenceRoots"],
            "allRootsDistinct": True,
        },
        "launchGuardDryRejection": launch_rejection,
        "preRenderReportWriteGuards": prelock_report_write_rejection_check(),
        "candidateCommandDryRejections": candidate_rejections,
        "missingABCRejection": abc_rejection,
        "candidateCommandSurfaces": sorted(EXPECTED_MODES),
        "staticGuardOrder": static_guard_order_check(),
        "literal192AnalyticProof": literal192_check(contract),
        "deterministicNonProductionFixture": deterministic_fixture_check(),
        "productionValidationDisposition": {
            "processA": "not_run",
            "processB": "not_run",
            "processC": "not_run",
            "normalization": "not_run",
            "lods": "not_run",
            "contactSheet": "not_run",
            "reviewManifest": "not_run",
            "assembly": "not_run",
        },
        "zeroInvocationProof": {
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizerProductionInvocations": 0,
            "contactSheetProductionInvocations": 0,
            "repositoryPixelFiles": after_pixels,
        },
        "sourceReady": False,
        "productionSelected": False,
        "selfAccepted": False,
        "result": "PASS",
    }
    EVIDENCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE_PATH.write_text(
        json.dumps(evidence, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"result": "PASS", "evidence": str(EVIDENCE_PATH)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
