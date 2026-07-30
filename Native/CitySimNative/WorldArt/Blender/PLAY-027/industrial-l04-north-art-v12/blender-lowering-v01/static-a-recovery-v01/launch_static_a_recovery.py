#!/usr/bin/env python3
"""Single-use fail-closed launcher for the PLAY-027 North v12 static-a recovery."""

from __future__ import annotations

import argparse
import copy
import fcntl
import hashlib
import json
import os
import signal
import stat
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any, Iterable


STATIC_CHILD_FILES = (
    "BLENDER-OBJECT-MANIFEST.json",
    "MATERIAL-MANIFEST.json",
    "PROJECTION.json",
    "TOPOLOGY.json",
    "INPUT-BINDINGS.json",
    "VALIDATION.json",
)
SOURCE_RELATIVE = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/blender-lowering-v01"
)
RECOVERY_RELATIVE = SOURCE_RELATIVE / "static-a-recovery-v01"
CONTRACT_RELATIVE = RECOVERY_RELATIVE / "RECOVERY-CONTRACT.json"
ORIGINAL_CONTRACT_RELATIVE = SOURCE_RELATIVE / "LOWERING-CONTRACT.json"
IMPORTER_RELATIVE = SOURCE_RELATIVE / "import_v12_scene.py"
LOWERER_RELATIVE = SOURCE_RELATIVE / "lower_v12_scene.py"
RECOVERY_LAUNCHER_RELATIVE = (
    RECOVERY_RELATIVE / "launch_static_a_recovery.py"
)
RECOVERY_TEST_RELATIVE = RECOVERY_RELATIVE / "test_static_a_recovery.py"
AUTHORITY_RELATIVE = Path(
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-NORTH-V12-STATIC-A-RECOVERY-V01-AUTHORITY.md"
)
DISPATCH_RELATIVE = Path(
    "docs/production/evidence/INTEGRATION/"
    "WORLD_ART_PARALLEL_DISPATCH-2026-07-30T0227Z.json"
)
ORIGINAL_FAILURE_RELATIVE = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12/blender-lowering-v01/static-a/FAILURE.json"
)
EXPECTED_BRANCH = "codex/citysim-world-art"
EXPECTED_AUTHORITY_COMMIT = "10b0dacf1440b1c7a351e99cca29ac95e62e40c4"
EXPECTED_DISPATCH_COMMIT = "270c5ad30c001dbaa9ebc9beceacf19744a2f409"
EXPECTED_AUTHORITY_SHA256 = (
    "b171b8d05296c8f6808188c2f31cd5e6be43b4a16cd5123424eb5ba085211b4a"
)
EXPECTED_FAILURE_SHA256 = (
    "aa9e71684dffcd501cbdb6f664787de6e7cb6d33602f46aa928f09a062d4ebd3"
)
EXPECTED_WORKER_ANCESTORS = (
    "c609d1cd44c8a188f702894002a0fdd7d79a1d47",
    "12bcb1a2c740d30cebdc975c2f0882f63de6b6cf",
)
MAXIMUM_TAIL_BYTES = 65_536
SAMPLE_INTERVAL_SECONDS = 0.01
PROHIBITED_SUFFIXES = {
    ".blend", ".png", ".jpg", ".jpeg", ".exr", ".tif", ".tiff",
    ".bmp", ".webp",
}
FROZEN_CONTRACT_KEYS = (
    "claim", "authority", "scene", "materials", "bridge",
    "compoundAuditTool", "analyticReplayIdentity", "compoundAudit",
    "compoundAdversaries", "compoundDisposition", "replayPreservation",
)


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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


