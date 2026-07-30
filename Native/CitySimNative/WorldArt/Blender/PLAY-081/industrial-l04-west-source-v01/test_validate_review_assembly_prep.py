#!/usr/bin/env python3
"""Focused tests for PLAY-081 West zero-pixel review-assembly prep."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
REPOSITORY_ROOT = HERE.parents[5]
sys.path.insert(0, str(HERE))

from validate_review_assembly_prep import (  # noqa: E402
    CURRENT_INTEGRATION,
    DEFAULT_CASES,
    DEFAULT_CONTRACT,
    EXPECTED_ARTIFACTS,
    EXPECTED_FUTURE_OUTPUTS,
    EXPECTED_SETTLED_GATES,
    MISSING_RELEASE_INPUT,
    ZERO_INVOCATIONS,
    _set_mutation,
    build_report,
    load_json,
    validate_contract,
)


class ReviewAssemblyPrepTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = load_json(REPOSITORY_ROOT / DEFAULT_CONTRACT)
        cls.cases = load_json(REPOSITORY_ROOT / DEFAULT_CASES)["cases"]

    def test_exact_zero_pixel_contract_passes(self) -> None:
        errors, inspected = validate_contract(
            REPOSITORY_ROOT,
            self.contract,
        )
        self.assertEqual(errors, [])
        self.assertGreaterEqual(len(inspected), 22)
        self.assertEqual(
            self.contract["currentIntegrationBaseline"],
            CURRENT_INTEGRATION,
        )

    def test_all_committed_adversaries_fail_closed(self) -> None:
        for case in self.cases:
            with self.subTest(case=case["name"]):
                candidate = copy.deepcopy(self.contract)
                _set_mutation(candidate, case["mutationPath"], case["value"])
                errors, _ = validate_contract(REPOSITORY_ROOT, candidate)
                self.assertIn(case["expectedError"], errors)

    def test_sibling_path_rejects_before_read(self) -> None:
        case = next(
            case for case in self.cases if case["name"] == "sibling-review-path"
        )
        candidate = copy.deepcopy(self.contract)
        _set_mutation(candidate, case["mutationPath"], case["value"])
        errors, inspected = validate_contract(REPOSITORY_ROOT, candidate)
        self.assertIn(case["expectedError"], errors)
        self.assertNotIn(case["value"], inspected)

    def test_review_artifact_inventory_is_exact_and_absent(self) -> None:
        self.assertEqual(
            self.contract["reviewArtifacts"],
            EXPECTED_ARTIFACTS,
        )
        self.assertEqual(
            EXPECTED_ARTIFACTS["sourceSizeColor"]["canvasPixels"],
            [1536, 1024],
        )
        self.assertEqual(
            EXPECTED_ARTIFACTS["native2xColor"]["canvasPixels"],
            [1024, 683],
        )
        self.assertEqual(
            EXPECTED_ARTIFACTS["actualGameScaleColor"]["canvasPixels"],
            [192, 128],
        )
        for artifact in EXPECTED_ARTIFACTS.values():
            self.assertFalse((REPOSITORY_ROOT / artifact["path"]).exists())

    def test_release_inputs_are_explicit_missing_nulls(self) -> None:
        self.assertEqual(
            self.contract["releaseInputs"],
            {
                "appearanceLock": MISSING_RELEASE_INPUT,
                "sourceProductionProfile": MISSING_RELEASE_INPUT,
            },
        )
        self.assertFalse(self.contract["reviewAssemblyReady"])
        self.assertFalse(self.contract["sourceReady"])

    def test_single_assembler_waits_for_every_future_job(self) -> None:
        assembler = self.contract["assembler"]
        self.assertTrue(assembler["singleWriter"])
        self.assertFalse(assembler["assemblyReady"])
        self.assertFalse(assembler["creationAuthorizedNow"])
        self.assertEqual(
            assembler["requiredSettledGates"],
            EXPECTED_SETTLED_GATES,
        )
        self.assertTrue(
            all(value is False for value in EXPECTED_SETTLED_GATES.values())
        )
        self.assertEqual(
            assembler["futureOutputs"],
            EXPECTED_FUTURE_OUTPUTS,
        )

    def test_overwrite_fallback_alias_and_invocation_cases_are_present(self) -> None:
        names = {case["name"] for case in self.cases}
        self.assertTrue(
            {
                "early-assembly-ready",
                "overwrite-policy-disabled",
                "fallback-enabled",
                "alias-enabled",
                "dcc-invocation",
                "render-invocation",
                "pixel-invocation",
                "artifact-claimed-produced",
            }.issubset(names)
        )
        self.assertEqual(self.contract["invocations"], ZERO_INVOCATIONS)

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
        self.assertEqual(first["forbiddenOutputs"], [])
        self.assertEqual(first["invocations"], ZERO_INVOCATIONS)


if __name__ == "__main__":
    unittest.main()
