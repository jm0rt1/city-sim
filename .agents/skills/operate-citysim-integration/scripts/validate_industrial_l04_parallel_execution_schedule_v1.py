#!/usr/bin/env python3
"""Fail-closed semantic validation for Industrial L4 process launch schedules."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

SHA256 = re.compile(r"^[0-9a-f]{64}$")
GIT_COMMIT = re.compile(r"^[0-9a-f]{40}$")
DIRECTIONS = ("north", "east", "south", "west")
PROCESSES = ("A", "B", "C")
EXPECTED = {
    "north": ("PLAY-027", "codex/citysim-world-art"),
    "east": ("PLAY-079", "codex/citysim-world-art-east"),
    "south": ("PLAY-080", "codex/citysim-world-art-south"),
    "west": ("PLAY-081", "codex/citysim-world-art-west"),
}


class ScheduleError(ValueError):
    pass


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ScheduleError(message)


def validate_binding(root: Path, binding: object, label: str) -> None:
    require(isinstance(binding, dict), f"{label} must be an object")
    require(set(binding) == {"path", "sha256"}, f"{label} has unexpected fields")
    path = binding.get("path")
    sha = binding.get("sha256")
    require(isinstance(path, str) and path and not path.startswith("/"), f"{label}.path must be repository-relative")
    require(isinstance(sha, str) and SHA256.fullmatch(sha) is not None, f"{label}.sha256 is invalid")
    resolved = (root / path).resolve()
    require(resolved.is_relative_to(root.resolve()), f"{label}.path escapes repository")
    require(resolved.is_file(), f"{label}.path does not exist: {path}")
    require(digest(resolved) == sha, f"{label}.sha256 is stale: {path}")


def git_object_exists(root: Path, sha: str, label: str) -> None:
    require(GIT_COMMIT.fullmatch(sha) is not None, f"{label} is not a full Git commit id")
    result = subprocess.run(
        ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    require(result.returncode == 0, f"{label} is not a repository commit: {sha}")


def validate(root: Path, schedule_path: Path) -> dict:
    data = json.loads(schedule_path.read_text())
    required_top = {
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
    require(isinstance(data, dict) and set(data) == required_top, "top-level fields do not match schema v1")
    require(data["schema"] == 1, "schema must equal 1")
    require(data["batch"] == "industrial_l04_directional_family", "wrong batch")
    require(data["phase"] in {"prelock_north_a", "postlock_abc"}, "invalid phase")
    require(isinstance(data["issuedAt"], str) and data["issuedAt"].endswith("Z"), "issuedAt must be UTC")
    git_object_exists(root, data["integrationAuthorityCommit"], "integrationAuthorityCommit")
    validate_binding(root, data["familyContract"], "familyContract")

    if data["phase"] == "prelock_north_a":
        require(data["appearanceLock"] is None, "prelock schedule must not bind an appearance lock")
        require(data["sourceProductionProfile"] is None, "prelock schedule must not bind a source profile")
    else:
        require(data["appearanceLock"] is not None, "postlock schedule requires appearance lock")
        require(data["sourceProductionProfile"] is not None, "postlock schedule requires source profile")
        validate_binding(root, data["appearanceLock"], "appearanceLock")
        validate_binding(root, data["sourceProductionProfile"], "sourceProductionProfile")

    envelope = data["computeEnvelope"]
    require(
        isinstance(envelope, dict)
        and set(envelope) == {"maximumSimultaneousDCCProcesses", "slotIds", "queueOrder"},
        "invalid computeEnvelope fields",
    )
    cap = envelope["maximumSimultaneousDCCProcesses"]
    slots = envelope["slotIds"]
    queue = envelope["queueOrder"]
    require(isinstance(cap, int) and 1 <= cap <= 4, "DCC process cap must be 1..4")
    require(isinstance(slots, list) and len(slots) == cap and len(set(slots)) == len(slots), "slotIds must exactly match cap")
    require(isinstance(queue, list) and len(queue) == len(set(queue)), "queueOrder must be unique")

    grants = data["directionGrants"]
    require(isinstance(grants, list) and len(grants) == 4, "exactly four direction grants required")
    by_direction = {}
    all_grant_ids: set[str] = set()
    all_roots: set[str] = set()
    granted_tokens: set[str] = set()

    for entry in grants:
        require(isinstance(entry, dict), "direction grant must be an object")
        required_direction = {
            "direction",
            "claim",
            "branch",
            "claimSha256",
            "baseCommit",
            "orchestrator",
            "exclusiveRoots",
            "processes",
        }
        require(set(entry) == required_direction, "direction grant fields do not match schema v1")
        direction = entry["direction"]
        require(direction in DIRECTIONS and direction not in by_direction, "direction grants must be unique N/E/S/W")
        by_direction[direction] = entry
        require((entry["claim"], entry["branch"]) == EXPECTED[direction], f"{direction} claim/branch mismatch")
        require(SHA256.fullmatch(entry["claimSha256"]) is not None, f"{direction} claim hash invalid")
        git_object_exists(root, entry["baseCommit"], f"{direction}.baseCommit")
        validate_binding(root, entry["orchestrator"], f"{direction}.orchestrator")

        roots = entry["exclusiveRoots"]
        require(isinstance(roots, list) and len(roots) >= 2 and len(set(roots)) == len(roots), f"{direction} roots invalid")
        for owned_root in roots:
            require(isinstance(owned_root, str) and owned_root and not owned_root.startswith("/"), f"{direction} root invalid")
            require(owned_root not in all_roots, f"exclusive root overlaps another direction: {owned_root}")
            all_roots.add(owned_root)

        processes = entry["processes"]
        require(isinstance(processes, list) and len(processes) == 3, f"{direction} must declare A/B/C")
        by_process = {}
        for process in processes:
            required_process = {
                "grantId",
                "process",
                "state",
                "slotId",
                "maximumChildStarts",
                "orchestratorOnly",
                "directLowLevelInvocationAllowed",
            }
            require(isinstance(process, dict) and set(process) == required_process, "process grant fields invalid")
            name = process["process"]
            require(name in PROCESSES and name not in by_process, f"{direction} A/B/C must be unique")
            by_process[name] = process
            grant_id = process["grantId"]
            require(isinstance(grant_id, str) and grant_id and grant_id not in all_grant_ids, "grantId must be unique")
            all_grant_ids.add(grant_id)
            require(process["orchestratorOnly"] is True, "all process starts must use the approved orchestrator")
            require(process["directLowLevelInvocationAllowed"] is False, "direct low-level invocation is forbidden")
            token = f"{direction}:{name}"
            if process["state"] == "granted":
                require(process["maximumChildStarts"] == 1, f"{token} must allow exactly one child")
                require(process["slotId"] in slots, f"{token} uses an unknown slot")
                granted_tokens.add(token)
            else:
                require(process["state"] == "blocked", f"{token} state invalid")
                require(process["maximumChildStarts"] == 0 and process["slotId"] is None, f"{token} blocked grant must have no slot/start")
        require(set(by_process) == set(PROCESSES), f"{direction} must declare A/B/C exactly")

    require(set(by_direction) == set(DIRECTIONS), "missing direction grant")
    require(set(queue) == granted_tokens, "queueOrder must contain every and only granted process")

    if data["phase"] == "prelock_north_a":
        require(granted_tokens == {"north:A"}, "prelock phase grants exactly North Process A")
        require(cap == 1, "prelock phase has exactly one DCC slot")
    else:
        expected = {"north:B", "north:C"}
        expected |= {f"{direction}:{process}" for direction in ("east", "south", "west") for process in PROCESSES}
        require(granted_tokens == expected, "postlock phase must grant North B/C and sibling A/B/C")
        require(cap >= 3, "postlock phase requires at least three concurrent DCC slots")

    return {
        "result": "PASS",
        "schedule": str(schedule_path),
        "phase": data["phase"],
        "grantedProcesses": sorted(granted_tokens),
        "maximumSimultaneousDCCProcesses": cap,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("schedule")
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()
    try:
        result = validate(Path(args.repo_root).resolve(), Path(args.schedule).resolve())
    except (OSError, json.JSONDecodeError, ScheduleError) as error:
        print(json.dumps({"result": "FAIL", "reason": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
