#!/usr/bin/env python3
"""Authenticate one PLAY-079 East validation-only execution closure.

The Integration validator establishes Git publication, ancestry, schedule,
grant, slot, root, artifact, and disposition truth. This direction-local
consumer adds the anonymous-pipe secret and one-time HMAC checks that cannot be
performed from the persisted authority alone. It never creates a lease, root,
child, process, render, pixel, or receipt.
"""

from __future__ import annotations

import hashlib
import hmac
import importlib.util
import json
import os
import pathlib
import stat
import sys
from typing import Any, NoReturn


VERSION_ROOT = pathlib.Path(__file__).resolve().parent
SOURCE_ROOT = VERSION_ROOT.parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
CONTRACT_PATH = VERSION_ROOT / "EXECUTION-CLOSURE-CONTRACT.json"
_AUTHENTICATED_SEAL = object()
_CONSUMED_CAPABILITIES: set[str] = set()


class ClosureRejected(RuntimeError):
    """Stable rejection before the runner or any child boundary."""

    def __init__(self, code: str, detail: object):
        super().__init__(str(detail))
        self.code = code
        self.detail = str(detail)


def reject(code: str, detail: object) -> NoReturn:
    raise ClosureRejected(code, detail)


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def load_json(path: pathlib.Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ClosureRejected(f"{label}_invalid", error) from error
    if not isinstance(value, dict):
        reject(f"{label}_invalid", "expected object")
    return value


def load_exact_module(
    repository_root: pathlib.Path,
    binding: dict[str, str],
    module_name: str,
) -> Any:
    path = repository_root / binding["path"]
    try:
        payload = path.read_bytes()
    except OSError as error:
        raise ClosureRejected("shared_validator_missing", error) from error
    if sha256_bytes(payload) != binding["sha256"]:
        reject("shared_validator_hash_mismatch", binding["path"])
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        reject("shared_validator_load_failed", binding["path"])
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def validate_control_bindings(
    repository_root: pathlib.Path,
    contract: dict[str, Any],
) -> None:
    for name, binding in contract["sharedAuthority"].items():
        path = repository_root / binding["path"]
        try:
            payload = path.read_bytes()
        except OSError as error:
            raise ClosureRejected(f"shared_{name}_missing", error) from error
        if sha256_bytes(payload) != binding["sha256"]:
            reject(f"shared_{name}_hash_mismatch", binding["path"])


def capability_payload(authority: dict[str, Any]) -> bytes:
    authentication = authority["authentication"]
    capability = authentication["childCapability"]
    return canonical_bytes(
        {
            "$schema": authority["$schema"],
            "schemaVersion": authority["schemaVersion"],
            "testProtocolRevision": authority["testProtocolRevision"],
            "batch": authority["batch"],
            "mode": authority["mode"],
            "issuedAt": authority["issuedAt"],
            "task": authority["task"],
            "schedule": authority["schedule"],
            "appearanceLock": authority["appearanceLock"],
            "sourceProductionProfile": authority["sourceProductionProfile"],
            "grant": authority["grant"],
            "artifacts": authority["artifacts"],
            "exclusiveRoots": authority["exclusiveRoots"],
            "executionEnvelope": authority["executionEnvelope"],
            "authentication": {
                "secretTransport": authentication["secretTransport"],
                "secretSha256": authentication["secretSha256"],
                "rawSecretPersisted": authentication["rawSecretPersisted"],
                "childCapability": {
                    "algorithm": capability["algorithm"],
                    "capabilityId": capability["capabilityId"],
                    "audience": capability["audience"],
                    "boundGrantId": capability["boundGrantId"],
                    "oneTime": capability["oneTime"],
                    "replayAllowed": capability["replayAllowed"],
                },
            },
            "disposition": authority["disposition"],
        }
    )


def read_pipe_secret(secret_fd: int, expected_length: int) -> bytes:
    try:
        before = os.fstat(secret_fd)
    except OSError as error:
        raise ClosureRejected("secret_fd_invalid", error) from error
    if not stat.S_ISFIFO(before.st_mode):
        reject("secret_transport_not_anonymous_pipe", secret_fd)
    chunks: list[bytes] = []
    total = 0
    while total <= expected_length:
        chunk = os.read(secret_fd, expected_length + 1 - total)
        if not chunk:
            break
        chunks.append(chunk)
        total += len(chunk)
    try:
        after = os.fstat(secret_fd)
    except OSError as error:
        raise ClosureRejected("secret_fd_changed", error) from error
    if (before.st_dev, before.st_ino, stat.S_IFMT(before.st_mode)) != (
        after.st_dev,
        after.st_ino,
        stat.S_IFMT(after.st_mode),
    ):
        reject("secret_fd_changed", secret_fd)
    secret = b"".join(chunks)
    if len(secret) != expected_length:
        reject("secret_length_mismatch", len(secret))
    return secret


def _require_equal(actual: object, expected: object, code: str) -> None:
    if actual != expected:
        reject(code, f"{actual!r} != {expected!r}")


class AuthenticatedExecutionClosure:
    """Opaque in-process handoff accepted only after shared and HMAC checks."""

    __slots__ = ("_authority", "_shared_result", "_capability_id", "_seal")

    def __init__(
        self,
        authority: dict[str, Any],
        shared_result: dict[str, Any],
        capability_id: str,
        seal: object,
    ) -> None:
        if seal is not _AUTHENTICATED_SEAL:
            reject("unauthenticated_runner_input", "invalid closure seal")
        self._authority = authority
        self._shared_result = shared_result
        self._capability_id = capability_id
        self._seal = seal

    def consume_for_runner(self) -> tuple[dict[str, Any], dict[str, Any]]:
        if self._seal is not _AUTHENTICATED_SEAL:
            reject("unauthenticated_runner_input", "invalid closure seal")
        if self._capability_id in _CONSUMED_CAPABILITIES:
            reject("replayed_capability", self._capability_id)
        _CONSUMED_CAPABILITIES.add(self._capability_id)
        return self._authority, self._shared_result


def authenticate(
    *,
    repository_root: pathlib.Path,
    authority_path: pathlib.Path,
    trusted_head: str,
    worker_head: str,
    authority_publication_commit: str,
    secret_fd: int,
    contract: dict[str, Any] | None = None,
    shared_validator: Any | None = None,
) -> AuthenticatedExecutionClosure:
    contract = contract or load_json(CONTRACT_PATH, "execution_closure_contract")
    validate_control_bindings(REPOSITORY_ROOT, contract)
    if shared_validator is None:
        shared_validator = load_exact_module(
            REPOSITORY_ROOT,
            contract["sharedAuthority"]["validator"],
            "play079_execution_closure_shared_validator",
        )
    try:
        shared_result = shared_validator.validate(
            repository_root,
            authority_path,
            trusted_head=trusted_head,
            worker_head=worker_head,
            authority_publication_commit=authority_publication_commit,
        )
    except (OSError, ValueError) as error:
        raise ClosureRejected("shared_authority_rejected", error) from error
    try:
        authority = shared_validator.load_strict_json_bytes(
            authority_path.read_bytes(), "authority"
        )
    except (OSError, ValueError) as error:
        raise ClosureRejected("authority_reload_rejected", error) from error

    expected_task = contract["task"]
    _require_equal(authority["task"], expected_task, "east_task_binding_mismatch")
    expected_paths = contract["artifactPaths"]
    observed_paths = {
        name: binding["path"] for name, binding in authority["artifacts"].items()
    }
    _require_equal(observed_paths, expected_paths, "worker_artifact_path_mismatch")
    _require_equal(shared_result.get("result"), "PASS", "shared_validation_not_pass")
    _require_equal(shared_result.get("direction"), "east", "wrong_direction")
    _require_equal(shared_result.get("taskId"), "PLAY-079", "wrong_task")
    _require_equal(shared_result.get("validationOnly"), True, "not_validation_only")

    auth_contract = contract["authentication"]
    secret = read_pipe_secret(secret_fd, auth_contract["secretLengthBytes"])
    authentication = authority["authentication"]
    if not hmac.compare_digest(
        sha256_bytes(secret), authentication["secretSha256"]
    ):
        reject("secret_hash_mismatch", "anonymous-pipe secret does not match")
    payload = capability_payload(authority)
    capability = authentication["childCapability"]
    if not hmac.compare_digest(sha256_bytes(payload), capability["payloadSha256"]):
        reject("capability_payload_hash_mismatch", capability["capabilityId"])
    computed_mac = hmac.new(secret, payload, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(computed_mac, capability["macSha256"]):
        reject("forged_capability_mac", capability["capabilityId"])
    return AuthenticatedExecutionClosure(
        authority,
        shared_result,
        capability["capabilityId"],
        _AUTHENTICATED_SEAL,
    )


def reset_test_replay_state() -> None:
    """Clear only in-memory validation-only state for disposable test fixtures."""

    _CONSUMED_CAPABILITIES.clear()
