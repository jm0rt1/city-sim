#!/usr/bin/env python3
"""Focused adversarial tests for the proposal-only route preflight."""

from __future__ import annotations

import copy
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from validate_route_preflight import validate_route  # noqa: E402


ROOT = "/Users/James/.codex/worktrees/c92d/city-sim"
ALLOWED = "docs/production/evidence/PLAY-089/route-prevalidation-v1"
PRODUCER = f"python3 {ALLOWED}/validate_route_preflight.py"
OUTPUT = f"{ALLOWED}/PROPOSAL-RESULT.json"


def valid_route() -> dict:
    return {
        "modelRoute": {
            "schema": 1,
            "routeId": "play-089:route-preflight-prototype:v1",
            "taskId": "PLAY-089",
            "classification": "LUNA_IMPLEMENTATION",
            "model": "gpt-5.6-luna",
            "effort": "high",
            "boundedDeliverable": "Proposal-only offline route-preflight prototype.",
            "stopCondition": "Stop after one coherent proposal-only prototype commit.",
            "assignment": {
                "branch": "codex/citysim-os-optimization",
                "worktree": ROOT,
                "expectedHead": "04ac64187415fcf58c4c9aa9bd2087acf3894fdb",
            },
            "pathPolicy": {
                "claimOwnedRoots": [ALLOWED],
                "allowed": [ALLOWED],
                "forbidden": ["Native", ".agents/skills", "docs/production/evidence/INTEGRATION"],
            },
            "validation": {
                "focusedCommands": [
                    f"python3 {ALLOWED}/test_validate_route_preflight.py",
                    f"python3 -m json.tool {OUTPUT}",
                    "git diff --check",
                ]
            },
            "preflightContract": {
                "repositoryRoot": ROOT,
                "producer": {"command": PRODUCER, "outputPath": OUTPUT},
                "output": {"path": OUTPUT, "format": "JSON"},
            },
        }
    }


def expect_invalid(name: str, route: dict, code: str, repository_root: str = ROOT) -> None:
    result = validate_route(route, repository_root)
    assert not result["valid"], f"{name}: route unexpectedly valid"
    assert code in {error["code"] for error in result["errors"]}, (name, result)


def main() -> None:
    valid = validate_route(valid_route(), ROOT)
    assert valid == {"valid": True, "errors": []}, valid

    missing_root = copy.deepcopy(valid_route())
    missing_root["modelRoute"]["preflightContract"].pop("repositoryRoot")
    expect_invalid("missing repository-root argument", missing_root, "invalid_repository_root")

    invalid_root = copy.deepcopy(valid_route())
    invalid_root["modelRoute"]["preflightContract"]["repositoryRoot"] = "relative/repository"
    expect_invalid("invalid repository-root argument", invalid_root, "invalid_repository_root", "relative/repository")

    unsafe_output = copy.deepcopy(valid_route())
    unsafe_output["modelRoute"]["preflightContract"]["output"]["path"] = "docs/production/claims/not-owned.json"
    expect_invalid("output outside claim root", unsafe_output, "unsafe_output_path")

    missing_contract = copy.deepcopy(valid_route())
    missing_contract["modelRoute"].pop("preflightContract")
    expect_invalid("missing producer/output contract", missing_contract, "missing_preflight_contract")

    invalid_command = copy.deepcopy(valid_route())
    invalid_command["modelRoute"]["validation"]["focusedCommands"][0] = "python3 /tmp/unowned.py"
    expect_invalid("invalid focused producer command", invalid_command, "invalid_focused_command")

    shell_command = copy.deepcopy(valid_route())
    shell_command["modelRoute"]["validation"]["focusedCommands"][0] += " && rm -rf /tmp"
    expect_invalid("shell operator", shell_command, "invalid_focused_command")

    print("PASS: valid exact-route projection")
    print("PASS: 6 adversarial route-preflight cases")


if __name__ == "__main__":
    main()
