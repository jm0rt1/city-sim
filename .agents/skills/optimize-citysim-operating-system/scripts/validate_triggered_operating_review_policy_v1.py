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
    "delegation_acknowledgement_failed",
    "delegation_ready_for_dispatch",
    "dispatch_published",
    "duplicate_full_gate_requested",
    "eligible_lane_became_idle",
    "exact_candidate_qa_started",
    "first_focused_gate_failure",
    "first_return",
    "frontier_route_assigned",
    "independent_return_after_focused_pass",
    "integration_closed",
    "model_route_mismatch",
    "no_progress_two_snapshots",
    "ready_handoff_waiting_for_owner",
    "repeated_context_load_detected",
    "task_completed_or_stopped",
    "useful_concurrency_below_floor",
    "second_unsuccessful_repair",
    "worktree_or_dispatch_setup_failed_before_mutation",
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
EXPECTED_COVERAGE_FIELDS = [
    "taskId",
    "routeId",
    "workstream",
    "state",
    "evidenceCommit",
    "disposition",
]
EXPECTED_DIRECTIONS = ["north", "east", "south", "west"]
EXPECTED_FALSE_GREEN_ESCALATIONS = [
    "shared_contract_or_schema_decision",
    "baseline_or_candidate_identity_mismatch",
    "failure_outside_focused_scope",
    "cross_lane_semantic_conflict",
    "subjective_acceptance_required",
]
EXPECTED_OUTCOME_FAST_PATH = {
    "mode": "outcome_lease",
    "eligibility": {
        "validatedSchema2ClaimRouteAndSelectedDispatch": True,
        "exactBranchHeadAndStatusContract": True,
        "protectedUserDirtOutsideClaimAllowed": True,
        "protectedUserDirtMustRemainUnchanged": True,
        "explicitAllowedPaths": True,
        "reversibleLocalWorkOnly": True,
        "focusedProofDeclared": True,
        "judgmentBoundaryPresent": False,
        "sharedContractMutation": False,
        "irreversibleOrExternalAction": False,
        "candidateAcceptanceOrRelease": False,
    },
    "authorizedActions": [
        "inspect",
        "edit_allowed_paths",
        "run_focused_proof",
        "stage_explicit_paths",
        "commit_once",
    ],
    "pathScopeContract": {
        "allowedPathsAreMaximumMutationBoundary": True,
        "minimumTouchedPathCountRequired": False,
        "predictedPathCountIsMutationMinimum": False,
        "manufacturedNoOpEditsAllowed": False,
        "fewerChangedPathsAllowedWhenDeliverableAndFocusedProofPass": True,
        "everyChangedPathMustBeInAllowlist": True,
        "extraOrUnexpectedPathDecision": "ESCALATE",
        "exactChangedPathStagingAndProofRequired": True,
    },
    "separateRoundsRequiredWithinEligibility": {
        "ackOnly": False,
        "staticReview": False,
        "executionRelease": False,
        "receiptReview": False,
        "routineDelegationObservation": False,
    },
    "manualCtoReviewBoundaries": [
        "product_semantics",
        "shared_contract_or_schema",
        "irreversible_or_external_action",
        "candidate_acceptance",
        "release",
    ],
    "integrationMayDispatchEligibleRoutineWork": True,
    "carrierRules": {
        "validatedTempLocalCarrierAllowedForReversibleLocalWork": True,
        "durablePublicationRequiredForDurableGovernanceOrProductArtifact": True,
        "durablePublicationRequiredAtJudgmentBoundary": True,
    },
    "exactCommandRecovery": {
        "maxIdenticalRetries": 1,
        "allowedFailureClasses": ["sandbox", "permission", "tool_transport"],
        "requiresPreProductExecution": True,
        "requiresZeroMutation": True,
        "freshCarrierRequired": False,
    },
    "correctedMechanicalActionRecovery": {
        "maxCorrectedMechanicalActions": 1,
        "sameOutcomeLeaseRequired": True,
        "freshCarrierRequired": False,
        "requiresExactPostFailureAudit": True,
        "auditMustProve": {
            "zeroOutOfAllowlistMutation": True,
            "intendedOutcomeUnchanged": True,
            "intendedPathsUnchanged": True,
            "noCompletedProductOrProofActionReplayed": True,
            "noSemanticsOrDataNondeterminism": True,
        },
        "countsAgainstIdenticalInfrastructureRetry": False,
        "countsAgainstFocusedProofAttempts": False,
        "stopOn": [
            "second_corrected_action",
            "out_of_allowlist_mutation",
            "outcome_or_path_change",
            "completed_product_or_proof_replay",
            "semantics_or_data_nondeterminism",
        ],
    },
    "boundedLocalRepair": {
        "maxFocusedProofAttempts": 2,
        "firstFailureMayInformOneRepair": True,
        "freshCarrierRequired": False,
        "allowlistMayExpand": False,
        "escalateOn": [
            "second_focused_failure",
            "scope_expansion",
            "semantics_ambiguity",
            "unexpected_path",
        ],
    },
    "ceoUpdateFields": ["done", "blocker", "owner", "next", "deadlineConfidence"],
    "deadlineMode": {
        "optionalScopeFrozen": True,
        "oneCriticalPath": True,
        "optionalSlicesExcludedAtCutoff": True,
        "buildAndQAContinue": True,
    },
    "taskIdentity": {
        "exactObsidianAgentTitleRequired": True,
        "genericTitlesAllowed": False,
    },
    "documentedDirectReportCoordinationAllowed": True,
    "aggregateGates": {
        "fullAggregateOncePerChangedCandidate": True,
        "buildOncePerChangedCandidate": True,
        "realAppQAOncePerChangedCandidate": True,
        "rerunOnlyWhenCandidateChangesOrEvidenceIsStale": True,
    },
    "optimizer": {
        "observationMode": "exception_only",
        "routineDelegationReceiptRequiredWhenEligible": False,
        "directRulePatchWhenRepeatedWasteIsProven": True,
    },
    "hardSafety": {
        "explicitPathsRequired": True,
        "preserveUserDirt": True,
        "independentQARequired": True,
        "workerSelfAcceptanceAllowed": False,
        "pushOrReleaseRequiresAuthority": True,
    },
}
EXPECTED_EVENT_REQUIREMENTS = {
    "authority_acknowledged": (
        ["dispatchReceiptHash", "modelRouteHash", "claimHash", "acknowledgedAuthority", "acknowledgedAllowedPaths", "acknowledgedModelEffort"],
        ["NO_CHANGE", "RETURN", "ESCALATE"],
    ),
    "candidate_handoff": (
        ["candidateIdentity", "focusedGateReceiptHash", "allowedPathAudit", "candidateCleanliness", "nextGateOwner", "independentReviewer"],
        ["NO_CHANGE", "RETURN", "ESCALATE"],
    ),
    "claim_or_baseline_mismatch": (
        ["expectedIdentity", "observedIdentity", "mismatch", "preservedWorkState"],
        ["RETURN", "ESCALATE"],
    ),
    "delegation_acknowledgement_failed": (
        ["dispatchReceiptHash", "modelRouteHash", "claimHash", "allowedPathBinding", "acknowledgementDefect"],
        ["RETURN", "ESCALATE"],
    ),
    "delegation_ready_for_dispatch": (
        ["classification", "lowestLegalRoute", "authorityBoundary", "claimHash", "allowedPathBinding", "focusedGateOwner", "fullGateOwner", "independentReviewer", "usefulWorkstreamDelta"],
        ["NO_CHANGE", "RETURN", "ESCALATE"],
    ),
    "dispatch_published": (
        ["dispatchReceiptHash", "modelRouteHash", "claimHash", "authorityCommit", "expectedHead", "assignedModelEffort"],
        ["NO_CHANGE", "RETURN", "ESCALATE"],
    ),
    "duplicate_full_gate_requested": (
        ["candidateIdentity", "priorGateReceiptHash", "priorGateCandidateIdentity", "evidenceStale", "identityChanged"],
        ["NO_CHANGE", "RETURN", "ESCALATE"],
    ),
    "eligible_lane_became_idle": (
        ["lane", "claimState", "readyDisjointWork", "protectedOperation", "refillOrSerializedDependency"],
        ["NO_CHANGE", "REFILL", "ESCALATE"],
    ),
    "exact_candidate_qa_started": (
        ["candidateIdentity", "featureAuthorThread", "qaThread", "independentReviewer", "exclusiveLease", "fullGateOwner"],
        ["NO_CHANGE", "RETURN", "ESCALATE"],
    ),
    "first_focused_gate_failure": (
        ["candidateIdentity", "focusedGate", "failureBoundary", "outsideScope", "preservedCheckpoint"],
        ["NO_CHANGE", "RETURN", "ESCALATE"],
    ),
    "first_return": (
        ["returningReviewer", "returnedCandidate", "preservedEvidence", "defectBoundary", "replacementOrEscalation"],
        ["NO_CHANGE", "REFILL", "RETURN", "ESCALATE"],
    ),
    "frontier_route_assigned": (
        ["classification", "frontierRationale", "authorityBoundary", "lunaDecompositionChecked"],
        ["NO_CHANGE", "PROPOSE", "ESCALATE"],
    ),
    "independent_return_after_focused_pass": (
        ["independentReviewer", "candidateIdentity", "priorFocusedPass", "independentDefect", "unaffectedRowsPreserved", "replacementRouteOrEscalation"],
        ["REFILL", "RETURN", "ESCALATE"],
    ),
    "integration_closed": (
        ["integratedCandidate", "masterCommit", "originParity", "fullGateReceiptHash", "qaDisposition", "nextWaveRefill"],
        ["NO_CHANGE", "REFILL", "RETURN", "ESCALATE"],
    ),
    "model_route_mismatch": (
        ["expectedRouteTuple", "observedRouteTuple", "mismatch", "preservedWorkState"],
        ["RETURN", "ESCALATE"],
    ),
    "no_progress_two_snapshots": (
        ["snapshotA", "snapshotB", "snapshotIntervalSeconds", "durableProgress", "protectedOperation", "refillOrStop"],
        ["NO_CHANGE", "REFILL", "RETURN", "ESCALATE"],
    ),
    "ready_handoff_waiting_for_owner": (
        ["candidateIdentity", "handoffReceiptHash", "waitingOwner", "readySinceBoundary", "protectedOperation", "refillOrSerializedDependency"],
        ["NO_CHANGE", "REFILL", "ESCALATE"],
    ),
    "repeated_context_load_detected": (
        ["threadId", "unchangedAuthorityHash", "unchangedClaimHash", "unchangedSkillHashes", "repeatedFullReadBytes", "compactPacketAvailable"],
        ["NO_CHANGE", "PROPOSE"],
    ),
    "second_unsuccessful_repair": (
        ["attemptOneCandidate", "attemptTwoCandidate", "repeatedOrNewDefect", "preservedEvidence", "frontierEscalation"],
        ["ESCALATE"],
    ),
    "task_completed_or_stopped": (
        ["terminalState", "resultOrStopReason", "commitOrBlockedReason", "evidenceOrBlockedReason", "nextDependencyOrRefill"],
        ["NO_CHANGE", "REFILL", "RETURN", "ESCALATE"],
    ),
    "useful_concurrency_below_floor": (
        ["usefulActiveCount", "minimumUsefulActiveWorkstreams", "protectedOperationsExcluded", "readyDisjointWork", "refillOrSerializedDependency"],
        ["NO_CHANGE", "REFILL", "ESCALATE"],
    ),
    "worktree_or_dispatch_setup_failed_before_mutation": (
        ["expectedWorktreeTuple", "observedWorktreeTuple", "setupDefect", "mutationCount", "preservedWorkState"],
        ["RETURN", "ESCALATE"],
    ),
}

