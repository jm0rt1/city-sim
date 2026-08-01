"""Deterministic, zero-child North v13 Process-A prelaunch closure.

The prelaunch runner verifies immutable inputs and proves that live authority is
not present.  It never creates the future process root, starts a child, imports
Blender, or emits pixels.  A later Integration authority must replace the
missing-by-design state before any source process can be considered.
"""

from __future__ import annotations

import hashlib
import hmac
import json
from datetime import datetime, timezone
from pathlib import Path
import sys


ROUTE_ID = "quality-v1:north-v13-prelaunch-repair"
ROUTE_CANONICAL_SHA256 = "f180cedfe88001c7d7d4591b4edd65fd4b654e5c31e0b9ee6e0ad7db8576a2f4"
EXPECTED_CARRIER = "c791878749416e2caeb03650c8abd859b6bc9525"
EXPECTED_RECEIPT_PATH = "docs/production/evidence/INTEGRATION/MODEL-ROUTING-QUALITY-NORTH-V13-PRELAUNCH-REPAIR-V1.json"
EXPECTED_RECEIPT_SHA256 = "405dbdac13ec2771b3e0f23e061afa77d94b7832f940babe1d4080dc2a81e107"
EXPECTED_HEAD = "db9ea3d8779127d52d25d536310544aaf58193be"
EXPECTED_CLAIM = "7d42ba7c38a55d7681171499aad50e15c2d3eba0878cabf508d0e42ee97cdc83"
EXPECTED_BASE = "73b72fce27d1bcfedcf48b76940ddfa688baa48c"
EXPECTED_SCENE_ID = "industrial-l04-north-v13-portal-crown-foundry"
EXPECTED_EXCLUSIVE_ROOT = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a"
EXPECTED_RUN_ROOT = EXPECTED_EXCLUSIVE_ROOT + "/run-a"
EXPECTED_EVIDENCE_ROOT = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a-prelaunch-v01"
EXPECTED_ALLOWED_ROOTS = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-prelaunch-v01",
    EXPECTED_EVIDENCE_ROOT,
    EXPECTED_RUN_ROOT,
)
EXPECTED_THREAD = "019f96e0-3793-7542-9172-060a9ca09b0a"
EXPECTED_WORKTREE = "/Users/James/.codex/worktrees/0648/city-sim"
EXPECTED_CONSUMPTION_ID = "test-only-north-v13-process-a-attempt-0001"


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
        if ref.is_file():
            return ref.read_text(encoding="utf-8").strip()
        commondir = git_dir / "commondir"
        if commondir.is_file():
            common = Path(commondir.read_text(encoding="utf-8").strip())
            if not common.is_absolute():
                common = git_dir / common
            ref = common / value[5:]
            return ref.read_text(encoding="utf-8").strip() if ref.is_file() else None
        return None
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
    if route["routeId"] != ROUTE_ID or route["canonicalSHA256"] != ROUTE_CANONICAL_SHA256:
        raise ValueError("wrong route")
    if route.get("carrierCommit") != EXPECTED_CARRIER or route.get("receiptPath") != EXPECTED_RECEIPT_PATH or route.get("receiptSHA256") != EXPECTED_RECEIPT_SHA256:
        raise ValueError("wrong carrier or receipt binding")
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
    assignment = contract["assignment"]
    if assignment.get("threadId") != EXPECTED_THREAD or assignment.get("branch") != "codex/citysim-world-art" or assignment.get("worktree") != EXPECTED_WORKTREE:
        raise ValueError("wrong assignment binding")
    output = contract["output"]
    if output["exclusiveFutureProcessRoot"] != EXPECTED_EXCLUSIVE_ROOT or output["runRoot"] != EXPECTED_RUN_ROOT or output["evidenceRoot"] != EXPECTED_EVIDENCE_ROOT:
        raise ValueError("wrong output root")
    if tuple(output.get("allowedRoots", ())) != EXPECTED_ALLOWED_ROOTS:
        raise ValueError("wrong allowed roots")
    if contract["authorityState"].get("maximumDCCChildStarts") != 1 or contract["authorityState"].get("maximumProcessAStarts") != 1:
        raise ValueError("wrong DCC child limit")
    actual_claim = root / claim["path"]
    _assert_no_symlink(actual_claim, root)
    if sha256(actual_claim) != EXPECTED_CLAIM:
        raise ValueError("claim bytes do not match")
    for item in contract["inputs"]:
        path = root / item["path"]
        _assert_no_symlink(path, root)
        if not path.is_file() or sha256(path) != item["sha256"]:
            raise ValueError(f"immutable input mismatch: {item['path']}")
    actual_head = _git_head(root)
    if actual_head != EXPECTED_HEAD:
        raise ValueError(f"candidate HEAD mismatch: expected {EXPECTED_HEAD}, actual {actual_head}")
    if expected_head is not None and expected_head != actual_head:
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
        "currentHead": actual_head,
    }


