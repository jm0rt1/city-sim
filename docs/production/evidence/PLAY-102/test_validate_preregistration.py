#!/usr/bin/env python3
"""Adversarial static tests for the candidate-neutral PLAY-102 validator."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("play102_validator", ROOT / "validate_preregistration.py")
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class PreregistrationValidatorAdversarialTests(unittest.TestCase):
    def run_with_packet(self, packet_name: str, mutate) -> None:
        with tempfile.TemporaryDirectory(prefix="play102-validator-") as temp:
            isolated = Path(temp) / "PLAY-102"
            shutil.copytree(ROOT, isolated, ignore=shutil.ignore_patterns("*.pyc", "__pycache__"))
            path = isolated / packet_name
            packet = json.loads(path.read_text())
            mutate(packet)
            path.write_text(json.dumps(packet, indent=2) + "\n")
            original_root = VALIDATOR.ROOT
            VALIDATOR.ROOT = isolated
            try:
                with self.assertRaises(ValueError):
                    VALIDATOR.main()
            finally:
                VALIDATOR.ROOT = original_root

    def run_with_measurement_plan(self, mutate) -> None:
        self.run_with_packet("MEASUREMENT-PLAN.json", mutate)

    def test_invalid_measurement_direction_returns(self) -> None:
        def mutate(packet: dict) -> None:
            packet["captureMatrix"]["directions"][0] = "up"

        self.run_with_measurement_plan(mutate)

    def test_invalid_measurement_count_returns(self) -> None:
        def mutate(packet: dict) -> None:
            packet["captureMatrix"]["count"] = 23

        self.run_with_measurement_plan(mutate)

    def test_invalid_fixture_source_hash_returns(self) -> None:
        def mutate(packet: dict) -> None:
            packet["sourceFixture"]["fileSha256"] = "0" * 64

        self.run_with_packet("fixture-manifest.json", mutate)

    def test_non_null_measurement_receipt_returns(self) -> None:
        def mutate(packet: dict) -> None:
            packet["preconditions"]["measurementReceipt"] = {"status": "measured"}

        self.run_with_packet("REHEARSAL-PLAN.json", mutate)


if __name__ == "__main__":
    unittest.main()
