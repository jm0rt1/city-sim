#!/usr/bin/env python3
"""Dry structural and fail-closed tests for the South packet writer boundary."""

from __future__ import annotations

import copy
import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable

import source_candidate_packet_writer as writer


ROOT = Path(__file__).resolve().parent
REPOSITORY_ROOT = ROOT.parents[5]


def git(*arguments: str) -> str:
    return subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), *arguments],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def candidate(content_commit: str) -> dict[str, Any]:
    return {
        "stage": "source_candidate",
        "identity": {
            "taskId": writer.TASK_ID,
            "direction": writer.DIRECTION,
            "branch": writer.BRANCH,
            "sourceRoot": writer.SOURCE_ROOT,
            "evidenceRoot": writer.EVIDENCE_ROOT,
        },
        "lineage": {"cellContentCommit": content_commit},
        "completion": {
            "contentCommit": content_commit,
            "parallelExecutionReceipt": {
                "path": writer.STRICT_RECEIPT_PATH,
                "sha256": "1" * 64,
            },
        },
    }


def canonical(value: dict[str, Any]) -> bytes:
    return writer.canonical_json_bytes(value)


def source_stage_pass(
    content_commit: str,
) -> Callable[[Path, dict[str, Any]], dict[str, Any]]:
    def run(_: Path, __: dict[str, Any]) -> dict[str, Any]:
        return {
            "result": "PASS",
            "stage": "source_candidate",
            "taskId": writer.TASK_ID,
            "direction": writer.DIRECTION,
            "contentCommit": content_commit,
            "fixtureOnly": True,
        }

    return run


def strict_pass(_: Path, __: dict[str, Any]) -> dict[str, Any]:
    return {
        "result": "PASS",
        "taskId": writer.TASK_ID,
        "direction": writer.DIRECTION,
        "globalCapProven": False,
        "productionReady": False,
        "fixtureOnly": True,
    }


def expect_rejection(
    name: str,
    expected: str,
    operation: Callable[[], Any],
) -> dict[str, Any]:
    try:
        operation()
    except writer.PacketWriterRejected as error:
        if error.code != expected:
            raise AssertionError(
                f"{name}: expected {expected}, got {error.code}: {error.detail}"
            ) from error
        return {
            "case": name,
            "result": "REJECTED",
            "code": error.code,
            "packetWritten": False,
        }
    raise AssertionError(f"{name}: operation unexpectedly passed")


def evaluate_fixture(
    value: dict[str, Any],
    content_commit: str,
    *,
    destination: str = writer.RESERVED_PACKET_PATH,
    source_runner: Callable[[Path, dict[str, Any]], dict[str, Any]] | None = None,
    strict_runner: Callable[[Path, dict[str, Any]], dict[str, Any]] = strict_pass,
) -> dict[str, Any]:
    return writer.evaluate(
        repo=REPOSITORY_ROOT,
        candidate_path=Path("/private/tmp/PLAY-080-SOURCE-STAGE-HANDOFF-V2.json"),
        candidate_bytes=canonical(value),
        content_commit=content_commit,
        strict_receipt_path=Path(
            "/private/tmp/PLAY-080-FUTURE-SOURCE-PARALLEL-EXECUTION-RECEIPT.json"
        ),
        destination=destination,
        write=False,
        source_stage_runner=source_runner or source_stage_pass(content_commit),
        strict_runner=strict_runner,
    )


def path_fixture(kind: str) -> Callable[[], Any]:
    def run() -> Any:
        with tempfile.TemporaryDirectory(prefix=f"play-080-{kind}-") as temporary:
            repo = Path(temporary)
            parent = repo / writer.EVIDENCE_ROOT
            parent.mkdir(parents=True)
            target = repo / writer.RESERVED_PACKET_PATH
            if kind == "preexisting":
                target.write_text("occupied\n", encoding="utf-8")
            elif kind == "symlink":
                redirect = repo / "redirect.json"
                redirect.write_text("redirect\n", encoding="utf-8")
                os.symlink(redirect, target)
            else:
                raise AssertionError(kind)
            return writer.prove_destination_safe(repo, writer.RESERVED_PACKET_PATH)

    return run


