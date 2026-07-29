#!/usr/bin/env python3
"""Focused tests for PLAY-081 West prelock direction isolation."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
REPOSITORY_ROOT = HERE.parents[5]
sys.path.insert(0, str(HERE))

from validate_current_master_prelock_bundle import (  # noqa: E402
    DEFAULT_CASES,
    DEFAULT_VALID,
    EXPECTED_OUTPUT_ROOTS,
    ZERO_INVOCATIONS,
    _set_mutation,
    build_report,
    load_json,
    validate_bundle,
)


class CurrentMasterPrelockBundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.valid = load_json(REPOSITORY_ROOT / DEFAULT_VALID)
        cls.cases = load_json(REPOSITORY_ROOT / DEFAULT_CASES)["cases"]

    def test_valid_west_bundle_passes(self) -> None:
        errors, reads = validate_bundle(REPOSITORY_ROOT, self.valid)
        self.assertEqual(errors, [])
        self.assertGreaterEqual(len(reads), 10)

    def test_all_committed_adversarial_cases_reject_expected_error(self) -> None:
        for case in self.cases:
            with self.subTest(case=case["name"]):
                candidate = copy.deepcopy(self.valid)
                _set_mutation(candidate, case["mutationPath"], case["value"])
                errors, _ = validate_bundle(REPOSITORY_ROOT, candidate)
                self.assertIn(case["expectedError"], errors)

    def test_sibling_paths_reject_before_read(self) -> None:
        for case in self.cases:
            if not case["name"].startswith("sibling-"):
                continue
            candidate = copy.deepcopy(self.valid)
            _set_mutation(candidate, case["mutationPath"], case["value"])
            errors, reads = validate_bundle(REPOSITORY_ROOT, candidate)
            self.assertIn(case["expectedError"], errors)
            self.assertNotIn(case["value"], reads)

    def test_socket_and_transform_cases_are_present(self) -> None:
        names = {case["name"] for case in self.cases}
        self.assertTrue(
            {
                "socket-citysim-substitution",
                "socket-blender-substitution",
                "socket-source-substitution",
                "orientation-transform-not-none",
            }.issubset(names)
        )

    def test_unsafe_output_cases_are_present(self) -> None:
        names = {case["name"] for case in self.cases}
        self.assertTrue(
            {
                "unsafe-output-sibling-root",
                "unsafe-output-shared-root",
                "unsafe-output-traversal",
                "unsafe-output-absolute",
                "unsafe-output-alias",
            }.issubset(names)
        )
        self.assertEqual(
            len(EXPECTED_OUTPUT_ROOTS.values()),
            len(set(EXPECTED_OUTPUT_ROOTS.values())),
        )

    def test_report_is_deterministic(self) -> None:
        first = build_report(REPOSITORY_ROOT)
        second = build_report(REPOSITORY_ROOT)
        first_bytes = (
            json.dumps(first, indent=2, sort_keys=True) + "\n"
        ).encode()
        second_bytes = (
            json.dumps(second, indent=2, sort_keys=True) + "\n"
        ).encode()
        self.assertEqual(first_bytes, second_bytes)
        self.assertTrue(first["passed"])

    def test_report_retains_zero_invocation_boundary(self) -> None:
        report = build_report(REPOSITORY_ROOT)
        self.assertEqual(report["invocations"], ZERO_INVOCATIONS)
        self.assertEqual(report["forbiddenOutputs"], [])
        for result in report["adversarialCases"]:
            self.assertEqual(result["invocations"], ZERO_INVOCATIONS)


if __name__ == "__main__":
    unittest.main()
