#!/usr/bin/env python3
"""Lexical, symlink-safe path boundaries for PLAY-081 West.

This module uses only the Python standard library and performs no subprocess,
pixel, or Blender work. Every production output path is compared with its
exact task-owned lexical identity before any existing path component is
inspected for symlinks, then written descriptor-relative with no-follow and
no-overwrite semantics.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01"
)
DEFAULT_VALIDATION_OUTPUT = (
    f"{EVIDENCE_ROOT}/PRELOCK-LAUNCH-PLUMBING-VALIDATION.json"
)
PROCESS_IDS = ("A", "B", "C")
PIPELINE_PATH_IDENTITIES = {
    "evidenceRoot": EVIDENCE_ROOT,
    "launchBound.frozenInputManifest": f"{EVIDENCE_ROOT}/FROZEN-INPUT-MANIFEST.json",
    "launchBound.guardReceipt": f"{EVIDENCE_ROOT}/LAUNCH-GUARD-RECEIPT.json",
    "launchBound.outputRootIsolationReceipt": (
        f"{EVIDENCE_ROOT}/OUTPUT-ROOT-ISOLATION-RECEIPT.json"
    ),
    "launchBound.packet": f"{EVIDENCE_ROOT}/SOURCE-STAGE-LAUNCH-BOUND-V2.json",
    "postSource.assemblyRoot": f"{EVIDENCE_ROOT}/assembly",
    "postSource.canonicalRoot": f"{EVIDENCE_ROOT}/validation/canonical-rgba",
    "postSource.normalizationRun1Root": (
        f"{EVIDENCE_ROOT}/normalization-repeat/run-1"
    ),
    "postSource.normalizationRun2Root": (
        f"{EVIDENCE_ROOT}/normalization-repeat/run-2"
    ),
    "postSource.normalizationRepeatReceipt": (
        f"{EVIDENCE_ROOT}/NORMALIZATION-REPEAT-IDENTITY.json"
    ),
    "postSource.parallelExecutionReceipt": (
        f"{EVIDENCE_ROOT}/PARALLEL-EXECUTION-RECEIPT.json"
    ),
    "postSource.reviewManifest": f"{EVIDENCE_ROOT}/review/REVIEW-MANIFEST.json",
    "postSource.reviewRoot": f"{EVIDENCE_ROOT}/review",
    "postSource.sourceCandidatePacket": (
        f"{EVIDENCE_ROOT}/SOURCE-STAGE-HANDOFF-V2.json"
    ),
    "review.contactSheet": f"{EVIDENCE_ROOT}/review/CONTACT-SHEET.png",
    "review.literal192Color": f"{EVIDENCE_ROOT}/review/EXACT-192X128-COLOR.png",
    "review.literal192Grayscale": (
        f"{EVIDENCE_ROOT}/review/EXACT-192X128-GRAYSCALE.png"
    ),
    "review.native2xColor": f"{EVIDENCE_ROOT}/review/NATIVE-2X-COLOR.png",
    "review.native2xGrayscale": (
        f"{EVIDENCE_ROOT}/review/NATIVE-2X-GRAYSCALE.png"
    ),
    "review.registration": f"{EVIDENCE_ROOT}/review/REGISTRATION.png",
    "review.sourceColor": f"{EVIDENCE_ROOT}/review/SOURCE-COLOR.png",
    "review.sourceGrayscale": f"{EVIDENCE_ROOT}/review/SOURCE-GRAYSCALE.png",
    "validation.sourceValidation": f"{EVIDENCE_ROOT}/SOURCE-VALIDATION.json",
    "rejections": f"{EVIDENCE_ROOT}/REJECTIONS.json",
}


class PathSafetyError(ValueError):
    """An output path is not the exact symlink-free PLAY-081 identity."""


def expected_process_paths(process_id: str) -> dict[str, str]:
    if process_id not in PROCESS_IDS:
        raise PathSafetyError(f"INVALID_PROCESS_ID:{process_id}")
    base = f"{EVIDENCE_ROOT}/process-{process_id}"
    return {
        "directory": base,
        "rawRoot": f"{base}/raw",
        "semanticRoot": f"{base}/semantic",
        "evidenceRoot": f"{base}/evidence",
        "raw": f"{base}/raw/raw.png",
        "semantic": f"{base}/semantic/semantic.png",
        "provenance": f"{base}/evidence/provenance.json",
        "freshInvocationReceipt": f"{base}/evidence/fresh-invocation.json",
        "objectMapping": f"{base}/evidence/object-mapping.json",
        "registration": f"{base}/evidence/registration.json",
    }


def lexical_repository_path(
    root: Path,
    relative: Any,
    *,
    expected: str | None = None,
) -> Path:
    """Return an un-resolved repository path after exact and symlink checks."""
    if expected is not None and relative != expected:
        raise PathSafetyError(
            f"LEXICAL_IDENTITY_MISMATCH:{relative!r}!={expected!r}"
        )
    if (
        not isinstance(relative, str)
        or not relative
        or Path(relative).is_absolute()
        or "\\" in relative
    ):
        raise PathSafetyError(f"INVALID_REPOSITORY_PATH:{relative!r}")
    parts = relative.split("/")
    if any(not part or part in {".", ".."} for part in parts):
        raise PathSafetyError(f"PATH_TRAVERSAL:{relative}")
    repository = root.resolve()
    candidate = repository.joinpath(*parts)
    current = repository
    for part in parts:
        current = current / part
        if current.is_symlink():
            raise PathSafetyError(
                f"SYMLINK_COMPONENT:{current.relative_to(repository)}"
            )
    return candidate


def validate_exact_output(
    root: Path,
    supplied: Any,
    *,
    expected: str = DEFAULT_VALIDATION_OUTPUT,
) -> Path:
    """Bind a validator output to one exact task-owned, symlink-free path."""
    return lexical_repository_path(root, supplied, expected=expected)


def _contract_pipeline_value(
    contract: dict[str, Any],
    identity: str,
) -> Any:
    inventory = contract.get("outputInventory", {})
    if identity == "evidenceRoot":
        return inventory.get("evidenceRoot")
    if identity == "rejections":
        return inventory.get("rejections")
    section, key = identity.split(".", 1)
    value = inventory.get(section, {})
    return value.get(key) if isinstance(value, dict) else None


def pipeline_relative(
    contract: dict[str, Any],
    identity: str,
) -> str:
    """Return one exact contract-bound downstream PLAY-081 path."""
    if identity not in PIPELINE_PATH_IDENTITIES:
        raise PathSafetyError(f"UNKNOWN_PIPELINE_IDENTITY:{identity}")
    expected = PIPELINE_PATH_IDENTITIES[identity]
    supplied = _contract_pipeline_value(contract, identity)
    if supplied != expected:
        raise PathSafetyError(
            f"PIPELINE_IDENTITY_MISMATCH:{identity}:{supplied!r}!={expected!r}"
        )
    return expected


def exact_pipeline_path(
    root: Path,
    contract: dict[str, Any],
    identity: str,
) -> Path:
    relative = pipeline_relative(contract, identity)
    return lexical_repository_path(root, relative, expected=relative)


def validate_pipeline_layout(
    root: Path,
    contract: dict[str, Any],
) -> dict[str, Any]:
    """Validate every declared launch/downstream identity and symlink component."""
    errors: list[str] = []
    paths: dict[str, str] = {}
    for identity in PIPELINE_PATH_IDENTITIES:
        try:
            relative = pipeline_relative(contract, identity)
            lexical_repository_path(root, relative, expected=relative)
            paths[identity] = relative
        except PathSafetyError as error:
            errors.append(f"{identity}:{str(error).split(':', 1)[0]}")
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "paths": paths,
        "errors": sorted(set(errors)),
        "exactLexicalIdentitiesRequired": True,
        "symlinkComponentsRejected": True,
        "passed": not errors,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "pixelFiles": 0,
    }


def _open_parent_no_follow(root: Path, relative: str) -> int:
    """Open/create a relative parent chain without following symlinks."""
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        raise PathSafetyError("NO_FOLLOW_DIRECTORY_API_UNAVAILABLE")
    parts = relative.split("/")[:-1]
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    current = os.open(root.resolve(), flags)
    try:
        for part in parts:
            try:
                child = os.open(part, flags, dir_fd=current)
            except FileNotFoundError:
                try:
                    os.mkdir(part, 0o755, dir_fd=current)
                except FileExistsError:
                    pass
                try:
                    child = os.open(part, flags, dir_fd=current)
                except OSError as error:
                    raise PathSafetyError(
                        f"NO_FOLLOW_PARENT:{relative}"
                    ) from error
            except OSError as error:
                raise PathSafetyError(
                    f"NO_FOLLOW_PARENT:{relative}"
                ) from error
            os.close(current)
            current = child
        return current
    except BaseException:
        os.close(current)
        raise


def _write_exact_bytes(
    root: Path,
    supplied: Any,
    value: bytes,
    *,
    expected: str,
    no_overwrite: bool,
) -> Path:
    path = lexical_repository_path(root, supplied, expected=expected)
    parent_descriptor = _open_parent_no_follow(root, expected)
    try:
        path = lexical_repository_path(root, supplied, expected=expected)
        flags = os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW
        flags |= os.O_EXCL if no_overwrite else os.O_TRUNC
        try:
            descriptor = os.open(
                expected.rsplit("/", 1)[-1],
                flags,
                0o644,
                dir_fd=parent_descriptor,
            )
        except FileExistsError as error:
            raise PathSafetyError(f"NO_OVERWRITE:{expected}") from error
        except OSError as error:
            raise PathSafetyError(f"NO_FOLLOW_WRITE:{expected}") from error
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(value)
    finally:
        os.close(parent_descriptor)
    return path


def write_exact_json(
    root: Path,
    supplied: Any,
    value: dict[str, Any],
    *,
    expected: str = DEFAULT_VALIDATION_OUTPUT,
) -> Path:
    """Write JSON only after the exact output path passes twice."""
    return _write_exact_bytes(
        root,
        supplied,
        (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8"),
        expected=expected,
        no_overwrite=False,
    )


def write_exact_bytes_no_overwrite(
    root: Path,
    supplied: Any,
    value: bytes,
    *,
    expected: str,
) -> Path:
    """Write one exact output with O_NOFOLLOW and O_EXCL after final recheck."""
    return _write_exact_bytes(
        root,
        supplied,
        value,
        expected=expected,
        no_overwrite=True,
    )


def write_exact_json_no_overwrite(
    root: Path,
    supplied: Any,
    value: dict[str, Any],
    *,
    expected: str,
) -> Path:
    return write_exact_bytes_no_overwrite(
        root,
        supplied,
        (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8"),
        expected=expected,
    )


def validate_process_layout(
    root: Path,
    contract: dict[str, Any],
    *,
    require_absent: bool,
) -> dict[str, Any]:
    """Validate every A/B/C directory, root, leaf, and symlink component."""
    inventory = contract.get("outputInventory", {}).get("processes", {})
    errors: list[str] = []
    paths: dict[str, dict[str, str]] = {}
    root_paths: list[Path] = []
    existing_paths: list[str] = []
    for process_id in PROCESS_IDS:
        process = inventory.get(process_id)
        expected = expected_process_paths(process_id)
        if not isinstance(process, dict):
            errors.append(f"process-{process_id}:missing")
            continue
        paths[process_id] = {}
        if set(process) != set(expected):
            errors.append(f"process-{process_id}:field-set")
        for name, exact in expected.items():
            relative = process.get(name)
            paths[process_id][name] = relative
            if relative != exact:
                errors.append(f"process-{process_id}:{name}:lexical-identity")
                continue
            try:
                path = lexical_repository_path(
                    root,
                    relative,
                    expected=exact,
                )
            except PathSafetyError as error:
                errors.append(
                    f"process-{process_id}:{name}:{str(error).split(':', 1)[0]}"
                )
                continue
            if name in {"rawRoot", "semanticRoot", "evidenceRoot"}:
                root_paths.append(path)
            if path.exists() or path.is_symlink():
                existing_paths.append(relative)
                if require_absent:
                    errors.append(f"process-{process_id}:{name}:already-exists")
    distinct = len(root_paths) == 9 and len(set(root_paths)) == 9
    if not distinct:
        errors.append("output-roots:not-nine-distinct-roots")
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "paths": paths,
        "allOutputRootsDistinct": distinct,
        "noExistingOutputPaths": not existing_paths,
        "existingOutputPaths": sorted(existing_paths),
        "noOverwrite": True,
        "symlinkComponentsRejected": True,
        "exactLexicalIdentitiesRequired": True,
        "errors": sorted(set(errors)),
        "passed": not errors,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "pixelFiles": 0,
    }
