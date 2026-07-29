#!/usr/bin/env python3
"""Validate PLAY-081 West direction isolation without DCC or pixel work."""

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
FIXTURE_ROOT = f"{SOURCE_ROOT}/fixtures/prelock-direction-isolation"
DEFAULT_VALID = f"{FIXTURE_ROOT}/VALID-WEST.json"
DEFAULT_CASES = f"{FIXTURE_ROOT}/FAIL-CLOSED-CASES.json"
PUBLISHED_MASTER = "94ae73a99abe64f59bb052582fcaba1d9725319d"
EXPECTED_IDENTITY = {
    "taskId": "PLAY-081",
    "direction": "west",
    "branch": "codex/citysim-world-art-west",
    "logicalId": "industrial_l04_v0_west",
    "orientationTransform": "none",
}
EXPECTED_SOCKET = {
    "citySimWorldXYZ": [-28, 0, 0],
    "blenderXYZ": [0, -28, 0],
    "sourceXY": [640, 704],
}
EXPECTED_GEOMETRY = [
    {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
            "industrial-l04-west-predesign-v01/PREDESIGN-CONTRACT.json"
        ),
        "sha256": (
            "9376538d66a653be4a07f7c8d511626f16dbb4b0d4ef42e0354efb737f1f1b9c"
        ),
    },
    {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
            "industrial-l04-west-predesign-v01/MATERIAL-ROLE-BINDING.json"
        ),
        "sha256": (
            "3d3588a57d7c42f09c3978aa2f2a1ac68b5ccba0cc591eba8ef3172242976463"
        ),
    },
]
EXPECTED_EVIDENCE = [
    {
        "path": "docs/production/evidence/PLAY-081/PREDESIGN-HANDOFF.json",
        "sha256": (
            "0bfe22cb607708e21e446f7e11dbc91876f107b3910bf23fcf474e9ee428e978"
        ),
    },
    {
        "path": "docs/production/evidence/PLAY-081/STATIC-PREDESIGN-PROOF.json",
        "sha256": (
            "2dd6c5b77734f0bc1dd101a38ab7f4f69be2a4ac6b2a26c4b3ec6c6872a22727"
        ),
    },
    {
        "path": (
            "docs/production/evidence/PLAY-081/"
            "ACTUAL-CAMERA-PREDESIGN-PROOF.json"
        ),
        "sha256": (
            "7fa5fdde4f3cd18439b220189c6efac9f0118e3dc5e8d9bb2fe8a0705bfa951d"
        ),
    },
    {
        "path": "docs/production/evidence/PLAY-081/REPEAT-IDENTITY.json",
        "sha256": (
            "14d5f5b3115426a28d85518f2f27e467cf841dcb0ae8b55796160d833490de8a"
        ),
    },
]
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
}
EXPECTED_ORCHESTRATION = {
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
    "appearanceLockPublished": False,
    "sourceProductionProfilePublished": False,
    "productionExecutionEnabled": False,
    "productionReceiptEmissionEnabled": False,
    "sourceReady": False,
    "integrationAdmitted": False,
    "rendererQuarantined": False,
    "productionSelected": False,
    "shipping": False,
}
ZERO_INVOCATIONS = {
    "blenderProcessLaunches": 0,
    "blenderRenderApiCalls": 0,
    "imageGenInvocations": 0,
    "normalizerInvocations": 0,
    "contactSheetInvocations": 0,
    "productionReceipts": 0,
    "sourceCandidatePackets": 0,
    "pixelFiles": 0,
}
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr"}


