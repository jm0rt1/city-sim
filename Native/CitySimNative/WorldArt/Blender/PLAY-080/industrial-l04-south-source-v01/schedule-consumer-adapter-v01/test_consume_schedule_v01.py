#!/usr/bin/env python3
"""No-DCC tests for the PLAY-080 South schedule-consumer adapter."""

from __future__ import annotations

import ast
import copy
import hashlib
import hmac
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import consume_schedule_v01 as adapter
import jsonschema


def closure_authority(
    secret: bytes = b"play-080-nonproduction-secret",
    *,
    root_suffix: str = "fresh-001",
) -> tuple[dict, dict]:
    authority = {
        "task": {
            "taskId": "PLAY-080",
            "direction": "south",
            "branch": adapter.BRANCH,
            "claimRevision": 6,
            "claimSha256": adapter.REVISION_6_CLAIM_SHA256,
            "publishedBaseCommit": adapter.REVISION_6_BASE,
        },
        "grant": {
            "grantId": "grant-south-A-rev6",
            "process": "A",
            "queueId": "south:A",
            "slotId": "dcc-1",
            "maximumChildStarts": 1,
            "exactlyOneInvocation": True,
            "orchestratorOnly": True,
            "directLowLevelInvocationAllowed": False,
        },
        "artifacts": {
            "highLevelOrchestrator": {
                "path": (
                    f"{adapter.SOURCE_ROOT}prepare_launch_binding.py"
                ),
                "sha256": "1" * 64,
            },
            "runnerEntrypoint": {
                "path": f"{adapter.SOURCE_ROOT}run_production.py",
                "sha256": "2" * 64,
            },
        },
        "exclusiveRoots": {
            "output": f"{adapter.SOURCE_ROOT}outputs/{root_suffix}",
            "evidence": f"{adapter.EVIDENCE_ROOT}evidence/{root_suffix}",
            "attempt": f"{adapter.EVIDENCE_ROOT}attempts/{root_suffix}",
            "terminal": f"{adapter.EVIDENCE_ROOT}terminals/{root_suffix}",
        },
        "authentication": {
            "secretTransport": "anonymous_pipe",
            "secretSha256": hashlib.sha256(secret).hexdigest(),
            "rawSecretPersisted": False,
            "childCapability": {
                "algorithm": "HMAC-SHA256",
                "capabilityId": "cap-south-A-rev6",
                "audience": "industrial-l04-direction-child",
                "boundGrantId": "grant-south-A-rev6",
                "payloadSha256": "",
                "macSha256": "",
                "oneTime": True,
                "replayAllowed": False,
            },
        },
        "disposition": {
            "validationOnly": True,
            "liveLeaseAuthorized": False,
            "childStartAuthorized": False,
            "dccExecutionAuthorized": False,
            "renderAuthorized": False,
            "pixelAuthorized": False,
            "sourceCandidateReady": False,
            "appearanceAccepted": False,
            "sourceProfileActivated": False,
            "integrationAdmitted": False,
            "rendererQuarantined": False,
            "productionSelected": False,
            "shippingAuthorized": False,
        },
        "_validated": {
            "authorityPublicationCommit": "3" * 40,
            "trustedHead": adapter.REVISION_6_BASE,
            "workerHead": "4" * 40,
        },
    }
    receipt = {
        "result": "PASS",
        "authorityPath": (
            "docs/production/evidence/INTEGRATION/"
            "PLAY-080-SOUTH-EXECUTION-AUTHORITY.json"
        ),
        "authorityPublicationCommit": "3" * 40,
        "trustedHead": adapter.REVISION_6_BASE,
        "workerHead": "4" * 40,
        "taskId": "PLAY-080",
        "direction": "south",
        "process": "A",
        "grantId": "grant-south-A-rev6",
        "queueId": "south:A",
        "slotId": "dcc-1",
    }
    payload = adapter.prepare_launch_binding.execution_capability_payload(authority)
    capability = authority["authentication"]["childCapability"]
    capability["payloadSha256"] = hashlib.sha256(payload).hexdigest()
    capability["macSha256"] = hmac.new(secret, payload, hashlib.sha256).hexdigest()
    return authority, receipt


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

    def test_revision_6_authenticated_boundary_is_deterministic_across_two_fresh_roots(
        self,
    ) -> None:
        secret = b"play-080-nonproduction-secret"
        first_authority, first_receipt = closure_authority(
            secret, root_suffix="fresh-validation-root"
        )
        second_authority, second_receipt = closure_authority(
            secret, root_suffix="fresh-validation-root"
        )
        with tempfile.TemporaryDirectory(
            prefix="play-080-closure-root-a-"
        ) as first_root, tempfile.TemporaryDirectory(
            prefix="play-080-closure-root-b-"
        ) as second_root:
            self.assertNotEqual(first_root, second_root)
            self.assertEqual([], list(Path(first_root).iterdir()))
            self.assertEqual([], list(Path(second_root).iterdir()))
            first = adapter.prepare_launch_binding.validate_execution_closure(
                first_authority, first_receipt, secret, set()
            )
            second = adapter.prepare_launch_binding.validate_execution_closure(
                second_authority, second_receipt, secret, set()
            )
        self.assertEqual(
            adapter.canonical_bytes(first), adapter.canonical_bytes(second)
        )
        self.assertEqual(0, first["activity"]["childrenStarted"])
        self.assertEqual(0, first["activity"]["dccStarts"])
        self.assertEqual(0, first["activity"]["renders"])
        self.assertEqual(0, first["activity"]["pixels"])
        self.assertFalse(first["runnerBoundary"]["liveLeaseAcquired"])

    def test_revision_6_replay_and_authentication_fail_closed(self) -> None:
        secret = b"play-080-nonproduction-secret"
        authority, receipt = closure_authority(secret)
        seen: set[str] = set()
        adapter.prepare_launch_binding.validate_execution_closure(
            authority, receipt, secret, seen
        )
        with self.assertRaises(
            adapter.prepare_launch_binding.LaunchBindingRejected
        ) as replay:
            adapter.prepare_launch_binding.validate_execution_closure(
                authority, receipt, secret, seen
            )
        self.assertEqual("REPLAYED_EXECUTION_CAPABILITY", replay.exception.code)
        with self.assertRaises(
            adapter.prepare_launch_binding.LaunchBindingRejected
        ) as missing:
            adapter.prepare_launch_binding.validate_execution_closure(
                authority, receipt, None, set()
            )
        self.assertEqual("MISSING_ANONYMOUS_PIPE_SECRET", missing.exception.code)
        with self.assertRaises(
            adapter.prepare_launch_binding.LaunchBindingRejected
        ) as forged:
            adapter.prepare_launch_binding.validate_execution_closure(
                authority, receipt, b"forged", set()
            )
        self.assertEqual("FORGED_ANONYMOUS_PIPE_SECRET", forged.exception.code)

    def test_revision_6_identity_root_slot_and_orchestrator_adversaries(self) -> None:
        secret = b"play-080-nonproduction-secret"
        cases = (
            ("wrong-direction", lambda a, r: a["task"].update(direction="east")),
            ("wrong-process", lambda a, r: r.update(process="B")),
            ("wrong-root", lambda a, r: a["exclusiveRoots"].update(
                output="Native/CitySimNative/Rendering/escape"
            )),
            ("wrong-slot", lambda a, r: r.update(slotId="dcc-2")),
            ("wrong-claim", lambda a, r: a["task"].update(taskId="PLAY-079")),
            ("wrong-base", lambda a, r: a["task"].update(
                publishedBaseCommit="5" * 40
            )),
            ("wrong-orchestrator", lambda a, r: a["artifacts"][
                "highLevelOrchestrator"
            ].update(path=f"{adapter.SOURCE_ROOT}run_production.py")),
            ("stale-receipt", lambda a, r: r.update(result="STALE")),
            ("non-ancestral-worker", lambda a, r: r.update(workerHead="6" * 40)),
        )
        for case_id, mutate in cases:
            with self.subTest(case=case_id):
                authority, receipt = closure_authority(secret)
                mutate(authority, receipt)
                if case_id in {
                    "wrong-direction",
                    "wrong-root",
                    "wrong-claim",
                    "wrong-base",
                    "wrong-orchestrator",
                }:
                    payload = adapter.prepare_launch_binding.execution_capability_payload(
                        authority
                    )
                    authority["authentication"]["childCapability"][
                        "payloadSha256"
                    ] = hashlib.sha256(payload).hexdigest()
                    authority["authentication"]["childCapability"][
                        "macSha256"
                    ] = hmac.new(secret, payload, hashlib.sha256).hexdigest()
                with self.assertRaises(Exception):
                    adapter.prepare_launch_binding.validate_execution_closure(
                        authority, receipt, secret, set()
                    )

    def test_direct_runner_boundary_is_unauthenticated_and_zero_child(self) -> None:
        authority, receipt = closure_authority()
        with self.assertRaises(
            adapter.prepare_launch_binding.run_production.GuardRejected
        ) as direct:
            adapter.prepare_launch_binding.run_production.validate_authenticated_execution_boundary(
                authority,
                receipt,
                authenticated_by_orchestrator=False,
            )
        self.assertEqual(
            "UNAUTHENTICATED_EXECUTION_CLOSURE", direct.exception.code
        )

    def test_revision_6_shared_bindings_and_missing_instance_fail_closed(self) -> None:
        module = adapter.load_execution_validator()
        self.assertEqual(
            "citysim://integration/industrial-l04-direction-execution-authority-v1",
            module.SCHEMA_ID,
        )
        command = [
            sys.executable,
            str(adapter.REPOSITORY_ROOT / adapter.ADAPTER_PATH),
            "--consume-execution-authority",
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
        self.assertEqual("MISSING_EXECUTION_CLOSURE_INPUT", payload["code"])
        self.assertEqual(0, payload["childrenStarted"])
        self.assertEqual(0, payload["activity"]["dccProcessLaunches"])
        self.assertEqual(0, payload["activity"]["pixelFiles"])
        self.assertFalse(payload["reportWritten"])


if __name__ == "__main__":
    unittest.main()
