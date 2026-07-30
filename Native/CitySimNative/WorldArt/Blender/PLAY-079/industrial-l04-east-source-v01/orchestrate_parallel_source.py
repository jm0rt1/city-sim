#!/usr/bin/env python3
"""Fail-closed PLAY-079 East parallel-source orchestration boundary.

Production modes require exact future Integration artifacts and reject before
any subprocess or repository write while those authorities are absent. The
dry-structural mode validates only task-owned, explicitly nonproduction
fixtures and never imports or launches Blender.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import stat
import subprocess
import sys
from dataclasses import dataclass
from typing import Any, Iterable

import east_output_safety as output_safety


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
EVIDENCE_ROOT = (
    REPOSITORY_ROOT
    / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01"
)
FIXTURE_ROOT = SOURCE_ROOT / "fixtures/parallel-source"
RUNNER_CONTRACT_PATH = SOURCE_ROOT / "RUNNER-CONTRACT.json"
CLAIM_PATH = REPOSITORY_ROOT / "docs/production/claims/PLAY-079.world-art-east.md"
PROCESS_IDS = ("A", "B", "C")
EXPECTED_CLAIM_SHA256 = (
    "8b32a70a11b636a87ffecc70bbb1eace4c5313adc3077fdd0316c15151138483"
)
EXECUTION_CLOSURE_VERSION_ROOT = (
    SOURCE_ROOT / "schedule-consumer-adapter-v01"
)
EXECUTION_CLOSURE_CONTRACT_PATH = (
    EXECUTION_CLOSURE_VERSION_ROOT / "EXECUTION-CLOSURE-CONTRACT.json"
)
PARALLEL_DESIGN_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-PARALLEL-EXECUTION-CONTRACT-CANDIDATE.md"
)
PARALLEL_DESIGN_COMMIT = "aeaecb0bef4e7fe1e9670b1d57bd49b50b4eeab7"
PARALLEL_DESIGN_SHA256 = (
    "a2c726585fa83f9a795c02cb4e97fd476ae3969587db7c5e133ecc9889636e36"
)
INTEGRATION_PREFIX = pathlib.PurePosixPath("docs/production/evidence/INTEGRATION")
SHARED_PREFIX = pathlib.PurePosixPath("Native/CitySimNative/WorldArt/Shared")
EAST_EVIDENCE_PREFIX = pathlib.PurePosixPath(
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01"
)
PIXEL_EXTENSIONS = {
    ".bmp",
    ".exr",
    ".gif",
    ".jpeg",
    ".jpg",
    ".png",
    ".tif",
    ".tiff",
    ".webp",
}

PRODUCTION_ARGUMENTS = (
    "launch_handoff",
    "launch_handoff_commit",
    "launch_handoff_sha256",
    "cell_content_commit",
    "appearance_lock",
    "appearance_lock_commit",
    "appearance_lock_sha256",
    "material_mapping",
    "material_mapping_commit",
    "material_mapping_sha256",
    "source_production_profile",
    "source_profile_commit",
    "source_profile_sha256",
    "strict_receipt_schema",
    "strict_receipt_schema_commit",
    "strict_receipt_schema_sha256",
    "strict_receipt_validator",
    "strict_receipt_validator_commit",
    "strict_receipt_validator_sha256",
    "global_schedule_schema",
    "global_schedule_schema_commit",
    "global_schedule_schema_sha256",
    "global_schedule",
    "global_schedule_commit",
    "global_schedule_sha256",
    "launch_grant",
    "launch_grant_commit",
    "launch_grant_sha256",
    "claim_sha256",
)
OPTIONAL_AUTHORITY_ARGUMENTS = (
    "sequential_exception",
    "sequential_exception_commit",
    "sequential_exception_sha256",
)


class OrchestrationRejected(RuntimeError):
    """Stable fail-closed orchestration rejection."""

    def __init__(self, code: str, detail: Any, exit_code: int = 2):
        super().__init__(code)
        self.code = code
        self.detail = detail
        self.exit_code = exit_code


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: pathlib.Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise OrchestrationRejected(code, f"{path}: {error}") from error
    if not isinstance(value, dict):
        raise OrchestrationRejected(code, f"{path}: expected object")
    return value


def require_hex(value: Any, length: int, label: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) != length
        or any(character not in "0123456789abcdef" for character in value)
    ):
        raise OrchestrationRejected("invalid_authority_identity", f"{label}: {value}")
    return value


def strict_relative(path: pathlib.Path, label: str) -> tuple[str, pathlib.Path]:
    candidate = pathlib.Path(os.path.abspath(path))
    try:
        relative = candidate.relative_to(REPOSITORY_ROOT).as_posix()
    except ValueError as error:
        raise OrchestrationRejected("authority_path_outside_repository", f"{label}: {path}") from error
    expected = REPOSITORY_ROOT / pathlib.PurePosixPath(relative)
    if candidate != expected:
        raise OrchestrationRejected("authority_path_not_lexically_exact", f"{label}: {path}")
    pure = pathlib.PurePosixPath(relative)
    if (
        pure.is_absolute()
        or pure.as_posix() != relative
        or any(part in {"", ".", ".."} for part in pure.parts)
    ):
        raise OrchestrationRejected("unsafe_path_component", f"{label}: {relative}")
    return relative, candidate


def strict_authority_relative(path: str, label: str) -> tuple[str, pathlib.Path]:
    if (
        not isinstance(path, str)
        or not path
        or path.startswith("/")
        or "\\" in path
        or "\x00" in path
    ):
        raise OrchestrationRejected("authority_path_not_repo_relative", f"{label}: {path!r}")
    pure = pathlib.PurePosixPath(path)
    if (
        pure.as_posix() != path
        or any(part in {"", ".", ".."} for part in pure.parts)
    ):
        raise OrchestrationRejected("unsafe_authority_path_component", f"{label}: {path!r}")
    return path, REPOSITORY_ROOT / pure


def reject_symlink_components(relative: str, label: str) -> None:
    current = REPOSITORY_ROOT
    missing_seen = False
    for component in pathlib.PurePosixPath(relative).parts:
        current /= component
        try:
            status = os.lstat(current)
        except FileNotFoundError:
            missing_seen = True
            continue
        except OSError as error:
            raise OrchestrationRejected("path_component_unreadable", f"{label}: {error}") from error
        if missing_seen:
            raise OrchestrationRejected("component_after_missing_parent", f"{label}: {current}")
        if stat.S_ISLNK(status.st_mode):
            raise OrchestrationRejected("symlink_component", f"{label}: {current}")


def is_under(relative: str, prefix: pathlib.PurePosixPath) -> bool:
    pure = pathlib.PurePosixPath(relative)
    return pure != prefix and prefix in pure.parents


def git_output(arguments: list[str], code: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode:
        raise OrchestrationRejected(code, completed.stderr.strip() or "git command failed")
    return completed.stdout.strip()


def git_blob_identity(
    commit: str,
    relative: str,
    expected_sha256: str,
    label: str,
) -> dict[str, str]:
    commit = require_hex(commit, 40, f"{label}.commit")
    expected_sha256 = require_hex(expected_sha256, 64, f"{label}.sha256")
    pure = pathlib.PurePosixPath(relative)
    if (
        pure.is_absolute()
        or pure.as_posix() != relative
        or any(part in {"", ".", ".."} for part in pure.parts)
    ):
        raise OrchestrationRejected("unsafe_git_blob_path", f"{label}: {relative}")
    tree = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), "ls-tree", "-z", commit, "--", relative],
        check=False,
        capture_output=True,
    )
    entries = tree.stdout.split(b"\0")
    entry = entries[0] if len(entries) == 2 and entries[1] == b"" else b""
    metadata, separator, encoded_path = entry.partition(b"\t")
    fields = metadata.split()
    if (
        tree.returncode
        or separator != b"\t"
        or len(fields) != 3
        or fields[0] not in {b"100644", b"100755"}
        or fields[1] != b"blob"
        or encoded_path != relative.encode("utf-8")
    ):
        raise OrchestrationRejected(
            "authority_not_regular_git_blob",
            {
                "label": label,
                "commit": commit,
                "path": relative,
                "tree": tree.stdout.decode("utf-8", errors="replace"),
            },
        )
    committed = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), "show", f"{commit}:{relative}"],
        check=False,
        capture_output=True,
    )
    observed = sha256_bytes(committed.stdout) if committed.returncode == 0 else None
    if committed.returncode or observed != expected_sha256:
        raise OrchestrationRejected(
            "authority_commit_bytes_mismatch",
            {"label": label, "expected": expected_sha256, "observed": observed},
        )
    return {"path": relative, "commit": commit, "sha256": expected_sha256}


def validate_parallel_design_binding() -> dict[str, str]:
    return git_blob_identity(
        PARALLEL_DESIGN_COMMIT,
        PARALLEL_DESIGN_PATH,
        PARALLEL_DESIGN_SHA256,
        "parallelExecutionDesign",
    )


def capture_regular_file_no_follow(relative: str, label: str) -> bytes:
    pure = pathlib.PurePosixPath(relative)
    directory_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
    file_flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    directory_fd = os.open(REPOSITORY_ROOT, directory_flags)
    try:
        for component in pure.parts[:-1]:
            next_fd = os.open(component, directory_flags, dir_fd=directory_fd)
            os.close(directory_fd)
            directory_fd = next_fd
        file_fd = os.open(pure.name, file_flags, dir_fd=directory_fd)
        try:
            before = os.fstat(file_fd)
            if not stat.S_ISREG(before.st_mode):
                raise OrchestrationRejected("authority_not_regular_file", f"{label}: {relative}")
            chunks: list[bytes] = []
            while True:
                chunk = os.read(file_fd, 1024 * 1024)
                if not chunk:
                    break
                chunks.append(chunk)
            after = os.fstat(file_fd)
            post = os.stat(pure.name, dir_fd=directory_fd, follow_symlinks=False)
        finally:
            os.close(file_fd)
    except FileNotFoundError as error:
        raise OrchestrationRejected("missing_future_authority", f"{label}: {relative}") from error
    except (NotADirectoryError, OSError) as error:
        raise OrchestrationRejected("authority_capture_failed", f"{label}: {error}") from error
    finally:
        os.close(directory_fd)
    identity_fields = ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")
    before_identity = tuple(getattr(before, field) for field in identity_fields)
    if (
        before_identity != tuple(getattr(after, field) for field in identity_fields)
        or before_identity != tuple(getattr(post, field) for field in identity_fields)
        or not stat.S_ISREG(post.st_mode)
    ):
        raise OrchestrationRejected("authority_changed_during_capture", f"{label}: {relative}")
    captured = b"".join(chunks)
    if len(captured) != before.st_size:
        raise OrchestrationRejected("authority_capture_size_mismatch", f"{label}: {relative}")
    return captured


def validate_committed_artifact(
    path: str,
    commit: str,
    expected_sha256: str,
    label: str,
    *,
    allowed_prefixes: tuple[pathlib.PurePosixPath, ...],
    content_commit: str,
) -> dict[str, str]:
    commit = require_hex(commit, 40, f"{label}.commit")
    expected_sha256 = require_hex(expected_sha256, 64, f"{label}.sha256")
    content_commit = require_hex(content_commit, 40, "cellContentCommit")
    relative, _absolute = strict_authority_relative(path, label)
    if not any(is_under(relative, prefix) for prefix in allowed_prefixes):
        raise OrchestrationRejected("authority_path_outside_governed_root", f"{label}: {relative}")
    reject_symlink_components(relative, label)
    captured = capture_regular_file_no_follow(relative, label)
    observed = sha256_bytes(captured)
    if observed != expected_sha256:
        raise OrchestrationRejected(
            "authority_sha256_mismatch",
            {"label": label, "expected": expected_sha256, "observed": observed},
        )
    ancestor = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), "merge-base", "--is-ancestor", commit, content_commit],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if ancestor.returncode:
        raise OrchestrationRejected(
            "authority_commit_not_in_content_ancestry",
            {"label": label, "authorityCommit": commit, "contentCommit": content_commit},
        )
    return git_blob_identity(commit, relative, expected_sha256, label)


def validate_optional_authority_presence(args: argparse.Namespace) -> bool:
    present = [
        getattr(args, name, None) not in {None, ""}
        for name in OPTIONAL_AUTHORITY_ARGUMENTS
    ]
    if any(present) and not all(present):
        raise OrchestrationRejected(
            "incomplete_sequential_exception_authority",
            {
                name: getattr(args, name, None)
                for name in OPTIONAL_AUTHORITY_ARGUMENTS
            },
        )
    return all(present)


def expected_roots() -> dict[str, dict[str, str]]:
    base = "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
    return {
        process_id: {
            "outputRoot": f"{base}renders/process-{process_id.lower()}/",
            "evidenceRoot": f"{base}execution/process-{process_id.lower()}/",
            "invocationReceipt": (
                f"{base}execution/process-{process_id.lower()}/INVOCATION-RECEIPT.json"
            ),
        }
        for process_id in PROCESS_IDS
    }


def roots_overlap(left: str, right: str) -> bool:
    left_path = pathlib.PurePosixPath(left.rstrip("/"))
    right_path = pathlib.PurePosixPath(right.rstrip("/"))
    return (
        left_path == right_path
        or left_path in right_path.parents
        or right_path in left_path.parents
    )


def validate_disjoint_roots(processes: dict[str, Any]) -> None:
    observed: list[tuple[str, str]] = []
    expected = expected_roots()
    if tuple(sorted(processes)) != PROCESS_IDS:
        raise OrchestrationRejected("process_set_mismatch", sorted(processes), 3)
    for process_id in PROCESS_IDS:
        process = processes[process_id]
        for field in ("outputRoot", "evidenceRoot"):
            value = process.get(field)
            if value != expected[process_id][field]:
                raise OrchestrationRejected(
                    "process_root_mismatch",
                    {"processId": process_id, "field": field, "value": value},
                    3,
                )
            pure = pathlib.PurePosixPath(str(value).rstrip("/"))
            if (
                pure.is_absolute()
                or any(part in {"", ".", ".."} for part in pure.parts)
                or not is_under(pure.as_posix(), pathlib.PurePosixPath(output_safety.EVIDENCE_PREFIX.rstrip("/")))
            ):
                raise OrchestrationRejected("unsafe_process_root", str(value), 3)
            observed.append((f"{process_id}.{field}", str(value)))
    for index, (left_name, left) in enumerate(observed):
        for right_name, right in observed[index + 1 :]:
            if roots_overlap(left, right):
                raise OrchestrationRejected(
                    "process_root_overlap",
                    {"left": left_name, "leftRoot": left, "right": right_name, "rightRoot": right},
                    3,
                )


def parse_utc(value: str, label: str) -> dt.datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise OrchestrationRejected("timestamp_not_utc_z", f"{label}: {value}", 5)
    try:
        parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as error:
        raise OrchestrationRejected("invalid_timestamp", f"{label}: {value}", 5) from error
    if parsed.utcoffset() != dt.timedelta(0):
        raise OrchestrationRejected("timestamp_not_utc_z", f"{label}: {value}", 5)
    return parsed


@dataclass(frozen=True)
class Interval:
    process_id: str
    started_utc: dt.datetime
    ended_utc: dt.datetime
    started_ns: int
    ended_ns: int


def validate_process_receipt(process_id: str, value: dict[str, Any]) -> Interval:
    expected = expected_roots()[process_id]
    exact = {
        "taskId": "PLAY-079",
        "branch": "codex/citysim-world-art-east",
        "direction": "east",
        "processId": process_id,
        "outputRoot": expected["outputRoot"],
        "evidenceRoot": expected["evidenceRoot"],
        "invocationCount": 1,
    }
    for field, expected_value in exact.items():
        if value.get(field) != expected_value:
            raise OrchestrationRejected(
                "invocation_receipt_identity_mismatch",
                {"processId": process_id, "field": field, "value": value.get(field)},
                5,
            )
    allocation_echo = value.get("allocationEcho")
    expected_allocation_echo = {
        "allocationId": f"synthetic-nonproduction-east-{process_id.lower()}",
        "attemptId": f"synthetic-nonproduction-east-{process_id.lower()}-attempt-1",
        "preassignedSlot": "synthetic_nonproduction_unassigned",
        "plannedLease": {"start": None, "end": None},
        "schedulerEventIds": [],
    }
    if allocation_echo != expected_allocation_echo:
        raise OrchestrationRejected(
            "allocation_echo_shape_mismatch",
            {"processId": process_id, "value": allocation_echo},
            5,
        )
    started_utc = parse_utc(value.get("startedAtUtc"), f"{process_id}.startedAtUtc")
    ended_utc = parse_utc(value.get("endedAtUtc"), f"{process_id}.endedAtUtc")
    started_ns = value.get("startedMonotonicNs")
    ended_ns = value.get("endedMonotonicNs")
    if (
        not isinstance(started_ns, int)
        or isinstance(started_ns, bool)
        or not isinstance(ended_ns, int)
        or isinstance(ended_ns, bool)
        or started_ns < 0
        or started_ns >= ended_ns
    ):
        raise OrchestrationRejected("invalid_monotonic_interval", process_id, 5)
    if started_utc >= ended_utc:
        raise OrchestrationRejected("invalid_utc_interval", process_id, 5)
    if value.get("result") != "PASS":
        raise OrchestrationRejected("process_result_not_pass", process_id, 5)
    return Interval(process_id, started_utc, ended_utc, started_ns, ended_ns)


def compute_execution(intervals: dict[str, Interval]) -> dict[str, Any]:
    overlap_pairs: list[list[str]] = []
    for index, left_id in enumerate(PROCESS_IDS):
        left = intervals[left_id]
        for right_id in PROCESS_IDS[index + 1 :]:
            right = intervals[right_id]
            if max(left.started_ns, right.started_ns) < min(left.ended_ns, right.ended_ns):
                overlap_pairs.append([left_id, right_id])
    events: list[tuple[int, int]] = []
    for interval in intervals.values():
        events.append((interval.started_ns, 1))
        events.append((interval.ended_ns, -1))
    active = 0
    maximum = 0
    for _moment, delta in sorted(events, key=lambda event: (event[0], event[1])):
        active += delta
        maximum = max(maximum, active)
    queue_order = [
        interval.process_id
        for interval in sorted(intervals.values(), key=lambda interval: interval.started_ns)
    ]
    return {
        "actualOverlap": bool(overlap_pairs),
        "overlapPairs": overlap_pairs,
        "localMaximumActiveIntervals": maximum,
        "localStartOrder": queue_order,
    }


class InvocationTracker:
    """Exactly-once state machine used by the future production launcher."""

    _TRANSITIONS = {
        "QUEUED": "SPAWNED",
        "SPAWNED": "STARTED",
        "STARTED": "SETTLED",
        "SETTLED": "RECEIPT_WRITTEN",
    }

    def __init__(self) -> None:
        self.states = {process_id: "QUEUED" for process_id in PROCESS_IDS}
        self.spawn_counts = {process_id: 0 for process_id in PROCESS_IDS}

    def transition(self, process_id: str, target: str) -> None:
        if process_id not in self.states:
            raise OrchestrationRejected("unknown_process_id", process_id, 5)
        current = self.states[process_id]
        expected = self._TRANSITIONS.get(current)
        if target != expected:
            raise OrchestrationRejected(
                "exactly_once_transition_rejected",
                {"processId": process_id, "current": current, "target": target},
                5,
            )
        if target == "SPAWNED":
            self.spawn_counts[process_id] += 1
            if self.spawn_counts[process_id] != 1:
                raise OrchestrationRejected("duplicate_process_invocation", process_id, 5)
        self.states[process_id] = target


def validate_dry_fixture(path: pathlib.Path) -> dict[str, Any]:
    relative, absolute = strict_relative(path, "fixture")
    fixture_relative, _fixture_root = strict_relative(FIXTURE_ROOT, "fixtureRoot")
    if not is_under(relative, pathlib.PurePosixPath(fixture_relative)):
        raise OrchestrationRejected("fixture_outside_task_root", relative)
    reject_symlink_components(relative, "fixture")
    fixture = load_json(absolute, "invalid_dry_fixture")
    if fixture.get("schema") != "citysim.play-079.parallel-source-dry-fixture.v1":
        raise OrchestrationRejected("dry_fixture_schema_mismatch", fixture.get("schema"))
    if fixture.get("nonProductionFixture") is not True:
        raise OrchestrationRejected("dry_fixture_disposition_invalid", fixture.get("nonProductionFixture"))
    if fixture.get("identity") != {
        "taskId": "PLAY-079",
        "branch": "codex/citysim-world-art-east",
        "direction": "east",
    }:
        raise OrchestrationRejected("dry_fixture_identity_mismatch", fixture.get("identity"))
    if fixture.get("designBinding") != {
        "status": "DESIGN_FROZEN_IMPLEMENTATION_AND_INDEPENDENT_AUDIT_REQUIRED",
        **validate_parallel_design_binding(),
        "productionAuthority": False,
    }:
        raise OrchestrationRejected("parallel_design_binding_mismatch", fixture.get("designBinding"))
    authorities = fixture.get("authorities")
    if not isinstance(authorities, dict) or set(authorities) != {
        "appearanceLock",
        "materialMapping",
        "sourceProductionProfile",
        "strictReceiptSchema",
        "strictReceiptValidator",
        "globalScheduleSchema",
        "globalSchedule",
        "sequentialException",
        "launchGrant",
    }:
        raise OrchestrationRejected("dry_fixture_authority_set_mismatch", authorities)
    for name, record in authorities.items():
        if record != {
            "state": "synthetic_nonproduction_absent",
            "path": None,
            "commit": None,
            "sha256": None,
        }:
            raise OrchestrationRejected("dry_fixture_invented_authority", {name: record})
    processes = fixture.get("processes")
    if not isinstance(processes, dict):
        raise OrchestrationRejected("dry_fixture_processes_invalid", processes)
    validate_disjoint_roots(processes)
    intervals = {
        process_id: validate_process_receipt(process_id, processes[process_id])
        for process_id in PROCESS_IDS
    }
    computed = compute_execution(intervals)
    execution = fixture.get("execution")
    if not isinstance(execution, dict):
        raise OrchestrationRejected("dry_fixture_execution_invalid", execution, 5)
    expected_execution_keys = {
        "disposition",
        "localOverlapPairs",
        "localMaximumActiveIntervals",
        "localStartOrder",
        "globalCapClaim",
        "globalParallelGateClaim",
        "scheduleModeClaim",
        "sequentialExceptionClaim",
        "integrationMustRecompute",
    }
    if set(execution) != expected_execution_keys:
        raise OrchestrationRejected("execution_shape_mismatch", sorted(execution), 5)
    for field, computed_field in (
        ("localOverlapPairs", "overlapPairs"),
        ("localMaximumActiveIntervals", "localMaximumActiveIntervals"),
        ("localStartOrder", "localStartOrder"),
    ):
        if execution.get(field) != computed[computed_field]:
            raise OrchestrationRejected(
                "execution_claim_mismatch",
                {
                    "field": field,
                    "declared": execution.get(field),
                    "computed": computed[computed_field],
                },
                5,
            )
    if any(
        execution.get(field) is not None
        for field in (
            "globalCapClaim",
            "globalParallelGateClaim",
            "scheduleModeClaim",
            "sequentialExceptionClaim",
        )
    ):
        raise OrchestrationRejected("forbidden_global_execution_claim", execution, 5)
    expected_disposition = (
        "synthetic_local_overlap_evidence_only"
        if computed["overlapPairs"]
        else "synthetic_no_overlap_nonready"
    )
    if (
        fixture.get("fixtureDisposition") != expected_disposition
        or execution.get("disposition") != expected_disposition
        or execution.get("integrationMustRecompute") is not True
    ):
        raise OrchestrationRejected("execution_disposition_mismatch", execution, 5)
    safety = fixture.get("safety")
    expected_safety = {
        "subprocessInvocations": 0,
        "dccInvocations": 0,
        "blenderProcessInvocations": 0,
        "renderApiCalls": 0,
        "pixelFiles": 0,
        "repositoryWrites": 0,
    }
    if safety != expected_safety:
        raise OrchestrationRejected("dry_fixture_safety_mismatch", safety)
    return {
        "schema": "citysim.play-079.parallel-source-dry-validation.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "result": "PASS",
        "fixture": relative,
        "fixtureSha256": sha256_file(absolute),
        "execution": computed,
        "globalExecutionClaims": "NOT_MADE_INTEGRATION_MUST_RECOMPUTE",
        "designBinding": validate_parallel_design_binding(),
        "futureAuthorities": "REQUIRED_AND_ABSENT",
        "subprocessInvocations": 0,
        "dccInvocations": 0,
        "blenderProcessInvocations": 0,
        "renderApiCalls": 0,
        "pixelFiles": 0,
        "repositoryWrites": 0,
        "sourceReady": False,
        "productionSelected": False,
    }


def pixel_inventory() -> list[str]:
    return sorted(
        str(path.relative_to(REPOSITORY_ROOT))
        for root in (SOURCE_ROOT, EVIDENCE_ROOT)
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_EXTENSIONS
    )


def missing_production_arguments(args: argparse.Namespace) -> list[str]:
    return [name for name in PRODUCTION_ARGUMENTS if getattr(args, name, None) in {None, ""}]


def validate_production_config(args: argparse.Namespace) -> dict[str, Any]:
    missing = missing_production_arguments(args)
    if missing:
        raise OrchestrationRejected("missing_future_integration_authorities", missing)
    has_sequential_exception = validate_optional_authority_presence(args)
    branch = git_output(["branch", "--show-current"], "branch_identity_unavailable")
    if branch != "codex/citysim-world-art-east":
        raise OrchestrationRejected("branch_identity_mismatch", branch)
    status = git_output(["status", "--porcelain=v1"], "worktree_status_unavailable")
    if status:
        raise OrchestrationRejected("worktree_not_clean_before_launch", status.splitlines())
    head = git_output(["rev-parse", "HEAD"], "head_identity_unavailable")
    require_hex(args.cell_content_commit, 40, "cellContentCommit")
    if head != args.cell_content_commit:
        raise OrchestrationRejected(
            "cell_content_commit_mismatch",
            {"head": head, "supplied": args.cell_content_commit},
        )
    design = validate_parallel_design_binding()
    design_ancestor = subprocess.run(
        [
            "git",
            "-C",
            str(REPOSITORY_ROOT),
            "merge-base",
            "--is-ancestor",
            design["commit"],
            head,
        ],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if design_ancestor.returncode:
        raise OrchestrationRejected(
            "parallel_design_not_in_cell_content_ancestry",
            {"designCommit": design["commit"], "cellContentCommit": head},
        )
    claim_sha = require_hex(args.claim_sha256, 64, "claimSha256")
    observed_claim_sha = sha256_file(CLAIM_PATH)
    if claim_sha != observed_claim_sha:
        raise OrchestrationRejected(
            "claim_sha256_mismatch",
            {"expected": claim_sha, "observed": observed_claim_sha},
        )
    if claim_sha == EXPECTED_CLAIM_SHA256:
        raise OrchestrationRejected(
            "prelock_claim_does_not_authorize_production",
            claim_sha,
        )
    launch_relative, _launch_path = strict_authority_relative(
        args.launch_handoff,
        "launchHandoff",
    )
    expected_handoff = (
        "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
        "SOURCE-STAGE-HANDOFF.json"
    )
    if launch_relative != expected_handoff:
        raise OrchestrationRejected("launch_handoff_path_mismatch", launch_relative)

    authority = {
        "launchHandoff": validate_committed_artifact(
            args.launch_handoff,
            args.launch_handoff_commit,
            args.launch_handoff_sha256,
            "launchHandoff",
            allowed_prefixes=(EAST_EVIDENCE_PREFIX,),
            content_commit=head,
        ),
        "appearanceLock": validate_committed_artifact(
            args.appearance_lock,
            args.appearance_lock_commit,
            args.appearance_lock_sha256,
            "appearanceLock",
            allowed_prefixes=(INTEGRATION_PREFIX,),
            content_commit=head,
        ),
        "materialMapping": validate_committed_artifact(
            args.material_mapping,
            args.material_mapping_commit,
            args.material_mapping_sha256,
            "materialMapping",
            allowed_prefixes=(INTEGRATION_PREFIX,),
            content_commit=head,
        ),
        "sourceProductionProfile": validate_committed_artifact(
            args.source_production_profile,
            args.source_profile_commit,
            args.source_profile_sha256,
            "sourceProductionProfile",
            allowed_prefixes=(INTEGRATION_PREFIX,),
            content_commit=head,
        ),
        "strictReceiptSchema": validate_committed_artifact(
            args.strict_receipt_schema,
            args.strict_receipt_schema_commit,
            args.strict_receipt_schema_sha256,
            "strictReceiptSchema",
            allowed_prefixes=(INTEGRATION_PREFIX,),
            content_commit=head,
        ),
        "strictReceiptValidator": validate_committed_artifact(
            args.strict_receipt_validator,
            args.strict_receipt_validator_commit,
            args.strict_receipt_validator_sha256,
            "strictReceiptValidator",
            allowed_prefixes=(INTEGRATION_PREFIX, SHARED_PREFIX),
            content_commit=head,
        ),
        "globalScheduleSchema": validate_committed_artifact(
            args.global_schedule_schema,
            args.global_schedule_schema_commit,
            args.global_schedule_schema_sha256,
            "globalScheduleSchema",
            allowed_prefixes=(INTEGRATION_PREFIX,),
            content_commit=head,
        ),
        "globalSchedule": validate_committed_artifact(
            args.global_schedule,
            args.global_schedule_commit,
            args.global_schedule_sha256,
            "globalSchedule",
            allowed_prefixes=(INTEGRATION_PREFIX,),
            content_commit=head,
        ),
        "launchGrant": validate_committed_artifact(
            args.launch_grant,
            args.launch_grant_commit,
            args.launch_grant_sha256,
            "launchGrant",
            allowed_prefixes=(INTEGRATION_PREFIX,),
            content_commit=head,
        ),
    }
    authority["sequentialException"] = (
        validate_committed_artifact(
            args.sequential_exception,
            args.sequential_exception_commit,
            args.sequential_exception_sha256,
            "sequentialException",
            allowed_prefixes=(INTEGRATION_PREFIX,),
            content_commit=head,
        )
        if has_sequential_exception
        else None
    )
    raise OrchestrationRejected(
        "future_integration_validator_interface_not_published",
        {
            "parallelExecutionDesign": design,
            "validatedArtifactIdentities": authority,
            "detail": (
                "The East cell will not invent the production strict-receipt or "
                "global-schedule semantic-validator interface."
            ),
        },
    )


def write_invocation_receipt(path: pathlib.Path, payload: dict[str, Any]) -> str:
    """Future production writer; callers must validate payload before calling."""

    return output_safety.write_bytes_exclusive(
        path,
        canonical_bytes(payload),
        "receipt",
    )


def validate_execution_closure(
    args: argparse.Namespace,
    *,
    repository_root: pathlib.Path = REPOSITORY_ROOT,
    contract: dict[str, Any] | None = None,
    shared_validator: Any | None = None,
    fixture_contract: dict[str, Any] | None = None,
) -> dict[str, Any]:
    required = (
        "execution_authority",
        "trusted_head",
        "worker_head",
        "authority_publication_commit",
        "secret_fd",
    )
    missing = [name for name in required if getattr(args, name, None) is None]
    if missing:
        raise OrchestrationRejected("missing_execution_closure_inputs", missing)
    if str(EXECUTION_CLOSURE_VERSION_ROOT) not in sys.path:
        sys.path.insert(0, str(EXECUTION_CLOSURE_VERSION_ROOT))
    import validate_execution_closure_v1 as closure  # type: ignore
    import run_production as runner

    try:
        authenticated = closure.authenticate(
            repository_root=repository_root,
            authority_path=pathlib.Path(args.execution_authority),
            trusted_head=args.trusted_head,
            worker_head=args.worker_head,
            authority_publication_commit=args.authority_publication_commit,
            secret_fd=args.secret_fd,
            contract=contract,
            shared_validator=shared_validator,
        )
        result = runner.validate_execution_closure_boundary(
            authenticated,
            fixture_contract=fixture_contract,
        )
        durable_attempt = authenticated.durable_attempt_result()
    except closure.ClosureRejected as error:
        raise OrchestrationRejected(error.code, error.detail) from error
    except runner.GuardRejected as error:
        raise OrchestrationRejected(error.code, error.detail) from error
    return {
        "schema": "citysim.play-079.east-execution-closure-validation.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "result": "PASS",
        "authority": {
            "path": pathlib.Path(args.execution_authority).as_posix(),
            "publicationCommit": args.authority_publication_commit,
            "trustedHead": args.trusted_head,
            "workerHead": args.worker_head,
        },
        "runnerBoundary": result,
        "durableAttempt": durable_attempt,
        "sourceReady": False,
        "productionSelected": False,
        "liveLeaseCreated": False,
        "sourceChildStarts": 0,
        "dccInvocations": 0,
        "blenderProcessInvocations": 0,
        "renderApiCalls": 0,
        "pixelFilesCreated": 0,
        "repositoryWrites": 1,
    }


def add_production_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--launch-handoff")
    parser.add_argument("--launch-handoff-commit")
    parser.add_argument("--launch-handoff-sha256")
    parser.add_argument("--cell-content-commit")
    parser.add_argument("--appearance-lock")
    parser.add_argument("--appearance-lock-commit")
    parser.add_argument("--appearance-lock-sha256")
    parser.add_argument("--material-mapping")
    parser.add_argument("--material-mapping-commit")
    parser.add_argument("--material-mapping-sha256")
    parser.add_argument("--source-production-profile")
    parser.add_argument("--source-profile-commit")
    parser.add_argument("--source-profile-sha256")
    parser.add_argument("--strict-receipt-schema")
    parser.add_argument("--strict-receipt-schema-commit")
    parser.add_argument("--strict-receipt-schema-sha256")
    parser.add_argument("--strict-receipt-validator")
    parser.add_argument("--strict-receipt-validator-commit")
    parser.add_argument("--strict-receipt-validator-sha256")
    parser.add_argument("--global-schedule-schema")
    parser.add_argument("--global-schedule-schema-commit")
    parser.add_argument("--global-schedule-schema-sha256")
    parser.add_argument("--global-schedule")
    parser.add_argument("--global-schedule-commit")
    parser.add_argument("--global-schedule-sha256")
    parser.add_argument("--sequential-exception")
    parser.add_argument("--sequential-exception-commit")
    parser.add_argument("--sequential-exception-sha256")
    parser.add_argument("--launch-grant")
    parser.add_argument("--launch-grant-commit")
    parser.add_argument("--launch-grant-sha256")
    parser.add_argument("--claim-sha256")


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    dry = subparsers.add_parser("dry-structural")
    dry.add_argument("--fixture", type=pathlib.Path, required=True)
    closure = subparsers.add_parser("validate-closure")
    closure.add_argument("--execution-authority")
    closure.add_argument("--trusted-head")
    closure.add_argument("--worker-head")
    closure.add_argument("--authority-publication-commit")
    closure.add_argument("--secret-fd", type=int)
    for command in ("preflight", "launch", "finalize"):
        child = subparsers.add_parser(command)
        add_production_arguments(child)
        if command == "finalize":
            child.add_argument("--job-receipt-manifest", type=pathlib.Path)
    return parser.parse_args(list(argv))


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_arguments(sys.argv[1:] if argv is None else argv)
    pixels_before = pixel_inventory()
    try:
        if args.command == "dry-structural":
            result = validate_dry_fixture(args.fixture)
        elif args.command == "validate-closure":
            result = validate_execution_closure(args)
        else:
            result = validate_production_config(args)
            raise AssertionError(f"unexpected production validation result: {result}")
        pixels_after = pixel_inventory()
        if pixels_after != pixels_before:
            raise OrchestrationRejected(
                "zero_pixel_boundary_changed",
                {"before": pixels_before, "after": pixels_after},
            )
        sys.stdout.buffer.write(canonical_bytes(result))
        return 0
    except OrchestrationRejected as error:
        result = {
            "schema": "citysim.play-079.parallel-source-orchestrator-rejection.v1",
            "taskId": "PLAY-079",
            "direction": "east",
            "result": "REJECTED",
            "command": args.command,
            "stage": "before_dcc_or_repository_write",
            "code": error.code,
            "detail": error.detail,
            "subprocessInvocations": 0,
            "sourceChildStarts": 0,
            "dccInvocations": 0,
            "blenderProcessInvocations": 0,
            "renderApiCalls": 0,
            "pixelFilesCreated": 0,
            "repositoryWrites": 0,
            "sourceReady": False,
            "productionSelected": False,
        }
        sys.stdout.buffer.write(canonical_bytes(result))
        return error.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
