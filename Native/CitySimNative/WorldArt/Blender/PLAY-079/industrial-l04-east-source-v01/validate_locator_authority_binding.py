#!/usr/bin/env python3
"""Bind PLAY-079 East to the published source-packet locator authority."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.metadata
import json
import os
import pathlib
import subprocess
import sys
import tempfile
from typing import Any, NoReturn

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError, ValidationError

import east_output_safety as output_safety


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
EVIDENCE_ROOT = (
    REPOSITORY_ROOT
    / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01"
)
RUNNER_CONTRACT_PATH = SOURCE_ROOT / "RUNNER-CONTRACT.json"
SAFETY_PATH = SOURCE_ROOT / "east_output_safety.py"
RECEIPT_PATH = EVIDENCE_ROOT / "LOCATOR-AUTHORITY-BINDING-RECEIPT.json"
AUTHORITY_COMMIT = "fa66b5605deca987685c058a072613e89a0d8be9"
AUTHORITY_INSTANCE_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-candidate-packet-locators-v1.json"
)
AUTHORITY_SCHEMA_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-candidate-packet-locators-v1.schema.json"
)
AUTHORITY_INSTANCE_SHA256 = (
    "a2c8daf558274bed9088b6c9ab616044e919af5b19101a01c2fe3a1b89122e65"
)
AUTHORITY_SCHEMA_SHA256 = (
    "cb9716330593224bc5cbdae46052cff17cbb84a270ca9976c5452b8075308cbe"
)
EXPECTED_TASK_ID = "PLAY-079"
EXPECTED_DIRECTION = "east"
EXPECTED_BRANCH = "codex/citysim-world-art-east"
EXPECTED_EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01"
)
EXPECTED_PACKET_PATH = f"{EXPECTED_EVIDENCE_ROOT}/SOURCE-STAGE-HANDOFF.json"
EXPECTED_WRITER_CLASS = "prepare_launch_bound"
PIXEL_SUFFIXES = {
    ".bmp",
    ".exr",
    ".jpeg",
    ".jpg",
    ".png",
    ".tif",
    ".tiff",
    ".webp",
}


class BindingRejected(RuntimeError):
    """Stable fail-closed locator-authority rejection."""

    def __init__(self, code: str, detail: str):
        super().__init__(detail)
        self.code = code
        self.detail = detail


def reject(code: str, detail: object) -> NoReturn:
    raise BindingRejected(code, str(detail))


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    try:
        return sha256_bytes(path.read_bytes())
    except OSError as error:
        raise BindingRejected("authority_file_unreadable", f"{path}: {error}") from error


def repository_relative(path: pathlib.Path) -> str:
    try:
        return path.relative_to(REPOSITORY_ROOT).as_posix()
    except ValueError as error:
        raise BindingRejected("path_outside_repository", str(path)) from error


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def load_json_bytes(payload: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(payload)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise BindingRejected(f"{label}_json_invalid", str(error)) from error
    if not isinstance(value, dict):
        reject(f"{label}_not_object", type(value).__name__)
    return value


def load_json_file(path: pathlib.Path, label: str) -> dict[str, Any]:
    try:
        return load_json_bytes(path.read_bytes(), label)
    except OSError as error:
        raise BindingRejected(f"{label}_unreadable", f"{path}: {error}") from error


def require_safe_repository_path(value: object, label: str) -> str:
    if not isinstance(value, str) or not value or value.startswith("/") or "\\" in value:
        reject("unsafe_repository_path", f"{label}: {value!r}")
    pure = pathlib.PurePosixPath(value)
    if (
        pure.as_posix() != value
        or "//" in value
        or any(part in {"", ".", ".."} for part in pure.parts)
    ):
        reject("unsafe_repository_path", f"{label}: {value!r}")
    return value


def require_dict(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject("authority_shape_invalid", f"{label}: {type(value).__name__}")
    return value


def require_list(value: object, label: str) -> list[Any]:
    if not isinstance(value, list):
        reject("authority_shape_invalid", f"{label}: {type(value).__name__}")
    return value


def git_output(*arguments: str) -> str:
    completed = subprocess.run(
        ["git", *arguments],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise BindingRejected(
            "git_identity_check_failed",
            f"git {' '.join(arguments)}: {completed.stderr.strip()}",
        )
    return completed.stdout.strip()


def validate_git_authority() -> None:
    branch = git_output("branch", "--show-current")
    if branch not in {EXPECTED_BRANCH, "master"}:
        reject("branch_mismatch", branch)
    completed = subprocess.run(
        ["git", "merge-base", "--is-ancestor", AUTHORITY_COMMIT, "HEAD"],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        reject("locator_authority_not_ancestor", AUTHORITY_COMMIT)


def east_record(instance: dict[str, Any]) -> dict[str, Any]:
    directions = require_list(instance.get("directions"), "directions")
    if not directions:
        reject("east_record_missing", "directions")
    east = require_dict(directions[0], "directions[0]")
    expected_identity = {
        "taskId": EXPECTED_TASK_ID,
        "direction": EXPECTED_DIRECTION,
        "branch": EXPECTED_BRANCH,
    }
    for key, expected in expected_identity.items():
        if east.get(key) != expected:
            reject(
                "east_identity_mismatch",
                f"{key}: expected {expected!r}, got {east.get(key)!r}",
            )
    return east


def validate_runner_and_writer_binding(
    instance: dict[str, Any],
    runner: dict[str, Any],
) -> dict[str, Any]:
    east = east_record(instance)
    authority_root = require_safe_repository_path(
        east.get("evidenceRoot"),
        "directions[0].evidenceRoot",
    )
    authority_packet = require_safe_repository_path(
        east.get("packetPath"),
        "directions[0].packetPath",
    )
    if authority_root != EXPECTED_EVIDENCE_ROOT:
        reject(
            "east_evidence_root_mismatch",
            f"{authority_root!r} != {EXPECTED_EVIDENCE_ROOT!r}",
        )
    if authority_packet != EXPECTED_PACKET_PATH:
        reject(
            "east_packet_path_mismatch",
            f"{authority_packet!r} != {EXPECTED_PACKET_PATH!r}",
        )
    if east.get("status") != "reserved":
        reject("east_packet_status_mismatch", east.get("status"))
    if east.get("writer") != "direction_cell":
        reject("east_writer_mismatch", east.get("writer"))
    if east.get("creationPolicy") != "exclusive_no_overwrite_nofollow":
        reject("east_creation_policy_mismatch", east.get("creationPolicy"))

    runner_identity = require_dict(
        require_dict(runner.get("sourceStage"), "runner.sourceStage").get("identity"),
        "runner.sourceStage.identity",
    )
    for key, expected in {
        "taskId": EXPECTED_TASK_ID,
        "direction": EXPECTED_DIRECTION,
        "branch": EXPECTED_BRANCH,
    }.items():
        if runner_identity.get(key) != expected:
            reject(
                "runner_identity_mismatch",
                f"{key}: expected {expected!r}, got {runner_identity.get(key)!r}",
            )
    runner_root = runner_identity.get("evidenceRoot")
    if runner_root != f"{authority_root}/":
        reject(
            "runner_evidence_root_mismatch",
            f"{runner_root!r} != {authority_root + '/'!r}",
        )
    output_inventory = require_dict(
        runner.get("outputInventory"),
        "runner.outputInventory",
    )
    if output_inventory.get("root") != runner_root:
        reject(
            "runner_output_root_mismatch",
            f"{output_inventory.get('root')!r} != {runner_root!r}",
        )
    runner_stage = require_dict(runner.get("sourceStage"), "runner.sourceStage")
    if runner_stage.get("handoffOutputPath") != authority_packet:
        reject(
            "runner_packet_path_mismatch",
            f"{runner_stage.get('handoffOutputPath')!r} != {authority_packet!r}",
        )
    if output_inventory.get("sourceStageHandoff") != "SOURCE-STAGE-HANDOFF.json":
        reject(
            "runner_packet_leaf_mismatch",
            output_inventory.get("sourceStageHandoff"),
        )
    reconstructed = (
        f"{output_inventory['root']}{output_inventory['sourceStageHandoff']}"
    )
    if reconstructed != authority_packet:
        reject(
            "runner_packet_reconstruction_mismatch",
            f"{reconstructed!r} != {authority_packet!r}",
        )

    writer_owners = sorted(
        writer_class
        for writer_class, identities in output_safety.WRITER_IDENTITIES.items()
        if authority_packet in identities
    )
    if writer_owners != [EXPECTED_WRITER_CLASS]:
        reject("safe_writer_ownership_mismatch", writer_owners)
    output_safety._parts(authority_packet)
    return {
        "taskId": EXPECTED_TASK_ID,
        "direction": EXPECTED_DIRECTION,
        "branch": EXPECTED_BRANCH,
        "authorityEvidenceRoot": authority_root,
        "runnerEvidenceRoot": runner_root,
        "evidenceRootComparison": "authorityEvidenceRoot + '/' == runnerEvidenceRoot",
        "packetPath": authority_packet,
        "status": "reserved",
        "writer": "direction_cell",
        "creationPolicy": "exclusive_no_overwrite_nofollow",
        "safeWriterClass": EXPECTED_WRITER_CLASS,
        "safeWriterOwners": writer_owners,
    }


def validate_schema_instance(
    schema: dict[str, Any],
    instance: dict[str, Any],
) -> None:
    try:
        Draft202012Validator.check_schema(schema)
        Draft202012Validator(schema).validate(instance)
    except SchemaError as error:
        raise BindingRejected("authority_schema_invalid", error.message) from error
    except ValidationError as error:
        raise BindingRejected("authority_instance_schema_invalid", error.message) from error


def validate_documents(
    schema_bytes: bytes,
    instance_bytes: bytes,
    runner: dict[str, Any],
    *,
    expected_schema_sha256: str = AUTHORITY_SCHEMA_SHA256,
    expected_instance_sha256: str = AUTHORITY_INSTANCE_SHA256,
    validate_git: bool = False,
) -> dict[str, Any]:
    actual_schema_sha256 = sha256_bytes(schema_bytes)
    actual_instance_sha256 = sha256_bytes(instance_bytes)
    if actual_schema_sha256 != expected_schema_sha256:
        reject(
            "locator_authority_schema_hash_mismatch",
            f"{actual_schema_sha256} != {expected_schema_sha256}",
        )
    if actual_instance_sha256 != expected_instance_sha256:
        reject(
            "locator_authority_instance_hash_mismatch",
            f"{actual_instance_sha256} != {expected_instance_sha256}",
        )
    schema = load_json_bytes(schema_bytes, "authority_schema")
    instance = load_json_bytes(instance_bytes, "authority_instance")
    binding = validate_runner_and_writer_binding(instance, runner)
    validate_schema_instance(schema, instance)
    if validate_git:
        validate_git_authority()
    return binding


def expect_binding_rejection(
    case: str,
    expected_code: str,
    schema_bytes: bytes,
    instance_bytes: bytes,
    runner: dict[str, Any],
    *,
    expected_schema_sha256: str | None = None,
    expected_instance_sha256: str | None = None,
) -> dict[str, str]:
    try:
        validate_documents(
            schema_bytes,
            instance_bytes,
            runner,
            expected_schema_sha256=(
                expected_schema_sha256
                if expected_schema_sha256 is not None
                else sha256_bytes(schema_bytes)
            ),
            expected_instance_sha256=(
                expected_instance_sha256
                if expected_instance_sha256 is not None
                else sha256_bytes(instance_bytes)
            ),
        )
    except BindingRejected as error:
        if error.code != expected_code:
            reject(
                "negative_case_wrong_rejection",
                f"{case}: expected {expected_code}, got {error.code}: {error.detail}",
            )
        return {"case": case, "result": "REJECTED", "code": error.code}
    reject("negative_case_failed_open", case)


def mutated_instance_bytes(
    instance: dict[str, Any],
    mutation: Any,
) -> bytes:
    fixture = copy.deepcopy(instance)
    mutation(fixture)
    return canonical_bytes(fixture)


def output_safety_negatives() -> list[dict[str, str]]:
    results: list[dict[str, str]] = []
    with tempfile.TemporaryDirectory(
        prefix="play079-east-locator-preexisting-"
    ) as temporary:
        root = pathlib.Path(temporary)
        policy = output_safety.OutputPolicy(
            root,
            {EXPECTED_WRITER_CLASS: frozenset({EXPECTED_PACKET_PATH})},
        )
        target = root / pathlib.PurePosixPath(EXPECTED_PACKET_PATH)
        target.parent.mkdir(parents=True)
        target.write_bytes(b"preexisting-reserved-packet\n")
        try:
            policy.write_bytes_exclusive(
                target,
                b"must-not-overwrite\n",
                EXPECTED_WRITER_CLASS,
            )
        except output_safety.OutputSafetyRejected as error:
            if error.code != "output_already_exists":
                reject(
                    "negative_case_wrong_rejection",
                    f"preexisting_file: {error.code}: {error.detail}",
                )
            results.append(
                {
                    "case": "preexisting_file",
                    "result": "REJECTED",
                    "code": error.code,
                }
            )
        else:
            reject("negative_case_failed_open", "preexisting_file")
        if target.read_bytes() != b"preexisting-reserved-packet\n":
            reject("preexisting_file_modified", target)

    with tempfile.TemporaryDirectory(
        prefix="play079-east-locator-symlink-"
    ) as temporary:
        root = pathlib.Path(temporary)
        policy = output_safety.OutputPolicy(
            root,
            {EXPECTED_WRITER_CLASS: frozenset({EXPECTED_PACKET_PATH})},
        )
        target = root / pathlib.PurePosixPath(EXPECTED_PACKET_PATH)
        target.parent.mkdir(parents=True)
        outside = root / "redirect-target"
        outside.mkdir()
        held = root / "held-east-root"

        def redirect_parent() -> None:
            target.parent.rename(held)
            target.parent.symlink_to(outside, target_is_directory=True)

        try:
            policy.write_bytes_exclusive(
                target,
                b"must-not-follow\n",
                EXPECTED_WRITER_CLASS,
                pre_write_hook=redirect_parent,
            )
        except output_safety.OutputSafetyRejected as error:
            if error.code != "output_symlink_component":
                reject(
                    "negative_case_wrong_rejection",
                    f"symlink_redirect: {error.code}: {error.detail}",
                )
            results.append(
                {
                    "case": "symlink_redirect",
                    "result": "REJECTED",
                    "code": error.code,
                }
            )
        else:
            reject("negative_case_failed_open", "symlink_redirect")
        if any(outside.iterdir()):
            reject("symlink_redirect_wrote_outside", outside)
    return results


def negative_cases(
    schema_bytes: bytes,
    instance_bytes: bytes,
    instance: dict[str, Any],
    runner: dict[str, Any],
) -> list[dict[str, str]]:
    zeros = "0" * 64
    cases = [
        expect_binding_rejection(
            "wrong_schema_authority_hash",
            "locator_authority_schema_hash_mismatch",
            schema_bytes,
            instance_bytes,
            runner,
            expected_schema_sha256=zeros,
            expected_instance_sha256=AUTHORITY_INSTANCE_SHA256,
        ),
        expect_binding_rejection(
            "wrong_instance_authority_hash",
            "locator_authority_instance_hash_mismatch",
            schema_bytes,
            instance_bytes,
            runner,
            expected_schema_sha256=AUTHORITY_SCHEMA_SHA256,
            expected_instance_sha256=zeros,
        ),
        expect_binding_rejection(
            "wrong_east_path",
            "east_packet_path_mismatch",
            schema_bytes,
            mutated_instance_bytes(
                instance,
                lambda value: value["directions"][0].__setitem__(
                    "packetPath",
                    f"{EXPECTED_EVIDENCE_ROOT}/WRONG-SOURCE-STAGE-HANDOFF.json",
                ),
            ),
            runner,
        ),
        expect_binding_rejection(
            "south_substitution",
            "east_identity_mismatch",
            schema_bytes,
            mutated_instance_bytes(
                instance,
                lambda value: value["directions"].__setitem__(
                    0,
                    copy.deepcopy(value["directions"][1]),
                ),
            ),
            runner,
        ),
        expect_binding_rejection(
            "west_substitution",
            "east_identity_mismatch",
            schema_bytes,
            mutated_instance_bytes(
                instance,
                lambda value: value["directions"].__setitem__(
                    0,
                    copy.deepcopy(value["directions"][2]),
                ),
            ),
            runner,
        ),
        expect_binding_rejection(
            "unsafe_components",
            "unsafe_repository_path",
            schema_bytes,
            mutated_instance_bytes(
                instance,
                lambda value: value["directions"][0].__setitem__(
                    "packetPath",
                    f"{EXPECTED_EVIDENCE_ROOT}/../SOURCE-STAGE-HANDOFF.json",
                ),
            ),
            runner,
        ),
    ]
    return cases + output_safety_negatives()


def pixel_inventory() -> list[str]:
    roots = (SOURCE_ROOT, EVIDENCE_ROOT)
    return sorted(
        repository_relative(path)
        for root in roots
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES
    )


def build_receipt() -> dict[str, Any]:
    pixels_before = pixel_inventory()
    if pixels_before:
        reject("preexisting_pixel_files", pixels_before)
    reserved_packet = REPOSITORY_ROOT / pathlib.PurePosixPath(EXPECTED_PACKET_PATH)
    if os.path.lexists(reserved_packet):
        reject("reserved_packet_already_exists", EXPECTED_PACKET_PATH)

    schema_bytes = AUTHORITY_SCHEMA_PATH.read_bytes()
    instance_bytes = AUTHORITY_INSTANCE_PATH.read_bytes()
    runner = load_json_file(RUNNER_CONTRACT_PATH, "runner_contract")
    instance = load_json_bytes(instance_bytes, "authority_instance")
    binding = validate_documents(
        schema_bytes,
        instance_bytes,
        runner,
        validate_git=True,
    )
    rejections = negative_cases(
        schema_bytes,
        instance_bytes,
        instance,
        runner,
    )

    pixels_after = pixel_inventory()
    if pixels_after != pixels_before:
        reject("pixel_inventory_changed", {"before": pixels_before, "after": pixels_after})
    if os.path.lexists(reserved_packet):
        reject("reserved_packet_created", EXPECTED_PACKET_PATH)
    return {
        "schema": "citysim.play-079.locator-authority-binding-receipt.v1",
        "schemaVersion": 1,
        "taskId": EXPECTED_TASK_ID,
        "direction": EXPECTED_DIRECTION,
        "branch": EXPECTED_BRANCH,
        "result": "PASS",
        "authority": {
            "commit": AUTHORITY_COMMIT,
            "schema": {
                "path": repository_relative(AUTHORITY_SCHEMA_PATH),
                "sha256": AUTHORITY_SCHEMA_SHA256,
                "validation": "PASS",
            },
            "instance": {
                "path": repository_relative(AUTHORITY_INSTANCE_PATH),
                "sha256": AUTHORITY_INSTANCE_SHA256,
                "validation": "PASS",
            },
            "commitAncestry": "PASS",
            "grants": {
                "sourceAdmission": False,
                "rendererQuarantine": False,
                "rendererActivation": False,
                "productionSelection": False,
                "shipping": False,
            },
        },
        "bindings": {
            "east": binding,
            "runnerContract": {
                "path": repository_relative(RUNNER_CONTRACT_PATH),
                "sha256": sha256_file(RUNNER_CONTRACT_PATH),
            },
            "safeWriterInventory": {
                "path": repository_relative(SAFETY_PATH),
                "sha256": sha256_file(SAFETY_PATH),
                "writerClass": EXPECTED_WRITER_CLASS,
            },
            "validator": {
                "path": repository_relative(pathlib.Path(__file__).resolve()),
                "sha256": sha256_file(pathlib.Path(__file__).resolve()),
                "jsonschemaVersion": importlib.metadata.version("jsonschema"),
            },
        },
        "negativeCases": rejections,
        "reservedPacket": {
            "path": EXPECTED_PACKET_PATH,
            "status": "reserved",
            "existsBefore": False,
            "existsAfter": False,
            "created": False,
        },
        "invocations": {
            "blenderProcesses": 0,
            "blenderRenderApiCalls": 0,
            "dccProcesses": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "renderInvocations": 0,
        },
        "pixelFiles": {
            "before": pixels_before,
            "after": pixels_after,
            "created": 0,
        },
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check-receipt",
        action="store_true",
        help="Require the committed receipt to equal the deterministic proof.",
    )
    arguments = parser.parse_args()
    try:
        payload = canonical_bytes(build_receipt())
        if arguments.check_receipt:
            try:
                committed = RECEIPT_PATH.read_bytes()
            except OSError as error:
                raise BindingRejected("receipt_unreadable", str(error)) from error
            if committed != payload:
                reject(
                    "receipt_drift",
                    f"{sha256_bytes(committed)} != {sha256_bytes(payload)}",
                )
    except BindingRejected as error:
        print(
            json.dumps(
                {"result": "REJECTED", "code": error.code, "detail": error.detail},
                sort_keys=True,
            )
        )
        return 1
    sys.stdout.buffer.write(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
