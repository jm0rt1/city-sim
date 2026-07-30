#!/usr/bin/env python3
"""Revision-7 West validation-only execution-closure tests."""

from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from typing import Any, Callable


HERE = Path(__file__).resolve().parent
SOURCE_ROOT = HERE.parent
REPOSITORY_ROOT = HERE.parents[6]
CONSUMER_ROOT = SOURCE_ROOT / "schedule-consumer-v01"
sys.path.insert(0, str(CONSUMER_ROOT))
sys.path.insert(0, str(SOURCE_ROOT))

import consume_west_parallel_schedule_v1 as consumer  # noqa: E402
import run_west_source as low_level_runner  # noqa: E402


PUBLISHED_BASE = "aaee294718a8176b70a4688b738b517f216dd3a7"
AUTHORITY_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-WEST-EXECUTION-CLOSURE-TEST-V1.json"
)
SCHEDULE_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-EXECUTION-CLOSURE-TEST-SCHEDULE-V1.json"
)
APPEARANCE_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-EXECUTION-CLOSURE-TEST-APPEARANCE.json"
)
PROFILE_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-EXECUTION-CLOSURE-TEST-PROFILE.json"
)
CLAIMS = {
    "north": (
        "PLAY-027",
        "codex/citysim-world-art",
        "docs/production/claims/PLAY-027.world-art.md",
    ),
    "east": (
        "PLAY-079",
        "codex/citysim-world-art-east",
        "docs/production/claims/PLAY-079.world-art-east.md",
    ),
    "south": (
        "PLAY-080",
        "codex/citysim-world-art-south",
        "docs/production/claims/PLAY-080.world-art-south.md",
    ),
    "west": (
        "PLAY-081",
        "codex/citysim-world-art-west",
        "docs/production/claims/PLAY-081.world-art-west.md",
    ),
}
NATIVE_ROOTS = {
    "north": (
        "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
        "industrial-l04-north-art-v12/process-a-execution-v01"
    ),
    "east": (
        "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
        "industrial-l04-east-source-v01"
    ),
    "south": (
        "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
        "industrial-l04-south-source-v01"
    ),
    "west": consumer.SOURCE_ROOT,
}
EVIDENCE_ROOTS = {
    "north": (
        "docs/production/evidence/PLAY-027/industrial-l04/l04/"
        "blender-north-art-v12/process-a-execution-v01"
    ),
    "east": (
        "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01"
    ),
    "south": (
        "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01"
    ),
    "west": (
        "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01"
    ),
}
ARTIFACT_PATHS = {
    "executionContract": (
        f"{consumer.SOURCE_ROOT}/WEST-EXECUTION-ORCHESTRATION-V2.json"
    ),
    "directionScheduleAdapter": (
        f"{consumer.SOURCE_ROOT}/schedule-consumer-v01/"
        "consume_west_parallel_schedule_v1.py"
    ),
    "highLevelOrchestrator": (
        f"{consumer.SOURCE_ROOT}/west_execution_orchestration_v2.py"
    ),
    "runnerContract": f"{consumer.SOURCE_ROOT}/RUNNER-CONTRACT.json",
    "runnerEntrypoint": f"{consumer.SOURCE_ROOT}/run_west_source.py",
    "scene": (
        f"{consumer.SOURCE_ROOT}/execution-closure-v01/SCENE-BINDING.json"
    ),
    "materials": (
        f"{consumer.SOURCE_ROOT}/execution-closure-v01/"
        "MATERIALS-BINDING.json"
    ),
    "toolchain": (
        f"{consumer.SOURCE_ROOT}/execution-closure-v01/"
        "TOOLCHAIN-BINDING.json"
    ),
}
WORKER_FILES = set(ARTIFACT_PATHS.values()) | {
    f"{consumer.SOURCE_ROOT}/schedule-consumer-v01/"
    "WEST-SCHEDULE-CONSUMER-CONTRACT-V1.json",
    f"{consumer.SOURCE_ROOT}/validate_locator_authority.py",
    f"{consumer.SOURCE_ROOT}/west_launch_authority.py",
    f"{consumer.SOURCE_ROOT}/west_path_safety.py",
}
FIXED_GIT_ENV = {
    "GIT_AUTHOR_NAME": "PLAY-081 Validation",
    "GIT_AUTHOR_EMAIL": "play-081@example.invalid",
    "GIT_COMMITTER_NAME": "PLAY-081 Validation",
    "GIT_COMMITTER_EMAIL": "play-081@example.invalid",
    "GIT_AUTHOR_DATE": "2026-07-30T12:00:00+00:00",
    "GIT_COMMITTER_DATE": "2026-07-30T12:00:00+00:00",
}


