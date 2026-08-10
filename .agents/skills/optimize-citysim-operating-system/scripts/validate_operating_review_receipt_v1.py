#!/usr/bin/env python3
"""Fail-closed validator for schema-4 triggered operating-review receipts."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import subprocess
from pathlib import Path


DEFAULT_ROUTE = {"classification": "LUNA_MECHANICAL", "model": "gpt-5.6-luna", "effort": "medium"}
HEX64 = set("0123456789abcdef")
HEX40 = set("0123456789abcdef")
ALLOWED_OPERATION_KINDS = {
    "assemble_receipt",
    "hash_file",
    "inspect_diff_paths",
    "inspect_git_identity",
    "read_receipt",
    "validate_schema",
}
REQUIRED_RECEIPT_FIELDS = {
    "schema",
    "policySha256",
    "modelRoute",
    "eventKey",
    "binding",
    "decision",
    "compactContext",
    "inputReceipts",
    "nextAction",
    "prohibitedWork",
    "reviewOperations",
    "operationKinds",
    "metrics",
    "evidence",
    "multiLane",
    "sourceCoverage",
}
OPTIONAL_RECEIPT_FIELDS = {"eventFindings"}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _canonical_sha256(value: object) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _hash(value: object) -> bool:
    return isinstance(value, str) and len(value) == 64 and set(value) <= HEX64


def _commit(value: object) -> bool:
    return isinstance(value, str) and len(value) == 40 and set(value) <= HEX40


def _strings(value: object) -> bool:
    return isinstance(value, list) and all(isinstance(item, str) and item for item in value)


def _requirement(policy: dict, trigger: str) -> dict | None:
    requirements = policy.get("eventRequirements")
    if not isinstance(requirements, dict):
        return None
    entry = requirements.get(trigger)
    if isinstance(entry, dict):
        evidence = entry.get("requiredEvidence")
        decisions = entry.get("allowedDecisions")
        if set(entry) == {"requiredEvidence", "allowedDecisions"} and _strings(evidence) and _strings(decisions):
            return entry
    return None


def _present(value: object) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value)
    if isinstance(value, (list, dict)):
        return bool(value)
    return isinstance(value, (bool, int, float))


def _ledger_rows(ledger: object) -> list[object] | None:
    if isinstance(ledger, list):
        return ledger
    if isinstance(ledger, dict) and set(ledger) == {"schema", "receipts"} and ledger.get("schema") == 1 and isinstance(ledger.get("receipts"), list):
        return ledger["receipts"]
    return None


def _git_commit_exists(repo_root: Path, value: object) -> bool:
    if not _commit(value):
        return False
    result = subprocess.run(
        ["git", "-C", str(repo_root), "cat-file", "-e", f"{value}^{{commit}}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def _is_git_repo(repo_root: Path) -> bool:
    result = subprocess.run(
        ["git", "-C", str(repo_root), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return False
    try:
        return Path(result.stdout.strip()).resolve() == repo_root.resolve()
    except (OSError, RuntimeError):
        return False


def _output_identity_errors(output_root: Path, assignment: dict) -> list[str]:
    errors: list[str] = []
    branch = subprocess.run(
        ["git", "-C", str(output_root), "branch", "--show-current"],
        capture_output=True,
        text=True,
        check=False,
    )
    if branch.returncode != 0 or branch.stdout.strip() != assignment.get("branch"):
        errors.append("live worker/output branch must exactly match the model route branch")
    expected_head = assignment.get("expectedHead")
    ancestry = subprocess.run(
        ["git", "-C", str(output_root), "merge-base", "--is-ancestor", str(expected_head), "HEAD"],
        capture_output=True,
        text=True,
        check=False,
    )
    if ancestry.returncode != 0:
        errors.append("model route expected HEAD must be an ancestor of live worker/output HEAD")
    return errors


def _confined_path(root: Path, supplied: str, label: str) -> tuple[Path | None, list[str]]:
    candidate = Path(supplied)
    candidate = candidate.resolve() if candidate.is_absolute() else (root / candidate).resolve()
    try:
        candidate.relative_to(root.resolve())
        return candidate, []
    except ValueError:
        return None, [f"{label} must remain inside its declared root"]


def _within(path: str, root: str) -> bool:
    return path == root or path.startswith(root.rstrip("/") + "/")


def _project_observer_dispatch(
    dispatch: object,
    route_id: str,
) -> tuple[dict | None, dict | None, list[str]]:
    """Preserve the original binding while projecting only schema-validation worktree state."""
    errors: list[str] = []
    assignments = dispatch.get("assignments") if isinstance(dispatch, dict) else None
    matches = [
        (index, item)
        for index, item in enumerate(assignments or [])
        if isinstance(item, dict)
        and isinstance(item.get("modelRoute"), dict)
        and item["modelRoute"].get("routeId") == route_id
    ]
    if len(matches) != 1:
        return None, None, ["observer model route must resolve exactly once"]
    selected_index, selected = matches[0]
    route = selected["modelRoute"]
    original_hash = selected.get("modelRouteSha256")
    if original_hash != _canonical_sha256(route):
        errors.append("observer selected model route hash must match canonical original route JSON")
    authority = route.get("authority") if isinstance(route.get("authority"), dict) else {}
    if not isinstance(dispatch, dict) or dispatch.get("authorityCommit") != authority.get("authorityCommit"):
        errors.append("observer dispatch and selected route authority must exactly match")
    projected_dispatch = copy.deepcopy(dispatch)
    try:
        projected_row = projected_dispatch["assignments"][selected_index]
        projected_route = projected_row["modelRoute"]
        projected_assignment = projected_route["assignment"]
    except (KeyError, IndexError, TypeError):
        return route, None, errors + ["observer selected route must contain an assignment"]
    if not isinstance(projected_assignment, dict):
        return route, None, errors + ["observer selected route must contain an assignment"]
    projected_assignment["worktree"] = "/__citysim_schema_validation__/nonexistent"
    projected_row["modelRouteSha256"] = _canonical_sha256(projected_route)
    return route, projected_dispatch, errors


def validate_observer_output_route(
    dispatch_supplied: str,
    route_id: str,
    authority_root: Path,
    output_root: Path,
    output_paths: list[str],
) -> tuple[list[str], list[str]]:
    """Validate the observer's route separately from each observed event route."""
    dispatch_path, errors = _confined_path(authority_root, dispatch_supplied, "observer dispatch receipt")
    if dispatch_path is None:
        return [], errors
    try:
        dispatch = json.loads(dispatch_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, UnicodeError):
        return [], errors + ["observer dispatch receipt must be readable schema-2 JSON"]
    route, projected_dispatch, projection_errors = _project_observer_dispatch(dispatch, route_id)
    errors.extend(projection_errors)
    if route is None:
        return [], errors
    if projected_dispatch is not None:
        try:
            route_validator = _load_model_route_validator(authority_root)
            errors.extend(route_validator.validate_dispatch(projected_dispatch, authority_root, route_id))
        except (OSError, RuntimeError) as exc:
            errors.append(str(exc))
    if (
        route.get("taskId") != "PLAY-089"
        or route.get("classification") != "LUNA_MECHANICAL"
        or route.get("model") != "gpt-5.6-luna"
        or route.get("effort") != "medium"
    ):
        errors.append("observer route must be PLAY-089 Luna mechanical/medium")
    assignment = route.get("assignment") if isinstance(route.get("assignment"), dict) else {}
    observed_root, observed_root_errors = _observed_route_root(assignment)
    errors.extend(observed_root_errors)
    if observed_root is not None and observed_root != output_root.resolve():
        errors.append("observer route worktree must exactly match the worker/output root")
    elif observed_root is not None:
        errors.extend(_output_identity_errors(observed_root, assignment))
    policy = route.get("pathPolicy") if isinstance(route.get("pathPolicy"), dict) else {}
    allowed = policy.get("allowed") if isinstance(policy.get("allowed"), list) else []
    if not allowed:
        errors.append("observer route must declare allowed output paths")
    for path in output_paths:
        candidate = Path(path)
        if candidate.is_absolute() or ".." in candidate.parts or not any(_within(path, root) for root in allowed):
            errors.append(f"observer output lies outside its exact route: {path}")
    return allowed, errors