class DuplicateKeyError(ValueError):
    """A fixture contains an ambiguous duplicate JSON key."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument(
        "--mode",
        choices=("describe", "validate-fixtures"),
        default="validate-fixtures",
    )
    parser.add_argument("--valid-fixture", default=DEFAULT_VALID)
    parser.add_argument("--cases-fixture", default=DEFAULT_CASES)
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
    errors: list[str] = []
    if not isinstance(supplied, dict):
        return [f"{label}:shape"]
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


def validate_bundle(
    root: Path,
    bundle: dict[str, Any],
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    reads: list[str] = []
    if bundle.get("schema") != (
        "citysim.play-081.west-prelock-direction-isolation.v1"
    ):
        errors.append("bundle:schema")
    if bundle.get("schemaVersion") != 1:
        errors.append("bundle:schemaVersion")
    if bundle.get("publishedMaster") != PUBLISHED_MASTER:
        errors.append("authority:publishedMaster")
    elif not git_ancestor(root, PUBLISHED_MASTER):
        errors.append("authority:publishedMaster-not-ancestor")

    claim_expected = {
        "path": "docs/production/claims/PLAY-081.world-art-west.md",
        "sha256": (
            "da46ae05307fa9fcff2af889e15b5270dca461c85ad136dce52ba72e921c35e8"
        ),
    }
    errors.extend(
        _exact_binding(root, bundle.get("claim"), claim_expected, "claim", reads)
    )

    identity = bundle.get("identity")
    if not isinstance(identity, dict):
        errors.append("identity:shape")
    else:
        for key, expected in EXPECTED_IDENTITY.items():
            if identity.get(key) != expected:
                errors.append(f"identity:{key}")

    socket = bundle.get("socket")
    socket_labels = {
        "citySimWorldXYZ": "citysim",
        "blenderXYZ": "blender",
        "sourceXY": "source",
    }
    if not isinstance(socket, dict):
        errors.append("socket:shape")
    else:
        for key, expected in EXPECTED_SOCKET.items():
            if socket.get(key) != expected:
                errors.append(f"socket:{socket_labels[key]}")

    predesign = bundle.get("acceptedPredesign")
    if not isinstance(predesign, dict):
        errors.append("predesign:shape")
    else:
        for group, expected_bindings in (
            ("geometry", EXPECTED_GEOMETRY),
            ("evidence", EXPECTED_EVIDENCE),
        ):
            supplied_bindings = predesign.get(group)
            if (
                not isinstance(supplied_bindings, list)
                or len(supplied_bindings) != len(expected_bindings)
            ):
                errors.append(f"predesign:{group}:shape")
                continue
            for index, expected in enumerate(expected_bindings):
                errors.extend(
                    _exact_binding(
                        root,
                        supplied_bindings[index],
                        expected,
                        f"predesign:{group}:{index}",
                        reads,
                    )
                )

    bridge = bundle.get("bridgeAuthority")
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
        for prefix, path_key, hash_key in (
            ("bridge:acceptance", "acceptancePath", "acceptanceSha256"),
            ("bridge:authority", "authorityPath", "authoritySha256"),
            ("bridge:mapping", "mappingPath", "mappingSha256"),
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
                    prefix,
                    reads,
                )
            )

    orchestration = bundle.get("orchestration")
    if not isinstance(orchestration, dict):
        errors.append("orchestration:shape")
    else:
        for key, expected in EXPECTED_ORCHESTRATION.items():
            errors.extend(
                _exact_binding(
                    root,
                    orchestration.get(key),
                    expected,
                    f"orchestration:{key}",
                    reads,
                )
            )

    output_roots = bundle.get("outputRoots")
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
        values = [value for value in output_roots.values() if isinstance(value, str)]
        if len(values) != len(set(values)):
            errors.append("output:alias")

    boundary = bundle.get("authorityBoundary")
    if not isinstance(boundary, dict):
        errors.append("authority:shape")
    else:
        for key, expected in EXPECTED_AUTHORITY_BOUNDARY.items():
            if boundary.get(key) is not expected:
                errors.append(f"authority:{key}")

    return sorted(set(errors)), sorted(set(reads))


def _set_mutation(value: dict[str, Any], dotted: str, replacement: Any) -> None:
    components = dotted.split(".")
    current: Any = value
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
    valid_fixture: str = DEFAULT_VALID,
    cases_fixture: str = DEFAULT_CASES,
) -> dict[str, Any]:
    valid_path = lexical_repository_path(root, valid_fixture, expected=DEFAULT_VALID)
    cases_path = lexical_repository_path(root, cases_fixture, expected=DEFAULT_CASES)
    valid = load_json(valid_path)
    cases = load_json(cases_path)
    valid_errors, valid_reads = validate_bundle(root, valid)
    results: list[dict[str, Any]] = []
    for case in cases.get("cases", []):
        candidate = copy.deepcopy(valid)
        _set_mutation(candidate, case["mutationPath"], case["value"])
        errors, reads = validate_bundle(root, candidate)
        mutated_value = case["value"]
        sibling_path_read = (
            isinstance(mutated_value, str)
            and ("PLAY-079/" in mutated_value or "PLAY-080/" in mutated_value)
            and mutated_value in reads
        )
        results.append(
            {
                "name": case["name"],
                "expectedError": case["expectedError"],
                "errors": errors,
                "rejected": bool(errors),
                "expectedErrorObserved": case["expectedError"] in errors,
                "siblingPathRead": sibling_path_read,
                "invocations": dict(ZERO_INVOCATIONS),
                "passed": (
                    bool(errors)
                    and case["expectedError"] in errors
                    and not sibling_path_read
                ),
            }
        )
    forbidden_outputs = _forbidden_outputs(root)
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "stage": "zero_pixel_prelock_direction_isolation",
        "publishedMaster": PUBLISHED_MASTER,
        "validFixture": {
            "path": valid_fixture,
            "sha256": sha256(valid_path),
            "errors": valid_errors,
            "referencedPathCount": len(valid_reads),
            "passed": not valid_errors,
        },
        "casesFixture": {
            "path": cases_fixture,
            "sha256": sha256(cases_path),
            "caseCount": len(results),
        },
        "adversarialCases": results,
        "allAdversarialCasesPassed": bool(results)
        and all(result["passed"] for result in results),
        "forbiddenOutputs": forbidden_outputs,
        "invocations": dict(ZERO_INVOCATIONS),
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "shipping": False,
        "passed": (
            not valid_errors
            and bool(results)
            and all(result["passed"] for result in results)
            and not forbidden_outputs
        ),
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    if args.mode == "describe":
        result = {
            "schemaVersion": 1,
            "taskId": "PLAY-081",
            "direction": "west",
            "stage": "zero_pixel_prelock_direction_isolation",
            "validFixture": DEFAULT_VALID,
            "casesFixture": DEFAULT_CASES,
            "invocations": dict(ZERO_INVOCATIONS),
            "productionAuthority": False,
            "passed": True,
        }
    else:
        if args.valid_fixture != DEFAULT_VALID or args.cases_fixture != DEFAULT_CASES:
            result = {
                "schemaVersion": 1,
                "taskId": "PLAY-081",
                "direction": "west",
                "stage": "zero_pixel_prelock_direction_isolation",
                "errors": ["fixture-path-mismatch"],
                "invocations": dict(ZERO_INVOCATIONS),
                "passed": False,
            }
        else:
            result = build_report(root, args.valid_fixture, args.cases_fixture)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
