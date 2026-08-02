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

    def test_extra_or_missing_trigger_is_rejected(self) -> None:
        self.assert_invalid(lambda p: p["triggers"].pop())
        self.assert_invalid(lambda p: p["triggers"].append("hourly_poll"))

    def test_duplicate_trigger_is_rejected(self) -> None:
        self.assert_invalid(lambda p: p["triggers"].append(p["triggers"][0]))

    def test_review_fanout_is_rejected(self) -> None:
        self.assert_invalid(lambda p: p["reviewBudget"].update({"maxReviewsPerEventKey": 2}))
        self.assert_invalid(lambda p: p["reviewBudget"].update({"maxTurns": 2}))

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


if __name__ == "__main__":
    unittest.main()
