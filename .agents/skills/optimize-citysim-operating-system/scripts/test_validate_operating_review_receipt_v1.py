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
REPO_ROOT = Path(__file__).resolve().parents[4]
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


def _binding_for_dispatch(repo_root: Path, dispatch_path: str) -> dict:
    dispatch_file = repo_root / dispatch_path
    dispatch = json.loads(dispatch_file.read_text(encoding="utf-8"))
    row = dispatch["assignments"][0]
    route = row["modelRoute"]
    claim = route["authority"]["claim"]
    return {
        "dispatchReceiptPath": dispatch_path,
        "dispatchReceiptHash": hashlib.sha256(dispatch_file.read_bytes()).hexdigest(),
        "modelRouteHash": row["modelRouteSha256"],
        "claimPath": claim["path"],
        "claimHash": claim["sha256"],
        "expectedHead": route["assignment"]["expectedHead"],
        "allowedPaths": route["pathPolicy"]["allowed"],
    }


def _init_git_repo(root: Path, branch: str = "codex/observed") -> tuple[str, str]:
    subprocess.run(["git", "init", str(root)], check=True, capture_output=True)
    subprocess.run(["git", "-C", str(root), "checkout", "-b", branch], check=True, capture_output=True)
    subprocess.run(["git", "-C", str(root), "config", "user.email", "test@example.com"], check=True)
    subprocess.run(["git", "-C", str(root), "config", "user.name", "Test"], check=True)
    source = root / "file"
    source.write_text("base\n", encoding="utf-8")
    subprocess.run(["git", "-C", str(root), "add", "file"], check=True)
    subprocess.run(["git", "-C", str(root), "commit", "-m", "base"], check=True, capture_output=True)
    base = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    source.write_text("descendant\n", encoding="utf-8")
    subprocess.run(["git", "-C", str(root), "add", "file"], check=True)
    subprocess.run(["git", "-C", str(root), "commit", "-m", "descendant"], check=True, capture_output=True)
    head = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    return base, head


def _write_projection_dispatch(
    authority_root: Path,
    worktree: str | None,
    branch: str,
    expected_head: str,
) -> tuple[dict, dict]:
    assignment = {
        "expectedHead": expected_head,
        "featureAuthorThreadId": "worker",
        "branch": branch,
    }
    if worktree is not None:
        assignment["worktree"] = worktree
    route = {
        "authority": {"claim": {"path": "claim.md", "sha256": H}},
        "assignment": assignment,
        "pathPolicy": {"allowed": ["owned/path"]},
        "validation": {
            "focusedGateOwner": {"threadId": "worker"},
            "fullGateOwner": {"threadId": "integration"},
        },
        "independentReviewer": {"required": True, "threadId": "integration"},
    }
    route_hash = MOD._canonical_sha256(route)
    dispatch = {
        "schema": 2,
        "assignments": [{"modelRouteSha256": route_hash, "modelRoute": route}],
    }
    dispatch_path = authority_root / "dispatch.json"
    dispatch_path.write_text(json.dumps(dispatch), encoding="utf-8")
    binding = {
        "dispatchReceiptPath": "dispatch.json",
        "dispatchReceiptHash": hashlib.sha256(dispatch_path.read_bytes()).hexdigest(),
        "modelRouteHash": route_hash,
        "claimPath": "claim.md",
        "claimHash": H,
        "expectedHead": expected_head,
        "allowedPaths": ["owned/path"],
    }
    return route, binding


