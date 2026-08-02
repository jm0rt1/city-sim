#!/usr/bin/env python3
"""Adversarial tests for schema-3 operating-review receipts."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("validate_operating_review_receipt_v1.py")
SPEC = importlib.util.spec_from_file_location("operating_receipt_validator", SCRIPT)
assert SPEC and SPEC.loader
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)
H = "a" * 64
POLICY = {
    "schema": 3,
    "defaultRoute": MOD.DEFAULT_ROUTE,
    "eventKeyFields": ["authorityCommit", "taskId", "routeId", "trigger", "candidateOrResultCommit"],
    "triggers": ["first_return", "candidate_handoff"],
    "allowedDecisions": ["NO_CHANGE", "RETURN"],
    "reviewBudget": {
        **{key: False for key in ("productBuildAllowed", "fullGateAllowed", "dccAllowed", "realAppQAAllowed", "sharedMutationAllowed")},
        "maxCompactContextBytes": 32768,
        "threadPollingAllowed": False,
        "reviewCanSpawnReviews": False,
    },
    "coverage": {"requiredRowFields": ["taskId", "routeId", "workstream", "state", "evidenceCommit", "disposition"], "directionWorkstreams": ["north", "east", "south", "west"]},
    "eventRequirements": {
        "first_return": {"requiredEvidence": ["returnReceipt"], "allowedDecisions": ["RETURN"]},
        "candidate_handoff": {"requiredEvidence": ["handoffReceipt"], "allowedDecisions": ["NO_CHANGE"]},
    },
}


def receipt(*, multi=False):
    event = {"authorityCommit": "base", "taskId": "PLAY-089", "routeId": "route", "trigger": "first_return", "candidateOrResultCommit": "candidate"}
    result = {"policySha256": H, "modelRoute": copy.deepcopy(MOD.DEFAULT_ROUTE), "eventKey": event, "decision": "RETURN", "compactContext": {"mode": "compact_hash_bound", "hashes": {"authority": H}, "bytes": 128}, "inputReceipts": [{"path": "receipt.json", "sha256": H}], "nextAction": {"action": "return", "owner": "integration", "boundedDeliverable": "one route", "stopCondition": "receipt published"}, "prohibitedWork": {key: False for key in ("productBuildAllowed", "fullGateAllowed", "dccAllowed", "realAppQAAllowed", "sharedMutationAllowed")}, "reviewOperations": {"threadPolling": False, "spawnedReviews": False}, "metrics": {"elapsedSeconds": None, "turns": 1}, "evidence": {"returnReceipt": H}, "multiLane": multi, "sourceCoverage": None}
    if multi:
        result["sourceCoverage"] = [{"taskId": "PLAY-027", "routeId": f"r-{direction}", "workstream": direction, "state": "active", "evidenceCommit": "abc", "disposition": "RETURN"} for direction in POLICY["coverage"]["directionWorkstreams"]]
    return result


class OperatingReceiptTests(unittest.TestCase):
    def assert_invalid(self, mutate, *, multi=False, ledger=None):
        candidate = receipt(multi=multi)
        mutate(candidate)
        self.assertTrue(MOD.validate(candidate, POLICY, H, ledger))

    def test_valid_minimal(self):
        self.assertEqual(MOD.validate(receipt(), POLICY, H), [])

    def test_wrong_policy_hash(self):
        self.assert_invalid(lambda r: r.__setitem__("policySha256", "b" * 64))

    def test_sol_route(self):
        self.assert_invalid(lambda r: r["modelRoute"].__setitem__("model", "gpt-5.6-sol"))

    def test_missing_trigger_evidence(self):
        self.assert_invalid(lambda r: r["evidence"].clear())

    def test_invented_metric(self):
        self.assert_invalid(lambda r: r["metrics"].__setitem__("tokenCost", "cheap"))

    def test_prohibited_work(self):
        self.assert_invalid(lambda r: r["prohibitedWork"].__setitem__("dccAllowed", True))

    def test_coverage_omission(self):
        self.assert_invalid(lambda r: r.__setitem__("sourceCoverage", []), multi=True)

    def test_duplicate_event_key(self):
        existing = {"receipts": [{"eventKey": receipt()["eventKey"]}]}
        self.assertTrue(MOD.validate(receipt(), POLICY, H, existing))

    def test_context_cap_and_review_fanout(self):
        self.assert_invalid(lambda r: r["compactContext"].__setitem__("bytes", 32769))
        self.assert_invalid(lambda r: r["reviewOperations"].__setitem__("threadPolling", True))
        self.assert_invalid(lambda r: r["reviewOperations"].__setitem__("spawnedReviews", True))

    def test_trigger_specific_decision_is_enforced(self):
        self.assert_invalid(lambda r: r.__setitem__("decision", "NO_CHANGE"))


if __name__ == "__main__":
    unittest.main()
