#!/usr/bin/env python3
"""Focused zero-DCC tests for PLAY-081 West execution orchestration v2."""

from __future__ import annotations

import copy
from itertools import product
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from west_execution_orchestration_v2 import (
    DEFAULT_EXECUTION_CONTRACT,
    DEFAULT_RUNNER_CONTRACT,
    OrchestrationError,
    current_binding_errors,
    fixture_grant,
    fixture_schedule,
    fixture_writes,
    safe_write_receipt,
    simulate_receipt,
    static_contract_errors,
    validate_allocation,
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

    def test_current_inputs_fail_closed_before_dcc(self) -> None:
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
        self.assertIn("production-execution:disabled", errors)
        self.assertIn("production-receipt-emission:disabled", errors)

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
        self.assertEqual(validate_schedule(schedule, self.execution_contract), [])
        self.assertEqual(
            validate_execution_receipt(
                receipt,
                schedule,
                self.execution_contract,
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
            self.assertEqual(
                validate_execution_receipt(
                    sequential_receipt,
                    sequential,
                    self.execution_contract,
                ),
                [],
            )


if __name__ == "__main__":
    unittest.main()
