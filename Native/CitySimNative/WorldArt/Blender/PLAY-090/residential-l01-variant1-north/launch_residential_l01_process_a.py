"""Atomic, grant-gated PLAY-090 North Blender launcher.

The only worker-executable runtime path is the route-authorized disposable
replay below ``/private/tmp/play090-residential-north-runtime-repair-v1``.
The same boundary can later consume Integration-owned production documents,
but this repair never creates or invokes those authorities.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time


ROUTE_ID = "quality-v2:play-090-residential-l01-variant1-north-runtime-repair-v1"
ROUTE_SHA256 = "c8cf8a789860088444a969bd5cad4cdbbedaecd50a8b275791ce3e5e37f17472"
CARRIER_COMMIT = "4fc75509a95f49fc4ae15d8a12df992c338679dd"
RECEIPT_PATH = "docs/production/evidence/INTEGRATION/MODEL-ROUTING-PLAY-090-RESIDENTIAL-L01-VARIANT1-NORTH-RUNTIME-REPAIR-V1.json"
RECEIPT_SHA256 = "2d2964e1b2f018949b66b5e6c098d0115a1d7b4fa8d19e50a6b7477788137cbb"
AUTHORITY_COMMIT = "46d105c97324b554e2ce76b8ad95b0591bf66340"
EXECUTION_BASE = "029d5759eb6887f6ee16a65f099f6bfe9cfd697a"
CLAIM_SHA256 = "3d28843b7cbd53c9f25e71163a6bd3e9821c340010f7303a0909e35b9251d6b2"
WORKTREE = "/Users/James/.codex/worktrees/0648/city-sim"
BRANCH = "codex/citysim-world-art"
SOURCE_ROOT = "Native/CitySimNative/WorldArt/Blender/PLAY-090/residential-l01-variant1-north"
EVIDENCE_ROOT = "docs/production/evidence/PLAY-090"
FUTURE_PROCESS_ROOT = "docs/production/evidence/PLAY-090/residential-l01-variant1-process-a"
RUNTIME_REPLAY_ROOT = Path("/private/tmp/play090-residential-north-runtime-repair-v1")
CONTRACT_NAME = "EXECUTION-CONTRACT.json"
LOWERING_NAME = "LOWERING-CONTRACT.json"
CHILD_NAME = "render_residential_l01_process_a_child.py"
BLENDER_RECEIPT_PATH = "docs/production/evidence/INTEGRATION/BLENDER-4.5.12-ARM64-STARTUP-RECEIPT-V1.json"
BLENDER_RECEIPT_SHA256 = "4202de8d3ffbb9f3094b1c2e78b30a4c7e26664bce8af74916147d6995eb36aa"
BLENDER = "/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender"
BLENDER_SHA256 = "0fa2ab6500e41bfd8114485b218a1e4aebf15b3d8cea90dc8398535291061506"
BLENDER_ARGS = ("--factory-startup", "--disable-autoexec", "--background", "--python-exit-code", "1")
IMMUTABLE_EXECUTION_CONTRACT_SHA256 = "35e4b10156980ef354f6aa8a90b087f316445d99c0b1ce73bd61e39c7039e409"


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
    if type(raw) is not str or raw != WORKTREE or not os.path.isabs(raw) or os.path.realpath(raw) != raw:
        raise ValueError("repository root is not the exact assigned worktree")
    root = Path(raw)
    if root.is_symlink() or not root.is_dir():
        raise ValueError("repository root is not a real directory")
    return root


def safe_repo_path(root: Path, relative: str) -> Path:
    if type(relative) is not str or not relative or Path(relative).is_absolute() or Path(relative).as_posix() != relative:
        raise ValueError("repository path is not normalized")
    path = root / relative
    try:
        parts = path.relative_to(root).parts
    except ValueError as exc:
        raise ValueError("path escapes repository") from exc
    current = root
    for part in parts:
        if part in {"", ".", ".."}:
            raise ValueError("unsafe repository path component")
        current /= part
        if current.is_symlink():
            raise ValueError("symlink path rejected")
    return path


def safe_private_path(value: str | Path, *, allow_root: bool = False) -> Path:
    raw = os.fspath(value)
    if type(raw) is not str or not os.path.isabs(raw) or os.path.abspath(raw) != raw or os.path.realpath(raw) != raw:
        raise ValueError("runtime replay path must be canonical and absolute")
    path = Path(raw)
    if path == RUNTIME_REPLAY_ROOT:
        if allow_root:
            return path
        raise ValueError("runtime replay output must use an exclusive child root")
    if RUNTIME_REPLAY_ROOT not in path.parents:
        raise ValueError("runtime replay path escapes the exact disposable root")
    current = RUNTIME_REPLAY_ROOT
    if current.is_symlink():
        raise ValueError("runtime replay root symlink rejected")
    for part in path.relative_to(RUNTIME_REPLAY_ROOT).parts:
        current /= part
        if current.is_symlink():
            raise ValueError("runtime replay symlink rejected")
    return path


def write_exclusive(path: Path, payload: bytes) -> None:
    if path.exists() or path.is_symlink():
        raise ValueError(f"exclusive output already exists: {path.name}")
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
    except Exception:
        try:
            path.unlink()
        except FileNotFoundError:
            pass
        raise


def verify_route(root: Path) -> dict:
    if _git(root, "rev-parse", "--abbrev-ref", "HEAD").decode().strip() != BRANCH:
        raise ValueError("wrong branch")
    current = _git(root, "rev-parse", "HEAD").decode().strip()
    _git(root, "merge-base", "--is-ancestor", EXECUTION_BASE, current)
    _git(root, "cat-file", "-e", f"{CARRIER_COMMIT}^{{commit}}")
    route_bytes = _git(root, "show", f"{CARRIER_COMMIT}:{RECEIPT_PATH}")
    if sha256_bytes(route_bytes) != RECEIPT_SHA256:
        raise ValueError("route carrier bytes mismatch")
    dispatch = json.loads(route_bytes)
    rows = [row for row in dispatch.get("assignments", []) if row.get("modelRoute", {}).get("routeId") == ROUTE_ID]
    if len(rows) != 1:
        raise ValueError("selected route missing or duplicated")
    row = rows[0]
    route = row["modelRoute"]
    if row.get("modelRouteSha256") != ROUTE_SHA256 or sha256_bytes(canonical_bytes(route)) != ROUTE_SHA256:
        raise ValueError("route canonical hash mismatch")
    if route.get("authority", {}).get("authorityCommit") != AUTHORITY_COMMIT:
        raise ValueError("route authority mismatch")
    if route.get("assignment", {}).get("expectedHead") != EXECUTION_BASE:
        raise ValueError("route expected starting HEAD mismatch")
    if route.get("pathPolicy", {}).get("allowed") != [SOURCE_ROOT, EVIDENCE_ROOT]:
        raise ValueError("route allowed roots mismatch")
    return {"currentHead": current, "route": route}


def validate_contract(root: Path, contract_value: str) -> dict:
    contract_path = safe_repo_path(root, contract_value)
    expected = root / SOURCE_ROOT / CONTRACT_NAME
    if contract_path != expected or not expected.is_file():
        raise ValueError("contract path mismatch")
    contract = load_json(expected)
    if sha256_file(expected) != IMMUTABLE_EXECUTION_CONTRACT_SHA256:
        raise ValueError("immutable execution contract drift")
    if contract.get("route", {}).get("routeId") != "quality-v2:play-090-residential-l01-variant1-north-process-a-executable-v1":
        raise ValueError("immutable predecessor contract identity mismatch")
    if contract.get("claim") != {"path": "docs/production/claims/PLAY-090.world-art-north.md", "sha256": CLAIM_SHA256, "revision": 1}:
        raise ValueError("contract claim mismatch")
    for item in contract.get("inputs", [])[:2]:
        path = safe_repo_path(root, item["path"])
        if not path.is_file() or sha256_file(path) != item["sha256"]:
            raise ValueError(f"frozen input mismatch: {item['path']}")
    lowering = root / SOURCE_ROOT / LOWERING_NAME
    if not lowering.is_file():
        raise ValueError("lowering contract missing")
    lowered = load_json(lowering)
    if lowered.get("routeId") != ROUTE_ID or lowered.get("routeSHA256") != ROUTE_SHA256 or lowered.get("componentCount") != 19:
        raise ValueError("lowering contract identity mismatch")
    if sha256_file(root / contract["claim"]["path"]) != CLAIM_SHA256:
        raise ValueError("claim bytes mismatch")
    return contract


def verify_blender(root: Path) -> dict:
    receipt_bytes = _git(root, "show", f"{CARRIER_COMMIT}:{BLENDER_RECEIPT_PATH}")
    if sha256_bytes(receipt_bytes) != BLENDER_RECEIPT_SHA256:
        raise ValueError("Blender startup receipt mismatch")
    receipt = json.loads(receipt_bytes)
    executable = receipt.get("executable", {})
    if receipt.get("status") != "PASS" or executable.get("path") != BLENDER or executable.get("sha256") != BLENDER_SHA256:
        raise ValueError("Blender receipt identity mismatch")
    if executable.get("architecture") != "arm64" or executable.get("version") != "4.5.12 LTS" or executable.get("buildHash") != "84afd5f785f7":
        raise ValueError("Blender receipt tuple mismatch")
    if platform.machine() != "arm64":
        raise ValueError("host architecture drift")
    binary = Path(BLENDER)
    if not binary.is_file() or binary.is_symlink() or sha256_file(binary) != BLENDER_SHA256:
        raise ValueError("admitted Blender binary drift")
    return receipt


def _document_file(root: Path, value: str, fixture: bool) -> Path:
    if fixture:
        path = safe_private_path(value)
        if not path.is_file():
            raise ValueError("fixture authority document missing")
        return path
    if not value.startswith("docs/production/evidence/INTEGRATION/"):
        raise ValueError("production authority document is not Integration-owned")
    path = safe_repo_path(root, value)
    if not path.is_file():
        raise ValueError("production authority document missing")
    return path


def validate_documents(root: Path, contract: dict, schedule_path: str, grant_path: str,
                       receipt_path: str, output_root: str, fixture: bool) -> dict:
    schedule_file = _document_file(root, schedule_path, fixture)
    grant_file = _document_file(root, grant_path, fixture)
    receipt_file = _document_file(root, receipt_path, fixture)
    schedule_bytes, grant_bytes, receipt_bytes = (schedule_file.read_bytes(), grant_file.read_bytes(), receipt_file.read_bytes())
    schedule, grant, receipt = (json.loads(schedule_bytes), json.loads(grant_bytes), json.loads(receipt_bytes))
    current = _git(root, "rev-parse", "HEAD").decode().strip()
    child = root / SOURCE_ROOT / CHILD_NAME
    launcher = root / SOURCE_ROOT / "launch_residential_l01_process_a.py"
    lowering = root / SOURCE_ROOT / LOWERING_NAME
    output = safe_private_path(output_root) if fixture else safe_repo_path(root, output_root)
    if fixture:
        placeholders = {"schedule": "<fixture>/schedule.json", "grant": "<fixture>/grant.json", "receipt": "<fixture>/receipt.json",
                        "output": "<fixture>/output", "attempt": "<fixture>/attempt.json"}
    else:
        placeholders = {"schedule": schedule_path, "grant": grant_path, "receipt": receipt_path,
                        "output": output_root, "attempt": receipt.get("attemptMarkerPath")}
    expected_schedule = {
        "schema": 2, "task": "PLAY-090", "routeId": ROUTE_ID, "routeSHA256": ROUTE_SHA256,
        "slot": "north:A", "direction": "north", "process": "A", "claimSHA256": CLAIM_SHA256,
        "workerHead": current, "schedulePath": placeholders["schedule"], "grantPath": placeholders["grant"],
        "processReceiptPath": placeholders["receipt"], "attemptMarkerPath": placeholders["attempt"],
        "orchestratorPath": f"{SOURCE_ROOT}/launch_residential_l01_process_a.py", "orchestratorSHA256": sha256_file(launcher),
        "childPath": f"{SOURCE_ROOT}/{CHILD_NAME}", "childSHA256": sha256_file(child),
        "loweringPath": f"{SOURCE_ROOT}/{LOWERING_NAME}", "loweringSHA256": sha256_file(lowering),
        "outputRoot": placeholders["output"], "maximumChildStarts": 1, "blenderPath": BLENDER,
        "blenderSHA256": BLENDER_SHA256, "sourceAuthority": False, "productionSelected": False,
    }
    if schedule != expected_schedule:
        raise ValueError("schedule identity mismatch")
    schedule_sha = sha256_bytes(schedule_bytes)
    expected_grant = {"schema": 2, "grantId": "north:A", "scheduleSHA256": schedule_sha, "workerHead": current,
                      "maximumChildStarts": 1, "consumed": False, "sourceAuthority": False, "productionSelected": False}
    if grant != expected_grant:
        raise ValueError("grant identity or consumption mismatch")
    expected_receipt = {"schema": 2, "kind": "integration-process-receipt", "task": "PLAY-090", "routeId": ROUTE_ID,
                        "schedulePath": placeholders["schedule"], "scheduleSHA256": schedule_sha, "grantId": "north:A",
                        "workerHead": current, "attemptMarkerPath": placeholders["attempt"], "outputRoot": placeholders["output"],
                        "maximumChildStarts": 1, "sourceAuthority": False, "productionSelected": False}
    if receipt != expected_receipt:
        raise ValueError("process receipt identity mismatch")
    attempt = output.parent / "attempt.json" if fixture else safe_repo_path(root, receipt["attemptMarkerPath"])
    return {"schedule": schedule, "grant": grant, "receipt": receipt, "schedulePath": schedule_file,
            "grantPath": grant_file, "receiptPath": receipt_file, "scheduleSHA256": schedule_sha,
            "grantSHA256": sha256_bytes(grant_bytes), "receiptSHA256": sha256_bytes(receipt_bytes),
            "output": output, "attempt": attempt, "currentHead": current, "fixture": fixture}


def consume_attempt(root: Path, binding: dict) -> dict:
    output: Path = binding["output"]
    attempt: Path = binding["attempt"]
    if output.exists() or output.is_symlink() or attempt.exists() or attempt.is_symlink():
        raise ValueError("attempt or exclusive output root already exists")
    marker = {
        "schema": 2, "kind": "play090-runtime-attempt", "state": "consumed", "task": "PLAY-090", "routeId": ROUTE_ID,
        "workerHead": binding["currentHead"], "scheduleSHA256": binding["scheduleSHA256"],
        "grantSHA256": binding["grantSHA256"], "receiptSHA256": binding["receiptSHA256"],
        "outputRoot": "<fixture>/output" if binding["fixture"] else FUTURE_PROCESS_ROOT,
        "maximumChildStarts": 1, "childStartMarker": "<attempt>.child-start",
        "sourceAuthority": False, "productionSelected": False,
    }
    write_exclusive(attempt, pretty_bytes(marker))
    try:
        os.mkdir(output, mode=0o700)
    except Exception:
        raise RuntimeError("attempt consumed but exclusive output root creation failed")
    return marker


def fixed_command(root: Path, binding: dict) -> list[str]:
    child = root / SOURCE_ROOT / CHILD_NAME
    command = [BLENDER, *BLENDER_ARGS, "--python", str(child), "--", "--integration-direct"]
    if binding["fixture"]:
        command.append("--runtime-replay")
    command.extend(["--repository-root", str(root), "--contract", f"{SOURCE_ROOT}/{CONTRACT_NAME}",
                    "--schedule-path", str(binding["schedulePath"]), "--grant-path", str(binding["grantPath"]),
                    "--process-receipt-path", str(binding["receiptPath"]), "--attempt-marker-path", str(binding["attempt"]),
                    "--output-root", str(binding["output"])])
    if command.count(BLENDER) != 1 or command.count("--python") != 1:
        raise ValueError("fixed Blender command shape invalid")
    return command


def execute_one(root: Path, contract_path: str, schedule_path: str, grant_path: str,
                receipt_path: str, output_root: str, *, fixture: bool) -> dict:
    verify_route(root)
    contract = validate_contract(root, contract_path)
    verify_blender(root)
    binding = validate_documents(root, contract, schedule_path, grant_path, receipt_path, output_root, fixture)
    marker = consume_attempt(root, binding)
    command = fixed_command(root, binding)
    child_start = Path(os.fspath(binding["attempt"]) + ".child-start")
    start_marker = {"schema": 1, "attemptSHA256": sha256_file(binding["attempt"]), "commandSHA256": sha256_bytes(canonical_bytes(command)), "maximumChildStarts": 1}
    write_exclusive(child_start, pretty_bytes(start_marker))
    environment = os.environ.copy()
    environment.update({"CITYSIM_PLAY090_INTEGRATION_DIRECT": "1", "PYTHONHASHSEED": "0"})
    started = time.monotonic()
    process = subprocess.Popen(command, cwd=root, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, env=environment, start_new_session=True)
    stdout, stderr = process.communicate()
    duration = time.monotonic() - started
    result = {"schema": 1, "kind": "play090-launch-result", "exitCode": process.returncode, "pid": process.pid,
              "durationSeconds": round(duration, 6), "commandSHA256": start_marker["commandSHA256"],
              "stdoutSHA256": sha256_bytes(stdout), "stderrSHA256": sha256_bytes(stderr),
              "stdoutTail": stdout.decode("utf-8", "replace")[-4000:], "stderrTail": stderr.decode("utf-8", "replace")[-4000:],
              "attemptConsumed": True, "childStarts": 1, "sourceAuthority": False, "productionSelected": False}
    try:
        write_exclusive(binding["output"] / "LAUNCH-RESULT.json", pretty_bytes(result))
    except Exception:
        if process.returncode == 0:
            raise
    if process.returncode != 0:
        raise RuntimeError(f"Blender child failed ({process.returncode}): {result['stderrTail']}")
    required = load_json(root / SOURCE_ROOT / LOWERING_NAME)["artifacts"]
    missing = [name for name in required if not (binding["output"] / name).is_file()]
    if missing:
        raise RuntimeError(f"Blender child omitted required outputs: {missing}")
    return {"binding": binding, "marker": marker, "command": command, "result": result}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--schedule-path", required=True)
    parser.add_argument("--grant-path", required=True)
    parser.add_argument("--process-receipt-path", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--runtime-replay", action="store_true")
    parser.add_argument("--integration-direct", action="store_true")
    args = parser.parse_args(argv)
    if args.runtime_replay == args.integration_direct:
        raise SystemExit("choose exactly one runtime mode")
    root = exact_repository_root(args.repository_root)
    if args.integration_direct and os.environ.get("CITYSIM_INTEGRATION_DIRECT") != "1":
        raise ValueError("Integration production capability missing")
    execute_one(root, args.contract, args.schedule_path, args.grant_path, args.process_receipt_path,
                args.output_root, fixture=args.runtime_replay)
    print("PASS PLAY-090 ATOMIC BLENDER LAUNCH childStarts=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
