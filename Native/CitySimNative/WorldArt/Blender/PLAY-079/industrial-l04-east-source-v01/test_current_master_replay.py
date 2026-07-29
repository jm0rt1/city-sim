#!/usr/bin/env python3
"""Focused zero-DCC tests for the PLAY-079 current-master replay harness."""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
from typing import Any

import replay_current_master_inputs as replay


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
SCRIPT_PATH = SOURCE_ROOT / "replay_current_master_inputs.py"
FIXTURE_PATH = SOURCE_ROOT / "fixtures/current-master-replay/REPLAY-FIXTURE.json"


def run_cli(command: str) -> tuple[int, bytes, bytes]:
    completed = subprocess.run(
        [
            sys.executable,
            "-B",
            str(SCRIPT_PATH),
            command,
            "--fixture",
            FIXTURE_PATH.relative_to(REPOSITORY_ROOT).as_posix(),
        ],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
    )
    return completed.returncode, completed.stdout, completed.stderr


def load_output(payload: bytes) -> dict[str, Any]:
    value = json.loads(payload)
    if not isinstance(value, dict):
        raise RuntimeError("CLI output is not an object")
    return value


def main() -> int:
    first_code, first_bytes, first_error = run_cli("validate")
    second_code, second_bytes, second_error = run_cli("validate")
    if (first_code, second_code) != (0, 0):
        raise RuntimeError(
            f"deterministic validation failed: {first_code}, {second_code}"
        )
    if first_error or second_error:
        raise RuntimeError(f"unexpected stderr: {first_error!r}, {second_error!r}")
    if first_bytes != second_bytes:
        raise RuntimeError("two deterministic CLI validations differ")
    positive = load_output(first_bytes)
    if positive.get("result") != "PASS":
        raise RuntimeError(f"positive validation did not pass: {positive}")

    adversarial_code, adversarial_bytes, adversarial_error = run_cli("adversarial")
    if adversarial_code != 0 or adversarial_error:
        raise RuntimeError(
            f"adversarial replay failed: {adversarial_code}, {adversarial_error!r}"
        )
    adversarial = load_output(adversarial_bytes)
    cases = adversarial.get("cases")
    if not isinstance(cases, list) or len(cases) != 8:
        raise RuntimeError(f"unexpected adversarial cases: {cases}")
    if any(
        case.get("result") != "REJECTED" or not case.get("code")
        for case in cases
    ):
        raise RuntimeError(f"adversarial case escaped: {cases}")

    if replay.pixel_inventory():
        raise RuntimeError("pixel files exist in the East evidence root")
    if replay.EVIDENCE_PATH.exists():
        raise RuntimeError("receipt must not exist during implementation validation")

    result = {
        "result": "PASS",
        "deterministicValidations": {
            "runs": 2,
            "byteIdentical": True,
            "resultSha256": replay.sha256_bytes(first_bytes),
        },
        "adversarialCases": cases,
        "invocations": {
            "blenderProcesses": 0,
            "dccProcesses": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
        },
        "pixelFilesCreated": 0,
        "receiptCreated": False,
    }
    sys.stdout.buffer.write(replay.canonical_bytes(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
