#!/usr/bin/env python3
"""Validate the PLAY-081 West v4 baseline repair without DCC or writes."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any

import validate_zero_pixel_v3_successor as v3
from west_path_safety import lexical_repository_path


SOURCE_ROOT = v3.SOURCE_ROOT
EVIDENCE_ROOT = v3.EVIDENCE_ROOT
DEFAULT_HANDOFF = f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V4-SUCCESSOR-HANDOFF.json"
DEFAULT_CASES = (
    f"{SOURCE_ROOT}/fixtures/zero-pixel-v4-successor/FAIL-CLOSED-CASES.json"
)
PUBLISHED_MASTER = "4d3428ddc62aec439859d4121814bc02928cfda6"
EXPECTED_V3_COMMITS = {
    "v3ImplementationCommit": "3c29afe2894c45206624594207ebddf290212061",
    "v3EvidenceCommit": "1dc4cf30096885c382830aa72bfa1998b7697557",
}
EXPECTED_V3_PREDECESSORS = {
    "predecessorV3Handoff": {
        "path": f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V3-SUCCESSOR-HANDOFF.json",
        "sha256": (
            "e118391db6a1264a13edb946ad9b210e3d926803df706352e67c1c146ae3816f"
        ),
    },
    "predecessorV3Validation": {
        "path": f"{EVIDENCE_ROOT}/WEST-ZERO-PIXEL-V3-SUCCESSOR-VALIDATION.json",
        "sha256": (
            "5d74ba573a66cadc9d3f6607c62cc47a9c70ae59681f289379e59a0b49734350"
        ),
    },
    "predecessorV3Validator": {
        "path": f"{SOURCE_ROOT}/validate_zero_pixel_v3_successor.py",
        "sha256": (
            "d858197a383c495c4204b1fdb4921af8c66b8b3b5dd4eb3b0e549bac5ac7f63e"
        ),
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--handoff", default=DEFAULT_HANDOFF)
    parser.add_argument("--cases", default=DEFAULT_CASES)
    return parser.parse_args()


def validate_handoff(
    root: Path,
    handoff: dict[str, Any],
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    reads: list[str] = []
    if handoff.get("schema") != (
        "citysim.play-081.west-zero-pixel-successor-handoff.v4"
    ):
        errors.append("handoff:schema")
    if handoff.get("schemaVersion") != 4:
        errors.append("handoff:schemaVersion")

    lineage = handoff.get("lineage")
    if not isinstance(lineage, dict):
        errors.append("lineage:shape")
    else:
        if lineage.get("publishedMaster") != PUBLISHED_MASTER:
            errors.append("lineage:publishedMaster")
        elif not v3.git_ancestor(root, PUBLISHED_MASTER):
            errors.append("lineage:publishedMaster-not-ancestor")
        for key, expected in EXPECTED_V3_COMMITS.items():
            if lineage.get(key) != expected:
                errors.append(f"lineage:{key}")
            elif not v3.git_ancestor(root, expected):
                errors.append(f"lineage:{key}-not-ancestor")
        for key, expected in EXPECTED_V3_PREDECESSORS.items():
            supplied = lineage.get(key)
            errors.extend(
                v3._exact_binding(  # noqa: SLF001
                    root,
                    supplied,
                    expected,
                    f"lineage:{key}",
                    reads,
                )
            )
            if not isinstance(supplied, dict) or supplied.get(
                "preservedByteForByte"
            ) is not True:
                errors.append(f"lineage:{key}:preservation")

    normalized = copy.deepcopy(handoff)
    normalized["schema"] = (
        "citysim.play-081.west-zero-pixel-successor-handoff.v3"
    )
    normalized["schemaVersion"] = 3
    normalized_lineage = normalized.get("lineage")
    if isinstance(normalized_lineage, dict):
        normalized_lineage["publishedMaster"] = v3.PUBLISHED_MASTER
    predecessor_errors, predecessor_reads = v3.validate_handoff(
        root,
        normalized,
    )
    errors.extend(predecessor_errors)
    reads.extend(predecessor_reads)
    return sorted(set(errors)), sorted(set(reads))


def build_report(
    root: Path,
    handoff_relative: str = DEFAULT_HANDOFF,
    cases_relative: str = DEFAULT_CASES,
) -> dict[str, Any]:
    handoff_path = lexical_repository_path(
        root,
        handoff_relative,
        expected=DEFAULT_HANDOFF,
    )
    cases_path = lexical_repository_path(
        root,
        cases_relative,
        expected=DEFAULT_CASES,
    )
    handoff = v3.load_json(handoff_path)
    cases = v3.load_json(cases_path)
    valid_errors, reads = validate_handoff(root, handoff)
    results: list[dict[str, Any]] = []
    for case in cases.get("cases", []):
        candidate = copy.deepcopy(handoff)
        v3._set_mutation(  # noqa: SLF001
            candidate,
            case["mutationPath"],
            case["value"],
        )
        errors, case_reads = validate_handoff(root, candidate)
        mutated_value = case["value"]
        sibling_path_read = (
            isinstance(mutated_value, str)
            and ("PLAY-079/" in mutated_value or "PLAY-080/" in mutated_value)
            and mutated_value in case_reads
        )
        results.append(
            {
                "name": case["name"],
                "expectedError": case["expectedError"],
                "errors": errors,
                "expectedErrorObserved": case["expectedError"] in errors,
                "siblingPathRead": sibling_path_read,
                "passed": (
                    bool(errors)
                    and case["expectedError"] in errors
                    and not sibling_path_read
                ),
            }
        )
    forbidden_outputs = v3._forbidden_outputs(root)  # noqa: SLF001
    all_cases_passed = bool(results) and all(
        result["passed"] for result in results
    )
    return {
        "schema": "citysim.play-081.west-zero-pixel-successor-validation.v4",
        "schemaVersion": 4,
        "taskId": "PLAY-081",
        "direction": "west",
        "stage": "zero_pixel_prelock",
        "publishedMaster": PUBLISHED_MASTER,
        "handoff": {
            "path": handoff_relative,
            "sha256": v3.sha256(handoff_path),
            "referencedPathCount": len(reads),
            "errors": valid_errors,
            "passed": not valid_errors,
        },
        "cases": {
            "path": cases_relative,
            "sha256": v3.sha256(cases_path),
            "caseCount": len(results),
        },
        "adversarialCases": results,
        "allAdversarialCasesPassed": all_cases_passed,
        "forbiddenOutputs": forbidden_outputs,
        "invocations": dict(v3.ZERO_INVOCATIONS),
        "appearanceLockPublished": False,
        "sourceProductionProfilePublished": False,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "shipping": False,
        "passed": not valid_errors and all_cases_passed and not forbidden_outputs,
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    if args.handoff != DEFAULT_HANDOFF or args.cases != DEFAULT_CASES:
        result = {
            "schema": (
                "citysim.play-081.west-zero-pixel-successor-validation.v4"
            ),
            "schemaVersion": 4,
            "taskId": "PLAY-081",
            "direction": "west",
            "errors": ["input-path-mismatch"],
            "invocations": dict(v3.ZERO_INVOCATIONS),
            "passed": False,
        }
    else:
        result = build_report(root, args.handoff, args.cases)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
