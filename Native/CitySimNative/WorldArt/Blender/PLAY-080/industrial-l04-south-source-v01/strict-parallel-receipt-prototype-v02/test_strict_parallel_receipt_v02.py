#!/usr/bin/env python3
"""Exercise PLAY-080 v02 positives, adversarial rejects, and repeat identity."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parent
REPO = next(parent for parent in ROOT.parents if parent.joinpath(".git").exists())
SCHEDULE_SCHEMA = ROOT / "planned-schedule-fixture-schema-v02.json"
RECEIPT_SCHEMA = ROOT / "observed-direction-receipt-fixture-schema-v02.json"
VALIDATOR = ROOT / "validate_strict_parallel_receipt_v02.py"
FIXTURES = {
    "cap2_overlap": (
        ROOT / "fixtures/cap2-overlap/PLANNED-SCHEDULE.json",
        ROOT / "fixtures/cap2-overlap/OBSERVED-RECEIPT.json",
    ),
    "cap1_exception": (
        ROOT / "fixtures/cap1-exception/PLANNED-SCHEDULE.json",
        ROOT / "fixtures/cap1-exception/OBSERVED-RECEIPT.json",
    ),
}
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff", ".exr"}

spec = importlib.util.spec_from_file_location("strict_receipt_v02", VALIDATOR)
if spec is None or spec.loader is None:
    raise RuntimeError("validator import failed")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def repo_path(path: Path) -> str:
    return path.relative_to(REPO).as_posix()


def recompute_attempt_identities(schedule: dict[str, Any]) -> None:
    for attempt in schedule["attemptLedger"]:
        attempt["identitySha256"] = validator.attempt_identity_sha(attempt)


def validate_bytes(
    schedule_bytes: bytes,
    receipt_bytes: bytes,
    schedule_path: str,
    *,
    repo: Path = REPO,
) -> dict[str, Any]:
    return validator.validate_documents(
        repo=repo,
        schedule_schema_bytes=SCHEDULE_SCHEMA.read_bytes(),
        receipt_schema_bytes=RECEIPT_SCHEMA.read_bytes(),
        schedule_bytes=schedule_bytes,
        receipt_bytes=receipt_bytes,
        schedule_repo_path=schedule_path,
    )


def mutated_documents(
    mode: str,
    mutate: Callable[[dict[str, Any], dict[str, Any]], None],
    *,
    recompute_identities: bool = False,
    refresh_schedule_sha: bool = True,
) -> tuple[bytes, bytes, str]:
    schedule_path, receipt_path = FIXTURES[mode]
    schedule = copy.deepcopy(load(schedule_path))
    receipt = copy.deepcopy(load(receipt_path))
    mutate(schedule, receipt)
    if recompute_identities:
        recompute_attempt_identities(schedule)
    schedule_bytes = canonical_bytes(schedule)
    if refresh_schedule_sha:
        receipt["plannedScheduleRef"]["sha256"] = sha256(schedule_bytes)
    return schedule_bytes, canonical_bytes(receipt), repo_path(schedule_path)


def expect_rejected(
    case_id: str,
    expected_code: str,
    schedule_bytes: bytes,
    receipt_bytes: bytes,
    schedule_path: str,
    *,
    repo: Path = REPO,
) -> dict[str, Any]:
    try:
        validate_bytes(schedule_bytes, receipt_bytes, schedule_path, repo=repo)
    except validator.ModelRejected as error:
        if error.code != expected_code:
            raise AssertionError(
                f"{case_id}: expected {expected_code}, received {error.code}: {error.detail}"
            )
        return {
            "case": case_id,
            "code": error.code,
            "failClosed": True,
            "globalCapProven": False,
            "productionReady": False,
        }
    raise AssertionError(f"{case_id}: unexpectedly accepted")


def replace_first(data: bytes, old: bytes, new: bytes) -> bytes:
    if old not in data:
        raise AssertionError(f"raw fixture marker missing: {old!r}")
    return data.replace(old, new, 1)


def run_symlink_input_case() -> dict[str, Any]:
    schedule_path, receipt_path = FIXTURES["cap2_overlap"]
    with tempfile.TemporaryDirectory(
        prefix="play080-v02-input-", dir="/private/tmp"
    ) as temporary:
        link = Path(temporary) / "schedule-link.json"
        os.symlink(schedule_path, link)
        command = [
            sys.executable,
            str(VALIDATOR),
            "--schedule-schema",
            str(SCHEDULE_SCHEMA),
            "--receipt-schema",
            str(RECEIPT_SCHEMA),
            "--schedule",
            str(link),
            "--receipt",
            str(receipt_path),
            "--schedule-repo-path",
            repo_path(schedule_path),
        ]
        environment = dict(os.environ)
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        completed = subprocess.run(
            command, check=False, capture_output=True, env=environment
        )
    if completed.stderr:
        raise AssertionError(completed.stderr.decode("utf-8", errors="replace"))
    result = json.loads(completed.stdout)
    if completed.returncode != 2 or result.get("code") != "SYMLINK_INPUT_REJECTED":
        raise AssertionError(f"symlink input fail-closed mismatch: {result}")
    return {
        "case": "symlink-input",
        "code": result["code"],
        "failClosed": True,
        "globalCapProven": False,
        "productionReady": False,
    }


def run_alternate_schedule_input_case() -> dict[str, Any]:
    schedule_path, receipt_path = FIXTURES["cap2_overlap"]
    with tempfile.TemporaryDirectory(
        prefix="play080-v02-alternate-", dir="/private/tmp"
    ) as temporary:
        alternate = Path(temporary) / "alternate-schedule.json"
        alternate.write_bytes(schedule_path.read_bytes())
        command = [
            sys.executable,
            str(VALIDATOR),
            "--schedule-schema",
            str(SCHEDULE_SCHEMA),
            "--receipt-schema",
            str(RECEIPT_SCHEMA),
            "--schedule",
            str(alternate),
            "--receipt",
            str(receipt_path),
            "--schedule-repo-path",
            repo_path(schedule_path),
        ]
        environment = dict(os.environ)
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        completed = subprocess.run(
            command, check=False, capture_output=True, env=environment
        )
    if completed.stderr:
        raise AssertionError(completed.stderr.decode("utf-8", errors="replace"))
    result = json.loads(completed.stdout)
    if completed.returncode != 2 or result.get("code") != "SCHEDULE_INPUT_PATH_MISMATCH":
        raise AssertionError(f"alternate schedule input fail-closed mismatch: {result}")
    return {
        "case": "alternate-schedule-input",
        "code": result["code"],
        "failClosed": True,
        "globalCapProven": False,
        "productionReady": False,
    }


def run_symlink_ancestor_input_case() -> dict[str, Any]:
    schedule_path, receipt_path = FIXTURES["cap2_overlap"]
    with tempfile.TemporaryDirectory(
        prefix="play080-v02-ancestor-", dir="/private/tmp"
    ) as temporary:
        linked_parent = Path(temporary) / "linked-fixture-parent"
        os.symlink(schedule_path.parent, linked_parent)
        linked_schedule = linked_parent / schedule_path.name
        command = [
            sys.executable,
            str(VALIDATOR),
            "--schedule-schema",
            str(SCHEDULE_SCHEMA),
            "--receipt-schema",
            str(RECEIPT_SCHEMA),
            "--schedule",
            str(linked_schedule),
            "--receipt",
            str(receipt_path),
            "--schedule-repo-path",
            repo_path(schedule_path),
        ]
        environment = dict(os.environ)
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        completed = subprocess.run(
            command, check=False, capture_output=True, env=environment
        )
    if completed.stderr:
        raise AssertionError(completed.stderr.decode("utf-8", errors="replace"))
    result = json.loads(completed.stdout)
    if (
        completed.returncode != 2
        or result.get("code") != "SYMLINK_INPUT_ANCESTOR_REJECTED"
    ):
        raise AssertionError(f"symlink ancestor fail-closed mismatch: {result}")
    return {
        "case": "symlink-input-ancestor",
        "code": result["code"],
        "failClosed": True,
        "globalCapProven": False,
        "productionReady": False,
    }


def run_negative_cases() -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    cap2_schedule_path, cap2_receipt_path = FIXTURES["cap2_overlap"]
    cap2_schedule_raw = cap2_schedule_path.read_bytes()
    cap2_receipt_raw = cap2_receipt_path.read_bytes()
    schedule_path = repo_path(cap2_schedule_path)

    duplicate_schedule = replace_first(
        cap2_schedule_raw,
        b'{\n  "schema":',
        b'{\n  "schema": "duplicate",\n  "schema":',
    )
    results.append(
        expect_rejected(
            "duplicate-schedule-key",
            "DUPLICATE_JSON_KEY",
            duplicate_schedule,
            cap2_receipt_raw,
            schedule_path,
        )
    )
    duplicate_receipt = replace_first(
        cap2_receipt_raw,
        b'{\n  "schema":',
        b'{\n  "schema": "duplicate",\n  "schema":',
    )
    results.append(
        expect_rejected(
            "duplicate-receipt-key",
            "DUPLICATE_JSON_KEY",
            cap2_schedule_raw,
            duplicate_receipt,
            schedule_path,
        )
    )
    nonfinite_schedule = replace_first(
        cap2_schedule_raw,
        b'{\n  "schema":',
        b'{\n  "nonfiniteProbe": NaN,\n  "schema":',
    )
    results.append(
        expect_rejected(
            "nonfinite-schedule",
            "NONFINITE_JSON_NUMBER",
            nonfinite_schedule,
            cap2_receipt_raw,
            schedule_path,
        )
    )
    nonfinite_receipt = replace_first(
        cap2_receipt_raw,
        b'{\n  "schema":',
        b'{\n  "nonfiniteProbe": Infinity,\n  "schema":',
    )
    results.append(
        expect_rejected(
            "nonfinite-receipt",
            "NONFINITE_JSON_NUMBER",
            cap2_schedule_raw,
            nonfinite_receipt,
            schedule_path,
        )
    )

    def extra_schedule(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["unexpected"] = False

    def extra_receipt(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["unexpected"] = False

    def traversal_root(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["attemptLedger"][0]["ownedRoots"][0] = (
            "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
            "industrial-l04-south-source-v01/../Rendering"
        )

    def absolute_root(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["attemptLedger"][0]["ownedRoots"][0] = "/tmp/play080"

    def duplicate_separator(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["attemptLedger"][0]["ownedRoots"][0] = (
            "Native/CitySimNative//WorldArt/Blender/PLAY-080/"
            "industrial-l04-south-source-v01/source-candidate-v02/cap2/unsafe"
        )

    def planned_cap_exceeded(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["allocations"][2]["notBeforeUtc"] = "2026-07-29T12:01:00Z"

    def same_slot_overlap(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        schedule["allocations"][1]["preassignedSlot"] = 0
        receipt["processes"]["B"]["preassignedSlot"] = 0

    def cap2_false_overlap(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["allocations"][1]["notBeforeUtc"] = "2026-07-29T12:04:00Z"
        schedule["allocations"][1]["notAfterUtc"] = "2026-07-29T12:05:00Z"

    def zero_interval(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["allocations"][0]["notAfterUtc"] = schedule["allocations"][0][
            "notBeforeUtc"
        ]

    def reversed_interval(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["allocations"][0]["notAfterUtc"] = "2026-07-29T11:59:59Z"

    def lease_escape(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["processes"]["A"]["startedAtUtc"] = "2026-07-29T11:59:59Z"

    def allocation_mismatch(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["processes"]["A"]["allocationId"] = "south-allocation-999"

    def duplicate_allocation_id(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del receipt
        schedule["allocations"][1]["allocationId"] = schedule["allocations"][0][
            "allocationId"
        ]

    def same_slot_planned_lease_fifo_reversed(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del receipt
        first = schedule["allocations"][0]
        last = schedule["allocations"][2]
        first["notBeforeUtc"], last["notBeforeUtc"] = (
            last["notBeforeUtc"],
            first["notBeforeUtc"],
        )
        first["notAfterUtc"], last["notAfterUtc"] = (
            last["notAfterUtc"],
            first["notAfterUtc"],
        )

    def same_slot_acquire_fifo_reversed(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del receipt
        first_acquire = schedule["dispatchEvents"][6]
        second_acquire = schedule["dispatchEvents"][7]
        first_acquire["attemptId"], second_acquire["attemptId"] = (
            second_acquire["attemptId"],
            first_acquire["attemptId"],
        )

    def scheduler_event_mismatch(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del schedule
        receipt["processes"]["A"]["schedulerEventIds"][1] = "cap2-event-005"

    def sibling_root(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["attemptLedger"][0]["ownedRoots"][0] = (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/process-A"
        )

    def cancellation_escape(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["events"][0]["direction"] = "east"

    def retry_chain_broken(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["attemptLedger"][3]["previousAttemptId"] = "south-A-attempt-001"

    def retry_identity_mutated(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["attemptLedger"][3]["ownedRoots"][0] += "-mutated"

    def retry_root_reused(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        schedule["attemptLedger"][3]["ownedRoots"] = copy.deepcopy(
            schedule["attemptLedger"][2]["ownedRoots"]
        )
        receipt["processes"]["C"]["ownedRoots"] = copy.deepcopy(
            schedule["attemptLedger"][3]["ownedRoots"]
        )

    def dispatch_sequence_duplicate(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["dispatchEvents"][2]["sequence"] = 2

    def observed_event_id_duplicate(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del schedule
        receipt["events"][1]["eventId"] = receipt["events"][0]["eventId"]

    def retry_dispatched_before_append(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del receipt
        schedule["dispatchEvents"][5]["kind"] = "process_dispatched"

    def fifo_dispatch_changed(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        for index in (3, 4):
            schedule["dispatchEvents"][index]["attemptId"] = "south-C-attempt-001"
        for index in (5, 6):
            schedule["dispatchEvents"][index]["attemptId"] = "south-B-attempt-001"

    def cancellation_after_acquire(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del receipt
        schedule["dispatchEvents"][4]["kind"] = "slot_acquired"

    def ambiguous_retry_scope(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del receipt
        schedule["allocations"][3]["retryScope"] = "complete_direction_set"

    def fixed_dag_edge(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["jobs"][3]["dependsOn"] = ["provenance-A", "provenance-B"]

    def retry_observation_missing(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del schedule
        receipt["events"][1]["kind"] = "attempt_cancel_observed"
        receipt["events"][1]["attemptId"] = "south-C-attempt-001"

    def second_assembler(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["assembler"]["invocationCount"] = 2

    def self_referential_receipt_commit(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del schedule
        receipt["identity"]["receiptCommit"] = receipt["identity"]["cellContentCommit"]

    def schedule_commit_invented(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del schedule
        receipt["plannedScheduleRef"]["commit"] = "e" * 40

    def identity_join_selection_wrong(
        schedule: dict[str, Any], receipt: dict[str, Any]
    ) -> None:
        del schedule
        receipt["join"]["selectedAttempts"]["C"] = "south-B-attempt-001"

    def identity_join_false(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["join"]["rawIdentityResult"] = "FAIL"

    def wrong_process_set(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        del receipt["processes"]["C"]

    def duplicate_invocation(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["processes"]["A"]["invocationCount"] = 2

    def authority_invented(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del receipt
        schedule["globalIntegrationAuthority"]["authorityCommit"] = (
            "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
        )

    def grant_true(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["grants"]["pixels"] = True

    def schedule_path_mismatch(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["plannedScheduleRef"]["path"] = (
            ROOT.relative_to(REPO).as_posix() + "/fixtures/alternate/PLANNED-SCHEDULE.json"
        )

    def schedule_sha_mismatch(schedule: dict[str, Any], receipt: dict[str, Any]) -> None:
        del schedule
        receipt["plannedScheduleRef"]["sha256"] = "f" * 64

    cases: list[
        tuple[str, str, str, Callable[[dict[str, Any], dict[str, Any]], None], bool, bool]
    ] = [
        ("extra-schedule-property", "SCHEMA_INVALID", "cap2_overlap", extra_schedule, False, True),
        ("extra-receipt-property", "SCHEMA_INVALID", "cap2_overlap", extra_receipt, False, True),
        ("traversal-root", "UNSAFE_REPO_PATH", "cap2_overlap", traversal_root, True, True),
        ("absolute-root", "UNSAFE_REPO_PATH", "cap2_overlap", absolute_root, True, True),
        ("duplicate-separator-root", "UNSAFE_REPO_PATH", "cap2_overlap", duplicate_separator, True, True),
        ("sibling-root", "PATH_OUTSIDE_PLAY_080_OWNERSHIP", "cap2_overlap", sibling_root, True, True),
        ("planned-cap-exceeded", "PLANNED_CAP_EXCEEDED", "cap2_overlap", planned_cap_exceeded, False, True),
        ("same-slot-overlap", "SAME_SLOT_PLANNED_OVERLAP", "cap2_overlap", same_slot_overlap, False, True),
        ("cap2-false-overlap", "CAP2_MODE_INVALID", "cap2_overlap", cap2_false_overlap, False, True),
        ("zero-interval", "INVALID_HALF_OPEN_INTERVAL", "cap2_overlap", zero_interval, False, True),
        ("reversed-interval", "INVALID_HALF_OPEN_INTERVAL", "cap2_overlap", reversed_interval, False, True),
        ("lease-escape", "OBSERVED_INTERVAL_OUTSIDE_ALLOCATION", "cap2_overlap", lease_escape, False, True),
        ("allocation-mismatch", "OBSERVED_ALLOCATION_BINDING_MISMATCH", "cap2_overlap", allocation_mismatch, False, True),
        ("duplicate-allocation-id", "DUPLICATE_ALLOCATION_ID", "cap2_overlap", duplicate_allocation_id, False, True),
        ("same-slot-planned-lease-fifo-reversed", "SAME_SLOT_PLANNED_LEASE_FIFO_CHANGED", "cap2_overlap", same_slot_planned_lease_fifo_reversed, False, True),
        ("same-slot-acquire-fifo-reversed", "SAME_SLOT_ACQUIRE_FIFO_CHANGED", "cap1_exception", same_slot_acquire_fifo_reversed, False, True),
        ("scheduler-event-mismatch", "SCHEDULER_EVENT_REFERENCE_MISMATCH", "cap2_overlap", scheduler_event_mismatch, False, True),
        ("cancellation-escapes-direction", "SCHEMA_INVALID", "cap2_overlap", cancellation_escape, False, True),
        ("retry-chain-broken", "INVALID_RETRY_CHAIN", "cap1_exception", retry_chain_broken, True, True),
        ("retry-identity-mutated", "ATTEMPT_IDENTITY_HASH_MISMATCH", "cap1_exception", retry_identity_mutated, False, True),
        ("retry-root-reused", "ROOT_ISOLATION_FAILURE", "cap1_exception", retry_root_reused, True, True),
        ("dispatch-sequence-duplicate", "DISPATCH_SEQUENCE_INVALID", "cap2_overlap", dispatch_sequence_duplicate, False, True),
        ("observed-event-id-duplicate", "DUPLICATE_OBSERVED_EVENT_ID", "cap2_overlap", observed_event_id_duplicate, False, True),
        ("retry-dispatch-kind-invalid", "RETRY_DISPATCH_KIND_INVALID", "cap1_exception", retry_dispatched_before_append, False, True),
        ("fifo-dispatch-changed", "FIFO_DISPATCH_ORDER_CHANGED", "cap2_overlap", fifo_dispatch_changed, False, True),
        ("cancellation-after-acquire", "CANCELLED_ATTEMPT_ACQUIRED_SLOT", "cap1_exception", cancellation_after_acquire, False, True),
        ("ambiguous-retry-scope", "AMBIGUOUS_COMPLETE_DIRECTION_RETRY_SCOPE", "cap1_exception", ambiguous_retry_scope, False, True),
        ("retry-observation-missing", "OBSERVED_RETRY_SET_MISMATCH", "cap1_exception", retry_observation_missing, False, True),
        ("fixed-dag-edge", "FIXED_DAG_EDGE_MISMATCH", "cap2_overlap", fixed_dag_edge, False, True),
        ("second-assembler", "SCHEMA_INVALID", "cap2_overlap", second_assembler, False, True),
        ("self-referential-receipt-commit", "SCHEMA_INVALID", "cap2_overlap", self_referential_receipt_commit, False, True),
        ("invented-schedule-commit", "SCHEMA_INVALID", "cap2_overlap", schedule_commit_invented, False, True),
        ("identity-join-selection-wrong", "IDENTITY_JOIN_SELECTION_MISMATCH", "cap2_overlap", identity_join_selection_wrong, False, True),
        ("identity-join-false", "SCHEMA_INVALID", "cap2_overlap", identity_join_false, False, True),
        ("wrong-process-set", "SCHEMA_INVALID", "cap2_overlap", wrong_process_set, False, True),
        ("duplicate-invocation", "SCHEMA_INVALID", "cap2_overlap", duplicate_invocation, False, True),
        ("invented-global-authority", "SCHEMA_INVALID", "cap2_overlap", authority_invented, False, True),
        ("grant-true", "SCHEMA_INVALID", "cap2_overlap", grant_true, False, True),
        ("schedule-path-mismatch", "PLANNED_SCHEDULE_PATH_MISMATCH", "cap2_overlap", schedule_path_mismatch, False, True),
        ("schedule-sha-mismatch", "PLANNED_SCHEDULE_SHA_MISMATCH", "cap2_overlap", schedule_sha_mismatch, False, False),
    ]
    for case_id, code, mode, mutation, recompute, refresh in cases:
        schedule_bytes, receipt_bytes, declared_path = mutated_documents(
            mode,
            mutation,
            recompute_identities=recompute,
            refresh_schedule_sha=refresh,
        )
        results.append(
            expect_rejected(case_id, code, schedule_bytes, receipt_bytes, declared_path)
        )

    schedule_bytes, receipt_bytes, declared_path = mutated_documents(
        "cap2_overlap", lambda schedule, receipt: None
    )
    with tempfile.TemporaryDirectory(prefix="play080-v02-root-") as temporary:
        temp_repo = Path(temporary)
        symlink_parent = temp_repo / (
            "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
            "industrial-l04-south-source-v01/source-candidate-v02/cap2"
        )
        symlink_parent.mkdir(parents=True)
        target = temp_repo / "redirect-target"
        target.mkdir()
        os.symlink(target, symlink_parent / "process-A")
        results.append(
            expect_rejected(
                "symlink-root-component",
                "SYMLINK_PATH_COMPONENT",
                schedule_bytes,
                receipt_bytes,
                declared_path,
                repo=temp_repo,
            )
        )
    results.append(run_symlink_input_case())
    results.append(run_symlink_ancestor_input_case())
    results.append(run_alternate_schedule_input_case())
    return results


def run_positive_and_repeat() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    positives: list[dict[str, Any]] = []
    repeats: list[dict[str, Any]] = []
    for mode, (schedule_path, receipt_path) in FIXTURES.items():
        schedule_bytes = schedule_path.read_bytes()
        receipt_bytes = receipt_path.read_bytes()
        first = validate_bytes(schedule_bytes, receipt_bytes, repo_path(schedule_path))
        second = validate_bytes(schedule_bytes, receipt_bytes, repo_path(schedule_path))
        first_bytes = validator.result_bytes(first)
        second_bytes = validator.result_bytes(second)
        if first_bytes != second_bytes:
            raise AssertionError(f"{mode}: repeat output differs")
        positives.append(
            {
                "fixture": mode,
                "result": first["result"],
                "plannedPeak": first["plannedPeak"],
                "observedPeak": first["observedPeak"],
                "cellContentCommit": first["cellContentCommit"],
                "receiptCommitEmbedded": first["receiptCommitEmbedded"],
                "globalCapProven": first["globalCapProven"],
                "productionReady": first["productionReady"],
            }
        )
        repeats.append(
            {
                "fixture": mode,
                "run1Sha256": sha256(first_bytes),
                "run2Sha256": sha256(second_bytes),
                "byteIdentical": first_bytes == second_bytes,
            }
        )
    return positives, repeats


def main() -> int:
    positives, repeats = run_positive_and_repeat()
    negatives = run_negative_cases()
    pixel_files = sorted(
        path.relative_to(ROOT).as_posix()
        for path in ROOT.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES
    )
    if pixel_files:
        raise AssertionError(f"pixel files present: {pixel_files}")
    claim = REPO / "docs/production/claims/PLAY-080.world-art-south.md"
    claim_sha = sha256(claim.read_bytes())
    if claim_sha != "6ccd0313c078b24fc1b1a42806434480f46fd9fe705dd51c26015b174be95973":
        raise AssertionError(f"claim authority drift: {claim_sha}")
    report = {
        "schema": "citysim.play-080.strict-parallel-receipt-prototype-validation.v02",
        "taskId": "PLAY-080",
        "implementationBase": "2f218104cf924c5cb2e80f9a07501dd3755612bf",
        "parallelExecutionDesign": {
            "path": (
                "docs/production/evidence/INTEGRATION/"
                "INDUSTRIAL-L04-PARALLEL-EXECUTION-CONTRACT-CANDIDATE.md"
            ),
            "commit": "aeaecb0bef4e7fe1e9670b1d57bd49b50b4eeab7",
            "sha256": (
                "a2c726585fa83f9a795c02cb4e97fd476ae3969587db7c5e133ecc9889636e36"
            ),
            "status": "DESIGN_FROZEN_IMPLEMENTATION_AND_INDEPENDENT_AUDIT_REQUIRED",
            "executableAuthorityGranted": False,
        },
        "claimSha256": claim_sha,
        "result": "PASS_NONPRODUCTION_GLOBAL_AUTHORITY_PENDING",
        "positiveFixtures": positives,
        "negativeFixtures": negatives,
        "negativeFixtureCount": len(negatives),
        "deterministicRepeat": repeats,
        "architecture": {
            "plannedScheduleSeparateFromObservedReceipt": True,
            "cellContentCommitBound": True,
            "receiptCommitEmbedded": False,
            "portableRepoPaths": True,
            "halfOpenIntervalsEndBeforeStart": True,
            "dispatchAndObservedEventSequencesValidated": True,
            "directionLocalCancellation": True,
            "appendOnlyRetryIdentity": True,
            "fixedDag": True,
            "singleAssembler": True,
            "cap2OverlapMode": True,
            "cap1ExceptionMode": True,
        },
        "globalIntegrationBoundary": {
            "schemaPath": None,
            "schemaSha256": None,
            "validatorPath": None,
            "validatorSha256": None,
            "globalScheduleReceiptPath": None,
            "globalScheduleReceiptSha256": None,
            "authorityCommit": None,
            "published": False,
            "globalCapProven": False,
            "productionReady": False,
        },
        "executionBoundary": {
            "testRuntime": Path(sys.executable).name,
            "validatorSubprocessInvocations": 3,
            "dccProcessInvocations": 0,
            "renderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizationInvocations": 0,
            "contactSheetInvocations": 0,
            "packetWrites": 0,
            "pixelFiles": pixel_files,
        },
    }
    sys.stdout.buffer.write(canonical_bytes(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
