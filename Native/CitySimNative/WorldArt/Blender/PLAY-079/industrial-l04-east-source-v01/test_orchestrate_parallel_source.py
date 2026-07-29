#!/usr/bin/env python3
"""Zero-DCC tests for the PLAY-079 parallel-source orchestrator boundary."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
from typing import Any

import east_output_safety as output_safety
import orchestrate_parallel_source as orchestrator


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
FIXTURE_ROOT = SOURCE_ROOT / "fixtures/parallel-source"
SCRIPT_PATH = SOURCE_ROOT / "orchestrate_parallel_source.py"


def load_json(path: pathlib.Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"{path}: expected object")
    return value


def set_pointer(value: Any, pointer: str, replacement: Any) -> None:
    parts = pointer.removeprefix("/").split("/")
    current = value
    for part in parts[:-1]:
        current = current[int(part)] if isinstance(current, list) else current[part]
    leaf = parts[-1]
    if isinstance(current, list):
        current[int(leaf)] = replacement
    else:
        current[leaf] = replacement


def expect_code(callable_value: Any, code: str) -> dict[str, str]:
    try:
        callable_value()
    except orchestrator.OrchestrationRejected as error:
        if error.code != code:
            raise RuntimeError(
                f"expected {code}, got {error.code}: {error.detail}"
            ) from error
        return {"result": "REJECTED", "code": error.code}
    raise RuntimeError(f"expected rejection {code}")


def run_cli(*arguments: str) -> tuple[int, dict[str, Any], str]:
    completed = subprocess.run(
        [sys.executable, "-B", str(SCRIPT_PATH), *arguments],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"invalid CLI JSON: {completed.stdout!r}") from error
    return completed.returncode, payload, completed.stderr


def assert_zero_activity(payload: dict[str, Any]) -> None:
    for field in (
        "subprocessInvocations",
        "dccInvocations",
        "blenderProcessInvocations",
        "renderApiCalls",
        "repositoryWrites",
    ):
        if payload.get(field) != 0:
            raise RuntimeError(f"{field}: {payload.get(field)}")
    pixel_value = payload.get("pixelFiles", payload.get("pixelFilesCreated"))
    if pixel_value != 0:
        raise RuntimeError(f"pixel activity: {pixel_value}")


def validate_positive_fixtures() -> dict[str, Any]:
    results: dict[str, Any] = {}
    for name in ("VALID-OVERLAPPED.json", "VALID-NO-OVERLAP-NONREADY.json"):
        path = FIXTURE_ROOT / name
        direct = orchestrator.validate_dry_fixture(path)
        code, cli, stderr = run_cli("dry-structural", "--fixture", str(path))
        if code != 0 or stderr or cli != direct:
            raise RuntimeError(
                f"{name}: code={code}, stderr={stderr!r}, cli={cli}, direct={direct}"
            )
        assert_zero_activity(cli)
        results[name] = {
            "result": "PASS",
            "fixtureSha256": direct["fixtureSha256"],
            "execution": direct["execution"],
        }
    return results


def validate_negative_fixtures() -> list[dict[str, str]]:
    specification = load_json(FIXTURE_ROOT / "FAIL-CLOSED-CASES.json")
    results: list[dict[str, str]] = []
    for case in specification["cases"]:
        base = load_json(FIXTURE_ROOT / case.get("baseFixture", specification["baseFixture"]))
        mutated = copy.deepcopy(base)
        set_pointer(mutated, case["pointer"], case["value"])
        with tempfile.TemporaryDirectory(prefix="play079-orchestrator-negative-") as temporary:
            sandbox = pathlib.Path(temporary)
            fixture_root = sandbox / "parallel-source"
            fixture_root.mkdir()
            fixture_path = fixture_root / "MUTATED.json"
            fixture_path.write_text(json.dumps(mutated), encoding="utf-8")
            original_fixture_root = orchestrator.FIXTURE_ROOT
            original_repository_root = orchestrator.REPOSITORY_ROOT
            original_design_validator = orchestrator.validate_parallel_design_binding
            try:
                orchestrator.FIXTURE_ROOT = fixture_root
                orchestrator.REPOSITORY_ROOT = sandbox
                orchestrator.validate_parallel_design_binding = lambda: {
                    "path": orchestrator.PARALLEL_DESIGN_PATH,
                    "commit": orchestrator.PARALLEL_DESIGN_COMMIT,
                    "sha256": orchestrator.PARALLEL_DESIGN_SHA256,
                }
                result = expect_code(
                    lambda: orchestrator.validate_dry_fixture(fixture_path),
                    case["expectedCode"],
                )
            finally:
                orchestrator.FIXTURE_ROOT = original_fixture_root
                orchestrator.REPOSITORY_ROOT = original_repository_root
                orchestrator.validate_parallel_design_binding = original_design_validator
        results.append({"id": case["id"], **result})
    return results


def validate_missing_authority_cli() -> dict[str, Any]:
    for command in ("preflight", "launch", "finalize"):
        code, payload, stderr = run_cli(command)
        if code != 2 or stderr:
            raise RuntimeError(f"{command}: code={code}, stderr={stderr!r}")
        if payload.get("code") != "missing_future_integration_authorities":
            raise RuntimeError(f"{command}: {payload}")
        if set(payload.get("detail", [])) != set(orchestrator.PRODUCTION_ARGUMENTS):
            raise RuntimeError(f"{command}: incomplete mandatory authority set: {payload}")
        assert_zero_activity(payload)
    return {
        "result": "PASS",
        "commands": ["preflight", "launch", "finalize"],
        "expectedCode": "missing_future_integration_authorities",
        "mandatoryArguments": list(orchestrator.PRODUCTION_ARGUMENTS),
    }


def validate_exactly_once_tracker() -> dict[str, Any]:
    tracker = orchestrator.InvocationTracker()
    for process_id in orchestrator.PROCESS_IDS:
        for state in ("SPAWNED", "STARTED", "SETTLED", "RECEIPT_WRITTEN"):
            tracker.transition(process_id, state)
    duplicate = expect_code(
        lambda: tracker.transition("A", "SPAWNED"),
        "exactly_once_transition_rejected",
    )
    if tracker.spawn_counts != {"A": 1, "B": 1, "C": 1}:
        raise RuntimeError(f"spawn counts: {tracker.spawn_counts}")
    return {
        "result": "PASS",
        "finalStates": tracker.states,
        "spawnCounts": tracker.spawn_counts,
        "duplicate": duplicate,
    }


def validate_safe_write_order() -> dict[str, Any]:
    payload = b'{"fixtureOnly":true}\n'
    with tempfile.TemporaryDirectory(prefix="play079-orchestrator-safety-") as temporary:
        root = pathlib.Path(temporary)
        relative = "evidence/execution/process-a/INVOCATION-RECEIPT.json"
        policy = output_safety.OutputPolicy(root, {"receipt": frozenset({relative})})
        path = root / relative
        policy.write_bytes_exclusive(path, payload, "receipt")
        if path.read_bytes() != payload:
            raise RuntimeError("positive exclusive write mismatch")
        try:
            policy.write_bytes_exclusive(path, b"overwrite\n", "receipt")
        except output_safety.OutputSafetyRejected as error:
            if error.code != "output_already_exists":
                raise RuntimeError(f"unexpected overwrite code: {error.code}") from error
        else:
            raise RuntimeError("exclusive writer overwrote a receipt")

        redirect_root = root / "redirect-case"
        redirect_root.mkdir()
        redirect_relative = "evidence/execution/process-b/INVOCATION-RECEIPT.json"
        redirect_policy = output_safety.OutputPolicy(
            redirect_root,
            {"receipt": frozenset({redirect_relative})},
        )
        redirect_target = redirect_root / redirect_relative
        redirect_target.parent.mkdir(parents=True)
        redirected = redirect_root / "redirected"
        redirected.mkdir()

        def redirect_after_check() -> None:
            redirect_target.parent.rmdir()
            redirect_target.parent.symlink_to(redirected, target_is_directory=True)

        try:
            redirect_policy.write_bytes_exclusive(
                redirect_target,
                payload,
                "receipt",
                pre_write_hook=redirect_after_check,
            )
        except output_safety.OutputSafetyRejected as error:
            if error.code != "output_symlink_component":
                raise RuntimeError(f"unexpected redirect code: {error.code}") from error
        else:
            raise RuntimeError("redirected receipt write was accepted")
        if any(redirected.iterdir()):
            raise RuntimeError("redirect target received bytes")
    return {
        "result": "PASS",
        "noOverwrite": True,
        "preWriteRedirectRejected": True,
        "noFollow": True,
    }


def git_command(root: pathlib.Path, *arguments: str) -> str:
    completed = subprocess.run(
        ["git", *arguments],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode:
        raise RuntimeError(
            f"git {' '.join(arguments)} failed: {completed.stderr.strip()}"
        )
    return completed.stdout.strip()


def validate_authority_trust_boundary() -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="play079-authority-trust-") as temporary:
        root = pathlib.Path(temporary)
        git_command(root, "init", "-q")
        git_command(root, "config", "user.name", "PLAY-079 Fixture")
        git_command(root, "config", "user.email", "play079@example.invalid")
        base_path = root / "BASE.txt"
        base_path.write_text("base\n", encoding="utf-8")
        git_command(root, "add", "BASE.txt")
        git_command(root, "commit", "-q", "-m", "fixture base")
        base_commit = git_command(root, "rev-parse", "HEAD")

        integration = root / "docs/production/evidence/INTEGRATION"
        integration.mkdir(parents=True)
        regular_relative = "docs/production/evidence/INTEGRATION/AUTHORITY.json"
        regular_bytes = b'{"authority":"fixture"}\n'
        regular_path = root / regular_relative
        regular_path.write_bytes(regular_bytes)
        symlink_relative = "docs/production/evidence/INTEGRATION/SYMLINK.json"
        symlink_path = root / symlink_relative
        symlink_path.symlink_to("AUTHORITY.json")
        tree_path = integration / "TREE"
        tree_path.mkdir()
        (tree_path / "child.json").write_text("{}\n", encoding="utf-8")
        outside_relative = "docs/production/evidence/PLAY-079/FOREIGN.json"
        outside_path = root / outside_relative
        outside_path.parent.mkdir(parents=True)
        outside_bytes = b'{"authority":"wrong-root"}\n'
        outside_path.write_bytes(outside_bytes)
        git_command(root, "add", "docs")
        git_command(root, "commit", "-q", "-m", "fixture authorities")
        authority_commit = git_command(root, "rev-parse", "HEAD")

        regular_sha = hashlib.sha256(regular_bytes).hexdigest()
        outside_sha = hashlib.sha256(outside_bytes).hexdigest()
        symlink_blob_sha = hashlib.sha256(b"AUTHORITY.json").hexdigest()
        original_root = orchestrator.REPOSITORY_ROOT
        orchestrator.REPOSITORY_ROOT = root
        try:
            positive = orchestrator.validate_committed_artifact(
                regular_relative,
                authority_commit,
                regular_sha,
                "fixtureAuthority",
                allowed_prefixes=(orchestrator.INTEGRATION_PREFIX,),
                content_commit=authority_commit,
            )
            cases = [
                {
                    "id": "absolute-in-repository-path",
                    **expect_code(
                        lambda: orchestrator.validate_committed_artifact(
                            str(regular_path),
                            authority_commit,
                            regular_sha,
                            "fixtureAuthority",
                            allowed_prefixes=(orchestrator.INTEGRATION_PREFIX,),
                            content_commit=authority_commit,
                        ),
                        "authority_path_not_repo_relative",
                    ),
                },
                {
                    "id": "wrong-governed-root",
                    **expect_code(
                        lambda: orchestrator.validate_committed_artifact(
                            outside_relative,
                            authority_commit,
                            outside_sha,
                            "fixtureAuthority",
                            allowed_prefixes=(orchestrator.INTEGRATION_PREFIX,),
                            content_commit=authority_commit,
                        ),
                        "authority_path_outside_governed_root",
                    ),
                },
                {
                    "id": "local-symlink-authority",
                    **expect_code(
                        lambda: orchestrator.validate_committed_artifact(
                            symlink_relative,
                            authority_commit,
                            regular_sha,
                            "fixtureAuthority",
                            allowed_prefixes=(orchestrator.INTEGRATION_PREFIX,),
                            content_commit=authority_commit,
                        ),
                        "symlink_component",
                    ),
                },
                {
                    "id": "git-tree-not-blob",
                    **expect_code(
                        lambda: orchestrator.git_blob_identity(
                            authority_commit,
                            "docs/production/evidence/INTEGRATION/TREE",
                            "0" * 64,
                            "fixtureAuthority",
                        ),
                        "authority_not_regular_git_blob",
                    ),
                },
                {
                    "id": "nonexistent-authority-commit",
                    **expect_code(
                        lambda: orchestrator.git_blob_identity(
                            "f" * 40,
                            regular_relative,
                            regular_sha,
                            "fixtureAuthority",
                        ),
                        "authority_not_regular_git_blob",
                    ),
                },
                {
                    "id": "malformed-authority-commit",
                    **expect_code(
                        lambda: orchestrator.validate_committed_artifact(
                            regular_relative,
                            None,
                            regular_sha,
                            "fixtureAuthority",
                            allowed_prefixes=(orchestrator.INTEGRATION_PREFIX,),
                            content_commit=authority_commit,
                        ),
                        "invalid_authority_identity",
                    ),
                },
                {
                    "id": "sha256-mismatch",
                    **expect_code(
                        lambda: orchestrator.validate_committed_artifact(
                            regular_relative,
                            authority_commit,
                            "0" * 64,
                            "fixtureAuthority",
                            allowed_prefixes=(orchestrator.INTEGRATION_PREFIX,),
                            content_commit=authority_commit,
                        ),
                        "authority_sha256_mismatch",
                    ),
                },
                {
                    "id": "non-ancestral-authority",
                    **expect_code(
                        lambda: orchestrator.validate_committed_artifact(
                            regular_relative,
                            authority_commit,
                            regular_sha,
                            "fixtureAuthority",
                            allowed_prefixes=(orchestrator.INTEGRATION_PREFIX,),
                            content_commit=base_commit,
                        ),
                        "authority_commit_not_in_content_ancestry",
                    ),
                },
            ]

            symlink_path.unlink()
            symlink_path.write_bytes(b"AUTHORITY.json")
            cases.append(
                {
                    "id": "git-symlink-mode",
                    **expect_code(
                        lambda: orchestrator.validate_committed_artifact(
                            symlink_relative,
                            authority_commit,
                            symlink_blob_sha,
                            "fixtureAuthority",
                            allowed_prefixes=(orchestrator.INTEGRATION_PREFIX,),
                            content_commit=authority_commit,
                        ),
                        "authority_not_regular_git_blob",
                    ),
                }
            )

            changed_bytes = b'{"authority":"working-tree-only"}\n'
            regular_path.write_bytes(changed_bytes)
            cases.append(
                {
                    "id": "commit-content-mismatch",
                    **expect_code(
                        lambda: orchestrator.validate_committed_artifact(
                            regular_relative,
                            authority_commit,
                            hashlib.sha256(changed_bytes).hexdigest(),
                            "fixtureAuthority",
                            allowed_prefixes=(orchestrator.INTEGRATION_PREFIX,),
                            content_commit=authority_commit,
                        ),
                        "authority_commit_bytes_mismatch",
                    ),
                }
            )
            cases.append(
                {
                    "id": "nonexistent-shape-only-authority",
                    **expect_code(
                        lambda: orchestrator.validate_committed_artifact(
                            "docs/production/evidence/INTEGRATION/MISSING.json",
                            authority_commit,
                            "0" * 64,
                            "fixtureAuthority",
                            allowed_prefixes=(orchestrator.INTEGRATION_PREFIX,),
                            content_commit=authority_commit,
                        ),
                        "missing_future_authority",
                    ),
                }
            )
            partial = argparse.Namespace(
                sequential_exception=regular_relative,
                sequential_exception_commit=None,
                sequential_exception_sha256=None,
            )
            cases.append(
                {
                    "id": "caller-shape-only-sequential-exception",
                    **expect_code(
                        lambda: orchestrator.validate_optional_authority_presence(
                            partial
                        ),
                        "incomplete_sequential_exception_authority",
                    ),
                }
            )
        finally:
            orchestrator.REPOSITORY_ROOT = original_root
    return {
        "result": "PASS",
        "positiveExactGitBlob": {
            "path": positive["path"],
            "sha256": positive["sha256"],
            "commitContentAndAncestry": "PASS",
        },
        "negativeCases": cases,
        "negativeCount": len(cases),
        "productionSubprocessInvocations": 0,
        "dccInvocations": 0,
        "pixelFiles": 0,
    }


def pixel_inventory() -> list[str]:
    return sorted(
        str(path.relative_to(REPOSITORY_ROOT))
        for root in (SOURCE_ROOT, REPOSITORY_ROOT / output_safety.EVIDENCE_PREFIX)
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in orchestrator.PIXEL_EXTENSIONS
    )


def main() -> int:
    pixels_before = pixel_inventory()
    result = {
        "schema": "citysim.play-079.parallel-source-orchestrator-validation.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "result": "PASS",
        "positiveFixtures": validate_positive_fixtures(),
        "negativeFixtures": validate_negative_fixtures(),
        "missingProductionAuthorities": validate_missing_authority_cli(),
        "exactlyOnce": validate_exactly_once_tracker(),
        "safeWriteOrder": validate_safe_write_order(),
        "authorityTrust": validate_authority_trust_boundary(),
        "implementationSha256": hashlib.sha256(SCRIPT_PATH.read_bytes()).hexdigest(),
        "invocations": {
            "productionSubprocessInvocations": 0,
            "dccInvocations": 0,
            "blenderProcessInvocations": 0,
            "renderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
        },
        "pixelFiles": {
            "before": pixels_before,
            "after": pixel_inventory(),
            "created": 0,
        },
        "repositoryWrites": 0,
        "sourceReady": False,
        "productionSelected": False,
    }
    if result["pixelFiles"]["after"] != pixels_before:
        raise RuntimeError(f"pixel inventory changed: {result['pixelFiles']}")
    sys.stdout.buffer.write(orchestrator.canonical_bytes(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
