#!/usr/bin/env python3
"""Validate CitySim model-route packets and their dispatch projection."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any


ROUTE_FIELDS = {
    "schema", "routeId", "taskId", "packetKind", "classification", "model",
    "effort", "rationale", "authority", "assignment", "pathPolicy",
    "boundedDeliverable", "validation", "expectedResult", "escalationTriggers",
    "stopCondition", "independentReviewer", "context", "proofPolicy",
}
ROUTE_SCHEMA = 2
DISPATCH_SCHEMA = 2
ROUTES = {
    "FRONTIER_AUTHORITY": ("gpt-5.6-sol", "high"),
    "LUNA_IMPLEMENTATION": ("gpt-5.6-luna", "high"),
    "LUNA_MECHANICAL": ("gpt-5.6-luna", "medium"),
    "LUNA_LOCAL_DEBUG": ("gpt-5.6-luna", "max"),
}
PACKET_ROUTE = {
    "authority": "FRONTIER_AUTHORITY",
    "implementation": "LUNA_IMPLEMENTATION",
    "mechanical": "LUNA_MECHANICAL",
    "local_debug": "LUNA_LOCAL_DEBUG",
    "acceptance": "FRONTIER_AUTHORITY",
}
TRIGGERS = {
    "shared_contract_or_schema_decision",
    "unresolved_product_visual_or_interaction_judgment",
    "path_outside_claim",
    "baseline_or_candidate_identity_mismatch",
    "failure_outside_focused_scope",
    "save_or_migration_uncertainty",
    "cross_lane_semantic_conflict",
    "two_unsuccessful_repair_attempts",
    "subjective_acceptance_required",
}
FULL_GATE_MARKERS = (
    "swift test --package-path Native/CitySimNative",
    "build_and_run.sh --verify",
    "fresh-player real-app",
    "final real-app",
)
LUNA_PROTECTED_ROOTS = (
    ".agents/skills",
    "docs/production/PLAYABLE_BACKLOG.md",
    "docs/production/claims",
    "docs/production/decisions",
    "docs/production/evidence/INTEGRATION",
    "Native/CitySimNative/Package.swift",
    "script/build_and_run.sh",
)
STATE_RANK = {
    "predesign": 0, "returned": 0, "source_candidate": 1,
    "integration_admitted": 2, "renderer_quarantined": 3,
    "intake_ready": 1, "assembly_candidate": 2,
    "preregistering": 0, "preregistered": 1, "candidate_ready": 2,
    "approved": 3,
}
PROOF_LEVEL_RANK = {
    "static_only": 0,
    "contained_smoke": 1,
    "deterministic_replay": 2,
    "real_app_journey": 3,
}
DELIVERABLE_CLAIMS = {
    "static_structure",
    "executable_behavior",
    "deterministic_output",
    "visual_quality",
    "real_app_interaction",
}
FOCUSED_CLAIM_MINIMUM = {
    "static_structure": "static_only",
    "executable_behavior": "contained_smoke",
    "deterministic_output": "deterministic_replay",
}
PROHIBITED_EVIDENCE_SUBSTITUTIONS = {
    "source_token_presence_for_execution",
    "ast_shape_for_runtime_success",
    "manifest_or_prose_for_rendered_pixels",
    "unit_tests_for_visual_acceptance",
    "worker_self_report_for_independent_acceptance",
}


class ValidationError(Exception):
    pass


def _reject_constant(value: str) -> None:
    raise ValidationError(f"non-finite JSON number is forbidden: {value}")


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise ValidationError(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def load_json(path: Path) -> Any:
    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_pairs,
            parse_constant=_reject_constant,
        )
    except (OSError, UnicodeError, json.JSONDecodeError, ValidationError) as exc:
        raise ValidationError(f"{path}: {exc}") from exc


def canonical_sha(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def file_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, text=True
    )
    if result.returncode:
        raise ValidationError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def _is_hex(value: Any, width: int) -> bool:
    return isinstance(value, str) and len(value) == width and all(c in "0123456789abcdef" for c in value)


def _repo_path(value: Any, label: str, errors: list[str]) -> str | None:
    if not isinstance(value, str) or not value:
        errors.append(f"{label} must be a non-empty repository-relative path")
        return None
    p = PurePosixPath(value)
    if p.is_absolute() or ".." in p.parts or "." in p.parts or any(ch in value for ch in "*?[]"):
        errors.append(f"{label} is not an exact normalized repository path: {value!r}")
        return None
    return value.rstrip("/")


def _within(path: str, root: str) -> bool:
    return path == root or path.startswith(root + "/")


def _check_binding(repo: Path, binding: Any, label: str, errors: list[str]) -> None:
    if not isinstance(binding, dict) or set(binding) != {"path", "sha256"}:
        errors.append(f"{label} must contain exactly path and sha256")
        return
    rel = _repo_path(binding.get("path"), f"{label}.path", errors)
    digest = binding.get("sha256")
    if not _is_hex(digest, 64):
        errors.append(f"{label}.sha256 must be 64 lowercase hex characters")
    if rel is None:
        return
    resolved = repo / rel
    if not resolved.is_file():
        errors.append(f"{label}.path does not resolve to a file: {rel}")
    elif _is_hex(digest, 64) and file_sha(resolved) != digest:
        errors.append(f"{label}.sha256 does not match repository bytes: {rel}")


def validate_route(route: Any, repo: Path) -> list[str]:
    errors: list[str] = []
    if not isinstance(route, dict):
        return ["route packet must be a JSON object"]
    missing, extra = ROUTE_FIELDS - set(route), set(route) - ROUTE_FIELDS
    if missing:
        errors.append(f"missing route fields: {sorted(missing)}")
    if extra:
        errors.append(f"unsupported route fields: {sorted(extra)}")
    if errors:
        return errors

    if route["schema"] != ROUTE_SCHEMA:
        errors.append(f"schema must equal {ROUTE_SCHEMA}")
    if not isinstance(route["routeId"], str) or not route["routeId"]:
        errors.append("routeId must be non-empty")
    if not isinstance(route["taskId"], str) or not route["taskId"].startswith("PLAY-"):
        errors.append("taskId must be a PLAY task")
    classification = route["classification"]
    if classification not in ROUTES:
        errors.append(f"unsupported model route: {classification!r}")
    elif (route["model"], route["effort"]) != ROUTES[classification]:
        errors.append(f"{classification} requires model/effort {ROUTES[classification]}")
    expected_class = PACKET_ROUTE.get(route["packetKind"])
    if expected_class is None:
        errors.append(f"unsupported packetKind: {route['packetKind']!r}")
    elif classification != expected_class:
        errors.append(f"packetKind {route['packetKind']} requires {expected_class}")
    if not isinstance(route["rationale"], str) or not route["rationale"].strip():
        errors.append("rationale must be non-empty")
    if not isinstance(route["boundedDeliverable"], str) or not route["boundedDeliverable"].strip():
        errors.append("boundedDeliverable must be non-empty")
    if not isinstance(route["stopCondition"], str) or not route["stopCondition"].strip():
        errors.append("stopCondition must be non-empty")
    triggers = route["escalationTriggers"]
    if not isinstance(triggers, list) or len(triggers) != len(set(triggers)) or set(triggers) != TRIGGERS:
        errors.append("escalationTriggers must contain the exact mandatory set")

    proof = route["proofPolicy"]
    proof_fields = {
        "architectureState", "referenceImplementation", "deliverableClaims",
        "focusedProofLevel", "fullProofLevel", "behavioralCommands",
        "prohibitedSubstitutions",
    }
    if not isinstance(proof, dict) or set(proof) != proof_fields:
        errors.append("proofPolicy has unsupported or missing fields")
        proof = {}
    architecture_state = proof.get("architectureState")
    if architecture_state not in ("frozen_reference", "novel_or_ambiguous"):
        errors.append("proofPolicy.architectureState is unsupported")
    reference = proof.get("referenceImplementation")
    if architecture_state == "frozen_reference":
        if reference is None:
            errors.append("frozen_reference requires an exact referenceImplementation binding")
        else:
            _check_binding(repo, reference, "proofPolicy.referenceImplementation", errors)
    elif architecture_state == "novel_or_ambiguous":
        if reference is not None:
            errors.append("novel_or_ambiguous must not pretend to have a frozen reference")
        if isinstance(classification, str) and classification.startswith("LUNA_"):
            errors.append("Luna cannot own novel or ambiguous architecture")
    claims = proof.get("deliverableClaims")
    if (
        not isinstance(claims, list)
        or not claims
        or len(claims) != len(set(claims))
        or not set(claims).issubset(DELIVERABLE_CLAIMS)
    ):
        errors.append("proofPolicy.deliverableClaims contains unsupported or duplicate claims")
        claims = []
    focused_level = proof.get("focusedProofLevel")
    full_level = proof.get("fullProofLevel")
    if focused_level not in PROOF_LEVEL_RANK:
        errors.append("proofPolicy.focusedProofLevel is unsupported")
    if full_level not in PROOF_LEVEL_RANK:
        errors.append("proofPolicy.fullProofLevel is unsupported")
    if focused_level in PROOF_LEVEL_RANK and full_level in PROOF_LEVEL_RANK:
        if PROOF_LEVEL_RANK[full_level] < PROOF_LEVEL_RANK[focused_level]:
            errors.append("full proof level cannot be weaker than focused proof level")
        for claim in claims:
            minimum = FOCUSED_CLAIM_MINIMUM.get(claim)
            if minimum and PROOF_LEVEL_RANK[focused_level] < PROOF_LEVEL_RANK[minimum]:
                errors.append(
                    f"claim {claim} requires focused proof level {minimum} or stronger"
                )
        if any(claim in ("visual_quality", "real_app_interaction") for claim in claims):
            if full_level != "real_app_journey":
                errors.append("visual or interaction claims require a frontier real_app_journey full proof")
    behavioral_commands = proof.get("behavioralCommands")
    if not isinstance(behavioral_commands, list) or not all(
        isinstance(command, str) and command for command in behavioral_commands
    ):
        errors.append("proofPolicy.behavioralCommands must be a string list")
        behavioral_commands = []
    if focused_level == "static_only" and behavioral_commands:
        errors.append("static-only proof cannot declare behavioral commands")
    if focused_level in PROOF_LEVEL_RANK and PROOF_LEVEL_RANK[focused_level] >= PROOF_LEVEL_RANK["contained_smoke"] and not behavioral_commands:
        errors.append("behavioral proof level requires at least one behavioral command")
    substitutions = proof.get("prohibitedSubstitutions")
    if (
        not isinstance(substitutions, list)
        or len(substitutions) != len(set(substitutions))
        or set(substitutions) != PROHIBITED_EVIDENCE_SUBSTITUTIONS
    ):
        errors.append("proofPolicy.prohibitedSubstitutions must contain the exact mandatory set")
    if classification == "LUNA_MECHANICAL" and any(
        claim in {"executable_behavior", "visual_quality", "real_app_interaction"}
        for claim in claims
    ):
        errors.append("LUNA_MECHANICAL cannot claim executable, visual, or interaction behavior")

    authority = route["authority"]
    if not isinstance(authority, dict) or set(authority) != {"authorityCommit", "baseCommit", "claim", "immutableInputs"}:
        errors.append("authority has unsupported or missing fields")
    else:
        ac, bc = authority["authorityCommit"], authority["baseCommit"]
        if not _is_hex(ac, 40): errors.append("authorityCommit must be a full lowercase Git SHA")
        if not _is_hex(bc, 40): errors.append("baseCommit must be a full lowercase Git SHA")
        if _is_hex(ac, 40) and _is_hex(bc, 40):
            try:
                _git(repo, "cat-file", "-e", f"{ac}^{{commit}}")
                _git(repo, "cat-file", "-e", f"{bc}^{{commit}}")
                result = subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", bc, ac])
                if result.returncode != 0:
                    errors.append("baseCommit is not an ancestor of authorityCommit")
            except ValidationError as exc:
                errors.append(str(exc))
        _check_binding(repo, authority["claim"], "authority.claim", errors)
        inputs = authority["immutableInputs"]
        if not isinstance(inputs, list) or not inputs:
            errors.append("authority.immutableInputs must be non-empty")
        else:
            for idx, binding in enumerate(inputs):
                _check_binding(repo, binding, f"authority.immutableInputs[{idx}]", errors)

    assignment = route["assignment"]
    assignment_fields = {
        "threadId", "branch", "worktree", "expectedHead", "featureAuthorThreadId",
        "sharedAuthorityOwnership", "finalQAOwnership", "subjectiveJudgmentRequired",
    }
    if not isinstance(assignment, dict) or set(assignment) != assignment_fields:
        errors.append("assignment has unsupported or missing fields")
        assignment = {}
    thread = assignment.get("threadId")
    is_luna = isinstance(classification, str) and classification.startswith("LUNA_")
    if not isinstance(thread, str) or not thread:
        errors.append("assignment.threadId must be non-empty")
    branch = assignment.get("branch")
    worktree = assignment.get("worktree")
    expected_head = assignment.get("expectedHead")
    if not isinstance(branch, str) or not branch:
        errors.append("assignment.branch must be non-empty")
    if not isinstance(worktree, str) or not Path(worktree).is_absolute():
        errors.append("assignment.worktree must be absolute")
    if not _is_hex(expected_head, 40):
        errors.append("assignment.expectedHead must be a full lowercase Git SHA")
    else:
        try:
            _git(repo, "cat-file", "-e", f"{expected_head}^{{commit}}")
            authority_commit = authority.get("authorityCommit") if isinstance(authority, dict) else None
            if _is_hex(authority_commit, 40):
                ancestry = subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", authority_commit, expected_head])
                if ancestry.returncode != 0:
                    errors.append("authorityCommit is not an ancestor of assignment.expectedHead")
        except ValidationError as exc:
            errors.append(str(exc))
    if isinstance(worktree, str) and Path(worktree).is_dir():
        try:
            live_branch = _git(Path(worktree), "branch", "--show-current")
            live_head = _git(Path(worktree), "rev-parse", "HEAD")
            if isinstance(branch, str) and live_branch != branch:
                errors.append(f"assignment branch mismatch: expected {branch}, live {live_branch}")
            if _is_hex(expected_head, 40) and live_head != expected_head:
                errors.append(f"assignment HEAD mismatch: expected {expected_head}, live {live_head}")
        except ValidationError as exc:
            errors.append(str(exc))
    if is_luna and any(assignment.get(key) for key in ("sharedAuthorityOwnership", "finalQAOwnership", "subjectiveJudgmentRequired")):
        errors.append("Luna cannot own shared authority, final QA, or subjective judgment")

    policy = route["pathPolicy"]
    if not isinstance(policy, dict) or set(policy) != {"claimOwnedRoots", "allowed", "forbidden"}:
        errors.append("pathPolicy has unsupported or missing fields")
        policy = {"claimOwnedRoots": [], "allowed": [], "forbidden": []}
    normalized: dict[str, list[str]] = {}
    for key in ("claimOwnedRoots", "allowed", "forbidden"):
        values = policy.get(key)
        normalized[key] = []
        if not isinstance(values, list) or not values:
            errors.append(f"pathPolicy.{key} must be a non-empty list")
            continue
        for idx, value in enumerate(values):
            parsed = _repo_path(value, f"pathPolicy.{key}[{idx}]", errors)
            if parsed is not None:
                normalized[key].append(parsed)
        if len(normalized[key]) != len(set(normalized[key])):
            errors.append(f"pathPolicy.{key} contains duplicates")
    roots, allowed, forbidden = normalized["claimOwnedRoots"], normalized["allowed"], normalized["forbidden"]
    claim_text = ""
    if isinstance(authority, dict) and isinstance(authority.get("claim"), dict):
        rel = authority["claim"].get("path")
        if isinstance(rel, str) and (repo / rel).is_file():
            claim_text = (repo / rel).read_text(encoding="utf-8")
    for root in roots:
        if root not in claim_text:
            errors.append(f"claim does not literally own root: {root}")
    for path in allowed:
        if not any(_within(path, root) for root in roots):
            errors.append(f"allowed path lies outside claim-owned roots: {path}")
        if any(_within(path, blocked) or _within(blocked, path) for blocked in forbidden):
            errors.append(f"allowed and forbidden paths overlap: {path}")
        if is_luna and any(_within(path, protected) or _within(protected, path) for protected in LUNA_PROTECTED_ROOTS):
            errors.append(f"Luna may not mutate a shared-authority root: {path}")

    validation = route["validation"]
    if not isinstance(validation, dict) or set(validation) != {"focusedGateOwner", "focusedCommands", "fullGateOwner", "fullCommands"}:
        errors.append("validation has unsupported or missing fields")
        validation = {}
    focused, full = validation.get("focusedGateOwner", {}), validation.get("fullGateOwner", {})
    if not isinstance(focused, dict) or set(focused) != {"threadId", "role"}:
        errors.append("focusedGateOwner has unsupported or missing fields")
        focused = {}
    if not isinstance(full, dict) or set(full) != {"threadId", "role", "model", "effort"}:
        errors.append("fullGateOwner has unsupported or missing fields")
        full = {}
    if focused.get("role") == full.get("role") or focused.get("threadId") == full.get("threadId"):
        errors.append("focused-gate and full-gate ownership must be distinct")
    if is_luna and focused.get("threadId") != thread:
        errors.append("Luna assignment must own its focused gate")
    if full.get("model") != "gpt-5.6-sol" or full.get("effort") != "high":
        errors.append("full gate must be owned by gpt-5.6-sol high")
    focused_commands = validation.get("focusedCommands")
    full_commands = validation.get("fullCommands")
    if not isinstance(focused_commands, list) or not focused_commands or not all(isinstance(x, str) and x for x in focused_commands):
        errors.append("focusedCommands must be a non-empty string list")
    if not isinstance(full_commands, list) or not full_commands or not all(isinstance(x, str) and x for x in full_commands):
        errors.append("fullCommands must be a non-empty string list")
    if is_luna and isinstance(focused_commands, list):
        for command in focused_commands:
            unfiltered_swift = FULL_GATE_MARKERS[0] in command and "--filter" not in command
            other_full_gate = any(marker in command for marker in FULL_GATE_MARKERS[1:])
            if unfiltered_swift or other_full_gate:
                errors.append(f"Luna focused gate contains aggregate/final command: {command}")
    if isinstance(focused_commands, list):
        for command in behavioral_commands:
            if command not in focused_commands:
                errors.append(
                    f"behavioral command is not an exact focusedCommands entry: {command}"
                )

    result = route["expectedResult"]
    if not isinstance(result, dict) or set(result) != {"evidencePaths", "commitRequired", "commitMessagePattern"}:
        errors.append("expectedResult has unsupported or missing fields")
    else:
        evidence = result["evidencePaths"]
        if not isinstance(evidence, list) or not evidence:
            errors.append("expectedResult.evidencePaths must be non-empty")
        else:
            for idx, value in enumerate(evidence):
                parsed = _repo_path(value, f"expectedResult.evidencePaths[{idx}]", errors)
                if parsed and not any(_within(parsed, root) for root in allowed):
                    errors.append(f"evidence path lies outside allowed paths: {parsed}")
        if not isinstance(result["commitRequired"], bool):
            errors.append("commitRequired must be boolean")
        if not isinstance(result["commitMessagePattern"], str) or not result["commitMessagePattern"]:
            errors.append("commitMessagePattern must be non-empty")

    reviewer = route["independentReviewer"]
    if not isinstance(reviewer, dict) or set(reviewer) != {"required", "threadId", "model", "effort"}:
        errors.append("independentReviewer has unsupported or missing fields")
        reviewer = {}
    if is_luna:
        if reviewer.get("required") is not True or reviewer.get("model") != "gpt-5.6-sol" or reviewer.get("effort") != "high":
            errors.append("every Luna packet requires an independent gpt-5.6-sol high reviewer")
        if reviewer.get("threadId") in (None, thread):
            errors.append("Luna reviewer must be a distinct task")
    if route["packetKind"] == "acceptance":
        author = assignment.get("featureAuthorThreadId")
        if assignment.get("finalQAOwnership") is not True:
            errors.append("acceptance packet must own final QA")
        if not isinstance(author, str) or not author or author == thread:
            errors.append("final QA assignment cannot use the feature-author task")
        if reviewer.get("threadId") != thread or reviewer.get("model") != "gpt-5.6-sol" or reviewer.get("effort") != "high":
            errors.append("acceptance reviewer must be the assigned gpt-5.6-sol high task")
        if not any(claim in ("visual_quality", "real_app_interaction") for claim in claims):
            errors.append("acceptance packet must claim visual quality or real-app interaction")
        if full_level != "real_app_journey":
            errors.append("acceptance packet requires real_app_journey full proof")

    context = route["context"]
    if not isinstance(context, dict) or set(context) != {"mode", "packet", "verifiedHashes"}:
        errors.append("context has unsupported or missing fields")
    else:
        mode = context["mode"]
        if mode not in ("full_authority_read", "compact_continuation"):
            errors.append("unsupported context mode")
        if mode == "full_authority_read" and context["packet"] is not None:
            errors.append("full_authority_read must not rely on a compact packet")
        if mode == "compact_continuation":
            if context["packet"] is None:
                errors.append("compact_continuation requires a bound context packet")
            else:
                _check_binding(repo, context["packet"], "context.packet", errors)
        bindings = context["verifiedHashes"]
        if not isinstance(bindings, list) or not bindings:
            errors.append("context.verifiedHashes must be non-empty")
        else:
            for idx, binding in enumerate(bindings):
                _check_binding(repo, binding, f"context.verifiedHashes[{idx}]", errors)
    return errors


def validate_dispatch(
    dispatch: Any, repo: Path, route_id: str | None = None
) -> list[str]:
    """Validate a dispatch receipt, optionally resolving one exact route row.

    Receipt-wide row shape, canonical hashes, authority projection, and route-ID
    uniqueness always remain mandatory. When ``route_id`` is supplied, only
    that exact route receives live worktree/HEAD and full route validation, so
    unrelated sibling movement cannot invalidate a worker acknowledgement.
    """
    errors: list[str] = []
    expected = {"schema", "authorityCommit", "assignments"}
    if not isinstance(dispatch, dict) or set(dispatch) != expected:
        return ["dispatch receipt must contain exactly schema, authorityCommit, assignments"]
    if dispatch["schema"] != DISPATCH_SCHEMA:
        errors.append(f"dispatch schema must equal {DISPATCH_SCHEMA}")
    if not _is_hex(dispatch["authorityCommit"], 40):
        errors.append("dispatch authorityCommit must be a full lowercase Git SHA")
    if not isinstance(dispatch["assignments"], list) or not dispatch["assignments"]:
        return errors + ["dispatch assignments must be non-empty"]
    route_rows: dict[str, list[int]] = {}
    selected_rows = 0
    for idx, row in enumerate(dispatch["assignments"]):
        if not isinstance(row, dict) or set(row) != {"modelRouteSha256", "modelRoute"}:
            errors.append(f"assignments[{idx}] must contain exactly modelRouteSha256 and modelRoute")
            continue
        packet = row["modelRoute"]
        digest = row["modelRouteSha256"]
        if not _is_hex(digest, 64) or canonical_sha(packet) != digest:
            errors.append(f"assignments[{idx}] modelRouteSha256 does not match canonical route JSON")
        packet_route_id = packet.get("routeId") if isinstance(packet, dict) else None
        if not isinstance(packet_route_id, str) or not packet_route_id:
            errors.append(f"assignments[{idx}] modelRoute.routeId must be non-empty")
        else:
            route_rows.setdefault(packet_route_id, []).append(idx)
        if route_id is None or packet_route_id == route_id:
            selected_rows += 1
            errors.extend(f"assignments[{idx}]: {e}" for e in validate_route(packet, repo))
        if isinstance(packet, dict) and packet.get("authority", {}).get("authorityCommit") != dispatch["authorityCommit"]:
            errors.append(f"assignments[{idx}] authority does not match dispatch authority")
    for duplicate_id, indexes in sorted(route_rows.items()):
        if len(indexes) > 1:
            errors.append(
                f"dispatch contains duplicate routeId {duplicate_id!r} at assignments {indexes}"
            )
    if route_id is not None and selected_rows == 0:
        errors.append(f"dispatch routeId not found: {route_id!r}")
    return errors


def validate_siblings(previous: Any, current: Any, failed_direction: str) -> list[str]:
    errors: list[str] = []
    if not isinstance(previous, dict) or not isinstance(current, dict):
        return ["ledgers must be objects"]
    before = {row.get("direction"): row for row in previous.get("cells", []) if isinstance(row, dict)}
    after = {row.get("direction"): row for row in current.get("cells", []) if isinstance(row, dict)}
    for direction, old in before.items():
        if direction == failed_direction or direction not in after:
            continue
        new = after[direction]
        old_state, new_state = old.get("state"), new.get("state")
        if STATE_RANK.get(new_state, -1) < STATE_RANK.get(old_state, -1):
            errors.append(f"unchanged sibling {direction} was demoted: {old_state} -> {new_state}")
        for key in ("claimRevision", "sourceAdmissionReceipt", "rendererQuarantinePacket", "rendererCandidateReceipt", "qaResult"):
            if key in old and new.get(key) != old.get(key):
                errors.append(f"unchanged sibling {direction} changed protected field {key}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--route")
    parser.add_argument("--dispatch")
    parser.add_argument("--dispatch-route-id")
    parser.add_argument("--previous-ledger")
    parser.add_argument("--current-ledger")
    parser.add_argument("--failed-direction")
    args = parser.parse_args(argv)
    repo = Path(args.repo_root).resolve()
    errors: list[str] = []
    try:
        if args.route:
            errors.extend(validate_route(load_json(Path(args.route)), repo))
        if args.dispatch_route_id and not args.dispatch:
            errors.append("--dispatch-route-id requires --dispatch")
        if args.dispatch:
            errors.extend(
                validate_dispatch(
                    load_json(Path(args.dispatch)), repo, args.dispatch_route_id
                )
            )
        ledger_args = (args.previous_ledger, args.current_ledger, args.failed_direction)
        if any(ledger_args) and not all(ledger_args):
            errors.append("sibling validation requires previous ledger, current ledger, and failed direction")
        elif all(ledger_args):
            errors.extend(validate_siblings(load_json(Path(args.previous_ledger)), load_json(Path(args.current_ledger)), args.failed_direction))
    except ValidationError as exc:
        errors.append(str(exc))
    if not any((args.route, args.dispatch, args.previous_ledger)):
        errors.append("provide --route, --dispatch, or sibling ledger arguments")
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1
    print("PASS: model routing contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
