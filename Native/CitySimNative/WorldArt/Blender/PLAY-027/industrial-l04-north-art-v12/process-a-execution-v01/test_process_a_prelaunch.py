#!/usr/bin/env python3
"""Zero-child security proof for the North v12 Process-A boundary."""

from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Callable


SOURCE_ROOT = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/process-a-execution-v01"
)
ADAPTER_ROOT = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/process-a-schedule-adapter-v01"
)
EVIDENCE_ROOT = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12/process-a-execution-v01"
)
EVIDENCE_RELATIVE = EVIDENCE_ROOT / "CURRENT-ZERO-CHILD-PRELAUNCH.json"


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: Any) -> bytes:
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": ")) + "\n"
    ).encode("utf-8")


def load_module(path: Path, name: str) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"{name} import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_git(repository: Path, *arguments: str) -> str:
    environment = os.environ.copy()
    environment.update(
        {
            "GIT_AUTHOR_DATE": "2001-01-01T00:00:00Z",
            "GIT_COMMITTER_DATE": "2001-01-01T00:00:00Z",
        }
    )
    result = subprocess.run(
        ["git", *arguments],
        cwd=repository,
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"temporary Git command failed: {' '.join(arguments)}: {result.stderr}"
        )
    return result.stdout.strip()


def expect_failure(
    name: str,
    operation: Callable[[], Any],
    expected: str,
) -> dict[str, Any]:
    try:
        operation()
    except Exception as error:
        actual = str(error)
        if expected not in actual:
            raise RuntimeError(
                f"{name}: expected {expected!r}, got {actual!r}"
            ) from error
        return {
            "name": name,
            "expectedFailure": expected,
            "actualFailure": actual,
            "passed": True,
        }
    raise RuntimeError(f"{name}: unexpectedly passed")


