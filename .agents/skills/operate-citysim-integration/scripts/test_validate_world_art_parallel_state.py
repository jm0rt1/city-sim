#!/usr/bin/env python3
"""No-DCC tests for the World Art parallel control-plane validator."""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

import validate_world_art_parallel_state as validator


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n"
    ).encode("utf-8")


class StubValidator(validator.Validator):
    """Keep these tests independent of the developer's live worktrees."""

    def _git_snapshot(
        self, worktree: Path, location: str
    ) -> tuple[str, str, bool] | None:
        cell = worktree.name
        branch = validator.CELL_BINDINGS[cell][0]
        return branch, "a" * 40, True

    def _commit_resolves(self, sha: str) -> bool:
        return True

    def _commit_is_ancestor(self, ancestor: str, descendant: str) -> bool:
        return True

    def _commit_range_changes(
        self,
        ancestor: str,
        descendant: str,
    ) -> tuple[tuple[str, tuple[str, ...]], ...] | None:
        return (
            (
                descendant,
                ("docs/production/evidence/PLAY-027/receipt.json",),
            ),
        )


class NonAncestorStubValidator(StubValidator):
    def _commit_is_ancestor(self, ancestor: str, descendant: str) -> bool:
        return False


class ProductDeltaStubValidator(StubValidator):
    def _commit_range_changes(
        self,
        ancestor: str,
        descendant: str,
    ) -> tuple[tuple[str, tuple[str, ...]], ...] | None:
        return (
            (
                "c" * 40,
                (
                    "Native/CitySimNative/Sources/CitySimNative/Rendering/"
                    "CityScene.swift",
                ),
            ),
            (
                descendant,
                ("docs/production/evidence/PLAY-027/receipt.json",),
            ),
        )


