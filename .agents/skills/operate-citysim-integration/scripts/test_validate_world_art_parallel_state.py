#!/usr/bin/env python3
"""No-DCC tests for the World Art parallel control-plane validator."""

from __future__ import annotations

import copy
import hashlib
import json
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
            rows.append(
                {
                    "lane": validator.LANE_BINDINGS[cell],
                    "direction": cell,
                    "threadId": f"thread-{cell}",
                    "branch": branch,
                    "worktree": str(self.repo / "worktrees" / cell),
                    "claim": claim,
                    "publishedBase": "a" * 40,
                    "head": "a" * 40,
                    "state": states[cell],
                    "dispatchState": "completed",
                    "acknowledgedAt": "2026-07-30T04:00:00Z",
                    "claimRevision": claim_revisions[cell],
                    "cleanState": "clean",
                    "blocker": "stage authority is intentionally closed",
                    "nextAction": "resume when Integration publishes the next stage",
                    "boundedDeliverable": "one exact bounded preparation packet",
                    "stopCondition": "stop before any unapproved shared mutation",
                    "updatedAt": "2026-07-30T04:00:00Z",
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

    def diagnostics(self) -> list[validator.Diagnostic]:
        subject = StubValidator(self.repo)
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

    def codes(self) -> set[str]:
        return {item.code for item in self.diagnostics()}

    def close(self) -> None:
        self.temp.cleanup()


class ParallelStateValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = ParallelStateFixture()

    def tearDown(self) -> None:
        self.fixture.close()

    def test_valid_control_plane_passes(self) -> None:
        self.assertEqual(self.fixture.diagnostics(), [])

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
