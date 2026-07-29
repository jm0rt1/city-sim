#!/usr/bin/env python3
"""Validate the authorized PLAY-080 non-schema prelock repair.

The guard is exercised by direct function calls, never by invoking A/B/C.
Source-schema v1 is intentionally held and no Blender or pixel process starts.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import run_production
from jsonschema import Draft202012Validator


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
DEFAULT_CONTRACT = SOURCE_DIR / "runner-contract.json"
DEFAULT_SOURCE_VALIDATOR = SOURCE_DIR / "validate_source_outputs.py"
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr", ".webp"}
ACCEPTED_BLENDER_SHA256 = (
    "8485107307b16bd0899f3c259261494b0c80e383db239c04e2c9fcd14d305fb4"
)
SOURCE_SCHEMA_V1 = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-stage-handoff-schema-v1.json"
)
SOURCE_SCHEMA_V2 = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-stage-handoff-schema-v2.json"
)
SOURCE_SCHEMA_V2_SHA256 = (
    "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7"
)
EXPECTED_SHARED_BINDINGS = {
    "sourceStageHandoffSchema": {
        "path": SOURCE_SCHEMA_V2,
        "sha256": SOURCE_SCHEMA_V2_SHA256,
    },
    "nonAliasLoader": {
        "path": "Native/CitySimNative/WorldArt/Shared/accepted_master_non_alias_v1.py",
        "sha256": "2c44bc3a4ffe3fdfc68a477b70f3af9478122e9b796543f32a154859ac300a39",
    },
    "semanticValidator": {
        "path": "Native/CitySimNative/WorldArt/Shared/validate_source_stage_handoff_v2.py",
        "sha256": "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340",
    },
    "canonicalDecoder": {
        "path": "Native/CitySimNative/WorldArt/Shared/canonical_rgba_v1.swift",
        "sha256": "2be2b57d0c9bb73e8a4438c69aa4230eba08c4b87937fae4d4e048244b9beaab",
    },
}


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def display_path(path: Path) -> str:
    return path.resolve().relative_to(REPOSITORY_ROOT).as_posix()


def pixel_files(*roots: Path) -> list[str]:
    return sorted(
        path.relative_to(REPOSITORY_ROOT).as_posix()
        for root in roots
        if root.exists()
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES
    )


def guard_code(function: Any, contract: dict[str, Any]) -> str:
    try:
        function(contract)
    except run_production.GuardRejected as rejection:
        return rejection.code
    return "NOT_REJECTED"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--source-validator", type=Path, default=DEFAULT_SOURCE_VALIDATOR)
    parser.add_argument("--evidence-root", type=Path, required=True)
    args = parser.parse_args()

    contract = load_json(args.contract)
    evidence_root = args.evidence_root.resolve()
    before_pixels = pixel_files(SOURCE_DIR, evidence_root)

    static_checks: dict[str, bool] = {}
    try:
        run_production.validate_contract_shape(contract)
        static_checks["runnerContractShapeAndFrozenInputs"] = True
    except run_production.GuardRejected:
        static_checks["runnerContractShapeAndFrozenInputs"] = False

    blender_sha = contract["invariants"]["render"]["blenderExecutableSha256"]
    static_checks["acceptedBlenderFingerprint"] = (
        blender_sha == ACCEPTED_BLENDER_SHA256 and len(blender_sha) == 64
    )
    non_alias = contract["authorities"]["nonAliasInput"]
    static_checks["common44MasterNonAliasInputBound"] = (
        non_alias["path"]
        == "docs/production/evidence/INTEGRATION/"
        "industrial-l04-accepted-master-non-alias-input-v1.json"
        and non_alias["sha256"]
        == "c281dd8f3527363ad3ff56746f50e9110b2166898bdf4918ed628b5a429d27fb"
    )
    static_checks["sourceStageV2AndSharedToolsBound"] = all(
        contract["authorities"].get(key) == value
        for key, value in EXPECTED_SHARED_BINDINGS.items()
    )

    driver_text = (SOURCE_DIR / "run_production.py").read_text(encoding="utf-8")
    semantic_text = (SOURCE_DIR / "literal192_semantic_proof.py").read_text(
        encoding="utf-8"
    )
    owned_text = "\n".join(
        path.read_text(encoding="utf-8")
        for path in SOURCE_DIR.iterdir()
        if path.is_file() and path.suffix in {".py", ".json"}
    )
    static_checks["literalPlaceholderRemoved"] = (
        "requires-post-render-v06-measurement" not in driver_text
    )
    static_checks["deterministicFiveFieldSemanticProofBound"] = (
        "measure_literal192_semantic_proof" in driver_text
        and "primaryPortalPixels" in semantic_text
        and "freightOpeningWidthsPixels" in semantic_text
        and "frameMinimumThicknessPixels" in semantic_text
        and "silhouetteBreaks" in semantic_text
        and "processOcclusionPixels" in semantic_text
    )
    static_checks["sourceSchemaV1FinalBindingAbsent"] = SOURCE_SCHEMA_V1 not in owned_text

    describe_command = [
        sys.executable,
        str(args.source_validator),
        "--mode",
        "describe",
        "--contract",
        str(args.contract),
    ]
    describe = subprocess.run(
        describe_command,
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    describe_payload = json.loads(describe.stdout)
    describe_ok = (
        describe.returncode == 0
        and describe_payload.get("literal192Measurement")
        == "analytic-v06-camera-semantic-cells-v1"
        and describe_payload.get("literal192FiveFieldValidator")
        == [
            "primaryPortalPixels",
            "freightOpeningWidthsPixels",
            "frameMinimumThicknessPixels",
            "silhouetteBreaks",
            "processOcclusionPixels",
        ]
        and describe_payload.get("nonAliasInput") == non_alias
        and all(
            describe_payload.get(key) == "not_run"
            for key in ("rgba", "literal192", "abcIdentity", "normalization")
        )
    )

    missing_profile_code = guard_code(
        run_production.require_source_production_profile, contract
    )
    missing_code = guard_code(run_production.require_lock, contract)
    wrong_contract = copy.deepcopy(contract)
    contract_hash = sha256(args.contract)
    contract_display = display_path(args.contract)
    wrong_contract["appearanceLock"] = {
        "documentPath": contract_display,
        "appearanceLockCommit": "0" * 40,
        "appearanceLockSha256": contract_hash,
        "northProcessASourceSha256": "1" * 64,
        "northProcessADecodedRgbaSha256": "2" * 64,
    }
    wrong_contract["lockedMaterialMapping"]["path"] = contract_display
    wrong_contract["lockedMaterialMapping"]["sha256"] = contract_hash
    wrong_contract["postLockProductionAuthority"] = {
        "path": contract_display,
        "commit": "3" * 40,
        "sha256": contract_hash,
    }
    wrong_code = guard_code(run_production.require_lock, wrong_contract)
    guard_ok = (
        missing_profile_code == "MISSING_SOURCE_PRODUCTION_PROFILE"
        and
        missing_code == "MISSING_APPEARANCE_LOCK"
        and wrong_code == "WRONG_APPEARANCE_LOCK"
    )

    schema_record = contract["authorities"]["sourceStageHandoffSchema"]
    schema_path = REPOSITORY_ROOT / schema_record["path"]
    schema_ok = False
    schema_error = None
    try:
        if sha256(schema_path) != SOURCE_SCHEMA_V2_SHA256:
            raise ValueError("source-stage schema v2 hash mismatch")
        schema = load_json(schema_path)
        Draft202012Validator.check_schema(schema)
        if schema.get("$id") != (
            "citysim://integration/industrial-l04-source-stage-handoff-v2"
        ):
            raise ValueError("source-stage schema v2 id mismatch")
        schema_ok = True
    except Exception as error:  # fail closed in the evidence receipt
        schema_error = str(error)

    after_pixels = pixel_files(SOURCE_DIR, evidence_root)
    overall = (
        all(static_checks.values())
        and describe_ok
        and guard_ok
        and schema_ok
        and not before_pixels
        and not after_pixels
    )
    report = {
        "schema": "citysim.play-080.prelock-repair-validation.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "baselineCommit": contract["baselineCommit"],
        "result": "PASS" if overall else "FAIL",
        "static": {
            "result": "PASS" if all(static_checks.values()) else "FAIL",
            "checks": static_checks,
        },
        "describe": {
            "result": "PASS" if describe_ok else "FAIL",
            "command": (
                "python3 "
                f"{display_path(args.source_validator)} --mode describe "
                f"--contract {display_path(args.contract)}"
            ),
            "exitCode": describe.returncode,
            "payload": describe_payload,
        },
        "guard": {
            "result": "PASS" if guard_ok else "FAIL",
            "execution": "direct-function-no-A-B-C-mode",
            "missingSourceProductionProfileRejection": missing_profile_code,
            "missingAppearanceLockRejection": missing_code,
            "wrongAppearanceLockRejection": wrong_code,
            "rejectionStage": "before_renderer_launch",
        },
        "schemaGate": {
            "result": "PASS" if schema_ok else "FAIL",
            "state": "source_stage_schema_v2_bound",
            "path": SOURCE_SCHEMA_V2,
            "sha256": SOURCE_SCHEMA_V2_SHA256,
            "documentValidation": "PASS" if schema_ok else "FAIL",
            "error": schema_error,
            "sourceSchemaV1FinalBinding": False,
            "sourceSchemaV1Validation": "not_run",
            "launchBoundInstanceValidation": (
                "not_run_missing_source_production_profile"
            ),
        },
        "pixelValidations": {
            "rgba": "not_run",
            "literal192": "not_run",
            "abcIdentity": "not_run",
            "normalization": "not_run",
        },
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "renderInvocations": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "pixelFilesBefore": before_pixels,
        "pixelFilesAfter": after_pixels,
        "processA": "not_run",
        "processB": "not_run",
        "processC": "not_run",
        "sourceReady": False,
        "productionSelected": False,
        "selfAccepted": False,
    }
    evidence_root.mkdir(parents=True, exist_ok=True)
    output = evidence_root / "PRELOCK-REPAIR-VALIDATION.json"
    output.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    binding_receipt = {
        "schema": "citysim.play-080.source-stage-v2-schema-binding.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "publishedBaseline": contract["baselineCommit"],
        "result": "PASS" if schema_ok and guard_ok else "FAIL",
        "sourceStageSchema": schema_record,
        "sharedBindings": {
            key: contract["authorities"][key]
            for key in (
                "nonAliasLoader",
                "semanticValidator",
                "canonicalDecoder",
            )
        },
        "schemaDocumentValidation": "PASS" if schema_ok else "FAIL",
        "schemaInstanceValidation": "not_run_missing_source_production_profile",
        "sourceProductionProfileGuard": {
            "result": (
                "PASS"
                if missing_profile_code == "MISSING_SOURCE_PRODUCTION_PROFILE"
                else "FAIL"
            ),
            "rejection": missing_profile_code,
            "stage": "before_renderer_launch",
            "execution": "direct-function-no-A-B-C-mode",
        },
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "renderInvocations": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "pixelFiles": 0,
        "processA": "not_run",
        "processB": "not_run",
        "processC": "not_run",
        "sourceReady": False,
        "productionSelected": False,
        "selfAccepted": False,
    }
    binding_output = evidence_root / "SOURCE-STAGE-V2-SCHEMA-BINDING.json"
    binding_output.write_text(
        json.dumps(binding_receipt, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"result": report["result"], "output": display_path(output)}))
    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
