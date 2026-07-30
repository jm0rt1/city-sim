#!/usr/bin/env python3
"""Zero-child adversarial tests for the PLAY-079 East schedule consumer."""

from __future__ import annotations

import importlib.util
import pathlib
import unittest


ADAPTER_PATH = pathlib.Path(__file__).with_name("consume_parallel_schedule_v1.py")
SPEC = importlib.util.spec_from_file_location("play079_schedule_adapter", ADAPTER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"unable to import {ADAPTER_PATH}")
adapter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(adapter)


class EastScheduleConsumerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = adapter.load_json(
            adapter.HARDENED.capture_repository_file(
                adapter.CONTRACT_RELATIVE, "testContract"
            ),
            "testContract",
        )

    def test_readiness_is_blocked_and_zero_child(self) -> None:
        result = adapter.validate_contract(self.contract)
        self.assertEqual(result["status"], "PASS_BLOCKED_ZERO_CHILD")
        self.assertEqual(result["futureSchedule"], adapter.MISSING_SCHEDULE)
        self.assertEqual(result["readiness"]["childStarts"], 0)
        self.assertFalse(result["readiness"]["launchReady"])

    def test_valid_structural_postlock_east_grant_is_zero_child(self) -> None:
        result = adapter.validate_east_schedule_fields(
            adapter.synthetic_postlock_schedule()
        )
        self.assertEqual(result["processes"], ["A", "B", "C"])
        self.assertEqual(result["childStartsPerformed"], 0)
        self.assertFalse(result["directLowLevelInvocationAllowed"])

    def test_all_adversaries_fail_closed(self) -> None:
        cases = adapter.adversarial_cases(self.contract)
        self.assertEqual(len(cases), 18)
        self.assertTrue(all(case["result"] == "REJECTED" for case in cases))

    def test_adapter_exposes_no_child_launch_api(self) -> None:
        surface = adapter.validate_no_launch_api()
        self.assertFalse(surface["launchApiPresent"])
        self.assertFalse(surface["lowLevelRunnerImported"])
        self.assertFalse(surface["highLevelOrchestratorImported"])
        self.assertFalse(surface["directLowLevelInvocationPossible"])

    def test_two_readiness_runs_are_byte_identical(self) -> None:
        first = adapter.validate_contract(self.contract)
        second = adapter.validate_contract(self.contract)
        self.assertEqual(adapter.canonical_bytes(first), adapter.canonical_bytes(second))

    def test_missing_schedule_binding_rejects_before_child(self) -> None:
        with self.assertRaises(adapter.AdapterRejected) as caught:
            adapter.reject("missing_schedule_binding", ["schedule"])
        self.assertEqual(caught.exception.code, "missing_schedule_binding")


if __name__ == "__main__":
    unittest.main()
