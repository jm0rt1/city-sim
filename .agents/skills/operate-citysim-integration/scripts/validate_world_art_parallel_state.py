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
        "codex/citysim-world-rendering-r4b-current",
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
CLAIM_OWNED_DIRECTION_ROOTS = {
    "north": (
        Path("Native/CitySimNative/WorldArt/Blender/PLAY-027"),
        Path("Native/CitySimNative/WorldArt/ImageGen"),
        Path("docs/production/evidence/PLAY-027"),
    ),
    "east": (
        Path("Native/CitySimNative/WorldArt/Blender/PLAY-079"),
        Path("docs/production/evidence/PLAY-079"),
    ),
    "south": (
        Path("Native/CitySimNative/WorldArt/Blender/PLAY-080"),
        Path("docs/production/evidence/PLAY-080"),
    ),
    "west": (
        Path("Native/CitySimNative/WorldArt/Blender/PLAY-081"),
        Path("docs/production/evidence/PLAY-081"),
    ),
}
BROAD_EXECUTION_ROOTS = frozenset(
    {
        Path("/"),
        Path("/private"),
        Path("/private/tmp"),
        Path("/tmp"),
        Path.home().resolve(strict=False),
    }
)

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
    "parallelExecutionSchedule": (
        ("path", "sha256"),
        ("schemaPath", "schemaSha256"),
        ("validatorPath", "validatorSha256"),
    ),
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
OVERLAP_STATES = frozenset({"observed", "none", "not_applicable"})
JOIN_STATES = frozenset({"no_join_required", "waiting", "joined"})
JOB_RESOURCE_CLASSES = frozenset({"helper", "dcc"})
JOB_STATES = frozenset({"running", "completed", "failed"})
JOB_MUTATION_CLASSES = frozenset(
    {"read_only", "isolated_temp", "direction_owned"}
)
WORKSTREAM_EXEMPTION_CODES = frozenset(
    {
        "stage_prohibited_by_authority",
        "exclusive_gate_owned_elsewhere",
        "shared_surface_serialized",
        "no_stage_legal_preparation_remaining",
    }
)
UNUSED_CAPACITY_REASON_CODES = frozenset(
    {
        "authority_prohibited",
        "dependency_blocked",
        "serialized_writer",
        "completed_before_observation",
        "compute_envelope_unassigned",
        "resource_safety_limit",
    }
)
UNUSED_CAPACITY_REASON_CODES_BY_RESOURCE = {
    "helper": frozenset(
        {
            "authority_prohibited",
            "dependency_blocked",
            "serialized_writer",
            "completed_before_observation",
            "resource_safety_limit",
        }
    ),
    "dcc": frozenset(
        {
            "authority_prohibited",
            "dependency_blocked",
            "completed_before_observation",
            "compute_envelope_unassigned",
            "resource_safety_limit",
        }
    ),
}

