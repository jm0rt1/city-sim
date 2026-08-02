#!/usr/bin/env python3
"""Validate one bounded batch of schema-4 operating-review receipts."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path


def _load_receipt_validator() -> object:
    script = Path(__file__).with_name("validate_operating_review_receipt_v1.py")
    spec = importlib.util.spec_from_file_location("operating_receipt_validator", script)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _canonical(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def validate_batch(manifest: object, receipts: list[object], policy: object, source_envelope: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(policy, dict) or policy.get("schema") != 4:
        return ["policy must be schema 4"]
    if not isinstance(manifest, dict) or set(manifest) != {"schema", "sourceEventEnvelope", "eventKeys", "receiptPaths"} or manifest.get("schema") != 1:
        return ["batch manifest must match schema 1"]
    source_binding = manifest.get("sourceEventEnvelope")
    if not isinstance(source_binding, dict) or set(source_binding) != {"path", "sha256"} or not isinstance(source_binding.get("path"), str) or not source_binding["path"] or not isinstance(source_binding.get("sha256"), str):
        errors.append("batch must bind one immutable source event envelope")
    if not isinstance(source_envelope, dict) or set(source_envelope) != {"schema", "eventKeys"} or source_envelope.get("schema") != 1 or not isinstance(source_envelope.get("eventKeys"), list):
        errors.append("source event envelope must match schema 1")
    event_keys = manifest.get("eventKeys")
    receipt_paths = manifest.get("receiptPaths")
    scheduling = policy.get("reviewScheduling") if isinstance(policy.get("reviewScheduling"), dict) else {}
    budget = policy.get("reviewBudget") if isinstance(policy.get("reviewBudget"), dict) else {}
    if not isinstance(event_keys, list) or not event_keys:
        errors.append("batch must contain at least one event key")
        event_keys = []
    if isinstance(source_envelope, dict) and source_envelope.get("eventKeys") != event_keys:
        errors.append("manifest event keys must exactly project the immutable source event envelope")
    if not isinstance(receipt_paths, list) or len(receipt_paths) != len(event_keys) or not all(isinstance(path, str) and path for path in receipt_paths):
        errors.append("batch must contain one receipt path per event key")
    if len(event_keys) > scheduling.get("maxEventsPerTurn", 0):
        errors.append("batch exceeds the event-per-turn cap")
    canonical_keys = [_canonical(key) for key in event_keys]
    if len(canonical_keys) != len(set(canonical_keys)):
        errors.append("batch event keys must be unique")
    receipt_keys = [receipt.get("eventKey") if isinstance(receipt, dict) else None for receipt in receipts]
    if receipt_keys != event_keys:
        errors.append("receipt event keys must exactly project the source event keys in order")
    if len(receipts) != len(event_keys):
        errors.append("batch must include every declared event receipt exactly once")
    context_total = sum(
        receipt.get("compactContext", {}).get("bytes", 0)
        for receipt in receipts
        if isinstance(receipt, dict) and isinstance(receipt.get("compactContext"), dict) and isinstance(receipt["compactContext"].get("bytes"), int)
    )
    if context_total > budget.get("maxBatchContextBytes", 0):
        errors.append("batch exceeds the aggregate compact-context cap")
    immediate = set(scheduling.get("immediateTriggers", []))
    saw_batchable = False
    for key in event_keys:
        trigger = key.get("trigger") if isinstance(key, dict) else None
        if trigger not in policy.get("triggers", []):
            errors.append("batch contains an unknown trigger")
            break
        if trigger in immediate:
            if saw_batchable:
                errors.append("immediate events must precede batchable events")
                break
        else:
            saw_batchable = True
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    root = Path(__file__).resolve().parents[1]
    parser.add_argument("manifest")
    parser.add_argument("--policy", default=str(root / "references" / "triggered-operating-review-policy.json"))
    parser.add_argument("--ledger", required=True)
    parser.add_argument("--repo-root", required=True)
    args = parser.parse_args()
    repo_root = Path(args.repo_root).resolve()
    policy_path = Path(args.policy)
    policy = json.loads(policy_path.read_text(encoding="utf-8"))
    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    source_binding = manifest.get("sourceEventEnvelope", {}) if isinstance(manifest, dict) else {}
    source_path = (repo_root / source_binding.get("path", "")).resolve()
    try:
        source_path.relative_to(repo_root)
        source_bytes = source_path.read_bytes()
        source_envelope = json.loads(source_bytes)
    except (ValueError, OSError, json.JSONDecodeError):
        source_envelope = None
    receipts = [json.loads((repo_root / path).read_text(encoding="utf-8")) for path in manifest.get("receiptPaths", [])]
    errors = validate_batch(manifest, receipts, policy, source_envelope)
    if source_envelope is None or hashlib.sha256(source_bytes).hexdigest() != source_binding.get("sha256"):
        errors.append("source event envelope path and SHA-256 must match repository bytes")
    receipt_validator = _load_receipt_validator()
    ledger = json.loads(Path(args.ledger).read_text(encoding="utf-8"))
    policy_hash = hashlib.sha256(policy_path.read_bytes()).hexdigest()
    for receipt in receipts:
        errors.extend(receipt_validator.validate(receipt, policy, policy_hash, ledger, repo_root))
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PASS: operating review batch")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
