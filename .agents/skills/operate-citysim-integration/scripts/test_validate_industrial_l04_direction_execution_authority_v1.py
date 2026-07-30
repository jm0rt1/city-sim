#!/usr/bin/env python3
"""Revision-6 no-DCC tests for the direction execution-closure validator."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
import uuid
from pathlib import Path
from typing import Any, Callable

VALIDATOR = Path(__file__).with_name(
    "validate_industrial_l04_direction_execution_authority_v1.py"
)
SPEC = importlib.util.spec_from_file_location("direction_execution_validator", VALIDATOR)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)

SPECS = MODULE.DIRECTION_SPECS
AUTHORITY_PATH = Path(
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-TEST-DIRECTION-EXECUTION-CLOSURE.json"
)
SCHEDULE_PATH = Path(
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-TEST-PARALLEL-EXECUTION-SCHEDULE.json"
)


def digest(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


class Fixture:
    def __init__(
        self,
        *,
        direction: str = "north",
        phase: str = "prelock_north_a",
        authority_path: Path = AUTHORITY_PATH,
        authority_mutator: Callable[[dict[str, Any]], None] | None = None,
        schedule_mutator: Callable[[dict[str, Any]], None] | None = None,
    ) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.authority_path = authority_path
        self.direction = direction
        self.phase = phase
        self.lease_path = (
            f"/private/tmp/citysim-industrial-l04-{direction}-"
            f"{uuid.uuid4().hex}.lock"
        )
        self._git("init", "-q")
        self._git("config", "user.name", "CitySim Test")
        self._git("config", "user.email", "citysim-test@example.invalid")
        self._write(Path("docs/production/decisions/CONTRACT-010.md"), b"family\n")
        self._write(Path("docs/production/evidence/INTEGRATION/APPEARANCE.json"), b'{"lock":1}\n')
        self._write(Path("docs/production/evidence/INTEGRATION/PROFILE.json"), b'{"profile":1}\n')
        self.claim_payloads: dict[str, bytes] = {}
        for name, spec in SPECS.items():
            revision = "" if name == "north" else "- **Claim revision:** 6\n"
            payload = (
                f"# {spec['taskId']} Claim\n\n"
                f"{revision}"
                f"- **Branch:** `{spec['branch']}`\n"
            ).encode()
            self.claim_payloads[name] = payload
            self._write(Path(spec["claimPath"]), payload)
        self._commit_all("foundation")
        self.base = self._rev("HEAD")

        self.artifact_payloads: dict[str, bytes] = {}
        self.artifact_paths: dict[str, Path] = {}
        artifact_names = (
            "executionContract",
            "directionScheduleAdapter",
            "highLevelOrchestrator",
            "runnerContract",
            "runnerEntrypoint",
            "scene",
            "materials",
            "toolchain",
        )
        artifact_root = Path(SPECS[direction]["artifactRoot"])
        for index, name in enumerate(artifact_names):
            path = artifact_root / "closure-test-v01" / f"{index:02d}-{name}.txt"
            payload = f"{direction}:{name}:revision-6\n".encode()
            self.artifact_paths[name] = path
            self.artifact_payloads[name] = payload

        schedule = self._schedule(direction, phase)
        if schedule_mutator is not None:
            schedule_mutator(schedule)
        self.schedule_payload = canonical_json(schedule)
        self._write(SCHEDULE_PATH, self.schedule_payload)
        self._commit_all("schedule")
        self.schedule_publication = self._rev("HEAD")

        authority = self._authority(direction, phase)
        if authority_mutator is not None:
            authority_mutator(authority)
        self.authority = authority
        self.authority_payload = canonical_json(authority)
        self._write(authority_path, self.authority_payload)
        self._commit_all("authority")
        self.authority_publication = self._rev("HEAD")
        self._git("update-ref", "refs/remotes/origin/master", self.authority_publication)
        self.trusted_head = self.authority_publication

        for name, path in self.artifact_paths.items():
            self._write(path, self.artifact_payloads[name])
        self._commit_all("worker")
        self.worker_head = self._rev("HEAD")

    def close(self) -> None:
        Path(self.lease_path).unlink(missing_ok=True)
        self.temporary.cleanup()

    def _git(self, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.root,
            capture_output=True,
            check=check,
        )

    def _rev(self, revision: str) -> str:
        return self._git("rev-parse", revision).stdout.decode().strip()

    def _write(self, path: Path, payload: bytes) -> None:
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)

    def _commit_all(self, message: str) -> None:
        self._git("add", ".")
        self._git("-c", "commit.gpgsign=false", "commit", "-q", "-m", message)

    def _schedule(self, selected_direction: str, phase: str) -> dict[str, Any]:
        slots = ["dcc-1"] if phase == "prelock_north_a" else ["dcc-1", "dcc-2", "dcc-3"]
        granted_tokens = (
            {"north:A"}
            if phase == "prelock_north_a"
            else {
                "north:B",
                "north:C",
                *{
                    f"{direction}:{process}"
                    for direction in ("east", "south", "west")
                    for process in ("A", "B", "C")
                },
            }
        )
        queue = sorted(granted_tokens)
        direction_grants = []
        for direction, spec in SPECS.items():
            adapter_path = (
                self.artifact_paths["directionScheduleAdapter"]
                if direction == selected_direction
                else Path(spec["artifactRoot"]) / "test-adapter.py"
            )
            adapter_payload = (
                self.artifact_payloads["directionScheduleAdapter"]
                if direction == selected_direction
                else f"{direction}:adapter\n".encode()
            )
            processes = []
            for process in ("A", "B", "C"):
                token = f"{direction}:{process}"
                granted = token in granted_tokens
                slot = slots[queue.index(token) % len(slots)] if granted else None
                processes.append(
                    {
                        "grantId": f"grant-{direction}-{process}",
                        "process": process,
                        "state": "granted" if granted else "blocked",
                        "slotId": slot,
                        "maximumChildStarts": 1 if granted else 0,
                        "orchestratorOnly": True,
                        "directLowLevelInvocationAllowed": False,
                    }
                )
            direction_grants.append(
                {
                    "direction": direction,
                    "claim": spec["taskId"],
                    "branch": spec["branch"],
                    "claimSha256": digest(self.claim_payloads[direction]),
                    "baseCommit": self.base,
                    "orchestrator": {
                        "path": adapter_path.as_posix(),
                        "sha256": digest(adapter_payload),
                    },
                    "exclusiveRoots": [
                        f"{spec['artifactRoot']}/schedule-exclusive",
                        f"{spec['evidenceRoot']}/schedule-exclusive",
                    ],
                    "processes": processes,
                }
            )
        appearance = None
        profile = None
        if phase == "postlock_abc":
            appearance_payload = (self.root / "docs/production/evidence/INTEGRATION/APPEARANCE.json").read_bytes()
            profile_payload = (self.root / "docs/production/evidence/INTEGRATION/PROFILE.json").read_bytes()
            appearance = {
                "path": "docs/production/evidence/INTEGRATION/APPEARANCE.json",
                "sha256": digest(appearance_payload),
            }
            profile = {
                "path": "docs/production/evidence/INTEGRATION/PROFILE.json",
                "sha256": digest(profile_payload),
            }
        return {
            "schema": 1,
            "batch": "industrial_l04_directional_family",
            "phase": phase,
            "issuedAt": "2026-07-30T12:00:00Z",
            "integrationAuthorityCommit": self.base,
            "familyContract": {
                "path": "docs/production/decisions/CONTRACT-010.md",
                "sha256": digest(b"family\n"),
            },
            "appearanceLock": appearance,
            "sourceProductionProfile": profile,
            "computeEnvelope": {
                "maximumSimultaneousDCCProcesses": len(slots),
                "slotIds": slots,
                "queueOrder": queue,
            },
            "directionGrants": direction_grants,
        }

    def _authority(self, direction: str, phase: str) -> dict[str, Any]:
        spec = SPECS[direction]
        process = "A" if direction != "north" or phase == "prelock_north_a" else "B"
        schedule = json.loads(self.schedule_payload)
        schedule_direction = next(
            item for item in schedule["directionGrants"] if item["direction"] == direction
        )
        schedule_process = next(
            item for item in schedule_direction["processes"] if item["process"] == process
        )
        appearance = None
        profile = None
        if phase == "postlock_abc":
            appearance = {
                **schedule["appearanceLock"],
                "publicationCommit": self.base,
            }
            profile = {
                **schedule["sourceProductionProfile"],
                "publicationCommit": self.base,
            }
        root_suffix = uuid.uuid4().hex
        native_root = spec["nativeRoot"]
        evidence_root = spec["evidenceRoot"]
        claim_revision = 1 if direction == "north" else 6
        return {
            "$schema": MODULE.SCHEMA_ID,
            "schemaVersion": 1,
            "testProtocolRevision": 6,
            "batch": "industrial_l04_directional_family",
            "mode": "validation_only",
            "issuedAt": "2026-07-30T12:01:00Z",
            "task": {
                "taskId": spec["taskId"],
                "direction": direction,
                "branch": spec["branch"],
                "claimPath": spec["claimPath"],
                "claimRevision": claim_revision,
                "claimSha256": digest(self.claim_payloads[direction]),
                "publishedBaseCommit": self.base,
            },
            "schedule": {
                "path": SCHEDULE_PATH.as_posix(),
                "sha256": digest(self.schedule_payload),
                "publicationCommit": self.schedule_publication,
                "phase": phase,
            },
            "appearanceLock": appearance,
            "sourceProductionProfile": profile,
            "grant": {
                "grantId": schedule_process["grantId"],
                "process": process,
                "queueId": f"{direction}:{process}",
                "slotId": schedule_process["slotId"],
                "maximumChildStarts": 1,
                "exactlyOneInvocation": True,
                "orchestratorOnly": True,
                "directLowLevelInvocationAllowed": False,
            },
            "artifacts": {
                name: {
                    "path": path.as_posix(),
                    "sha256": digest(self.artifact_payloads[name]),
                }
                for name, path in self.artifact_paths.items()
            },
            "exclusiveRoots": {
                "output": f"{native_root}/outputs/{root_suffix}",
                "evidence": f"{evidence_root}/evidence/{root_suffix}",
                "attempt": f"{evidence_root}/attempts/{root_suffix}",
                "terminal": f"{evidence_root}/terminals/{root_suffix}",
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
                "secretSha256": digest(b"test-secret"),
                "rawSecretPersisted": False,
                "childCapability": {
                    "algorithm": "HMAC-SHA256",
                    "capabilityId": f"cap-{root_suffix}",
                    "audience": "industrial-l04-direction-child",
                    "boundGrantId": schedule_process["grantId"],
                    "payloadSha256": digest(b"payload"),
                    "macSha256": digest(b"test-mac"),
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

    def validate(self, **overrides: str) -> dict[str, Any]:
        return MODULE.validate(
            self.root,
            self.root / self.authority_path,
            trusted_head=overrides.get("trusted_head", self.trusted_head),
            worker_head=overrides.get("worker_head", self.worker_head),
            authority_publication_commit=overrides.get(
                "authority_publication_commit", self.authority_publication
            ),
        )

    def republish_authority(self, payload: bytes) -> None:
        self._write(self.authority_path, payload)
        self._commit_all("republish authority")
        self.authority_publication = self._rev("HEAD")
        self.trusted_head = self.authority_publication
        self.worker_head = self.authority_publication
        self._git("update-ref", "refs/remotes/origin/master", self.trusted_head)


class DirectionExecutionAuthorityTests(unittest.TestCase):
    def fixture(self, **kwargs: Any) -> Fixture:
        fixture = Fixture(**kwargs)
        self.addCleanup(fixture.close)
        return fixture

    def assert_invalid(self, fixture: Fixture, pattern: str | None = None, **overrides: str) -> None:
        with self.assertRaises(MODULE.AuthorityError) as caught:
            fixture.validate(**overrides)
        if pattern is not None:
            self.assertIn(pattern, str(caught.exception))

    def test_valid_prelock_north_is_validation_only(self) -> None:
        fixture = self.fixture()
        result = fixture.validate()
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["direction"], "north")
        self.assertEqual(result["maximumChildStarts"], 1)
        self.assertEqual(
            (result["dccStarts"], result["childStarts"], result["renders"], result["pixels"]),
            (0, 0, 0, 0),
        )

    def test_valid_postlock_east_is_validation_only(self) -> None:
        fixture = self.fixture(direction="east", phase="postlock_abc")
        result = fixture.validate()
        self.assertEqual((result["direction"], result["process"]), ("east", "A"))
        self.assertTrue(result["validationOnly"])

    def test_rejects_forged_task_owned_authority(self) -> None:
        fixture = self.fixture(
            authority_path=Path(
                "docs/production/evidence/PLAY-027/FORGED-DIRECTION-AUTHORITY.json"
            )
        )
        self.assert_invalid(fixture, "Integration-owned")

    def test_rejects_wrong_trusted_head(self) -> None:
        fixture = self.fixture()
        self.assert_invalid(fixture, "does not equal fetched origin/master", trusted_head=fixture.base)

    def test_rejects_worker_without_authority_ancestry(self) -> None:
        fixture = self.fixture()
        self.assert_invalid(fixture, "authority publication/worker ancestry", worker_head=fixture.schedule_publication)

    def test_rejects_stale_authority_working_bytes(self) -> None:
        fixture = self.fixture()
        fixture._write(fixture.authority_path, fixture.authority_payload + b"\n")
        self.assert_invalid(fixture, "working bytes differ")

    def test_rejects_stale_schedule_hash(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["schedule"].update(sha256="f" * 64)
        )
        self.assert_invalid(fixture, "schedule hash")

    def test_rejects_wrong_task(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["task"].update(taskId="PLAY-079")
        )
        self.assert_invalid(fixture, "task.taskId")

    def test_rejects_wrong_direction_mapping(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["task"].update(direction="east")
        )
        self.assert_invalid(fixture, "task.taskId")

    def test_rejects_ungranted_process(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["grant"].update(
                process="B", queueId="north:B"
            )
        )
        self.assert_invalid(fixture, "not granted")

    def test_rejects_wrong_claim_path(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["task"].update(
                claimPath="docs/production/claims/PLAY-079.world-art-east.md"
            )
        )
        self.assert_invalid(fixture, "claimPath")

    def test_rejects_wrong_claim_revision(self) -> None:
        fixture = self.fixture(
            direction="east",
            phase="postlock_abc",
            authority_mutator=lambda value: value["task"].update(claimRevision=5),
        )
        self.assert_invalid(fixture, "claim revision")

    def test_rejects_wrong_claim_hash(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["task"].update(claimSha256="e" * 64)
        )
        self.assert_invalid(fixture, "claim hash")

    def test_rejects_wrong_base(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["task"].update(
                publishedBaseCommit=value["schedule"]["publicationCommit"]
            )
        )
        self.assert_invalid(fixture, "schedule base differs")

    def test_rejects_sibling_output_root(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["exclusiveRoots"].update(
                output=(
                    "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
                    "industrial-l04-east-source-v01/outputs/forged"
                )
            )
        )
        self.assert_invalid(fixture, "north-exclusive")

    def test_rejects_traversing_root(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["exclusiveRoots"].update(
                output=(
                    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
                    "industrial-l04-north-art-v12/process-a-execution-v01/"
                    "outputs/../forged"
                )
            )
        )
        self.assert_invalid(fixture, "may not traverse")

    def test_rejects_overlapping_roots(self) -> None:
        def mutate(value: dict[str, Any]) -> None:
            common = SPECS["north"]["evidenceRoot"]
            value["exclusiveRoots"].update(
                evidence=f"{common}/evidence/shared",
                attempt=f"{common}/evidence/shared/child",
            )

        fixture = self.fixture(authority_mutator=mutate)
        self.assert_invalid(fixture, "roots overlap")

    def test_rejects_preexisting_output_root(self) -> None:
        fixture = self.fixture()
        (fixture.root / fixture.authority["exclusiveRoots"]["output"]).mkdir(
            parents=True
        )
        self.assert_invalid(fixture, "already exists")

    def test_rejects_wrong_orchestrator_binding(self) -> None:
        def mutate(value: dict[str, Any]) -> None:
            adapter = copy.deepcopy(value["artifacts"]["directionScheduleAdapter"])
            contract = copy.deepcopy(value["artifacts"]["executionContract"])
            value["artifacts"]["directionScheduleAdapter"] = contract
            value["artifacts"]["executionContract"] = adapter

        fixture = self.fixture(authority_mutator=mutate)
        self.assert_invalid(fixture, "adapter binding differs")

    def test_rejects_direct_low_level_invocation(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["grant"].update(
                directLowLevelInvocationAllowed=True
            )
        )
        self.assert_invalid(fixture, "directLowLevelInvocationAllowed")

    def test_rejects_more_than_one_child(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["grant"].update(
                maximumChildStarts=2
            )
        )
        self.assert_invalid(fixture, "exactly one")

    def test_rejects_non_exact_invocation(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["grant"].update(
                exactlyOneInvocation=False
            )
        )
        self.assert_invalid(fixture, "exactlyOneInvocation")

    def test_rejects_replay_permission(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["executionEnvelope"].update(
                replayAllowed=True
            )
        )
        self.assert_invalid(fixture, "replayAllowed")

    def test_rejects_preexisting_lease(self) -> None:
        fixture = self.fixture()
        Path(fixture.lease_path).write_text("occupied")
        self.assert_invalid(fixture, "lease already exists")

    def test_rejects_bad_anonymous_pipe_auth(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["authentication"].update(
                secretTransport="environment"
            )
        )
        self.assert_invalid(fixture, "anonymous pipe")

    def test_rejects_bad_hmac_grant_binding(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["authentication"][
                "childCapability"
            ].update(boundGrantId="forged-grant")
        )
        self.assert_invalid(fixture, "exact grant")

    def test_rejects_non_false_readiness_admission_shipping_flags(self) -> None:
        for field in (
            "sourceCandidateReady",
            "appearanceAccepted",
            "integrationAdmitted",
            "rendererQuarantined",
            "productionSelected",
            "shippingAuthorized",
        ):
            with self.subTest(field=field):
                fixture = self.fixture(
                    authority_mutator=lambda value, field=field: value[
                        "disposition"
                    ].update({field: True})
                )
                self.assert_invalid(fixture, f"disposition.{field}")

    def test_rejects_extra_json_field(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value.update(unexpected=True)
        )
        self.assert_invalid(fixture, "fields do not match")

    def test_rejects_duplicate_json_key(self) -> None:
        fixture = self.fixture()
        duplicate = fixture.authority_payload.replace(
            b'{\n  "$schema":',
            b'{\n  "batch": "forged",\n  "$schema":',
            1,
        )
        fixture.republish_authority(duplicate)
        self.assert_invalid(fixture, "duplicate JSON key")

    def test_rejects_non_finite_json_number(self) -> None:
        fixture = self.fixture()
        mutated = fixture.authority_payload.replace(
            b'"timeoutSeconds": 900',
            b'"timeoutSeconds": NaN',
            1,
        )
        fixture.republish_authority(mutated)
        self.assert_invalid(fixture, "non-finite JSON number")

    def test_rejects_stale_worker_artifact_hash(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["artifacts"][
                "executionContract"
            ].update(sha256="a" * 64)
        )
        self.assert_invalid(fixture, "worker HEAD bytes")

    def test_rejects_artifact_alias(self) -> None:
        def mutate(value: dict[str, Any]) -> None:
            value["artifacts"]["runnerEntrypoint"] = copy.deepcopy(
                value["artifacts"]["runnerContract"]
            )

        fixture = self.fixture(authority_mutator=mutate)
        self.assert_invalid(fixture, "must not alias")

    def test_rejects_non_finite_runtime_value_even_if_python_accepts_it(self) -> None:
        fixture = self.fixture(
            authority_mutator=lambda value: value["executionEnvelope"].update(
                timeoutSeconds=float("inf")
            )
        )
        self.assert_invalid(fixture, "non-finite JSON number")


if __name__ == "__main__":
    unittest.main()
