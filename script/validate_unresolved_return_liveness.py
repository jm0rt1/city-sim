#!/usr/bin/env python3
"""Fail closed unless every unresolved return has one concrete successor."""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


SHA1 = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
DEPENDENCY_FIELDS = (
    "taskId",
    "owner",
    "routeId",
    "commit",
    "artifactPath",
    "artifactSha256",
    "resumeWhen",
)


class LivenessError(ValueError):
    pass


def _non_empty(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict) or set(payload) != {"schema", "unresolvedReturns"}:
        raise LivenessError("liveness input must contain exactly schema and unresolvedReturns")
    if payload["schema"] != 1 or not isinstance(payload["unresolvedReturns"], list):
        raise LivenessError("liveness input must be schema 1 with an unresolvedReturns array")

    validated = []
    for index, item in enumerate(payload["unresolvedReturns"]):
        if not isinstance(item, dict) or set(item) != {"returnId", "nextOwner", "serializedDependency"}:
            raise LivenessError(f"return {index} must contain exactly returnId, nextOwner, and serializedDependency")
        if not _non_empty(item["returnId"]):
            raise LivenessError(f"return {index} returnId must be a non-empty string")
        owner_present = _non_empty(item["nextOwner"])
        dependency = item["serializedDependency"]
        dependency_present = isinstance(dependency, dict)
        if owner_present == dependency_present:
            raise LivenessError(f"return {item['returnId']} requires exactly one nextOwner or serializedDependency")
        if dependency_present:
            if set(dependency) != set(DEPENDENCY_FIELDS):
                raise LivenessError(f"return {item['returnId']} serialized dependency has the wrong fields")
            for field in ("taskId", "owner", "routeId", "artifactPath", "resumeWhen"):
                if not _non_empty(dependency[field]):
                    raise LivenessError(f"return {item['returnId']} dependency {field} must be a non-empty string")
            if not isinstance(dependency["commit"], str) or not SHA1.fullmatch(dependency["commit"]):
                raise LivenessError(f"return {item['returnId']} dependency commit must be a 40-character SHA")
            if not isinstance(dependency["artifactSha256"], str) or not SHA256.fullmatch(dependency["artifactSha256"]):
                raise LivenessError(f"return {item['returnId']} dependency artifactSha256 must be a 64-character SHA")
        validated.append(item)

    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return {
        "schema": 1,
        "kind": "validated_unresolved_return_liveness",
        "unresolvedReturnCount": len(validated),
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
