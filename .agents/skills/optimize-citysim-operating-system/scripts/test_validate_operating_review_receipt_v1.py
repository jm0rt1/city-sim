#!/usr/bin/env python3
"""Adversarial tests for schema-4 operating-review receipts."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).with_name("validate_operating_review_receipt_v1.py")
SPEC = importlib.util.spec_from_file_location("operating_receipt_validator", SCRIPT)
assert SPEC and SPEC.loader
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)
ROOT = Path(__file__).resolve().parents[1]
REAL_POLICY = json.loads((ROOT / "references" / "triggered-operating-review-policy.json").read_text(encoding="utf-8"))
H = "a" * 64
C = "b" * 40
POLICY = {
    "schema": 4,
    "defaultRoute": MOD.DEFAULT_ROUTE,
    "eventKeyFields": ["authorityCommit", "taskId", "routeId", "trigger", "candidateOrResultCommit"],
    "triggers": ["first_return", "candidate_handoff"],
    "allowedDecisions": ["NO_CHANGE", "RETURN"],
    "reviewBudget": {
        **{key: False for key in ("productBuildAllowed", "fullGateAllowed", "dccAllowed", "realAppQAAllowed", "sharedMutationAllowed")},
        "maxCompactContextBytes": 8192,
        "maxTurns": 1,
        "threadPollingAllowed": False,
        "reviewCanSpawnReviews": False,
    },
    "coverage": {"requiredRowFields": ["taskId", "routeId", "workstream", "state", "evidenceCommit", "disposition"], "directionWorkstreams": ["north", "east", "south", "west"]},
    "eventRequirements": {
        "first_return": {"requiredEvidence": ["returnReceiptHash"], "allowedDecisions": ["RETURN"]},
        "candidate_handoff": {"requiredEvidence": ["handoffReceiptHash"], "allowedDecisions": ["NO_CHANGE"]},
    },
}


def _evidence(policy: dict, trigger: str) -> dict:
    fields = policy["eventRequirements"][trigger]["requiredEvidence"]
    result = {field: (H if field.lower().endswith("hash") else "bound") for field in fields}
    if trigger == "frontier_route_assigned":
        result.update({"classification": "FRONTIER_AUTHORITY", "lunaDecompositionChecked": True})
    elif trigger == "delegation_ready_for_dispatch":
        result["lowestLegalRoute"] = "LUNA_MECHANICAL"
    elif trigger == "useful_concurrency_below_floor":
        result.update({"usefulActiveCount": 2, "minimumUsefulActiveWorkstreams": 3, "protectedOperationsExcluded": True, "readyDisjointWork": False})
    elif trigger == "duplicate_full_gate_requested":
        result.update({"identityChanged": True, "evidenceStale": False})
    elif trigger == "worktree_or_dispatch_setup_failed_before_mutation":
        result["mutationCount"] = 0
    elif trigger == "candidate_handoff":
        result["candidateCleanliness"] = "clean"
    elif trigger == "exact_candidate_qa_started":
        result.update({"featureAuthorThread": "author", "qaThread": "qa", "independentReviewer": "qa"})
    return result


def receipt(*, trigger="first_return", policy=POLICY, multi=False):
    event = {"authorityCommit": C, "taskId": "PLAY-089", "routeId": "route", "trigger": trigger, "candidateOrResultCommit": C}
    decision = policy["eventRequirements"][trigger]["allowedDecisions"][0]
    result = {
        "schema": 4,
        "policySha256": H,
        "modelRoute": copy.deepcopy(MOD.DEFAULT_ROUTE),
        "eventKey": event,
        "binding": {
            "dispatchReceiptPath": "receipt.json",
            "dispatchReceiptHash": H,
            "modelRouteHash": H,
            "claimPath": "claim.md",
            "claimHash": H,
            "expectedHead": C,
            "allowedPaths": ["docs/production/evidence/PLAY-089/"],
        },
        "decision": decision,
        "compactContext": {"mode": "compact_hash_bound", "hashes": {"authority": H}, "bytes": 128},
        "inputReceipts": [{"path": "receipt.json", "sha256": H}, {"path": "claim.md", "sha256": H}],
        "nextAction": {"action": "record", "owner": "integration", "boundedDeliverable": "one receipt", "stopCondition": "receipt published"},
        "prohibitedWork": {key: False for key in ("productBuildAllowed", "fullGateAllowed", "dccAllowed", "realAppQAAllowed", "sharedMutationAllowed")},
        "reviewOperations": {"threadPolling": False, "spawnedReviews": False},
        "operationKinds": ["read_receipt", "assemble_receipt"],
        "metrics": {"elapsedSeconds": None, "turns": 1},
        "evidence": _evidence(policy, trigger),
        "multiLane": multi,
        "sourceCoverage": None,
    }
    if multi:
        result["sourceCoverage"] = [{"taskId": "PLAY-027", "routeId": f"r-{direction}", "workstream": direction, "state": "active", "evidenceCommit": C, "disposition": "NO_CHANGE"} for direction in policy["coverage"]["directionWorkstreams"]]
    return result


class OperatingReceiptTests(unittest.TestCase):
    def assert_invalid(self, mutate, *, multi=False, ledger=None):
        candidate = receipt(multi=multi)
        mutate(candidate)
        self.assertTrue(MOD.validate(candidate, POLICY, H, {"schema": 1, "receipts": []} if ledger is None else ledger))

    def test_valid_minimal(self):
        self.assertEqual(MOD.validate(receipt(), POLICY, H, {"schema": 1, "receipts": []}), [])

    def test_every_declared_trigger_has_a_valid_receipt_shape(self):
        for trigger in REAL_POLICY["triggers"]:
            with self.subTest(trigger=trigger):
                candidate = receipt(trigger=trigger, policy=REAL_POLICY)
                policy_hash = hashlib.sha256((ROOT / "references" / "triggered-operating-review-policy.json").read_bytes()).hexdigest()
                candidate["policySha256"] = policy_hash
                self.assertEqual(MOD.validate(candidate, REAL_POLICY, policy_hash, {"schema": 1, "receipts": []}), [])

    def test_schema_and_top_level_fields_are_exact(self):
        self.assert_invalid(lambda r: r.pop("schema"))
        self.assert_invalid(lambda r: r.__setitem__("invented", True))

    def test_wrong_policy_hash(self):
        self.assert_invalid(lambda r: r.__setitem__("policySha256", "b" * 64))

    def test_sol_route(self):
        self.assert_invalid(lambda r: r["modelRoute"].__setitem__("model", "gpt-5.6-sol"))

    def test_missing_trigger_evidence(self):
        self.assert_invalid(lambda r: r["evidence"].clear())

    def test_invented_or_over_budget_metric(self):
        self.assert_invalid(lambda r: r["metrics"].__setitem__("tokenCost", "cheap"))
        self.assert_invalid(lambda r: r["metrics"].__setitem__("turns", 2))
        self.assert_invalid(lambda r: r["metrics"].__setitem__("elapsedSeconds", -1))

    def test_prohibited_work_and_operation_kind(self):
        self.assert_invalid(lambda r: r["prohibitedWork"].__setitem__("dccAllowed", True))
        self.assert_invalid(lambda r: r["operationKinds"].append("run_full_swift_suite"))

    def test_coverage_omission(self):
        self.assert_invalid(lambda r: r.__setitem__("sourceCoverage", []), multi=True)

    def test_ledger_is_mandatory_and_deduplicated(self):
        self.assertTrue(MOD.validate(receipt(), POLICY, H, None))
        existing = {"schema": 1, "receipts": [{"eventKey": receipt()["eventKey"]}]}
        self.assertTrue(MOD.validate(receipt(), POLICY, H, existing))
        duplicate_inside = {"schema": 1, "receipts": [{"eventKey": {"a": 1}}, {"eventKey": {"a": 1}}]}
        self.assertTrue(MOD.validate(receipt(), POLICY, H, duplicate_inside))

    def test_context_cap_and_review_fanout(self):
        self.assert_invalid(lambda r: r["compactContext"].__setitem__("bytes", 8193))
        self.assert_invalid(lambda r: r["reviewOperations"].__setitem__("threadPolling", True))
        self.assert_invalid(lambda r: r["reviewOperations"].__setitem__("spawnedReviews", True))

    def test_trigger_specific_decision_is_enforced(self):
        self.assert_invalid(lambda r: r.__setitem__("decision", "NO_CHANGE"))

    def test_input_receipt_bytes_are_verified(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "receipt.json"
            source.write_text("bound\n", encoding="utf-8")
            claim = root / "claim.md"
            claim.write_text("claim\n", encoding="utf-8")
            candidate = receipt()
            candidate["inputReceipts"][0]["sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
            candidate["binding"]["dispatchReceiptHash"] = candidate["inputReceipts"][0]["sha256"]
            candidate["inputReceipts"][1]["sha256"] = hashlib.sha256(claim.read_bytes()).hexdigest()
            candidate["binding"]["claimHash"] = candidate["inputReceipts"][1]["sha256"]
            self.assertEqual(MOD.validate(candidate, POLICY, H, {"schema": 1, "receipts": []}, root), [])
            candidate["inputReceipts"][0]["sha256"] = H
            self.assertTrue(MOD.validate(candidate, POLICY, H, {"schema": 1, "receipts": []}, root))
            candidate["inputReceipts"][0]["path"] = "../outside"
            self.assertTrue(MOD.validate(candidate, POLICY, H, {"schema": 1, "receipts": []}, root))

    def test_semantic_contradictions_fail(self):
        policy_hash = hashlib.sha256((ROOT / "references" / "triggered-operating-review-policy.json").read_bytes()).hexdigest()
        frontier = receipt(trigger="frontier_route_assigned", policy=REAL_POLICY)
        frontier["policySha256"] = policy_hash
        frontier["evidence"]["classification"] = "LUNA_MECHANICAL"
        self.assertTrue(MOD.validate(frontier, REAL_POLICY, policy_hash, {"schema": 1, "receipts": []}))
        concurrency = receipt(trigger="useful_concurrency_below_floor", policy=REAL_POLICY)
        concurrency["policySha256"] = policy_hash
        concurrency["evidence"]["usefulActiveCount"] = 3
        self.assertTrue(MOD.validate(concurrency, REAL_POLICY, policy_hash, {"schema": 1, "receipts": []}))

    def test_route_projection_rejects_skeletal_route(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            route = {
                "authority": {"claim": {"path": "claim.md", "sha256": H}},
                "assignment": {"expectedHead": C, "featureAuthorThreadId": "worker"},
                "pathPolicy": {"allowed": ["owned/path"]},
                "validation": {
                    "focusedGateOwner": {"threadId": "worker"},
                    "fullGateOwner": {"threadId": "integration"},
                },
                "independentReviewer": {"required": True, "threadId": "integration"},
            }
            route_hash = MOD._canonical_sha256(route)
            dispatch = {"schema": 2, "assignments": [{"modelRouteSha256": route_hash, "modelRoute": route}]}
            (root / "dispatch.json").write_text(json.dumps(dispatch), encoding="utf-8")
            binding = {
                "dispatchReceiptPath": "dispatch.json",
                "dispatchReceiptHash": hashlib.sha256((root / "dispatch.json").read_bytes()).hexdigest(),
                "modelRouteHash": route_hash,
                "claimPath": "claim.md",
                "claimHash": H,
                "expectedHead": C,
                "allowedPaths": ["owned/path"],
            }
            errors = MOD._route_projection_errors(binding, root)
            self.assertTrue(any("schema-2 route" in error or "validator is unavailable" in error for error in errors))

    def test_required_repo_root_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIn(
                "authority root must be the exact root of a Git repository",
                MOD.validate(receipt(), POLICY, H, {"schema": 1, "receipts": []}, Path(tmp), require_git_repo=True),
            )

    def test_route_projection_binds_exact_output_worktree(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as assigned_tmp, tempfile.TemporaryDirectory() as wrong_tmp:
            authority = Path(authority_tmp)
            route = {
                "authority": {"claim": {"path": "claim.md", "sha256": H}},
                "assignment": {"expectedHead": C, "featureAuthorThreadId": "worker", "worktree": assigned_tmp},
                "pathPolicy": {"allowed": ["owned/path"]},
                "validation": {"focusedGateOwner": {"threadId": "worker"}, "fullGateOwner": {"threadId": "integration"}},
                "independentReviewer": {"required": True, "threadId": "integration"},
            }
            route_hash = MOD._canonical_sha256(route)
            dispatch = {"schema": 2, "assignments": [{"modelRouteSha256": route_hash, "modelRoute": route}]}
            (authority / "dispatch.json").write_text(json.dumps(dispatch), encoding="utf-8")
            binding = {
                "dispatchReceiptPath": "dispatch.json", "dispatchReceiptHash": hashlib.sha256((authority / "dispatch.json").read_bytes()).hexdigest(),
                "modelRouteHash": route_hash, "claimPath": "claim.md", "claimHash": H,
                "expectedHead": C, "allowedPaths": ["owned/path"],
            }
            errors = MOD._route_projection_errors(binding, authority, output_root=Path(wrong_tmp))
            self.assertIn("worker/output root must exactly match the model route worktree", errors)

    def test_receipt_path_cannot_escape_output_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertTrue(MOD._confined_path(root, "../receipt.json", "receipt")[1])

    def test_output_identity_rejects_wrong_branch_and_unrelated_head(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            subprocess.run(["git", "init", str(root)], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(root), "checkout", "-b", "codex/correct"], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(root), "config", "user.email", "test@example.com"], check=True)
            subprocess.run(["git", "-C", str(root), "config", "user.name", "Test"], check=True)
            (root / "file").write_text("one\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(root), "add", "file"], check=True)
            subprocess.run(["git", "-C", str(root), "commit", "-m", "base"], check=True, capture_output=True)
            head = subprocess.run(
                ["git", "-C", str(root), "rev-parse", "HEAD"], check=True, capture_output=True, text=True
            ).stdout.strip()
            wrong_branch = MOD._output_identity_errors(
                root, {"branch": "codex/wrong", "expectedHead": head}
            )
            self.assertIn("live worker/output branch must exactly match the model route branch", wrong_branch)
            unrelated = MOD._output_identity_errors(
                root, {"branch": "codex/correct", "expectedHead": "f" * 40}
            )
            self.assertIn("model route expected HEAD must be an ancestor of live worker/output HEAD", unrelated)

    def test_observer_route_owns_output_without_replacing_observed_binding(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as output_tmp:
            authority = Path(authority_tmp)
            output = Path(output_tmp)
            subprocess.run(["git", "init", str(output)], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(output), "checkout", "-b", "codex/citysim-os-optimization"], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(output), "config", "user.email", "test@example.com"], check=True)
            subprocess.run(["git", "-C", str(output), "config", "user.name", "Test"], check=True)
            (output / "file").write_text("one\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(output), "add", "file"], check=True)
            subprocess.run(["git", "-C", str(output), "commit", "-m", "base"], check=True, capture_output=True)
            head = subprocess.run(["git", "-C", str(output), "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
            route = {
                "routeId": "observer-route",
                "taskId": "PLAY-089",
                "classification": "LUNA_MECHANICAL",
                "model": "gpt-5.6-luna",
                "effort": "medium",
                "assignment": {"worktree": str(output), "branch": "codex/citysim-os-optimization", "expectedHead": head},
                "pathPolicy": {"allowed": ["docs/production/evidence/PLAY-089/review"]},
            }
            (authority / "dispatch.json").write_text(json.dumps({"assignments": [{"modelRoute": route}]}), encoding="utf-8")
            validator = mock.Mock()
            validator.validate_dispatch.return_value = []
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                allowed, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertEqual(errors, [])
            self.assertEqual(allowed, ["docs/production/evidence/PLAY-089/review"])
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-090/escape.json"],
                )
            self.assertTrue(any("outside its exact route" in error for error in errors))

    def test_phantom_ledger_receipt_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "receipt.json").write_text("bound\n", encoding="utf-8")
            (root / "claim.md").write_text("claim\n", encoding="utf-8")
            candidate = receipt()
            for item in candidate["inputReceipts"]:
                item["sha256"] = hashlib.sha256((root / item["path"]).read_bytes()).hexdigest()
            candidate["binding"]["dispatchReceiptHash"] = candidate["inputReceipts"][0]["sha256"]
            candidate["binding"]["claimHash"] = candidate["inputReceipts"][1]["sha256"]
            phantom = {
                "schema": 1,
                "receipts": [{
                    "eventKey": {**candidate["eventKey"], "routeId": "prior"},
                    "receiptPath": "missing.json",
                    "receiptSha256": H,
                    "decision": "RETURN",
                    "disposition": {"status": "deferred", "authorityCommit": None, "reason": "waiting"},
                }],
            }
            self.assertTrue(MOD.validate(candidate, POLICY, H, phantom, root))


if __name__ == "__main__":
    unittest.main()
