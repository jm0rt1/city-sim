#!/usr/bin/env python3
"""Fail-closed validation for one Industrial L4 direction execution closure."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any

SCHEMA_ID = "citysim://integration/industrial-l04-direction-execution-authority-v1"
AUTHORITY_ROOT = PurePosixPath("docs/production/evidence/INTEGRATION")
SCHEDULE_ROOT = PurePosixPath("docs/production/evidence/INTEGRATION")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
GIT_COMMIT = re.compile(r"^[0-9a-f]{40}$")
UTC_TIMESTAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
LEASE_PATH = re.compile(
    r"^/private/tmp/citysim-industrial-l04-(north|east|south|west)-[a-z0-9._-]+\.lock$"
)

DIRECTION_SPECS = {
    "north": {
        "taskId": "PLAY-027",
        "branch": "codex/citysim-world-art",
        "claimPath": "docs/production/claims/PLAY-027.world-art.md",
        "artifactRoot": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
            "industrial-l04-north-art-v12"
        ),
        "nativeRoot": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
            "industrial-l04-north-art-v12/process-a-execution-v01"
        ),
        "evidenceRoot": (
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
            "blender-north-art-v12/process-a-execution-v01"
        ),
    },
    "east": {
        "taskId": "PLAY-079",
        "branch": "codex/citysim-world-art-east",
        "claimPath": "docs/production/claims/PLAY-079.world-art-east.md",
        "artifactRoot": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01"
        ),
        "nativeRoot": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01"
        ),
        "evidenceRoot": (
            "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01"
        ),
    },
    "south": {
        "taskId": "PLAY-080",
        "branch": "codex/citysim-world-art-south",
        "claimPath": "docs/production/claims/PLAY-080.world-art-south.md",
        "artifactRoot": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
            "industrial-l04-south-source-v01"
        ),
        "nativeRoot": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
            "industrial-l04-south-source-v01"
        ),
        "evidenceRoot": (
            "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01"
        ),
    },
    "west": {
        "taskId": "PLAY-081",
        "branch": "codex/citysim-world-art-west",
        "claimPath": "docs/production/claims/PLAY-081.world-art-west.md",
        "artifactRoot": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
            "industrial-l04-west-source-v01"
        ),
        "nativeRoot": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
            "industrial-l04-west-source-v01"
        ),
        "evidenceRoot": (
            "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01"
        ),
    },
}

TOP_FIELDS = {
    "$schema",
    "schemaVersion",
    "testProtocolRevision",
    "batch",
    "mode",
    "issuedAt",
    "task",
    "schedule",
    "appearanceLock",
    "sourceProductionProfile",
    "grant",
    "artifacts",
    "exclusiveRoots",
    "executionEnvelope",
    "authentication",
    "disposition",
}


class AuthorityError(ValueError):
    """Raised when the closure is not an exact, published, fail-closed authority."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuthorityError(message)


def _reject_constant(value: str) -> None:
    raise AuthorityError(f"non-finite JSON number is forbidden: {value}")


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise AuthorityError(f"duplicate JSON key is forbidden: {key}")
        result[key] = value
    return result