def git_output(repository_root: Path, arguments: list[str]) -> str:
    result = subprocess.run(
        ["/usr/bin/git", "-C", str(repository_root), *arguments],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def assert_ancestor(repository_root: Path, commit: str) -> None:
    result = subprocess.run(
        [
            "/usr/bin/git", "-C", str(repository_root),
            "merge-base", "--is-ancestor", commit, "HEAD",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"required commit is not an ancestor: {commit}")


def assert_nofollow_chain(path: Path, stop: Path) -> None:
    stop = stop.resolve(strict=True)
    absolute = path.absolute()
    absolute.relative_to(stop)
    current = stop
    for part in absolute.relative_to(stop).parts:
        current = current / part
        if current.exists() or current.is_symlink():
            mode = os.lstat(current).st_mode
            if stat.S_ISLNK(mode):
                raise RuntimeError(f"symlink path component rejected: {current}")


def exact_regular(
    path: Path,
    expected_hash: str | None = None,
    confinement_root: Path | None = None,
) -> Path:
    if confinement_root is not None:
        assert_nofollow_chain(path, confinement_root)
    if path.is_symlink():
        raise RuntimeError(f"symlink input rejected: {path}")
    resolved = path.resolve(strict=True)
    if not stat.S_ISREG(os.lstat(resolved).st_mode):
        raise RuntimeError(f"regular input required: {resolved}")
    if expected_hash is not None and sha256(resolved) != expected_hash:
        raise RuntimeError(f"hash drift: {resolved}")
    return resolved


def exact_directory(path: Path, confinement_root: Path) -> Path:
    assert_nofollow_chain(path, confinement_root)
    if path.is_symlink():
        raise RuntimeError(f"symlink directory rejected: {path}")
    resolved = path.resolve(strict=True)
    if not stat.S_ISDIR(os.lstat(resolved).st_mode):
        raise RuntimeError(f"directory required: {resolved}")
    return resolved


def validate_recovery_contract(
    repository_root: Path,
    contract_path: Path,
) -> tuple[dict[str, Any], dict[str, Any]]:
    expected = (repository_root / CONTRACT_RELATIVE).resolve(strict=True)
    actual = exact_regular(
        contract_path, confinement_root=repository_root
    )
    if actual != expected:
        raise RuntimeError("exact recovery contract required")
    original_path = exact_regular(
        repository_root / ORIGINAL_CONTRACT_RELATIVE,
        "21480cd8c1dbb66f33b3ccd4987fea169198f2640b793a220d8d22c9c8505aa8",
        repository_root,
    )
    original = load_json(original_path)
    recovery = load_json(actual)
    comparison = copy.deepcopy(recovery)
    recovery_block = comparison.pop("recovery", None)
    comparison["evidenceRoot"] = original["evidenceRoot"]
    if comparison != original:
        raise RuntimeError(
            "recovery contract differs beyond evidenceRoot and recovery"
        )
    validate_recovery_values(recovery_block)
    return recovery, original


def validate_recovery_values(recovery_block: Any) -> None:
    expected_recovery = {
        "authorityCommit": EXPECTED_AUTHORITY_COMMIT,
        "authorityFile": str(AUTHORITY_RELATIVE),
        "authoritySHA256": EXPECTED_AUTHORITY_SHA256,
        "dispatchCommit": EXPECTED_DISPATCH_COMMIT,
        "dispatchFile": str(DISPATCH_RELATIVE),
        "integrationBaseline": "472ffa85cd35639a675c1c2e4ede748c94446a7f",
        "requiredWorkerAncestors": list(EXPECTED_WORKER_ANCESTORS),
        "consumedFailure": {
            "file": str(ORIGINAL_FAILURE_RELATIVE),
            "sha256": EXPECTED_FAILURE_SHA256,
            "commit": EXPECTED_WORKER_ANCESTORS[1],
        },
        "allowedProcessID": "static-a",
        "maximumChildStarts": 1,
    }
    if recovery_block != expected_recovery:
        raise RuntimeError("recovery authority binding drift")


def verify_frozen_inputs(
    repository_root: Path,
    contract: dict[str, Any],
) -> dict[str, str]:
    result: dict[str, str] = {}
    for key in FROZEN_CONTRACT_KEYS:
        path = exact_regular(
            repository_root / contract[key]["file"],
            contract[key]["sha256"],
            repository_root,
        )
        result[key] = sha256(path)
    additions = {
        "originalContract": (
            ORIGINAL_CONTRACT_RELATIVE,
            "21480cd8c1dbb66f33b3ccd4987fea169198f2640b793a220d8d22c9c8505aa8",
        ),
        "lowerer": (
            LOWERER_RELATIVE,
            "7dc01ddc56bfff3ee9efca417ad0f70265d92daf99281dd53f7231c691e53a42",
        ),
        "importer": (
            IMPORTER_RELATIVE,
            "ec726d584ce4b22253fca486e82bc6a198616debed94358d76f6dac7a1f62988",
        ),
        "authorityFile": (
            AUTHORITY_RELATIVE,
            EXPECTED_AUTHORITY_SHA256,
        ),
        "originalFailure": (
            ORIGINAL_FAILURE_RELATIVE,
            EXPECTED_FAILURE_SHA256,
        ),
    }
    for key, (relative, expected) in additions.items():
        result[key] = sha256(
            exact_regular(repository_root / relative, expected, repository_root)
        )
    executable = exact_regular(
        Path(contract["blender"]["executable"]),
        contract["blender"]["executableSHA256"],
    )
    result["blenderExecutable"] = sha256(executable)
    return result


def dependency_scan(repository_root: Path) -> dict[str, Any]:
    frozen_launcher = repository_root / SOURCE_RELATIVE / "launch_static_import.py"
    recovery_launcher = repository_root / RECOVERY_LAUNCHER_RELATIVE
    files = (
        repository_root / IMPORTER_RELATIVE,
        repository_root / LOWERER_RELATIVE,
        frozen_launcher,
        recovery_launcher,
        repository_root / RECOVERY_TEST_RELATIVE,
    )
    forbidden = (
        "bpy.ops.render", "render.filepath", "save_as_mainfile",
        "save_mainfile", "bpy.data.images", "import socket", "import urllib",
        "import requests", "eval(", "exec(",
    )
    findings = []
    subprocess_files = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        if "subprocess" in text:
            subprocess_files.append(str(path.relative_to(repository_root)))
        if path in (
            repository_root / IMPORTER_RELATIVE,
            repository_root / LOWERER_RELATIVE,
        ):
            for token in forbidden:
                if token in text:
                    findings.append({
                        "file": str(path.relative_to(repository_root)),
                        "token": token,
                    })
    expected_subprocess_files = sorted([
        str(frozen_launcher.relative_to(repository_root)),
        str(recovery_launcher.relative_to(repository_root)),
    ])
    if findings:
        raise RuntimeError(f"forbidden dependency token: {findings}")
    if sorted(subprocess_files) != expected_subprocess_files:
        raise RuntimeError(
            f"subprocess dependency scope drift: {subprocess_files}"
        )
    return {
        "files": [
            {
                "file": str(path.relative_to(repository_root)),
                "sha256": sha256(path),
            }
            for path in files
        ],
        "forbiddenFindings": [],
        "subprocessFiles": expected_subprocess_files,
        "passed": True,
    }


def validate_branch(branch: str) -> None:
    if branch != EXPECTED_BRANCH:
        raise RuntimeError(f"wrong branch: {branch}")


def validate_status_entries(
    entries: Iterable[str],
    allowed_output_root: str | None,
) -> None:
    values = list(entries)
    if allowed_output_root is None:
        if values:
            raise RuntimeError(f"clean worktree required: {values}")
        return
    unexpected = []
    for entry in values:
        path = entry[3:]
        if not (
            path == allowed_output_root
            or path.startswith(f"{allowed_output_root}/")
        ):
            unexpected.append(entry)
    if unexpected:
        raise RuntimeError(
            f"repository mutation outside output root: {unexpected}"
        )


def validate_repository_context(
    repository_root: Path,
    allowed_output_root: Path | None = None,
) -> dict[str, Any]:
    branch = git_output(repository_root, ["branch", "--show-current"])
    validate_branch(branch)
    for commit in (
        EXPECTED_AUTHORITY_COMMIT,
        EXPECTED_DISPATCH_COMMIT,
        *EXPECTED_WORKER_ANCESTORS,
    ):
        assert_ancestor(repository_root, commit)
    status = git_output(
        repository_root, ["status", "--porcelain=v1", "--untracked-files=all"]
    )
    entries = [line for line in status.splitlines() if line]
    allowed = (
        str(allowed_output_root.relative_to(repository_root))
        if allowed_output_root is not None else None
    )
    validate_status_entries(entries, allowed)
    return {
        "branch": branch,
        "head": git_output(repository_root, ["rev-parse", "HEAD"]),
        "requiredAncestors": [
            EXPECTED_AUTHORITY_COMMIT,
            EXPECTED_DISPATCH_COMMIT,
            *EXPECTED_WORKER_ANCESTORS,
        ],
        "statusEntries": entries,
        "unexpectedStatusEntries": [],
        "passed": True,
    }


def expected_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    process_id: str,
) -> Path:
    if process_id != contract["recovery"]["allowedProcessID"]:
        raise RuntimeError("only recovery static-a is authorized")
    return (
        repository_root / contract["evidenceRoot"] / process_id
    ).absolute()


def create_exact_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    process_id: str,
    requested: Path,
) -> Path:
    expected = expected_output_root(repository_root, contract, process_id)
    if requested.absolute() != expected:
        raise RuntimeError("exact recovery output root required")
    requested.absolute().relative_to(repository_root)
    assert_nofollow_chain(requested, repository_root)
    ensure_absent_output_path(requested)
    parent = exact_directory(requested.parent, repository_root)
    os.mkdir(requested, mode=0o755)
    created = exact_directory(requested, repository_root)
    if created.parent != parent:
        raise RuntimeError("recovery output parent drift")
    return created


