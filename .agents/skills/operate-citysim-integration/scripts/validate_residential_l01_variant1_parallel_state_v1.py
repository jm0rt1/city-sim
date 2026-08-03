#!/usr/bin/env python3
"""Fail-closed validation for Residential L1 variant-one parallel controls."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


AUTHORITY = "07b2ad82eac047573537503ffdb091499310f644"
CELLS = ("north", "east", "south", "west", "renderer", "qa")
DIRECTIONS = ("north", "east", "south", "west")
ESCALATIONS = frozenset({
    "baseline_or_candidate_identity_mismatch",
    "cross_lane_semantic_conflict",
    "failure_outside_focused_scope",
    "path_outside_claim",
    "save_or_migration_uncertainty",
    "shared_contract_or_schema_decision",
    "subjective_acceptance_required",
    "two_unsuccessful_repair_attempts",
    "unresolved_product_visual_or_interaction_judgment",
})
EXPECTED = {
    "north": ("PLAY-090", "019f96e0-3793-7542-9172-060a9ca09b0a", "codex/citysim-world-art", "/Users/James/.codex/worktrees/0648/city-sim", "docs/production/claims/PLAY-090.world-art-north.md", ("FRONTIER_AUTHORITY", "gpt-5.6-sol", "high")),
    "east": ("PLAY-091", "019fab72-b2c8-76c1-b430-6c6f8431733f", "codex/citysim-world-art-east", "/Users/James/.codex/worktrees/92c2/city-sim", "docs/production/claims/PLAY-091.world-art-east.md", ("LUNA_IMPLEMENTATION", "gpt-5.6-luna", "high")),
    "south": ("PLAY-092", "019fab72-b2c9-7d60-a397-27f4fde85950", "codex/citysim-world-art-south", "/Users/James/.codex/worktrees/4247/city-sim", "docs/production/claims/PLAY-092.world-art-south.md", ("LUNA_IMPLEMENTATION", "gpt-5.6-luna", "high")),
    "west": ("PLAY-093", "019fab72-b2c9-7d60-a397-27d01d06cbbd", "codex/citysim-world-art-west", "/Users/James/.codex/worktrees/ef17/city-sim", "docs/production/claims/PLAY-093.world-art-west.md", ("LUNA_IMPLEMENTATION", "gpt-5.6-luna", "high")),
    "renderer": ("PLAY-094", "019f7c8a-69a2-78c2-ae70-fa23ee7bfcd0", "codex/citysim-world-rendering", "/Users/James/.codex/worktrees/cac1/city-sim", "docs/production/claims/PLAY-094.world-rendering.md", ("LUNA_IMPLEMENTATION", "gpt-5.6-luna", "high")),
    "qa": ("PLAY-075", "019f9a0a-35fa-75b1-92c4-73c182390a25", "codex/citysim-playtest-quality", "/Users/James/.codex/worktrees/71b0/city-sim", "docs/production/claims/PLAY-075.playtest-quality.md", ("LUNA_MECHANICAL", "gpt-5.6-luna", "medium")),
}
OWNED_ROOTS = {
    "north": ["Native/CitySimNative/WorldArt/Blender/PLAY-090/residential-l01-variant1-north/", "docs/production/evidence/PLAY-090/"],
    "east": ["Native/CitySimNative/WorldArt/Blender/PLAY-091/residential-l01-variant1-east/", "docs/production/evidence/PLAY-091/"],
    "south": ["Native/CitySimNative/WorldArt/Blender/PLAY-092/residential-l01-variant1-south/", "docs/production/evidence/PLAY-092/"],
    "west": ["Native/CitySimNative/WorldArt/Blender/PLAY-093/residential-l01-variant1-west/", "docs/production/evidence/PLAY-093/"],
    "renderer": ["docs/production/evidence/PLAY-094/"],
    "qa": ["docs/production/evidence/PLAY-075/"],
}
ROUTE_IDS = {
    "north": "quality-v2:play-090-residential-l01-variant1-north-prelock-v1",
    "east": "quality-v2:play-091-residential-l01-variant1-east-prelock-v1",
    "south": "quality-v2:play-092-residential-l01-variant1-south-prelock-v1",
    "west": "quality-v2:play-093-residential-l01-variant1-west-prelock-v1",
    "renderer": "quality-v2:play-094-residential-l01-variant1-renderer-prelock-v1",
    "qa": "quality-v2:play-075-residential-l01-variant1-preregistration-v1",
}
SHA40 = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")


class ControlError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ControlError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, check=False)


def require_commit(root: Path, value: Any, label: str) -> None:
    require(isinstance(value, str) and SHA40.fullmatch(value) is not None, f"{label} must be a full Git commit")
    require(git(root, "cat-file", "-e", f"{value}^{{commit}}").returncode == 0, f"{label} does not resolve")


def validate_binding(root: Path, value: Any, label: str) -> None:
    require(isinstance(value, dict) and set(value) == {"path", "sha256"}, f"{label} must contain path and sha256")
    path, expected = value["path"], value["sha256"]
    require(isinstance(path, str) and path and not Path(path).is_absolute(), f"{label}.path must be repository-relative")
    require(isinstance(expected, str) and SHA256.fullmatch(expected) is not None, f"{label}.sha256 is invalid")
    resolved = (root / path).resolve()
    require(resolved.is_relative_to(root.resolve()) and resolved.is_file(), f"{label}.path is missing or escapes the repository")
    require(digest(resolved) == expected, f"{label}.sha256 is stale")


def overlap(left: str, right: str) -> bool:
    a, b = Path(left), Path(right)
    return a == b or a in b.parents or b in a.parents


def validate_schedule(data: Any, root: Path, *, check_live: bool = True) -> dict[str, Any]:
    fields = {"schema", "batchId", "phase", "authorityCommit", "familyContract", "controlSchema", "dispatchReady", "cells", "familyActivation", "capacity"}
    require(isinstance(data, dict) and set(data) == fields, "top-level fields do not match the control schema")
    require(data["schema"] == 1 and data["batchId"] == "residential-l01-variant1-v1", "wrong schema or batch")
    require(data["phase"] == "prelock", "initial control schedule must remain prelock")
    require(data["authorityCommit"] == AUTHORITY, "schedule authorityCommit mismatch")
    require_commit(root, data["authorityCommit"], "authorityCommit")
    require(git(root, "merge-base", "--is-ancestor", AUTHORITY, "HEAD").returncode == 0, "published authority is not an ancestor of HEAD")
    validate_binding(root, data["familyContract"], "familyContract")
    validate_binding(root, data["controlSchema"], "controlSchema")
    require(data["dispatchReady"] is False, "control publication does not authorize dispatch")

    rows = data["cells"]
    require(isinstance(rows, list) and len(rows) == 6, "exactly six control rows are required")
    require([row.get("cell") for row in rows if isinstance(row, dict)] == list(CELLS), "rows must be ordered north/east/south/west/renderer/qa")
    all_roots: list[tuple[str, str]] = []
    by_cell: dict[str, dict[str, Any]] = {}
    row_fields = {"cell", "taskId", "threadId", "branch", "worktree", "head", "claim", "state", "ownedRoots", "siblingTransformAllowed", "modelRoute", "permissions", "failureIsolation", "featureAuthorThreadId"}
    for row in rows:
        require(isinstance(row, dict) and set(row) == row_fields, "cell row fields do not match schema")
        cell = row["cell"]
        require(cell in EXPECTED and cell not in by_cell, "cell rows must be unique")
        by_cell[cell] = row
        task, thread, branch, worktree, claim_path, route_tuple = EXPECTED[cell]
        require((row["taskId"], row["threadId"], row["branch"], row["worktree"], row["claim"]["path"]) == (task, thread, branch, worktree, claim_path), f"{cell} identity binding mismatch")
        validate_binding(root, row["claim"], f"{cell}.claim")
        require_commit(root, row["head"], f"{cell}.head")
        require(row["state"] == "not_dispatched", f"{cell} must remain not_dispatched")
        require(row["siblingTransformAllowed"] is False, f"{cell} may not derive from a sibling")
        require(row["failureIsolation"] is True, f"{cell} must preserve passing siblings")
        roots = row["ownedRoots"]
        require(roots == OWNED_ROOTS[cell], f"{cell}.ownedRoots do not match the exact claim projection")
        for owned in roots:
            require(isinstance(owned, str) and owned and not Path(owned).is_absolute() and ".." not in Path(owned).parts, f"{cell} owned root invalid")
            for other_cell, other in all_roots:
                require(not overlap(owned, other), f"owned root overlap: {cell} and {other_cell}")
            all_roots.append((cell, owned))
        model_route = row["modelRoute"]
        require(isinstance(model_route, dict) and set(model_route) == {"routeId", "classification", "model", "effort", "escalationTriggers"}, f"{cell}.modelRoute fields invalid")
        require(model_route["routeId"] == ROUTE_IDS[cell], f"{cell}.modelRoute routeId mismatch")
        require((model_route["classification"], model_route["model"], model_route["effort"]) == route_tuple, f"{cell}.modelRoute tier mismatch")
        triggers = model_route["escalationTriggers"]
        require(isinstance(triggers, list) and set(triggers) == ESCALATIONS and len(triggers) == len(ESCALATIONS), f"{cell}.modelRoute escalation triggers incomplete")
        permissions = row["permissions"]
        require(permissions == {"prelockPixels": False, "productionPixels": False, "shippingActivation": False}, f"{cell} has a prelock pixel or shipping grant")
        require(row["featureAuthorThreadId"] == (None if cell == "qa" else thread), f"{cell} feature-author binding mismatch")
        if check_live:
            live = Path(worktree)
            require(live.is_dir(), f"{cell} worktree missing")
            require(git(live, "branch", "--show-current").stdout.strip() == branch, f"{cell} live branch mismatch")
            require(git(live, "rev-parse", "HEAD").stdout.strip() == row["head"], f"{cell} live HEAD mismatch")
            status = git(live, "status", "--porcelain=v1")
            require(status.returncode == 0 and not status.stdout.strip(), f"{cell} worktree is dirty or unreadable")

    activation = data["familyActivation"]
    require(isinstance(activation, dict) and set(activation) == {"state", "requiredDirections", "admittedDirections", "partialActivationAllowed", "variantZeroFallbackAllowed"}, "familyActivation fields invalid")
    require(activation["requiredDirections"] == list(DIRECTIONS), "family activation directions mismatch")
    admitted = activation["admittedDirections"]
    require(isinstance(admitted, list) and len(admitted) == len(set(admitted)) and set(admitted) <= set(DIRECTIONS), "admittedDirections invalid")
    require(activation["partialActivationAllowed"] is False and activation["variantZeroFallbackAllowed"] is False, "partial or fallback activation is forbidden")
    require(activation["state"] == "blocked_until_4_of_4" and not admitted, "prelock activation must remain blocked with zero admissions")
    failed = {cell for cell, row in by_cell.items() if row["state"] == "failed"}
    if failed:
        require(not any(row["state"] == "demoted" for cell, row in by_cell.items() if cell not in failed), "failed direction demotes a passing sibling")

    capacity = data["capacity"]
    require(isinstance(capacity, dict) and set(capacity) == {"minimumUsefulActiveWorkstreams", "activeWorkstreams", "idleCapacityReason", "overlapProof"}, "capacity fields invalid")
    require(capacity["minimumUsefulActiveWorkstreams"] == 3, "minimum useful concurrency must be three")
    active = capacity["activeWorkstreams"]
    require(isinstance(active, list) and len(active) == len(set(active)) and set(active) <= set(CELLS), "activeWorkstreams invalid")
    require(not active, "a non-dispatch schedule cannot claim active workstreams")
    require(isinstance(capacity["idleCapacityReason"], str) and capacity["idleCapacityReason"].strip(), "idle capacity requires an exact reason")
    proof = capacity["overlapProof"]
    require(proof == [], "a non-dispatch schedule cannot claim overlap proof")
    return {"result": "PASS", "batchId": data["batchId"], "phase": data["phase"], "rows": list(CELLS), "dispatchReady": False}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("schedule")
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()
    root = Path(args.repo_root).resolve()
    try:
        result = validate_schedule(json.loads(Path(args.schedule).read_text()), root)
    except (OSError, json.JSONDecodeError, ControlError) as error:
        print(json.dumps({"result": "FAIL", "reason": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
