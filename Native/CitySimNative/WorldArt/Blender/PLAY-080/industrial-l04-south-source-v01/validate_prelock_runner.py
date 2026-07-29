#!/usr/bin/env python3
"""Prove the PLAY-080 runner guards without launching Blender or producing pixels."""

from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
DEFAULT_CONTRACT = SOURCE_DIR / "runner-contract.json"
DEFAULT_DRIVER = SOURCE_DIR / "run_production.py"
DEFAULT_EVIDENCE_ROOT = (
    REPOSITORY_ROOT
    / "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01"
)
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr", ".webp"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--driver", type=Path, default=DEFAULT_DRIVER)
    parser.add_argument("--evidence-root", type=Path, default=DEFAULT_EVIDENCE_ROOT)
    parser.add_argument("--hold-static-only", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def display_path(path: Path, ephemeral_label: str) -> str:
    try:
        return path.resolve().relative_to(REPOSITORY_ROOT).as_posix()
    except ValueError:
        return f"<{ephemeral_label}>"


def run_driver(driver: Path, contract: Path, mode: str) -> tuple[int, dict[str, Any], str]:
    command = [
        sys.executable,
        str(driver),
        "--mode",
        mode,
        "--contract",
        str(contract),
    ]
    completed = subprocess.run(
        command,
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    payload = json.loads(completed.stdout)
    display_command = " ".join(
        (
            "python3",
            display_path(driver, "driver"),
            "--mode",
            mode,
            "--contract",
            display_path(contract, "ephemeral-contract"),
        )
    )
    return completed.returncode, payload, display_command


def inspect_driver(driver: Path) -> dict[str, Any]:
    driver_text = driver.read_text(encoding="utf-8")
    tree = ast.parse(driver_text, filename=str(driver))
    top_level_bpy_imports = []
    render_function: ast.FunctionDef | None = None
    main_function: ast.FunctionDef | None = None
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            names = [alias.name for alias in node.names]
            if any(name == "bpy" or name.startswith("bpy.") for name in names):
                top_level_bpy_imports.extend(names)
        if isinstance(node, ast.FunctionDef) and node.name == "render_source":
            render_function = node
        if isinstance(node, ast.FunctionDef) and node.name == "main":
            main_function = node

    if render_function is None or main_function is None:
        raise AssertionError("driver must define render_source and main")

    render_source_text = ast.get_source_segment(driver_text, render_function) or ""
    main_text = ast.get_source_segment(driver_text, main_function) or ""
    require_lock_index = main_text.find("require_lock(contract)")
    require_bridge_index = main_text.find("require_coordinate_bridge(contract)")
    render_index = main_text.find("render_source(contract")
    checks = {
        "noTopLevelBpyImport": not top_level_bpy_imports,
        "driverCannotLaunchBlenderProcess": (
            "import subprocess" not in driver_text
            and "subprocess." not in driver_text
            and "Popen(" not in driver_text
        ),
        "bpyImportIsRenderLocal": "import bpy" in render_source_text,
        "twoRenderApiCallsAreRenderLocal": (
            render_source_text.count("bpy.ops.render.render(write_still=True)") == 2
        ),
        "semanticAndProvenanceOutputsBound": (
            'contract["outputInventory"]["semantic"][mode]' in render_source_text
            and 'contract["outputInventory"]["provenance"][mode]' in render_source_text
        ),
        "guardPrecedesRenderFunctionCall": (
            require_lock_index >= 0
            and require_bridge_index > require_lock_index
            and render_index > require_bridge_index
        ),
        "canonicalSouthSocketRetained": (
            '"canonicalCitySimFrontageSocket": [0, 0, 28]' in driver_text
            and '"sourceSocketPixels": [640, 832]' in driver_text
        ),
        "noHardCodedBlenderDirectionalSocket": (
            '"blenderNativeDirectionalSocket": coordinate_bridge[' in driver_text
        ),
        "separateModes": all(
            f'"{mode}"' in driver_text for mode in ("validate", "A", "B", "C")
        ),
    }
    return {"result": "PASS" if all(checks.values()) else "FAIL", "checks": checks}


def pixel_files(root: Path) -> list[str]:
    if not root.exists():
        return []
    return sorted(
        path.relative_to(REPOSITORY_ROOT).as_posix()
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES
    )


def zero_counters(payload: dict[str, Any]) -> bool:
    keys = (
        "blenderProcessLaunches",
        "blenderRenderApiCalls",
        "imageGenInvocations",
        "normalizerInvocations",
        "contactSheetInvocations",
        "renderInvocations",
        "pixelFiles",
    )
    return all(payload.get(key) == 0 for key in keys)


def main() -> int:
    args = parse_args()
    contract = load_json(args.contract)
    bridge_state = contract.get("coordinateBridge", {}).get("state")
    source_root = SOURCE_DIR
    evidence_root = args.evidence_root.resolve()
    before_pixels = pixel_files(source_root) + pixel_files(evidence_root)
    if before_pixels:
        raise AssertionError(f"exclusive roots already contain pixel files: {before_pixels}")

    static_inspection = inspect_driver(args.driver)
    validate_one = run_driver(args.driver, args.contract, "validate")
    validate_two = run_driver(args.driver, args.contract, "validate")

    contract_display = args.contract.resolve().relative_to(REPOSITORY_ROOT).as_posix()
    runner_hash = sha256(args.contract)
    if args.hold_static_only:
        retained_missing = load_json(evidence_root / "MISSING-LOCK-REJECTION.json")
        retained_wrong = load_json(evidence_root / "WRONG-LOCK-REJECTION.json")
        missing_one = (
            retained_missing["exitCode"],
            retained_missing["driverResult"],
            retained_missing["command"],
        )
        missing_two = missing_one
        wrong_one = (
            retained_wrong["exitCode"],
            retained_wrong["driverResult"],
            retained_wrong["command"],
        )
        wrong_two = wrong_one
    else:
        missing_one = run_driver(args.driver, args.contract, "A")
        missing_two = run_driver(args.driver, args.contract, "A")
        wrong_contract = copy.deepcopy(contract)
        wrong_contract["appearanceLock"] = {
            "documentPath": contract_display,
            "appearanceLockCommit": "0" * 40,
            "appearanceLockSha256": runner_hash,
            "northProcessASourceSha256": "1" * 64,
            "northProcessADecodedRgbaSha256": "2" * 64,
        }
        wrong_contract["lockedMaterialMapping"]["path"] = contract_display
        wrong_contract["lockedMaterialMapping"]["sha256"] = runner_hash
        wrong_contract["postLockProductionAuthority"] = {
            "path": contract_display,
            "commit": "3" * 40,
            "sha256": runner_hash,
        }
        with tempfile.TemporaryDirectory(prefix="play080-prelock-") as temporary:
            wrong_path = Path(temporary) / "wrong-lock-contract.json"
            write_json(wrong_path, wrong_contract)
            wrong_one = run_driver(args.driver, wrong_path, "A")
            wrong_two = run_driver(args.driver, wrong_path, "A")

    validate_ok = (
        validate_one[0] == 0
        and validate_one[1].get("result") == "PASS"
        and zero_counters(validate_one[1])
    )
    missing_ok = (
        missing_one[0] == 2
        and missing_one[1].get("result") == "REJECTED"
        and missing_one[1].get("rejection", {}).get("code")
        == "MISSING_APPEARANCE_LOCK"
        and missing_one[1].get("rejectionStage") == "before_renderer_launch"
        and zero_counters(missing_one[1])
    )
    wrong_ok = (
        wrong_one[0] == 2
        and wrong_one[1].get("result") == "REJECTED"
        and wrong_one[1].get("rejection", {}).get("code") == "WRONG_APPEARANCE_LOCK"
        and wrong_one[1].get("rejectionStage") == "before_renderer_launch"
        and zero_counters(wrong_one[1])
    )
    repeat_ok = (
        validate_one[:2] == validate_two[:2]
        and missing_one[:2] == missing_two[:2]
        and wrong_one[:2] == wrong_two[:2]
    )

    missing_evidence = {
        "schema": "citysim.play-080.prelock-guard-evidence.v1",
        "case": "missing-appearance-lock",
        "command": missing_one[2],
        "exitCode": missing_one[0],
        "expectedExitCode": 2,
        "result": "PASS" if missing_ok else "FAIL",
        "driverResult": missing_one[1],
    }
    wrong_evidence = {
        "schema": "citysim.play-080.prelock-guard-evidence.v1",
        "case": "wrong-appearance-lock",
        "fixture": "ephemeral contract bound to the runner contract instead of an appearance lock",
        "command": (
            "python3 "
            f"{display_path(args.driver, 'driver')} "
            "--mode A --contract <ephemeral-wrong-lock-contract>"
        ),
        "exitCode": wrong_one[0],
        "expectedExitCode": 2,
        "result": "PASS" if wrong_ok else "FAIL",
        "driverResult": wrong_one[1],
    }
    static_evidence = {
        "schema": "citysim.play-080.prelock-runner-static-validation.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "baselineCommit": contract["baselineCommit"],
        "contractPath": contract_display,
        "contractSha256": runner_hash,
        "driverPath": args.driver.resolve().relative_to(REPOSITORY_ROOT).as_posix(),
        "driverSha256": sha256(args.driver),
        "staticInspection": static_inspection,
        "validateMode": {
            "command": validate_one[2],
            "exitCode": validate_one[0],
            "result": "PASS" if validate_ok else "FAIL",
            "driverResult": validate_one[1],
        },
        "repeatIdentityPass": repeat_ok,
        "coordinateBridgeRevalidation": bridge_state,
        "coordinateBridgeBlocker": (
            "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/"
            "COORDINATE-BRIDGE-V06-BLOCKER.json"
        ),
        "guardEvidenceExecution": (
            "retained-no-A-B-C-invocation" if args.hold_static_only else "fresh"
        ),
        "pixelValidations": {
            "rgba": "not_run",
            "literal192": "not_run",
            "abcIdentity": "not_run",
            "normalization": "not_run",
        },
    }

    write_json(evidence_root / "MISSING-LOCK-REJECTION.json", missing_evidence)
    write_json(evidence_root / "WRONG-LOCK-REJECTION.json", wrong_evidence)
    write_json(evidence_root / "RUNNER-STATIC-VALIDATION.json", static_evidence)

    after_pixels = pixel_files(source_root) + pixel_files(evidence_root)
    overall = (
        static_inspection["result"] == "PASS"
        and validate_ok
        and missing_ok
        and wrong_ok
        and repeat_ok
        and not after_pixels
    )
    addendum = {
        "schema": "citysim.play-080.prelock-runner-validation-addendum.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "result": "PASS" if overall else "FAIL",
        "runnerStaticPass": static_inspection["result"] == "PASS" and validate_ok,
        "guardPass": missing_ok and wrong_ok,
        "repeatIdentityPass": repeat_ok,
        "coordinateBridgeRevalidation": bridge_state,
        "coordinateBridgeBlocker": (
            "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/"
            "COORDINATE-BRIDGE-V06-BLOCKER.json"
        ),
        "guardEvidenceExecution": (
            "retained-no-A-B-C-invocation" if args.hold_static_only else "fresh"
        ),
        "guardEvidence": {
            "missingLockRejected": missing_ok,
            "wrongLockRejected": wrong_ok,
            "rejectionStage": "before_renderer_launch",
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "renderInvocations": 0,
            "pixelFiles": len(after_pixels),
        },
        "pixelFilesBefore": before_pixels,
        "pixelFilesAfter": after_pixels,
        "pixelValidations": {
            "rgba": "not_run",
            "literal192": "not_run",
            "abcIdentity": "not_run",
            "normalization": "not_run",
        },
    }
    write_json(evidence_root / "VALIDATION-ADDENDUM.json", addendum)
    print(json.dumps({"result": addendum["result"], "evidenceRoot": str(evidence_root)}))
    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