def load_strict_json_bytes(payload: bytes, label: str) -> Any:
    try:
        return json.loads(
            payload.decode("utf-8"),
            object_pairs_hook=_strict_object,
            parse_constant=_reject_constant,
        )
    except UnicodeDecodeError as error:
        raise AuthorityError(f"{label} is not UTF-8 JSON") from error
    except json.JSONDecodeError as error:
        raise AuthorityError(f"{label} is invalid JSON: {error}") from error


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def exact_fields(value: Any, fields: set[str], label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object")
    require(set(value) == fields, f"{label} fields do not match v1")
    return value


def exact_bool(value: Any, expected: bool, label: str) -> None:
    require(type(value) is bool and value is expected, f"{label} must be {expected}")


def exact_int(value: Any, label: str) -> int:
    require(type(value) is int, f"{label} must be an integer")
    return value


def full_commit(value: Any, label: str) -> str:
    require(isinstance(value, str) and GIT_COMMIT.fullmatch(value) is not None, f"{label} must be a full Git commit")
    return value


def valid_sha(value: Any, label: str) -> str:
    require(isinstance(value, str) and SHA256.fullmatch(value) is not None, f"{label} must be lowercase SHA-256")
    return value


def run_git(root: Path, arguments: list[str], label: str) -> bytes:
    result = subprocess.run(
        ["git", *arguments],
        cwd=root,
        capture_output=True,
        check=False,
    )
    require(result.returncode == 0, f"{label}: {result.stderr.decode('utf-8', 'replace').strip()}")
    return result.stdout


def resolve_commit(root: Path, revision: str, label: str) -> str:
    payload = run_git(root, ["rev-parse", "--verify", f"{revision}^{{commit}}"], label)
    value = payload.decode("ascii").strip()
    return full_commit(value, label)


def require_ancestor(root: Path, ancestor: str, descendant: str, label: str) -> None:
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", ancestor, descendant],
        cwd=root,
        capture_output=True,
        check=False,
    )
    require(result.returncode == 0, f"{label}: {ancestor} is not an ancestor of {descendant}")


def repository_path(value: Any, label: str) -> PurePosixPath:
    require(isinstance(value, str) and value and not value.startswith("/"), f"{label} must be repository-relative")
    path = PurePosixPath(value)
    require(str(path) == value, f"{label} must be normalized")
    require(".." not in path.parts and "." not in path.parts, f"{label} may not traverse")
    require(path.parts and path.parts[0] not in {".git", ".hg", ".svn"}, f"{label} targets repository control data")
    return path


def git_bytes(root: Path, commit: str, path: PurePosixPath, label: str) -> bytes:
    return run_git(root, ["show", f"{commit}:{path.as_posix()}"], label)


def current_authority_bytes(root: Path, path: Path) -> tuple[PurePosixPath, bytes]:
    root_resolved = root.resolve()
    path_resolved = path.resolve()
    require(path_resolved.is_relative_to(root_resolved), "authority path is outside repository")
    relative = PurePosixPath(path_resolved.relative_to(root_resolved).as_posix())
    require(relative.parent == AUTHORITY_ROOT, "authority must be an Integration-owned top-level evidence file")
    require(path_resolved.is_file(), "authority path does not exist")
    return relative, path_resolved.read_bytes()


def published_binding(
    root: Path,
    value: Any,
    label: str,
    trusted_head: str,
    worker_head: str,
) -> dict[str, Any]:
    binding = exact_fields(value, {"path", "sha256", "publicationCommit"}, label)
    path = repository_path(binding["path"], f"{label}.path")
    digest = valid_sha(binding["sha256"], f"{label}.sha256")
    publication = resolve_commit(root, full_commit(binding["publicationCommit"], f"{label}.publicationCommit"), f"{label}.publicationCommit")
    require_ancestor(root, publication, trusted_head, f"{label} publication/trusted ancestry")
    require_ancestor(root, publication, worker_head, f"{label} publication/worker ancestry")
    payload = git_bytes(root, publication, path, f"{label} published bytes")
    require(sha256(payload) == digest, f"{label}.sha256 does not match Git-published bytes")
    return {"path": path.as_posix(), "sha256": digest, "publicationCommit": publication}


def worker_binding(root: Path, value: Any, label: str, worker_head: str) -> dict[str, str]:
    binding = exact_fields(value, {"path", "sha256"}, label)
    path = repository_path(binding["path"], f"{label}.path")
    digest = valid_sha(binding["sha256"], f"{label}.sha256")
    payload = git_bytes(root, worker_head, path, f"{label} worker bytes")
    require(sha256(payload) == digest, f"{label}.sha256 does not match worker HEAD bytes")
    return {"path": path.as_posix(), "sha256": digest}


