#!/usr/bin/env python3
"""Tests for deterministic operating-review envelope preparation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("prepare_operating_review_envelope_v1.py")
SPEC = importlib.util.spec_from_file_location("prepare_operating_review_envelope", SCRIPT)
assert SPEC and SPEC.loader
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)
C = "a" * 40


def event(trigger: str, suffix: str) -> dict:
    return {
        "authorityCommit": C,
        "taskId": "PLAY-089",
        "routeId": f"route-{suffix}",
        "trigger": trigger,
        "candidateOrResultCommit": C,
    }


POLICY = {
    "triggers": ["dispatch_published", "delegation_ready_for_dispatch"],
    "reviewScheduling": {"immediateTriggers": ["delegation_ready_for_dispatch"]},
}


class PrepareOperatingReviewEnvelopeTests(unittest.TestCase):
    def test_stably_moves_immediate_events_first(self) -> None:
        source = {
            "schema": 1,
            "eventKeys": [
                event("dispatch_published", "ordinary-a"),
                event("delegation_ready_for_dispatch", "immediate-a"),
                event("dispatch_published", "ordinary-b"),
                event("delegation_ready_for_dispatch", "immediate-b"),
            ],
        }
        prepared, errors = MOD.prepare(source, POLICY)
        self.assertEqual(errors, [])
        self.assertEqual(
            [row["routeId"] for row in prepared["eventKeys"]],
            ["route-immediate-a", "route-immediate-b", "route-ordinary-a", "route-ordinary-b"],
        )

    def test_unknown_duplicate_and_bad_identity_fail_closed(self) -> None:
        bad = event("unknown", "bad")
        bad["authorityCommit"] = "short"
        prepared, errors = MOD.prepare({"schema": 1, "eventKeys": [bad, bad]}, POLICY)
        self.assertIsNone(prepared)
        self.assertGreaterEqual(len(errors), 3)

    def test_caps_and_exact_shape_are_enforced(self) -> None:
        nine = [event("dispatch_published", str(index)) for index in range(9)]
        self.assertTrue(MOD.prepare({"schema": 1, "eventKeys": nine}, POLICY)[1])
        malformed = {"schema": 1, "eventKeys": [event("dispatch_published", "x")], "extra": True}
        self.assertTrue(MOD.prepare(malformed, POLICY)[1])

    def test_write_is_idempotent_but_never_overwrites_different_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "event.json"
            payload = b"{\n}\n"
            MOD.write_once(target, payload)
            MOD.write_once(target, payload)
            self.assertEqual(target.read_bytes(), payload)
            with self.assertRaises(ValueError):
                MOD.write_once(target, b"different")


if __name__ == "__main__":
    unittest.main()
