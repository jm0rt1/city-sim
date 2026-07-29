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
    build_receipt,
    canonical_bytes,
    ensure_task_owned_output,
    sha256_bytes,
    sha256_file,
    validate_request,
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
) -> Dict[str, str]:
    candidate = copy.deepcopy(request)
    mutate(candidate)
    try:
        validate_request(candidate)
    except MaterializerError as error:
        if error.code != expected_code:
            raise AssertionError(
                f"{name}: expected {expected_code}, received {error.code}"
            ) from error
        return {"case": name, "status": "REJECTED", "code": error.code}
    raise AssertionError(f"{name}: request unexpectedly passed")


def main() -> int:
    args = parse_args()
    request = json.loads(args.request.read_text(encoding="utf-8"))
    validated = validate_request(request)
    receipt_a = build_receipt(validated)
    receipt_b = build_receipt(copy.deepcopy(validated))
    path_a = write_receipt(receipt_a, args.run_a_output_root)
    path_b = write_receipt(receipt_b, args.run_b_output_root)
    bytes_a = path_a.read_bytes()
    bytes_b = path_b.read_bytes()
    if bytes_a != bytes_b:
        raise AssertionError("repeat receipts differ")

    negative_results: List[Dict[str, str]] = []
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
