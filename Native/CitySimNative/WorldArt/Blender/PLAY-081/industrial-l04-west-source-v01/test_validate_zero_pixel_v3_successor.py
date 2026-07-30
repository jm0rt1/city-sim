#!/usr/bin/env python3
"""Focused tests for the PLAY-081 West v3 zero-pixel successor."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
REPOSITORY_ROOT = HERE.parents[5]
sys.path.insert(0, str(HERE))

from validate_zero_pixel_v3_successor import (  # noqa: E402
    DEFAULT_CASES,
    DEFAULT_HANDOFF,
    EXPECTED_AUTHORITY_BOUNDARY,
    EXPECTED_OUTPUT_ROOTS,
    PUBLISHED_MASTER,
    ZERO_INVOCATIONS,
    _set_mutation,
    build_report,
    load_json,
    sha256,
    validate_handoff,
)


class ZeroPixelV3SuccessorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.handoff = load_json(REPOSITORY_ROOT / DEFAULT_HANDOFF)
        cls.cases = load_json(REPOSITORY_ROOT / DEFAULT_CASES)["cases"]

    def test_exact_successor_handoff_passes(self) -> None:
        errors, reads = validate_handoff(REPOSITORY_ROOT, self.handoff)
        self.assertEqual(errors, [])
        self.assertGreaterEqual(len(reads), 16)
        self.assertEqual(
            self.handoff["lineage"]["publishedMaster"],
            PUBLISHED_MASTER,
        )

    def test_all_committed_adversaries_fail_closed(self) -> None:
        for case in self.cases:
            with self.subTest(case=case["name"]):
                candidate = copy.deepcopy(self.handoff)
                _set_mutation(candidate, case["mutationPath"], case["value"])
                errors, _ = validate_handoff(REPOSITORY_ROOT, candidate)
                self.assertIn(case["expectedError"], errors)

    def test_required_adversary_classes_are_present(self) -> None:
        names = {case["name"] for case in self.cases}
        self.assertTrue(
            {
                "stale-runner-hash",
                "old-published-master",
                "wrong-claim-hash",
                "wrong-bridge-integrated-proof",
                "sibling-scene-path",
                "orientation-transform-not-none",
                "unsafe-output-shared-root",
            }.issubset(names)
        )

    def test_sibling_path_rejects_before_read(self) -> None:
        case = next(
            case for case in self.cases if case["name"] == "sibling-scene-path"
        )
        candidate = copy.deepcopy(self.handoff)
        _set_mutation(candidate, case["mutationPath"], case["value"])
        errors, reads = validate_handoff(REPOSITORY_ROOT, candidate)
        self.assertIn(case["expectedError"], errors)
        self.assertNotIn(case["value"], reads)

    def test_historical_handoff_bytes_remain_exact(self) -> None:
        for key in ("predecessorHandoff", "predecessorValidation"):
            binding = self.handoff["lineage"][key]
            self.assertTrue(binding["preservedByteForByte"])
            self.assertEqual(
                sha256(REPOSITORY_ROOT / binding["path"]),
                binding["sha256"],
            )

    def test_source_boundary_stays_closed(self) -> None:
        self.assertEqual(
            self.handoff["authorityBoundary"],
            EXPECTED_AUTHORITY_BOUNDARY,
        )
        self.assertFalse(self.handoff["sourceReady"])
        self.assertEqual(self.handoff["invocations"], ZERO_INVOCATIONS)
        self.assertEqual(
            len(EXPECTED_OUTPUT_ROOTS),
            len(set(EXPECTED_OUTPUT_ROOTS.values())),
        )

    def test_report_is_byte_deterministic(self) -> None:
        first = build_report(REPOSITORY_ROOT)
        second = build_report(REPOSITORY_ROOT)
        first_bytes = (
            json.dumps(first, indent=2, sort_keys=True) + "\n"
        ).encode("utf-8")
        second_bytes = (
            json.dumps(second, indent=2, sort_keys=True) + "\n"
        ).encode("utf-8")
        self.assertEqual(first_bytes, second_bytes)
        self.assertTrue(first["passed"])
        self.assertEqual(first["invocations"], ZERO_INVOCATIONS)
        self.assertEqual(first["forbiddenOutputs"], [])


if __name__ == "__main__":
    unittest.main()
