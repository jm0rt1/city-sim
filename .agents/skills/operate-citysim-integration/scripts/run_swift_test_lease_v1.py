#!/usr/bin/env python3
"""Run one Swift-test command under an OS-visible, descendant-safe lease.

The lease is deliberately a small control-plane primitive.  A lock file may
survive a crash, but its advisory ``flock`` does not: a later holder can take
that stale file.  Only a live lock holder rejects a second invocation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import subprocess
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import fcntl


POLL_SECONDS = 0.02


def utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def lock_name(kind: str, value: str) -> str:
    return f"{kind}-{hashlib.sha256(value.encode('utf-8')).hexdigest()}.lock"


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.seek(0)
    path.truncate()
    path.write(json.dumps(value, sort_keys=True, indent=2) + "\n")
    path.flush()
    os.fsync(path.fileno())


def try_lock(path: Path) -> Any | None:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = path.open("a+", encoding="utf-8")
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()
        return None
    return handle


def process_rows() -> dict[int, tuple[int, int, str]]:
    """Return live pid -> (ppid, pgid, state), ignoring zombie processes."""
    completed = subprocess.run(
        ["ps", "-axo", "pid=,ppid=,pgid=,state="],
        capture_output=True, text=True, check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            "cannot inspect process ancestry: "
            + (completed.stderr.strip() or f"ps exit {completed.returncode}")
        )
    rows: dict[int, tuple[int, int, str]] = {}
    for line in completed.stdout.splitlines():
        fields = line.split()
        if len(fields) != 4:
            continue
        try:
            pid, ppid, pgid = (int(fields[0]), int(fields[1]), int(fields[2]))
        except ValueError:
            continue
        if "Z" not in fields[3]:
            rows[pid] = (ppid, pgid, fields[3])
    return rows


def descendants_of(root: int, rows: dict[int, tuple[int, int, str]]) -> set[int]:
    descendants: set[int] = set()
    frontier = {root}
    while frontier:
        parent = frontier.pop()
        children = {pid for pid, (ppid, _pgid, _state) in rows.items() if ppid == parent}
        children -= descendants
        descendants.update(children)
        frontier.update(children)
    return descendants


def observe_descendants(
    parent_pid: int,
    observed: dict[int, dict[str, int]],
    rows: dict[int, tuple[int, int, str]],
) -> None:
    """Retain descendant identities and follow descendants of known escapees."""
    roots = {parent_pid, *observed}
    discovered: set[int] = set()
    for root in roots:
        discovered.update(descendants_of(root, rows))
    for pid in discovered:
        ppid, pgid, _state = rows[pid]
        observed[pid] = {"pid": pid, "ppid": ppid, "pgid": pgid}


def hold_until_clear(
    parent_pid: int,
    pgid: int,
    observed: dict[int, dict[str, int]],
    update: Any,
) -> None:
    """Observe descendants while running, then retain locks through escapees."""
    while True:
        rows = process_rows()
        observe_descendants(parent_pid, observed, rows)
        group_live = {pid for pid, (_ppid, process_group, _state) in rows.items() if process_group == pgid}
        tracked_live = set(observed).intersection(rows)
        update(rows, group_live, tracked_live)
        if parent_pid not in rows and not group_live and not tracked_live:
            break
        time.sleep(POLL_SECONDS)


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lease-id", required=True)
    parser.add_argument("--build-root", required=True, type=Path)
    parser.add_argument("--lock-dir", required=True, type=Path)
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--metadata", required=True, type=Path)
    parser.add_argument("--produced-test-bundle-executable", type=Path)
    parser.add_argument("--cwd", type=Path)
    parser.add_argument(
        "--validator",
        type=Path,
        default=Path(__file__).with_name("validate_model_route_v1.py"),
    )
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if args.command[:1] == ["--"]:
        args.command = args.command[1:]
    if not args.command:
        parser.error("a command is required after --")
    for label, path in (("lock-dir", args.lock_dir), ("log", args.log), ("metadata", args.metadata)):
        if not path.is_absolute():
            parser.error(f"--{label} must be absolute")
    if args.log == args.metadata:
        parser.error("--log and --metadata must be distinct")
    if (
        args.produced_test_bundle_executable is not None
        and not args.produced_test_bundle_executable.is_absolute()
    ):
        parser.error("--produced-test-bundle-executable must be absolute")
    if args.log.exists() or args.metadata.exists():
        parser.error("--log and --metadata must be new paths for this attempt")
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    # Fail before acquiring a lease or launching a command if this host cannot
    # provide the process inventory required for descendant-safe completion.
    process_rows()
    lease_path = args.lock_dir / lock_name("lease", args.lease_id)
    root_key = str(args.build_root.resolve())
    root_path = args.lock_dir / lock_name("build-root", root_key)
    lease_lock = try_lock(lease_path)
    if lease_lock is None:
        print(f"LEASE_CONTENTION: live lease lock: {args.lease_id}", file=sys.stderr)
        return 2
    root_lock = try_lock(root_path)
    if root_lock is None:
        fcntl.flock(lease_lock.fileno(), fcntl.LOCK_UN)
        lease_lock.close()
        print(f"BUILD_ROOT_CONTENTION: live build-root lock: {root_key}", file=sys.stderr)
        return 3

    started = utc_now()
    state: dict[str, Any] = {
        "schema": 1,
        "leaseId": args.lease_id,
        "buildRoot": root_key,
        "lockDir": str(args.lock_dir.resolve()),
        "argv": args.command,
        "literalCommand": shlex.join(args.command),
        "utcStarted": started,
        "leasePid": os.getpid(),
        "leasePgid": os.getpgrp(),
        "rootLockPid": os.getpid(),
        "rootLockPgid": os.getpgrp(),
        "parentPid": None,
        "parentPgid": None,
        "observedDescendants": [],
        "status": "running",
        "terminal": False,
    }

    def persist(rows: dict[int, tuple[int, int, str]], group_live: set[int], tracked_live: set[int]) -> None:
        state["observedDescendants"] = [observed[pid] for pid in sorted(observed)]
        state["liveProcessGroupPids"] = sorted(group_live)
        state["liveObservedDescendantPids"] = sorted(tracked_live)
        for handle in (lease_lock, root_lock):
            write_json(handle, state)
        args.metadata.parent.mkdir(parents=True, exist_ok=True)
        args.metadata.write_text(json.dumps(state, sort_keys=True, indent=2) + "\n", encoding="utf-8")

    observed: dict[int, dict[str, int]] = {}
    args.log.parent.mkdir(parents=True, exist_ok=True)
    try:
        with args.log.open("wb") as log:
            process = subprocess.Popen(
                args.command,
                cwd=str(args.cwd) if args.cwd else None,
                stdout=log,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            state["parentPid"] = process.pid
            state["parentPgid"] = process.pid
            # Sample while the parent is alive. This preserves an observed
            # child that calls setsid and escapes its process group before the
            # parent exits.
            while process.poll() is None:
                rows = process_rows()
                observe_descendants(process.pid, observed, rows)
                group_live = {
                    pid for pid, (_ppid, process_group, _state) in rows.items()
                    if process_group == process.pid
                }
                persist(rows, group_live, set(observed).intersection(rows))
                time.sleep(POLL_SECONDS)
            exit_code = process.wait()
        hold_until_clear(process.pid, process.pid, observed, persist)
        log_sha = hashlib.sha256(args.log.read_bytes()).hexdigest()
        validator = subprocess.run(
            [sys.executable, str(args.validator), "--swift-test-log", str(args.log)],
            capture_output=True, text=True, check=False,
        )
        produced_error: str | None = None
        if args.produced_test_bundle_executable is not None:
            produced = args.produced_test_bundle_executable.resolve()
            if not produced.is_file():
                produced_error = f"produced XCTest executable does not exist: {produced}"
            elif not produced.stat().st_mode & 0o111:
                produced_error = f"produced XCTest executable is not executable: {produced}"
            else:
                state["producedTestBundleExecutable"] = {
                    "path": str(produced),
                    "sha256": hashlib.sha256(produced.read_bytes()).hexdigest(),
                }
        state.update({
            "utcEnded": utc_now(),
            "exitCode": exit_code,
            "logSha256": log_sha,
            "validatorArgv": [sys.executable, str(args.validator), "--swift-test-log", str(args.log)],
            "validatorExitCode": validator.returncode,
            "validatorStdout": validator.stdout,
            "validatorStderr": validator.stderr,
            "producedTestBundleError": produced_error,
            "parentExited": True,
            "processGroupExited": True,
            "descendantsExited": True,
            "terminal": True,
            "status": "terminal",
        })
        persist({}, set(), set())
    finally:
        fcntl.flock(root_lock.fileno(), fcntl.LOCK_UN)
        root_lock.close()
        fcntl.flock(lease_lock.fileno(), fcntl.LOCK_UN)
        lease_lock.close()

    if exit_code != 0:
        return exit_code if exit_code > 0 else 1
    if produced_error is not None:
        print(produced_error, file=sys.stderr)
        return 4
    return validator.returncode


if __name__ == "__main__":
    raise SystemExit(main())
