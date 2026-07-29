#!/usr/bin/env python3
"""Validate a zero-pixel PLAY-080 strict parallel-receipt fixture."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
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


class ReceiptRejected(Exception):
    def __init__(self, code: str, detail: Any) -> None:
        super().__init__(code)
        self.code = code
        self.detail = detail


def reject(code: str, detail: Any) -> None:
    raise ReceiptRejected(code, detail)


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
        return json.loads(
            data,
            object_pairs_hook=object_without_duplicates,
            parse_constant=reject_nonfinite,
        )
    except ReceiptRejected:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        reject("INVALID_JSON", f"{label}: {error}")


def load_json_file(path: Path) -> Any:
    try:
        data = path.read_bytes()
    except OSError as error:
        reject("MISSING_JSON_FILE", f"{path}: {error}")
    return load_json_bytes(data, str(path))


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


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def strict_repo_path(value: str, label: str) -> PurePosixPath:
    if not isinstance(value, str) or not value:
        reject("UNSAFE_ROOT_PATH_COMPONENT", f"{label}: {value!r}")
    if value.startswith("/") or "\\" in value or "\x00" in value:
        reject("UNSAFE_ROOT_PATH_COMPONENT", f"{label}: {value}")
    components = value.split("/")
    if components[-1] == "":
        components = components[:-1]
    if not components or any(component in {"", ".", ".."} for component in components):
        reject("UNSAFE_ROOT_PATH_COMPONENT", f"{label}: {value}")
    pure = PurePosixPath(value)
    if pure.is_absolute():
        reject("UNSAFE_ROOT_PATH_COMPONENT", f"{label}: {value}")
    return pure


def safe_repo_path(repo: Path, value: str, label: str, *, must_exist: bool) -> Path:
    pure = strict_repo_path(value, label)
    resolved = repo.joinpath(*pure.parts).resolve()
    try:
        resolved.relative_to(repo.resolve())
    except ValueError:
        reject("UNSAFE_REPOSITORY_PATH", f"{label}: {value}")
    if must_exist and not resolved.is_file():
        reject("MISSING_FROZEN_INPUT", f"{label}: {value}")
    return resolved


def is_within(value: str, root: PurePosixPath) -> bool:
    pure = PurePosixPath(value)
    return pure == root or root in pure.parents


def require_owned_root(value: str, label: str) -> PurePosixPath:
    pure = strict_repo_path(value, label)
    if not (is_within(value, SOURCE_ROOT) or is_within(value, EVIDENCE_ROOT)):
        reject("ROOT_OUTSIDE_PLAY_080_OWNERSHIP", f"{label}: {value}")
    if pure == SOURCE_ROOT or pure == EVIDENCE_ROOT:
        reject("ROOT_TOO_BROAD", f"{label}: {value}")
    return pure


def roots_overlap(left: PurePosixPath, right: PurePosixPath) -> bool:
    return left == right or left in right.parents or right in left.parents


def parse_timestamp(value: str, label: str) -> dt.datetime:
    if not value.endswith("Z"):
        reject("TIMESTAMP_NOT_UTC_Z", f"{label}: {value}")
    try:
        parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        reject("INVALID_TIMESTAMP", f"{label}: {value}")
    if parsed.utcoffset() != dt.timedelta(0):
        reject("TIMESTAMP_NOT_UTC_Z", f"{label}: {value}")
    return parsed


def interval(record: dict[str, Any], label: str) -> tuple[dt.datetime, dt.datetime]:
    started = parse_timestamp(record["startedAtUtc"], f"{label}.startedAtUtc")
    ended = parse_timestamp(record["endedAtUtc"], f"{label}.endedAtUtc")
    if started >= ended:
        reject("INVALID_INTERVAL", label)
    return started, ended


def schema_validate(schema: Any, payload: Any) -> None:
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = sorted(
        validator.iter_errors(payload),
        key=lambda error: (tuple(str(part) for part in error.absolute_path), error.message),
    )
    if errors:
        error = errors[0]
        path = ".".join(str(part) for part in error.absolute_path) or "<root>"
        reject("SCHEMA_INVALID", f"{path}: {error.message}")


def validate_frozen_inputs(repo: Path, payload: dict[str, Any]) -> None:
    for name, artifact in payload["frozenInputs"].items():
        path = safe_repo_path(repo, artifact["path"], f"frozenInputs.{name}.path", must_exist=True)
        observed = sha256_file(path)
        if observed != artifact["sha256"]:
            reject(
                "FROZEN_INPUT_SHA_MISMATCH",
                {"name": name, "expected": artifact["sha256"], "observed": observed},
            )


def validate_roots_and_processes(
    repo: Path, payload: dict[str, Any]
) -> dict[str, tuple[dt.datetime, dt.datetime]]:
    del repo
    all_roots: list[tuple[str, PurePosixPath]] = []
    intervals: dict[str, tuple[dt.datetime, dt.datetime]] = {}
    processes = payload["processes"]
    if tuple(sorted(processes)) != PROCESS_IDS:
        reject("PROCESS_SET_MISMATCH", sorted(processes))
    for process_id in PROCESS_IDS:
        process = processes[process_id]
        if process["processId"] != process_id:
            reject("PROCESS_ID_MISMATCH", process_id)
        if process["invocationCount"] != 1:
            reject("PROCESS_INVOCATION_COUNT_MISMATCH", process_id)
        output_root = require_owned_root(
            process["outputRoot"], f"processes.{process_id}.outputRoot"
        )
        evidence_root = require_owned_root(
            process["evidenceRoot"], f"processes.{process_id}.evidenceRoot"
        )
        all_roots.extend(
            (
                (f"process-{process_id}-output", output_root),
                (f"process-{process_id}-evidence", evidence_root),
            )
        )
        intervals[f"process-{process_id}"] = interval(process, f"processes.{process_id}")

    for job in payload["jobs"]:
        root = require_owned_root(job["root"], f"jobs.{job['jobId']}.root")
        all_roots.append((f"job-{job['jobId']}", root))

    for index, (left_name, left_root) in enumerate(all_roots):
        for right_name, right_root in all_roots[index + 1 :]:
            if roots_overlap(left_root, right_root):
                reject(
                    "ROOT_ISOLATION_FAILURE",
                    {
                        "left": left_name,
                        "leftRoot": left_root.as_posix(),
                        "right": right_name,
                        "rightRoot": right_root.as_posix(),
                    },
                )
    return intervals


def computed_overlap(
    intervals: dict[str, tuple[dt.datetime, dt.datetime]]
) -> tuple[list[list[str]], int]:
    pairs: list[list[str]] = []
    process_intervals = {
        process_id: intervals[f"process-{process_id}"] for process_id in PROCESS_IDS
    }
    for index, left in enumerate(PROCESS_IDS):
        for right in PROCESS_IDS[index + 1 :]:
            left_start, left_end = process_intervals[left]
            right_start, right_end = process_intervals[right]
            if max(left_start, right_start) < min(left_end, right_end):
                pairs.append([left, right])

    events: list[tuple[dt.datetime, int]] = []
    for started, ended in process_intervals.values():
        events.append((started, 1))
        events.append((ended, -1))
    active = 0
    maximum = 0
    for _, delta in sorted(events, key=lambda value: (value[0], value[1])):
        active += delta
        maximum = max(maximum, active)
    return pairs, maximum


def validate_execution(
    payload: dict[str, Any],
    intervals: dict[str, tuple[dt.datetime, dt.datetime]],
) -> None:
    execution = payload["execution"]
    pairs, maximum = computed_overlap(intervals)
    if execution["overlapPairs"] != pairs:
        reject(
            "OVERLAP_PAIR_MISMATCH",
            {"declared": execution["overlapPairs"], "computed": pairs},
        )
    if execution["actualOverlap"] != bool(pairs):
        reject(
            "ACTUAL_OVERLAP_MISMATCH",
            {"declared": execution["actualOverlap"], "computed": bool(pairs)},
        )
    if execution["maximumObservedDirectionLocalConcurrency"] != maximum:
        reject(
            "DIRECTION_LOCAL_CONCURRENCY_MISMATCH",
            {
                "declared": execution["maximumObservedDirectionLocalConcurrency"],
                "computed": maximum,
            },
        )
    if maximum > execution["maximumConcurrentDccProcesses"]:
        reject(
            "DIRECTION_LOCAL_CAP_EXCEEDED",
            {
                "maximum": maximum,
                "cap": execution["maximumConcurrentDccProcesses"],
            },
        )
    if execution["mode"] == "sequential_exception":
        ordered = sorted(
            PROCESS_IDS, key=lambda process_id: intervals[f"process-{process_id}"][0]
        )
        if execution["queueOrder"] != ordered:
            reject(
                "SEQUENTIAL_QUEUE_ORDER_MISMATCH",
                {"declared": execution["queueOrder"], "computed": ordered},
            )


def validate_dag(
    payload: dict[str, Any],
    process_intervals: dict[str, tuple[dt.datetime, dt.datetime]],
) -> None:
    jobs = payload["jobs"]
    by_id: dict[str, dict[str, Any]] = {}
    for job in jobs:
        if job["jobId"] in by_id:
            reject("DUPLICATE_JOB_ID", job["jobId"])
        by_id[job["jobId"]] = job
    assemblers = [job for job in jobs if job["kind"] == "packet_assembly"]
    if len(assemblers) != 1 or assemblers[0]["jobId"] != payload["assembler"]["jobId"]:
        reject(
            "ASSEMBLER_COUNT_MISMATCH",
            {"count": len(assemblers), "declared": payload["assembler"]["jobId"]},
        )
    if set(by_id) != set(EXPECTED_JOBS):
        reject(
            "JOB_SET_MISMATCH",
            {
                "missing": sorted(set(EXPECTED_JOBS) - set(by_id)),
                "extra": sorted(set(by_id) - set(EXPECTED_JOBS)),
            },
        )

    intervals = dict(process_intervals)
    for job_id, job in by_id.items():
        expected_kind, expected_dependencies = EXPECTED_JOBS[job_id]
        if job["kind"] != expected_kind:
            reject(
                "JOB_KIND_MISMATCH",
                {"jobId": job_id, "expected": expected_kind, "actual": job["kind"]},
            )
        if tuple(job["dependsOn"]) != expected_dependencies:
            reject(
                "DEPENDENCY_SET_MISMATCH",
                {
                    "jobId": job_id,
                    "expected": expected_dependencies,
                    "actual": job["dependsOn"],
                },
            )
        intervals[job_id] = interval(job, f"jobs.{job_id}")

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node: str) -> None:
        if node in visited or node.startswith("process-"):
            return
        if node in visiting:
            reject("DEPENDENCY_CYCLE", node)
        visiting.add(node)
        for dependency in by_id[node]["dependsOn"]:
            if dependency not in intervals:
                reject("UNKNOWN_DEPENDENCY", {"jobId": node, "dependency": dependency})
            visit(dependency)
        visiting.remove(node)
        visited.add(node)

    for job_id in by_id:
        visit(job_id)

    for job_id, job in by_id.items():
        job_start, _ = intervals[job_id]
        for dependency in job["dependsOn"]:
            _, dependency_end = intervals[dependency]
            if dependency_end > job_start:
                reject(
                    "DEPENDENCY_BARRIER_VIOLATION",
                    {
                        "jobId": job_id,
                        "jobStartedAtUtc": job["startedAtUtc"],
                        "dependency": dependency,
                        "dependencyEndedAtUtc": (
                            payload["processes"][dependency[-1]]["endedAtUtc"]
                            if dependency.startswith("process-")
                            else by_id[dependency]["endedAtUtc"]
                        ),
                    },
                )

    join = payload["joins"]["identityJoin"]
    if parse_timestamp(join["completedAtUtc"], "joins.identityJoin.completedAtUtc") != intervals[
        "identity-join"
    ][1]:
        reject("JOIN_TIMESTAMP_MISMATCH", join["completedAtUtc"])
    if payload["assembler"]["identity"] != payload["frozenInputs"]["assemblerTool"]:
        reject("ASSEMBLER_IDENTITY_MISMATCH", payload["assembler"]["identity"])


def validate_global_schedule_boundary(payload: dict[str, Any]) -> None:
    schedule = payload["globalScheduleReceipt"]
    if schedule != {
        "owner": "Integration",
        "state": "pending_integration_authority",
        "path": None,
        "sha256": None,
        "authorityCommit": None,
        "globalCapProven": False,
    }:
        reject("GLOBAL_SCHEDULE_AUTHORITY_SUBSTITUTION", schedule)


def validate_payload(repo: Path, schema: Any, payload: Any) -> dict[str, Any]:
    schema_validate(schema, payload)
    validate_frozen_inputs(repo, payload)
    intervals = validate_roots_and_processes(repo, payload)
    validate_execution(payload, intervals)
    validate_dag(payload, intervals)
    validate_global_schedule_boundary(payload)
    return {
        "schema": "citysim.play-080.strict-parallel-receipt-fixture-validation.v1",
        "result": "PASS",
        "taskId": "PLAY-080",
        "direction": "south",
        "executionMode": payload["execution"]["mode"],
        "directionLocalReceiptValid": True,
        "globalScheduleAuthority": "PENDING_INTEGRATION",
        "globalCapProven": False,
        "productionReady": False,
        "zeroPixelFixture": True,
        "receiptCanonicalSha256": hashlib.sha256(canonical_bytes(payload)).hexdigest(),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--schema", required=True, type=Path)
    parser.add_argument("--receipt", required=True)
    args = parser.parse_args()
    try:
        repo = repository_root()
        schema = load_json_file(args.schema.resolve())
        payload = (
            load_json_bytes(sys.stdin.buffer.read(), "<stdin>")
            if args.receipt == "-"
            else load_json_file(Path(args.receipt).resolve())
        )
        result = validate_payload(repo, schema, payload)
        sys.stdout.buffer.write(canonical_bytes(result))
        return 0
    except ReceiptRejected as error:
        sys.stdout.buffer.write(
            canonical_bytes(
                {
                    "schema": "citysim.play-080.strict-parallel-receipt-fixture-validation.v1",
                    "result": "REJECTED",
                    "code": error.code,
                    "detail": error.detail,
                    "directionLocalReceiptValid": False,
                    "globalCapProven": False,
                    "productionReady": False,
                }
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
