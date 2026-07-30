#!/usr/bin/env python3
"""Focused tests for the PLAY-081 West v4 baseline repair."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
REPOSITORY_ROOT = HERE.parents[5]
sys.path.insert(0, str(HERE))

import validate_zero_pixel_v3_successor as v3  # noqa: E402
from validate_zero_pixel_v4_successor import (  # noqa: E402
    DEFAULT_CASES,
    DEFAULT_HANDOFF,
    EXPECTED_V3_PREDECESSORS,
    PUBLISHED_MASTER,
    build_report,
    validate_handoff,
)


class ZeroPixelV4SuccessorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.handoff = v3.load_json(REPOSITORY_ROOT / DEFAULT_HANDOFF)
        cls.cases = v3.load_json(REPOSITORY_ROOT / DEFAULT_CASES)["cases"]

    def test_exact_v4_successor_passes(self) -> None:
        errors, reads = validate_handoff(REPOSITORY_ROOT, self.handoff)
        self.assertEqual(errors, [])
        self.assertGreaterEqual(len(reads), 20)
        self.assertEqual(
            self.handoff["lineage"]["publishedMaster"],
            PUBLISHED_MASTER,
        )

    def test_all_committed_adversaries_fail_closed(self) -> None:
        for case in self.cases:
            with self.subTest(case=case["name"]):
                candidate = copy.deepcopy(self.handoff)
                v3._set_mutation(  # noqa: SLF001
                    candidate,
                    case["mutationPath"],
                    case["value"],
                )
                errors, _ = validate_handoff(REPOSITORY_ROOT, candidate)
                self.assertIn(case["expectedError"], errors)

    def test_both_stale_master_generations_reject(self) -> None:
        master_cases = {
            case["value"]: case
            for case in self.cases
            if case["mutationPath"] == "lineage.publishedMaster"
        }
        self.assertEqual(
            set(master_cases),
            {
                "9d8e3e776eecbfb518d08d18085180ae084a6929",
                "94ae73a99abe64f59bb052582fcaba1d9725319d",
            },
        )
        for stale_master, case in master_cases.items():
            with self.subTest(stale_master=stale_master):
                candidate = copy.deepcopy(self.handoff)
                candidate["lineage"]["publishedMaster"] = stale_master
                errors, _ = validate_handoff(REPOSITORY_ROOT, candidate)
                self.assertIn("lineage:publishedMaster", errors)

    def test_required_v3_adversary_classes_remain(self) -> None:
        names = {case["name"] for case in self.cases}
        self.assertTrue(
            {
                "stale-runner-hash",
                "wrong-claim-hash",
                "wrong-bridge-integrated-proof",
                "wrong-bridge-mapping-hash",
                "sibling-scene-path",
                "orientation-transform-not-none",
                "unsafe-output-shared-root",
                "unsafe-output-traversal",
                "unsafe-output-alias",
            }.issubset(names)
        )
        self.assertEqual(len(self.cases), 11)

    def test_sibling_path_rejects_before_read(self) -> None:
        case = next(
            case for case in self.cases if case["name"] == "sibling-scene-path"
        )
        candidate = copy.deepcopy(self.handoff)
        v3._set_mutation(  # noqa: SLF001
            candidate,
            case["mutationPath"],
            case["value"],
        )
        errors, reads = validate_handoff(REPOSITORY_ROOT, candidate)
        self.assertIn(case["expectedError"], errors)
        self.assertNotIn(case["value"], reads)

    def test_v2_v3_and_predesign_bytes_remain_exact(self) -> None:
        for key in (
            "predecessorHandoff",
            "predecessorValidation",
            *EXPECTED_V3_PREDECESSORS.keys(),
        ):
            binding = self.handoff["lineage"][key]
            self.assertTrue(binding["preservedByteForByte"])
            self.assertEqual(
                v3.sha256(REPOSITORY_ROOT / binding["path"]),
                binding["sha256"],
            )
        for key, expected in v3.EXPECTED_BINDINGS.items():
            binding = self.handoff["bindings"][key]
            self.assertEqual(binding["path"], expected["path"])
            self.assertEqual(binding["sha256"], expected["sha256"])

    def test_camera_socket_and_source_boundary_remain_exact(self) -> None:
        self.assertEqual(self.handoff["camera"], v3.EXPECTED_CAMERA)
        self.assertEqual(self.handoff["socket"], v3.EXPECTED_SOCKET)
        self.assertEqual(
            self.handoff["authorityBoundary"],
            v3.EXPECTED_AUTHORITY_BOUNDARY,
        )
        self.assertEqual(self.handoff["invocations"], v3.ZERO_INVOCATIONS)
        self.assertFalse(self.handoff["sourceReady"])

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
        self.assertEqual(first["invocations"], v3.ZERO_INVOCATIONS)
        self.assertEqual(first["forbiddenOutputs"], [])


if __name__ == "__main__":
    unittest.main()