class ParallelStateFixture:
    def __init__(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name).resolve()
        self.ledger_path = self.repo / "ledger.json"
        self.board_path = self.repo / "board.md"
        self.receipt_path = self.repo / "receipt.json"

        claim_revisions: dict[str, str] = {}
        for cell, (_, _, claim_path) in validator.CELL_BINDINGS.items():
            content = f"{cell} governed claim\n".encode()
            absolute = self.repo / claim_path
            absolute.parent.mkdir(parents=True, exist_ok=True)
            absolute.write_bytes(content)
            claim_revisions[cell] = hashlib.sha256(content).hexdigest()

        family = self._authority("docs/family.md", b"family\n")
        self.family_authority = {
            "path": family[0],
            "sha256": family[1],
        }
        parallel = self._authority("docs/parallel.md", b"parallel\n")
        semantic = self._authority("tools/semantic.py", b"semantic\n")
        receipt_schema = self._authority("schemas/admission.json", b"schema\n")
        receipt_validator = self._authority("tools/admission.py", b"validator\n")

        states = {
            "north": "predesign",
            "east": "predesign",
            "south": "predesign",
            "west": "predesign",
            "renderer": "intake_preparing",
            "qa": "preregistering",
        }
        rows = []
        for cell in validator.EXPECTED_CELLS:
            branch, claim, _ = validator.CELL_BINDINGS[cell]
            worktree = str(self.repo / "worktrees" / cell)
            rows.append(
                {
                    "batch": "industrial_l04_directional_family",
                    "lane": validator.LANE_BINDINGS[cell],
                    "direction": cell,
                    "threadId": f"thread-{cell}",
                    "branch": branch,
                    "worktree": worktree,
                    "claim": claim,
                    "publishedBase": "a" * 40,
                    "head": "a" * 40,
                    "state": states[cell],
                    "dispatchState": "completed",
                    "acknowledgedAt": "2026-07-30T03:00:00Z",
                    "claimRevision": claim_revisions[cell],
                    "cleanState": "clean",
                    "blocker": "stage authority is intentionally closed",
                    "nextAction": "resume when Integration publishes the next stage",
                    "boundedDeliverable": "one exact bounded preparation packet",
                    "stopCondition": "stop before any unapproved shared mutation",
                    "updatedAt": "2026-07-30T04:00:00Z",
                    "executionAccounting": {
                        "readyNow": [],
                        "running": [],
                        "waitingOnJoin": [],
                        "serializedAuthority": {
                            "threadId": f"thread-{cell}",
                            "branch": branch,
                            "worktree": worktree,
                            "gitIndexWriter": f"thread-{cell}",
                            "governedEvidenceWriter": f"thread-{cell}",
                        },
                        "nextRefill": "resume when Integration publishes the next stage",
                        "capacity": {
                            "helperSlots": 0,
                            "dccSlots": 0,
                        },
                        "launchedJobs": [],
                        "unusedCapacityReasons": [],
                        "overlap": {
                            "status": "not_applicable",
                            "jobIds": [],
                            "startedAt": None,
                            "endedAt": None,
                            "reason": "no concurrent work was authorized",
                        },
                        "join": {
                            "state": "no_join_required",
                            "requiredJobs": [],
                            "completedJobs": [],
                        },
                    },
                    "parallelismExemption": {
                        "reasonCode": "stage_prohibited_by_authority",
                        "stageProhibition": {
                            "batchState": "prelock_active",
                            "rule": "this fixture row has no remaining prelock work",
                        },
                        "owner": {
                            "role": "cell",
                            "id": f"thread-{cell}",
                        },
                        "dependencyAuthority": copy.deepcopy(
                            self.family_authority
                        ),
                        "resumptionEvent": (
                            "Integration publishes the next stage authority"
                        ),
                        "nextRefillJob": (
                            "resume when Integration publishes the next stage"
                        ),
                    },
                }
            )

        self.ledger = {
            "schema": 3,
            "batch": "industrial_l04_directional_family",
            "updatedAt": "2026-07-30T04:00:00Z",
            "lastDispatchReceipt": str(self.receipt_path),
            "stateMachine": list(validator.BATCH_STATE_MACHINE),
            "directionStateMachine": {
                key: list(value)
                for key, value in validator.DIRECTION_STATE_MACHINE.items()
            },
            "rendererStateMachine": list(validator.RENDERER_STATE_MACHINE),
            "qaStateMachine": list(validator.QA_STATE_MACHINE),
            "batchState": "prelock_active",
            "familyAuthority": {
                "familyContract": {
                    "path": family[0],
                    "sha256": family[1],
                    "status": "published",
                },
                "parallelCellsContract": {
                    "path": parallel[0],
                    "sha256": parallel[1],
                    "status": "published",
                },
                "appearanceLock": {
                    "path": None,
                    "sha256": None,
                    "status": "pending",
                },
                "sourceProductionProfile": {
                    "path": None,
                    "sha256": None,
                    "status": "pending",
                },
                "parallelExecutionSchedule": {
                    "path": None,
                    "sha256": None,
                    "schemaPath": None,
                    "schemaSha256": None,
                    "validatorPath": None,
                    "validatorSha256": None,
                    "status": "pending",
                },
                "semanticValidator": {
                    "path": semantic[0],
                    "sha256": semantic[1],
                    "status": "published",
                },
                "sourceAdmissionReceipt": {
                    "schemaPath": receipt_schema[0],
                    "schemaSha256": receipt_schema[1],
                    "validatorPath": receipt_validator[0],
                    "validatorSha256": receipt_validator[1],
                    "authorityCommit": "a" * 40,
                    "status": "published",
                },
            },
            "cells": rows,
        }
        self.receipt = {
            "schema": 4,
            "batch": self.ledger["batch"],
            "sentAt": "2026-07-30T04:00:00Z",
            "authorityCommit": "a" * 40,
            "ledger": str(self.ledger_path),
            "computeEnvelope": {
                "maximumSimultaneousDCCProcesses": 0,
                "assignedSlots": [],
                "queueOrder": [],
                "resourceAssumptions": {
                    "machine": "single local macOS host",
                    "dcc": "no DCC process before appearance lock",
                    "rendererHarness": "CPU-only synthetic harness",
                    "qa": "independent preregistration only",
                },
                "prohibited": ["all DCC work before appearance lock"],
                "exceptionOwner": "integration",
                "reason": "the family remains in zero-pixel prelock preparation",
            },
            "rows": [],
        }
        for row in rows:
            projected = copy.deepcopy(row)
            projected["base"] = projected.pop("publishedBase")
            projected["changedThisTurn"] = False
            self.receipt["rows"].append(projected)
        self.refresh_hash()
        self.board = self._board(rows)

    def _authority(self, relative: str, content: bytes) -> tuple[str, str]:
        target = self.repo / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        return relative, hashlib.sha256(content).hexdigest()

    def refresh_hash(self) -> None:
        self.ledger_bytes = canonical_bytes(self.ledger)
        self.receipt["ledgerSha256"] = hashlib.sha256(
            self.ledger_bytes
        ).hexdigest()

    def unused_capacity_reason(
        self,
        row: dict[str, object],
        *,
        resource: str = "helper",
        reason_code: str = "completed_before_observation",
    ) -> dict[str, object]:
        return {
            "resourceClass": resource,
            "slots": 1,
            "reasonCode": reason_code,
            "owner": row["threadId"],
            "dependencyAuthority": copy.deepcopy(self.family_authority),
            "resumptionEvent": "the next bounded job becomes ready",
            "nextRefillJob": row["executionAccounting"]["nextRefill"],
        }

    def activate_cells(
        self,
        cells: tuple[str, ...],
        *,
        starts: tuple[str, ...],
    ) -> None:
        for collection in (
            self.ledger["cells"],
            self.receipt["rows"],
        ):
            by_cell = {row["direction"]: row for row in collection}
            for cell, started_at in zip(cells, starts, strict=True):
                row = by_cell[cell]
                row.pop("parallelismExemption", None)
                row["dispatchState"] = "working"
                row["authorityAcknowledgement"] = {
                    "threadId": row["threadId"],
                    "authorityCommit": "a" * 40,
                    "claimRevision": row["claimRevision"],
                    "acknowledgedAt": row["acknowledgedAt"],
                    "evidenceId": (
                        f"thread:{row['threadId']}/turn:parallel-turn/"
                        f"item:{cell}-active-item"
                    ),
                    "boundedDeliverable": row["boundedDeliverable"],
                    "stopCondition": row["stopCondition"],
                }
                accounting = row["executionAccounting"]
                job_id = f"{cell}-parallel-job"
                accounting["capacity"]["helperSlots"] = 1
                accounting["running"] = [job_id]
                accounting["launchedJobs"] = [
                    self.job(
                        row,
                        job_id,
                        state="running",
                        started_at=started_at,
                        ended_at=None,
                    )
                ]
        proof = {
            "requiredConcurrentCells": min(3, len(cells)),
            "eligibleCells": list(cells),
            "jobRefs": [
                {"cell": cell, "jobId": f"{cell}-parallel-job"}
                for cell in cells
            ],
            "startedAt": max(starts),
            "endedAt": "2026-07-30T04:00:00Z",
        }
        self.ledger["parallelismProof"] = proof
        self.receipt["parallelismProof"] = copy.deepcopy(proof)

    @staticmethod
    def job(
        row: dict[str, object],
        job_id: str,
        *,
        state: str = "completed",
        resource: str = "helper",
        started_at: str = "2026-07-30T04:00:00Z",
        ended_at: str | None = "2026-07-30T04:01:00Z",
    ) -> dict[str, object]:
        return {
            "id": job_id,
            "batch": row["batch"],
            "claim": row["claim"],
            "claimRevision": row["claimRevision"],
            "publishedBase": row.get("publishedBase", row.get("base")),
            "head": row.get("observedHead", row["head"]),
            "threadId": row["threadId"],
            "branch": row["branch"],
            "worktree": row["worktree"],
            "resourceClass": resource,
            "mutation": "read_only",
            "exclusiveRoot": None,
            "state": state,
            "startedAt": started_at,
            "endedAt": ended_at,
            "evidenceId": (
                f"thread:{row['threadId']}/turn:fixture-turn/item:{job_id}"
            ),
            "dccSlot": None,
            "processId": None,
        }

    @staticmethod
    def _board(rows: list[dict[str, object]]) -> str:
        lines = [
            "| Cell | Branch / claim | Current state | Head |",
            "|---|---|---|---|",
        ]
        for row in rows:
            lines.append(
                f"| {str(row['direction']).title()} | "
                f"{row['branch']} / {row['claim']} | {row['state']} | "
                f"{row['head']} |"
            )
        return "\n".join(lines) + "\n"

    def diagnostics(
        self,
        validator_type: type[validator.Validator] = StubValidator,
    ) -> list[validator.Diagnostic]:
        subject = validator_type(self.repo)
        subject.validate(
            self.ledger,
            self.ledger_path,
            self.ledger_bytes,
            self.board,
            self.board_path,
            self.receipt,
            self.receipt_path,
        )
        return sorted(subject.diagnostics)

    def codes(
        self,
        validator_type: type[validator.Validator] = StubValidator,
    ) -> set[str]:
        return {item.code for item in self.diagnostics(validator_type)}

    def close(self) -> None:
        self.temp.cleanup()


class ParallelStateValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = ParallelStateFixture()

    def tearDown(self) -> None:
        self.fixture.close()

    def test_valid_control_plane_passes(self) -> None:
        self.assertEqual(self.fixture.diagnostics(), [])

    def test_valid_completed_parallel_jobs_pass(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 2
            accounting["unusedCapacityReasons"] = [
                self.fixture.unused_capacity_reason(row),
                self.fixture.unused_capacity_reason(row),
            ]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "first-helper-job",
                    started_at="2026-07-30T03:50:00Z",
                    ended_at="2026-07-30T03:58:00Z",
                ),
                self.fixture.job(
                    row,
                    "second-helper-job",
                    started_at="2026-07-30T03:55:00Z",
                    ended_at="2026-07-30T03:59:00Z",
                ),
            ]
            accounting["overlap"] = {
                "status": "observed",
                "jobIds": ["first-helper-job", "second-helper-job"],
                "startedAt": "2026-07-30T03:55:00Z",
                "endedAt": "2026-07-30T03:58:00Z",
                "reason": "bound job intervals overlap",
            }
        self.fixture.refresh_hash()
        self.assertEqual(self.fixture.diagnostics(), [])

    def test_valid_active_running_job_passes(self) -> None:
        self.fixture.activate_cells(
            ("north",),
            starts=("2026-07-30T03:59:00Z",),
        )
        self.fixture.refresh_hash()
        self.assertEqual(self.fixture.diagnostics(), [])

    def test_valid_two_cell_minimum_useful_concurrency_passes(self) -> None:
        self.fixture.activate_cells(
            ("north", "east"),
            starts=(
                "2026-07-30T03:58:00Z",
                "2026-07-30T03:59:00Z",
            ),
        )
        self.fixture.refresh_hash()
        self.assertEqual(self.fixture.diagnostics(), [])

    def test_two_eligible_cells_require_two_active_cells(self) -> None:
        self.fixture.activate_cells(
            ("north",),
            starts=("2026-07-30T03:59:00Z",),
        )
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            by_cell = {row["direction"]: row for row in collection}
            by_cell["east"].pop("parallelismExemption")
        self.fixture.refresh_hash()
        self.assertIn("PARALLELISM_ACTIVE_FLOOR", self.fixture.codes())

    def test_valid_three_cell_cross_row_parallelism_proof_passes(self) -> None:
        self.fixture.activate_cells(
            ("north", "east", "south"),
            starts=(
                "2026-07-30T03:50:00Z",
                "2026-07-30T03:51:00Z",
                "2026-07-30T03:52:00Z",
            ),
        )
        self.fixture.refresh_hash()
        self.assertEqual(self.fixture.diagnostics(), [])

    def test_valid_completed_parallel_epoch_remains_proven(self) -> None:
        cells = ("north", "east", "south")
        starts = (
            "2026-07-30T03:50:00Z",
            "2026-07-30T03:51:00Z",
            "2026-07-30T03:52:00Z",
        )
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            by_cell = {row["direction"]: row for row in collection}
            for cell, started_at in zip(cells, starts, strict=True):
                row = by_cell[cell]
                accounting = row["executionAccounting"]
                accounting["capacity"]["helperSlots"] = 1
                accounting["launchedJobs"] = [
                    self.fixture.job(
                        row,
                        f"{cell}-completed-epoch-job",
                        started_at=started_at,
                        ended_at="2026-07-30T03:59:00Z",
                    )
                ]
                accounting["unusedCapacityReasons"] = [
                    self.fixture.unused_capacity_reason(row)
                ]
        proof = {
            "requiredConcurrentCells": 3,
            "eligibleCells": list(cells),
            "jobRefs": [
                {"cell": cell, "jobId": f"{cell}-completed-epoch-job"}
                for cell in cells
            ],
            "startedAt": "2026-07-30T03:52:00Z",
            "endedAt": "2026-07-30T03:59:00Z",
        }
        self.fixture.ledger["parallelismProof"] = proof
        self.fixture.receipt["parallelismProof"] = copy.deepcopy(proof)
        self.fixture.refresh_hash()
        self.assertEqual(self.fixture.diagnostics(), [])

    def test_three_eligible_rows_require_three_active_acknowledged_rows(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            for row in collection[:3]:
                row.pop("parallelismExemption")
        self.fixture.refresh_hash()
        codes = self.fixture.codes()
        self.assertIn("PARALLELISM_ACTIVE_FLOOR", codes)
        self.assertIn("PARALLELISM_PROOF_MISSING", codes)

    def test_free_text_exemption_cannot_hide_eligible_row(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            for row in collection[:3]:
                row["parallelismExemption"] = {
                    "reason": "waiting for North",
                }
        self.fixture.refresh_hash()
        codes = self.fixture.codes()
        self.assertIn("PARALLELISM_EXEMPTION_FIELDS", codes)
        self.assertIn("PARALLELISM_ACTIVE_FLOOR", codes)

    def test_six_sequential_cross_cell_jobs_do_not_prove_parallelism(self) -> None:
        cells = validator.EXPECTED_CELLS
        intervals = (
            ("2026-07-30T03:00:00Z", "2026-07-30T03:05:00Z"),
            ("2026-07-30T03:05:00Z", "2026-07-30T03:10:00Z"),
            ("2026-07-30T03:10:00Z", "2026-07-30T03:15:00Z"),
            ("2026-07-30T03:15:00Z", "2026-07-30T03:20:00Z"),
            ("2026-07-30T03:20:00Z", "2026-07-30T03:25:00Z"),
            ("2026-07-30T03:25:00Z", "2026-07-30T03:30:00Z"),
        )
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            by_cell = {row["direction"]: row for row in collection}
            for cell, (started_at, ended_at) in zip(
                cells, intervals, strict=True
            ):
                row = by_cell[cell]
                row.pop("parallelismExemption")
                accounting = row["executionAccounting"]
                accounting["capacity"]["helperSlots"] = 1
                accounting["launchedJobs"] = [
                    self.fixture.job(
                        row,
                        f"{cell}-sequential-job",
                        started_at=started_at,
                        ended_at=ended_at,
                    )
                ]
                accounting["unusedCapacityReasons"] = [
                    self.fixture.unused_capacity_reason(row)
                ]
        proof = {
            "requiredConcurrentCells": 3,
            "eligibleCells": list(cells),
            "jobRefs": [
                {"cell": cell, "jobId": f"{cell}-sequential-job"}
                for cell in cells
            ],
            "startedAt": "2026-07-30T03:25:00Z",
            "endedAt": "2026-07-30T03:05:00Z",
        }
        self.fixture.ledger["parallelismProof"] = proof
        self.fixture.receipt["parallelismProof"] = copy.deepcopy(proof)
        self.fixture.refresh_hash()
        self.assertIn(
            "PARALLELISM_PROOF_INTERVAL_EMPTY",
            self.fixture.codes(),
        )

    def test_free_text_only_unused_capacity_reason_is_rejected(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            accounting = collection[0]["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "waiting for somebody",
                }
            ]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_UNUSED_CAPACITY_FIELDS",
            self.fixture.codes(),
        )

    def test_unused_capacity_authority_hash_must_be_current(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            reason = self.fixture.unused_capacity_reason(row)
            reason["dependencyAuthority"]["sha256"] = "f" * 64
            accounting["unusedCapacityReasons"] = [reason]
        self.fixture.refresh_hash()
        self.assertIn("AUTHORITY_HASH_STALE", self.fixture.codes())

    def test_wrong_direction_branch_is_rejected(self) -> None:
        self.fixture.ledger["cells"][1]["branch"] = (
            "codex/citysim-world-art-south"
        )
        self.fixture.receipt["rows"][1]["branch"] = (
            "codex/citysim-world-art-south"
        )
        self.fixture.refresh_hash()
        self.assertIn("CELL_BRANCH_BINDING", self.fixture.codes())

    def test_stale_claim_hash_is_rejected(self) -> None:
        self.fixture.ledger["cells"][0]["claimRevision"] = "f" * 64
        self.fixture.receipt["rows"][0]["claimRevision"] = "f" * 64
        self.fixture.refresh_hash()
        self.assertIn("CLAIM_REVISION_STALE", self.fixture.codes())

    def test_illegal_direction_state_is_rejected(self) -> None:
        self.fixture.ledger["cells"][0]["state"] = "source_ready"
        self.fixture.receipt["rows"][0]["state"] = "source_ready"
        self.fixture.board = self.fixture._board(self.fixture.ledger["cells"])
        self.fixture.refresh_hash()
        self.assertIn("DIRECTION_STATE_INVALID", self.fixture.codes())

    def test_4of4_requires_every_direction_quarantined(self) -> None:
        self.fixture.ledger["batchState"] = "4of4_ready"
        self.fixture.refresh_hash()
        self.assertIn("BATCH_4OF4_PRECONDITION", self.fixture.codes())

    def test_stale_authority_hash_is_rejected(self) -> None:
        self.fixture.ledger["familyAuthority"]["familyContract"][
            "sha256"
        ] = "f" * 64
        self.fixture.refresh_hash()
        self.assertIn("AUTHORITY_HASH_STALE", self.fixture.codes())

    def test_empty_required_authority_is_rejected(self) -> None:
        self.fixture.ledger["familyAuthority"]["familyContract"] = {}
        self.fixture.refresh_hash()
        codes = self.fixture.codes()
        self.assertIn("AUTHORITY_STATUS_MISSING", codes)

    def test_family_contract_requires_document_path_pair(self) -> None:
        family = self.fixture.ledger["familyAuthority"]["familyContract"]
        self.fixture.ledger["familyAuthority"]["familyContract"] = {
            "schemaPath": family["path"],
            "schemaSha256": family["sha256"],
            "status": "published",
        }
        self.fixture.refresh_hash()
        self.assertIn("AUTHORITY_BINDING_MISSING", self.fixture.codes())

    def test_admission_authority_requires_schema_and_validator_pairs(self) -> None:
        admission = self.fixture.ledger["familyAuthority"][
            "sourceAdmissionReceipt"
        ]
        del admission["validatorPath"]
        del admission["validatorSha256"]
        self.fixture.refresh_hash()
        self.assertIn("AUTHORITY_BINDING_MISSING", self.fixture.codes())

    def test_pending_authority_cannot_bind_concrete_file(self) -> None:
        self.fixture.ledger["familyAuthority"]["appearanceLock"] = {
            "path": "docs/family.md",
            "sha256": self.fixture.ledger["familyAuthority"]["familyContract"][
                "sha256"
            ],
            "status": "pending",
        }
        self.fixture.refresh_hash()
        self.assertIn("AUTHORITY_PENDING_CONCRETE", self.fixture.codes())

    def test_dispatch_must_project_every_ledger_field(self) -> None:
        self.fixture.receipt["rows"][0]["nextAction"] = "different next action"
        self.assertIn("RECEIPT_LEDGER_ROW_MISMATCH", self.fixture.codes())

    def test_dispatch_requires_exact_ledger_hash(self) -> None:
        del self.fixture.receipt["ledgerSha256"]
        self.assertIn("RECEIPT_LEDGER_HASH_MISSING", self.fixture.codes())

    def test_active_row_requires_exact_acknowledgement_evidence(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            collection[0]["dispatchState"] = "working"
        self.fixture.refresh_hash()
        self.assertIn("ACTIVE_ACK_EVIDENCE_MISSING", self.fixture.codes())

    def test_active_acknowledgement_requires_exact_thread_item_evidence(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["dispatchState"] = "working"
            row["authorityAcknowledgement"] = {
                "threadId": row["threadId"],
                "authorityCommit": "a" * 40,
                "claimRevision": row["claimRevision"],
                "acknowledgedAt": row["acknowledgedAt"],
                "evidenceId": "fabricated acknowledgement evidence",
                "boundedDeliverable": row["boundedDeliverable"],
                "stopCondition": row["stopCondition"],
            }
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["running"] = ["active-helper-job"]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "active-helper-job",
                    state="running",
                    started_at="2026-07-30T03:59:00Z",
                    ended_at=None,
                )
            ]
        self.fixture.refresh_hash()
        self.assertIn("ACTIVE_ACK_EVIDENCE_INVALID", self.fixture.codes())

    def test_active_acknowledgement_binds_receipt_authority_commit(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["dispatchState"] = "working"
            row["authorityAcknowledgement"] = {
                "threadId": row["threadId"],
                "authorityCommit": "b" * 40,
                "claimRevision": row["claimRevision"],
                "acknowledgedAt": row["acknowledgedAt"],
                "evidenceId": (
                    f"thread:{row['threadId']}/turn:active-turn/item:active-item"
                ),
                "boundedDeliverable": row["boundedDeliverable"],
                "stopCondition": row["stopCondition"],
            }
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["running"] = ["active-helper-job"]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "active-helper-job",
                    state="running",
                    started_at="2026-07-30T03:59:00Z",
                    ended_at=None,
                )
            ]
        self.fixture.refresh_hash()
        self.assertIn(
            "ACTIVE_ACK_AUTHORITY_COMMIT_MISMATCH",
            self.fixture.codes(),
        )

    def test_row_requires_execution_accounting(self) -> None:
        del self.fixture.ledger["cells"][0]["executionAccounting"]
        del self.fixture.receipt["rows"][0]["executionAccounting"]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_ACCOUNTING_MISSING", self.fixture.codes())

    def test_active_row_requires_running_job_and_unused_capacity_reason(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["dispatchState"] = "working"
            row["executionAccounting"]["capacity"]["helperSlots"] = 2
            row["executionAccounting"]["unusedCapacityReasons"] = []
        self.fixture.refresh_hash()
        codes = self.fixture.codes()
        self.assertIn("ACTIVE_EXECUTION_NOT_RUNNING", codes)
        self.assertIn("EXECUTION_UNUSED_CAPACITY_MISMATCH", codes)

    def test_observed_overlap_requires_two_launched_jobs_and_timestamps(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["launchedJobs"] = [
                self.fixture.job(row, "only-job")
            ]
            accounting["overlap"] = {
                "status": "observed",
                "jobIds": ["only-job"],
                "startedAt": None,
                "endedAt": None,
                "reason": "claimed overlap without a second process",
            }
        self.fixture.refresh_hash()
        codes = self.fixture.codes()
        self.assertIn("EXECUTION_OVERLAP_INSUFFICIENT_JOBS", codes)
        self.assertIn("TIMESTAMP_MISSING", codes)

    def test_waiting_join_must_match_exact_remaining_jobs(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["launchedJobs"] = [
                self.fixture.job(row, "first-job"),
                self.fixture.job(row, "second-job"),
            ]
            accounting["waitingOnJoin"] = ["second-job"]
            accounting["join"] = {
                "state": "waiting",
                "requiredJobs": ["first-job", "second-job"],
                "completedJobs": [],
            }
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_JOIN_WAIT_SET_MISMATCH", self.fixture.codes())

    def test_running_job_must_be_launched_and_fit_capacity(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["dispatchState"] = "working"
            accounting = row["executionAccounting"]
            accounting["running"] = ["never-launched-job"]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_UNKNOWN_JOB", self.fixture.codes())

    def test_completed_job_interval_requires_historical_capacity(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["executionAccounting"]["launchedJobs"] = [
                self.fixture.job(row, "completed-helper")
            ]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_HISTORICAL_CAPACITY_EXCEEDED",
            self.fixture.codes(),
        )

    def test_job_must_bind_exact_batch_and_visible_owner(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            job = self.fixture.job(row, "wrong-batch")
            job["batch"] = "PLAY-999-other-batch"
            row["executionAccounting"]["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_JOB_BINDING_MISMATCH", self.fixture.codes())

    def test_observed_head_preserves_job_snapshot_while_live_head_advances(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["observedHead"] = "b" * 40
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                self.fixture.unused_capacity_reason(row)
            ]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "observed-snapshot-job",
                    started_at="2026-07-30T03:50:00Z",
                    ended_at="2026-07-30T03:59:00Z",
                )
            ]
            accounting["join"] = {
                "state": "joined",
                "requiredJobs": ["observed-snapshot-job"],
                "completedJobs": ["observed-snapshot-job"],
            }
        self.fixture.refresh_hash()
        self.assertEqual(self.fixture.diagnostics(), [])

    def test_observed_head_job_cannot_claim_live_receipt_head(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["observedHead"] = "b" * 40
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                self.fixture.unused_capacity_reason(row)
            ]
            job = self.fixture.job(row, "forged-live-head-job")
            job["head"] = row["head"]
            accounting["launchedJobs"] = [job]
            accounting["join"] = {
                "state": "joined",
                "requiredJobs": ["forged-live-head-job"],
                "completedJobs": ["forged-live-head-job"],
            }
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_JOB_BINDING_MISMATCH", self.fixture.codes())

    def test_observed_head_must_be_ancestral(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["observedHead"] = "b" * 40
            accounting = row["executionAccounting"]
            accounting["launchedJobs"] = [
                self.fixture.job(row, "nonancestral-job")
            ]
        self.fixture.refresh_hash()
        self.assertIn(
            "GIT_OBSERVED_HEAD_NOT_ANCESTOR",
            self.fixture.codes(NonAncestorStubValidator),
        )

    def test_observed_head_range_must_be_claim_owned_evidence_only(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["observedHead"] = "b" * 40
            accounting = row["executionAccounting"]
            accounting["launchedJobs"] = [
                self.fixture.job(row, "product-delta-job")
            ]
        self.fixture.refresh_hash()
        self.assertIn(
            "GIT_OBSERVED_HEAD_NON_EVIDENCE_DELTA",
            self.fixture.codes(ProductDeltaStubValidator),
        )

    def test_observed_head_rejects_product_change_hidden_by_revert(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary).resolve()

            def git(*arguments: str) -> str:
                result = subprocess.run(
                    ["git", "-C", str(repo), *arguments],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                return result.stdout.strip()

            git("init", "-q")
            git("config", "user.name", "CitySim Test")
            git("config", "user.email", "citysim-test@example.invalid")

            product = (
                repo
                / "Native/CitySimNative/Sources/CitySimNative/Rendering/"
                "CityScene.swift"
            )
            product.parent.mkdir(parents=True)
            product.write_text("base\n", encoding="utf-8")
            git("add", str(product.relative_to(repo)))
            git("commit", "-q", "-m", "base")
            observed = git("rev-parse", "HEAD")

            product.write_text("hidden product mutation\n", encoding="utf-8")
            git("add", str(product.relative_to(repo)))
            git("commit", "-q", "-m", "mutate product")

            product.write_text("base\n", encoding="utf-8")
            git("add", str(product.relative_to(repo)))
            git("commit", "-q", "-m", "revert product")

            receipt = (
                repo
                / "docs/production/evidence/PLAY-027/"
                "execution-receipt.json"
            )
            receipt.parent.mkdir(parents=True)
            receipt.write_text("{}\n", encoding="utf-8")
            git("add", str(receipt.relative_to(repo)))
            git("commit", "-q", "-m", "record receipt")
            head = git("rev-parse", "HEAD")

            subject = validator.Validator(repo)
            subject._validate_observed_head_binding(
                {
                    "claim": "PLAY-027",
                    "observedHead": observed,
                    "head": head,
                    "executionAccounting": {
                        "launchedJobs": [{"id": "observed-job"}],
                    },
                },
                "row",
            )
            self.assertIn(
                "GIT_OBSERVED_HEAD_NON_EVIDENCE_DELTA",
                {diagnostic.code for diagnostic in subject.diagnostics},
            )

    def test_observed_head_rejects_empty_receipt_commit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary).resolve()

            def git(*arguments: str) -> str:
                result = subprocess.run(
                    ["git", "-C", str(repo), *arguments],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                return result.stdout.strip()

            git("init", "-q")
            git("config", "user.name", "CitySim Test")
            git("config", "user.email", "citysim-test@example.invalid")

            receipt = (
                repo
                / "docs/production/evidence/PLAY-027/"
                "execution-receipt.json"
            )
            receipt.parent.mkdir(parents=True)
            receipt.write_text("{}\n", encoding="utf-8")
            git("add", str(receipt.relative_to(repo)))
            git("commit", "-q", "-m", "base evidence")
            observed = git("rev-parse", "HEAD")

            git("commit", "--allow-empty", "-q", "-m", "empty receipt")
            head = git("rev-parse", "HEAD")

            subject = validator.Validator(repo)
            subject._validate_observed_head_binding(
                {
                    "claim": "PLAY-027",
                    "observedHead": observed,
                    "head": head,
                    "executionAccounting": {
                        "launchedJobs": [{"id": "observed-job"}],
                    },
                },
                "row",
            )
            self.assertIn(
                "GIT_OBSERVED_HEAD_EMPTY_RANGE",
                {diagnostic.code for diagnostic in subject.diagnostics},
            )

    def test_job_evidence_must_bind_exact_visible_thread_item(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            job = self.fixture.job(row, "unbound-evidence")
            job["evidenceId"] = "some prose says it ran"
            row["executionAccounting"]["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_JOB_EVIDENCE_INVALID", self.fixture.codes())

    def test_unresolvable_artifact_hash_is_not_job_evidence(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            job = self.fixture.job(row, "unresolved-artifact")
            job["evidenceId"] = "artifact-sha256:" + "0" * 64
            row["executionAccounting"]["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_JOB_EVIDENCE_INVALID", self.fixture.codes())

    def test_thread_evidence_requires_exact_nonempty_turn_and_item(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            job = self.fixture.job(row, "forged-thread-evidence")
            job["evidenceId"] = (
                f"thread:{row['threadId']}/turn:/item:/forged:tail"
            )
            row["executionAccounting"]["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_JOB_EVIDENCE_INVALID", self.fixture.codes())

    def test_thread_evidence_rejects_whitespace_and_control_ids(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            job = self.fixture.job(row, "whitespace-evidence")
            job["evidenceId"] = (
                f"thread:{row['threadId']}/turn:        /item:        "
            )
            row["executionAccounting"]["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_JOB_EVIDENCE_INVALID", self.fixture.codes())

    def test_serialized_writer_must_match_visible_thread(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            collection[0]["executionAccounting"]["serializedAuthority"][
                "gitIndexWriter"
            ] = "unbound-shared-writer"
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_SERIALIZED_AUTHORITY_MISMATCH",
            self.fixture.codes(),
        )

    def test_overlap_is_derived_from_job_intervals(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "first-job",
                    started_at="2026-07-30T06:00:00Z",
                    ended_at="2026-07-30T06:10:00Z",
                ),
                self.fixture.job(
                    row,
                    "second-job",
                    started_at="2026-07-30T07:00:00Z",
                    ended_at="2026-07-30T07:10:00Z",
                ),
            ]
            accounting["overlap"] = {
                "status": "observed",
                "jobIds": ["first-job", "second-job"],
                "startedAt": "2026-07-30T07:00:00Z",
                "endedAt": "2026-07-30T06:10:00Z",
                "reason": "fabricated reverse interval",
            }
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_OVERLAP_NOT_OBSERVED", self.fixture.codes())

    def test_overlap_requires_complete_peak_job_set(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 3
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": f"helper {index} completed before observation",
                }
                for index in range(3)
            ]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    f"overlap-helper-{index}",
                    started_at="2026-07-30T03:50:00Z",
                    ended_at="2026-07-30T03:59:00Z",
                )
                for index in range(3)
            ]
            accounting["overlap"] = {
                "status": "observed",
                "jobIds": ["overlap-helper-0", "overlap-helper-1"],
                "startedAt": "2026-07-30T03:50:00Z",
                "endedAt": "2026-07-30T03:59:00Z",
                "reason": "third overlapping job was omitted",
            }
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_OVERLAP_JOB_SET_INCOMPLETE",
            self.fixture.codes(),
        )

    def test_real_overlap_cannot_be_omitted(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 2
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 2,
                    "reason": "both completed before the snapshot",
                }
            ]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "first-job",
                    started_at="2026-07-30T06:00:00Z",
                    ended_at="2026-07-30T06:10:00Z",
                ),
                self.fixture.job(
                    row,
                    "second-job",
                    started_at="2026-07-30T06:05:00Z",
                    ended_at="2026-07-30T06:15:00Z",
                ),
            ]
            accounting["overlap"] = {
                "status": "none",
                "jobIds": [],
                "startedAt": None,
                "endedAt": None,
                "reason": "falsely omitted overlap",
            }
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_OVERLAP_OMITTED", self.fixture.codes())

    def test_unused_capacity_is_accounted_by_resource_and_slot_count(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            accounting = collection[0]["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 3
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "only one generic reason",
                }
            ]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_UNUSED_CAPACITY_MISMATCH", self.fixture.codes())

    def test_dcc_capacity_must_match_compute_envelope(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            collection[0]["executionAccounting"]["capacity"]["dccSlots"] = 1
            collection[0]["executionAccounting"]["unusedCapacityReasons"] = [
                {
                    "resourceClass": "dcc",
                    "slots": 1,
                    "reason": "claimed but unassigned",
                }
            ]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_DCC_CAPACITY_ENVELOPE_MISMATCH",
            self.fixture.codes(),
        )

    def test_running_jobs_cannot_fabricate_completed_overlap(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["dispatchState"] = "working"
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 2
            accounting["running"] = ["first-running", "second-running"]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "first-running",
                    state="running",
                    started_at="2026-07-30T03:58:00Z",
                    ended_at=None,
                ),
                self.fixture.job(
                    row,
                    "second-running",
                    state="running",
                    started_at="2026-07-30T03:59:00Z",
                    ended_at=None,
                ),
            ]
            accounting["overlap"] = {
                "status": "observed",
                "jobIds": ["first-running", "second-running"],
                "startedAt": "2026-07-30T04:00:00Z",
                "endedAt": "2026-07-30T03:59:30Z",
                "reason": "fabricated running overlap",
            }
        self.fixture.refresh_hash()
        codes = self.fixture.codes()
        self.assertIn("EXECUTION_OVERLAP_JOB_INCOMPLETE", codes)
        self.assertIn("EXECUTION_OVERLAP_TIME_REVERSED", codes)

    def test_identical_cross_row_temp_roots_are_rejected(self) -> None:
        shared_root = str(self.fixture.repo / "outside" / "shared")
        for row_index in (0, 1):
            for collection in (
                self.fixture.ledger["cells"],
                self.fixture.receipt["rows"],
            ):
                row = collection[row_index]
                accounting = row["executionAccounting"]
                accounting["capacity"]["helperSlots"] = 1
                accounting["unusedCapacityReasons"] = [
                    {
                        "resourceClass": "helper",
                        "slots": 1,
                        "reason": "job completed before observation",
                    }
                ]
                job = self.fixture.job(row, f"job-{row_index}")
                job["mutation"] = "isolated_temp"
                job["exclusiveRoot"] = shared_root
                accounting["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_CROSS_ROW_ROOT_OVERLAP", self.fixture.codes())

    def test_running_job_state_cannot_be_omitted_from_running_set(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            job = self.fixture.job(
                row,
                "north-process-a",
                state="running",
                resource="dcc",
                started_at="2026-07-30T03:59:00Z",
                ended_at=None,
            )
            job["mutation"] = "direction_owned"
            job["exclusiveRoot"] = str(
                Path(str(row["worktree"]))
                / "Native/CitySimNative/WorldArt/Blender/PLAY-027/north-a"
            )
            job["dccSlot"] = "dcc-1"
            job["processId"] = "process-a"
            accounting["capacity"]["dccSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "dcc",
                    "slots": 1,
                    "reason": "falsely reported unused",
                }
            ]
            accounting["launchedJobs"] = [job]
        self.fixture.receipt["computeEnvelope"][
            "maximumSimultaneousDCCProcesses"
        ] = 1
        self.fixture.receipt["computeEnvelope"]["assignedSlots"] = [
            {
                "slot": "dcc-1",
                "direction": "north",
                "claim": "PLAY-027",
                "attemptID": "north-attempt-a",
                "processID": "process-a",
                "maximumChildStarts": 1,
            }
        ]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_RUNNING_SET_MISMATCH", self.fixture.codes())

    def test_direction_owned_root_must_be_claim_owned(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job completed before observation",
                }
            ]
            job = self.fixture.job(row, "wrong-root")
            job["mutation"] = "direction_owned"
            job["exclusiveRoot"] = str(
                self.fixture.repo / "outside" / "unrelated-shared-authority"
            )
            accounting["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_JOB_DIRECTION_ROOT_OUTSIDE_WORKTREE",
            self.fixture.codes(),
        )

    def test_job_evidence_cannot_postdate_row_observation(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job completed before observation",
                }
            ]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "future-job",
                    started_at="2099-07-30T04:00:00Z",
                    ended_at="2099-07-30T04:01:00Z",
                )
            ]
        self.fixture.refresh_hash()
        codes = self.fixture.codes()
        self.assertIn("EXECUTION_JOB_START_AFTER_OBSERVATION", codes)
        self.assertIn("EXECUTION_JOB_END_AFTER_OBSERVATION", codes)

    def test_observed_at_fallback_still_bounds_job_evidence(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["observedAt"] = row.pop("updatedAt")
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job completed before observation",
                }
            ]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "future-observed-job",
                    started_at="2099-07-30T04:00:00Z",
                    ended_at="2099-07-30T04:01:00Z",
                )
            ]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_JOB_START_AFTER_OBSERVATION",
            self.fixture.codes(),
        )

    def test_conflicting_observation_aliases_are_rejected(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["liveObservationAt"] = "2026-07-30T04:00:00Z"
            row["updatedAt"] = "2099-07-30T04:00:00Z"
        self.fixture.refresh_hash()
        self.assertIn("ROW_OBSERVATION_ALIAS_COUNT", self.fixture.codes())

    def test_acknowledgement_must_precede_job_start(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["acknowledgedAt"] = "2026-07-30T03:55:00Z"
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job completed before observation",
                }
            ]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "pre-ack-job",
                    started_at="2026-07-30T03:50:00Z",
                    ended_at="2026-07-30T03:51:00Z",
                )
            ]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_JOB_START_BEFORE_ACKNOWLEDGEMENT",
            self.fixture.codes(),
        )

    def test_acknowledgement_cannot_postdate_observation(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            collection[0]["acknowledgedAt"] = "2099-07-30T04:00:00Z"
        self.fixture.refresh_hash()
        self.assertIn(
            "ROW_ACKNOWLEDGEMENT_AFTER_OBSERVATION",
            self.fixture.codes(),
        )

    def test_launched_jobs_require_authority_acknowledgement(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["acknowledgedAt"] = None
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job completed before observation",
                }
            ]
            accounting["launchedJobs"] = [
                self.fixture.job(row, "unacknowledged-job")
            ]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_JOBS_WITHOUT_ACKNOWLEDGEMENT",
            self.fixture.codes(),
        )

    def test_temp_root_cannot_equal_another_lane_worktree(self) -> None:
        east_worktree = self.fixture.ledger["cells"][1]["worktree"]
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job completed before observation",
                }
            ]
            job = self.fixture.job(row, "cross-worktree-root")
            job["mutation"] = "isolated_temp"
            job["exclusiveRoot"] = east_worktree
            accounting["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_JOB_ROOT_OVERLAPS_WORKTREE",
            self.fixture.codes(),
        )

    def test_temp_root_must_use_task_scoped_private_tmp(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job completed before observation",
                }
            ]
            job = self.fixture.job(row, "system-root-job")
            job["mutation"] = "isolated_temp"
            job["exclusiveRoot"] = "/System"
            accounting["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_JOB_TEMP_ROOT_UNAPPROVED",
            self.fixture.codes(),
        )

    def test_temp_root_requires_nonempty_claim_token(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job completed before observation",
                }
            ]
            job = self.fixture.job(row, "empty-task-temp")
            job["mutation"] = "isolated_temp"
            job["exclusiveRoot"] = "/private/tmp/citysim-"
            accounting["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_JOB_TEMP_ROOT_UNSCOPED",
            self.fixture.codes(),
        )

    def test_temp_root_claim_token_must_be_anchored(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job completed before observation",
                }
            ]
            job = self.fixture.job(row, "embedded-claim-temp")
            job["mutation"] = "isolated_temp"
            job["exclusiveRoot"] = "/private/tmp/citysim-replay027-evil"
            accounting["launchedJobs"] = [job]
        self.fixture.refresh_hash()
        self.assertIn(
            "EXECUTION_JOB_TEMP_ROOT_UNSCOPED",
            self.fixture.codes(),
        )

    def test_completed_job_requires_positive_duration(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job completed before observation",
                }
            ]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "zero-duration-job",
                    started_at="2026-07-30T03:59:00Z",
                    ended_at="2026-07-30T03:59:00Z",
                )
            ]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_JOB_TIME_REVERSED", self.fixture.codes())

    def test_join_reconciles_completed_waiting_and_failed_states(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            accounting = row["executionAccounting"]
            accounting["capacity"]["helperSlots"] = 1
            accounting["unusedCapacityReasons"] = [
                {
                    "resourceClass": "helper",
                    "slots": 1,
                    "reason": "job is not currently running",
                }
            ]
            accounting["launchedJobs"] = [
                self.fixture.job(
                    row,
                    "failed-required-job",
                    state="failed",
                )
            ]
            accounting["join"] = {
                "state": "joined",
                "requiredJobs": ["failed-required-job"],
                "completedJobs": ["failed-required-job"],
            }
        self.fixture.refresh_hash()
        codes = self.fixture.codes()
        self.assertIn("EXECUTION_JOIN_FALSE_COMPLETION", codes)
        self.assertIn("EXECUTION_JOIN_FAILED_JOB", codes)
        self.assertIn("EXECUTION_JOIN_STATE_INCOMPLETE", codes)

    def test_two_dcc_jobs_cannot_reuse_one_assigned_slot(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            row = collection[0]
            row["dispatchState"] = "working"
            row["authorityAcknowledgement"] = {
                "threadId": row["threadId"],
                "authorityCommit": "a" * 40,
                "claimRevision": row["claimRevision"],
                "acknowledgedAt": row["acknowledgedAt"],
                "evidenceId": (
                    f"thread:{row['threadId']}/turn:dcc-turn/item:dcc-item"
                ),
                "boundedDeliverable": row["boundedDeliverable"],
                "stopCondition": row["stopCondition"],
            }
            accounting = row["executionAccounting"]
            accounting["capacity"]["dccSlots"] = 2
            accounting["running"] = ["north-process-a", "north-process-b"]
            jobs = []
            for process in ("a", "b"):
                job = self.fixture.job(
                    row,
                    f"north-process-{process}",
                    state="running",
                    resource="dcc",
                    started_at="2026-07-30T03:59:00Z",
                    ended_at=None,
                )
                job["mutation"] = "direction_owned"
                job["exclusiveRoot"] = str(
                    Path(str(row["worktree"]))
                    / "Native/CitySimNative/WorldArt/Blender/PLAY-027"
                    / f"north-{process}"
                )
                job["dccSlot"] = "dcc-slot-one"
                job["processId"] = f"process-{process}"
                jobs.append(job)
            accounting["launchedJobs"] = jobs
        self.fixture.receipt["computeEnvelope"][
            "maximumSimultaneousDCCProcesses"
        ] = 2
        self.fixture.receipt["computeEnvelope"]["assignedSlots"] = [
            {
                "slot": "dcc-slot-one",
                "direction": "north",
                "claim": "PLAY-027",
                "attemptID": "north-attempt-a",
                "processID": "process-a",
                "maximumChildStarts": 1,
            },
            {
                "slot": "dcc-slot-two",
                "direction": "north",
                "claim": "PLAY-027",
                "attemptID": "north-attempt-b",
                "processID": "process-b",
                "maximumChildStarts": 1,
            },
        ]
        self.fixture.refresh_hash()
        self.assertIn("EXECUTION_DCC_SLOT_REUSED", self.fixture.codes())

    def test_row_cannot_count_unrelated_batch_work(self) -> None:
        self.fixture.ledger["cells"][4]["batch"] = "renderer_r4a"
        self.fixture.receipt["rows"][4]["batch"] = "renderer_r4a"
        self.fixture.refresh_hash()
        self.assertIn("ROW_BATCH_MISMATCH", self.fixture.codes())

    def test_abc_requires_validated_parallel_schedule(self) -> None:
        self.fixture.ledger["batchState"] = "abc_active"
        for field in ("appearanceLock", "sourceProductionProfile"):
            self.fixture.ledger["familyAuthority"][field] = copy.deepcopy(
                self.fixture.ledger["familyAuthority"]["familyContract"]
            )
        self.fixture.refresh_hash()
        self.assertIn(
            "BATCH_SOURCE_AUTHORITY_PRECONDITION",
            self.fixture.codes(),
        )

    def test_fourth_quarantine_requires_same_turn_assembly_dispatch(self) -> None:
        for index in range(4):
            for collection in (
                self.fixture.ledger["cells"],
                self.fixture.receipt["rows"],
            ):
                collection[index]["state"] = "renderer_quarantined"
        self.fixture.board = self.fixture._board(self.fixture.ledger["cells"])
        self.fixture.refresh_hash()
        self.assertIn(
            "ALL4_QUARANTINED_REQUIRES_ASSEMBLY_DISPATCH",
            self.fixture.codes(),
        )

    def test_row_requires_canonical_lane_thread_and_base(self) -> None:
        for collection in (
            self.fixture.ledger["cells"],
            self.fixture.receipt["rows"],
        ):
            collection[4]["lane"] = "world_art"
            collection[4]["threadId"] = ""
        del self.fixture.ledger["cells"][4]["publishedBase"]
        del self.fixture.receipt["rows"][4]["base"]
        self.fixture.refresh_hash()
        codes = self.fixture.codes()
        self.assertIn("CELL_LANE_BINDING", codes)
        self.assertIn("CELL_THREAD_BINDING", codes)
        self.assertIn("ROW_BASE_INVALID", codes)

    def test_terminal_batch_requires_renderer_and_qa(self) -> None:
        self.fixture.ledger["batchState"] = "integrated"
        for index in range(4):
            self.fixture.ledger["cells"][index]["state"] = (
                "renderer_quarantined"
            )
            self.fixture.receipt["rows"][index]["state"] = (
                "renderer_quarantined"
            )
        self.fixture.board = self.fixture._board(self.fixture.ledger["cells"])
        self.fixture.refresh_hash()
        codes = self.fixture.codes()
        self.assertIn("BATCH_RENDERER_PRECONDITION", codes)
        self.assertIn("BATCH_QA_PRECONDITION", codes)

    def test_quarantine_state_requires_exact_direction_artifacts(self) -> None:
        self.fixture.ledger["cells"][0]["state"] = "renderer_quarantined"
        self.fixture.receipt["rows"][0]["state"] = "renderer_quarantined"
        self.fixture.board = self.fixture._board(self.fixture.ledger["cells"])
        self.fixture.refresh_hash()
        self.assertIn("DIRECTION_ARTIFACT_MISSING", self.fixture.codes())

    def test_timezone_free_observation_is_rejected(self) -> None:
        self.fixture.ledger["cells"][0]["updatedAt"] = "2026-07-30T04:00:00"
        self.fixture.receipt["rows"][0]["updatedAt"] = "2026-07-30T04:00:00"
        self.fixture.refresh_hash()
        self.assertIn("TIMESTAMP_TIMEZONE_MISSING", self.fixture.codes())

    def test_compute_slots_cannot_exceed_cap(self) -> None:
        envelope = self.fixture.receipt["computeEnvelope"]
        envelope["maximumSimultaneousDCCProcesses"] = 0
        envelope["assignedSlots"] = [
            {
                "slot": "dcc-1",
                "direction": "north",
                "claim": "PLAY-027",
                "attemptID": "industrial-l04-north-v12",
                "processID": "process-a",
                "maximumChildStarts": 1,
            }
        ]
        envelope["queueOrder"] = [
            "north:industrial-l04-north-v12:process-a"
        ]
        self.assertIn("COMPUTE_OVERSUBSCRIBED", self.fixture.codes())

    def test_compute_slot_claim_must_match_direction(self) -> None:
        envelope = self.fixture.receipt["computeEnvelope"]
        envelope["maximumSimultaneousDCCProcesses"] = 1
        envelope["assignedSlots"] = [
            {
                "slot": "dcc-1",
                "direction": "east",
                "claim": "PLAY-080",
                "attemptID": "industrial-l04-east-v01",
                "processID": "process-a",
                "maximumChildStarts": 1,
            }
        ]
        envelope["queueOrder"] = [
            "east:industrial-l04-east-v01:process-a"
        ]
        self.assertIn("COMPUTE_SLOT_CLAIM", self.fixture.codes())

    def test_compute_slots_require_unique_attempt_process_identity(self) -> None:
        envelope = self.fixture.receipt["computeEnvelope"]
        envelope["maximumSimultaneousDCCProcesses"] = 2
        envelope["assignedSlots"] = [
            {
                "slot": "dcc-1",
                "direction": "north",
                "claim": "PLAY-027",
                "attemptID": "industrial-l04-north-v12",
                "processID": "process-a",
                "maximumChildStarts": 1,
            },
            {
                "slot": "dcc-2",
                "direction": "north",
                "claim": "PLAY-027",
                "attemptID": "industrial-l04-north-v12",
                "processID": "process-a",
                "maximumChildStarts": 1,
            },
        ]
        envelope["queueOrder"] = [
            "north:industrial-l04-north-v12:process-a"
        ]
        self.assertIn("COMPUTE_SLOT_WORK_DUPLICATE", self.fixture.codes())

    def test_compute_assumptions_require_canonical_concrete_fields(self) -> None:
        self.fixture.receipt["computeEnvelope"]["resourceAssumptions"] = {
            "garbage": None
        }
        self.assertIn(
            "COMPUTE_ASSUMPTION_FIELD_MISSING",
            self.fixture.codes(),
        )


if __name__ == "__main__":
    unittest.main()