def _load_model_route_validator(repo_root: Path) -> object:
    script = repo_root / ".agents/skills/operate-citysim-integration/scripts/validate_model_route_v1.py"
    spec = importlib.util.spec_from_file_location("citysim_model_route_validator", script)
    if not script.is_file() or spec is None or spec.loader is None:
        raise RuntimeError("schema-2 model-route validator is unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _observed_route_root(assignment: dict) -> tuple[Path | None, list[str]]:
    supplied = assignment.get("worktree")
    if not isinstance(supplied, str) or not supplied or not Path(supplied).is_absolute():
        return None, ["observed route assignment.worktree must be an absolute path"]
    try:
        observed_root = Path(supplied).resolve()
    except (OSError, RuntimeError):
        return None, ["observed route assignment.worktree must resolve"]
    if not observed_root.is_dir():
        return None, ["observed route assignment.worktree must be an existing directory"]
    top_level = subprocess.run(
        ["git", "-C", str(observed_root), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    if top_level.returncode != 0:
        return None, ["observed route assignment.worktree must be a Git repository"]
    try:
        git_root = Path(top_level.stdout.strip()).resolve()
    except OSError:
        return None, ["observed route Git top level must resolve"]
    if git_root != observed_root:
        return None, ["observed route assignment.worktree must equal its Git top level"]
    return observed_root, []


def _route_projection_errors(
    binding: dict,
    repo_root: Path,
    event_key: dict | None = None,
    output_root: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    dispatch_path = (repo_root / binding["dispatchReceiptPath"]).resolve()
    try:
        dispatch = json.loads(dispatch_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ["binding dispatch receipt must be readable schema-2 JSON"]
    assignments = dispatch.get("assignments") if isinstance(dispatch, dict) else None
    if not isinstance(dispatch, dict) or dispatch.get("schema") != 2 or not isinstance(assignments, list):
        return ["binding dispatch receipt must be schema 2"]
    matches = [
        item for item in assignments
        if isinstance(item, dict) and item.get("modelRouteSha256") == binding["modelRouteHash"]
    ]
    if len(matches) != 1 or not isinstance(matches[0].get("modelRoute"), dict):
        return ["binding model route must resolve exactly once from dispatch receipt"]
    assignment = matches[0]
    route = assignment["modelRoute"]
    if _canonical_sha256(route) != binding["modelRouteHash"]:
        errors.append("binding model route hash must match canonical route JSON")
    authority = route.get("authority") if isinstance(route.get("authority"), dict) else {}
    claim = authority.get("claim") if isinstance(authority.get("claim"), dict) else {}
    route_assignment = route.get("assignment") if isinstance(route.get("assignment"), dict) else {}
    path_policy = route.get("pathPolicy") if isinstance(route.get("pathPolicy"), dict) else {}
    focused = route.get("validation", {}).get("focusedGateOwner", {}) if isinstance(route.get("validation"), dict) else {}
    full = route.get("validation", {}).get("fullGateOwner", {}) if isinstance(route.get("validation"), dict) else {}
    reviewer = route.get("independentReviewer") if isinstance(route.get("independentReviewer"), dict) else {}
    observed_root, observed_root_errors = _observed_route_root(route_assignment)
    errors.extend(observed_root_errors)
    if observed_root is not None:
        try:
            route_validator = _load_model_route_validator(repo_root)
            schema_route = copy.deepcopy(route)
            if isinstance(schema_route.get("assignment"), dict):
                schema_route["assignment"]["worktree"] = "/__citysim_schema_validation__/nonexistent"
            errors.extend(
                f"schema-2 route: {error}"
                for error in route_validator.validate_route(schema_route, observed_root)
            )
            errors.extend(_output_identity_errors(observed_root, route_assignment))
        except (OSError, RuntimeError) as exc:
            errors.append(str(exc))
    if claim.get("path") != binding["claimPath"] or claim.get("sha256") != binding["claimHash"]:
        errors.append("binding claim must exactly project from model route")
    if isinstance(event_key, dict):
        if route.get("taskId") != event_key.get("taskId"):
            errors.append("event task must exactly project from model route")
        if authority.get("authorityCommit") != event_key.get("authorityCommit"):
            errors.append("event authority must exactly project from model route")
    if route_assignment.get("expectedHead") != binding["expectedHead"]:
        errors.append("binding expected HEAD must exactly project from model route")
    if output_root is not None:
        assigned_worktree = route_assignment.get("worktree")
        if not isinstance(assigned_worktree, str) or Path(assigned_worktree).resolve() != output_root.resolve():
            errors.append("worker/output root must exactly match the model route worktree")
        elif _is_git_repo(output_root):
            errors.extend(_output_identity_errors(output_root, route_assignment))
    if path_policy.get("allowed") != binding["allowedPaths"]:
        errors.append("binding allowed paths must exactly project from model route")
    if focused.get("threadId") == full.get("threadId"):
        errors.append("focused and full gate owners must be distinct")
    if reviewer.get("required") is not True or reviewer.get("threadId") != full.get("threadId"):
        errors.append("independent reviewer must be required and own the full gate")
    if route_assignment.get("featureAuthorThreadId") == reviewer.get("threadId"):
        errors.append("feature author cannot be the independent reviewer")
    for path in binding["allowedPaths"]:
        candidate = Path(path)
        if candidate.is_absolute() or ".." in candidate.parts:
            errors.append("binding allowed paths must be safe repo-relative paths")
            break
    return errors


def validate(
    receipt: object,
    policy: object,
    policy_sha256: str,
    ledger: object | None,
    input_root: Path | None = None,
    require_git_repo: bool = False,
    output_root: Path | None = None,
    observed_output_root: bool = True,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(policy, dict) or policy.get("schema") != 4:
        return ["policy must be schema 4"]
    if policy.get("defaultRoute") != DEFAULT_ROUTE:
        errors.append("policy default route must be Luna mechanical/medium")
    keys = policy.get("eventKeyFields")
    if not _strings(keys) or len(keys) != len(set(keys)):
        errors.append("policy eventKeyFields must be a unique nonempty string list")
        keys = []
    if not isinstance(receipt, dict):
        return errors + ["receipt must be an object"]
    if receipt.get("schema") != 4:
        errors.append("receipt must be schema 4")
    if not REQUIRED_RECEIPT_FIELDS <= set(receipt) or set(receipt) - REQUIRED_RECEIPT_FIELDS - OPTIONAL_RECEIPT_FIELDS:
        errors.append("receipt fields must match the schema-4 contract")
    budget = policy.get("reviewBudget") if isinstance(policy.get("reviewBudget"), dict) else {}
    if not _hash(receipt.get("policySha256")) or receipt.get("policySha256") != policy_sha256:
        errors.append("receipt policySha256 must bind the exact policy bytes")
    if receipt.get("modelRoute") != DEFAULT_ROUTE:
        errors.append("receipt route must be Luna mechanical/medium")
    event_key = receipt.get("eventKey")
    if not isinstance(event_key, dict) or list(event_key) != keys or not all(isinstance(event_key.get(key), str) and event_key[key] for key in keys):
        errors.append("receipt eventKey fields must exactly match policy order and values")
        trigger = None
    else:
        trigger = event_key.get("trigger")
        if not _commit(event_key.get("authorityCommit")) or not _commit(event_key.get("candidateOrResultCommit")):
            errors.append("event authority and candidate/result identities must be exact commits")
        if not event_key.get("taskId", "").startswith("PLAY-"):
            errors.append("event taskId must be a PLAY identifier")
    if trigger not in policy.get("triggers", []):
        errors.append("receipt trigger must be legal")
    decision = receipt.get("decision")
    if decision not in policy.get("allowedDecisions", []):
        errors.append("receipt decision must be legal")

    context = receipt.get("compactContext")
    context_cap = budget.get("maxCompactContextBytes") if isinstance(budget, dict) else None
    if not isinstance(context, dict) or set(context) != {"mode", "hashes", "bytes"} or context.get("mode") != "compact_hash_bound" or not isinstance(context.get("bytes"), int) or context["bytes"] < 0 or not isinstance(context_cap, int) or context["bytes"] > context_cap or not isinstance(context.get("hashes"), dict) or not context["hashes"] or not all(isinstance(k, str) and k and _hash(v) for k, v in context["hashes"].items()):
        errors.append("receipt compactContext must contain hash-bound hashes and byte count")
    binding = receipt.get("binding")
    binding_fields = {
        "dispatchReceiptPath",
        "dispatchReceiptHash",
        "modelRouteHash",
        "claimPath",
        "claimHash",
        "expectedHead",
        "allowedPaths",
    }
    if (
        not isinstance(binding, dict)
        or set(binding) != binding_fields
        or not _hash(binding.get("dispatchReceiptHash"))
        or not _hash(binding.get("modelRouteHash"))
        or not _hash(binding.get("claimHash"))
        or not _commit(binding.get("expectedHead"))
        or not _strings(binding.get("allowedPaths"))
        or not isinstance(binding.get("dispatchReceiptPath"), str)
        or not binding.get("dispatchReceiptPath")
        or not isinstance(binding.get("claimPath"), str)
        or not binding.get("claimPath")
    ):
        errors.append("receipt binding must contain exact route, claim, HEAD, and allowed paths")

    inputs = receipt.get("inputReceipts")
    if not isinstance(inputs, list) or not inputs:
        errors.append("receipt must identify input receipt hashes")
    else:
        seen: set[str] = set()
        hashes_by_path: dict[str, str] = {}
        for item in inputs:
            if not isinstance(item, dict) or set(item) != {"path", "sha256"} or not isinstance(item.get("path"), str) or not item["path"] or not _hash(item.get("sha256")) or item["path"] in seen:
                errors.append("input receipt hashes must be exact and unique")
                break
            seen.add(item["path"])
            hashes_by_path[item["path"]] = item["sha256"]
            if input_root is not None:
                candidate = (input_root / item["path"]).resolve()
                try:
                    candidate.relative_to(input_root.resolve())
                except ValueError:
                    errors.append("input receipt path must remain inside repo root")
                    break
                if not candidate.is_file():
                    errors.append("input receipt path must exist")
                    break
                if _sha256(candidate) != item["sha256"]:
                    errors.append("input receipt hash must match repository bytes")
                    break
        if isinstance(binding, dict):
            for path_key, hash_key in (("dispatchReceiptPath", "dispatchReceiptHash"), ("claimPath", "claimHash")):
                if hashes_by_path.get(binding.get(path_key)) != binding.get(hash_key):
                    errors.append("binding dispatch and claim hashes must project from inputReceipts")
                    break
    action = receipt.get("nextAction")
    if not isinstance(action, dict) or set(action) != {"action", "owner", "boundedDeliverable", "stopCondition"} or not all(isinstance(value, str) and value for value in action.values()):
        errors.append("receipt must contain one bounded nextAction")
    prohibited = receipt.get("prohibitedWork")
    restricted = ("productBuildAllowed", "fullGateAllowed", "dccAllowed", "realAppQAAllowed", "sharedMutationAllowed")
    if not isinstance(prohibited, dict) or set(prohibited) != set(restricted) or any(prohibited.get(key) is not False or budget.get(key) is not False for key in restricted):
        errors.append("receipt may not perform policy-prohibited work")
    operations = receipt.get("reviewOperations")
    if operations != {"threadPolling": False, "spawnedReviews": False} or budget.get("threadPollingAllowed") is not False or budget.get("reviewCanSpawnReviews") is not False:
        errors.append("receipt may not poll tasks or spawn more reviews")
    operation_kinds = receipt.get("operationKinds")
    if not _strings(operation_kinds) or len(operation_kinds) != len(set(operation_kinds)) or not set(operation_kinds) <= ALLOWED_OPERATION_KINDS:
        errors.append("receipt operationKinds must be unique low-cost review operations")
    metrics = receipt.get("metrics")
    if not isinstance(metrics, dict) or any(
        value is not None and (isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0)
        for value in metrics.values()
    ):
        errors.append("unknown metrics must be null or nonnegative measured numbers")
    elif metrics.get("turns") is not None and metrics["turns"] > budget.get("maxTurns", 0):
        errors.append("review turns exceed the policy budget")
    requirement = _requirement(policy, trigger) if isinstance(trigger, str) else None
    evidence = receipt.get("evidence")
    if requirement is None:
        errors.append("policy must define valid trigger-specific eventRequirements")
    elif decision not in requirement["allowedDecisions"]:
        errors.append("receipt decision is not allowed for its trigger")
    elif not isinstance(evidence, dict) or set(evidence) != set(requirement["requiredEvidence"]) or any(not _present(evidence[key]) for key in requirement["requiredEvidence"]):
        errors.append("receipt is missing trigger-required evidence")
    else:
        for key, value in evidence.items():
            if key.lower().endswith("hash") and not _hash(value):
                errors.append(f"{key} must be a SHA-256 hash")

    if isinstance(evidence, dict):
        if trigger == "frontier_route_assigned" and (
            evidence.get("classification") != "FRONTIER_AUTHORITY"
            or evidence.get("lunaDecompositionChecked") is not True
        ):
            errors.append("frontier route review must prove frontier classification and Luna decomposition")
        if trigger == "delegation_ready_for_dispatch" and evidence.get("lowestLegalRoute") not in {
            "LUNA_MECHANICAL",
            "LUNA_IMPLEMENTATION",
            "LUNA_LOCAL_DEBUG",
            "FRONTIER_AUTHORITY",
        }:
            errors.append("delegation readiness must name a legal lowest-cost route")
        if trigger == "useful_concurrency_below_floor":
            count = evidence.get("usefulActiveCount")
            floor = evidence.get("minimumUsefulActiveWorkstreams")
            if isinstance(count, bool) or isinstance(floor, bool) or not isinstance(count, int) or not isinstance(floor, int) or count >= floor:
                errors.append("concurrency trigger must prove useful active work below the floor")
            if evidence.get("protectedOperationsExcluded") is not True:
                errors.append("concurrency trigger must exclude protected operations")
            if evidence.get("readyDisjointWork") is True and decision != "REFILL":
                errors.append("ready disjoint work below the floor requires REFILL")
        if trigger == "duplicate_full_gate_requested":
            rerun_justified = evidence.get("identityChanged") is True or evidence.get("evidenceStale") is True
            if rerun_justified and decision == "RETURN":
                errors.append("a changed identity or stale proof must not be returned as duplicate")
            if not rerun_justified and decision != "RETURN":
                errors.append("an unchanged fresh full-gate request must be RETURN")
        if trigger == "second_unsuccessful_repair" and decision != "ESCALATE":
            errors.append("a second unsuccessful repair must escalate")
        if trigger == "worktree_or_dispatch_setup_failed_before_mutation" and evidence.get("mutationCount") != 0:
            errors.append("setup-failure review requires zero mutation")
        if trigger == "candidate_handoff" and evidence.get("candidateCleanliness") != "clean":
            errors.append("candidate handoff must bind a clean candidate")
        if trigger == "exact_candidate_qa_started" and (
            evidence.get("featureAuthorThread") == evidence.get("qaThread")
            or evidence.get("independentReviewer") != evidence.get("qaThread")
        ):
            errors.append("final QA must be independent of the feature author")

    coverage = receipt.get("sourceCoverage")
    if receipt.get("multiLane") is True:
        fields = policy.get("coverage", {}).get("requiredRowFields") if isinstance(policy.get("coverage"), dict) else None
        directions = policy.get("coverage", {}).get("directionWorkstreams") if isinstance(policy.get("coverage"), dict) else None
        if not isinstance(coverage, list) or not isinstance(fields, list) or not isinstance(directions, list) or len(coverage) != len(directions):
            errors.append("multi-lane receipt must contain exact source coverage rows")
        else:
            streams = []
            for row in coverage:
                if not isinstance(row, dict) or list(row) != fields or not all(isinstance(row.get(field), str) and row[field] for field in fields):
                    errors.append("source coverage rows must exactly match policy fields")
                    break
                streams.append(row["workstream"])
            if streams != directions:
                errors.append("source coverage workstreams must exactly match policy")
    elif coverage not in (None, []):
        errors.append("single-lane receipt must not include source coverage")
    if ledger is None:
        errors.append("a durable operating-review ledger is required")
    elif isinstance(event_key, dict) and list(event_key) == keys:
        rows = _ledger_rows(ledger)
        if rows is None:
            errors.append("ledger must be a receipt/event list")
        else:
            valid_ledger_rows = True
            for row in rows:
                if not isinstance(row, dict) or set(row) != {
                    "eventKey",
                    "receiptPath",
                    "receiptSha256",
                    "decision",
                    "disposition",
                }:
                    valid_ledger_rows = False
                    break
                if input_root is not None:
                    receipt_path = (input_root / row["receiptPath"]).resolve()
                    try:
                        receipt_path.relative_to(input_root.resolve())
                        prior_receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
                    except (ValueError, OSError, json.JSONDecodeError):
                        valid_ledger_rows = False
                        break
                    if (
                        _sha256(receipt_path) != row["receiptSha256"]
                        or prior_receipt.get("eventKey") != row["eventKey"]
                        or prior_receipt.get("decision") != row["decision"]
                    ):
                        valid_ledger_rows = False
                        break
                disposition = row.get("disposition")
                if (
                    not isinstance(row.get("eventKey"), dict)
                    or not isinstance(row.get("receiptPath"), str)
                    or not row["receiptPath"]
                    or not _hash(row.get("receiptSha256"))
                    or row.get("decision") not in policy.get("allowedDecisions", [])
                    or not isinstance(disposition, dict)
                    or set(disposition) != {"status", "authorityCommit", "reason"}
                    or disposition.get("status") not in {"auto_closed", "applied", "deferred", "rejected"}
                    or not isinstance(disposition.get("reason"), str)
                    or not disposition["reason"]
                    or (disposition.get("authorityCommit") is not None and not _commit(disposition["authorityCommit"]))
                    or (row.get("decision") == "NO_CHANGE" and disposition.get("status") != "auto_closed")
                    or (row.get("decision") != "NO_CHANGE" and disposition.get("status") == "auto_closed")
                ):
                    valid_ledger_rows = False
                    break
            if not valid_ledger_rows:
                errors.append("ledger rows and dispositions must match the schema-1 contract")
            ledger_keys = [row.get("eventKey") for row in rows if isinstance(row, dict)]
            if len(ledger_keys) != len({json.dumps(key, sort_keys=True) for key in ledger_keys if isinstance(key, dict)}):
                errors.append("ledger contains duplicate operating-review eventKeys")
            if any(key == event_key for key in ledger_keys):
                errors.append("duplicate operating-review eventKey in ledger")
    if require_git_repo and (input_root is None or not _is_git_repo(input_root)):
        errors.append("authority root must be the exact root of a Git repository")
    if require_git_repo and (output_root is None or not _is_git_repo(output_root)):
        errors.append("worker/output root must be the exact root of a Git repository")
    if input_root is not None and _is_git_repo(input_root):
        if not _git_commit_exists(input_root, event_key.get("authorityCommit") if isinstance(event_key, dict) else None):
            errors.append("event authority commit must resolve in Git")
        if not _git_commit_exists(input_root, event_key.get("candidateOrResultCommit") if isinstance(event_key, dict) else None):
            errors.append("event candidate/result commit must resolve in Git")
        if isinstance(binding, dict):
            if not _git_commit_exists(input_root, binding.get("expectedHead")):
                errors.append("binding expected HEAD must resolve in Git")
            errors.extend(
                _route_projection_errors(
                    binding,
                    input_root,
                    event_key if isinstance(event_key, dict) else None,
                    output_root if observed_output_root else None,
                )
            )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    root = Path(__file__).resolve().parents[1]
    parser.add_argument("receipt")
    parser.add_argument("--policy")
    parser.add_argument("--ledger", required=True)
    parser.add_argument("--repo-root", required=True, help="worker/output root; also the default authority root")
    parser.add_argument(
        "--authority-root",
        help="exact Integration authority Git root when immutable inputs live outside the worker checkout",
    )
    parser.add_argument("--observer-dispatch", help="schema-2 PLAY-089 observer dispatch receipt in the authority root")
    parser.add_argument("--observer-route-id", help="exact PLAY-089 observer route ID")
    args = parser.parse_args()
    output_root = Path(args.repo_root).resolve()
    authority_root = Path(args.authority_root or args.repo_root).resolve()

    receipt_path, errors = _confined_path(output_root, args.receipt, "receipt path")
    policy_supplied = args.policy or ".agents/skills/optimize-citysim-operating-system/references/triggered-operating-review-policy.json"
    policy_path, path_errors = _confined_path(authority_root, policy_supplied, "policy path")
    errors.extend(path_errors)
    ledger_path, path_errors = _confined_path(authority_root, args.ledger, "ledger path")
    errors.extend(path_errors)
    try:
        receipt = json.loads(receipt_path.read_bytes()) if receipt_path else None
        policy = json.loads(policy_path.read_bytes()) if policy_path else None
        ledger = json.loads(ledger_path.read_bytes()) if ledger_path else None
    except (OSError, json.JSONDecodeError, UnicodeError):
        receipt = policy = ledger = None
        errors.append("receipt, policy, and ledger must be readable JSON")
    errors.extend(
        validate(
            receipt,
            policy,
            _sha256(policy_path) if policy_path and policy_path.is_file() else "",
            ledger,
            authority_root,
            require_git_repo=True,
            output_root=output_root,
            observed_output_root=not bool(args.observer_dispatch),
        )
    )
    if receipt_path is not None and isinstance(receipt, dict):
        relative_receipt = receipt_path.relative_to(output_root).as_posix()
        if bool(args.observer_dispatch) != bool(args.observer_route_id):
            errors.append("observer dispatch and route ID must be supplied together")
        elif args.observer_dispatch:
            _, observer_errors = validate_observer_output_route(
                args.observer_dispatch,
                args.observer_route_id,
                authority_root,
                output_root,
                [relative_receipt],
            )
            errors.extend(observer_errors)
        else:
            allowed = receipt.get("binding", {}).get("allowedPaths")
            if not isinstance(allowed, list) or relative_receipt not in allowed:
                errors.append("receipt path must be one exact model-route allowed output")
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PASS: operating review receipt")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