def claim_revision(payload: bytes, task_id: str) -> int:
    text = payload.decode("utf-8")
    matches = re.findall(r"(?m)^- \*\*Claim revision:\*\* ([1-9][0-9]*)$", text)
    require(len(matches) <= 1, "claim contains duplicate revision declarations")
    if matches:
        return int(matches[0])
    require(task_id == "PLAY-027", "direction claim omits its revision")
    return 1


def validate_schedule(
    root: Path,
    schedule_payload: bytes,
    authority: dict[str, Any],
    trusted_head: str,
    worker_head: str,
) -> None:
    schedule = load_strict_json_bytes(schedule_payload, "schedule")
    schedule_fields = {
        "schema",
        "batch",
        "phase",
        "issuedAt",
        "integrationAuthorityCommit",
        "familyContract",
        "appearanceLock",
        "sourceProductionProfile",
        "computeEnvelope",
        "directionGrants",
    }
    schedule = exact_fields(schedule, schedule_fields, "schedule")
    require(exact_int(schedule["schema"], "schedule.schema") == 1, "schedule.schema must equal 1")
    require(schedule["batch"] == authority["batch"], "schedule batch differs from authority")
    require(schedule["phase"] == authority["schedule"]["phase"], "schedule phase differs from authority")
    require(isinstance(schedule["issuedAt"], str) and UTC_TIMESTAMP.fullmatch(schedule["issuedAt"]) is not None, "schedule.issuedAt must be UTC")
    schedule_authority = resolve_commit(
        root,
        full_commit(schedule["integrationAuthorityCommit"], "schedule.integrationAuthorityCommit"),
        "schedule.integrationAuthorityCommit",
    )
    require_ancestor(root, schedule_authority, trusted_head, "schedule authority/trusted ancestry")
    require_ancestor(root, schedule_authority, worker_head, "schedule authority/worker ancestry")

    family = exact_fields(schedule["familyContract"], {"path", "sha256"}, "schedule.familyContract")
    family_path = repository_path(family["path"], "schedule.familyContract.path")
    family_hash = valid_sha(family["sha256"], "schedule.familyContract.sha256")
    family_bytes = git_bytes(root, authority["schedule"]["publicationCommit"], family_path, "schedule family contract")
    require(sha256(family_bytes) == family_hash, "schedule family contract hash is stale")

    for field in ("appearanceLock", "sourceProductionProfile"):
        schedule_binding = schedule[field]
        closure_binding = authority[field]
        if authority["schedule"]["phase"] == "prelock_north_a":
            require(schedule_binding is None and closure_binding is None, f"prelock {field} must be null")
        else:
            require(schedule_binding is not None and closure_binding is not None, f"postlock {field} is required")
            schedule_binding = exact_fields(schedule_binding, {"path", "sha256"}, f"schedule.{field}")
            require(
                schedule_binding["path"] == closure_binding["path"]
                and schedule_binding["sha256"] == closure_binding["sha256"],
                f"schedule {field} differs from execution authority",
            )

    envelope = exact_fields(
        schedule["computeEnvelope"],
        {"maximumSimultaneousDCCProcesses", "slotIds", "queueOrder"},
        "schedule.computeEnvelope",
    )
    cap = exact_int(envelope["maximumSimultaneousDCCProcesses"], "schedule maximum DCC processes")
    slots = envelope["slotIds"]
    queue = envelope["queueOrder"]
    require(1 <= cap <= 4, "schedule DCC cap must be 1..4")
    require(isinstance(slots, list) and all(isinstance(item, str) and item for item in slots), "schedule slots are invalid")
    require(len(slots) == cap and len(set(slots)) == len(slots), "schedule slots must exactly match cap")
    require(isinstance(queue, list) and all(isinstance(item, str) and item for item in queue), "schedule queue is invalid")
    require(len(queue) == len(set(queue)), "schedule queue contains duplicates")

    entries = schedule["directionGrants"]
    require(isinstance(entries, list) and len(entries) == 4, "schedule must contain exactly four direction grants")
    by_direction: dict[str, dict[str, Any]] = {}
    granted_tokens: set[str] = set()
    schedule_roots: list[PurePosixPath] = []
    for entry in entries:
        entry = exact_fields(
            entry,
            {
                "direction",
                "claim",
                "branch",
                "claimSha256",
                "baseCommit",
                "orchestrator",
                "exclusiveRoots",
                "processes",
            },
            "schedule.directionGrant",
        )
        direction = entry["direction"]
        require(direction in DIRECTION_SPECS and direction not in by_direction, "schedule directions must be unique N/E/S/W")
        spec = DIRECTION_SPECS[direction]
        require(entry["claim"] == spec["taskId"] and entry["branch"] == spec["branch"], f"schedule {direction} task/branch mismatch")
        valid_sha(entry["claimSha256"], f"schedule {direction} claimSha256")
        resolve_commit(root, full_commit(entry["baseCommit"], f"schedule {direction} baseCommit"), f"schedule {direction} baseCommit")
        orchestrator = exact_fields(entry["orchestrator"], {"path", "sha256"}, f"schedule {direction} orchestrator")
        repository_path(orchestrator["path"], f"schedule {direction} orchestrator.path")
        valid_sha(orchestrator["sha256"], f"schedule {direction} orchestrator.sha256")
        roots = entry["exclusiveRoots"]
        require(isinstance(roots, list) and len(roots) >= 2, f"schedule {direction} roots invalid")
        for item in roots:
            schedule_roots.append(repository_path(item, f"schedule {direction} root"))
        processes = entry["processes"]
        require(isinstance(processes, list) and len(processes) == 3, f"schedule {direction} must declare A/B/C")
        by_process: dict[str, dict[str, Any]] = {}
        for process in processes:
            process = exact_fields(
                process,
                {
                    "grantId",
                    "process",
                    "state",
                    "slotId",
                    "maximumChildStarts",
                    "orchestratorOnly",
                    "directLowLevelInvocationAllowed",
                },
                f"schedule {direction} process",
            )
            name = process["process"]
            require(name in {"A", "B", "C"} and name not in by_process, f"schedule {direction} process names invalid")
            by_process[name] = process
            exact_bool(process["orchestratorOnly"], True, f"schedule {direction}:{name} orchestratorOnly")
            exact_bool(process["directLowLevelInvocationAllowed"], False, f"schedule {direction}:{name} directLowLevelInvocationAllowed")
            token = f"{direction}:{name}"
            if process["state"] == "granted":
                require(exact_int(process["maximumChildStarts"], f"schedule {token} maximumChildStarts") == 1, f"schedule {token} must permit one child")
                require(process["slotId"] in slots, f"schedule {token} slot is not provisioned")
                granted_tokens.add(token)
            else:
                require(process["state"] == "blocked", f"schedule {token} state invalid")
                require(exact_int(process["maximumChildStarts"], f"schedule {token} maximumChildStarts") == 0, f"schedule {token} blocked start count must be zero")
                require(process["slotId"] is None, f"schedule {token} blocked slot must be null")
        require(set(by_process) == {"A", "B", "C"}, f"schedule {direction} does not declare A/B/C exactly")
        by_direction[direction] = entry

    require(set(by_direction) == set(DIRECTION_SPECS), "schedule is missing a direction")
    require(set(queue) == granted_tokens, "schedule queue must contain every and only granted process")
    for index, left in enumerate(schedule_roots):
        for right in schedule_roots[index + 1 :]:
            require(left != right, "schedule contains duplicate exclusive roots")

    if schedule["phase"] == "prelock_north_a":
        require(granted_tokens == {"north:A"} and cap == 1, "prelock schedule grants only North A in one slot")
    else:
        expected = {"north:B", "north:C"} | {
            f"{direction}:{process}"
            for direction in ("east", "south", "west")
            for process in ("A", "B", "C")
        }
        require(granted_tokens == expected and cap >= 3, "postlock schedule grant set/cap is invalid")

    task = authority["task"]
    direction_entry = by_direction[task["direction"]]
    require(direction_entry["claim"] == task["taskId"], "schedule task differs from closure task")
    require(direction_entry["branch"] == task["branch"], "schedule branch differs from closure branch")
    require(direction_entry["claimSha256"] == task["claimSha256"], "schedule claim hash differs from closure")
    require(direction_entry["baseCommit"] == task["publishedBaseCommit"], "schedule base differs from closure")
    require(direction_entry["orchestrator"] == authority["artifacts"]["directionScheduleAdapter"], "schedule adapter binding differs from closure")

    process_name = authority["grant"]["process"]
    scheduled_process = next(item for item in direction_entry["processes"] if item["process"] == process_name)
    require(scheduled_process["state"] == "granted", "closure process is not granted by schedule")
    require(scheduled_process["grantId"] == authority["grant"]["grantId"], "closure grantId differs from schedule")
    require(scheduled_process["slotId"] == authority["grant"]["slotId"], "closure slot differs from schedule")
    require(scheduled_process["maximumChildStarts"] == 1, "closure process does not have one child start")
    token = f"{task['direction']}:{process_name}"
    require(authority["grant"]["queueId"] == token and token in queue, "closure queueId differs from schedule queue")


