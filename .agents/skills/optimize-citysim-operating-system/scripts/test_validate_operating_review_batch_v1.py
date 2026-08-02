#!/usr/bin/env python3
"""Adversarial tests for operating-review batch coverage."""

from __future__ import annotations

import copy
import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POLICY = json.loads((ROOT / "references" / "triggered-operating-review-policy.json").read_text(encoding="utf-8"))
SCRIPT = Path(__file__).with_name("validate_operating_review_batch_v1.py")
SPEC = importlib.util.spec_from_file_location("operating_batch_validator", SCRIPT)
assert SPEC and SPEC.loader
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)
C = "a" * 40


def key(trigger: str, suffix: str) -> dict:
    return {
        "authorityCommit": C,
        "taskId": "PLAY-089",
        "routeId": f"route-{suffix}",
        "trigger": trigger,
        "candidateOrResultCommit": C,
    }


def receipt(event_key: dict, size: int = 100) -> dict:
    return {"eventKey": copy.deepcopy(event_key), "compactContext": {"bytes": size}}


def manifest(keys: list[dict]) -> dict:
    return {
        "schema": 1,
        "sourceEventEnvelope": {"path": "event.json", "sha256": "a" * 64},
        "eventKeys": keys,
        "receiptPaths": [f"{index}.json" for index in range(len(keys))],
    }


def envelope(keys: list[dict]) -> dict:
    return {"schema": 1, "eventKeys": copy.deepcopy(keys)}


class OperatingReviewBatchTests(unittest.TestCase):
    def test_complete_ordered_batch_passes(self) -> None:
        keys = [key("delegation_ready_for_dispatch", "a"), key("dispatch_published", "b")]
        batch = manifest(keys)
        self.assertEqual(MOD.validate_batch(batch, [receipt(item) for item in keys], POLICY, envelope(keys)), [])

    def test_missing_receipt_for_declared_trigger_fails(self) -> None:
        keys = [key("dispatch_published", "a"), key("authority_acknowledged", "b")]
        batch = manifest(keys)
        self.assertTrue(MOD.validate_batch(batch, [receipt(keys[0])], POLICY, envelope(keys)))

    def test_manifest_cannot_omit_source_envelope_trigger(self) -> None:
        source_keys = [key("dispatch_published", "a"), key("authority_acknowledged", "b")]
        manifest_keys = source_keys[:1]
        batch = manifest(manifest_keys)
        self.assertTrue(MOD.validate_batch(batch, [receipt(manifest_keys[0])], POLICY, envelope(source_keys)))

    def test_duplicate_or_reordered_event_fails(self) -> None:
        first = key("dispatch_published", "a")
        batch = manifest([first, first])
        self.assertTrue(MOD.validate_batch(batch, [receipt(first), receipt(first)], POLICY, envelope([first, first])))
        second = key("authority_acknowledged", "b")
        batch = manifest([first, second])
        self.assertTrue(MOD.validate_batch(batch, [receipt(second), receipt(first)], POLICY, envelope([first, second])))

    def test_immediate_events_must_come_first(self) -> None:
        keys = [key("dispatch_published", "a"), key("delegation_ready_for_dispatch", "b")]
        batch = manifest(keys)
        self.assertTrue(MOD.validate_batch(batch, [receipt(item) for item in keys], POLICY, envelope(keys)))

    def test_batch_caps_are_enforced(self) -> None:
        keys = [key("dispatch_published", str(index)) for index in range(9)]
        batch = manifest(keys)
        self.assertTrue(MOD.validate_batch(batch, [receipt(item) for item in keys], POLICY, envelope(keys)))
        two = keys[:2]
        batch = manifest(two)
        self.assertTrue(MOD.validate_batch(batch, [receipt(item, 20000) for item in two], POLICY, envelope(two)))


if __name__ == "__main__":
    unittest.main()
