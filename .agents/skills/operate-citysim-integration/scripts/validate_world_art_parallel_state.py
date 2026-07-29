#!/usr/bin/env python3
"""Fail-closed validation for CitySim's canonical World Art parallel state."""

from __future__ import annotations

import argparse
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
                self._validate_required_row_fields(
                    ledger_row, f"ledger.cells.{cell}"
                )
                self._validate_work_row(ledger_row, f"ledger.cells.{cell}")
                self._validate_live_git(ledger_row, f"ledger.cells.{cell}")

            receipt_row = receipt_rows.get(cell)
            if receipt_row is not None:
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
            "branch",
            "worktree",
            "claim",
            "head",
            "cleanState",
            "dispatchState",
        ):
            value = row.get(field)
            if not isinstance(value, str) or not value.strip():
                self.error(
                    "ROW_FIELD_MISSING",
                    f"{location}.{field}",
                    "must be present and non-empty",
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
        aliases = (("publishedBase", "base"),)
        for field in (
            "branch",
            "worktree",
            "claim",
            "claimRevision",
            "head",
            "dispatchState",
        ):
            if field in ledger_row and field in receipt_row:
                if ledger_row[field] != receipt_row[field]:
                    self.error(
                        "RECEIPT_LEDGER_ROW_MISMATCH",
                        f"receipt.rows.{cell}.{field}",
                        f"{receipt_row[field]!r} does not match ledger value "
                        f"{ledger_row[field]!r}",
                    )
        for ledger_field, receipt_field in aliases:
            if ledger_field in ledger_row and receipt_field in receipt_row:
                if ledger_row[ledger_field] != receipt_row[receipt_field]:
                    self.error(
                        "RECEIPT_LEDGER_ROW_MISMATCH",
                        f"receipt.rows.{cell}.{receipt_field}",
                        f"{receipt_row[receipt_field]!r} does not match ledger "
                        f"{ledger_field} {ledger_row[ledger_field]!r}",
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
