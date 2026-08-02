#!/usr/bin/env python3
"""Emit exact Git commit/tree identities for CitySim dispatches."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


class IdentityError(ValueError):
    pass


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, text=True
    )
    if result.returncode:
        raise IdentityError(result.stderr.strip() or "git identity resolution failed")
    return result.stdout.strip()


def is_full_sha(value: str) -> bool:
    return len(value) == 40 and all(character in "0123456789abcdef" for character in value)


def resolve(repo: Path, ref: str) -> dict[str, str]:
    if not ref or any(character.isspace() for character in ref):
        raise IdentityError("ref must be non-empty and contain no whitespace")
    commit = git(repo, "rev-parse", "--verify", f"{ref}^{{commit}}")
    tree = git(repo, "show", "-s", "--format=%T", commit)
    if not is_full_sha(commit) or not is_full_sha(tree):
        raise IdentityError("Git did not return exact full commit/tree identities")
    return {"ref": ref, "commit": commit, "tree": tree}


def parse_expectations(values: list[str]) -> dict[str, str]:
    expectations: dict[str, str] = {}
    for value in values:
        if "=" not in value:
            raise IdentityError("expected identity must use ref=full_sha")
        ref, expected = value.split("=", 1)
        if not ref or ref in expectations:
            raise IdentityError("expected refs must be non-empty and unique")
        if not is_full_sha(expected):
            raise IdentityError(f"expected identity for {ref} must be 40 lowercase hex")
        expectations[ref] = expected
    return expectations


def build_receipt(repo: Path, refs: list[str], expected_values: list[str]) -> dict[str, object]:
    if not refs or len(refs) != len(set(refs)):
        raise IdentityError("refs must be non-empty and unique")
    expectations = parse_expectations(expected_values)
    if set(expectations) - set(refs):
        raise IdentityError("every expected ref must also be requested")
    identities = [resolve(repo, ref) for ref in refs]
    for identity in identities:
        expected = expectations.get(identity["ref"])
        if expected is not None and identity["commit"] != expected:
            raise IdentityError(
                f"identity mismatch for {identity['ref']}: expected {expected}, resolved {identity['commit']}"
            )
    return {
        "schema": 1,
        "repository": str(repo.resolve()),
        "identities": identities,
        "expectationsVerified": bool(expectations),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".")
    parser.add_argument("--ref", action="append", required=True)
    parser.add_argument("--expect", action="append", default=[])
    args = parser.parse_args()
    try:
        receipt = build_receipt(Path(args.repo), args.ref, args.expect)
    except IdentityError as error:
        print(f"ERROR: {error}")
        return 1
    print(json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
