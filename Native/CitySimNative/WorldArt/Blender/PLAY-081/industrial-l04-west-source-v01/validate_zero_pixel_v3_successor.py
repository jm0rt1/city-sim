#!/usr/bin/env python3
"""Validate the PLAY-081 West v3 successor handoff without DCC or writes."""

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
DEFAULT_HANDOFF = f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V3-SUCCESSOR-HANDOFF.json"
DEFAULT_CASES = (
    f"{SOURCE_ROOT}/fixtures/zero-pixel-v3-successor/FAIL-CLOSED-CASES.json"
)
PUBLISHED_MASTER = "9d8e3e776eecbfb518d08d18085180ae084a6929"
EXPECTED_IDENTITY = {
    "taskId": "PLAY-081",
    "direction": "west",
    "branch": "codex/citysim-world-art-west",
    "logicalId": "industrial_l04_v0_west",
    "orientationTransform": "none",
}
EXPECTED_LINEAGE = {
    "publishedMaster": PUBLISHED_MASTER,
    "integratedIsolationImplementationCommit": (
        "b2ad9cbbba51d1203973efe172404f96fab4f489"
    ),
    "integratedIsolationEvidenceCommit": PUBLISHED_MASTER,
    "retainedWorkerEvidenceCommit": (
        "24158d679628dc6d2507a88f9d3bd307cb8ad3c5"
    ),
}
EXPECTED_BINDINGS = {
    "claim": {
        "path": "docs/production/claims/PLAY-081.world-art-west.md",
        "sha256": (
            "da46ae05307fa9fcff2af889e15b5270dca461c85ad136dce52ba72e921c35e8"
        ),
    },
    "currentMasterValidator": {
        "path": f"{SOURCE_ROOT}/validate_current_master_prelock_bundle.py",
        "sha256": (
            "217b75f7750dc28e121b0ee649362a3de7ebcd1eaca0cd7d9bfd5c10876ed826"
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
            "f1e7a4c6d4aa0198b5bed92d1993b3630d205b3862f0fbbcc2e00757c7da74c0"
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
    "acceptedMaterialRoles": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
            "industrial-l04-west-predesign-v01/MATERIAL-ROLE-BINDING.json"
        ),
        "sha256": (
            "3d3588a57d7c42f09c3978aa2f2a1ac68b5ccba0cc591eba8ef3172242976463"
        ),
    },
    "acceptedPredesignValidator": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
            "industrial-l04-west-predesign-v01/validate_predesign.py"
        ),
        "sha256": (
            "70df01d053b08df2a3ebd13d1aa1df3b9291c3b3e4a3c68c28516e45f87105f7"
        ),
    },
    "acceptedActualCameraProofTool": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
            "industrial-l04-west-predesign-v01/prove_actual_camera.py"
        ),
        "sha256": (
            "5dedf5f269b002ec5ea9078ed30ac8da7d804d622c32d52468dc7996f878b3ff"
        ),
    },
    "acceptedPredesignHandoff": {
        "path": "docs/production/evidence/PLAY-081/PREDESIGN-HANDOFF.json",
        "sha256": (
            "0bfe22cb607708e21e446f7e11dbc91876f107b3910bf23fcf474e9ee428e978"
        ),
    },
    "acceptedStaticProof": {
        "path": "docs/production/evidence/PLAY-081/STATIC-PREDESIGN-PROOF.json",
        "sha256": (
            "2dd6c5b77734f0bc1dd101a38ab7f4f69be2a4ac6b2a26c4b3ec6c6872a22727"
        ),
    },
    "acceptedActualCameraProof": {
        "path": (
            "docs/production/evidence/PLAY-081/"
            "ACTUAL-CAMERA-PREDESIGN-PROOF.json"
        ),
        "sha256": (
            "7fa5fdde4f3cd18439b220189c6efac9f0118e3dc5e8d9bb2fe8a0705bfa951d"
        ),
    },
    "acceptedRepeatIdentity": {
        "path": "docs/production/evidence/PLAY-081/REPEAT-IDENTITY.json",
        "sha256": (
            "14d5f5b3115426a28d85518f2f27e467cf841dcb0ae8b55796160d833490de8a"
        ),
    },
}
EXPECTED_PREDECESSORS = {
    "predecessorHandoff": {
        "path": f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V2-HANDOFF.json",
        "sha256": (
            "b6328cbf64781809df4264590924846ce8c2e0eff6ea6c868480e24e8e2a1f05"
        ),
    },
    "predecessorValidation": {
        "path": f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V2-HANDOFF-VALIDATION.json",
        "sha256": (
            "9fed1e9f72cfcf5e783779f3f70a4b9075f79aee32b9c66902b257e0f0733113"
        ),
    },
}
EXPECTED_BRIDGE = {
    "acceptancePath": (
        "docs/production/evidence/INTEGRATION/"
        "INDUSTRIAL-L04-DIRECTIONAL-BRIDGE-V06-ACCEPTANCE.md"
    ),
    "acceptanceSha256": (
        "9765d88191d8a555de41dcccfb83b3da16d8f1423d534d66312ffa98a4615208"
    ),
    "authorityPath": (
        "docs/production/evidence/PLAY-027/"
        "INDUSTRIAL-L04-DIRECTIONAL-COORDINATE-BRIDGE-V06-AUTHORITY.md"
    ),
    "authorityCommit": "3e01ca6738d7574718f9aeff4b66771eee109feb",
    "authoritySha256": (
        "5b8cbe06a430b48cd955ba0ec722873ec4c739b7919e22ddac2776561d2910b4"
    ),
    "integratedProofCommit": "3d76fab8a45807c34198a6d8bb1dd1eeff7be51e",
    "mappingPath": (
        "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
        "industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
    ),
    "mappingSha256": (
        "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
    ),
    "basisFormula": "B(CitySim[x,y,z])=Blender[z,x,y]",
}
EXPECTED_CAMERA = {
    "projection": "orthographic-2:1",
    "positionWorldXYZ": [96, 101.24557426726288, 96],
    "targetWorldXYZ": [0, 22.861902498201186, 0],
    "blenderOrthographicScale": 237.5878601074218,
    "shiftX": 0,
    "shiftY": 0.08333333333333333,
    "renderViewportPixels": [1536, 1024],
    "literalViewportPixels": [192, 128],
}
EXPECTED_SOCKET = {
    "citySimWorldXYZ": [-28, 0, 0],
    "blenderXYZ": [0, -28, 0],
    "sourceXY": [640, 704],
}
EXPECTED_OUTPUT_ROOTS = {
    "processA": f"{EVIDENCE_ROOT}/process-A",
    "processB": f"{EVIDENCE_ROOT}/process-B",
    "processC": f"{EVIDENCE_ROOT}/process-C",
    "normalizationRun1": f"{EVIDENCE_ROOT}/normalization-repeat/run-1",
    "normalizationRun2": f"{EVIDENCE_ROOT}/normalization-repeat/run-2",
    "review": f"{EVIDENCE_ROOT}/review",
    "assembly": f"{EVIDENCE_ROOT}/assembly",
    "parallelReceipt": f"{EVIDENCE_ROOT}/PARALLEL-EXECUTION-RECEIPT.json",
    "sourceCandidatePacket": f"{EVIDENCE_ROOT}/SOURCE-STAGE-HANDOFF-V2.json",
}
EXPECTED_AUTHORITY_BOUNDARY = {
    "appearanceLock": {
        "state": "not_published",
        "path": None,
        "commit": None,
        "sha256": None,
    },
    "sourceProductionProfile": {
        "state": "not_published",
        "path": None,
        "commit": None,
        "sha256": None,
    },
    "sourceReady": False,
    "productionExecutionEnabled": False,
    "productionReceiptEmissionEnabled": False,
    "integrationAdmitted": False,
    "rendererQuarantined": False,
    "productionSelected": False,
    "shipping": False,
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
    """The handoff or fixture contains an ambiguous duplicate JSON key."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--handoff", default=DEFAULT_HANDOFF)
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


def validate_handoff(
    root: Path,
    handoff: dict[str, Any],
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    reads: list[str] = []
    if handoff.get("schema") != (
        "citysim.play-081.west-zero-pixel-successor-handoff.v3"
    ):
        errors.append("handoff:schema")
    if handoff.get("schemaVersion") != 3:
        errors.append("handoff:schemaVersion")
    if handoff.get("stage") != "zero_pixel_prelock":
        errors.append("handoff:stage")

    identity = handoff.get("identity")
    if not isinstance(identity, dict):
        errors.append("identity:shape")
    else:
        for key, expected in EXPECTED_IDENTITY.items():
            if identity.get(key) != expected:
                errors.append(f"identity:{key}")

    lineage = handoff.get("lineage")
    if not isinstance(lineage, dict):
        errors.append("lineage:shape")
    else:
        for key, expected in EXPECTED_LINEAGE.items():
            if lineage.get(key) != expected:
                errors.append(f"lineage:{key}")
        if lineage.get("publishedMaster") == PUBLISHED_MASTER:
            if not git_ancestor(root, PUBLISHED_MASTER):
                errors.append("lineage:publishedMaster-not-ancestor")
        for key in (
            "integratedIsolationImplementationCommit",
            "integratedIsolationEvidenceCommit",
        ):
            if lineage.get(key) == EXPECTED_LINEAGE[key]:
                if not git_ancestor(root, EXPECTED_LINEAGE[key]):
                    errors.append(f"lineage:{key}-not-ancestor")
        for key, expected in EXPECTED_PREDECESSORS.items():
            supplied = lineage.get(key)
            errors.extend(
                _exact_binding(
                    root,
                    supplied,
                    expected,
                    f"lineage:{key}",
                    reads,
                )
            )
            if not isinstance(supplied, dict) or supplied.get(
                "preservedByteForByte"
            ) is not True:
                errors.append(f"lineage:{key}:preservation")

    bindings = handoff.get("bindings")
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
                    reads,
                )
            )
        camera_tool = bindings.get("acceptedActualCameraProofTool")
        if not isinstance(camera_tool, dict):
            errors.append("binding:acceptedActualCameraProofTool:shape")
        else:
            if camera_tool.get("authorityScope") != (
                "historical-zero-pixel-evidence-only"
            ):
                errors.append(
                    "binding:acceptedActualCameraProofTool:authorityScope"
                )
            if camera_tool.get("futureSourceAuthority") is not False:
                errors.append(
                    "binding:acceptedActualCameraProofTool:"
                    "futureSourceAuthority"
                )

    bridge = handoff.get("bridgeAuthority")
    if not isinstance(bridge, dict):
        errors.append("bridge:shape")
    else:
        for key, expected in EXPECTED_BRIDGE.items():
            if bridge.get(key) != expected:
                errors.append(f"bridge:{key}")
        if bridge.get("integratedProofCommit") == EXPECTED_BRIDGE[
            "integratedProofCommit"
        ] and not git_ancestor(root, EXPECTED_BRIDGE["integratedProofCommit"]):
            errors.append("bridge:integratedProofCommit-not-ancestor")
        for label, path_key, hash_key in (
            ("acceptance", "acceptancePath", "acceptanceSha256"),
            ("authority", "authorityPath", "authoritySha256"),
            ("mapping", "mappingPath", "mappingSha256"),
        ):
            errors.extend(
                _exact_binding(
                    root,
                    {
                        "path": bridge.get(path_key),
                        "sha256": bridge.get(hash_key),
                    },
                    {
                        "path": EXPECTED_BRIDGE[path_key],
                        "sha256": EXPECTED_BRIDGE[hash_key],
                    },
                    f"bridge:{label}",
                    reads,
                )
            )

    if handoff.get("camera") != EXPECTED_CAMERA:
        errors.append("camera:identity")
    if handoff.get("socket") != EXPECTED_SOCKET:
        errors.append("socket:identity")

    output_roots = handoff.get("outputRoots")
    if not isinstance(output_roots, dict):
        errors.append("output:shape")
    else:
        for key, expected in EXPECTED_OUTPUT_ROOTS.items():
            supplied = output_roots.get(key)
            if supplied != expected:
                errors.append(f"output:{key}")
                continue
            try:
                lexical_repository_path(root, supplied, expected=expected)
            except PathSafetyError:
                errors.append(f"output:{key}:path-safety")
        values = [
            value for value in output_roots.values() if isinstance(value, str)
        ]
        if len(values) != len(set(values)):
            errors.append("output:alias")

    if handoff.get("authorityBoundary") != EXPECTED_AUTHORITY_BOUNDARY:
        errors.append("authorityBoundary:identity")
    if handoff.get("invocations") != ZERO_INVOCATIONS:
        errors.append("invocations:not-zero")
    for key in (
        "sourceReady",
        "integrationAdmitted",
        "rendererQuarantined",
        "productionSelected",
    ):
        if handoff.get(key) is not False:
            errors.append(f"handoff:{key}")
    for key in ("processA", "processB", "processC"):
        if handoff.get(key) != "not_produced":
            errors.append(f"handoff:{key}")
    if handoff.get("pixelProduction") != "not_run":
        errors.append("handoff:pixelProduction")

    return sorted(set(errors)), sorted(set(reads))


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
    for relative in EXPECTED_OUTPUT_ROOTS.values():
        path = root / relative
        if path.exists() or path.is_symlink():
            found.append(relative)
    for relative in (SOURCE_ROOT, EVIDENCE_ROOT):
        directory = root / relative
        for path in directory.rglob("*"):
            if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES:
                found.append(str(path.relative_to(root)))
    return sorted(set(found))


def build_report(
    root: Path,
    handoff_relative: str = DEFAULT_HANDOFF,
    cases_relative: str = DEFAULT_CASES,
) -> dict[str, Any]:
    handoff_path = lexical_repository_path(
        root,
        handoff_relative,
        expected=DEFAULT_HANDOFF,
    )
    cases_path = lexical_repository_path(
        root,
        cases_relative,
        expected=DEFAULT_CASES,
    )
    handoff = load_json(handoff_path)
    cases = load_json(cases_path)
    valid_errors, reads = validate_handoff(root, handoff)
    results: list[dict[str, Any]] = []
    for case in cases.get("cases", []):
        candidate = copy.deepcopy(handoff)
        _set_mutation(candidate, case["mutationPath"], case["value"])
        errors, case_reads = validate_handoff(root, candidate)
        mutated_value = case["value"]
        sibling_path_read = (
            isinstance(mutated_value, str)
            and ("PLAY-079/" in mutated_value or "PLAY-080/" in mutated_value)
            and mutated_value in case_reads
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
        "schema": "citysim.play-081.west-zero-pixel-successor-validation.v3",
        "schemaVersion": 3,
        "taskId": "PLAY-081",
        "direction": "west",
        "stage": "zero_pixel_prelock",
        "publishedMaster": PUBLISHED_MASTER,
        "handoff": {
            "path": handoff_relative,
            "sha256": sha256(handoff_path),
            "referencedPathCount": len(reads),
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
    if args.handoff != DEFAULT_HANDOFF or args.cases != DEFAULT_CASES:
        result = {
            "schema": (
                "citysim.play-081.west-zero-pixel-successor-validation.v3"
            ),
            "schemaVersion": 3,
            "taskId": "PLAY-081",
            "direction": "west",
            "errors": ["input-path-mismatch"],
            "invocations": dict(ZERO_INVOCATIONS),
            "passed": False,
        }
    else:
        result = build_report(root, args.handoff, args.cases)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
