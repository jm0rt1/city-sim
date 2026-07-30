#!/usr/bin/env python3
"""No-DCC adversarial proof for the North v12 Process-A schedule adapter."""

from __future__ import annotations

import argparse
import atexit
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
    "industrial-l04-north-art-v12/process-a-schedule-adapter-v01"
)
EVIDENCE_RELATIVE = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v12/process-a-schedule-adapter-v01/"
    "TRUSTED-CURRENT-ZERO-CHILD-READINESS.json"
)
TRUSTED_MASTER_COMMIT = "5d86e804be679c765c2465c60ceaee72f3702c48"


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
        raise RuntimeError(f"could not load {name}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def git(repository: Path, *arguments: str) -> str:
    environment = os.environ.copy()
    environment.update(
        {
            "GIT_AUTHOR_DATE": "2001-01-01T00:00:00Z",
            "GIT_COMMITTER_DATE": "2001-01-01T00:00:00Z",
        }
    )
    result = subprocess.run(
        ["git", *arguments],
        cwd=repository,
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"temporary Git command failed: {' '.join(arguments)}")
    return result.stdout.strip()


def write_exclusive(path: Path, value: Any, canonical: Callable[[Any], bytes]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.parent.is_symlink():
        raise RuntimeError("readiness output parent must not be a symlink")
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


def fixture(
    repository_root: Path,
    adapter: Any,
    contract: dict[str, Any],
) -> dict[str, Any]:
    directions = {
        "north": ("PLAY-027", "codex/citysim-world-art"),
        "east": ("PLAY-079", "codex/citysim-world-art-east"),
        "south": ("PLAY-080", "codex/citysim-world-art-south"),
        "west": ("PLAY-081", "codex/citysim-world-art-west"),
    }
    grants = []
    for direction, (claim, branch) in directions.items():
        processes = []
        for process in ("A", "B", "C"):
            granted = direction == "north" and process == "A"
            processes.append(
                {
                    "grantId": (
                        "north:A"
                        if direction == "north" and process == "A"
                        else f"fixture-{direction}-{process}"
                    ),
                    "process": process,
                    "state": "granted" if granted else "blocked",
                    "slotId": "dcc-1" if granted else None,
                    "maximumChildStarts": 1 if granted else 0,
                    "orchestratorOnly": True,
                    "directLowLevelInvocationAllowed": False,
                }
            )
        roots = (
            contract["expectedExclusiveRoots"]
            if direction == "north"
            else [
                f"Native/CitySimNative/WorldArt/Blender/PLAY-0{78 + len(grants)}/fixture",
                f"docs/production/evidence/PLAY-0{78 + len(grants)}/fixture",
            ]
        )
        grants.append(
            {
                "direction": direction,
                "claim": claim,
                "branch": branch,
                "claimSha256": (
                    contract["claim"]["sha256"]
                    if direction == "north"
                    else hashlib.sha256(direction.encode()).hexdigest()
                ),
                "baseCommit": contract["publishedBaseCommit"],
                "orchestrator": (
                    contract["directionScheduleAdapter"]
                    if direction == "north"
                    else {
                        "path": str(
                            SOURCE_ROOT
                            / "_test-fixtures"
                            / f"{direction}-schedule-adapter.py"
                        ),
                        "sha256": hashlib.sha256(
                            f"{direction}:schedule-adapter".encode()
                        ).hexdigest(),
                    }
                ),
                "exclusiveRoots": roots,
                "processes": processes,
            }
        )
    return {
        "schema": 1,
        "batch": contract["batch"],
        "phase": contract["phase"],
        "issuedAt": "2026-07-30T00:00:00Z",
        "integrationAuthorityCommit": contract["publishedBaseCommit"],
        "familyContract": contract["familyContract"],
        "appearanceLock": None,
        "sourceProductionProfile": None,
        "computeEnvelope": {
            "maximumSimultaneousDCCProcesses": 1,
            "slotIds": ["dcc-1"],
            "queueOrder": ["north:A"],
        },
        "directionGrants": grants,
    }


def install_sibling_orchestrator_fixtures(repository_root: Path) -> Callable[[], None]:
    fixture_parent = repository_root / SOURCE_ROOT / "_test-fixtures"
    fixture_parent.mkdir(exist_ok=False)
    fixture_paths: list[Path] = []
    for direction in ("east", "south", "west"):
        fixture_path = fixture_parent / f"{direction}-schedule-adapter.py"
        descriptor = os.open(
            fixture_path,
            os.O_WRONLY
            | os.O_CREAT
            | os.O_EXCL
            | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
            0o600,
        )
        try:
            os.write(descriptor, f"{direction}:schedule-adapter".encode())
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
        fixture_paths.append(fixture_path)

    def cleanup() -> None:
        for fixture_path in fixture_paths:
            fixture_path.unlink(missing_ok=True)
        if fixture_parent.exists():
            fixture_parent.rmdir()

    atexit.register(cleanup)
    return cleanup


def validate_fixture(
    repository_root: Path,
    adapter: Any,
    shared: Any,
    contract: dict[str, Any],
    value: dict[str, Any],
) -> dict[str, Any]:
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".json",
        prefix="play027-north-schedule-fixture-",
        dir="/private/tmp",
        delete=False,
    ) as handle:
        json.dump(value, handle, sort_keys=True)
        path = Path(handle.name)
    try:
        shared.validate(repository_root, path)
        return adapter.validate_north_grant(
            repository_root,
            contract,
            value,
        )
    finally:
        path.unlink(missing_ok=True)


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    output = Path(options.output).absolute()
    expected_output = (repository_root / EVIDENCE_RELATIVE).absolute()
    if output != expected_output:
        raise RuntimeError("exact zero-child readiness output required")
    if output.exists() or output.is_symlink():
        raise RuntimeError("zero-child readiness output must be absent")
    candidate_head = git(repository_root, "rev-parse", "HEAD")
    if (
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", TRUSTED_MASTER_COMMIT, candidate_head],
            cwd=repository_root,
            check=False,
        ).returncode
        != 0
    ):
        raise RuntimeError("trusted Integration master is not an ancestor of candidate")
    source_root = repository_root / SOURCE_ROOT
    adapter_path = source_root / "consume_north_process_a_schedule.py"
    contract_path = source_root / "ADAPTER-CONTRACT.json"
    test_path = source_root / "test_north_process_a_schedule_adapter.py"
    adapter = load_module(adapter_path, "play027_north_schedule_adapter")
    contract = adapter.validate_contract(repository_root, contract_path)
    cleanup_sibling_fixtures = install_sibling_orchestrator_fixtures(repository_root)
    validator_path = adapter.verify_file_binding(
        repository_root,
        contract["scheduleValidator"],
        "scheduleValidator",
    )
    shared = adapter.load_shared_validator(repository_root, validator_path)
    valid = fixture(repository_root, adapter, contract)
    grant = validate_fixture(repository_root, adapter, shared, contract, valid)
    if grant["grantValidated"] is not True or grant["processStarted"] is not False:
        raise RuntimeError("valid in-memory grant did not remain zero-child")

    cases: list[dict[str, Any]] = []

    def case(name: str, mutate: Callable[[dict[str, Any]], None], reason: str) -> None:
        changed = copy.deepcopy(valid)
        mutate(changed)
        cases.append(
            expect_failure(
                name,
                lambda: validate_fixture(
                    repository_root,
                    adapter,
                    shared,
                    contract,
                    changed,
                ),
                reason,
            )
        )

    case("wrong-phase", lambda item: item.update(phase="postlock_abc"), "postlock schedule requires appearance lock")
    case("wrong-batch", lambda item: item.update(batch="other"), "wrong batch")
    case(
        "wrong-direction-claim",
        lambda item: item["directionGrants"][0].update(claim="PLAY-079"),
        "north claim/branch mismatch",
    )
    case(
        "wrong-claim-hash",
        lambda item: item["directionGrants"][0].update(claimSha256="0" * 64),
        "claim hash drift",
    )
    case(
        "wrong-base",
        lambda item: item["directionGrants"][0].update(
            baseCommit="c9d3e754447d4c87ea4d8123c54baad5259d549f"
        ),
        "base commit drift",
    )
    case(
        "wrong-slot",
        lambda item: item["directionGrants"][0]["processes"][0].update(slotId="dcc-2"),
        "unknown slot",
    )
    case(
        "wrong-queue",
        lambda item: item["computeEnvelope"].update(queueOrder=[]),
        "queueOrder must contain every and only granted process",
    )
    case(
        "wrong-roots",
        lambda item: item["directionGrants"][0].update(
            exclusiveRoots=[
                "Native/wrong",
                "docs/wrong",
            ]
        ),
        "exclusive roots drift",
    )
    case(
        "wrong-orchestrator",
        lambda item: item["directionGrants"][0].update(
            orchestrator=contract["scheduleValidator"]
        ),
        "direction schedule-adapter binding drift",
    )
    case(
        "prelock-appearance-lock-present",
        lambda item: item.update(appearanceLock=contract["familyContract"]),
        "prelock schedule must not bind an appearance lock",
    )
    case(
        "prelock-profile-present",
        lambda item: item.update(sourceProductionProfile=contract["familyContract"]),
        "prelock schedule must not bind a source profile",
    )
    case(
        "wrong-child-limit",
        lambda item: item["directionGrants"][0]["processes"][0].update(
            maximumChildStarts=0
        ),
        "north:A must allow exactly one child",
    )
    case(
        "blocked-process-a",
        lambda item: (
            item["directionGrants"][0]["processes"][0].update(
                state="blocked",
                slotId=None,
                maximumChildStarts=0,
            ),
            item["computeEnvelope"].update(queueOrder=[]),
        ),
        "prelock phase grants exactly North Process A",
    )
    case(
        "direct-low-level-enabled",
        lambda item: item["directionGrants"][0]["processes"][0].update(
            directLowLevelInvocationAllowed=True
        ),
        "direct low-level invocation is forbidden",
    )
    case(
        "orchestrator-only-disabled",
        lambda item: item["directionGrants"][0]["processes"][0].update(
            orchestratorOnly=False
        ),
        "all process starts must use the approved orchestrator",
    )
    case(
        "wrong-process-granted",
        lambda item: (
            item["directionGrants"][0]["processes"][0].update(
                state="blocked", slotId=None, maximumChildStarts=0
            ),
            item["directionGrants"][0]["processes"][1].update(
                state="granted", slotId="dcc-1", maximumChildStarts=1
            ),
            item["computeEnvelope"].update(queueOrder=["north:B"]),
        ),
        "prelock phase grants exactly North Process A",
    )

    cases.append(
        expect_failure(
            "missing-live-schedule",
            lambda: adapter.consume_published_schedule(
                repository_root,
                contract_path,
                repository_root
                / "docs/production/evidence/INTEGRATION/"
                "industrial-l04-prelock-north-a-schedule-v1.json",
                contract["publishedBaseCommit"],
            ),
            (
                "MISSING_PUBLISHED_SCHEDULE: "
                "docs/production/evidence/INTEGRATION/"
                "industrial-l04-prelock-north-a-schedule-v1.json"
            ),
        )
    )

    with tempfile.TemporaryDirectory(
        prefix="play027-schedule-publication-",
        dir="/private/tmp",
    ) as publication_directory:
        publication_root = Path(publication_directory)
        git(publication_root, "init")
        git(publication_root, "checkout", "-b", "main")
        git(publication_root, "config", "user.name", "PLAY-027 Test")
        git(publication_root, "config", "user.email", "play027@example.invalid")
        (publication_root / "README.md").write_text(
            "temporary publication fixture\n",
            encoding="utf-8",
        )
        git(publication_root, "add", "README.md")
        git(publication_root, "commit", "-m", "authority")
        authority_commit = git(publication_root, "rev-parse", "HEAD")
        schedule_relative = Path(
            "docs/production/evidence/INTEGRATION/"
            "temporary-prelock-north-a-schedule.json"
        )
        schedule_path = publication_root / schedule_relative
        schedule_path.parent.mkdir(parents=True)
        schedule_value = {"integrationAuthorityCommit": authority_commit}
        schedule_path.write_bytes(adapter.canonical_bytes(schedule_value))
        git(publication_root, "add", str(schedule_relative))
        git(publication_root, "commit", "-m", "publish schedule")
        publication_commit = git(publication_root, "rev-parse", "HEAD")
        adapter.verify_published_schedule(
            publication_root,
            schedule_path,
            schedule_value,
            publication_commit,
        )
        cases.append(
            {
                "name": "real-git-schedule-publication",
                "authorityPreexistsPublication": True,
                "publicationCommitContainsExactBytes": True,
                "passed": True,
            }
        )
        cases.append(
            expect_failure(
                "wrong-publication-commit",
                lambda: adapter.verify_published_schedule(
                    publication_root,
                    schedule_path,
                    schedule_value,
                    authority_commit,
                ),
                "requires a preexisting authority commit",
            )
        )
        git(publication_root, "checkout", "-b", "side", authority_commit)
        (publication_root / "SIDE.md").write_text("side\n", encoding="utf-8")
        git(publication_root, "add", "SIDE.md")
        git(publication_root, "commit", "-m", "nonancestor")
        nonancestor_commit = git(publication_root, "rev-parse", "HEAD")
        git(publication_root, "checkout", "main")
        cases.append(
            expect_failure(
                "nonancestor-publication-commit",
                lambda: adapter.verify_published_schedule(
                    publication_root,
                    schedule_path,
                    schedule_value,
                    nonancestor_commit,
                ),
                "Git check failed",
            )
        )
        changed_schedule = {"integrationAuthorityCommit": authority_commit, "stale": True}
        schedule_path.write_bytes(adapter.canonical_bytes(changed_schedule))
        git(publication_root, "add", str(schedule_relative))
        git(publication_root, "commit", "-m", "stale schedule bytes")
        cases.append(
            expect_failure(
                "stale-published-schedule-bytes",
                lambda: adapter.verify_published_schedule(
                    publication_root,
                    schedule_path,
                    changed_schedule,
                    publication_commit,
                ),
                "schedule bytes are not frozen at publication commit",
            )
        )
        untracked_path = schedule_path.with_name("untracked-schedule.json")
        untracked_path.write_bytes(adapter.canonical_bytes(schedule_value))
        cases.append(
            expect_failure(
                "untracked-published-schedule",
                lambda: adapter.verify_published_schedule(
                    publication_root,
                    untracked_path,
                    schedule_value,
                    publication_commit,
                ),
                "published schedule worktree bytes are dirty",
            )
        )

    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".json",
        prefix="play027-unpublished-schedule-",
        dir="/private/tmp",
        delete=False,
    ) as handle:
        json.dump(valid, handle, sort_keys=True)
        unpublished = Path(handle.name)
    try:
        cases.append(
            expect_failure(
                "unpublished-schedule",
                lambda: adapter.consume_published_schedule(
                    repository_root,
                    contract_path,
                    unpublished,
                    contract["publishedBaseCommit"],
                ),
                "schedule path escapes repository",
            )
        )
    finally:
        unpublished.unlink(missing_ok=True)

    cases.append(
        expect_failure(
            "schema-hash-drift",
            lambda: adapter.verify_file_binding(
                repository_root,
                contract["scheduleSchema"],
                "scheduleSchema",
                expected_sha256="0" * 64,
            ),
            "expected hash drift",
        )
    )
    cases.append(
        expect_failure(
            "validator-hash-drift",
            lambda: adapter.verify_file_binding(
                repository_root,
                contract["scheduleValidator"],
                "scheduleValidator",
                expected_sha256="0" * 64,
            ),
            "expected hash drift",
        )
    )

    syntax = ast.parse(adapter_path.read_text(encoding="utf-8"))
    forbidden_names = {"Popen", "system", "execv", "execve", "spawnl", "spawnv"}
    forbidden_calls = sorted(
        {
            node.func.attr
            for node in ast.walk(syntax)
            if isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and node.func.attr in forbidden_names
        }
    )
    source_text = adapter_path.read_text(encoding="utf-8")
    forbidden_tokens = [
        token
        for token in ("import bpy", "bpy.ops.render", "/Applications/Blender.app")
        if token in source_text
    ]
    if forbidden_calls or forbidden_tokens:
        raise RuntimeError(
            f"direct DCC surface detected: {forbidden_calls + forbidden_tokens}"
        )
    cases.append(
        {
            "name": "direct-low-level-dcc-surface-absent",
            "forbiddenCalls": forbidden_calls,
            "forbiddenTokens": forbidden_tokens,
            "subprocessPolicy": "git-only whitelist",
            "passed": True,
        }
    )

    cleanup_sibling_fixtures()
    atexit.unregister(cleanup_sibling_fixtures)
    status = subprocess.run(
        ["git", "status", "--porcelain=v1", "--untracked-files=all"],
        cwd=repository_root,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.splitlines()
    allowed_prefixes = {
        str(SOURCE_ROOT),
        str(EVIDENCE_RELATIVE.parent),
        (
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
            "industrial-l04-north-art-v12/process-a-execution-v01"
        ),
        (
            "docs/production/evidence/PLAY-027/industrial-l04/l04/"
            "blender-north-art-v12/process-a-execution-v01"
        ),
    }
    unexpected = [
        line
        for line in status
        if line
        and not any(line[3:].startswith(prefix) for prefix in allowed_prefixes)
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
        "trustedIntegrationMaster": TRUSTED_MASTER_COMMIT,
        "candidateHead": candidate_head,
        "trustedMasterIsAncestor": True,
        "authorityBaseCommit": contract["publishedBaseCommit"],
        "publishedAuthorityCommit": "2eb5ddcb97a84376d66a008f8a7ad6ab3c97209b",
        "claimSHA256": contract["claim"]["sha256"],
        "processAPrelaunchAuthority": contract["processAPrelaunchAuthority"],
        "processAOrchestrator": contract["processAOrchestrator"],
        "scheduleSchema": contract["scheduleSchema"],
        "scheduleValidator": contract["scheduleValidator"],
        "adapterAuthority": contract["adapterAuthority"],
        "familyContract": contract["familyContract"],
        "frozenNorthV12Inputs": contract["frozenNorthV12Inputs"],
        "adapter": {
            "path": str(adapter.ADAPTER_RELATIVE),
            "sha256": sha256(adapter_path),
            "mode": contract["adapterMode"],
        },
        "contract": {
            "path": str(adapter.CONTRACT_RELATIVE),
            "sha256": sha256(contract_path),
        },
        "tests": {
            "path": str(test_path.relative_to(repository_root)),
            "sha256": sha256(test_path),
            "adversarialCaseCount": len(cases),
            "allPassed": all(case["passed"] for case in cases),
            "cases": cases,
        },
        "positiveInMemoryGrantPlan": grant,
        "liveSchedule": {
            "present": False,
            "grantValidated": False,
            "disposition": "BLOCKED_PENDING_INTEGRATION_PUBLISHED_PRELOCK_NORTH_A_SCHEDULE",
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
        "directLowLevelInvocationAllowed": False,
        "appearanceLockPresent": False,
        "sourceProductionProfilePresent": False,
        "sourceAuthority": False,
        "integrationAdmitted": False,
        "rendererActivated": False,
        "productionSelected": False,
        "validationPassed": True,
    }
    write_exclusive(output, result, adapter.canonical_bytes)
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
