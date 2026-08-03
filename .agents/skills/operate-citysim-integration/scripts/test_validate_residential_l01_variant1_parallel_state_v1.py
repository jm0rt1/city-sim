#!/usr/bin/env python3
"""Adversarial tests for Residential L1 variant-one parallel controls."""

from __future__ import annotations

import copy
import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
VALIDATOR = Path(__file__).with_name("validate_residential_l01_variant1_parallel_state_v1.py")
SCHEDULE = ROOT / "docs/production/evidence/INTEGRATION/RESIDENTIAL-L01-VARIANT1-PARALLEL-SCHEDULE-V1.json"
SPEC = importlib.util.spec_from_file_location("residential_controls", VALIDATOR)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ResidentialControlTests(unittest.TestCase):
    def setUp(self) -> None:
        self.valid = json.loads(SCHEDULE.read_text())

    def assert_fails(self, mutate) -> None:
        data = copy.deepcopy(self.valid)
        mutate(data)
        with self.assertRaises(MODULE.ControlError):
            MODULE.validate_schedule(data, ROOT, check_live=False)

    def test_valid_schedule(self) -> None:
        result = MODULE.validate_schedule(self.valid, ROOT, check_live=False)
        self.assertEqual(result["rows"], list(MODULE.CELLS))

    def test_rejects_wrong_task_claim_thread_branch_worktree_or_head(self) -> None:
        mutations = (
            lambda d: d["cells"][0].update(taskId="PLAY-999"),
            lambda d: d["cells"][0]["claim"].update(path="docs/production/claims/PLAY-091.world-art-east.md"),
            lambda d: d["cells"][0].update(threadId="wrong-thread"),
            lambda d: d["cells"][0].update(branch="wrong-branch"),
            lambda d: d["cells"][0].update(worktree="/private/tmp/wrong"),
            lambda d: d["cells"][0].update(head="0" * 40),
        )
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                self.assert_fails(mutate)

    def test_rejects_stale_contract_or_claim_hash(self) -> None:
        self.assert_fails(lambda d: d["familyContract"].update(sha256="0" * 64))
        self.assert_fails(lambda d: d["cells"][1]["claim"].update(sha256="0" * 64))

    def test_rejects_sibling_root_overlap_or_transform_authority(self) -> None:
        self.assert_fails(lambda d: d["cells"][1]["ownedRoots"].__setitem__(0, d["cells"][0]["ownedRoots"][0]))
        self.assert_fails(lambda d: d["cells"][1].update(ownedRoots=["docs/production/evidence/PLAY-999/"]))
        self.assert_fails(lambda d: d["cells"][2].update(siblingTransformAllowed=True))

    def test_rejects_prelock_pixel_or_shipping_grant(self) -> None:
        self.assert_fails(lambda d: d["cells"][0]["permissions"].update(prelockPixels=True))
        self.assert_fails(lambda d: d["cells"][4]["permissions"].update(shippingActivation=True))

    def test_rejects_missing_model_route_or_escalation_trigger(self) -> None:
        self.assert_fails(lambda d: d["cells"][0]["modelRoute"].update(routeId=""))
        self.assert_fails(lambda d: d["cells"][0]["modelRoute"].update(routeId="quality-v2:wrong"))
        self.assert_fails(lambda d: d["cells"][1]["modelRoute"]["escalationTriggers"].pop())

    def test_rejects_partial_family_activation(self) -> None:
        self.assert_fails(lambda d: d["familyActivation"].update(admittedDirections=["north"]))

    def test_rejects_failed_direction_demoting_passing_sibling(self) -> None:
        def mutate(data):
            data["cells"][1]["state"] = "failed"
            data["cells"][2]["state"] = "demoted"
        self.assert_fails(mutate)

    def test_rejects_qa_feature_author_collision(self) -> None:
        self.assert_fails(lambda d: d["cells"][5].update(featureAuthorThreadId=d["cells"][5]["threadId"]))

    def test_rejects_unexplained_idle_capacity_or_fabricated_overlap(self) -> None:
        self.assert_fails(lambda d: d["capacity"].update(idleCapacityReason=None))
        self.assert_fails(lambda d: d["capacity"].update(overlapProof=[{"cell": "north"}]))


if __name__ == "__main__":
    unittest.main()
