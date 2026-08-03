"""Grant-gated Residential L1 Process-A boundary.

The worker-side path is intentionally executable for Integration but inert in
contained-smoke mode: it validates the frozen North inputs, assembles the
fixed Blender payload, and writes only deterministic task-owned evidence. A
production launch requires Integration-owned schedule, grant, receipt and
attempt state; this module never creates those authorities.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


ROUTE_ID = "quality-v2:play-090-residential-l01-variant1-north-process-a-executable-v1"
ROUTE_SHA256 = "f951fc6065b3a4c22f57a16843a0282d071d89b80bd84ec13cbb6a624030ec16"
CARRIER_COMMIT = "3dea03000b8cb05dbdd9bc5b8a6e629b13925f5a"
RECEIPT_PATH = "docs/production/evidence/INTEGRATION/MODEL-ROUTING-PLAY-090-RESIDENTIAL-L01-VARIANT1-NORTH-PROCESS-A-EXECUTABLE-V1.json"
RECEIPT_SHA256 = "06d4b5e8342b1682de24d5fcf328a37dd73857c6df9e8e8e53b7f33060f4d4d5"
AUTHORITY_COMMIT = "e8e884d53bb568ccc14128ca581c65302af35177"
EXECUTION_BASE = "caea709ae185a1c4ad734f1a343ffecfbbd0234d"
CLAIM_SHA256 = "3d28843b7cbd53c9f25e71163a6bd3e9821c340010f7303a0909e35b9251d6b2"
THREAD_ID = "019f96e0-3793-7542-9172-060a9ca09b0a"
WORKTREE = "/Users/James/.codex/worktrees/0648/city-sim"
BRANCH = "codex/citysim-world-art"
SOURCE_ROOT = "Native/CitySimNative/WorldArt/Blender/PLAY-090/residential-l01-variant1-north"
EVIDENCE_ROOT = "docs/production/evidence/PLAY-090"
CONTAINED_SMOKE_ROOT = "docs/production/evidence/PLAY-090/residential-l01-variant1-process-a-executable-v1/contained-smoke"
FUTURE_PROCESS_ROOT = "docs/production/evidence/PLAY-090/residential-l01-variant1-process-a"
CONTRACT_NAME = "EXECUTION-CONTRACT.json"
RUNNER_NAME = "RUNNER-CONTRACT.json"
CHILD_NAME = "render_residential_l01_process_a_child.py"
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
BLENDER_ARGS = ("--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1")
MAX_OUTPUT_BYTES = 65536


def canonical_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def pretty_bytes(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if type(value) is not dict:
        raise ValueError(f"JSON object required: {path}")
    return value


def exact_types(actual: object, expected: object, path: str = "value") -> None:
    if type(actual) is not type(expected):
        raise ValueError(f"exact JSON type mismatch at {path}")
    if isinstance(expected, dict):
        if set(actual) != set(expected):
            raise ValueError(f"exact JSON fields mismatch at {path}")
        for key in expected:
            exact_types(actual[key], expected[key], f"{path}/{key}")
    elif isinstance(expected, list):
        if len(actual) != len(expected):
            raise ValueError(f"exact JSON list length mismatch at {path}")
        for index, (a, e) in enumerate(zip(actual, expected)):
            exact_types(a, e, f"{path}/{index}")


def _git(root: Path, *args: str) -> bytes:
    if not args or args[0] not in {"cat-file", "show", "rev-parse", "merge-base", "diff", "ls-files"}:
        raise ValueError("unapproved Git helper")
    result = subprocess.run(["git", *args], cwd=root, stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode:
        raise ValueError(f"git {' '.join(args)} failed")
    return result.stdout


def exact_repository_root(value: str | Path) -> Path:
    raw = os.fspath(value)
    if type(raw) is not str or raw != WORKTREE:
        raise ValueError("repository root is not the assigned worktree")
    if not os.path.isabs(raw) or os.path.abspath(raw) != raw or os.path.realpath(raw) != raw:
        raise ValueError("repository root has a lexical or symlink alias")
    root = Path(raw)
    if root.is_symlink() or not root.is_dir():
        raise ValueError("repository root is not a real directory")
    return root


def safe_path(root: Path, relative: str) -> Path:
    path = root / relative
    try:
        parts = path.relative_to(root).parts
    except ValueError as exc:
        raise ValueError("path escapes repository") from exc
    current = root
    for part in parts:
        current /= part
        if current.is_symlink():
            raise ValueError(f"symlink path rejected: {relative}")
    return path


def _full_sha(value: object, label: str) -> str:
    if type(value) is not str or len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
        raise ValueError(f"{label} must be a full lowercase SHA-256")
    return value


def _full_commit(value: object, label: str) -> str:
    if type(value) is not str or len(value) != 40 or any(c not in "0123456789abcdef" for c in value):
        raise ValueError(f"{label} must be a full lowercase commit")
    return value


def _changed_paths(root: Path) -> list[str]:
    tracked = _git(root, "diff", "--name-only", EXECUTION_BASE, "--").decode().splitlines()
    untracked = _git(root, "ls-files", "--others", "--exclude-standard").decode().splitlines()
    return sorted({p for p in tracked + untracked if p})


def _verify_route(root: Path) -> None:
    if _git(root, "rev-parse", "--abbrev-ref", "HEAD").decode().strip() != BRANCH:
        raise ValueError("wrong branch")
    current = _git(root, "rev-parse", "HEAD").decode().strip()
    _git(root, "merge-base", "--is-ancestor", EXECUTION_BASE, current)
    _git(root, "cat-file", "-e", f"{CARRIER_COMMIT}^{{commit}}")
    route_bytes = _git(root, "show", f"{CARRIER_COMMIT}:{RECEIPT_PATH}")
    if sha256_bytes(route_bytes) != RECEIPT_SHA256:
        raise ValueError("published route receipt hash mismatch")
    dispatch = json.loads(route_bytes.decode("utf-8"))
    rows = [x for x in dispatch.get("assignments", []) if isinstance(x, dict) and isinstance(x.get("modelRoute"), dict)
            and x["modelRoute"].get("routeId") == ROUTE_ID]
    if len(rows) != 1:
        raise ValueError("selected route row missing or duplicated")
    row = rows[0]
    if row.get("modelRouteSha256") != ROUTE_SHA256 or sha256_bytes(canonical_bytes(row["modelRoute"])) != ROUTE_SHA256:
        raise ValueError("selected route canonical hash mismatch")
    route = row["modelRoute"]
    if route.get("authority", {}).get("authorityCommit") != AUTHORITY_COMMIT:
        raise ValueError("route authority mismatch")
    if route.get("assignment", {}).get("expectedHead") != EXECUTION_BASE:
        raise ValueError("route worker identity mismatch")
    if route.get("pathPolicy", {}).get("allowed") != [SOURCE_ROOT, EVIDENCE_ROOT]:
        raise ValueError("route allowed roots mismatch")


def validate_contract(root: Path, contract_path: str) -> dict:
    expected_path = root / SOURCE_ROOT / CONTRACT_NAME
    supplied = safe_path(root, contract_path)
    if supplied != expected_path or not supplied.is_file():
        raise ValueError("contract path is not the exact task-owned contract")
    contract = load_json(expected_path)
    if contract.get("route", {}).get("routeId") != ROUTE_ID or contract["route"]["canonicalSHA256"] != ROUTE_SHA256:
        raise ValueError("contract route binding mismatch")
    if contract.get("claim") != {"path": "docs/production/claims/PLAY-090.world-art-north.md", "sha256": CLAIM_SHA256, "revision": 1}:
        raise ValueError("contract claim binding mismatch")
    if contract.get("assignment", {}).get("branch") != BRANCH or contract["assignment"].get("worktree") != WORKTREE:
        raise ValueError("contract assignment mismatch")
    if contract.get("output", {}).get("allowedRoots") != [SOURCE_ROOT, EVIDENCE_ROOT]:
        raise ValueError("contract allowed roots mismatch")
    if contract.get("integrationDirect", {}).get("maximumDCCChildStarts") != 1:
        raise ValueError("child limit mismatch")
    for item in contract.get("inputs", []):
        path = safe_path(root, item["path"])
        if not path.is_file() or sha256_file(path) != item["sha256"]:
            raise ValueError(f"frozen input mismatch: {item['path']}")
    claim = safe_path(root, contract["claim"]["path"])
    if not claim.is_file() or sha256_file(claim) != CLAIM_SHA256:
        raise ValueError("claim bytes mismatch")
    return contract


def _authority_path(path: str, label: str, fixture_mode: bool) -> str:
    if type(path) is not str or not path or (not fixture_mode and Path(path).is_absolute()) or ".." in Path(path).parts:
        raise ValueError(f"{label} must be normalized")
    if fixture_mode:
        if not Path(path).is_absolute() or not str(Path(path).resolve()).startswith("/private/tmp/"):
            raise ValueError(f"fixture {label} must remain in /private/tmp")
    elif not path.startswith("docs/production/evidence/INTEGRATION/"):
        raise ValueError(f"{label} must be Integration-owned")
    return path


def validate_direct_documents(root: Path, contract: dict, schedule_path: str, grant_path: str,
                              receipt_path: str, fixture_mode: bool = False) -> dict:
    schedule_path = _authority_path(schedule_path, "schedule path", fixture_mode)
    grant_path = _authority_path(grant_path, "grant path", fixture_mode)
    receipt_path = _authority_path(receipt_path, "process receipt path", fixture_mode)
    schedule_file = Path(schedule_path) if fixture_mode else safe_path(root, schedule_path)
    grant_file = Path(grant_path) if fixture_mode else safe_path(root, grant_path)
    receipt_file = Path(receipt_path) if fixture_mode else safe_path(root, receipt_path)
    if not schedule_file.is_file() or not grant_file.is_file() or not receipt_file.is_file():
        raise ValueError("Integration schedule, grant and receipt are required")
    schedule_bytes, grant_bytes, receipt_bytes = schedule_file.read_bytes(), grant_file.read_bytes(), receipt_file.read_bytes()
    schedule, grant, receipt = map(lambda b: json.loads(b.decode("utf-8")), (schedule_bytes, grant_bytes, receipt_bytes))
    current = _git(root, "rev-parse", "HEAD").decode().strip()
    child = root / SOURCE_ROOT / CHILD_NAME
    orchestrator = root / SOURCE_ROOT / "launch_residential_l01_process_a.py"
    expected_schedule_path = "<fixture>/schedule.json" if fixture_mode else schedule_path
    expected_grant_path = "<fixture>/grant.json" if fixture_mode else grant_path
    expected_receipt_path = "<fixture>/receipt.json" if fixture_mode else receipt_path
    bound_head = EXECUTION_BASE if fixture_mode else current
    expected_schedule = {
        "schema": 1, "task": "PLAY-090", "routeId": ROUTE_ID, "slot": "north:A", "direction": "north", "process": "A",
        "claimSHA256": CLAIM_SHA256, "workerHead": bound_head, "schedulePath": expected_schedule_path, "grantPath": expected_grant_path,
        "processReceiptPath": expected_receipt_path, "orchestratorPath": SOURCE_ROOT + "/launch_residential_l01_process_a.py",
        "orchestratorSHA256": sha256_file(orchestrator), "childPath": SOURCE_ROOT + "/" + CHILD_NAME,
        "childSHA256": sha256_file(child), "outputRoot": FUTURE_PROCESS_ROOT, "evidenceRoot": EVIDENCE_ROOT,
        "maximumChildStarts": 1, "sourceAuthority": False, "productionSelected": False
    }
    exact_types(schedule, expected_schedule, "schedule")
    if schedule != expected_schedule:
        raise ValueError("schedule identity mismatch")
    schedule_sha = sha256_bytes(schedule_bytes)
    expected_grant = {"schema": 1, "grantId": "north:A", "scheduleSHA256": schedule_sha, "workerHead": bound_head,
                      "maximumChildStarts": 1, "consumed": False, "sourceAuthority": False, "productionSelected": False}
    exact_types(grant, expected_grant, "grant")
    if grant != expected_grant:
        raise ValueError("grant identity or consumption mismatch")
    expected_receipt = {"schema": 1, "kind": "integration-process-receipt", "task": "PLAY-090", "routeId": ROUTE_ID,
                        "schedulePath": expected_schedule_path, "scheduleSHA256": schedule_sha, "grantId": "north:A",
                        "workerHead": bound_head, "maximumChildStarts": 1, "sourceAuthority": False, "productionSelected": False}
    exact_types(receipt, expected_receipt, "receipt")
    if receipt != expected_receipt:
        raise ValueError("process receipt identity mismatch")
    return {"schedule": schedule, "grant": grant, "receipt": receipt, "scheduleSHA256": schedule_sha,
            "grantSHA256": sha256_bytes(grant_bytes), "receiptSHA256": sha256_bytes(receipt_bytes), "currentHead": bound_head,
            "observedHead": current,
            "schedulePath": schedule_path, "grantPath": grant_path, "receiptPath": receipt_path,
            "fixtureMode": fixture_mode}


def build_payload(root: Path, contract: dict, binding: dict) -> dict:
    child = root / SOURCE_ROOT / CHILD_NAME
    schedule_path = binding["schedulePath"]
    grant_path = binding["grantPath"]
    receipt_path = binding["receiptPath"]
    if binding.get("fixtureMode"):
        schedule_path = "<fixture>/schedule.json"
        grant_path = "<fixture>/grant.json"
        receipt_path = "<fixture>/receipt.json"
    command = [BLENDER, *BLENDER_ARGS, "--python", str(child), "--", "--integration-direct",
               "--repository-root", str(root), "--contract", str(root / SOURCE_ROOT / CONTRACT_NAME),
               "--schedule-path", schedule_path, "--grant-path", grant_path,
               "--process-receipt-path", receipt_path, "--output-root", str(root / FUTURE_PROCESS_ROOT)]
    if command.count(BLENDER) != 1 or command.count("--python") != 1:
        raise ValueError("fixed Blender command shape invalid")
    return {"schema": 1, "mode": "zero-child", "routeId": ROUTE_ID, "routeSHA256": ROUTE_SHA256,
            "workerHead": binding["currentHead"], "scheduleSHA256": binding["scheduleSHA256"],
            "grantSHA256": binding["grantSHA256"], "receiptSHA256": binding["receiptSHA256"],
            "command": command, "commandSHA256": sha256_bytes(canonical_bytes(command)),
            "dccChildStarts": 0, "processAStarts": 0, "pixelWrites": 0, "productionSelected": False,
            "sourceAuthority": False, "outputRoot": CONTAINED_SMOKE_ROOT}


def _write_exclusive(directory: Path, name: str, payload: bytes) -> None:
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    target = directory / name
    if target.exists() or target.is_symlink():
        if target.read_bytes() != payload:
            raise ValueError(f"non-identical existing evidence: {name}")
        return
    fd = os.open(str(target), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
    except Exception:
        try:
            target.unlink()
        except FileNotFoundError:
            pass
        raise


def run_zero_child(root: Path, contract_path: str, schedule_path: str, grant_path: str, receipt_path: str,
                   output_root: Path, fixture_mode: bool = False) -> dict:
    contract = validate_contract(root, contract_path)
    _verify_route(root)
    binding = validate_direct_documents(root, contract, schedule_path, grant_path, receipt_path, fixture_mode)
    payload = build_payload(root, contract, binding)
    smoke = {"schema": 1, "result": "PASS_CONTAINED_ZERO_CHILD", "routeId": ROUTE_ID,
             "payloadSHA256": sha256_bytes(canonical_bytes(payload)), "payload": payload,
             "productionDeniedWithoutGrant": True, "authority": {"scheduleSHA256": binding["scheduleSHA256"],
             "grantSHA256": binding["grantSHA256"], "receiptSHA256": binding["receiptSHA256"]},
             "frozenInputCount": len(contract["inputs"]), "dccChildStarts": 0, "processAStarts": 0,
             "pixelWrites": 0, "sourceAuthority": False, "productionSelected": False}
    encoded_payload, encoded_smoke = pretty_bytes(payload), pretty_bytes(smoke)
    if len(encoded_payload) + len(encoded_smoke) > MAX_OUTPUT_BYTES:
        raise ValueError("contained-smoke output exceeds bounded size")
    _write_exclusive(output_root, "PAYLOAD.json", encoded_payload)
    _write_exclusive(output_root, "CONTAINED-SMOKE.json", encoded_smoke)
    return smoke


def prepare_production(root: Path, contract_path: str, schedule_path: str | None, grant_path: str | None,
                       receipt_path: str | None) -> dict:
    if not schedule_path or not grant_path or not receipt_path:
        raise ValueError("production launch requires Integration schedule, grant and process receipt")
    contract = validate_contract(root, contract_path)
    _verify_route(root)
    binding = validate_direct_documents(root, contract, schedule_path, grant_path, receipt_path, False)
    output = safe_path(root, FUTURE_PROCESS_ROOT)
    if output.exists():
        raise ValueError("future Process-A output root must be absent")
    return build_payload(root, contract, binding) | {"launchReady": True, "childStarts": 0}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--schedule-path")
    parser.add_argument("--grant-path")
    parser.add_argument("--process-receipt-path")
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--zero-child", action="store_true")
    parser.add_argument("--integration-direct", action="store_true")
    parser.add_argument("--contained-smoke", action="store_true")
    args = parser.parse_args(argv)
    if args.zero_child == args.integration_direct:
        raise SystemExit("choose exactly one of --zero-child or --integration-direct")
    root = exact_repository_root(args.repository_root)
    if args.integration_direct:
        if os.environ.get("CITYSIM_INTEGRATION_DIRECT") != "1":
            raise ValueError("Integration-direct capability is not present")
        prepare_production(root, args.contract, args.schedule_path, args.grant_path, args.process_receipt_path)
        raise RuntimeError("production child launch is Integration-owned and not available in worker mode")
    fixture_mode = bool(args.contained_smoke)
    if fixture_mode:
        output = Path(args.output_root)
        if not (str(output).startswith("/private/tmp/") or args.output_root == CONTAINED_SMOKE_ROOT):
            raise ValueError("contained-smoke output root must be task-owned or disposable /private/tmp")
    else:
        if args.output_root != CONTAINED_SMOKE_ROOT:
            raise ValueError("zero-child output root is not the exact contained-smoke root")
        output = safe_path(root, args.output_root)
    run_zero_child(root, args.contract, args.schedule_path or "", args.grant_path or "", args.process_receipt_path or "",
                   output, fixture_mode)
    print("PASS ZERO_CHILD_ORCHESTRATOR processA=0 dcc=0 pixels=0 productionDeniedWithoutGrant=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
