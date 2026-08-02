#!/usr/bin/env python3
"""Prepare one deterministic, immediate-first operating-review event envelope."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
from pathlib import Path
from typing import Any


EVENT_FIELDS = {
    "authorityCommit",
    "taskId",
    "routeId",
    "trigger",
    "candidateOrResultCommit",
}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def is_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def prepare(source: Any, policy: Any) -> tuple[dict[str, Any] | None, list[str]]:
    errors: list[str] = []
    if not isinstance(source, dict) or set(source) != {"schema", "eventKeys"}:
        return None, ["source must contain exactly schema and eventKeys"]
    if source.get("schema") != 1:
        errors.append("source schema must be 1")
    keys = source.get("eventKeys")
    if not isinstance(keys, list) or not 1 <= len(keys) <= 8:
        return None, errors + ["eventKeys must contain between one and eight rows"]

    triggers = set(policy.get("triggers", [])) if isinstance(policy, dict) else set()
    immediate = set(
        policy.get("reviewScheduling", {}).get("immediateTriggers", [])
        if isinstance(policy, dict)
        else []
    )
    normalized: list[dict[str, str]] = []
    seen: set[str] = set()
    for index, row in enumerate(keys):
        label = f"eventKeys[{index}]"
        if not isinstance(row, dict) or set(row) != EVENT_FIELDS:
            errors.append(f"{label} must contain exactly the five event-key fields")
            continue
        if not is_commit(row.get("authorityCommit")):
            errors.append(f"{label}.authorityCommit must be a full lowercase Git SHA")
        if not is_commit(row.get("candidateOrResultCommit")):
            errors.append(f"{label}.candidateOrResultCommit must be a full lowercase Git SHA")
        for field in ("taskId", "routeId"):
            if not isinstance(row.get(field), str) or not row[field].strip():
                errors.append(f"{label}.{field} must be non-empty text")
        if row.get("trigger") not in triggers:
            errors.append(f"{label}.trigger is not declared by the policy")
        fingerprint = json.dumps(row, sort_keys=True, separators=(",", ":"))
        if fingerprint in seen:
            errors.append(f"{label} duplicates an earlier event key")
        seen.add(fingerprint)
        normalized.append(dict(row))

    if errors:
        return None, errors
    ordered = [row for row in normalized if row["trigger"] in immediate]
    ordered.extend(row for row in normalized if row["trigger"] not in immediate)
    return {"schema": 1, "eventKeys": ordered}, []


def write_once(path: Path, payload: bytes) -> None:
    if path.exists():
        if path.read_bytes() == payload:
            return
        raise ValueError(f"refusing to replace different existing envelope: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--policy", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    try:
        prepared, errors = prepare(load_json(Path(args.source)), load_json(Path(args.policy)))
        if errors or prepared is None:
            for error in errors:
                print(f"ERROR: {error}")
            return 1
        payload = canonical(prepared)
        write_once(Path(args.output), payload)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        print(f"ERROR: {error}")
        return 1
    print(f"PASS: operating review envelope {hashlib.sha256(payload).hexdigest()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
