#!/usr/bin/env python3
"""Fail-closed validator for one Residential L1 v1 North Process-A launch."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
from datetime import datetime
from pathlib import Path, PurePosixPath
from typing import Any

SHA256 = re.compile(r"^[0-9a-f]{64}$")
GIT_COMMIT = re.compile(r"^[0-9a-f]{40}$")
BATCH = "residential-l01-variant1-v1"
THREAD = "019f96e0-3793-7542-9172-060a9ca09b0a"
BRANCH = "codex/citysim-world-art"
WORKTREE = "/Users/James/.codex/worktrees/0648/city-sim"
FAMILY_PATH = "docs/production/decisions/CONTRACT-023-residential-l01-variant-one-family.md"
CLAIM_PATH = "docs/production/claims/PLAY-090.world-art-north.md"
STARTUP_PATH = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v14/native-blender-startup-probe-v1/RECEIPT.json"
SOURCE_ROOT = "Native/CitySimNative/WorldArt/Blender/PLAY-090/residential-l01-variant1-north/process-a-execution-v01"
EVIDENCE_ROOT = "docs/production/evidence/PLAY-090/residential-l01-variant1-north-process-a-v1"
ORCHESTRATOR_PATH = f"{SOURCE_ROOT}/launch_north_process_a.py"
CHILD_PATH = f"{SOURCE_ROOT}/render_north_process_a_child.py"
OUTPUT_ROOT = f"{SOURCE_ROOT}/process-a-output"
INTEGRATION_ROOT = "docs/production/evidence/INTEGRATION/PLAY-090-RESIDENTIAL-L01-VARIANT1-NORTH-PROCESS-A-V1"
ATTEMPT_PATH = f"{INTEGRATION_ROOT}/ATTEMPT.json"
PROCESS_RECEIPT_PATH = f"{INTEGRATION_ROOT}/PROCESS-RECEIPT.json"
SLOT = "residential-v1-north-a-slot-0"


class ScheduleError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ScheduleError(message)


def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in items:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_constant(value: str) -> None:
    raise ScheduleError(f"non-finite number: {value}")


def load_bytes(payload: bytes, label: str) -> Any:
    try:
        return json.loads(payload.decode("utf-8"), object_pairs_hook=pairs, parse_constant=reject_constant)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ScheduleError(f"{label}: {error}") from error


def digest_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def digest(path: Path) -> str:
    return digest_bytes(path.read_bytes())


def git(root: Path, *args: str, binary: bool = False) -> bytes | str:
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=not binary)
    if result.returncode:
        stderr = result.stderr.decode(errors="replace") if binary else result.stderr
        raise ScheduleError(f"git {' '.join(args)} failed: {stderr.strip()}")
    return result.stdout if binary else result.stdout.strip()


def git_blob(root: Path, commit: str, path: str) -> bytes:
    return git(root, "show", f"{commit}:{path}", binary=True)  # type: ignore[return-value]


def is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    return subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", ancestor, descendant]).returncode == 0


def repo_path(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty path")
    path = PurePosixPath(value)
    require(not path.is_absolute() and "." not in path.parts and ".." not in path.parts, f"{label} must be repository-relative")
    return value.rstrip("/")


def validate_file_binding(value: Any, label: str, expected_path: str | None = None) -> tuple[str, str]:
    require(isinstance(value, dict) and set(value) == {"path", "sha256"}, f"{label} binding fields invalid")
    path = repo_path(value["path"], f"{label}.path")
    require(expected_path is None or path == expected_path, f"{label}.path mismatch")
    require(isinstance(value["sha256"], str) and SHA256.fullmatch(value["sha256"]), f"{label}.sha256 invalid")
    return path, value["sha256"]


def validate_authority_binding(root: Path, authority: str, value: Any, label: str, expected_path: str) -> bytes:
    path, sha = validate_file_binding(value, label, expected_path)
    payload = git_blob(root, authority, path)
    require(digest_bytes(payload) == sha, f"{label} does not match authority blob")
    return payload


def validate_worker_binding(worker_root: Path, head: str, value: Any, label: str, expected_path: str) -> bytes:
    path, sha = validate_file_binding(value, label, expected_path)
    payload = git_blob(worker_root, head, path)
    require(digest_bytes(payload) == sha, f"{label} does not match worker HEAD blob")
    working = worker_root / path
    require(working.is_file() and not working.is_symlink() and working.read_bytes() == payload, f"{label} working bytes differ from worker HEAD")
    return payload


def parse_utc(value: Any, label: str) -> None:
    require(isinstance(value, str) and value.endswith("Z"), f"{label} must be UTC Z time")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ScheduleError(f"{label} is invalid") from error
    require(parsed.utcoffset() is not None, f"{label} lacks timezone")


def validate_process_receipt(authority_root: Path, authority: str, binding: Any, data: dict[str, Any]) -> dict[str, Any]:
    require(isinstance(binding, dict) and set(binding) == {"path", "sha256", "commit"}, "integrationProcessReceipt fields invalid")
    path = repo_path(binding["path"], "integrationProcessReceipt.path")
    require(path == PROCESS_RECEIPT_PATH, "integrationProcessReceipt.path mismatch")
    require(SHA256.fullmatch(binding["sha256"] or "") and GIT_COMMIT.fullmatch(binding["commit"] or ""), "integrationProcessReceipt hash/commit invalid")
    git(authority_root, "cat-file", "-e", f"{binding['commit']}^{{commit}}")
    require(is_ancestor(authority_root, authority, binding["commit"]), "process receipt commit predates authority")
    payload = git_blob(authority_root, binding["commit"], path)
    require(digest_bytes(payload) == binding["sha256"], "process receipt committed bytes mismatch")
    working = authority_root / path
    require(working.is_file() and working.read_bytes() == payload, "process receipt working bytes differ from committed binding")
    receipt = load_bytes(payload, path)
    fields = {
        "schema", "taskId", "family", "direction", "process", "grantId", "slotId",
        "authorityCommit", "workerHead", "claimSha256", "orchestratorSha256",
        "childSha256", "startupReceiptSha256", "executableSha256", "outputRoot",
        "attemptMarker", "maximumChildStarts", "pixelProductionAuthorized",
        "consumed", "attemptCount",
    }
    require(isinstance(receipt, dict) and set(receipt) == fields, "process receipt fields invalid")
    expected = {
        "schema": 1,
        "taskId": "PLAY-090",
        "family": BATCH,
        "direction": "north",
        "process": "A",
        "grantId": data["northGrant"]["grantId"],
        "slotId": SLOT,
        "authorityCommit": authority,
        "workerHead": data["worker"]["head"],
        "claimSha256": data["claim"]["sha256"],
        "orchestratorSha256": data["orchestrator"]["sha256"],
        "childSha256": data["child"]["sha256"],
        "startupReceiptSha256": data["startupReceipt"]["sha256"],
        "executableSha256": data["executable"]["sha256"],
        "outputRoot": OUTPUT_ROOT,
        "attemptMarker": ATTEMPT_PATH,
        "maximumChildStarts": 1,
        "pixelProductionAuthorized": True,
        "consumed": False,
        "attemptCount": 0,
    }
    require(receipt == expected, "process receipt does not exactly cross-bind schedule authority")
    return receipt


def validate(schedule_path: Path, authority_root: Path, worker_root: Path) -> dict[str, Any]:
    data = load_bytes(schedule_path.read_bytes(), str(schedule_path))
    top = {
        "schema", "batch", "phase", "issuedAt", "integrationAuthorityCommit",
        "familyContract", "claim", "worker", "startupReceipt", "executable",
        "orchestrator", "child", "computeEnvelope", "northGrant",
        "blockedProcesses", "blockedDirections", "exclusiveRoots",
        "integrationProcessReceipt", "productionBoundary",
    }
    require(isinstance(data, dict) and set(data) == top, "top-level fields invalid")
    require((data["schema"], data["batch"], data["phase"]) == (1, BATCH, "prelock_north_a"), "schema/batch/phase mismatch")
    parse_utc(data["issuedAt"], "issuedAt")
    authority = data["integrationAuthorityCommit"]
    require(isinstance(authority, str) and GIT_COMMIT.fullmatch(authority), "integrationAuthorityCommit invalid")
    git(authority_root, "cat-file", "-e", f"{authority}^{{commit}}")

    family = validate_authority_binding(authority_root, authority, data["familyContract"], "familyContract", FAMILY_PATH).decode()
    require("CONTRACT-023" in family and "Integration alone owns" in family, "family contract semantics mismatch")
    claim = validate_authority_binding(authority_root, authority, data["claim"], "claim", CLAIM_PATH).decode()
    require("# PLAY-090 Claim" in claim and BRANCH in claim and WORKTREE in claim and SOURCE_ROOT in claim and EVIDENCE_ROOT in claim, "claim semantics mismatch")

    worker = data["worker"]
    require(isinstance(worker, dict) and set(worker) == {"threadId", "branch", "worktree", "head"}, "worker fields invalid")
    require((worker["threadId"], worker["branch"], worker["worktree"]) == (THREAD, BRANCH, WORKTREE), "worker identity mismatch")
    head = worker["head"]
    require(isinstance(head, str) and GIT_COMMIT.fullmatch(head), "worker.head invalid")
    git(worker_root, "cat-file", "-e", f"{head}^{{commit}}")
    require(is_ancestor(worker_root, authority, head), "worker HEAD does not descend from authority")
    require(git(worker_root, "branch", "--show-current") == BRANCH and git(worker_root, "rev-parse", "HEAD") == head, "live worker branch/HEAD mismatch")
    require(git(worker_root, "status", "--porcelain=v1") == "", "worker worktree is dirty")
    validate_worker_binding(worker_root, head, data["orchestrator"], "orchestrator", ORCHESTRATOR_PATH)
    validate_worker_binding(worker_root, head, data["child"], "child", CHILD_PATH)

    startup_payload = validate_authority_binding(authority_root, authority, data["startupReceipt"], "startupReceipt", STARTUP_PATH)
    startup = load_bytes(startup_payload, STARTUP_PATH)
    require(isinstance(startup, dict) and startup.get("startupPass") is True and startup.get("processAccounting", {}).get("activeBlenderAfterProbe") is False, "startup receipt is not a closed passing probe")

    executable = data["executable"]
    executable_fields = {"path", "sha256", "architecture", "version", "buildHash", "factoryStartup", "autoexecDisabled"}
    require(isinstance(executable, dict) and set(executable) == executable_fields, "executable fields invalid")
    path = Path(executable["path"])
    require(path.is_absolute() and path.is_file() and not path.is_symlink(), "executable must be an absolute regular non-symlink file")
    mode = path.stat().st_mode
    require(stat.S_ISREG(mode) and os.access(path, os.X_OK) and digest(path) == executable["sha256"], "executable path/hash/mode mismatch")
    binary = startup.get("binary", {})
    require((binary.get("path"), binary.get("architecture"), binary.get("version"), binary.get("buildHash")) == (executable["path"], executable["architecture"], executable["version"], executable["buildHash"]), "startup receipt/executable tuple mismatch")
    require(executable["factoryStartup"] is True and executable["autoexecDisabled"] is True, "executable safety flags missing")
    file_result = subprocess.run(["/usr/bin/file", str(path)], capture_output=True, text=True)
    require(file_result.returncode == 0 and executable["architecture"] in file_result.stdout, "executable architecture mismatch")

    envelope = data["computeEnvelope"]
    require(isinstance(envelope, dict) and set(envelope) == {"maximumSimultaneousDCCProcesses", "slotIds", "queueOrder"}, "computeEnvelope fields invalid")
    require(envelope == {"maximumSimultaneousDCCProcesses": 1, "slotIds": [SLOT], "queueOrder": ["north:A"]}, "schedule must grant one North-A slot only")
    grant = data["northGrant"]
    grant_fields = {"grantId", "direction", "process", "state", "slotId", "maximumChildStarts", "orchestratorOnly", "directLowLevelInvocationAllowed", "pixelProductionAuthorized"}
    require(isinstance(grant, dict) and set(grant) == grant_fields and isinstance(grant["grantId"], str) and grant["grantId"], "northGrant fields invalid")
    expected_grant = {
        "direction": "north", "process": "A", "state": "granted", "slotId": SLOT,
        "maximumChildStarts": 1, "orchestratorOnly": True,
        "directLowLevelInvocationAllowed": False, "pixelProductionAuthorized": True,
    }
    require({key: grant[key] for key in expected_grant} == expected_grant, "northGrant is not exact one-child orchestrator-only North A")
    require(data["blockedProcesses"] == ["B", "C"] and data["blockedDirections"] == ["east", "south", "west"], "B/C and sibling directions must remain blocked")

    roots = data["exclusiveRoots"]
    require(isinstance(roots, dict) and set(roots) == {"sourceRoot", "evidenceRoot", "outputRoot", "attemptMarker"}, "exclusiveRoots fields invalid")
    require(roots == {"sourceRoot": SOURCE_ROOT, "evidenceRoot": EVIDENCE_ROOT, "outputRoot": OUTPUT_ROOT, "attemptMarker": ATTEMPT_PATH}, "exclusive roots mismatch")
    require(not (worker_root / OUTPUT_ROOT).exists(), "exclusive output root must be absent before launch")
    require(not (authority_root / ATTEMPT_PATH).exists(), "attempt marker must be absent before launch")

    boundary = data["productionBoundary"]
    boundary_fields = {"pixelsAuthorizedByGrantId", "requireOutputRootAbsent", "requireAttemptMarkerAbsent", "maximumAttempts", "appearanceLockPublished", "sourceAuthority", "productionSelected", "siblingPixelsAuthorized"}
    require(isinstance(boundary, dict) and set(boundary) == boundary_fields, "productionBoundary fields invalid")
    expected_boundary = {
        "pixelsAuthorizedByGrantId": grant["grantId"], "requireOutputRootAbsent": True,
        "requireAttemptMarkerAbsent": True, "maximumAttempts": 1,
        "appearanceLockPublished": False, "sourceAuthority": False,
        "productionSelected": False, "siblingPixelsAuthorized": False,
    }
    require(boundary == expected_boundary, "pixel/source/production boundary mismatch")
    validate_process_receipt(authority_root, authority, data["integrationProcessReceipt"], data)

    return {
        "result": "PASS", "batch": BATCH, "phase": "prelock_north_a",
        "grantedProcesses": ["north:A"], "maximumSimultaneousDCCProcesses": 1,
        "workerHead": head, "grantId": grant["grantId"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("schedule")
    parser.add_argument("--authority-root", default=".")
    parser.add_argument("--worker-root", required=True)
    args = parser.parse_args()
    try:
        result = validate(Path(args.schedule).resolve(), Path(args.authority_root).resolve(), Path(args.worker_root).resolve())
    except (OSError, ScheduleError) as error:
        print(json.dumps({"result": "FAIL", "reason": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
