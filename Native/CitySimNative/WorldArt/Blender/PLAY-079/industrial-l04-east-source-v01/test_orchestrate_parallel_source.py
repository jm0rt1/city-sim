#!/usr/bin/env python3
"""Zero-DCC tests for the PLAY-079 parallel-source orchestrator boundary."""

from __future__ import annotations

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
        assert_zero_activity(payload)
    return {
        "result": "PASS",
        "commands": ["preflight", "launch", "finalize"],
        "expectedCode": "missing_future_integration_authorities",
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
