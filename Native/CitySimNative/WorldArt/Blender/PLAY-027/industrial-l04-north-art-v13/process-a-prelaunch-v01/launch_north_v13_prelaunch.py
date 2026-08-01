"""Deterministic, zero-child North v13 Process-A prelaunch closure.

The prelaunch runner verifies immutable inputs and proves that live authority is
not present.  It never creates the future process root, starts a child, imports
Blender, or emits pixels.  A later Integration authority must replace the
missing-by-design state before any source process can be considered.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import sys


ROUTE_ID = "quality-v1:north-v13-prelaunch"
EXPECTED_HEAD = "41427d773cb12594a4eb723b7291a38ed6321a0f"
EXPECTED_CLAIM = "7d42ba7c38a55d7681171499aad50e15c2d3eba0878cabf508d0e42ee97cdc83"
EXPECTED_BASE = "73b72fce27d1bcfedcf48b76940ddfa688baa48c"
EXPECTED_SCENE_ID = "industrial-l04-north-v13-portal-crown-foundry"
EXPECTED_EXCLUSIVE_ROOT = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a"
EXPECTED_RUN_ROOT = EXPECTED_EXCLUSIVE_ROOT + "/run-a"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        value = json.load(f)
    if not isinstance(value, dict):
        raise ValueError(f"object required: {path}")
    return value


def _git_head(root: Path) -> str | None:
    git_marker = root / ".git"
    if git_marker.is_file():
        marker = git_marker.read_text(encoding="utf-8").strip()
        if marker.startswith("gitdir: "):
            git_dir = Path(marker[8:])
        else:
            git_dir = git_marker
    else:
        git_dir = git_marker
    head = git_dir / "HEAD"
    if not head.is_file():
        return None
    value = head.read_text(encoding="utf-8").strip()
    if value.startswith("ref: "):
        ref = git_dir / value[5:]
        return ref.read_text(encoding="utf-8").strip() if ref.is_file() else None
    return value


def _assert_no_symlink(path: Path, root: Path) -> None:
    current = root
    try:
        rel_parts = path.relative_to(root).parts
    except ValueError as exc:
        raise ValueError(f"path outside repository: {path}") from exc
    for part in rel_parts:
        current /= part
        if current.is_symlink():
            raise ValueError(f"symlink path rejected: {current}")


def validate_contract(root: Path, contract: dict, *, expected_head: str | None = None) -> dict:
    route = contract["route"]
    claim = contract["claim"]
    identity = contract["identity"]
    if route["routeId"] != ROUTE_ID:
        raise ValueError("wrong route")
    if route["authorityCommit"] != EXPECTED_BASE or route["baseCommit"] != EXPECTED_BASE:
        raise ValueError("wrong authority/base")
    if route["expectedStartingHEAD"] != EXPECTED_HEAD:
        raise ValueError("wrong expected starting HEAD")
    if claim["sha256"] != EXPECTED_CLAIM:
        raise ValueError("wrong claim hash")
    if identity["viewDirection"] != "north" or identity["processID"] != "A":
        raise ValueError("wrong direction/process")
    if identity.get("slotID") != "north:A":
        raise ValueError("wrong slot")
    if identity["sceneGeometryID"] != EXPECTED_SCENE_ID:
        raise ValueError("wrong scene geometry")
    if contract["output"]["exclusiveFutureProcessRoot"] != EXPECTED_EXCLUSIVE_ROOT or contract["output"]["runRoot"] != EXPECTED_RUN_ROOT:
        raise ValueError("wrong output root")
    actual_claim = root / claim["path"]
    _assert_no_symlink(actual_claim, root)
    if sha256(actual_claim) != EXPECTED_CLAIM:
        raise ValueError("claim bytes do not match")
    for item in contract["inputs"]:
        path = root / item["path"]
        _assert_no_symlink(path, root)
        if not path.is_file() or sha256(path) != item["sha256"]:
            raise ValueError(f"immutable input mismatch: {item['path']}")
    if expected_head is not None and expected_head != EXPECTED_HEAD:
        raise ValueError("unexpected starting HEAD")
    future = root / contract["output"]["runRoot"]
    _assert_no_symlink(future, root)
    if future.exists():
        raise ValueError("future Process-A output root already exists")
    for marker in ("schedule.json", "lease.json", "secret", "grant.json", "execution-authority.json"):
        if (root / contract["output"]["exclusiveFutureProcessRoot"] / marker).exists():
            raise ValueError(f"live authority present: {marker}")
    if any(contract["authorityState"].get(k) for k in ("scheduleCreated", "leaseCreated", "secretCreated", "grantCreated")):
        raise ValueError("prelaunch contract claims a live authority")
    return {
        "claimSHA256": sha256(actual_claim),
        "inputCount": len(contract["inputs"]),
        "futureProcessRootAbsent": True,
        "liveAuthorityAbsent": True,
        "currentHead": _git_head(root),
    }


def _stable_receipt(contract: dict, root: Path) -> tuple[dict, dict]:
    script = Path(__file__).resolve()
    child = script.with_name("render_north_v13_process_a_child.py")
    contract_path = script.with_name("EXECUTION-CONTRACT.json")
    checks = validate_contract(root, contract)
    common = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v13-process-a-prelaunch-v01",
        "route": contract["route"],
        "claim": contract["claim"],
        "identity": contract["identity"],
        "inputs": contract["inputs"],
        "toolHashes": {
            "executionContract": sha256(contract_path),
            "runner": sha256(script),
            "child": sha256(child),
        },
        "checks": checks,
        "authority": {
            "schedule": {"status": "missing-by-design", "created": False},
            "oneAttemptLease": {"status": "missing-by-design", "created": False},
            "secret": {"status": "missing-by-design", "created": False},
        },
        "counts": {
            "processA": 0, "blender": 0, "dcc": 0, "renders": 0,
            "pixels": 0, "normalizer": 0, "processB": 0, "processC": 0,
        },
        "sourceAuthority": False,
        "productionSelected": False,
    }
    validation = dict(common)
    validation.update({
        "result": "PASS_ZERO_CHILD_PRELAUNCH",
        "prelaunchOnly": True,
        "forbiddenOutputsAbsent": ["future-process-root", "raw-png", "blend", "normalization", "live-grant"],
    })
    accounting = {
        "readyNow": [],
        "running": [],
        "waitingOnJoin": [],
        "joined": [{
            "jobId": "north-v13-prelaunch-validation",
            "batch": "north-v13-prelaunch-v01",
            "claim": contract["claim"]["path"],
            "claimRevision": contract["claim"]["revision"],
            "publishedBase": contract["route"]["baseCommit"],
            "head": contract["route"]["expectedStartingHEAD"],
            "threadId": contract["assignment"]["threadId"],
            "branch": contract["assignment"]["branch"],
            "worktree": contract["assignment"]["worktree"],
            "resourceClass": "helper",
            "mutation": "write-task-owned-prelaunch-evidence",
            "exclusiveRoot": contract["output"]["evidenceRoot"],
            "state": "joined",
            "processId": None,
            "dccSlot": None,
            "evidenceId": "ZERO-CHILD-CLOSURE.json",
        }],
        "overlap": {"status": "none", "jobIds": [], "reason": "single deterministic helper; no concurrent child"},
        "serializedAuthority": {
            "threadId": contract["assignment"]["threadId"],
            "branch": contract["assignment"]["branch"],
            "worktree": contract["assignment"]["worktree"],
            "gitIndexWriter": contract["assignment"]["threadId"],
            "governedEvidenceWriter": contract["assignment"]["threadId"],
        },
        "capacity": {"helperSlots": 1, "dccSlots": 0, "maximumDCCChildStarts": 1},
        "unusedCapacityReasons": [{
            "reasonCode": "DCC_AUTHORITY_NOT_PUBLISHED",
            "owner": "019f7686-4491-7891-86a6-95a78d67e5c8",
            "dependencyAuthority": "docs/production/evidence/INTEGRATION/MODEL-ROUTING-QUALITY-NORTH-V13-PRELAUNCH-AND-QA-ID-REPAIR-V1.json#quality-v1:north-v13-prelaunch",
            "resumptionEvent": "Integration publishes schedule, lease, authenticated grant, and compute slot",
            "nextRefillJob": "north-v13-process-a",
        }],
        "nextRefill": "Integration-published Process-A schedule + authenticated one-attempt grant/lease/secret",
    }
    closure = dict(common)
    closure.update({
        "result": "READY_FOR_INTEGRATION_REVIEW_ONLY",
        "prelaunchReady": True,
        "launchReady": False,
        "executionAccounting": accounting,
        "requiredNextAuthority": ["published schedule", "one-attempt lease", "authenticated grant/secret", "named compute slot"],
        "hardStop": "No live authority or child is issued by this packet.",
    })
    return validation, closure


def write_evidence(root: Path, evidence_root: Path) -> tuple[Path, Path]:
    contract_path = Path(__file__).with_name("EXECUTION-CONTRACT.json")
    contract = load_json(contract_path)
    validate_contract(root, contract)
    evidence_root.mkdir(parents=True, exist_ok=True)
    validation, closure = _stable_receipt(contract, root)
    vp = evidence_root / "PRELAUNCH-VALIDATION.json"
    cp = evidence_root / "ZERO-CHILD-CLOSURE.json"
    for path, value in ((vp, validation), (cp, closure)):
        path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return vp, cp


def main(argv: list[str] | None = None) -> int:
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--evidence-root", required=True)
    parser.add_argument("--write-evidence", action="store_true")
    args = parser.parse_args(argv)
    repo = Path(args.repository_root).resolve()
    contract_path = (repo / args.contract).resolve()
    if contract_path.name != "EXECUTION-CONTRACT.json":
        raise SystemExit("wrong contract")
    contract = load_json(contract_path)
    validate_contract(repo, contract)
    if args.write_evidence:
        evidence = (repo / args.evidence_root).resolve()
        _assert_no_symlink(evidence, repo)
        write_evidence(repo, evidence)
    print("PASS ZERO_CHILD_PRELAUNCH processA=0 blender=0 dcc=0 pixels=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