def _write_observer_dispatch(
    authority_root: Path,
    worktree: str,
    branch: str,
    expected_head: str,
    *,
    route_id: str = "observer-route",
    authority_commit: str = C,
) -> tuple[dict, dict]:
    route = {
        "routeId": route_id,
        "taskId": "PLAY-089",
        "classification": "LUNA_MECHANICAL",
        "model": "gpt-5.6-luna",
        "effort": "medium",
        "authority": {"authorityCommit": authority_commit},
        "assignment": {
            "worktree": worktree,
            "branch": branch,
            "expectedHead": expected_head,
        },
        "pathPolicy": {"allowed": ["docs/production/evidence/PLAY-089/review"]},
    }
    route_hash = MOD._canonical_sha256(route)
    dispatch = {
        "schema": 2,
        "authorityCommit": authority_commit,
        "assignments": [{"modelRouteSha256": route_hash, "modelRoute": route}],
    }
    (authority_root / "dispatch.json").write_text(json.dumps(dispatch), encoding="utf-8")
    return dispatch, route


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
            base, _ = _init_git_repo(root)
            route = {
                "authority": {"claim": {"path": "claim.md", "sha256": H}},
                "assignment": {
                    "expectedHead": base,
                    "featureAuthorThreadId": "worker",
                    "worktree": str(root),
                    "branch": "codex/observed",
                },
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
                "expectedHead": base,
                "allowedPaths": ["owned/path"],
            }
            errors = MOD._route_projection_errors(binding, root)
            self.assertTrue(any("schema-2 route" in error or "validator is unavailable" in error for error in errors))

    def test_current_durable_cross_root_and_same_root_product_routes_project(self):
        dispatches = [
            "docs/production/evidence/INTEGRATION/GAME-009-R6D-A6-PLAY-073-RENDERER-DISPATCH.json",
            "docs/production/evidence/INTEGRATION/GAMEPLAY-ADOPTION-R4-PLAY-085-OVERLAY-DISPATCH.json",
        ]
        for dispatch_path in dispatches:
            with self.subTest(dispatch=dispatch_path):
                binding = _binding_for_dispatch(REPO_ROOT, dispatch_path)
                self.assertEqual(MOD._route_projection_errors(binding, REPO_ROOT), [])

    def test_route_projection_uses_assigned_git_root_and_expected_head_ancestry(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as observed_tmp:
            authority = Path(authority_tmp)
            observed = Path(observed_tmp)
            base, _ = _init_git_repo(observed)
            route, binding = _write_projection_dispatch(
                authority, str(observed), "codex/observed", base
            )
            validator = mock.Mock()
            validator.validate_route.return_value = []
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                self.assertEqual(MOD._route_projection_errors(binding, authority), [])
            projected_route, projected_root = validator.validate_route.call_args.args
            self.assertEqual(projected_root, observed.resolve())
            self.assertEqual(
                projected_route["assignment"]["worktree"],
                "/__citysim_schema_validation__/nonexistent",
            )
            self.assertEqual(route["assignment"]["worktree"], str(observed))
            persisted = json.loads((authority / "dispatch.json").read_text(encoding="utf-8"))
            self.assertEqual(
                persisted["assignments"][0]["modelRoute"]["assignment"]["worktree"],
                str(observed),
            )

    def test_route_projection_rejects_missing_worktree_before_schema_validation(self):
        with tempfile.TemporaryDirectory() as authority_tmp:
            authority = Path(authority_tmp)
            _, binding = _write_projection_dispatch(
                authority, str(authority / "missing"), "codex/observed", C
            )
            validator = mock.Mock()
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                errors = MOD._route_projection_errors(binding, authority)
            self.assertIn("observed route assignment.worktree must be an existing directory", errors)
            validator.validate_route.assert_not_called()

    def test_route_projection_rejects_non_git_worktree_before_schema_validation(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as observed_tmp:
            authority = Path(authority_tmp)
            observed = Path(observed_tmp)
            _, binding = _write_projection_dispatch(
                authority, str(observed), "codex/observed", C
            )
            validator = mock.Mock()
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                errors = MOD._route_projection_errors(binding, authority)
            self.assertIn("observed route assignment.worktree must be a Git repository", errors)
            validator.validate_route.assert_not_called()

    def test_route_projection_rejects_nested_non_root_git_path_before_schema_validation(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as observed_tmp:
            authority = Path(authority_tmp)
            observed = Path(observed_tmp)
            base, _ = _init_git_repo(observed)
            nested = observed / "nested"
            nested.mkdir()
            _, binding = _write_projection_dispatch(
                authority, str(nested), "codex/observed", base
            )
            validator = mock.Mock()
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                errors = MOD._route_projection_errors(binding, authority)
            self.assertIn("observed route assignment.worktree must equal its Git top level", errors)
            validator.validate_route.assert_not_called()

    def test_route_projection_rejects_observed_branch_mismatch(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as observed_tmp:
            authority = Path(authority_tmp)
            observed = Path(observed_tmp)
            base, _ = _init_git_repo(observed)
            _, binding = _write_projection_dispatch(
                authority, str(observed), "codex/wrong", base
            )
            validator = mock.Mock()
            validator.validate_route.return_value = []
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                errors = MOD._route_projection_errors(binding, authority)
            self.assertIn("live worker/output branch must exactly match the model route branch", errors)

    def test_route_projection_rejects_non_ancestor_expected_head(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as observed_tmp:
            authority = Path(authority_tmp)
            observed = Path(observed_tmp)
            _init_git_repo(observed)
            _, binding = _write_projection_dispatch(
                authority, str(observed), "codex/observed", "f" * 40
            )
            validator = mock.Mock()
            validator.validate_route.return_value = []
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                errors = MOD._route_projection_errors(binding, authority)
            self.assertIn(
                "model route expected HEAD must be an ancestor of live worker/output HEAD",
                errors,
            )

    def test_route_projection_reports_observed_byte_hash_mismatch(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as observed_tmp:
            authority = Path(authority_tmp)
            observed = Path(observed_tmp)
            base, _ = _init_git_repo(observed)
            _, binding = _write_projection_dispatch(
                authority, str(observed), "codex/observed", base
            )
            validator = mock.Mock()
            validator.validate_route.return_value = [
                "authority.immutableInputs[0] sha256 mismatch for observed bytes"
            ]
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                errors = MOD._route_projection_errors(binding, authority)
            self.assertIn(
                "schema-2 route: authority.immutableInputs[0] sha256 mismatch for observed bytes",
                errors,
            )
            _, projected_root = validator.validate_route.call_args.args
            self.assertEqual(projected_root, observed.resolve())

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
            dispatch, route = _write_observer_dispatch(
                authority,
                str(output),
                "codex/citysim-os-optimization",
                head,
            )
            validator = mock.Mock()
            validator.validate_dispatch.return_value = []
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                allowed, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertEqual(errors, [])
            self.assertEqual(allowed, ["docs/production/evidence/PLAY-089/review"])
            projected_dispatch, projected_root, projected_route_id = validator.validate_dispatch.call_args.args
            projected_row = projected_dispatch["assignments"][0]
            self.assertEqual(projected_root, authority)
            self.assertEqual(projected_route_id, "observer-route")
            self.assertEqual(
                projected_row["modelRoute"]["assignment"]["worktree"],
                "/__citysim_schema_validation__/nonexistent",
            )
            self.assertEqual(
                projected_row["modelRouteSha256"],
                MOD._canonical_sha256(projected_row["modelRoute"]),
            )
            self.assertEqual(route["assignment"]["worktree"], str(output))
            persisted = json.loads((authority / "dispatch.json").read_text(encoding="utf-8"))
            self.assertEqual(persisted, dispatch)
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-090/escape.json"],
                )
            self.assertTrue(any("outside its exact route" in error for error in errors))

    def test_observer_route_accepts_descendant_result_head(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as output_tmp:
            authority = Path(authority_tmp)
            output = Path(output_tmp)
            base, descendant = _init_git_repo(output)
            dispatch, route = _write_observer_dispatch(
                authority,
                str(output),
                "codex/observed",
                base,
            )
            validator = mock.Mock()
            validator.validate_dispatch.return_value = []
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                allowed, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertEqual(errors, [])
            self.assertEqual(allowed, ["docs/production/evidence/PLAY-089/review"])
            self.assertNotEqual(base, descendant)
            self.assertEqual(route["assignment"]["expectedHead"], base)
            self.assertEqual(json.loads((authority / "dispatch.json").read_text(encoding="utf-8")), dispatch)

    def test_observer_route_rejects_original_hash_tamper_duplicate_and_authority_mismatch(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as output_tmp:
            authority = Path(authority_tmp)
            output = Path(output_tmp)
            base, _ = _init_git_repo(output)
            validator = mock.Mock()
            validator.validate_dispatch.return_value = []

            dispatch, _ = _write_observer_dispatch(authority, str(output), "codex/observed", base)
            tampered = copy.deepcopy(dispatch)
            tampered["assignments"][0]["modelRouteSha256"] = H
            (authority / "dispatch.json").write_text(json.dumps(tampered), encoding="utf-8")
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertIn("observer selected model route hash must match canonical original route JSON", errors)

            duplicate = copy.deepcopy(dispatch)
            duplicate["assignments"].append(copy.deepcopy(duplicate["assignments"][0]))
            (authority / "dispatch.json").write_text(json.dumps(duplicate), encoding="utf-8")
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertEqual(errors, ["observer model route must resolve exactly once"])

            authority_mismatch = copy.deepcopy(dispatch)
            authority_mismatch["authorityCommit"] = "c" * 40
            (authority / "dispatch.json").write_text(json.dumps(authority_mismatch), encoding="utf-8")
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertIn("observer dispatch and selected route authority must exactly match", errors)

    def test_observer_route_rejects_missing_non_git_and_nested_roots(self):
        validator = mock.Mock()
        validator.validate_dispatch.return_value = []
        with tempfile.TemporaryDirectory() as authority_tmp:
            authority = Path(authority_tmp)
            missing = authority / "missing"
            _write_observer_dispatch(authority, str(missing), "codex/observed", C)
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, missing,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertIn("observed route assignment.worktree must be an existing directory", errors)

        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as output_tmp:
            authority = Path(authority_tmp)
            output = Path(output_tmp)
            _write_observer_dispatch(authority, str(output), "codex/observed", C)
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertIn("observed route assignment.worktree must be a Git repository", errors)

        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as output_tmp:
            authority = Path(authority_tmp)
            output = Path(output_tmp)
            base, _ = _init_git_repo(output)
            nested = output / "nested"
            nested.mkdir()
            _write_observer_dispatch(authority, str(nested), "codex/observed", base)
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, nested,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertIn("observed route assignment.worktree must equal its Git top level", errors)

    def test_observer_route_rejects_branch_and_non_ancestor_head(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as output_tmp:
            authority = Path(authority_tmp)
            output = Path(output_tmp)
            base, _ = _init_git_repo(output)
            validator = mock.Mock()
            validator.validate_dispatch.return_value = []
            _write_observer_dispatch(authority, str(output), "codex/wrong", base)
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertIn("live worker/output branch must exactly match the model route branch", errors)

            _write_observer_dispatch(authority, str(output), "codex/observed", "f" * 40)
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertIn("model route expected HEAD must be an ancestor of live worker/output HEAD", errors)

    def test_observer_route_propagates_immutable_input_and_claim_failures(self):
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as output_tmp:
            authority = Path(authority_tmp)
            output = Path(output_tmp)
            base, _ = _init_git_repo(output)
            _write_observer_dispatch(authority, str(output), "codex/observed", base)
            validator = mock.Mock()
            validator.validate_dispatch.return_value = [
                "assignments[0]: authority.immutableInputs[0] sha256 mismatch",
                "assignments[0]: claim sha256 mismatch",
            ]
            with mock.patch.object(MOD, "_load_model_route_validator", return_value=validator):
                _, errors = MOD.validate_observer_output_route(
                    "dispatch.json", "observer-route", authority, output,
                    ["docs/production/evidence/PLAY-089/review/01.json"],
                )
            self.assertIn("assignments[0]: authority.immutableInputs[0] sha256 mismatch", errors)
            self.assertIn("assignments[0]: claim sha256 mismatch", errors)

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
