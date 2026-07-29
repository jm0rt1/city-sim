#!/usr/bin/env python3
"""Fail-closed PLAY-081 consumption of the Integration locator authority.

This validator performs no DCC, image, normalization, or packet-production
work.  Its only repository write mode emits one task-owned zero-pixel proof
through the existing no-follow/no-overwrite writer.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from typing import Any

from jsonschema import Draft202012Validator

from west_path_safety import (
    PathSafetyError,
    exact_pipeline_path,
    pipeline_relative,
    write_exact_json_no_overwrite,
)


SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01"
)
DEFAULT_CONTRACT = f"{SOURCE_ROOT}/RUNNER-CONTRACT.json"
AUTHORITY_COMMIT = "fa66b5605deca987685c058a072613e89a0d8be9"
SCHEMA_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-candidate-packet-locators-v1.schema.json"
)
SCHEMA_SHA256 = "cb9716330593224bc5cbdae46052cff17cbb84a270ca9976c5452b8075308cbe"
INSTANCE_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-candidate-packet-locators-v1.json"
)
INSTANCE_SHA256 = "a2c8daf558274bed9088b6c9ab616044e919af5b19101a01c2fe3a1b89122e65"
WEST_EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01"
)
WEST_PACKET_PATH = f"{WEST_EVIDENCE_ROOT}/SOURCE-STAGE-HANDOFF-V2.json"
PROOF_IDENTITY = "validation.locatorAuthorityProof"
ZERO_INVOCATIONS = {
    "blenderProcessLaunches": 0,
    "blenderRenderApiCalls": 0,
    "imageGenInvocations": 0,
    "normalizerInvocations": 0,
    "contactSheetInvocations": 0,
    "renderInvocations": 0,
    "pixelFiles": 0,
    "sourceCandidatePacketWrites": 0,
}
EXPECTED_GRANTS = {
    "sourceAdmission": False,
    "rendererQuarantine": False,
    "rendererActivation": False,
    "productionSelection": False,
    "shipping": False,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument("--mode", choices=("check", "write-proof"), default="check")
    return parser.parse_args()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"JSON_OBJECT_REQUIRED:{path}")
    return value


def repository_file(root: Path, relative: Any, expected: str) -> Path:
    if relative != expected:
        raise ValueError(f"LEXICAL_IDENTITY_MISMATCH:{relative!r}!={expected!r}")
    if (
        not isinstance(relative, str)
        or not relative
        or Path(relative).is_absolute()
        or "\\" in relative
    ):
        raise ValueError(f"INVALID_REPOSITORY_PATH:{relative!r}")
    parts = relative.split("/")
    if any(not part or part in {".", ".."} for part in parts):
        raise ValueError(f"PATH_TRAVERSAL:{relative}")
    current = root.resolve()
    for part in parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"SYMLINK_COMPONENT:{relative}")
    return current


def git_commit_errors(
    root: Path,
    commit: Any,
    bindings: tuple[tuple[str, str, str], ...],
) -> list[str]:
    if commit != AUTHORITY_COMMIT:
        return ["locator-authority:commit-mismatch"]
    object_check = subprocess.run(
        ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
        cwd=root,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if object_check.returncode != 0:
        return ["locator-authority:commit-missing"]
    ancestry = subprocess.run(
        ["git", "merge-base", "--is-ancestor", str(commit), "HEAD"],
        cwd=root,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    errors: list[str] = []
    if ancestry.returncode != 0:
        errors.append("locator-authority:not-ancestor")
    for label, path, expected_hash in bindings:
        retained = subprocess.run(
            ["git", "show", f"{commit}:{path}"],
            cwd=root,
            check=False,
            capture_output=True,
        )
        if retained.returncode != 0:
            errors.append(f"{label}:absent-at-authority-commit")
        elif sha256_bytes(retained.stdout) != expected_hash:
            errors.append(f"{label}:authority-commit-sha256-mismatch")
    return errors


def binding_errors(
    root: Path,
    binding: Any,
    *,
    label: str,
    expected_path: str,
    expected_hash: str,
) -> tuple[Path | None, list[str]]:
    if not isinstance(binding, dict):
        return None, [f"{label}:missing-binding"]
    errors: list[str] = []
    if binding.get("path") != expected_path:
        errors.append(f"{label}:path-mismatch")
    if binding.get("sha256") != expected_hash:
        errors.append(f"{label}:bound-sha256-mismatch")
    try:
        path = repository_file(root, binding.get("path"), expected_path)
    except ValueError as error:
        errors.append(f"{label}:unsafe:{error}")
        return None, errors
    if not path.is_file():
        errors.append(f"{label}:missing")
    elif sha256(path) != expected_hash:
        errors.append(f"{label}:sha256-mismatch")
    return path, errors


def schema_validation_errors(
    schema: dict[str, Any],
    instance: dict[str, Any],
) -> list[str]:
    errors = sorted(
        Draft202012Validator(schema).iter_errors(instance),
        key=lambda error: (list(error.absolute_path), error.message),
    )
    return [
        "locator-instance:schema:"
        + "/".join(str(value) for value in error.absolute_path)
        + f":{error.validator}"
        for error in errors
    ]


def document_errors(
    contract: dict[str, Any],
    instance: dict[str, Any],
    *,
    selected_direction: str = "west",
) -> list[str]:
    errors: list[str] = []
    if selected_direction != "west":
        errors.append(f"locator-selection:sibling-direction:{selected_direction}")
        return errors

    directions = instance.get("directions")
    if not isinstance(directions, list):
        return ["locator-instance:directions-invalid"]
    west_records = [
        value
        for value in directions
        if isinstance(value, dict) and value.get("taskId") == "PLAY-081"
    ]
    if len(west_records) != 1:
        return ["locator-west:record-cardinality"]
    west = west_records[0]
    expected = {
        "taskId": "PLAY-081",
        "direction": "west",
        "branch": "codex/citysim-world-art-west",
        "evidenceRoot": WEST_EVIDENCE_ROOT,
        "packetPath": WEST_PACKET_PATH,
        "status": "reserved",
        "writer": "direction_cell",
        "creationPolicy": "exclusive_no_overwrite_nofollow",
    }
    for key, expected_value in expected.items():
        if west.get(key) != expected_value:
            errors.append(f"locator-west:{key}-mismatch")

    if contract.get("taskId") != west.get("taskId"):
        errors.append("locator-west:runner-task-mismatch")
    if contract.get("direction") != west.get("direction"):
        errors.append("locator-west:runner-direction-mismatch")
    if contract.get("branch") != west.get("branch"):
        errors.append("locator-west:runner-branch-mismatch")
    inventory = contract.get("outputInventory", {})
    if inventory.get("evidenceRoot") != west.get("evidenceRoot"):
        errors.append("locator-west:evidence-root-mismatch")
    post = inventory.get("postSource", {})
    if post.get("sourceCandidatePacket") != west.get("packetPath"):
        errors.append("locator-west:packet-path-mismatch")

    source_schema = contract.get("sourceStage", {}).get("handoffSchema", {})
    locator_schema = instance.get("sourceStageSchema", {})
    for key in ("path", "sha256"):
        if source_schema.get(key) != locator_schema.get(key):
            errors.append(f"locator-source-stage-schema:{key}-mismatch")
    if locator_schema.get("version") != 2:
        errors.append("locator-source-stage-schema:version-mismatch")

    governing = contract.get("governingContract", {})
    locator_governing = instance.get("governingContract", {})
    for key in ("path", "revision", "sha256"):
        if governing.get(key) != locator_governing.get(key):
            errors.append(f"locator-governing-contract:{key}-mismatch")

    grants = instance.get("grants")
    if grants != EXPECTED_GRANTS:
        errors.append("locator-authority:grants-mismatch")
    return sorted(set(errors))


def pipeline_binding(
    root: Path,
    contract: dict[str, Any],
) -> dict[str, Any]:
    implementation = contract.get("runnerImplementation", {})
    expected = {
        "postSourcePipelinePath": f"{SOURCE_ROOT}/post_source_pipeline.py",
        "pathSafetyPath": f"{SOURCE_ROOT}/west_path_safety.py",
        "locatorAuthorityValidatorPath": (
            f"{SOURCE_ROOT}/validate_locator_authority.py"
        ),
    }
    errors: list[str] = []
    records: dict[str, dict[str, str]] = {}
    contents: dict[str, str] = {}
    runner_contract = root / DEFAULT_CONTRACT
    runner_record: dict[str, Any] = {
        "path": DEFAULT_CONTRACT,
        "sha256": None,
    }
    if runner_contract.is_file():
        runner_record["sha256"] = sha256(runner_contract)
    else:
        errors.append("locator-pipeline:runner-contract-missing")
    for key, expected_path in expected.items():
        supplied = implementation.get(key)
        if supplied != expected_path:
            errors.append(f"locator-pipeline:{key}-mismatch")
            continue
        try:
            path = repository_file(root, supplied, expected_path)
        except ValueError as error:
            errors.append(f"locator-pipeline:{key}-unsafe:{error}")
            continue
        if not path.is_file():
            errors.append(f"locator-pipeline:{key}-missing")
            continue
        records[key] = {
            "path": expected_path,
            "sha256": sha256(path),
        }
        contents[key] = path.read_text(encoding="utf-8")

    post_source = contents.get("postSourcePipelinePath", "")
    for label, marker in (
        ("locator-consumer", "validate_locator_authority(root, contract)"),
        ("packet-identity", '"postSource.sourceCandidatePacket"'),
        ("safe-writer-call", "no_overwrite_json(root, packet_relative, packet)"),
        ("safe-writer-import", "write_exact_json_no_overwrite"),
    ):
        if marker not in post_source:
            errors.append(f"locator-pipeline:post-source-{label}-missing")
    path_safety = contents.get("pathSafetyPath", "")
    for label, marker in (
        ("no-follow", "os.O_NOFOLLOW"),
        ("no-overwrite", "os.O_EXCL"),
        ("exact-writer", "write_exact_json_no_overwrite"),
        ("packet-identity", '"postSource.sourceCandidatePacket"'),
    ):
        if marker not in path_safety:
            errors.append(f"locator-pipeline:path-safety-{label}-missing")
    return {
        "runnerContract": runner_record,
        "implementations": records,
        "packetPipelineIdentity": "postSource.sourceCandidatePacket",
        "safeWriter": "write_exact_json_no_overwrite",
        "noFollow": True,
        "noOverwrite": True,
        "errors": sorted(set(errors)),
        "passed": not errors,
    }


def packet_target_errors(
    root: Path,
    contract: dict[str, Any],
) -> tuple[Path | None, list[str]]:
    errors: list[str] = []
    try:
        relative = pipeline_relative(
            contract,
            "postSource.sourceCandidatePacket",
        )
        if relative != WEST_PACKET_PATH:
            errors.append("locator-packet:pipeline-path-mismatch")
        path = exact_pipeline_path(
            root,
            contract,
            "postSource.sourceCandidatePacket",
        )
    except (PathSafetyError, KeyError, TypeError) as error:
        errors.append(f"locator-packet:unsafe:{error}")
        return None, errors
    if path.exists() or path.is_symlink():
        errors.append("locator-packet:preexisting")
    return path, errors


def validate_locator_authority(
    root: Path,
    contract: dict[str, Any],
    *,
    schema_override: dict[str, Any] | None = None,
    instance_override: dict[str, Any] | None = None,
    selected_direction: str = "west",
    verify_git: bool = True,
) -> dict[str, Any]:
    authority = contract.get("sourceCandidatePacketLocatorAuthority")
    errors: list[str] = []
    if not isinstance(authority, dict):
        authority = {}
        errors.append("locator-authority:missing-binding")
    if authority.get("state") != "bound_reserved_zero_pixel":
        errors.append("locator-authority:state-mismatch")
    if authority.get("authorityCommit") != AUTHORITY_COMMIT:
        errors.append("locator-authority:commit-mismatch")
    if authority.get("grants") != EXPECTED_GRANTS:
        errors.append("locator-authority:bound-grants-mismatch")

    schema_path, schema_errors = binding_errors(
        root,
        authority.get("schema"),
        label="locator-schema",
        expected_path=SCHEMA_PATH,
        expected_hash=SCHEMA_SHA256,
    )
    instance_path, instance_errors = binding_errors(
        root,
        authority.get("instance"),
        label="locator-instance",
        expected_path=INSTANCE_PATH,
        expected_hash=INSTANCE_SHA256,
    )
    errors.extend(schema_errors)
    errors.extend(instance_errors)
    if verify_git:
        errors.extend(
            git_commit_errors(
                root,
                authority.get("authorityCommit"),
                (
                    ("locator-schema", SCHEMA_PATH, SCHEMA_SHA256),
                    ("locator-instance", INSTANCE_PATH, INSTANCE_SHA256),
                ),
            )
        )

    schema: dict[str, Any] | None = schema_override
    instance: dict[str, Any] | None = instance_override
    try:
        if schema is None and schema_path is not None and schema_path.is_file():
            schema = load_json(schema_path)
        if (
            instance is None
            and instance_path is not None
            and instance_path.is_file()
        ):
            instance = load_json(instance_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        errors.append(f"locator-authority:json-invalid:{type(error).__name__}")
    if schema is None:
        errors.append("locator-schema:unavailable")
    if instance is None:
        errors.append("locator-instance:unavailable")
    if schema is not None and instance is not None:
        errors.extend(schema_validation_errors(schema, instance))
        errors.extend(
            document_errors(
                contract,
                instance,
                selected_direction=selected_direction,
            )
        )

    packet_path, packet_errors = packet_target_errors(root, contract)
    errors.extend(packet_errors)
    pipeline = pipeline_binding(root, contract)
    errors.extend(pipeline["errors"])
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "authorityCommit": authority.get("authorityCommit"),
        "schema": {
            "path": SCHEMA_PATH,
            "sha256": SCHEMA_SHA256,
        },
        "instance": {
            "path": INSTANCE_PATH,
            "sha256": INSTANCE_SHA256,
        },
        "reservedPacket": {
            "path": WEST_PACKET_PATH,
            "exists": bool(
                packet_path is not None
                and (packet_path.exists() or packet_path.is_symlink())
            ),
            "creationPolicy": "exclusive_no_overwrite_nofollow",
        },
        "pipeline": pipeline,
        "errors": sorted(set(errors)),
        "passed": not errors,
        "invocations": dict(ZERO_INVOCATIONS),
    }


def negative_result(
    name: str,
    errors: list[str],
    expected_error: str,
    *,
    targetUnchanged: bool = True,
) -> dict[str, Any]:
    return {
        "name": name,
        "expectedError": expected_error,
        "errors": sorted(set(errors)),
        "rejected": bool(errors),
        "targetUnchanged": targetUnchanged,
        "invocations": dict(ZERO_INVOCATIONS),
        "passed": (
            expected_error in errors
            and targetUnchanged
        ),
    }


def dynamic_negatives(
    root: Path,
    contract: dict[str, Any],
    schema: dict[str, Any],
    instance: dict[str, Any],
) -> list[dict[str, Any]]:
    tests: list[dict[str, Any]] = []

    wrong_schema = copy.deepcopy(contract)
    wrong_schema["sourceCandidatePacketLocatorAuthority"]["schema"][
        "sha256"
    ] = "0" * 64
    result = validate_locator_authority(root, wrong_schema)
    tests.append(
        negative_result(
            "wrong-schema-hash",
            result["errors"],
            "locator-schema:bound-sha256-mismatch",
        )
    )

    wrong_instance = copy.deepcopy(contract)
    wrong_instance["sourceCandidatePacketLocatorAuthority"]["instance"][
        "sha256"
    ] = "f" * 64
    result = validate_locator_authority(root, wrong_instance)
    tests.append(
        negative_result(
            "wrong-instance-hash",
            result["errors"],
            "locator-instance:bound-sha256-mismatch",
        )
    )

    from post_source_pipeline import preflight as post_source_preflight

    _, post_source_errors = post_source_preflight(root, wrong_instance)
    tests.append(
        negative_result(
            "post-source-wrong-instance-hash",
            post_source_errors,
            (
                "source-candidate-locator:"
                "locator-instance:bound-sha256-mismatch"
            ),
        )
    )

    from run_west_source import evaluate_render_guard

    guard = evaluate_render_guard(root, wrong_schema, "A")
    tests.append(
        negative_result(
            "launch-guard-wrong-schema-hash",
            guard["reasonCodes"],
            (
                "source-candidate-locator:"
                "locator-schema:bound-sha256-mismatch"
            ),
        )
    )

    wrong_path = copy.deepcopy(instance)
    west = next(
        value
        for value in wrong_path["directions"]
        if value["taskId"] == "PLAY-081"
    )
    west["packetPath"] = f"{WEST_EVIDENCE_ROOT}/WRONG-HANDOFF.json"
    errors = (
        schema_validation_errors(schema, wrong_path)
        + document_errors(contract, wrong_path)
    )
    tests.append(
        negative_result(
            "wrong-reserved-path",
            errors,
            "locator-west:packetPath-mismatch",
        )
    )

    wrong_direction = copy.deepcopy(instance)
    west = next(
        value
        for value in wrong_direction["directions"]
        if value["taskId"] == "PLAY-081"
    )
    west["direction"] = "south"
    errors = (
        schema_validation_errors(schema, wrong_direction)
        + document_errors(contract, wrong_direction)
    )
    tests.append(
        negative_result(
            "wrong-direction",
            errors,
            "locator-west:direction-mismatch",
        )
    )

    sibling_errors = document_errors(
        contract,
        instance,
        selected_direction="east",
    )
    tests.append(
        negative_result(
            "sibling-direction-selection",
            sibling_errors,
            "locator-selection:sibling-direction:east",
        )
    )

    with tempfile.TemporaryDirectory(
        prefix="play081-locator-authority-"
    ) as temporary:
        fixture = Path(temporary)
        packet = fixture / WEST_PACKET_PATH
        packet.parent.mkdir(parents=True)
        sentinel = b"preexisting-packet-sentinel"
        packet.write_bytes(sentinel)
        _, errors = packet_target_errors(fixture, contract)
        tests.append(
            negative_result(
                "preexisting-packet",
                errors,
                "locator-packet:preexisting",
                targetUnchanged=packet.read_bytes() == sentinel,
            )
        )

        symlink_fixture = fixture / "symlink-repository"
        symlink_packet = symlink_fixture / WEST_PACKET_PATH
        symlink_packet.parent.mkdir(parents=True)
        redirect = fixture / "redirect-target.json"
        redirect_sentinel = b"redirect-sentinel"
        redirect.write_bytes(redirect_sentinel)
        symlink_packet.symlink_to(redirect)
        _, errors = packet_target_errors(symlink_fixture, contract)
        tests.append(
            negative_result(
                "symlink-packet",
                errors,
                next(
                    error
                    for error in errors
                    if error.startswith(
                        "locator-packet:unsafe:SYMLINK_COMPONENT:"
                    )
                ),
                targetUnchanged=redirect.read_bytes() == redirect_sentinel,
            )
        )
    return tests


def build_proof(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    authority = contract["sourceCandidatePacketLocatorAuthority"]
    schema = load_json(
        repository_file(root, authority["schema"]["path"], SCHEMA_PATH)
    )
    instance = load_json(
        repository_file(root, authority["instance"]["path"], INSTANCE_PATH)
    )
    packet = root / WEST_PACKET_PATH
    existed_before = packet.exists() or packet.is_symlink()
    positive = validate_locator_authority(root, contract)
    negatives = dynamic_negatives(root, contract, schema, instance)
    exists_after = packet.exists() or packet.is_symlink()
    proof_relative = pipeline_relative(contract, PROOF_IDENTITY)
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "stage": "zero_pixel_locator_authority_consumption",
        "authority": {
            "commit": AUTHORITY_COMMIT,
            "schemaPath": SCHEMA_PATH,
            "schemaSha256": SCHEMA_SHA256,
            "instancePath": INSTANCE_PATH,
            "instanceSha256": INSTANCE_SHA256,
        },
        "reservedPacket": {
            "path": WEST_PACKET_PATH,
            "pipelineIdentity": "postSource.sourceCandidatePacket",
            "safeWriter": "write_exact_json_no_overwrite",
            "creationPolicy": "exclusive_no_overwrite_nofollow",
            "existedBefore": existed_before,
            "existsAfter": exists_after,
            "created": False,
        },
        "proofOutput": proof_relative,
        "positive": positive,
        "negativeTests": negatives,
        "negativeTestCount": len(negatives),
        "allNegativesPassed": all(value["passed"] for value in negatives),
        "invocations": dict(ZERO_INVOCATIONS),
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "passed": (
            positive["passed"]
            and all(value["passed"] for value in negatives)
            and not existed_before
            and not exists_after
        ),
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract_path = repository_file(root, args.contract, DEFAULT_CONTRACT)
    contract = load_json(contract_path)
    proof = build_proof(root, contract)
    if args.mode == "write-proof":
        relative = pipeline_relative(contract, PROOF_IDENTITY)
        write_exact_json_no_overwrite(
            root,
            relative,
            proof,
            expected=relative,
        )
    print(json.dumps(proof, indent=2, sort_keys=True))
    return 0 if proof["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