def _canonical_binding(binding: dict) -> bytes:
    return json.dumps(binding, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _fixture_signature(binding: dict, fixture_key: bytes) -> str:
    return hmac.new(fixture_key, _canonical_binding(binding), hashlib.sha256).hexdigest()


def build_test_fixture_authority(contract: dict, fixture_key: bytes, root: Path) -> dict:
    """Build authority only in test memory; never write a grant/secret file."""
    validate_contract(root, contract)
    binding = {
        "routeId": ROUTE_ID,
        "routeCanonicalSHA256": ROUTE_CANONICAL_SHA256,
        "carrierCommit": EXPECTED_CARRIER,
        "receiptPath": EXPECTED_RECEIPT_PATH,
        "receiptSHA256": EXPECTED_RECEIPT_SHA256,
        "claimPath": contract["claim"]["path"],
        "claimSHA256": EXPECTED_CLAIM,
        "claimRevision": contract["claim"]["revision"],
        "authorityBase": EXPECTED_BASE,
        "assignmentThreadId": EXPECTED_THREAD,
        "candidateHead": EXPECTED_HEAD,
        "logicalBuildingID": "industrial_l04",
        "variantID": "variant-0",
        "viewDirection": "north",
        "processID": "A",
        "slotID": "north:A",
        "grantId": "north:A",
        "dccChildLimit": 1,
        "exclusiveOutputRoot": EXPECTED_RUN_ROOT,
        "evidenceRoot": EXPECTED_EVIDENCE_ROOT,
        "allowedRoots": list(EXPECTED_ALLOWED_ROOTS),
        "consumptionId": EXPECTED_CONSUMPTION_ID,
        "testOnly": True,
        "childStarts": 0,
        "dccStarts": 0,
        "renderedPixels": 0,
        "consumed": False,
    }
    return {"schema": 1, "kind": "test-only-fixture-authority", "binding": binding, "signature": _fixture_signature(binding, fixture_key)}


def validate_fixture_authority(authority: dict, contract: dict, root: Path, fixture_key: bytes) -> dict:
    if authority.get("schema") != 1 or authority.get("kind") != "test-only-fixture-authority":
        raise ValueError("wrong fixture authority kind")
    binding = authority.get("binding")
    if not isinstance(binding, dict) or not hmac.compare_digest(authority.get("signature", ""), _fixture_signature(binding, fixture_key)):
        raise ValueError("fixture authority signature mismatch")
    expected = {
        "routeId": ROUTE_ID, "routeCanonicalSHA256": ROUTE_CANONICAL_SHA256, "carrierCommit": EXPECTED_CARRIER,
        "receiptPath": EXPECTED_RECEIPT_PATH, "receiptSHA256": EXPECTED_RECEIPT_SHA256,
        "claimPath": contract["claim"]["path"], "claimSHA256": EXPECTED_CLAIM, "claimRevision": contract["claim"]["revision"],
        "authorityBase": EXPECTED_BASE, "assignmentThreadId": EXPECTED_THREAD, "candidateHead": EXPECTED_HEAD,
        "logicalBuildingID": "industrial_l04", "variantID": "variant-0", "viewDirection": "north", "processID": "A",
        "slotID": "north:A", "grantId": "north:A", "dccChildLimit": 1, "exclusiveOutputRoot": EXPECTED_RUN_ROOT,
        "evidenceRoot": EXPECTED_EVIDENCE_ROOT, "allowedRoots": list(EXPECTED_ALLOWED_ROOTS),
        "consumptionId": EXPECTED_CONSUMPTION_ID,
        "testOnly": True, "childStarts": 0, "dccStarts": 0, "renderedPixels": 0, "consumed": False,
    }
    for key, value in expected.items():
        if binding.get(key) != value:
            raise ValueError(f"fixture binding mismatch: {key}")
    if _git_head(root) != binding["candidateHead"]:
        raise ValueError("fixture candidate HEAD mismatch")
    return binding


def validate_owned_output(root: Path, output_root: str, contract: dict) -> None:
    if output_root != EXPECTED_RUN_ROOT or output_root not in contract["output"]["allowedRoots"]:
        raise ValueError("output is outside exclusive allowed root")
    path = root / output_root
    _assert_no_symlink(path, root)
    if path.exists():
        raise ValueError("output overwrite or replay")


def consume_test_fixture(authority: dict, contract: dict, root: Path, fixture_key: bytes, state: dict) -> dict:
    binding = validate_fixture_authority(authority, contract, root, fixture_key)
    if state.get("consumptionId") != binding["consumptionId"] or state.get("consumed"):
        raise ValueError("fixture grant replay")
    validate_owned_output(root, binding["exclusiveOutputRoot"], contract)
    state["consumed"] = True
    return {"consumed": True, "startedChild": False, "dccStarts": 0, "renderedPixels": 0, "outputCreated": False}


def _stable_receipt(contract: dict, root: Path, *, started_at: str | None = None, ended_at: str | None = None) -> tuple[dict, dict]:
    script = Path(__file__).resolve()
    child = script.with_name("render_north_v13_process_a_child.py")
    contract_path = script.with_name("EXECUTION-CONTRACT.json")
    checks = validate_contract(root, contract)
    common = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": contract["stage"],
        "route": contract["route"],
        "claim": contract["claim"],
        "identity": contract["identity"],
        "inputs": contract["inputs"],
        "adapter": {
            "mode": "test-only-fixture",
            "signature": "HMAC-SHA256",
            "routeCanonicalBound": True,
            "carrierBound": True,
            "candidateHeadBound": True,
            "exclusiveRootBound": True,
            "oneAttemptConsumption": True,
            "replayRejected": True,
            "authorityFilesCreated": 0,
        },
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
            "grant": {"status": "missing-by-design", "created": False},
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
            "jobId": "north-v13-prelaunch-repair-validation",
            "batch": "north-v13-prelaunch-repair-v01",
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
            "startedAt": started_at,
            "endedAt": ended_at,
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
            "dependencyAuthority": "docs/production/evidence/INTEGRATION/MODEL-ROUTING-QUALITY-NORTH-V13-PRELAUNCH-REPAIR-V1.json#quality-v1:north-v13-prelaunch-repair",
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
    started_at = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    validation, closure = _stable_receipt(contract, root, started_at=started_at, ended_at=None)
    ended_at = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    validation, closure = _stable_receipt(contract, root, started_at=started_at, ended_at=ended_at)
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
