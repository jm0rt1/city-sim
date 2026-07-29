#!/usr/bin/env python3
"""Fail-closed future production authority checks for PLAY-081 West.

This module is safe to import from system Python.  It never imports Blender,
decodes candidate pixels, or writes files.  Production launch is allowed only
when the exact Integration-published appearance lock, material mapping, source
profile, and bound ``origin/master`` commit all validate.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

from west_path_safety import validate_process_layout


HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
INTEGRATION_PREFIX = "docs/production/evidence/INTEGRATION/"
PROFILE_SCHEMA = "citysim.integration.world-art-source-production-profile.v1"
SOURCE_SCHEMA_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-stage-handoff-schema-v2.json"
)
SOURCE_SCHEMA_SHA256 = (
    "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7"
)
EXPECTED_DIRECTION_PROCESSES = {
    "north": ["B", "C"],
    "east": ["A", "B", "C"],
    "south": ["A", "B", "C"],
    "west": ["A", "B", "C"],
}
EXPECTED_GRANTS = {
    "sourceAcceptance": False,
    "rendererAdmission": False,
    "productionSelection": False,
    "shippingActivation": False,
}


class AuthorityError(ValueError):
    """A stable authority or repository binding failure."""


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repository_path(root: Path, relative: Any) -> Path:
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute():
        raise AuthorityError(f"INVALID_REPOSITORY_PATH:{relative!r}")
    if any(part in {".", ".."} for part in relative.split("/")):
        raise AuthorityError(f"PATH_TRAVERSAL:{relative}")
    resolved = (root / relative).resolve()
    try:
        resolved.relative_to(root)
    except ValueError as error:
        raise AuthorityError(f"PATH_OUTSIDE_REPOSITORY:{relative}") from error
    return resolved


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AuthorityError(f"EXPECTED_JSON_OBJECT:{path}")
    return value


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


def file_at_commit_sha256(
    root: Path,
    commit: str,
    relative: str,
) -> str | None:
    result = subprocess.run(
        ["git", "show", f"{commit}:{relative}"],
        cwd=root,
        check=False,
        capture_output=True,
    )
    return hashlib.sha256(result.stdout).hexdigest() if result.returncode == 0 else None


def _committed_artifact_errors(
    root: Path,
    binding: Any,
    label: str,
    *,
    origin_master: str,
) -> tuple[list[str], dict[str, Any] | None]:
    errors: list[str] = []
    if not isinstance(binding, dict):
        return [f"{label}:missing"], None
    required = {"path", "commit", "sha256"}
    if not required.issubset(binding):
        return [f"{label}:incomplete"], None
    relative = binding.get("path")
    commit = binding.get("commit")
    expected = binding.get("sha256")
    fatal = False
    if not isinstance(relative, str) or not relative.startswith(INTEGRATION_PREFIX):
        errors.append(f"{label}:unpublished-path")
        fatal = not isinstance(relative, str)
    if not isinstance(commit, str) or HEX_40.fullmatch(commit) is None:
        errors.append(f"{label}:invalid-commit")
        fatal = True
    if not isinstance(expected, str) or HEX_64.fullmatch(expected) is None:
        errors.append(f"{label}:invalid-sha256")
        fatal = True
    if fatal:
        return errors, None
    try:
        path = repository_path(root, relative)
    except AuthorityError:
        return [f"{label}:invalid-path"], None
    if not path.is_file():
        errors.append(f"{label}:missing-file")
        return errors, None
    if sha256(path) != expected:
        errors.append(f"{label}:working-tree-sha256")
    head = git_output(root, "rev-parse", "HEAD")
    if not is_ancestor(root, commit, origin_master):
        errors.append(f"{label}:commit-not-on-origin-master")
    if head is None or not is_ancestor(root, commit, head):
        errors.append(f"{label}:commit-not-in-head")
    if file_at_commit_sha256(root, commit, relative) != expected:
        errors.append(f"{label}:publication-content-drift")
    if errors:
        return errors, None
    try:
        return [], load_json(path)
    except (AuthorityError, OSError, json.JSONDecodeError):
        return [f"{label}:invalid-json"], None


def _appearance_errors(
    document: dict[str, Any] | None,
    binding: dict[str, Any],
) -> list[str]:
    if document is None:
        return []
    expected_keys = {
        "documentPath",
        "commit",
        "documentSha256",
        "northProcessASourceSha256",
        "northProcessADecodedRgbaSha256",
    }
    if set(binding) != expected_keys:
        return ["appearance-lock:binding-shape"]
    authority = document.get("appearanceLockBinding")
    expected = {
        "commit": binding["commit"],
        "northProcessASourceSha256": binding["northProcessASourceSha256"],
        "northProcessADecodedRgbaSha256": binding[
            "northProcessADecodedRgbaSha256"
        ],
    }
    if not isinstance(authority, dict) or any(
        authority.get(key) != value for key, value in expected.items()
    ):
        return ["appearance-lock:document-binding"]
    return []


def _material_errors(
    document: dict[str, Any] | None,
    contract: dict[str, Any],
) -> list[str]:
    if document is None:
        return []
    binding = contract["lockedMaterialMapping"]
    appearance = contract["appearanceLock"]
    errors: list[str] = []
    if document.get("schemaVersion") != 1:
        errors.append("locked-materials:schema-version")
    if document.get("direction") != "west":
        errors.append("locked-materials:direction")
    if document.get("appearanceLockSha256") != appearance.get("documentSha256"):
        errors.append("locked-materials:appearance-lock-sha256")
    roles = document.get("roles")
    try:
        predesign = load_json(
            repository_path(
                Path(contract["_repositoryRoot"]),
                contract["acceptedPredesign"]["materials"]["path"],
            )
        )
        expected_roles = set(predesign["roles"])
    except (AuthorityError, KeyError, OSError, json.JSONDecodeError):
        return errors + ["locked-materials:predesign-role-authority"]
    if not isinstance(roles, dict) or set(roles) != expected_roles:
        return errors + ["locked-materials:role-set"]
    for name, role in roles.items():
        if not isinstance(role, dict) or set(role) != {
            "baseColorSrgb",
            "roughness",
            "metallic",
        }:
            errors.append(f"locked-materials:{name}:shape")
            continue
        color = role["baseColorSrgb"]
        if (
            not isinstance(color, list)
            or len(color) != 4
            or any(not isinstance(value, (int, float)) for value in color)
        ):
            errors.append(f"locked-materials:{name}:base-color")
        for field in ("roughness", "metallic"):
            value = role[field]
            if not isinstance(value, (int, float)) or not 0 <= value <= 1:
                errors.append(f"locked-materials:{name}:{field}")
    if binding.get("requiredSchema", {}).get("direction") != "west":
        errors.append("locked-materials:contract-schema")
    return errors


def _profile_errors(
    document: dict[str, Any] | None,
    contract: dict[str, Any],
) -> list[str]:
    if document is None:
        return []
    required = {
        "schema",
        "familyIdentity",
        "appearanceLock",
        "lockedMaterialMapping",
        "sourceStageSchema",
        "directionProcesses",
        "computeEnvelope",
        "grants",
    }
    errors: list[str] = []
    if set(document) != required:
        return ["source-profile:shape"]
    if document["schema"] != PROFILE_SCHEMA:
        errors.append("source-profile:schema")
    if document["familyIdentity"] != {
        "family": "industrial",
        "level": 4,
        "variant": 0,
    }:
        errors.append("source-profile:family")
    if document["appearanceLock"] != contract["appearanceLock"]:
        errors.append("source-profile:appearance-lock")
    expected_material = {
        key: contract["lockedMaterialMapping"][key]
        for key in ("path", "commit", "sha256")
    }
    if document["lockedMaterialMapping"] != expected_material:
        errors.append("source-profile:locked-materials")
    if document["sourceStageSchema"] != {
        "path": SOURCE_SCHEMA_PATH,
        "sha256": SOURCE_SCHEMA_SHA256,
    }:
        errors.append("source-profile:source-stage-schema")
    if document["directionProcesses"] != EXPECTED_DIRECTION_PROCESSES:
        errors.append("source-profile:direction-processes")
    if document["computeEnvelope"] != {
        "maximumConcurrentDccProcesses": 2,
        "exceptionOwner": "Integration",
    }:
        errors.append("source-profile:compute-envelope")
    if document["grants"] != EXPECTED_GRANTS:
        errors.append("source-profile:authority-escalation")
    return errors


def validate_future_authorities(
    root: Path,
    contract: dict[str, Any],
) -> dict[str, Any]:
    """Validate all launch authority without launching a subprocess."""
    root = root.resolve()
    errors: list[str] = []
    policy = contract.get("futureProductionAuthority", {})
    source_profile = contract.get("sourceStage", {}).get(
        "sourceProductionProfile",
        {},
    )
    appearance = contract.get("appearanceLock", {})
    materials = contract.get("lockedMaterialMapping", {})
    origin_bound = policy.get("originMasterCommit")
    actual_origin = git_output(root, "rev-parse", "origin/master")
    head = git_output(root, "rev-parse", "HEAD")
    if policy.get("state") != "bound":
        errors.append("future-authority:not-bound")
    if not isinstance(origin_bound, str) or HEX_40.fullmatch(origin_bound) is None:
        errors.append("origin-master:missing-binding")
    elif actual_origin != origin_bound:
        errors.append("origin-master:stale-binding")
    elif head is None or not is_ancestor(root, origin_bound, head):
        errors.append("origin-master:not-in-head")
    if source_profile.get("state") != "bound_integration_profile":
        errors.append("source-profile:not-bound")
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
    if not isinstance(materials, dict) or any(
        not materials.get(field) for field in ("path", "commit", "sha256")
    ):
        errors.append("locked-materials:not-bound")
    if (
        contract.get("appearanceLockCommit") != appearance.get("commit")
        or contract.get("appearanceLockSha256") != appearance.get("documentSha256")
    ):
        errors.append("appearance-lock:alias-binding")

    appearance_document = material_document = profile_document = None
    if isinstance(origin_bound, str) and HEX_40.fullmatch(origin_bound):
        appearance_binding = (
            {
                "path": appearance.get("documentPath"),
                "commit": appearance.get("commit"),
                "sha256": appearance.get("documentSha256"),
            }
            if isinstance(appearance, dict)
            else {}
        )
        found, appearance_document = _committed_artifact_errors(
            root,
            appearance_binding,
            "appearance-lock",
            origin_master=origin_bound,
        )
        errors.extend(found)
        found, material_document = _committed_artifact_errors(
            root,
            materials,
            "locked-materials",
            origin_master=origin_bound,
        )
        errors.extend(found)
        found, profile_document = _committed_artifact_errors(
            root,
            source_profile,
            "source-profile",
            origin_master=origin_bound,
        )
        errors.extend(found)

    contract_with_root = dict(contract)
    contract_with_root["_repositoryRoot"] = str(root)
    if isinstance(appearance, dict):
        errors.extend(_appearance_errors(appearance_document, appearance))
    errors.extend(_material_errors(material_document, contract_with_root))
    errors.extend(_profile_errors(profile_document, contract))
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "originMaster": {
            "bound": origin_bound,
            "actual": actual_origin,
            "head": head,
        },
        "appearanceLockCommit": appearance.get("commit")
        if isinstance(appearance, dict)
        else None,
        "sourceProductionProfileCommit": source_profile.get("commit")
        if isinstance(source_profile, dict)
        else None,
        "errors": sorted(set(errors)),
        "passed": not errors,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "pixelFiles": 0,
    }


def validate_output_root_isolation(
    root: Path,
    contract: dict[str, Any],
    *,
    require_absent: bool,
) -> dict[str, Any]:
    """Validate exact immutable A/B/C paths without following symlinks."""
    report = validate_process_layout(
        root,
        contract,
        require_absent=require_absent,
    )
    return {
        **report,
        "roots": {
            process_id: {
                kind: values[kind]
                for kind in ("rawRoot", "semanticRoot", "evidenceRoot")
            }
            for process_id, values in report["paths"].items()
        },
        "noExistingOutputRoots": not any(
            path.endswith(("/raw", "/semantic", "/evidence"))
            for path in report["existingOutputPaths"]
        ),
    }
