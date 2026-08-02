#!/usr/bin/env python3
"""Adversarial tests for operating-review batch coverage."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import tempfile
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

    def test_external_authority_and_worker_outputs_are_separate_roots(self) -> None:
        keys = [key("dispatch_published", "a")]
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as output_tmp:
            authority_root = Path(authority_tmp)
            output_root = Path(output_tmp)
            source = envelope(keys)
            source_bytes = json.dumps(source).encode("utf-8")
            (authority_root / "event.json").write_bytes(source_bytes)
            batch = manifest(keys)
            batch["sourceEventEnvelope"]["sha256"] = hashlib.sha256(source_bytes).hexdigest()
            (output_root / "0.json").write_text(json.dumps(receipt(keys[0])), encoding="utf-8")
            loaded_source, loaded_bytes, receipts, errors = MOD.load_bound_inputs(batch, output_root, authority_root)
            self.assertEqual(errors, [])
            self.assertEqual(loaded_source, source)
            self.assertEqual(loaded_bytes, source_bytes)
            self.assertEqual(receipts, [receipt(keys[0])])

    def test_bound_inputs_fail_closed_on_missing_or_traversal(self) -> None:
        keys = [key("dispatch_published", "a")]
        with tempfile.TemporaryDirectory() as authority_tmp, tempfile.TemporaryDirectory() as output_tmp:
            authority_root = Path(authority_tmp)
            output_root = Path(output_tmp)
            batch = manifest(keys)
            batch["sourceEventEnvelope"]["path"] = "../outside.json"
            _, _, receipts, errors = MOD.load_bound_inputs(batch, output_root, authority_root)
            self.assertEqual(receipts, [])
            self.assertTrue(any("inside its declared root" in error for error in errors))
            self.assertTrue(any("batch receipt must be readable JSON" in error for error in errors))

    def test_same_root_and_exact_allowed_outputs_pass(self) -> None:
        keys = [key("dispatch_published", "a")]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = envelope(keys)
            (root / "event.json").write_text(json.dumps(source), encoding="utf-8")
            batch = manifest(keys)
            candidate_receipt = receipt(keys[0])
            candidate_receipt["binding"] = {"allowedPaths": ["BATCH.json", "0.json"]}
            (root / "0.json").write_text(json.dumps(candidate_receipt), encoding="utf-8")
            loaded_source, _, receipts, errors = MOD.load_bound_inputs(batch, root, root)
            self.assertEqual(errors, [])
            self.assertEqual(loaded_source, source)
            self.assertEqual(MOD.validate_output_paths(root / "BATCH.json", batch, receipts, root), [])
            receipts[0]["binding"]["allowedPaths"].remove("0.json")
            self.assertTrue(MOD.validate_output_paths(root / "BATCH.json", batch, receipts, root))

    def test_symlink_escape_and_malformed_utf_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as root_tmp, tempfile.TemporaryDirectory() as outside_tmp:
            root = Path(root_tmp)
            outside = Path(outside_tmp) / "outside.json"
            outside.write_text("{}", encoding="utf-8")
            (root / "link.json").symlink_to(outside)
            _, _, errors = MOD._read_bound_json(root, "link.json", "source")
            self.assertTrue(any("inside its declared root" in error for error in errors))
            (root / "bad.json").write_bytes(b"\xff\xfe")
            _, _, errors = MOD._read_bound_json(root, "bad.json", "source")
            self.assertTrue(any("readable JSON" in error for error in errors))

    def test_policy_or_ledger_path_cannot_escape_authority_root(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertTrue(MOD._confined_path(root, "../policy.json", "policy")[1])
            self.assertTrue(MOD._confined_path(root, "../ledger.json", "ledger")[1])


if __name__ == "__main__":
    unittest.main()