def ensure_absent_output_path(path: Path) -> None:
    if path.exists() or path.is_symlink():
        raise RuntimeError("recovery output root must be absent")


def build_child_command(
    repository_root: Path,
    contract: dict[str, Any],
    contract_path: Path,
    output_root: Path,
    process_id: str,
) -> list[str]:
    executable = str(Path(contract["blender"]["executable"]))
    return [
        executable,
        "--background",
        "--factory-startup",
        "--disable-autoexec",
        "--threads",
        "1",
        "--python-exit-code",
        "1",
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
        raise RuntimeError("fixed child argv drift")


def acquire_lock(path: Path) -> int:
    if path.is_symlink():
        raise RuntimeError("symlink lock rejected")
    descriptor = os.open(
        path,
        os.O_RDWR | os.O_CREAT
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
        0o600,
    )
    if not stat.S_ISREG(os.fstat(descriptor).st_mode):
        os.close(descriptor)
        raise RuntimeError("regular task lock required")
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError as error:
        os.close(descriptor)
        raise RuntimeError("static Blender concurrency lock is busy") from error
    return descriptor


def process_group_rss_kib(process_group: int) -> int:
    result = subprocess.run(
        ["/bin/ps", "-axo", "pgid=,rss="],
        check=True,
        capture_output=True,
        text=True,
    )
    total = 0
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) == 2 and int(fields[0]) == process_group:
            total += int(fields[1])
    return total


