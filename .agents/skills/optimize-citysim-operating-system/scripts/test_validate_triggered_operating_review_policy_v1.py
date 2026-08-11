#!/usr/bin/env python3
"""Adversarial tests for the triggered operating-review policy."""

from __future__ import annotations

import copy
import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POLICY = json.loads((ROOT / "references" / "triggered-operating-review-policy.json").read_text(encoding="utf-8"))
SPEC = importlib.util.spec_from_file_location("trigger_policy_validator", Path(__file__).with_name("validate_triggered_operating_review_policy_v1.py"))
VALIDATOR = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(VALIDATOR)


class TriggeredOperatingReviewPolicyTests(unittest.TestCase):
    def assert_invalid(self, mutate) -> None:
        candidate = copy.deepcopy(POLICY)
        mutate(candidate)
        self.assertTrue(VALIDATOR.validate(candidate))

    def test_published_policy_passes(self) -> None:
        self.assertEqual(VALIDATOR.validate(POLICY), [])

    def test_frontier_default_is_rejected(self) -> None:
        self.assert_invalid(lambda p: p["defaultRoute"].update({"model": "gpt-5.6-sol"}))

    def test_outcome_lease_is_narrow_and_complete(self) -> None:
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["eligibility"].update({"validatedSchema2ClaimRouteAndSelectedDispatch": False})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["eligibility"].update({"judgmentBoundaryPresent": True})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["eligibility"].update({"reversibleLocalWorkOnly": False})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["eligibility"].update({"protectedUserDirtMustRemainUnchanged": False})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["authorizedActions"].append("push")
        )

    def test_outcome_lease_removes_only_eligible_routine_rounds(self) -> None:
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["separateRoundsRequiredWithinEligibility"].update({"ackOnly": True})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["manualCtoReviewBoundaries"].remove("candidate_acceptance")
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["optimizer"].update({"observationMode": "every_delegation"})
        )

    def test_allowed_paths_are_a_maximum_boundary_not_a_touch_minimum(self) -> None:
        contract = "pathScopeContract"
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][contract].update({"allowedPathsAreMaximumMutationBoundary": False})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][contract].update({"minimumTouchedPathCountRequired": True})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][contract].update({"predictedPathCountIsMutationMinimum": True})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][contract].update({"manufacturedNoOpEditsAllowed": True})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][contract].update(
                {"fewerChangedPathsAllowedWhenDeliverableAndFocusedProofPass": False}
            )
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][contract].update({"everyChangedPathMustBeInAllowlist": False})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][contract].update({"extraOrUnexpectedPathDecision": "RETURN"})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][contract].update({"exactChangedPathStagingAndProofRequired": False})
        )

    def test_exact_command_recovery_is_one_pre_mutation_retry(self) -> None:
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["exactCommandRecovery"].update({"maxIdenticalRetries": 2})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["exactCommandRecovery"].update({"requiresZeroMutation": False})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["exactCommandRecovery"]["allowedFailureClasses"].append("test_failure")
        )

    def test_corrected_mechanical_action_is_single_audited_and_distinct(self) -> None:
        recovery = "correctedMechanicalActionRecovery"
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][recovery].update({"maxCorrectedMechanicalActions": 2})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][recovery].update({"requiresExactPostFailureAudit": False})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][recovery]["auditMustProve"].update(
                {"zeroOutOfAllowlistMutation": False}
            )
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][recovery]["auditMustProve"].update(
                {"noCompletedProductOrProofActionReplayed": False}
            )
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][recovery]["auditMustProve"].update(
                {"noSemanticsOrDataNondeterminism": False}
            )
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][recovery].update({"countsAgainstFocusedProofAttempts": True})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"][recovery]["stopOn"].remove("outcome_or_path_change")
        )

    def test_temp_carrier_and_local_repair_are_bounded(self) -> None:
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["carrierRules"].update({"durablePublicationRequiredAtJudgmentBoundary": False})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["boundedLocalRepair"].update({"maxFocusedProofAttempts": 3})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["boundedLocalRepair"].update({"allowlistMayExpand": True})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["boundedLocalRepair"]["escalateOn"].remove("semantics_ambiguity")
        )

    def test_fast_path_preserves_reporting_identity_deadline_and_safety(self) -> None:
        self.assert_invalid(lambda p: p["outcomeFastPath"]["ceoUpdateFields"].append("hashLedger"))
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["taskIdentity"].update({"genericTitlesAllowed": True})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["deadlineMode"].update({"oneCriticalPath": False})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["hardSafety"].update({"workerSelfAcceptanceAllowed": True})
        )
        self.assert_invalid(
            lambda p: p["outcomeFastPath"]["aggregateGates"].update({"fullAggregateOncePerChangedCandidate": False})
        )

    def test_extra_or_missing_trigger_is_rejected(self) -> None:
        self.assert_invalid(lambda p: p["triggers"].pop())
        self.assert_invalid(lambda p: p["triggers"].append("hourly_poll"))

    def test_duplicate_trigger_is_rejected(self) -> None:
        self.assert_invalid(lambda p: p["triggers"].append(p["triggers"][0]))

    def test_review_fanout_is_rejected(self) -> None:
        self.assert_invalid(lambda p: p["reviewBudget"].update({"maxReviewsPerEventKey": 2}))
        self.assert_invalid(lambda p: p["reviewBudget"].update({"maxTurns": 2}))
        self.assert_invalid(lambda p: p["reviewBudget"].update({"reviewCanSpawnReviews": True}))

    def test_review_stays_compact_and_event_driven(self) -> None:
        self.assert_invalid(lambda p: p["reviewBudget"].update({"maxCompactContextBytes": 131072}))
        self.assert_invalid(lambda p: p["reviewBudget"].update({"maxBatchContextBytes": 131072}))
        self.assert_invalid(lambda p: p["reviewBudget"].update({"threadPollingAllowed": True}))
        self.assert_invalid(lambda p: p["reviewBudget"].update({"receiptMode": "narrative"}))

    def test_review_batching_is_bounded_and_nonblocking_only_for_safe_prelude(self) -> None:
        self.assert_invalid(lambda p: p["reviewScheduling"].update({"maxEventsPerTurn": 32}))
        self.assert_invalid(lambda p: p["reviewScheduling"].update({"oneReceiptPerEventKey": False}))
        self.assert_invalid(lambda p: p["reviewScheduling"].update({"workerMayMutateBeforeImmediateReview": True}))
        self.assert_invalid(lambda p: p["reviewScheduling"].update({"workerMaySynchronizeWhileReviewRuns": True}))
        self.assert_invalid(lambda p: p["reviewScheduling"]["immediateTriggers"].remove("delegation_ready_for_dispatch"))
        self.assert_invalid(lambda p: p["reviewScheduling"]["flushTriggers"].remove("integration_closed"))

    def test_observer_route_bootstrap_cannot_review_itself(self) -> None:
        self.assert_invalid(lambda p: p["observerRouteBootstrap"].update({"selfReviewAllowed": True}))
        self.assert_invalid(lambda p: p["observerRouteBootstrap"].update({"owner": "LUNA_MECHANICAL"}))
        self.assert_invalid(lambda p: p["observerRouteBootstrap"].update({"emitsRecursiveDelegationEvent": True}))
        self.assert_invalid(lambda p: p["observerRouteBootstrap"]["requiredChecks"].remove("independent_static_route_review"))

    def test_expensive_or_mutating_observation_is_rejected(self) -> None:
        for field in ("productBuildAllowed", "fullGateAllowed", "dccAllowed", "realAppQAAllowed", "sharedMutationAllowed"):
            with self.subTest(field=field):
                self.assert_invalid(lambda p, key=field: p["reviewBudget"].update({key: True}))

    def test_parallelism_guardrails_are_required(self) -> None:
        self.assert_invalid(lambda p: p["parallelism"].update({"minimumUsefulActiveWorkstreams": 1}))
        self.assert_invalid(lambda p: p["parallelism"].update({"sameTurnRefillRequired": False}))
        self.assert_invalid(lambda p: p["parallelism"].update({"manufacturedBusyworkAllowed": True}))

    def test_false_green_requires_same_turn_refill(self) -> None:
        self.assert_invalid(lambda p: p["falseGreenRecovery"].update({"sameTurnIntegrationDecision": "PROPOSE"}))
        self.assert_invalid(lambda p: p["falseGreenRecovery"].update({"requireReplacementModelRoute": False}))

    def test_false_green_preserves_independence_and_siblings(self) -> None:
        self.assert_invalid(lambda p: p["falseGreenRecovery"].update({"requireIndependentReviewer": False}))
        self.assert_invalid(lambda p: p["falseGreenRecovery"].update({"preserveOtherDirectionRows": False}))

    def test_false_green_observer_cannot_run_expensive_gates_or_mutate(self) -> None:
        for field in ("fullGateAllowed", "dccAllowed", "realAppQAAllowed", "sharedMutationAllowed"):
            with self.subTest(field=field):
                self.assert_invalid(lambda p, key=field: p["falseGreenRecovery"].update({key: True}))

    def test_false_green_escalation_reasons_are_closed(self) -> None:
        self.assert_invalid(lambda p: p["falseGreenRecovery"]["allowEscalateOnlyFor"].append("worker_prefers_frontier"))

    def test_coverage_cannot_hide_a_lane_or_direction(self) -> None:
        self.assert_invalid(lambda p: p["coverage"]["directionWorkstreams"].remove("east"))
        self.assert_invalid(lambda p: p["coverage"].update({"sourceRowsMustProjectExactly": False}))
        self.assert_invalid(lambda p: p["coverage"].update({"aggregateWithoutRowsAllowed": True}))
        self.assert_invalid(lambda p: p["coverage"].update({"omissionDecision": "NO_CHANGE"}))

    def test_coverage_row_schema_is_exact(self) -> None:
        self.assert_invalid(lambda p: p["coverage"]["requiredRowFields"].remove("routeId"))
        self.assert_invalid(lambda p: p["coverage"]["requiredRowFields"].append("summary"))

    def test_no_progress_requires_two_bounded_snapshots_and_exceptions(self) -> None:
        self.assert_invalid(lambda p: p["noProgress"].update({"consecutiveSnapshots": 1}))
        self.assert_invalid(lambda p: p["noProgress"]["protectedActiveOperations"].pop())

    def test_event_key_is_exact_and_deduplicating(self) -> None:
        self.assert_invalid(lambda p: p["eventKeyFields"].remove("candidateOrResultCommit"))
        self.assert_invalid(lambda p: p["eventKeyFields"].reverse())

    def test_unknown_metrics_remain_null(self) -> None:
        self.assert_invalid(lambda p: p["reviewBudget"].update({"missingMetricValue": 0}))

    def test_management_event_requirements_are_fail_closed(self) -> None:
        self.assertEqual(set(POLICY["eventRequirements"]), set(POLICY["triggers"]))
        for trigger in VALIDATOR.EXPECTED_EVENT_REQUIREMENTS:
            with self.subTest(trigger=trigger):
                self.assert_invalid(lambda p, key=trigger: p["eventRequirements"].pop(key))

    def test_frontier_route_review_cannot_self_return_or_refill(self) -> None:
        self.assert_invalid(
            lambda p: p["eventRequirements"]["frontier_route_assigned"]["allowedDecisions"].append("REFILL")
        )
        self.assert_invalid(
            lambda p: p["eventRequirements"]["frontier_route_assigned"]["requiredEvidence"].remove("frontierRationale")
        )

    def test_terminal_and_concurrency_reviews_require_next_work(self) -> None:
        self.assert_invalid(
            lambda p: p["eventRequirements"]["task_completed_or_stopped"]["requiredEvidence"].remove("nextDependencyOrRefill")
        )
        self.assert_invalid(
            lambda p: p["eventRequirements"]["useful_concurrency_below_floor"]["requiredEvidence"].remove("refillOrSerializedDependency")
        )

    def test_duplicate_full_gate_review_binds_candidate_identity(self) -> None:
        self.assert_invalid(
            lambda p: p["eventRequirements"]["duplicate_full_gate_requested"]["requiredEvidence"].remove("candidateIdentity")
        )
        self.assert_invalid(
            lambda p: p["eventRequirements"]["duplicate_full_gate_requested"]["requiredEvidence"].remove("identityChanged")
        )

    def test_repeated_context_and_failed_ack_need_exact_proof(self) -> None:
        self.assert_invalid(
            lambda p: p["eventRequirements"]["repeated_context_load_detected"]["requiredEvidence"].remove("unchangedSkillHashes")
        )
        self.assert_invalid(
            lambda p: p["eventRequirements"]["delegation_acknowledgement_failed"]["requiredEvidence"].remove("modelRouteHash")
        )

    def test_outcome_fast_path_is_documented_across_authority_surfaces(self) -> None:
        repo_root = ROOT.parents[2]
        surfaces = {
            "optimizer skill": (ROOT / "SKILL.md").read_text(encoding="utf-8"),
            "optimizer protocol": (ROOT / "references" / "observation-and-upgrade-protocol.md").read_text(encoding="utf-8"),
            "routing contract": (
                ROOT.parent / "operate-citysim-integration" / "references" / "model-routing-and-cost-control.md"
            ).read_text(encoding="utf-8"),
            "worktree operating system": (
                repo_root / "docs" / "production" / "CITYSIM_WORKTREE_OPERATING_SYSTEM.md"
            ).read_text(encoding="utf-8"),
        }
        required_phrases = (
            "outcome lease",
            "maximum mutation boundary",
            "one identical retry",
            "corrected mechanical action",
            "deadline confidence",
            "Obsidian agent note",
            "once per changed candidate",
        )
        for label, text in surfaces.items():
            for phrase in required_phrases:
                with self.subTest(surface=label, phrase=phrase):
                    self.assertIn(phrase, text)


if __name__ == "__main__":
    unittest.main()
