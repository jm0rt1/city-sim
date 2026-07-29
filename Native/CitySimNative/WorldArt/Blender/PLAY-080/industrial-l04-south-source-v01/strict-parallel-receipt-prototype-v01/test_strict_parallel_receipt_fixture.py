#!/usr/bin/env python3
"""Exercise positive, negative, repeat, and zero-pixel receipt fixtures."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
SCHEMA = ROOT / "strict-parallel-execution-receipt-fixture-schema-v1.json"
VALIDATOR = ROOT / "validate_strict_parallel_receipt_fixture.py"
FIXTURES = ROOT / "fixtures"
POSITIVE = (
    FIXTURES / "PASS-OVERLAPPED.json",
    FIXTURES / "PASS-SEQUENTIAL-EXCEPTION.json",
)
NEGATIVE = FIXTURES / "FAIL-CLOSED-NEGATIVE-FIXTURES.json"
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff", ".exr"}


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def replace_pointer(payload: Any, pointer: str, value: Any) -> None:
    parts = [part.replace("~1", "/").replace("~0", "~") for part in pointer.split("/")[1:]]
    target = payload
    for part in parts[:-1]:
        target = target[int(part)] if isinstance(target, list) else target[part]
    final = parts[-1]
    if isinstance(target, list):
        target[int(final)] = value
    else:
        target[final] = value


def validator_command(receipt: str) -> list[str]:
    return [
        sys.executable,
        str(VALIDATOR),
        "--schema",
        str(SCHEMA),
        "--receipt",
        receipt,
    ]


def run_validator(receipt: Path | dict[str, Any]) -> tuple[int, bytes, dict[str, Any]]:
    environment = dict(os.environ)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    if isinstance(receipt, Path):
        completed = subprocess.run(
            validator_command(str(receipt)),
            check=False,
            capture_output=True,
            env=environment,
        )
    else:
        completed = subprocess.run(
            validator_command("-"),
            input=canonical_bytes(receipt),
            check=False,
            capture_output=True,
            env=environment,
        )
    if completed.stderr:
        raise AssertionError(completed.stderr.decode("utf-8", errors="replace"))
    return completed.returncode, completed.stdout, json.loads(completed.stdout)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    positive_results: list[dict[str, Any]] = []
    repeat_results: list[dict[str, Any]] = []
    for fixture in POSITIVE:
        first_rc, first_stdout, first = run_validator(fixture)
        second_rc, second_stdout, second = run_validator(fixture)
        if first_rc != 0 or second_rc != 0 or first["result"] != "PASS":
            raise AssertionError(f"positive fixture rejected: {fixture.name}: {first}")
        if first_stdout != second_stdout or first != second:
            raise AssertionError(f"nondeterministic validator output: {fixture.name}")
        positive_results.append(
            {
                "fixture": fixture.name,
                "result": first["result"],
                "executionMode": first["executionMode"],
                "globalCapProven": first["globalCapProven"],
                "productionReady": first["productionReady"],
            }
        )
        repeat_results.append(
            {
                "fixture": fixture.name,
                "run1Sha256": sha256(first_stdout),
                "run2Sha256": sha256(second_stdout),
                "byteIdentical": first_stdout == second_stdout,
            }
        )

    negative_manifest = load(NEGATIVE)
    negative_results: list[dict[str, Any]] = []
    for case in negative_manifest["cases"]:
        base = load(
            ROOT / case.get("baseReceipt", negative_manifest["baseReceipt"])
        )
        payload = copy.deepcopy(base)
        if case["operation"] != "replace":
            raise AssertionError(f"unsupported fixture operation: {case['operation']}")
        replace_pointer(payload, case["pointer"], case["value"])
        returncode, _, result = run_validator(payload)
        if returncode != 2 or result.get("code") != case["expectedCode"]:
            raise AssertionError(
                f"negative fixture did not fail closed: {case['id']}: "
                f"rc={returncode} result={result}"
            )
        negative_results.append(
            {
                "fixture": case["id"],
                "returnCode": returncode,
                "code": result["code"],
                "productionReady": result["productionReady"],
            }
        )

    pixel_files = sorted(
        path.relative_to(ROOT).as_posix()
        for path in ROOT.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES
    )
    if pixel_files:
        raise AssertionError(f"pixel files found in prototype: {pixel_files}")

    report = {
        "schema": "citysim.play-080.strict-parallel-receipt-prototype-validation.v1",
        "taskId": "PLAY-080",
        "frozenCandidate": "779cf5141a4735d6b7c84a0372f08c9ab111d358",
        "result": "PASS",
        "positiveFixtures": positive_results,
        "negativeFixtures": negative_results,
        "deterministicRepeat": repeat_results,
        "globalScheduleBoundary": {
            "owner": "Integration",
            "state": "PENDING_INTEGRATION_AUTHORITY",
            "globalCapProven": False,
            "productionReady": False,
        },
        "executionBoundary": {
            "executablesInvoked": [Path(sys.executable).name],
            "validatorSubprocessInvocations": len(POSITIVE) * 2
            + len(negative_manifest["cases"]),
            "dccProcessInvocations": 0,
            "renderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizationInvocations": 0,
            "contactSheetInvocations": 0,
            "pixelFiles": pixel_files,
        },
    }
    sys.stdout.buffer.write(canonical_bytes(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
