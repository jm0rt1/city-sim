#!/usr/bin/env python3
"""No-DCC tests for the PLAY-080 South schedule-consumer adapter."""

from __future__ import annotations

import ast
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

import consume_schedule_v01 as adapter
import jsonschema


class ScheduleConsumerAdapterV01Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract_path = adapter.REPOSITORY_ROOT / adapter.CONTRACT_PATH
        cls.contract = adapter.load_json_bytes(
            cls.contract_path.read_bytes(), adapter.CONTRACT_PATH
        )

    def candidate_contract(self) -> dict:
        return copy.deepcopy(self.contract)

    def test_current_environment_is_exactly_blocked_and_zero_child(self) -> None:
        environment = adapter.validate_environment(self.contract)
        self.assertEqual(adapter.BRANCH, environment["branch"])
        self.assertEqual(adapter.CURRENT_INPUTS, self.contract["currentInputs"])
        self.assertEqual(adapter.ACTIVITY, self.contract["activity"])
        self.assertEqual(0, self.contract["activity"]["childStarts"])
        self.assertFalse(self.contract["gates"]["childStartAuthorized"])
        self.assertFalse(self.contract["gates"]["dccAuthorized"])
        self.assertFalse(self.contract["gates"]["pixelProductionAuthorized"])

    def test_synthetic_future_postlock_schedule_core_is_ready_but_starts_zero(self) -> None:
        schedule = adapter.synthetic_postlock_schedule()
        result = adapter.validate_schedule_core(
            schedule, self.contract, adapter.future_runner(schedule)
        )
        self.assertEqual(
            "VALIDATED_FOR_HIGH_LEVEL_ORCHESTRATOR", result["result"]
        )
        self.assertEqual(["A", "B", "C"], [grant["process"] for grant in result["grants"]])
        self.assertEqual(0, result["childrenStarted"])
        self.assertFalse(result["directLowLevelInvocationAllowed"])

    def test_all_adversaries_fail_closed_with_zero_children(self) -> None:
        results = adapter.run_adversaries(self.contract)
        self.assertEqual(21, len(results))
        self.assertTrue(
            all(case["result"] == "PASS_ZERO_CHILD_FAIL_CLOSED" for case in results)
        )

    def test_real_cli_consumes_schema_and_semantic_passing_postlock_fixture_zero_child(
        self,
    ) -> None:
        schema = json.loads(
            (
                adapter.REPOSITORY_ROOT
                / adapter.AUTHORITIES["scheduleSchema"]["path"]
            ).read_text()
        )
        schedule = json.loads(
            (
                adapter.REPOSITORY_ROOT / adapter.POSTLOCK_FIXTURE_SCHEDULE_PATH
            ).read_text()
        )
        jsonschema.Draft202012Validator(
            schema,
            format_checker=jsonschema.FormatChecker(),
        ).validate(schedule)
        command = [
            sys.executable,
            str(adapter.REPOSITORY_ROOT / adapter.ADAPTER_PATH),
            "--consume",
            "--schedule",
            adapter.POSTLOCK_FIXTURE_SCHEDULE_PATH,
            "--nonproduction-postlock-fixture",
        ]
        result = subprocess.run(
            command,
            cwd=adapter.REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(
            "VALIDATED_FOR_HIGH_LEVEL_ORCHESTRATOR", payload["result"]
        )
        self.assertTrue(payload["nonproductionFixture"])
        self.assertEqual(
            "appearance_lock_bound", payload["runner"]["stage"]
        )
        self.assertEqual(
            "PASS",
            payload["schedule"]["sharedSemanticValidation"]["result"],
        )
        self.assertEqual(0, payload["childrenStarted"])
        self.assertEqual(0, payload["activity"]["childStarts"])
        self.assertEqual(0, payload["activity"]["dccProcessLaunches"])
        self.assertEqual(0, payload["activity"]["pixelFiles"])
        self.assertFalse(payload["directLowLevelInvocationAllowed"])
        self.assertFalse(payload["reportWritten"])

    def test_prelock_and_stale_runner_adversaries_fail_closed(self) -> None:
        schedule = adapter.synthetic_postlock_schedule()
        prelock_runner = adapter.load_json_bytes(
            adapter.capture_file(
                adapter.RUNNER_CONTRACT["path"], "RUNNER_CONTRACT_UNSAFE"
            ).raw,
            adapter.RUNNER_CONTRACT["path"],
        )
        with self.assertRaises(adapter.AdapterRejected) as prelock:
            adapter.validate_schedule_core(
                schedule, self.contract, prelock_runner
            )
        self.assertEqual("RUNNER_NOT_POSTLOCK_BOUND", prelock.exception.code)

        stale_runner = adapter.future_runner(schedule)
        stale_runner["acceptedPredesign"]["scene"]["sha256"] = "f" * 64
        with self.assertRaises(adapter.AdapterRejected) as stale:
            adapter.validate_schedule_core(
                schedule, self.contract, stale_runner
            )
        self.assertEqual(
            "STALE_RUNNER_IMMUTABLE_BINDING", stale.exception.code
        )

    def test_direct_low_level_and_wrong_child_limit_reject(self) -> None:
        schedule = adapter.synthetic_postlock_schedule()
        runner = adapter.future_runner(schedule)
        direct = copy.deepcopy(schedule)
        adapter.south_grant(direct)["processes"][0][
            "directLowLevelInvocationAllowed"
        ] = True
        with self.assertRaises(adapter.AdapterRejected) as raised:
            adapter.validate_schedule_core(direct, self.contract, runner)
        self.assertEqual(
            "DIRECT_LOW_LEVEL_INVOCATION_FORBIDDEN", raised.exception.code
        )
        wrong_limit = copy.deepcopy(schedule)
        adapter.south_grant(wrong_limit)["processes"][0][
            "maximumChildStarts"
        ] = 2
        with self.assertRaises(adapter.AdapterRejected) as raised:
            adapter.validate_schedule_core(wrong_limit, self.contract, runner)
        self.assertEqual("WRONG_CHILD_LIMIT", raised.exception.code)

    def test_adapter_source_has_no_dcc_child_start_primitive(self) -> None:
        source = (adapter.REPOSITORY_ROOT / adapter.ADAPTER_PATH).read_text()
        tree = ast.parse(source)
        imported_names = {
            alias.name
            for node in ast.walk(tree)
            if isinstance(node, (ast.Import, ast.ImportFrom))
            for alias in node.names
        }
        self.assertNotIn("bpy", imported_names)
        forbidden_calls = []
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            function = node.func
            if isinstance(function, ast.Attribute):
                owner = function.value.id if isinstance(function.value, ast.Name) else ""
                name = f"{owner}.{function.attr}"
            elif isinstance(function, ast.Name):
                name = function.id
            else:
                name = ""
            if name in {
                "subprocess.Popen",
                "subprocess.call",
                "subprocess.check_call",
                "os.execv",
                "os.execve",
                "os.execvp",
                "os.execvpe",
                "os.posix_spawn",
            }:
                forbidden_calls.append(name)
        self.assertEqual([], forbidden_calls)
        self.assertNotIn("--launch", source)
        self.assertNotIn("import bpy", source)
        self.assertNotIn("Blender.app", source)

    def test_duplicate_keys_and_nonfinite_json_reject(self) -> None:
        with self.assertRaises(adapter.AdapterRejected) as duplicate:
            adapter.load_json_bytes(b'{"a":1,"a":2}', "duplicate")
        self.assertEqual("DUPLICATE_JSON_KEY", duplicate.exception.code)
        with self.assertRaises(adapter.AdapterRejected) as nonfinite:
            adapter.load_json_bytes(b'{"value":NaN}', "nonfinite")
        self.assertEqual("NONFINITE_JSON_NUMBER", nonfinite.exception.code)

    def test_readiness_dry_run_repeats_without_writing(self) -> None:
        readiness = adapter.REPOSITORY_ROOT / adapter.READINESS_PATH
        before = readiness.read_bytes() if readiness.exists() else None
        command = [
            sys.executable,
            str(adapter.REPOSITORY_ROOT / adapter.ADAPTER_PATH),
            "--readiness-dry-run",
        ]
        first = subprocess.run(
            command,
            cwd=adapter.REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        second = subprocess.run(
            command,
            cwd=adapter.REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, first.returncode, first.stderr)
        self.assertEqual(first.stdout, second.stdout)
        payload = json.loads(first.stdout)
        self.assertEqual("PASS_ZERO_CHILD_READY", payload["result"])
        self.assertEqual(0, payload["childrenStarted"])
        self.assertEqual(0, payload["pixelFiles"])
        self.assertFalse(payload["reportWritten"])
        after = readiness.read_bytes() if readiness.exists() else None
        self.assertEqual(before, after)

    def test_consume_without_schedule_fails_before_child(self) -> None:
        command = [
            sys.executable,
            str(adapter.REPOSITORY_ROOT / adapter.ADAPTER_PATH),
            "--consume",
        ]
        result = subprocess.run(
            command,
            cwd=adapter.REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(2, result.returncode)
        payload = json.loads(result.stdout)
        self.assertEqual("MISSING_SCHEDULE", payload["code"])
        self.assertEqual(0, payload["childrenStarted"])
        self.assertEqual(0, payload["activity"]["dccProcessLaunches"])
        self.assertEqual(0, payload["activity"]["pixelFiles"])
        self.assertFalse(payload["reportWritten"])

    def test_alternate_contract_readiness_and_unsafe_schedule_reject(self) -> None:
        script = str(adapter.REPOSITORY_ROOT / adapter.ADAPTER_PATH)
        cases = (
            (
                ["--readiness-dry-run", "--contract", adapter.CONTRACT_PATH.replace("PLAY-080", "PLAY-079")],
                "CONTRACT_PATH_MISMATCH",
            ),
            (
                ["--readiness-dry-run", "--readiness", "../../Rendering/escape.json"],
                "READINESS_PATH_MISMATCH",
            ),
            (
                ["--consume", "--schedule", "../../Rendering/escape.json"],
                "UNSAFE_SCHEDULE_PATH",
            ),
            (
                ["--consume", "--schedule", f"{adapter.SOURCE_ROOT}runner-contract.json"],
                "SCHEDULE_PATH_NOT_INTEGRATION_OWNED",
            ),
            (
                [
                    "--consume",
                    "--schedule",
                    adapter.POSTLOCK_FIXTURE_SCHEDULE_PATH,
                ],
                "SCHEDULE_PATH_NOT_INTEGRATION_OWNED",
            ),
            (
                [
                    "--consume",
                    "--schedule",
                    f"{adapter.MODEL_ROOT}CONTRACT.json",
                    "--nonproduction-postlock-fixture",
                ],
                "FIXTURE_SCHEDULE_PATH_MISMATCH",
            ),
        )
        for arguments, expected in cases:
            with self.subTest(expected=expected):
                result = subprocess.run(
                    [sys.executable, script, *arguments],
                    cwd=adapter.REPOSITORY_ROOT,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(2, result.returncode)
                payload = json.loads(result.stdout)
                self.assertEqual(expected, payload["code"])
                self.assertEqual(0, payload["childrenStarted"])
                self.assertEqual(0, payload["activity"]["dccProcessLaunches"])

    def test_claim_revision_and_hash_are_independent_fail_closed_gates(self) -> None:
        schedule = adapter.synthetic_postlock_schedule()
        runner = adapter.future_runner(schedule)
        wrong_revision = self.candidate_contract()
        wrong_revision["target"]["claimRevision"] = 4
        with self.assertRaises(adapter.AdapterRejected) as raised:
            adapter.validate_schedule_core(schedule, wrong_revision, runner)
        self.assertEqual("WRONG_CLAIM_REVISION", raised.exception.code)
        wrong_hash = copy.deepcopy(schedule)
        adapter.south_grant(wrong_hash)["claimSha256"] = "a" * 64
        with self.assertRaises(adapter.AdapterRejected) as raised:
            adapter.validate_schedule_core(wrong_hash, self.contract, runner)
        self.assertEqual("WRONG_CLAIM_HASH", raised.exception.code)


if __name__ == "__main__":
    unittest.main()
