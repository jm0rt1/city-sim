#!/usr/bin/env python3
"""High-level one-child launcher for a future North v12 Process A grant."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import platform
import secrets
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Callable


SOURCE_ROOT = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/process-a-execution-v01"
)
CONTRACT_RELATIVE = SOURCE_ROOT / "EXECUTION-CONTRACT.json"
LAUNCHER_RELATIVE = SOURCE_ROOT / "launch_north_process_a.py"


class LaunchError(ValueError):
    """A fail-closed prelaunch or execution-boundary rejection."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise LaunchError(message)


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON object required: {path.name}")
    return value


def resolve_regular(repository_root: Path, relative: str, label: str) -> Path:
    require(relative and not relative.startswith("/"), f"{label} path must be relative")
    lexical = repository_root / relative
    current = repository_root
    for component in Path(relative).parts:
        current = current / component
        require(not current.is_symlink(), f"{label} path contains a symlink")
    resolved = lexical.resolve(strict=True)
    require(resolved.is_relative_to(repository_root), f"{label} escapes repository")
    require(resolved.is_file(), f"{label} must be a regular file")
    return resolved


def verify_binding(
    repository_root: Path,
    binding: Any,
    label: str,
    *,
    expected_path: str | None = None,
    expected_sha256: str | None = None,
) -> Path:
    require(isinstance(binding, dict), f"{label} binding must be an object")
    require(set(binding) == {"path", "sha256"}, f"{label} binding fields drift")
    if expected_path is not None:
        require(binding["path"] == expected_path, f"{label} path drift")
    if expected_sha256 is not None:
        require(binding["sha256"] == expected_sha256, f"{label} hash drift")
    path = resolve_regular(repository_root, binding["path"], label)
    require(sha256(path) == binding["sha256"], f"{label} bytes drift")
    return path


def git_check(repository_root: Path, arguments: list[str]) -> str:
    require(
        arguments and arguments[0] in {"branch", "cat-file", "merge-base"},
        "unapproved Git prelaunch operation",
    )
    result = subprocess.run(
        ["git", *arguments],
        cwd=repository_root,
        capture_output=True,
        text=True,
        check=False,
    )
    require(result.returncode == 0, f"Git binding failed: {' '.join(arguments)}")
    return result.stdout.strip()


def require_ancestor(repository_root: Path, commit: str, label: str) -> None:
    require(
        len(commit) == 40
        and all(character in "0123456789abcdef" for character in commit),
        f"{label} must be a full commit",
    )
    git_check(repository_root, ["cat-file", "-e", f"{commit}^{{commit}}"])
    git_check(repository_root, ["merge-base", "--is-ancestor", commit, "HEAD"])


