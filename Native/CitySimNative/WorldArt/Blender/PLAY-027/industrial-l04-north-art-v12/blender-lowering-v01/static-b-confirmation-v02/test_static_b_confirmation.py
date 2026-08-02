#!/usr/bin/env python3
"""No-DCC prelaunch proof for North v12 static-B confirmation v02."""

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
    "static-b-confirmation-v02"
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
        "play027_static_b_confirmation_v02", path
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("static-B confirmation launcher import failed")
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
        launcher.EXPECTED_V01_STOP,
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
        "cleanOutsideAuthorizedV02Paths": True,
        "passed": True,
    }


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    output = Path(options.output).absolute()
    expected_output = (repository_root / PRELAUNCH_RELATIVE).absolute()
    if output != expected_output:
        raise RuntimeError("exact static-B prelaunch output required")
    if output.exists() or output.is_symlink():
        raise RuntimeError("static-B prelaunch output must be absent")
    launcher = load_launcher(repository_root)
    static_a = launcher.load_static_a_launcher(repository_root)
    base = static_a.load_v01_launcher(repository_root)
    contract_path = Path(options.contract).resolve(strict=True)
    contract, accepted_contract = launcher.validate_contract(
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
        "static-B confirmation authority binding drift",
    ))
    changed = copy.deepcopy(contract["confirmation"])
    changed["maximumChildStarts"] = 2
    cases.append(expect_failure(
        "multiple-child-starts",
        lambda: launcher.validate_confirmation_values(changed),
        "static-B confirmation authority binding drift",
    ))
    changed = copy.deepcopy(contract["confirmation"])
    changed["allowedProcessID"] = "static-a"
    cases.append(expect_failure(
        "wrong-process-binding",
        lambda: launcher.validate_confirmation_values(changed),
        "static-B confirmation authority binding drift",
    ))
    cases.append(expect_failure(
        "missing-ancestry",
        lambda: base.assert_ancestor(repository_root, "0" * 40),
        "required commit is not an ancestor",
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
    changed_contract = copy.deepcopy(contract)
    changed_contract["materials"]["sha256"] = "0" * 64
    cases.append(expect_failure(
        "materials-hash-drift",
        lambda: launcher.verify_frozen_inputs(
            repository_root, changed_contract, base
        ),
        "hash drift",
    ))
    cases.append(expect_failure(
        "wrong-output-root",
        lambda: launcher.create_output_root(
            repository_root,
            contract,
            "static-b",
            Path("/private/tmp/not-authorized"),
            base,
        ),
        "exact static-B output root required",
    ))
    cases.append(expect_failure(
        "wrong-process",
        lambda: launcher.expected_output_root(
            repository_root, contract, "static-a"
        ),
        "only static-B is authorized",
    ))
    with tempfile.TemporaryDirectory(
        prefix="citysim-play027-static-b-v02-",
        dir="/private/tmp",
    ) as temporary:
        root = Path(temporary)
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
        changed_command = list(expected_command)
        changed_command[expression_index + 1] += ";x=1"
        cases.append(expect_failure(
            "changed-bootstrap-expression",
            lambda: launcher.validate_child_command(
                changed_command, expected_command
            ),
            "fixed static-B child argv drift",
        ))
        changed_command = list(expected_command)
        changed_command[-1] = "static-a"
        cases.append(expect_failure(
            "changed-child-process",
            lambda: launcher.validate_child_command(
                changed_command, expected_command
            ),
            "fixed static-B child argv drift",
        ))
        cases.append(expect_failure(
            "repository-mutation",
            lambda: base.validate_status_entries(
                [" M Native/CitySimNative/Rendering/CityScene.swift"],
                str(evidence_root.relative_to(repository_root)),
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
    changed_bindings = copy.deepcopy(expected_static_b_bindings)
    del changed_bindings["bindings"]["bridge"]
    cases.append(expect_failure(
        "input-bindings-missing-key",
        lambda: launcher.compare_input_bindings(
            accepted_bindings, changed_bindings, contract_canonical_sha
        ),
        "INPUT-BINDINGS differs outside the two-pointer allowlist",
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

    normalized = copy.deepcopy(contract)
    normalized.pop("confirmation")
    normalized["claim"] = copy.deepcopy(accepted_contract["claim"])
    normalized["evidenceRoot"] = accepted_contract["evidenceRoot"]
    normalized["recovery"] = copy.deepcopy(accepted_contract["recovery"])
    if normalized != accepted_contract:
        raise RuntimeError("contract normalization proof failed")
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
                "confirmationAuthority"
            ],
            "normalizesExactlyToAcceptedStaticAContract": True,
        },
        "frozenInputHashes": frozen,
        "confirmationSourceFiles": source_hashes,
        "dependencyScan": scan,
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
            "rssSampleMaximumSeconds": 0.05,
            "outputTailMaximumBytes": base.MAXIMUM_TAIL_BYTES,
        },
        "runtimeEvidenceRoot": str(
            evidence_root.relative_to(repository_root)
        ),
        "runtimeOutputRoot": str(runtime_root.relative_to(repository_root)),
        "runtimeEvidenceRootAbsent": True,
        "adversarialCaseCount": len(cases),
        "adversaries": cases,
        "allAdversariesRejected": all(case["passed"] for case in cases),
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
        "allAdversariesRejected": True,
        "contractCanonicalSHA256": contract_canonical_sha,
        "inputBindingsTwoPointerComparisonVerified": True,
        "output": str(output),
        "outputSHA256": launcher.sha256(output),
        "validationPassed": True,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