def write_exclusive(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.parent.is_symlink():
        raise RuntimeError("prelaunch output parent must not be a symlink")
    descriptor = os.open(
        path,
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | getattr(os, "O_NOFOLLOW", 0),
        0o644,
    )
    try:
        payload = canonical(value)
        offset = 0
        while offset < len(payload):
            offset += os.write(descriptor, payload[offset:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def valid_grant(contract: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": 1,
        "task": contract["task"],
        "batch": contract["batch"],
        "phase": contract["phase"],
        "direction": contract["direction"],
        "process": contract["process"],
        "grantId": "north:A",
        "slotId": "dcc-1",
        "maximumChildStarts": 1,
        "orchestrator": contract["launcher"],
        "exclusiveRoots": [
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12",
            "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12",
        ],
        "integrationAuthorityCommit": contract["publicationCommit"],
        "publishedBaseCommit": contract["authorityBaseCommit"],
        "claimSHA256": contract["claim"]["sha256"],
        "frozenNorthV12Inputs": contract["frozenNorthV12Inputs"],
        "adapterMode": "validate-and-return-grant-plan-only",
        "directLowLevelInvocationAllowed": False,
        "blenderChildStartCount": 0,
        "dccProcessCount": 0,
        "renderInvocationCount": 0,
        "sourcePixelCount": 0,
        "grantValidated": True,
        "processStarted": False,
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }


def authority_fixture(
    repository: Path,
    launcher: Any,
    contract: dict[str, Any],
    secret: bytes,
) -> tuple[Path, str, Path, str, dict[str, Any]]:
    run_git(repository, "init")
    run_git(repository, "checkout", "-b", "main")
    run_git(repository, "config", "user.name", "PLAY-027 Test")
    run_git(repository, "config", "user.email", "play027@example.invalid")
    contract_path = repository / launcher.CONTRACT_RELATIVE
    contract_path.parent.mkdir(parents=True)
    contract_path.write_bytes(canonical(contract))
    integration = repository / launcher.INTEGRATION_ROOT
    integration.mkdir(parents=True)
    (repository / "AUTHORITY.md").write_text("authority\n", encoding="utf-8")
    run_git(repository, "add", ".")
    run_git(repository, "commit", "-m", "preexisting authority")
    base_commit = run_git(repository, "rev-parse", "HEAD")
    schedule_path = integration / "north-a-schedule.json"
    schedule_path.write_bytes(
        canonical({"integrationAuthorityCommit": base_commit, "grantId": "north:A"})
    )
    run_git(repository, "add", str(schedule_path.relative_to(repository)))
    run_git(repository, "commit", "-m", "publish schedule")
    schedule_commit = run_git(repository, "rev-parse", "HEAD")
    output_relative = Path(contract["processOutputRoot"])
    authority = {
        "schema": 1,
        "task": "PLAY-027",
        "direction": "north",
        "process": "A",
        "grantId": "north:A",
        "slotId": "dcc-1",
        "schedule": {
            "path": str(schedule_path.relative_to(repository)),
            "sha256": sha256(schedule_path),
            "publicationCommit": schedule_commit,
        },
        "executionContract": {
            "path": str(launcher.CONTRACT_RELATIVE),
            "sha256": sha256(contract_path),
        },
        "launcher": contract["launcher"],
        "childEntrypoint": contract["childEntrypoint"],
        "processOutputRoot": str(output_relative),
        "attemptRecordPath": str(
            output_relative.parent / "attempt-consumption-v01/north-A.json"
        ),
        "attemptId": "north:A",
        "maximumConcurrentDCCProcesses": 1,
        "maximumChildStarts": 1,
        "timeoutSeconds": contract["processEnvelope"]["timeoutSeconds"],
        "maximumProcessGroupRSSMiB": contract["processEnvelope"][
            "maximumProcessGroupRSSMiB"
        ],
        "stopDisposition": "STOP_AFTER_ONE_FRESH_NORTH_SOURCE_CANDIDATE",
        "authorizationSecretSHA256": hashlib.sha256(secret).hexdigest(),
        "sourceAuthority": False,
        "productionSelected": False,
    }
    authority_path = integration / "north-a-execution-authority.json"
    authority_path.write_bytes(canonical(authority))
    run_git(repository, "add", str(authority_path.relative_to(repository)))
    run_git(repository, "commit", "-m", "publish execution authority")
    authority_commit = run_git(repository, "rev-parse", "HEAD")
    return (
        schedule_path,
        schedule_commit,
        authority_path,
        authority_commit,
        authority,
    )


def source_ast(path: Path) -> ast.Module:
    return ast.parse(path.read_text(encoding="utf-8"), filename=str(path))


def attribute_calls(syntax: ast.Module, attribute: str) -> list[ast.Call]:
    return [
        node
        for node in ast.walk(syntax)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == attribute
    ]


def run_fault_case(
    launcher: Any,
    contract: dict[str, Any],
    stage: str,
    *,
    expect_root: bool,
    expect_dcc_starts: int = 0,
) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(
        prefix=f"play027-run-one-child-{stage}-",
        dir="/private/tmp",
    ) as directory:
        root = Path(directory)
        output_relative = Path("evidence") / stage / "process-a"
        output = root / output_relative
        output.parent.mkdir(parents=True)
        schedule = root / "schedule.json"
        schedule.write_bytes(b"{}\n")
        contract_path = root / "contract.json"
        contract_path.write_bytes(b"{}\n")
        local_contract = copy.deepcopy(contract)
        local_contract["processOutputRoot"] = str(output_relative)
        if stage == "timeout":
            local_contract["processEnvelope"]["timeoutSeconds"] = 0
        if stage == "rss":
            local_contract["processEnvelope"]["maximumProcessGroupRSSMiB"] = 0
        local_contract["launcher"] = {
            "path": contract["launcher"]["path"],
            "sha256": contract["launcher"]["sha256"],
        }
        local_authority = {
            "grantId": "north:A",
            "slotId": "dcc-1",
            "path": "docs/production/evidence/INTEGRATION/authority.json",
            "sha256": "a" * 64,
            "publicationCommit": "b" * 40,
            "schedule": {
                "path": "schedule.json",
                "sha256": hashlib.sha256(schedule.read_bytes()).hexdigest(),
                "publicationCommit": "c" * 40,
            },
            "attemptRecordPath": str(
                output_relative.parent / "attempt-consumption-v01/north-A.json"
            ),
            "attemptId": "north:A",
            "authorizationSecretSHA256": hashlib.sha256(b"x" * 32).hexdigest(),
        }
        attempt_parent = root / Path(local_authority["attemptRecordPath"]).parent
        attempt_parent.mkdir(parents=True)
        grant = valid_grant(local_contract)

        class FakeAdapter:
            git_output = staticmethod(lambda *_args: "")
            git_bytes = staticmethod(lambda *_args: b"")

            @staticmethod
            def consume_published_schedule(*_args: Any) -> dict[str, Any]:
                return grant

        saved = {
            "validate_execution_contract": launcher.validate_execution_contract,
            "normalize_repository_file": launcher.normalize_repository_file,
            "read_authorization_secret": launcher.read_authorization_secret,
            "validate_execution_authority": launcher.validate_execution_authority,
            "load_module": launcher.load_module,
            "validate_grant_plan": launcher.validate_grant_plan,
            "verify_blender_executable": launcher.verify_blender_executable,
            "platform": launcher.sys.platform,
            "Popen": launcher.subprocess.Popen,
            "process_group_snapshot": launcher.process_group_snapshot,
            "wait4": launcher.os.wait4,
            "terminate_group": launcher.terminate_group,
        }
        try:
            launcher.validate_execution_contract = lambda *_args: local_contract
            launcher.normalize_repository_file = lambda *_args: schedule
            launcher.read_authorization_secret = lambda _fd: b"x" * 32
            launcher.validate_execution_authority = lambda *_args: local_authority
            launcher.load_module = lambda *_args: FakeAdapter
            launcher.validate_grant_plan = lambda *_args, **_kwargs: {
                "grant": grant,
                "outputRoot": str(output_relative),
                "requestedChildStarts": 1,
                "validated": True,
            }
            launcher.verify_blender_executable = lambda *_args: Path("/private/tmp/blender")
            launcher.sys.platform = "darwin"
            terminated: list[int] = []

            class FakeProcess:
                pid = 7301
                returncode: int | None = None

            snapshot_count = 0
            wait_count = 0

            def fake_snapshot(_pid: int) -> list[dict[str, int]]:
                nonlocal snapshot_count
                snapshot_count += 1
                if stage in {"timeout", "rss"} and snapshot_count == 1:
                    return [
                        {
                            "pid": FakeProcess.pid,
                            "rssKiB": 1 if stage == "rss" else 0,
                        }
                    ]
                return []

            def fake_wait4(pid: int, options: int) -> tuple[int, int, Any]:
                nonlocal wait_count
                wait_count += 1
                if stage in {"timeout", "rss"} and wait_count == 1 and options != 0:
                    return (0, 0, None)
                return (pid, 0, SimpleNamespace(ru_maxrss=1024))

            if stage in {"sampler", "cleanup", "timeout", "rss"}:
                launcher.subprocess.Popen = lambda *_args, **_kwargs: FakeProcess()
                launcher.process_group_snapshot = fake_snapshot
                launcher.os.wait4 = fake_wait4
                launcher.terminate_group = terminated.append

            def inject(actual: str) -> None:
                if actual == stage and stage not in {"timeout", "rss"}:
                    raise OSError(f"injected-{stage}")

            result: int | None = None
            failure: str | None = None
            try:
                result = launcher.run_one_child(
                    root,
                    contract_path,
                    schedule,
                    "c" * 40,
                    root / "authority.json",
                    "b" * 40,
                    9,
                    output,
                    _fault=inject,
                )
            except Exception as error:
                failure = f"{type(error).__name__}: {error}"
            if output.exists() != expect_root:
                raise RuntimeError(f"{stage}: output-root accounting drift")
            receipt = output / "PROCESS-RECEIPT.json"
            if expect_root:
                if not receipt.is_file():
                    raise RuntimeError(f"{stage}: terminal receipt missing")
                receipt_value = json.loads(receipt.read_text(encoding="utf-8"))
                if receipt_value["dccChildStartCount"] != expect_dcc_starts:
                    raise RuntimeError(f"{stage}: DCC child accounting drift")
                if stage in {"timeout", "rss"} and not terminated:
                    raise RuntimeError(f"{stage}: process group was not terminated")
                receipt_summary = {
                    "dccChildStartCount": receipt_value["dccChildStartCount"],
                    "maximumDCCChildStarts": receipt_value["maximumDCCChildStarts"],
                    "terminationReason": receipt_value["terminationReason"],
                    "postReapProcessGroupExhausted": receipt_value[
                        "postReapProcessGroupExhausted"
                    ],
                    "helperProcessesRecordedSeparately": (
                        receipt_value["helperProcessCount"]
                        == len(receipt_value["helperProcessInvocations"])
                    ),
                }
            else:
                receipt_summary = None
            return {
                "name": f"run-one-child-{stage}-failure",
                "returnCode": result,
                "raised": failure,
                "outputRootCreated": output.exists(),
                "terminalReceipt": receipt_summary,
                "terminatedProcessGroups": terminated,
                "passed": True,
            }
        finally:
            for name, value in saved.items():
                if name == "platform":
                    launcher.sys.platform = value
                elif name == "Popen":
                    launcher.subprocess.Popen = value
                elif name == "wait4":
                    launcher.os.wait4 = value
                else:
                    setattr(launcher, name, value)


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    output = Path(options.output).absolute()
    expected_output = (repository_root / EVIDENCE_RELATIVE).absolute()
    if output != expected_output:
        raise RuntimeError("exact current zero-child prelaunch output required")
    if output.exists() or output.is_symlink():
        raise RuntimeError("current zero-child prelaunch output must be absent")

    source_root = repository_root / SOURCE_ROOT
    launcher_path = source_root / "launch_north_process_a.py"
    child_path = source_root / "render_north_process_a_child.py"
    contract_path = source_root / "EXECUTION-CONTRACT.json"
    test_path = source_root / "test_process_a_prelaunch.py"
    launcher = load_module(launcher_path, "play027_process_a_launcher")
    child = load_module(child_path, "play027_process_a_child")
    contract = launcher.validate_execution_contract(repository_root, contract_path)
    grant = valid_grant(contract)
    requested_output = repository_root / contract["processOutputRoot"]
    positive = launcher.validate_grant_plan(
        contract,
        grant,
        requested_output,
        repository_root,
        output_exists=lambda _: False,
    )
    cases: list[dict[str, Any]] = []

    for name, field, value, expected in [
        ("wrong-grant", "grantId", "forged", "grant"),
        ("wrong-slot", "slotId", "dcc-2", "slot"),
        ("reused-grant", "processStarted", True, "already consumed"),
        ("wrong-process", "process", "B", "process drift"),
        ("extra-child", "maximumChildStarts", 2, "child limit"),
        ("wrong-orchestrator", "orchestrator", contract["childEntrypoint"], "orchestrator"),
    ]:
        changed = copy.deepcopy(grant)
        changed[field] = value
        cases.append(
            expect_failure(
                name,
                lambda changed=changed: launcher.validate_grant_plan(
                    contract,
                    changed,
                    requested_output,
                    repository_root,
                    output_exists=lambda _: False,
                ),
                expected,
            )
        )

    secret = b"integration-secret-for-play027-test"
    with tempfile.TemporaryDirectory(
        prefix="play027-execution-authority-",
        dir="/private/tmp",
    ) as directory:
        authority_root = Path(directory)
        fixture_contract = copy.deepcopy(contract)
        fixture_contract["processOutputRoot"] = (
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
            "blender-north-art-v12/process-a-execution-v01/process-a"
        )
        (
            schedule_path,
            schedule_commit,
            authority_path,
            authority_commit,
            _authority,
        ) = authority_fixture(authority_root, launcher, fixture_contract, secret)
        validated_authority = launcher.validate_execution_authority(
            authority_root,
            fixture_contract,
            authority_path,
            authority_commit,
            schedule_path,
            schedule_commit,
            authority_root / fixture_contract["processOutputRoot"],
            secret,
        )
        cases.append(
            {
                "name": "real-git-execution-authority-publication",
                "publicationCommit": authority_commit,
                "schedulePublicationCommit": schedule_commit,
                "authoritySHA256": validated_authority["sha256"],
                "passed": True,
            }
        )
        cases.append(
            expect_failure(
                "wrong-execution-secret",
                lambda: launcher.validate_execution_authority(
                    authority_root,
                    fixture_contract,
                    authority_path,
                    authority_commit,
                    schedule_path,
                    schedule_commit,
                    authority_root / fixture_contract["processOutputRoot"],
                    b"wrong-secret" * 4,
                ),
                "secret mismatch",
            )
        )
        authority_path.write_bytes(authority_path.read_bytes() + b" ")
        cases.append(
            expect_failure(
                "dirty-execution-authority",
                lambda: launcher.validate_execution_authority(
                    authority_root,
                    fixture_contract,
                    authority_path,
                    authority_commit,
                    schedule_path,
                    schedule_commit,
                    authority_root / fixture_contract["processOutputRoot"],
                    secret,
                ),
                "worktree bytes are dirty",
            )
        )

    with tempfile.TemporaryDirectory(
        prefix="play027-output-inode-",
        dir="/private/tmp",
    ) as directory:
        inode_root = Path(directory)
        (inode_root / "evidence").mkdir()
        inode_contract = {"processOutputRoot": "evidence/process-a"}
        output_fd, identity = launcher.create_output_root(
            inode_root,
            inode_contract,
            inode_root / "evidence/process-a",
        )
        os.rename(
            inode_root / "evidence/process-a",
            inode_root / "evidence/process-a-moved",
        )
        (inode_root / "evidence/process-a").mkdir()
        launcher.write_exclusive_at(output_fd, "BOUND.json", {"identity": identity})
        os.close(output_fd)
        if not (inode_root / "evidence/process-a-moved/BOUND.json").is_file():
            raise RuntimeError("directory-FD ownership did not survive ancestor swap")
        if list((inode_root / "evidence/process-a").iterdir()):
            raise RuntimeError("replacement output directory received a write")
        cases.append(
            {
                "name": "directory-fd-inode-ownership-survives-name-swap",
                "openedIdentityRetained": True,
                "replacementDirectoryWrites": 0,
                "passed": True,
            }
        )

    with tempfile.TemporaryDirectory(
        prefix="play027-attempt-record-",
        dir="/private/tmp",
    ) as directory:
        lease_root = Path(directory)
        attempt_relative = Path("evidence/attempt-consumption-v01/north-A.json")
        (lease_root / attempt_relative.parent).mkdir(parents=True)
        lease_authority = {
            "grantId": "north:A",
            "attemptId": "north:A",
            "attemptRecordPath": str(attempt_relative),
            "path": "docs/production/evidence/INTEGRATION/authority.json",
            "sha256": "a" * 64,
            "publicationCommit": "b" * 40,
            "schedule": {"path": "schedule.json", "sha256": "c" * 64},
        }
        launcher.create_attempt_record(lease_root, lease_authority)
        cases.append(
            expect_failure(
                "durable-one-shot-attempt-survives-output-loss",
                lambda: launcher.create_attempt_record(lease_root, lease_authority),
                "already consumed",
            )
        )

    authorization_secret = b"q" * 32
    with tempfile.TemporaryDirectory(
        prefix="play027-forged-pipe-",
        dir="/private/tmp",
    ) as directory:
        child_root = Path(directory)
        output_fd = os.open(child_root, os.O_RDONLY | os.O_DIRECTORY)
        fake_grant = {
            "schema": 2,
            "task": "PLAY-027",
            "direction": "north",
            "process": "A",
            "grantId": "north:A",
            "slotId": "dcc-1",
            "schedulePath": "schedule.json",
            "scheduleSHA256": "a" * 64,
            "schedulePublicationCommit": "b" * 40,
            "executionAuthorityPath": "docs/production/evidence/INTEGRATION/a.json",
            "executionAuthoritySHA256": "c" * 64,
            "executionAuthorityPublicationCommit": "d" * 40,
            "contractSHA256": sha256(contract_path),
            "launcherSHA256": contract["launcher"]["sha256"],
            "launcherPID": os.getppid(),
            "childEntrypointSHA256": contract["childEntrypoint"]["sha256"],
            "outputRoot": contract["processOutputRoot"],
            "outputRootDevice": os.fstat(output_fd).st_dev,
            "outputRootInode": os.fstat(output_fd).st_ino,
            "authorizationSecretSHA256": hashlib.sha256(authorization_secret).hexdigest(),
            "sessionSecretSHA256": hashlib.sha256(b"s" * 32).hexdigest(),
            "attemptRecordPath": "attempt.json",
            "attemptRecordSHA256": "e" * 64,
            "maximumDCCChildStarts": 1,
        }
        launcher.write_exclusive_at(output_fd, "CHILD-GRANT.json", fake_grant)
        read_fd, write_fd = os.pipe()
        forged = launcher.capability_message(
            b"forged-secret-without-authority!!",
            session_secret=b"s" * 32,
            public_payload={
                "schema": 2,
                "grantId": "north:A",
                "launcherPID": os.getppid(),
                "launcherSHA256": contract["launcher"]["sha256"],
                "scheduleSHA256": "a" * 64,
                "schedulePublicationCommit": "b" * 40,
                "executionAuthoritySHA256": "c" * 64,
                "executionAuthorityPublicationCommit": "d" * 40,
                "outputRootDevice": os.fstat(output_fd).st_dev,
                "outputRootInode": os.fstat(output_fd).st_ino,
            },
        )
        os.write(write_fd, canonical(forged))
        os.close(write_fd)
        payload = child.read_one_use_capability(read_fd)
        cases.append(
            expect_failure(
                "forged-anonymous-pipe-parent",
                lambda: child.verify_capability(
                    repository_root,
                    contract,
                    contract_path,
                    output_fd,
                    "CHILD-GRANT.json",
                    payload,
                ),
                "Integration authorization secret mismatch",
            )
        )
        os.close(output_fd)

    for stage, expect_root in [
        ("lease", False),
        ("root", False),
        ("pipe", True),
        ("grant", True),
        ("command", True),
        ("temp", True),
        ("popen", True),
    ]:
        cases.append(
            run_fault_case(
                launcher,
                contract,
                stage,
                expect_root=expect_root,
            )
        )
    for stage in ("sampler", "cleanup", "timeout", "rss"):
        cases.append(
            run_fault_case(
                launcher,
                contract,
                stage,
                expect_root=True,
                expect_dcc_starts=1,
            )
        )

    timeout_kills: list[int] = []
    timeout_reason = launcher.enforce_resource_observation(
        7001,
        elapsed_seconds=121.0,
        sampled_peak_rss_kib=1,
        maximum_seconds=120.0,
        maximum_rss_kib=1024 * 1024,
        observed_extra_members=set(),
        terminate=timeout_kills.append,
    )
    rss_kills: list[int] = []
    rss_reason = launcher.enforce_resource_observation(
        7002,
        elapsed_seconds=1.0,
        sampled_peak_rss_kib=1024 * 1024 + 1,
        maximum_seconds=120.0,
        maximum_rss_kib=1024 * 1024,
        observed_extra_members=set(),
        terminate=rss_kills.append,
    )
    if timeout_reason != "timeout" or timeout_kills != [7001]:
        raise RuntimeError("timeout group-kill adversary failed")
    if rss_reason != "rss-limit" or rss_kills != [7002]:
        raise RuntimeError("RSS group-kill adversary failed")
    cases.extend(
        [
            {
                "name": "timeout-kills-DCC-process-group",
                "terminationReason": timeout_reason,
                "terminatedProcessGroups": timeout_kills,
                "passed": True,
            },
            {
                "name": "rss-limit-kills-DCC-process-group",
                "terminationReason": rss_reason,
                "terminatedProcessGroups": rss_kills,
                "passed": True,
            },
        ]
    )

    launcher_syntax = source_ast(launcher_path)
    child_syntax = source_ast(child_path)
    popen_calls = attribute_calls(launcher_syntax, "Popen")
    if len(popen_calls) != 1:
        raise RuntimeError(f"exactly one DCC Popen site required, found {len(popen_calls)}")
    if attribute_calls(child_syntax, "Popen") or "import subprocess" in child_path.read_text(
        encoding="utf-8"
    ):
        raise RuntimeError("child-side subprocess surface is forbidden")
    render_calls = [
        node
        for node in ast.walk(child_syntax)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == "render"
    ]
    if len(render_calls) != 2:
        raise RuntimeError("future child must retain exactly two render calls")
    if len(attribute_calls(launcher_syntax, "pipe")) != 1:
        raise RuntimeError("launcher session capability must use exactly one pipe")
    if not attribute_calls(launcher_syntax, "killpg"):
        raise RuntimeError("process-group kill path missing")
    cases.append(
        {
            "name": "dcc-and-helper-process-accounting",
            "dccPopenSiteCount": 1,
            "helperClasses": ["git-read-only", "process-observer"],
            "helperInvocationsRecordedSeparately": True,
            "childSubprocessSites": 0,
            "futureRenderCalls": 2,
            "futureRenderCallsExecuted": 0,
            "passed": True,
        }
    )

    adapter_test = repository_root / ADAPTER_ROOT / "test_north_process_a_schedule_adapter.py"
    result = {
        "schema": 2,
        "task": "PLAY-027",
        "direction": "north",
        "process": "A",
        "authorityBaseCommit": contract["authorityBaseCommit"],
        "publicationCommit": contract["publicationCommit"],
        "executionContract": {
            "path": str(contract_path.relative_to(repository_root)),
            "sha256": sha256(contract_path),
        },
        "launcher": contract["launcher"],
        "childEntrypoint": contract["childEntrypoint"],
        "scheduleAdapter": contract["scheduleAdapter"],
        "prelockProcessPolicy": contract["prelockProcessPolicy"],
        "directionRootMap": contract["directionRootMap"],
        "futureDirectionHandoff": contract["futureDirectionHandoff"],
        "adapterCurrentTest": {
            "path": str(adapter_test.relative_to(repository_root)),
            "sha256": sha256(adapter_test),
        },
        "positiveGrantPlan": positive,
        "adversarialCaseCount": len(cases),
        "allPassed": all(case["passed"] for case in cases),
        "cases": cases,
        "securityBoundary": {
            "externalSchedulePublicationCommit": True,
            "externalExecutionAuthorityRequired": True,
            "integrationSecretRequired": True,
            "launcherSessionHMAC": True,
            "durableAttemptRecord": True,
            "directoryFDAndInodeBound": True,
            "terminalReceiptAfterRootCreation": True,
            "helperProcessesSeparateFromDCCChild": True,
        },
        "liveSchedule": {
            "present": False,
            "executionAuthorityPresent": False,
            "disposition": "BLOCKED_PENDING_INTEGRATION_SCHEDULE_EXECUTION_AUTHORITY_AND_SECRET",
        },
        "blenderChildStartCount": 0,
        "dccProcessCount": 0,
        "renderInvocationCount": 0,
        "sourcePixelCount": 0,
        "normalizerProcessCount": 0,
        "imageGenProcessCount": 0,
        "siblingProcessCount": 0,
        "rendererProcessCount": 0,
        "shippingMutationCount": 0,
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
        "validationPassed": True,
    }
    write_exclusive(output, result)
    print(
        json.dumps(
            {
                "adversarialCaseCount": len(cases),
                "allPassed": True,
                "blenderChildStartCount": 0,
                "dccProcessCount": 0,
                "output": str(output),
                "outputSHA256": sha256(output),
                "validationPassed": True,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