EXPECTED_IMMEDIATE = [
    "delegation_ready_for_dispatch",
    "worktree_or_dispatch_setup_failed_before_mutation",
    "claim_or_baseline_mismatch",
    "delegation_acknowledgement_failed",
    "model_route_mismatch",
    "independent_return_after_focused_pass",
    "second_unsuccessful_repair",
    "exact_candidate_qa_started",
]
EXPECTED_FLUSH = [
    "candidate_handoff",
    "task_completed_or_stopped",
    "ready_handoff_waiting_for_owner",
    "useful_concurrency_below_floor",
    "integration_closed",
]


def validate(policy: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(policy, dict):
        return ["policy must be an object"]
    expected_top = {
        "schema",
        "defaultRoute",
        "eventKeyFields",
        "outcomeFastPath",
        "reviewBudget",
        "reviewScheduling",
        "observerRouteBootstrap",
        "parallelism",
        "falseGreenRecovery",
        "coverage",
        "noProgress",
        "eventRequirements",
        "allowedDecisions",
        "triggers",
    }
    if set(policy) != expected_top:
        errors.append("policy top-level fields must match the exact schema")
    if policy.get("schema") != 4:
        errors.append("schema must be 4")
    if policy.get("defaultRoute") != {
        "classification": "LUNA_MECHANICAL",
        "model": "gpt-5.6-luna",
        "effort": "medium",
    }:
        errors.append("default review route must be Luna mechanical/medium")
    if policy.get("eventKeyFields") != EXPECTED_KEY_FIELDS:
        errors.append("event key fields must be exact and ordered")
    if policy.get("outcomeFastPath") != EXPECTED_OUTCOME_FAST_PATH:
        errors.append("outcome fast path must preserve the exact eligibility, authority, recovery, reporting, deadline, identity, gate, and safety contract")

    budget = policy.get("reviewBudget")
    if not isinstance(budget, dict):
        errors.append("reviewBudget must be an object")
    else:
        if budget.get("maxReviewsPerEventKey") != 1 or budget.get("maxTurns") != 1:
            errors.append("each event is limited to one review and one turn")
        if budget.get("contextMode") != "compact_hash_bound":
            errors.append("review context must be compact and hash-bound")
        if budget.get("maxCompactContextBytes") != 8192:
            errors.append("per-event compact context must be capped at 8192 bytes")
        if budget.get("maxBatchContextBytes") != 32768:
            errors.append("batched compact context must be capped at 32768 bytes")
        if budget.get("threadPollingAllowed") is not False:
            errors.append("thread polling must be forbidden")
        if budget.get("reviewCanSpawnReviews") is not False:
            errors.append("review fan-out must be forbidden")
        if budget.get("receiptMode") != "machine_readable_exception_first":
            errors.append("review receipts must be machine-readable and exception-first")
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

    scheduling = policy.get("reviewScheduling")
    if not isinstance(scheduling, dict) or set(scheduling) != {
        "maxEventsPerTurn",
        "oneReceiptPerEventKey",
        "reuseCanonicalObserverTask",
        "workerMayReadWhileReviewRuns",
        "workerMaySynchronizeWhileReviewRuns",
        "workerMayMutateBeforeImmediateReview",
        "sameManagementTurnFlush",
        "immediateTriggers",
        "flushTriggers",
    }:
        errors.append("reviewScheduling fields must match the exact schema")
    else:
        if scheduling.get("maxEventsPerTurn") != 8:
            errors.append("a review turn may cover at most eight events")
        for key in (
            "oneReceiptPerEventKey",
            "reuseCanonicalObserverTask",
            "workerMayReadWhileReviewRuns",
            "sameManagementTurnFlush",
        ):
            if scheduling.get(key) is not True:
                errors.append(f"{key} must be true")
        if scheduling.get("workerMayMutateBeforeImmediateReview") is not False:
            errors.append("immediate review must complete before worker mutation")
        if scheduling.get("workerMaySynchronizeWhileReviewRuns") is not False:
            errors.append("route-bound worktree identity may not change during immediate review")
        if scheduling.get("immediateTriggers") != EXPECTED_IMMEDIATE:
            errors.append("immediate triggers must be exact and ordered")
        if scheduling.get("flushTriggers") != EXPECTED_FLUSH:
            errors.append("flush triggers must be exact and ordered")

    bootstrap = policy.get("observerRouteBootstrap")
    if bootstrap != {
        "selfReviewAllowed": False,
        "owner": "FRONTIER_AUTHORITY",
        "requiredChecks": [
            "full_schema2_route_validation",
            "exact_git_claim_head_and_path_binding",
            "independent_static_route_review",
            "zero_worker_mutation_before_dispatch",
        ],
        "emitsRecursiveDelegationEvent": False,
    }:
        errors.append("observer route bootstrap must be frontier-owned, non-recursive, and exact")

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

    recovery = policy.get("falseGreenRecovery")
    if not isinstance(recovery, dict):
        errors.append("falseGreenRecovery must be an object")
    else:
        expected_recovery_fields = {
            "sameTurnIntegrationDecision",
            "allowEscalateOnlyFor",
            "requireIndependentReviewer",
            "requirePriorFocusedPass",
            "requireReplacementModelRoute",
            "preserveOtherDirectionRows",
            "fullGateAllowed",
            "dccAllowed",
            "realAppQAAllowed",
            "sharedMutationAllowed",
        }
        if set(recovery) != expected_recovery_fields:
            errors.append("false-green recovery fields must match the exact schema")
        if recovery.get("sameTurnIntegrationDecision") != "REFILL":
            errors.append("false-green recovery must refill in the same turn")
        if recovery.get("allowEscalateOnlyFor") != EXPECTED_FALSE_GREEN_ESCALATIONS:
            errors.append("false-green escalation reasons must be exact and ordered")
        for key in (
            "requireIndependentReviewer",
            "requirePriorFocusedPass",
            "requireReplacementModelRoute",
            "preserveOtherDirectionRows",
        ):
            if recovery.get(key) is not True:
                errors.append(f"{key} must be true")
        for key in (
            "fullGateAllowed",
            "dccAllowed",
            "realAppQAAllowed",
            "sharedMutationAllowed",
        ):
            if recovery.get(key) is not False:
                errors.append(f"false-green {key} must be false")

    coverage = policy.get("coverage")
    if not isinstance(coverage, dict):
        errors.append("coverage must be an object")
    else:
        if set(coverage) != {
            "requiredRowFields",
            "directionWorkstreams",
            "sourceRowsMustProjectExactly",
            "aggregateWithoutRowsAllowed",
            "omissionDecision",
        }:
            errors.append("coverage fields must match the exact schema")
        if coverage.get("requiredRowFields") != EXPECTED_COVERAGE_FIELDS:
            errors.append("coverage row fields must be exact and ordered")
        if coverage.get("directionWorkstreams") != EXPECTED_DIRECTIONS:
            errors.append("direction workstreams must be north/east/south/west in order")
        if coverage.get("sourceRowsMustProjectExactly") is not True:
            errors.append("source rows must project exactly")
        if coverage.get("aggregateWithoutRowsAllowed") is not False:
            errors.append("aggregate summaries without rows must be forbidden")
        if coverage.get("omissionDecision") != "RETURN":
            errors.append("coverage omission must force RETURN")

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

    requirements = policy.get("eventRequirements")
    if not isinstance(requirements, dict) or set(requirements) != EXPECTED_TRIGGERS or set(requirements) != set(EXPECTED_EVENT_REQUIREMENTS):
        errors.append("event requirements must cover every declared trigger exactly")
    else:
        for trigger, (required_evidence, allowed_decisions) in EXPECTED_EVENT_REQUIREMENTS.items():
            rule = requirements.get(trigger)
            if not isinstance(rule, dict) or set(rule) != {"requiredEvidence", "allowedDecisions"}:
                errors.append(f"{trigger} requirement fields must be exact")
                continue
            if rule.get("requiredEvidence") != required_evidence:
                errors.append(f"{trigger} required evidence must be exact and ordered")
            if rule.get("allowedDecisions") != allowed_decisions:
                errors.append(f"{trigger} decisions must be exact and ordered")

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