GIT_SHA_KEYS = frozenset(
    {
        "acceptedIntegrationCommit",
        "authorityCommit",
        "base",
        "candidate",
        "head",
        "ledgerRevision",
        "observedHead",
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
        self._ancestor_cache: dict[tuple[str, str], bool] = {}
        self._commit_range_cache: dict[
            tuple[str, str],
            tuple[tuple[str, tuple[str, ...]], ...] | None,
        ] = {}

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
        self._validate_batch_bindings(ledger, ledger_rows)
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
        receipt_authority_commit = receipt.get("authorityCommit")

        for cell in EXPECTED_CELLS:
            ledger_row = ledger_rows.get(cell)
            if ledger_row is not None:
                self._validate_cell_binding(
                    cell, ledger_row, f"ledger.cells.{cell}"
                )
                self._validate_required_row_fields(
                    ledger_row, f"ledger.cells.{cell}"
                )
                self._validate_observed_head_binding(
                    ledger_row, f"ledger.cells.{cell}"
                )
                self._validate_work_row(
                    ledger_row,
                    f"ledger.cells.{cell}",
                    receipt_authority_commit,
                )
                self._validate_live_git(ledger_row, f"ledger.cells.{cell}")

            receipt_row = receipt_rows.get(cell)
            if receipt_row is not None:
                self._validate_cell_binding(
                    cell, receipt_row, f"receipt.rows.{cell}"
                )
                self._validate_required_row_fields(
                    receipt_row, f"receipt.rows.{cell}"
                )
                self._validate_observed_head_binding(
                    receipt_row, f"receipt.rows.{cell}"
                )
                if not isinstance(receipt_row.get("changedThisTurn"), bool):
                    self.error(
                        "RECEIPT_CHANGED_TYPE",
                        f"receipt.rows.{cell}.changedThisTurn",
                        "must be present on every row and be a JSON boolean",
                    )
                self._validate_work_row(
                    receipt_row,
                    f"receipt.rows.{cell}",
                    receipt_authority_commit,
                )
                self._validate_live_git(receipt_row, f"receipt.rows.{cell}")

            if ledger_row is not None and receipt_row is not None:
                self._validate_row_binding(cell, ledger_row, receipt_row)

        self._validate_timestamp(receipt.get("sentAt"), "receipt.sentAt")
        compute_envelope = receipt.get("computeEnvelope")
        self._validate_compute_envelope(compute_envelope)
        self._validate_execution_compute_bindings(receipt_rows, compute_envelope)
        self._validate_execution_root_isolation(receipt_rows)
        self._validate_execution_observation_order(
            receipt_rows, receipt.get("sentAt")
        )
        self._validate_parallel_workstream_floor(
            ledger,
            ledger_rows,
            receipt,
        )
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
        self,
        row: Mapping[str, Any],
        location: str,
        receipt_authority_commit: Any,
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

        self._validate_execution_accounting(row, location, state)

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
            self._validate_active_acknowledgement(
                row,
                location,
                receipt_authority_commit,
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

    def _validate_execution_accounting(
        self,
        row: Mapping[str, Any],
        location: str,
        dispatch_state: str,
    ) -> None:
        accounting = row.get("executionAccounting")
        accounting_location = f"{location}.executionAccounting"
        if not isinstance(accounting, Mapping):
            self.error(
                "EXECUTION_ACCOUNTING_MISSING",
                accounting_location,
                "every row must bind exact intra-lane execution accounting",
            )
            return

        expected_fields = {
            "readyNow",
            "running",
            "waitingOnJoin",
            "serializedAuthority",
            "nextRefill",
            "capacity",
            "launchedJobs",
            "unusedCapacityReasons",
            "overlap",
            "join",
        }
        missing = sorted(expected_fields - set(accounting))
        extras = sorted(set(accounting) - expected_fields)
        if missing:
            self.error(
                "EXECUTION_ACCOUNTING_FIELD_MISSING",
                accounting_location,
                "missing fields: " + ", ".join(missing),
            )
        if extras:
            self.error(
                "EXECUTION_ACCOUNTING_FIELD_EXTRA",
                accounting_location,
                "unsupported fields: " + ", ".join(extras),
            )

        list_values: dict[str, list[str]] = {}
        for field in ("readyNow", "running", "waitingOnJoin"):
            list_values[field] = self._concrete_string_list(
                accounting.get(field),
                f"{accounting_location}.{field}",
            )

        self._validate_serialized_authority(
            accounting.get("serializedAuthority"),
            f"{accounting_location}.serializedAuthority",
            row,
        )
        if not _concrete_text(accounting.get("nextRefill")):
            self.error(
                "EXECUTION_ACCOUNTING_TEXT_INVALID",
                f"{accounting_location}.nextRefill",
                "must be concrete text",
            )

        row_refill = _first_concrete(
            row,
            ("nextRefillAction", "refillAction", "nextAction", "legalPreparation"),
        )
        if (
            row_refill is not None
            and accounting.get("nextRefill") != row_refill
        ):
            self.error(
                "EXECUTION_ACCOUNTING_REFILL_MISMATCH",
                f"{accounting_location}.nextRefill",
                "must exactly match the row's canonical refill action",
            )

        capacity = accounting.get("capacity")
        capacity_location = f"{accounting_location}.capacity"
        capacity_by_resource = {resource: 0 for resource in JOB_RESOURCE_CLASSES}
        if not isinstance(capacity, Mapping):
            self.error(
                "EXECUTION_CAPACITY_INVALID",
                capacity_location,
                "must be an object with helperSlots and dccSlots",
            )
        else:
            expected_capacity_fields = {"helperSlots", "dccSlots"}
            if set(capacity) != expected_capacity_fields:
                self.error(
                    "EXECUTION_CAPACITY_FIELDS",
                    capacity_location,
                    "must contain exactly helperSlots and dccSlots",
                )
            for field in expected_capacity_fields:
                value = capacity.get(field)
                if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                    self.error(
                        "EXECUTION_CAPACITY_VALUE",
                        f"{capacity_location}.{field}",
                        "must be a non-negative integer",
                    )
                else:
                    resource = "helper" if field == "helperSlots" else "dcc"
                    capacity_by_resource[resource] = value

        jobs = self._validate_execution_jobs(
            accounting.get("launchedJobs"),
            f"{accounting_location}.launchedJobs",
            row,
        )
        if jobs and self._parse_timestamp(row.get("acknowledgedAt")) is None:
            self.error(
                "EXECUTION_JOBS_WITHOUT_ACKNOWLEDGEMENT",
                f"{location}.acknowledgedAt",
                "launched jobs require a timestamped authority acknowledgement",
            )
        launched_ids = list(jobs)
        running_ids = list_values["running"]
        ready_ids = list_values["readyNow"]
        waiting_ids = list_values["waitingOnJoin"]

        for field, identifiers in (
            ("running", running_ids),
            ("waitingOnJoin", waiting_ids),
        ):
            for index, identifier in enumerate(identifiers):
                if identifier not in jobs:
                    self.error(
                        "EXECUTION_UNKNOWN_JOB",
                        f"{accounting_location}.{field}[{index}]",
                        "must name a job present in launchedJobs",
                    )
        for identifier in set(ready_ids) & set(launched_ids):
            self.error(
                "EXECUTION_READY_ALREADY_LAUNCHED",
                f"{accounting_location}.readyNow",
                f"{identifier!r} cannot be readyNow after launch",
            )

        running_by_resource = {resource: 0 for resource in JOB_RESOURCE_CLASSES}
        for index, identifier in enumerate(running_ids):
            job = jobs.get(identifier)
            if job is None:
                continue
            if job.get("state") != "running":
                self.error(
                    "EXECUTION_RUNNING_STATE_MISMATCH",
                    f"{accounting_location}.running[{index}]",
                    "running must reference a launched job with state=running",
                )
            resource = job.get("resourceClass")
            if resource in running_by_resource:
                running_by_resource[resource] += 1
        state_running_ids = {
            identifier
            for identifier, job in jobs.items()
            if job.get("state") == "running"
        }
        if set(running_ids) != state_running_ids:
            self.error(
                "EXECUTION_RUNNING_SET_MISMATCH",
                f"{accounting_location}.running",
                "must equal the exact launchedJobs set whose state is running",
            )
        for resource in JOB_RESOURCE_CLASSES:
            if running_by_resource[resource] > capacity_by_resource[resource]:
                self.error(
                    "EXECUTION_CAPACITY_EXCEEDED",
                    f"{accounting_location}.capacity",
                    f"{running_by_resource[resource]} running {resource} jobs exceed "
                    f"declared capacity {capacity_by_resource[resource]}",
                )
            peak = self._peak_job_concurrency(
                [
                    job
                    for job in jobs.values()
                    if job.get("resourceClass") == resource
                ]
            )
            if peak > capacity_by_resource[resource]:
                self.error(
                    "EXECUTION_HISTORICAL_CAPACITY_EXCEEDED",
                    f"{accounting_location}.capacity",
                    f"bound job intervals prove peak {resource} concurrency {peak}, "
                    f"above declared capacity {capacity_by_resource[resource]}",
                )

        unused_capacity = {
            resource: capacity_by_resource[resource] - running_by_resource[resource]
            for resource in JOB_RESOURCE_CLASSES
        }
        explained_unused = self._validate_unused_capacity_reasons(
            accounting.get("unusedCapacityReasons"),
            f"{accounting_location}.unusedCapacityReasons",
            row,
            accounting.get("nextRefill"),
        )
        for resource in JOB_RESOURCE_CLASSES:
            if explained_unused[resource] != unused_capacity[resource]:
                self.error(
                    "EXECUTION_UNUSED_CAPACITY_MISMATCH",
                    f"{accounting_location}.unusedCapacityReasons",
                    f"{resource} reasons account for {explained_unused[resource]} "
                    f"slots; exact unused capacity is {unused_capacity[resource]}",
                )

        overlap = accounting.get("overlap")
        self._validate_execution_overlap(
            overlap,
            f"{accounting_location}.overlap",
            jobs,
        )

        join = accounting.get("join")
        self._validate_execution_join(
            join,
            f"{accounting_location}.join",
            waiting_ids,
            jobs,
        )

        if dispatch_state in ACTIVE_DISPATCH_STATES:
            if not running_ids:
                self.error(
                    "ACTIVE_EXECUTION_NOT_RUNNING",
                    f"{accounting_location}.running",
                    "an active row must name at least one currently running job",
                )
        elif running_ids:
            self.error(
                "INACTIVE_EXECUTION_RUNNING",
                f"{accounting_location}.running",
                "only an acknowledged active row may report running jobs",
            )

    def _validate_serialized_authority(
        self,
        value: Any,
        location: str,
        row: Mapping[str, Any],
    ) -> None:
        expected_fields = {
            "threadId",
            "branch",
            "worktree",
            "gitIndexWriter",
            "governedEvidenceWriter",
        }
        if not isinstance(value, Mapping):
            self.error(
                "EXECUTION_SERIALIZED_AUTHORITY_INVALID",
                location,
                "must be an exact visible-owner binding object",
            )
            return
        if set(value) != expected_fields:
            self.error(
                "EXECUTION_SERIALIZED_AUTHORITY_FIELDS",
                location,
                "must contain exactly " + ", ".join(sorted(expected_fields)),
            )
        expected_values = {
            "threadId": row.get("threadId"),
            "branch": row.get("branch"),
            "worktree": row.get("worktree"),
            "gitIndexWriter": row.get("threadId"),
            "governedEvidenceWriter": row.get("threadId"),
        }
        for field, expected in expected_values.items():
            if value.get(field) != expected:
                self.error(
                    "EXECUTION_SERIALIZED_AUTHORITY_MISMATCH",
                    f"{location}.{field}",
                    f"must equal the row-bound visible owner {expected!r}",
                )

    def _validate_execution_jobs(
        self,
        value: Any,
        location: str,
        row: Mapping[str, Any],
    ) -> dict[str, Mapping[str, Any]]:
        if not isinstance(value, list):
            self.error(
                "EXECUTION_JOBS_INVALID",
                location,
                "must be an array of exact job binding objects",
            )
            return {}
        expected_fields = {
            "id",
            "batch",
            "claim",
            "claimRevision",
            "publishedBase",
            "head",
            "threadId",
            "branch",
            "worktree",
            "resourceClass",
            "mutation",
            "exclusiveRoot",
            "state",
            "startedAt",
            "endedAt",
            "evidenceId",
            "dccSlot",
            "processId",
        }
        expected_bindings = {
            "batch": row.get("batch"),
            "claim": row.get("claim"),
            "claimRevision": row.get("claimRevision"),
            "publishedBase": row.get("publishedBase", row.get("base")),
            "head": row.get("observedHead", row.get("head")),
            "threadId": row.get("threadId"),
            "branch": row.get("branch"),
            "worktree": row.get("worktree"),
        }
        jobs: dict[str, Mapping[str, Any]] = {}
        owned_roots: list[tuple[str, Path]] = []
        observation_time = self._row_observation_timestamp(row)
        acknowledged_time = self._parse_timestamp(row.get("acknowledgedAt"))
        cell = _normalize_cell(row.get("direction"))
        for index, raw_job in enumerate(value):
            job_location = f"{location}[{index}]"
            if not isinstance(raw_job, Mapping):
                self.error("EXECUTION_JOB_TYPE", job_location, "must be an object")
                continue
            if set(raw_job) != expected_fields:
                self.error(
                    "EXECUTION_JOB_FIELDS",
                    job_location,
                    "must contain exactly " + ", ".join(sorted(expected_fields)),
                )
            job_id = raw_job.get("id")
            if not _concrete_text(job_id):
                self.error(
                    "EXECUTION_JOB_ID_INVALID",
                    f"{job_location}.id",
                    "must be a concrete identifier",
                )
                continue
            assert isinstance(job_id, str)
            if job_id in jobs:
                self.error(
                    "EXECUTION_JOB_ID_DUPLICATE",
                    f"{job_location}.id",
                    f"duplicates {job_id!r}",
                )
                continue
            jobs[job_id] = raw_job

            for field, expected in expected_bindings.items():
                if raw_job.get(field) != expected:
                    self.error(
                        "EXECUTION_JOB_BINDING_MISMATCH",
                        f"{job_location}.{field}",
                        f"must equal row binding {expected!r}",
                    )

            resource = raw_job.get("resourceClass")
            if resource not in JOB_RESOURCE_CLASSES:
                self.error(
                    "EXECUTION_JOB_RESOURCE_INVALID",
                    f"{job_location}.resourceClass",
                    f"must be one of {sorted(JOB_RESOURCE_CLASSES)}",
                )
            mutation = raw_job.get("mutation")
            if mutation not in JOB_MUTATION_CLASSES:
                self.error(
                    "EXECUTION_JOB_MUTATION_INVALID",
                    f"{job_location}.mutation",
                    f"must be one of {sorted(JOB_MUTATION_CLASSES)}",
                )
            state = raw_job.get("state")
            if state not in JOB_STATES:
                self.error(
                    "EXECUTION_JOB_STATE_INVALID",
                    f"{job_location}.state",
                    f"must be one of {sorted(JOB_STATES)}",
                )

            started = self._parsed_timestamp(
                raw_job.get("startedAt"), f"{job_location}.startedAt"
            )
            if (
                observation_time is not None
                and started is not None
                and started > observation_time
            ):
                self.error(
                    "EXECUTION_JOB_START_AFTER_OBSERVATION",
                    f"{job_location}.startedAt",
                    "must not be later than the row observation",
                )
            if (
                acknowledged_time is not None
                and started is not None
                and started < acknowledged_time
            ):
                self.error(
                    "EXECUTION_JOB_START_BEFORE_ACKNOWLEDGEMENT",
                    f"{job_location}.startedAt",
                    "must not precede the row authority acknowledgement",
                )
            ended_value = raw_job.get("endedAt")
            ended = None
            if state == "running":
                if ended_value is not None:
                    self.error(
                        "EXECUTION_JOB_RUNNING_ENDED",
                        f"{job_location}.endedAt",
                        "running jobs must use null endedAt",
                    )
            else:
                ended = self._parsed_timestamp(
                    ended_value, f"{job_location}.endedAt"
                )
                if started is not None and ended is not None and ended <= started:
                    self.error(
                        "EXECUTION_JOB_TIME_REVERSED",
                        f"{job_location}.endedAt",
                        "completed/failed jobs must end after startedAt",
                    )
                if (
                    observation_time is not None
                    and ended is not None
                    and ended > observation_time
                ):
                    self.error(
                        "EXECUTION_JOB_END_AFTER_OBSERVATION",
                        f"{job_location}.endedAt",
                        "must not be later than the row observation",
                    )
            evidence_id = raw_job.get("evidenceId")
            thread_bound = (
                isinstance(evidence_id, str)
                and re.fullmatch(
                    rf"thread:{re.escape(str(row.get('threadId')))}"
                    r"/turn:[A-Za-z0-9._:-]{8,}"
                    r"/item:[A-Za-z0-9._:-]{8,}",
                    evidence_id,
                )
                is not None
            )
            if not thread_bound:
                self.error(
                    "EXECUTION_JOB_EVIDENCE_INVALID",
                    f"{job_location}.evidenceId",
                    "must bind this exact visible thread turn/item",
                )

            root = raw_job.get("exclusiveRoot")
            if mutation == "read_only":
                if root is not None:
                    self.error(
                        "EXECUTION_JOB_READ_ONLY_ROOT",
                        f"{job_location}.exclusiveRoot",
                        "read_only jobs must use null exclusiveRoot",
                    )
            elif not isinstance(root, str) or not Path(root).is_absolute():
                self.error(
                    "EXECUTION_JOB_ROOT_INVALID",
                    f"{job_location}.exclusiveRoot",
                    "mutating jobs must bind an absolute exclusive root",
                )
            else:
                resolved_root = Path(root).resolve(strict=False)
                worktree = Path(str(row.get("worktree"))).resolve(strict=False)
                if resolved_root in BROAD_EXECUTION_ROOTS:
                    self.error(
                        "EXECUTION_JOB_ROOT_BROAD",
                        f"{job_location}.exclusiveRoot",
                        "must not use a filesystem, home, or shared temp root",
                    )
                if resolved_root == worktree:
                    self.error(
                        "EXECUTION_JOB_ROOT_TOO_BROAD",
                        f"{job_location}.exclusiveRoot",
                        "must not equal the lane worktree",
                    )
                if mutation == "direction_owned":
                    try:
                        relative_root = resolved_root.relative_to(worktree)
                    except ValueError:
                        self.error(
                            "EXECUTION_JOB_DIRECTION_ROOT_OUTSIDE_WORKTREE",
                            f"{job_location}.exclusiveRoot",
                            "direction_owned roots must be inside the bound worktree",
                        )
                    else:
                        allowed_roots = CLAIM_OWNED_DIRECTION_ROOTS.get(cell, ())
                        if not any(
                            relative_root == allowed
                            or allowed in relative_root.parents
                            for allowed in allowed_roots
                        ):
                            self.error(
                                "EXECUTION_JOB_DIRECTION_ROOT_UNCLAIMED",
                                f"{job_location}.exclusiveRoot",
                                "is outside the claim-owned direction roots",
                            )
                elif mutation == "isolated_temp":
                    temp_base = Path("/private/tmp").resolve(strict=False)
                    try:
                        temp_relative = resolved_root.relative_to(temp_base)
                    except ValueError:
                        self.error(
                            "EXECUTION_JOB_TEMP_ROOT_UNAPPROVED",
                            f"{job_location}.exclusiveRoot",
                            "isolated_temp roots must be beneath /private/tmp",
                        )
                    else:
                        task_token = str(row.get("claim")).strip().lower()
                        top_level = (
                            temp_relative.parts[0] if temp_relative.parts else ""
                        )
                        if (
                            not temp_relative.parts
                            or re.fullmatch(
                                r"citysim-[a-z0-9][a-z0-9._-]{2,}",
                                top_level,
                            )
                            is None
                            or re.match(
                                rf"^citysim-{re.escape(task_token)}(?:-|$)",
                                top_level,
                            )
                            is None
                        ):
                            self.error(
                                "EXECUTION_JOB_TEMP_ROOT_UNSCOPED",
                                f"{job_location}.exclusiveRoot",
                                "isolated_temp roots require a task-specific "
                                "citysim-* top-level directory bound to the claim",
                            )
                    try:
                        resolved_root.relative_to(worktree)
                    except ValueError:
                        pass
                    else:
                        self.error(
                            "EXECUTION_JOB_TEMP_ROOT_INSIDE_WORKTREE",
                            f"{job_location}.exclusiveRoot",
                            "isolated_temp roots must be outside the visible worktree",
                        )
                owned_roots.append((job_location, resolved_root))

            if resource == "dcc":
                for field in ("dccSlot", "processId"):
                    if not _concrete_text(raw_job.get(field)):
                        self.error(
                            "EXECUTION_DCC_BINDING_MISSING",
                            f"{job_location}.{field}",
                            "DCC jobs must bind the published slot and process",
                        )
            else:
                for field in ("dccSlot", "processId"):
                    if raw_job.get(field) is not None:
                        self.error(
                            "EXECUTION_HELPER_DCC_BINDING",
                            f"{job_location}.{field}",
                            "helper jobs must use null DCC bindings",
                        )

        for left_index, (left_location, left_root) in enumerate(owned_roots):
            for right_location, right_root in owned_roots[left_index + 1 :]:
                if (
                    left_root == right_root
                    or left_root in right_root.parents
                    or right_root in left_root.parents
                ):
                    self.error(
                        "EXECUTION_JOB_ROOT_OVERLAP",
                        f"{left_location}.exclusiveRoot",
                        f"overlaps {right_location}.exclusiveRoot",
                    )
        return jobs

    @staticmethod
    def _peak_job_concurrency(jobs: Sequence[Mapping[str, Any]]) -> int:
        events: list[tuple[datetime, int]] = []
        for job in jobs:
            start = Validator._parse_timestamp(job.get("startedAt"))
            end = Validator._parse_timestamp(job.get("endedAt"))
            if start is None:
                continue
            if end is None:
                if job.get("state") == "running":
                    events.append((start, 1))
                continue
            events.append((start, 1))
            events.append((end, -1))
        active = 0
        peak = 0
        for _, delta in sorted(events, key=lambda item: (item[0], item[1])):
            active += delta
            peak = max(peak, active)
        return peak

    def _validate_unused_capacity_reasons(
        self,
        value: Any,
        location: str,
        row: Mapping[str, Any],
        next_refill: Any,
    ) -> dict[str, int]:
        totals = {resource: 0 for resource in JOB_RESOURCE_CLASSES}
        if not isinstance(value, list):
            self.error(
                "EXECUTION_UNUSED_CAPACITY_INVALID",
                location,
                "must be an array of per-resource slot explanations",
            )
            return totals
        expected_fields = {
            "resourceClass",
            "slots",
            "reasonCode",
            "owner",
            "dependencyAuthority",
            "resumptionEvent",
            "nextRefillJob",
        }
        for index, item in enumerate(value):
            item_location = f"{location}[{index}]"
            if not isinstance(item, Mapping):
                self.error(
                    "EXECUTION_UNUSED_CAPACITY_ITEM",
                    item_location,
                    "must be an object",
                )
                continue
            if set(item) != expected_fields:
                self.error(
                    "EXECUTION_UNUSED_CAPACITY_FIELDS",
                    item_location,
                    "must contain exactly resourceClass, slots, reasonCode, owner, "
                    "dependencyAuthority, resumptionEvent, and nextRefillJob",
                )
            resource = item.get("resourceClass")
            if resource not in JOB_RESOURCE_CLASSES:
                self.error(
                    "EXECUTION_UNUSED_CAPACITY_RESOURCE",
                    f"{item_location}.resourceClass",
                    f"must be one of {sorted(JOB_RESOURCE_CLASSES)}",
                )
                continue
            slots = item.get("slots")
            if isinstance(slots, bool) or not isinstance(slots, int) or slots != 1:
                self.error(
                    "EXECUTION_UNUSED_CAPACITY_SLOTS",
                    f"{item_location}.slots",
                    "must equal 1 so every unused slot has its own reason entry",
                )
            else:
                totals[resource] += slots
            reason_code = item.get("reasonCode")
            if reason_code not in UNUSED_CAPACITY_REASON_CODES:
                self.error(
                    "EXECUTION_UNUSED_CAPACITY_REASON_CODE",
                    f"{item_location}.reasonCode",
                    f"must be one of {sorted(UNUSED_CAPACITY_REASON_CODES)}",
                )
            elif (
                resource in UNUSED_CAPACITY_REASON_CODES_BY_RESOURCE
                and reason_code
                not in UNUSED_CAPACITY_REASON_CODES_BY_RESOURCE[resource]
            ):
                self.error(
                    "EXECUTION_UNUSED_CAPACITY_REASON_RESOURCE",
                    f"{item_location}.reasonCode",
                    f"{reason_code!r} is not valid for {resource} capacity",
                )
            owner = item.get("owner")
            if owner not in {row.get("threadId"), "integration"}:
                self.error(
                    "EXECUTION_UNUSED_CAPACITY_OWNER",
                    f"{item_location}.owner",
                    "must name the row's visible thread or integration",
                )
            authority = item.get("dependencyAuthority")
            self._validate_exact_authority_binding(
                authority,
                f"{item_location}.dependencyAuthority",
                "EXECUTION_UNUSED_CAPACITY",
            )
            if not _concrete_text(item.get("resumptionEvent")):
                self.error(
                    "EXECUTION_UNUSED_CAPACITY_RESUMPTION",
                    f"{item_location}.resumptionEvent",
                    "must name the concrete event that makes this slot useful",
                )
            if (
                not _concrete_text(item.get("nextRefillJob"))
                or item.get("nextRefillJob") != next_refill
            ):
                self.error(
                    "EXECUTION_UNUSED_CAPACITY_REFILL",
                    f"{item_location}.nextRefillJob",
                    "must exactly match executionAccounting.nextRefill",
                )
        return totals

    def _validate_exact_authority_binding(
        self,
        value: Any,
        location: str,
        code_prefix: str,
    ) -> bool:
        if not isinstance(value, Mapping) or set(value) != {"path", "sha256"}:
            self.error(
                f"{code_prefix}_AUTHORITY_FIELDS",
                location,
                "must contain exactly path and sha256",
            )
            return False
        before = len(self.diagnostics)
        self._validate_authority_hashes(value, location)
        raw_path = value.get("path")
        raw_hash = value.get("sha256")
        if (
            not isinstance(raw_path, str)
            or not raw_path
            or not isinstance(raw_hash, str)
            or not SHA256_RE.fullmatch(raw_hash)
        ):
            self.error(
                f"{code_prefix}_AUTHORITY_INVALID",
                location,
                "must bind one readable authority file and its exact SHA-256",
            )
        return len(self.diagnostics) == before

    def _concrete_string_list(self, value: Any, location: str) -> list[str]:
        if not isinstance(value, list):
            self.error(
                "EXECUTION_LIST_INVALID",
                location,
                "must be an array of unique concrete strings",
            )
            return []
        result: list[str] = []
        seen: set[str] = set()
        for index, item in enumerate(value):
            if not _concrete_text(item):
                self.error(
                    "EXECUTION_LIST_ITEM_INVALID",
                    f"{location}[{index}]",
                    "must be concrete text",
                )
                continue
            assert isinstance(item, str)
            if item in seen:
                self.error(
                    "EXECUTION_LIST_DUPLICATE",
                    f"{location}[{index}]",
                    f"duplicates {item!r}",
                )
                continue
            seen.add(item)
            result.append(item)
        return result

    def _validate_execution_overlap(
        self,
        value: Any,
        location: str,
        launched_jobs: Mapping[str, Mapping[str, Any]],
    ) -> None:
        if not isinstance(value, Mapping):
            self.error(
                "EXECUTION_OVERLAP_INVALID",
                location,
                "must be an object",
            )
            return
        expected_fields = {"status", "jobIds", "startedAt", "endedAt", "reason"}
        if set(value) != expected_fields:
            self.error(
                "EXECUTION_OVERLAP_FIELDS",
                location,
                "must contain exactly status, jobIds, startedAt, endedAt, and reason",
            )
        status = value.get("status")
        if status not in OVERLAP_STATES:
            self.error(
                "EXECUTION_OVERLAP_STATUS",
                f"{location}.status",
                f"must be one of {sorted(OVERLAP_STATES)}",
            )
        completed_intervals: dict[str, tuple[datetime, datetime]] = {}
        for job_id, job in launched_jobs.items():
            start = self._parse_timestamp(job.get("startedAt"))
            end = self._parse_timestamp(job.get("endedAt"))
            if start is not None and end is not None:
                completed_intervals[job_id] = (start, end)
        interval_values = list(completed_intervals.values())
        actual_overlap_exists = any(
            max(left[0], right[0]) < min(left[1], right[1])
            for index, left in enumerate(interval_values)
            for right in interval_values[index + 1 :]
        )
        if actual_overlap_exists and status != "observed":
            self.error(
                "EXECUTION_OVERLAP_OMITTED",
                f"{location}.status",
                "bound completed job intervals overlap and must be reported",
            )
        jobs = self._concrete_string_list(value.get("jobIds"), f"{location}.jobIds")
        job_records: list[Mapping[str, Any]] = []
        for index, job in enumerate(jobs):
            if job not in launched_jobs:
                self.error(
                    "EXECUTION_OVERLAP_UNKNOWN_JOB",
                    f"{location}.jobIds[{index}]",
                    "must name a job present in launchedJobs",
                )
            else:
                job_records.append(launched_jobs[job])
        if not _concrete_text(value.get("reason")):
            self.error(
                "EXECUTION_OVERLAP_REASON",
                f"{location}.reason",
                "must explain the observed or absent overlap",
            )
        if status == "observed":
            if len(jobs) < 2:
                self.error(
                    "EXECUTION_OVERLAP_INSUFFICIENT_JOBS",
                    f"{location}.jobIds",
                    "observed overlap requires at least two launched jobs",
                )
            peak_sets: list[frozenset[str]] = []
            peak_size = 0
            for timestamp in sorted(
                {start for start, _ in completed_intervals.values()}
            ):
                active = frozenset(
                    job_id
                    for job_id, (start, end) in completed_intervals.items()
                    if start <= timestamp < end
                )
                if len(active) > peak_size:
                    peak_size = len(active)
                    peak_sets = [active]
                elif len(active) == peak_size and active not in peak_sets:
                    peak_sets.append(active)
            if peak_size >= 2 and frozenset(jobs) not in peak_sets:
                self.error(
                    "EXECUTION_OVERLAP_JOB_SET_INCOMPLETE",
                    f"{location}.jobIds",
                    "must name one complete maximum-concurrency job set",
                )
            reported_start = self._parsed_timestamp(
                value.get("startedAt"), f"{location}.startedAt"
            )
            reported_end = self._parsed_timestamp(
                value.get("endedAt"), f"{location}.endedAt"
            )
            if (
                reported_start is not None
                and reported_end is not None
                and reported_end <= reported_start
            ):
                self.error(
                    "EXECUTION_OVERLAP_TIME_REVERSED",
                    f"{location}.endedAt",
                    "observed overlap must end after it starts",
                )
            starts = [
                self._parse_timestamp(job.get("startedAt")) for job in job_records
            ]
            ends = [self._parse_timestamp(job.get("endedAt")) for job in job_records]
            if any(item is None for item in ends):
                self.error(
                    "EXECUTION_OVERLAP_JOB_INCOMPLETE",
                    f"{location}.jobIds",
                    "observed overlap requires completed bound job intervals",
                )
            if (
                len(job_records) >= 2
                and all(item is not None for item in starts)
                and all(item is not None for item in ends)
            ):
                actual_start = max(item for item in starts if item is not None)
                actual_end = min(item for item in ends if item is not None)
                if actual_end <= actual_start:
                    self.error(
                        "EXECUTION_OVERLAP_NOT_OBSERVED",
                        f"{location}.jobIds",
                        "the bound per-job intervals do not overlap",
                    )
                if reported_start is not None and reported_start != actual_start:
                    self.error(
                        "EXECUTION_OVERLAP_START_MISMATCH",
                        f"{location}.startedAt",
                        "must equal the latest bound job start",
                    )
                if reported_end is not None and reported_end != actual_end:
                    self.error(
                        "EXECUTION_OVERLAP_END_MISMATCH",
                        f"{location}.endedAt",
                        "must equal the earliest bound job end",
                    )
        else:
            if jobs:
                self.error(
                    "EXECUTION_OVERLAP_UNEXPECTED_JOBS",
                    f"{location}.jobIds",
                    "none/not_applicable overlap must not name overlapping jobs",
                )
            for field in ("startedAt", "endedAt"):
                if value.get(field) is not None:
                    self.error(
                        "EXECUTION_OVERLAP_UNEXPECTED_TIME",
                        f"{location}.{field}",
                        "none/not_applicable overlap must use null timestamps",
                    )

    def _validate_execution_join(
        self,
        value: Any,
        location: str,
        waiting_on_join: Sequence[str],
        launched_jobs: Mapping[str, Mapping[str, Any]],
    ) -> None:
        if not isinstance(value, Mapping):
            self.error(
                "EXECUTION_JOIN_INVALID",
                location,
                "must be an object",
            )
            return
        expected_fields = {"state", "requiredJobs", "completedJobs"}
        if set(value) != expected_fields:
            self.error(
                "EXECUTION_JOIN_FIELDS",
                location,
                "must contain exactly state, requiredJobs, and completedJobs",
            )
        state = value.get("state")
        if state not in JOIN_STATES:
            self.error(
                "EXECUTION_JOIN_STATE",
                f"{location}.state",
                f"must be one of {sorted(JOIN_STATES)}",
            )
        required = self._concrete_string_list(
            value.get("requiredJobs"), f"{location}.requiredJobs"
        )
        completed = self._concrete_string_list(
            value.get("completedJobs"), f"{location}.completedJobs"
        )
        for field, jobs in (("requiredJobs", required), ("completedJobs", completed)):
            for index, job in enumerate(jobs):
                if job not in launched_jobs:
                    self.error(
                        "EXECUTION_JOIN_UNKNOWN_JOB",
                        f"{location}.{field}[{index}]",
                        "must name a job present in launchedJobs",
                    )
        for index, job in enumerate(completed):
            record = launched_jobs.get(job)
            if record is not None and record.get("state") != "completed":
                self.error(
                    "EXECUTION_JOIN_FALSE_COMPLETION",
                    f"{location}.completedJobs[{index}]",
                    "completedJobs must resolve to state=completed jobs",
                )
        for index, job in enumerate(waiting_on_join):
            record = launched_jobs.get(job)
            if record is not None and record.get("state") != "running":
                self.error(
                    "EXECUTION_JOIN_FALSE_WAIT",
                    f"{location}.waitingOnJoin[{index}]",
                    "waitingOnJoin must resolve to state=running jobs",
                )
        failed_required = [
            job
            for job in required
            if launched_jobs.get(job, {}).get("state") == "failed"
        ]
        if failed_required:
            self.error(
                "EXECUTION_JOIN_FAILED_JOB",
                f"{location}.requiredJobs",
                "required jobs failed: " + ", ".join(failed_required),
            )
        if not set(completed).issubset(required):
            self.error(
                "EXECUTION_JOIN_COMPLETION_MISMATCH",
                f"{location}.completedJobs",
                "completedJobs must be a subset of requiredJobs",
            )
        if state == "waiting":
            if not waiting_on_join:
                self.error(
                    "EXECUTION_JOIN_WAIT_MISMATCH",
                    f"{location}.state",
                    "waiting join state requires waitingOnJoin jobs",
                )
            if set(waiting_on_join) != set(required) - set(completed):
                self.error(
                    "EXECUTION_JOIN_WAIT_SET_MISMATCH",
                    f"{location}.requiredJobs",
                    "waitingOnJoin must equal requiredJobs minus completedJobs",
                )
        elif waiting_on_join:
            self.error(
                "EXECUTION_JOIN_UNEXPECTED_WAIT",
                f"{location}.state",
                "non-waiting join state cannot carry waitingOnJoin jobs",
            )
        if state == "joined":
            if set(required) != set(completed):
                self.error(
                    "EXECUTION_JOIN_INCOMPLETE",
                    f"{location}.completedJobs",
                    "joined state requires every required job completed",
                )
            elif any(
                launched_jobs.get(job, {}).get("state") != "completed"
                for job in required
            ):
                self.error(
                    "EXECUTION_JOIN_STATE_INCOMPLETE",
                    f"{location}.completedJobs",
                    "joined state requires state=completed for every required job",
                )
        if state == "no_join_required" and (required or completed):
            self.error(
                "EXECUTION_JOIN_UNEXPECTED_JOBS",
                location,
                "no_join_required must use empty required/completed jobs",
            )

    def _validate_execution_compute_bindings(
        self,
        rows: Mapping[str, Mapping[str, Any]],
        envelope: Any,
    ) -> None:
        if not isinstance(envelope, Mapping):
            return
        maximum = envelope.get("maximumSimultaneousDCCProcesses")
        if isinstance(maximum, bool) or not isinstance(maximum, int) or maximum < 0:
            return
        raw_slots = envelope.get("assignedSlots")
        if not isinstance(raw_slots, list):
            return
        slots: dict[str, Mapping[str, Any]] = {}
        slots_by_cell = {cell: 0 for cell in EXPECTED_CELLS}
        for raw_slot in raw_slots:
            if not isinstance(raw_slot, Mapping):
                continue
            slot_id = raw_slot.get("slot")
            cell = _normalize_cell(raw_slot.get("direction"))
            if isinstance(slot_id, str) and slot_id and cell in slots_by_cell:
                slots[slot_id] = raw_slot
                slots_by_cell[cell] += 1

        running_dcc = 0
        jobs_by_slot: dict[str, list[Mapping[str, Any]]] = {}
        for cell, row in rows.items():
            accounting = row.get("executionAccounting")
            if not isinstance(accounting, Mapping):
                continue
            capacity = accounting.get("capacity")
            if isinstance(capacity, Mapping):
                declared = capacity.get("dccSlots")
                if declared != slots_by_cell[cell]:
                    self.error(
                        "EXECUTION_DCC_CAPACITY_ENVELOPE_MISMATCH",
                        f"receipt.rows.{cell}.executionAccounting.capacity.dccSlots",
                        f"declared={declared!r}; assigned envelope slots="
                        f"{slots_by_cell[cell]}",
                    )
            jobs = accounting.get("launchedJobs")
            if not isinstance(jobs, list):
                continue
            for index, job in enumerate(jobs):
                if not isinstance(job, Mapping) or job.get("resourceClass") != "dcc":
                    continue
                if job.get("state") == "running":
                    running_dcc += 1
                slot_id = job.get("dccSlot")
                slot = slots.get(slot_id) if isinstance(slot_id, str) else None
                location = (
                    f"receipt.rows.{cell}.executionAccounting.launchedJobs[{index}]"
                )
                if slot is None:
                    self.error(
                        "EXECUTION_DCC_SLOT_UNASSIGNED",
                        f"{location}.dccSlot",
                        "must bind an assigned compute-envelope slot",
                    )
                    continue
                jobs_by_slot.setdefault(slot_id, []).append(job)
                if _normalize_cell(slot.get("direction")) != cell:
                    self.error(
                        "EXECUTION_DCC_SLOT_DIRECTION_MISMATCH",
                        f"{location}.dccSlot",
                        "slot direction does not match the row",
                    )
                if slot.get("claim") != row.get("claim"):
                    self.error(
                        "EXECUTION_DCC_SLOT_CLAIM_MISMATCH",
                        f"{location}.dccSlot",
                        "slot claim does not match the row",
                    )
                if slot.get("processID") != job.get("processId"):
                    self.error(
                        "EXECUTION_DCC_PROCESS_MISMATCH",
                        f"{location}.processId",
                        "must match the compute-envelope processID",
                    )
        for slot_id, slot_jobs in jobs_by_slot.items():
            if len(slot_jobs) > 1:
                self.error(
                    "EXECUTION_DCC_SLOT_REUSED",
                    "receipt.computeEnvelope.assignedSlots",
                    f"slot {slot_id!r} is bound to {len(slot_jobs)} DCC jobs; "
                    "one-attempt slots are exclusive",
                )
            if self._peak_job_concurrency(slot_jobs) > 1:
                self.error(
                    "EXECUTION_DCC_SLOT_OVERLAP",
                    "receipt.computeEnvelope.assignedSlots",
                    f"slot {slot_id!r} has overlapping DCC job intervals",
                )
        if running_dcc > maximum:
            self.error(
                "EXECUTION_DCC_GLOBAL_CAP_EXCEEDED",
                "receipt.computeEnvelope.maximumSimultaneousDCCProcesses",
                f"{running_dcc} running DCC jobs exceed global cap {maximum}",
            )

    def _validate_execution_root_isolation(
        self,
        rows: Mapping[str, Mapping[str, Any]],
    ) -> None:
        roots: list[tuple[str, str, str, Path, Path | None]] = []
        worktrees = {
            cell: Path(str(row.get("worktree"))).resolve(strict=False)
            for cell, row in rows.items()
        }
        for cell, row in rows.items():
            accounting = row.get("executionAccounting")
            if not isinstance(accounting, Mapping):
                continue
            jobs = accounting.get("launchedJobs")
            if not isinstance(jobs, list):
                continue
            worktree = Path(str(row.get("worktree"))).resolve(strict=False)
            for index, job in enumerate(jobs):
                if not isinstance(job, Mapping):
                    continue
                root = job.get("exclusiveRoot")
                if not isinstance(root, str) or not Path(root).is_absolute():
                    continue
                resolved = Path(root).resolve(strict=False)
                logical: Path | None = None
                if job.get("mutation") == "direction_owned":
                    try:
                        logical = resolved.relative_to(worktree)
                    except ValueError:
                        logical = None
                roots.append(
                    (
                        f"receipt.rows.{cell}.executionAccounting."
                        f"launchedJobs[{index}].exclusiveRoot",
                        cell,
                        str(job.get("mutation")),
                        resolved,
                        logical,
                    )
                )
        for location, owner_cell, mutation, root, _ in roots:
            for worktree_cell, worktree in worktrees.items():
                overlaps_worktree = (
                    root == worktree
                    or root in worktree.parents
                    or worktree in root.parents
                )
                own_direction_root = (
                    mutation == "direction_owned" and owner_cell == worktree_cell
                )
                if overlaps_worktree and not own_direction_root:
                    self.error(
                        "EXECUTION_JOB_ROOT_OVERLAPS_WORKTREE",
                        location,
                        f"overlaps canonical {worktree_cell} worktree {worktree}",
                    )
        for left_index, (
            left_location,
            _,
            _,
            left_root,
            left_logical,
        ) in enumerate(roots):
            for (
                right_location,
                _,
                _,
                right_root,
                right_logical,
            ) in roots[left_index + 1 :]:
                physical_overlap = (
                    left_root == right_root
                    or left_root in right_root.parents
                    or right_root in left_root.parents
                )
                logical_overlap = (
                    left_logical is not None
                    and right_logical is not None
                    and (
                        left_logical == right_logical
                        or left_logical in right_logical.parents
                        or right_logical in left_logical.parents
                    )
                )
                if physical_overlap or logical_overlap:
                    self.error(
                        "EXECUTION_CROSS_ROW_ROOT_OVERLAP",
                        left_location,
                        f"overlaps {right_location}",
                    )

    def _validate_execution_observation_order(
        self,
        rows: Mapping[str, Mapping[str, Any]],
        sent_at_value: Any,
    ) -> None:
        sent_at = self._parse_timestamp(sent_at_value)
        if sent_at is None:
            return
        for cell, row in rows.items():
            observation = self._row_observation_timestamp(row)
            acknowledged = self._parse_timestamp(row.get("acknowledgedAt"))
            if (
                acknowledged is not None
                and observation is not None
                and acknowledged > observation
            ):
                self.error(
                    "ROW_ACKNOWLEDGEMENT_AFTER_OBSERVATION",
                    f"receipt.rows.{cell}.acknowledgedAt",
                    "authority acknowledgement must not postdate row observation",
                )
            if observation is not None and observation > sent_at:
                self.error(
                    "ROW_OBSERVATION_AFTER_DISPATCH",
                    f"receipt.rows.{cell}.observation",
                    "row observation must not postdate receipt.sentAt",
                )

    def _validate_parallel_workstream_floor(
        self,
        ledger: Mapping[str, Any],
        ledger_rows: Mapping[str, Mapping[str, Any]],
        receipt: Mapping[str, Any],
    ) -> None:
        batch_state = ledger.get("batchState")
        eligible_cells: list[str] = []
        active_cells: list[str] = []
        for cell in EXPECTED_CELLS:
            row = ledger_rows.get(cell)
            if row is None:
                continue
            dispatch_state = _normalize_token(str(row.get("dispatchState", "")))
            exemption = row.get("parallelismExemption")
            exempt = False
            if exemption is not None:
                if dispatch_state in ACTIVE_DISPATCH_STATES:
                    self.error(
                        "PARALLELISM_ACTIVE_ROW_EXEMPT",
                        f"ledger.cells.{cell}.parallelismExemption",
                        "an active acknowledged row cannot also claim exemption",
                    )
                elif dispatch_state not in INACTIVE_DISPATCH_STATES:
                    self.error(
                        "PARALLELISM_EXEMPTION_STATE",
                        f"ledger.cells.{cell}.parallelismExemption",
                        "only an idle, returned, blocked, or completed row may "
                        "claim a stage exemption",
                    )
                else:
                    exempt = self._validate_parallelism_exemption(
                        exemption,
                        f"ledger.cells.{cell}.parallelismExemption",
                        row,
                        batch_state,
                    )
            if not exempt:
                eligible_cells.append(cell)
            if dispatch_state in ACTIVE_DISPATCH_STATES:
                acknowledgement = row.get("authorityAcknowledgement")
                running = (
                    row.get("executionAccounting", {}).get("running", [])
                    if isinstance(row.get("executionAccounting"), Mapping)
                    else []
                )
                if isinstance(acknowledgement, Mapping) and running:
                    active_cells.append(cell)

        required = min(3, len(eligible_cells))
        if len(active_cells) < required:
            self.error(
                "PARALLELISM_ACTIVE_FLOOR",
                "ledger.cells",
                f"{len(eligible_cells)} rows are eligible but only "
                f"{len(active_cells)} carry acknowledged running work; "
                f"at least {required} are required",
            )

        ledger_proof = ledger.get("parallelismProof")
        receipt_proof = receipt.get("parallelismProof")
        if required and not isinstance(ledger_proof, Mapping):
            self.error(
                "PARALLELISM_PROOF_MISSING",
                "ledger.parallelismProof",
                "three-or-more eligible rows require a cross-row interval proof",
            )
        if ledger_proof is None:
            if receipt_proof is not None:
                self.error(
                    "PARALLELISM_PROOF_RECEIPT_EXTRA",
                    "receipt.parallelismProof",
                    "receipt cannot project a proof absent from the ledger",
                )
            return
        if receipt_proof != ledger_proof:
            self.error(
                "PARALLELISM_PROOF_RECEIPT_MISMATCH",
                "receipt.parallelismProof",
                "must exactly project ledger.parallelismProof",
            )
        self._validate_parallelism_proof(
            ledger_proof,
            "ledger.parallelismProof",
            ledger_rows,
            eligible_cells,
            required,
        )

    def _validate_parallelism_exemption(
        self,
        value: Any,
        location: str,
        row: Mapping[str, Any],
        batch_state: Any,
    ) -> bool:
        expected_fields = {
            "reasonCode",
            "stageProhibition",
            "owner",
            "dependencyAuthority",
            "resumptionEvent",
            "nextRefillJob",
        }
        if not isinstance(value, Mapping) or set(value) != expected_fields:
            self.error(
                "PARALLELISM_EXEMPTION_FIELDS",
                location,
                "must contain exactly reasonCode, stageProhibition, owner, "
                "dependencyAuthority, resumptionEvent, and nextRefillJob",
            )
            return False
        valid = True
        if value.get("reasonCode") not in WORKSTREAM_EXEMPTION_CODES:
            self.error(
                "PARALLELISM_EXEMPTION_REASON_CODE",
                f"{location}.reasonCode",
                f"must be one of {sorted(WORKSTREAM_EXEMPTION_CODES)}",
            )
            valid = False

        prohibition = value.get("stageProhibition")
        if (
            not isinstance(prohibition, Mapping)
            or set(prohibition) != {"batchState", "rule"}
        ):
            self.error(
                "PARALLELISM_EXEMPTION_PROHIBITION_FIELDS",
                f"{location}.stageProhibition",
                "must contain exactly batchState and rule",
            )
            valid = False
        else:
            if prohibition.get("batchState") != batch_state:
                self.error(
                    "PARALLELISM_EXEMPTION_BATCH_STATE",
                    f"{location}.stageProhibition.batchState",
                    f"must equal current ledger batchState {batch_state!r}",
                )
                valid = False
            if not _concrete_text(prohibition.get("rule")):
                self.error(
                    "PARALLELISM_EXEMPTION_RULE",
                    f"{location}.stageProhibition.rule",
                    "must name the exact stage rule that prohibits useful work",
                )
                valid = False

        owner = value.get("owner")
        expected_owner_fields = {"role", "id"}
        if not isinstance(owner, Mapping) or set(owner) != expected_owner_fields:
            self.error(
                "PARALLELISM_EXEMPTION_OWNER_FIELDS",
                f"{location}.owner",
                "must contain exactly role and id",
            )
            valid = False
        else:
            role = owner.get("role")
            owner_id = owner.get("id")
            expected_ids = {
                "integration": "integration",
                "cell": row.get("threadId"),
            }
            if role not in expected_ids or owner_id != expected_ids.get(role):
                self.error(
                    "PARALLELISM_EXEMPTION_OWNER",
                    f"{location}.owner",
                    "must bind Integration or this row's visible thread",
                )
                valid = False

        if not self._validate_exact_authority_binding(
            value.get("dependencyAuthority"),
            f"{location}.dependencyAuthority",
            "PARALLELISM_EXEMPTION",
        ):
            valid = False
        if not _concrete_text(value.get("resumptionEvent")):
            self.error(
                "PARALLELISM_EXEMPTION_RESUMPTION",
                f"{location}.resumptionEvent",
                "must name the concrete authority event that resumes the row",
            )
            valid = False
        accounting = row.get("executionAccounting")
        next_refill = (
            accounting.get("nextRefill")
            if isinstance(accounting, Mapping)
            else None
        )
        if (
            not _concrete_text(value.get("nextRefillJob"))
            or value.get("nextRefillJob") != next_refill
        ):
            self.error(
                "PARALLELISM_EXEMPTION_REFILL",
                f"{location}.nextRefillJob",
                "must exactly match executionAccounting.nextRefill",
            )
            valid = False
        return valid

    def _validate_parallelism_proof(
        self,
        value: Any,
        location: str,
        rows: Mapping[str, Mapping[str, Any]],
        eligible_cells: Sequence[str],
        required: int,
    ) -> None:
        expected_fields = {
            "requiredConcurrentCells",
            "eligibleCells",
            "jobRefs",
            "startedAt",
            "endedAt",
        }
        if not isinstance(value, Mapping) or set(value) != expected_fields:
            self.error(
                "PARALLELISM_PROOF_FIELDS",
                location,
                "must contain exactly requiredConcurrentCells, eligibleCells, "
                "jobRefs, startedAt, and endedAt",
            )
            return
        proof_required = value.get("requiredConcurrentCells")
        expected_required = required if required else None
        if (
            isinstance(proof_required, bool)
            or not isinstance(proof_required, int)
            or (
                expected_required is not None
                and proof_required != expected_required
            )
            or (
                expected_required is None
                and proof_required not in {1, 2, 3}
            )
        ):
            self.error(
                "PARALLELISM_PROOF_REQUIRED_COUNT",
                f"{location}.requiredConcurrentCells",
                (
                    f"must equal derived floor {expected_required}"
                    if expected_required is not None
                    else "a retained historical proof must bind 1, 2, or 3 cells"
                ),
            )

        proof_eligible = value.get("eligibleCells")
        if (
            not isinstance(proof_eligible, list)
            or not proof_eligible
            or any(not isinstance(cell, str) for cell in proof_eligible)
            or len(proof_eligible) != len(set(proof_eligible))
            or any(cell not in EXPECTED_CELL_SET for cell in proof_eligible)
        ):
            self.error(
                "PARALLELISM_PROOF_ELIGIBLE_CELLS",
                f"{location}.eligibleCells",
                "must be a non-empty unique canonical cell list",
            )
            proof_eligible = []
        elif required and proof_eligible != list(eligible_cells):
            self.error(
                "PARALLELISM_PROOF_ELIGIBLE_CELLS",
                f"{location}.eligibleCells",
                f"must equal current derived eligible cells "
                f"{list(eligible_cells)!r}",
            )

        started = self._parsed_timestamp(
            value.get("startedAt"), f"{location}.startedAt"
        )
        ended = self._parsed_timestamp(
            value.get("endedAt"), f"{location}.endedAt"
        )
        refs = value.get("jobRefs")
        if not isinstance(refs, list):
            self.error(
                "PARALLELISM_PROOF_JOB_REFS",
                f"{location}.jobRefs",
                "must be an array of cross-row job references",
            )
            return

        intervals: list[tuple[str, datetime, datetime]] = []
        seen_cells: set[str] = set()
        seen_refs: set[tuple[str, str]] = set()
        for index, raw_ref in enumerate(refs):
            ref_location = f"{location}.jobRefs[{index}]"
            if not isinstance(raw_ref, Mapping) or set(raw_ref) != {
                "cell",
                "jobId",
            }:
                self.error(
                    "PARALLELISM_PROOF_JOB_REF_FIELDS",
                    ref_location,
                    "must contain exactly cell and jobId",
                )
                continue
            cell = _normalize_cell(raw_ref.get("cell"))
            job_id = raw_ref.get("jobId")
            if cell not in proof_eligible or not _concrete_text(job_id):
                self.error(
                    "PARALLELISM_PROOF_JOB_REF_INVALID",
                    ref_location,
                    "must bind one concrete job in a proof-eligible cell",
                )
                continue
            key = (cell, str(job_id))
            if key in seen_refs:
                self.error(
                    "PARALLELISM_PROOF_JOB_REF_DUPLICATE",
                    ref_location,
                    f"duplicates {key!r}",
                )
                continue
            seen_refs.add(key)
            row = rows.get(cell)
            accounting = (
                row.get("executionAccounting")
                if isinstance(row, Mapping)
                else None
            )
            jobs = (
                accounting.get("launchedJobs")
                if isinstance(accounting, Mapping)
                else None
            )
            matching = [
                job
                for job in jobs or []
                if isinstance(job, Mapping) and job.get("id") == job_id
            ]
            if len(matching) != 1:
                self.error(
                    "PARALLELISM_PROOF_JOB_UNKNOWN",
                    ref_location,
                    "must resolve to exactly one launchedJobs entry",
                )
                continue
            job = matching[0]
            job_start = self._parse_timestamp(job.get("startedAt"))
            job_end = self._parse_timestamp(job.get("endedAt"))
            if job_end is None and job.get("state") == "running" and row is not None:
                job_end = self._row_observation_timestamp(row)
            if job_start is None or job_end is None or job_end <= job_start:
                self.error(
                    "PARALLELISM_PROOF_JOB_INTERVAL",
                    ref_location,
                    "job must provide a positive observed interval",
                )
                continue
            intervals.append((cell, job_start, job_end))
            seen_cells.add(cell)

        if proof_required and len(seen_cells) < proof_required:
            self.error(
                "PARALLELISM_PROOF_CELL_COUNT",
                f"{location}.jobRefs",
                f"must prove jobs in at least {proof_required} distinct cells",
            )
        if not intervals:
            return
        derived_start = max(item[1] for item in intervals)
        derived_end = min(item[2] for item in intervals)
        if derived_end <= derived_start:
            self.error(
                "PARALLELISM_PROOF_INTERVAL_EMPTY",
                location,
                "referenced cross-cell job intervals never overlap",
            )
            return
        if started != derived_start or ended != derived_end:
            self.error(
                "PARALLELISM_PROOF_INTERVAL_MISMATCH",
                location,
                f"must equal derived overlap "
                f"{derived_start.isoformat()} through {derived_end.isoformat()}",
            )

    @staticmethod
    def _row_observation_timestamp(row: Mapping[str, Any]) -> datetime | None:
        present = [
            row.get(field)
            for field in ("liveObservationAt", "observedAt", "updatedAt")
            if row.get(field) is not None
        ]
        if len(present) != 1:
            return None
        return Validator._parse_timestamp(present[0])

    def _validate_required_row_fields(
        self, row: Mapping[str, Any], location: str
    ) -> None:
        for field in (
            "batch",
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

        observation_fields = [
            field
            for field in ("liveObservationAt", "observedAt", "updatedAt")
            if row.get(field) is not None
        ]
        if not observation_fields:
            self.error(
                "ROW_OBSERVATION_MISSING",
                location,
                "must record a live observation timestamp",
            )
        else:
            if len(observation_fields) != 1:
                self.error(
                    "ROW_OBSERVATION_ALIAS_COUNT",
                    location,
                    "must use exactly one of liveObservationAt, observedAt, or "
                    "updatedAt",
                )
            for field in observation_fields:
                self._validate_timestamp(
                    row.get(field), f"{location}.{field}"
                )

        acknowledged_at = row.get("acknowledgedAt")
        if acknowledged_at is not None:
            self._validate_timestamp(
                acknowledged_at, f"{location}.acknowledgedAt"
            )

    def _validate_batch_bindings(
        self,
        ledger: Mapping[str, Any],
        rows: Mapping[str, Mapping[str, Any]],
    ) -> None:
        batch = ledger.get("batch")
        if not _concrete_text(batch):
            self.error(
                "BATCH_BINDING_MISSING",
                "ledger.batch",
                "must name the exact active family or release batch",
            )
            return
        for cell, row in rows.items():
            if row.get("batch") != batch:
                self.error(
                    "ROW_BATCH_MISMATCH",
                    f"ledger.cells.{cell}.batch",
                    f"must bind the ledger batch {batch!r}",
                )

    def _validate_active_acknowledgement(
        self,
        row: Mapping[str, Any],
        location: str,
        receipt_authority_commit: Any,
    ) -> None:
        acknowledgement = row.get("authorityAcknowledgement")
        acknowledgement_location = f"{location}.authorityAcknowledgement"
        if not isinstance(acknowledgement, Mapping):
            self.error(
                "ACTIVE_ACK_EVIDENCE_MISSING",
                acknowledgement_location,
                "active work must bind exact visible-thread acknowledgement evidence",
            )
            return
        for field in (
            "threadId",
            "authorityCommit",
            "claimRevision",
            "acknowledgedAt",
            "evidenceId",
            "boundedDeliverable",
            "stopCondition",
        ):
            if not _concrete_text(acknowledgement.get(field)):
                self.error(
                    "ACTIVE_ACK_EVIDENCE_FIELD",
                    f"{acknowledgement_location}.{field}",
                    "must be concrete",
                )
        for field in (
            "threadId",
            "claimRevision",
            "acknowledgedAt",
            "boundedDeliverable",
            "stopCondition",
        ):
            if acknowledgement.get(field) != row.get(field):
                self.error(
                    "ACTIVE_ACK_EVIDENCE_MISMATCH",
                    f"{acknowledgement_location}.{field}",
                    f"must exactly match row {field}",
                )
        evidence_id = acknowledgement.get("evidenceId")
        if not (
            isinstance(evidence_id, str)
            and re.fullmatch(
                rf"thread:{re.escape(str(row.get('threadId')))}"
                r"/turn:[A-Za-z0-9._:-]{8,}"
                r"/item:[A-Za-z0-9._:-]{8,}",
                evidence_id,
            )
            is not None
        ):
            self.error(
                "ACTIVE_ACK_EVIDENCE_INVALID",
                f"{acknowledgement_location}.evidenceId",
                "must bind this exact visible thread turn/item",
            )
        if acknowledgement.get("authorityCommit") != receipt_authority_commit:
            self.error(
                "ACTIVE_ACK_AUTHORITY_COMMIT_MISMATCH",
                f"{acknowledgement_location}.authorityCommit",
                "must exactly match the dispatch receipt authorityCommit",
            )
        self._validate_timestamp(
            acknowledgement.get("acknowledgedAt"),
            f"{acknowledgement_location}.acknowledgedAt",
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
        schedule_ready = self._authority_is_concrete(
            family_authority, "parallelExecutionSchedule"
        )
        if batch_state in {
            "abc_active",
            "4of4_ready",
            "exact_candidate_qa",
            "integrated",
        } and not (appearance_ready and profile_ready and schedule_ready):
            self.error(
                "BATCH_SOURCE_AUTHORITY_PRECONDITION",
                "ledger.batchState",
                "abc_active and later require concrete appearance lock and "
                "source production profile plus validated parallel execution "
                "schedule authorities",
            )

        for cell, state in direction_states.items():
            row = rows[cell]
            if state in {
                "source_candidate",
                "integration_admitted",
                "renderer_quarantined",
            } and not (appearance_ready and profile_ready and schedule_ready):
                self.error(
                    "DIRECTION_SOURCE_AUTHORITY_PRECONDITION",
                    f"ledger.cells.{cell}.state",
                    "source_candidate and later require concrete appearance "
                    "lock, source production profile, and validated parallel "
                    "execution schedule authorities",
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

        if all_quarantined and renderer_state not in {
            "quarantining",
            "4of4_assembled",
        }:
            self.error(
                "ALL4_QUARANTINED_REQUIRES_ASSEMBLY_DISPATCH",
                "ledger.cells.renderer.state",
                "the fourth quarantined direction must trigger same-turn "
                "Renderer assembly dispatch",
            )
        renderer_row = rows.get("renderer", {})
        if all_quarantined and renderer_state == "quarantining":
            self._validate_row_artifact(
                renderer_row,
                "assemblyManifest",
                "ledger.cells.renderer.assemblyManifest",
            )
        if renderer_state == "4of4_assembled":
            self._validate_row_artifact(
                renderer_row,
                "rendererCandidateReceipt",
                "ledger.cells.renderer.rendererCandidateReceipt",
            )

        qa_row = rows.get("qa", {})
        if qa_state == "exact_candidate_active":
            self._validate_row_artifact(
                qa_row,
                "qaGateLease",
                "ledger.cells.qa.qaGateLease",
            )
        elif qa_state == "passed":
            self._validate_row_artifact(
                qa_row,
                "qaGateResult",
                "ledger.cells.qa.qaGateResult",
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
            "parallelExecutionSchedule",
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
        assigned_work: set[str] = set()
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
                identifier = f"{direction}:{attempt_id}:{process_id}"
                identifiers.append(identifier)
                if identifier in assigned_work:
                    self.error(
                        "COMPUTE_SLOT_WORK_DUPLICATE",
                        slot_location,
                        f"duplicate assigned work identity {identifier!r}",
                    )
                else:
                    assigned_work.add(identifier)
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

    @staticmethod
    def _parse_timestamp(value: Any) -> datetime | None:
        if not isinstance(value, str) or not value:
            return None
        candidate = value[:-1] + "+00:00" if value.endswith("Z") else value
        try:
            parsed = datetime.fromisoformat(candidate)
        except ValueError:
            return None
        return parsed if parsed.tzinfo is not None else None

    def _parsed_timestamp(self, value: Any, location: str) -> datetime | None:
        if not isinstance(value, str) or not value:
            self.error("TIMESTAMP_MISSING", location, "must be an ISO-8601 timestamp")
            return None
        candidate = value[:-1] + "+00:00" if value.endswith("Z") else value
        try:
            parsed = datetime.fromisoformat(candidate)
        except ValueError:
            self.error(
                "TIMESTAMP_INVALID",
                location,
                f"not ISO-8601: {value!r}",
            )
            return None
        if parsed.tzinfo is None:
            self.error(
                "TIMESTAMP_TIMEZONE_MISSING",
                location,
                "must include a timezone",
            )
            return None
        return parsed

    def _validate_timestamp(self, value: Any, location: str) -> None:
        self._parsed_timestamp(value, location)

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

    def _validate_observed_head_binding(
        self,
        row: Mapping[str, Any],
        location: str,
    ) -> None:
        """Separate immutable job observation from the live receipt candidate.

        A worker cannot know the commit that will contain its own receipt while
        it is executing jobs. `observedHead` therefore binds the exact snapshot
        those jobs tested, while `head` binds the later clean receipt candidate
        that Integration is considering. The intervening range is admissible
        only when it is ancestral and evidence-only for the row's PLAY claim.
        """

        observed = row.get("observedHead")
        if observed is None:
            return
        head = row.get("head")
        if (
            not isinstance(observed, str)
            or SHA40_RE.fullmatch(observed) is None
            or not isinstance(head, str)
            or SHA40_RE.fullmatch(head) is None
        ):
            self.error(
                "GIT_OBSERVED_HEAD_INVALID",
                f"{location}.observedHead",
                "observedHead and head must both be exact 40-character Git SHAs",
            )
            return
        if observed == head:
            self.error(
                "GIT_OBSERVED_HEAD_REDUNDANT",
                f"{location}.observedHead",
                "omit observedHead when jobs and the live row bind the same commit",
            )
            return

        accounting = row.get("executionAccounting")
        jobs = (
            accounting.get("launchedJobs")
            if isinstance(accounting, Mapping)
            else None
        )
        if not isinstance(jobs, list) or not jobs:
            self.error(
                "GIT_OBSERVED_HEAD_WITHOUT_JOBS",
                f"{location}.observedHead",
                "is allowed only when the row retains launched job evidence",
            )

        if not self._commit_is_ancestor(observed, head):
            self.error(
                "GIT_OBSERVED_HEAD_NOT_ANCESTOR",
                f"{location}.observedHead",
                f"{observed} must be an ancestor of live receipt head {head}",
            )
            return

        commit_changes = self._commit_range_changes(observed, head)
        if commit_changes is None:
            self.error(
                "GIT_OBSERVED_HEAD_DIFF_UNREADABLE",
                f"{location}.observedHead",
                f"could not inspect {observed}..{head}",
            )
            return
        claim = row.get("claim")
        if not isinstance(claim, str) or re.fullmatch(r"PLAY-\d{3}", claim) is None:
            self.error(
                "GIT_OBSERVED_HEAD_CLAIM_INVALID",
                f"{location}.claim",
                "observedHead evidence admission requires one PLAY-### claim",
            )
            return
        allowed_root = f"docs/production/evidence/{claim}/"
        if not commit_changes or not any(paths for _, paths in commit_changes):
            self.error(
                "GIT_OBSERVED_HEAD_EMPTY_RANGE",
                f"{location}.observedHead",
                "the observed-to-live range must contain the receipt evidence",
            )
        forbidden = [
            f"{commit}:{path}"
            for commit, paths in commit_changes
            for path in paths
            if not path.startswith(allowed_root)
        ]
        if forbidden:
            self.error(
                "GIT_OBSERVED_HEAD_NON_EVIDENCE_DELTA",
                f"{location}.observedHead",
                "every commit and merge-parent delta in the observed-to-live "
                "range may change only claim-owned evidence; "
                f"found {forbidden!r}",
            )

    def _commit_is_ancestor(self, ancestor: str, descendant: str) -> bool:
        key = (ancestor, descendant)
        if key in self._ancestor_cache:
            return self._ancestor_cache[key]
        result = subprocess.run(
            [
                "git",
                "-C",
                str(self.repo_root),
                "merge-base",
                "--is-ancestor",
                ancestor,
                descendant,
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        value = result.returncode == 0
        self._ancestor_cache[key] = value
        return value

    def _commit_range_changes(
        self,
        ancestor: str,
        descendant: str,
    ) -> tuple[tuple[str, tuple[str, ...]], ...] | None:
        key = (ancestor, descendant)
        if key in self._commit_range_cache:
            return self._commit_range_cache[key]
        commits_result = subprocess.run(
            [
                "git",
                "-C",
                str(self.repo_root),
                "rev-list",
                "--reverse",
                f"{ancestor}..{descendant}",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if commits_result.returncode != 0:
            self._commit_range_cache[key] = None
            return None
        changes: list[tuple[str, tuple[str, ...]]] = []
        for commit in (
            line for line in commits_result.stdout.splitlines() if line
        ):
            paths_result = subprocess.run(
                [
                    "git",
                    "-C",
                    str(self.repo_root),
                    "diff-tree",
                    "--root",
                    "--no-commit-id",
                    "--name-only",
                    "-r",
                    "-m",
                    commit,
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            if paths_result.returncode != 0:
                self._commit_range_cache[key] = None
                return None
            paths = tuple(
                sorted(
                    {
                        line
                        for line in paths_result.stdout.splitlines()
                        if line
                    }
                )
            )
            changes.append((commit, paths))
        result = tuple(changes)
        self._commit_range_cache[key] = result
        return result

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
