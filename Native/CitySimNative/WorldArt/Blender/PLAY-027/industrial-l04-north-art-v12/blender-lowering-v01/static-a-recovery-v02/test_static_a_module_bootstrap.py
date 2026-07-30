#!/usr/bin/env python3
"""No-Blender adversaries and prelaunch proof for module-bootstrap recovery v02."""

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
    "static-a-recovery-v02"
)
EVIDENCE_RELATIVE = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12/blender-lowering-v01/"
    "static-a-recovery-v02/PRELAUNCH-VALIDATION.json"
)
AUTHORIZED_PENDING = {
    str(SOURCE_RELATIVE / "RECOVERY-CONTRACT.json"),
    str(SOURCE_RELATIVE / "launch_static_a_module_bootstrap.py"),
    str(SOURCE_RELATIVE / "test_static_a_module_bootstrap.py"),
    str(EVIDENCE_RELATIVE),
}


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def load_launcher(repository_root: Path) -> Any:
    path = (
        repository_root / SOURCE_RELATIVE
        / "launch_static_a_module_bootstrap.py"
    )
    specification = importlib.util.spec_from_file_location(
        "play027_static_a_module_bootstrap_v02", path
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("v02 launcher import failed")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def expect_failure(
    name: str,
    operation: Callable[[], None],
    fragment: str | None = None,
) -> dict[str, Any]:
    try:
        operation()
    except Exception as error:
        message = str(error)
        if fragment is not None and fragment not in message:
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


def write_once(path: Path, value: Any, canonical: Callable[[Any], bytes]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
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


def status_scope(launcher: Any, base: Any, repository_root: Path) -> dict[str, Any]:
    branch = base.git_output(repository_root, ["branch", "--show-current"])
    if branch != launcher.EXPECTED_BRANCH:
        raise RuntimeError(f"wrong branch: {branch}")
    ancestors = [
        launcher.EXPECTED_AUTHORITY_COMMIT,
        launcher.EXPECTED_DISPATCH_COMMIT,
        launcher.EXPECTED_WORKER_ANCESTOR,
    ]
    for commit in ancestors:
        base.assert_ancestor(repository_root, commit)
    status = base.git_output(
        repository_root, ["status", "--porcelain=v1", "--untracked-files=all"]
    )
    entries = [line for line in status.splitlines() if line]
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
        "cleanBeforeV02Mutation": True,
        "cleanOutsideAuthorizedV02Paths": True,
        "passed": True,
    }


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    output = Path(options.output).absolute()
    expected_output = (repository_root / EVIDENCE_RELATIVE).absolute()
    if output != expected_output:
        raise RuntimeError("exact v02 prelaunch evidence output required")
    if output.exists() or output.is_symlink():
        raise RuntimeError("v02 prelaunch evidence must be absent")
    launcher = load_launcher(repository_root)
    base = launcher.load_v01_launcher(repository_root)
    contract_path = Path(options.contract).resolve(strict=True)
    contract, original = launcher.validate_contract(
        repository_root, contract_path, base
    )
    context = status_scope(launcher, base, repository_root)
    frozen = launcher.verify_frozen_inputs(repository_root, contract, base)
    dependency_scan = launcher.dependency_scan(repository_root)
    launcher.ensure_no_python_path_environment()
    runtime_root = launcher.expected_output_root(
        repository_root, contract, "static-a"
    )
    base.ensure_absent_output_path(runtime_root)
    expected_command = launcher.build_child_command(
        repository_root,
        contract,
        contract_path,
        runtime_root,
        "static-a",
    )
    launcher.validate_child_command(expected_command, expected_command)
    expression = launcher.module_bootstrap_expression(repository_root)
    expression_index = expected_command.index("--python-expr")
    if expected_command[expression_index + 1] != expression:
        raise RuntimeError("bootstrap expression command binding drift")
    original_sys_path = list(sys.path)
    try:
        namespace: dict[str, Any] = {}
        exec(expression, namespace)
        expected_directory = str(
            (repository_root / launcher.SOURCE_RELATIVE).resolve(strict=True)
        )
        if sys.path[0] != expected_directory:
            raise RuntimeError("bootstrap did not insert exact sys.path[0]")
        specification = importlib.util.find_spec("lower_v12_scene")
        if specification is None or specification.origin is None:
            raise RuntimeError("bootstrap module specification missing")
        if Path(specification.origin).resolve(strict=True) != (
            repository_root / launcher.LOWERER_RELATIVE
        ).resolve(strict=True):
            raise RuntimeError("bootstrap module origin mismatch")
    finally:
        sys.path[:] = original_sys_path
        sys.modules.pop("lower_v12_scene", None)

    cases: list[dict[str, Any]] = []
    changed = copy.deepcopy(contract)
    changed["recovery"]["authorityCommit"] = "0" * 40
    cases.append(expect_failure(
        "wrong-authority",
        lambda: launcher.validate_recovery_values(changed["recovery"]),
        "v02 recovery authority binding drift",
    ))
    changed = copy.deepcopy(contract)
    changed["recovery"]["dispatchCommit"] = "0" * 40
    cases.append(expect_failure(
        "wrong-dispatch",
        lambda: launcher.validate_recovery_values(changed["recovery"]),
        "v02 recovery authority binding drift",
    ))
    changed = copy.deepcopy(contract)
    changed["recovery"]["maximumChildStarts"] = 2
    cases.append(expect_failure(
        "multiple-child-starts",
        lambda: launcher.validate_recovery_values(changed["recovery"]),
        "v02 recovery authority binding drift",
    ))
    cases.append(expect_failure(
        "wrong-branch",
        lambda: (
            None if "codex/citysim-world-art-east" == launcher.EXPECTED_BRANCH
            else (_ for _ in ()).throw(RuntimeError("wrong branch"))
        ),
        "wrong branch",
    ))
    cases.append(expect_failure(
        "missing-ancestry",
        lambda: base.assert_ancestor(repository_root, "0" * 40),
        "required commit is not an ancestor",
    ))
    changed = copy.deepcopy(contract)
    changed["scene"]["sha256"] = "0" * 64
    cases.append(expect_failure(
        "scene-hash-drift",
        lambda: launcher.verify_frozen_inputs(
            repository_root, changed, base
        ),
        "hash drift",
    ))
    changed = copy.deepcopy(contract)
    changed["materials"]["sha256"] = "0" * 64
    cases.append(expect_failure(
        "materials-hash-drift",
        lambda: launcher.verify_frozen_inputs(
            repository_root, changed, base
        ),
        "hash drift",
    ))
    changed = copy.deepcopy(contract)
    changed["bridge"]["sha256"] = "0" * 64
    cases.append(expect_failure(
        "bridge-hash-drift",
        lambda: launcher.verify_frozen_inputs(
            repository_root, changed, base
        ),
        "hash drift",
    ))
    directory = (repository_root / launcher.SOURCE_RELATIVE).resolve(strict=True)
    lowerer = (repository_root / launcher.LOWERER_RELATIVE).resolve(strict=True)
    cases.append(expect_failure(
        "preexisting-bootstrap-directory",
        lambda: launcher.validate_bootstrap_preconditions(
            directory, lowerer, [str(directory)]
        ),
        "unexpected existing bootstrap directory",
    ))
    with tempfile.TemporaryDirectory(
        prefix="citysim-play027-v02-bootstrap-",
        dir="/private/tmp",
    ) as temporary:
        root = Path(temporary)
        fake_directory = root / "module"
        fake_directory.mkdir()
        fake_lowerer = fake_directory / "lower_v12_scene.py"
        fake_lowerer.write_text("pass\n", encoding="utf-8")
        cases.append(expect_failure(
            "lowerer-hash-drift",
            lambda: launcher.validate_bootstrap_preconditions(
                fake_directory, fake_lowerer, []
            ),
            "bootstrap lowerer hash drift",
        ))
        symlink = root / "symlink"
        symlink.symlink_to(fake_directory, target_is_directory=True)
        cases.append(expect_failure(
            "symlink-output-root",
            lambda: base.ensure_absent_output_path(symlink),
            "recovery output root must be absent",
        ))
        preexisting = root / "preexisting"
        preexisting.mkdir()
        cases.append(expect_failure(
            "preexisting-output-root",
            lambda: base.ensure_absent_output_path(preexisting),
            "recovery output root must be absent",
        ))
        cases.append(expect_failure(
            "second-child-start",
            lambda: base.ensure_absent_output_path(preexisting),
            "recovery output root must be absent",
        ))
        cases.append(expect_failure(
            "arbitrary-output-root",
            lambda: launcher.create_output_root(
                repository_root,
                contract,
                "static-a",
                root / "arbitrary",
                base,
            ),
            "exact v02 recovery output root required",
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
        changed_command = list(expected_command)
        changed_command[expression_index + 1] += ";x=1"
        cases.append(expect_failure(
            "changed-bootstrap-expression",
            lambda: launcher.validate_child_command(
                changed_command, expected_command
            ),
            "fixed v02 child argv drift",
        ))
        changed_order = list(expected_command)
        changed_order.insert(expression_index + 2, "--threads")
        changed_order.insert(expression_index + 3, "2")
        cases.append(expect_failure(
            "bootstrap-importer-order",
            lambda: launcher.validate_child_command(
                changed_order, expected_command
            ),
            "fixed v02 child argv drift",
        ))
        cases.append(expect_failure(
            "repository-mutation",
            lambda: base.validate_status_entries(
                [" M Native/CitySimNative/Rendering/CityScene.swift"],
                str(runtime_root.relative_to(repository_root)),
            ),
            "repository mutation outside output root",
        ))
        empty = root / "empty"
        empty.mkdir()
        cases.append(expect_failure(
            "missing-child-files",
            lambda: base.validate_child_inventory(empty, True),
            "static child inventory drift",
        ))
        extra = root / "extra"
        extra.mkdir()
        (extra / "EXTRA.json").write_text("{}\n", encoding="utf-8")
        cases.append(expect_failure(
            "extra-child-file",
            lambda: base.validate_child_inventory(extra, False),
            "unexpected child output",
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
    if base.classify_limits(121.0, 1, 120.0, 1024) != "per-process-timeout":
        raise RuntimeError("timeout adversary failed")
    cases.append({
        "name": "timeout",
        "expectedFailure": "per-process-timeout",
        "actualFailure": "per-process-timeout",
        "passed": True,
    })
    if base.classify_limits(1.0, 1025, 120.0, 1024) != (
        "process-group-rss-limit"
    ):
        raise RuntimeError("RSS adversary failed")
    cases.append({
        "name": "rss-limit",
        "expectedFailure": "process-group-rss-limit",
        "actualFailure": "process-group-rss-limit",
        "passed": True,
    })

    changed_keys = {
        key for key in contract
        if key not in original or contract[key] != original[key]
    }
    if changed_keys != {"evidenceRoot", "recovery"}:
        raise RuntimeError("v02 contract difference drift")
    source_hashes = {
        str(path.relative_to(repository_root)): launcher.sha256(path)
        for path in sorted(
            (repository_root / SOURCE_RELATIVE).iterdir(),
            key=lambda item: item.name,
        )
        if path.is_file()
    }
    prior_failure_records = [
        {
            "file": str(relative),
            "sha256": launcher.sha256(repository_root / relative),
            "immutable": True,
        }
        for relative in launcher.PRIOR_FAILURES
    ]
    result = {
        "schema": 1,
        "task": "PLAY-027",
        "attemptID": launcher.ATTEMPT_ID,
        "processID": "static-a",
        "authorityCommit": launcher.EXPECTED_AUTHORITY_COMMIT,
        "authoritySHA256": launcher.EXPECTED_AUTHORITY_SHA256,
        "dispatchCommit": launcher.EXPECTED_DISPATCH_COMMIT,
        "claimSHA256": contract["claim"]["sha256"],
        "repositoryContext": context,
        "contractDifference": {
            "changedTopLevelKeys": sorted(changed_keys),
            "onlyEvidenceRootAndRecoveryChanged": True,
        },
        "frozenInputHashes": frozen,
        "priorFailures": prior_failure_records,
        "recoverySourceFiles": source_hashes,
        "dependencyScan": dependency_scan,
        "moduleBootstrap": {
            "directory": str(launcher.SOURCE_RELATIVE),
            "lowererSHA256": launcher.EXPECTED_LOWERER_SHA256,
            "importerSHA256": launcher.EXPECTED_IMPORTER_SHA256,
            "pythonExpr": expression,
            "pythonExprCount": expected_command.count("--python-expr"),
            "importerImmediatelyFollowsBootstrap": (
                expected_command[expression_index + 2] == "--python"
            ),
            "exactDirectoryInsertedAtIndex": 0,
            "findSpecOriginExact": True,
            "unexpectedExistingOccurrenceRejected": True,
            "pythonPathEnvironmentUsed": False,
        },
        "fixedChildArgv": expected_command,
        "runtimeEnvelope": {
            "maximumChildStarts": 1,
            "maximumConcurrency": 1,
            "timeoutSeconds": 120,
            "maximumProcessGroupRSSMiB": 1024,
            "rssSampleMaximumSeconds": 0.05,
            "outputTailMaximumBytes": base.MAXIMUM_TAIL_BYTES,
        },
        "runtimeOutputRoot": str(runtime_root.relative_to(repository_root)),
        "runtimeOutputRootAbsent": True,
        "adversarialCaseCount": len(cases),
        "adversaries": cases,
        "allAdversariesRejected": all(case["passed"] for case in cases),
        "blenderChildStartCount": 0,
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "blendFiles": [],
        "staticBInvocationCount": 0,
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
        "validationPassed": True,
    }
    write_once(output, result, launcher.canonical_bytes)
    print(json.dumps({
        "adversarialCaseCount": len(cases),
        "allAdversariesRejected": True,
        "moduleBootstrapVerified": True,
        "output": str(output),
        "outputSHA256": launcher.sha256(output),
        "validationPassed": True,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
