#!/usr/bin/env python3
"""Fail-closed, zero-DCC orchestration contract for PLAY-081 West.

The module validates future Integration bindings through exact committed blobs
and exercises only non-authoritative synthetic scheduling traces. It contains
no Blender launch or production receipt command. All production bindings are
absent, so every authority-bearing CLI mode rejects before process or output
creation.
"""

from __future__ import annotations

import argparse
import copy
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
from typing import Any

from jsonschema import Draft202012Validator

from west_path_safety import (
    PathSafetyError,
    lexical_repository_path,
    write_exact_json_no_overwrite,
)


SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01"
)
DEFAULT_EXECUTION_CONTRACT = f"{SOURCE_ROOT}/WEST-EXECUTION-ORCHESTRATION-V2.json"
DEFAULT_RUNNER_CONTRACT = f"{SOURCE_ROOT}/RUNNER-CONTRACT.json"
DEFAULT_CLOSURE_CONSUMER = (
    f"{SOURCE_ROOT}/schedule-consumer-v01/"
    "consume_west_parallel_schedule_v1.py"
)
DEFAULT_HIGH_LEVEL_ORCHESTRATOR = (
    f"{SOURCE_ROOT}/west_execution_orchestration_v2.py"
)
DEFAULT_LOW_LEVEL_RUNNER = f"{SOURCE_ROOT}/run_west_source.py"
DEFAULT_CLOSURE_SCENE = (
    f"{SOURCE_ROOT}/execution-closure-v01/SCENE-BINDING.json"
)
DEFAULT_CLOSURE_MATERIALS = (
    f"{SOURCE_ROOT}/execution-closure-v01/MATERIALS-BINDING.json"
)
DEFAULT_CLOSURE_TOOLCHAIN = (
    f"{SOURCE_ROOT}/execution-closure-v01/TOOLCHAIN-BINDING.json"
)
INTEGRATION_PREFIX = "docs/production/evidence/INTEGRATION/"
SCHEDULE_SCHEMA = "citysim.integration.world-art-two-slot-schedule.v1"
GLOBAL_RECEIPT_SCHEMA = (
    "citysim.integration.world-art-two-slot-execution-receipt.v1"
)
HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
UTC_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$")
ZERO_INVOCATIONS = {
    "blenderProcessLaunches": 0,
    "blenderRenderApiCalls": 0,
    "imageGenInvocations": 0,
    "normalizerInvocations": 0,
    "contactSheetInvocations": 0,
    "pixelFiles": 0,
    "productionReceipts": 0,
    "sourceCandidatePackets": 0,
}
CLOSURE_ZERO_ACTIVITY = {
    "dccStarts": 0,
    "childStarts": 0,
    "renders": 0,
    "pixels": 0,
    "normalizerInvocations": 0,
    "sourcePackets": 0,
    "productionReceipts": 0,
}
MODEL_ROUTE_CARRIER_COMMIT = "4f041092dc6bd90da858ea959d6d5c5554ecdfe4"
MODEL_ROUTE_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "MODEL-ROUTING-PLAY-081-WEST-V14-EXACT-CLOSURE-R2.json"
)
MODEL_ROUTE_FILE_SHA256 = (
    "0d62e26ff49e995e519b1f9d04d4ed9f46c812b2f65bea4877dca88be1122027"
)
MODEL_ROUTE_ID = "quality-v2:play-081-west-v14-exact-closure-r2"
MODEL_ROUTE_SHA256 = (
    "16d011163da66a72637aa0f9ca3bde30d65c7f0dc97ed8c1d434f96bdb253809"
)
MODEL_ROUTE_AUTHORITY_COMMIT = "b4dcbd0418176d680ecf2d993c16649fc401a92e"
MODEL_ROUTE_EXPECTED_HEAD = "aae1e799f1eaabba88f1c1e85c3974e778eab69d"
SOURCE_STAGE_SCHEMA_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-stage-handoff-schema-v2.json"
)
SOURCE_STAGE_SCHEMA_SHA256 = (
    "85f6a2824c273a1e63354df79a97e5a59c2909a68771613b325664d649ac53ec"
)


class OrchestrationError(ValueError):
    """Stable fail-closed orchestration error."""


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise OrchestrationError(f"DUPLICATE_JSON_KEY:{key}")
        value[key] = item
    return value


def _reject_nonfinite(value: str) -> None:
    raise OrchestrationError(f"NONFINITE_JSON_VALUE:{value}")