def terminate_group(process_group: int) -> None:
    try:
        os.killpg(process_group, signal.SIGTERM)
    except ProcessLookupError:
        return
    time.sleep(0.2)
    try:
        os.killpg(process_group, signal.SIGKILL)
    except ProcessLookupError:
        return


def classify_limits(
    elapsed_seconds: float,
    rss_kib: int,
    timeout_seconds: float,
    maximum_rss_kib: int,
) -> str | None:
    if elapsed_seconds > timeout_seconds:
        return "per-process-timeout"
    if rss_kib > maximum_rss_kib:
        return "process-group-rss-limit"
    return None


def regular_inventory(root: Path) -> dict[str, dict[str, Any]]:
    result = {}
    for path in sorted(root.iterdir(), key=lambda item: item.name):
        if path.is_symlink() or not path.is_file():
            raise RuntimeError(f"regular child output required: {path}")
        result[path.name] = {
            "path": str(path),
            "sha256": sha256(path),
            "byteCount": path.stat().st_size,
        }
    return result


def prohibited_outputs(root: Path) -> list[str]:
    return sorted(
        str(path.relative_to(root))
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in PROHIBITED_SUFFIXES
    )


def validate_child_inventory(root: Path, success: bool) -> dict[str, dict[str, Any]]:
    inventory = regular_inventory(root)
    names = sorted(inventory)
    prohibited = prohibited_outputs(root)
    if prohibited:
        raise RuntimeError(f"prohibited static output: {prohibited}")
    if success and names != sorted(STATIC_CHILD_FILES):
        raise RuntimeError(f"static child inventory drift: {names}")
    if not success and "FAILURE.json" in names:
        raise RuntimeError("child may not create launcher failure receipt")
    unknown = sorted(
        set(names) - set(STATIC_CHILD_FILES)
    )
    if unknown:
        raise RuntimeError(f"unexpected child output: {unknown}")
    return inventory


