#!/usr/bin/env python3
"""Zero-pixel validation for the PLAY-081 pre-lock runner boundary."""

from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01"
)
EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01"
)
DEFAULT_CONTRACT = f"{SOURCE_ROOT}/RUNNER-CONTRACT.json"
DEFAULT_DRIVER = f"{SOURCE_ROOT}/run_west_source.py"
DEFAULT_BLENDER_SCRIPT = f"{SOURCE_ROOT}/blender_render_west.py"
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument("--driver", default=DEFAULT_DRIVER)
    parser.add_argument("--blender-script", default=DEFAULT_BLENDER_SCRIPT)
    parser.add_argument("--output-directory", required=True)
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def repository_path(root: Path, relative: str) -> Path:
    resolved = (root / relative).resolve()
    resolved.relative_to(root)
    return resolved


def load_runner(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("play081_west_runner", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load West runner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def count_pixel_files(root: Path) -> tuple[int, list[str]]:
    files: list[str] = []
    for relative in (SOURCE_ROOT, EVIDENCE_ROOT):
        directory = repository_path(root, relative)
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES:
                files.append(str(path.relative_to(root)))
    return len(files), sorted(files)


def static_control_flow_checks(driver_path: Path) -> dict[str, Any]:
    source = driver_path.read_text()
    tree = ast.parse(source, filename=str(driver_path))
    imports_bpy = any(
        (
            isinstance(node, ast.Import)
            and any(alias.name == "bpy" for alias in node.names)
        )
        or (isinstance(node, ast.ImportFrom) and node.module == "bpy")
        for node in ast.walk(tree)
    )
    main = next(
        node
        for node in tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        and node.name == "main"
    )
    evaluate_lines = [
        node.lineno
        for node in ast.walk(main)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id == "evaluate_render_guard"
    ]
    launch_lines = [
        node.lineno
        for node in ast.walk(main)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id == "launch_blender"
    ]
    subprocess_calls = [
        node.lineno
        for node in ast.walk(tree)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and isinstance(node.func.value, ast.Name)
        and node.func.value.id == "subprocess"
        and node.func.attr == "run"
    ]
    return {
        "driverImportsBpy": imports_bpy,
        "evaluateGuardLines": evaluate_lines,
        "launchBlenderLines": launch_lines,
        "subprocessRunLines": subprocess_calls,
        "guardTextPrecedesLaunchText": (
            source.find("decision = evaluate_render_guard")
            < source.find("return launch_blender")
        ),
        "passed": (
            not imports_bpy
            and len(evaluate_lines) == 1
            and len(launch_lines) == 1
            and evaluate_lines[0] < launch_lines[0]
            and source.find("decision = evaluate_render_guard")
            < source.find("return launch_blender")
        ),
    }


def zero_counts() -> dict[str, int]:
    return {
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "renderInvocations": 0,
        "pixelFiles": 0,
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract_path = repository_path(root, args.contract)
    driver_path = repository_path(root, args.driver)
    blender_script_path = repository_path(root, args.blender_script)
    output = Path(args.output_directory).resolve()
    output.mkdir(parents=True, exist_ok=True)

    contract = json.loads(contract_path.read_text())
    runner = load_runner(driver_path)
    frozen_errors = runner.frozen_input_errors(root, contract)
    control_flow = static_control_flow_checks(driver_path)
    pixel_count, pixel_paths = count_pixel_files(root)
    modes = ("A", "B", "C")
    source_validator_path = repository_path(
        root,
        contract["runnerImplementation"]["sourceValidatorPath"],
    )
    describe_process = subprocess.run(
        [
            sys.executable,
            str(source_validator_path),
            "--repository-root",
            str(root),
            "--contract",
            str(contract_path.relative_to(root)),
            "--mode",
            "describe",
        ],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
        env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
    )
    try:
        describe_report = json.loads(describe_process.stdout)
    except json.JSONDecodeError:
        describe_report = {
            "passed": False,
            "parseError": describe_process.stdout,
            "stderr": describe_process.stderr,
        }
    describe_pass = (
        describe_process.returncode == 0
        and describe_report.get("passed") is True
        and describe_report.get("pixelFilesRead") == 0
        and describe_report.get("nonAliasInput", {}).get(
            "forbiddenDecodedRgbaSha256Count"
        )
        == 44
        and describe_report.get("pngDecoder", {}).get("pillowImported") is False
        and describe_report.get("sourceStageSchema", {}).get("state")
        == "pending_integration_v2"
        and describe_report.get("sourceStageSchema", {}).get("path") is None
        and describe_report.get("sourceStageSchema", {}).get("sha256") is None
    )

    missing_decisions = {
        mode: runner.evaluate_render_guard(root, contract, mode)
        for mode in modes
    }
    missing_pass = all(
        decision["decision"] == "reject"
        and decision["rejectionStage"] == "before_renderer_launch"
        and "appearance-lock:missing" in decision["reasonCodes"]
        and not any(
            code.startswith("coordinate-bridge:")
            for code in decision["reasonCodes"]
        )
        and all(value == 0 for key, value in decision.items() if key.endswith("Invocations") or key.endswith("Calls") or key == "pixelFiles")
        for decision in missing_decisions.values()
    )

    wrong_contract = copy.deepcopy(contract)
    wrong_contract["state"] = "ready_for_source_render"
    wrong_contract["appearanceLock"] = {
        "documentPath": contract["authority"]["path"],
        "commit": contract["baselineCommit"],
        "documentSha256": "0" * 64,
        "northProcessASourceSha256": "1" * 64,
        "northProcessADecodedRgbaSha256": "2" * 64,
    }
    wrong_contract["appearanceLockCommit"] = contract["baselineCommit"]
    wrong_contract["appearanceLockSha256"] = "0" * 64
    wrong_contract["lockedMaterialMapping"] = {
        "path": contract["acceptedPredesign"]["materials"]["path"],
        "sha256": "3" * 64,
        "requiredSchema": contract["lockedMaterialMapping"]["requiredSchema"],
    }
    wrong_decisions = {
        mode: runner.evaluate_render_guard(root, wrong_contract, mode)
        for mode in modes
    }
    wrong_pass = all(
        decision["decision"] == "reject"
        and decision["rejectionStage"] == "before_renderer_launch"
        and "appearance-lock:document-sha256-mismatch" in decision["reasonCodes"]
        and "locked-materials:sha256-mismatch" in decision["reasonCodes"]
        and "appearance-lock:missing" not in decision["reasonCodes"]
        and not any(
            code.startswith("coordinate-bridge:")
            for code in decision["reasonCodes"]
        )
        and all(value == 0 for key, value in decision.items() if key.endswith("Invocations") or key.endswith("Calls") or key == "pixelFiles")
        for decision in wrong_decisions.values()
    )

    stale_bridge_contract = copy.deepcopy(contract)
    stale_bridge_contract["coordinateBridge"]["v06"]["integratedProofCommit"] = (
        stale_bridge_contract["coordinateBridge"]["v06"]["sourceCandidateCommit"]
    )
    stale_bridge_decisions = {
        mode: runner.evaluate_render_guard(root, stale_bridge_contract, mode)
        for mode in modes
    }
    integrated_proof_guard_pass = all(
        decision["decision"] == "reject"
        and decision["rejectionStage"] == "before_renderer_launch"
        and "coordinate-bridge:integrated-proof-execution-authority"
        in decision["reasonCodes"]
        and all(
            value == 0
            for key, value in decision.items()
            if key.endswith("Invocations")
            or key.endswith("Calls")
            or key == "pixelFiles"
        )
        for decision in stale_bridge_decisions.values()
    )

    coordinate_bridge = contract["coordinateBridge"]
    canonical = coordinate_bridge["canonicalCitySim"]
    historical = coordinate_bridge["historicalProjectionAdapter"]
    bridge_v06 = coordinate_bridge["v06"]
    blender_script_source = blender_script_path.read_text()
    coordinate_bridge_pass = (
        coordinate_bridge["state"] == "validated_v06"
        and coordinate_bridge["holdIsStop"] is False
        and canonical["frontageSocketWorldXYZ"] == [-28, 0, 0]
        and canonical["frontageSocketExpectedSource"] == [640, 704]
        and historical["futureSourceAuthority"] is False
        and historical["authorityScope"] == "retained-predesign-proof-only"
        and bridge_v06["authorityCommit"]
        == "3e01ca6738d7574718f9aeff4b66771eee109feb"
        and bridge_v06["sourceCandidateCommit"]
        == "3e01ca6738d7574718f9aeff4b66771eee109feb"
        and bridge_v06["integratedProofCommit"]
        == "3d76fab8a45807c34198a6d8bb1dd1eeff7be51e"
        and runner._commit_is_ancestor(
            root,
            bridge_v06["integratedProofCommit"],
        )
        and bridge_v06["mappingContractSha256"]
        == "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
        and bridge_v06["basisFormula"]
        == "B(CitySim[x,y,z])=Blender[z,x,y]"
        and bridge_v06["sourceOrder"] == [0, 1, 2, 3]
        and bridge_v06["frontageSocketCitySimXYZ"] == [-28, 0, 0]
        and bridge_v06["frontageSocketBlenderXYZ"] == [0, -28, 0]
        and bridge_v06["frontageSocketSourceXY"] == [640, 704]
        and bridge_v06["perDirectionTransform"] is False
        and bridge_v06["windingChange"] is False
        and "actualCameraProofScript" not in blender_script_source
        and "load_accepted_builder" not in blender_script_source
    )
    proof_paths = {
        name: repository_path(root, contract["outputInventory"]["validation"][key])
        for name, key in (
            ("runA", "bridgeActualCameraRunA"),
            ("runB", "bridgeActualCameraRunB"),
        )
    }
    proof_records = {
        name: json.loads(path.read_text()) if path.is_file() else {}
        for name, path in proof_paths.items()
    }
    proof_hashes = {
        name: sha256(path) if path.is_file() else None
        for name, path in proof_paths.items()
    }
    proof_checks = {
        name: (
            record.get("passed") is True
            and record.get("acceptedBridgeCandidate")
            == bridge_v06["sourceCandidateCommit"]
            and record.get("mappingContractSha256")
            == bridge_v06["mappingContractSha256"]
            and record.get("basisFormula") == bridge_v06["basisFormula"]
            and record.get("sourceOrder") == bridge_v06["sourceOrder"]
            and record.get("west", {}).get("socketCitySim") == [-28, 0, 0]
            and record.get("west", {}).get("socketBlender") == [0.0, -28.0, 0.0]
            and record.get("west", {}).get("socketExpectedSource") == [640, 704]
            and record.get("invocations", {}).get("blenderRenderApiCalls") == 0
            and record.get("invocations", {}).get("renderInvocations") == 0
            and record.get("invocations", {}).get("pixelFiles") == 0
        )
        for name, record in proof_records.items()
    }
    bridge_repeat_pass = (
        all(proof_checks.values())
        and proof_paths["runA"].read_bytes() == proof_paths["runB"].read_bytes()
        and proof_hashes["runA"] == proof_hashes["runB"]
    )
    bridge_repeat_report = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "proof": "V06_ACTUAL_CAMERA_REPEAT_IDENTITY",
        "runA": {
            "path": str(proof_paths["runA"].relative_to(root)),
            "sha256": proof_hashes["runA"],
            "passed": proof_checks["runA"],
        },
        "runB": {
            "path": str(proof_paths["runB"].relative_to(root)),
            "sha256": proof_hashes["runB"],
            "passed": proof_checks["runB"],
        },
        "byteIdentical": (
            proof_paths["runA"].is_file()
            and proof_paths["runB"].is_file()
            and proof_paths["runA"].read_bytes()
            == proof_paths["runB"].read_bytes()
        ),
        "invocations": {
            "blenderProjectionProcesses": 2,
            "blenderRenderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "renderInvocations": 0,
            "pixelFiles": 0,
        },
        "sourceReady": False,
        "productionSelected": False,
        "passed": bridge_repeat_pass,
    }
    static_checks = {
        "frozenInputHashes": not frozen_errors,
        "frozenInputErrors": frozen_errors,
        "controlFlow": control_flow,
        "sourceAndEvidencePixelFiles": pixel_paths,
        "pixelFiles": pixel_count,
        "acceptedPredesignUnmodified": not frozen_errors,
        "blenderScriptPresentButNotImported": (
            blender_script_path.is_file() and not control_flow["driverImportsBpy"]
        ),
        "coordinateBridgeAdoption": {
            "state": coordinate_bridge["state"],
            "holdIsStop": coordinate_bridge["holdIsStop"],
            "canonicalWestSocketWorldXYZ": canonical[
                "frontageSocketWorldXYZ"
            ],
            "canonicalWestSocketSource": canonical[
                "frontageSocketExpectedSource"
            ],
            "historicalAdapterFutureSourceAuthority": historical[
                "futureSourceAuthority"
            ],
            "historicalAdapterLoadedByBlenderScript": (
                "actualCameraProofScript" in blender_script_source
                or "load_accepted_builder" in blender_script_source
            ),
            "sourceCandidateProvenance": bridge_v06["sourceCandidateCommit"],
            "integratedProofExecutionAuthority": bridge_v06[
                "integratedProofCommit"
            ],
            "mappingContractSha256": bridge_v06["mappingContractSha256"],
            "canonicalWestSocketBlenderXYZ": bridge_v06[
                "frontageSocketBlenderXYZ"
            ],
            "sourceOrder": bridge_v06["sourceOrder"],
            "actualCameraProofs": proof_checks,
            "actualCameraProofsByteIdentical": bridge_repeat_report[
                "byteIdentical"
            ],
            "passed": coordinate_bridge_pass,
        },
        "sourceValidatorDescribe": {
            "returnCode": describe_process.returncode,
            "nonAliasMasterCount": describe_report.get(
                "nonAliasInput",
                {},
            ).get("forbiddenDecodedRgbaSha256Count"),
            "pngDecoder": describe_report.get("pngDecoder"),
            "sourceStageSchema": describe_report.get("sourceStageSchema"),
            "passed": describe_pass,
        },
        "integratedProofExecutionGuard": {
            "requiredCommit": bridge_v06["integratedProofCommit"],
            "sourceCandidateProvenance": bridge_v06[
                "sourceCandidateCommit"
            ],
            "sourceCandidateSubstitutionRejected": integrated_proof_guard_pass,
            "passed": integrated_proof_guard_pass,
        },
    }
    static_pass = (
        not frozen_errors
        and control_flow["passed"]
        and pixel_count == 0
        and blender_script_path.is_file()
        and coordinate_bridge_pass
        and bridge_repeat_pass
        and describe_pass
        and integrated_proof_guard_pass
    )
    common = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "baselineCommit": contract["baselineCommit"],
        "runnerContractSha256": sha256(contract_path),
        "driverSha256": sha256(driver_path),
        "blenderScriptSha256": sha256(blender_script_path),
        "coordinateBridgeState": coordinate_bridge["state"],
        "rejectionStage": "before_renderer_launch",
        **zero_counts(),
    }
    static_report = {
        **common,
        "proof": "PRELOCK_RUNNER_STATIC",
        "bridgeProjectionProcessLaunches": 2,
        "checks": static_checks,
        "validation": {
            "runnerStatic": "pass" if static_pass else "fail",
            "sourceValidatorDescribe": "pass" if describe_pass else "fail",
            "integratedProofGuard": (
                "pass" if integrated_proof_guard_pass else "fail"
            ),
            "sourceStageSchema": "not_run_pending_integration_v2",
            "rgba": "not_run",
            "literal192": "not_run",
            "abcIdentity": "not_run",
            "normalization": "not_run",
        },
        "passed": static_pass,
    }
    missing_report = {
        **common,
        "proof": "MISSING_APPEARANCE_LOCK_REJECTION",
        "modes": missing_decisions,
        "missingAppearanceLockFields": [
            "appearanceLock.documentPath",
            "appearanceLock.commit",
            "appearanceLock.documentSha256",
            "appearanceLock.northProcessASourceSha256",
            "appearanceLock.northProcessADecodedRgbaSha256",
            "appearanceLockCommit",
            "appearanceLockSha256",
            "lockedMaterialMapping.path",
            "lockedMaterialMapping.sha256",
        ],
        "coordinateBridgeState": "validated_v06",
        "remainingBlockers": [
            "Integration source-stage schema v2 is not published",
            "North process-A appearance lock is not published"
        ],
        "passed": missing_pass,
    }
    wrong_report = {
        **common,
        "proof": "WRONG_APPEARANCE_LOCK_REJECTION",
        "testBinding": {
            "documentPath": wrong_contract["appearanceLock"]["documentPath"],
            "deliberatelyWrongDocumentSha256": wrong_contract["appearanceLock"][
                "documentSha256"
            ],
            "deliberatelyWrongMaterialSha256": wrong_contract[
                "lockedMaterialMapping"
            ]["sha256"],
        },
        "coordinateBridgeState": "validated_v06",
        "remainingBlockers": [
            "Integration source-stage schema v2 is not published",
            "North process-A appearance lock is not published"
        ],
        "modes": wrong_decisions,
        "passed": wrong_pass,
    }
    integrated_proof_guard_report = {
        **common,
        "proof": "INTEGRATED_V06_PROOF_EXECUTION_GUARD",
        "requiredIntegratedProofCommit": bridge_v06["integratedProofCommit"],
        "sourceCandidateProvenanceCommit": bridge_v06[
            "sourceCandidateCommit"
        ],
        "testMutation": "substitute source candidate for integrated proof",
        "modes": stale_bridge_decisions,
        "passed": integrated_proof_guard_pass,
    }
    source_stage_schema_gate = {
        **common,
        "proof": "SOURCE_STAGE_SCHEMA_HOLD",
        "state": "not_run_pending_integration_v2",
        "binding": contract["sourceStage"]["handoffSchema"],
        "v1FinalBindingDeclared": False,
        "candidatePacketValidation": "not_run",
        "placeholderHashesUsed": False,
        "renderModesRemainClosed": True,
        "passed": (
            contract["sourceStage"]["handoffSchema"]
            == {
                "state": "pending_integration_v2",
                "path": None,
                "sha256": None,
            }
        ),
    }
    reports = {
        "RUNNER-STATIC-VALIDATION.json": static_report,
        "MISSING-LOCK-REJECTION.json": missing_report,
        "WRONG-LOCK-REJECTION.json": wrong_report,
        "BRIDGE-REPEAT-IDENTITY.json": bridge_repeat_report,
        "SOURCE-VALIDATOR-DESCRIBE.json": describe_report,
        "INTEGRATED-PROOF-GUARD.json": integrated_proof_guard_report,
        "SOURCE-STAGE-SCHEMA-GATE.json": source_stage_schema_gate,
    }
    for name, report in reports.items():
        (output / name).write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n"
        )
    return (
        0
        if (
            static_pass
            and missing_pass
            and wrong_pass
            and integrated_proof_guard_pass
            and describe_pass
            and source_stage_schema_gate["passed"]
        )
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
