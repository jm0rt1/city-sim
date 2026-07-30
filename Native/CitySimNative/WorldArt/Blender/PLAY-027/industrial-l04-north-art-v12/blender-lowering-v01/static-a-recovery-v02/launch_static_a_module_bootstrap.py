#!/usr/bin/env python3
"""Single-use module-bootstrap launcher for North v12 static-a recovery v02."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
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
V01_RELATIVE = SOURCE_RELATIVE / "static-a-recovery-v01"
V02_RELATIVE = SOURCE_RELATIVE / "static-a-recovery-v02"
CONTRACT_RELATIVE = V02_RELATIVE / "RECOVERY-CONTRACT.json"
ORIGINAL_CONTRACT_RELATIVE = SOURCE_RELATIVE / "LOWERING-CONTRACT.json"
IMPORTER_RELATIVE = SOURCE_RELATIVE / "import_v12_scene.py"
LOWERER_RELATIVE = SOURCE_RELATIVE / "lower_v12_scene.py"
ORIGINAL_LAUNCHER_RELATIVE = SOURCE_RELATIVE / "launch_static_import.py"
V01_LAUNCHER_RELATIVE = V01_RELATIVE / "launch_static_a_recovery.py"
V02_LAUNCHER_RELATIVE = V02_RELATIVE / "launch_static_a_module_bootstrap.py"
V02_TEST_RELATIVE = V02_RELATIVE / "test_static_a_module_bootstrap.py"
AUTHORITY_RELATIVE = Path(
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-NORTH-V12-STATIC-A-MODULE-BOOTSTRAP-RECOVERY-V02-AUTHORITY.md"
)
DISPATCH_RELATIVE = Path(
    "docs/production/evidence/INTEGRATION/"
    "WORLD_ART_PARALLEL_DISPATCH-2026-07-30T0309Z.json"
)
EXPECTED_BRANCH = "codex/citysim-world-art"
EXPECTED_AUTHORITY_COMMIT = "03f320554951ef79bb8e200c844b3ad168fb3d10"
EXPECTED_DISPATCH_COMMIT = "8a3954160b28d580439db3df0aa5fae780d833e5"
EXPECTED_WORKER_ANCESTOR = "56e4f484ac07ca3fcf11e72f69a7fb56170d9792"
EXPECTED_AUTHORITY_SHA256 = (
    "89dbecb8aaf491238c09a09f6fcd2c4c716b6be7d2a51373ec5045355306c84c"
)
EXPECTED_LOWERER_SHA256 = (
    "7dc01ddc56bfff3ee9efca417ad0f70265d92daf99281dd53f7231c691e53a42"
)
EXPECTED_IMPORTER_SHA256 = (
    "ec726d584ce4b22253fca486e82bc6a198616debed94358d76f6dac7a1f62988"
)
EXPECTED_V01_LAUNCHER_SHA256 = (
    "e3c1cae8dbfafa297cdc70de14097f0769d9a9941e5a09f92e2bce8901be3333"
)
PRIOR_FAILURES = {
    Path(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/"
        "blender-north-art-v12/blender-lowering-v01/static-a/FAILURE.json"
    ): "aa9e71684dffcd501cbdb6f664787de6e7cb6d33602f46aa928f09a062d4ebd3",
    Path(
        "docs/production/evidence/PLAY-027/industrial-l04/l04/"
        "blender-north-art-v12/blender-lowering-v01/"
        "static-a-recovery-v01/static-a/FAILURE.json"
    ): "d68b922bb93ea57449e69fd5ee5d177e697d0b19cc02860c95db11d56ab2f5a6",
}
ATTEMPT_ID = "industrial-l04-north-v12-static-a-module-bootstrap-recovery-v02"


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


def load_v01_launcher(repository_root: Path) -> Any:
    path = repository_root / V01_LAUNCHER_RELATIVE
    if sha256(path) != EXPECTED_V01_LAUNCHER_SHA256:
        raise RuntimeError("v01 recovery launcher hash drift")
    specification = importlib.util.spec_from_file_location(
        "play027_static_a_recovery_v01", path
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("v01 recovery launcher import failed")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def expected_recovery_block() -> dict[str, Any]:
    return {
        "authorityCommit": EXPECTED_AUTHORITY_COMMIT,
        "authorityFile": str(AUTHORITY_RELATIVE),
        "authoritySHA256": EXPECTED_AUTHORITY_SHA256,
        "dispatchCommit": EXPECTED_DISPATCH_COMMIT,
        "dispatchFile": str(DISPATCH_RELATIVE),
        "integrationBaseline": "ccb3d67eb2cd7095589249ac316ac48f105e76dd",
        "requiredWorkerAncestors": [EXPECTED_WORKER_ANCESTOR],
        "priorFailures": [
            {"file": str(path), "sha256": digest}
            for path, digest in PRIOR_FAILURES.items()
        ],
        "moduleBootstrap": {
            "directory": str(SOURCE_RELATIVE),
            "module": "lower_v12_scene",
            "file": "lower_v12_scene.py",
            "sha256": EXPECTED_LOWERER_SHA256,
            "insertionIndex": 0,
        },
        "allowedProcessID": "static-a",
        "maximumChildStarts": 1,
    }


def validate_recovery_values(value: Any) -> None:
    if value != expected_recovery_block():
        raise RuntimeError("v02 recovery authority binding drift")


def validate_contract(
    repository_root: Path,
    contract_path: Path,
    base: Any,
) -> tuple[dict[str, Any], dict[str, Any]]:
    expected_path = (repository_root / CONTRACT_RELATIVE).resolve(strict=True)
    actual = base.exact_regular(
        contract_path, confinement_root=repository_root
    )
    if actual != expected_path:
        raise RuntimeError("exact v02 recovery contract required")
    original_path = base.exact_regular(
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
            "v02 recovery contract differs beyond evidenceRoot and recovery"
        )
    validate_recovery_values(recovery_block)
    return recovery, original


def verify_frozen_inputs(
    repository_root: Path,
    contract: dict[str, Any],
    base: Any,
) -> dict[str, str]:
    result = base.verify_frozen_inputs(repository_root, contract)
    additions = {
        "moduleBootstrapAuthority": (
            AUTHORITY_RELATIVE, EXPECTED_AUTHORITY_SHA256
        ),
        "v01RecoveryLauncher": (
            V01_LAUNCHER_RELATIVE, EXPECTED_V01_LAUNCHER_SHA256
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
    for index, (relative, expected) in enumerate(PRIOR_FAILURES.items()):
        result[f"priorFailure{index + 1}"] = sha256(
            base.exact_regular(
                repository_root / relative, expected, repository_root
            )
        )
    return result


def validate_context(
    repository_root: Path,
    base: Any,
    allowed_output_root: Path | None = None,
) -> dict[str, Any]:
    branch = base.git_output(repository_root, ["branch", "--show-current"])
    if branch != EXPECTED_BRANCH:
        raise RuntimeError(f"wrong branch: {branch}")
    ancestors = [
        EXPECTED_AUTHORITY_COMMIT,
        EXPECTED_DISPATCH_COMMIT,
        EXPECTED_WORKER_ANCESTOR,
    ]
    for commit in ancestors:
        base.assert_ancestor(repository_root, commit)
    status = base.git_output(
        repository_root, ["status", "--porcelain=v1", "--untracked-files=all"]
    )
    entries = [line for line in status.splitlines() if line]
    allowed = (
        str(allowed_output_root.relative_to(repository_root))
        if allowed_output_root is not None else None
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
        repository_root / ORIGINAL_LAUNCHER_RELATIVE,
        repository_root / V01_LAUNCHER_RELATIVE,
        repository_root / V02_LAUNCHER_RELATIVE,
        repository_root / V02_TEST_RELATIVE,
    )
    forbidden = (
        "bpy.ops.render", "render.filepath", "save_as_mainfile",
        "save_mainfile", "bpy.data.images", "import socket", "import urllib",
        "import requests", "eval(", "exec(",
    )
    findings = []
    process_module_files = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        if "subprocess" in text:
            process_module_files.append(str(path.relative_to(repository_root)))
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
    expected_process_files = sorted([
        str(ORIGINAL_LAUNCHER_RELATIVE),
        str(V01_LAUNCHER_RELATIVE),
        str(V02_LAUNCHER_RELATIVE),
    ])
    if findings:
        raise RuntimeError(f"forbidden dependency token: {findings}")
    if sorted(process_module_files) != expected_process_files:
        raise RuntimeError(
            f"process-module dependency scope drift: {process_module_files}"
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
        "processModuleFiles": expected_process_files,
        "passed": True,
    }


def ensure_no_python_path_environment() -> None:
    present = [
        key for key in ("PYTHONPATH", "PYTHONHOME")
        if key in os.environ
    ]
    if present:
        raise RuntimeError(f"Python path environment injection rejected: {present}")


def validate_bootstrap_preconditions(
    directory: Path,
    lowerer: Path,
    search_path: list[str],
) -> None:
    canonical_directory = directory.resolve(strict=True)
    canonical_lowerer = lowerer.resolve(strict=True)
    if canonical_lowerer.parent != canonical_directory:
        raise RuntimeError("bootstrap lowerer directory drift")
    if sha256(canonical_lowerer) != EXPECTED_LOWERER_SHA256:
        raise RuntimeError("bootstrap lowerer hash drift")
    occurrences = []
    for value in search_path:
        if not value:
            continue
        candidate = Path(value)
        if candidate.exists() and candidate.resolve() == canonical_directory:
            occurrences.append(value)
    if occurrences:
        raise RuntimeError(
            f"unexpected existing bootstrap directory: {occurrences}"
        )


def module_bootstrap_expression(repository_root: Path) -> str:
    directory = (repository_root / SOURCE_RELATIVE).resolve(strict=True)
    lowerer = (repository_root / LOWERER_RELATIVE).resolve(strict=True)
    validate_bootstrap_preconditions(directory, lowerer, [])
    quoted_directory = repr(str(directory))
    expected_hash = repr(EXPECTED_LOWERER_SHA256)
    return (
        "import hashlib,importlib.util,pathlib,sys;"
        f"d=pathlib.Path({quoted_directory}).resolve(strict=True);"
        "m=(d/'lower_v12_scene.py').resolve(strict=True);"
        "bad=[p for p in sys.path if p and pathlib.Path(p).exists() "
        "and pathlib.Path(p).resolve()==d];"
        f"hashlib.sha256(m.read_bytes()).hexdigest()=={expected_hash} "
        "or (_ for _ in ()).throw(RuntimeError('lowerer hash drift'));"
        "not bad or (_ for _ in ()).throw("
        "RuntimeError('unexpected existing bootstrap directory'));"
        "sys.path.insert(0,str(d));"
        "s=importlib.util.find_spec('lower_v12_scene');"
        "s is not None or (_ for _ in ()).throw("
        "RuntimeError('lowerer module not found'));"
        "pathlib.Path(s.origin).resolve(strict=True)==m or "
        "(_ for _ in ()).throw(RuntimeError('lowerer module origin drift'))"
    )


def expected_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    process_id: str,
) -> Path:
    if process_id != "static-a":
        raise RuntimeError("only v02 recovery static-a is authorized")
    return (
        repository_root / contract["evidenceRoot"] / process_id
    ).absolute()


def create_output_root(
    repository_root: Path,
    contract: dict[str, Any],
    process_id: str,
    requested: Path,
    base: Any,
) -> Path:
    expected = expected_output_root(repository_root, contract, process_id)
    if requested.absolute() != expected:
        raise RuntimeError("exact v02 recovery output root required")
    requested.absolute().relative_to(repository_root)
    base.assert_nofollow_chain(requested, repository_root)
    base.ensure_absent_output_path(requested)
    parent = base.exact_directory(requested.parent, repository_root)
    os.mkdir(requested, mode=0o755)
    created = base.exact_directory(requested, repository_root)
    if created.parent != parent:
        raise RuntimeError("v02 recovery output parent drift")
    return created


def build_child_command(
    repository_root: Path,
    contract: dict[str, Any],
    contract_path: Path,
    output_root: Path,
    process_id: str,
) -> list[str]:
    expression = module_bootstrap_expression(repository_root)
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


def validate_child_command(
    actual: list[str],
    expected: list[str],
) -> None:
    if actual != expected:
        raise RuntimeError("fixed v02 child argv drift")
    if actual.count("--python-expr") != 1:
        raise RuntimeError("exactly one module bootstrap expression required")
    expression_index = actual.index("--python-expr")
    if actual[expression_index + 2] != "--python":
        raise RuntimeError("unchanged importer must immediately follow bootstrap")
    if actual.count("--python") != 1:
        raise RuntimeError("exactly one importer execution required")


def receipt(
    base: Any,
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
    value = base.receipt_base(
        contract,
        process_id,
        command,
        return_code,
        termination,
        elapsed,
        peak_rss_kib,
        sample_times,
        output,
        partial,
    )
    value["attemptID"] = ATTEMPT_ID
    value["moduleBootstrap"] = {
        "directory": str(SOURCE_RELATIVE),
        "lowererSHA256": EXPECTED_LOWERER_SHA256,
        "importerSHA256": EXPECTED_IMPORTER_SHA256,
        "pythonExprCount": 1,
        "insertionIndex": 0,
        "pythonPathEnvironmentUsed": False,
    }
    return value


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    base = load_v01_launcher(repository_root)
    contract_path = Path(options.contract).absolute()
    requested_output = Path(options.output_root).absolute()
    contract, _ = validate_contract(repository_root, contract_path, base)
    if options.process_id != "static-a":
        raise RuntimeError("only v02 recovery static-a is authorized")
    ensure_no_python_path_environment()
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
    command = build_child_command(
        repository_root,
        contract,
        contract_path.resolve(strict=True),
        output_root,
        options.process_id,
    )
    validate_child_command(command, command)
    lock_descriptor = base.acquire_lock(Path(contract["blender"]["lockFile"]))
    temporary_path: Path | None = None
    process: subprocess.Popen[bytes] | None = None
    started = time.monotonic()
    peak_rss_kib = 0
    sample_times: list[float] = []
    termination = "not-started"
    try:
        with tempfile.NamedTemporaryFile(
            mode="w+b",
            prefix="citysim-play027-v12-static-a-bootstrap-v02-output-",
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
                    base.process_group_rss_kib(process.pid),
                )
                elapsed = time.monotonic() - started
                limit = base.classify_limits(
                    elapsed,
                    peak_rss_kib,
                    float(contract["blender"]["perProcessTimeoutSeconds"]),
                    int(contract["blender"]["maximumProcessGroupRSSMiB"]) * 1024,
                )
                if limit is not None:
                    termination = limit
                    base.terminate_group(process.pid)
                    break
                time.sleep(base.SAMPLE_INTERVAL_SECONDS)
            process.wait(timeout=5)
            temporary.flush()
            os.fsync(temporary.fileno())
        elapsed = time.monotonic() - started
        payload = temporary_path.read_bytes()
        output_details = base.bounded_tail(payload)
        frozen_after = verify_frozen_inputs(repository_root, contract, base)
        if frozen_after != frozen_before:
            termination = "frozen-input-mutation"
        context_after = validate_context(repository_root, base, output_root)
        intervals = [
            sample_times[index] - sample_times[index - 1]
            for index in range(1, len(sample_times))
        ]
        if intervals and max(intervals) > 0.05:
            termination = "rss-sampling-interval-exceeded"
        if termination == "running":
            termination = (
                "success" if process.returncode == 0 else "child-nonzero-exit"
            )
        success = termination == "success"
        try:
            partial = base.validate_child_inventory(output_root, success)
        except RuntimeError as error:
            partial = base.regular_inventory(output_root)
            termination = f"child-output-validation-failure: {error}"
            success = False
        result = receipt(
            base,
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
        result["repositoryContextBefore"] = context_before
        result["repositoryContextAfter"] = context_after
        result["frozenInputHashesBefore"] = frozen_before
        result["frozenInputHashesAfter"] = frozen_after
        result["dependencyScan"] = scan
        if success:
            base.exclusive_write_json(
                output_root / "PROCESS-PROVENANCE.json", result
            )
            print(json.dumps({
                "processID": options.process_id,
                "returnCode": process.returncode,
                "terminationDisposition": termination,
                "elapsedMonotonicSeconds": result["elapsedMonotonicSeconds"],
                "peakProcessGroupRSSMiB": result["peakProcessGroupRSSMiB"],
                "rssSampleCount": result["rssSampleCount"],
                "combinedOutputSHA256": result["combinedOutputSHA256"],
                "validationPassed": True,
            }, sort_keys=True))
            return
        result["failure"] = {"reason": termination}
        base.exclusive_write_json(output_root / "FAILURE.json", result)
        raise RuntimeError(f"v02 static-a recovery failed closed: {termination}")
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
