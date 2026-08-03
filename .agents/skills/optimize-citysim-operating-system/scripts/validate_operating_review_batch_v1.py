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


def _confined_path(root: Path, supplied: str, label: str) -> tuple[Path | None, list[str]]:
    candidate = Path(supplied)
    candidate = candidate.resolve() if candidate.is_absolute() else (root / candidate).resolve()
    try:
        candidate.relative_to(root.resolve())
        return candidate, []
    except ValueError:
        return None, [f"{label} must remain inside its declared root"]


def _read_bound_json(root: Path, relative_path: object, label: str) -> tuple[object | None, bytes | None, list[str]]:
    if not isinstance(relative_path, str) or not relative_path:
        return None, None, [f"{label} path must be a nonempty repo-relative string"]
    candidate = (root / relative_path).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError:
        return None, None, [f"{label} path must remain inside its declared root"]
    try:
        payload = candidate.read_bytes()
        return json.loads(payload), payload, []
    except (OSError, json.JSONDecodeError, UnicodeError):
        return None, None, [f"{label} must be readable JSON"]


def load_bound_inputs(manifest: object, output_root: Path, authority_root: Path) -> tuple[object | None, bytes | None, list[object], list[str]]:
    errors: list[str] = []
    source_binding = manifest.get("sourceEventEnvelope", {}) if isinstance(manifest, dict) else {}
    source_envelope, source_bytes, source_errors = _read_bound_json(
        authority_root, source_binding.get("path"), "source event envelope"
    )
    errors.extend(source_errors)
    receipts: list[object] = []
    receipt_paths = manifest.get("receiptPaths", []) if isinstance(manifest, dict) else []
    if not isinstance(receipt_paths, list):
        return source_envelope, source_bytes, receipts, errors + ["receipt paths must be a list"]
    for path in receipt_paths:
        receipt, _, receipt_errors = _read_bound_json(output_root, path, "batch receipt")
        errors.extend(receipt_errors)
        if receipt is not None:
            receipts.append(receipt)
    return source_envelope, source_bytes, receipts, errors


def _within(path: str, root: str) -> bool:
    return path == root or path.startswith(root.rstrip("/") + "/")


def validate_output_paths(
    manifest_path: Path | None,
    manifest: object,
    receipts: list[object],
    output_root: Path,
    observer_allowed: list[str] | None = None,
) -> list[str]:
    errors: list[str] = []
    if manifest_path is None or not isinstance(manifest, dict):
        return ["batch manifest path must be one exact model-route allowed output"]
    relative_manifest = manifest_path.resolve().relative_to(output_root.resolve()).as_posix()
    receipt_paths = manifest.get("receiptPaths", [])
    if not isinstance(receipt_paths, list) or len(receipt_paths) != len(receipts):
        return ["batch receipt paths must exactly match loaded receipts"]
    if observer_allowed is not None:
        for path in [relative_manifest, *receipt_paths]:
            if not any(_within(path, root) for root in observer_allowed):
                errors.append("batch output must remain inside the exact observer route")
        return errors
    for receipt_path, receipt in zip(receipt_paths, receipts):
        allowed = receipt.get("binding", {}).get("allowedPaths") if isinstance(receipt, dict) else None
        if not isinstance(allowed, list) or relative_manifest not in allowed:
            errors.append("batch manifest path must be one exact model-route allowed output")
        if not isinstance(allowed, list) or receipt_path not in allowed:
            errors.append("batch receipt path must be one exact model-route allowed output")
    return errors


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
    parser.add_argument("--policy")
    parser.add_argument("--ledger", required=True)
    parser.add_argument("--repo-root", required=True, help="exact worker/output Git root")
    parser.add_argument(
        "--authority-root",
        help="exact Integration authority Git root; defaults to --repo-root for integrated validation",
    )
    parser.add_argument("--observer-dispatch", help="schema-2 PLAY-089 observer dispatch receipt in the authority root")
    parser.add_argument("--observer-route-id", help="exact PLAY-089 observer route ID")
    args = parser.parse_args()
    output_root = Path(args.repo_root).resolve()
    authority_root = Path(args.authority_root or args.repo_root).resolve()
    manifest_path, errors = _confined_path(output_root, args.manifest, "batch manifest path")
    policy_supplied = args.policy or ".agents/skills/optimize-citysim-operating-system/references/triggered-operating-review-policy.json"
    policy_path, path_errors = _confined_path(authority_root, policy_supplied, "policy path")
    errors.extend(path_errors)
    ledger_path, path_errors = _confined_path(authority_root, args.ledger, "ledger path")
    errors.extend(path_errors)
    try:
        policy = json.loads(policy_path.read_bytes()) if policy_path else None
        manifest = json.loads(manifest_path.read_bytes()) if manifest_path else None
        ledger = json.loads(ledger_path.read_bytes()) if ledger_path else None
    except (OSError, json.JSONDecodeError, UnicodeError):
        policy = manifest = ledger = None
        errors.append("manifest, policy, and ledger must be readable JSON")
    source_binding = manifest.get("sourceEventEnvelope", {}) if isinstance(manifest, dict) else {}
    source_envelope, source_bytes, receipts, load_errors = load_bound_inputs(manifest, output_root, authority_root)
    errors.extend(load_errors)
    errors.extend(validate_batch(manifest, receipts, policy, source_envelope))
    if source_bytes is None or hashlib.sha256(source_bytes).hexdigest() != source_binding.get("sha256"):
        errors.append("source event envelope path and SHA-256 must match repository bytes")
    receipt_validator = _load_receipt_validator()
    policy_hash = hashlib.sha256(policy_path.read_bytes()).hexdigest() if policy_path and policy_path.is_file() else ""
    if not receipt_validator._is_git_repo(output_root):
        errors.append("worker/output root must be the exact root of a Git repository")
    observer_allowed = None
    if bool(args.observer_dispatch) != bool(args.observer_route_id):
        errors.append("observer dispatch and route ID must be supplied together")
    elif args.observer_dispatch:
        relative_manifest = manifest_path.relative_to(output_root).as_posix() if manifest_path else ""
        receipt_paths = manifest.get("receiptPaths", []) if isinstance(manifest, dict) else []
        observer_allowed, observer_errors = receipt_validator.validate_observer_output_route(
            args.observer_dispatch,
            args.observer_route_id,
            authority_root,
            output_root,
            [relative_manifest, *receipt_paths],
        )
        errors.extend(observer_errors)
    for receipt in receipts:
        errors.extend(
            receipt_validator.validate(
                receipt,
                policy,
                policy_hash,
                ledger,
                authority_root,
                require_git_repo=True,
                output_root=output_root,
                observed_output_root=not bool(args.observer_dispatch),
            )
        )
    errors.extend(validate_output_paths(manifest_path, manifest, receipts, output_root, observer_allowed))
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PASS: operating review batch")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