def load_module(path: Path, name: str) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"{name} import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_execution_contract(
    repository_root: Path,
    contract_path: Path,
) -> dict[str, Any]:
    repository_root = repository_root.resolve(strict=True)
    expected_path = (repository_root / CONTRACT_RELATIVE).resolve(strict=True)
    require(contract_path.resolve(strict=True) == expected_path, "exact execution contract required")
    contract = load_json(expected_path)
    expected_fields = {
        "schema",
        "task",
        "batch",
        "direction",
        "process",
        "phase",
        "branch",
        "authorityBaseCommit",
        "publicationCommit",
        "claim",
        "prelaunchAuthority",
        "familyContract",
        "scheduleAdapter",
        "frozenNorthV12Inputs",
        "launcher",
        "childEntrypoint",
        "tests",
        "blender",
        "cycles",
        "processEnvelope",
        "processOutputRoot",
        "capabilityChannel",
        "allowedProcessOutputs",
        "prohibitedSurfaces",
        "sourceAuthority",
        "candidateReadyForIndependentReview",
        "productionSelected",
    }
    require(set(contract) == expected_fields, "execution contract fields drift")
    exact = {
        "schema": 1,
        "task": "PLAY-027",
        "batch": "industrial_l04_directional_family",
        "direction": "north",
        "process": "A",
        "phase": "prelock_north_a",
        "branch": "codex/citysim-world-art",
        "authorityBaseCommit": "ffb3db1a35aec5067a07a5405ee721ff379ecd51",
        "publicationCommit": "2eb5ddcb97a84376d66a008f8a7ad6ab3c97209b",
        "processOutputRoot": (
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
            "blender-north-art-v12/process-a-execution-v01/process-a"
        ),
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    for field, value in exact.items():
        require(contract[field] == value, f"execution contract drift: {field}")
    expected_bindings = {
        "claim": (
            "docs/production/claims/PLAY-027.world-art.md",
            "b7eb42ccacf323a3149a4c25faa587a0e6557afb6784d08e19fbe9d108e9434a",
        ),
        "prelaunchAuthority": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-NORTH-V12-PROCESS-A-PRELAUNCH-AUTHORITY.md",
            "889fd6f87a0d7eb112fe392d66901e927658a86a6d3aa311e53178d61cb4725e",
        ),
        "familyContract": (
            "docs/production/decisions/CONTRACT-010-directional-building-art.md",
            "0ee2d68a9dba4694d92a864bfeb5a91970c88fe87d893e1898de7b26d38609af",
        ),
    }
    for label, (path, digest) in expected_bindings.items():
        verify_binding(
            repository_root,
            contract[label],
            label,
            expected_path=path,
            expected_sha256=digest,
        )
    adapter = contract["scheduleAdapter"]
    require(
        isinstance(adapter, dict)
        and set(adapter) == {"contract", "consumer", "acceptedReadiness"},
        "schedule-adapter inventory drift",
    )
    for label, binding in adapter.items():
        verify_binding(repository_root, binding, f"scheduleAdapter.{label}")
    frozen = contract["frozenNorthV12Inputs"]
    require(
        isinstance(frozen, dict)
        and set(frozen)
        == {
            "scene",
            "materials",
            "loweringContract",
            "lowerer",
            "importer",
            "acceptedStaticBContract",
        },
        "frozen input inventory drift",
    )
    for label, binding in frozen.items():
        verify_binding(repository_root, binding, f"frozenNorthV12Inputs.{label}")
    verify_binding(
        repository_root,
        contract["launcher"],
        "launcher",
        expected_path=str(LAUNCHER_RELATIVE),
    )
    verify_binding(repository_root, contract["childEntrypoint"], "childEntrypoint")
    verify_binding(repository_root, contract["tests"], "tests")
    blender = contract["blender"]
    require(
        blender
        == {
            "executable": "/Applications/Blender.app/Contents/MacOS/Blender",
            "executableSHA256": "8485107307b16bd0899f3c259261494b0c80e383db239c04e2c9fcd14d305fb4",
            "version": "4.5.12 LTS",
            "buildHash": "84afd5f785f7",
            "factoryStartup": True,
            "autoexecDisabled": True,
            "pythonExitCode": 1,
        },
        "Blender contract drift",
    )
    require(contract["cycles"]["threads"] == 1, "Cycles thread cap drift")
    require(
        contract["allowedProcessOutputs"]
        == [
            "CHILD-GRANT.json",
            "GROUND-PROJECTION.json",
            "INPUT-BINDINGS.json",
            "OBJECT-MANIFEST.json",
            "PROCESS-RECEIPT.json",
            "provenance.json",
            "raw.png",
            "semantic.png",
        ],
        "allowed Process-A output inventory drift",
    )
    require(
        contract["capabilityChannel"]
        == {
            "type": "inherited-anonymous-pipe",
            "oneUse": True,
            "parentPIDBound": True,
            "payloadMaximumBytes": 8192,
            "hashAlgorithm": "SHA-256",
        },
        "launcher capability channel drift",
    )
    envelope = contract["processEnvelope"]
    require(
        envelope
        == {
            "maximumChildStarts": 1,
            "maximumConcurrentDCCProcesses": 1,
            "timeoutSeconds": 120,
            "maximumProcessGroupRSSMiB": 1024,
            "newProcessGroup": True,
            "killProcessGroupOnViolation": True,
        },
        "process envelope drift",
    )
    require_ancestor(repository_root, contract["authorityBaseCommit"], "authorityBaseCommit")
    require_ancestor(repository_root, contract["publicationCommit"], "publicationCommit")
    require(
        git_check(repository_root, ["branch", "--show-current"]) == contract["branch"],
        "attached branch mismatch",
    )
    return contract


def validate_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    requested: Path,
    *,
    exists: Callable[[Path], bool] = os.path.lexists,
) -> Path:
    expected = (repository_root / contract["processOutputRoot"]).absolute()
    lexical = requested.absolute()
    require(lexical == expected, "exact Process-A output root required")
    require(lexical.is_relative_to(repository_root), "Process-A output escapes repository")
    current = repository_root
    for component in lexical.relative_to(repository_root).parts:
        current = current / component
        require(not current.is_symlink(), "Process-A output path contains a symlink")
    require(not exists(lexical), "Process-A output root already exists")
    return lexical


