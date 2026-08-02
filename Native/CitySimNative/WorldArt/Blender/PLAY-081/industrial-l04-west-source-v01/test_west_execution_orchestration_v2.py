#!/usr/bin/env python3
"""Focused zero-DCC tests for PLAY-081 West execution orchestration v2."""

from __future__ import annotations

import copy
from contextlib import contextmanager
import hashlib
from itertools import product
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

from west_execution_orchestration_v2 import (
    DEFAULT_EXECUTION_CONTRACT,
    DEFAULT_HIGH_LEVEL_ORCHESTRATOR,
    DEFAULT_LOW_LEVEL_RUNNER,
    DEFAULT_RUNNER_CONTRACT,
    SCHEDULE_SCHEMA,
    SOURCE_STAGE_SCHEMA_SHA256,
    OrchestrationError,
    committed_input_errors,
    current_binding_errors,
    decode_json_object,
    fixture_grant,
    fixture_schedule,
    fixture_writes,
    safe_write_receipt,
    simulate_receipt,
    static_contract_errors,
    validate_allocation,
    validate_bound_launch_grant,
    validate_contract_authorities,
    validate_integration_document_closure,
    validate_model_route_and_source_schema,
    validate_execution_receipt,
    validate_failure_isolation,
    validate_receipt_order,
    validate_retries,
    validate_schedule,
)
from west_path_safety import PathSafetyError