def digest(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def canonical(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


class ClosureFixture:
    """One disposable Git-published West execution authority."""

    def __init__(
        self,
        *,
        authority_mutator: Callable[[dict[str, Any]], None] | None = None,
        schedule_mutator: Callable[[dict[str, Any]], None] | None = None,
        authority_path: str = AUTHORITY_PATH,
    ) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "repository"
        self.authority_path = authority_path
        self.lease_path = (
            "/private/tmp/"
            "citysim-industrial-l04-west-play081-rev6-validation.lock"
        )
        Path(self.lease_path).unlink(missing_ok=True)
        subprocess.run(
            [
                "git",
                "clone",
                "--shared",
                "--quiet",
                str(REPOSITORY_ROOT),
                str(self.root),
            ],
            check=True,
            capture_output=True,
        )
        self._git("checkout", "--detach", "--quiet", PUBLISHED_BASE)
        self._git("config", "user.name", "PLAY-081 Validation")
        self._git("config", "user.email", "play-081@example.invalid")

        self.appearance_payload = b'{"appearance":"validation-only"}\n'
        self.profile_payload = b'{"profile":"validation-only"}\n'
        self._write(APPEARANCE_PATH, self.appearance_payload)
        self._write(PROFILE_PATH, self.profile_payload)
        self._commit("fixture integration inputs")
        self.integration_inputs_commit = self._rev("HEAD")

        self.artifact_payloads = {
            name: (REPOSITORY_ROOT / path).read_bytes()
            for name, path in ARTIFACT_PATHS.items()
        }
        schedule = self._schedule()
        if schedule_mutator is not None:
            schedule_mutator(schedule)
        self.schedule_payload = canonical(schedule)
        self._write(SCHEDULE_PATH, self.schedule_payload)
        self._commit("fixture schedule")
        self.schedule_publication = self._rev("HEAD")

        authority = self._authority()
        if authority_mutator is not None:
            authority_mutator(authority)
        self.authority = authority
        self.authority_payload = canonical(authority)
        self._write(authority_path, self.authority_payload)
        self._commit("fixture authority")
        self.authority_publication = self._rev("HEAD")
        self._git(
            "update-ref",
            "refs/remotes/origin/master",
            self.authority_publication,
        )
        self.trusted_head = self.authority_publication

        for path in sorted(WORKER_FILES):
            source = REPOSITORY_ROOT / path
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        self._commit("fixture worker")
        self.worker_head = self._rev("HEAD")
        self.contract = consumer.decode_json(
            (
                self.root
                / consumer.DEFAULT_CONTRACT
            ).read_bytes(),
            consumer.DEFAULT_CONTRACT,
        )

    def close(self) -> None:
        Path(self.lease_path).unlink(missing_ok=True)
        self.temporary.cleanup()

    def _git(self, *arguments: str) -> subprocess.CompletedProcess[bytes]:
        environment = os.environ.copy()
        environment.update(FIXED_GIT_ENV)
        return subprocess.run(
            ["git", *arguments],
            cwd=self.root,
            check=True,
            capture_output=True,
            env=environment,
        )

    def _rev(self, revision: str) -> str:
        return self._git("rev-parse", revision).stdout.decode().strip()

    def _write(self, relative: str, payload: bytes) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)

    def _commit(self, message: str) -> None:
        self._git("add", "--all")
        self._git(
            "-c",
            "commit.gpgsign=false",
            "commit",
            "--quiet",
            "-m",
            message,
        )

    def _git_bytes(self, commit: str, path: str) -> bytes:
        return self._git("show", f"{commit}:{path}").stdout

    def _schedule(self) -> dict[str, Any]:
        slots = ["dcc-1", "dcc-2", "dcc-3"]
        granted = {
            "north:B",
            "north:C",
            *{
                f"{direction}:{process}"
                for direction in ("east", "south", "west")
                for process in ("A", "B", "C")
            },
        }
        queue = sorted(granted)
        grants: list[dict[str, Any]] = []
        for direction, (task, branch, claim_path) in CLAIMS.items():
            claim_payload = self._git_bytes(PUBLISHED_BASE, claim_path)
            processes = []
            for process in ("A", "B", "C"):
                token = f"{direction}:{process}"
                is_granted = token in granted
                processes.append(
                    {
                        "grantId": f"grant-{direction}-{process}",
                        "process": process,
                        "state": "granted" if is_granted else "blocked",
                        "slotId": (
                            slots[queue.index(token) % len(slots)]
                            if is_granted
                            else None
                        ),
                        "maximumChildStarts": 1 if is_granted else 0,
                        "orchestratorOnly": True,
                        "directLowLevelInvocationAllowed": False,
                    }
                )
            if direction == "west":
                adapter = {
                    "path": ARTIFACT_PATHS["directionScheduleAdapter"],
                    "sha256": digest(
                        self.artifact_payloads["directionScheduleAdapter"]
                    ),
                }
            else:
                adapter = {
                    "path": f"{NATIVE_ROOTS[direction]}/test-adapter.py",
                    "sha256": digest(f"{direction}:adapter\n".encode()),
                }
            grants.append(
                {
                    "direction": direction,
                    "claim": task,
                    "branch": branch,
                    "claimSha256": digest(claim_payload),
                    "baseCommit": PUBLISHED_BASE,
                    "orchestrator": adapter,
                    "exclusiveRoots": [
                        f"{NATIVE_ROOTS[direction]}/schedule-exclusive",
                        f"{EVIDENCE_ROOTS[direction]}/schedule-exclusive",
                    ],
                    "processes": processes,
                }
            )
        family_path = (
            "docs/production/decisions/"
            "CONTRACT-010-directional-building-art.md"
        )
        family_payload = self._git_bytes(PUBLISHED_BASE, family_path)
        return {
            "schema": 1,
            "batch": "industrial_l04_directional_family",
            "phase": "postlock_abc",
            "issuedAt": "2026-07-30T12:01:00Z",
            "integrationAuthorityCommit": PUBLISHED_BASE,
            "familyContract": {
                "path": family_path,
                "sha256": digest(family_payload),
            },
            "appearanceLock": {
                "path": APPEARANCE_PATH,
                "sha256": digest(self.appearance_payload),
            },
            "sourceProductionProfile": {
                "path": PROFILE_PATH,
                "sha256": digest(self.profile_payload),
            },
            "computeEnvelope": {
                "maximumSimultaneousDCCProcesses": 3,
                "slotIds": slots,
                "queueOrder": queue,
            },
            "directionGrants": grants,
        }

    def _authority(self) -> dict[str, Any]:
        schedule = json.loads(self.schedule_payload)
        west = next(
            value
            for value in schedule["directionGrants"]
            if value["direction"] == "west"
        )
        process = next(
            value for value in west["processes"] if value["process"] == "A"
        )
        claim_payload = self._git_bytes(
            PUBLISHED_BASE,
            CLAIMS["west"][2],
        )
        return {
            "$schema": (
                "citysim://integration/"
                "industrial-l04-direction-execution-authority-v1"
            ),
            "schemaVersion": 1,
            "testProtocolRevision": 6,
            "batch": "industrial_l04_directional_family",
            "mode": "validation_only",
            "issuedAt": "2026-07-30T12:02:00Z",
            "task": {
                "taskId": "PLAY-081",
                "direction": "west",
                "branch": "codex/citysim-world-art-west",
                "claimPath": CLAIMS["west"][2],
                "claimRevision": 7,
                "claimSha256": digest(claim_payload),
                "publishedBaseCommit": PUBLISHED_BASE,
            },
            "schedule": {
                "path": SCHEDULE_PATH,
                "sha256": digest(self.schedule_payload),
                "publicationCommit": self.schedule_publication,
                "phase": "postlock_abc",
            },
            "appearanceLock": {
                "path": APPEARANCE_PATH,
                "sha256": digest(self.appearance_payload),
                "publicationCommit": self.integration_inputs_commit,
            },
            "sourceProductionProfile": {
                "path": PROFILE_PATH,
                "sha256": digest(self.profile_payload),
                "publicationCommit": self.integration_inputs_commit,
            },
            "grant": {
                "grantId": process["grantId"],
                "process": "A",
                "queueId": "west:A",
                "slotId": process["slotId"],
                "maximumChildStarts": 1,
                "exactlyOneInvocation": True,
                "orchestratorOnly": True,
                "directLowLevelInvocationAllowed": False,
            },
            "artifacts": {
                name: {
                    "path": ARTIFACT_PATHS[name],
                    "sha256": digest(payload),
                }
                for name, payload in self.artifact_payloads.items()
            },
            "exclusiveRoots": {
                "output": (
                    f"{consumer.SOURCE_ROOT}/outputs/"
                    "execution-closure-v1"
                ),
                "evidence": (
                    f"{EVIDENCE_ROOTS['west']}/evidence/"
                    "execution-closure-v1"
                ),
                "attempt": (
                    f"{EVIDENCE_ROOTS['west']}/attempts/"
                    "execution-closure-v1"
                ),
                "terminal": (
                    f"{EVIDENCE_ROOTS['west']}/terminals/"
                    "execution-closure-v1"
                ),
            },
            "executionEnvelope": {
                "timeoutSeconds": 900,
                "maximumRSSBytes": 4294967296,
                "cpuThreadLimit": 1,
                "startNewProcessGroup": True,
                "killProcessGroupOnLimit": True,
                "postReapProcessGroupExhaustionRequired": True,
                "networkAllowed": False,
                "leasePath": self.lease_path,
                "leaseMustBeFresh": True,
                "replayAllowed": False,
            },
            "authentication": {
                "secretTransport": "anonymous_pipe",
                "secretSha256": digest(b"play-081-test-secret"),
                "rawSecretPersisted": False,
                "childCapability": {
                    "algorithm": "HMAC-SHA256",
                    "capabilityId": "play-081-west-A-validation",
                    "audience": "industrial-l04-direction-child",
                    "boundGrantId": process["grantId"],
                    "payloadSha256": digest(b"play-081-test-payload"),
                    "macSha256": digest(b"play-081-test-mac"),
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
        }

    def validate(
        self,
        *,
        authority_path: str | None = None,
        trusted_head: str | None = None,
        worker_head: str | None = None,
        authority_publication_commit: str | None = None,
    ) -> dict[str, Any]:
        return consumer.validate_execution_closure(
            self.root,
            self.contract,
            authority_path=authority_path or self.authority_path,
            trusted_head=trusted_head or self.trusted_head,
            worker_head=worker_head or self.worker_head,
            authority_publication_commit=(
                authority_publication_commit
                or self.authority_publication
            ),
        )


class WestExecutionClosureV1Tests(unittest.TestCase):
    def fixture(self, **kwargs: Any) -> ClosureFixture:
        value = ClosureFixture(**kwargs)
        self.addCleanup(value.close)
        return value

    def assert_zero(self, result: dict[str, Any]) -> None:
        self.assertFalse(result.get("childStartAuthorized", False))
        self.assertTrue(
            all(value == 0 for value in result["activity"].values()),
            result,
        )

    def test_two_fresh_roots_produce_byte_identical_packet(self) -> None:
        first = self.fixture()
        second = self.fixture()
        first_result = first.validate()
        second_result = second.validate()
        self.assertEqual(first_result["result"], "PASS")
        self.assertEqual(second_result["result"], "PASS")
        self.assertEqual(canonical(first_result), canonical(second_result))
        self.assertEqual(first.trusted_head, second.trusted_head)
        self.assertEqual(first.worker_head, second.worker_head)
        self.assertTrue(first_result["highLevelOrchestratorInvoked"])
        self.assertTrue(first_result["runnerValidationBoundaryReached"])
        self.assert_zero(first_result)

    def test_missing_inputs_reject_before_high_level_or_runner(self) -> None:
        contract = consumer.decode_json(
            (REPOSITORY_ROOT / consumer.DEFAULT_CONTRACT).read_bytes(),
            consumer.DEFAULT_CONTRACT,
        )
        result = consumer.validate_execution_closure(
            REPOSITORY_ROOT,
            contract,
            authority_path=None,
            trusted_head=None,
            worker_head=None,
            authority_publication_commit=None,
        )
        self.assertEqual(result["result"], "BLOCKED")
        self.assertFalse(result["highLevelOrchestratorInvoked"])
        self.assertFalse(result["runnerValidationBoundaryReached"])
        self.assert_zero(result)

    def test_stale_nonancestral_replayed_and_forged_reject(self) -> None:
        stale = self.fixture()
        (stale.root / stale.authority_path).write_bytes(
            stale.authority_payload + b"\n"
        )
        result = stale.validate()
        self.assertEqual(result["result"], "BLOCKED")
        self.assert_zero(result)

        nonancestral = self.fixture()
        result = nonancestral.validate(
            worker_head=nonancestral.schedule_publication,
        )
        self.assertEqual(result["result"], "BLOCKED")
        self.assert_zero(result)

        replayed = self.fixture()
        (
            replayed.root
            / replayed.authority["exclusiveRoots"]["output"]
        ).mkdir(parents=True)
        result = replayed.validate()
        self.assertEqual(result["result"], "BLOCKED")
        self.assert_zero(result)

        forged = self.fixture(
            authority_path=(
                "docs/production/evidence/PLAY-081/"
                "FORGED-WEST-EXECUTION-AUTHORITY.json"
            )
        )
        result = forged.validate()
        self.assertEqual(result["result"], "BLOCKED")
        self.assert_zero(result)

    def test_wrong_direction_process_root_slot_claim_base_and_orchestrator(self) -> None:
        cases: list[
            tuple[str, Callable[[dict[str, Any]], None]]
        ] = [
            (
                "direction",
                lambda value: value["task"].update(direction="east"),
            ),
            (
                "process",
                lambda value: value["grant"].update(
                    process="B",
                    queueId="west:B",
                ),
            ),
            (
                "root",
                lambda value: value["exclusiveRoots"].update(
                    output=(
                        "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
                        "industrial-l04-east-source-v01/outputs/forged"
                    )
                ),
            ),
            (
                "slot",
                lambda value: value["grant"].update(slotId="dcc-9"),
            ),
            (
                "claim",
                lambda value: value["task"].update(claimSha256="f" * 64),
            ),
            (
                "base",
                lambda value: value["task"].update(
                    publishedBaseCommit=(
                        "448fd45c2fb07e7c6efdd4ac19764cdd04ce6cda"
                    )
                ),
            ),
            (
                "orchestrator",
                lambda value: value["artifacts"].update(
                    highLevelOrchestrator={
                        "path": (
                            f"{consumer.SOURCE_ROOT}/blender_render_west.py"
                        ),
                        "sha256": digest(
                            (
                                REPOSITORY_ROOT
                                / consumer.SOURCE_ROOT
                                / "blender_render_west.py"
                            ).read_bytes()
                        ),
                    }
                ),
            ),
        ]
        for name, mutator in cases:
            with self.subTest(name=name):
                fixture = self.fixture(authority_mutator=mutator)
                result = fixture.validate()
                self.assertEqual(result["result"], "BLOCKED")
                self.assert_zero(result)

    def test_direct_runner_and_unauthenticated_inputs_reject(self) -> None:
        direct_authority = self.fixture(
            authority_mutator=lambda value: value["grant"].update(
                directLowLevelInvocationAllowed=True
            )
        )
        result = direct_authority.validate()
        self.assertEqual(result["result"], "BLOCKED")
        self.assert_zero(result)

        unauthenticated = self.fixture(
            authority_mutator=lambda value: value["authentication"].update(
                secretTransport="environment"
            )
        )
        result = unauthenticated.validate()
        self.assertEqual(result["result"], "BLOCKED")
        self.assert_zero(result)

        direct_result = low_level_runner.validate_execution_closure_boundary(
            {},
            {},
            direct_invocation=True,
        )
        self.assertEqual(direct_result["result"], "BLOCKED")
        self.assertIn("direct-runner:forbidden", direct_result["errors"])
        self.assertTrue(
            all(value == 0 for value in direct_result["activity"].values())
        )


if __name__ == "__main__":
    unittest.main()
