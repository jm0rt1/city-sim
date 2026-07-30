#!/usr/bin/env python3
"""Focused zero-process tests for the PLAY-079 East orchestration preparation."""

from __future__ import annotations

import json
import importlib.util
import pathlib
import unittest


VALIDATOR_PATH = pathlib.Path(__file__).with_name(
    "validate_process_orchestration_prep_v01.py"
)
SPEC = importlib.util.spec_from_file_location("play079_process_prep", VALIDATOR_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"unable to import {VALIDATOR_PATH}")
prep = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(prep)


class ProcessOrchestrationPrepTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = prep.load_json(
            prep.HARDENED.capture_repository_file(
                prep.CONTRACT_RELATIVE, "testContract"
            ),
            "testContract",
        )

    def test_two_validations_are_byte_identical_and_closed(self) -> None:
        first = prep.validate_contract(self.contract)
        second = prep.validate_contract(self.contract)
        self.assertEqual(prep.canonical_bytes(first), prep.canonical_bytes(second))
        self.assertFalse(first["gates"]["dccAllowed"])
        self.assertFalse(first["gates"]["pixelProductionAllowed"])
        self.assertEqual(first["pixelFiles"], [])
        self.assertEqual(first["dependencyGraph"]["singleAssembler"], "packet-assembly")

    def test_every_future_authority_is_explicitly_missing(self) -> None:
        result = prep.validate_contract(self.contract)
        self.assertEqual(
            result["futureIntegrationAuthorities"],
            prep.EXPECTED_FUTURE_AUTHORITIES,
        )

    def test_adversarial_cases_fail_closed(self) -> None:
        cases = prep.adversarial_cases(self.contract)
        self.assertEqual(len(cases), 14)
        self.assertTrue(all(case["result"] == "REJECTED" for case in cases))

    def test_dependency_graph_matches_fixed_pipeline(self) -> None:
        result = prep.validate_contract(self.contract)
        graph = result["dependencyGraph"]
        self.assertEqual(graph["rawFanOut"], ["raw-A", "raw-B", "raw-C"])
        self.assertEqual(graph["identityJoin"], "identity-join")
        self.assertEqual(graph["packetAssembly"], "packet-assembly")
        self.assertTrue(graph["acyclic"])

    def test_contract_contains_no_production_authority_shape(self) -> None:
        encoded = json.dumps(self.contract, sort_keys=True)
        self.assertNotIn('"state": "present"', encoded)
        self.assertNotIn('"launchAllowed": true', encoded)
        self.assertNotIn('"sourceReady": true', encoded)


if __name__ == "__main__":
    unittest.main()
