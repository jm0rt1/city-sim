#!/usr/bin/env python3
"""Fail-closed validator for schema-3 triggered operating-review receipts."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


DEFAULT_ROUTE = {"classification": "LUNA_MECHANICAL", "model": "gpt-5.6-luna", "effort": "medium"}
HEX64 = set("0123456789abcdef")


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _hash(value: object) -> bool:
    return isinstance(value, str) and len(value) == 64 and set(value) <= HEX64


def _strings(value: object) -> bool:
    return isinstance(value, list) and all(isinstance(item, str) and item for item in value)


def _requirement(policy: dict, trigger: str) -> dict | None:
    requirements = policy.get("eventRequirements")
    if not isinstance(requirements, dict):
        return None
    entry = requirements.get(trigger)
    if isinstance(entry, dict):
        evidence = entry.get("requiredEvidence")
        decisions = entry.get("allowedDecisions")
        if set(entry) == {"requiredEvidence", "allowedDecisions"} and _strings(evidence) and _strings(decisions):
            return entry
    return None


def _present(value: object) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value)
    if isinstance(value, (list, dict)):
        return bool(value)
    return isinstance(value, (bool, int, float))


def _ledger_rows(ledger: object) -> list[object] | None:
    if isinstance(ledger, list):
        return ledger
    if isinstance(ledger, dict):
        for key in ("receipts", "events"):
            if isinstance(ledger.get(key), list):
                return ledger[key]
    return None


def validate(receipt: object, policy: object, policy_sha256: str, ledger: object | None = None) -> list[str]:
    errors: list[str] = []
    if not isinstance(policy, dict) or policy.get("schema") != 3:
        return ["policy must be schema 3"]
    if policy.get("defaultRoute") != DEFAULT_ROUTE:
        errors.append("policy default route must be Luna mechanical/medium")
    keys = policy.get("eventKeyFields")
    if not _strings(keys) or len(keys) != len(set(keys)):
        errors.append("policy eventKeyFields must be a unique nonempty string list")
        keys = []
    if not isinstance(receipt, dict):
        return errors + ["receipt must be an object"]
    budget = policy.get("reviewBudget") if isinstance(policy.get("reviewBudget"), dict) else {}
    if not _hash(receipt.get("policySha256")) or receipt.get("policySha256") != policy_sha256:
        errors.append("receipt policySha256 must bind the exact policy bytes")
    if receipt.get("modelRoute") != DEFAULT_ROUTE:
        errors.append("receipt route must be Luna mechanical/medium")
    event_key = receipt.get("eventKey")
    if not isinstance(event_key, dict) or list(event_key) != keys or not all(isinstance(event_key.get(key), str) and event_key[key] for key in keys):
        errors.append("receipt eventKey fields must exactly match policy order and values")
        trigger = None
    else:
        trigger = event_key.get("trigger")
    if trigger not in policy.get("triggers", []):
        errors.append("receipt trigger must be legal")
    decision = receipt.get("decision")
    if decision not in policy.get("allowedDecisions", []):
        errors.append("receipt decision must be legal")

    context = receipt.get("compactContext")
    context_cap = budget.get("maxCompactContextBytes") if isinstance(budget, dict) else None
    if not isinstance(context, dict) or set(context) != {"mode", "hashes", "bytes"} or context.get("mode") != "compact_hash_bound" or not isinstance(context.get("bytes"), int) or context["bytes"] < 0 or not isinstance(context_cap, int) or context["bytes"] > context_cap or not isinstance(context.get("hashes"), dict) or not context["hashes"] or not all(isinstance(k, str) and k and _hash(v) for k, v in context["hashes"].items()):
        errors.append("receipt compactContext must contain hash-bound hashes and byte count")
    inputs = receipt.get("inputReceipts")
    if not isinstance(inputs, list) or not inputs:
        errors.append("receipt must identify input receipt hashes")
    else:
        seen: set[str] = set()
        for item in inputs:
            if not isinstance(item, dict) or set(item) != {"path", "sha256"} or not isinstance(item.get("path"), str) or not item["path"] or not _hash(item.get("sha256")) or item["path"] in seen:
                errors.append("input receipt hashes must be exact and unique")
                break
            seen.add(item["path"])
    action = receipt.get("nextAction")
    if not isinstance(action, dict) or set(action) != {"action", "owner", "boundedDeliverable", "stopCondition"} or not all(isinstance(value, str) and value for value in action.values()):
        errors.append("receipt must contain one bounded nextAction")
    prohibited = receipt.get("prohibitedWork")
    restricted = ("productBuildAllowed", "fullGateAllowed", "dccAllowed", "realAppQAAllowed", "sharedMutationAllowed")
    if not isinstance(prohibited, dict) or set(prohibited) != set(restricted) or any(prohibited.get(key) is not False or budget.get(key) is not False for key in restricted):
        errors.append("receipt may not perform policy-prohibited work")
    operations = receipt.get("reviewOperations")
    if operations != {"threadPolling": False, "spawnedReviews": False} or budget.get("threadPollingAllowed") is not False or budget.get("reviewCanSpawnReviews") is not False:
        errors.append("receipt may not poll tasks or spawn more reviews")
    metrics = receipt.get("metrics")
    if not isinstance(metrics, dict) or any(value is not None and not isinstance(value, (int, float)) for value in metrics.values()):
        errors.append("unknown metrics must be null or measured numbers")
    requirement = _requirement(policy, trigger) if isinstance(trigger, str) else None
    evidence = receipt.get("evidence")
    if requirement is None:
        errors.append("policy must define valid trigger-specific eventRequirements")
    elif decision not in requirement["allowedDecisions"]:
        errors.append("receipt decision is not allowed for its trigger")
    elif not isinstance(evidence, dict) or set(evidence) != set(requirement["requiredEvidence"]) or any(not _present(evidence[key]) for key in requirement["requiredEvidence"]):
        errors.append("receipt is missing trigger-required evidence")
    else:
        for key, value in evidence.items():
            if key.lower().endswith("hash") and not _hash(value):
                errors.append(f"{key} must be a SHA-256 hash")

    coverage = receipt.get("sourceCoverage")
    if receipt.get("multiLane") is True:
        fields = policy.get("coverage", {}).get("requiredRowFields") if isinstance(policy.get("coverage"), dict) else None
        directions = policy.get("coverage", {}).get("directionWorkstreams") if isinstance(policy.get("coverage"), dict) else None
        if not isinstance(coverage, list) or not isinstance(fields, list) or not isinstance(directions, list) or len(coverage) != len(directions):
            errors.append("multi-lane receipt must contain exact source coverage rows")
        else:
            streams = []
            for row in coverage:
                if not isinstance(row, dict) or list(row) != fields or not all(isinstance(row.get(field), str) and row[field] for field in fields):
                    errors.append("source coverage rows must exactly match policy fields")
                    break
                streams.append(row["workstream"])
            if streams != directions:
                errors.append("source coverage workstreams must exactly match policy")
    elif coverage not in (None, []):
        errors.append("single-lane receipt must not include source coverage")
    if ledger is not None and isinstance(event_key, dict) and list(event_key) == keys:
        rows = _ledger_rows(ledger)
        if rows is None:
            errors.append("ledger must be a receipt/event list")
        elif any(isinstance(row, dict) and row.get("eventKey") == event_key for row in rows):
            errors.append("duplicate operating-review eventKey in ledger")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    root = Path(__file__).resolve().parents[1]
    parser.add_argument("receipt")
    parser.add_argument("--policy", default=str(root / "references" / "triggered-operating-review-policy.json"))
    parser.add_argument("--ledger")
    args = parser.parse_args()
    policy_path = Path(args.policy)
    receipt = json.loads(Path(args.receipt).read_text(encoding="utf-8"))
    policy = json.loads(policy_path.read_text(encoding="utf-8"))
    ledger = json.loads(Path(args.ledger).read_text(encoding="utf-8")) if args.ledger else None
    errors = validate(receipt, policy, _sha256(policy_path), ledger)
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PASS: operating review receipt")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
