#!/usr/bin/env python3
"""Executable gate for Residential L1 variant-one parallel state."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path, PurePosixPath
from typing import Any, Callable


AUTHORITY = "07b2ad82eac047573537503ffdb091499310f644"
BATCH = "residential-l01-variant1-v1"
CELLS = ("north", "east", "south", "west", "renderer", "qa")
DIRECTIONS = ("north", "east", "south", "west")
QA_PREREG_THREAD = "019fc0b0-74cb-70e1-8923-8c9d9600484d"
FINAL_QA_REVIEWER = "019f7686-4491-7891-86a6-95a78d67e5c8"
PHASES = (
    "contract_pending", "prelock_active", "appearance_lock_pending",
    "abc_active", "4of4_ready", "exact_candidate_qa", "integrated",
)
PHASE_NEXT = {
    phase: {phase, PHASES[min(index + 1, len(PHASES) - 1)]}
    for index, phase in enumerate(PHASES)
}
ESCALATIONS = {
    "baseline_or_candidate_identity_mismatch",
    "cross_lane_semantic_conflict",
    "failure_outside_focused_scope",
    "path_outside_claim",
    "save_or_migration_uncertainty",
    "shared_contract_or_schema_decision",
    "subjective_acceptance_required",
    "two_unsuccessful_repair_attempts",
    "unresolved_product_visual_or_interaction_judgment",
}
EXPECTED = {
    "north": ("PLAY-090", "019f96e0-3793-7542-9172-060a9ca09b0a", "codex/citysim-world-art", "/Users/James/.codex/worktrees/0648/city-sim", "docs/production/claims/PLAY-090.world-art-north.md"),
    "east": ("PLAY-091", "019fab72-b2c8-76c1-b430-6c6f8431733f", "codex/citysim-world-art-east", "/Users/James/.codex/worktrees/92c2/city-sim", "docs/production/claims/PLAY-091.world-art-east.md"),
    "south": ("PLAY-092", "019fab72-b2c9-7d60-a397-27f4fde85950", "codex/citysim-world-art-south", "/Users/James/.codex/worktrees/4247/city-sim", "docs/production/claims/PLAY-092.world-art-south.md"),
    "west": ("PLAY-093", "019fab72-b2c9-7d60-a397-27d01d06cbbd", "codex/citysim-world-art-west", "/Users/James/.codex/worktrees/ef17/city-sim", "docs/production/claims/PLAY-093.world-art-west.md"),
    "renderer": ("PLAY-094", "019f7c8a-69a2-78c2-ae70-fa23ee7bfcd0", "codex/citysim-world-rendering", "/Users/James/.codex/worktrees/cac1/city-sim", "docs/production/claims/PLAY-094.world-rendering.md"),
    "qa": ("PLAY-075", QA_PREREG_THREAD, "codex/citysim-playtest-quality", "/Users/James/.codex/worktrees/71b0/city-sim", "docs/production/claims/PLAY-075.playtest-quality.md"),
}
OWNED_ROOTS = {
    "north": ["Native/CitySimNative/WorldArt/Blender/PLAY-090/residential-l01-variant1-north/", "docs/production/evidence/PLAY-090/"],
    "east": ["Native/CitySimNative/WorldArt/Blender/PLAY-091/residential-l01-variant1-east/", "docs/production/evidence/PLAY-091/"],
    "south": ["Native/CitySimNative/WorldArt/Blender/PLAY-092/residential-l01-variant1-south/", "docs/production/evidence/PLAY-092/"],
    "west": ["Native/CitySimNative/WorldArt/Blender/PLAY-093/residential-l01-variant1-west/", "docs/production/evidence/PLAY-093/"],
    "renderer": ["docs/production/evidence/PLAY-094/"],
    "qa": ["docs/production/evidence/PLAY-075/"],
}
DIRECTION_TRANSITIONS = {
    "predesign": {"predesign", "source_candidate", "returned"},
    "source_candidate": {"source_candidate", "returned", "integration_admitted"},
    "returned": {"returned", "predesign", "source_candidate"},
    "integration_admitted": {"integration_admitted", "returned", "renderer_quarantined"},
    "renderer_quarantined": {"renderer_quarantined", "returned"},
}
RENDERER_TRANSITIONS = {
    "intake_preparing": {"intake_preparing", "intake_ready"},
    "intake_ready": {"intake_ready", "quarantining"},
    "quarantining": {"quarantining", "4of4_assembled"},
    "4of4_assembled": {"4of4_assembled"},
}
QA_TRANSITIONS = {
    "preregistering": {"preregistering", "preregistered"},
    "preregistered": {"preregistered", "exact_candidate_active"},
    "exact_candidate_active": {"exact_candidate_active", "passed", "returned"},
    "returned": {"returned", "preregistering", "exact_candidate_active"},
    "passed": {"passed"},
}
PERMISSION_FIELDS = {
    "zeroPixelPreparation", "prelockProcessA", "productionProcesses",
    "rendererIntake", "atomicAssembly", "qaPreregistration", "finalQA",
    "shippingActivation",
}
TOP_FIELDS = {
    "schema", "batchId", "previousPhase", "phase", "observedAt",
    "authorityCommit", "familyContract", "controlSchema", "dispatchReady",
    "compute", "ledgerProjection", "ledgerSha256", "dispatchProjection",
    "parallelismProof", "finalQAReviewer", "cells", "familyActivation",
}
ROW_FIELDS = {
    "cell", "taskId", "threadId", "branch", "worktree", "head", "observedHead",
    "headStatus", "claim", "previousState", "state", "dispatchState",
    "eligibleUsefulWork", "boundedDeliverable", "stopCondition", "dependency",
    "ownedRoots", "siblingTransformAllowed", "routeRequirement", "routeReceipt",
    "authorityAcknowledgement", "executionAccounting", "permissions",
    "failureIsolation", "featureAuthorThreadId", "observedAt", "cleanState",
}
SHA40 = set("0123456789abcdef")


class ControlError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ControlError(message)


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_constant(value: str) -> None:
    raise ControlError(f"non-finite JSON number: {value}")


def load_json_bytes(payload: bytes, label: str) -> Any:
    try:
        return json.loads(payload.decode("utf-8"), object_pairs_hook=_pairs, parse_constant=_reject_constant)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ControlError(f"{label}: {error}") from error


def canonical_sha(value: Any) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return hashlib.sha256(encoded).hexdigest()


def file_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def is_hex(value: Any, width: int) -> bool:
    return isinstance(value, str) and len(value) == width and set(value) <= SHA40


def repo_path(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty path")
    path = PurePosixPath(value)
    require(not path.is_absolute() and ".." not in path.parts and "." not in path.parts, f"{label} must be repository-relative")
    return value.rstrip("/")


def git(root: Path, *args: str, binary: bool = False) -> bytes | str:
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=not binary)
    if result.returncode:
        stderr = result.stderr.decode(errors="replace") if binary else result.stderr
        raise ControlError(f"git {' '.join(args)} failed: {stderr.strip()}")
    return result.stdout if binary else result.stdout.strip()


def git_blob(root: Path, commit: str, path: str) -> bytes:
    return git(root, "show", f"{commit}:{path}", binary=True)  # type: ignore[return-value]


def is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    result = subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", ancestor, descendant])
    return result.returncode == 0


def parse_time(value: Any, label: str) -> datetime:
    require(isinstance(value, str), f"{label} must be a timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ControlError(f"{label} is not ISO-8601") from error
    require(parsed.tzinfo is not None and parsed.utcoffset() is not None, f"{label} must carry a timezone")
    return parsed


def validate_binding(value: Any, label: str) -> tuple[str, str]:
    require(isinstance(value, dict) and set(value) == {"path", "sha256"}, f"{label} must contain path and sha256")
    path = repo_path(value["path"], f"{label}.path")
    digest = value["sha256"]
    require(is_hex(digest, 64), f"{label}.sha256 is invalid")
    return path, digest


def validate_authority_binding(root: Path, authority: str, value: Any, label: str) -> bytes:
    path, digest = validate_binding(value, label)
    payload = git_blob(root, authority, path)
    require(hashlib.sha256(payload).hexdigest() == digest, f"{label} does not match {authority}:{path}")
    return payload


def validate_working_binding(root: Path, value: Any, label: str) -> None:
    path, digest = validate_binding(value, label)
    resolved = root / path
    require(resolved.is_file() and file_sha(resolved) == digest, f"{label} does not match working bytes")


def required_route(cell: str, phase: str) -> tuple[str, str, str]:
    if cell == "north" and phase in {"contract_pending", "prelock_active", "appearance_lock_pending"}:
        return "FRONTIER_AUTHORITY", "gpt-5.6-sol", "high"
    if cell == "qa" and phase in {"exact_candidate_qa", "integrated"}:
        return "FRONTIER_AUTHORITY", "gpt-5.6-sol", "high"
    if cell == "qa":
        return "LUNA_MECHANICAL", "gpt-5.6-luna", "medium"
    return "LUNA_IMPLEMENTATION", "gpt-5.6-luna", "high"


def run_real_route_validator(route_root: Path, receipt_path: Path, route_id: str) -> None:
    validator = route_root / ".agents/skills/operate-citysim-integration/scripts/validate_model_route_v1.py"
    require(validator.is_file(), "real model-route validator is missing")
    result = subprocess.run(
        [sys.executable, str(validator), "--repo-root", str(route_root), "--dispatch", str(receipt_path), "--dispatch-route-id", route_id],
        capture_output=True,
        text=True,
    )
    require(result.returncode == 0, f"real model-route validator rejected {route_id}: {(result.stdout + result.stderr).strip()}")


RouteRunner = Callable[[Path, Path, str], None]


def validate_route_receipt(
    binding: Any,
    row: dict[str, Any],
    authority: str,
    route_root: Path,
    *,
    check_repository: bool,
    runner: RouteRunner,
) -> None:
    fields = {"path", "sha256", "routeId", "modelRouteSha256"}
    require(isinstance(binding, dict) and set(binding) == fields, f"{row['cell']}.routeReceipt fields invalid")
    path = repo_path(binding["path"], f"{row['cell']}.routeReceipt.path")
    require(is_hex(binding["sha256"], 64) and is_hex(binding["modelRouteSha256"], 64), f"{row['cell']}.routeReceipt hashes invalid")
    receipt_path = route_root / path
    require(receipt_path.is_file(), f"{row['cell']}.routeReceipt path missing")
    working_payload = receipt_path.read_bytes()
    require(hashlib.sha256(working_payload).hexdigest() == binding["sha256"], f"{row['cell']}.routeReceipt file hash mismatch")
    if check_repository:
        committed = git_blob(route_root, authority, path)
        require(committed == working_payload, f"{row['cell']}.routeReceipt is not the declared authority blob")
    receipt = load_json_bytes(working_payload, path)
    require(isinstance(receipt, dict) and receipt.get("schema") == 2 and receipt.get("authorityCommit") == authority, f"{row['cell']}.routeReceipt is not schema-2 authority")
    assignments = receipt.get("assignments")
    require(isinstance(assignments, list), f"{row['cell']}.routeReceipt assignments missing")
    matches = [item for item in assignments if isinstance(item, dict) and isinstance(item.get("modelRoute"), dict) and item["modelRoute"].get("routeId") == binding["routeId"]]
    require(len(matches) == 1, f"{row['cell']}.routeReceipt routeId must resolve exactly once")
    assignment = matches[0]
    route = assignment["modelRoute"]
    require(assignment.get("modelRouteSha256") == binding["modelRouteSha256"] == canonical_sha(route), f"{row['cell']}.routeReceipt canonical route hash mismatch")
    requirement = row["routeRequirement"]
    require((route.get("classification"), route.get("model"), route.get("effort")) == (requirement["classification"], requirement["model"], requirement["effort"]), f"{row['cell']}.routeReceipt tier mismatch")
    require(route.get("taskId") == row["taskId"], f"{row['cell']}.routeReceipt task mismatch")
    route_assignment = route.get("assignment")
    require(isinstance(route_assignment, dict), f"{row['cell']}.routeReceipt assignment missing")
    require((route_assignment.get("threadId"), route_assignment.get("branch"), route_assignment.get("worktree"), route_assignment.get("expectedHead")) == (row["threadId"], row["branch"], row["worktree"], row["head"]), f"{row['cell']}.routeReceipt worker binding mismatch")
    route_authority = route.get("authority")
    require(isinstance(route_authority, dict) and route_authority.get("authorityCommit") == authority, f"{row['cell']}.routeReceipt authority mismatch")
    runner(route_root, receipt_path, binding["routeId"])


def permission_projection(cell: str, phase: str) -> dict[str, bool]:
    result = {field: False for field in PERMISSION_FIELDS}
    if phase in {"prelock_active", "appearance_lock_pending"}:
        if cell == "north":
            result["prelockProcessA"] = True
        elif cell in {"east", "south", "west"}:
            result["zeroPixelPreparation"] = True
        elif cell == "renderer":
            result["rendererIntake"] = True
        elif cell == "qa":
            result["qaPreregistration"] = True
    elif phase == "abc_active":
        if cell in DIRECTIONS:
            result["productionProcesses"] = True
        elif cell == "renderer":
            result["rendererIntake"] = True
        elif cell == "qa":
            result["qaPreregistration"] = True
    elif phase == "4of4_ready" and cell == "renderer":
        result["atomicAssembly"] = True
    elif phase == "exact_candidate_qa" and cell == "qa":
        result["finalQA"] = True
    return result


def validate_execution(row: dict[str, Any], batch: str, authority: str, observed: datetime) -> dict[str, dict[str, Any]]:
    value = row["executionAccounting"]
    fields = {"readyNow", "running", "waitingOnJoin", "serializedAuthority", "nextRefill", "capacity", "launchedJobs", "unusedCapacityReasons", "overlap", "join"}
    require(isinstance(value, dict) and set(value) == fields, f"{row['cell']}.executionAccounting fields invalid")
    for name in ("readyNow", "running", "waitingOnJoin", "nextRefill", "launchedJobs", "unusedCapacityReasons"):
        require(isinstance(value[name], list), f"{row['cell']}.{name} must be a list")
    serial = value["serializedAuthority"]
    require(isinstance(serial, dict) and set(serial) == {"threadId", "branch", "worktree", "gitIndexWriter", "governedEvidenceWriter"}, f"{row['cell']}.serializedAuthority fields invalid")
    require((serial["threadId"], serial["branch"], serial["worktree"], serial["gitIndexWriter"], serial["governedEvidenceWriter"]) == (row["threadId"], row["branch"], row["worktree"], row["threadId"], row["threadId"]), f"{row['cell']}.serializedAuthority mismatch")
    capacity = value["capacity"]
    require(isinstance(capacity, dict) and set(capacity) == {"helperSlots", "dccSlots"}, f"{row['cell']}.capacity fields invalid")
    require(all(isinstance(capacity[key], int) and capacity[key] >= 0 for key in capacity), f"{row['cell']}.capacity invalid")
    jobs: dict[str, dict[str, Any]] = {}
    job_fields = {"id", "batchId", "claimSha256", "publishedBase", "head", "threadId", "branch", "worktree", "resourceClass", "mutationClass", "exclusiveRoot", "processSlot", "state", "startedAt", "endedAt", "evidenceId"}
    for job in value["launchedJobs"]:
        require(isinstance(job, dict) and set(job) == job_fields, f"{row['cell']} launched job fields invalid")
        job_id = job["id"]
        require(isinstance(job_id, str) and job_id and job_id not in jobs, f"{row['cell']} launched job ID invalid")
        execution_head = row["observedHead"] or row["head"]
        require((job["batchId"], job["claimSha256"], job["publishedBase"], job["head"], job["threadId"], job["branch"], job["worktree"]) == (batch, row["claim"]["sha256"], authority, execution_head, row["threadId"], row["branch"], row["worktree"]), f"{row['cell']} launched job identity mismatch")
        require(job["resourceClass"] in {"helper", "dcc"} and job["mutationClass"] in {"read_only", "isolated_temp", "claim_owned"}, f"{row['cell']} launched job class invalid")
        root = repo_path(job["exclusiveRoot"], f"{row['cell']} launched job root")
        if job["mutationClass"] == "claim_owned":
            require(any(root == owned.rstrip("/") or root.startswith(owned) for owned in row["ownedRoots"]), f"{row['cell']} launched job root is outside claim")
        require((job["resourceClass"] == "dcc") == isinstance(job["processSlot"], str), f"{row['cell']} launched job processSlot mismatch")
        require(job["state"] in {"running", "completed"}, f"{row['cell']} launched job state invalid")
        started = parse_time(job["startedAt"], f"{row['cell']}.{job_id}.startedAt")
        ended = None if job["endedAt"] is None else parse_time(job["endedAt"], f"{row['cell']}.{job_id}.endedAt")
        require(started <= observed and (ended is None or (started < ended <= observed)), f"{row['cell']} launched job interval invalid")
        require((job["state"] == "running") == (ended is None), f"{row['cell']} launched job state/time mismatch")
        require(isinstance(job["evidenceId"], str) and row["threadId"] in job["evidenceId"], f"{row['cell']} launched job evidence is not thread-bound")
        jobs[job_id] = job
    running = value["running"]
    waiting = value["waitingOnJoin"]
    require(len(running) == len(set(running)) and all(job_id in jobs and jobs[job_id]["state"] == "running" for job_id in running), f"{row['cell']}.running contains unknown jobs")
    require(len(waiting) == len(set(waiting)) and all(job_id in jobs for job_id in waiting), f"{row['cell']}.waitingOnJoin contains unknown jobs")
    active_counts = {kind: sum(1 for job_id in running if jobs[job_id]["resourceClass"] == kind) for kind in ("helper", "dcc")}
    unused = value["unusedCapacityReasons"]
    unused_fields = {"resourceClass", "slot", "reason"}
    for item in unused:
        require(isinstance(item, dict) and set(item) == unused_fields and item["resourceClass"] in {"helper", "dcc"} and isinstance(item["slot"], int) and item["slot"] >= 0 and isinstance(item["reason"], str) and item["reason"].strip(), f"{row['cell']} unused-capacity reason invalid")
    for kind, key in (("helper", "helperSlots"), ("dcc", "dccSlots")):
        require(active_counts[kind] <= capacity[key], f"{row['cell']} exceeds {kind} capacity")
        require(sum(1 for item in unused if item["resourceClass"] == kind) == capacity[key] - active_counts[kind], f"{row['cell']} has unexplained {kind} capacity")
    overlap = value["overlap"]
    require(isinstance(overlap, dict) and set(overlap) == {"status", "jobIds", "startedAt", "endedAt", "reason"}, f"{row['cell']}.overlap fields invalid")
    require(overlap["status"] in {"not_observed", "observed"}, f"{row['cell']}.overlap status invalid")
    if overlap["status"] == "observed":
        ids = overlap["jobIds"]
        require(isinstance(ids, list) and len(ids) >= 2 and len(ids) == len(set(ids)) and all(job_id in jobs and jobs[job_id]["endedAt"] is not None for job_id in ids), f"{row['cell']}.overlap jobs invalid")
        starts = [parse_time(jobs[job_id]["startedAt"], "job.startedAt") for job_id in ids]
        ends = [parse_time(jobs[job_id]["endedAt"], "job.endedAt") for job_id in ids]
        require(parse_time(overlap["startedAt"], "overlap.startedAt") == max(starts) and parse_time(overlap["endedAt"], "overlap.endedAt") == min(ends) and max(starts) < min(ends), f"{row['cell']}.overlap is fabricated")
    else:
        require(overlap["jobIds"] == [] and overlap["startedAt"] is None and overlap["endedAt"] is None and isinstance(overlap["reason"], str) and overlap["reason"].strip(), f"{row['cell']}.overlap absence invalid")
    join = value["join"]
    require(isinstance(join, dict) and set(join) == {"state", "requiredJobs", "completedJobs"}, f"{row['cell']}.join fields invalid")
    require(join["state"] in {"not_required", "waiting", "complete"} and join["requiredJobs"] == waiting and set(join["completedJobs"]) <= set(waiting), f"{row['cell']}.join does not match waitingOnJoin")
    return jobs


def validate_schedule(
    data: Any,
    root: Path,
    *,
    check_live: bool = True,
    check_repository: bool = True,
    route_root: Path | None = None,
    route_runner: RouteRunner = run_real_route_validator,
) -> dict[str, Any]:
    require(isinstance(data, dict) and set(data) == TOP_FIELDS, "top-level fields do not match schema-2 controls")
    require(data["schema"] == 2 and data["batchId"] == BATCH, "wrong schema or batch")
    previous_phase, phase = data["previousPhase"], data["phase"]
    require(previous_phase in PHASE_NEXT and phase in PHASE_NEXT[previous_phase], "illegal batch phase transition")
    observed = parse_time(data["observedAt"], "observedAt")
    authority = data["authorityCommit"]
    require(authority == AUTHORITY and is_hex(authority, 40), "authorityCommit mismatch")
    if check_repository:
        git(root, "cat-file", "-e", f"{authority}^{{commit}}")
        contract = validate_authority_binding(root, authority, data["familyContract"], "familyContract").decode()
        require("CONTRACT-023" in contract and "No partial fallback" in contract and "Integration alone owns" in contract, "familyContract authority semantics mismatch")
        validate_working_binding(root, data["controlSchema"], "controlSchema")
    else:
        validate_binding(data["familyContract"], "familyContract")
        validate_binding(data["controlSchema"], "controlSchema")
    require(isinstance(data["dispatchReady"], bool), "dispatchReady must be boolean")

    final_reviewer = data["finalQAReviewer"]
    require(isinstance(final_reviewer, dict) and set(final_reviewer) == {"threadId", "classification", "model", "effort", "distinctFromQaPreregistration"}, "finalQAReviewer fields invalid")
    require((final_reviewer["threadId"], final_reviewer["classification"], final_reviewer["model"], final_reviewer["effort"], final_reviewer["distinctFromQaPreregistration"]) == (FINAL_QA_REVIEWER, "FRONTIER_AUTHORITY", "gpt-5.6-sol", "high", True), "finalQAReviewer binding mismatch")
    require(final_reviewer["threadId"] != QA_PREREG_THREAD, "final QA reviewer must be distinct from QA preregistration")

    rows = data["cells"]
    require(isinstance(rows, list) and len(rows) == 6 and [row.get("cell") for row in rows if isinstance(row, dict)] == list(CELLS), "cells must be exact and ordered")
    by_cell: dict[str, dict[str, Any]] = {}
    all_roots: list[tuple[str, str]] = []
    all_jobs: dict[tuple[str, str], dict[str, Any]] = {}
    route_root = route_root or root
    for row in rows:
        require(isinstance(row, dict) and set(row) == ROW_FIELDS, "cell row fields invalid")
        cell = row["cell"]
        require(cell not in by_cell, "duplicate cell")
        by_cell[cell] = row
        task, thread, branch, worktree, claim_path = EXPECTED[cell]
        require((row["taskId"], row["threadId"], row["branch"], row["worktree"], row["claim"]["path"]) == (task, thread, branch, worktree, claim_path), f"{cell} identity binding mismatch")
        require(row["ownedRoots"] == OWNED_ROOTS[cell], f"{cell} owned roots mismatch")
        for owned in row["ownedRoots"]:
            normalized = repo_path(owned, f"{cell}.ownedRoots")
            for other_cell, other in all_roots:
                require(not (normalized == other or normalized.startswith(other + "/") or other.startswith(normalized + "/")), f"owned root overlap: {cell}/{other_cell}")
            all_roots.append((cell, normalized))
        _, claim_sha = validate_binding(row["claim"], f"{cell}.claim")
        if check_repository:
            claim_text = validate_authority_binding(root, authority, row["claim"], f"{cell}.claim").decode()
            require(f"# {task} Claim" in claim_text and f"`{branch}`" in claim_text and worktree in claim_text and all(owned in claim_text for owned in OWNED_ROOTS[cell]), f"{cell} claim semantics mismatch")
            git(root, "cat-file", "-e", f"{row['head']}^{{commit}}")
            current = is_ancestor(root, authority, row["head"])
        else:
            current = row["headStatus"] == "current"
        observed_head = row["observedHead"]
        require(observed_head is None or is_hex(observed_head, 40), f"{cell}.observedHead is invalid")
        if observed_head is not None:
            require(is_ancestor(root, observed_head, row["head"]) if check_repository else True, f"{cell}.observedHead is not an ancestor of head")
            if check_repository:
                changed = git(root, "diff", "--name-only", f"{observed_head}..{row['head']}").splitlines()
                evidence_root = f"docs/production/evidence/{task}/"
                require(changed and all(path.startswith(evidence_root) for path in changed), f"{cell}.observedHead intervening diff escapes evidence root")
        require(row["headStatus"] == ("current" if current else "stale_pre_authority"), f"{cell} headStatus mismatch")
        require(row["cleanState"] == "clean", f"{cell} is not clean")
        require(parse_time(row["observedAt"], f"{cell}.observedAt") <= observed, f"{cell}.observedAt is in the future")
        if check_live:
            live = Path(worktree)
            require(live.is_dir(), f"{cell} worktree missing")
            require(git(live, "branch", "--show-current") == branch and git(live, "rev-parse", "HEAD") == row["head"], f"{cell} live identity mismatch")
            require(git(live, "status", "--porcelain=v1") == "", f"{cell} live worktree is dirty")
        transitions = DIRECTION_TRANSITIONS if cell in DIRECTIONS else RENDERER_TRANSITIONS if cell == "renderer" else QA_TRANSITIONS
        require(row["previousState"] in transitions and row["state"] in transitions[row["previousState"]], f"{cell} illegal state transition")
        require(row["siblingTransformAllowed"] is False and row["failureIsolation"] is True, f"{cell} isolation controls invalid")
        require(isinstance(row["boundedDeliverable"], str) and row["boundedDeliverable"].strip() and isinstance(row["stopCondition"], str) and row["stopCondition"].strip(), f"{cell} bounded work fields invalid")
        dependency = row["dependency"]
        require(isinstance(dependency, dict) and set(dependency) == {"status", "ownerThreadId", "resumptionEvent", "unavailablePreparation", "nextRefill"}, f"{cell} dependency fields invalid")
        require(dependency["status"] in {"ready", "blocked", "waiting"} and all(isinstance(dependency[key], str) and dependency[key].strip() for key in dependency if key != "status"), f"{cell} dependency invalid")
        requirement = row["routeRequirement"]
        require(isinstance(requirement, dict) and set(requirement) == {"classification", "model", "effort", "escalationTriggers"}, f"{cell} routeRequirement fields invalid")
        require((requirement["classification"], requirement["model"], requirement["effort"]) == required_route(cell, phase), f"{cell} routeRequirement tier mismatch")
        require(isinstance(requirement["escalationTriggers"], list) and len(requirement["escalationTriggers"]) == len(ESCALATIONS) and set(requirement["escalationTriggers"]) == ESCALATIONS, f"{cell} escalation triggers invalid")
        dispatch_bound = row["eligibleUsefulWork"] or row["dispatchState"] in {"acknowledged", "working", "returned", "completed"}
        if dispatch_bound:
            require(current, f"{cell} valid but stale head cannot be dispatchable")
            require(row["dispatchState"] in {"acknowledged", "working", "returned", "completed"}, f"{cell} eligible work is not acknowledged")
            require(row["routeReceipt"] is not None, f"{cell} dispatchable row lacks a real route receipt")
            validate_route_receipt(row["routeReceipt"], row, authority, route_root, check_repository=check_repository, runner=route_runner)
            ack = row["authorityAcknowledgement"]
            ack_fields = {"threadId", "authorityCommit", "claimRevision", "acknowledgedAt", "boundedDeliverable", "stopCondition", "evidenceId"}
            require(isinstance(ack, dict) and set(ack) == ack_fields, f"{cell} acknowledgement fields invalid")
            require((ack["threadId"], ack["authorityCommit"], ack["claimRevision"], ack["boundedDeliverable"], ack["stopCondition"]) == (thread, authority, claim_sha, row["boundedDeliverable"], row["stopCondition"]), f"{cell} acknowledgement mismatch")
            require(parse_time(ack["acknowledgedAt"], f"{cell}.acknowledgedAt") <= observed, f"{cell} acknowledgement is in the future")
            require(isinstance(ack["evidenceId"], str) and thread in ack["evidenceId"], f"{cell} acknowledgement evidence mismatch")
        else:
            require(row["routeReceipt"] is None and row["authorityAcknowledgement"] is None, f"{cell} non-dispatch row carries route or acknowledgement authority")
        require(row["permissions"] == permission_projection(cell, phase), f"{cell} permissions do not match phase")
        require(row["permissions"]["shippingActivation"] is False, f"{cell} cannot grant shipping activation")
        require(row["featureAuthorThreadId"] == (None if cell == "qa" else thread), f"{cell} feature-author binding mismatch")
        jobs = validate_execution(row, BATCH, authority, observed)
        for job_id, job in jobs.items():
            all_jobs[(cell, job_id)] = job
        if not dispatch_bound:
            require(not jobs and not row["executionAccounting"]["running"], f"{cell} blocked row cannot claim jobs")

    for cell in DIRECTIONS:
        row = by_cell[cell]
        if row["state"] == "returned" and row["previousState"] != "returned":
            for sibling in DIRECTIONS:
                if sibling != cell:
                    require(by_cell[sibling]["state"] in DIRECTION_TRANSITIONS[by_cell[sibling]["previousState"]] and by_cell[sibling]["state"] != "returned", f"{cell} return demotes sibling {sibling}")

    activation = data["familyActivation"]
    activation_fields = {"state", "requiredDirections", "admittedDirections", "quarantinedDirections", "atomicAssemblyManifest", "rendererCandidateReceipt", "qaResult", "partialActivationAllowed", "variantZeroFallbackAllowed"}
    require(isinstance(activation, dict) and set(activation) == activation_fields, "familyActivation fields invalid")
    require(activation["requiredDirections"] == list(DIRECTIONS) and activation["partialActivationAllowed"] is False and activation["variantZeroFallbackAllowed"] is False, "family activation invariant invalid")
    admitted, quarantined = activation["admittedDirections"], activation["quarantinedDirections"]
    require(isinstance(admitted, list) and isinstance(quarantined, list) and len(admitted) == len(set(admitted)) and len(quarantined) == len(set(quarantined)) and set(quarantined) <= set(admitted) <= set(DIRECTIONS), "family admission projection invalid")
    exact_four = set(admitted) == set(quarantined) == set(DIRECTIONS) and all(by_cell[cell]["state"] == "renderer_quarantined" for cell in DIRECTIONS)
    if phase in {"contract_pending", "prelock_active", "appearance_lock_pending", "abc_active"}:
        require(activation["state"] == "blocked_until_4_of_4" and activation["atomicAssemblyManifest"] is None and activation["rendererCandidateReceipt"] is None and activation["qaResult"] is None, "pre-4of4 activation must remain blocked")
    elif phase == "4of4_ready":
        require(exact_four and activation["state"] == "ready_for_atomic_activation" and activation["atomicAssemblyManifest"] is not None and activation["rendererCandidateReceipt"] is None, "4of4_ready requires exact atomic four-direction input")
    elif phase == "exact_candidate_qa":
        require(exact_four and by_cell["renderer"]["state"] == "4of4_assembled" and by_cell["qa"]["state"] == "exact_candidate_active" and activation["state"] == "exact_candidate_active" and activation["rendererCandidateReceipt"] is not None, "exact-candidate QA requires atomic 4of4 assembly")
    else:
        require(exact_four and by_cell["qa"]["state"] == "passed" and activation["state"] == "integrated" and activation["qaResult"] is not None, "integrated phase requires exact QA result")
    for name in ("atomicAssemblyManifest", "rendererCandidateReceipt", "qaResult"):
        if activation[name] is not None:
            if check_repository:
                validate_authority_binding(root, authority, activation[name], f"familyActivation.{name}")
            else:
                validate_binding(activation[name], f"familyActivation.{name}")

    compute = data["compute"]
    compute_fields = {"maxSimultaneousDccProcesses", "assignedSlots", "queue", "machineAssumptions", "prohibitedWork", "exceptionOwnerThreadId"}
    require(isinstance(compute, dict) and set(compute) == compute_fields, "compute fields invalid")
    require(isinstance(compute["maxSimultaneousDccProcesses"], int) and compute["maxSimultaneousDccProcesses"] >= 0 and isinstance(compute["assignedSlots"], list) and len(compute["assignedSlots"]) <= compute["maxSimultaneousDccProcesses"], "compute DCC cap invalid")
    require(isinstance(compute["queue"], list) and isinstance(compute["machineAssumptions"], list) and compute["machineAssumptions"] and isinstance(compute["prohibitedWork"], list) and compute["prohibitedWork"] and compute["exceptionOwnerThreadId"] == FINAL_QA_REVIEWER, "compute envelope incomplete")
    assigned = {(item.get("cell"), item.get("jobId"), item.get("slot")) for item in compute["assignedSlots"] if isinstance(item, dict) and set(item) == {"cell", "jobId", "slot"}}
    require(len(assigned) == len(compute["assignedSlots"]), "compute assigned slots invalid or duplicated")
    for (cell, job_id), job in all_jobs.items():
        if job["resourceClass"] == "dcc":
            require((cell, job_id, job["processSlot"]) in assigned, "DCC job lacks exact compute slot")

    eligible = [cell for cell in CELLS if by_cell[cell]["eligibleUsefulWork"]]
    proof = data["parallelismProof"]
    proof_fields = {"requiredConcurrentCells", "eligibleCells", "jobRefs", "startedAt", "endedAt"}
    require(isinstance(proof, dict) and set(proof) == proof_fields and proof["eligibleCells"] == eligible and proof["requiredConcurrentCells"] == min(3, len(eligible)), "parallelismProof eligibility mismatch")
    refs = proof["jobRefs"]
    require(isinstance(refs, list), "parallelismProof.jobRefs must be a list")
    if proof["requiredConcurrentCells"]:
        require(len(refs) >= proof["requiredConcurrentCells"], "parallelismProof lacks required cells")
        keys = []
        for ref in refs:
            require(isinstance(ref, dict) and set(ref) == {"cell", "jobId"}, "parallelismProof jobRef invalid")
            key = (ref["cell"], ref["jobId"])
            require(key in all_jobs and all_jobs[key]["endedAt"] is not None, "parallelismProof references unknown or unfinished job")
            keys.append(key)
        require(len({cell for cell, _ in keys}) == len(keys), "parallelismProof must use distinct canonical cells")
        starts = [parse_time(all_jobs[key]["startedAt"], "parallelism job start") for key in keys]
        ends = [parse_time(all_jobs[key]["endedAt"], "parallelism job end") for key in keys]
        require(parse_time(proof["startedAt"], "parallelismProof.startedAt") == max(starts) and parse_time(proof["endedAt"], "parallelismProof.endedAt") == min(ends) and max(starts) < min(ends) <= observed, "parallelismProof interval is fabricated")
    else:
        require(refs == [] and proof["startedAt"] is None and proof["endedAt"] is None, "zero-eligibility proof must be empty")
    require(data["dispatchReady"] == (phase != "contract_pending" and len(eligible) >= min(3, len(eligible)) and bool(eligible)), "dispatchReady does not match executable eligibility")

    ledger_rows = [
        {key: row[key] for key in ("cell", "taskId", "threadId", "head", "state", "dispatchState", "cleanState", "observedAt")} | {"claimRevision": row["claim"]["sha256"]}
        for row in rows
    ]
    expected_projection = {"batchId": BATCH, "phase": phase, "rows": ledger_rows}
    require(data["ledgerProjection"] == expected_projection and data["dispatchProjection"] == expected_projection, "ledger/dispatch row projection mismatch")
    require(is_hex(data["ledgerSha256"], 64) and data["ledgerSha256"] == canonical_sha(expected_projection), "ledgerSha256 mismatch")
    return {"result": "PASS", "batchId": BATCH, "phase": phase, "dispatchReady": data["dispatchReady"], "eligibleCells": eligible, "ledgerSha256": data["ledgerSha256"]}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("schedule")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--route-root")
    args = parser.parse_args()
    root = Path(args.repo_root).resolve()
    try:
        payload = Path(args.schedule).read_bytes()
        result = validate_schedule(load_json_bytes(payload, args.schedule), root, route_root=Path(args.route_root).resolve() if args.route_root else None)
    except (OSError, ControlError) as error:
        print(json.dumps({"result": "FAIL", "reason": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
