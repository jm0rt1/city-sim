#!/usr/bin/env python3
"""Single-use North v12 static-B confirmation launcher."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
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
STATIC_A_SOURCE_RELATIVE = SOURCE_RELATIVE / "static-a-recovery-v02"
CONFIRMATION_SOURCE_RELATIVE = SOURCE_RELATIVE / "static-b-confirmation-v02"
CONTRACT_RELATIVE = (
    CONFIRMATION_SOURCE_RELATIVE / "CONFIRMATION-CONTRACT.json"
)
LAUNCHER_RELATIVE = (
    CONFIRMATION_SOURCE_RELATIVE / "launch_static_b_confirmation.py"
)
TEST_RELATIVE = (
    CONFIRMATION_SOURCE_RELATIVE / "test_static_b_confirmation.py"
)
PRELAUNCH_RELATIVE = (
    CONFIRMATION_SOURCE_RELATIVE / "PRELAUNCH-VALIDATION.json"
)
STATIC_A_CONTRACT_RELATIVE = (
    STATIC_A_SOURCE_RELATIVE / "RECOVERY-CONTRACT.json"
)
STATIC_A_LAUNCHER_RELATIVE = (
    STATIC_A_SOURCE_RELATIVE / "launch_static_a_module_bootstrap.py"
)
IMPORTER_RELATIVE = SOURCE_RELATIVE / "import_v12_scene.py"
LOWERER_RELATIVE = SOURCE_RELATIVE / "lower_v12_scene.py"
AUTHORITY_RELATIVE = Path(
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-NORTH-V12-STATIC-B-CONFIRMATION-V02-AUTHORITY.md"
)
STATIC_A_RESULT_RELATIVE = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12/blender-lowering-v01/"
    "static-a-recovery-v02/static-a"
)
EXPECTED_BRANCH = "codex/citysim-world-art"
EXPECTED_AUTHORITY_COMMIT = "73300af6f2ae6e31c4f818c078f82cc73ce4c70b"
EXPECTED_V01_STOP = "3e5d418b6c805f3a68410be93c77afb7e3d26194"
EXPECTED_STATIC_A_INTEGRATION = "28103902a75c8232644a998a34dcaf33ca643a63"
EXPECTED_AUTHORITY_SHA256 = (
    "fdb36c1ab9061490724b04b9a351d711bd81ec13ec3edda9c42c455316d1162a"
)
EXPECTED_CLAIM_SHA256 = (
    "154abc8a6f2360421b4fa4a7367290342b78cc9f4e10b69e2bceafb547ee3a86"
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
EXPECTED_LOWERER_SHA256 = (
    "7dc01ddc56bfff3ee9efca417ad0f70265d92daf99281dd53f7231c691e53a42"
)
EXPECTED_IMPORTER_SHA256 = (
    "ec726d584ce4b22253fca486e82bc6a198616debed94358d76f6dac7a1f62988"
)
EXPECTED_STATIC_A_CLAIM_SHA256 = (
    "83fa2894bd822c5b7b25d8da37903dec5f039b30fc334f7b59ca3d8eba82bf0d"
)
EXPECTED_STATIC_A_INPUT_BINDINGS_SHA256 = (
    "ee3691ffc5a8a817d35913e4359a66f0efb12042ab505f1f95b2b2c9c7bd3e1c"
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
ATTEMPT_ID = "industrial-l04-north-v12-static-b-confirmation-v02"


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


def load_static_a_launcher(repository_root: Path) -> Any:
    path = repository_root / STATIC_A_LAUNCHER_RELATIVE
    if sha256(path) != EXPECTED_STATIC_A_LAUNCHER_SHA256:
        raise RuntimeError("accepted static-A launcher hash drift")
    specification = importlib.util.spec_from_file_location(
        "play027_static_a_module_bootstrap_v02", path
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("accepted static-A launcher import failed")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def expected_confirmation_block() -> dict[str, Any]:
    return {
        "authorityCommit": EXPECTED_AUTHORITY_COMMIT,
        "authorityFile": str(AUTHORITY_RELATIVE),
        "authoritySHA256": EXPECTED_AUTHORITY_SHA256,
        "acceptedStaticAContract": {
            "file": str(STATIC_A_CONTRACT_RELATIVE),
            "sha256": EXPECTED_STATIC_A_CONTRACT_FILE_SHA256,
        },
        "acceptedStaticARoot": str(STATIC_A_RESULT_RELATIVE),
        "acceptedStaticAInputBindingsSHA256":
            EXPECTED_STATIC_A_INPUT_BINDINGS_SHA256,
        "acceptedStaticAContractCanonicalSHA256":
            EXPECTED_STATIC_A_CONTRACT_CANONICAL_SHA256,
        "acceptedStaticAClaimSHA256": EXPECTED_STATIC_A_CLAIM_SHA256,
        "allowedInputBindingDifferences":
            list(ALLOWED_INPUT_BINDING_POINTERS),
        "slot": "dcc-1",
        "attemptID": ATTEMPT_ID,
        "allowedProcessID": "static-b",
        "maximumChildStarts": 1,
    }


def validate_confirmation_values(value: Any) -> None:
    if value != expected_confirmation_block():
        raise RuntimeError("static-B confirmation authority binding drift")


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
        raise RuntimeError("exact static-B v02 contract required")
    accepted_path = base.exact_regular(
        repository_root / STATIC_A_CONTRACT_RELATIVE,
        EXPECTED_STATIC_A_CONTRACT_FILE_SHA256,
        repository_root,
    )
    accepted = load_json(accepted_path)
    if canonical_sha256(accepted) != (
        EXPECTED_STATIC_A_CONTRACT_CANONICAL_SHA256
    ):
        raise RuntimeError("accepted static-A canonical contract hash drift")
    contract = load_json(actual)
    confirmation = contract.get("confirmation")
    validate_confirmation_values(confirmation)
    comparison = copy.deepcopy(contract)
    comparison.pop("confirmation")
    comparison["claim"] = copy.deepcopy(accepted["claim"])
    comparison["evidenceRoot"] = accepted["evidenceRoot"]
    comparison["recovery"] = copy.deepcopy(accepted["recovery"])
    if comparison != accepted:
        raise RuntimeError(
            "static-B contract differs beyond claim, output root, and authority"
        )
    if contract["claim"]["sha256"] != EXPECTED_CLAIM_SHA256:
        raise RuntimeError("current claim binding drift")
    return contract, accepted


def verify_frozen_inputs(
    repository_root: Path,
    contract: dict[str, Any],
    base: Any,
) -> dict[str, str]:
    result = base.verify_frozen_inputs(repository_root, contract)
    additions = {
        "staticBConfirmationAuthority": (
            AUTHORITY_RELATIVE, EXPECTED_AUTHORITY_SHA256
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
        EXPECTED_V01_STOP,
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
        repository_root / STATIC_A_LAUNCHER_RELATIVE,
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
        raise RuntimeError("exact static-B output root required")
    expected.relative_to(repository_root)
    base.assert_nofollow_chain(expected, repository_root)
    base.ensure_absent_output_path(expected)
    evidence_root = expected.parent
    base.ensure_absent_output_path(evidence_root)
    parent = base.exact_directory(evidence_root.parent, repository_root)
    os.mkdir(evidence_root, mode=0o755)
    created_parent = base.exact_directory(evidence_root, repository_root)
    if created_parent.parent != parent:
        raise RuntimeError("static-B evidence parent drift")
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


def validate_child_command(
    actual: list[str],
    expected: list[str],
) -> None:
    if actual != expected:
        raise RuntimeError("fixed static-B child argv drift")
    if actual.count("--python-expr") != 1:
        raise RuntimeError("exactly one module bootstrap expression required")
    expression_index = actual.index("--python-expr")
    if actual[expression_index + 2] != "--python":
        raise RuntimeError("unchanged importer must immediately follow bootstrap")
    if actual.count("--python") != 1:
        raise RuntimeError("exactly one importer execution required")


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
        file_results.append({
            "file": name,
            "acceptedStaticASHA256": a_hash,
            "staticBSHA256": b_hash,
            "byteIdentical": static_a.read_bytes() == static_b.read_bytes(),
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
        "allFiveByteIdentical": all(
            item["byteIdentical"] for item in file_results
        ),
        "inputBindings": binding_result,
        "processProvenanceExcludedFromByteIdentity": True,
        "passed": True,
    }


def write_success_evidence(
    base: Any,
    evidence_root: Path,
    comparison: dict[str, Any],
    provenance_path: Path,
) -> None:
    provenance_sha = sha256(provenance_path)
    validation = {
        "schema": 1,
        "task": "PLAY-027",
        "attemptID": ATTEMPT_ID,
        "processID": "static-b",
        "fiveRunNeutralFilesByteIdentical": True,
        "inputBindingsStrictTwoPointerComparison": True,
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
        "stage": "static-b-confirmation",
        "attemptID": ATTEMPT_ID,
        "processID": "static-b",
        "comparison": {
            "file": "AB-COMPARISON.json",
            "sha256": hashlib.sha256(
                canonical_bytes(comparison)
            ).hexdigest(),
        },
        "processProvenance": {
            "file": "static-b/PROCESS-PROVENANCE.json",
            "sha256": provenance_sha,
        },
        "validation": {
            "file": "CONFIRMATION-VALIDATION.json",
            "sha256": hashlib.sha256(
                canonical_bytes(validation)
            ).hexdigest(),
        },
        "disposition": "STATIC_B_CONFIRMATION_CANDIDATE",
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    base.exclusive_write_json(evidence_root / "AB-COMPARISON.json", comparison)
    base.exclusive_write_json(
        evidence_root / "CONFIRMATION-VALIDATION.json", validation
    )
    base.exclusive_write_json(evidence_root / "HANDOFF.json", handoff)


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
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
    peak_rss_kib = 0
    sample_times: list[float] = []
    termination = "not-started"
    try:
        with tempfile.NamedTemporaryFile(
            mode="w+b",
            prefix="citysim-play027-v12-static-b-confirmation-v02-output-",
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
                    int(contract["blender"]["maximumProcessGroupRSSMiB"])
                    * 1024,
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
        comparison: dict[str, Any] | None = None
        if success:
            try:
                comparison = compare_static_results(
                    repository_root, contract, output_root
                )
            except RuntimeError as error:
                termination = f"static-comparison-failure: {error}"
                success = False
        result = base.receipt_base(
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
        result["attemptID"] = ATTEMPT_ID
        result["slot"] = "dcc-1"
        result["repositoryContextBefore"] = context_before
        result["frozenInputHashesBefore"] = frozen_before
        result["frozenInputHashesAfter"] = frozen_after
        result["dependencyScan"] = scan
        result["staticAComparison"] = (
            comparison if success else {"performed": success, "passed": False}
        )
        if success and comparison is not None:
            result["repositoryContextAfter"] = validate_context(
                repository_root, base, evidence_root
            )
            base.exclusive_write_json(
                output_root / "PROCESS-PROVENANCE.json", result
            )
            write_success_evidence(
                base,
                evidence_root,
                comparison,
                output_root / "PROCESS-PROVENANCE.json",
            )
            print(json.dumps({
                "processID": options.process_id,
                "returnCode": process.returncode,
                "terminationDisposition": termination,
                "elapsedMonotonicSeconds": result["elapsedMonotonicSeconds"],
                "peakProcessGroupRSSMiB": result["peakProcessGroupRSSMiB"],
                "fiveRunNeutralFilesByteIdentical": True,
                "inputBindingsTwoPointerComparison": True,
                "validationPassed": True,
            }, sort_keys=True))
            return
        result["failure"] = {"reason": termination}
        base.exclusive_write_json(output_root / "FAILURE.json", result)
        raise RuntimeError(f"static-B confirmation failed closed: {termination}")
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
