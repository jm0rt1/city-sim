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


def model_route_hash(route: dict[str, Any]) -> str:
    payload = json.dumps(route, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def select_model_route(selected: Any, carrier: str | None) -> tuple[dict[str, Any] | None, list[str]]:
    """Resolve a direct model route or one assignment from a dispatch carrier."""
    errors: list[str] = []
    route = selected
    embedded_carrier: str | None = None
    if isinstance(selected, dict) and "assignments" in selected:
        assignments = selected.get("assignments")
        if not isinstance(assignments, list) or not assignments:
            return None, ["selected route must contain at least one assignment"]
        matches = [
            assignment
            for assignment in assignments
            if isinstance(assignment, dict)
            and (carrier is None or assignment.get("modelRouteSha256") == carrier)
        ]
        if len(matches) != 1:
            return None, ["selected route carrier must identify exactly one assignment"]
        assignment = matches[0]
        route = assignment.get("modelRoute")
        embedded_carrier = assignment.get("modelRouteSha256")
    if not isinstance(route, dict):
        return None, ["selected route must be a model-route object or dispatch envelope"]
    computed = model_route_hash(route)
    if embedded_carrier is not None and embedded_carrier != computed:
        errors.append("selected route carrier does not match canonical model-route bytes")
    if carrier is not None and carrier != computed:
        errors.append("selected route carrier does not match canonical model-route bytes")
    if errors:
        return None, errors
    return route, []


def prepare(
    source: Any,
    policy: Any,
    selected_route: Any | None = None,
    carrier: str | None = None,
) -> tuple[dict[str, Any] | None, list[str]]:
    errors: list[str] = []
    if not isinstance(source, dict) or set(source) != {"schema", "eventKeys"}:
        return None, ["source must contain exactly schema and eventKeys"]
    if source.get("schema") != 1:
        errors.append("source schema must be 1")
    keys = source.get("eventKeys")
    if not isinstance(keys, list) or not 1 <= len(keys) <= 8:
        return None, errors + ["eventKeys must contain between one and eight rows"]

    route: dict[str, Any] | None = None
    if selected_route is not None:
        route, route_errors = select_model_route(selected_route, carrier)
        errors.extend(route_errors)
        if route is not None:
            authority = route.get("authority")
            if not isinstance(authority, dict) or not is_commit(authority.get("authorityCommit")):
                errors.append("selected route must bind a full authorityCommit")
            if not isinstance(route.get("taskId"), str) or not route["taskId"].strip():
                errors.append("selected route must bind a non-empty taskId")
            if not isinstance(route.get("routeId"), str) or not route["routeId"].strip():
                errors.append("selected route must bind a non-empty routeId")

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

        if route is not None:
            authority = route.get("authority", {})
            if row.get("authorityCommit") != authority.get("authorityCommit"):
                errors.append(f"{label}.authorityCommit does not match selected route")
            if row.get("taskId") != route.get("taskId"):
                errors.append(f"{label}.taskId does not match selected route")
            if row.get("routeId") != route.get("routeId"):
                errors.append(f"{label}.routeId does not match selected route")

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
    parser.add_argument("--route", help="optional selected model-route or dispatch envelope")
    parser.add_argument("--carrier", help="optional canonical model-route SHA-256 carrier")
    args = parser.parse_args()

    try:
        selected_route = load_json(Path(args.route)) if args.route else None
        prepared, errors = prepare(
            load_json(Path(args.source)),
            load_json(Path(args.policy)),
            selected_route,
            args.carrier,
        )
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
