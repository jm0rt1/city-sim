#!/usr/bin/env python3
"""Authenticate one PLAY-079 East validation-only execution closure.

The Integration validator establishes Git publication, ancestry, schedule,
grant, slot, root, artifact, and disposition truth. This direction-local
consumer adds the anonymous-pipe secret and one-time HMAC checks that cannot be
performed from the persisted authority alone. After authentication it
atomically claims the authority's exact task-owned attempt root and writes one
nonsecret consumed marker. It never creates the live lease or starts a child,
DCC process, render, pixel, normalization, or source packet.
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


def normalized_attempt_root(
    repository_root: pathlib.Path,
    authority: dict[str, Any],
    contract: dict[str, Any],
) -> tuple[pathlib.PurePosixPath, pathlib.Path]:
    value = authority["exclusiveRoots"]["attempt"]
    if not isinstance(value, str) or not value or value.startswith("/"):
        reject("durable_attempt_path_invalid", value)
    relative = pathlib.PurePosixPath(value)
    if (
        relative.as_posix() != value
        or any(part in {"", ".", ".."} for part in relative.parts)
    ):
        reject("durable_attempt_path_invalid", value)
    prefix = pathlib.PurePosixPath(contract["durableReplay"]["attemptRootPrefix"])
    if relative.parent != prefix:
        reject(
            "durable_attempt_path_outside_east_prefix",
            f"{relative.parent} != {prefix}",
        )
    root = repository_root.resolve()
    absolute = root / relative.as_posix()
    if absolute.parent.resolve() != (root / prefix.as_posix()).resolve():
        reject("durable_attempt_parent_redirect", value)
    return relative, absolute


def _open_directory_component(
    parent_fd: int,
    component: str,
    *,
    create: bool,
) -> int:
    flags = os.O_RDONLY | os.O_DIRECTORY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        return os.open(component, flags, dir_fd=parent_fd)
    except FileNotFoundError:
        if not create:
            raise
        try:
            os.mkdir(component, 0o755, dir_fd=parent_fd)
        except FileExistsError:
            pass
        return os.open(component, flags, dir_fd=parent_fd)


def claim_durable_attempt(
    *,
    repository_root: pathlib.Path,
    authority_path: pathlib.Path,
    authority_publication_commit: str,
    trusted_head: str,
    worker_head: str,
    authority: dict[str, Any],
    contract: dict[str, Any],
) -> dict[str, Any]:
    relative, _absolute = normalized_attempt_root(
        repository_root,
        authority,
        contract,
    )
    replay_contract = contract["durableReplay"]
    marker_name = replay_contract["markerFileName"]
    if (
        not isinstance(marker_name, str)
        or not marker_name
        or pathlib.PurePosixPath(marker_name).name != marker_name
    ):
        reject("durable_marker_name_invalid", marker_name)
    repository = repository_root.resolve()
    try:
        authority_relative = authority_path.resolve().relative_to(repository).as_posix()
    except ValueError as error:
        raise ClosureRejected("authority_path_outside_repository", authority_path) from error
    marker_payload = canonical_bytes(
        {
            "schema": "citysim.play-079.east-execution-attempt-consumed.v1",
            "taskId": "PLAY-079",
            "direction": "east",
            "validationOnly": True,
            "authorityPath": authority_relative,
            "authorityPublicationCommit": authority_publication_commit,
            "trustedHead": trusted_head,
            "workerHead": worker_head,
            "capabilityId": authority["authentication"]["childCapability"][
                "capabilityId"
            ],
            "grantId": authority["grant"]["grantId"],
            "leasePath": authority["executionEnvelope"]["leasePath"],
            "liveLeaseCreated": False,
            "sourceChildStarts": 0,
            "dccStarts": 0,
            "renders": 0,
            "pixels": 0,
        }
    )

    root_flags = os.O_RDONLY | os.O_DIRECTORY
    if hasattr(os, "O_NOFOLLOW"):
        root_flags |= os.O_NOFOLLOW
    current_fd = os.open(repository, root_flags)
    attempt_fd: int | None = None
    try:
        for component in relative.parent.parts:
            next_fd = _open_directory_component(
                current_fd,
                component,
                create=True,
            )
            os.close(current_fd)
            current_fd = next_fd
        try:
            os.mkdir(relative.name, 0o700, dir_fd=current_fd)
        except FileExistsError as error:
            raise ClosureRejected(
                "replayed_capability",
                authority["authentication"]["childCapability"]["capabilityId"],
            ) from error
        except OSError as error:
            raise ClosureRejected("durable_attempt_claim_failed", error) from error
        os.fsync(current_fd)
        attempt_fd = _open_directory_component(
            current_fd,
            relative.name,
            create=False,
        )
        marker_flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
        if hasattr(os, "O_NOFOLLOW"):
            marker_flags |= os.O_NOFOLLOW
        marker_fd = os.open(
            marker_name,
            marker_flags,
            0o600,
            dir_fd=attempt_fd,
        )
        try:
            written = 0
            while written < len(marker_payload):
                count = os.write(marker_fd, marker_payload[written:])
                if count <= 0:
                    reject("durable_attempt_marker_short_write", written)
                written += count
            os.fsync(marker_fd)
        finally:
            os.close(marker_fd)
        os.fsync(attempt_fd)
    except ClosureRejected:
        raise
    except OSError as error:
        raise ClosureRejected("durable_attempt_path_unsafe", error) from error
    finally:
        if attempt_fd is not None:
            os.close(attempt_fd)
        os.close(current_fd)
    return {
        "attemptRoot": relative.as_posix(),
        "marker": f"{relative.as_posix()}/{marker_name}",
        "markerSha256": sha256_bytes(marker_payload),
        "atomicDirectoryClaim": True,
        "noFollow": True,
        "noOverwrite": True,
        "liveLeaseCreated": False,
    }


class AuthenticatedExecutionClosure:
    """Opaque in-process handoff accepted only after shared and HMAC checks."""

    __slots__ = (
        "_authority",
        "_shared_result",
        "_capability_id",
        "_durable_attempt",
        "_seal",
    )

    def __init__(
        self,
        authority: dict[str, Any],
        shared_result: dict[str, Any],
        capability_id: str,
        durable_attempt: dict[str, Any],
        seal: object,
    ) -> None:
        if seal is not _AUTHENTICATED_SEAL:
            reject("unauthenticated_runner_input", "invalid closure seal")
        self._authority = authority
        self._shared_result = shared_result
        self._capability_id = capability_id
        self._durable_attempt = durable_attempt
        self._seal = seal

    def consume_for_runner(self) -> tuple[dict[str, Any], dict[str, Any]]:
        if self._seal is not _AUTHENTICATED_SEAL:
            reject("unauthenticated_runner_input", "invalid closure seal")
        if self._capability_id in _CONSUMED_CAPABILITIES:
            reject("replayed_capability", self._capability_id)
        _CONSUMED_CAPABILITIES.add(self._capability_id)
        return self._authority, self._shared_result

    def durable_attempt_result(self) -> dict[str, Any]:
        if self._seal is not _AUTHENTICATED_SEAL:
            reject("unauthenticated_runner_input", "invalid closure seal")
        return dict(self._durable_attempt)


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
        if "exclusiveRoots.attempt already exists; replay is forbidden" in str(error):
            raise ClosureRejected("replayed_capability", error) from error
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
    durable_attempt = claim_durable_attempt(
        repository_root=repository_root,
        authority_path=authority_path,
        authority_publication_commit=authority_publication_commit,
        trusted_head=trusted_head,
        worker_head=worker_head,
        authority=authority,
        contract=contract,
    )
    return AuthenticatedExecutionClosure(
        authority,
        shared_result,
        capability["capabilityId"],
        durable_attempt,
        _AUTHENTICATED_SEAL,
    )


def reset_test_replay_state() -> None:
    """Clear only in-memory validation-only state for disposable test fixtures."""

    _CONSUMED_CAPABILITIES.clear()
