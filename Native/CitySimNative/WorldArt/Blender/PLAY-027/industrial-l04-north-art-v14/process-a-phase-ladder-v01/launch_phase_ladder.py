#!/usr/bin/env python3
"""Externally gated North v14 diagnostic launcher; dormant without Integration documents."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Callable

ROOT_REL = Path("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14/process-a-phase-ladder-v01")
CONTRACT_PATH = ROOT_REL / "DIAGNOSTIC-CONTRACT.json"
CHILD_PATH = ROOT_REL / "phase_ladder_child.py"
CHILD_START_COUNT = 0


class AuthorityError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuthorityError(message)


def canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode()


def canonical_hash(value: Any) -> str:
    return sha256_bytes(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode())


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def load_object(path: Path) -> dict[str, Any]:
    require(path.is_file() and not path.is_symlink(), f"regular JSON required: {path}")
    value = json.loads(path.read_bytes())
    require(type(value) is dict, f"JSON object required: {path}")
    return value


def _git(root: Path, *args: str) -> str:
    allowed = {"rev-parse", "symbolic-ref", "merge-base", "cat-file", "show", "diff", "ls-files", "log"}
    require(args and args[0] in allowed, "git helper forbidden")
    result = subprocess.run(["git", "-C", str(root), *args], check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(result.returncode == 0, f"git {' '.join(args)} failed")
    return result.stdout.decode().strip()


def repository_identity(root: Path, contract: dict[str, Any]) -> dict[str, str]:
    root = root.resolve(strict=True)
    require(not root.is_symlink(), "repository root symlink forbidden")
    require(str(root) == contract["assignment"]["worktree"], "assigned worktree mismatch")
    branch = _git(root, "symbolic-ref", "--short", "HEAD")
    head = _git(root, "rev-parse", "HEAD")
    require(branch == contract["assignment"]["branch"], "assigned branch mismatch")
    require(_git(root, "merge-base", "--is-ancestor", contract["executionBaseHead"], head) == "", "execution base not ancestor")
    changed = set(filter(None, _git(root, "diff", "--name-only", "HEAD", "--").splitlines()))
    untracked = set(filter(None, _git(root, "ls-files", "--others", "--exclude-standard").splitlines()))
    allowed_prefixes = (ROOT_REL.as_posix() + "/", "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v14/process-a-phase-ladder-r1/")
    require(all(path.startswith(allowed_prefixes) for path in changed | untracked), "worktree dirt outside task-owned roots")
    return {"branch": branch, "head": head, "root": str(root)}


def verify_file(root: Path, binding: dict[str, Any]) -> None:
    path = root / binding["path"]
    require(path.is_file() and not path.is_symlink(), f"immutable input missing: {binding['path']}")
    require(sha256(path) == binding["sha256"], f"immutable input hash drift: {binding['path']}")


def validate_static(root: Path, *, require_output_absent: bool = True) -> tuple[dict[str, Any], dict[str, str]]:
    contract = load_object(root / CONTRACT_PATH)
    identity = repository_identity(root, contract)
    route = contract["route"]
    require(_git(root, "cat-file", "-t", route["carrierCommit"]) == "commit", "route carrier missing")
    require(_git(root, "merge-base", "--is-ancestor", route["authorityCommit"], route["carrierCommit"]) == "", "route authority not carried")
    receipt_bytes = subprocess.run(["git", "-C", str(root), "show", f"{route['carrierCommit']}:{route['receiptPath']}"], check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(receipt_bytes.returncode == 0 and sha256_bytes(receipt_bytes.stdout) == route["receiptSHA256"], "route receipt bytes drift")
    receipt = json.loads(receipt_bytes.stdout)
    assignments = [item for item in receipt.get("assignments", []) if item.get("modelRoute", {}).get("routeId") == route["routeId"]]
    require(len(assignments) == 1 and assignments[0].get("modelRouteSha256") == route["modelRouteSHA256"], "selected model route missing")
    require(canonical_hash(assignments[0]["modelRoute"]) == route["modelRouteSHA256"], "selected model route canonical hash drift")
    require(sha256(root / route["claim"]["path"]) == route["claim"]["sha256"], "claim hash drift")
    for binding in contract["immutableInputs"].values():
        verify_file(root, binding)
    output = root / contract["futureStageB"]["outputRoot"]
    if require_output_absent:
        require(not output.exists() and not output.is_symlink(), "governed output root must be absent")
    return contract, identity


def _published_bytes(root: Path, path: Path, publication_commit: str, publication_ref: str) -> bytes:
    require(not path.is_absolute() and ".." not in path.parts, "published path must be repository-relative")
    require(path.parts[:4] == ("docs", "production", "evidence", "INTEGRATION"), "Integration path required")
    require(_git(root, "cat-file", "-t", publication_commit) == "commit", "publication commit missing")
    require(_git(root, "merge-base", "--is-ancestor", publication_commit, publication_ref) == "", "publication not trusted by Integration ref")
    result = subprocess.run(["git", "-C", str(root), "show", f"{publication_commit}:{path.as_posix()}"], check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(result.returncode == 0, f"published blob missing: {path}")
    return result.stdout


def _publication_commit(root: Path, path: Path, publication_ref: str) -> str:
    commit = _git(root, "log", "-1", "--format=%H", publication_ref, "--", path.as_posix())
    require(len(commit) == 40, f"published commit missing for {path}")
    return commit


def validate_direct_documents(root: Path, contract: dict[str, Any], identity: dict[str, str], paths: dict[str, Path], *, expected_attempt_state: str | None = None) -> dict[str, Any]:
    require(set(paths) == set(contract["externalAuthority"]["requiredDocuments"]), "authority document set drift")
    loaded: dict[str, dict[str, Any]] = {}
    hashes: dict[str, str] = {}
    for name, path in paths.items():
        resolved = path.resolve(strict=True)
        require(not path.is_symlink() and resolved == path.absolute(), f"{name} lexical/symlink alias forbidden")
        document = load_object(path)
        require(document.get("kind") == f"industrial-l04-north-v14-phase-{name}-v1", f"{name} kind drift")
        publication = document.get("publication")
        require(type(publication) is dict and set(publication) == {"path"} and type(publication.get("path")) is str, f"{name} publication binding invalid")
        relative = Path(publication["path"])
        publication_commit = _publication_commit(root, relative, contract["externalAuthority"]["publicationRef"])
        require(_published_bytes(root, relative, publication_commit, contract["externalAuthority"]["publicationRef"]) == path.read_bytes(), f"{name} published bytes mismatch")
        document["_verifiedPublicationCommit"] = publication_commit
        loaded[name] = document
        hashes[name] = sha256(path)

    schedule, grant, session, approval = (loaded[n] for n in ("schedule", "grant", "session", "staticApproval"))
    expected_common = {
        "task": "PLAY-027", "direction": "north", "workerHead": identity["head"],
        "routeId": contract["route"]["routeId"], "outputRoot": contract["futureStageB"]["outputRoot"],
    }
    for name, document in loaded.items():
        for key, value in expected_common.items():
            require(type(document.get(key)) is type(value) and document.get(key) == value, f"{name} {key} drift")
        require(type(document.get("sourceAuthority")) is bool and document.get("sourceAuthority") is False, f"{name} source authority flag drift")
        require(type(document.get("productionSelected")) is bool and document.get("productionSelected") is False, f"{name} production flag drift")
    require(schedule.get("claimSHA256") == contract["route"]["claim"]["sha256"], "schedule claim drift")
    require(schedule.get("routeCarrierCommit") == contract["route"]["carrierCommit"], "schedule route carrier drift")
    require(schedule.get("routeReceiptSHA256") == contract["route"]["receiptSHA256"], "schedule route receipt drift")
    require(schedule.get("modelRouteSHA256") == contract["route"]["modelRouteSHA256"], "schedule model route drift")
    require(schedule.get("blender") == contract["blender"], "schedule Blender binding drift")
    require(schedule.get("allowedOutputLeaves") == contract["futureStageB"]["allowedOutputLeaves"], "schedule output inventory drift")
    require(schedule.get("microRender") == contract["futureStageB"]["microRender"], "schedule micro-render drift")
    require(type(schedule.get("maximumChildStarts")) is int and schedule.get("maximumChildStarts") == 1, "schedule child cap drift")
    require(type(schedule.get("maximumConcurrentDCCProcesses")) is int and schedule.get("maximumConcurrentDCCProcesses") == 1, "schedule DCC cap drift")
    require(type(schedule.get("timeoutSeconds")) is int and schedule.get("timeoutSeconds") == contract["futureStageB"]["timeoutSeconds"], "schedule timeout drift")
    require(schedule.get("contractSHA256") == sha256(root / CONTRACT_PATH), "schedule contract hash drift")
    require(schedule.get("launcherSHA256") == sha256(Path(__file__)), "schedule launcher hash drift")
    require(schedule.get("childSHA256") == sha256(root / CHILD_PATH), "schedule child hash drift")
    require(type(grant.get("grantId")) is str and grant["grantId"] == "north:phase-ladder:stage-b", "grant ID drift")
    require(type(grant.get("maximumChildStarts")) is int and grant.get("maximumChildStarts") == 1, "grant child cap drift")
    require(grant.get("scheduleSHA256") == hashes["schedule"], "grant schedule drift")
    require(type(session.get("sessionId")) is str and session.get("grantId") == grant["grantId"] and grant.get("sessionId") == session["sessionId"], "session identity drift")
    require(session.get("dccSlot") == "dcc-1" and session.get("scheduleSHA256") == hashes["schedule"] and session.get("grantSHA256") == hashes["grant"], "session drift")
    require(type(approval.get("approved")) is bool and approval.get("approved") is True, "static approval missing")
    require(approval.get("approvedCandidateHead") == identity["head"] and approval.get("scheduleSHA256") == hashes["schedule"], "static approval binding drift")
    attempt = Path(schedule.get("attemptMarkerPath", ""))
    require(attempt.is_absolute(), "attempt marker must be absolute")
    output = (root / contract["futureStageB"]["outputRoot"]).resolve(strict=False)
    require(output not in attempt.parents and attempt != output, "attempt marker must be outside output root")
    require(attempt.is_file() and not attempt.is_symlink(), "available attempt marker missing")
    marker = load_object(attempt)
    expected_state = expected_attempt_state or contract["externalAuthority"]["availableState"]
    require(marker.get("state") == expected_state, "attempt state unavailable or replayed")
    require(marker.get("scheduleSHA256") == hashes["schedule"] and marker.get("grantSHA256") == hashes["grant"] and marker.get("sessionSHA256") == hashes["session"] and marker.get("staticApprovalSHA256") == hashes["staticApproval"], "attempt binding drift")
    return {"documents": loaded, "hashes": hashes, "attemptPath": attempt, "outputRoot": output}


def parse_markers(stdout: bytes, phases: list[str]) -> list[dict[str, Any]]:
    markers: list[dict[str, Any]] = []
    for line in stdout.splitlines():
        if not line.startswith(b'{"play027Phase"'):
            continue
        value = json.loads(line)
        require(type(value) is dict and set(value) == {"play027Phase", "sequence"}, "phase marker schema drift")
        require(type(value["play027Phase"]) is str and type(value["sequence"]) is int, "phase marker types drift")
        require(value["sequence"] == len(markers) and value["play027Phase"] == phases[len(markers)], "phase marker order drift")
        markers.append(value)
    return markers


def _write_exclusive(root: Path, leaf: str, data: bytes, allowed: set[str]) -> None:
    require(root.is_dir() and not root.is_symlink(), "owned output root required")
    require(leaf in allowed and Path(leaf).name == leaf, "output leaf forbidden")
    directory_fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fd = os.open(leaf, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600, dir_fd=directory_fd)
        try:
            os.write(fd, data)
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        os.close(directory_fd)


def consume_attempt(path: Path, authority: dict[str, Any], identity: dict[str, str]) -> dict[str, Any]:
    available = load_object(path)
    require(available.get("state") == "AVAILABLE", "attempt already consumed")
    consumed = {
        **available, "state": "CONSUMED", "launcherPID": os.getpid(), "workerHead": identity["head"],
        "documentHashes": authority["hashes"],
    }
    temp = path.with_name(path.name + ".consume-tmp")
    require(not temp.exists() and not temp.is_symlink(), "attempt temporary path occupied")
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
    try:
        os.write(fd, canonical(consumed))
        os.fsync(fd)
    finally:
        os.close(fd)
    os.replace(temp, path)
    require(load_object(path) == consumed, "attempt consumption not durable")
    return consumed


def write_child_start(path: Path, identity: dict[str, str]) -> Path:
    marker = path.with_name(path.name + ".child-start")
    _write_exclusive(marker.parent, marker.name, canonical({"launcherPID": os.getpid(), "state": "CHILD_STARTED", "workerHead": identity["head"]}), {marker.name})
    return marker


def crash_report_inventory(root: Path | None = None) -> list[dict[str, Any]]:
    crash_root = root or (Path.home() / "Library/Logs/DiagnosticReports")
    if not crash_root.is_dir():
        return []
    reports = []
    for path in sorted(crash_root.iterdir(), key=lambda item: item.name):
        if path.is_file() and not path.is_symlink() and ("blender" in path.name.lower() or "python" in path.name.lower()):
            reports.append({"name": path.name, "size": path.stat().st_size, "sha256": sha256(path)})
    return reports


def capture_process(process: Any, argv: list[str], output: Path, contract: dict[str, Any], *, started_at: str, timeout: float, kill_group: Callable[[int], None] | None = None, ended_at: str | None = "TEST-END", crash_before: list[dict[str, Any]] | None = None, crash_after: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    timed_out = False
    communication_error = None
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        (kill_group or (lambda pid: os.killpg(pid, signal.SIGKILL)))(process.pid)
        stdout, stderr = process.communicate()
    except BaseException as error:
        communication_error = f"{type(error).__name__}: {error}"
        (kill_group or (lambda pid: os.killpg(pid, signal.SIGKILL)))(process.pid)
        try:
            stdout, stderr = process.communicate()
        except BaseException as second_error:
            stdout, stderr = b"", f"capture failed: {type(second_error).__name__}: {second_error}".encode()
    return_code = process.returncode
    if ended_at is None:
        ended_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    phases = contract["phaseLadder"]["ordered"]
    marker_error = None
    try:
        markers = parse_markers(stdout, phases)
    except Exception as error:
        markers = []
        marker_error = f"{type(error).__name__}: {error}"
    complete = not timed_out and communication_error is None and return_code == 0 and marker_error is None and len(markers) == len(phases)
    allowed = set(contract["futureStageB"]["allowedOutputLeaves"])
    _write_exclusive(output, "stdout.bin", stdout, allowed)
    _write_exclusive(output, "stderr.bin", stderr, allowed)
    marker_bytes = b"".join(canonical(marker) for marker in markers)
    _write_exclusive(output, "PHASE-MARKERS.jsonl", marker_bytes, allowed)
    before = crash_before if crash_before is not None else []
    after = crash_after if crash_after is not None else crash_report_inventory()
    before_hashes = {item["sha256"] for item in before}
    new_crashes = [item for item in after if item["sha256"] not in before_hashes]
    leaf = "DIAGNOSTIC-RECEIPT.json" if complete else "FAILURE.json"
    payload = {
        "status": "COMPLETE" if complete else "FAILURE", "argv": argv, "pid": process.pid,
        "startedAt": started_at, "endedAt": ended_at, "timeoutSeconds": timeout, "timedOut": timed_out,
        "returnCode": return_code, "signal": -return_code if type(return_code) is int and return_code < 0 else None,
        "observedPhases": [m["play027Phase"] for m in markers], "lastPhase": markers[-1]["play027Phase"] if markers else None, "markerError": marker_error, "communicationError": communication_error,
        "stdoutSHA256": sha256_bytes(stdout), "stderrSHA256": sha256_bytes(stderr),
        "inventory": sorted([p.name for p in output.iterdir()] + [leaf]), "crashReportsBefore": before, "crashReportsAfter": after, "newCrashReports": new_crashes,
        "sourceAuthority": False, "productionSelected": False,
    }
    _write_exclusive(output, leaf, canonical(payload), allowed)
    return payload


def preserve_launch_failure(output: Path, contract: dict[str, Any], argv: list[str], error: BaseException, started_at: str) -> dict[str, Any]:
    allowed = set(contract["futureStageB"]["allowedOutputLeaves"])
    payload = {
        "status": "FAILURE", "argv": argv, "pid": None, "startedAt": started_at,
        "endedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "timeoutSeconds": contract["futureStageB"]["timeoutSeconds"],
        "timedOut": False, "returnCode": None, "signal": None, "observedPhases": [], "lastPhase": None,
        "markerError": None, "launchError": f"{type(error).__name__}: {error}", "stdoutSHA256": sha256_bytes(b""), "stderrSHA256": sha256_bytes(b""),
        "inventory": ["FAILURE.json"], "crashReportsBefore": [], "crashReportsAfter": [], "newCrashReports": [],
        "sourceAuthority": False, "productionSelected": False,
    }
    _write_exclusive(output, "FAILURE.json", canonical(payload), allowed)
    return payload


def child_argv(root: Path, contract: dict[str, Any], documents: dict[str, Path], output: Path) -> list[str]:
    return [contract["blender"]["executable"], "--factory-startup", "--disable-autoexec", "--background", "--python", str(root / CHILD_PATH), "--", "--repository-root", str(root), "--contract", str(root / CONTRACT_PATH), "--schedule", str(documents["schedule"]), "--grant", str(documents["grant"]), "--session", str(documents["session"]), "--static-approval", str(documents["staticApproval"]), "--output-root", str(output)]


def launch_once(root: Path, documents: dict[str, Path]) -> dict[str, Any]:
    global CHILD_START_COUNT
    contract, identity = validate_static(root)
    authority = validate_direct_documents(root, contract, identity, documents)
    require(CHILD_START_COUNT == 0, "one-child lease already consumed")
    output = authority["outputRoot"]
    require(output.parent.resolve(strict=True) == (root / ROOT_REL).resolve(strict=True), "output parent identity drift")
    output.mkdir(mode=0o700, parents=False, exist_ok=False)
    started_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    try:
        consume_attempt(authority["attemptPath"], authority, identity)
        write_child_start(authority["attemptPath"], identity)
        argv = child_argv(root, contract, documents, output)
        crashes_before = crash_report_inventory()
        CHILD_START_COUNT += 1
        process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    except BaseException as error:
        return preserve_launch_failure(output, contract, locals().get("argv", []), error, started_at)
    return capture_process(process, argv, output, contract, started_at=started_at, timeout=contract["futureStageB"]["timeoutSeconds"], ended_at=None, crash_before=crashes_before)


def prepare_zero_child(root: Path) -> dict[str, Any]:
    contract, identity = validate_static(root.resolve(strict=True))
    return {"status": "STATIC_REFERENCE_CANDIDATE", "head": identity["head"], "childStarts": 0, "dccProcessCount": 0, "outputRootCreated": 0, "pixelWrites": 0, "executableBehavior": "UNPROVEN", "futureDocumentsRequired": contract["externalAuthority"]["requiredDocuments"]}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=".")
    parser.add_argument("--zero-child", action="store_true")
    parser.add_argument("--schedule")
    parser.add_argument("--grant")
    parser.add_argument("--session")
    parser.add_argument("--static-approval")
    args = parser.parse_args(argv)
    root = Path(args.repository_root).resolve(strict=True)
    if args.zero_child:
        print(json.dumps(prepare_zero_child(root), sort_keys=True))
        return 0
    required = {"schedule": args.schedule, "grant": args.grant, "session": args.session, "staticApproval": args.static_approval}
    require(all(type(v) is str for v in required.values()), "all Integration documents required")
    result = launch_once(root, {k: Path(v) for k, v in required.items()})
    print(json.dumps(result, sort_keys=True))
    return 0 if result["status"] == "COMPLETE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
