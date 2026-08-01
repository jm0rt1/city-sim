"""North v13 integration-direct Process-A preflight.

This worker-side surface is deliberately validation-only.  It authenticates
the published route and frozen inputs, but never creates a schedule, lease,
secret, attempt marker, child, render, or pixel.  Integration owns the later
direct launch and its process receipt.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


ROUTE_ID = "quality-v1:north-v13-process-a-v02-live-authority-local-debug-v1"
ROUTE_SHA256 = "167301b26d50810952c841a160194cb4bac051f5078dacb43232796c9adf9dc8"
CARRIER_COMMIT = "45e1422304443a012a2f121c90be3e7d31b82c59"
RECEIPT_PATH = "docs/production/evidence/INTEGRATION/MODEL-ROUTING-PLAY-027-073-TECHNICAL-RETURNS-LUNA-V1.json"
RECEIPT_SHA256 = "bc83e9ae8b85acb1a40adf0a657ee11e3e95e5491745c5553889f90b85ae2692"
AUTHORITY_BASE = "68ef9bdf213b9b7f659f4a049f2f2708bcae166c"
EXECUTION_BASE = "57a89b916f3c97801f7f26e83ad3b6422bae3065"
CLAIM_SHA256 = "bf0b167a1d1e6f7007d609aeb657917fe9d3d0866d5a7a6e36b0e5a32faefa6f"
THREAD_ID = "019f96e0-3793-7542-9172-060a9ca09b0a"
WORKTREE = "/Users/James/.codex/worktrees/0648/city-sim"
ASSIGNED_WORKTREE = WORKTREE
BRANCH = "codex/citysim-world-art"
SOURCE_ROOT = "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-v02"
EVIDENCE_ROOT = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a-v02"
FUTURE_PROCESS_ROOT = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a"
ATTEMPT_MARKER_PATH = "docs/production/evidence/INTEGRATION/PLAY-027-NORTH-V13-PROCESS-A-ATTEMPT.json"
CHILD_NAME = "render_north_v13_process_a_child.py"
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
ALLOWED_PATHS = [
    f"{SOURCE_ROOT}/EXECUTION-CONTRACT.json",
    f"{SOURCE_ROOT}/RUNNER-CONTRACT.json",
    f"{SOURCE_ROOT}/launch_north_v13_process_a_v02.py",
    f"{SOURCE_ROOT}/{CHILD_NAME}",
    f"{SOURCE_ROOT}/test_process_a_v02.py",
    f"{EVIDENCE_ROOT}/HANDOFF.json",
    f"{EVIDENCE_ROOT}/ORCHESTRATOR-READINESS.json",
    f"{EVIDENCE_ROOT}/CURRENT-AUTHORITY-REBIND.json",
]


def canonical_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


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
    allowed = {"cat-file", "show", "rev-parse", "merge-base", "diff", "ls-files"}
    if not args or args[0] not in allowed:
        raise ValueError("unapproved Git helper")
    result = subprocess.run(
        ["git", *args], cwd=root, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
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


def _assert_no_symlink(root: Path, relative: str) -> Path:
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


def _changed_paths(root: Path) -> list[str]:
    tracked = _git(root, "diff", "--name-only", EXECUTION_BASE, "--")
    untracked = _git(root, "ls-files", "--others", "--exclude-standard")
    return sorted({line for raw in (tracked, untracked) for line in raw.decode().splitlines() if line})


def _allowed_changed_path(path: str) -> bool:
    return path in ALLOWED_PATHS


def _load_contract(root: Path, contract_path: str) -> dict:
    expected_path = root / SOURCE_ROOT / "EXECUTION-CONTRACT.json"
    supplied = _assert_no_symlink(root, contract_path)
    if supplied != expected_path or not supplied.is_file():
        raise ValueError("contract path is not the exact task-owned contract")
    expected = load_json(expected_path)
    exact_types(expected, load_json(supplied), "contract")
    if expected != load_json(supplied):
        raise ValueError("execution contract differs from its immutable bytes")
    return expected


def _verify_carrier(root: Path) -> dict:
    _git(root, "cat-file", "-e", CARRIER_COMMIT + "^{commit}")
    receipt = _git(root, "show", f"{CARRIER_COMMIT}:{RECEIPT_PATH}")
    if sha256_bytes(receipt) != RECEIPT_SHA256:
        raise ValueError("published route receipt hash mismatch")
    dispatch = json.loads(receipt)
    matches = [
        item for item in dispatch.get("assignments", [])
        if isinstance(item, dict) and isinstance(item.get("modelRoute"), dict)
        and item["modelRoute"].get("routeId") == ROUTE_ID
    ]
    if len(matches) != 1:
        raise ValueError("published route row missing or duplicated")
    wrapper = matches[0]
    route = wrapper["modelRoute"]
    if sha256_bytes(canonical_bytes(route)) != ROUTE_SHA256 or wrapper.get("modelRouteSha256") != ROUTE_SHA256:
        raise ValueError("published canonical route hash mismatch")
    assignment = route.get("assignment", {})
    if assignment.get("branch") != "codex/citysim-world-art" or assignment.get("worktree") != ASSIGNED_WORKTREE or assignment.get("expectedHead") != EXECUTION_BASE:
        raise ValueError("published assignment mismatch")
    authority = route.get("authority", {})
    if authority.get("authorityCommit") != AUTHORITY_BASE or authority.get("baseCommit") != AUTHORITY_BASE:
        raise ValueError("published authority/base mismatch")
    claim = authority.get("claim", {})
    if claim.get("path") != "docs/production/claims/PLAY-027.world-art.md" or claim.get("sha256") != CLAIM_SHA256:
        raise ValueError("published claim mismatch")
    allowed = route.get("pathPolicy", {}).get("allowed", [])
    if allowed != ALLOWED_PATHS:
        raise ValueError("published allowed roots mismatch")
    return {"carrierCommit": CARRIER_COMMIT, "receiptPath": RECEIPT_PATH, "receiptSHA256": RECEIPT_SHA256, "routeSHA256": ROUTE_SHA256}


def _verify_contract_bindings(root: Path, contract: dict) -> dict:
    if contract["route"] != {
        "routeId": ROUTE_ID, "canonicalSHA256": ROUTE_SHA256, "carrierCommit": CARRIER_COMMIT,
        "receiptPath": RECEIPT_PATH, "receiptSHA256": RECEIPT_SHA256,
        "authorityCommit": AUTHORITY_BASE, "baseCommit": AUTHORITY_BASE, "executionBaseHEAD": EXECUTION_BASE,
    }:
        raise ValueError("contract route binding mismatch")
    if contract["claim"] != {"path": "docs/production/claims/PLAY-027.world-art.md", "sha256": CLAIM_SHA256, "revision": 10}:
        raise ValueError("contract claim binding mismatch")
    if contract["assignment"] != {"threadId": THREAD_ID, "branch": BRANCH, "worktree": WORKTREE}:
        raise ValueError("contract assignment mismatch")
    if contract["identity"] != {
        "logicalBuildingID": "industrial_l04", "variantID": "variant-0", "viewDirection": "north",
        "processID": "A", "slotID": "north:A", "sourceRevision": "blender-art-v13-design-authority",
        "sceneGeometryID": "industrial-l04-north-v13-portal-crown-foundry",
        "samplingContract": "blender-cycles-cpu-v13-design-authority", "sourceAuthority": False, "productionSelected": False,
    }:
        raise ValueError("contract identity mismatch")
    output = contract["output"]
    if output["sourceRoot"] != SOURCE_ROOT or output["evidenceRoot"] != EVIDENCE_ROOT or output["futureProcessRoot"] != FUTURE_PROCESS_ROOT:
        raise ValueError("contract output roots mismatch")
    if output["allowedRoots"] != [SOURCE_ROOT, EVIDENCE_ROOT]:
        raise ValueError("contract allowed roots mismatch")
    direct = contract["integrationDirect"]
    if direct != {
        "schedulePathRequired": True, "scheduleCreatedByWorker": False,
        "processReceiptPathRequired": True, "processReceiptCreatedByWorker": False,
        "attemptMarkerCreatedByWorker": False, "childConstructionAllowedInZeroChild": False,
        "executableForIntegration": True,
        "maximumDCCChildStarts": 1, "maximumProcessAStarts": 1,
        "executionOwner": "Integration", "workerMode": "validation-only",
    }:
        raise ValueError("integration-direct contract mismatch")
    launch = contract["directLaunch"]
    if launch != {
        "scheduleSchema": 1, "receiptSchema": 1,
        "schedulePublicationCommitRequired": True, "schedulePublicationBlobRequired": True,
        "receiptMustBindScheduleBytes": True, "receiptMustBindWorkerHead": True,
        "attemptMarkerPath": ATTEMPT_MARKER_PATH, "attemptMarkerOutsideOutputRoot": True,
        "attemptMarkerMustPreexist": True, "attemptMarkerAtomicConsumption": True,
        "attemptMarkerStates": ["available", "consumed"], "childRequiresConsumedAttempt": True,
        "outputRootMustBeAbsentBeforeLaunch": True, "fixedBlenderExecutable": BLENDER,
        "fixedBlenderArgs": ["--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1"],
        "childFlag": "--integration-direct",
        "childOutputs": ["raw.png", "provenance.json", "OBJECT-MANIFEST.json", "INPUT-BINDINGS.json"],
        "childStartMarkerSuffix": ".child-start", "captureMode": "communicate",
        "maximumSubprocessStarts": 1,
    }:
        raise ValueError("integration-direct launch contract mismatch")
    return direct


def validate_frozen_inputs(root: Path, contract: dict) -> list[dict[str, str]]:
    items = contract["inputs"]
    immutable_contract = load_json(root / SOURCE_ROOT / "EXECUTION-CONTRACT.json")
    if items != immutable_contract["inputs"]:
        raise ValueError("caller-supplied immutable input set differs from the committed contract")
    for item in items:
        path = _assert_no_symlink(root, item["path"])
        if not path.is_file() or sha256_file(path) != item["sha256"]:
            raise ValueError(f"frozen input mismatch: {item['path']}")
    claim = _assert_no_symlink(root, contract["claim"]["path"])
    if sha256_file(claim) != CLAIM_SHA256:
        raise ValueError("claim bytes mismatch")
    return items


def validate_schedule_path(root: Path, value: str | None, label: str) -> str:
    if type(value) is not str or not value:
        raise ValueError(f"{label} is required; Integration must supply it")
    path = Path(value)
    if path.is_absolute() or path.as_posix() != value or value.endswith("/") or ".." in path.parts or "." in path.parts:
        raise ValueError(f"{label} must be a normalized repository-relative path")
    if not value.startswith("docs/production/evidence/INTEGRATION/"):
        raise ValueError(f"{label} is outside the Integration authority namespace")
    _assert_no_symlink(root, value)
    return value


def _authority_exclusion_paths(schedule_path: str, receipt_path: str) -> tuple[str, str, str]:
    if type(schedule_path) is not str or type(receipt_path) is not str:
        raise ValueError("validated authority paths must be strings")
    if schedule_path == receipt_path or schedule_path == ATTEMPT_MARKER_PATH or receipt_path == ATTEMPT_MARKER_PATH:
        raise ValueError("schedule, receipt, and attempt marker paths must be distinct")
    if not schedule_path.startswith("docs/production/evidence/INTEGRATION/") or not receipt_path.startswith("docs/production/evidence/INTEGRATION/"):
        raise ValueError("validated authority paths must remain in the Integration namespace")
    return (schedule_path, receipt_path, ATTEMPT_MARKER_PATH)


def _required_fields(value: dict, expected: dict, label: str) -> None:
    exact_types(value, expected, label)
    if value.keys() != expected.keys():
        raise ValueError(f"{label} fields are not closed")


def _full_commit(value: object, label: str) -> str:
    if type(value) is not str or len(value) != 40 or any(ch not in "0123456789abcdef" for ch in value):
        raise ValueError(f"{label} must be a full lowercase commit")
    return value


def _validate_publication(root: Path, commit: str, schedule_path: str, schedule_bytes: bytes, current_head: str) -> None:
    _full_commit(commit, "schedule publication commit")
    _git(root, "cat-file", "-e", commit + "^{commit}")
    _git(root, "merge-base", "--is-ancestor", commit, current_head)
    try:
        published = _git(root, "show", f"{commit}:{schedule_path}")
    except ValueError as exc:
        raise ValueError("schedule publication commit does not contain the exact schedule path") from exc
    if published != schedule_bytes:
        raise ValueError("published schedule blob differs from consumed schedule bytes")


def _marker_template(schedule: dict, receipt: dict, schedule_path: str, receipt_path: str, state: str, consumed: bool, schedule_sha256: str | None = None, receipt_sha256: str | None = None) -> dict:
    return {
        "schema": 1, "kind": "integration-process-attempt",
        "task": "PLAY-027", "slot": "north:A", "state": state, "attemptConsumed": consumed,
        "schedulePath": schedule_path, "scheduleSHA256": schedule_sha256 or sha256_bytes(canonical_bytes(schedule)),
        "schedulePublicationCommit": receipt["schedulePublicationCommit"],
        "receiptPath": receipt_path, "receiptSHA256": receipt_sha256 or sha256_bytes(canonical_bytes(receipt)),
        "workerHead": receipt["workerHead"], "outputRoot": FUTURE_PROCESS_ROOT, "evidenceRoot": EVIDENCE_ROOT,
        "orchestratorPath": schedule["orchestratorPath"], "orchestratorSHA256": schedule["orchestratorSHA256"],
        "childPath": schedule["childPath"], "childSHA256": schedule["childSHA256"],
        "maximumChildStarts": 1, "childStartMarker": ATTEMPT_MARKER_PATH + ".child-start",
    }


def _validate_attempt_marker(root: Path, marker_path: str, schedule: dict, receipt: dict, schedule_path: str, receipt_path: str, expected_state: str, schedule_sha256: str, receipt_sha256: str) -> dict:
    if marker_path != ATTEMPT_MARKER_PATH or marker_path.startswith(FUTURE_PROCESS_ROOT + "/"):
        raise ValueError("attempt marker must be the Integration-owned sibling outside the output root")
    marker_file = _assert_no_symlink(root, marker_path)
    if not marker_file.is_file():
        raise ValueError("Integration attempt marker must preexist")
    marker = load_json(marker_file)
    expected = _marker_template(schedule, receipt, schedule_path, receipt_path, expected_state, expected_state == "consumed", schedule_sha256, receipt_sha256)
    _required_fields(marker, expected, "attempt marker")
    if marker != expected:
        raise ValueError("attempt marker does not bind exact schedule/receipt/worker/output identities")
    return marker


def validate_direct_documents(root: Path, contract: dict, schedule_path: str, receipt_path: str, schedule_bytes: bytes, receipt_bytes: bytes) -> dict:
    current_head = _git(root, "rev-parse", "HEAD").decode().strip()
    schedule = json.loads(schedule_bytes.decode("utf-8"))
    receipt = json.loads(receipt_bytes.decode("utf-8"))
    schedule_template = {
        "schema": 1, "task": "PLAY-027", "batch": "industrial_l04_directional_family",
        "claimSHA256": CLAIM_SHA256, "authorityBase": AUTHORITY_BASE, "trustedIntegrationHead": AUTHORITY_BASE,
        "direction": "north", "process": "A", "slot": "north:A",
        "schedulePath": schedule_path,
        "orchestratorPath": SOURCE_ROOT + "/launch_north_v13_process_a_v02.py", "orchestratorSHA256": sha256_file(Path(__file__)),
        "childPath": SOURCE_ROOT + "/render_north_v13_process_a_child.py", "childSHA256": sha256_file(Path(__file__).with_name(CHILD_NAME)),
        "outputRoot": FUTURE_PROCESS_ROOT, "evidenceRoot": EVIDENCE_ROOT,
        "attemptMarkerPath": ATTEMPT_MARKER_PATH, "schedulePublicationCommit": AUTHORITY_BASE,
        "maximumChildStarts": 1,
    }
    _required_fields(schedule, schedule_template, "schedule")
    _full_commit(schedule["schedulePublicationCommit"], "schedule publication commit")
    if schedule["attemptMarkerPath"] != ATTEMPT_MARKER_PATH or schedule["schedulePath"] != schedule_path:
        raise ValueError("schedule marker/path identity mismatch")
    if schedule != schedule_template:
        raise ValueError("schedule identity does not match the frozen North contract")
    if schedule["schedulePublicationCommit"] != AUTHORITY_BASE:
        raise ValueError("schedule must bind the published Integration authority base")
    publication_commit = _full_commit(receipt.get("schedulePublicationCommit"), "receipt schedule publication commit")
    receipt_template = {
        "schema": 1, "kind": "integration-process-receipt", "task": "PLAY-027",
        "schedulePath": schedule_path, "scheduleSHA256": sha256_bytes(schedule_bytes),
        "schedulePublicationCommit": publication_commit, "claimSHA256": CLAIM_SHA256,
        "authorityBase": AUTHORITY_BASE, "trustedIntegrationHead": AUTHORITY_BASE,
        "workerHead": current_head, "direction": "north", "process": "A", "slot": "north:A",
        "orchestratorPath": schedule_template["orchestratorPath"], "orchestratorSHA256": schedule_template["orchestratorSHA256"],
        "childPath": schedule_template["childPath"], "childSHA256": schedule_template["childSHA256"],
        "outputRoot": FUTURE_PROCESS_ROOT, "evidenceRoot": EVIDENCE_ROOT,
        "attemptMarkerPath": schedule["attemptMarkerPath"], "attemptConsumed": True,
        "maximumChildStarts": 1, "receiptPath": receipt_path,
    }
    _required_fields(receipt, receipt_template, "process receipt")
    if receipt != receipt_template:
        raise ValueError("process receipt identity or schedule-byte binding mismatch")
    _validate_publication(root, publication_commit, schedule_path, schedule_bytes, current_head)
    if schedule["trustedIntegrationHead"] != AUTHORITY_BASE:
        raise ValueError("trusted Integration head mismatch")
    return {"schedule": schedule, "receipt": receipt, "currentHead": current_head, "scheduleSHA256": receipt["scheduleSHA256"], "receiptSHA256": sha256_bytes(receipt_bytes)}


def build_launch_command(root: Path, contract: dict, schedule_path: str, receipt_path: str) -> list[str]:
    child = root / SOURCE_ROOT / CHILD_NAME
    return [
        BLENDER, "--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1",
        "--python", str(child), "--", "--integration-direct",
        "--repository-root", str(root), "--contract", str(root / SOURCE_ROOT / "EXECUTION-CONTRACT.json"),
        "--schedule-path", schedule_path, "--process-receipt-path", receipt_path,
        "--attempt-marker-path", ATTEMPT_MARKER_PATH,
        "--output-root", str(root / FUTURE_PROCESS_ROOT), "--evidence-root", str(root / EVIDENCE_ROOT),
    ]


def prepare_integration_launch(repository_root: str | Path, contract_path: str, schedule_path: str, process_receipt_path: str) -> dict:
    root = exact_repository_root(repository_root)
    contract = _load_contract(root, contract_path)
    schedule_path = validate_schedule_path(root, schedule_path, "schedule path")
    process_receipt_path = validate_schedule_path(root, process_receipt_path, "process receipt path")
    schedule_file = _assert_no_symlink(root, schedule_path)
    receipt_file = _assert_no_symlink(root, process_receipt_path)
    if not schedule_file.is_file() or not receipt_file.is_file():
        raise ValueError("Integration schedule and process receipt bytes are required")
    binding = validate_direct_documents(root, contract, schedule_path, process_receipt_path, schedule_file.read_bytes(), receipt_file.read_bytes())
    _validate_attempt_marker(root, binding["schedule"]["attemptMarkerPath"], binding["schedule"], binding["receipt"], schedule_path, process_receipt_path, "available", binding["scheduleSHA256"], binding["receiptSHA256"])
    authority_paths = _authority_exclusion_paths(schedule_path, process_receipt_path)
    preflight_result = _preflight(root, contract_path, schedule_path, process_receipt_path, FUTURE_PROCESS_ROOT, authority_paths)
    output_root = _assert_no_symlink(root, FUTURE_PROCESS_ROOT)
    if output_root.exists():
        raise ValueError("exclusive output root must be absent before launch")
    command = build_launch_command(root, contract, schedule_path, process_receipt_path)
    if command.count(BLENDER) != 1 or command.count("--python") != 1:
        raise ValueError("fixed one-child command shape invalid")
    return {"preflight": preflight_result, "binding": binding, "attemptMarkerPath": ATTEMPT_MARKER_PATH, "validatedAuthorityExclusions": list(authority_paths), "command": command, "commandSHA256": sha256_bytes(canonical_bytes(command)), "launchReady": True, "childStarts": 0}


def _atomic_consume_attempt(prepared: dict, root: Path) -> dict:
    marker_path = _assert_no_symlink(root, prepared["attemptMarkerPath"])
    before = marker_path.stat()
    marker = _validate_attempt_marker(root, prepared["attemptMarkerPath"], prepared["binding"]["schedule"], prepared["binding"]["receipt"], prepared["binding"]["schedule"]["schedulePath"], prepared["binding"]["receipt"]["receiptPath"], "available", prepared["binding"]["scheduleSHA256"], prepared["binding"]["receiptSHA256"])
    consumed = _marker_template(prepared["binding"]["schedule"], prepared["binding"]["receipt"], prepared["binding"]["schedule"]["schedulePath"], prepared["binding"]["receipt"]["receiptPath"], "consumed", True, prepared["binding"]["scheduleSHA256"], prepared["binding"]["receiptSHA256"])
    temporary = marker_path.with_name(marker_path.name + ".consuming")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    fd = os.open(temporary, flags, 0o600)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(canonical_bytes(consumed))
            stream.flush()
            os.fsync(stream.fileno())
        if marker_path.stat().st_ino != before.st_ino or marker_path.stat().st_dev != before.st_dev:
            raise ValueError("attempt marker changed before atomic consumption")
        os.replace(temporary, marker_path)
        directory = os.open(str(marker_path.parent), os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    except Exception:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        raise
    return consumed


def execute_integration_direct(prepared: dict, root: Path) -> int:
    """Integration-only execution hook; worker validation never calls this."""
    _atomic_consume_attempt(prepared, root)
    output_root = root / FUTURE_PROCESS_ROOT
    output_root.mkdir(mode=0o700)
    environment = os.environ.copy()
    environment["CITYSIM_INTEGRATION_DIRECT"] = "1"
    process = subprocess.Popen(prepared["command"], cwd=root, env=environment, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    stdout, stderr = process.communicate()
    prepared["capture"] = {"stdoutSHA256": sha256_bytes(stdout), "stderrSHA256": sha256_bytes(stderr), "returncode": process.returncode}
    return process.returncode


def _preflight(repository_root: str | Path, contract_path: str, schedule_path: str | None, process_receipt_path: str | None, output_root: str | None, validated_authority_paths: tuple[str, str, str] = ()) -> dict:
    root = exact_repository_root(repository_root)
    contract = _load_contract(root, contract_path)
    _verify_contract_bindings(root, contract)
    carrier = _verify_carrier(root)
    if _git(root, "rev-parse", "--abbrev-ref", "HEAD").decode().strip() != BRANCH:
        raise ValueError("wrong branch")
    _git(root, "merge-base", "--is-ancestor", EXECUTION_BASE, _git(root, "rev-parse", "HEAD").decode().strip())
    schedule = validate_schedule_path(root, schedule_path, "schedule path")
    receipt = validate_schedule_path(root, process_receipt_path, "process receipt path")
    if validated_authority_paths:
        expected_authority_paths = _authority_exclusion_paths(schedule, receipt)
        if validated_authority_paths != expected_authority_paths:
            raise ValueError("authority exclusions do not match the validated schedule, receipt, and marker")
    changed = [path for path in _changed_paths(root) if path not in validated_authority_paths]
    if any(not _allowed_changed_path(path) for path in changed):
        raise ValueError("current delta escapes the two task-owned roots")
    validate_frozen_inputs(root, contract)
    expected_output = contract["output"]["futureProcessRoot"]
    if output_root is not None and output_root != expected_output:
        raise ValueError("output root is not the exact future Process-A root")
    future = _assert_no_symlink(root, expected_output)
    if future.exists():
        raise ValueError("future Process-A root already exists")
    evidence = root / EVIDENCE_ROOT
    if evidence.is_symlink():
        raise ValueError("evidence root may not be a symlink")
    return {
        "route": carrier,
        "branch": BRANCH,
        "executionBaseHEAD": EXECUTION_BASE,
        "observedHeadMustDescendFromBase": True,
        "changedPaths": changed,
        "validatedAuthorityExclusions": list(validated_authority_paths),
        "frozenInputCount": len(contract["inputs"]),
        "schedulePath": schedule,
        "schedulePresent": (root / schedule).is_file(),
        "processReceiptPath": receipt,
        "processReceiptPresent": (root / receipt).is_file(),
        "futureProcessRootAbsent": True,
        "workerCreatedSchedule": False,
        "workerCreatedProcessReceipt": False,
        "workerCreatedAttemptMarker": False,
        "dccChildStarts": 0,
        "processAStarts": 0,
        "pixelWrites": 0,
    }


def preflight(repository_root: str | Path, contract_path: str, schedule_path: str | None, process_receipt_path: str | None, output_root: str | None) -> dict:
    return _preflight(repository_root, contract_path, schedule_path, process_receipt_path, output_root)


def build_documents(preflight_result: dict, contract: dict, root: Path) -> tuple[dict, dict]:
    runner = Path(__file__).resolve()
    child = runner.with_name(CHILD_NAME)
    common = {
        "schema": 1,
        "task": "PLAY-027",
        "routeId": ROUTE_ID,
        "routeSHA256": ROUTE_SHA256,
        "authorityBase": AUTHORITY_BASE,
        "claimSHA256": CLAIM_SHA256,
        "assignment": {"threadId": THREAD_ID, "branch": BRANCH, "worktree": WORKTREE},
        "identity": contract["identity"],
        "frozenInputs": contract["inputs"],
        "roots": {"source": SOURCE_ROOT, "evidence": EVIDENCE_ROOT, "futureProcess": FUTURE_PROCESS_ROOT},
        "directLaunch": {"executableForIntegration": True, "launchReady": False, "fixedBlenderExecutable": BLENDER, "fixedBlenderArgs": ["--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1"], "childOutputs": ["raw.png", "provenance.json", "OBJECT-MANIFEST.json", "INPUT-BINDINGS.json"], "attemptMarkerPath": ATTEMPT_MARKER_PATH, "attemptMarkerOutsideOutputRoot": True, "schedulePublicationBlobRequired": True, "captureMode": "communicate", "commandConstruction": "deferred until exact schedule, committed schedule blob, process-receipt, and available attempt marker bytes are present"},
        "toolHashes": {"runner": sha256_file(runner), "child": sha256_file(child), "executionContract": sha256_file(runner.with_name("EXECUTION-CONTRACT.json")), "runnerContract": sha256_file(runner.with_name("RUNNER-CONTRACT.json"))},
        "preflight": preflight_result,
        "executionAccounting": {"readyNow": 0, "running": [], "waitingOnJoin": [], "serializedAuthority": "Integration direct launch", "nextRefill": "published schedule and one-attempt process receipt", "helperCapacity": 0, "dccCapacity": 0, "launchedJobs": [], "join": "joined", "unusedCapacityReasons": [{"reasonCode": "waiting_on_integration_direct_authority", "owner": "Integration", "dependencyAuthority": RECEIPT_PATH, "resumptionEvent": "published schedule/receipt", "nextRefillJob": "north:A"}]},
        "sourceAuthority": False,
        "productionSelected": False,
        "processA": "not_produced",
        "processBC": "not_produced",
        "pixels": "not_produced",
    }
    readiness = dict(common)
    readiness.update({"result": "PASS_ZERO_CHILD_ORCHESTRATOR_PREFLIGHT", "prelaunchOnly": True, "executableForIntegration": True, "launchReady": False, "writeScope": "task-owned evidence only", "forbiddenOutputsAbsent": ["schedule", "lease", "secret", "attempt-marker", "child", "blend", "raw-png", "normalized-png"]})
    handoff = dict(common)
    handoff.update({"stage": "predesign", "disposition": "predesign_ready", "executableForIntegration": True, "launchReady": False, "candidateReadyForIndependentReview": False, "knownBlockers": ["Integration must publish and consume the exact schedule, one-attempt receipt, and compute slot"], "stopCondition": "Stop before any child or pixel; Integration owns the later direct launch."})
    return readiness, handoff


def _write_exclusive(parent: Path, name: str, payload: bytes) -> None:
    parent_fd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent_fd)
        try:
            os.write(fd, payload)
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        os.close(parent_fd)


def write_evidence(root: Path, readiness: dict, handoff: dict) -> None:
    target = root / EVIDENCE_ROOT
    if target.exists() or target.is_symlink():
        raise ValueError("evidence root must be absent")
    parent = target.parent
    if parent.is_symlink() or not parent.is_dir():
        raise ValueError("evidence parent is unavailable")
    os.mkdir(target, 0o700)
    _write_exclusive(target, "ORCHESTRATOR-READINESS.json", json.dumps(readiness, indent=2, sort_keys=True).encode() + b"\n")
    _write_exclusive(target, "HANDOFF.json", json.dumps(handoff, indent=2, sort_keys=True).encode() + b"\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--schedule-path", required=True)
    parser.add_argument("--process-receipt-path", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--zero-child", action="store_true")
    parser.add_argument("--integration-direct", action="store_true")
    parser.add_argument("--write-evidence", action="store_true")
    args = parser.parse_args(argv)
    if args.zero_child == args.integration_direct:
        raise SystemExit("choose exactly one of --zero-child or --integration-direct")
    root = exact_repository_root(args.repository_root)
    contract = _load_contract(root, args.contract)
    if args.integration_direct:
        prepared = prepare_integration_launch(root, args.contract, args.schedule_path, args.process_receipt_path)
        return execute_integration_direct(prepared, root)
    result = preflight(root, args.contract, args.schedule_path, args.process_receipt_path, args.output_root)
    readiness, handoff = build_documents(result, contract, root)
    if args.write_evidence:
        write_evidence(root, readiness, handoff)
    print("PASS ZERO_CHILD_ORCHESTRATOR processA=0 dcc=0 pixels=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
