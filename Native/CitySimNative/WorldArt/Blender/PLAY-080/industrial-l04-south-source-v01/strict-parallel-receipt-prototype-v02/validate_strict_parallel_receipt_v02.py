#!/usr/bin/env python3
"""Validate the PLAY-080 v02 nonproduction schedule/receipt model."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import stat
import sys
from pathlib import Path, PurePosixPath
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker


PROCESS_IDS = ("A", "B", "C")
SOURCE_ROOT = PurePosixPath(
    "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
    "industrial-l04-south-source-v01"
)
EVIDENCE_ROOT = PurePosixPath(
    "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01"
)
PROTOTYPE_ROOT = SOURCE_ROOT / "strict-parallel-receipt-prototype-v02"
EXPECTED_JOBS = {
    "provenance-A": ("provenance_rgba", ("process-A",)),
    "provenance-B": ("provenance_rgba", ("process-B",)),
    "provenance-C": ("provenance_rgba", ("process-C",)),
    "identity-join": (
        "identity_join",
        ("provenance-A", "provenance-B", "provenance-C"),
    ),
    "normalization-repeat-1": ("normalization_repeat", ("identity-join",)),
    "normalization-repeat-2": ("normalization_repeat", ("identity-join",)),
    "literal-color": (
        "literal_color",
        ("normalization-repeat-1", "normalization-repeat-2"),
    ),
    "grayscale": (
        "grayscale",
        ("normalization-repeat-1", "normalization-repeat-2"),
    ),
    "contact-sheet": (
        "contact_sheet",
        ("normalization-repeat-1", "normalization-repeat-2"),
    ),
    "packet-assembly": (
        "packet_assembly",
        ("literal-color", "grayscale", "contact-sheet"),
    ),
}
GRANT_KEYS = (
    "blender",
    "render",
    "pixels",
    "normalization",
    "contactSheet",
    "packetWrite",
    "productionAdmission",
    "integrationAdmitted",
    "rendererQuarantined",
    "productionSelected",
    "shipping",
)


class ModelRejected(Exception):
    def __init__(self, code: str, detail: Any) -> None:
        super().__init__(code)
        self.code = code
        self.detail = detail


def reject(code: str, detail: Any) -> None:
    raise ModelRejected(code, detail)


def object_without_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("DUPLICATE_JSON_KEY", key)
        result[key] = value
    return result


def reject_nonfinite(value: str) -> None:
    reject("NONFINITE_JSON_NUMBER", value)


def load_json_bytes(data: bytes, label: str) -> Any:
    try:
        value = json.loads(
            data,
            object_pairs_hook=object_without_duplicates,
            parse_constant=reject_nonfinite,
        )
    except ModelRejected:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        reject("INVALID_JSON", f"{label}: {error}")
    assert_finite(value, label)
    return value


def assert_finite(value: Any, label: str) -> None:
    if isinstance(value, float) and not math.isfinite(value):
        reject("NONFINITE_JSON_NUMBER", label)
    if isinstance(value, dict):
        for key, child in value.items():
            assert_finite(child, f"{label}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            assert_finite(child, f"{label}[{index}]")


def reject_input_symlink_ancestors(path: Path, label: str) -> None:
    absolute = path.absolute()
    current = Path(absolute.anchor)
    for component in absolute.parts[1:-1]:
        current = current / component
        try:
            item = os.lstat(current)
        except OSError as error:
            reject("INPUT_ANCESTOR_LSTAT_FAILED", f"{label}: {current}: {error}")
        if stat.S_ISLNK(item.st_mode):
            reject("SYMLINK_INPUT_ANCESTOR_REJECTED", f"{label}: {current}")
        if not stat.S_ISDIR(item.st_mode):
            reject("NON_DIRECTORY_INPUT_ANCESTOR", f"{label}: {current}")


def read_regular_nofollow(path: Path, label: str) -> bytes:
    reject_input_symlink_ancestors(path, label)
    try:
        before = os.lstat(path)
    except OSError as error:
        reject("MISSING_INPUT_FILE", f"{label}: {path}: {error}")
    if stat.S_ISLNK(before.st_mode):
        reject("SYMLINK_INPUT_REJECTED", f"{label}: {path}")
    if not stat.S_ISREG(before.st_mode):
        reject("NONREGULAR_INPUT_REJECTED", f"{label}: {path}")
    parent_flags = (
        os.O_RDONLY
        | getattr(os, "O_DIRECTORY", 0)
        | getattr(os, "O_NOFOLLOW", 0)
    )
    try:
        parent_descriptor = os.open(path.parent, parent_flags)
    except OSError as error:
        reject("PARENT_DIRECTORY_OPEN_FAILED", f"{label}: {path.parent}: {error}")
    try:
        parent_before = os.fstat(parent_descriptor)
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
        try:
            descriptor = os.open(path.name, flags, dir_fd=parent_descriptor)
        except OSError as error:
            reject("NOFOLLOW_OPEN_FAILED", f"{label}: {path}: {error}")
        try:
            opened = os.fstat(descriptor)
            before_identity = (
                before.st_dev,
                before.st_ino,
                before.st_size,
                before.st_mtime_ns,
                before.st_ctime_ns,
            )
            opened_identity = (
                opened.st_dev,
                opened.st_ino,
                opened.st_size,
                opened.st_mtime_ns,
                opened.st_ctime_ns,
            )
            if before_identity != opened_identity:
                reject("INPUT_REPLACED_DURING_OPEN", f"{label}: {path}")
            chunks: list[bytes] = []
            while True:
                chunk = os.read(descriptor, 1024 * 1024)
                if not chunk:
                    break
                chunks.append(chunk)
            after = os.fstat(descriptor)
            try:
                relisted = os.lstat(path)
            except OSError as error:
                reject("INPUT_RELIST_FAILED", f"{label}: {path}: {error}")
            after_identity = (
                after.st_dev,
                after.st_ino,
                after.st_size,
                after.st_mtime_ns,
                after.st_ctime_ns,
            )
            relisted_identity = (
                relisted.st_dev,
                relisted.st_ino,
                relisted.st_size,
                relisted.st_mtime_ns,
                relisted.st_ctime_ns,
            )
            if opened_identity != after_identity or after_identity != relisted_identity:
                reject("INPUT_CHANGED_DURING_READ", f"{label}: {path}")
            parent_after = os.fstat(parent_descriptor)
            try:
                parent_relisted = os.lstat(path.parent)
            except OSError as error:
                reject("PARENT_DIRECTORY_RELIST_FAILED", f"{label}: {path.parent}: {error}")
            parent_before_identity = (
                parent_before.st_dev,
                parent_before.st_ino,
                parent_before.st_mtime_ns,
                parent_before.st_ctime_ns,
            )
            parent_after_identity = (
                parent_after.st_dev,
                parent_after.st_ino,
                parent_after.st_mtime_ns,
                parent_after.st_ctime_ns,
            )
            parent_relisted_identity = (
                parent_relisted.st_dev,
                parent_relisted.st_ino,
                parent_relisted.st_mtime_ns,
                parent_relisted.st_ctime_ns,
            )
            if (
                parent_before_identity != parent_after_identity
                or parent_after_identity != parent_relisted_identity
            ):
                reject("PARENT_DIRECTORY_CHANGED_DURING_READ", f"{label}: {path.parent}")
            return b"".join(chunks)
        finally:
            os.close(descriptor)
    finally:
        os.close(parent_descriptor)


def repository_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        if parent.joinpath(".git").exists():
            return parent
    reject("REPOSITORY_ROOT_NOT_FOUND", str(Path(__file__).resolve()))


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def strict_repo_path(value: Any, label: str) -> PurePosixPath:
    if not isinstance(value, str) or not value:
        reject("UNSAFE_REPO_PATH", f"{label}: {value!r}")
    if value.startswith("/") or "\\" in value or "\x00" in value:
        reject("UNSAFE_REPO_PATH", f"{label}: {value!r}")
    components = value.split("/")
    if any(component in {"", ".", ".."} for component in components):
        reject("UNSAFE_REPO_PATH", f"{label}: {value!r}")
    pure = PurePosixPath(value)
    if pure.is_absolute() or pure.as_posix() != value:
        reject("UNSAFE_REPO_PATH", f"{label}: {value!r}")
    return pure


def reject_symlink_components(repo: Path, pure: PurePosixPath, label: str) -> None:
    current = repo
    for component in pure.parts:
        current = current / component
        try:
            item = os.lstat(current)
        except FileNotFoundError:
            return
        except OSError as error:
            reject("PATH_COMPONENT_LSTAT_FAILED", f"{label}: {current}: {error}")
        if stat.S_ISLNK(item.st_mode):
            reject("SYMLINK_PATH_COMPONENT", f"{label}: {pure.as_posix()}")


def is_within(pure: PurePosixPath, root: PurePosixPath) -> bool:
    return pure == root or root in pure.parents


def owned_path(repo: Path, value: Any, label: str) -> PurePosixPath:
    pure = strict_repo_path(value, label)
    if not (is_within(pure, SOURCE_ROOT) or is_within(pure, EVIDENCE_ROOT)):
        reject("PATH_OUTSIDE_PLAY_080_OWNERSHIP", f"{label}: {pure}")
    if pure in {SOURCE_ROOT, EVIDENCE_ROOT}:
        reject("PATH_TOO_BROAD", f"{label}: {pure}")
    reject_symlink_components(repo, pure, label)
    return pure


def roots_overlap(left: PurePosixPath, right: PurePosixPath) -> bool:
    return left == right or left in right.parents or right in left.parents


def parse_timestamp(value: str, label: str) -> dt.datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        reject("TIMESTAMP_NOT_UTC_Z", f"{label}: {value!r}")
    try:
        parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        reject("INVALID_TIMESTAMP", f"{label}: {value}")
    if parsed.utcoffset() != dt.timedelta(0):
        reject("TIMESTAMP_NOT_UTC_Z", f"{label}: {value}")
    return parsed


def interval(
    started: str, ended: str, label: str
) -> tuple[dt.datetime, dt.datetime]:
    start = parse_timestamp(started, f"{label}.start")
    end = parse_timestamp(ended, f"{label}.end")
    if start >= end:
        reject("INVALID_HALF_OPEN_INTERVAL", label)
    return start, end


def schema_validate(schema: Any, payload: Any, label: str) -> None:
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = sorted(
        validator.iter_errors(payload),
        key=lambda error: (tuple(str(part) for part in error.absolute_path), error.message),
    )
    if errors:
        error = errors[0]
        path = ".".join(str(part) for part in error.absolute_path) or "<root>"
        reject("SCHEMA_INVALID", f"{label}.{path}: {error.message}")


def require_all_grants_false(payload: dict[str, Any], label: str) -> None:
    grants = payload["grants"]
    if set(grants) != set(GRANT_KEYS) or any(grants.values()):
        reject("GRANT_NOT_FALSE", label)


def validate_global_boundary(payload: dict[str, Any], label: str) -> None:
    authority = payload["globalIntegrationAuthority"]
    if authority != {
        "owner": "Integration",
        "schemaPath": None,
        "schemaSha256": None,
        "validatorPath": None,
        "validatorSha256": None,
        "scheduleReceiptPath": None,
        "scheduleReceiptSha256": None,
        "authorityCommit": None,
        "published": False,
    }:
        reject("GLOBAL_AUTHORITY_NOT_NULL_UNPUBLISHED", label)


def half_open_peak(
    intervals: dict[str, tuple[dt.datetime, dt.datetime]]
) -> tuple[int, list[dict[str, Any]]]:
    events: list[tuple[dt.datetime, int, str]] = []
    for identity, (start, end) in intervals.items():
        events.append((end, 0, identity))
        events.append((start, 1, identity))
    active: set[str] = set()
    peak = 0
    trace: list[dict[str, Any]] = []
    for timestamp, kind, identity in sorted(events, key=lambda item: (item[0], item[1], item[2])):
        if kind == 0:
            if identity not in active:
                reject("INTERVAL_SWEEP_UNDERFLOW", identity)
            active.remove(identity)
            action = "end"
        else:
            if identity in active:
                reject("INTERVAL_SWEEP_DUPLICATE_START", identity)
            active.add(identity)
            peak = max(peak, len(active))
            action = "start"
        trace.append(
            {
                "atUtc": timestamp.isoformat().replace("+00:00", "Z"),
                "action": action,
                "identity": identity,
                "activeCount": len(active),
            }
        )
    if active:
        reject("INTERVAL_SWEEP_NOT_CLOSED", sorted(active))
    return peak, trace


def attempt_identity_payload(attempt: dict[str, Any]) -> dict[str, Any]:
    return {
        "attemptId": attempt["attemptId"],
        "processId": attempt["processId"],
        "ordinal": attempt["ordinal"],
        "previousAttemptId": attempt["previousAttemptId"],
        "ownedRoots": attempt["ownedRoots"],
    }


def attempt_identity_sha(attempt: dict[str, Any]) -> str:
    return sha256_bytes(canonical_bytes(attempt_identity_payload(attempt)))


def validate_attempts_and_roots(
    repo: Path, schedule: dict[str, Any]
) -> tuple[dict[str, dict[str, Any]], list[tuple[str, PurePosixPath]]]:
    attempts: dict[str, dict[str, Any]] = {}
    prior_by_process: dict[str, dict[str, Any]] = {}
    roots: list[tuple[str, PurePosixPath]] = []
    for expected_index, attempt in enumerate(schedule["attemptLedger"], start=1):
        attempt_id = attempt["attemptId"]
        process_id = attempt["processId"]
        if attempt["ledgerIndex"] != expected_index:
            reject("ATTEMPT_LEDGER_NOT_APPEND_ONLY", attempt_id)
        if attempt_id in attempts:
            reject("DUPLICATE_ATTEMPT_ID", attempt_id)
        previous = prior_by_process.get(process_id)
        if previous is None:
            if attempt["ordinal"] != 1 or attempt["previousAttemptId"] is not None:
                reject("INVALID_INITIAL_ATTEMPT_IDENTITY", attempt_id)
        else:
            if (
                attempt["ordinal"] != previous["ordinal"] + 1
                or attempt["previousAttemptId"] != previous["attemptId"]
            ):
                reject("INVALID_RETRY_CHAIN", attempt_id)
        if attempt["identitySha256"] != attempt_identity_sha(attempt):
            reject("ATTEMPT_IDENTITY_HASH_MISMATCH", attempt_id)
        if len(attempt["ownedRoots"]) != 2:
            reject("ATTEMPT_OWNED_ROOT_COUNT", attempt_id)
        for root_index, value in enumerate(attempt["ownedRoots"]):
            root = owned_path(repo, value, f"attemptLedger.{attempt_id}.ownedRoots[{root_index}]")
            roots.append((f"attempt-{attempt_id}-root-{root_index}", root))
        attempts[attempt_id] = attempt
        prior_by_process[process_id] = attempt
    if set(prior_by_process) != set(PROCESS_IDS):
        reject("PROCESS_ATTEMPT_SET_MISMATCH", sorted(prior_by_process))
    return attempts, roots


def validate_allocations_and_dispatch(
    schedule: dict[str, Any], attempts: dict[str, dict[str, Any]]
) -> tuple[
    dict[str, dict[str, Any]],
    dict[str, tuple[dt.datetime, dt.datetime]],
    int,
    list[dict[str, Any]],
    dict[str, dict[str, Any]],
]:
    allocations: dict[str, dict[str, Any]] = {}
    allocation_ids: set[str] = set()
    all_intervals: dict[str, tuple[dt.datetime, dt.datetime]] = {}
    for allocation in schedule["allocations"]:
        attempt_id = allocation["attemptId"]
        allocation_id = allocation["allocationId"]
        if allocation_id in allocation_ids:
            reject("DUPLICATE_ALLOCATION_ID", allocation_id)
        allocation_ids.add(allocation_id)
        if attempt_id not in attempts:
            reject("ALLOCATION_UNKNOWN_ATTEMPT", attempt_id)
        if (
            allocation["taskId"] != "PLAY-080"
            or allocation["direction"] != "south"
            or allocation["processId"] != attempts[attempt_id]["processId"]
        ):
            reject("ALLOCATION_PROCESS_MISMATCH", attempt_id)
        if attempt_id in allocations:
            reject("DUPLICATE_ALLOCATION_ATTEMPT", attempt_id)
        if allocation["state"] != attempts[attempt_id]["state"]:
            reject("ALLOCATION_STATE_MISMATCH", attempt_id)
        expected_retry = attempts[attempt_id]["previousAttemptId"]
        if allocation["retryOf"] != expected_retry:
            reject("ALLOCATION_RETRY_BINDING_MISMATCH", attempt_id)
        if (
            expected_retry is None
            and allocation["retryScope"] is not None
        ) or (
            expected_retry is not None
            and allocation["retryScope"] not in {"single_process", "complete_direction_set"}
        ):
            reject("ALLOCATION_RETRY_SCOPE_INVALID", attempt_id)
        allocations[attempt_id] = allocation
        all_intervals[attempt_id] = interval(
            allocation["notBeforeUtc"],
            allocation["notAfterUtc"],
            f"allocations.{attempt_id}",
        )
    if set(allocations) != set(attempts):
        reject(
            "ALLOCATION_ATTEMPT_SET_MISMATCH",
            {"expected": sorted(attempts), "observed": sorted(allocations)},
        )
    direction_set_retries = {
        allocation["processId"]
        for allocation in allocations.values()
        if allocation["retryScope"] == "complete_direction_set"
    }
    if direction_set_retries and direction_set_retries != set(PROCESS_IDS):
        reject("AMBIGUOUS_COMPLETE_DIRECTION_RETRY_SCOPE", sorted(direction_set_retries))
    dispatch_sequences = [
        allocation["dispatchSequence"] for allocation in schedule["allocations"]
    ]
    if dispatch_sequences != list(range(1, len(allocations) + 1)):
        reject("ALLOCATION_DISPATCH_SEQUENCE_INVALID", dispatch_sequences)

    events = schedule["dispatchEvents"]
    if [event["sequence"] for event in events] != list(range(1, len(events) + 1)):
        reject("DISPATCH_SEQUENCE_INVALID", "sequences must be contiguous from one")
    event_ids = [event["eventId"] for event in events]
    if len(event_ids) != len(set(event_ids)):
        reject("DUPLICATE_DISPATCH_EVENT_ID", event_ids)
    event_times = [
        parse_timestamp(event["atUtc"], f"dispatchEvents.{event['sequence']}")
        for event in events
    ]
    if event_times != sorted(event_times):
        reject("DISPATCH_TIME_ORDER_INVALID", "events are not chronological")
    if events[0]["kind"] != "schedule_sealed":
        reject("DISPATCH_FIRST_EVENT_INVALID", events[0]["kind"])

    seen_dispatch: set[str] = set()
    seen_acquire: set[str] = set()
    seen_cancel: set[str] = set()
    event_by_id: dict[str, dict[str, Any]] = {}
    dispatch_order: list[str] = []
    for event in events[1:]:
        attempt_id = event["attemptId"]
        if attempt_id not in attempts:
            reject("DISPATCH_EVENT_UNKNOWN_ATTEMPT", attempt_id)
        event_by_id[event["eventId"]] = event
        kind = event["kind"]
        if kind in {"process_dispatched", "retry_dispatched"}:
            if kind == "retry_dispatched" and attempts[attempt_id]["ordinal"] == 1:
                reject("RETRY_EVENT_FOR_INITIAL_ATTEMPT", attempt_id)
            if kind == "process_dispatched" and attempts[attempt_id]["ordinal"] > 1:
                reject("RETRY_DISPATCH_KIND_INVALID", attempt_id)
            if attempt_id in seen_dispatch:
                reject("DUPLICATE_ATTEMPT_DISPATCH", attempt_id)
            seen_dispatch.add(attempt_id)
            dispatch_order.append(attempt_id)
        elif kind == "slot_acquired":
            if attempt_id not in seen_dispatch:
                reject("SLOT_ACQUIRED_BEFORE_DISPATCH", attempt_id)
            if attempts[attempt_id]["state"] != "planned":
                reject("CANCELLED_ATTEMPT_ACQUIRED_SLOT", attempt_id)
            seen_acquire.add(attempt_id)
        elif kind == "allocation_cancelled":
            if attempt_id not in seen_dispatch:
                reject("ATTEMPT_CANCELLED_BEFORE_DISPATCH", attempt_id)
            if attempt_id in seen_acquire:
                reject("CANCELLATION_AFTER_SLOT_ACQUIRE", attempt_id)
            seen_cancel.add(attempt_id)

    if seen_dispatch != set(attempts):
        reject(
            "DISPATCH_ATTEMPT_SET_MISMATCH",
            {"expected": sorted(attempts), "observed": sorted(seen_dispatch)},
        )
    expected_cancelled = {
        attempt_id
        for attempt_id, attempt in attempts.items()
        if attempt["state"] == "cancelled"
    }
    if seen_cancel != expected_cancelled:
        reject("CANCELLATION_EVENT_SET_MISMATCH", sorted(seen_cancel))
    expected_acquired = set(attempts) - expected_cancelled
    if seen_acquire != expected_acquired:
        reject("SLOT_ACQUIRE_EVENT_SET_MISMATCH", sorted(seen_acquire))
    if dispatch_order != [
        allocation["attemptId"] for allocation in schedule["allocations"]
    ]:
        reject("FIFO_DISPATCH_ORDER_CHANGED", dispatch_order)
    for slot in range(schedule["limits"]["localPlannedDccCap"]):
        expected_acquire_order = [
            allocation["attemptId"]
            for allocation in schedule["allocations"]
            if allocation["state"] == "planned"
            and allocation["preassignedSlot"] == slot
        ]
        observed_acquire_order = [
            event["attemptId"]
            for event in events
            if event["kind"] == "slot_acquired"
            and allocations[event["attemptId"]]["preassignedSlot"] == slot
        ]
        if observed_acquire_order != expected_acquire_order:
            reject(
                "SAME_SLOT_ACQUIRE_FIFO_CHANGED",
                {
                    "slot": slot,
                    "expected": expected_acquire_order,
                    "observed": observed_acquire_order,
                },
            )

    cancellation = schedule["cancellationPolicy"]
    if set(cancellation["cancelledAttemptIds"]) != expected_cancelled:
        reject("CANCELLATION_POLICY_SET_MISMATCH", cancellation["cancelledAttemptIds"])
    if cancellation["direction"] != "south" or cancellation["scope"] != "direction_local":
        reject("CANCELLATION_ESCAPES_DIRECTION", cancellation)
    if cancellation["siblingDirectionsUnaffected"] != ["north", "east", "west"]:
        reject("CANCELLATION_SIBLING_EFFECT_INVALID", cancellation)

    active_intervals = {
        attempt_id: planned
        for attempt_id, planned in all_intervals.items()
        if attempts[attempt_id]["state"] == "planned"
    }
    peak, trace = half_open_peak(active_intervals)
    cap = schedule["limits"]["localPlannedDccCap"]
    if peak > cap:
        reject("PLANNED_CAP_EXCEEDED", {"peak": peak, "cap": cap})

    for slot in range(cap):
        slot_intervals = {
            attempt_id: active_intervals[attempt_id]
            for attempt_id, allocation in allocations.items()
            if allocation["state"] == "planned"
            and allocation["preassignedSlot"] == slot
        }
        if slot_intervals:
            slot_peak, _ = half_open_peak(slot_intervals)
            if slot_peak > 1:
                reject("SAME_SLOT_PLANNED_OVERLAP", {"slot": slot, "peak": slot_peak})
        slot_allocations = sorted(
            (
                allocation
                for allocation in allocations.values()
                if allocation["state"] == "planned"
                and allocation["preassignedSlot"] == slot
            ),
            key=lambda allocation: allocation["dispatchSequence"],
        )
        for previous, current in zip(slot_allocations, slot_allocations[1:]):
            previous_interval = all_intervals[previous["attemptId"]]
            current_interval = all_intervals[current["attemptId"]]
            if previous_interval[1] > current_interval[0]:
                reject(
                    "SAME_SLOT_PLANNED_LEASE_FIFO_CHANGED",
                    {
                        "slot": slot,
                        "previousAttemptId": previous["attemptId"],
                        "previousDispatchSequence": previous["dispatchSequence"],
                        "currentAttemptId": current["attemptId"],
                        "currentDispatchSequence": current["dispatchSequence"],
                    },
                )

    mode = schedule["scheduleMode"]
    exception = schedule["resourceException"]
    if mode == "parallel_two_slot":
        if cap != 2 or peak != 2 or exception is not None:
            reject("CAP2_MODE_INVALID", {"cap": cap, "peak": peak, "exception": exception})
    elif mode == "sequential_exception":
        if cap != 1 or peak != 1 or exception is None:
            reject("CAP1_EXCEPTION_MODE_INVALID", {"cap": cap, "peak": peak})
        if any(
            exception[key] is not None
            for key in ("integrationPath", "integrationSha256", "authorityCommit")
        ) or exception["published"]:
            reject("CAP1_EXCEPTION_AUTHORITY_MUST_REMAIN_NULL", exception)
    return allocations, all_intervals, peak, trace, event_by_id


def validate_receipt_roots_and_processes(
    repo: Path,
    schedule: dict[str, Any],
    receipt: dict[str, Any],
    attempts: dict[str, dict[str, Any]],
    allocations: dict[str, dict[str, Any]],
    allocation_intervals: dict[str, tuple[dt.datetime, dt.datetime]],
    scheduler_events: dict[str, dict[str, Any]],
    schedule_roots: list[tuple[str, PurePosixPath]],
) -> tuple[dict[str, tuple[dt.datetime, dt.datetime]], list[tuple[str, PurePosixPath]]]:
    processes = receipt["processes"]
    if tuple(processes.keys()) != PROCESS_IDS:
        reject("PROCESS_SET_MISMATCH", list(processes.keys()))
    observed_intervals: dict[str, tuple[dt.datetime, dt.datetime]] = {}
    roots = list(schedule_roots)
    for process_id in PROCESS_IDS:
        process = processes[process_id]
        attempt_id = process["attemptId"]
        if process["processId"] != process_id:
            reject("PROCESS_ID_MISMATCH", process_id)
        if process["invocationCount"] != 1:
            reject("INVOCATION_COUNT_INVALID", process_id)
        if attempt_id not in attempts or attempts[attempt_id]["processId"] != process_id:
            reject("OBSERVED_ATTEMPT_IDENTITY_INVALID", attempt_id)
        if attempts[attempt_id]["state"] != "planned":
            reject("CANCELLED_ATTEMPT_OBSERVED", attempt_id)
        if process["ownedRoots"] != attempts[attempt_id]["ownedRoots"]:
            reject("OBSERVED_ROOTS_DIFFER_FROM_ATTEMPT", attempt_id)
        allocation = allocations[attempt_id]
        if (
            process["allocationId"] != allocation["allocationId"]
            or process["preassignedSlot"] != allocation["preassignedSlot"]
        ):
            reject("OBSERVED_ALLOCATION_BINDING_MISMATCH", attempt_id)
        referenced_events = process["schedulerEventIds"]
        expected_events = [
            event["eventId"]
            for event in schedule["dispatchEvents"]
            if event["attemptId"] == attempt_id
            and event["kind"]
            in {"process_dispatched", "retry_dispatched", "slot_acquired"}
        ]
        if referenced_events != expected_events:
            reject("SCHEDULER_EVENT_REFERENCE_MISMATCH", attempt_id)
        if any(
            event_id not in scheduler_events
            or scheduler_events[event_id]["attemptId"] != attempt_id
            for event_id in referenced_events
        ):
            reject("FOREIGN_SCHEDULER_EVENT_REFERENCE", attempt_id)
        observed = interval(
            process["startedAtUtc"],
            process["endedAtUtc"],
            f"processes.{process_id}",
        )
        planned = allocation_intervals[attempt_id]
        if observed[0] < planned[0] or observed[1] > planned[1]:
            reject("OBSERVED_INTERVAL_OUTSIDE_ALLOCATION", attempt_id)
        observed_intervals[attempt_id] = observed

    for slot in range(schedule["limits"]["localPlannedDccCap"]):
        slot_intervals = {
            attempt_id: observed_intervals[attempt_id]
            for attempt_id in observed_intervals
            if allocations[attempt_id]["preassignedSlot"] == slot
        }
        if slot_intervals:
            slot_peak, _ = half_open_peak(slot_intervals)
            if slot_peak > 1:
                reject("SAME_SLOT_OBSERVED_OVERLAP", {"slot": slot, "peak": slot_peak})

    for job in receipt["jobs"]:
        root = owned_path(repo, job["root"], f"jobs.{job['jobId']}.root")
        roots.append((f"job-{job['jobId']}", root))

    for index, (left_label, left_root) in enumerate(roots):
        for right_label, right_root in roots[index + 1 :]:
            if roots_overlap(left_root, right_root):
                reject(
                    "ROOT_ISOLATION_FAILURE",
                    {
                        "left": left_label,
                        "leftRoot": left_root.as_posix(),
                        "right": right_label,
                        "rightRoot": right_root.as_posix(),
                    },
                )
    return observed_intervals, roots


def validate_receipt_events(
    receipt: dict[str, Any],
    observed: dict[str, tuple[dt.datetime, dt.datetime]],
    cancelled: set[str],
    retry_attempts: set[str],
) -> None:
    events = receipt["events"]
    if [event["sequence"] for event in events] != list(range(1, len(events) + 1)):
        reject("OBSERVED_EVENT_SEQUENCE_INVALID", "sequences must be contiguous from one")
    event_ids = [event["eventId"] for event in events]
    if len(event_ids) != len(set(event_ids)):
        reject("DUPLICATE_OBSERVED_EVENT_ID", event_ids)
    times = [
        parse_timestamp(event["atUtc"], f"events.{event['sequence']}")
        for event in events
    ]
    if times != sorted(times):
        reject("OBSERVED_EVENT_TIME_ORDER_INVALID", "events are not chronological")
    starts: dict[str, dt.datetime] = {}
    ends: dict[str, dt.datetime] = {}
    observed_cancels: set[str] = set()
    observed_retries: set[str] = set()
    for event, timestamp in zip(events, times):
        attempt_id = event["attemptId"]
        if event["direction"] != "south":
            reject("CANCELLATION_ESCAPES_DIRECTION", event)
        if event["kind"] == "process_started":
            if attempt_id in starts:
                reject("DUPLICATE_PROCESS_START_EVENT", attempt_id)
            starts[attempt_id] = timestamp
        elif event["kind"] == "process_ended":
            if attempt_id not in starts or attempt_id in ends:
                reject("PROCESS_END_EVENT_ORDER_INVALID", attempt_id)
            ends[attempt_id] = timestamp
        elif event["kind"] == "attempt_cancel_observed":
            observed_cancels.add(attempt_id)
        elif event["kind"] == "retry_observed":
            observed_retries.add(attempt_id)
    if set(starts) != set(observed) or set(ends) != set(observed):
        reject("PROCESS_EVENT_SET_MISMATCH", {"starts": sorted(starts), "ends": sorted(ends)})
    for attempt_id, (start, end) in observed.items():
        if starts[attempt_id] != start or ends[attempt_id] != end:
            reject("PROCESS_EVENT_TIMESTAMP_MISMATCH", attempt_id)
    if observed_cancels != cancelled:
        reject("OBSERVED_CANCELLATION_SET_MISMATCH", sorted(observed_cancels))
    if observed_retries != retry_attempts:
        reject("OBSERVED_RETRY_SET_MISMATCH", sorted(observed_retries))


def validate_fixed_dag(receipt: dict[str, Any]) -> None:
    jobs = receipt["jobs"]
    by_id: dict[str, dict[str, Any]] = {}
    for job in jobs:
        if job["jobId"] in by_id:
            reject("DUPLICATE_JOB_ID", job["jobId"])
        by_id[job["jobId"]] = job
    if set(by_id) != set(EXPECTED_JOBS):
        reject("FIXED_DAG_JOB_SET_MISMATCH", sorted(by_id))
    for job_id, (kind, dependencies) in EXPECTED_JOBS.items():
        job = by_id[job_id]
        if job["kind"] != kind or tuple(job["dependsOn"]) != dependencies:
            reject("FIXED_DAG_EDGE_MISMATCH", job_id)
    completed: set[str] = {f"process-{process_id}" for process_id in PROCESS_IDS}
    remaining = set(by_id)
    while remaining:
        ready = {
            job_id
            for job_id in remaining
            if set(by_id[job_id]["dependsOn"]) <= completed
        }
        if not ready:
            reject("FIXED_DAG_CYCLE", sorted(remaining))
        completed.update(ready)
        remaining -= ready
    assembler = receipt["assembler"]
    if (
        assembler["jobId"] != "packet-assembly"
        or assembler["invocationCount"] != 1
        or sum(job["kind"] == "packet_assembly" for job in jobs) != 1
    ):
        reject("SINGLE_ASSEMBLER_VIOLATION", assembler)


def validate_identity_join(
    receipt: dict[str, Any], attempts: dict[str, dict[str, Any]]
) -> None:
    join = receipt["join"]
    expected_selected = {
        process_id: receipt["processes"][process_id]["attemptId"]
        for process_id in PROCESS_IDS
    }
    if join["selectedAttempts"] != expected_selected:
        reject("IDENTITY_JOIN_SELECTION_MISMATCH", join["selectedAttempts"])
    if join["allAttemptIds"] != list(attempts):
        reject("IDENTITY_JOIN_HISTORY_MISMATCH", join["allAttemptIds"])
    if (
        join["rawIdentityResult"] != "STRUCTURAL_FIXTURE_PASS"
        or join["semanticIdentityResult"] != "STRUCTURAL_FIXTURE_PASS"
    ):
        reject("IDENTITY_JOIN_RESULT_FALSE", join)


def validate_documents(
    *,
    repo: Path,
    schedule_schema_bytes: bytes,
    receipt_schema_bytes: bytes,
    schedule_bytes: bytes,
    receipt_bytes: bytes,
    schedule_repo_path: str,
) -> dict[str, Any]:
    schedule_schema = load_json_bytes(schedule_schema_bytes, "scheduleSchema")
    receipt_schema = load_json_bytes(receipt_schema_bytes, "receiptSchema")
    schedule = load_json_bytes(schedule_bytes, "plannedSchedule")
    receipt = load_json_bytes(receipt_bytes, "observedReceipt")
    schema_validate(schedule_schema, schedule, "plannedSchedule")
    schema_validate(receipt_schema, receipt, "observedReceipt")

    expected_schedule_path = strict_repo_path(schedule_repo_path, "scheduleInputPath")
    declared_schedule_path = strict_repo_path(
        receipt["plannedScheduleRef"]["path"], "plannedScheduleRef.path"
    )
    if expected_schedule_path != declared_schedule_path:
        reject(
            "PLANNED_SCHEDULE_PATH_MISMATCH",
            {"actual": expected_schedule_path.as_posix(), "declared": declared_schedule_path.as_posix()},
        )
    if not is_within(declared_schedule_path, PROTOTYPE_ROOT):
        reject("PLANNED_SCHEDULE_PATH_OUTSIDE_PROTOTYPE", declared_schedule_path.as_posix())
    reject_symlink_components(repo, declared_schedule_path, "plannedScheduleRef.path")
    if receipt["plannedScheduleRef"]["sha256"] != sha256_bytes(schedule_bytes):
        reject("PLANNED_SCHEDULE_SHA_MISMATCH", receipt["plannedScheduleRef"])
    if receipt["plannedScheduleRef"]["commit"] is not None:
        reject("UNPUBLISHED_SCHEDULE_COMMIT_MUST_BE_NULL", receipt["plannedScheduleRef"])

    schedule_identity = schedule["identity"]
    receipt_identity = receipt["identity"]
    for key in ("taskId", "branch", "direction", "scheduleId"):
        if schedule_identity[key] != receipt_identity[key]:
            reject("SCHEDULE_RECEIPT_IDENTITY_MISMATCH", key)
    if "receiptCommit" in receipt_identity:
        reject("SELF_REFERENTIAL_RECEIPT_COMMIT_FORBIDDEN", receipt_identity)

    validate_global_boundary(schedule, "plannedSchedule")
    validate_global_boundary(receipt, "observedReceipt")
    require_all_grants_false(receipt, "observedReceipt")
    if receipt["result"] != "PASS_NONPRODUCTION_GLOBAL_AUTHORITY_PENDING":
        reject("RECEIPT_RESULT_INVALID", receipt["result"])

    attempts, schedule_roots = validate_attempts_and_roots(repo, schedule)
    (
        allocations,
        allocation_intervals,
        planned_peak,
        planned_trace,
        scheduler_events,
    ) = validate_allocations_and_dispatch(schedule, attempts)
    observed, receipt_roots = validate_receipt_roots_and_processes(
        repo,
        schedule,
        receipt,
        attempts,
        allocations,
        allocation_intervals,
        scheduler_events,
        schedule_roots,
    )
    observed_peak, observed_trace = half_open_peak(observed)
    if observed_peak > schedule["limits"]["localPlannedDccCap"]:
        reject(
            "OBSERVED_CAP_EXCEEDED",
            {"peak": observed_peak, "cap": schedule["limits"]["localPlannedDccCap"]},
        )
    mode = schedule["scheduleMode"]
    if mode == "parallel_two_slot" and observed_peak != 2:
        reject("CAP2_OBSERVED_OVERLAP_MISSING", observed_peak)
    if mode == "sequential_exception" and observed_peak != 1:
        reject("CAP1_OBSERVED_SEQUENTIAL_INVALID", observed_peak)

    cancelled = {
        attempt_id
        for attempt_id, attempt in attempts.items()
        if attempt["state"] == "cancelled"
    }
    if set(receipt["cancellations"]["attemptIds"]) != cancelled:
        reject("RECEIPT_CANCELLATION_SET_MISMATCH", receipt["cancellations"])
    if (
        receipt["cancellations"]["scope"] != "direction_local"
        or receipt["cancellations"]["direction"] != "south"
        or not receipt["cancellations"]["siblingDirectionsUnaffected"]
    ):
        reject("CANCELLATION_ESCAPES_DIRECTION", receipt["cancellations"])
    retry_attempts = {
        attempt_id
        for attempt_id, attempt in attempts.items()
        if attempt["ordinal"] > 1
    }
    validate_receipt_events(receipt, observed, cancelled, retry_attempts)
    validate_identity_join(receipt, attempts)
    validate_fixed_dag(receipt)

    return {
        "schema": "citysim.play-080.strict-parallel-model-validation.v02",
        "result": "PASS_NONPRODUCTION_GLOBAL_AUTHORITY_PENDING",
        "taskId": "PLAY-080",
        "direction": "south",
        "scheduleMode": mode,
        "scheduleId": schedule_identity["scheduleId"],
        "receiptId": receipt_identity["receiptId"],
        "cellContentCommit": receipt_identity["cellContentCommit"],
        "receiptCommitEmbedded": False,
        "receiptCommitBindingOwner": "Integration closeout",
        "plannedScheduleSha256": sha256_bytes(schedule_bytes),
        "plannedPeak": planned_peak,
        "observedPeak": observed_peak,
        "halfOpenIntervalPolicy": "[start,end); end-before-start",
        "plannedSweep": planned_trace,
        "observedSweep": observed_trace,
        "rootCount": len(receipt_roots),
        "globalIntegrationAuthoritiesPublished": False,
        "globalCapProven": False,
        "allGrantsFalse": True,
        "productionReady": False,
        "actualDccProcessInvocations": 0,
        "actualPixelFiles": 0,
    }


def result_bytes(value: dict[str, Any]) -> bytes:
    return canonical_bytes(value)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--schedule-schema", required=True)
    parser.add_argument("--receipt-schema", required=True)
    parser.add_argument("--schedule", required=True)
    parser.add_argument("--receipt", required=True)
    parser.add_argument("--repo-root")
    parser.add_argument("--schedule-repo-path", required=True)
    args = parser.parse_args()
    try:
        repo = Path(args.repo_root).resolve() if args.repo_root else repository_root()
        schedule_schema_bytes = read_regular_nofollow(
            Path(args.schedule_schema), "scheduleSchema"
        )
        receipt_schema_bytes = read_regular_nofollow(
            Path(args.receipt_schema), "receiptSchema"
        )
        schedule_bytes = read_regular_nofollow(Path(args.schedule), "plannedSchedule")
        receipt_bytes = read_regular_nofollow(Path(args.receipt), "observedReceipt")
        declared_schedule_input = strict_repo_path(
            args.schedule_repo_path, "scheduleInputPath"
        )
        expected_schedule_input = repo.joinpath(*declared_schedule_input.parts).absolute()
        actual_schedule_input = Path(args.schedule).absolute()
        if actual_schedule_input != expected_schedule_input:
            reject(
                "SCHEDULE_INPUT_PATH_MISMATCH",
                {
                    "actual": str(actual_schedule_input),
                    "expected": str(expected_schedule_input),
                },
            )
        result = validate_documents(
            repo=repo,
            schedule_schema_bytes=schedule_schema_bytes,
            receipt_schema_bytes=receipt_schema_bytes,
            schedule_bytes=schedule_bytes,
            receipt_bytes=receipt_bytes,
            schedule_repo_path=args.schedule_repo_path,
        )
        sys.stdout.buffer.write(result_bytes(result))
        return 0
    except ModelRejected as error:
        sys.stdout.buffer.write(
            result_bytes(
                {
                    "schema": "citysim.play-080.strict-parallel-model-validation.v02",
                    "result": "REJECTED",
                    "code": error.code,
                    "detail": error.detail,
                    "globalCapProven": False,
                    "grantsIssued": False,
                    "productionReady": False,
                    "actualDccProcessInvocations": 0,
                    "actualPixelFiles": 0,
                }
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
