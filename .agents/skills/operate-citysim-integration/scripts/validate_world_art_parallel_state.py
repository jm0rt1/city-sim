#!/usr/bin/env python3
"""Fail-closed validation for CitySim's canonical World Art parallel state."""

from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


EXIT_OK = 0
EXIT_INVALID_STATE = 1
EXIT_USAGE = 2
EXIT_INPUT_ERROR = 3
EXIT_INTERNAL_ERROR = 4

EXPECTED_CELLS = ("north", "east", "south", "west", "renderer", "qa")
EXPECTED_CELL_SET = frozenset(EXPECTED_CELLS)
CELL_LABELS = {
    "north": "North",
    "east": "East",
    "south": "South",
    "west": "West",
    "renderer": "Renderer",
    "qa": "QA",
}

CELL_BINDINGS = {
    "north": (
        "codex/citysim-world-art",
        "PLAY-027",
        Path("docs/production/claims/PLAY-027.world-art.md"),
    ),
    "east": (
        "codex/citysim-world-art-east",
        "PLAY-079",
        Path("docs/production/claims/PLAY-079.world-art-east.md"),
    ),
    "south": (
        "codex/citysim-world-art-south",
        "PLAY-080",
        Path("docs/production/claims/PLAY-080.world-art-south.md"),
    ),
    "west": (
        "codex/citysim-world-art-west",
        "PLAY-081",
        Path("docs/production/claims/PLAY-081.world-art-west.md"),
    ),
    "renderer": (
        "codex/citysim-world-rendering",
        "PLAY-073",
        Path("docs/production/claims/PLAY-073.world-rendering.md"),
    ),
    "qa": (
        "codex/citysim-playtest-quality",
        "PLAY-075",
        Path("docs/production/claims/PLAY-075.playtest-quality.md"),
    ),
}
LANE_BINDINGS = {
    "north": "world_art",
    "east": "world_art",
    "south": "world_art",
    "west": "world_art",
    "renderer": "world_rendering",
    "qa": "playtest_quality",
}

BATCH_STATE_MACHINE = (
    "contract_pending",
    "prelock_active",
    "appearance_lock_pending",
    "abc_active",
    "4of4_ready",
    "exact_candidate_qa",
    "integrated",
)
DIRECTION_STATE_MACHINE = {
    "predesign": ("source_candidate",),
    "source_candidate": ("returned", "integration_admitted"),
    "returned": ("predesign", "source_candidate"),
    "integration_admitted": ("returned", "renderer_quarantined"),
    "renderer_quarantined": (),
}
RENDERER_STATE_MACHINE = (
    "intake_preparing",
    "intake_ready",
    "quarantining",
    "4of4_assembled",
)
QA_STATE_MACHINE = (
    "preregistering",
    "preregistered",
    "exact_candidate_active",
    "passed",
    "returned",
)
AUTHORITY_REQUIRED_PAIRS = {
    "familyContract": (("path", "sha256"),),
    "parallelCellsContract": (("path", "sha256"),),
    "appearanceLock": (("path", "sha256"),),
    "sourceProductionProfile": (("path", "sha256"),),
    "semanticValidator": (("path", "sha256"),),
    "sourceAdmissionReceipt": (
        ("schemaPath", "schemaSha256"),
        ("validatorPath", "validatorSha256"),
    ),
}
REQUIRED_RESOURCE_ASSUMPTIONS = (
    "machine",
    "dcc",
    "rendererHarness",
    "qa",
)

ACTIVE_DISPATCH_STATES = frozenset(
    {"acknowledged", "working", "active", "in_progress"}
)
PENDING_DISPATCH_STATES = frozenset({"planned", "sent", "review_pending"})
INACTIVE_DISPATCH_STATES = frozenset(
    {"idle", "returned", "blocked", "completed", "complete", "done"}
)
KNOWN_DISPATCH_STATES = (
    ACTIVE_DISPATCH_STATES | PENDING_DISPATCH_STATES | INACTIVE_DISPATCH_STATES
)

GIT_SHA_KEYS = frozenset(
    {
        "acceptedIntegrationCommit",
        "authorityCommit",
        "base",
        "candidate",
        "head",
        "ledgerRevision",
        "publishedBase",
        "technicalHeadBeforeLedger",
    }
)
SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA40_SEARCH_RE = re.compile(r"(?<![0-9a-f])[0-9a-f]{40}(?![0-9a-f])")
PLACEHOLDER_RE = re.compile(
    r"^(?:n/?a|none|null|unknown|tbd|todo|pending|waiting|same|later|idle)$",
    re.IGNORECASE,
)

DEFAULT_LEDGER = Path(
    "docs/production/evidence/INTEGRATION/"
    "WORLD_ART_PARALLEL_BATCH_LEDGER.json"
)
DEFAULT_BOARD = Path(
    "docs/production/evidence/INTEGRATION/WORLD_ART_PARALLEL_BOARD.md"
)


@dataclass(frozen=True, order=True)
class Diagnostic:
    code: str
    location: str
    message: str


class InputError(RuntimeError):
    """Raised when a required artifact cannot be read or decoded."""