class WestExecutionOrchestrationV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repository_root = Path(__file__).resolve().parents[6]
        cls.execution_contract = json.loads(
            (cls.repository_root / DEFAULT_EXECUTION_CONTRACT).read_text(
                encoding="utf-8"
            )
        )
        cls.runner_contract = json.loads(
            (cls.repository_root / DEFAULT_RUNNER_CONTRACT).read_text(
                encoding="utf-8"
            )
        )
        cls.durations = [4, 4, 2, 2, 3, 3, 2, 2, 2, 2, 1]

    def schedule(self, mode: str = "parallel_two_slot") -> dict:
        return fixture_schedule(self.execution_contract, mode)

    def receipt(
        self,
        mode: str = "parallel_two_slot",
        **kwargs: object,
    ) -> tuple[dict, dict]:
        schedule = self.schedule(mode)
        return schedule, simulate_receipt(
            schedule,
            self.execution_contract,
            self.durations,
            **kwargs,
        )

    @contextmanager
    def committed_authority(
        self,
        relative: str,
        value: bytes,
    ):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(
                ["git", "config", "user.name", "PLAY-081 Test"],
                cwd=root,
                check=True,
            )
            subprocess.run(
                ["git", "config", "user.email", "play-081@example.invalid"],
                cwd=root,
                check=True,
            )
            path = root / relative
            path.parent.mkdir(parents=True)
            path.write_bytes(value)
            subprocess.run(["git", "add", relative], cwd=root, check=True)
            subprocess.run(
                ["git", "commit", "-q", "-m", "fixture authority"],
                cwd=root,
                check=True,
            )
            commit = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=root,
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            yield root, commit, hashlib.sha256(value).hexdigest(), path

    def test_current_inputs_fail_closed_before_dcc(self) -> None:
        self.assertEqual(
            set(self.execution_contract["futureIntegrationInputs"]),
            {
                "scheduleSchema",
                "scheduleAuthority",
                "launchGrantA",
                "launchGrantB",
                "launchGrantC",
                "appearanceLock",
                "lockedMaterialMapping",
                "sourceProductionProfile",
                "globalExecutionReceipt",
            },
        )
        self.assertEqual(
            static_contract_errors(
                self.execution_contract,
                self.runner_contract,
            ),
            [],
        )
        errors = current_binding_errors(
            self.execution_contract,
            self.runner_contract,
        )
        self.assertIn("appearance-lock:not-bound", errors)
        self.assertIn("source-production-profile:not-bound", errors)
        self.assertIn("integration-input:scheduleSchema:not-published", errors)
        self.assertIn("integration-input:scheduleAuthority:not-published", errors)
        self.assertIn("integration-input:launchGrantA:not-published", errors)
        self.assertIn("integration-input:launchGrantB:not-published", errors)
        self.assertIn("integration-input:launchGrantC:not-published", errors)
        self.assertIn("production-execution:disabled", errors)
        self.assertIn("production-receipt-emission:disabled", errors)

    def test_external_route_and_source_schema_are_exactly_bound(self) -> None:
        errors, result = validate_model_route_and_source_schema(
            self.repository_root, self.execution_contract
        )
        self.assertEqual(errors, [])
        self.assertEqual(result["routeId"], "quality-v2:play-081-west-v14-exact-closure-r2")
        self.assertEqual(result["routeSHA256"], "16d011163da66a72637aa0f9ca3bde30d65c7f0dc97ed8c1d434f96bdb253809")
        self.assertEqual(result["sourceStageSchemaSHA256"], "85f6a2824c273a1e63354df79a97e5a59c2909a68771613b325664d649ac53ec")
        mutations = (
            ("carrierCommit", "0" * 40, "model-route:binding"),
            ("path", "docs/production/evidence/INTEGRATION/other.json", "model-route:binding"),
            ("sha256", "0" * 64, "model-route:binding"),
            ("routeId", "quality-v2:wrong", "model-route:binding"),
            ("routeSha256", "0" * 64, "model-route:binding"),
        )
        for field, value, expected in mutations:
            candidate = copy.deepcopy(self.execution_contract)
            candidate["modelRouteAuthority"][field] = value
            bad, _ = validate_model_route_and_source_schema(self.repository_root, candidate)
            self.assertIn(expected, bad, field)
        candidate = copy.deepcopy(self.execution_contract)
        candidate["sourceStageSchemaAuthority"]["sha256"] = "0" * 64
        bad, _ = validate_model_route_and_source_schema(self.repository_root, candidate)
        self.assertIn("source-schema:binding", bad)

    def test_parallel_two_slot_positive(self) -> None:
        schedule, receipt = self.receipt()
        self.assertEqual(validate_schedule(schedule, self.execution_contract), [])
        self.assertEqual(
            validate_execution_receipt(
                receipt,
                schedule,
                self.execution_contract,
            ),
            [],
        )
        self.assertEqual(receipt["maximumObservedConcurrency"], 2)
        self.assertTrue(receipt["actualOverlap"])

    def test_authorized_sequential_exception_positive(self) -> None:
        schedule, receipt = self.receipt("sequential_exception")
        authority = {
            "schema": "citysim.integration.world-art-sequential-exception.v1",
            "owner": "Integration",
            "scheduleId": schedule["scheduleId"],
            "scheduleRevision": schedule["scheduleRevision"],
            "executionMode": "sequential_exception",
            "reason": schedule["exceptionAuthority"]["reason"],
            "queueOrder": schedule["exceptionAuthority"]["queueOrder"],
        }
        data = (
            json.dumps(authority, indent=2, sort_keys=True) + "\n"
        ).encode()
        relative = (
            "docs/production/evidence/INTEGRATION/"
            "SYNTHETIC-SEQUENTIAL-EXCEPTION.json"
        )
        with self.committed_authority(relative, data) as (
            root,
            commit,
            digest,
            _,
        ):
            schedule["exceptionAuthority"].update(
                {
                    "path": relative,
                    "commit": commit,
                    "sha256": digest,
                }
            )
            self.assertEqual(
                validate_schedule(
                    schedule,
                    self.execution_contract,
                    repository_root=root,
                ),
                [],
            )
            self.assertEqual(
                validate_execution_receipt(
                    receipt,
                    schedule,
                    self.execution_contract,
                    repository_root=root,
                ),
                [],
            )
        self.assertEqual(receipt["maximumObservedConcurrency"], 1)
        self.assertFalse(receipt["actualOverlap"])

    def test_parallel_requires_actual_overlap(self) -> None:
        parallel = self.schedule()
        sequential = self.schedule("sequential_exception")
        receipt = simulate_receipt(
            sequential,
            self.execution_contract,
            self.durations,
        )
        receipt["scheduleId"] = parallel["scheduleId"]
        receipt["scheduleRevision"] = parallel["scheduleRevision"]
        receipt["executionMode"] = "parallel_two_slot"
        errors = validate_execution_receipt(
            receipt,
            parallel,
            self.execution_contract,
        )
        self.assertIn("receipt:parallel-overlap-required", errors)

    def test_sequential_forbids_overlap(self) -> None:
        parallel = self.schedule()
        sequential = self.schedule("sequential_exception")
        receipt = simulate_receipt(
            parallel,
            self.execution_contract,
            self.durations,
        )
        receipt["scheduleId"] = sequential["scheduleId"]
        receipt["scheduleRevision"] = sequential["scheduleRevision"]
        receipt["executionMode"] = "sequential_exception"
        errors = validate_execution_receipt(
            receipt,
            sequential,
            self.execution_contract,
        )
        self.assertIn("receipt:sequential-cap", errors)
        self.assertIn("receipt:sequential-overlap-forbidden", errors)

    def test_sequential_requires_exact_integration_exception(self) -> None:
        schedule = self.schedule("sequential_exception")
        schedule["exceptionAuthority"] = None
        self.assertIn(
            "schedule:sequential-exception-shape",
            validate_schedule(schedule, self.execution_contract),
        )

    def test_simultaneous_end_precedes_start(self) -> None:
        schedule = self.schedule()
        receipt = simulate_receipt(
            schedule,
            self.execution_contract,
            [2] * 11,
        )
        self.assertEqual(
            validate_execution_receipt(
                receipt,
                schedule,
                self.execution_contract,
            ),
            [],
        )
        events_by_time: dict[int, list[str]] = {}
        for event in receipt["events"]:
            events_by_time.setdefault(event["monotonicNs"], []).append(event["kind"])
        boundary = next(
            kinds
            for kinds in events_by_time.values()
            if "end" in kinds and "start" in kinds
        )
        self.assertLess(boundary.index("end"), boundary.index("start"))

    def test_monotonic_event_reordering_rejected(self) -> None:
        schedule, receipt = self.receipt()
        receipt["events"][0], receipt["events"][1] = (
            receipt["events"][1],
            receipt["events"][0],
        )
        errors = validate_execution_receipt(
            receipt,
            schedule,
            self.execution_contract,
        )
        self.assertTrue(
            {"receipt:event-sequence", "receipt:event-order"} & set(errors)
        )

    def test_missing_invocation_and_fifo_reordering_rejected(self) -> None:
        schedule, receipt = self.receipt()
        receipt["events"] = [
            event for event in receipt["events"] if event["jobId"] != "W-C"
        ]
        for sequence, event in enumerate(receipt["events"], start=1):
            event["sequence"] = sequence
        errors = validate_execution_receipt(
            receipt,
            schedule,
            self.execution_contract,
        )
        self.assertIn("receipt:job-disposition-completeness", errors)

        _, reordered = self.receipt()
        first = next(
            event for event in reordered["events"] if event["jobId"] == "N-B" and event["kind"] == "start"
        )
        second = next(
            event for event in reordered["events"] if event["jobId"] == "E-A" and event["kind"] == "start"
        )
        first["jobId"], second["jobId"] = second["jobId"], first["jobId"]
        errors = validate_execution_receipt(
            reordered,
            schedule,
            self.execution_contract,
        )
        self.assertIn("receipt:fifo-start-order", errors)

    def test_receipt_rejects_unassigned_slot(self) -> None:
        schedule, receipt = self.receipt()
        receipt["events"][0]["slotId"] = "dcc-9"
        errors = validate_execution_receipt(
            receipt,
            schedule,
            self.execution_contract,
        )
        self.assertIn("receipt:slot", errors)

    def test_allocation_binds_exact_west_identity_and_roots(self) -> None:
        schedule = self.schedule()
        for process_id in ("A", "B", "C"):
            grant = fixture_grant(
                schedule,
                self.execution_contract,
                self.runner_contract,
                process_id,
            )
            self.assertEqual(
                validate_allocation(
                    schedule,
                    grant,
                    self.execution_contract,
                    self.runner_contract,
                    process_id,
                ),
                [],
            )

    def test_wrong_direction_ordinal_and_root_rejected(self) -> None:
        schedule = self.schedule()
        grant = fixture_grant(
            schedule,
            self.execution_contract,
            self.runner_contract,
            "A",
        )
        grant["direction"] = "east"
        grant["queueOrdinal"] = 8
        grant["rawRoot"] = grant["semanticRoot"]
        errors = validate_allocation(
            schedule,
            grant,
            self.execution_contract,
            self.runner_contract,
            "A",
        )
        self.assertIn("allocation:west-identity", errors)
        self.assertIn("allocation:rawRoot", errors)
        self.assertIn("allocation:root-alias", errors)

    def test_sequential_rejects_second_slot(self) -> None:
        schedule = self.schedule("sequential_exception")
        grant = fixture_grant(
            schedule,
            self.execution_contract,
            self.runner_contract,
            "A",
        )
        grant["slotId"] = "dcc-1"
        self.assertIn(
            "allocation:slot",
            validate_allocation(
                schedule,
                grant,
                self.execution_contract,
                self.runner_contract,
                "A",
            ),
        )

    def test_committed_authority_exact_regular_blob_positive(self) -> None:
        relative = (
            "docs/production/evidence/INTEGRATION/"
            "SYNTHETIC-AUTHORITY.json"
        )
        data = b'{"fixtureOnly":true}\n'
        with self.committed_authority(relative, data) as (
            root,
            commit,
            digest,
            _,
        ):
            binding = {
                "state": "bound_integration",
                "path": relative,
                "commit": commit,
                "sha256": digest,
            }
            errors, captured = committed_input_errors(
                root,
                binding,
                relative,
                digest,
                "fixture",
            )
            self.assertEqual(errors, [])
            self.assertEqual(captured, data)

    def test_authority_json_rejects_duplicate_keys_and_nonfinite_values(self) -> None:
        with self.assertRaises(OrchestrationError):
            decode_json_object(b'{"value":1,"value":2}', "duplicate")
        with self.assertRaises(OrchestrationError):
            decode_json_object(b'{"value":NaN}', "nonfinite")

    def test_every_declared_integration_authority_is_dereferenced(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(
                ["git", "config", "user.name", "PLAY-081 Test"],
                cwd=root,
                check=True,
            )
            subprocess.run(
                ["git", "config", "user.email", "play-081@example.invalid"],
                cwd=root,
                check=True,
            )
            contract = copy.deepcopy(self.execution_contract)
            runner = copy.deepcopy(self.runner_contract)
            contract["modelRouteAuthority"] = None
            contract["sourceStageSchemaAuthority"] = None
            paths: dict[str, tuple[str, bytes]] = {
                "frozenDesignAuthority": (
                    "docs/production/evidence/INTEGRATION/DESIGN.md",
                    b"frozen design fixture\n",
                )
            }
            for name in contract["futureIntegrationInputs"]:
                paths[name] = (
                    f"docs/production/evidence/INTEGRATION/{name}.json",
                    (json.dumps({"authority": name}) + "\n").encode(),
                )
            for relative, data in paths.values():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(
                ["git", "commit", "-q", "-m", "all authorities"],
                cwd=root,
                check=True,
            )
            commit = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=root,
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            design_path, design_data = paths["frozenDesignAuthority"]
            contract["frozenDesignAuthority"].update(
                {
                    "path": design_path,
                    "commit": commit,
                    "sha256": hashlib.sha256(design_data).hexdigest(),
                }
            )
            for name, binding in contract["futureIntegrationInputs"].items():
                relative, data = paths[name]
                binding.update(
                    {
                        "state": "bound_integration",
                        "path": relative,
                        "commit": commit,
                        "sha256": hashlib.sha256(data).hexdigest(),
                    }
                )
            appearance = contract["futureIntegrationInputs"]["appearanceLock"]
            runner["appearanceLock"].update(
                {
                    "documentPath": appearance["path"],
                    "commit": appearance["commit"],
                    "documentSha256": appearance["sha256"],
                }
            )
            profile = contract["futureIntegrationInputs"][
                "sourceProductionProfile"
            ]
            runner["sourceStage"]["sourceProductionProfile"] = {
                "state": "bound_integration_profile",
                "path": profile["path"],
                "commit": profile["commit"],
                "sha256": profile["sha256"],
            }
            errors, captures = validate_contract_authorities(
                root,
                contract,
                runner,
            )
            self.assertEqual(errors, [])
            self.assertEqual(
                set(captures),
                {
                    "frozenDesignAuthority",
                    *contract["futureIntegrationInputs"].keys(),
                },
            )
            locked_path = root / paths["lockedMaterialMapping"][0]
            locked_path.write_bytes(b'{"authority":"tampered"}\n')
            errors, _ = validate_contract_authorities(
                root,
                contract,
                runner,
            )
            self.assertIn(
                "integration-input:lockedMaterialMapping:working-tree-sha256",
                errors,
            )

    def test_complete_integration_document_closure_is_cross_bound(self) -> None:
        """A committed positive fixture and field-level adversaries stay zero-child."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "PLAY-081 Test"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "play-081@example.invalid"], cwd=root, check=True)
            branch = self.execution_contract["branch"]
            subprocess.run(["git", "checkout", "-qb", branch], cwd=root, check=True)
            claim_path = root / "docs/production/claims/PLAY-081.world-art-west.md"
            claim_path.parent.mkdir(parents=True)
            claim_path.write_text("Claim revision: 11\n", encoding="utf-8")
            base_path = root / "docs/production/evidence/INTEGRATION/BASE.md"
            base_path.parent.mkdir(parents=True, exist_ok=True)
            base_path.write_text("frozen design\n", encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "fixture base"], cwd=root, check=True)
            base = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
            contract = copy.deepcopy(self.execution_contract)
            runner = copy.deepcopy(self.runner_contract)
            contract["modelRouteAuthority"] = None
            contract["sourceStageSchemaAuthority"] = None
            session_id = "west-integration-session-v1"
            docs: dict[str, dict] = {}
            schedule = fixture_schedule(contract, "parallel_two_slot")
            schema = {
                "documentType": "scheduleSchema", "schema": SCHEDULE_SCHEMA,
                "schemaVersion": 1, "taskId": "PLAY-081", "direction": "west",
                "claimSHA256": hashlib.sha256(claim_path.read_bytes()).hexdigest(),
                "claimRevision": 11, "branch": branch, "workerHead": base,
                "sessionId": session_id,
            }
            docs["scheduleSchema"] = schema
            docs["scheduleAuthority"] = {
                "documentType": "scheduleAuthority", "schedule": schedule,
                "scheduleSchemaSHA256": "", "sessionId": session_id,
                "taskId": "PLAY-081", "direction": "west",
                "claimSHA256": schema["claimSHA256"], "claimRevision": 11,
                "branch": branch, "workerHead": base, "publishedBase": base,
            }
            schema_bytes = (json.dumps(schema, indent=2, sort_keys=True) + "\n").encode()
            docs["scheduleAuthority"]["scheduleSchemaSHA256"] = hashlib.sha256(schema_bytes).hexdigest()
            appearance = {
                "documentType": "appearanceLock", "state": "released",
                "sessionId": session_id, "taskId": "PLAY-081", "direction": "west",
                "claimSHA256": schema["claimSHA256"], "claimRevision": 11,
                "branch": branch, "workerHead": base, "publishedBase": base,
                "sourceSha256": "a" * 64, "decodedRgbaSha256": "b" * 64,
            }
            materials = {
                "documentType": "lockedMaterialMapping", "state": "released",
                "sessionId": session_id, "taskId": "PLAY-081", "direction": "west",
                "claimSHA256": schema["claimSHA256"], "claimRevision": 11,
                "branch": branch, "workerHead": base, "publishedBase": base,
                "appearanceLockSHA256": "", "roles": {"frame": "steel"},
            }
            profile = {
                "documentType": "sourceProductionProfile", "schema": "source-stage-v2",
                "sessionId": session_id, "taskId": "PLAY-081", "direction": "west",
                "claimSHA256": schema["claimSHA256"], "claimRevision": 11,
                "branch": branch, "workerHead": base, "publishedBase": base,
                "scheduleAuthoritySHA256": "", "appearanceLockSHA256": "",
                "lockedMaterialMappingSHA256": "", "sourceStageSchemaSHA256": SOURCE_STAGE_SCHEMA_SHA256,
            }
            docs["appearanceLock"], docs["lockedMaterialMapping"], docs["sourceProductionProfile"] = appearance, materials, profile
            for process_id in ("A", "B", "C"):
                grant = fixture_grant(schedule, contract, runner, process_id)
                expected = contract["westProcesses"][process_id]
                docs[f"launchGrant{process_id}"] = {
                    "documentType": "launchGrant", "grant": grant,
                    "sessionId": session_id, "taskId": "PLAY-081", "direction": "west",
                    "claimSHA256": schema["claimSHA256"], "claimRevision": 11,
                    "branch": branch, "workerHead": base, "publishedBase": base,
                    "scheduleAuthoritySHA256": "", "orchestrator": DEFAULT_HIGH_LEVEL_ORCHESTRATOR,
                    "runner": DEFAULT_LOW_LEVEL_RUNNER, "outputRoot": expected["directory"],
                    "rawRoot": expected["rawRoot"], "semanticRoot": expected["semanticRoot"],
                    "evidenceRoot": expected["evidenceRoot"], "maximumChildStarts": 1,
                }
            def canonical_bytes(value: dict) -> bytes:
                return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()
            docs["scheduleAuthority"]["scheduleSchemaSHA256"] = hashlib.sha256(canonical_bytes(docs["scheduleSchema"])).hexdigest()
            schedule_authority_hash = hashlib.sha256(canonical_bytes(docs["scheduleAuthority"])).hexdigest()
            appearance_hash = hashlib.sha256(canonical_bytes(appearance)).hexdigest()
            materials["appearanceLockSHA256"] = appearance_hash
            materials_hash = hashlib.sha256(canonical_bytes(materials)).hexdigest()
            profile["scheduleAuthoritySHA256"] = schedule_authority_hash
            profile["appearanceLockSHA256"] = appearance_hash
            profile["lockedMaterialMappingSHA256"] = materials_hash
            profile_hash = hashlib.sha256(canonical_bytes(profile)).hexdigest()
            for process_id in ("A", "B", "C"):
                docs[f"launchGrant{process_id}"]["scheduleAuthoritySHA256"] = schedule_authority_hash
            grant_hashes = {p: hashlib.sha256(canonical_bytes(docs[f"launchGrant{p}"])).hexdigest() for p in ("A", "B", "C")}
            docs["globalExecutionReceipt"] = {
                "documentType": "integrationSession", "sessionId": session_id,
                "taskId": "PLAY-081", "direction": "west", "claimSHA256": schema["claimSHA256"],
                "claimRevision": 11, "branch": branch, "workerHead": base, "publishedBase": base,
                "scheduleAuthoritySHA256": schedule_authority_hash, "grantSHA256": grant_hashes,
                "appearanceLockSHA256": appearance_hash, "lockedMaterialMappingSHA256": materials_hash,
                "sourceProductionProfileSHA256": profile_hash,
            }
            path_map: dict[str, tuple[str, bytes]] = {"frozenDesignAuthority": (str(base_path.relative_to(root)), base_path.read_bytes())}
            for name, value in docs.items():
                relative = f"docs/production/evidence/INTEGRATION/{name}.json"
                path_map[name] = (relative, canonical_bytes(value))
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(path_map[name][1])
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "fixture authorities"], cwd=root, check=True)
            worker_head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
            contract["frozenDesignAuthority"] = {"path": path_map["frozenDesignAuthority"][0], "commit": worker_head, "sha256": hashlib.sha256(path_map["frozenDesignAuthority"][1]).hexdigest()}
            for name, binding in contract["futureIntegrationInputs"].items():
                relative, data = path_map[name]
                binding.update({"state": "bound_integration", "path": relative, "commit": worker_head, "sha256": hashlib.sha256(data).hexdigest()})
            runner["appearanceLock"].update({"documentPath": contract["futureIntegrationInputs"]["appearanceLock"]["path"], "commit": worker_head, "documentSha256": contract["futureIntegrationInputs"]["appearanceLock"]["sha256"]})
            profile_binding = contract["futureIntegrationInputs"]["sourceProductionProfile"]
            runner["sourceStage"]["sourceProductionProfile"] = {"state": "bound_integration_profile", "path": profile_binding["path"], "commit": worker_head, "sha256": profile_binding["sha256"]}
            with patch(
                "west_execution_orchestration_v2.git_output",
                side_effect=lambda _root, *args: (
                    base if args == ("rev-parse", "HEAD") else branch
                    if args == ("branch", "--show-current") else None
                ),
            ):
                errors, result = validate_integration_document_closure(root, contract, runner)
            self.assertEqual(errors, [])
            self.assertEqual(result["workerHead"], base)
            for field, expected in (("direction", "east"), ("claimSHA256", "0" * 64), ("branch", "codex/citysim-world-art-south")):
                candidate = copy.deepcopy(docs["appearanceLock"])
                candidate[field] = expected
                target = root / path_map["appearanceLock"][0]
                target.write_bytes(canonical_bytes(candidate))
                with patch(
                    "west_execution_orchestration_v2.git_output",
                    side_effect=lambda _root, *args: (
                        base if args == ("rev-parse", "HEAD") else branch
                        if args == ("branch", "--show-current") else None
                    ),
                ):
                    bad, _ = validate_integration_document_closure(root, contract, runner)
                self.assertTrue(bad)
                target.write_bytes(path_map["appearanceLock"][1])
            adversarial_fields = (
                ("taskId", "PLAY-999"),
                ("claimRevision", 99),
                ("workerHead", "0" * 40),
                ("sessionId", "other-session"),
                ("publishedBase", "0" * 40),
                ("outputRoot", "docs/production/evidence/PLAY-079/escape"),
                ("maximumChildStarts", 2),
            )
            for field, expected in adversarial_fields:
                candidate = copy.deepcopy(docs["launchGrantA"])
                candidate[field] = expected
                target = root / path_map["launchGrantA"][0]
                target.write_bytes(canonical_bytes(candidate))
                with patch(
                    "west_execution_orchestration_v2.git_output",
                    side_effect=lambda _root, *args: (
                        base if args == ("rev-parse", "HEAD") else branch
                        if args == ("branch", "--show-current") else None
                    ),
                ):
                    bad, _ = validate_integration_document_closure(root, contract, runner)
                self.assertTrue(bad, field)
                target.write_bytes(path_map["launchGrantA"][1])
            for field, expected in (
                ("scheduleAuthoritySHA256", "0" * 64),
                ("appearanceLockSHA256", "0" * 64),
                ("lockedMaterialMappingSHA256", "0" * 64),
                ("sourceProductionProfileSHA256", "0" * 64),
            ):
                candidate = copy.deepcopy(docs["globalExecutionReceipt"])
                candidate[field] = expected
                target = root / path_map["globalExecutionReceipt"][0]
                target.write_bytes(canonical_bytes(candidate))
                with patch(
                    "west_execution_orchestration_v2.git_output",
                    side_effect=lambda _root, *args: (
                        base if args == ("rev-parse", "HEAD") else branch
                        if args == ("branch", "--show-current") else None
                    ),
                ):
                    bad, _ = validate_integration_document_closure(root, contract, runner)
                self.assertTrue(bad, field)
                target.write_bytes(path_map["globalExecutionReceipt"][1])

    def test_committed_authority_rejects_hash_and_content_drift(self) -> None:
        relative = (
            "docs/production/evidence/INTEGRATION/"
            "SYNTHETIC-AUTHORITY.json"
        )
        original = b'{"revision":1}\n'
        with self.committed_authority(relative, original) as (
            root,
            commit,
            digest,
            path,
        ):
            binding = {
                "state": "bound_integration",
                "path": relative,
                "commit": commit,
                "sha256": digest,
            }
            wrong_errors, _ = committed_input_errors(
                root,
                binding,
                relative,
                "0" * 64,
                "fixture",
            )
            self.assertIn("fixture:argument-sha256-mismatch", wrong_errors)
            path.write_bytes(b'{"revision":2}\n')
            drift_errors, _ = committed_input_errors(
                root,
                binding,
                relative,
                digest,
                "fixture",
            )
            self.assertIn("fixture:working-tree-sha256", drift_errors)
            self.assertIn("fixture:working-tree-content-drift", drift_errors)

    def test_committed_authority_rejects_missing_and_symlink(self) -> None:
        relative = (
            "docs/production/evidence/INTEGRATION/"
            "SYNTHETIC-AUTHORITY.json"
        )
        data = b'{"fixtureOnly":true}\n'
        with self.committed_authority(relative, data) as (
            root,
            commit,
            digest,
            path,
        ):
            missing = relative.replace("AUTHORITY", "MISSING")
            missing_binding = {
                "state": "bound_integration",
                "path": missing,
                "commit": commit,
                "sha256": digest,
            }
            missing_errors, _ = committed_input_errors(
                root,
                missing_binding,
                missing,
                digest,
                "missing",
            )
            self.assertTrue(
                any(error.startswith("missing:unsafe-path:") for error in missing_errors)
            )
            target = root / "authority-target.json"
            target.write_bytes(data)
            path.unlink()
            path.symlink_to(target)
            symlink_errors, _ = committed_input_errors(
                root,
                {
                    "state": "bound_integration",
                    "path": relative,
                    "commit": commit,
                    "sha256": digest,
                },
                relative,
                digest,
                "symlink",
            )
            self.assertTrue(
                any("SYMLINK_COMPONENT" in error for error in symlink_errors)
            )

    def test_committed_authority_rejects_git_symlink_blob(self) -> None:
        relative = (
            "docs/production/evidence/INTEGRATION/"
            "SYNTHETIC-AUTHORITY.json"
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(
                ["git", "config", "user.name", "PLAY-081 Test"],
                cwd=root,
                check=True,
            )
            subprocess.run(
                ["git", "config", "user.email", "play-081@example.invalid"],
                cwd=root,
                check=True,
            )
            path = root / relative
            path.parent.mkdir(parents=True)
            path.symlink_to("fixture-target")
            subprocess.run(["git", "add", relative], cwd=root, check=True)
            subprocess.run(
                ["git", "commit", "-q", "-m", "symlink authority"],
                cwd=root,
                check=True,
            )
            symlink_commit = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=root,
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            path.unlink()
            path.write_bytes(b"fixture-target")
            subprocess.run(["git", "add", relative], cwd=root, check=True)
            subprocess.run(
                ["git", "commit", "-q", "-m", "regular working blob"],
                cwd=root,
                check=True,
            )
            digest = hashlib.sha256(b"fixture-target").hexdigest()
            errors, _ = committed_input_errors(
                root,
                {
                    "state": "bound_integration",
                    "path": relative,
                    "commit": symlink_commit,
                    "sha256": digest,
                },
                relative,
                digest,
                "git-mode",
            )
            self.assertIn(
                "git-mode:commit-object-not-regular-blob",
                errors,
            )

    def test_committed_authority_rejects_non_ancestral_commit(self) -> None:
        relative = (
            "docs/production/evidence/INTEGRATION/"
            "SYNTHETIC-AUTHORITY.json"
        )
        data = b'{"fixtureOnly":true}\n'
        with self.committed_authority(relative, data) as (
            root,
            _,
            digest,
            _,
        ):
            tree = subprocess.run(
                ["git", "rev-parse", "HEAD^{tree}"],
                cwd=root,
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            unrelated = subprocess.run(
                ["git", "commit-tree", tree],
                cwd=root,
                check=True,
                capture_output=True,
                text=True,
                input="unrelated authority\n",
            ).stdout.strip()
            errors, _ = committed_input_errors(
                root,
                {
                    "state": "bound_integration",
                    "path": relative,
                    "commit": unrelated,
                    "sha256": digest,
                },
                relative,
                digest,
                "ancestry",
            )
            self.assertIn("ancestry:commit-not-in-head", errors)

    def test_sequential_exception_rejects_nonexistent_and_wrong_content(self) -> None:
        schedule = self.schedule("sequential_exception")
        self.assertIn(
            "schedule:sequential-exception-not-dereferenced",
            validate_schedule(schedule, self.execution_contract),
        )
        wrong = {
            "schema": "citysim.integration.world-art-sequential-exception.v1",
            "owner": "Integration",
            "scheduleId": schedule["scheduleId"],
            "scheduleRevision": schedule["scheduleRevision"],
            "executionMode": "sequential_exception",
            "reason": "different authority content",
            "queueOrder": schedule["exceptionAuthority"]["queueOrder"],
        }
        data = (json.dumps(wrong, sort_keys=True) + "\n").encode()
        relative = (
            "docs/production/evidence/INTEGRATION/"
            "SYNTHETIC-SEQUENTIAL-EXCEPTION.json"
        )
        with self.committed_authority(relative, data) as (
            root,
            commit,
            digest,
            _,
        ):
            schedule["exceptionAuthority"].update(
                {
                    "path": relative,
                    "commit": commit,
                    "sha256": digest,
                }
            )
            self.assertIn(
                "schedule:sequential-exception-content",
                validate_schedule(
                    schedule,
                    self.execution_contract,
                    repository_root=root,
                ),
            )

    def test_launch_grant_must_be_exact_contract_bound_blob(self) -> None:
        schedule = self.schedule()
        grant = fixture_grant(
            schedule,
            self.execution_contract,
            self.runner_contract,
            "A",
        )
        data = (json.dumps(grant, indent=2, sort_keys=True) + "\n").encode()
        relative = (
            "docs/production/evidence/INTEGRATION/"
            "SYNTHETIC-WEST-A-LAUNCH-GRANT.json"
        )
        with self.committed_authority(relative, data) as (
            root,
            commit,
            digest,
            path,
        ):
            contract = copy.deepcopy(self.execution_contract)
            contract["futureIntegrationInputs"]["launchGrantA"] = {
                "state": "bound_integration",
                "path": relative,
                "commit": commit,
                "sha256": digest,
            }
            self.assertEqual(
                validate_bound_launch_grant(
                    root,
                    schedule,
                    contract,
                    self.runner_contract,
                    "A",
                    relative,
                    digest,
                ),
                [],
            )
            wrong_path_errors = validate_bound_launch_grant(
                root,
                schedule,
                contract,
                self.runner_contract,
                "A",
                relative + ".other",
                digest,
            )
            self.assertIn(
                "launch-grant-A:path-mismatch",
                wrong_path_errors,
            )
            target = root / "grant-target.json"
            target.write_bytes(data)
            path.unlink()
            path.symlink_to(target)
            symlink_errors = validate_bound_launch_grant(
                root,
                schedule,
                contract,
                self.runner_contract,
                "A",
                relative,
                digest,
            )
            self.assertTrue(
                any("SYMLINK_COMPONENT" in error for error in symlink_errors)
            )

    def test_process_local_west_failure_cancels_nothing(self) -> None:
        failures = [
            {
                "jobId": "W-A",
                "direction": "west",
                "failureClass": "process_local",
            }
        ]
        self.assertEqual(validate_failure_isolation(failures, []), [])
        schedule, receipt = self.receipt(
            failures=failures,
            direction_outcome="fail",
        )
        errors = validate_execution_receipt(
            receipt,
            schedule,
            self.execution_contract,
        )
        self.assertEqual(errors, [])

    def test_cross_direction_cancellation_rejected(self) -> None:
        failures = [
            {
                "jobId": "W-A",
                "direction": "west",
                "failureClass": "direction_guard",
            }
        ]
        cancellations = [
            {
                "causedByJobId": "W-A",
                "direction": "east",
                "jobIds": ["E-B"],
            }
        ]
        errors = validate_failure_isolation(failures, cancellations)
        self.assertIn("failure-isolation:cross-direction", errors)
        self.assertIn("failure-isolation:foreign-job", errors)

    def test_immutable_retry_must_append_and_use_new_roots(self) -> None:
        schedule = self.schedule()
        retry = {
            "originalJobId": "W-A",
            "retryJobId": "W-A-r2",
            "failureClass": "scheduler_or_machine_infrastructure",
            "automatic": False,
            "newScheduleRevision": 2,
            "ordinal": 12,
            "roots": {
                "rawRoot": "docs/production/evidence/PLAY-081/industrial-l04-west-source-v02/process-A/raw",
                "semanticRoot": "docs/production/evidence/PLAY-081/industrial-l04-west-source-v02/process-A/semantic",
                "evidenceRoot": "docs/production/evidence/PLAY-081/industrial-l04-west-source-v02/process-A/evidence",
            },
        }
        self.assertEqual(
            validate_retries(
                [retry],
                schedule,
                self.execution_contract,
            ),
            [],
        )
        retry["ordinal"] = 11
        retry["roots"]["rawRoot"] = self.execution_contract["westProcesses"]["A"][
            "rawRoot"
        ]
        errors = validate_retries(
            [retry],
            schedule,
            self.execution_contract,
        )
        self.assertIn("retry:ordinal-not-appended", errors)
        self.assertIn("retry:root-reuse", errors)

    def test_content_failure_requires_new_direction_revision(self) -> None:
        schedule = self.schedule()
        retry = {
            "originalJobId": "W-A",
            "retryJobId": "W-A-r2",
            "failureClass": "candidate_content_or_determinism",
            "automatic": False,
            "newScheduleRevision": 2,
            "ordinal": 12,
            "roots": {
                "rawRoot": "new/raw",
                "semanticRoot": "new/semantic",
                "evidenceRoot": "new/evidence",
            },
        }
        self.assertIn(
            "retry:content-failure-requires-new-direction-revision",
            validate_retries([retry], schedule, self.execution_contract),
        )

    def test_receipt_dependency_groups_allow_concurrent_completion_order(self) -> None:
        writes = fixture_writes(self.execution_contract)
        writes[0], writes[1] = writes[1], writes[0]
        for sequence, write in enumerate(writes, start=1):
            write["sequence"] = sequence
        self.assertEqual(
            validate_receipt_order(
                writes,
                self.execution_contract,
                direction_outcome="pass",
            ),
            [],
        )

    def test_source_packet_before_direction_receipt_rejected(self) -> None:
        writes = fixture_writes(self.execution_contract)
        packet = writes.pop()
        writes.insert(-1, packet)
        for sequence, write in enumerate(writes, start=1):
            write["sequence"] = sequence
        self.assertIn(
            "receipt-order:dependency-order",
            validate_receipt_order(
                writes,
                self.execution_contract,
                direction_outcome="pass",
            ),
        )

    def test_safe_writer_is_no_follow_and_no_overwrite(self) -> None:
        contract = copy.deepcopy(self.execution_contract)
        identity = "sourceValidation"
        contract["receiptPaths"][identity] = (
            "docs/production/evidence/PLAY-081/test-only/receipt.json"
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            value = {"fixtureOnly": True}
            path = safe_write_receipt(
                root,
                contract,
                identity,
                value,
                emission_authorized=True,
            )
            self.assertTrue(path.is_file())
            with self.assertRaises(PathSafetyError):
                safe_write_receipt(
                    root,
                    contract,
                    identity,
                    value,
                    emission_authorized=True,
                )

    def test_safe_writer_rejects_symlink_component(self) -> None:
        contract = copy.deepcopy(self.execution_contract)
        identity = "sourceValidation"
        relative = "docs/production/evidence/PLAY-081/test-only/receipt.json"
        contract["receiptPaths"][identity] = relative
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            redirect = root / "redirect"
            redirect.mkdir()
            (root / "docs").symlink_to(redirect, target_is_directory=True)
            with self.assertRaises(PathSafetyError):
                safe_write_receipt(
                    root,
                    contract,
                    identity,
                    {"fixtureOnly": True},
                    emission_authorized=True,
                )
            self.assertEqual(list(redirect.iterdir()), [])

    def test_production_receipt_emission_disabled_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(OrchestrationError):
                safe_write_receipt(
                    Path(directory),
                    self.execution_contract,
                    "sourceValidation",
                    {"fixtureOnly": True},
                    emission_authorized=False,
                )

    def test_bounded_duration_sweep_preserves_mode_rules(self) -> None:
        parallel = self.schedule()
        sequential = self.schedule("sequential_exception")
        for prefix in product((1, 2), repeat=5):
            durations = list(prefix) + [1, 2, 1, 2, 1, 2]
            parallel_receipt = simulate_receipt(
                parallel,
                self.execution_contract,
                durations,
            )
            sequential_receipt = simulate_receipt(
                sequential,
                self.execution_contract,
                durations,
            )
            self.assertEqual(
                validate_execution_receipt(
                    parallel_receipt,
                    parallel,
                    self.execution_contract,
                ),
                [],
            )
            self.assertIn(
                "schedule:sequential-exception-not-dereferenced",
                validate_execution_receipt(
                    sequential_receipt,
                    sequential,
                    self.execution_contract,
                ),
            )


if __name__ == "__main__":
    unittest.main()
