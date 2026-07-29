#!/usr/bin/env python3
"""Zero-pixel validation for the PLAY-081 pre-lock runner boundary."""

from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import importlib.util
import json
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

    missing_decisions = {
        mode: runner.evaluate_render_guard(root, contract, mode)
        for mode in modes
    }
    missing_pass = all(
        decision["decision"] == "reject"
        and decision["rejectionStage"] == "before_renderer_launch"
        and "appearance-lock:missing" in decision["reasonCodes"]
        and "coordinate-bridge:pending-v06" in decision["reasonCodes"]
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
        and "coordinate-bridge:pending-v06" in decision["reasonCodes"]
        and all(value == 0 for key, value in decision.items() if key.endswith("Invocations") or key.endswith("Calls") or key == "pixelFiles")
        for decision in wrong_decisions.values()
    )

    coordinate_bridge = contract["coordinateBridge"]
    canonical = coordinate_bridge["canonicalCitySim"]
    historical = coordinate_bridge["historicalProjectionAdapter"]
    blender_script_source = blender_script_path.read_text()
    coordinate_bridge_pass = (
        coordinate_bridge["state"] == "pending_v06_revalidation"
        and coordinate_bridge["holdIsStop"] is False
        and canonical["frontageSocketWorldXYZ"] == [-28, 0, 0]
        and canonical["frontageSocketExpectedSource"] == [640, 704]
        and historical["futureSourceAuthority"] is False
        and historical["authorityScope"] == "retained-predesign-proof-only"
        and all(value is None for value in coordinate_bridge["v06"].values())
        and "actualCameraProofScript" not in blender_script_source
        and "load_accepted_builder" not in blender_script_source
    )
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
        "coordinateBridgeHold": {
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
            "passed": coordinate_bridge_pass,
        },
    }
    static_pass = (
        not frozen_errors
        and control_flow["passed"]
        and pixel_count == 0
        and blender_script_path.is_file()
        and coordinate_bridge_pass
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
        "checks": static_checks,
        "validation": {
            "runnerStatic": "pass" if static_pass else "fail",
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
        "coordinateBridgeBlocker": "v06 coordinate projection and contact-corner revalidation is pending",
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
        "coordinateBridgeBlocker": "v06 coordinate projection and contact-corner revalidation is pending",
        "modes": wrong_decisions,
        "passed": wrong_pass,
    }
    reports = {
        "RUNNER-STATIC-VALIDATION.json": static_report,
        "MISSING-LOCK-REJECTION.json": missing_report,
        "WRONG-LOCK-REJECTION.json": wrong_report,
    }
    for name, report in reports.items():
        (output / name).write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n"
        )
    return 0 if static_pass and missing_pass and wrong_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
