#!/usr/bin/env python3
"""Lexical, symlink-safe path boundaries for PLAY-081 West.

This module uses only the Python standard library and performs no subprocess,
pixel, Blender, or file writes except through ``write_exact_json``.  Every
production output path is compared with its exact task-owned lexical identity
before any existing path component is inspected for symlinks.
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


def write_exact_json(
    root: Path,
    supplied: Any,
    value: dict[str, Any],
    *,
    expected: str = DEFAULT_VALIDATION_OUTPUT,
) -> Path:
    """Write JSON only after the exact output path passes twice."""
    path = validate_exact_output(root, supplied, expected=expected)
    path.parent.mkdir(parents=True, exist_ok=True)
    path = validate_exact_output(root, supplied, expected=expected)
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(path, flags, 0o644)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(value, indent=2, sort_keys=True) + "\n")
    return path


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
