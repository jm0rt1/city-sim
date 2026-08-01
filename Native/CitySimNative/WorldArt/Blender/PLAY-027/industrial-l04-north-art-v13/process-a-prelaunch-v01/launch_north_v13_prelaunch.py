"""Fail-closed, zero-DCC North v13 Process-A prelaunch recovery.

This task-local adapter verifies its Integration carrier from Git, binds an
explicit execution base, accepts only a closed zero-activity test authority,
and proves atomic one-shot consumption in an isolated fixture store.  It never
starts Blender, imports bpy, creates a live grant, or emits source pixels.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
from pathlib import Path
import subprocess
import sys


ROUTE_ID = "quality-v1:north-v13-prelaunch-frontier-repair-r4"
ROUTE_CANONICAL_SHA256 = "b285ac5913960241f28d9a70d7fe6132bbb20c41d05a654e71b6b5aa7a2c2b93"
EXPECTED_CARRIER = "4025b85c68d5cd85f0612532ede18b0ec5ec8f0c"
EXPECTED_RECEIPT_PATH = "docs/production/evidence/INTEGRATION/MODEL-ROUTING-QUALITY-NORTH-V13-PRELAUNCH-FRONTIER-REPAIR-R4.json"
EXPECTED_RECEIPT_SHA256 = "2eab208d8f3066088c5d567f5628b364882cefc5632e2a9ba96808e1d4071a0b"
EXECUTION_BASE_HEAD = "4febf8067c0a68e5e43a8a26bdeea1ecdc6290c4"
EXPECTED_CLAIM = "7d42ba7c38a55d7681171499aad50e15c2d3eba0878cabf508d0e42ee97cdc83"
EXPECTED_BASE = "73b72fce27d1bcfedcf48b76940ddfa688baa48c"
EXPECTED_SCENE_ID = "industrial-l04-north-v13-portal-crown-foundry"
EXPECTED_EXCLUSIVE_ROOT = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a"
EXPECTED_RUN_ROOT = EXPECTED_EXCLUSIVE_ROOT + "/run-a"
EXPECTED_EVIDENCE_ROOT = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a-prelaunch-v01"
EXPECTED_SOURCE_ROOT = "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-prelaunch-v01"
EXPECTED_ALLOWED_ROOTS = (EXPECTED_SOURCE_ROOT, EXPECTED_EVIDENCE_ROOT, EXPECTED_RUN_ROOT)
EXPECTED_THREAD = "019f96e0-3793-7542-9172-060a9ca09b0a"
EXPECTED_WORKTREE = "/Users/James/.codex/worktrees/0648/city-sim"
EXPECTED_CONSUMPTION_ID = "test-only-north-v13-process-a-attempt-0001"
EXPECTED_IDENTITY = {
    "logicalBuildingID": "industrial_l04",
    "variantID": "variant-0",
    "viewDirection": "north",
    "processID": "A",
    "slotID": "north:A",
    "sourceRevision": "blender-art-v13-design-authority",
    "sceneGeometryID": EXPECTED_SCENE_ID,
    "samplingContract": "blender-cycles-cpu-v13-design-authority",
    "sourceAuthority": False,
    "productionSelected": False,
}
EXPECTED_INPUT_ITEMS = (
    ("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/DESIGN-SCENE.json", "0f7a8e40a07f5c2b7320ab42fe5e1bcb2dc23fb508ff6b04e8ea49cf6c974060"),
    ("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/DESIGN-MATERIALS.json", "c8179b77a184e41b723e26b34e7da2ef256b09e93b54a47e76cc5103f22b8cab"),
    ("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/lowering-v01/LOWERING-CONTRACT.json", "41125b2ee110085451a787879825cefe9a724cafa8ed3347db5a2688b063e111"),
    ("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json", "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"),
    ("docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/design-authority-v01/DESIGN-AUTHORITY.json", "1b1006403081c3933c54451b6c506af74493a2ac3b253fdd9f1f79098d7c1bed"),
    ("docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/lowering-v01/ACTUAL-CAMERA-ZERO-PIXEL-PROOF.json", "e4bbe982e47f4bf96703e75848d8bdad1d9c0cc2aa4d227749005fa039273470"),
)

CONTRACT_KEYS = {
    "schema", "stage", "task", "route", "claim", "assignment", "identity",
    "inputs", "output", "authorityState", "registration", "forbiddenActions",
}
AUTHORITY_KEYS = {"schema", "kind", "binding", "signature"}
BINDING_KEYS = {
    "routeId", "routeCanonicalSHA256", "carrierCommit", "receiptPath",
    "receiptSHA256", "claimPath", "claimSHA256", "claimRevision",
    "authorityBase", "assignmentThreadId", "executionBaseHEAD",
    "logicalBuildingID", "variantID", "viewDirection", "processID", "slotID",
    "sourceAuthority", "productionSelected", "inputs",
    "grantId", "dccChildLimit", "exclusiveOutputRoot", "evidenceRoot",
    "allowedRoots", "consumptionId", "testOnly", "activity",
}
ACTIVITY_KEYS = {
    "childStarts", "processAStarts", "blenderStarts", "dccStarts",
    "renderStarts", "normalizerStarts", "pixelWrites",
}


def canonical_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def bytes_sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"object required: {path}")
    return value


def _expected_inputs() -> list[dict[str, str]]:
    return [{"path": path, "sha256": digest} for path, digest in EXPECTED_INPUT_ITEMS]


def _require_exact_json_types(actual: object, expected: object, path: str) -> None:
    if type(actual) is not type(expected):
        raise ValueError(
            f"exact type mismatch at {path}: {type(actual).__name__} != {type(expected).__name__}"
        )
    if isinstance(expected, dict):
        if set(actual) != set(expected):
            raise ValueError(f"exact object fields mismatch at {path}")
        for key in expected:
            _require_exact_json_types(actual[key], expected[key], f"{path}/{key}")
    elif isinstance(expected, list):
        if len(actual) != len(expected):
            raise ValueError(f"exact list length mismatch at {path}")
        for index, (actual_item, expected_item) in enumerate(zip(actual, expected)):
            _require_exact_json_types(actual_item, expected_item, f"{path}/{index}")


def _validate_repository_root(root: Path | str) -> Path:
    raw = os.fspath(root)
    if type(raw) is not str or raw != EXPECTED_WORKTREE:
        raise ValueError("caller root is not the exact assigned absolute worktree")
    if not os.path.isabs(raw) or os.path.abspath(raw) != raw or os.path.realpath(raw) != raw:
        raise ValueError("caller root contains a lexical or symlink alias")
    expected = Path(EXPECTED_WORKTREE)
    if expected.is_symlink() or not expected.is_dir():
        raise ValueError("assigned worktree is not a real directory")
    actual_stat = os.stat(raw, follow_symlinks=False)
    expected_stat = os.stat(EXPECTED_WORKTREE, follow_symlinks=False)
    if (actual_stat.st_dev, actual_stat.st_ino) != (expected_stat.st_dev, expected_stat.st_ino):
        raise ValueError("caller root is not the assigned worktree inode")
    return expected


def _run_git(root: Path, *args: str, allow_failure: bool = False) -> bytes:
    allowed = {"cat-file", "show", "rev-parse", "merge-base", "diff", "ls-files"}
    if not args or args[0] not in allowed:
        raise ValueError("unapproved helper command")
    result = subprocess.run(
        ["git", *args], cwd=root, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if result.returncode and not allow_failure:
        raise ValueError(f"git {' '.join(args)} failed: {result.stderr.decode('utf-8', 'replace').strip()}")
    return result.stdout


def _git_head(root: Path) -> str:
    return _run_git(root, "rev-parse", "HEAD").decode("ascii").strip()


def _git_branch(root: Path) -> str:
    return _run_git(root, "rev-parse", "--abbrev-ref", "HEAD").decode("utf-8").strip()


def _assert_no_symlink(path: Path, root: Path) -> None:
    try:
        parts = path.relative_to(root).parts
    except ValueError as exc:
        raise ValueError(f"path outside repository: {path}") from exc
    current = root
    for part in parts:
        current /= part
        if current.is_symlink():
            raise ValueError(f"symlink path rejected: {current}")


def _changed_paths_from_execution_base(root: Path) -> list[str]:
    tracked = _run_git(root, "diff", "--name-only", EXECUTION_BASE_HEAD, "--")
    untracked = _run_git(root, "ls-files", "--others", "--exclude-standard")
    return sorted({
        line
        for raw in (tracked, untracked)
        for line in raw.decode("utf-8").splitlines()
        if line
    })


def _path_is_allowed(path: str) -> bool:
    return any(path == prefix or path.startswith(prefix + "/") for prefix in (EXPECTED_SOURCE_ROOT, EXPECTED_EVIDENCE_ROOT))


def verify_carrier_route(root: Path) -> dict:
    _run_git(root, "cat-file", "-e", EXPECTED_CARRIER + "^{commit}")
    receipt = _run_git(root, "show", f"{EXPECTED_CARRIER}:{EXPECTED_RECEIPT_PATH}")
    if bytes_sha256(receipt) != EXPECTED_RECEIPT_SHA256:
        raise ValueError("carrier receipt byte hash mismatch")
    dispatch = json.loads(receipt)
    assignments = dispatch.get("assignments")
    if not isinstance(assignments, list):
        raise ValueError("carrier receipt assignments missing")
    matches = [a for a in assignments if isinstance(a, dict) and isinstance(a.get("modelRoute"), dict) and a["modelRoute"].get("routeId") == ROUTE_ID]
    if len(matches) != 1:
        raise ValueError("carrier route row missing or duplicated")
    wrapper = matches[0]
    route = wrapper["modelRoute"]
    route_hash = bytes_sha256(canonical_bytes(route))
    if route_hash != ROUTE_CANONICAL_SHA256 or wrapper.get("modelRouteSha256") != route_hash:
        raise ValueError("canonical carrier route mismatch")
    assignment = route.get("assignment", {})
    authority = route.get("authority", {})
    claim = authority.get("claim", {})
    path_policy = route.get("pathPolicy", {})
    if assignment != {
        "branch": "codex/citysim-world-art", "expectedHead": EXECUTION_BASE_HEAD,
        "featureAuthorThreadId": None, "finalQAOwnership": False,
        "sharedAuthorityOwnership": False, "subjectiveJudgmentRequired": False,
        "threadId": EXPECTED_THREAD, "worktree": EXPECTED_WORKTREE,
    }:
        raise ValueError("carrier assignment mismatch")
    if authority.get("authorityCommit") != EXPECTED_BASE or authority.get("baseCommit") != EXPECTED_BASE:
        raise ValueError("carrier authority/base mismatch")
    if claim != {"path": "docs/production/claims/PLAY-027.world-art.md", "sha256": EXPECTED_CLAIM}:
        raise ValueError("carrier claim mismatch")
    if tuple(path_policy.get("allowed", ())) != EXPECTED_ALLOWED_ROOTS[:2]:
        raise ValueError("carrier allowed roots mismatch")
    return {
        "carrierCommit": EXPECTED_CARRIER,
        "receiptPath": EXPECTED_RECEIPT_PATH,
        "receiptSHA256": EXPECTED_RECEIPT_SHA256,
        "canonicalRouteSHA256": route_hash,
        "routeId": ROUTE_ID,
    }


def validate_contract(root: Path | str, contract: dict) -> dict:
    root = _validate_repository_root(root)
    expected_contract = load_json(Path(__file__).with_name("EXECUTION-CONTRACT.json"))
    _require_exact_json_types(contract, expected_contract, "contract")
    if contract != expected_contract:
        raise ValueError("execution contract differs from the frozen contract")
    if set(contract) != CONTRACT_KEYS:
        raise ValueError("execution contract has unknown or missing top-level fields")
    route = contract["route"]
    expected_route = {
        "routeId": ROUTE_ID, "canonicalSHA256": ROUTE_CANONICAL_SHA256,
        "carrierCommit": EXPECTED_CARRIER, "receiptPath": EXPECTED_RECEIPT_PATH,
        "receiptSHA256": EXPECTED_RECEIPT_SHA256, "authorityCommit": EXPECTED_BASE,
        "baseCommit": EXPECTED_BASE, "executionBaseHEAD": EXECUTION_BASE_HEAD,
    }
    if route != expected_route:
        raise ValueError("wrong route or execution-base binding")
    if contract["claim"] != {
        "path": "docs/production/claims/PLAY-027.world-art.md",
        "sha256": EXPECTED_CLAIM, "revision": 8,
    }:
        raise ValueError("wrong claim binding")
    if contract["assignment"] != {
        "threadId": EXPECTED_THREAD, "branch": "codex/citysim-world-art",
        "worktree": EXPECTED_WORKTREE,
    }:
        raise ValueError("wrong assignment binding")
    identity = contract["identity"]
    if identity != EXPECTED_IDENTITY:
        raise ValueError("wrong identity binding")
    if contract["inputs"] != _expected_inputs():
        raise ValueError("wrong immutable input set")
    output = contract["output"]
    if output.get("exclusiveFutureProcessRoot") != EXPECTED_EXCLUSIVE_ROOT or output.get("runRoot") != EXPECTED_RUN_ROOT or output.get("evidenceRoot") != EXPECTED_EVIDENCE_ROOT or tuple(output.get("allowedRoots", ())) != EXPECTED_ALLOWED_ROOTS:
        raise ValueError("wrong output binding")
    authority = contract["authorityState"]
    if authority.get("maximumDCCChildStarts") != 1 or authority.get("maximumProcessAStarts") != 1:
        raise ValueError("wrong child limit")
    if any(authority.get(key) for key in ("scheduleCreated", "leaseCreated", "secretCreated", "grantCreated")):
        raise ValueError("live authority claimed")
    claim_path = root / contract["claim"]["path"]
    _assert_no_symlink(claim_path, root)
    if sha256(claim_path) != EXPECTED_CLAIM:
        raise ValueError("claim bytes do not match")
    for item in _expected_inputs():
        path = root / item["path"]
        _assert_no_symlink(path, root)
        if not path.is_file() or sha256(path) != item["sha256"]:
            raise ValueError(f"immutable input mismatch: {item['path']}")
    if _git_branch(root) != "codex/citysim-world-art":
        raise ValueError("wrong branch")
    actual_head = _git_head(root)
    _run_git(root, "merge-base", "--is-ancestor", EXECUTION_BASE_HEAD, actual_head)
    changed_paths = _changed_paths_from_execution_base(root)
    if any(not _path_is_allowed(path) for path in changed_paths):
        raise ValueError("execution-base delta escapes task-owned roots")
    carrier = verify_carrier_route(root)
    future = root / EXPECTED_RUN_ROOT
    _assert_no_symlink(future, root)
    if future.exists():
        raise ValueError("future Process-A output root already exists")
    for marker in ("schedule.json", "lease.json", "secret", "grant.json", "execution-authority.json"):
        if (root / EXPECTED_EXCLUSIVE_ROOT / marker).exists():
            raise ValueError(f"live authority present: {marker}")
    return {
        "claimSHA256": EXPECTED_CLAIM,
        "inputCount": len(contract["inputs"]),
        "executionBaseHEAD": EXECUTION_BASE_HEAD,
        "executionBaseIsAncestor": True,
        "descendantDeltaRestrictedToTaskRoots": True,
        "changedPaths": changed_paths,
        "futureProcessRootAbsent": True,
        "liveAuthorityAbsent": True,
        "carrier": carrier,
    }


def _fixture_signature(binding: dict, fixture_key: bytes) -> str:
    return hmac.new(fixture_key, canonical_bytes(binding), hashlib.sha256).hexdigest()


def _expected_binding(contract: dict) -> dict:
    return {
        "routeId": ROUTE_ID, "routeCanonicalSHA256": ROUTE_CANONICAL_SHA256,
        "carrierCommit": EXPECTED_CARRIER, "receiptPath": EXPECTED_RECEIPT_PATH,
        "receiptSHA256": EXPECTED_RECEIPT_SHA256,
        "claimPath": contract["claim"]["path"], "claimSHA256": EXPECTED_CLAIM,
        "claimRevision": 8, "authorityBase": EXPECTED_BASE,
        "assignmentThreadId": EXPECTED_THREAD, "executionBaseHEAD": EXECUTION_BASE_HEAD,
        "logicalBuildingID": "industrial_l04", "variantID": "variant-0",
        "viewDirection": "north", "processID": "A", "slotID": "north:A",
        "sourceAuthority": False, "productionSelected": False,
        "inputs": _expected_inputs(),
        "grantId": "north:A", "dccChildLimit": 1,
        "exclusiveOutputRoot": EXPECTED_RUN_ROOT, "evidenceRoot": EXPECTED_EVIDENCE_ROOT,
        "allowedRoots": list(EXPECTED_ALLOWED_ROOTS), "consumptionId": EXPECTED_CONSUMPTION_ID,
        "testOnly": True,
        "activity": {key: 0 for key in sorted(ACTIVITY_KEYS)},
    }


def build_test_fixture_authority(contract: dict, fixture_key: bytes, root: Path) -> dict:
    validate_contract(root, contract)
    binding = _expected_binding(contract)
    return {
        "schema": 1, "kind": "test-only-fixture-authority", "binding": binding,
        "signature": _fixture_signature(binding, fixture_key),
    }


def validate_fixture_authority(authority: dict, contract: dict, root: Path, fixture_key: bytes) -> dict:
    validate_contract(root, contract)
    if type(authority) is not dict or set(authority) != AUTHORITY_KEYS:
        raise ValueError("fixture authority schema is not closed")
    if type(authority.get("schema")) is not int or authority.get("schema") != 1:
        raise ValueError("fixture authority schema is not exact integer one")
    if type(authority.get("kind")) is not str or authority.get("kind") != "test-only-fixture-authority":
        raise ValueError("fixture authority schema is not closed")
    binding = authority.get("binding")
    if type(binding) is not dict or set(binding) != BINDING_KEYS:
        raise ValueError("fixture binding schema is not closed")
    expected_binding = _expected_binding(contract)
    _require_exact_json_types(binding, expected_binding, "fixture/binding")
    activity = binding.get("activity")
    if type(activity) is not dict or set(activity) != ACTIVITY_KEYS:
        raise ValueError("fixture activity schema is not closed")
    if any(type(value) is not int or value != 0 for value in activity.values()):
        raise ValueError("fixture activity must be exact closed zero state")
    signature = authority.get("signature")
    if type(signature) is not str or not hmac.compare_digest(signature, _fixture_signature(binding, fixture_key)):
        raise ValueError("fixture signature mismatch")
    if binding != expected_binding:
        raise ValueError("fixture binding mismatch")
    return binding


def _fixture_state_name(binding: dict) -> str:
    immutable_key = {
        "routeId": binding["routeId"],
        "carrierCommit": binding["carrierCommit"],
        "executionBaseHEAD": binding["executionBaseHEAD"],
        "consumptionId": binding["consumptionId"],
    }
    return "citysim-play027-north-v13-test-attempt-" + bytes_sha256(canonical_bytes(immutable_key))


def consume_test_fixture(authority: dict, contract: dict, root: Path, fixture_key: bytes) -> dict:
    """Authenticate first, then atomically consume at one adapter-owned store."""
    binding = validate_fixture_authority(authority, contract, root, fixture_key)
    if (root / binding["exclusiveOutputRoot"]).exists():
        raise ValueError("output overwrite or replay")
    parent = Path("/private/tmp")
    if parent.is_symlink() or not parent.is_dir():
        raise ValueError("adapter-owned fixture state parent unavailable")
    state_name = _fixture_state_name(binding)
    parent_fd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.mkdir(state_name, mode=0o700, dir_fd=parent_fd)
        state_fd = os.open(state_name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent_fd)
    except FileExistsError as exc:
        raise ValueError("fixture attempt state already exists or consumed") from exc
    finally:
        os.close(parent_fd)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
    try:
        marker_fd = os.open("CONSUMED.json", flags, 0o600, dir_fd=state_fd)
    except FileExistsError as exc:
        os.close(state_fd)
        raise ValueError("fixture grant replay") from exc
    try:
        payload = canonical_bytes({"consumptionId": binding["consumptionId"], "consumed": True}) + b"\n"
        os.write(marker_fd, payload)
        os.fsync(marker_fd)
    finally:
        os.close(marker_fd)
        os.close(state_fd)
    return {
        "consumed": True, "startedDCCChild": False, "dccStarts": 0,
        "renderStarts": 0, "pixelWrites": 0, "outputCreated": False,
    }


def _canonical_documents(contract: dict, root: Path) -> tuple[dict, dict]:
    script = Path(__file__).resolve()
    checks = validate_contract(root, contract)
    common = {
        "schema": 1, "task": "PLAY-027", "stage": contract["stage"],
        "route": contract["route"], "claim": contract["claim"],
        "identity": contract["identity"], "inputs": contract["inputs"],
        "adapter": {
            "mode": "test-only-atomic-fixture", "closedSchema": True,
            "allActivityCountersZero": True, "repositoryBackedCarrier": True,
            "executionBaseBound": True, "atomicOneShotState": True,
            "immutableAdapterOwnedStore": True,
            "singleAuthenticatedConsumptionSurface": True,
            "exactCandidateIdentityBound": True,
            "exactSixInputSetBound": True,
            "exactRecursiveJSONTypes": True,
            "exactAssignedRootIdentity": True,
            "callerStateAccepted": False, "replayRejected": True,
            "authorityFilesCreated": 0,
        },
        "toolHashes": {
            "executionContract": sha256(script.with_name("EXECUTION-CONTRACT.json")),
            "runnerContract": sha256(script.with_name("RUNNER-CONTRACT.json")),
            "runner": sha256(script),
            "child": sha256(script.with_name("render_north_v13_process_a_child.py")),
        },
        "checks": checks,
        "counts": {
            "processA": 0, "blender": 0, "dcc": 0, "renders": 0,
            "pixels": 0, "normalizer": 0, "processB": 0, "processC": 0,
        },
        "sourceAuthority": False, "productionSelected": False,
        "canonicalWallClockFieldCount": 0,
    }
    validation = dict(common)
    validation.update({
        "result": "PASS_ZERO_CHILD_FRONTIER_REPAIR_R4",
        "prelaunchOnly": True,
        "forbiddenOutputsAbsent": ["future-process-root", "raw-png", "blend", "normalization", "live-grant"],
    })
    closure = dict(common)
    closure.update({
        "result": "READY_FOR_INDEPENDENT_REVIEW_ONLY", "prelaunchReady": True,
        "launchReady": False,
        "requiredNextAuthority": ["published schedule", "one-attempt lease", "authenticated grant/secret", "named compute slot"],
        "hardStop": "No live authority or DCC child is issued by this packet.",
        "executionAccountingPath": EXPECTED_EVIDENCE_ROOT + "/EXECUTION-ACCOUNTING.json",
    })
    return validation, closure


def _write_exclusive(dir_fd: int, name: str, payload: bytes) -> None:
    fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=dir_fd)
    try:
        os.write(fd, payload)
        os.fsync(fd)
    finally:
        os.close(fd)


def write_canonical_evidence(root: Path, target_root: Path) -> dict:
    """Write canonical receipts only into one absent, non-symlink root."""
    contract = load_json(Path(__file__).with_name("EXECUTION-CONTRACT.json"))
    validation, closure = _canonical_documents(contract, root)
    if target_root.exists() or target_root.is_symlink():
        raise ValueError("canonical evidence root must be absent")
    parent = target_root.parent
    if parent.is_symlink() or not parent.is_dir():
        raise ValueError("canonical evidence parent must be an existing real directory")
    parent_fd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.mkdir(target_root.name, mode=0o700, dir_fd=parent_fd)
        out_fd = os.open(target_root.name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent_fd)
    finally:
        os.close(parent_fd)
    try:
        _write_exclusive(out_fd, "PRELAUNCH-VALIDATION.json", json.dumps(validation, indent=2, sort_keys=True).encode("utf-8") + b"\n")
        _write_exclusive(out_fd, "ZERO-CHILD-CLOSURE.json", json.dumps(closure, indent=2, sort_keys=True).encode("utf-8") + b"\n")
    finally:
        os.close(out_fd)
    return {name: sha256(target_root / name) for name in ("PRELAUNCH-VALIDATION.json", "ZERO-CHILD-CLOSURE.json")}


def snapshot_topology(root: Path) -> dict:
    files: dict[str, str] = {}
    directories: list[str] = []
    symlinks: dict[str, str] = {}
    for base, dir_names, file_names in os.walk(root, topdown=True, followlinks=False):
        base_path = Path(base)
        relative_base = base_path.relative_to(root).as_posix()
        if relative_base != ".":
            directories.append(relative_base)
        kept: list[str] = []
        for name in sorted(dir_names):
            path = base_path / name
            rel = path.relative_to(root).as_posix()
            if path.is_symlink():
                symlinks[rel] = os.readlink(path)
            elif name != ".git":
                kept.append(name)
        dir_names[:] = kept
        for name in sorted(file_names):
            path = base_path / name
            rel = path.relative_to(root).as_posix()
            if path.is_symlink():
                symlinks[rel] = os.readlink(path)
            else:
                files[rel] = sha256(path)
    return {"directories": sorted(directories), "files": dict(sorted(files.items())), "symlinks": dict(sorted(symlinks.items()))}


def main(argv: list[str] | None = None) -> int:
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--evidence-root")
    parser.add_argument("--write-evidence", action="store_true")
    args = parser.parse_args(argv)
    repo = _validate_repository_root(args.repository_root)
    contract_path = (repo / args.contract).resolve()
    if contract_path != Path(__file__).with_name("EXECUTION-CONTRACT.json").resolve():
        raise SystemExit("wrong contract")
    contract = load_json(contract_path)
    validate_contract(repo, contract)
    if args.write_evidence:
        if not args.evidence_root:
            raise SystemExit("missing evidence root")
        write_canonical_evidence(repo, Path(args.evidence_root).resolve())
    print("PASS ZERO_CHILD_FRONTIER_REPAIR_R4 processA=0 blender=0 dcc=0 pixels=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