def exclusive_write_json(path: Path, value: Any) -> None:
    parent = path.parent
    if parent.is_symlink() or not parent.is_dir():
        raise RuntimeError("receipt parent drift")
    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL
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


def output_record(path: Path) -> dict[str, Any]:
    return {
        "path": str(path),
        "sha256": sha256(path),
        "byteCount": path.stat().st_size,
    }


def bounded_tail(payload: bytes) -> dict[str, Any]:
    start = max(0, len(payload) - MAXIMUM_TAIL_BYTES)
    while start < len(payload) and (payload[start] & 0xC0) == 0x80:
        start += 1
    tail_bytes = payload[start:]
    return {
        "combinedOutputSHA256": hashlib.sha256(payload).hexdigest(),
        "combinedOutputByteCount": len(payload),
        "outputTail": tail_bytes.decode("utf-8", errors="replace"),
        "outputTailByteCount": len(tail_bytes),
        "outputTailMaximumBytes": MAXIMUM_TAIL_BYTES,
        "outputTailTruncated": start > 0,
    }


def receipt_base(
    contract: dict[str, Any],
    process_id: str,
    command: list[str],
    return_code: int | None,
    termination: str,
    elapsed: float,
    peak_rss_kib: int,
    sample_times: list[float],
    output: dict[str, Any],
    partial: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    intervals = [
        sample_times[index] - sample_times[index - 1]
        for index in range(1, len(sample_times))
    ]
    return {
        "schema": 1,
        "task": "PLAY-027",
        "attemptID": "industrial-l04-north-v12-static-a-recovery-v01",
        "stage": contract["stage"],
        "processID": process_id,
        "returnCode": return_code,
        "terminationDisposition": termination,
        "childArgv": command,
        "childStartCount": 1,
        "elapsedMonotonicSeconds": round(elapsed, 6),
        "peakProcessGroupRSSKiB": peak_rss_kib,
        "peakProcessGroupRSSMiB": round(peak_rss_kib / 1024.0, 6),
        "rssSampleCount": len(sample_times),
        "rssMaximumIntervalSeconds": round(max(intervals, default=0.0), 6),
        "rssRequiredMaximumIntervalSeconds": 0.05,
        **output,
        "partialOrSuccessfulOutputs": partial,
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "blendFiles": [],
        "staticBInvocationCount": 0,
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    contract_path = Path(options.contract).absolute()
    requested_output = Path(options.output_root).absolute()
    contract, _ = validate_recovery_contract(repository_root, contract_path)
    if options.process_id != "static-a":
        raise RuntimeError("only recovery static-a is authorized")
    context_before = validate_repository_context(repository_root)
    frozen_before = verify_frozen_inputs(repository_root, contract)
    scan = dependency_scan(repository_root)
    output_root = create_exact_output_root(
        repository_root,
        contract,
        options.process_id,
        requested_output,
    )
    command = build_child_command(
        repository_root,
        contract,
        contract_path.resolve(strict=True),
        output_root,
        options.process_id,
    )
    validate_child_command(command, command)
    lock_descriptor = acquire_lock(Path(contract["blender"]["lockFile"]))
    temporary_path: Path | None = None
    process: subprocess.Popen[bytes] | None = None
    started = time.monotonic()
    peak_rss_kib = 0
    sample_times: list[float] = []
    termination = "not-started"
    try:
        with tempfile.NamedTemporaryFile(
            mode="w+b",
            prefix="citysim-play027-v12-static-a-recovery-output-",
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
            while process.poll() is None:
                sampled = time.monotonic()
                sample_times.append(sampled)
                peak_rss_kib = max(
                    peak_rss_kib,
                    process_group_rss_kib(process.pid),
                )
                elapsed = time.monotonic() - started
                limit = classify_limits(
                    elapsed,
                    peak_rss_kib,
                    float(contract["blender"]["perProcessTimeoutSeconds"]),
                    int(contract["blender"]["maximumProcessGroupRSSMiB"]) * 1024,
                )
                if limit is not None:
                    termination = limit
                    terminate_group(process.pid)
                    break
                time.sleep(SAMPLE_INTERVAL_SECONDS)
            process.wait(timeout=5)
            temporary.flush()
            os.fsync(temporary.fileno())
        elapsed = time.monotonic() - started
        payload = temporary_path.read_bytes()
        output_details = bounded_tail(payload)
        frozen_after = verify_frozen_inputs(repository_root, contract)
        if frozen_after != frozen_before:
            termination = "frozen-input-mutation"
        context_after = validate_repository_context(repository_root, output_root)
        if (
            len(sample_times) > 1
            and max(
                sample_times[index] - sample_times[index - 1]
                for index in range(1, len(sample_times))
            ) > 0.05
        ):
            termination = "rss-sampling-interval-exceeded"
        if termination == "running":
            termination = (
                "success" if process.returncode == 0 else "child-nonzero-exit"
            )
        success = termination == "success"
        try:
            partial = validate_child_inventory(output_root, success)
        except RuntimeError as error:
            partial = regular_inventory(output_root)
            termination = f"child-output-validation-failure: {error}"
            success = False
        receipt = receipt_base(
            contract,
            options.process_id,
            command,
            process.returncode,
            termination,
            elapsed,
            peak_rss_kib,
            sample_times,
            output_details,
            partial,
        )
        receipt["repositoryContextBefore"] = context_before
        receipt["repositoryContextAfter"] = context_after
        receipt["frozenInputHashesBefore"] = frozen_before
        receipt["frozenInputHashesAfter"] = frozen_after
        receipt["dependencyScan"] = scan
        if success:
            exclusive_write_json(output_root / "PROCESS-PROVENANCE.json", receipt)
            print(json.dumps({
                "processID": options.process_id,
                "returnCode": process.returncode,
                "terminationDisposition": termination,
                "elapsedMonotonicSeconds": receipt["elapsedMonotonicSeconds"],
                "peakProcessGroupRSSMiB": receipt["peakProcessGroupRSSMiB"],
                "rssSampleCount": receipt["rssSampleCount"],
                "combinedOutputSHA256": receipt["combinedOutputSHA256"],
                "validationPassed": True,
            }, sort_keys=True))
            return
        receipt["failure"] = {"reason": termination}
        exclusive_write_json(output_root / "FAILURE.json", receipt)
        raise RuntimeError(f"static-a recovery failed closed: {termination}")
    finally:
        if temporary_path is not None:
            try:
                temporary_path.unlink()
            except FileNotFoundError:
                pass
        fcntl.flock(lock_descriptor, fcntl.LOCK_UN)
        os.close(lock_descriptor)


if __name__ == "__main__":
    main()
