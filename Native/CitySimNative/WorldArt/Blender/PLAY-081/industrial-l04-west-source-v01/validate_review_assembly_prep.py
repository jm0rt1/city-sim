#!/usr/bin/env python3
"""Validate PLAY-081 West review-assembly prep without DCC or writes."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any

from west_path_safety import PathSafetyError, lexical_repository_path


SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01"
)
EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01"
)
DEFAULT_CONTRACT = f"{SOURCE_ROOT}/REVIEW-ASSEMBLY-PREP-CONTRACT.json"
DEFAULT_CASES = (
    f"{SOURCE_ROOT}/fixtures/review-assembly-prep/FAIL-CLOSED-CASES.json"
)
CURRENT_INTEGRATION = "d4f18ea3b1ccfd522f3b5e877bc7cb742fd9be09"
EXPECTED_IDENTITY = {
    "taskId": "PLAY-081",
    "direction": "west",
    "branch": "codex/citysim-world-art-west",
    "logicalId": "industrial_l04_v0_west",
    "orientationTransform": "none",
}
EXPECTED_BINDINGS = {
    "claim": {
        "path": "docs/production/claims/PLAY-081.world-art-west.md",
        "sha256": (
            "52f90aafd67d7bb8083b84e3704ea8eb14c577db7bf9f20145016f36bc6c14aa"
        ),
    },
    "runnerContract": {
        "path": f"{SOURCE_ROOT}/RUNNER-CONTRACT.json",
        "sha256": (
            "ac87bd1013daaa8e21a6204bdd09969489a4e237698b3e95c135949968fe6be1"
        ),
    },
    "executionContract": {
        "path": f"{SOURCE_ROOT}/WEST-EXECUTION-ORCHESTRATION-V2.json",
        "sha256": (
            "434bbf95c1f225773b72f5087a31995c89482f8d18e112ae4daf410c85fcc890"
        ),
    },
    "pathSafety": {
        "path": f"{SOURCE_ROOT}/west_path_safety.py",
        "sha256": (
            "d8b742e90e562d2da97c342d9c79c1674134b086a9df8d47b3bbe9ec689e6f1a"
        ),
    },
    "postSourceAssembler": {
        "path": f"{SOURCE_ROOT}/post_source_pipeline.py",
        "sha256": (
            "a652d6dfed934e0ceebcdcda275693702961fd706fdefc8e218a662af7c847a9"
        ),
    },
    "v4SuccessorHandoff": {
        "path": f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V4-SUCCESSOR-HANDOFF.json",
        "sha256": (
            "e2b5a1b083f65a0a89ea4003f8df3a3fd294e654d94b70cc0938503a6252af92"
        ),
    },
    "v4SuccessorValidation": {
        "path": f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V4-SUCCESSOR-VALIDATION.json",
        "sha256": (
            "8b0d137f58af53d4d5c007c3924e6fcbca46d1f94e7ace941a6074f28f33b682"
        ),
    },
    "acceptedScene": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
            "industrial-l04-west-predesign-v01/PREDESIGN-CONTRACT.json"
        ),
        "sha256": (
            "9376538d66a653be4a07f7c8d511626f16dbb4b0d4ef42e0354efb737f1f1b9c"
        ),
    },
    "acceptedMaterials": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
            "industrial-l04-west-predesign-v01/MATERIAL-ROLE-BINDING.json"
        ),
        "sha256": (
            "3d3588a57d7c42f09c3978aa2f2a1ac68b5ccba0cc591eba8ef3172242976463"
        ),
    },
}
MISSING_RELEASE_INPUT = {
    "state": "missing",
    "path": None,
    "commit": None,
    "sha256": None,
}
EXPECTED_ARTIFACTS = {
    "sourceSizeColor": {
        "path": f"{EVIDENCE_ROOT}/review/SOURCE-COLOR.png",
        "canvasPixels": [1536, 1024],
        "mode": "RGBA",
        "state": "not_produced",
    },
    "sourceSizeGrayscale": {
        "path": f"{EVIDENCE_ROOT}/review/SOURCE-GRAYSCALE.png",
        "canvasPixels": [1536, 1024],
        "mode": "RGBA-grayscale",
        "state": "not_produced",
    },
    "native2xColor": {
        "path": f"{EVIDENCE_ROOT}/review/NATIVE-2X-COLOR.png",
        "canvasPixels": [1024, 683],
        "mode": "RGBA",
        "state": "not_produced",
    },
    "native2xGrayscale": {
        "path": f"{EVIDENCE_ROOT}/review/NATIVE-2X-GRAYSCALE.png",
        "canvasPixels": [1024, 683],
        "mode": "RGBA-grayscale",
        "state": "not_produced",
    },
    "actualGameScaleColor": {
        "path": f"{EVIDENCE_ROOT}/review/EXACT-192X128-COLOR.png",
        "canvasPixels": [192, 128],
        "mode": "RGBA",
        "state": "not_produced",
    },
    "actualGameScaleGrayscale": {
        "path": f"{EVIDENCE_ROOT}/review/EXACT-192X128-GRAYSCALE.png",
        "canvasPixels": [192, 128],
        "mode": "RGBA-grayscale",
        "state": "not_produced",
    },
    "registration": {
        "path": f"{EVIDENCE_ROOT}/review/REGISTRATION.png",
        "canvasPixels": [192, 128],
        "mode": "RGBA-registration",
        "state": "not_produced",
    },
    "contactSheet": {
        "path": f"{EVIDENCE_ROOT}/review/CONTACT-SHEET.png",
        "canvasPixels": [1152, 512],
        "mode": "RGBA-review-sheet",
        "state": "not_produced",
    },
    "reviewManifest": {
        "path": f"{EVIDENCE_ROOT}/review/REVIEW-MANIFEST.json",
        "state": "not_produced",
    },
    "rejectedAttempts": {
        "path": f"{EVIDENCE_ROOT}/REJECTIONS.json",
        "state": "not_produced",
    },
}
EXPECTED_SETTLED_GATES = {
    "appearanceLockBound": False,
    "sourceProductionProfileBound": False,
    "processASettled": False,
    "processBSettled": False,
    "processCSettled": False,
    "abcDecodedIdentityPassed": False,
    "normalizationRun1Settled": False,
    "normalizationRun2Settled": False,
    "normalizationRepeatPassed": False,
    "reviewArtifactsComplete": False,
    "rejectedAttemptInventorySealed": False,
    "sourceValidationPassed": False,
    "parallelExecutionReceiptPassed": False,
}
EXPECTED_WRITE_POLICY = {
    "exactTaskOwnedPathsOnly": True,
    "rejectSymlinkComponents": True,
    "noFollow": True,
    "noOverwrite": True,
    "finalPathRecheck": True,
}
EXPECTED_FUTURE_OUTPUTS = {
    "sourceValidation": {
        "path": f"{EVIDENCE_ROOT}/SOURCE-VALIDATION.json",
        "state": "not_produced",
    },
    "parallelExecutionReceipt": {
        "path": f"{EVIDENCE_ROOT}/PARALLEL-EXECUTION-RECEIPT.json",
        "state": "not_produced",
    },
    "sourceCandidatePacket": {
        "path": f"{EVIDENCE_ROOT}/SOURCE-STAGE-HANDOFF-V2.json",
        "state": "not_produced",
    },
}
EXPECTED_IDENTITY_SAFETY = {
    "siblingPathsAllowed": False,
    "orientationTransform": "none",
    "fallbackAllowed": False,
    "aliasAllowed": False,
    "sourceKeySubstitutionAllowed": False,
}
ZERO_INVOCATIONS = {
    "blenderProcessLaunches": 0,
    "blenderRenderApiCalls": 0,
    "dccProcesses": 0,
    "imageGenInvocations": 0,
    "normalizerInvocations": 0,
    "contactSheetInvocations": 0,
    "renderInvocations": 0,
    "productionReceipts": 0,
    "sourceCandidatePackets": 0,
    "pixelFiles": 0,
}
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr"}


class DuplicateKeyError(ValueError):
    """A contract or fixture contains an ambiguous duplicate JSON key."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument("--cases", default=DEFAULT_CASES)
    return parser.parse_args()