def decode_json_object(data: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(
            data.decode("utf-8"),
            object_pairs_hook=_reject_duplicate_pairs,
            parse_constant=_reject_nonfinite,
        )
    except UnicodeDecodeError as error:
        raise OrchestrationError(f"INVALID_UTF8:{label}") from error
    if not isinstance(value, dict):
        raise OrchestrationError(f"EXPECTED_JSON_OBJECT:{label}")
    return value


def load_json(path: Path) -> dict[str, Any]:
    value = decode_json_object(path.read_bytes(), str(path))
    if not isinstance(value, dict):
        raise OrchestrationError(f"EXPECTED_JSON_OBJECT:{path}")
    return value


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def capture_regular_file_no_follow(root: Path, relative: str) -> bytes:
    """Capture one stable regular file without following any symlink."""
    path = lexical_repository_path(root, relative, expected=relative)
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        raise OrchestrationError("NO_FOLLOW_CAPTURE_API_UNAVAILABLE")
    parent_parts = relative.split("/")[:-1]
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    descriptor = os.open(root.resolve(), flags)
    try:
        for part in parent_parts:
            try:
                child = os.open(part, flags, dir_fd=descriptor)
            except OSError as error:
                raise OrchestrationError(
                    f"AUTHORITY_PARENT_NOT_REGULAR:{relative}"
                ) from error
            os.close(descriptor)
            descriptor = child
        try:
            file_descriptor = os.open(
                relative.rsplit("/", 1)[-1],
                os.O_RDONLY | os.O_NOFOLLOW,
                dir_fd=descriptor,
            )
        except OSError as error:
            raise OrchestrationError(
                f"AUTHORITY_FILE_NOT_REGULAR:{relative}"
            ) from error
        try:
            before = os.fstat(file_descriptor)
            if not stat.S_ISREG(before.st_mode):
                raise OrchestrationError(
                    f"AUTHORITY_FILE_NOT_REGULAR:{relative}"
                )
            chunks: list[bytes] = []
            while True:
                chunk = os.read(file_descriptor, 1024 * 1024)
                if not chunk:
                    break
                chunks.append(chunk)
            after = os.fstat(file_descriptor)
        finally:
            os.close(file_descriptor)
    finally:
        os.close(descriptor)
    final = os.lstat(path)
    if not stat.S_ISREG(final.st_mode):
        raise OrchestrationError(f"AUTHORITY_FILE_NOT_REGULAR:{relative}")
    identity_before = (
        before.st_dev,
        before.st_ino,
        before.st_size,
        before.st_mtime_ns,
        before.st_ctime_ns,
    )
    identity_after = (
        after.st_dev,
        after.st_ino,
        after.st_size,
        after.st_mtime_ns,
        after.st_ctime_ns,
    )
    identity_final = (
        final.st_dev,
        final.st_ino,
        final.st_size,
        final.st_mtime_ns,
        final.st_ctime_ns,
    )
    if identity_before != identity_after or identity_after != identity_final:
        raise OrchestrationError(f"AUTHORITY_CHANGED_DURING_CAPTURE:{relative}")
    return b"".join(chunks)


def json_sha256(value: dict[str, Any]) -> str:
    data = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()
    return hashlib.sha256(data).hexdigest()


def execution_closure_contract_errors(
    root: Path,
    execution_contract: dict[str, Any],
) -> list[str]:
    closure = execution_contract.get("executionClosureV1")
    if not isinstance(closure, dict):
        return ["execution-closure:missing"]
    required = {
        "mode",
        "testProtocolRevision",
        "publishedBase",
        "claim",
        "sharedSchema",
        "sharedValidator",
        "sharedAuthority",
        "directionScheduleAdapter",
        "highLevelOrchestrator",
        "lowLevelRunner",
        "frozenArtifacts",
        "authorityInstance",
        "zeroChildBoundary",
    }
    if set(closure) != required:
        return ["execution-closure:shape"]
    errors: list[str] = []
    if closure.get("mode") != "validation_only":
        errors.append("execution-closure:mode")
    if closure.get("testProtocolRevision") != 6:
        errors.append("execution-closure:protocol-revision")
    if closure.get("publishedBase") != (
        "aaee294718a8176b70a4688b738b517f216dd3a7"
    ):
        errors.append("execution-closure:published-base")
    if closure.get("claim") != {
        "path": "docs/production/claims/PLAY-081.world-art-west.md",
        "revision": 7,
        "sha256": (
            "aa5e0acb5988807d1c934326fd6b3da7f594def8dde84b01ab273905f9753ed3"
        ),
    }:
        errors.append("execution-closure:claim")
    expected_bindings = {
        "sharedSchema": {
            "path": (
                "docs/production/evidence/INTEGRATION/"
                "industrial-l04-direction-execution-authority-schema-v1.json"
            ),
            "sha256": (
                "2796e224780c259b29d68b50cb12cdbbe45452535da681bba3522af920459491"
            ),
        },
        "sharedValidator": {
            "path": (
                ".agents/skills/operate-citysim-integration/scripts/"
                "validate_industrial_l04_direction_execution_authority_v1.py"
            ),
            "sha256": (
                "b212d2776d34b3334910c6b0b02ffba244919f4a83d5c0019c30bca87648d8ae"
            ),
        },
        "sharedAuthority": {
            "path": (
                "docs/production/evidence/INTEGRATION/"
                "INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1-AUTHORITY.md"
            ),
            "sha256": (
                "0125539f015ab8069c11093e755ac6e43d7b37994c86515fc06894e401b7eb54"
            ),
        },
    }
    for name, expected in expected_bindings.items():
        binding = closure.get(name)
        if binding != expected:
            errors.append(f"execution-closure:{name}:binding")
            continue
        try:
            payload = capture_regular_file_no_follow(root, expected["path"])
        except (OSError, OrchestrationError, PathSafetyError) as error:
            errors.append(f"execution-closure:{name}:unsafe:{error}")
            continue
        if hashlib.sha256(payload).hexdigest() != expected["sha256"]:
            errors.append(f"execution-closure:{name}:working-tree-sha256")
    if closure.get("directionScheduleAdapter") != DEFAULT_CLOSURE_CONSUMER:
        errors.append("execution-closure:direction-schedule-adapter")
    if closure.get("highLevelOrchestrator") != DEFAULT_HIGH_LEVEL_ORCHESTRATOR:
        errors.append("execution-closure:high-level-orchestrator")
    if closure.get("lowLevelRunner") != DEFAULT_LOW_LEVEL_RUNNER:
        errors.append("execution-closure:low-level-runner")
    if closure.get("frozenArtifacts") != {
        "scene": DEFAULT_CLOSURE_SCENE,
        "materials": DEFAULT_CLOSURE_MATERIALS,
        "toolchain": DEFAULT_CLOSURE_TOOLCHAIN,
    }:
        errors.append("execution-closure:frozen-artifacts")
    if closure.get("authorityInstance") != {
        "state": "not_published",
        "path": None,
        "publicationCommit": None,
        "sha256": None,
    }:
        errors.append("execution-closure:authority-instance")
    if closure.get("zeroChildBoundary") != {
        "validationOnly": True,
        "liveLeaseAuthorized": False,
        "childStartAuthorized": False,
        "dccExecutionAuthorized": False,
        "renderAuthorized": False,
        "pixelAuthorized": False,
    }:
        errors.append("execution-closure:zero-child-boundary")
    return sorted(set(errors))


def _load_exact_module(
    root: Path,
    binding: dict[str, str],
    module_name: str,
) -> Any:
    payload = capture_regular_file_no_follow(root, binding["path"])
    if hashlib.sha256(payload).hexdigest() != binding["sha256"]:
        raise OrchestrationError(f"MODULE_SHA256_MISMATCH:{module_name}")
    path = lexical_repository_path(
        root,
        binding["path"],
        expected=binding["path"],
    )
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise OrchestrationError(f"MODULE_LOAD_FAILED:{module_name}")
    module = importlib.util.module_from_spec(spec)
    parent = str(path.parent)
    inserted = parent not in sys.path
    if inserted:
        sys.path.insert(0, parent)
    try:
        spec.loader.exec_module(module)
    finally:
        if inserted:
            sys.path.remove(parent)
    return module


def closure_blocked(errors: list[str]) -> dict[str, Any]:
    return {
        "schema": "citysim.play-081.west-execution-closure.v1",
        "taskId": "PLAY-081",
        "direction": "west",
        "result": "BLOCKED",
        "reasonCodes": sorted(set(errors)),
        "validationOnly": True,
        "highLevelOrchestratorReached": True,
        "runnerValidationBoundaryReached": False,
        "childStartAuthorized": False,
        "activity": dict(CLOSURE_ZERO_ACTIVITY),
    }


def validate_execution_closure(
    root: Path,
    execution_contract: dict[str, Any],
    *,
    authority_path: str | None,
    trusted_head: str | None,
    worker_head: str | None,
    authority_publication_commit: str | None,
) -> dict[str, Any]:
    """Validate one published authority and reach only the runner boundary."""
    errors = execution_closure_contract_errors(root, execution_contract)
    arguments = {
        "authority": authority_path,
        "trustedHead": trusted_head,
        "workerHead": worker_head,
        "authorityPublicationCommit": authority_publication_commit,
    }
    for label, value in arguments.items():
        if not isinstance(value, str) or not value:
            errors.append(f"execution-closure:{label}:missing")
    if errors:
        return closure_blocked(errors)

    closure = execution_contract["executionClosureV1"]
    try:
        shared = _load_exact_module(
            root,
            closure["sharedValidator"],
            "industrial_l04_direction_execution_authority_v1",
        )
        shared_result = shared.validate(
            root,
            lexical_repository_path(root, authority_path),
            trusted_head=trusted_head,
            worker_head=worker_head,
            authority_publication_commit=authority_publication_commit,
        )
        authority_payload = capture_regular_file_no_follow(root, authority_path)
        authority = decode_json_object(
            authority_payload,
            "direction-execution-authority",
        )
    except (OSError, ValueError, OrchestrationError, PathSafetyError) as error:
        return closure_blocked([f"execution-closure:authority:{error}"])

    expected_artifacts = {
        "executionContract": DEFAULT_EXECUTION_CONTRACT,
        "directionScheduleAdapter": DEFAULT_CLOSURE_CONSUMER,
        "highLevelOrchestrator": DEFAULT_HIGH_LEVEL_ORCHESTRATOR,
        "runnerContract": DEFAULT_RUNNER_CONTRACT,
        "runnerEntrypoint": DEFAULT_LOW_LEVEL_RUNNER,
        "scene": DEFAULT_CLOSURE_SCENE,
        "materials": DEFAULT_CLOSURE_MATERIALS,
        "toolchain": DEFAULT_CLOSURE_TOOLCHAIN,
    }
    artifact_errors: list[str] = []
    artifacts = authority.get("artifacts", {})
    for name, expected_path in expected_artifacts.items():
        value = artifacts.get(name)
        if not isinstance(value, dict) or value.get("path") != expected_path:
            artifact_errors.append(f"execution-closure:artifact:{name}")
    if artifact_errors:
        return closure_blocked(artifact_errors)

    runner_binding = artifacts["runnerEntrypoint"]
    try:
        runner = _load_exact_module(
            root,
            runner_binding,
            "play081_west_low_level_validation_boundary",
        )
        runner_result = runner.validate_execution_closure_boundary(
            shared_result,
            authority,
            direct_invocation=False,
        )
    except (OSError, ValueError, OrchestrationError, PathSafetyError) as error:
        return closure_blocked([f"execution-closure:runner:{error}"])
    if runner_result.get("result") != "PASS":
        return closure_blocked(
            [
                f"execution-closure:runner:{value}"
                for value in runner_result.get("errors", ["blocked"])
            ]
        )

    return {
        "schema": "citysim.play-081.west-execution-closure.v1",
        "taskId": "PLAY-081",
        "direction": "west",
        "process": shared_result["process"],
        "grantId": shared_result["grantId"],
        "queueId": shared_result["queueId"],
        "slotId": shared_result["slotId"],
        "authorityPath": shared_result["authorityPath"],
        "authorityPublicationCommit": shared_result[
            "authorityPublicationCommit"
        ],
        "trustedHead": shared_result["trustedHead"],
        "workerHead": shared_result["workerHead"],
        "exclusiveRoots": authority["exclusiveRoots"],
        "artifacts": artifacts,
        "result": "PASS",
        "validationOnly": True,
        "highLevelOrchestratorReached": True,
        "runnerValidationBoundaryReached": True,
        "childStartAuthorized": False,
        "activity": dict(CLOSURE_ZERO_ACTIVITY),
    }


def parse_utc(value: Any) -> datetime:
    if not isinstance(value, str) or UTC_PATTERN.fullmatch(value) is None:
        raise OrchestrationError(f"INVALID_UTC_TIMESTAMP:{value!r}")
    return datetime.fromisoformat(value[:-1] + "+00:00")


def git_output(root: Path, *arguments: str) -> str | None:
    result = subprocess.run(
        ["git", *arguments],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def is_ancestor(root: Path, older: str, newer: str) -> bool:
    if HEX_40.fullmatch(older) is None or HEX_40.fullmatch(newer) is None:
        return False
    return (
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", older, newer],
            cwd=root,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def current_binding_errors(
    execution_contract: dict[str, Any],
    runner_contract: dict[str, Any],
) -> list[str]:
    errors = static_contract_errors(execution_contract, runner_contract)
    for name, binding in execution_contract["futureIntegrationInputs"].items():
        if binding != {
            "state": "not_published",
            "path": None,
            "commit": None,
            "sha256": None,
        }:
            if (
                not isinstance(binding, dict)
                or binding.get("state") != "bound_integration"
                or not isinstance(binding.get("path"), str)
                or not binding["path"].startswith(INTEGRATION_PREFIX)
                or HEX_40.fullmatch(str(binding.get("commit"))) is None
                or HEX_64.fullmatch(str(binding.get("sha256"))) is None
            ):
                errors.append(f"integration-input:{name}:invalid-binding")
        else:
            errors.append(f"integration-input:{name}:not-published")

    appearance = runner_contract.get("appearanceLock", {})
    if not isinstance(appearance, dict) or any(
        not appearance.get(field)
        for field in (
            "documentPath",
            "commit",
            "documentSha256",
            "northProcessASourceSha256",
            "northProcessADecodedRgbaSha256",
        )
    ):
        errors.append("appearance-lock:not-bound")
    profile = runner_contract.get("sourceStage", {}).get(
        "sourceProductionProfile",
        {},
    )
    if profile.get("state") != "bound_integration_profile":
        errors.append("source-production-profile:not-bound")
    if execution_contract.get("productionExecutionEnabled") is not True:
        errors.append("production-execution:disabled")
    if execution_contract.get("productionReceiptEmissionEnabled") is not True:
        errors.append("production-receipt-emission:disabled")
    return sorted(set(errors))


def static_contract_errors(
    execution_contract: dict[str, Any],
    runner_contract: dict[str, Any],
) -> list[str]:
    errors: list[str] = []
    if execution_contract.get("frozenDesignAuthority") != {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-PARALLEL-EXECUTION-CONTRACT-CANDIDATE.md"
        ),
        "commit": "aeaecb0bef4e7fe1e9670b1d57bd49b50b4eeab7",
        "sha256": (
            "a2c726585fa83f9a795c02cb4e97fd476ae3969587db7c5e133ecc9889636e36"
        ),
        "status": "DESIGN_FROZEN_IMPLEMENTATION_AND_INDEPENDENT_AUDIT_REQUIRED",
        "productionAuthority": False,
        "dccAuthority": False,
        "pixelAuthority": False,
    }:
        errors.append("static-contract:frozen-design-authority")
    separation = execution_contract.get("authoritySeparation")
    if (
        not isinstance(separation, dict)
        or separation.get("globalScheduleAndConcurrencyOwner") != "Integration"
        or separation.get("directionReceiptOwner") != "PLAY-081 West"
        or any(
            separation.get(field) is not False
            for field in (
                "syntheticTraceIsAuthority",
                "westMayClaimGlobalCapOrOverlap",
                "integrationAdmitted",
                "rendererQuarantined",
                "productionSelected",
                "shipping",
            )
        )
    ):
        errors.append("static-contract:authority-separation")
    queue = execution_contract.get("queue")
    if not isinstance(queue, list) or len(queue) != 11:
        return ["static-contract:queue"]
    expected_west = {
        "A": ("W-A", 4),
        "B": ("W-B", 8),
        "C": ("W-C", 11),
    }
    process_directories: list[str] = []
    all_leaf_roots: list[str] = []
    for process_id, (job_id, ordinal) in expected_west.items():
        process = execution_contract.get("westProcesses", {}).get(process_id)
        inventory = (
            runner_contract.get("outputInventory", {})
            .get("processes", {})
            .get(process_id)
        )
        if not isinstance(process, dict) or not isinstance(inventory, dict):
            errors.append(f"static-contract:process-{process_id}")
            continue
        if process.get("jobId") != job_id or process.get("ordinal") != ordinal:
            errors.append(f"static-contract:process-{process_id}-identity")
        for field in ("directory", "rawRoot", "semanticRoot", "evidenceRoot"):
            if process.get(field) != inventory.get(field):
                errors.append(f"static-contract:process-{process_id}-{field}")
        roots = [
            process.get("rawRoot"),
            process.get("semanticRoot"),
            process.get("evidenceRoot"),
        ]
        if any(not isinstance(value, str) for value in roots):
            errors.append(f"static-contract:process-{process_id}-roots")
        elif len(set(roots)) != 3:
            errors.append(f"static-contract:process-{process_id}-root-alias")
        else:
            all_leaf_roots.extend(roots)
        if isinstance(process.get("directory"), str):
            process_directories.append(process["directory"])
    if len(set(process_directories)) != 3:
        errors.append("static-contract:process-directory-alias")
    if len(set(all_leaf_roots)) != 9:
        errors.append("static-contract:cross-process-root-alias")
    for index, left in enumerate(process_directories):
        for right in process_directories[index + 1 :]:
            if left.startswith(right + "/") or right.startswith(left + "/"):
                errors.append("static-contract:process-directory-ancestry")
    return sorted(set(errors))


def committed_input_errors(
    root: Path,
    binding: dict[str, Any],
    supplied_path: str | None,
    supplied_sha256: str | None,
    label: str,
) -> tuple[list[str], bytes | None]:
    errors: list[str] = []
    if not isinstance(binding, dict) or binding.get("state") != "bound_integration":
        return [f"{label}:not-bound"], None
    relative = binding.get("path")
    commit = binding.get("commit")
    expected_sha = binding.get("sha256")
    if supplied_path != relative:
        errors.append(f"{label}:path-mismatch")
    if supplied_sha256 != expected_sha:
        errors.append(f"{label}:argument-sha256-mismatch")
    if (
        not isinstance(relative, str)
        or not relative.startswith(INTEGRATION_PREFIX)
        or HEX_40.fullmatch(str(commit)) is None
        or HEX_64.fullmatch(str(expected_sha)) is None
    ):
        return errors + [f"{label}:invalid-binding"], None
    try:
        captured = capture_regular_file_no_follow(root, relative)
    except (OSError, OrchestrationError, PathSafetyError) as error:
        return errors + [f"{label}:unsafe-path:{error}"], None
    if hashlib.sha256(captured).hexdigest() != expected_sha:
        errors.append(f"{label}:working-tree-sha256")
    head_result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    head = head_result.stdout.strip() if head_result.returncode == 0 else None
    if head is None or not is_ancestor(root, commit, head):
        errors.append(f"{label}:commit-not-in-head")
    tree_result = subprocess.run(
        ["git", "ls-tree", commit, "--", relative],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    tree_line = tree_result.stdout.rstrip("\n")
    tree_match = re.fullmatch(
        r"(100644|100755) blob ([0-9a-f]{40})\t(.+)",
        tree_line,
    )
    if (
        tree_result.returncode != 0
        or tree_match is None
        or tree_match.group(3) != relative
    ):
        errors.append(f"{label}:commit-object-not-regular-blob")
    file_result = subprocess.run(
        ["git", "show", f"{commit}:{relative}"],
        cwd=root,
        check=False,
        capture_output=True,
    )
    if (
        file_result.returncode != 0
        or hashlib.sha256(file_result.stdout).hexdigest() != expected_sha
    ):
        errors.append(f"{label}:publication-content-drift")
    elif file_result.stdout != captured:
        errors.append(f"{label}:working-tree-content-drift")
    return sorted(set(errors)), captured


def _claim_binding(root: Path) -> tuple[str | None, int | None]:
    """Read the live West claim instead of accepting a caller-supplied claim."""
    path = root / "docs/production/claims/PLAY-081.world-art-west.md"
    if not path.is_file() or path.is_symlink():
        return None, None
    payload = path.read_text(encoding="utf-8")
    match = re.search(r"Claim revision:\s*(?:\*\*)?\s*(\d+)", payload)
    return sha256(path), int(match.group(1)) if match else None


def _git_blob(root: Path, commit: str, relative: str) -> bytes | None:
    """Read one exact committed carrier blob without trusting the worktree."""
    if HEX_40.fullmatch(commit) is None or not relative.startswith(INTEGRATION_PREFIX):
        return None
    result = subprocess.run(
        ["git", "show", f"{commit}:{relative}"],
        cwd=root,
        check=False,
        capture_output=True,
    )
    return result.stdout if result.returncode == 0 else None


def validate_model_route_and_source_schema(
    root: Path,
    execution_contract: dict[str, Any],
) -> tuple[list[str], dict[str, Any]]:
    """Resolve the exact schema-2 route carrier and source-stage schema bytes."""
    errors: list[str] = []
    route_binding = execution_contract.get("modelRouteAuthority")
    if route_binding != {
        "carrierCommit": MODEL_ROUTE_CARRIER_COMMIT,
        "path": MODEL_ROUTE_PATH,
        "sha256": MODEL_ROUTE_FILE_SHA256,
        "routeId": MODEL_ROUTE_ID,
        "routeSha256": MODEL_ROUTE_SHA256,
    }:
        errors.append("model-route:binding")
        route_binding = {}
    route_bytes = _git_blob(
        root,
        route_binding.get("carrierCommit", MODEL_ROUTE_CARRIER_COMMIT),
        route_binding.get("path", MODEL_ROUTE_PATH),
    )
    if route_bytes is None:
        errors.append("model-route:carrier-blob")
        route_bytes = b""
    if hashlib.sha256(route_bytes).hexdigest() != MODEL_ROUTE_FILE_SHA256:
        errors.append("model-route:carrier-sha256")
    try:
        packet = decode_json_object(route_bytes, "model-route-carrier")
    except (OrchestrationError, json.JSONDecodeError) as error:
        errors.append(f"model-route:json:{error}")
        packet = {}
    assignments = packet.get("assignments")
    rows = (
        [row for row in assignments if isinstance(row, dict)
         and isinstance(row.get("modelRoute"), dict)
         and row["modelRoute"].get("routeId") == MODEL_ROUTE_ID]
        if isinstance(assignments, list) else []
    )
    if len(rows) != 1:
        errors.append("model-route:selected-row")
        row = {}
        route = {}
    else:
        row = rows[0]
        route = row["modelRoute"]
        if row.get("modelRouteSha256") != MODEL_ROUTE_SHA256:
            errors.append("model-route:row-hash")
        canonical_route = json.dumps(
            route, sort_keys=True, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")
        if hashlib.sha256(canonical_route).hexdigest() != MODEL_ROUTE_SHA256:
            errors.append("model-route:canonical-hash")
        if route.get("schema") != 2 or route.get("taskId") != "PLAY-081":
            errors.append("model-route:schema-identity")
        if route.get("classification") != "LUNA_LOCAL_DEBUG":
            errors.append("model-route:classification")
        if (route.get("model"), route.get("effort")) != (
            "gpt-5.6-luna", "max"
        ):
            errors.append("model-route:runtime")
        authority = route.get("authority", {})
        if authority.get("authorityCommit") != MODEL_ROUTE_AUTHORITY_COMMIT or authority.get("baseCommit") != MODEL_ROUTE_AUTHORITY_COMMIT:
            errors.append("model-route:authority")
        assignment = route.get("assignment", {})
        expected_head = assignment.get("expectedHead")
        live_head = git_output(root, "rev-parse", "HEAD")
        if assignment.get("branch") != execution_contract.get("branch"):
            errors.append("model-route:branch")
        if expected_head != MODEL_ROUTE_EXPECTED_HEAD:
            errors.append("model-route:expected-head")
        if live_head is None or not is_ancestor(root, expected_head or "", live_head):
            errors.append("model-route:live-head")
        claim = authority.get("claim", {})
        claim_sha, claim_revision = _claim_binding(root)
        if claim.get("path") != "docs/production/claims/PLAY-081.world-art-west.md":
            errors.append("model-route:claim-path")
        if claim.get("sha256") != claim_sha:
            errors.append("model-route:claim-sha256")
        if claim_revision != 12:
            errors.append("model-route:claim-revision")

    schema_binding = execution_contract.get("sourceStageSchemaAuthority")
    if schema_binding != {
        "path": SOURCE_STAGE_SCHEMA_PATH,
        "sha256": SOURCE_STAGE_SCHEMA_SHA256,
    }:
        errors.append("source-schema:binding")
    try:
        schema_bytes = capture_regular_file_no_follow(root, SOURCE_STAGE_SCHEMA_PATH)
    except (OSError, OrchestrationError, PathSafetyError) as error:
        errors.append(f"source-schema:capture:{error}")
        schema_bytes = b""
    if hashlib.sha256(schema_bytes).hexdigest() != SOURCE_STAGE_SCHEMA_SHA256:
        errors.append("source-schema:sha256")
    try:
        source_schema = decode_json_object(schema_bytes, "source-stage-schema")
        Draft202012Validator.check_schema(source_schema)
    except Exception as error:
        errors.append(f"source-schema:invalid:{error}")
        source_schema = {}
    return sorted(set(errors)), {
        "routeFileSHA256": hashlib.sha256(route_bytes).hexdigest(),
        "routeSHA256": MODEL_ROUTE_SHA256,
        "routeId": MODEL_ROUTE_ID,
        "carrierCommit": MODEL_ROUTE_CARRIER_COMMIT,
        "sourceStageSchemaPath": SOURCE_STAGE_SCHEMA_PATH,
        "sourceStageSchemaSHA256": hashlib.sha256(schema_bytes).hexdigest(),
        "sourceStageSchemaVersion": source_schema.get("$id"),
    }


def validate_integration_document_closure(
    root: Path,
    execution_contract: dict[str, Any],
    runner_contract: dict[str, Any],
) -> tuple[list[str], dict[str, Any]]:
    """Parse and cross-bind the complete Integration document set.

    The production contract remains fail-closed while its inputs are absent.
    When a test or future Integration instance binds documents, every value is
    read from the committed blob identified by the contract; no caller-supplied
    schedule, grant, profile, or session dictionary is trusted.
    """
    errors: list[str] = []
    route_result: dict[str, Any] = {}
    if execution_contract.get("modelRouteAuthority") is not None or execution_contract.get("sourceStageSchemaAuthority") is not None:
        route_errors, route_result = validate_model_route_and_source_schema(
            root, execution_contract
        )
        errors.extend(route_errors)
    authority_errors, captures = validate_contract_authorities(
        root, execution_contract, runner_contract
    )
    errors.extend(authority_errors)
    if errors:
        return sorted(set(errors)), {}
    names = (
        "scheduleSchema",
        "scheduleAuthority",
        "launchGrantA",
        "launchGrantB",
        "launchGrantC",
        "appearanceLock",
        "lockedMaterialMapping",
        "sourceProductionProfile",
        "globalExecutionReceipt",
    )
    documents: dict[str, Any] = {}
    for name in names:
        payload = captures.get(name)
        if payload is None:
            errors.append(f"document:{name}:missing-capture")
            continue
        try:
            documents[name] = decode_json_object(payload, name)
        except OrchestrationError as error:
            errors.append(f"document:{name}:json:{error}")
    if errors:
        return sorted(set(errors)), documents

    claim_sha, claim_revision = _claim_binding(root)
    branch = git_output(root, "branch", "--show-current")
    worker_head = git_output(root, "rev-parse", "HEAD")
    if claim_sha is None or claim_revision is None:
        errors.append("document-closure:claim-not-readable")
    if branch != execution_contract.get("branch"):
        errors.append("document-closure:branch")
    if worker_head is None:
        errors.append("document-closure:worker-head")

    schema = documents["scheduleSchema"]
    if set(schema) != {
        "documentType", "schema", "schemaVersion", "taskId", "direction",
        "claimSHA256", "claimRevision", "branch", "workerHead", "sessionId",
    } or schema.get("documentType") != "scheduleSchema":
        errors.append("document:scheduleSchema:shape")

    authority = documents["scheduleAuthority"]
    if set(authority) != {
        "documentType", "schedule", "scheduleSchemaSHA256", "sessionId",
        "taskId", "direction", "claimSHA256", "claimRevision", "branch",
        "workerHead", "publishedBase",
    } or authority.get("documentType") != "scheduleAuthority":
        errors.append("document:scheduleAuthority:shape")
    schedule = authority.get("schedule")
    if isinstance(schedule, dict):
        errors.extend(
            f"document:scheduleAuthority:{error}"
            for error in validate_schedule(schedule, execution_contract, repository_root=root)
        )
    else:
        errors.append("document:scheduleAuthority:schedule")

    session = documents["globalExecutionReceipt"]
    if set(session) != {
        "documentType", "sessionId", "taskId", "direction", "claimSHA256",
        "claimRevision", "branch", "workerHead", "publishedBase",
        "scheduleAuthoritySHA256", "grantSHA256", "appearanceLockSHA256",
        "lockedMaterialMappingSHA256", "sourceProductionProfileSHA256",
    } or session.get("documentType") != "integrationSession":
        errors.append("document:globalExecutionReceipt:shape")

    appearance = documents["appearanceLock"]
    if set(appearance) != {
        "documentType", "state", "sessionId", "taskId", "direction",
        "claimSHA256", "claimRevision", "branch", "workerHead",
        "publishedBase", "sourceSha256", "decodedRgbaSha256",
    } or appearance.get("documentType") != "appearanceLock":
        errors.append("document:appearanceLock:shape")
    materials = documents["lockedMaterialMapping"]
    if set(materials) != {
        "documentType", "state", "sessionId", "taskId", "direction",
        "claimSHA256", "claimRevision", "branch", "workerHead",
        "publishedBase", "appearanceLockSHA256", "roles",
    } or materials.get("documentType") != "lockedMaterialMapping":
        errors.append("document:lockedMaterialMapping:shape")
    profile = documents["sourceProductionProfile"]
    if set(profile) != {
        "documentType", "schema", "sessionId", "taskId", "direction",
        "claimSHA256", "claimRevision", "branch", "workerHead",
        "publishedBase", "scheduleAuthoritySHA256", "appearanceLockSHA256",
        "lockedMaterialMappingSHA256", "sourceStageSchemaSHA256",
    } or profile.get("documentType") != "sourceProductionProfile":
        errors.append("document:sourceProductionProfile:shape")

    grants: dict[str, dict[str, Any]] = {}
    for process_id in ("A", "B", "C"):
        name = f"launchGrant{process_id}"
        document = documents[name]
        if set(document) != {
            "documentType", "grant", "sessionId", "taskId", "direction",
            "claimSHA256", "claimRevision", "branch", "workerHead",
            "publishedBase", "scheduleAuthoritySHA256", "orchestrator",
            "runner", "outputRoot", "rawRoot", "semanticRoot", "evidenceRoot",
            "maximumChildStarts",
        } or document.get("documentType") != "launchGrant":
            errors.append(f"document:{name}:shape")
            continue
        grant = document.get("grant")
        if not isinstance(grant, dict):
            errors.append(f"document:{name}:grant")
            continue
        grants[process_id] = grant
        if isinstance(schedule, dict):
            errors.extend(
                f"document:{name}:{error}"
                for error in validate_allocation(
                    schedule,
                    grant,
                    execution_contract,
                    runner_contract,
                    process_id,
                    repository_root=root,
                )
            )

    expected_hashes = {
        "scheduleSchemaSHA256": hashlib.sha256(
            captures["scheduleSchema"]
        ).hexdigest(),
        "scheduleAuthoritySHA256": hashlib.sha256(
            captures["scheduleAuthority"]
        ).hexdigest(),
        "appearanceLockSHA256": hashlib.sha256(
            captures["appearanceLock"]
        ).hexdigest(),
        "lockedMaterialMappingSHA256": hashlib.sha256(
            captures["lockedMaterialMapping"]
        ).hexdigest(),
        "sourceProductionProfileSHA256": hashlib.sha256(
            captures["sourceProductionProfile"]
        ).hexdigest(),
        "grantSHA256": {
            process_id: hashlib.sha256(captures[f"launchGrant{process_id}"]).hexdigest()
            for process_id in ("A", "B", "C")
        },
    }
    if schema.get("schema") != SCHEDULE_SCHEMA:
        errors.append("document:scheduleSchema:schema")
    if authority.get("scheduleSchemaSHA256") != expected_hashes["scheduleSchemaSHA256"]:
        errors.append("document:scheduleAuthority:schema-hash")
    if session.get("scheduleAuthoritySHA256") != expected_hashes["scheduleAuthoritySHA256"]:
        errors.append("document:globalExecutionReceipt:schedule-hash")
    if session.get("grantSHA256") != expected_hashes["grantSHA256"]:
        errors.append("document:globalExecutionReceipt:grant-hash")
    if session.get("appearanceLockSHA256") != expected_hashes["appearanceLockSHA256"]:
        errors.append("document:globalExecutionReceipt:appearance-hash")
    if session.get("lockedMaterialMappingSHA256") != expected_hashes["lockedMaterialMappingSHA256"]:
        errors.append("document:globalExecutionReceipt:material-hash")
    if session.get("sourceProductionProfileSHA256") != expected_hashes["sourceProductionProfileSHA256"]:
        errors.append("document:globalExecutionReceipt:profile-hash")
    if profile.get("scheduleAuthoritySHA256") != expected_hashes["scheduleAuthoritySHA256"]:
        errors.append("document:sourceProductionProfile:schedule-hash")
    if profile.get("appearanceLockSHA256") != expected_hashes["appearanceLockSHA256"]:
        errors.append("document:sourceProductionProfile:appearance-hash")
    if profile.get("lockedMaterialMappingSHA256") != expected_hashes["lockedMaterialMappingSHA256"]:
        errors.append("document:sourceProductionProfile:material-hash")
    if profile.get("sourceStageSchemaSHA256") != SOURCE_STAGE_SCHEMA_SHA256:
        errors.append("document:sourceProductionProfile:source-schema-hash")
    if materials.get("appearanceLockSHA256") != expected_hashes["appearanceLockSHA256"]:
        errors.append("document:lockedMaterialMapping:appearance-hash")
    if any(grant.get("scheduleSha256") != json_sha256(schedule) for grant in grants.values()) if isinstance(schedule, dict) else True:
        errors.append("document:grant:schedule-content-hash")

    common_documents = [
        schema,
        authority,
        session,
        appearance,
        materials,
        profile,
        *[documents[f"launchGrant{process_id}"] for process_id in ("A", "B", "C")],
    ]
    document_heads = {
        document.get("workerHead")
        for document in common_documents
        if isinstance(document.get("workerHead"), str)
    }
    if len(document_heads) != 1:
        errors.append("document-closure:worker-head-consistency")
    document_head = next(iter(document_heads), None)
    if not isinstance(document_head, str) or HEX_40.fullmatch(document_head) is None:
        errors.append("document-closure:worker-head-ancestry")
    if document_head != worker_head:
        errors.append("document-closure:worker-head-live")
    for document in common_documents:
        for field, expected in (
            ("taskId", execution_contract.get("taskId")),
            ("direction", execution_contract.get("direction")),
            ("claimSHA256", claim_sha),
            ("claimRevision", claim_revision),
            ("branch", branch),
            ("workerHead", document_head),
        ):
            if document.get(field) != expected:
                errors.append(f"document-closure:{field}")
    if isinstance(schedule, dict):
        for process_id, grant in grants.items():
            expected_job = execution_contract["westProcesses"][process_id]
            if grant.get("jobId") != expected_job["jobId"] or grant.get("queueOrdinal") != expected_job["ordinal"]:
                errors.append(f"document:launchGrant{process_id}:queue-binding")
            expected = execution_contract["westProcesses"][process_id]
            document = documents[f"launchGrant{process_id}"]
            for field, value in (
                ("orchestrator", DEFAULT_HIGH_LEVEL_ORCHESTRATOR),
                ("runner", DEFAULT_LOW_LEVEL_RUNNER),
                ("outputRoot", expected["directory"]),
                ("rawRoot", expected["rawRoot"]),
                ("semanticRoot", expected["semanticRoot"]),
                ("evidenceRoot", expected["evidenceRoot"]),
                ("maximumChildStarts", 1),
            ):
                if document.get(field) != value:
                    errors.append(f"document:launchGrant{process_id}:{field}")
    published_base = authority.get("publishedBase")
    if not isinstance(published_base, str) or not is_ancestor(root, published_base, worker_head or ""):
        errors.append("document-closure:published-base")
    if any(document.get("sessionId") != session.get("sessionId") for document in common_documents):
        errors.append("document-closure:session-id")
    return sorted(set(errors)), {
        "branch": branch,
        "workerHead": worker_head,
        "claimSHA256": claim_sha,
        "claimRevision": claim_revision,
        "schedule": schedule,
        "grants": grants,
        "sessionId": session.get("sessionId"),
        "documentHashes": expected_hashes,
        "externalAuthority": route_result,
    }


def validate_contract_authorities(
    root: Path,
    execution_contract: dict[str, Any],
    runner_contract: dict[str, Any],
) -> tuple[list[str], dict[str, bytes]]:
    """Dereference every Integration binding from its contract, never a caller."""
    errors: list[str] = []
    captures: dict[str, bytes] = {}
    design = execution_contract.get("frozenDesignAuthority", {})
    design_binding = {
        "state": "bound_integration",
        "path": design.get("path"),
        "commit": design.get("commit"),
        "sha256": design.get("sha256"),
    }
    design_errors, design_bytes = committed_input_errors(
        root,
        design_binding,
        design_binding["path"],
        design_binding["sha256"],
        "frozen-design-authority",
    )
    errors.extend(design_errors)
    if design_bytes is not None:
        captures["frozenDesignAuthority"] = design_bytes

    for name, binding in execution_contract.get(
        "futureIntegrationInputs",
        {},
    ).items():
        if not isinstance(binding, dict):
            errors.append(f"integration-input:{name}:invalid-binding")
            continue
        binding_errors, data = committed_input_errors(
            root,
            binding,
            binding.get("path"),
            binding.get("sha256"),
            f"integration-input:{name}",
        )
        errors.extend(binding_errors)
        if data is not None:
            captures[name] = data

    appearance = runner_contract.get("appearanceLock", {})
    appearance_binding = execution_contract.get(
        "futureIntegrationInputs",
        {},
    ).get("appearanceLock", {})
    if (
        not isinstance(appearance, dict)
        or appearance.get("documentPath") != appearance_binding.get("path")
        or appearance.get("commit") != appearance_binding.get("commit")
        or appearance.get("documentSha256") != appearance_binding.get("sha256")
    ):
        errors.append("appearance-lock:runner-binding-mismatch")
    profile = (
        runner_contract.get("sourceStage", {})
        .get("sourceProductionProfile", {})
    )
    profile_binding = execution_contract.get(
        "futureIntegrationInputs",
        {},
    ).get("sourceProductionProfile", {})
    if (
        not isinstance(profile, dict)
        or profile.get("path") != profile_binding.get("path")
        or profile.get("commit") != profile_binding.get("commit")
        or profile.get("sha256") != profile_binding.get("sha256")
    ):
        errors.append("source-production-profile:runner-binding-mismatch")
    return sorted(set(errors)), captures


def expected_queue(execution_contract: dict[str, Any]) -> list[dict[str, Any]]:
    return copy.deepcopy(execution_contract["queue"])


def validate_schedule(
    schedule: dict[str, Any],
    execution_contract: dict[str, Any],
    *,
    repository_root: Path | None = None,
) -> list[str]:
    required = {
        "schema",
        "scheduleId",
        "scheduleRevision",
        "executionMode",
        "maximumConcurrentDccProcesses",
        "queue",
        "exceptionAuthority",
    }
    errors: list[str] = []
    if set(schedule) != required:
        return ["schedule:shape"]
    if schedule["schema"] != SCHEDULE_SCHEMA:
        errors.append("schedule:schema")
    if not isinstance(schedule["scheduleId"], str) or not schedule["scheduleId"]:
        errors.append("schedule:id")
    if (
        not isinstance(schedule["scheduleRevision"], int)
        or schedule["scheduleRevision"] < 1
    ):
        errors.append("schedule:revision")
    queue = schedule.get("queue")
    if not isinstance(queue, list) or len(queue) < 11:
        errors.append("schedule:queue-length")
        return sorted(set(errors))
    base = queue[:11]
    if base != expected_queue(execution_contract):
        errors.append("schedule:base-queue")
    ordinals = [job.get("ordinal") for job in queue if isinstance(job, dict)]
    job_ids = [job.get("jobId") for job in queue if isinstance(job, dict)]
    if ordinals != list(range(1, len(queue) + 1)):
        errors.append("schedule:ordinals")
    if len(set(job_ids)) != len(job_ids):
        errors.append("schedule:duplicate-job-id")

    mode = schedule.get("executionMode")
    modes = execution_contract["executionModes"]
    if mode not in modes:
        errors.append("schedule:execution-mode")
    elif mode == "parallel_two_slot":
        if schedule["maximumConcurrentDccProcesses"] != 2:
            errors.append("schedule:parallel-cap")
        if schedule["exceptionAuthority"] is not None:
            errors.append("schedule:unexpected-exception")
    else:
        if schedule["maximumConcurrentDccProcesses"] != 1:
            errors.append("schedule:sequential-cap")
        exception = schedule["exceptionAuthority"]
        if not isinstance(exception, dict) or set(exception) != {
            "owner",
            "path",
            "commit",
            "sha256",
            "reason",
            "queueOrder",
        }:
            errors.append("schedule:sequential-exception-shape")
        else:
            if exception["owner"] != "Integration":
                errors.append("schedule:sequential-exception-owner")
            if (
                not isinstance(exception["path"], str)
                or not exception["path"].startswith(INTEGRATION_PREFIX)
                or HEX_40.fullmatch(str(exception["commit"])) is None
                or HEX_64.fullmatch(str(exception["sha256"])) is None
                or not isinstance(exception["reason"], str)
                or not exception["reason"]
            ):
                errors.append("schedule:sequential-exception-binding")
            if exception["queueOrder"] != job_ids:
                errors.append("schedule:sequential-exception-order")
            if repository_root is None:
                errors.append("schedule:sequential-exception-not-dereferenced")
            else:
                binding = {
                    "state": "bound_integration",
                    "path": exception["path"],
                    "commit": exception["commit"],
                    "sha256": exception["sha256"],
                }
                authority_errors, authority_bytes = committed_input_errors(
                    repository_root,
                    binding,
                    exception["path"],
                    exception["sha256"],
                    "sequential-exception",
                )
                errors.extend(authority_errors)
                if not authority_errors and authority_bytes is not None:
                    try:
                        authority = decode_json_object(
                            authority_bytes,
                            "sequential-exception",
                        )
                    except (json.JSONDecodeError, OrchestrationError) as error:
                        errors.append(f"schedule:sequential-exception-json:{error}")
                    else:
                        expected_authority = {
                            "schema": (
                                "citysim.integration.world-art-"
                                "sequential-exception.v1"
                            ),
                            "owner": "Integration",
                            "scheduleId": schedule["scheduleId"],
                            "scheduleRevision": schedule["scheduleRevision"],
                            "executionMode": "sequential_exception",
                            "reason": exception["reason"],
                            "queueOrder": exception["queueOrder"],
                        }
                        if authority != expected_authority:
                            errors.append(
                                "schedule:sequential-exception-content"
                            )

    for job in queue[11:]:
        if not isinstance(job, dict) or set(job) != {
            "ordinal",
            "jobId",
            "direction",
            "processId",
            "retry",
        }:
            errors.append("schedule:retry-shape")
            continue
        retry = job["retry"]
        if not isinstance(retry, dict) or set(retry) != {
            "originalJobId",
            "failureClass",
            "automatic",
            "priorScheduleRevision",
            "roots",
        }:
            errors.append("schedule:retry-record")
            continue
        if retry["automatic"] is not False:
            errors.append("schedule:automatic-retry")
        if retry["priorScheduleRevision"] >= schedule["scheduleRevision"]:
            errors.append("schedule:retry-revision")
        if retry["originalJobId"] not in job_ids[:11]:
            errors.append("schedule:retry-original-job")
        roots = retry["roots"]
        if not isinstance(roots, dict) or set(roots) != {
            "rawRoot",
            "semanticRoot",
            "evidenceRoot",
        }:
            errors.append("schedule:retry-roots")
        elif len(set(roots.values())) != 3:
            errors.append("schedule:retry-root-alias")
    return sorted(set(errors))


def validate_allocation(
    schedule: dict[str, Any],
    grant: dict[str, Any],
    execution_contract: dict[str, Any],
    runner_contract: dict[str, Any],
    process_id: str,
    *,
    repository_root: Path | None = None,
) -> list[str]:
    errors = validate_schedule(
        schedule,
        execution_contract,
        repository_root=repository_root,
    )
    required = {
        "schema",
        "scheduleId",
        "scheduleRevision",
        "scheduleSha256",
        "grantId",
        "jobId",
        "direction",
        "processId",
        "queueOrdinal",
        "slotId",
        "grantedAtUtc",
        "exactlyOneInvocation",
        "invocationOrdinal",
        "rawRoot",
        "semanticRoot",
        "evidenceRoot",
    }
    if set(grant) != required:
        return sorted(set(errors + ["allocation:shape"]))
    if grant["schema"] != "citysim.integration.world-art-launch-grant.v1":
        errors.append("allocation:schema")
    if grant["scheduleId"] != schedule.get("scheduleId"):
        errors.append("allocation:schedule-id")
    if grant["scheduleRevision"] != schedule.get("scheduleRevision"):
        errors.append("allocation:schedule-revision")
    if grant["scheduleSha256"] != json_sha256(schedule):
        errors.append("allocation:schedule-sha256")
    if process_id not in {"A", "B", "C"}:
        errors.append("allocation:process-argument")
        return sorted(set(errors))
    expected = execution_contract["westProcesses"][process_id]
    if (
        grant["direction"] != "west"
        or grant["processId"] != process_id
        or grant["jobId"] != expected["jobId"]
        or grant["queueOrdinal"] != expected["ordinal"]
    ):
        errors.append("allocation:west-identity")
    if grant["exactlyOneInvocation"] is not True or grant["invocationOrdinal"] != 1:
        errors.append("allocation:exactly-once")
    try:
        parse_utc(grant["grantedAtUtc"])
    except OrchestrationError:
        errors.append("allocation:granted-at")
    mode = schedule.get("executionMode")
    allowed_slots = (
        {"dcc-0", "dcc-1"} if mode == "parallel_two_slot" else {"dcc-0"}
    )
    if grant["slotId"] not in allowed_slots:
        errors.append("allocation:slot")
    inventory = runner_contract["outputInventory"]["processes"][process_id]
    for field in ("rawRoot", "semanticRoot", "evidenceRoot"):
        if grant[field] != expected[field] or grant[field] != inventory[field]:
            errors.append(f"allocation:{field}")
    roots = [grant[field] for field in ("rawRoot", "semanticRoot", "evidenceRoot")]
    if len(set(roots)) != 3:
        errors.append("allocation:root-alias")
    return sorted(set(errors))


def validate_bound_launch_grant(
    root: Path,
    schedule: dict[str, Any],
    execution_contract: dict[str, Any],
    runner_contract: dict[str, Any],
    process_id: str,
    supplied_path: str | None,
    supplied_sha256: str | None,
) -> list[str]:
    """Load a launch grant only from its exact contract-bound Git authority."""
    if process_id not in {"A", "B", "C"}:
        return ["allocation:process-argument"]
    binding = execution_contract.get("futureIntegrationInputs", {}).get(
        f"launchGrant{process_id}",
        {},
    )
    errors, captured = committed_input_errors(
        root,
        binding,
        supplied_path,
        supplied_sha256,
        f"launch-grant-{process_id}",
    )
    if errors or captured is None:
        return sorted(set(errors))
    try:
        grant = decode_json_object(captured, f"launch-grant-{process_id}")
    except (json.JSONDecodeError, OrchestrationError) as error:
        return [f"launch-grant-{process_id}:json:{error}"]
    errors.extend(
        validate_allocation(
            schedule,
            grant,
            execution_contract,
            runner_contract,
            process_id,
            repository_root=root,
        )
    )
    return sorted(set(errors))


def _event_priority(kind: str) -> int:
    return 0 if kind == "end" else 1


def validate_execution_receipt(
    receipt: dict[str, Any],
    schedule: dict[str, Any],
    execution_contract: dict[str, Any],
    *,
    repository_root: Path | None = None,
) -> list[str]:
    errors = validate_schedule(
        schedule,
        execution_contract,
        repository_root=repository_root,
    )
    required = {
        "schema",
        "scheduleId",
        "scheduleRevision",
        "executionMode",
        "events",
        "maximumObservedConcurrency",
        "actualOverlap",
        "globalCapProven",
        "failures",
        "cancellations",
        "retries",
        "receiptWrites",
        "directionOutcome",
    }
    if set(receipt) != required:
        return sorted(set(errors + ["receipt:shape"]))
    if receipt["schema"] != GLOBAL_RECEIPT_SCHEMA:
        errors.append("receipt:schema")
    for field in ("scheduleId", "scheduleRevision", "executionMode"):
        if receipt[field] != schedule[field]:
            errors.append(f"receipt:{field}")
    events = receipt.get("events")
    if not isinstance(events, list):
        return sorted(set(errors + ["receipt:events"]))

    active_by_slot: dict[str, str] = {}
    starts: dict[str, dict[str, Any]] = {}
    ends: dict[str, dict[str, Any]] = {}
    maximum = 0
    overlap = False
    previous_key: tuple[int, int, str] | None = None
    previous_utc: datetime | None = None
    monotonic_utc: dict[int, datetime] = {}
    start_order: list[str] = []
    allowed_slots = (
        {"dcc-0", "dcc-1"}
        if schedule.get("executionMode") == "parallel_two_slot"
        else {"dcc-0"}
    )
    for index, event in enumerate(events, start=1):
        if not isinstance(event, dict) or set(event) != {
            "sequence",
            "kind",
            "jobId",
            "slotId",
            "atUtc",
            "monotonicNs",
        }:
            errors.append("receipt:event-shape")
            continue
        if event["sequence"] != index:
            errors.append("receipt:event-sequence")
        if event["kind"] not in {"start", "end"}:
            errors.append("receipt:event-kind")
            continue
        try:
            at_utc = parse_utc(event["atUtc"])
        except OrchestrationError:
            errors.append("receipt:event-utc")
            at_utc = None
        if at_utc is not None:
            if previous_utc is not None and at_utc < previous_utc:
                errors.append("receipt:event-utc-order")
            previous_utc = at_utc
        if not isinstance(event["monotonicNs"], int) or event["monotonicNs"] < 0:
            errors.append("receipt:event-monotonic")
            continue
        if (
            at_utc is not None
            and event["monotonicNs"] in monotonic_utc
            and monotonic_utc[event["monotonicNs"]] != at_utc
        ):
            errors.append("receipt:event-clock-disagreement")
        elif at_utc is not None:
            monotonic_utc[event["monotonicNs"]] = at_utc
        key = (
            event["monotonicNs"],
            _event_priority(event["kind"]),
            event["slotId"],
        )
        if previous_key is not None and key < previous_key:
            errors.append("receipt:event-order")
        previous_key = key
        if event["slotId"] not in allowed_slots:
            errors.append("receipt:slot")
        if event["kind"] == "start":
            if event["slotId"] in active_by_slot:
                errors.append("receipt:slot-overlap")
            if event["jobId"] in starts:
                errors.append("receipt:duplicate-start")
            active_by_slot[event["slotId"]] = event["jobId"]
            starts[event["jobId"]] = event
            start_order.append(event["jobId"])
            maximum = max(maximum, len(active_by_slot))
            overlap = overlap or len(active_by_slot) >= 2
        else:
            if active_by_slot.get(event["slotId"]) != event["jobId"]:
                errors.append("receipt:end-without-start")
            else:
                active_by_slot.pop(event["slotId"])
            if event["jobId"] in ends:
                errors.append("receipt:duplicate-end")
            ends[event["jobId"]] = event
    if active_by_slot:
        errors.append("receipt:unclosed-process")
    if set(starts) != set(ends):
        errors.append("receipt:invocation-pairs")
    scheduled_jobs = [job["jobId"] for job in schedule["queue"]]
    cancelled_jobs = {
        job_id
        for cancellation in receipt.get("cancellations", [])
        if isinstance(cancellation, dict)
        for job_id in cancellation.get("jobIds", [])
        if isinstance(job_id, str)
    }
    if set(starts) & cancelled_jobs:
        errors.append("receipt:cancelled-job-invoked")
    if set(starts) | cancelled_jobs != set(scheduled_jobs):
        errors.append("receipt:job-disposition-completeness")
    expected_start_order = [
        job_id for job_id in scheduled_jobs if job_id not in cancelled_jobs
    ]
    if start_order != expected_start_order:
        errors.append("receipt:fifo-start-order")
    failure_jobs = {
        failure.get("jobId")
        for failure in receipt.get("failures", [])
        if isinstance(failure, dict)
    }
    if not failure_jobs.issubset(set(starts)):
        errors.append("receipt:failure-without-invocation")
    if receipt["maximumObservedConcurrency"] != maximum:
        errors.append("receipt:maximum-concurrency-assertion")
    if receipt["actualOverlap"] is not overlap:
        errors.append("receipt:overlap-assertion")

    mode = schedule.get("executionMode")
    if mode == "parallel_two_slot":
        if maximum > 2:
            errors.append("receipt:parallel-cap")
        if not overlap:
            errors.append("receipt:parallel-overlap-required")
    elif mode == "sequential_exception":
        if maximum > 1:
            errors.append("receipt:sequential-cap")
        if overlap:
            errors.append("receipt:sequential-overlap-forbidden")
    if receipt["globalCapProven"] is not True:
        errors.append("receipt:global-cap-not-proven")
    errors.extend(
        validate_failure_isolation(
            receipt.get("failures"),
            receipt.get("cancellations"),
        )
    )
    errors.extend(
        validate_retries(
            receipt.get("retries"),
            schedule,
            execution_contract,
        )
    )
    errors.extend(
        validate_receipt_order(
            receipt.get("receiptWrites"),
            execution_contract,
            direction_outcome=receipt.get("directionOutcome"),
        )
    )
    return sorted(set(errors))


def validate_failure_isolation(
    failures: Any,
    cancellations: Any,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(failures, list) or not isinstance(cancellations, list):
        return ["failure-isolation:shape"]
    failure_by_id: dict[str, dict[str, Any]] = {}
    for failure in failures:
        if not isinstance(failure, dict) or set(failure) != {
            "jobId",
            "direction",
            "failureClass",
        }:
            errors.append("failure-isolation:failure-shape")
            continue
        failure_by_id[failure["jobId"]] = failure
    for cancellation in cancellations:
        if not isinstance(cancellation, dict) or set(cancellation) != {
            "causedByJobId",
            "direction",
            "jobIds",
        }:
            errors.append("failure-isolation:cancellation-shape")
            continue
        cause = failure_by_id.get(cancellation["causedByJobId"])
        if cause is None:
            errors.append("failure-isolation:missing-cause")
            continue
        if cancellation["direction"] != cause["direction"]:
            errors.append("failure-isolation:cross-direction")
        if cause["failureClass"] == "process_local" and cancellation["jobIds"]:
            errors.append("failure-isolation:process-local-cancellation")
        if any(
            not isinstance(job_id, str)
            or not job_id.startswith(cause["direction"][0].upper() + "-")
            for job_id in cancellation["jobIds"]
        ):
            errors.append("failure-isolation:foreign-job")
    return sorted(set(errors))


def validate_retries(
    retries: Any,
    schedule: dict[str, Any],
    execution_contract: dict[str, Any],
) -> list[str]:
    if not isinstance(retries, list):
        return ["retry:shape"]
    errors: list[str] = []
    base_roots: set[str] = {
        process[field]
        for process in execution_contract["westProcesses"].values()
        for field in ("rawRoot", "semanticRoot", "evidenceRoot")
    }
    for retry in retries:
        if not isinstance(retry, dict) or set(retry) != {
            "originalJobId",
            "retryJobId",
            "failureClass",
            "automatic",
            "newScheduleRevision",
            "ordinal",
            "roots",
        }:
            errors.append("retry:record-shape")
            continue
        if retry["automatic"] is not False:
            errors.append("retry:automatic")
        if retry["newScheduleRevision"] <= schedule["scheduleRevision"]:
            errors.append("retry:schedule-revision")
        if retry["ordinal"] <= len(schedule["queue"]):
            errors.append("retry:ordinal-not-appended")
        roots = retry["roots"]
        if not isinstance(roots, dict) or set(roots) != {
            "rawRoot",
            "semanticRoot",
            "evidenceRoot",
        }:
            errors.append("retry:roots")
            continue
        values = list(roots.values())
        if len(set(values)) != 3:
            errors.append("retry:root-alias")
        if any(value in base_roots for value in values):
            errors.append("retry:root-reuse")
        base_roots.update(values)
        if retry["failureClass"] == "candidate_content_or_determinism":
            errors.append("retry:content-failure-requires-new-direction-revision")
    return sorted(set(errors))


def validate_receipt_order(
    writes: Any,
    execution_contract: dict[str, Any],
    *,
    direction_outcome: Any,
) -> list[str]:
    if not isinstance(writes, list):
        return ["receipt-order:shape"]
    errors: list[str] = []
    groups = execution_contract["receiptOrderGroups"]
    expected = [identity for group in groups for identity in group]
    rank_by_identity = {
        identity: rank
        for rank, group in enumerate(groups)
        for identity in group
    }
    identities: list[str] = []
    for index, write in enumerate(writes, start=1):
        if not isinstance(write, dict) or set(write) != {
            "sequence",
            "identity",
            "path",
            "noFollow",
            "noOverwrite",
        }:
            errors.append("receipt-order:record-shape")
            continue
        if write["sequence"] != index:
            errors.append("receipt-order:sequence")
        identity = write["identity"]
        identities.append(identity)
        if identity not in expected:
            errors.append("receipt-order:unknown-identity")
            continue
        if write["path"] != execution_contract["receiptPaths"][identity]:
            errors.append("receipt-order:path")
        if write["noFollow"] is not True or write["noOverwrite"] is not True:
            errors.append("receipt-order:unsafe-write")
    ranks = [
        rank_by_identity[identity]
        for identity in identities
        if identity in rank_by_identity
    ]
    if ranks != sorted(ranks):
        errors.append("receipt-order:dependency-order")
    if len(set(identities)) != len(identities):
        errors.append("receipt-order:duplicate")
    if direction_outcome == "pass":
        if set(identities) != set(expected) or len(identities) != len(expected):
            errors.append("receipt-order:incomplete-pass")
    elif "sourceCandidatePacket" in identities:
        errors.append("receipt-order:packet-after-failure")
    return sorted(set(errors))


def safe_write_receipt(
    root: Path,
    execution_contract: dict[str, Any],
    identity: str,
    value: dict[str, Any],
    *,
    emission_authorized: bool,
) -> Path:
    if not emission_authorized:
        raise OrchestrationError("PRODUCTION_RECEIPT_EMISSION_DISABLED")
    if identity not in execution_contract["receiptPaths"]:
        raise OrchestrationError(f"UNKNOWN_RECEIPT_IDENTITY:{identity}")
    relative = execution_contract["receiptPaths"][identity]
    return write_exact_json_no_overwrite(
        root,
        relative,
        value,
        expected=relative,
    )


def fixture_schedule(
    execution_contract: dict[str, Any],
    mode: str,
) -> dict[str, Any]:
    exception = None
    cap = 2
    if mode == "sequential_exception":
        cap = 1
        exception = {
            "owner": "Integration",
            "path": f"{INTEGRATION_PREFIX}SYNTHETIC-SEQUENTIAL-EXCEPTION.json",
            "commit": "1" * 40,
            "sha256": "2" * 64,
            "reason": "Synthetic zero-DCC fixture",
            "queueOrder": [
                job["jobId"] for job in execution_contract["queue"]
            ],
        }
    return {
        "schema": SCHEDULE_SCHEMA,
        "scheduleId": "industrial-l04-synthetic-v1",
        "scheduleRevision": 1,
        "executionMode": mode,
        "maximumConcurrentDccProcesses": cap,
        "queue": expected_queue(execution_contract),
        "exceptionAuthority": exception,
    }


def fixture_grant(
    schedule: dict[str, Any],
    execution_contract: dict[str, Any],
    runner_contract: dict[str, Any],
    process_id: str,
) -> dict[str, Any]:
    expected = execution_contract["westProcesses"][process_id]
    inventory = runner_contract["outputInventory"]["processes"][process_id]
    return {
        "schema": "citysim.integration.world-art-launch-grant.v1",
        "scheduleId": schedule["scheduleId"],
        "scheduleRevision": schedule["scheduleRevision"],
        "scheduleSha256": json_sha256(schedule),
        "grantId": f"synthetic-W-{process_id}",
        "jobId": expected["jobId"],
        "direction": "west",
        "processId": process_id,
        "queueOrdinal": expected["ordinal"],
        "slotId": "dcc-0",
        "grantedAtUtc": "2026-07-29T12:00:00Z",
        "exactlyOneInvocation": True,
        "invocationOrdinal": 1,
        "rawRoot": inventory["rawRoot"],
        "semanticRoot": inventory["semanticRoot"],
        "evidenceRoot": inventory["evidenceRoot"],
    }


def fixture_writes(
    execution_contract: dict[str, Any],
) -> list[dict[str, Any]]:
    return [
        {
            "sequence": index,
            "identity": identity,
            "path": execution_contract["receiptPaths"][identity],
            "noFollow": True,
            "noOverwrite": True,
        }
        for index, identity in enumerate(
            (
                identity
                for group in execution_contract["receiptOrderGroups"]
                for identity in group
            ),
            start=1,
        )
    ]


def simulate_receipt(
    schedule: dict[str, Any],
    execution_contract: dict[str, Any],
    durations: list[int],
    *,
    failures: list[dict[str, Any]] | None = None,
    cancellations: list[dict[str, Any]] | None = None,
    retries: list[dict[str, Any]] | None = None,
    direction_outcome: str = "pass",
) -> dict[str, Any]:
    if len(durations) != len(schedule["queue"]) or any(value <= 0 for value in durations):
        raise OrchestrationError("INVALID_SYNTHETIC_DURATIONS")
    cap = schedule["maximumConcurrentDccProcesses"]
    free_at = [0] * cap
    events: list[dict[str, Any]] = []
    sequence = 0
    base_time = datetime(2026, 7, 29, 12, 0, tzinfo=timezone.utc)
    intervals: list[tuple[int, int, str, str]] = []
    for job, duration in zip(schedule["queue"], durations, strict=True):
        slot_index = min(range(cap), key=lambda index: (free_at[index], index))
        start = free_at[slot_index]
        end = start + duration
        free_at[slot_index] = end
        intervals.append((start, end, job["jobId"], f"dcc-{slot_index}"))
    raw_events: list[tuple[int, int, str, str, str]] = []
    for start, end, job_id, slot_id in intervals:
        raw_events.append((start, 1, slot_id, "start", job_id))
        raw_events.append((end, 0, slot_id, "end", job_id))
    raw_events.sort()
    active = 0
    maximum = 0
    overlap = False
    for moment, _, slot_id, kind, job_id in raw_events:
        sequence += 1
        if kind == "end":
            active -= 1
        else:
            active += 1
            maximum = max(maximum, active)
            overlap = overlap or active >= 2
        timestamp = (base_time + timedelta(seconds=moment)).isoformat().replace(
            "+00:00",
            "Z",
        )
        events.append(
            {
                "sequence": sequence,
                "kind": kind,
                "jobId": job_id,
                "slotId": slot_id,
                "atUtc": timestamp,
                "monotonicNs": moment * 1_000_000_000,
            }
        )
    return {
        "schema": GLOBAL_RECEIPT_SCHEMA,
        "scheduleId": schedule["scheduleId"],
        "scheduleRevision": schedule["scheduleRevision"],
        "executionMode": schedule["executionMode"],
        "events": events,
        "maximumObservedConcurrency": maximum,
        "actualOverlap": overlap,
        "globalCapProven": maximum <= cap,
        "failures": failures or [],
        "cancellations": cancellations or [],
        "retries": retries or [],
        "receiptWrites": (
            fixture_writes(execution_contract)
            if direction_outcome == "pass"
            else []
        ),
        "directionOutcome": direction_outcome,
    }


def synthetic_proof(
    execution_contract: dict[str, Any],
    runner_contract: dict[str, Any],
) -> dict[str, Any]:
    parallel = fixture_schedule(execution_contract, "parallel_two_slot")
    sequential = fixture_schedule(execution_contract, "sequential_exception")
    durations = [4, 4, 2, 2, 3, 3, 2, 2, 2, 2, 1]
    parallel_receipt = simulate_receipt(
        parallel,
        execution_contract,
        durations,
    )
    sequential_receipt = simulate_receipt(
        sequential,
        execution_contract,
        durations,
    )
    grants = {
        process_id: validate_allocation(
            parallel,
            fixture_grant(
                parallel,
                execution_contract,
                runner_contract,
                process_id,
            ),
            execution_contract,
            runner_contract,
            process_id,
        )
        for process_id in ("A", "B", "C")
    }
    sequential_errors = validate_schedule(
        sequential,
        execution_contract,
    )
    sequential_rejected = (
        "schedule:sequential-exception-not-dereferenced"
        in sequential_errors
    )
    cases = {
        "syntheticParallelTrace": validate_execution_receipt(
            parallel_receipt,
            parallel,
            execution_contract,
        ),
        "allocations": sorted(
            error for errors in grants.values() for error in errors
        ),
    }
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "stage": "zero_dcc_orchestration_proof",
        "currentAuthorityErrors": current_binding_errors(
            execution_contract,
            runner_contract,
        ),
        "positiveCases": cases,
        "allPositiveCasesPassed": (
            all(not errors for errors in cases.values())
            and sequential_rejected
        ),
        "syntheticParallelMaximumActive": parallel_receipt[
            "maximumObservedConcurrency"
        ],
        "syntheticParallelOverlap": parallel_receipt["actualOverlap"],
        "syntheticSequentialMaximumActive": sequential_receipt[
            "maximumObservedConcurrency"
        ],
        "syntheticSequentialOverlap": sequential_receipt["actualOverlap"],
        "syntheticTraceIsAuthority": False,
        "westClaimsGlobalCapOrOverlap": False,
        "integrationGlobalValidationRequired": True,
        "sequentialExceptionPositiveValidation": (
            "not_run_missing_published_integration_exception"
        ),
        "fakeSequentialExceptionRejected": sequential_rejected,
        "fakeSequentialExceptionErrors": sequential_errors,
        "invocations": dict(ZERO_INVOCATIONS),
        "productionExecutionEnabled": False,
        "productionReceiptEmissionEnabled": False,
        "passed": (
            all(not errors for errors in cases.values())
            and sequential_rejected
        ),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument(
        "--execution-contract",
        default=DEFAULT_EXECUTION_CONTRACT,
    )
    parser.add_argument("--runner-contract", default=DEFAULT_RUNNER_CONTRACT)
    parser.add_argument(
        "--mode",
        required=True,
        choices=(
            "describe",
            "validate-execution-closure",
            "validate-authority",
            "validate-schedule",
            "validate-allocation",
            "validate-receipt",
            "self-test",
        ),
    )
    parser.add_argument("--schedule")
    parser.add_argument("--schedule-sha256")
    parser.add_argument("--launch-grant")
    parser.add_argument("--launch-grant-sha256")
    parser.add_argument("--global-receipt")
    parser.add_argument("--global-receipt-sha256")
    parser.add_argument("--process-id", choices=("A", "B", "C"))
    parser.add_argument("--authority")
    parser.add_argument("--trusted-head")
    parser.add_argument("--worker-head")
    parser.add_argument("--authority-publication-commit")
    return parser.parse_args()


def blocked_result(mode: str, errors: list[str]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "mode": mode,
        "decision": "BLOCKED",
        "rejectionStage": "before_dcc_or_output_write",
        "errors": sorted(set(errors)),
        "invocations": dict(ZERO_INVOCATIONS),
        "passed": False,
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    try:
        execution_path = lexical_repository_path(
            root,
            args.execution_contract,
            expected=DEFAULT_EXECUTION_CONTRACT,
        )
        runner_path = lexical_repository_path(
            root,
            args.runner_contract,
            expected=DEFAULT_RUNNER_CONTRACT,
        )
        execution_contract = load_json(execution_path)
        runner_contract = load_json(runner_path)
    except (OSError, json.JSONDecodeError, OrchestrationError, PathSafetyError) as error:
        print(json.dumps(blocked_result(args.mode, [str(error)]), indent=2, sort_keys=True))
        return 3

    authority_errors = current_binding_errors(
        execution_contract,
        runner_contract,
    )
    if args.mode == "validate-execution-closure":
        result = validate_execution_closure(
            root,
            execution_contract,
            authority_path=args.authority,
            trusted_head=args.trusted_head,
            worker_head=args.worker_head,
            authority_publication_commit=args.authority_publication_commit,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result["result"] == "PASS" else 3
    if args.mode == "describe":
        result = {
            "schemaVersion": 1,
            "taskId": "PLAY-081",
            "direction": "west",
            "mode": "describe",
            "state": "awaiting_integration_schedule_lock_and_profile",
            "authorityErrors": authority_errors,
            "availableModes": [
                "validate-authority",
                "validate-execution-closure",
                "validate-schedule",
                "validate-allocation",
                "validate-receipt",
                "self-test",
            ],
            "productionExecutionMode": None,
            "invocations": dict(ZERO_INVOCATIONS),
            "passed": True,
        }
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    if args.mode == "self-test":
        result = synthetic_proof(execution_contract, runner_contract)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result["passed"] else 1
    dereference_errors, _ = validate_contract_authorities(
        root,
        execution_contract,
        runner_contract,
    )
    authority_errors = sorted(set(authority_errors + dereference_errors))
    if authority_errors:
        print(
            json.dumps(
                blocked_result(args.mode, authority_errors),
                indent=2,
                sort_keys=True,
            )
        )
        return 3

    contract_errors, captures = validate_contract_authorities(
        root,
        execution_contract,
        runner_contract,
    )
    binding_errors, schedule_bytes = committed_input_errors(
        root,
        execution_contract["futureIntegrationInputs"]["scheduleAuthority"],
        args.schedule,
        args.schedule_sha256,
        "schedule-authority",
    )
    schema_errors, schema_bytes = committed_input_errors(
        root,
        execution_contract["futureIntegrationInputs"]["scheduleSchema"],
        execution_contract["futureIntegrationInputs"]["scheduleSchema"].get("path"),
        execution_contract["futureIntegrationInputs"]["scheduleSchema"].get("sha256"),
        "schedule-schema",
    )
    errors = contract_errors + binding_errors + schema_errors
    if errors or schedule_bytes is None or schema_bytes is None:
        print(json.dumps(blocked_result(args.mode, errors), indent=2, sort_keys=True))
        return 3
    try:
        schedule = decode_json_object(schedule_bytes, "schedule-authority")
        schedule_schema = decode_json_object(schema_bytes, "schedule-schema")
    except (json.JSONDecodeError, OrchestrationError) as error:
        print(
            json.dumps(
                blocked_result(args.mode, [f"authority-json:{error}"]),
                indent=2,
                sort_keys=True,
            )
        )
        return 3
    schema_validation = sorted(
        Draft202012Validator(schedule_schema).iter_errors(schedule),
        key=lambda error: list(error.path),
    )
    errors = [
        f"schedule-schema:{list(error.path)}:{error.message}"
        for error in schema_validation
    ]
    errors.extend(
        validate_schedule(
            schedule,
            execution_contract,
            repository_root=root,
        )
    )
    if args.mode in {"validate-authority", "validate-schedule"}:
        result = {
            "schemaVersion": 1,
            "taskId": "PLAY-081",
            "direction": "west",
            "mode": args.mode,
            "errors": sorted(set(errors)),
            "invocations": dict(ZERO_INVOCATIONS),
            "passed": not errors,
        }
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if not errors else 1
    if errors:
        print(json.dumps(blocked_result(args.mode, errors), indent=2, sort_keys=True))
        return 3

    if args.mode == "validate-allocation":
        if not args.launch_grant or not args.process_id:
            errors = ["allocation:missing-input"]
        else:
            errors = validate_bound_launch_grant(
                root,
                schedule,
                execution_contract,
                runner_contract,
                args.process_id,
                args.launch_grant,
                args.launch_grant_sha256,
            )
    else:
        binding = execution_contract["futureIntegrationInputs"][
            "globalExecutionReceipt"
        ]
        receipt_errors, receipt_bytes = committed_input_errors(
            root,
            binding,
            args.global_receipt,
            args.global_receipt_sha256,
            "global-execution-receipt",
        )
        errors = receipt_errors
        if not errors and receipt_bytes is not None:
            errors.extend(
                validate_execution_receipt(
                    decode_json_object(
                        receipt_bytes,
                        "global-execution-receipt",
                    ),
                    schedule,
                    execution_contract,
                    repository_root=root,
                )
            )
    result = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "mode": args.mode,
        "errors": sorted(set(errors)),
        "invocations": dict(ZERO_INVOCATIONS),
        "productionReceiptWritten": False,
        "passed": not errors,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