def validate_grant_plan(
    contract: dict[str, Any],
    grant: dict[str, Any],
    requested_output: Path,
    repository_root: Path,
    *,
    requested_process: str = "A",
    requested_child_starts: int = 1,
    output_exists: Callable[[Path], bool] = os.path.lexists,
) -> dict[str, Any]:
    require(grant.get("grantValidated") is True, "schedule grant is not validated")
    require(grant.get("processStarted") is False, "schedule grant was already consumed")
    require(grant.get("task") == contract["task"], "grant task drift")
    require(grant.get("batch") == contract["batch"], "grant batch drift")
    require(grant.get("phase") == contract["phase"], "grant phase drift")
    require(grant.get("direction") == contract["direction"], "grant direction drift")
    require(requested_process == contract["process"], "only North Process A is supported")
    require(grant.get("process") == requested_process, "grant process drift")
    require(grant.get("slotId") == "dcc-1", "grant slot drift")
    require(grant.get("maximumChildStarts") == 1, "grant child limit drift")
    require(requested_child_starts == 1, "exactly one child start required")
    require(grant.get("directLowLevelInvocationAllowed") is False, "low-level bypass enabled")
    require(grant.get("claimSHA256") == contract["claim"]["sha256"], "grant claim drift")
    require(
        grant.get("publishedBaseCommit") == contract["authorityBaseCommit"],
        "grant base drift",
    )
    require(
        grant.get("exclusiveRoots")
        == [
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12",
            "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12",
        ],
        "grant root drift",
    )
    require(grant.get("orchestrator") == contract["launcher"], "grant orchestrator drift")
    require(
        grant.get("frozenNorthV12Inputs") == contract["frozenNorthV12Inputs"],
        "grant frozen-input drift",
    )
    output_root = validate_output_root(
        repository_root,
        contract,
        requested_output,
        exists=output_exists,
    )
    return {
        "grant": grant,
        "outputRoot": str(output_root.relative_to(repository_root)),
        "requestedChildStarts": 1,
        "validated": True,
    }


def build_child_command(
    repository_root: Path,
    contract_path: Path,
    contract: dict[str, Any],
    output_root: Path,
    child_grant_path: Path,
    capability_read_fd: int,
) -> list[str]:
    return [
        contract["blender"]["executable"],
        "--background",
        "--factory-startup",
        "--disable-autoexec",
        "--threads",
        "1",
        "--python-exit-code",
        "1",
        "--python",
        str(repository_root / contract["childEntrypoint"]["path"]),
        "--",
        "--repository-root",
        str(repository_root),
        "--contract",
        str(contract_path),
        "--output-root",
        str(output_root),
        "--child-grant",
        str(child_grant_path),
        "--capability-fd",
        str(capability_read_fd),
    ]


def process_group_snapshot(process_group_id: int) -> list[dict[str, int]]:
    result = subprocess.run(
        ["/bin/ps", "-axo", "pid=,pgid=,rss="],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise LaunchError("process-group RSS sampling failed")
    members = []
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) == 3 and int(fields[1]) == process_group_id:
            members.append({"pid": int(fields[0]), "rssKiB": int(fields[2])})
    return sorted(members, key=lambda item: item["pid"])


def terminal_rss_kib(usage: Any) -> int:
    require(sys.platform == "darwin", "Process-A resource model requires Darwin")
    value = getattr(usage, "ru_maxrss", None)
    require(isinstance(value, int) and value > 0, "terminal ru_maxrss is unavailable")
    return (value + 1023) // 1024


def verify_blender_executable(contract: dict[str, Any]) -> Path:
    path = Path(contract["blender"]["executable"])
    require(path.is_absolute(), "Blender executable must be absolute")
    require(not path.is_symlink(), "Blender executable must not be a symlink")
    require(path.is_file(), "Blender executable is missing")
    require(
        sha256(path) == contract["blender"]["executableSHA256"],
        "Blender executable bytes drift",
    )
    return path


def terminate_group(process_group_id: int) -> None:
    try:
        os.killpg(process_group_id, signal.SIGTERM)
    except ProcessLookupError:
        return
    time.sleep(0.2)
    try:
        os.killpg(process_group_id, signal.SIGKILL)
    except ProcessLookupError:
        pass


def enforce_resource_observation(
    process_group_id: int,
    *,
    elapsed_seconds: float,
    sampled_peak_rss_kib: int,
    maximum_seconds: float,
    maximum_rss_kib: int,
    observed_extra_members: set[int],
    terminate: Callable[[int], None] = terminate_group,
) -> str | None:
    reason = None
    if elapsed_seconds > maximum_seconds:
        reason = "timeout"
    elif sampled_peak_rss_kib > maximum_rss_kib:
        reason = "rss-limit"
    elif observed_extra_members:
        reason = "unexpected-process-group-member"
    if reason is not None:
        terminate(process_group_id)
    return reason


