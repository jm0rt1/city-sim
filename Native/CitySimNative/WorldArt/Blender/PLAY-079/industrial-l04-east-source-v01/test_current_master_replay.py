#!/usr/bin/env python3
"""Focused zero-DCC tests for the PLAY-079 current-master replay harness."""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile
from typing import Any

import replay_current_master_inputs as replay


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
SCRIPT_PATH = SOURCE_ROOT / "replay_current_master_inputs.py"
FIXTURE_PATH = SOURCE_ROOT / "fixtures/current-master-replay/REPLAY-FIXTURE.json"


def run_cli(
    command: str,
    implementation_commit: str | None = None,
) -> tuple[int, bytes, bytes]:
    arguments = [
        sys.executable,
        "-B",
        str(SCRIPT_PATH),
        command,
        "--fixture",
        FIXTURE_PATH.relative_to(REPOSITORY_ROOT).as_posix(),
    ]
    if implementation_commit is not None:
        arguments.extend(["--implementation-commit", implementation_commit])
    completed = subprocess.run(
        arguments,
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


def git_output(*arguments: str) -> str:
    completed = subprocess.run(
        ["git", *arguments],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode:
        raise RuntimeError(
            f"git {' '.join(arguments)}: {completed.stderr.strip()}"
        )
    return completed.stdout.strip()


def validate_receipt_replay(
    validation_bytes: bytes,
    replay_branch: str,
) -> dict[str, Any]:
    script_relative = SCRIPT_PATH.relative_to(REPOSITORY_ROOT).as_posix()
    implementation_commit = git_output(
        "log",
        "-1",
        "--format=%H",
        "--",
        script_relative,
    )
    current_script_sha256 = replay.sha256_bytes(
        replay.capture_repository_file(script_relative, "test_implementation")
    )
    receipt_relative = replay.EVIDENCE_PATH.relative_to(REPOSITORY_ROOT).as_posix()
    existing_bytes: bytes | None = None
    existing: dict[str, Any] | None = None
    if replay.EVIDENCE_PATH.exists():
        existing_bytes = replay.capture_repository_file(
            receipt_relative,
            "committed_receipt",
        )
        existing = load_output(existing_bytes)

    receipt_code, generated_bytes, receipt_error = run_cli(
        "receipt",
        implementation_commit,
    )
    with tempfile.TemporaryDirectory(
        prefix="play079-replay-test-output-"
    ) as temporary:
        disposable = pathlib.Path(temporary) / "receipt.json"
        if disposable.exists():
            raise RuntimeError("disposable receipt output was not absent")
        if receipt_code == 0:
            if receipt_error:
                raise RuntimeError(f"unexpected receipt stderr: {receipt_error!r}")
            exact_existing = (
                existing is not None
                and existing.get("replayBranch") == replay_branch
                and existing.get("implementation", {}).get("commit")
                == implementation_commit
                and existing.get("implementation", {}).get("sha256")
                == current_script_sha256
            )
            if exact_existing:
                if generated_bytes != existing_bytes:
                    raise RuntimeError(
                        "committed receipt differs from deterministic replay"
                    )
                mode = "byte_identical_committed_receipt"
                compared_sha256 = replay.sha256_bytes(generated_bytes)
            else:
                disposable.write_bytes(generated_bytes)
                if disposable.read_bytes() != generated_bytes:
                    raise RuntimeError("disposable receipt round trip failed")
                mode = "disposable_absent_output"
                compared_sha256 = replay.sha256_bytes(generated_bytes)
        else:
            rejected = load_output(generated_bytes)
            if rejected.get("code") != "implementation_working_tree_hash_mismatch":
                raise RuntimeError(
                    f"unexpected dirty implementation rejection: {rejected}"
                )
            disposable.write_bytes(validation_bytes)
            if disposable.read_bytes() != validation_bytes:
                raise RuntimeError("disposable validation round trip failed")
            mode = "disposable_absent_output_dirty_implementation"
            compared_sha256 = replay.sha256_bytes(validation_bytes)
    return {
        "result": "PASS",
        "mode": mode,
        "replayBranch": replay_branch,
        "implementationCommit": implementation_commit,
        "comparedSha256": compared_sha256,
    }


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
    replay_branch = git_output("branch", "--show-current")
    base_identity = positive.get("baseAuthority", {})
    if base_identity.get("authoredBranch") != replay.AUTHORED_BRANCH:
        raise RuntimeError(f"authored branch mismatch: {base_identity}")
    if base_identity.get("replayBranch") != replay_branch:
        raise RuntimeError(f"replay branch mismatch: {base_identity}")
    master_identity = replay.branch_identity("master")
    if master_identity != {
        "authoredBranch": replay.AUTHORED_BRANCH,
        "replayBranch": "master",
    }:
        raise RuntimeError(f"master replay identity is false: {master_identity}")

    adversarial_code, adversarial_bytes, adversarial_error = run_cli("adversarial")
    if adversarial_code != 0 or adversarial_error:
        raise RuntimeError(
            f"adversarial replay failed: {adversarial_code}, {adversarial_error!r}"
        )
    adversarial = load_output(adversarial_bytes)
    fixture_cases = adversarial.get("fixtureCases")
    capture_cases = adversarial.get("captureCases")
    if not isinstance(fixture_cases, list) or len(fixture_cases) != 8:
        raise RuntimeError(f"unexpected fixture adversaries: {fixture_cases}")
    if not isinstance(capture_cases, list) or len(capture_cases) != 3:
        raise RuntimeError(f"unexpected capture adversaries: {capture_cases}")
    if any(
        case.get("result") != "REJECTED" or not case.get("code")
        for case in [*fixture_cases, *capture_cases]
    ):
        raise RuntimeError(
            f"adversarial case escaped: {fixture_cases}, {capture_cases}"
        )

    if replay.pixel_inventory():
        raise RuntimeError("pixel files exist in the East evidence root")
    receipt_replay = validate_receipt_replay(first_bytes, replay_branch)

    result = {
        "result": "PASS",
        "deterministicValidations": {
            "runs": 2,
            "byteIdentical": True,
            "resultSha256": replay.sha256_bytes(first_bytes),
        },
        "adversarialCases": {
            "fixture": fixture_cases,
            "capture": capture_cases,
        },
        "branchIdentity": {
            "authoredBranch": replay.AUTHORED_BRANCH,
            "replayBranch": replay_branch,
            "masterReplay": master_identity,
        },
        "receiptReplay": receipt_replay,
        "invocations": {
            "blenderProcesses": 0,
            "dccProcesses": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
        },
        "pixelFilesCreated": 0,
        "repositoryReceiptWrites": 0,
    }
    sys.stdout.buffer.write(replay.canonical_bytes(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