def _object_no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(f"DUPLICATE_KEY:{key}")
        result[key] = value
    return result


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(
        path.read_text(),
        object_pairs_hook=_object_no_duplicates,
        parse_constant=lambda value: (_ for _ in ()).throw(
            ValueError(f"NON_FINITE:{value}")
        ),
    )
    if not isinstance(value, dict):
        raise ValueError(f"EXPECTED_OBJECT:{path}")
    return value


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_ancestor(root: Path, commit: str) -> bool:
    return (
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", commit, "HEAD"],
            cwd=root,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def _exact_binding(
    root: Path,
    supplied: Any,
    expected: dict[str, str],
    label: str,
    reads: list[str],
) -> list[str]:
    if not isinstance(supplied, dict):
        return [f"{label}:shape"]
    errors: list[str] = []
    if supplied.get("path") != expected["path"]:
        return [f"{label}:path"]
    if supplied.get("sha256") != expected["sha256"]:
        errors.append(f"{label}:sha256")
    try:
        path = lexical_repository_path(
            root,
            supplied["path"],
            expected=expected["path"],
        )
    except PathSafetyError:
        return sorted(set(errors + [f"{label}:path-safety"]))
    reads.append(supplied["path"])
    if not path.is_file() or sha256(path) != expected["sha256"]:
        errors.append(f"{label}:content")
    return sorted(set(errors))


def _validate_output(
    root: Path,
    supplied: Any,
    expected: dict[str, Any],
    label: str,
    inspected: list[str],
) -> list[str]:
    if not isinstance(supplied, dict):
        return [f"{label}:shape"]
    errors: list[str] = []
    if supplied.get("path") != expected["path"]:
        return [f"{label}:path"]
    for key, value in expected.items():
        if key != "path" and supplied.get(key) != value:
            errors.append(f"{label}:{key}")
    try:
        path = lexical_repository_path(
            root,
            supplied["path"],
            expected=expected["path"],
        )
    except PathSafetyError:
        return sorted(set(errors + [f"{label}:path-safety"]))
    inspected.append(supplied["path"])
    if path.exists() or path.is_symlink():
        errors.append(f"{label}:preexisting")
    return sorted(set(errors))


def validate_contract(
    root: Path,
    contract: dict[str, Any],
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    inspected: list[str] = []
    if contract.get("schema") != (
        "citysim.play-081.west-review-assembly-prep.v1"
    ):
        errors.append("contract:schema")
    if contract.get("schemaVersion") != 1:
        errors.append("contract:schemaVersion")
    if contract.get("stage") != "zero_pixel_prelock":
        errors.append("contract:stage")
    if contract.get("currentIntegrationBaseline") != CURRENT_INTEGRATION:
        errors.append("authority:currentIntegrationBaseline")
    elif not git_ancestor(root, CURRENT_INTEGRATION):
        errors.append("authority:currentIntegrationBaseline-not-ancestor")

    identity = contract.get("identity")
    if not isinstance(identity, dict):
        errors.append("identity:shape")
    else:
        for key, expected in EXPECTED_IDENTITY.items():
            if identity.get(key) != expected:
                errors.append(f"identity:{key}")

    bindings = contract.get("bindings")
    if not isinstance(bindings, dict):
        errors.append("bindings:shape")
    else:
        for key, expected in EXPECTED_BINDINGS.items():
            errors.extend(
                _exact_binding(
                    root,
                    bindings.get(key),
                    expected,
                    f"binding:{key}",
                    inspected,
                )
            )

    release_inputs = contract.get("releaseInputs")
    if not isinstance(release_inputs, dict):
        errors.append("release:shape")
    else:
        for key in ("appearanceLock", "sourceProductionProfile"):
            if release_inputs.get(key) != MISSING_RELEASE_INPUT:
                errors.append(f"release:{key}")

    artifacts = contract.get("reviewArtifacts")
    if not isinstance(artifacts, dict):
        errors.append("artifacts:shape")
    else:
        for key, expected in EXPECTED_ARTIFACTS.items():
            errors.extend(
                _validate_output(
                    root,
                    artifacts.get(key),
                    expected,
                    f"artifact:{key}",
                    inspected,
                )
            )

    assembler = contract.get("assembler")
    if not isinstance(assembler, dict):
        errors.append("assembler:shape")
    else:
        exact_values = {
            "id": "play-081-west-direction-review-assembler-v1",
            "owner": "PLAY-081-west-direction-local",
            "implementationBinding": "postSourceAssembler",
            "singleWriter": True,
            "state": "blocked_missing_release_inputs",
            "assemblyReady": False,
            "creationAuthorizedNow": False,
            "startRule": (
                "run_once_only_after_every_required_settled_gate_is_true"
            ),
        }
        for key, expected in exact_values.items():
            if assembler.get(key) != expected:
                errors.append(f"assembler:{key}")
        if assembler.get("requiredSettledGates") != EXPECTED_SETTLED_GATES:
            errors.append("assembler:requiredSettledGates")
        if assembler.get("writePolicy") != EXPECTED_WRITE_POLICY:
            errors.append("assembler:writePolicy")
        future_outputs = assembler.get("futureOutputs")
        if not isinstance(future_outputs, dict):
            errors.append("futureOutputs:shape")
        else:
            for key, expected in EXPECTED_FUTURE_OUTPUTS.items():
                errors.extend(
                    _validate_output(
                        root,
                        future_outputs.get(key),
                        expected,
                        f"futureOutput:{key}",
                        inspected,
                    )
                )

    if contract.get("identitySafety") != EXPECTED_IDENTITY_SAFETY:
        supplied = contract.get("identitySafety")
        if not isinstance(supplied, dict):
            errors.append("identitySafety:shape")
        else:
            for key, expected in EXPECTED_IDENTITY_SAFETY.items():
                if supplied.get(key) != expected:
                    errors.append(f"identitySafety:{key}")
    if contract.get("invocations") != ZERO_INVOCATIONS:
        errors.append("invocations:not-zero")
    for key in (
        "reviewAssemblyReady",
        "sourceReady",
        "integrationAdmitted",
        "rendererQuarantined",
        "productionSelected",
        "shipping",
    ):
        if contract.get(key) is not False:
            errors.append(f"boundary:{key}")

    output_paths = [
        value["path"]
        for value in list(EXPECTED_ARTIFACTS.values())
        + list(EXPECTED_FUTURE_OUTPUTS.values())
    ]
    if len(output_paths) != len(set(output_paths)):
        errors.append("outputs:alias")
    return sorted(set(errors)), sorted(set(inspected))


def _set_mutation(value: dict[str, Any], dotted: str, replacement: Any) -> None:
    current: Any = value
    components = dotted.split(".")
    for component in components[:-1]:
        current = current[int(component)] if isinstance(current, list) else current[
            component
        ]
    terminal = components[-1]
    if isinstance(current, list):
        current[int(terminal)] = replacement
    else:
        current[terminal] = replacement


def _forbidden_outputs(root: Path) -> list[str]:
    found: list[str] = []
    for expected in list(EXPECTED_ARTIFACTS.values()) + list(
        EXPECTED_FUTURE_OUTPUTS.values()
    ):
        path = root / expected["path"]
        if path.exists() or path.is_symlink():
            found.append(expected["path"])
    for relative in (SOURCE_ROOT, EVIDENCE_ROOT):
        directory = root / relative
        for path in directory.rglob("*"):
            if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES:
                found.append(str(path.relative_to(root)))
    return sorted(set(found))


def build_report(
    root: Path,
    contract_relative: str = DEFAULT_CONTRACT,
    cases_relative: str = DEFAULT_CASES,
) -> dict[str, Any]:
    contract_path = lexical_repository_path(
        root,
        contract_relative,
        expected=DEFAULT_CONTRACT,
    )
    cases_path = lexical_repository_path(
        root,
        cases_relative,
        expected=DEFAULT_CASES,
    )
    contract = load_json(contract_path)
    cases = load_json(cases_path)
    valid_errors, inspected = validate_contract(root, contract)
    results: list[dict[str, Any]] = []
    for case in cases.get("cases", []):
        candidate = copy.deepcopy(contract)
        _set_mutation(candidate, case["mutationPath"], case["value"])
        errors, case_inspected = validate_contract(root, candidate)
        mutated_value = case["value"]
        sibling_path_read = (
            isinstance(mutated_value, str)
            and ("PLAY-079/" in mutated_value or "PLAY-080/" in mutated_value)
            and mutated_value in case_inspected
        )
        results.append(
            {
                "name": case["name"],
                "expectedError": case["expectedError"],
                "errors": errors,
                "expectedErrorObserved": case["expectedError"] in errors,
                "siblingPathRead": sibling_path_read,
                "passed": (
                    bool(errors)
                    and case["expectedError"] in errors
                    and not sibling_path_read
                ),
            }
        )
    forbidden_outputs = _forbidden_outputs(root)
    all_cases_passed = bool(results) and all(
        result["passed"] for result in results
    )
    return {
        "schema": "citysim.play-081.west-review-assembly-prep-validation.v1",
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "stage": "zero_pixel_prelock",
        "currentIntegrationBaseline": CURRENT_INTEGRATION,
        "contract": {
            "path": contract_relative,
            "sha256": sha256(contract_path),
            "inspectedPathCount": len(inspected),
            "errors": valid_errors,
            "passed": not valid_errors,
        },
        "cases": {
            "path": cases_relative,
            "sha256": sha256(cases_path),
            "caseCount": len(results),
        },
        "adversarialCases": results,
        "allAdversarialCasesPassed": all_cases_passed,
        "forbiddenOutputs": forbidden_outputs,
        "invocations": dict(ZERO_INVOCATIONS),
        "appearanceLockPublished": False,
        "sourceProductionProfilePublished": False,
        "reviewAssemblyReady": False,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "shipping": False,
        "passed": not valid_errors and all_cases_passed and not forbidden_outputs,
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    if args.contract != DEFAULT_CONTRACT or args.cases != DEFAULT_CASES:
        result = {
            "schema": (
                "citysim.play-081.west-review-assembly-prep-validation.v1"
            ),
            "schemaVersion": 1,
            "taskId": "PLAY-081",
            "direction": "west",
            "errors": ["input-path-mismatch"],
            "invocations": dict(ZERO_INVOCATIONS),
            "passed": False,
        }
    else:
        result = build_report(root, args.contract, args.cases)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