class Validator:
    def __init__(self, repo_root: Path) -> None:
        self.repo_root = repo_root
        self.diagnostics: list[Diagnostic] = []
        self._git_cache: dict[Path, tuple[str, str, bool] | None] = {}
        self._resolvable_commits: dict[str, bool] = {}

    def error(self, code: str, location: str, message: str) -> None:
        self.diagnostics.append(Diagnostic(code, location, message))

    def validate(
        self,
        ledger: Mapping[str, Any],
        ledger_path: Path,
        ledger_bytes: bytes,
        board_text: str,
        board_path: Path,
        receipt: Mapping[str, Any],
        receipt_path: Path,
    ) -> None:
        self._validate_git_sha_fields(ledger, "ledger")
        self._validate_git_sha_fields(receipt, "receipt")

        ledger_rows = self._canonical_rows(
            ledger.get("cells"), "ledger.cells", require_exact_six=True
        )
        self._validate_timestamp(ledger.get("updatedAt"), "ledger.updatedAt")
        self._validate_state_machines(ledger, ledger_rows)
        self._validate_family_authority(ledger.get("familyAuthority"))
        integration_writer = ledger.get("integrationWriter")
        if isinstance(integration_writer, Mapping):
            self._validate_live_git(
                integration_writer, "ledger.integrationWriter"
            )
        receipt_rows_value, receipt_rows_key = self._receipt_rows(receipt)
        receipt_rows = self._canonical_rows(
            receipt_rows_value,
            f"receipt.{receipt_rows_key}",
            require_exact_six=True,
        )

        for cell in EXPECTED_CELLS:
            ledger_row = ledger_rows.get(cell)
            if ledger_row is not None:
                self._validate_cell_binding(
                    cell, ledger_row, f"ledger.cells.{cell}"
                )
                self._validate_required_row_fields(
                    ledger_row, f"ledger.cells.{cell}"
                )
                self._validate_work_row(ledger_row, f"ledger.cells.{cell}")
                self._validate_live_git(ledger_row, f"ledger.cells.{cell}")

            receipt_row = receipt_rows.get(cell)
            if receipt_row is not None:
                self._validate_cell_binding(
                    cell, receipt_row, f"receipt.rows.{cell}"
                )
                self._validate_required_row_fields(
                    receipt_row, f"receipt.rows.{cell}"
                )
                if not isinstance(receipt_row.get("changedThisTurn"), bool):
                    self.error(
                        "RECEIPT_CHANGED_TYPE",
                        f"receipt.rows.{cell}.changedThisTurn",
                        "must be present on every row and be a JSON boolean",
                    )
                self._validate_work_row(receipt_row, f"receipt.rows.{cell}")
                self._validate_live_git(receipt_row, f"receipt.rows.{cell}")

            if ledger_row is not None and receipt_row is not None:
                self._validate_row_binding(cell, ledger_row, receipt_row)

        self._validate_timestamp(receipt.get("sentAt"), "receipt.sentAt")
        self._validate_compute_envelope(receipt.get("computeEnvelope"))
        self._validate_board(board_text, board_path, ledger_rows)
        self._validate_receipt_binding(
            ledger,
            ledger_path,
            ledger_bytes,
            receipt,
            receipt_path,
        )

    def _receipt_rows(
        self, receipt: Mapping[str, Any]
    ) -> tuple[Any, str]:
        present = [
            key
            for key in ("rows", "dispatches", "cells")
            if isinstance(receipt.get(key), list)
        ]
        if not present:
            self.error(
                "RECEIPT_ROWS_MISSING",
                "receipt",
                "must contain a rows, dispatches, or cells array",
            )
            return [], "rows"
        if len(present) > 1:
            self.error(
                "RECEIPT_ROWS_AMBIGUOUS",
                "receipt",
                "contains multiple row arrays: " + ", ".join(present),
            )
        key = present[0]
        return receipt[key], key

    def _canonical_rows(
        self, value: Any, location: str, *, require_exact_six: bool
    ) -> dict[str, Mapping[str, Any]]:
        if not isinstance(value, list):
            self.error(
                "ROWS_TYPE",
                location,
                "must be an array",
            )
            return {}

        rows: dict[str, Mapping[str, Any]] = {}
        duplicate_cells: set[str] = set()
        unknown_cells: list[str] = []
        for index, item in enumerate(value):
            item_location = f"{location}[{index}]"
            if not isinstance(item, Mapping):
                self.error("ROW_TYPE", item_location, "must be an object")
                continue
            raw_cell = item.get("direction", item.get("cell"))
            cell = _normalize_cell(raw_cell)
            if cell not in EXPECTED_CELL_SET:
                unknown_cells.append(repr(raw_cell))
                self.error(
                    "CELL_UNKNOWN",
                    f"{item_location}.direction",
                    f"expected one of {', '.join(CELL_LABELS.values())}; got {raw_cell!r}",
                )
                continue
            if cell in rows:
                duplicate_cells.add(cell)
                self.error(
                    "CELL_DUPLICATE",
                    f"{item_location}.direction",
                    f"duplicate {CELL_LABELS[cell]} row",
                )
                continue
            rows[cell] = item

        if require_exact_six:
            if len(value) != len(EXPECTED_CELLS):
                self.error(
                    "CELL_COUNT",
                    location,
                    f"must contain exactly 6 rows; found {len(value)}",
                )
            missing = [CELL_LABELS[cell] for cell in EXPECTED_CELLS if cell not in rows]
            if missing:
                self.error(
                    "CELL_MISSING",
                    location,
                    "missing rows: " + ", ".join(missing),
                )
            if duplicate_cells or unknown_cells:
                self.error(
                    "CELL_SET",
                    location,
                    "rows must be exactly North, East, South, West, Renderer, and QA",
                )
        return rows

    def _validate_work_row(
        self, row: Mapping[str, Any], location: str
    ) -> None:
        raw_state = row.get("dispatchState")
        if not isinstance(raw_state, str) or not raw_state.strip():
            self.error(
                "DISPATCH_STATE_MISSING",
                f"{location}.dispatchState",
                "must be a non-empty dispatch state",
            )
            return
        state = _normalize_token(raw_state)
        if state not in KNOWN_DISPATCH_STATES:
            self.error(
                "DISPATCH_STATE_UNKNOWN",
                f"{location}.dispatchState",
                f"unsupported dispatch state {raw_state!r}",
            )
            return

        deliverable = _first_concrete(
            row, ("boundedDeliverable", "firstDeliverable", "usefulWork")
        )
        stop_condition = _first_concrete(
            row, ("stopCondition", "exactStopCondition")
        )

        if state in ACTIVE_DISPATCH_STATES:
            acknowledged_at = row.get("acknowledgedAt")
            if not _concrete_text(acknowledged_at):
                self.error(
                    "ACTIVE_NOT_ACKNOWLEDGED",
                    f"{location}.acknowledgedAt",
                    "active work must carry an acknowledgement timestamp",
                )
            self._validate_optional_true_flags(
                row,
                location,
                ("acknowledged", "usefulWorkAcknowledged"),
            )
            if deliverable is None:
                self.error(
                    "ACTIVE_DELIVERABLE_MISSING",
                    location,
                    "active work must name a concrete bounded deliverable",
                )
            if stop_condition is None:
                self.error(
                    "ACTIVE_STOP_MISSING",
                    location,
                    "active work must name a concrete stop condition",
                )
            return

        if state in PENDING_DISPATCH_STATES:
            if deliverable is None:
                self.error(
                    "PENDING_DELIVERABLE_MISSING",
                    location,
                    "planned or sent work must name a concrete bounded deliverable",
                )
            if stop_condition is None:
                self.error(
                    "PENDING_STOP_MISSING",
                    location,
                    "planned or sent work must name a concrete stop condition",
                )
            return

        refill = _first_concrete(
            row,
            (
                "refillAction",
                "nextAction",
                "nextRefillAction",
                "legalPreparation",
            ),
        )
        prohibition = _first_concrete(
            row,
            (
                "exactProhibition",
                "stageProhibition",
                "prohibition",
                "blockedBy",
            ),
        )
        if refill is None and prohibition is None:
            self.error(
                "INACTIVE_REFILL_MISSING",
                location,
                "idle, returned, blocked, or completed work must name a concrete "
                "refill action or exact stage prohibition",
            )

    def _validate_required_row_fields(
        self, row: Mapping[str, Any], location: str
    ) -> None:
        for field in (
            "lane",
            "threadId",
            "branch",
            "worktree",
            "claim",
            "head",
            "cleanState",
            "dispatchState",
            "state",
        ):
            value = row.get(field)
            if not isinstance(value, str) or not value.strip():
                self.error(
                    "ROW_FIELD_MISSING",
                    f"{location}.{field}",
                    "must be present and non-empty",
                )

        base_value = row.get("publishedBase", row.get("base"))
        if not isinstance(base_value, str) or not SHA40_RE.fullmatch(base_value):
            self.error(
                "ROW_BASE_INVALID",
                f"{location}.publishedBase",
                "must carry publishedBase/base as a full lowercase Git SHA",
            )

        for field in (
            "boundedDeliverable",
            "stopCondition",
            "blocker",
        ):
            if not _concrete_text(row.get(field)):
                self.error(
                    "ROW_FIELD_MISSING",
                    f"{location}.{field}",
                    "must be present and concrete",
                )

        claim_revision = row.get("claimRevision")
        if (
            not isinstance(claim_revision, str)
            or not SHA256_RE.fullmatch(claim_revision)
        ):
            self.error(
                "CLAIM_REVISION_INVALID",
                f"{location}.claimRevision",
                "must be a lowercase 64-character content hash",
            )

        if _first_concrete(
            row,
            ("nextRefillAction", "refillAction", "nextAction", "legalPreparation"),
        ) is None:
            self.error(
                "ROW_REFILL_MISSING",
                location,
                "must name the next refill action or legal preparation",
            )

        if _first_concrete(
            row, ("liveObservationAt", "observedAt", "updatedAt")
        ) is None:
            self.error(
                "ROW_OBSERVATION_MISSING",
                location,
                "must record a live observation timestamp",
            )
        else:
            timestamp = next(
                row.get(name)
                for name in ("liveObservationAt", "observedAt", "updatedAt")
                if _concrete_text(row.get(name))
            )
            self._validate_timestamp(timestamp, f"{location}.observation")

        acknowledged_at = row.get("acknowledgedAt")
        if acknowledged_at is not None:
            self._validate_timestamp(
                acknowledged_at, f"{location}.acknowledgedAt"
            )

    def _validate_cell_binding(
        self, cell: str, row: Mapping[str, Any], location: str
    ) -> None:
        expected_branch, expected_claim, claim_path = CELL_BINDINGS[cell]
        expected_lane = LANE_BINDINGS[cell]
        if row.get("lane") != expected_lane:
            self.error(
                "CELL_LANE_BINDING",
                f"{location}.lane",
                f"{CELL_LABELS[cell]} must use lane {expected_lane!r}",
            )
        if row.get("branch") != expected_branch:
            self.error(
                "CELL_BRANCH_BINDING",
                f"{location}.branch",
                f"{CELL_LABELS[cell]} must use {expected_branch!r}",
            )
        if row.get("claim") != expected_claim:
            self.error(
                "CELL_CLAIM_BINDING",
                f"{location}.claim",
                f"{CELL_LABELS[cell]} must use {expected_claim!r}",
            )
        if not _concrete_text(row.get("threadId")):
            self.error(
                "CELL_THREAD_BINDING",
                f"{location}.threadId",
                "must bind a concrete visible thread identifier",
            )

        absolute_claim = self.repo_root / claim_path
        try:
            actual_revision = hashlib.sha256(absolute_claim.read_bytes()).hexdigest()
        except OSError as exc:
            self.error(
                "CLAIM_FILE_UNREADABLE",
                f"{location}.claimRevision",
                f"could not read {claim_path}: {exc}",
            )
            return
        if row.get("claimRevision") != actual_revision:
            self.error(
                "CLAIM_REVISION_STALE",
                f"{location}.claimRevision",
                f"recorded={row.get('claimRevision')!r}; actual={actual_revision}",
            )

    def _validate_optional_true_flags(
        self,
        row: Mapping[str, Any],
        location: str,
        names: Sequence[str],
    ) -> None:
        for name in names:
            if name in row and row[name] is not True:
                self.error(
                    "ACTIVE_ACK_FLAG",
                    f"{location}.{name}",
                    "must be true when present on an active row",
                )

    def _validate_row_binding(
        self,
        cell: str,
        ledger_row: Mapping[str, Any],
        receipt_row: Mapping[str, Any],
    ) -> None:
        aliases = {"publishedBase": "base"}
        for ledger_field, ledger_value in ledger_row.items():
            receipt_field = aliases.get(ledger_field, ledger_field)
            if receipt_field not in receipt_row:
                self.error(
                    "RECEIPT_LEDGER_ROW_FIELD_MISSING",
                    f"receipt.rows.{cell}.{receipt_field}",
                    f"must project ledger field {ledger_field!r}",
                )
                continue
            if receipt_row[receipt_field] != ledger_value:
                self.error(
                    "RECEIPT_LEDGER_ROW_MISMATCH",
                    f"receipt.rows.{cell}.{receipt_field}",
                    f"{receipt_row[receipt_field]!r} does not match ledger "
                    f"{ledger_field} {ledger_value!r}",
                )
        expected_fields = {
            aliases.get(field, field) for field in ledger_row
        } | {"changedThisTurn"}
        extras = sorted(set(receipt_row) - expected_fields)
        if extras:
            self.error(
                "RECEIPT_LEDGER_ROW_EXTRA",
                f"receipt.rows.{cell}",
                "contains non-projection fields: " + ", ".join(extras),
            )

    def _validate_state_machines(
        self,
        ledger: Mapping[str, Any],
        rows: Mapping[str, Mapping[str, Any]],
    ) -> None:
        expected_documents = (
            ("stateMachine", list(BATCH_STATE_MACHINE)),
            (
                "directionStateMachine",
                {key: list(value) for key, value in DIRECTION_STATE_MACHINE.items()},
            ),
            ("rendererStateMachine", list(RENDERER_STATE_MACHINE)),
            ("qaStateMachine", list(QA_STATE_MACHINE)),
        )
        for field, expected in expected_documents:
            if ledger.get(field) != expected:
                self.error(
                    "STATE_MACHINE_DRIFT",
                    f"ledger.{field}",
                    "must exactly match the governed parallel state machine",
                )

        batch_state = ledger.get("batchState")
        if batch_state not in BATCH_STATE_MACHINE:
            self.error(
                "BATCH_STATE_INVALID",
                "ledger.batchState",
                f"unsupported batch state {batch_state!r}",
            )

        direction_states: dict[str, Any] = {}
        for cell in ("north", "east", "south", "west"):
            row = rows.get(cell)
            if row is None:
                continue
            state = row.get("state")
            direction_states[cell] = state
            if state not in DIRECTION_STATE_MACHINE:
                self.error(
                    "DIRECTION_STATE_INVALID",
                    f"ledger.cells.{cell}.state",
                    f"unsupported direction state {state!r}",
                )

        renderer_state = rows.get("renderer", {}).get("state")
        if renderer_state not in RENDERER_STATE_MACHINE:
            self.error(
                "RENDERER_STATE_INVALID",
                "ledger.cells.renderer.state",
                f"unsupported renderer state {renderer_state!r}",
            )
        qa_state = rows.get("qa", {}).get("state")
        if qa_state not in QA_STATE_MACHINE:
            self.error(
                "QA_STATE_INVALID",
                "ledger.cells.qa.state",
                f"unsupported QA state {qa_state!r}",
            )

        all_quarantined = (
            len(direction_states) == 4
            and all(
                state == "renderer_quarantined"
                for state in direction_states.values()
            )
        )
        if batch_state in {"4of4_ready", "exact_candidate_qa", "integrated"}:
            if not all_quarantined:
                self.error(
                    "BATCH_4OF4_PRECONDITION",
                    "ledger.batchState",
                    "4of4_ready and later require all four directions "
                    "renderer_quarantined",
                )
        if renderer_state == "4of4_assembled" and not all_quarantined:
            self.error(
                "RENDERER_4OF4_PRECONDITION",
                "ledger.cells.renderer.state",
                "4of4_assembled requires all four directions "
                "renderer_quarantined",
            )

        family_authority = ledger.get("familyAuthority")
        appearance_ready = self._authority_is_concrete(
            family_authority, "appearanceLock"
        )
        profile_ready = self._authority_is_concrete(
            family_authority, "sourceProductionProfile"
        )
        if batch_state in {
            "abc_active",
            "4of4_ready",
            "exact_candidate_qa",
            "integrated",
        } and not (appearance_ready and profile_ready):
            self.error(
                "BATCH_SOURCE_AUTHORITY_PRECONDITION",
                "ledger.batchState",
                "abc_active and later require concrete appearance lock and "
                "source production profile authorities",
            )

        for cell, state in direction_states.items():
            row = rows[cell]
            if state in {
                "source_candidate",
                "integration_admitted",
                "renderer_quarantined",
            } and not (appearance_ready and profile_ready):
                self.error(
                    "DIRECTION_SOURCE_AUTHORITY_PRECONDITION",
                    f"ledger.cells.{cell}.state",
                    "source_candidate and later require concrete appearance "
                    "lock and source production profile authorities",
                )
            if state in {"integration_admitted", "renderer_quarantined"}:
                self._validate_row_artifact(
                    row,
                    "sourceAdmissionReceipt",
                    f"ledger.cells.{cell}.sourceAdmissionReceipt",
                )
            if state == "renderer_quarantined":
                self._validate_row_artifact(
                    row,
                    "rendererQuarantinePacket",
                    f"ledger.cells.{cell}.rendererQuarantinePacket",
                )

        if batch_state == "4of4_ready":
            if renderer_state != "4of4_assembled":
                self.error(
                    "BATCH_RENDERER_PRECONDITION",
                    "ledger.batchState",
                    "4of4_ready requires Renderer 4of4_assembled",
                )
            if qa_state not in {
                "preregistered",
                "exact_candidate_active",
                "passed",
            }:
                self.error(
                    "BATCH_QA_PRECONDITION",
                    "ledger.batchState",
                    "4of4_ready requires QA preregistered or later",
                )
        elif batch_state == "exact_candidate_qa":
            if renderer_state != "4of4_assembled":
                self.error(
                    "BATCH_RENDERER_PRECONDITION",
                    "ledger.batchState",
                    "exact_candidate_qa requires Renderer 4of4_assembled",
                )
            if qa_state not in {"exact_candidate_active", "passed"}:
                self.error(
                    "BATCH_QA_PRECONDITION",
                    "ledger.batchState",
                    "exact_candidate_qa requires QA exact_candidate_active "
                    "or passed",
                )
        elif batch_state == "integrated":
            if renderer_state != "4of4_assembled":
                self.error(
                    "BATCH_RENDERER_PRECONDITION",
                    "ledger.batchState",
                    "integrated requires Renderer 4of4_assembled",
                )
            if qa_state != "passed":
                self.error(
                    "BATCH_QA_PRECONDITION",
                    "ledger.batchState",
                    "integrated requires QA passed",
                )

    def _validate_family_authority(self, value: Any) -> None:
        location = "ledger.familyAuthority"
        if not isinstance(value, Mapping):
            self.error(
                "FAMILY_AUTHORITY_TYPE",
                location,
                "must be an object",
            )
            return
        for field in (
            "familyContract",
            "parallelCellsContract",
            "appearanceLock",
            "sourceProductionProfile",
            "semanticValidator",
            "sourceAdmissionReceipt",
        ):
            if field not in value:
                self.error(
                    "FAMILY_AUTHORITY_MISSING",
                    f"{location}.{field}",
                    "required authority binding is absent",
                )
                continue
            self._validate_required_authority_descriptor(
                field, value[field], f"{location}.{field}"
            )
        self._validate_authority_hashes(value, location)

    def _validate_required_authority_descriptor(
        self, field: str, value: Any, location: str
    ) -> None:
        if not isinstance(value, Mapping):
            self.error(
                "AUTHORITY_DESCRIPTOR_TYPE",
                location,
                "must be an object",
            )
            return
        status = value.get("status")
        if not isinstance(status, str) or not status.strip():
            self.error(
                "AUTHORITY_STATUS_MISSING",
                f"{location}.status",
                "must be a concrete status",
            )
            return
        token = _normalize_token(status)
        pending = "pending" in token or "absent" in token
        pairs = AUTHORITY_REQUIRED_PAIRS[field]
        for path_key, hash_key in pairs:
            if path_key not in value or hash_key not in value:
                self.error(
                    "AUTHORITY_BINDING_MISSING",
                    location,
                    f"must contain {path_key}/{hash_key}",
                )
                continue
            raw_path = value.get(path_key)
            raw_hash = value.get(hash_key)
            if pending:
                if raw_path is not None or raw_hash is not None:
                    self.error(
                        "AUTHORITY_PENDING_CONCRETE",
                        location,
                        "pending/absent authority must use null path and hash",
                    )
            elif raw_path is None or raw_hash is None:
                self.error(
                    "AUTHORITY_PUBLISHED_NULL",
                    location,
                    "non-pending authority must bind concrete path and hash",
                )

    @staticmethod
    def _authority_is_concrete(value: Any, field: str) -> bool:
        if not isinstance(value, Mapping):
            return False
        descriptor = value.get(field)
        if not isinstance(descriptor, Mapping):
            return False
        status = descriptor.get("status")
        if not isinstance(status, str):
            return False
        token = _normalize_token(status)
        if "pending" in token or "absent" in token:
            return False
        return (
            isinstance(descriptor.get("path"), str)
            and bool(descriptor.get("path"))
            and isinstance(descriptor.get("sha256"), str)
            and bool(SHA256_RE.fullmatch(descriptor["sha256"]))
        )

    def _validate_row_artifact(
        self, row: Mapping[str, Any], field: str, location: str
    ) -> None:
        descriptor = row.get(field)
        if not isinstance(descriptor, Mapping):
            self.error(
                "DIRECTION_ARTIFACT_MISSING",
                location,
                "must bind an exact path/hash descriptor",
            )
            return
        self._validate_authority_hashes(descriptor, location)
        raw_path = descriptor.get("path")
        raw_hash = descriptor.get("sha256")
        if (
            not isinstance(raw_path, str)
            or not raw_path
            or not isinstance(raw_hash, str)
            or not SHA256_RE.fullmatch(raw_hash)
        ):
            self.error(
                "DIRECTION_ARTIFACT_INVALID",
                location,
                "must bind concrete path and SHA-256",
            )

    def _validate_authority_hashes(self, value: Any, location: str) -> None:
        if isinstance(value, Mapping):
            pairs = (
                ("path", "sha256"),
                ("schemaPath", "schemaSha256"),
                ("validatorPath", "validatorSha256"),
            )
            for path_key, hash_key in pairs:
                if path_key not in value and hash_key not in value:
                    continue
                raw_path = value.get(path_key)
                raw_hash = value.get(hash_key)
                if raw_path is None and raw_hash is None:
                    continue
                if not isinstance(raw_path, str) or not raw_path:
                    self.error(
                        "AUTHORITY_PATH_INVALID",
                        f"{location}.{path_key}",
                        "path and hash must both be concrete or both be null",
                    )
                    continue
                if not isinstance(raw_hash, str) or not SHA256_RE.fullmatch(raw_hash):
                    self.error(
                        "AUTHORITY_HASH_INVALID",
                        f"{location}.{hash_key}",
                        "must be a lowercase 64-character SHA-256",
                    )
                    continue
                authority_path = _path_from_argument(self.repo_root, raw_path)
                try:
                    actual_hash = hashlib.sha256(authority_path.read_bytes()).hexdigest()
                except OSError as exc:
                    self.error(
                        "AUTHORITY_FILE_UNREADABLE",
                        f"{location}.{path_key}",
                        f"could not read {raw_path}: {exc}",
                    )
                    continue
                if actual_hash != raw_hash:
                    self.error(
                        "AUTHORITY_HASH_STALE",
                        f"{location}.{hash_key}",
                        f"recorded={raw_hash}; actual={actual_hash}",
                    )
            for key, item in value.items():
                self._validate_authority_hashes(item, f"{location}.{key}")
        elif isinstance(value, list):
            for index, item in enumerate(value):
                self._validate_authority_hashes(item, f"{location}[{index}]")

    def _validate_compute_envelope(self, value: Any) -> None:
        location = "receipt.computeEnvelope"
        if not isinstance(value, Mapping):
            self.error(
                "COMPUTE_ENVELOPE_TYPE",
                location,
                "must be an object",
            )
            return
        maximum = value.get("maximumSimultaneousDCCProcesses")
        if not isinstance(maximum, int) or isinstance(maximum, bool) or maximum < 0:
            self.error(
                "COMPUTE_CAP_INVALID",
                f"{location}.maximumSimultaneousDCCProcesses",
                "must be a non-negative integer",
            )
            maximum = 0
        slots = value.get("assignedSlots")
        if not isinstance(slots, list):
            self.error(
                "COMPUTE_SLOTS_TYPE",
                f"{location}.assignedSlots",
                "must be an array",
            )
            slots = []
        if len(slots) > maximum:
            self.error(
                "COMPUTE_OVERSUBSCRIBED",
                f"{location}.assignedSlots",
                f"{len(slots)} simultaneous slots exceed cap {maximum}",
            )

        identifiers: list[str] = []
        slot_names: set[str] = set()
        for index, slot in enumerate(slots):
            slot_location = f"{location}.assignedSlots[{index}]"
            if not isinstance(slot, Mapping):
                self.error("COMPUTE_SLOT_TYPE", slot_location, "must be an object")
                continue
            direction = _normalize_cell(slot.get("direction"))
            if direction not in {"north", "east", "south", "west"}:
                self.error(
                    "COMPUTE_SLOT_DIRECTION",
                    f"{slot_location}.direction",
                    "must name one World Art direction",
                )
            expected_claim = CELL_BINDINGS.get(direction, ("", "", Path()))[1]
            if slot.get("claim") != expected_claim:
                self.error(
                    "COMPUTE_SLOT_CLAIM",
                    f"{slot_location}.claim",
                    f"must bind {expected_claim!r} for {direction!r}",
                )
            slot_name = slot.get("slot")
            if not isinstance(slot_name, str) or not slot_name.strip():
                self.error(
                    "COMPUTE_SLOT_NAME",
                    f"{slot_location}.slot",
                    "must be a non-empty string",
                )
            elif slot_name in slot_names:
                self.error(
                    "COMPUTE_SLOT_DUPLICATE",
                    f"{slot_location}.slot",
                    f"duplicate slot {slot_name!r}",
                )
            else:
                slot_names.add(slot_name)
            attempt_id = slot.get("attemptID")
            process_id = slot.get("processID")
            if not _concrete_text(attempt_id) or not _concrete_text(process_id):
                self.error(
                    "COMPUTE_SLOT_WORK_MISSING",
                    slot_location,
                    "must bind concrete attemptID and processID",
                )
            else:
                identifiers.append(f"{direction}:{attempt_id}:{process_id}")
            starts = slot.get("maximumChildStarts")
            if not isinstance(starts, int) or isinstance(starts, bool) or starts < 1:
                self.error(
                    "COMPUTE_SLOT_CHILD_CAP",
                    f"{slot_location}.maximumChildStarts",
                    "must be a positive integer",
                )

        queue = value.get("queueOrder")
        if not isinstance(queue, list) or not all(
            isinstance(item, str) and item for item in queue
        ):
            self.error(
                "COMPUTE_QUEUE_INVALID",
                f"{location}.queueOrder",
                "must be an array of concrete queue identifiers",
            )
        elif len(queue) != len(set(queue)):
            self.error(
                "COMPUTE_QUEUE_DUPLICATE",
                f"{location}.queueOrder",
                "must not contain duplicate work",
            )
        elif any(identifier not in queue for identifier in identifiers):
            self.error(
                "COMPUTE_QUEUE_SLOT_MISSING",
                f"{location}.queueOrder",
                "must contain every assigned slot identifier",
            )

        assumptions = value.get("resourceAssumptions")
        if not isinstance(assumptions, Mapping) or not assumptions:
            self.error(
                "COMPUTE_ASSUMPTIONS_MISSING",
                f"{location}.resourceAssumptions",
                "must name machine and resource assumptions",
            )
        else:
            for field in REQUIRED_RESOURCE_ASSUMPTIONS:
                if not _concrete_text(assumptions.get(field)):
                    self.error(
                        "COMPUTE_ASSUMPTION_FIELD_MISSING",
                        f"{location}.resourceAssumptions.{field}",
                        "must be a concrete resource assumption",
                    )
        prohibited = value.get("prohibited")
        if not isinstance(prohibited, list) or not prohibited or not all(
            _concrete_text(item) for item in prohibited
        ):
            self.error(
                "COMPUTE_PROHIBITIONS_MISSING",
                f"{location}.prohibited",
                "must contain concrete prohibited work",
            )
        for field in ("exceptionOwner", "reason"):
            if not _concrete_text(value.get(field)):
                self.error(
                    "COMPUTE_FIELD_MISSING",
                    f"{location}.{field}",
                    "must be concrete",
                )

    def _validate_timestamp(self, value: Any, location: str) -> None:
        if not isinstance(value, str) or not value:
            self.error("TIMESTAMP_MISSING", location, "must be an ISO-8601 timestamp")
            return
        candidate = value[:-1] + "+00:00" if value.endswith("Z") else value
        try:
            parsed = datetime.fromisoformat(candidate)
        except ValueError:
            self.error(
                "TIMESTAMP_INVALID",
                location,
                f"not ISO-8601: {value!r}",
            )
            return
        if parsed.tzinfo is None:
            self.error(
                "TIMESTAMP_TIMEZONE_MISSING",
                location,
                "must include a timezone",
            )

    def _validate_git_sha_fields(self, value: Any, location: str) -> None:
        if isinstance(value, Mapping):
            for key in sorted(value):
                item = value[key]
                child_location = f"{location}.{key}"
                if key in GIT_SHA_KEYS and item is not None:
                    if not isinstance(item, str) or not SHA40_RE.fullmatch(item):
                        self.error(
                            "GIT_SHA_NOT_FULL",
                            child_location,
                            f"must be a lowercase full 40-character Git SHA; got {item!r}",
                        )
                    elif not self._commit_resolves(item):
                        self.error(
                            "GIT_SHA_UNRESOLVABLE",
                            child_location,
                            f"does not resolve to a commit in the repository: {item}",
                        )
                self._validate_git_sha_fields(item, child_location)
        elif isinstance(value, list):
            for index, item in enumerate(value):
                self._validate_git_sha_fields(item, f"{location}[{index}]")

    def _validate_live_git(
        self, row: Mapping[str, Any], location: str
    ) -> None:
        git_fields = ("worktree", "branch", "head", "cleanState")
        if not any(field in row for field in git_fields):
            return

        worktree_value = row.get("worktree")
        if not isinstance(worktree_value, str) or not worktree_value.strip():
            self.error(
                "GIT_WORKTREE_MISSING",
                f"{location}.worktree",
                "is required to resolve live branch, HEAD, and cleanliness",
            )
            return
        worktree = Path(worktree_value)
        if not worktree.is_absolute():
            self.error(
                "GIT_WORKTREE_NOT_ABSOLUTE",
                f"{location}.worktree",
                f"must be absolute; got {worktree_value!r}",
            )
            return
        worktree = worktree.resolve()
        snapshot = self._git_snapshot(worktree, location)
        if snapshot is None:
            return
        actual_branch, actual_head, actual_clean = snapshot

        expected_branch = row.get("branch")
        if expected_branch is not None:
            if not isinstance(expected_branch, str) or not expected_branch:
                self.error(
                    "GIT_BRANCH_TYPE",
                    f"{location}.branch",
                    "must be a non-empty string",
                )
            elif actual_branch != expected_branch:
                self.error(
                    "GIT_BRANCH_STALE",
                    f"{location}.branch",
                    f"ledger/receipt={expected_branch!r}; live={actual_branch!r}",
                )

        expected_head = row.get("head")
        if expected_head is not None and actual_head != expected_head:
            self.error(
                "GIT_HEAD_STALE",
                f"{location}.head",
                f"ledger/receipt={expected_head!r}; live={actual_head!r}",
            )

        clean_state = row.get("cleanState")
        if clean_state is not None:
            expected_clean = _expected_clean_state(clean_state)
            if expected_clean is None:
                self.error(
                    "GIT_CLEAN_STATE_UNKNOWN",
                    f"{location}.cleanState",
                    f"cannot derive clean/dirty expectation from {clean_state!r}",
                )
            elif expected_clean != actual_clean:
                self.error(
                    "GIT_CLEAN_STATE_STALE",
                    f"{location}.cleanState",
                    f"artifact expects {'clean' if expected_clean else 'dirty'}; "
                    f"live worktree is {'clean' if actual_clean else 'dirty'}",
                )

    def _git_snapshot(
        self, worktree: Path, location: str
    ) -> tuple[str, str, bool] | None:
        if worktree in self._git_cache:
            return self._git_cache[worktree]
        if not worktree.is_dir():
            self.error(
                "GIT_WORKTREE_MISSING_LIVE",
                f"{location}.worktree",
                f"live worktree does not exist: {worktree}",
            )
            self._git_cache[worktree] = None
            return None

        def run(*arguments: str) -> str | None:
            try:
                completed = subprocess.run(
                    ["git", "-C", str(worktree), *arguments],
                    check=False,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    timeout=15,
                )
            except (OSError, subprocess.TimeoutExpired) as exc:
                self.error(
                    "GIT_COMMAND_FAILED",
                    f"{location}.worktree",
                    f"could not execute git for {worktree}: {exc}",
                )
                return None
            if completed.returncode != 0:
                detail = (completed.stderr or completed.stdout).strip()
                self.error(
                    "GIT_COMMAND_FAILED",
                    f"{location}.worktree",
                    f"git {' '.join(arguments)} failed: {detail}",
                )
                return None
            return completed.stdout.rstrip("\n")

        top_level = run("rev-parse", "--show-toplevel")
        branch = run("branch", "--show-current")
        head = run("rev-parse", "HEAD")
        status = run("status", "--porcelain=v1", "--untracked-files=all")
        if None in (top_level, branch, head, status):
            self._git_cache[worktree] = None
            return None
        if Path(top_level).resolve() != worktree:
            self.error(
                "GIT_WORKTREE_ROOT_MISMATCH",
                f"{location}.worktree",
                f"declared {worktree}; git reports {Path(top_level).resolve()}",
            )
        if not branch:
            self.error(
                "GIT_BRANCH_DETACHED",
                f"{location}.branch",
                "live worktree is detached",
            )
        snapshot = (branch, head, status == "")
        self._git_cache[worktree] = snapshot
        return snapshot

    def _commit_resolves(self, sha: str) -> bool:
        if sha in self._resolvable_commits:
            return self._resolvable_commits[sha]
        try:
            completed = subprocess.run(
                [
                    "git",
                    "-C",
                    str(self.repo_root),
                    "cat-file",
                    "-e",
                    f"{sha}^{{commit}}",
                ],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=15,
            )
        except (OSError, subprocess.TimeoutExpired):
            resolved = False
        else:
            resolved = completed.returncode == 0
        self._resolvable_commits[sha] = resolved
        return resolved

    def _validate_board(
        self,
        board_text: str,
        board_path: Path,
        ledger_rows: Mapping[str, Mapping[str, Any]],
    ) -> None:
        parsed = _parse_board_table(board_text)
        if parsed is None:
            self.error(
                "BOARD_TABLE_MISSING",
                str(board_path),
                "could not find a Markdown table containing the six Cell rows",
            )
            return
        headers, raw_rows = parsed
        board_rows: dict[str, list[str]] = {}
        for cells in raw_rows:
            cell = _normalize_cell(cells[0] if cells else None)
            if cell not in EXPECTED_CELL_SET:
                continue
            if cell in board_rows:
                self.error(
                    "BOARD_CELL_DUPLICATE",
                    f"board.{cell}",
                    f"duplicate {CELL_LABELS[cell]} row",
                )
                continue
            board_rows[cell] = cells

        if len(board_rows) != len(EXPECTED_CELLS):
            missing = [
                CELL_LABELS[cell] for cell in EXPECTED_CELLS if cell not in board_rows
            ]
            self.error(
                "BOARD_CELL_SET",
                str(board_path),
                "board must contain exactly the six canonical rows"
                + (f"; missing {', '.join(missing)}" if missing else ""),
            )

        state_index = _header_index(headers, lambda text: "state" in text)
        head_index = _header_index(
            headers, lambda text: "head" in text.split("_")
        )
        branch_index = _header_index(
            headers, lambda text: "branch" in text and "claim" in text
        )

        for cell in EXPECTED_CELLS:
            board_row = board_rows.get(cell)
            ledger_row = ledger_rows.get(cell)
            if board_row is None or ledger_row is None:
                continue
            location = f"board.{cell}"

            expected_state = ledger_row.get("state")
            if not isinstance(expected_state, str) or not expected_state:
                self.error(
                    "LEDGER_STATE_MISSING",
                    f"ledger.cells.{cell}.state",
                    "must be a non-empty string for board comparison",
                )
            elif state_index is None or state_index >= len(board_row):
                self.error(
                    "BOARD_STATE_COLUMN_MISSING",
                    location,
                    "board must expose a Current state column",
                )
            elif not _board_state_matches(board_row[state_index], expected_state):
                self.error(
                    "BOARD_STATE_STALE",
                    f"{location}.state",
                    f"board={board_row[state_index]!r}; ledger={expected_state!r}",
                )

            expected_head = ledger_row.get("head")
            if isinstance(expected_head, str) and SHA40_RE.fullmatch(expected_head):
                head_source = (
                    board_row[head_index]
                    if head_index is not None and head_index < len(board_row)
                    else " | ".join(board_row)
                )
                board_heads = SHA40_SEARCH_RE.findall(head_source.lower())
                if not board_heads:
                    self.error(
                        "BOARD_HEAD_MISSING",
                        f"{location}.head",
                        "board row must expose the exact 40-character ledger HEAD",
                    )
                elif expected_head not in board_heads:
                    self.error(
                        "BOARD_HEAD_STALE",
                        f"{location}.head",
                        f"board heads={board_heads!r}; ledger={expected_head!r}",
                    )

            if branch_index is not None and branch_index < len(board_row):
                binding = board_row[branch_index]
                for field in ("branch", "claim"):
                    expected = ledger_row.get(field)
                    if isinstance(expected, str) and expected not in binding:
                        self.error(
                            "BOARD_BINDING_STALE",
                            f"{location}.{field}",
                            f"board binding does not contain ledger {field} {expected!r}",
                        )

    def _validate_receipt_binding(
        self,
        ledger: Mapping[str, Any],
        ledger_path: Path,
        ledger_bytes: bytes,
        receipt: Mapping[str, Any],
        receipt_path: Path,
    ) -> None:
        pointer = ledger.get("lastDispatchReceipt")
        if not isinstance(pointer, str) or not pointer:
            self.error(
                "LEDGER_RECEIPT_POINTER_MISSING",
                "ledger.lastDispatchReceipt",
                "must name the canonical latest dispatch receipt",
            )
        else:
            pointed_path = _path_from_argument(self.repo_root, pointer)
            if pointed_path != receipt_path:
                self.error(
                    "LEDGER_RECEIPT_POINTER_STALE",
                    "ledger.lastDispatchReceipt",
                    f"points to {pointed_path}; validated receipt is {receipt_path}",
                )

        receipt_ledger_path = receipt.get("ledger")
        if receipt_ledger_path is not None:
            if not isinstance(receipt_ledger_path, str) or not receipt_ledger_path:
                self.error(
                    "RECEIPT_LEDGER_PATH_TYPE",
                    "receipt.ledger",
                    "must be a non-empty path string",
                )
            elif _path_from_argument(self.repo_root, receipt_ledger_path) != ledger_path:
                self.error(
                    "RECEIPT_LEDGER_PATH_STALE",
                    "receipt.ledger",
                    f"does not bind validated ledger {ledger_path}",
                )

        ledger_revision = ledger.get("ledgerRevision", ledger.get("revision"))
        receipt_revision = receipt.get("ledgerRevision")
        if ledger_revision is not None:
            if receipt_revision is None:
                self.error(
                    "RECEIPT_LEDGER_REVISION_MISSING",
                    "receipt.ledgerRevision",
                    f"must bind ledger revision {ledger_revision!r}",
                )
            elif receipt_revision != ledger_revision:
                self.error(
                    "RECEIPT_LEDGER_REVISION_STALE",
                    "receipt.ledgerRevision",
                    f"receipt={receipt_revision!r}; ledger={ledger_revision!r}",
                )

        actual_hash = hashlib.sha256(ledger_bytes).hexdigest()
        if "ledgerSha256" not in receipt:
            self.error(
                "RECEIPT_LEDGER_HASH_MISSING",
                "receipt.ledgerSha256",
                "must bind the exact canonical ledger bytes",
            )
        for field in ("ledgerSha256", "ledgerHash"):
            if field not in receipt:
                continue
            recorded_hash = receipt[field]
            if not isinstance(recorded_hash, str) or not SHA256_RE.fullmatch(
                recorded_hash
            ):
                self.error(
                    "RECEIPT_LEDGER_HASH_TYPE",
                    f"receipt.{field}",
                    "must be a lowercase 64-character SHA-256",
                )
            elif recorded_hash != actual_hash:
                self.error(
                    "RECEIPT_LEDGER_HASH_STALE",
                    f"receipt.{field}",
                    f"receipt={recorded_hash}; actual={actual_hash}",
                )

        if receipt.get("batch") != ledger.get("batch"):
            self.error(
                "RECEIPT_BATCH_MISMATCH",
                "receipt.batch",
                f"receipt={receipt.get('batch')!r}; ledger={ledger.get('batch')!r}",
            )


