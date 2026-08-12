#!/usr/bin/env python3
"""Fail closed unless every unresolved return has one evidenced successor."""

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


SHA1 = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
IDENTITY_FIELDS = (
    "taskId",
    "owner",
    "routeId",
    "commit",
    "artifactPath",
    "artifactSha256",
)
RECEIVER_FIELDS = IDENTITY_FIELDS + (
    "threadId",
    "dispatchedAt",
    "acknowledgement",
    "firstJobStart",
)
DEPENDENCY_FIELDS = IDENTITY_FIELDS + ("recordedAt", "resumeWhen")


class LivenessError(ValueError):
    pass


def _non_empty(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _timestamp(value: Any, location: str) -> datetime:
    if not _non_empty(value):
        raise LivenessError(f"{location} must be a timezone-aware ISO-8601 timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise LivenessError(f"{location} must be a timezone-aware ISO-8601 timestamp") from error
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise LivenessError(f"{location} must be a timezone-aware ISO-8601 timestamp")
    return parsed


def _identity(value: Any, location: str, expected_fields: tuple[str, ...]) -> None:
    if not isinstance(value, dict) or set(value) != set(expected_fields):
        raise LivenessError(f"{location} has the wrong fields")
    for field in ("taskId", "owner", "routeId", "artifactPath"):
        if not _non_empty(value[field]):
            raise LivenessError(f"{location}.{field} must be a non-empty string")
    if not isinstance(value["commit"], str) or not SHA1.fullmatch(value["commit"]):
        raise LivenessError(f"{location}.commit must be a 40-character SHA")
    if not isinstance(value["artifactSha256"], str) or not SHA256.fullmatch(value["artifactSha256"]):
        raise LivenessError(f"{location}.artifactSha256 must be a 64-character SHA")


def _proof(
    value: Any,
    location: str,
    time_field: str,
    required_fields: set[str],
    thread_id: str,
    earliest: datetime,
    observed: datetime,
) -> None:
    if not isinstance(value, dict) or set(value) != required_fields:
        raise LivenessError(f"{location} has the wrong fields")
    for field in required_fields - {time_field}:
        if not _non_empty(value[field]):
            raise LivenessError(f"{location}.{field} must be a non-empty string")
    if value["threadId"] != thread_id:
        raise LivenessError(f"{location}.threadId must match the receiver thread")
    occurred = _timestamp(value[time_field], f"{location}.{time_field}")
    if occurred < earliest or occurred > observed:
        raise LivenessError(f"{location}.{time_field} must occur after dispatch and within the management turn")


def validate(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict) or set(payload) != {"schema", "managementTurn", "unresolvedReturns"}:
        raise LivenessError("liveness input must contain exactly schema, managementTurn, and unresolvedReturns")
    if payload["schema"] != 2 or not isinstance(payload["unresolvedReturns"], list):
        raise LivenessError("liveness input must be schema 2 with an unresolvedReturns array")

    turn = payload["managementTurn"]
    if not isinstance(turn, dict) or set(turn) != {"turnId", "startedAt", "observedAt"}:
        raise LivenessError("managementTurn has the wrong fields")
    if not _non_empty(turn["turnId"]):
        raise LivenessError("managementTurn.turnId must be a non-empty string")
    started = _timestamp(turn["startedAt"], "managementTurn.startedAt")
    observed = _timestamp(turn["observedAt"], "managementTurn.observedAt")
    if observed < started:
        raise LivenessError("managementTurn.observedAt must not precede startedAt")

    receiver_count = 0
    dependency_count = 0
    for index, item in enumerate(payload["unresolvedReturns"]):
        location = f"unresolvedReturns[{index}]"
        if not isinstance(item, dict) or set(item) != {
            "returnId", "returnedAt", "receiverReceipt", "serializedDependency"
        }:
            raise LivenessError(
                f"{location} must contain exactly returnId, returnedAt, receiverReceipt, and serializedDependency"
            )
        if not _non_empty(item["returnId"]):
            raise LivenessError(f"{location}.returnId must be a non-empty string")
        returned = _timestamp(item["returnedAt"], f"{location}.returnedAt")
        if returned < started or returned > observed:
            raise LivenessError(f"{location}.returnedAt must occur within the management turn")

        receiver = item["receiverReceipt"]
        dependency = item["serializedDependency"]
        receiver_present = isinstance(receiver, dict)
        dependency_present = isinstance(dependency, dict)
        if receiver_present == dependency_present:
            raise LivenessError(
                f"return {item['returnId']} requires exactly one receiverReceipt or serializedDependency"
            )

        if receiver_present:
            receiver_location = f"{location}.receiverReceipt"
            _identity(receiver, receiver_location, RECEIVER_FIELDS)
            if not _non_empty(receiver["threadId"]):
                raise LivenessError(f"{receiver_location}.threadId must be a non-empty string")
            dispatched = _timestamp(receiver["dispatchedAt"], f"{receiver_location}.dispatchedAt")
            if dispatched < returned or dispatched > observed:
                raise LivenessError(
                    f"{receiver_location}.dispatchedAt must occur after the return and within the management turn"
                )
            acknowledgement = receiver["acknowledgement"]
            first_job_start = receiver["firstJobStart"]
            if not isinstance(acknowledgement, dict) and not isinstance(first_job_start, dict):
                raise LivenessError(
                    f"{receiver_location} requires acknowledgement or firstJobStart evidence"
                )
            if acknowledgement is not None:
                _proof(
                    acknowledgement,
                    f"{receiver_location}.acknowledgement",
                    "acknowledgedAt",
                    {"threadId", "evidenceId", "acknowledgedAt"},
                    receiver["threadId"],
                    dispatched,
                    observed,
                )
            if first_job_start is not None:
                _proof(
                    first_job_start,
                    f"{receiver_location}.firstJobStart",
                    "startedAt",
                    {"threadId", "jobId", "evidenceId", "startedAt"},
                    receiver["threadId"],
                    dispatched,
                    observed,
                )
            receiver_count += 1
        else:
            dependency_location = f"{location}.serializedDependency"
            _identity(dependency, dependency_location, DEPENDENCY_FIELDS)
            if not _non_empty(dependency["resumeWhen"]):
                raise LivenessError(f"{dependency_location}.resumeWhen must be a non-empty string")
            recorded = _timestamp(dependency["recordedAt"], f"{dependency_location}.recordedAt")
            if recorded < returned or recorded > observed:
                raise LivenessError(
                    f"{dependency_location}.recordedAt must occur after the return and within the management turn"
                )
            dependency_count += 1

    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return {
        "schema": 2,
        "kind": "validated_unresolved_return_liveness",
        "unresolvedReturnCount": receiver_count + dependency_count,
        "receiverCount": receiver_count,
        "dependencyCount": dependency_count,
        "livenessSha256": hashlib.sha256(canonical).hexdigest(),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = validate(json.loads(args.input.read_text()))
    except (OSError, json.JSONDecodeError, LivenessError) as error:
        print(f"RETURN: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
