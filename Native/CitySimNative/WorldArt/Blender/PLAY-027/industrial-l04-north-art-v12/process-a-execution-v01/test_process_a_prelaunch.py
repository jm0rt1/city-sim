#!/usr/bin/env python3
"""Zero-child adversarial proof for the North v12 Process-A execution boundary."""

from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import importlib.util
import json
import os
import subprocess
import tempfile
from pathlib import Path
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
EVIDENCE_RELATIVE = EVIDENCE_ROOT / "ZERO-CHILD-PRELAUNCH.json"


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_module(path: Path, name: str) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"{name} import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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


def write_exclusive(path: Path, value: Any, canonical: Callable[[Any], bytes]) -> None:
    path.parent.mkdir(parents=True, exist_ok=False)
    descriptor = os.open(
        path,
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
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
        "grantId": "fixture-north-A",
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


def name_calls(syntax: ast.Module, name: str) -> list[ast.Call]:
    return [
        node
        for node in ast.walk(syntax)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id == name
    ]


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    output = Path(options.output).absolute()
    expected_output = (repository_root / EVIDENCE_RELATIVE).absolute()
    if output != expected_output:
        raise RuntimeError("exact zero-child prelaunch output required")
    if output.exists() or output.is_symlink() or output.parent.exists():
        raise RuntimeError("zero-child prelaunch root must be absent")
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
    if positive["validated"] is not True:
        raise RuntimeError("positive grant plan did not validate")

    cases: list[dict[str, Any]] = []

    def grant_case(
        name: str,
        mutate: Callable[[dict[str, Any]], None],
        expected: str,
        *,
        requested_process: str = "A",
        child_starts: int = 1,
        output_exists: Callable[[Path], bool] = lambda _: False,
    ) -> None:
        changed = copy.deepcopy(grant)
        mutate(changed)
        cases.append(
            expect_failure(
                name,
                lambda: launcher.validate_grant_plan(
                    contract,
                    changed,
                    requested_output,
                    repository_root,
                    requested_process=requested_process,
                    requested_child_starts=child_starts,
                    output_exists=output_exists,
                ),
                expected,
            )
        )

    grant_case("unvalidated-grant", lambda item: item.update(grantValidated=False), "not validated")
    grant_case("reused-grant", lambda item: item.update(processStarted=True), "already consumed")
    grant_case("wrong-task", lambda item: item.update(task="PLAY-079"), "grant task drift")
    grant_case("wrong-batch", lambda item: item.update(batch="other"), "grant batch drift")
    grant_case("wrong-phase", lambda item: item.update(phase="postlock_abc"), "grant phase drift")
    grant_case("sibling-direction", lambda item: item.update(direction="east"), "grant direction drift")
    grant_case("process-b", lambda _: None, "only North Process A", requested_process="B")
    grant_case("process-c", lambda _: None, "only North Process A", requested_process="C")
    grant_case("wrong-grant-process", lambda item: item.update(process="B"), "grant process drift")
    grant_case("wrong-slot", lambda item: item.update(slotId="dcc-2"), "grant slot drift")
    grant_case(
        "wrong-grant-child-limit",
        lambda item: item.update(maximumChildStarts=2),
        "grant child limit drift",
    )
    grant_case("zero-child-request", lambda _: None, "exactly one child", child_starts=0)
    grant_case("extra-child-request", lambda _: None, "exactly one child", child_starts=2)
    grant_case(
        "low-level-bypass-enabled",
        lambda item: item.update(directLowLevelInvocationAllowed=True),
        "low-level bypass enabled",
    )
    grant_case("stale-claim", lambda item: item.update(claimSHA256="0" * 64), "grant claim drift")
    grant_case(
        "stale-base",
        lambda item: item.update(publishedBaseCommit=contract["publicationCommit"]),
        "grant base drift",
    )
    grant_case(
        "wrong-roots",
        lambda item: item.update(exclusiveRoots=["Native/wrong", "docs/wrong"]),
        "grant root drift",
    )
    grant_case(
        "wrong-orchestrator",
        lambda item: item.update(orchestrator=contract["scheduleAdapter"]["consumer"]),
        "grant orchestrator drift",
    )
    grant_case(
        "stale-frozen-input",
        lambda item: item["frozenNorthV12Inputs"]["scene"].update(sha256="0" * 64),
        "grant frozen-input drift",
    )
    grant_case(
        "reused-output-root",
        lambda _: None,
        "already exists",
        output_exists=lambda _: True,
    )

    adapter_path = repository_root / contract["scheduleAdapter"]["consumer"]["path"]
    adapter = load_module(adapter_path, "play027_prelaunch_adapter")
    adapter_test_path = (
        repository_root
        / ADAPTER_ROOT
        / "test_north_process_a_schedule_adapter.py"
    )
    adapter_test = load_module(adapter_test_path, "play027_prelaunch_adapter_test")
    cases.append(
        expect_failure(
            "missing-published-schedule",
            lambda: adapter.consume_published_schedule(
                repository_root,
                repository_root / contract["scheduleAdapter"]["contract"]["path"],
                repository_root
                / "docs/production/evidence/INTEGRATION/"
                "industrial-l04-prelock-north-a-schedule-v1.json",
            ),
            "MISSING_PUBLISHED_SCHEDULE",
        )
    )
    schedule_fixture = adapter_test.fixture(
        repository_root,
        adapter,
        adapter.load_json(
            repository_root / contract["scheduleAdapter"]["contract"]["path"]
        ),
    )
    schedule_fixture["computeEnvelope"]["queueOrder"] = []
    cases.append(
        expect_failure(
            "wrong-schedule-queue",
            lambda: adapter.validate_north_grant(
                repository_root,
                adapter.load_json(
                    repository_root
                    / contract["scheduleAdapter"]["contract"]["path"]
                ),
                schedule_fixture,
            ),
            "queue order drift",
        )
    )
    original_git_output = adapter.git_output
    try:
        adapter.git_output = (
            lambda _root, arguments:
            "?? docs/production/evidence/INTEGRATION/future-schedule.json"
            if arguments and arguments[0] == "status"
            else original_git_output(_root, arguments)
        )
        cases.append(
            expect_failure(
                "dirty-or-untracked-schedule",
                lambda: adapter.verify_published_schedule(
                    repository_root,
                    repository_root
                    / "docs/production/evidence/INTEGRATION/"
                    "industrial-l04-parallel-execution-schedule-schema-v1.json",
                    {"integrationAuthorityCommit": contract["publicationCommit"]},
                ),
                "worktree bytes are dirty",
            )
        )
    finally:
        adapter.git_output = original_git_output

    original_git_bytes = adapter.git_bytes
    try:
        adapter.git_bytes = lambda _root, _arguments: b"stale-published-bytes\n"
        cases.append(
            expect_failure(
                "stale-published-schedule-bytes",
                lambda: adapter.verify_published_schedule(
                    repository_root,
                    repository_root
                    / "docs/production/evidence/INTEGRATION/"
                    "industrial-l04-parallel-execution-schedule-schema-v1.json",
                    {"integrationAuthorityCommit": contract["publicationCommit"]},
                ),
                "schedule bytes are not frozen at authority commit",
            )
        )
    finally:
        adapter.git_bytes = original_git_bytes

    cases.append(
        expect_failure(
            "low-level-child-bypass",
            lambda: child.read_one_use_capability(-1),
            "inherited launcher capability fd missing",
        )
    )
    with tempfile.TemporaryFile() as forged_capability:
        forged_capability.write(
            launcher.canonical_bytes(
                {
                    "capability": "f" * 64,
                    "grantId": "forged",
                    "launcherPID": os.getpid(),
                    "launcherSHA256": contract["launcher"]["sha256"],
                    "scheduleSHA256": "0" * 64,
                }
            )
        )
        forged_capability.seek(0)
        cases.append(
            expect_failure(
                "forged-regular-file-capability",
                lambda: child.read_one_use_capability(forged_capability.fileno()),
                "anonymous pipe",
            )
        )
    cases.append(
        expect_failure(
            "unapproved-child-output",
            lambda: child.write_exclusive(
                Path("/private/tmp"),
                "shipping-atlas.png",
                {},
            ),
            "unapproved child output",
        )
    )

    launcher_syntax = source_ast(launcher_path)
    child_syntax = source_ast(child_path)
    popen_calls = attribute_calls(launcher_syntax, "Popen")
    if len(popen_calls) != 1:
        raise RuntimeError(f"exactly one Popen site required, found {len(popen_calls)}")
    start_new_session = [
        keyword.value.value
        for keyword in popen_calls[0].keywords
        if keyword.arg == "start_new_session"
        and isinstance(keyword.value, ast.Constant)
    ]
    if start_new_session != [True]:
        raise RuntimeError("Popen must create a new process group")
    pass_fds_present = any(keyword.arg == "pass_fds" for keyword in popen_calls[0].keywords)
    close_fds_true = any(
        keyword.arg == "close_fds"
        and isinstance(keyword.value, ast.Constant)
        and keyword.value.value is True
        for keyword in popen_calls[0].keywords
    )
    if not pass_fds_present or not close_fds_true:
        raise RuntimeError("Popen must inherit only the one-use capability pipe")
    if not attribute_calls(launcher_syntax, "killpg"):
        raise RuntimeError("process-group kill path missing")
    if len(attribute_calls(launcher_syntax, "pipe")) != 1:
        raise RuntimeError("exactly one anonymous capability pipe required")
    if len(attribute_calls(launcher_syntax, "wait4")) < 2:
        raise RuntimeError("exact-PID terminal wait4 path missing")
    if not name_calls(launcher_syntax, "verify_blender_executable"):
        raise RuntimeError("Blender executable-byte preflight missing")
    render_calls = [
        node
        for node in ast.walk(child_syntax)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == "render"
    ]
    if len(render_calls) != 2:
        raise RuntimeError(f"exactly two future render calls required, found {len(render_calls)}")
    if attribute_calls(child_syntax, "Popen") or "import subprocess" in child_path.read_text(
        encoding="utf-8"
    ):
        raise RuntimeError("child-side subprocess surface is forbidden")
    combined_source = (
        launcher_path.read_text(encoding="utf-8")
        + "\n"
        + child_path.read_text(encoding="utf-8")
    )
    forbidden_tokens = [
        token
        for token in (
            "import socket",
            "import urllib",
            "import requests",
            "ImageGen",
            "Package.swift",
            "Rendering/",
            "shipping atlas",
            "normalizer",
            "save_as_mainfile",
            "save_mainfile",
        )
        if token in combined_source
    ]
    if forbidden_tokens:
        raise RuntimeError(f"forbidden execution surface: {forbidden_tokens}")
    cases.append(
        {
            "name": "single-child-site-and-new-process-group",
            "popenSiteCount": len(popen_calls),
            "startNewSession": True,
            "passFdsPresent": pass_fds_present,
            "closeFds": True,
            "killProcessGroupPathPresent": True,
            "passed": True,
        }
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
    if timeout_reason != "timeout" or timeout_kills != [7001]:
        raise RuntimeError("instrumented timeout group-kill adversary failed")
    cases.append(
        {
            "name": "instrumented-timeout-kills-process-group",
            "terminationReason": timeout_reason,
            "terminatedProcessGroups": timeout_kills,
            "passed": True,
        }
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
    if rss_reason != "rss-limit" or rss_kills != [7002]:
        raise RuntimeError("instrumented RSS group-kill adversary failed")
    cases.append(
        {
            "name": "instrumented-rss-kills-process-group",
            "terminationReason": rss_reason,
            "terminatedProcessGroups": rss_kills,
            "passed": True,
        }
    )
    popen_failure = launcher.terminal_disposition(
        child_pid=None,
        return_code=None,
        termination_reason="launcher-exception:OSError",
        launcher_exception="OSError: injected Popen failure",
        sampled_peak_rss_kib=0,
        terminal_peak_rss_kib=0,
        observed_extra_members=set(),
        remaining_members=[],
    )
    sampler_failure = launcher.terminal_disposition(
        child_pid=7003,
        return_code=-15,
        termination_reason="launcher-exception:LaunchError",
        launcher_exception="LaunchError: injected sampler failure",
        sampled_peak_rss_kib=32,
        terminal_peak_rss_kib=64,
        observed_extra_members=set(),
        remaining_members=[],
    )
    if (
        popen_failure["terminationReason"] != "launcher-exception:OSError"
        or popen_failure["postReapProcessGroupExhausted"] is not True
        or sampler_failure["enforcedPeakRSSKiB"] != 64
        or sampler_failure["postReapProcessGroupExhausted"] is not True
    ):
        raise RuntimeError("instrumented terminal accounting adversary failed")
    cases.append(
        {
            "name": "instrumented-terminal-accounting",
            "popenFailure": popen_failure,
            "samplerFailure": sampler_failure,
            "passed": True,
        }
    )
    cases.append(
        {
            "name": "future-child-render-surface-bounded",
            "futureRenderCallCount": len(render_calls),
            "allowedChildOutputs": sorted(child.ALLOWED_CHILD_OUTPUTS),
            "forbiddenTokens": forbidden_tokens,
            "passed": True,
        }
    )

    status = subprocess.run(
        ["git", "status", "--porcelain=v1", "--untracked-files=all"],
        cwd=repository_root,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.splitlines()
    allowed_prefixes = {
        str(SOURCE_ROOT),
        str(ADAPTER_ROOT),
        str(EVIDENCE_ROOT),
        str(
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
            "blender-north-art-v12/process-a-schedule-adapter-v01"
        ),
    }
    unexpected = [
        line
        for line in status
        if line and not any(line[3:].startswith(prefix) for prefix in allowed_prefixes)
    ]
    if unexpected:
        raise RuntimeError(f"unexpected worktree entries: {unexpected}")

    result = {
        "schema": 1,
        "task": "PLAY-027",
        "batch": contract["batch"],
        "direction": contract["direction"],
        "process": contract["process"],
        "phase": contract["phase"],
        "branch": contract["branch"],
        "authorityBaseCommit": contract["authorityBaseCommit"],
        "publicationCommit": contract["publicationCommit"],
        "claim": contract["claim"],
        "prelaunchAuthority": contract["prelaunchAuthority"],
        "familyContract": contract["familyContract"],
        "scheduleAdapter": contract["scheduleAdapter"],
        "frozenNorthV12Inputs": contract["frozenNorthV12Inputs"],
        "executionContract": {
            "path": str(launcher.CONTRACT_RELATIVE),
            "sha256": sha256(contract_path),
        },
        "launcher": contract["launcher"],
        "childEntrypoint": contract["childEntrypoint"],
        "tests": {
            "path": str(test_path.relative_to(repository_root)),
            "sha256": sha256(test_path),
            "adversarialCaseCount": len(cases),
            "allPassed": all(case["passed"] for case in cases),
            "cases": cases,
        },
        "positiveGrantPlan": positive,
        "astProof": {
            "launcherPopenSiteCount": len(popen_calls),
            "newProcessGroup": True,
            "killProcessGroupPathPresent": True,
            "futureChildRenderCallCount": len(render_calls),
            "futureRenderCallsExecuted": 0,
        },
        "liveSchedule": {
            "present": False,
            "grantValidated": False,
            "disposition": "BLOCKED_PENDING_INTEGRATION_SCHEDULE_AND_EXECUTION_AUTHORITY",
        },
        "worktreeScope": {
            "allowedPrefixes": sorted(allowed_prefixes),
            "unexpectedEntries": [],
            "passed": True,
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
    write_exclusive(output, result, launcher.canonical_bytes)
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
