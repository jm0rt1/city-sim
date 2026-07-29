#!/usr/bin/env python3
"""Validate deterministic receipts and fail-closed PLAY-075 input gates."""

from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path
from typing import Any, Callable, Dict, List

sys.dont_write_bytecode = True

from materialize_fixture_receipt import (
    MaterializerError,
    PLAY075_ROOT,
    PUBLISHED_MASTER,
    build_receipt,
    canonical_bytes,
    ensure_task_owned_output,
    sha256_bytes,
    sha256_file,
    validate_admission_manifest_contents,
    validate_request,
    verify_integration_admission,
    write_receipt,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--run-a-output-root", type=Path, required=True)
    parser.add_argument("--run-b-output-root", type=Path, required=True)
    parser.add_argument("--report-output-root", type=Path, required=True)
    return parser.parse_args()


def expect_rejection(
    request: Dict[str, Any],
    name: str,
    expected_code: str,
    mutate: Callable[[Dict[str, Any]], None],
    check: Callable[[Dict[str, Any]], Any] = validate_request,
) -> Dict[str, str]:
    candidate = copy.deepcopy(request)
    mutate(candidate)
    try:
        check(candidate)
    except MaterializerError as error:
        if error.code != expected_code:
            raise AssertionError(
                f"{name}: expected {expected_code}, received {error.code}"
            ) from error
        return {"case": name, "status": "REJECTED", "code": error.code}
    raise AssertionError(f"{name}: request unexpectedly passed")


def bind_missing_admission(request: Dict[str, Any]) -> None:
    request["mode"] = "candidate_bound"
    request["admissionManifest"] = {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-admissions/nonexistent.json"
        ),
        "sha256": "0" * 64,
        "publishedManifestCommit": PUBLISHED_MASTER,
    }


def synthetic_admission_manifest(request: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "schemaVersion": 1,
        "issuedBy": "Integration",
        "disposition": (
            "EXACT_RENDERER_CANDIDATE_ADMITTED_FOR_PLAY075_FIXTURE_PREPARATION"
        ),
        "baseFixture": copy.deepcopy(request["baseFixture"]),
        "rendererCandidate": copy.deepcopy(request["rendererCandidate"]),
        "directionBridge": copy.deepcopy(request["directionBridge"]),
        "packets": copy.deepcopy(request["packets"]),
        "productionSelected": False,
        "qaDispositionDeclared": False,
    }


def expect_manifest_rejection(
    request: Dict[str, Any],
    manifest: Dict[str, Any],
    name: str,
    expected_code: str,
    mutate: Callable[[Dict[str, Any]], None],
) -> Dict[str, str]:
    candidate = copy.deepcopy(manifest)
    mutate(candidate)
    try:
        validate_admission_manifest_contents(request, candidate)
    except MaterializerError as error:
        if error.code != expected_code:
            raise AssertionError(
                f"{name}: expected {expected_code}, received {error.code}"
            ) from error
        return {"case": name, "status": "REJECTED", "code": error.code}
    raise AssertionError(f"{name}: manifest unexpectedly passed")


