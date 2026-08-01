#!/usr/bin/env python3
"""Focused adversarial tests for the CitySim model-route contract."""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

import validate_model_route_v1 as validator


class ModelRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name)
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.email", "route@test.invalid"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.name", "Route Test"], check=True)
        (self.repo / "claims").mkdir()
        (self.repo / "inputs").mkdir()
        (self.repo / "owned" / "evidence").mkdir(parents=True)
        (self.repo / "claims" / "PLAY-999.md").write_text(
            "# PLAY-999\nOwn `owned/` and `owned/evidence/`.\n", encoding="utf-8"
        )
        (self.repo / "inputs" / "authority.txt").write_text("frozen\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(self.repo), "add", "claims", "inputs"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "commit", "-qm", "fixture"], check=True)
        self.head = subprocess.check_output(["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True).strip()
        self.claim = self._binding("claims/PLAY-999.md")
        self.input = self._binding("inputs/authority.txt")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _binding(self, rel: str) -> dict[str, str]:
        return {"path": rel, "sha256": hashlib.sha256((self.repo / rel).read_bytes()).hexdigest()}

    def route(self, classification: str = "LUNA_IMPLEMENTATION", packet_kind: str = "implementation") -> dict:
        model, effort = validator.ROUTES[classification]
        assignment_thread = "worker-thread"
        route = {
            "schema": 1,
            "routeId": f"PLAY-999:{classification.lower()}:v1",
            "taskId": "PLAY-999",
            "packetKind": packet_kind,
            "classification": classification,
            "model": model,
            "effort": effort,
            "rationale": "A bounded contract-complete test packet.",
            "authority": {
                "authorityCommit": self.head,
                "baseCommit": self.head,
                "claim": copy.deepcopy(self.claim),
                "immutableInputs": [copy.deepcopy(self.input)],
            },
            "assignment": {
                "threadId": assignment_thread,
                "featureAuthorThreadId": None,
                "sharedAuthorityOwnership": False,
                "finalQAOwnership": False,
                "subjectiveJudgmentRequired": False,
            },
            "pathPolicy": {
                "claimOwnedRoots": ["owned"],
                "allowed": ["owned/evidence"],
                "forbidden": ["claims"],
            },
            "boundedDeliverable": "Produce one deterministic evidence packet.",
            "validation": {
                "focusedGateOwner": {"threadId": assignment_thread, "role": "lane_focused_gate"},
                "focusedCommands": ["python3 focused_check.py"],
                "fullGateOwner": {
                    "threadId": "integration-thread",
                    "role": "aggregate_full_gate",
                    "model": "gpt-5.6-sol",
                    "effort": "high",
                },
                "fullCommands": ["aggregate full Swift suite and staged build"],
            },
            "expectedResult": {
                "evidencePaths": ["owned/evidence"],
                "commitRequired": True,
                "commitMessagePattern": "PLAY-999:",
            },
            "escalationTriggers": sorted(validator.TRIGGERS),
            "stopCondition": "Stop after one coherent packet or any escalation trigger.",
            "independentReviewer": {
                "required": True,
                "threadId": "review-thread",
                "model": "gpt-5.6-sol",
                "effort": "high",
            },
            "context": {
                "mode": "full_authority_read",
                "packet": None,
                "verifiedHashes": [copy.deepcopy(self.input)],
            },
        }
        if classification == "FRONTIER_AUTHORITY":
            route["independentReviewer"] = {"required": False, "threadId": None, "model": None, "effort": None}
        return route

    def assert_valid(self, route: dict) -> None:
        self.assertEqual([], validator.validate_route(route, self.repo))

    def assert_invalid(self, route: dict, fragment: str) -> None:
        errors = validator.validate_route(route, self.repo)
        self.assertTrue(any(fragment in error for error in errors), errors)

    def test_all_supported_route_tuples(self) -> None:
        kinds = {
            "FRONTIER_AUTHORITY": "authority",
            "LUNA_IMPLEMENTATION": "implementation",
            "LUNA_MECHANICAL": "mechanical",
            "LUNA_LOCAL_DEBUG": "local_debug",
        }
        for classification, kind in kinds.items():
            with self.subTest(classification=classification):
                self.assert_valid(self.route(classification, kind))

    def test_unsupported_or_wrong_model_route_fails(self) -> None:
        route = self.route()
        route["classification"] = "CHEAP_UNKNOWN"
        self.assert_invalid(route, "unsupported model route")
        route = self.route()
        route["model"] = "gpt-5.6-sol"
        self.assert_invalid(route, "requires model/effort")

    def test_luna_cannot_own_authority_or_final_qa(self) -> None:
        for key in ("sharedAuthorityOwnership", "finalQAOwnership", "subjectiveJudgmentRequired"):
            route = self.route()
            route["assignment"][key] = True
            with self.subTest(key=key):
                self.assert_invalid(route, "Luna cannot own")

    def test_every_escalation_trigger_is_required(self) -> None:
        for trigger in validator.TRIGGERS:
            route = self.route()
            route["escalationTriggers"].remove(trigger)
            with self.subTest(trigger=trigger):
                self.assert_invalid(route, "exact mandatory set")

    def test_claim_and_allowed_paths_are_exact(self) -> None:
        route = self.route()
        route["pathPolicy"]["allowed"] = ["outside"]
        self.assert_invalid(route, "outside claim-owned roots")
        route = self.route()
        route["pathPolicy"]["claimOwnedRoots"] = ["unclaimed"]
        route["pathPolicy"]["allowed"] = ["unclaimed"]
        self.assert_invalid(route, "claim does not literally own root")
        route = self.route()
        route["pathPolicy"]["allowed"] = ["owned/../claims"]
        self.assert_invalid(route, "not an exact normalized")

    def test_luna_cannot_mutate_shared_authority_roots(self) -> None:
        route = self.route()
        route["pathPolicy"]["claimOwnedRoots"] = ["docs/production/claims"]
        route["pathPolicy"]["allowed"] = ["docs/production/claims"]
        route["pathPolicy"]["forbidden"] = ["outside"]
        (self.repo / "claims" / "PLAY-999.md").write_text(
            "# PLAY-999\nOwn `docs/production/claims/`.\n", encoding="utf-8"
        )
        route["authority"]["claim"]["sha256"] = hashlib.sha256(
            (self.repo / "claims" / "PLAY-999.md").read_bytes()
        ).hexdigest()
        self.assert_invalid(route, "shared-authority root")

    def test_focused_and_full_gate_ownership_are_distinct(self) -> None:
        route = self.route()
        route["validation"]["fullGateOwner"]["threadId"] = "worker-thread"
        self.assert_invalid(route, "must be distinct")

    def test_luna_focused_gate_rejects_aggregate_commands(self) -> None:
        route = self.route()
        route["validation"]["focusedCommands"] = ["swift test --package-path Native/CitySimNative"]
        self.assert_invalid(route, "aggregate/final command")

    def test_final_qa_cannot_use_feature_author_task(self) -> None:
        route = self.route("FRONTIER_AUTHORITY", "acceptance")
        route["assignment"].update({
            "threadId": "qa-thread", "featureAuthorThreadId": "qa-thread",
            "finalQAOwnership": True, "subjectiveJudgmentRequired": True,
        })
        route["validation"]["focusedGateOwner"]["threadId"] = "fixture-thread"
        route["validation"]["fullGateOwner"]["threadId"] = "qa-thread"
        route["independentReviewer"] = {
            "required": True, "threadId": "qa-thread", "model": "gpt-5.6-sol", "effort": "high"
        }
        self.assert_invalid(route, "feature-author")
        route["assignment"]["featureAuthorThreadId"] = "author-thread"
        self.assert_valid(route)

    def test_compact_context_requires_exact_bound_packet(self) -> None:
        route = self.route()
        route["context"] = {"mode": "compact_continuation", "packet": None, "verifiedHashes": [self.input]}
        self.assert_invalid(route, "requires a bound context packet")

    def test_dispatch_projects_exact_route(self) -> None:
        route = self.route()
        dispatch = {
            "schema": 1,
            "authorityCommit": self.head,
            "assignments": [{"modelRouteSha256": validator.canonical_sha(route), "modelRoute": copy.deepcopy(route)}],
        }
        self.assertEqual([], validator.validate_dispatch(dispatch, self.repo))
        dispatch["assignments"][0]["modelRoute"]["effort"] = "medium"
        errors = validator.validate_dispatch(dispatch, self.repo)
        self.assertTrue(any("canonical route JSON" in error for error in errors), errors)

    def test_unchanged_passing_sibling_cannot_be_demoted(self) -> None:
        previous = {"cells": [
            {"direction": "east", "state": "returned", "claimRevision": "a"},
            {"direction": "south", "state": "integration_admitted", "claimRevision": "b", "sourceAdmissionReceipt": "sha"},
        ]}
        current = copy.deepcopy(previous)
        current["cells"][1]["state"] = "predesign"
        errors = validator.validate_siblings(previous, current, "east")
        self.assertTrue(any("south was demoted" in error for error in errors), errors)
        current = copy.deepcopy(previous)
        current["cells"][0]["state"] = "predesign"
        self.assertEqual([], validator.validate_siblings(previous, current, "east"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