def _normalize_cell(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    normalized = _normalize_token(value)
    aliases = {
        "world_rendering": "renderer",
        "rendering": "renderer",
        "playtest_quality": "qa",
        "quality": "qa",
    }
    return aliases.get(normalized, normalized)


def _normalize_token(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")


def _concrete_text(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    text = value.strip()
    return len(text) >= 8 and PLACEHOLDER_RE.fullmatch(text) is None


def _first_concrete(
    row: Mapping[str, Any], names: Iterable[str]
) -> str | None:
    for name in names:
        value = row.get(name)
        if _concrete_text(value):
            return value.strip()
    return None


def _expected_clean_state(value: Any) -> bool | None:
    if isinstance(value, bool):
        return value
    if not isinstance(value, str):
        return None
    token = _normalize_token(value)
    if token == "clean" or token.startswith("clean_"):
        return True
    if token == "dirty" or token.startswith("dirty_"):
        return False
    return None


def _parse_board_table(
    text: str,
) -> tuple[list[str], list[list[str]]] | None:
    lines = text.splitlines()
    for index, line in enumerate(lines):
        cells = _markdown_cells(line)
        if not cells or _normalize_token(cells[0]) != "cell":
            continue
        if index + 1 >= len(lines) or not _is_markdown_separator(lines[index + 1]):
            continue
        rows: list[list[str]] = []
        for candidate in lines[index + 2 :]:
            candidate_cells = _markdown_cells(candidate)
            if not candidate_cells:
                break
            rows.append(candidate_cells)
        return [_normalize_token(cell) for cell in cells], rows
    return None


def _markdown_cells(line: str) -> list[str] | None:
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return None
    return [cell.strip().strip("`") for cell in stripped[1:-1].split("|")]


def _is_markdown_separator(line: str) -> bool:
    cells = _markdown_cells(line)
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def _header_index(
    headers: Sequence[str], predicate: Any
) -> int | None:
    for index, header in enumerate(headers):
        if predicate(header):
            return index
    return None


def _board_state_matches(board_value: str, expected_state: str) -> bool:
    normalized_board = _normalize_token(board_value)
    normalized_expected = _normalize_token(expected_state)
    if normalized_board == normalized_expected:
        return True
    return f"_{normalized_expected}_" in f"_{normalized_board}_"


def _path_from_argument(repo_root: Path, value: str | Path) -> Path:
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = repo_root / path
    return path.resolve()


def _read_bytes(path: Path, label: str) -> bytes:
    try:
        return path.read_bytes()
    except OSError as exc:
        raise InputError(f"{label}: cannot read {path}: {exc}") from exc


def _read_json(path: Path, label: str) -> tuple[Mapping[str, Any], bytes]:
    raw = _read_bytes(path, label)
    try:
        value = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise InputError(f"{label}: invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, Mapping):
        raise InputError(f"{label}: top-level value in {path} must be an object")
    return value, raw


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Fail closed unless the canonical CitySim World Art ledger, board, "
            "latest dispatch receipt, and live Git worktrees agree."
        ),
        epilog=(
            "Exit codes: 0=valid, 1=state invalid, 2=CLI usage error, "
            "3=input/read/JSON error, 4=unexpected internal error."
        ),
    )
    parser.add_argument(
        "--repo-root",
        default=str(Path(__file__).resolve().parents[4]),
        help="CitySim repository root (default: inferred from this script)",
    )
    parser.add_argument(
        "--ledger",
        default=str(DEFAULT_LEDGER),
        help=f"ledger path, relative to repo root by default ({DEFAULT_LEDGER})",
    )
    parser.add_argument(
        "--board",
        default=str(DEFAULT_BOARD),
        help=f"board path, relative to repo root by default ({DEFAULT_BOARD})",
    )
    parser.add_argument(
        "--receipt",
        help=(
            "dispatch receipt path; default is the ledger's "
            "lastDispatchReceipt pointer"
        ),
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    try:
        repo_root = _path_from_argument(Path.cwd(), args.repo_root)
        if not repo_root.is_dir():
            raise InputError(f"repo-root: directory does not exist: {repo_root}")

        ledger_path = _path_from_argument(repo_root, args.ledger)
        board_path = _path_from_argument(repo_root, args.board)
        ledger, ledger_bytes = _read_json(ledger_path, "ledger")
        board_bytes = _read_bytes(board_path, "board")
        try:
            board_text = board_bytes.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise InputError(f"board: invalid UTF-8 in {board_path}: {exc}") from exc

        receipt_argument = args.receipt
        if receipt_argument is None:
            receipt_argument = ledger.get("lastDispatchReceipt")
            if not isinstance(receipt_argument, str) or not receipt_argument:
                raise InputError(
                    "receipt: --receipt omitted and ledger.lastDispatchReceipt "
                    "is missing"
                )
        receipt_path = _path_from_argument(repo_root, receipt_argument)
        receipt, _receipt_bytes = _read_json(receipt_path, "receipt")

        validator = Validator(repo_root)
        validator.validate(
            ledger,
            ledger_path,
            ledger_bytes,
            board_text,
            board_path,
            receipt,
            receipt_path,
        )
        diagnostics = sorted(set(validator.diagnostics))
        if diagnostics:
            for diagnostic in diagnostics:
                print(
                    f"ERROR {diagnostic.code} {diagnostic.location}: "
                    f"{diagnostic.message}",
                    file=sys.stderr,
                )
            print(
                f"FAIL world-art parallel state: {len(diagnostics)} error(s)",
                file=sys.stderr,
            )
            return EXIT_INVALID_STATE

        print(
            "PASS world-art parallel state: ledger, six-cell receipt, board, "
            "and live Git state agree"
        )
        return EXIT_OK
    except InputError as exc:
        print(f"INPUT_ERROR {exc}", file=sys.stderr)
        return EXIT_INPUT_ERROR
    except Exception as exc:  # pragma: no cover - fail closed at the CLI boundary.
        print(f"INTERNAL_ERROR {type(exc).__name__}: {exc}", file=sys.stderr)
        return EXIT_INTERNAL_ERROR


if __name__ == "__main__":
    raise SystemExit(main())
