#!/usr/bin/env python3
"""Validate the fail-closed CitySim triggered operating-review policy."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


EXPECTED_TRIGGERS = {
    "authority_acknowledged",
    "candidate_handoff",
    "claim_or_baseline_mismatch",
    "dispatch_published",
    "duplicate_full_gate_requested",
    "eligible_lane_became_idle",
    "exact_candidate_qa_started",
    "first_focused_gate_failure",
    "first_return",
    "integration_closed",
    "model_route_mismatch",
    "no_progress_two_snapshots",
    "second_unsuccessful_repair",
}
EXPECTED_DECISIONS = {"NO_CHANGE", "PROPOSE", "REFILL", "RETURN", "ESCALATE"}
EXPECTED_KEY_FIELDS = [
    "authorityCommit",
    "taskId",
    "routeId",
    "trigger",
    "candidateOrResultCommit",
]
EXPECTED_PROTECTED = {
    "coherent_commit_in_progress",
    "dcc_process",
    "exact_candidate_qa",
    "frozen_final_proof",
    "long_running_focused_gate",
}


def validate(policy: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(policy, dict):
        return ["policy must be an object"]
    expected_top = {
        "schema",
        "defaultRoute",
        "eventKeyFields",
        "reviewBudget",
        "parallelism",
        "noProgress",
        "allowedDecisions",
        "triggers",
    }
    if set(policy) != expected_top:
        errors.append("policy top-level fields must match the exact schema")
    if policy.get("schema") != 1:
        errors.append("schema must be 1")
    if policy.get("defaultRoute") != {
        "classification": "LUNA_MECHANICAL",
        "model": "gpt-5.6-luna",
        "effort": "medium",
    }:
        errors.append("default review route must be Luna mechanical/medium")
    if policy.get("eventKeyFields") != EXPECTED_KEY_FIELDS:
        errors.append("event key fields must be exact and ordered")

    budget = policy.get("reviewBudget")
    if not isinstance(budget, dict):
        errors.append("reviewBudget must be an object")
    else:
        if budget.get("maxReviewsPerEventKey") != 1 or budget.get("maxTurns") != 1:
            errors.append("each event is limited to one review and one turn")
        if budget.get("contextMode") != "compact_hash_bound":
            errors.append("review context must be compact and hash-bound")
        if budget.get("missingMetricValue", "missing") is not None:
            errors.append("missing metrics must be null")
        for key in (
            "productBuildAllowed",
            "fullGateAllowed",
            "dccAllowed",
            "realAppQAAllowed",
            "sharedMutationAllowed",
        ):
            if budget.get(key) is not False:
                errors.append(f"{key} must be false")

    parallel = policy.get("parallelism")
    if not isinstance(parallel, dict):
        errors.append("parallelism must be an object")
    else:
        if parallel.get("minimumUsefulActiveWorkstreams") != 3:
            errors.append("minimum useful active workstreams must be 3")
        if parallel.get("sameTurnRefillRequired") is not True:
            errors.append("same-turn refill must be required")
        if parallel.get("serializedDependencyRequiredWhenNotRefilled") is not True:
            errors.append("a non-refill requires an exact serialized dependency")
        if parallel.get("manufacturedBusyworkAllowed") is not False:
            errors.append("manufactured busywork must be forbidden")

    progress = policy.get("noProgress")
    if not isinstance(progress, dict):
        errors.append("noProgress must be an object")
    else:
        if progress.get("snapshotIntervalSeconds") != 60:
            errors.append("snapshot interval must be 60 seconds")
        if progress.get("consecutiveSnapshots") != 2:
            errors.append("no-progress review requires two snapshots")
        protected = progress.get("protectedActiveOperations")
        if not isinstance(protected, list) or len(protected) != len(set(protected)) or set(protected) != EXPECTED_PROTECTED:
            errors.append("protected active operations must be exact and unique")

    decisions = policy.get("allowedDecisions")
    if not isinstance(decisions, list) or len(decisions) != len(set(decisions)) or set(decisions) != EXPECTED_DECISIONS:
        errors.append("allowed decisions must be exact and unique")
    triggers = policy.get("triggers")
    if not isinstance(triggers, list) or len(triggers) != len(set(triggers)) or set(triggers) != EXPECTED_TRIGGERS:
        errors.append("triggers must be exact and unique")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "policy",
        nargs="?",
        default=str(Path(__file__).resolve().parents[1] / "references" / "triggered-operating-review-policy.json"),
    )
    args = parser.parse_args()
    policy = json.loads(Path(args.policy).read_text(encoding="utf-8"))
    errors = validate(policy)
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PASS: triggered operating-review policy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