def main() -> int:
    head = git("rev-parse", "HEAD")
    base = candidate(head)
    first = evaluate_fixture(base, head)
    second = evaluate_fixture(base, head)
    if first != second:
        raise AssertionError("positive dry-run result is not deterministic")
    if first["packetWritten"] or first["mode"] != "dry_run":
        raise AssertionError("positive fixture crossed the dry-run boundary")

    negatives: list[dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="play-080-authority-") as temporary:
        temporary_root = Path(temporary)
        null_authority = temporary_root / "null.json"
        null_authority.write_text("null\n", encoding="utf-8")
        negatives.append(
            expect_rejection(
                "null-authority",
                "NULL_LOCATOR_AUTHORITY",
                lambda: writer.load_locator_authority(
                    REPOSITORY_ROOT, instance_path=null_authority
                ),
            )
        )

        mismatched_authority = temporary_root / "mismatched.json"
        authority = json.loads(
            (REPOSITORY_ROOT / writer.LOCATOR_INSTANCE_PATH).read_text(
                encoding="utf-8"
            )
        )
        authority["grants"]["shipping"] = True
        mismatched_authority.write_bytes(writer.canonical_json_bytes(authority))
        negatives.append(
            expect_rejection(
                "mismatched-authority",
                "AUTHORITY_INSTANCE_SHA_MISMATCH",
                lambda: writer.load_locator_authority(
                    REPOSITORY_ROOT, instance_path=mismatched_authority
                ),
            )
        )

    negatives.append(
        expect_rejection(
            "wrong-packet-path",
            "WRONG_PACKET_PATH",
            lambda: evaluate_fixture(
                base,
                head,
                destination=f"{writer.EVIDENCE_ROOT}/WRONG.json",
            ),
        )
    )
    wrong_direction = copy.deepcopy(base)
    wrong_direction["identity"]["direction"] = "sideways"
    negatives.append(
        expect_rejection(
            "wrong-direction",
            "WRONG_DIRECTION",
            lambda: evaluate_fixture(wrong_direction, head),
        )
    )
    wrong_branch = copy.deepcopy(base)
    wrong_branch["identity"]["branch"] = "codex/citysim-world-art-west"
    negatives.append(
        expect_rejection(
            "wrong-branch",
            "WRONG_BRANCH",
            lambda: evaluate_fixture(wrong_branch, head),
        )
    )
    sibling = copy.deepcopy(base)
    sibling["identity"].update(
        {
            "taskId": "PLAY-079",
            "direction": "east",
            "branch": "codex/citysim-world-art-east",
        }
    )
    negatives.append(
        expect_rejection(
            "sibling-substitution",
            "SIBLING_SUBSTITUTION",
            lambda: evaluate_fixture(sibling, head),
        )
    )
    negatives.append(
        expect_rejection(
            "unsafe-root",
            "UNSAFE_ROOT",
            lambda: evaluate_fixture(
                base,
                head,
                destination=(
                    f"{writer.EVIDENCE_ROOT}/../../PLAY-081/"
                    "SOURCE-STAGE-HANDOFF-V2.json"
                ),
            ),
        )
    )
    negatives.append(
        expect_rejection(
            "preexisting-file",
            "PREEXISTING_PACKET",
            path_fixture("preexisting"),
        )
    )
    negatives.append(
        expect_rejection(
            "symlink-redirect",
            "SYMLINK_REDIRECT",
            path_fixture("symlink"),
        )
    )
    wrong_commit = copy.deepcopy(base)
    wrong_commit["lineage"]["cellContentCommit"] = "0" * 40
    negatives.append(
        expect_rejection(
            "content-commit-mismatch",
            "CONTENT_COMMIT_MISMATCH",
            lambda: evaluate_fixture(wrong_commit, head),
        )
    )
    negatives.append(
        expect_rejection(
            "source-stage-v2-rejection",
            "SOURCE_STAGE_V2_REJECTED",
            lambda: evaluate_fixture(
                base,
                head,
                source_runner=lambda _path, _candidate: {
                    "result": "FAIL",
                    "stage": "source_candidate",
                    "taskId": writer.TASK_ID,
                    "direction": writer.DIRECTION,
                    "contentCommit": head,
                },
            ),
        )
    )
    negatives.append(
        expect_rejection(
            "strict-parallel-receipt-rejection",
            "STRICT_PARALLEL_RECEIPT_REJECTED",
            lambda: evaluate_fixture(
                base,
                head,
                strict_runner=lambda _path, _candidate: {
                    "result": "FAIL",
                    "taskId": writer.TASK_ID,
                    "direction": writer.DIRECTION,
                },
            ),
        )
    )
    if len(negatives) != 12:
        raise AssertionError(f"expected 12 negative cases, got {len(negatives)}")

    report = {
        "schema": "citysim.play-080.source-candidate-packet-writer-test.v1",
        "result": "PASS",
        "taskId": writer.TASK_ID,
        "direction": writer.DIRECTION,
        "headUnderTest": head,
        "positiveDryRuns": {
            "count": 2,
            "byteIdentical": canonical(first) == canonical(second),
            "packetWritten": False,
            "reservedPacketPath": writer.RESERVED_PACKET_PATH,
        },
        "negativeCases": negatives,
        "authorityBindings": first["locatorAuthority"],
        "validationBoundary": {
            "sourceStageV2FixtureOnly": True,
            "strictParallelReceiptFixtureOnly": True,
            "liveValidatorsRequiredForWrite": True,
            "globalCapProven": False,
            "productionReady": False,
        },
        "zeroActivity": first["zeroActivity"],
        "authorityBoundary": first["authorityBoundary"],
    }
    print(json.dumps(report, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
