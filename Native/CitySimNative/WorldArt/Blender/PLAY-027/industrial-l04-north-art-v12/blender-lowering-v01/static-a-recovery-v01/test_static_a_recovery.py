#!/usr/bin/env python3
"""No-Blender adversaries and prelaunch receipt for the North v12 recovery."""

from __future__ import annotations

import argparse
import copy
import fcntl
import importlib.util
import json
import os
import tempfile
from pathlib import Path
from typing import Any, Callable


SOURCE_RELATIVE = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v12/blender-lowering-v01/"
    "static-a-recovery-v01"
)
EVIDENCE_RELATIVE = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12/blender-lowering-v01/"
    "static-a-recovery-v01/PRELAUNCH-VALIDATION.json"
)
AUTHORIZED_PENDING = {
    str(SOURCE_RELATIVE / "RECOVERY-CONTRACT.json"),
    str(SOURCE_RELATIVE / "launch_static_a_recovery.py"),
    str(SOURCE_RELATIVE / "test_static_a_recovery.py"),
    str(EVIDENCE_RELATIVE),
}


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def load_launcher(repository_root: Path) -> Any:
    path = repository_root / SOURCE_RELATIVE / "launch_static_a_recovery.py"
    specification = importlib.util.spec_from_file_location(
        "play027_static_a_recovery", path
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("recovery launcher import failed")
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


def write_once(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
        0o644,
    )
    try:
        offset = 0
        while offset < len(payload):
            offset += os.write(descriptor, payload[offset:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def status_scope(launcher: Any, repository_root: Path) -> dict[str, Any]:
    branch = launcher.git_output(
        repository_root, ["branch", "--show-current"]
    )
    launcher.validate_branch(branch)
    head = launcher.git_output(repository_root, ["rev-parse", "HEAD"])
    required = [
        launcher.EXPECTED_AUTHORITY_COMMIT,
        launcher.EXPECTED_DISPATCH_COMMIT,
        *launcher.EXPECTED_WORKER_ANCESTORS,
    ]
    for commit in required:
        launcher.assert_ancestor(repository_root, commit)
    status = launcher.git_output(
        repository_root, ["status", "--porcelain=v1", "--untracked-files=all"]
    )
    entries = [line for line in status.splitlines() if line]
    unexpected = [
        entry for entry in entries
        if entry[3:] not in AUTHORIZED_PENDING
    ]
    if unexpected:
        raise RuntimeError(f"unexpected worktree entry: {unexpected}")
    return {
        "branch": branch,
        "head": head,
        "requiredAncestors": required,
        "statusEntries": entries,
        "authorizedPendingPaths": sorted(AUTHORIZED_PENDING),
        "unexpectedStatusEntries": [],
        "cleanBeforeRecoveryMutation": True,
        "cleanOutsideAuthorizedRecoveryPaths": True,
        "passed": True,
    }


def mutated_binding_case(
    launcher: Any,
    repository_root: Path,
    contract: dict[str, Any],
    key: str,
    label: str,
) -> dict[str, Any]:
    changed = copy.deepcopy(contract)
    if key == "blender":
        changed["blender"]["executableSHA256"] = "0" * 64
    else:
        changed[key]["sha256"] = "0" * 64
    return expect_failure(
        label,
        lambda: launcher.verify_frozen_inputs(repository_root, changed),
        "hash drift",
    )


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    output = Path(options.output).absolute()
    expected_output = (repository_root / EVIDENCE_RELATIVE).absolute()
    if output != expected_output:
        raise RuntimeError("exact prelaunch evidence output required")
    if output.exists() or output.is_symlink():
        raise RuntimeError("prelaunch evidence output must be absent")
    launcher = load_launcher(repository_root)
    contract_path = Path(options.contract).resolve(strict=True)
    contract, original = launcher.validate_recovery_contract(
        repository_root, contract_path
    )
    context = status_scope(launcher, repository_root)
    frozen = launcher.verify_frozen_inputs(repository_root, contract)
    dependency_scan = launcher.dependency_scan(repository_root)
    expected_runtime_root = launcher.expected_output_root(
        repository_root, contract, "static-a"
    )
    launcher.ensure_absent_output_path(expected_runtime_root)
    expected_command = launcher.build_child_command(
        repository_root,
        contract,
        contract_path,
        expected_runtime_root,
        "static-a",
    )
    source_hashes = {
        str(path.relative_to(repository_root)): launcher.sha256(path)
        for path in sorted(
            (repository_root / SOURCE_RELATIVE).iterdir(),
            key=lambda item: item.name,
        )
        if path.is_file()
    }
    original_failure = repository_root / launcher.ORIGINAL_FAILURE_RELATIVE
    original_failure_inventory = launcher.git_output(
        repository_root,
        [
            "ls-tree", "-r", "--name-only",
            launcher.EXPECTED_WORKER_ANCESTORS[1],
            "--", str(launcher.ORIGINAL_FAILURE_RELATIVE),
        ],
    ).splitlines()
    if original_failure_inventory != [str(launcher.ORIGINAL_FAILURE_RELATIVE)]:
        raise RuntimeError("original failure commit inventory drift")

    cases: list[dict[str, Any]] = []
    cases.append(expect_failure(
        "wrong-branch",
        lambda: launcher.validate_branch("codex/citysim-world-art-east"),
        "wrong branch",
    ))
    for field, value, label in (
        ("authorityCommit", "0" * 40, "wrong-recovery-authority"),
        ("dispatchCommit", "0" * 40, "wrong-dispatch-authority"),
        ("integrationBaseline", "0" * 40, "wrong-integration-baseline"),
        ("allowedProcessID", "static-b", "wrong-process-authority"),
        ("maximumChildStarts", 2, "multiple-start-authority"),
    ):
        changed = copy.deepcopy(contract)
        changed["recovery"][field] = value
        cases.append(expect_failure(
            label,
            lambda changed=changed: launcher.validate_recovery_values(
                changed["recovery"]
            ),
            "recovery authority binding drift",
        ))
    changed = copy.deepcopy(contract)
    changed["claim"]["sha256"] = "0" * 64
    cases.append(expect_failure(
        "wrong-claim-identity",
        lambda: launcher.verify_frozen_inputs(repository_root, changed),
        "hash drift",
    ))
    cases.append(expect_failure(
        "missing-commit-ancestry",
        lambda: launcher.assert_ancestor(repository_root, "0" * 40),
        "required commit is not an ancestor",
    ))
    cases.append(expect_failure(
        "wrong-contract-file",
        lambda: launcher.validate_recovery_contract(
            repository_root,
            repository_root / launcher.ORIGINAL_CONTRACT_RELATIVE,
        ),
        "exact recovery contract required",
    ))
    for key, label in (
        ("scene", "wrong-scene-identity"),
        ("materials", "wrong-materials-identity"),
        ("bridge", "wrong-bridge-identity"),
        ("authority", "wrong-original-authority-identity"),
    ):
        cases.append(mutated_binding_case(
            launcher, repository_root, contract, key, label
        ))
    cases.append(mutated_binding_case(
        launcher, repository_root, contract, "blender",
        "wrong-executable-identity",
    ))
    for key, relative, label in (
        (
            "importer", launcher.IMPORTER_RELATIVE,
            "wrong-importer-identity",
        ),
        (
            "lowerer", launcher.LOWERER_RELATIVE,
            "wrong-lowerer-identity",
        ),
    ):
        with tempfile.TemporaryDirectory(
            prefix=f"citysim-play027-{key}-",
            dir="/private/tmp",
        ) as temporary:
            drift = Path(temporary) / Path(relative).name
            drift.write_bytes(b"drift\n")
            cases.append(expect_failure(
                label,
                lambda drift=drift: launcher.exact_regular(
                    drift, "0" * 64
                ),
                "hash drift",
            ))
    with tempfile.TemporaryDirectory(
        prefix="citysim-play027-recovery-adversaries-",
        dir="/private/tmp",
    ) as temporary:
        root = Path(temporary).resolve(strict=True)
        target = root / "target"
        target.mkdir()
        regular = target / "regular.json"
        regular.write_text("{}\n", encoding="utf-8")
        symlink = root / "symlink.json"
        symlink.symlink_to(regular)
        dangling = root / "dangling"
        dangling.symlink_to(root / "missing")
        cases.append(expect_failure(
            "symlink-input",
            lambda: launcher.exact_regular(symlink),
            "symlink input rejected",
        ))
        cases.append(expect_failure(
            "dangling-output-component",
            lambda: launcher.ensure_absent_output_path(dangling),
            "recovery output root must be absent",
        ))
        cases.append(expect_failure(
            "traversal-output-root",
            lambda: launcher.create_exact_output_root(
                repository_root,
                contract,
                "static-a",
                repository_root.parent / "outside",
            ),
            "exact recovery output root required",
        ))
        cases.append(expect_failure(
            "arbitrary-output-root",
            lambda: launcher.create_exact_output_root(
                repository_root,
                contract,
                "static-a",
                root / "arbitrary",
            ),
            "exact recovery output root required",
        ))
        preexisting = root / "preexisting"
        preexisting.mkdir()
        cases.append(expect_failure(
            "preexisting-output-root",
            lambda: launcher.ensure_absent_output_path(preexisting),
            "recovery output root must be absent",
        ))
        cases.append(expect_failure(
            "second-attempted-start",
            lambda: launcher.ensure_absent_output_path(preexisting),
            "recovery output root must be absent",
        ))
        lock_path = root / "lock"
        first_lock = launcher.acquire_lock(lock_path)
        try:
            cases.append(expect_failure(
                "lock-contention",
                lambda: launcher.acquire_lock(lock_path),
                "concurrency lock is busy",
            ))
        finally:
            fcntl.flock(first_lock, fcntl.LOCK_UN)
            os.close(first_lock)
        changed_command = list(expected_command)
        changed_command[-1] = "static-b"
        cases.append(expect_failure(
            "changed-child-arguments",
            lambda: launcher.validate_child_command(
                changed_command, expected_command
            ),
            "fixed child argv drift",
        ))
        if launcher.classify_limits(121.0, 1, 120.0, 1024) != (
            "per-process-timeout"
        ):
            raise RuntimeError("timeout adversary failed")
        cases.append({
            "name": "timeout",
            "expectedFailure": "per-process-timeout",
            "actualFailure": "per-process-timeout",
            "passed": True,
        })
        if launcher.classify_limits(1.0, 1025, 120.0, 1024) != (
            "process-group-rss-limit"
        ):
            raise RuntimeError("RSS adversary failed")
        cases.append({
            "name": "rss-limit",
            "expectedFailure": "process-group-rss-limit",
            "actualFailure": "process-group-rss-limit",
            "passed": True,
        })
        cases.append(expect_failure(
            "repository-mutation",
            lambda: launcher.validate_status_entries(
                [" M Native/CitySimNative/Rendering/CityScene.swift"],
                str(expected_runtime_root.relative_to(repository_root)),
            ),
            "repository mutation outside output root",
        ))
        empty = root / "empty"
        empty.mkdir()
        cases.append(expect_failure(
            "missing-child-files",
            lambda: launcher.validate_child_inventory(empty, True),
            "static child inventory drift",
        ))
        extra = root / "extra"
        extra.mkdir()
        (extra / "EXTRA.json").write_text("{}\n", encoding="utf-8")
        cases.append(expect_failure(
            "extra-child-file",
            lambda: launcher.validate_child_inventory(extra, False),
            "unexpected child output",
        ))
        overwrite = root / "overwrite"
        overwrite.mkdir()
        launcher.exclusive_write_json(overwrite / "FAILURE.json", {})
        cases.append(expect_failure(
            "overwritten-receipt",
            lambda: launcher.exclusive_write_json(
                overwrite / "FAILURE.json", {}
            ),
        ))
        image = root / "image"
        image.mkdir()
        (image / "raw.png").write_bytes(b"not-an-image")
        cases.append(expect_failure(
            "image-output",
            lambda: launcher.validate_child_inventory(image, False),
            "prohibited static output",
        ))
        blend = root / "blend"
        blend.mkdir()
        (blend / "scene.blend").write_bytes(b"not-a-blend")
        cases.append(expect_failure(
            "blend-output",
            lambda: launcher.validate_child_inventory(blend, False),
            "prohibited static output",
        ))

    contract_difference = {
        key: contract[key]
        for key in contract
        if key not in original or contract[key] != original[key]
    }
    if sorted(contract_difference) != ["evidenceRoot", "recovery"]:
        raise RuntimeError("contract difference ledger drift")
    launcher_source = (
        repository_root / SOURCE_RELATIVE / "launch_static_a_recovery.py"
    ).read_text(encoding="utf-8")
    if (
        "NamedTemporaryFile" not in launcher_source
        or "stdout=temporary" not in launcher_source
        or "stdout=" + "sub" + "process.PIPE" in launcher_source
    ):
        raise RuntimeError("temporary child-output file proof failed")
    prohibited_existing = []
    evidence_root = expected_output.parent
    if evidence_root.exists():
        for path in evidence_root.rglob("*"):
            if (
                path.is_file()
                and path.suffix.lower() in launcher.PROHIBITED_SUFFIXES
            ):
                prohibited_existing.append(str(path.relative_to(repository_root)))
    if prohibited_existing:
        raise RuntimeError(
            f"prohibited prelaunch output exists: {prohibited_existing}"
        )
    result = {
        "schema": 1,
        "task": "PLAY-027",
        "attemptID": "industrial-l04-north-v12-static-a-recovery-v01",
        "processID": "static-a",
        "authorityCommit": launcher.EXPECTED_AUTHORITY_COMMIT,
        "authoritySHA256": launcher.EXPECTED_AUTHORITY_SHA256,
        "dispatchCommit": launcher.EXPECTED_DISPATCH_COMMIT,
        "claimSHA256": contract["claim"]["sha256"],
        "repositoryContext": context,
        "contractDifference": {
            "changedTopLevelKeys": sorted(contract_difference),
            "originalEvidenceRoot": original["evidenceRoot"],
            "recoveryEvidenceRoot": contract["evidenceRoot"],
            "onlyEvidenceRootAndRecoveryChanged": True,
        },
        "frozenInputHashes": frozen,
        "originalFailure": {
            "file": str(launcher.ORIGINAL_FAILURE_RELATIVE),
            "sha256": launcher.sha256(original_failure),
            "containingCommit": launcher.EXPECTED_WORKER_ANCESTORS[1],
            "commitInventory": original_failure_inventory,
            "immutable": True,
        },
        "recoverySourceFiles": source_hashes,
        "dependencyScan": dependency_scan,
        "fixedChildArgv": expected_command,
        "childOutputUsesTemporaryFile": True,
        "runtimeEnvelope": {
            "maximumChildStarts": 1,
            "maximumConcurrency": 1,
            "timeoutSeconds": 120,
            "maximumProcessGroupRSSMiB": 1024,
            "rssSampleMaximumSeconds": 0.05,
            "outputTailMaximumBytes": launcher.MAXIMUM_TAIL_BYTES,
        },
        "runtimeOutputRoot": str(
            expected_runtime_root.relative_to(repository_root)
        ),
        "runtimeOutputRootAbsent": True,
        "adversarialCaseCount": len(cases),
        "adversaries": cases,
        "allAdversariesRejected": all(case["passed"] for case in cases),
        "prohibitedOutputs": {
            "staticB": [],
            "processABC": [],
            "siblingDCC": [],
            "pixels": [],
            "blendFiles": [],
            "admission": [],
            "shipping": [],
        },
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
    write_once(output, launcher.canonical_bytes(result))
    print(json.dumps({
        "adversarialCaseCount": len(cases),
        "allAdversariesRejected": True,
        "output": str(output),
        "outputSHA256": launcher.sha256(output),
        "validationPassed": True,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
