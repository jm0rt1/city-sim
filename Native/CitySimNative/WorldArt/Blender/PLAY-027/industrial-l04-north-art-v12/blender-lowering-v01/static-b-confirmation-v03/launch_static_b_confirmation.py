#!/usr/bin/env python3
"""Single-use Darwin wait4 launcher for North v12 static-B confirmation v03."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
import signal
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any


sys.dont_write_bytecode = True
SOURCE_RELATIVE = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/blender-lowering-v01"
)
V02_SOURCE_RELATIVE = SOURCE_RELATIVE / "static-b-confirmation-v02"
V03_SOURCE_RELATIVE = SOURCE_RELATIVE / "static-b-confirmation-v03"
CONTRACT_RELATIVE = V03_SOURCE_RELATIVE / "CONFIRMATION-CONTRACT.json"
LAUNCHER_RELATIVE = V03_SOURCE_RELATIVE / "launch_static_b_confirmation.py"
TEST_RELATIVE = V03_SOURCE_RELATIVE / "test_static_b_confirmation.py"
PRELAUNCH_RELATIVE = V03_SOURCE_RELATIVE / "PRELAUNCH-VALIDATION.json"
V02_CONTRACT_RELATIVE = V02_SOURCE_RELATIVE / "CONFIRMATION-CONTRACT.json"
V02_LAUNCHER_RELATIVE = (
    V02_SOURCE_RELATIVE / "launch_static_b_confirmation.py"
)
V02_PRELAUNCH_RELATIVE = V02_SOURCE_RELATIVE / "PRELAUNCH-VALIDATION.json"
STATIC_A_SOURCE_RELATIVE = SOURCE_RELATIVE / "static-a-recovery-v02"
STATIC_A_LAUNCHER_RELATIVE = (
    STATIC_A_SOURCE_RELATIVE / "launch_static_a_module_bootstrap.py"
)
STATIC_A_CONTRACT_RELATIVE = (
    STATIC_A_SOURCE_RELATIVE / "RECOVERY-CONTRACT.json"
)
IMPORTER_RELATIVE = SOURCE_RELATIVE / "import_v12_scene.py"
LOWERER_RELATIVE = SOURCE_RELATIVE / "lower_v12_scene.py"
AUTHORITY_RELATIVE = Path(
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-NORTH-V12-STATIC-B-CONFIRMATION-V03-AUTHORITY.md"
)
V02_FAILURE_RELATIVE = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12/blender-lowering-v01/"
    "static-b-confirmation-v02/static-b/FAILURE.json"
)
STATIC_A_RESULT_RELATIVE = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12/blender-lowering-v01/"
    "static-a-recovery-v02/static-a"
)
EXPECTED_BRANCH = "codex/citysim-world-art"
EXPECTED_AUTHORITY_COMMIT = "fcfad4602aef55d2decd8eb2153401a8e5ef1b3c"
EXPECTED_FROZEN_V02_CANDIDATE = (
    "81d51486fb2086e26ab08dd200221c5eb8d79edb"
)
EXPECTED_STATIC_A_INTEGRATION = (
    "28103902a75c8232644a998a34dcaf33ca643a63"
)
EXPECTED_AUTHORITY_SHA256 = (
    "a98127463947994c6c9e42517f1ed407b47d3bf6cf7790fc7ee2a461bfc4db3d"
)
EXPECTED_CLAIM_SHA256 = (
    "21495a4a19918ae68f14da1a90f33145a09b94942f9a9ea54f6475fb484d2890"
)
EXPECTED_V02_FAILURE_SHA256 = (
    "34c454159295426cdfe3cee4c92247e0432646947e2487e45464d5ff984144b2"
)
EXPECTED_V02_CONTRACT_FILE_SHA256 = (
    "61207d78d9106cd0b3b0b954ca3ef8c56f00171d6809b671b0b386d988a1e438"
)
EXPECTED_V02_CONTRACT_CANONICAL_SHA256 = (
    "b2feff7fc8ca4e97d667a21300ed332222b159bbdfd13fa00a905d2a7336c434"
)
EXPECTED_V02_LAUNCHER_SHA256 = (
    "fdf8e0dcd34634f6a749018de3a987594f252b4ef71ccc05d09c7618f4a09910"
)
EXPECTED_V02_PRELAUNCH_SHA256 = (
    "96f92149867820d9b515baf36c010919d104a952c5ce1bf5037d17b39b1c55d2"
)
EXPECTED_STATIC_A_CONTRACT_FILE_SHA256 = (
    "af55da8df7b5152c361c9e23ca9c3c5ad5b2231c62609add8b1b10712b30daef"
)
EXPECTED_STATIC_A_CONTRACT_CANONICAL_SHA256 = (
    "c3cf003c8c123d2fdcad1d2c04f4ae0f450b41ab80f4dcb4b5e056f6835df6e7"
)
EXPECTED_STATIC_A_LAUNCHER_SHA256 = (
    "375b1ad679a99c683fd06e50227737fb48198f1899ea6a8f0d269eda9f289f3e"
)
EXPECTED_STATIC_A_CLAIM_SHA256 = (
    "83fa2894bd822c5b7b25d8da37903dec5f039b30fc334f7b59ca3d8eba82bf0d"
)
EXPECTED_STATIC_A_INPUT_BINDINGS_SHA256 = (
    "ee3691ffc5a8a817d35913e4359a66f0efb12042ab505f1f95b2b2c9c7bd3e1c"
)
EXPECTED_LOWERER_SHA256 = (
    "7dc01ddc56bfff3ee9efca417ad0f70265d92daf99281dd53f7231c691e53a42"
)
EXPECTED_IMPORTER_SHA256 = (
    "ec726d584ce4b22253fca486e82bc6a198616debed94358d76f6dac7a1f62988"
)
RUN_NEUTRAL_HASHES = {
    "BLENDER-OBJECT-MANIFEST.json":
        "213ab497191808992b70459dcae25aa3ebd9a902c094a6fc225a24e57b0a5d69",
    "MATERIAL-MANIFEST.json":
        "c66bc0796c57581dc4dac629b6947b0d5ab4a515213165b8c8d5fcc992d80e88",
    "PROJECTION.json":
        "b5e1d6d88e03b940fb20725ddb8b18dce9ce52a6b72f332975f76f8bed79c11e",
    "TOPOLOGY.json":
        "8ad251808663f3daac85af7a0df388306f790af017e4e6d9b93ee3f7e9e51c8f",
    "VALIDATION.json":
        "9250eb7a26659e9c91c3a0debb9ad6de8be78d104e1cbd15ebfba6d3ed755ff2",
}
ALLOWED_INPUT_BINDING_POINTERS = (
    "/bindings/claim/sha256",
    "/contractSHA256",
)
ATTEMPT_ID = "industrial-l04-north-v12-static-b-confirmation-v03"
CADENCE_WARNING_SECONDS = 0.05
SAMPLE_SLEEP_SECONDS = 0.01
AGGREGATE_PEAK_COVERAGE = (
    "sampled_with_terminal_child_tree_high_water"
)
AGGREGATE_TRANSIENT_MEMBER_LIMITATION = (
    "ru_maxrss_is_not_maximum_simultaneous_process_group_sum;"
    "a_short_lived_unobserved_extra_member_below_the_individual_cap_may_escape"
)


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"JSON object required: {path}")
    return value


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--process-id", required=True)
    return parser.parse_args()


def load_module(path: Path, name: str, expected_hash: str) -> Any:
    if sha256(path) != expected_hash:
        raise RuntimeError(f"frozen module hash drift: {path}")
    specification = importlib.util.spec_from_file_location(name, path)
    if specification is None or specification.loader is None:
        raise RuntimeError(f"frozen module import failed: {path}")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def load_static_a_launcher(repository_root: Path) -> Any:
    return load_module(
        repository_root / STATIC_A_LAUNCHER_RELATIVE,
        "play027_static_a_module_bootstrap_v02_for_static_b_v03",
        EXPECTED_STATIC_A_LAUNCHER_SHA256,
    )


def expected_confirmation_block() -> dict[str, Any]:
    return {
        "authorityCommit": EXPECTED_AUTHORITY_COMMIT,
        "authorityFile": str(AUTHORITY_RELATIVE),
        "authoritySHA256": EXPECTED_AUTHORITY_SHA256,
        "frozenV02Candidate": EXPECTED_FROZEN_V02_CANDIDATE,
        "frozenV02Failure": {
            "file": str(V02_FAILURE_RELATIVE),
            "sha256": EXPECTED_V02_FAILURE_SHA256,
        },
        "acceptedStaticARoot": str(STATIC_A_RESULT_RELATIVE),
        "acceptedStaticAInputBindingsSHA256":
            EXPECTED_STATIC_A_INPUT_BINDINGS_SHA256,
        "acceptedStaticAContractCanonicalSHA256":
            EXPECTED_STATIC_A_CONTRACT_CANONICAL_SHA256,
        "acceptedStaticAClaimSHA256": EXPECTED_STATIC_A_CLAIM_SHA256,
        "allowedInputBindingDifferences":
            list(ALLOWED_INPUT_BINDING_POINTERS),
        "platform": "darwin",
        "terminalWaitPrimitive": "os.wait4",
        "terminalRSSUnit": "bytes",
        "terminalRSSNormalization": "(ru_maxrssBytes+1023)//1024",
        "aggregatePeakCoverage": AGGREGATE_PEAK_COVERAGE,
        "observerSleepSeconds": SAMPLE_SLEEP_SECONDS,
        "observerGapWarningSeconds": CADENCE_WARNING_SECONDS,
        "slot": "dcc-1",
        "attemptID": ATTEMPT_ID,
        "allowedProcessID": "static-b",
        "maximumChildStarts": 1,
    }


def validate_confirmation_values(value: Any) -> None:
    if value != expected_confirmation_block():
        raise RuntimeError("static-B v03 authority binding drift")


def validate_platform(platform_name: str) -> None:
    if platform_name != "darwin":
        raise RuntimeError("Darwin terminal-rusage contract required")
    if not hasattr(os, "wait4") or not hasattr(os, "WNOHANG"):
        raise RuntimeError("os.wait4 terminal accounting unavailable")


def validate_contract(
    repository_root: Path,
    contract_path: Path,
    base: Any,
) -> tuple[dict[str, Any], dict[str, Any]]:
    expected = (repository_root / CONTRACT_RELATIVE).resolve(strict=True)
    actual = base.exact_regular(
        contract_path, confinement_root=repository_root
    )
    if actual != expected:
        raise RuntimeError("exact static-B v03 contract required")
    v02_path = base.exact_regular(
        repository_root / V02_CONTRACT_RELATIVE,
        EXPECTED_V02_CONTRACT_FILE_SHA256,
        repository_root,
    )
    v02 = load_json(v02_path)
    if canonical_sha256(v02) != EXPECTED_V02_CONTRACT_CANONICAL_SHA256:
        raise RuntimeError("frozen v02 canonical contract hash drift")
    contract = load_json(actual)
    validate_confirmation_values(contract.get("confirmation"))
    comparison = copy.deepcopy(contract)
    comparison["claim"] = copy.deepcopy(v02["claim"])
    comparison["evidenceRoot"] = v02["evidenceRoot"]
    comparison["confirmation"] = copy.deepcopy(v02["confirmation"])
    if comparison != v02:
        raise RuntimeError(
            "static-B v03 contract differs beyond claim, root, and authority"
        )
    if contract["claim"]["sha256"] != EXPECTED_CLAIM_SHA256:
        raise RuntimeError("current claim binding drift")
    return contract, v02


def verify_frozen_inputs(
    repository_root: Path,
    contract: dict[str, Any],
    base: Any,
) -> dict[str, str]:
    result = base.verify_frozen_inputs(repository_root, contract)
    additions = {
        "staticBConfirmationV03Authority": (
            AUTHORITY_RELATIVE, EXPECTED_AUTHORITY_SHA256
        ),
        "frozenV02Contract": (
            V02_CONTRACT_RELATIVE, EXPECTED_V02_CONTRACT_FILE_SHA256
        ),
        "frozenV02Launcher": (
            V02_LAUNCHER_RELATIVE, EXPECTED_V02_LAUNCHER_SHA256
        ),
        "frozenV02Prelaunch": (
            V02_PRELAUNCH_RELATIVE, EXPECTED_V02_PRELAUNCH_SHA256
        ),
        "frozenV02Failure": (
            V02_FAILURE_RELATIVE, EXPECTED_V02_FAILURE_SHA256
        ),
        "acceptedStaticAContract": (
            STATIC_A_CONTRACT_RELATIVE,
            EXPECTED_STATIC_A_CONTRACT_FILE_SHA256,
        ),
        "acceptedStaticALauncher": (
            STATIC_A_LAUNCHER_RELATIVE,
            EXPECTED_STATIC_A_LAUNCHER_SHA256,
        ),
        "frozenImporter": (
            IMPORTER_RELATIVE, EXPECTED_IMPORTER_SHA256
        ),
        "frozenLowerer": (
            LOWERER_RELATIVE, EXPECTED_LOWERER_SHA256
        ),
    }
    for key, (relative, expected) in additions.items():
        result[key] = sha256(
            base.exact_regular(
                repository_root / relative, expected, repository_root
            )
        )
    static_a_root = base.exact_directory(
        repository_root / STATIC_A_RESULT_RELATIVE, repository_root
    )
    for name, expected in RUN_NEUTRAL_HASHES.items():
        result[f"acceptedStaticA:{name}"] = sha256(
            base.exact_regular(
                static_a_root / name, expected, repository_root
            )
        )
    result["acceptedStaticA:INPUT-BINDINGS.json"] = sha256(
        base.exact_regular(
            static_a_root / "INPUT-BINDINGS.json",
            EXPECTED_STATIC_A_INPUT_BINDINGS_SHA256,
            repository_root,
        )
    )
    return result


def validate_context(
    repository_root: Path,
    base: Any,
    allowed_root: Path | None = None,
) -> dict[str, Any]:
    branch = base.git_output(repository_root, ["branch", "--show-current"])
    if branch != EXPECTED_BRANCH:
        raise RuntimeError(f"wrong branch: {branch}")
    ancestors = [
        EXPECTED_AUTHORITY_COMMIT,
        EXPECTED_FROZEN_V02_CANDIDATE,
        EXPECTED_STATIC_A_INTEGRATION,
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
    allowed = (
        str(allowed_root.relative_to(repository_root))
        if allowed_root is not None else None
    )
    base.validate_status_entries(entries, allowed)
    return {
        "branch": branch,
        "head": base.git_output(repository_root, ["rev-parse", "HEAD"]),
        "requiredAncestors": ancestors,
        "statusEntries": entries,
        "unexpectedStatusEntries": [],
        "passed": True,
    }


def dependency_scan(repository_root: Path) -> dict[str, Any]:
    files = (
        repository_root / IMPORTER_RELATIVE,
        repository_root / LOWERER_RELATIVE,
        repository_root / V02_LAUNCHER_RELATIVE,
        repository_root / LAUNCHER_RELATIVE,
        repository_root / TEST_RELATIVE,
    )
    forbidden = (
        "bpy.ops.render", "render.filepath", "save_as_mainfile",
        "save_mainfile", "bpy.data.images", "import socket", "import urllib",
        "import requests", "eval(",
    )
    findings = []
    for path in files[:2]:
        text = path.read_text(encoding="utf-8")
        for token in forbidden:
            if token in text:
                findings.append({
                    "file": str(path.relative_to(repository_root)),
                    "token": token,
                })
    if findings:
        raise RuntimeError(f"forbidden dependency token: {findings}")
    return {
        "files": [
            {
                "file": str(path.relative_to(repository_root)),
                "sha256": sha256(path),
            }
            for path in files
        ],
        "forbiddenFindings": [],
        "passed": True,
    }


def expected_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    process_id: str,
) -> Path:
    if process_id != "static-b":
        raise RuntimeError("only static-B is authorized")
    return (repository_root / contract["evidenceRoot"] / process_id).absolute()


def create_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    process_id: str,
    requested: Path,
    base: Any,
) -> Path:
    expected = expected_output_root(repository_root, contract, process_id)
    if requested.absolute() != expected:
        raise RuntimeError("exact static-B v03 output root required")
    expected.relative_to(repository_root)
    base.assert_nofollow_chain(expected, repository_root)
    base.ensure_absent_output_path(expected)
    evidence_root = expected.parent
    base.ensure_absent_output_path(evidence_root)
    parent = base.exact_directory(evidence_root.parent, repository_root)
    os.mkdir(evidence_root, mode=0o755)
    created_parent = base.exact_directory(evidence_root, repository_root)
    if created_parent.parent != parent:
        raise RuntimeError("static-B v03 evidence parent drift")
    os.mkdir(expected, mode=0o755)
    return base.exact_directory(expected, repository_root)


def build_child_command(
    repository_root: Path,
    contract: dict[str, Any],
    contract_path: Path,
    output_root: Path,
    process_id: str,
    static_a: Any,
) -> list[str]:
    expression = static_a.module_bootstrap_expression(repository_root)
    return [
        str(Path(contract["blender"]["executable"])),
        "--background",
        "--factory-startup",
        "--disable-autoexec",
        "--threads",
        "1",
        "--python-exit-code",
        "1",
        "--python-expr",
        expression,
        "--python",
        str((repository_root / IMPORTER_RELATIVE).resolve(strict=True)),
        "--",
        "--repository-root",
        str(repository_root),
        "--contract",
        str(contract_path),
        "--output-root",
        str(output_root),
        "--process-id",
        process_id,
    ]


def validate_child_command(actual: list[str], expected: list[str]) -> None:
    if actual != expected:
        raise RuntimeError("fixed static-B v03 child argv drift")
    if actual.count("--python-expr") != 1:
        raise RuntimeError("exactly one module bootstrap expression required")
    expression_index = actual.index("--python-expr")
    if actual[expression_index + 2] != "--python":
        raise RuntimeError("unchanged importer must immediately follow bootstrap")
    if actual.count("--python") != 1:
        raise RuntimeError("exactly one importer execution required")


def process_group_snapshot(process_group: int) -> list[dict[str, int]]:
    result = subprocess.run(
        ["/bin/ps", "-axo", "pid=,pgid=,rss="],
        check=True,
        capture_output=True,
        text=True,
    )
    members = []
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) != 3:
            continue
        pid, pgid, rss_kib = (int(value) for value in fields)
        if pgid == process_group:
            members.append({"pid": pid, "rssKiB": rss_kib})
    return sorted(members, key=lambda item: item["pid"])


def cadence_metrics(
    sample_times: list[float],
    warning_seconds: float = CADENCE_WARNING_SECONDS,
) -> dict[str, Any]:
    intervals = [
        sample_times[index] - sample_times[index - 1]
        for index in range(1, len(sample_times))
    ]
    warnings = [value for value in intervals if value > warning_seconds]
    return {
        "requestedSleepSeconds": SAMPLE_SLEEP_SECONDS,
        "warningThresholdSeconds": warning_seconds,
        "sampleCount": len(sample_times),
        "maximumObserverGapSeconds": round(max(intervals, default=0.0), 6),
        "gapCountAboveWarning": len(warnings),
        "totalGapDurationAboveWarningSeconds": round(sum(warnings), 6),
        "totalGapExcessAboveWarningSeconds": round(
            sum(value - warning_seconds for value in warnings), 6
        ),
        "warningOnly": bool(warnings),
    }


def terminal_record_from_values(
    *,
    platform_name: str,
    expected_pid: int,
    waited_pid: int,
    wait_status: int,
    ru_maxrss_bytes: Any,
    already_consumed: bool,
) -> dict[str, Any]:
    validate_platform(platform_name)
    if already_consumed:
        raise RuntimeError("terminal rusage consumed more than once")
    if waited_pid != expected_pid:
        raise RuntimeError("terminal wait4 PID mismatch")
    if isinstance(ru_maxrss_bytes, bool) or not isinstance(
        ru_maxrss_bytes, int
    ):
        raise RuntimeError("terminal ru_maxrss malformed")
    if ru_maxrss_bytes <= 0:
        raise RuntimeError("terminal ru_maxrss must be positive bytes")
    exit_code = os.waitstatus_to_exitcode(wait_status)
    return {
        "waitPrimitive": "os.wait4",
        "platform": "darwin",
        "waitedPID": waited_pid,
        "rawWaitStatus": wait_status,
        "exitCode": exit_code,
        "signaled": exit_code < 0,
        "ruMaxRSSUnit": "bytes",
        "ruMaxRSSBytes": ru_maxrss_bytes,
        "terminalChildTreeMaxRSSKiB":
            (ru_maxrss_bytes + 1023) // 1024,
        "consumedExactlyOnce": True,
        "available": True,
    }


def terminal_record_from_wait4(
    expected_pid: int,
    waited_pid: int,
    wait_status: int,
    usage: Any,
    already_consumed: bool,
) -> dict[str, Any]:
    if usage is None or not hasattr(usage, "ru_maxrss"):
        raise RuntimeError("terminal rusage missing")
    return terminal_record_from_values(
        platform_name=sys.platform,
        expected_pid=expected_pid,
        waited_pid=waited_pid,
        wait_status=wait_status,
        ru_maxrss_bytes=usage.ru_maxrss,
        already_consumed=already_consumed,
    )


def classify_terminal_resources(
    *,
    elapsed_seconds: float,
    sampled_aggregate_peak_kib: int,
    terminal: dict[str, Any] | None,
    timeout_seconds: float,
    maximum_rss_kib: int,
) -> tuple[str | None, int]:
    if terminal is None or not terminal.get("available"):
        raise RuntimeError("terminal resource measurement unavailable")
    terminal_peak = terminal.get("terminalChildTreeMaxRSSKiB")
    if isinstance(terminal_peak, bool) or not isinstance(terminal_peak, int):
        raise RuntimeError("terminal resource measurement malformed")
    if terminal_peak <= 0:
        raise RuntimeError("terminal resource measurement nonpositive")
    enforced = max(sampled_aggregate_peak_kib, terminal_peak)
    if elapsed_seconds > timeout_seconds:
        return "terminal-per-process-timeout", enforced
    if enforced > maximum_rss_kib:
        return "terminal-enforced-rss-limit", enforced
    return None, enforced


def classify_terminal_exit(terminal: dict[str, Any]) -> str | None:
    exit_code = terminal.get("exitCode")
    if isinstance(exit_code, bool) or not isinstance(exit_code, int):
        raise RuntimeError("terminal exit status malformed")
    if exit_code < 0:
        return "child-signaled"
    if exit_code != 0:
        return "child-nonzero-exit"
    return None


def classify_sampled_members(
    expected_pid: int,
    members: list[dict[str, int]],
) -> list[dict[str, int]]:
    return [
        member for member in members
        if member.get("pid") != expected_pid
    ]


def classify_post_reap_members(
    members: list[dict[str, int]],
) -> str | None:
    if members:
        return "post-reap-process-group-not-exhausted"
    return None


def fixed_process_truth() -> dict[str, Any]:
    return {
        "childStartCount": 1,
        "staticBInvocationCount": 1,
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "blendFiles": [],
    }


def compare_input_bindings(
    accepted: dict[str, Any],
    actual: dict[str, Any],
    expected_contract_sha: str,
) -> dict[str, Any]:
    expected = copy.deepcopy(accepted)
    expected["bindings"]["claim"]["sha256"] = EXPECTED_CLAIM_SHA256
    expected["contractSHA256"] = expected_contract_sha
    if actual != expected:
        raise RuntimeError(
            "INPUT-BINDINGS differs outside the two-pointer allowlist"
        )
    return {
        "allowedPointers": list(ALLOWED_INPUT_BINDING_POINTERS),
        "differences": [
            {
                "pointer": "/bindings/claim/sha256",
                "acceptedStaticA": EXPECTED_STATIC_A_CLAIM_SHA256,
                "staticB": EXPECTED_CLAIM_SHA256,
            },
            {
                "pointer": "/contractSHA256",
                "acceptedStaticA":
                    EXPECTED_STATIC_A_CONTRACT_CANONICAL_SHA256,
                "staticB": expected_contract_sha,
            },
        ],
        "strictRecursiveEqualityAfterSubstitution": True,
        "passed": True,
    }


def compare_static_results(
    repository_root: Path,
    contract: dict[str, Any],
    static_b_root: Path,
) -> dict[str, Any]:
    static_a_root = repository_root / STATIC_A_RESULT_RELATIVE
    file_results = []
    for name, expected_hash in RUN_NEUTRAL_HASHES.items():
        static_a = static_a_root / name
        static_b = static_b_root / name
        a_hash = sha256(static_a)
        b_hash = sha256(static_b)
        if a_hash != expected_hash or b_hash != expected_hash:
            raise RuntimeError(f"run-neutral byte identity failed: {name}")
        identical = static_a.read_bytes() == static_b.read_bytes()
        if not identical:
            raise RuntimeError(f"run-neutral byte comparison failed: {name}")
        file_results.append({
            "file": name,
            "acceptedStaticASHA256": a_hash,
            "staticBSHA256": b_hash,
            "byteIdentical": identical,
        })
    accepted_bindings = load_json(static_a_root / "INPUT-BINDINGS.json")
    actual_bindings = load_json(static_b_root / "INPUT-BINDINGS.json")
    contract_sha = canonical_sha256(contract)
    binding_result = compare_input_bindings(
        accepted_bindings, actual_bindings, contract_sha
    )
    return {
        "schema": 1,
        "task": "PLAY-027",
        "attemptID": ATTEMPT_ID,
        "processID": "static-b",
        "contractCanonicalSHA256": contract_sha,
        "runNeutralFiles": file_results,
        "allFiveByteIdentical": True,
        "inputBindings": binding_result,
        "processProvenanceExcludedFromByteIdentity": True,
        "passed": True,
    }


def write_success_evidence(
    base: Any,
    evidence_root: Path,
    comparison: dict[str, Any],
    resource_evidence: dict[str, Any],
    provenance_path: Path,
) -> None:
    validation = {
        "schema": 1,
        "task": "PLAY-027",
        "attemptID": ATTEMPT_ID,
        "processID": "static-b",
        "fiveRunNeutralFilesByteIdentical": True,
        "inputBindingsStrictTwoPointerComparison": True,
        "terminalResourceValidationPassed": True,
        "processGroupExhaustedAfterReap": True,
        "childStartCount": 1,
        "staticBInvocationCount": 1,
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "blendFiles": [],
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
        "validationPassed": True,
    }
    handoff = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "static-b-confirmation-v03",
        "attemptID": ATTEMPT_ID,
        "processID": "static-b",
        "comparison": {
            "file": "AB-COMPARISON.json",
            "sha256": hashlib.sha256(
                canonical_bytes(comparison)
            ).hexdigest(),
        },
        "resourceEvidence": {
            "file": "RESOURCE-EVIDENCE.json",
            "sha256": hashlib.sha256(
                canonical_bytes(resource_evidence)
            ).hexdigest(),
        },
        "processProvenance": {
            "file": "static-b/PROCESS-PROVENANCE.json",
            "sha256": sha256(provenance_path),
        },
        "validation": {
            "file": "CONFIRMATION-VALIDATION.json",
            "sha256": hashlib.sha256(
                canonical_bytes(validation)
            ).hexdigest(),
        },
        "disclosedAggregateTransientMemberLimitation":
            AGGREGATE_TRANSIENT_MEMBER_LIMITATION,
        "disposition": "STATIC_B_CONFIRMATION_V03_CANDIDATE",
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    base.exclusive_write_json(evidence_root / "AB-COMPARISON.json", comparison)
    base.exclusive_write_json(
        evidence_root / "RESOURCE-EVIDENCE.json", resource_evidence
    )
    base.exclusive_write_json(
        evidence_root / "CONFIRMATION-VALIDATION.json", validation
    )
    base.exclusive_write_json(evidence_root / "HANDOFF.json", handoff)


def terminate_group_without_wait(process_group: int) -> None:
    try:
        os.killpg(process_group, signal.SIGTERM)
    except ProcessLookupError:
        return
    time.sleep(0.2)
    try:
        os.killpg(process_group, signal.SIGKILL)
    except ProcessLookupError:
        return


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    validate_platform(sys.platform)
    static_a = load_static_a_launcher(repository_root)
    base = static_a.load_v01_launcher(repository_root)
    contract_path = Path(options.contract).absolute()
    requested_output = Path(options.output_root).absolute()
    contract, _ = validate_contract(repository_root, contract_path, base)
    if options.process_id != "static-b":
        raise RuntimeError("only static-B is authorized")
    static_a.ensure_no_python_path_environment()
    context_before = validate_context(repository_root, base)
    frozen_before = verify_frozen_inputs(repository_root, contract, base)
    scan = dependency_scan(repository_root)
    output_root = create_output_root(
        repository_root,
        contract,
        options.process_id,
        requested_output,
        base,
    )
    evidence_root = output_root.parent
    command = build_child_command(
        repository_root,
        contract,
        contract_path.resolve(strict=True),
        output_root,
        options.process_id,
        static_a,
    )
    validate_child_command(command, command)
    lock_descriptor = base.acquire_lock(Path(contract["blender"]["lockFile"]))
    temporary_path: Path | None = None
    process: subprocess.Popen[bytes] | None = None
    started = time.monotonic()
    sample_times: list[float] = []
    sampled_aggregate_peak_kib = 0
    observed_member_pids: set[int] = set()
    observed_extra_members: list[dict[str, int]] = []
    terminal: dict[str, Any] | None = None
    terminal_consumed = False
    termination = "not-started"
    post_reap_members: list[dict[str, int]] = []
    post_reap_check_available = True
    try:
        with tempfile.NamedTemporaryFile(
            mode="w+b",
            prefix="citysim-play027-v12-static-b-confirmation-v03-output-",
            suffix=".tmp",
            dir="/private/tmp",
            delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)
            process = subprocess.Popen(
                command,
                cwd=repository_root,
                stdin=subprocess.DEVNULL,
                stdout=temporary,
                stderr=subprocess.STDOUT,
                shell=False,
                start_new_session=True,
            )
            termination = "running"
            try:
                while terminal is None:
                    waited_pid, wait_status, usage = os.wait4(
                        process.pid, os.WNOHANG
                    )
                    if waited_pid != 0:
                        terminal = terminal_record_from_wait4(
                            process.pid,
                            waited_pid,
                            wait_status,
                            usage,
                            terminal_consumed,
                        )
                        terminal_consumed = True
                        process.returncode = terminal["exitCode"]
                        break
                    sampled = time.monotonic()
                    sample_times.append(sampled)
                    members = process_group_snapshot(process.pid)
                    observed_member_pids.update(
                        member["pid"] for member in members
                    )
                    extras = classify_sampled_members(process.pid, members)
                    if extras:
                        observed_extra_members.extend(extras)
                        termination = "observed-extra-process-group-member"
                        terminate_group_without_wait(process.pid)
                    aggregate_kib = sum(
                        member["rssKiB"] for member in members
                    )
                    sampled_aggregate_peak_kib = max(
                        sampled_aggregate_peak_kib, aggregate_kib
                    )
                    elapsed = time.monotonic() - started
                    online_limit = base.classify_limits(
                        elapsed,
                        sampled_aggregate_peak_kib,
                        float(
                            contract["blender"]["perProcessTimeoutSeconds"]
                        ),
                        int(
                            contract["blender"][
                                "maximumProcessGroupRSSMiB"
                            ]
                        ) * 1024,
                    )
                    if online_limit is not None and termination == "running":
                        termination = f"online-{online_limit}"
                        terminate_group_without_wait(process.pid)
                    if termination != "running":
                        waited_pid, wait_status, usage = os.wait4(
                            process.pid, 0
                        )
                        terminal = terminal_record_from_wait4(
                            process.pid,
                            waited_pid,
                            wait_status,
                            usage,
                            terminal_consumed,
                        )
                        terminal_consumed = True
                        process.returncode = terminal["exitCode"]
                        break
                    time.sleep(SAMPLE_SLEEP_SECONDS)
            except Exception as error:
                termination = (
                    f"observer-or-terminal-wait-failure: "
                    f"{type(error).__name__}: {error}"
                )
                terminate_group_without_wait(process.pid)
                if terminal is None:
                    try:
                        waited_pid, wait_status, usage = os.wait4(
                            process.pid, 0
                        )
                        terminal = terminal_record_from_wait4(
                            process.pid,
                            waited_pid,
                            wait_status,
                            usage,
                            terminal_consumed,
                        )
                        terminal_consumed = True
                        process.returncode = terminal["exitCode"]
                    except Exception as reap_error:
                        termination += (
                            f"; terminal-reap-failure: "
                            f"{type(reap_error).__name__}: {reap_error}"
                        )
            temporary.flush()
            os.fsync(temporary.fileno())
        elapsed = time.monotonic() - started
        try:
            post_reap_members = process_group_snapshot(process.pid)
        except Exception as error:
            post_reap_check_available = False
            post_reap_members = []
            if termination == "running":
                termination = (
                    f"post-reap-exhaustion-check-failure: "
                    f"{type(error).__name__}: {error}"
                )
        exhaustion_reason = classify_post_reap_members(post_reap_members)
        if exhaustion_reason is not None:
            if termination == "running":
                termination = exhaustion_reason
            terminate_group_without_wait(process.pid)
        payload = temporary_path.read_bytes()
        output_details = base.bounded_tail(payload)
        try:
            frozen_after: dict[str, Any] = verify_frozen_inputs(
                repository_root, contract, base
            )
            if frozen_after != frozen_before:
                termination = "frozen-input-mutation"
        except Exception as error:
            frozen_after = {
                "verificationError":
                    f"{type(error).__name__}: {error}"
            }
            termination = "frozen-input-verification-failure"
        resource_reason: str | None = None
        enforced_peak_kib = 0
        try:
            resource_reason, enforced_peak_kib = classify_terminal_resources(
                elapsed_seconds=elapsed,
                sampled_aggregate_peak_kib=sampled_aggregate_peak_kib,
                terminal=terminal,
                timeout_seconds=float(
                    contract["blender"]["perProcessTimeoutSeconds"]
                ),
                maximum_rss_kib=int(
                    contract["blender"]["maximumProcessGroupRSSMiB"]
                ) * 1024,
            )
        except RuntimeError as error:
            resource_reason = f"terminal-resource-invalid: {error}"
        if termination == "running" and terminal is not None:
            exit_reason = classify_terminal_exit(terminal)
            if exit_reason is not None:
                termination = exit_reason
            elif resource_reason is not None:
                termination = resource_reason
            else:
                termination = "success"
        success = termination == "success"
        try:
            partial = base.validate_child_inventory(output_root, success)
        except RuntimeError as error:
            partial = base.regular_inventory(output_root)
            termination = f"child-output-validation-failure: {error}"
            success = False
        comparison: dict[str, Any] | None = None
        comparison_attempted = False
        if success:
            comparison_attempted = True
            try:
                comparison = compare_static_results(
                    repository_root, contract, output_root
                )
            except RuntimeError as error:
                termination = f"static-comparison-failure: {error}"
                success = False
        context_after: dict[str, Any] | None = None
        if success:
            try:
                context_after = validate_context(
                    repository_root, base, evidence_root
                )
            except RuntimeError as error:
                termination = f"repository-context-failure: {error}"
                success = False
        cadence = cadence_metrics(sample_times)
        resource_evidence = {
            "schema": 1,
            "task": "PLAY-027",
            "attemptID": ATTEMPT_ID,
            "processID": "static-b",
            "terminal": terminal,
            "terminalKernelMeasurementAvailable":
                terminal is not None and terminal.get("available", False),
            "sampledAggregateGroupPeakRSSKiB":
                sampled_aggregate_peak_kib,
            "enforcedPeakRSSKiB": enforced_peak_kib,
            "maximumAllowedRSSKiB": int(
                contract["blender"]["maximumProcessGroupRSSMiB"]
            ) * 1024,
            "terminalElapsedSeconds": round(elapsed, 6),
            "maximumAllowedElapsedSeconds": float(
                contract["blender"]["perProcessTimeoutSeconds"]
            ),
            "aggregatePeakCoverage": AGGREGATE_PEAK_COVERAGE,
            "disclosedAggregateTransientMemberLimitation":
                AGGREGATE_TRANSIENT_MEMBER_LIMITATION,
            "cadence": cadence,
            "observedProcessGroupMemberPIDs":
                sorted(observed_member_pids),
            "observedExtraProcessGroupMembers": observed_extra_members,
            "postReapProcessGroupMembers": post_reap_members,
            "postReapProcessGroupCheckAvailable":
                post_reap_check_available,
            "processGroupExhaustedAfterReap":
                post_reap_check_available and not post_reap_members,
            "resourceFailureReason": resource_reason,
            "passed": success,
        }
        result = {
            "schema": 1,
            "task": "PLAY-027",
            "attemptID": ATTEMPT_ID,
            "stage": contract["stage"],
            "processID": options.process_id,
            "returnCode": (
                terminal["exitCode"] if terminal is not None else None
            ),
            "terminationDisposition": termination,
            "childArgv": command,
            "elapsedMonotonicSeconds": round(elapsed, 6),
            "terminalResourceAccounting": resource_evidence,
            **output_details,
            "partialOrSuccessfulOutputs": partial,
            "repositoryContextBefore": context_before,
            "frozenInputHashesBefore": frozen_before,
            "frozenInputHashesAfter": frozen_after,
            "dependencyScan": scan,
            "staticAComparison": (
                comparison if success
                else {
                    "performed": comparison_attempted,
                    "passed": False,
                }
            ),
            **fixed_process_truth(),
            "sourceAuthority": False,
            "candidateReadyForIndependentReview": False,
            "productionSelected": False,
        }
        if success and comparison is not None:
            result["repositoryContextAfter"] = context_after
            base.exclusive_write_json(
                output_root / "PROCESS-PROVENANCE.json", result
            )
            write_success_evidence(
                base,
                evidence_root,
                comparison,
                resource_evidence,
                output_root / "PROCESS-PROVENANCE.json",
            )
            print(json.dumps({
                "processID": options.process_id,
                "returnCode": terminal["exitCode"],
                "terminationDisposition": termination,
                "elapsedMonotonicSeconds": round(elapsed, 6),
                "sampledAggregateGroupPeakRSSKiB":
                    sampled_aggregate_peak_kib,
                "terminalChildTreeMaxRSSKiB":
                    terminal["terminalChildTreeMaxRSSKiB"],
                "enforcedPeakRSSKiB": enforced_peak_kib,
                "fiveRunNeutralFilesByteIdentical": True,
                "inputBindingsTwoPointerComparison": True,
                "validationPassed": True,
            }, sort_keys=True))
            return
        result["failure"] = {"reason": termination}
        base.exclusive_write_json(output_root / "FAILURE.json", result)
        raise RuntimeError(
            f"static-B v03 confirmation failed closed: {termination}"
        )
    finally:
        if temporary_path is not None:
            try:
                temporary_path.unlink()
            except FileNotFoundError:
                pass
        import fcntl
        fcntl.flock(lock_descriptor, fcntl.LOCK_UN)
        os.close(lock_descriptor)


if __name__ == "__main__":
    main()