def main() -> int:
    args = parse_args()
    request = json.loads(args.request.read_text(encoding="utf-8"))
    validated = validate_request(request)
    admission = verify_integration_admission(validated)
    if admission is not None:
        raise AssertionError("contract rehearsal unexpectedly has admission")
    receipt_a = build_receipt(validated)
    receipt_b = build_receipt(copy.deepcopy(validated))
    if (
        receipt_a["rendererCandidate"]["eligibleForFutureFixtureMaterialization"]
        is not False
        or receipt_a["rendererCandidate"]["candidateOrPacketExistenceVerified"]
        is not False
    ):
        raise AssertionError("rehearsal identity became eligible or verified")
    path_a = write_receipt(receipt_a, args.run_a_output_root)
    path_b = write_receipt(receipt_b, args.run_b_output_root)
    bytes_a = path_a.read_bytes()
    bytes_b = path_b.read_bytes()
    if bytes_a != bytes_b:
        raise AssertionError("repeat receipts differ")

    negative_results: List[Dict[str, str]] = []
    negative_results.append(
        expect_rejection(
            request,
            "rehearsal-mode-flip",
            "ADMISSION_MANIFEST_REQUIRED",
            lambda value: value.update({"mode": "candidate_bound"}),
            build_receipt,
        )
    )
    negative_results.append(
        expect_rejection(
            request,
            "nonexistent-integration-admission",
            "ADMISSION_MANIFEST_NOT_PUBLISHED",
            bind_missing_admission,
            lambda value: verify_integration_admission(validate_request(value)),
        )
    )
    candidate_bound = copy.deepcopy(request)
    bind_missing_admission(candidate_bound)
    validate_request(candidate_bound)
    synthetic_manifest = synthetic_admission_manifest(candidate_bound)
    negative_results.append(
        expect_manifest_rejection(
            candidate_bound,
            synthetic_manifest,
            "packet-identity-not-admitted",
            "PACKET_NOT_ADMITTED",
            lambda value: value.update({"packets": value["packets"][:3]}),
        )
    )
    negative_results.append(
        expect_manifest_rejection(
            candidate_bound,
            synthetic_manifest,
            "packet-identity-unbound-from-admission",
            "UNBOUND_PACKET_IDENTITY",
            lambda value: value["packets"][0].update(
                {"packetSha256": "e" * 64}
            ),
        )
    )
    for direction_count in (1, 2, 3):
        negative_results.append(
            expect_rejection(
                request,
                f"{direction_count}-direction-input",
                "ATOMIC_4_OF_4_REQUIRED",
                lambda value, count=direction_count: value.update(
                    {"packets": value["packets"][:count]}
                ),
            )
        )
    try:
        ensure_task_owned_output(PLAY075_ROOT.parent / "not-play075-output")
    except MaterializerError as error:
        if error.code != "OUTPUT_OUTSIDE_TASK_ROOT":
            raise AssertionError(
                "outside-output-root: expected OUTPUT_OUTSIDE_TASK_ROOT, "
                f"received {error.code}"
            ) from error
        negative_results.append(
            {
                "case": "outside-output-root",
                "status": "REJECTED",
                "code": error.code,
            }
        )
    else:
        raise AssertionError("outside-output-root: path unexpectedly accepted")
    negative_results.append(
        expect_rejection(
            request,
            "stale-candidate",
            "STALE_CANDIDATE",
            lambda value: value["rendererCandidate"].update({"stale": True}),
        )
    )
    negative_results.append(
        expect_rejection(
            request,
            "admitted-candidate-mismatch",
            "STALE_CANDIDATE",
            lambda value: value["rendererCandidate"].update(
                {"admittedCommit": "7777777777777777777777777777777777777777"}
            ),
        )
    )
    negative_results.append(
        expect_rejection(
            request,
            "unbound-packet-hash",
            "UNBOUND_PACKET_HASH",
            lambda value: value["packets"][0].update(
                {"boundPacketSha256": "0" * 64}
            ),
        )
    )
    negative_results.append(
        expect_rejection(
            request,
            "runtime-socket-mismatch",
            "RUNTIME_SOCKET_MISMATCH",
            lambda value: value["packets"][0].update(
                {"sourcePixelSocket": [640, 704]}
            ),
        )
    )
    negative_results.append(
        expect_rejection(
            request,
            "dcc-direction-label",
            "DCC_LABEL_INPUT",
            lambda value: value["packets"][0].update(
                {"coordinateLabelSystem": "blender_native"}
            ),
        )
    )
    negative_results.append(
        expect_rejection(
            request,
            "per-direction-transform",
            "PER_DIRECTION_TRANSFORM",
            lambda value: value["packets"][0].update(
                {"perDirectionTransform": True}
            ),
        )
    )
    negative_results.append(
        expect_rejection(
            request,
            "alias-input",
            "ALIAS_OR_FALLBACK",
            lambda value: value["packets"][0].update({"aliasOf": "east"}),
        )
    )
    negative_results.append(
        expect_rejection(
            request,
            "mutable-candidate-default",
            "MUTABLE_OR_INEXACT_IDENTITY",
            lambda value: value["rendererCandidate"].update({"commit": "HEAD"}),
        )
    )

    report = {
        "schemaVersion": 1,
        "disposition": "FIXTURE_MATERIALIZER_PREPARATION_VALID",
        "requestCanonicalSha256": sha256_bytes(canonical_bytes(request)),
        "repeatReceiptSha256": sha256_file(path_a),
        "repeatReceiptsByteIdentical": True,
        "runA": str(path_a.relative_to(PLAY075_ROOT)),
        "runB": str(path_b.relative_to(PLAY075_ROOT)),
        "negativeGates": negative_results,
        "candidateBoundAuthorityPolicy": (
            "BYTE_IDENTICAL_MANIFEST_PUBLISHED_AT_ORIGIN_MASTER_REQUIRED"
        ),
        "rehearsalEligibleForFutureFixtureMaterialization": False,
        "rehearsalCandidateOrPacketExistenceVerified": False,
        "fixtureFilesCreated": [],
        "appRunOrScored": False,
        "productOrResourcesMutated": False,
        "qaDispositionDeclared": False,
    }
    report_root = ensure_task_owned_output(args.report_output_root)
    report_path = report_root / "VALIDATION-RECEIPT.json"
    payload = canonical_bytes(report)
    if report_path.exists() and report_path.read_bytes() != payload:
        raise AssertionError(f"existing validation report differs: {report_path}")
    if not report_path.exists():
        report_path.write_bytes(payload)
    print(
        json.dumps(
            {
                "status": report["disposition"],
                "receiptSha256": report["repeatReceiptSha256"],
                "negativeGateCount": len(negative_results),
                "report": str(report_path),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