def write_exclusive(path: Path, value: Any) -> None:
    descriptor = os.open(
        path,
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
        0o644,
    )
    try:
        payload = canonical_bytes(value)
        offset = 0
        while offset < len(payload):
            offset += os.write(descriptor, payload[offset:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def terminal_disposition(
    *,
    child_pid: int | None,
    return_code: int | None,
    termination_reason: str,
    launcher_exception: str | None,
    sampled_peak_rss_kib: int,
    terminal_peak_rss_kib: int,
    observed_extra_members: set[int],
    remaining_members: list[dict[str, int]],
) -> dict[str, Any]:
    return {
        "childPID": child_pid,
        "returnCode": return_code,
        "terminationReason": termination_reason,
        "sampledAggregateGroupPeakRSSKiB": sampled_peak_rss_kib,
        "terminalChildTreeMaxRSSKiB": terminal_peak_rss_kib,
        "enforcedPeakRSSKiB": max(
            sampled_peak_rss_kib,
            terminal_peak_rss_kib,
        ),
        "observedExtraProcessGroupMembers": sorted(observed_extra_members),
        "postReapProcessGroupMembers": remaining_members,
        "postReapProcessGroupExhausted": not remaining_members,
        "terminalWaitModel": "darwin-os.wait4-exact-pid",
        "launcherException": launcher_exception,
    }


def run_one_child(
    repository_root: Path,
    contract_path: Path,
    schedule_path: Path,
    output_root: Path,
) -> int:
    contract = validate_execution_contract(repository_root, contract_path)
    adapter_path = repository_root / contract["scheduleAdapter"]["consumer"]["path"]
    adapter = load_module(adapter_path, "play027_process_a_schedule_adapter")
    grant = adapter.consume_published_schedule(
        repository_root,
        repository_root / contract["scheduleAdapter"]["contract"]["path"],
        schedule_path,
    )
    plan = validate_grant_plan(contract, grant, output_root, repository_root)
    verify_blender_executable(contract)
    require(sys.platform == "darwin", "Process-A child launch requires Darwin")
    output_root.mkdir(parents=True, exist_ok=False)
    capability = secrets.token_hex(32)
    capability_read_fd, capability_write_fd = os.pipe()
    child_grant_path = output_root / "CHILD-GRANT.json"
    child_grant = {
        "schema": 1,
        "task": contract["task"],
        "direction": contract["direction"],
        "process": contract["process"],
        "grantId": grant["grantId"],
        "slotId": grant["slotId"],
        "schedulePath": str(schedule_path.relative_to(repository_root)),
        "scheduleSHA256": sha256(schedule_path),
        "contractSHA256": sha256(contract_path),
        "launcherSHA256": contract["launcher"]["sha256"],
        "launcherPID": os.getpid(),
        "childEntrypointSHA256": contract["childEntrypoint"]["sha256"],
        "outputRoot": plan["outputRoot"],
        "capabilitySHA256": sha256_bytes(capability.encode("utf-8")),
        "childStartCount": 1,
    }
    write_exclusive(child_grant_path, child_grant)
    command = build_child_command(
        repository_root,
        contract_path,
        contract,
        output_root,
        child_grant_path,
        capability_read_fd,
    )
    environment = os.environ.copy()
    environment.update(
        {
            "OMP_NUM_THREADS": "1",
            "OPENBLAS_NUM_THREADS": "1",
            "VECLIB_MAXIMUM_THREADS": "1",
        }
    )
    started = time.monotonic()
    sampled_peak_rss_kib = 0
    terminal_peak_rss_kib = 0
    observed_extra_members: set[int] = set()
    violation: str | None = None
    terminal_status: int | None = None
    terminal_usage: Any = None
    process: subprocess.Popen[bytes] | None = None
    process_pid: int | None = None
    return_code: int | None = None
    stdout = b""
    stderr = b""
    remaining_members: list[dict[str, int]] = []
    launcher_exception: str | None = None
    with tempfile.TemporaryFile() as stdout_file, tempfile.TemporaryFile() as stderr_file:
        try:
            process = subprocess.Popen(
                command,
                cwd=repository_root,
                env=environment,
                stdout=stdout_file,
                stderr=stderr_file,
                start_new_session=True,
                pass_fds=(capability_read_fd,),
                close_fds=True,
            )
            process_pid = process.pid
            os.close(capability_read_fd)
            capability_read_fd = -1
            capability_payload = {
                "capability": capability,
                "grantId": grant["grantId"],
                "launcherPID": os.getpid(),
                "launcherSHA256": contract["launcher"]["sha256"],
                "scheduleSHA256": sha256(schedule_path),
            }
            os.write(capability_write_fd, canonical_bytes(capability_payload))
            os.close(capability_write_fd)
            capability_write_fd = -1
            while terminal_status is None:
                members = process_group_snapshot(process.pid)
                sampled_peak_rss_kib = max(
                    sampled_peak_rss_kib,
                    sum(member["rssKiB"] for member in members),
                )
                observed_extra_members.update(
                    member["pid"]
                    for member in members
                    if member["pid"] != process.pid
                )
                waited_pid, waited_status, waited_usage = os.wait4(
                    process.pid,
                    os.WNOHANG,
                )
                if waited_pid == process.pid:
                    terminal_status = waited_status
                    terminal_usage = waited_usage
                    process.returncode = os.waitstatus_to_exitcode(waited_status)
                    break
                elapsed = time.monotonic() - started
                violation = enforce_resource_observation(
                    process.pid,
                    elapsed_seconds=elapsed,
                    sampled_peak_rss_kib=sampled_peak_rss_kib,
                    maximum_seconds=float(
                        contract["processEnvelope"]["timeoutSeconds"]
                    ),
                    maximum_rss_kib=int(
                        contract["processEnvelope"]["maximumProcessGroupRSSMiB"]
                    )
                    * 1024,
                    observed_extra_members=observed_extra_members,
                )
                if violation is not None:
                    _, terminal_status, terminal_usage = os.wait4(process.pid, 0)
                    process.returncode = os.waitstatus_to_exitcode(terminal_status)
                    break
                time.sleep(0.05)
            terminal_peak_rss_kib = terminal_rss_kib(terminal_usage)
            enforced_peak_rss_kib = max(
                sampled_peak_rss_kib,
                terminal_peak_rss_kib,
            )
            if (
                violation is None
                and enforced_peak_rss_kib
                > int(contract["processEnvelope"]["maximumProcessGroupRSSMiB"])
                * 1024
            ):
                violation = "terminal-rss-limit"
            remaining_members = process_group_snapshot(process.pid)
            if violation is None and remaining_members:
                violation = "post-reap-process-group-not-empty"
                terminate_group(process.pid)
            return_code = process.returncode
        except BaseException as error:
            launcher_exception = f"{type(error).__name__}: {error}"
            violation = f"launcher-exception:{type(error).__name__}"
            if process is not None:
                terminate_group(process.pid)
                try:
                    _, terminal_status, terminal_usage = os.wait4(process.pid, 0)
                    process.returncode = os.waitstatus_to_exitcode(terminal_status)
                    return_code = process.returncode
                    terminal_peak_rss_kib = terminal_rss_kib(terminal_usage)
                except ChildProcessError:
                    return_code = process.returncode
                try:
                    remaining_members = process_group_snapshot(process.pid)
                except LaunchError:
                    remaining_members = []
        finally:
            for descriptor in (capability_read_fd, capability_write_fd):
                if descriptor >= 0:
                    try:
                        os.close(descriptor)
                    except OSError:
                        pass
            stdout_file.seek(0)
            stderr_file.seek(0)
            stdout = stdout_file.read()
            stderr = stderr_file.read()
    elapsed = time.monotonic() - started
    receipt = {
        "schema": 1,
        "task": contract["task"],
        "direction": contract["direction"],
        "process": contract["process"],
        "childStartCount": 1,
        "childArgv": command,
        "newProcessGroup": True,
        "elapsedSeconds": round(elapsed, 6),
        **terminal_disposition(
            child_pid=process_pid,
            return_code=return_code,
            termination_reason=violation
            or ("success" if return_code == 0 else "child-nonzero-exit"),
            launcher_exception=launcher_exception,
            sampled_peak_rss_kib=sampled_peak_rss_kib,
            terminal_peak_rss_kib=terminal_peak_rss_kib,
            observed_extra_members=observed_extra_members,
            remaining_members=remaining_members,
        ),
        "stdoutTail": stdout.decode("utf-8", errors="replace")[-4000:],
        "stderrTail": stderr.decode("utf-8", errors="replace")[-4000:],
        "renderAuthority": False,
        "sourceAuthority": False,
        "productionSelected": False,
    }
    write_exclusive(output_root / "PROCESS-RECEIPT.json", receipt)
    if violation is not None or return_code != 0:
        return 1
    return 0


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--schedule", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args()


def main() -> int:
    options = arguments()
    return run_one_child(
        Path(options.repository_root).resolve(strict=True),
        Path(options.contract),
        Path(options.schedule),
        Path(options.output_root),
    )


if __name__ == "__main__":
    sys.exit(main())
