#!/usr/bin/env python3
"""Adversarial no-DCC tests for the PLAY-081 West schedule consumer."""

from __future__ import annotations

import ast
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import consume_west_parallel_schedule_v1 as consumer


class WestScheduleConsumerV1Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.root = Path(__file__).resolve().parents[7]
        cls.contract_path = cls.root / consumer.DEFAULT_CONTRACT
        cls.contract = consumer.decode_json(
            cls.contract_path.read_bytes(),
            consumer.DEFAULT_CONTRACT,
        )

    def future_contract(self) -> dict:
        value = copy.deepcopy(self.contract)
        value["releaseInputs"] = {
            "schedule": {
                "state": "bound_integration",
                "path": (
                    "docs/production/evidence/INTEGRATION/"
                    "INDUSTRIAL-L04-POSTLOCK-SCHEDULE.json"
                ),
                "commit": value["publishedBase"],
                "sha256": "1" * 64,
            },
            "appearanceLock": {
                "state": "bound_integration",
                "path": (
                    "docs/production/evidence/INTEGRATION/"
                    "INDUSTRIAL-L04-NORTH-APPEARANCE-LOCK.json"
                ),
                "sha256": "2" * 64,
            },
            "sourceProductionProfile": {
                "state": "bound_integration",
                "path": (
                    "docs/production/evidence/INTEGRATION/"
                    "INDUSTRIAL-L04-SOURCE-PRODUCTION-PROFILE.json"
                ),
                "sha256": "3" * 64,
            },
            "processGrants": {
                process: {
                    "state": "granted",
                    "grantId": f"west-{process}-grant",
                }
                for process in consumer.PROCESS_IDS
            },
        }
        return value

    def future_schedule(self, contract: dict | None = None) -> dict:
        contract = contract or self.future_contract()
        queue = [
            "north:B",
            "east:A",
            "south:A",
            "west:A",
            "north:C",
            "east:B",
            "south:B",
            "west:B",
            "east:C",
            "south:C",
            "west:C",
        ]
        grants = []
        lanes = {
            "north": ("PLAY-027", "codex/citysim-world-art"),
            "east": ("PLAY-079", "codex/citysim-world-art-east"),
            "south": ("PLAY-080", "codex/citysim-world-art-south"),
            "west": ("PLAY-081", "codex/citysim-world-art-west"),
        }
        for direction, (claim, branch) in lanes.items():
            if direction == "west":
                claim_sha = contract["claim"]["sha256"]
                base = contract["publishedBase"]
                orchestrator = copy.deepcopy(contract["adapter"])
                roots = copy.deepcopy(contract["exclusiveRoots"])
            else:
                claim_sha = direction[0] * 64
                base = contract["publishedBase"]
                orchestrator = {
                    "path": f"Native/test/{direction}/orchestrator.py",
                    "sha256": direction[0] * 64,
                }
                roots = [
                    f"Native/test/{direction}",
                    f"docs/test/{direction}",
                ]
            processes = []
            for index, process in enumerate(consumer.PROCESS_IDS):
                processes.append(
                    {
                        "grantId": (
                            f"west-{process}-grant"
                            if direction == "west"
                            else f"{direction}-{process}-grant"
                        ),
                        "process": process,
                        "state": "granted",
                        "slotId": f"dcc-{index}",
                        "maximumChildStarts": 1,
                        "orchestratorOnly": True,
                        "directLowLevelInvocationAllowed": False,
                    }
                )
            grants.append(
                {
                    "direction": direction,
                    "claim": claim,
                    "branch": branch,
                    "claimSha256": claim_sha,
                    "baseCommit": base,
                    "orchestrator": orchestrator,
                    "exclusiveRoots": roots,
                    "processes": processes,
                }
            )
        release = contract["releaseInputs"]
        return {
            "schema": 1,
            "batch": "industrial_l04_directional_family",
            "phase": "postlock_abc",
            "issuedAt": "2026-07-30T12:00:00Z",
            "integrationAuthorityCommit": contract["publishedBase"],
            "familyContract": copy.deepcopy(contract["familyContract"]),
            "appearanceLock": {
                "path": release["appearanceLock"]["path"],
                "sha256": release["appearanceLock"]["sha256"],
            },
            "sourceProductionProfile": {
                "path": release["sourceProductionProfile"]["path"],
                "sha256": release["sourceProductionProfile"]["sha256"],
            },
            "computeEnvelope": {
                "maximumSimultaneousDCCProcesses": 3,
                "slotIds": ["dcc-0", "dcc-1", "dcc-2"],
                "queueOrder": queue,
            },
            "directionGrants": grants,
        }

    @staticmethod
    def west(schedule: dict) -> dict:
        return next(
            grant
            for grant in schedule["directionGrants"]
            if grant["direction"] == "west"
        )

    def test_static_contract_and_zero_child_readiness(self) -> None:
        self.assertEqual(consumer.contract_errors(self.root, self.contract), [])
        result = consumer.describe(self.root, self.contract)
        self.assertTrue(result["adapterReady"])
        self.assertFalse(result["launchReady"])
        self.assertFalse(result["sourceReady"])
        self.assertEqual(
            result["activity"],
            consumer.ZERO_ACTIVITY,
        )
        self.assertEqual(
            set(result["blockers"]),
            {
                "release:schedule:not-published",
                "release:appearanceLock:not-published",
                "release:sourceProductionProfile:not-published",
                "release:west-A:not-granted",
                "release:west-B:not-granted",
                "release:west-C:not-granted",
            },
        )

    def test_describe_is_byte_identical(self) -> None:
        first = consumer.canonical_bytes(
            consumer.describe(self.root, self.contract)
        )
        second = consumer.canonical_bytes(
            consumer.describe(self.root, self.contract)
        )
        self.assertEqual(first, second)

    def test_missing_schedule_rejects_before_read_or_child(self) -> None:
        result = consumer.validate_published_schedule(
            self.root,
            self.contract,
            None,
            None,
        )
        self.assertEqual(result["result"], "BLOCKED")
        self.assertFalse(result["scheduleRead"])
        self.assertFalse(result["semanticValidatorInvoked"])
        self.assertFalse(result["orchestratorInvoked"])
        self.assertEqual(result["activity"], consumer.ZERO_ACTIVITY)

    def test_direction_local_future_shape_passes(self) -> None:
        contract = self.future_contract()
        schedule = self.future_schedule(contract)
        self.assertEqual(
            consumer.direction_schedule_errors(schedule, contract),
            [],
        )

    def test_schedule_adversaries_fail_closed(self) -> None:
        contract = self.future_contract()
        base = self.future_schedule(contract)

        def mutate_direction(schedule: dict) -> None:
            self.west(schedule)["direction"] = "east"

        cases = {
            "wrong-phase": (
                lambda value: value.update(phase="prelock_north_a"),
                "schedule:phase",
            ),
            "wrong-direction": (
                mutate_direction,
                "schedule:west-grant-count",
            ),
            "wrong-claim": (
                lambda value: self.west(value).update(claim="PLAY-080"),
                "schedule:west-claim",
            ),
            "wrong-claim-hash": (
                lambda value: self.west(value).update(claimSha256="f" * 64),
                "schedule:west-claimSha256",
            ),
            "stale-base": (
                lambda value: self.west(value).update(
                    baseCommit="401eb2ce19c5f5c932442ace72e66fbd734cfa35"
                ),
                "schedule:west-baseCommit",
            ),
            "old-integration-authority": (
                lambda value: value.update(
                    integrationAuthorityCommit=(
                        "401eb2ce19c5f5c932442ace72e66fbd734cfa35"
                    )
                ),
                "schedule:integration-authority",
            ),
            "wrong-slot": (
                lambda value: self.west(value)["processes"][0].update(
                    slotId="dcc-9"
                ),
                "schedule:west-A:slot",
            ),
            "missing-queue-token": (
                lambda value: value["computeEnvelope"]["queueOrder"].remove(
                    "west:C"
                ),
                "schedule:queue",
            ),
            "reordered-west-queue": (
                lambda value: value["computeEnvelope"].update(
                    queueOrder=[
                        token
                        for token in value["computeEnvelope"]["queueOrder"]
                        if token not in {"west:A", "west:B", "west:C"}
                    ]
                    + ["west:C", "west:B", "west:A"]
                ),
                "schedule:west-queue-order",
            ),
            "sibling-root": (
                lambda value: self.west(value).update(
                    exclusiveRoots=[
                        "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
                        "industrial-l04-south-source-v01",
                        "docs/production/evidence/PLAY-080/"
                        "industrial-l04-south-source-v01",
                    ]
                ),
                "schedule:west-exclusiveRoots",
            ),
            "low-level-orchestrator": (
                lambda value: self.west(value).update(
                    orchestrator={
                        "path": (
                            consumer.SOURCE_ROOT
                            + "/blender_render_west.py"
                        ),
                        "sha256": "a" * 64,
                    }
                ),
                "schedule:west-orchestrator",
            ),
            "missing-lock": (
                lambda value: value.update(appearanceLock=None),
                "schedule:appearance-lock:shape",
            ),
            "wrong-lock": (
                lambda value: value["appearanceLock"].update(
                    path="docs/production/evidence/INTEGRATION/WRONG-LOCK.json"
                ),
                "schedule:appearance-lock:binding",
            ),
            "missing-profile": (
                lambda value: value.update(sourceProductionProfile=None),
                "schedule:source-production-profile:shape",
            ),
            "wrong-profile": (
                lambda value: value["sourceProductionProfile"].update(
                    path="docs/production/evidence/INTEGRATION/WRONG-PROFILE.json"
                ),
                "schedule:source-production-profile:binding",
            ),
            "wrong-child-limit": (
                lambda value: self.west(value)["processes"][1].update(
                    maximumChildStarts=2
                ),
                "schedule:west-B:child-limit",
            ),
            "blocked-process": (
                lambda value: self.west(value)["processes"][2].update(
                    state="blocked"
                ),
                "schedule:west-C:state",
            ),
            "not-orchestrator-only": (
                lambda value: self.west(value)["processes"][0].update(
                    orchestratorOnly=False
                ),
                "schedule:west-A:orchestrator-only",
            ),
            "direct-low-level": (
                lambda value: self.west(value)["processes"][0].update(
                    directLowLevelInvocationAllowed=True
                ),
                "schedule:west-A:direct-low-level",
            ),
            "wrong-grant-id": (
                lambda value: self.west(value)["processes"][0].update(
                    grantId="foreign-grant"
                ),
                "schedule:west-A:grant-id",
            ),
        }
        for name, (mutation, expected) in cases.items():
            with self.subTest(name=name):
                schedule = copy.deepcopy(base)
                mutation(schedule)
                self.assertIn(
                    expected,
                    consumer.direction_schedule_errors(schedule, contract),
                )

    def test_contract_adversaries_fail_closed(self) -> None:
        cases = {
            "wrong-claim-revision": (
                lambda value: value["claim"].update(revision=5),
                "claim:revision",
            ),
            "wrong-claim-hash": (
                lambda value: value["claim"].update(sha256="f" * 64),
                "claim:sha256-contract",
            ),
            "stale-base": (
                lambda value: value.update(
                    publishedBase=(
                        "401eb2ce19c5f5c932442ace72e66fbd734cfa35"
                    )
                ),
                "contract:publishedBase",
            ),
            "wrong-orchestrator": (
                lambda value: value["orchestrator"].update(
                    path=consumer.SOURCE_ROOT + "/blender_render_west.py"
                ),
                "orchestrator:path",
            ),
            "unsafe-root": (
                lambda value: value.update(
                    exclusiveRoots=[
                        consumer.SOURCE_ROOT,
                        "docs/production/evidence/INTEGRATION",
                    ]
                ),
                "contract:exclusive-roots",
            ),
            "wrong-schema-hash": (
                lambda value: value["scheduleSchema"].update(
                    sha256="f" * 64
                ),
                "scheduleSchema:sha256-contract",
            ),
            "wrong-validator-hash": (
                lambda value: value["semanticValidator"].update(
                    sha256="f" * 64
                ),
                "semanticValidator:sha256-contract",
            ),
        }
        for name, (mutation, expected) in cases.items():
            with self.subTest(name=name):
                contract = copy.deepcopy(self.contract)
                mutation(contract)
                self.assertIn(
                    expected,
                    consumer.contract_errors(self.root, contract),
                )

    def test_adapter_exposes_no_direct_dcc_execution_surface(self) -> None:
        source = Path(consumer.__file__).read_text(encoding="utf-8")
        tree = ast.parse(source)
        imported = {
            alias.name
            for node in ast.walk(tree)
            if isinstance(node, (ast.Import, ast.ImportFrom))
            for alias in node.names
        }
        self.assertFalse(
            {"subprocess", "bpy"} & imported,
            imported,
        )
        forbidden_calls = {
            "system",
            "popen",
            "Popen",
            "run",
            "call",
            "check_call",
            "check_output",
            "exec",
            "eval",
        }
        calls = {
            node.func.attr
            for node in ast.walk(tree)
            if isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
        } | {
            node.func.id
            for node in ast.walk(tree)
            if isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
        }
        self.assertFalse(forbidden_calls & calls, calls)
        self.assertNotIn("blender_render_west.py", source)
        self.assertFalse(
            any(
                isinstance(node, ast.FunctionDef)
                and node.name.startswith(("launch", "render", "normalize"))
                for node in ast.walk(tree)
            )
        )

    def test_symlink_schedule_path_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target.json"
            target.write_text("{}\n", encoding="utf-8")
            link = root / "schedule.json"
            link.symlink_to(target)
            with self.assertRaisesRegex(
                consumer.ConsumerError,
                "SYMLINK_COMPONENT",
            ):
                consumer.safe_repository_file(
                    root,
                    "schedule.json",
                    expected="schedule.json",
                )


if __name__ == "__main__":
    unittest.main()