def validate(
    root: Path,
    authority_path: Path,
    *,
    trusted_head: str,
    worker_head: str,
    authority_publication_commit: str,
) -> dict[str, Any]:
    root = root.resolve()
    require((root / ".git").exists(), "repository root has no .git")
    trusted_head = resolve_commit(root, full_commit(trusted_head, "trustedHead"), "trustedHead")
    worker_head = resolve_commit(root, full_commit(worker_head, "workerHead"), "workerHead")
    authority_publication_commit = resolve_commit(
        root,
        full_commit(authority_publication_commit, "authorityPublicationCommit"),
        "authorityPublicationCommit",
    )
    fetched_master = resolve_commit(root, "refs/remotes/origin/master", "fetched origin/master")
    require(trusted_head == fetched_master, "caller-supplied trustedHead does not equal fetched origin/master")
    require_ancestor(root, authority_publication_commit, trusted_head, "authority publication/trusted ancestry")
    require_ancestor(root, authority_publication_commit, worker_head, "authority publication/worker ancestry")
    require_ancestor(root, trusted_head, worker_head, "trusted head/worker ancestry")

    authority_relative, current_payload = current_authority_bytes(root, authority_path)
    published_payload = git_bytes(
        root,
        authority_publication_commit,
        authority_relative,
        "authority Git-published bytes",
    )
    require(current_payload == published_payload, "authority working bytes differ from authority publication commit")
    authority = load_strict_json_bytes(current_payload, "authority")
    authority = exact_fields(authority, TOP_FIELDS, "authority")
    require(authority["$schema"] == SCHEMA_ID, "wrong authority schema id")
    require(exact_int(authority["schemaVersion"], "schemaVersion") == 1, "schemaVersion must equal 1")
    require(
        exact_int(authority["testProtocolRevision"], "testProtocolRevision") == 6,
        "testProtocolRevision must equal 6",
    )
    require(authority["batch"] == "industrial_l04_directional_family", "wrong batch")
    require(authority["mode"] == "validation_only", "authority must be validation_only")
    require(isinstance(authority["issuedAt"], str) and UTC_TIMESTAMP.fullmatch(authority["issuedAt"]) is not None, "issuedAt must be second-precision UTC")

    task = exact_fields(
        authority["task"],
        {
            "taskId",
            "direction",
            "branch",
            "claimPath",
            "claimRevision",
            "claimSha256",
            "publishedBaseCommit",
        },
        "task",
    )
    direction = task["direction"]
    require(direction in DIRECTION_SPECS, "invalid direction")
    spec = DIRECTION_SPECS[direction]
    for field in ("taskId", "branch", "claimPath"):
        require(task[field] == spec[field], f"task.{field} does not match {direction}")
    revision = exact_int(task["claimRevision"], "task.claimRevision")
    require(revision >= 1, "task.claimRevision must be positive")
    claim_hash = valid_sha(task["claimSha256"], "task.claimSha256")
    base = resolve_commit(root, full_commit(task["publishedBaseCommit"], "task.publishedBaseCommit"), "task.publishedBaseCommit")
    require_ancestor(root, base, trusted_head, "task base/trusted ancestry")
    require_ancestor(root, base, worker_head, "task base/worker ancestry")
    claim_path = repository_path(task["claimPath"], "task.claimPath")
    claim_payload = git_bytes(root, base, claim_path, "claim published bytes")
    require(sha256(claim_payload) == claim_hash, "task claim hash differs from published base bytes")
    require(claim_revision(claim_payload, task["taskId"]) == revision, "task claim revision differs from published claim")

    schedule_binding = exact_fields(
        authority["schedule"],
        {"path", "sha256", "publicationCommit", "phase"},
        "schedule binding",
    )
    schedule_path = repository_path(schedule_binding["path"], "schedule.path")
    require(schedule_path.parent == SCHEDULE_ROOT, "schedule must be an Integration-owned top-level evidence file")
    schedule_hash = valid_sha(schedule_binding["sha256"], "schedule.sha256")
    schedule_publication = resolve_commit(
        root,
        full_commit(schedule_binding["publicationCommit"], "schedule.publicationCommit"),
        "schedule.publicationCommit",
    )
    require_ancestor(root, schedule_publication, trusted_head, "schedule publication/trusted ancestry")
    require_ancestor(root, schedule_publication, worker_head, "schedule publication/worker ancestry")
    require(schedule_binding["phase"] in {"prelock_north_a", "postlock_abc"}, "schedule.phase is invalid")
    schedule_payload = git_bytes(root, schedule_publication, schedule_path, "schedule Git-published bytes")
    require(sha256(schedule_payload) == schedule_hash, "schedule hash differs from Git-published bytes")

    for field in ("appearanceLock", "sourceProductionProfile"):
        if authority[field] is not None:
            authority[field] = published_binding(root, authority[field], field, trusted_head, worker_head)

    grant = exact_fields(
        authority["grant"],
        {
            "grantId",
            "process",
            "queueId",
            "slotId",
            "maximumChildStarts",
            "exactlyOneInvocation",
            "orchestratorOnly",
            "directLowLevelInvocationAllowed",
        },
        "grant",
    )
    for field in ("grantId", "queueId", "slotId"):
        require(isinstance(grant[field], str) and grant[field], f"grant.{field} must be nonempty")
    require(grant["process"] in {"A", "B", "C"}, "grant.process is invalid")
    require(exact_int(grant["maximumChildStarts"], "grant.maximumChildStarts") == 1, "grant must permit exactly one child start")
    exact_bool(grant["exactlyOneInvocation"], True, "grant.exactlyOneInvocation")
    exact_bool(grant["orchestratorOnly"], True, "grant.orchestratorOnly")
    exact_bool(grant["directLowLevelInvocationAllowed"], False, "grant.directLowLevelInvocationAllowed")

    artifacts = exact_fields(
        authority["artifacts"],
        {
            "executionContract",
            "directionScheduleAdapter",
            "highLevelOrchestrator",
            "runnerContract",
            "runnerEntrypoint",
            "scene",
            "materials",
            "toolchain",
        },
        "artifacts",
    )
    validated_artifacts: dict[str, dict[str, str]] = {}
    native_anchor = PurePosixPath(spec["artifactRoot"])
    for name, binding in artifacts.items():
        validated = worker_binding(root, binding, f"artifacts.{name}", worker_head)
        path = PurePosixPath(validated["path"])
        require(path.is_relative_to(native_anchor), f"artifacts.{name} is outside the {direction}-exclusive native root")
        validated_artifacts[name] = validated
    require(
        len({item["path"] for item in validated_artifacts.values()}) == len(validated_artifacts),
        "artifact paths must not alias",
    )
    require(
        validated_artifacts["highLevelOrchestrator"]["path"]
        != validated_artifacts["runnerEntrypoint"]["path"],
        "high-level orchestrator may not alias the low-level runner entrypoint",
    )
    authority["artifacts"] = validated_artifacts

    roots = exact_fields(authority["exclusiveRoots"], {"output", "evidence", "attempt", "terminal"}, "exclusiveRoots")
    root_specs = {
        "output": (PurePosixPath(spec["nativeRoot"]), "outputs"),
        "evidence": (PurePosixPath(spec["evidenceRoot"]), "evidence"),
        "attempt": (PurePosixPath(spec["evidenceRoot"]), "attempts"),
        "terminal": (PurePosixPath(spec["evidenceRoot"]), "terminals"),
    }
    normalized_roots: dict[str, PurePosixPath] = {}
    for name, (anchor, category) in root_specs.items():
        value = repository_path(roots[name], f"exclusiveRoots.{name}")
        require(value.is_relative_to(anchor), f"exclusiveRoots.{name} is outside its {direction}-exclusive root")
        resolved = (root / value.as_posix()).resolve()
        require(resolved.is_relative_to(root), f"exclusiveRoots.{name} resolves outside repository")
        require(not resolved.exists(), f"exclusiveRoots.{name} already exists; replay is forbidden")
        normalized_roots[name] = value
    root_values = list(normalized_roots.values())
    for index, left in enumerate(root_values):
        for right in root_values[index + 1 :]:
            require(
                not left.is_relative_to(right) and not right.is_relative_to(left),
                "direction-exclusive roots overlap",
            )
    for name, (anchor, category) in root_specs.items():
        require(
            normalized_roots[name].is_relative_to(anchor / category),
            f"exclusiveRoots.{name} is outside its {direction}-exclusive {category} root",
        )

    envelope = exact_fields(
        authority["executionEnvelope"],
        {
            "timeoutSeconds",
            "maximumRSSBytes",
            "cpuThreadLimit",
            "startNewProcessGroup",
            "killProcessGroupOnLimit",
            "postReapProcessGroupExhaustionRequired",
            "networkAllowed",
            "leasePath",
            "leaseMustBeFresh",
            "replayAllowed",
        },
        "executionEnvelope",
    )
    timeout = envelope["timeoutSeconds"]
    require(type(timeout) in {int, float} and math.isfinite(timeout) and 0 < timeout <= 7200, "timeoutSeconds must be finite and in (0,7200]")
    rss = exact_int(envelope["maximumRSSBytes"], "executionEnvelope.maximumRSSBytes")
    require(1048576 <= rss <= 68719476736, "maximumRSSBytes is outside the governed envelope")
    require(exact_int(envelope["cpuThreadLimit"], "executionEnvelope.cpuThreadLimit") == 1, "child is limited to one CPU thread")
    exact_bool(envelope["startNewProcessGroup"], True, "executionEnvelope.startNewProcessGroup")
    exact_bool(envelope["killProcessGroupOnLimit"], True, "executionEnvelope.killProcessGroupOnLimit")
    exact_bool(
        envelope["postReapProcessGroupExhaustionRequired"],
        True,
        "executionEnvelope.postReapProcessGroupExhaustionRequired",
    )
    exact_bool(envelope["networkAllowed"], False, "executionEnvelope.networkAllowed")
    exact_bool(envelope["leaseMustBeFresh"], True, "executionEnvelope.leaseMustBeFresh")
    exact_bool(envelope["replayAllowed"], False, "executionEnvelope.replayAllowed")
    lease = envelope["leasePath"]
    require(isinstance(lease, str) and LEASE_PATH.fullmatch(lease) is not None, "leasePath is not direction-scoped")
    require(LEASE_PATH.fullmatch(lease).group(1) == direction, "leasePath direction differs from task direction")
    require(not Path(lease).exists(), "lease already exists; replay or concurrent execution is forbidden")

    authentication = exact_fields(
        authority["authentication"],
        {"secretTransport", "secretSha256", "rawSecretPersisted", "childCapability"},
        "authentication",
    )
    require(authentication["secretTransport"] == "anonymous_pipe", "secret must use an anonymous pipe")
    secret_hash = valid_sha(authentication["secretSha256"], "authentication.secretSha256")
    require(secret_hash != "0" * 64, "secretSha256 may not be the all-zero placeholder")
    exact_bool(authentication["rawSecretPersisted"], False, "authentication.rawSecretPersisted")
    capability = exact_fields(
        authentication["childCapability"],
        {
            "algorithm",
            "capabilityId",
            "audience",
            "boundGrantId",
            "payloadSha256",
            "macSha256",
            "oneTime",
            "replayAllowed",
        },
        "authentication.childCapability",
    )
    require(capability["algorithm"] == "HMAC-SHA256", "child capability must use HMAC-SHA256")
    require(isinstance(capability["capabilityId"], str) and capability["capabilityId"], "capabilityId must be nonempty")
    require(capability["audience"] == "industrial-l04-direction-child", "child capability audience is invalid")
    require(capability["boundGrantId"] == grant["grantId"], "child capability is not bound to the exact grant")
    valid_sha(capability["payloadSha256"], "childCapability.payloadSha256")
    mac = valid_sha(capability["macSha256"], "childCapability.macSha256")
    require(mac != "0" * 64, "child capability MAC may not be the all-zero placeholder")
    exact_bool(capability["oneTime"], True, "childCapability.oneTime")
    exact_bool(capability["replayAllowed"], False, "childCapability.replayAllowed")

    disposition = exact_fields(
        authority["disposition"],
        {
            "validationOnly",
            "liveLeaseAuthorized",
            "childStartAuthorized",
            "dccExecutionAuthorized",
            "renderAuthorized",
            "pixelAuthorized",
            "sourceCandidateReady",
            "appearanceAccepted",
            "sourceProfileActivated",
            "integrationAdmitted",
            "rendererQuarantined",
            "productionSelected",
            "shippingAuthorized",
        },
        "disposition",
    )
    exact_bool(disposition["validationOnly"], True, "disposition.validationOnly")
    for field, value in disposition.items():
        if field != "validationOnly":
            exact_bool(value, False, f"disposition.{field}")

    validate_schedule(root, schedule_payload, authority, trusted_head, worker_head)
    return {
        "result": "PASS",
        "schema": SCHEMA_ID,
        "testProtocolRevision": 6,
        "authorityPath": authority_relative.as_posix(),
        "authorityPublicationCommit": authority_publication_commit,
        "trustedHead": trusted_head,
        "workerHead": worker_head,
        "taskId": task["taskId"],
        "direction": direction,
        "process": grant["process"],
        "grantId": grant["grantId"],
        "queueId": grant["queueId"],
        "slotId": grant["slotId"],
        "maximumChildStarts": 1,
        "exactlyOneInvocation": True,
        "validationOnly": True,
        "dccStarts": 0,
        "childStarts": 0,
        "renders": 0,
        "pixels": 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("authority")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--trusted-head", required=True)
    parser.add_argument("--worker-head", required=True)
    parser.add_argument("--authority-publication-commit", required=True)
    args = parser.parse_args()
    try:
        result = validate(
            Path(args.repo_root),
            Path(args.authority),
            trusted_head=args.trusted_head,
            worker_head=args.worker_head,
            authority_publication_commit=args.authority_publication_commit,
        )
    except (OSError, AuthorityError) as error:
        print(json.dumps({"result": "FAIL", "reason": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
