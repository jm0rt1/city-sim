#!/usr/bin/env python3
"""No-DCC prelaunch proof for North v12 static-B confirmation v03."""

from __future__ import annotations

import argparse
import copy
import fcntl
import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable


sys.dont_write_bytecode = True
SOURCE_RELATIVE = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/blender-lowering-v01/"
    "static-b-confirmation-v03"
)
PRELAUNCH_RELATIVE = SOURCE_RELATIVE / "PRELAUNCH-VALIDATION.json"
AUTHORIZED_PENDING = {
    str(SOURCE_RELATIVE / "CONFIRMATION-CONTRACT.json"),
    str(SOURCE_RELATIVE / "launch_static_b_confirmation.py"),
    str(SOURCE_RELATIVE / "test_static_b_confirmation.py"),
    str(PRELAUNCH_RELATIVE),
}


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def load_launcher(repository_root: Path) -> Any:
    path = repository_root / SOURCE_RELATIVE / "launch_static_b_confirmation.py"
    specification = importlib.util.spec_from_file_location(
        "play027_static_b_confirmation_v03", path
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("static-B v03 launcher import failed")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def expect_failure(
    name: str,
    operation: Callable[[], None],
    fragment: str,
) -> dict[str, Any]:
    try:
        operation()
    except Exception as error:
        message = str(error)
        if fragment not in message:
            raise RuntimeError(
                f"{name}: expected {fragment!r}, got {message!r}"
            ) from error
        return {
            "name": name,
            "expectedFailure": fragment,
            "actualFailure": message,
            "passed": True,
        }
    raise RuntimeError(f"{name}: adversary was accepted")


def expect_reason(
    name: str,
    actual: str | None,
    expected: str,
) -> dict[str, Any]:
    if actual != expected:
        raise RuntimeError(
            f"{name}: expected reason {expected!r}, got {actual!r}"
        )
    return {
        "name": name,
        "expectedFailure": expected,
        "actualFailure": actual,
        "passed": True,
    }


def write_once(path: Path, value: Any, canonical: Callable[[Any], bytes]) -> None:
    if path.parent.is_symlink() or not path.parent.is_dir():
        raise RuntimeError("prelaunch parent drift")
    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL
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


def status_scope(
    launcher: Any,
    base: Any,
    repository_root: Path,
) -> dict[str, Any]:
    branch = base.git_output(repository_root, ["branch", "--show-current"])
    if branch != launcher.EXPECTED_BRANCH:
        raise RuntimeError(f"wrong branch: {branch}")
    ancestors = [
        launcher.EXPECTED_AUTHORITY_COMMIT,
        launcher.EXPECTED_FROZEN_V02_CANDIDATE,
        launcher.EXPECTED_STATIC_A_INTEGRATION,
    ]
    for commit in ancestors:
        base.assert_ancestor(repository_root, commit)
    entries = [
        line for line in base.git_output(
            repository_root,
            ["status", "--porcelain=v1", "--untracked-files=all"],
        ).splitlines()
        if line
    ]
    unexpected = [
        entry for entry in entries if entry[3:] not in AUTHORIZED_PENDING
    ]
    if unexpected:
        raise RuntimeError(f"unexpected worktree entry: {unexpected}")
    return {
        "branch": branch,
        "head": base.git_output(repository_root, ["rev-parse", "HEAD"]),
        "requiredAncestors": ancestors,
        "statusEntries": entries,
        "authorizedPendingPaths": sorted(AUTHORIZED_PENDING),
        "unexpectedStatusEntries": [],
        "cleanOutsideAuthorizedV03Paths": True,
        "passed": True,
    }


def terminal(
    launcher: Any,
    *,
    pid: int = 4242,
    status: int = 0,
    rss_bytes: Any = 64 * 1024 * 1024,
    platform_name: str = "darwin",
    consumed: bool = False,
) -> dict[str, Any]:
    return launcher.terminal_record_from_values(
        platform_name=platform_name,
        expected_pid=4242,
        waited_pid=pid,
        wait_status=status,
        ru_maxrss_bytes=rss_bytes,
        already_consumed=consumed,
    )


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    output = Path(options.output).absolute()
    expected_output = (repository_root / PRELAUNCH_RELATIVE).absolute()
    if output != expected_output:
        raise RuntimeError("exact static-B v03 prelaunch output required")
    if output.exists() or output.is_symlink():
        raise RuntimeError("static-B v03 prelaunch output must be absent")
    launcher = load_launcher(repository_root)
    static_a = launcher.load_static_a_launcher(repository_root)
    base = static_a.load_v01_launcher(repository_root)
    launcher.validate_platform(sys.platform)
    contract_path = Path(options.contract).resolve(strict=True)
    contract, v02_contract = launcher.validate_contract(
        repository_root, contract_path, base
    )
    context = status_scope(launcher, base, repository_root)
    frozen = launcher.verify_frozen_inputs(repository_root, contract, base)
    scan = launcher.dependency_scan(repository_root)
    static_a.ensure_no_python_path_environment()
    runtime_root = launcher.expected_output_root(
        repository_root, contract, "static-b"
    )
    evidence_root = runtime_root.parent
    base.ensure_absent_output_path(evidence_root)
    expected_command = launcher.build_child_command(
        repository_root,
        contract,
        contract_path,
        runtime_root,
        "static-b",
        static_a,
    )
    launcher.validate_child_command(expected_command, expected_command)
    expression = static_a.module_bootstrap_expression(repository_root)
    expression_index = expected_command.index("--python-expr")
    if expected_command[expression_index + 1] != expression:
        raise RuntimeError("module bootstrap expression drift")
    if expected_command[expression_index + 2] != "--python":
        raise RuntimeError("importer does not immediately follow bootstrap")

    accepted_bindings_path = (
        repository_root / launcher.STATIC_A_RESULT_RELATIVE
        / "INPUT-BINDINGS.json"
    )
    accepted_bindings = launcher.load_json(accepted_bindings_path)
    expected_static_b_bindings = copy.deepcopy(accepted_bindings)
    contract_canonical_sha = launcher.canonical_sha256(contract)
    expected_static_b_bindings["bindings"]["claim"]["sha256"] = (
        launcher.EXPECTED_CLAIM_SHA256
    )
    expected_static_b_bindings["contractSHA256"] = contract_canonical_sha
    pointer_proof = launcher.compare_input_bindings(
        accepted_bindings,
        expected_static_b_bindings,
        contract_canonical_sha,
    )

    cases: list[dict[str, Any]] = []
    changed = copy.deepcopy(contract["confirmation"])
    changed["authorityCommit"] = "0" * 40
    cases.append(expect_failure(
        "wrong-authority",
        lambda: launcher.validate_confirmation_values(changed),
        "static-B v03 authority binding drift",
    ))
    changed = copy.deepcopy(contract["confirmation"])
    changed["maximumChildStarts"] = 2
    cases.append(expect_failure(
        "multiple-child-starts",
        lambda: launcher.validate_confirmation_values(changed),
        "static-B v03 authority binding drift",
    ))
    changed = copy.deepcopy(contract["confirmation"])
    changed["terminalRSSUnit"] = "kib"
    cases.append(expect_failure(
        "wrong-terminal-rss-unit",
        lambda: launcher.validate_confirmation_values(changed),
        "static-B v03 authority binding drift",
    ))
    cases.append(expect_failure(
        "wrong-platform",
        lambda: launcher.validate_platform("linux"),
        "Darwin terminal-rusage contract required",
    ))
    cases.append(expect_failure(
        "wrong-terminal-pid",
        lambda: terminal(launcher, pid=4243),
        "terminal wait4 PID mismatch",
    ))
    cases.append(expect_failure(
        "twice-consumed-terminal-rusage",
        lambda: terminal(launcher, consumed=True),
        "terminal rusage consumed more than once",
    ))
    cases.append(expect_failure(
        "zero-terminal-rusage",
        lambda: terminal(launcher, rss_bytes=0),
        "terminal ru_maxrss must be positive bytes",
    ))
    cases.append(expect_failure(
        "negative-terminal-rusage",
        lambda: terminal(launcher, rss_bytes=-1),
        "terminal ru_maxrss must be positive bytes",
    ))
    cases.append(expect_failure(
        "malformed-terminal-rusage",
        lambda: terminal(launcher, rss_bytes="65536"),
        "terminal ru_maxrss malformed",
    ))
    cases.append(expect_failure(
        "missing-terminal-measurement",
        lambda: launcher.classify_terminal_resources(
            elapsed_seconds=1.0,
            sampled_aggregate_peak_kib=1,
            terminal=None,
            timeout_seconds=120.0,
            maximum_rss_kib=1024,
        ),
        "terminal resource measurement unavailable",
    ))

    cadence = launcher.cadence_metrics([0.0, 0.01, 0.16, 0.17])
    if (
        cadence["gapCountAboveWarning"] != 1
        or cadence["maximumObserverGapSeconds"] != 0.15
        or not cadence["warningOnly"]
    ):
        raise RuntimeError("150ms cadence-warning adversary failed")
    low_terminal = terminal(launcher, rss_bytes=32 * 1024)
    reason, enforced = launcher.classify_terminal_resources(
        elapsed_seconds=1.0,
        sampled_aggregate_peak_kib=16,
        terminal=low_terminal,
        timeout_seconds=120.0,
        maximum_rss_kib=64,
    )
    if reason is not None or enforced != 32:
        raise RuntimeError("low-RSS cadence-warning case did not pass")
    cases.append({
        "name": "150ms-observer-gap-low-rss-warning-only",
        "expectedFailure": None,
        "actualFailure": None,
        "cadence": cadence,
        "enforcedPeakRSSKiB": enforced,
        "passed": True,
    })

    high_terminal = terminal(launcher, rss_bytes=65 * 1024)
    reason, enforced = launcher.classify_terminal_resources(
        elapsed_seconds=1.0,
        sampled_aggregate_peak_kib=16,
        terminal=high_terminal,
        timeout_seconds=120.0,
        maximum_rss_kib=64,
    )
    cases.append(expect_reason(
        "hidden-terminal-child-tree-rss",
        reason,
        "terminal-enforced-rss-limit",
    ))
    if enforced != 65:
        raise RuntimeError("terminal child-tree high-water was not enforced")

    reason, _ = launcher.classify_terminal_resources(
        elapsed_seconds=120.001,
        sampled_aggregate_peak_kib=16,
        terminal=low_terminal,
        timeout_seconds=120.0,
        maximum_rss_kib=64,
    )
    cases.append(expect_reason(
        "terminal-timeout-after-observer-gap",
        reason,
        "terminal-per-process-timeout",
    ))
    if base.classify_limits(1.0, 65, 120.0, 64) != (
        "process-group-rss-limit"
    ):
        raise RuntimeError("online aggregate RSS adversary failed")
    cases.append({
        "name": "online-aggregate-rss-limit",
        "expectedFailure": "process-group-rss-limit",
        "actualFailure": "process-group-rss-limit",
        "passed": True,
    })

    nonzero = terminal(launcher, status=1 << 8)
    cases.append(expect_reason(
        "nonzero-child-status",
        launcher.classify_terminal_exit(nonzero),
        "child-nonzero-exit",
    ))
    signaled = terminal(launcher, status=15)
    cases.append(expect_reason(
        "signaled-child-status",
        launcher.classify_terminal_exit(signaled),
        "child-signaled",
    ))
    extra = launcher.classify_sampled_members(
        4242,
        [
            {"pid": 4242, "rssKiB": 16},
            {"pid": 4243, "rssKiB": 1},
        ],
    )
    if extra != [{"pid": 4243, "rssKiB": 1}]:
        raise RuntimeError("sampled extra-member adversary failed")
    cases.append({
        "name": "sampled-extra-process-group-member",
        "expectedFailure": "observed-extra-process-group-member",
        "actualFailure": "observed-extra-process-group-member",
        "passed": True,
    })
    cases.append(expect_reason(
        "post-reap-surviving-descendant",
        launcher.classify_post_reap_members(
            [{"pid": 4243, "rssKiB": 1}]
        ),
        "post-reap-process-group-not-exhausted",
    ))

    changed_command = list(expected_command)
    changed_command[expression_index + 1] += ";x=1"
    cases.append(expect_failure(
        "changed-bootstrap-expression",
        lambda: launcher.validate_child_command(
            changed_command, expected_command
        ),
        "fixed static-B v03 child argv drift",
    ))
    changed_command = list(expected_command)
    changed_command[-1] = "static-a"
    cases.append(expect_failure(
        "changed-child-process",
        lambda: launcher.validate_child_command(
            changed_command, expected_command
        ),
        "fixed static-B v03 child argv drift",
    ))
    changed_contract = copy.deepcopy(contract)
    changed_contract["claim"]["sha256"] = "0" * 64
    cases.append(expect_failure(
        "claim-hash-drift",
        lambda: launcher.verify_frozen_inputs(
            repository_root, changed_contract, base
        ),
        "hash drift",
    ))
    changed_contract = copy.deepcopy(contract)
    changed_contract["scene"]["sha256"] = "0" * 64
    cases.append(expect_failure(
        "scene-hash-drift",
        lambda: launcher.verify_frozen_inputs(
            repository_root, changed_contract, base
        ),
        "hash drift",
    ))
    changed_bindings = copy.deepcopy(expected_static_b_bindings)
    changed_bindings["bindings"]["scene"]["sha256"] = "0" * 64
    cases.append(expect_failure(
        "input-bindings-extra-value-difference",
        lambda: launcher.compare_input_bindings(
            accepted_bindings, changed_bindings, contract_canonical_sha
        ),
        "INPUT-BINDINGS differs outside the two-pointer allowlist",
    ))
    changed_bindings = copy.deepcopy(expected_static_b_bindings)
    changed_bindings["extra"] = True
    cases.append(expect_failure(
        "input-bindings-extra-key",
        lambda: launcher.compare_input_bindings(
            accepted_bindings, changed_bindings, contract_canonical_sha
        ),
        "INPUT-BINDINGS differs outside the two-pointer allowlist",
    ))

    with tempfile.TemporaryDirectory(
        prefix="citysim-play027-static-b-v03-",
        dir="/private/tmp",
    ) as temporary:
        root = Path(temporary)
        preexisting = root / "preexisting"
        preexisting.mkdir()
        cases.append(expect_failure(
            "reused-output-root",
            lambda: base.ensure_absent_output_path(preexisting),
            "recovery output root must be absent",
        ))
        cases.append(expect_failure(
            "second-child-start",
            lambda: base.ensure_absent_output_path(preexisting),
            "recovery output root must be absent",
        ))
        symlink = root / "symlink"
        symlink.symlink_to(preexisting, target_is_directory=True)
        cases.append(expect_failure(
            "symlink-output-root",
            lambda: base.ensure_absent_output_path(symlink),
            "recovery output root must be absent",
        ))
        lock_path = root / "lock"
        first_lock = base.acquire_lock(lock_path)
        try:
            cases.append(expect_failure(
                "lock-contention",
                lambda: base.acquire_lock(lock_path),
                "concurrency lock is busy",
            ))
        finally:
            fcntl.flock(first_lock, fcntl.LOCK_UN)
            os.close(first_lock)
        empty = root / "empty"
        empty.mkdir()
        cases.append(expect_failure(
            "missing-child-files",
            lambda: base.validate_child_inventory(empty, True),
            "static child inventory drift",
        ))
        image = root / "image"
        image.mkdir()
        (image / "raw.png").write_bytes(b"not-an-image")
        cases.append(expect_failure(
            "pixel-output",
            lambda: base.validate_child_inventory(image, False),
            "prohibited static output",
        ))
        blend = root / "blend"
        blend.mkdir()
        (blend / "scene.blend").write_bytes(b"not-a-blend")
        cases.append(expect_failure(
            "blend-output",
            lambda: base.validate_child_inventory(blend, False),
            "prohibited static output",
        ))
        cases.append(expect_failure(
            "repository-mutation",
            lambda: base.validate_status_entries(
                [" M Native/CitySimNative/Rendering/CityScene.swift"],
                str(evidence_root.relative_to(repository_root)),
            ),
            "repository mutation outside output root",
        ))

    truth = launcher.fixed_process_truth()
    if truth != {
        "childStartCount": 1,
        "staticBInvocationCount": 1,
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "blendFiles": [],
    }:
        raise RuntimeError("fixed process truth drift")
    cases.append({
        "name": "one-child-static-b-process-truth",
        "expected": truth,
        "actual": truth,
        "passed": True,
    })

    normalized = copy.deepcopy(contract)
    normalized["claim"] = copy.deepcopy(v02_contract["claim"])
    normalized["evidenceRoot"] = v02_contract["evidenceRoot"]
    normalized["confirmation"] = copy.deepcopy(
        v02_contract["confirmation"]
    )
    if normalized != v02_contract:
        raise RuntimeError("v03 contract normalization proof failed")
    source_hashes = {
        str(path.relative_to(repository_root)): launcher.sha256(path)
        for path in sorted(
            (repository_root / SOURCE_RELATIVE).iterdir(),
            key=lambda item: item.name,
        )
        if path.is_file()
    }
    result = {
        "schema": 1,
        "task": "PLAY-027",
        "attemptID": launcher.ATTEMPT_ID,
        "processID": "static-b",
        "authorityCommit": launcher.EXPECTED_AUTHORITY_COMMIT,
        "authoritySHA256": launcher.EXPECTED_AUTHORITY_SHA256,
        "claimSHA256": launcher.EXPECTED_CLAIM_SHA256,
        "repositoryContext": context,
        "contractFileSHA256": launcher.sha256(contract_path),
        "contractCanonicalSHA256": contract_canonical_sha,
        "contractDifference": {
            "allowedBindings": [
                "claim",
                "evidenceRoot",
                "confirmationAuthority",
            ],
            "normalizesExactlyToFrozenV02Contract": True,
        },
        "frozenInputHashes": frozen,
        "confirmationSourceFiles": source_hashes,
        "dependencyScan": scan,
        "darwinWait4Model": {
            "platform": sys.platform,
            "terminalWaitPrimitive": "os.wait4",
            "terminalRSSUnit": "bytes",
            "terminalRSSNormalization": "(ru_maxrssBytes+1023)//1024",
            "wait4IsSoleReapingAuthority": True,
            "terminalResourceMeasurementRequired": True,
            "aggregatePeakCoverage":
                launcher.AGGREGATE_PEAK_COVERAGE,
            "disclosedAggregateTransientMemberLimitation":
                launcher.AGGREGATE_TRANSIENT_MEMBER_LIMITATION,
        },
        "moduleBootstrap": {
            "pythonExpr": expression,
            "pythonExprCount": expected_command.count("--python-expr"),
            "importerImmediatelyFollowsBootstrap": True,
            "lowererSHA256": launcher.EXPECTED_LOWERER_SHA256,
            "importerSHA256": launcher.EXPECTED_IMPORTER_SHA256,
            "pythonPathEnvironmentUsed": False,
        },
        "fixedChildArgv": expected_command,
        "staticAComparisonContract": {
            "fiveRunNeutralFiles": launcher.RUN_NEUTRAL_HASHES,
            "inputBindings": pointer_proof,
        },
        "runtimeEnvelope": {
            "slot": "dcc-1",
            "maximumChildStarts": 1,
            "maximumConcurrency": 1,
            "timeoutSeconds": 120,
            "maximumProcessGroupRSSMiB": 1024,
            "observerSleepSeconds": launcher.SAMPLE_SLEEP_SECONDS,
            "observerGapWarningSeconds":
                launcher.CADENCE_WARNING_SECONDS,
            "outputTailMaximumBytes": base.MAXIMUM_TAIL_BYTES,
        },
        "runtimeEvidenceRoot": str(
            evidence_root.relative_to(repository_root)
        ),
        "runtimeOutputRoot": str(runtime_root.relative_to(repository_root)),
        "runtimeEvidenceRootAbsent": True,
        "adversarialCaseCount": len(cases),
        "adversaries": cases,
        "allAdversariesRejectedOrBounded": all(
            case["passed"] for case in cases
        ),
        "blenderChildStartCount": 0,
        "staticBInvocationCount": 0,
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "blendFiles": [],
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
        "validationPassed": True,
    }
    write_once(output, result, launcher.canonical_bytes)
    print(json.dumps({
        "adversarialCaseCount": len(cases),
        "allAdversariesRejectedOrBounded": True,
        "contractCanonicalSHA256": contract_canonical_sha,
        "darwinWait4ModelVerified": True,
        "output": str(output),
        "outputSHA256": launcher.sha256(output),
        "validationPassed": True,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
