"""Zero-child adversaries for the Integration-direct North v13 orchestrator."""

from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile

os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load("north_v13_process_a_v02_runner", HERE / "launch_north_v13_process_a_v02.py")
child = load("north_v13_process_a_v02_child", HERE / "render_north_v13_process_a_child.py")
contract = runner.load_json(HERE / "EXECUTION-CONTRACT.json")

SCHEDULE = "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-NORTH-PROCESS-A-SCHEDULE.json"
RECEIPT = "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-NORTH-PROCESS-A-RECEIPT.json"


def must_fail(callable_, label: str) -> None:
    try:
        callable_()
    except (ValueError, RuntimeError, SystemExit, OSError):
        return
    raise AssertionError(f"adversary passed: {label}")


def digest(value: object) -> str:
    return hashlib.sha256(runner.canonical_bytes(value)).hexdigest()


def fresh_packet(root: Path, readiness: dict, handoff: dict) -> dict:
    root.mkdir()
    for name, value in (("ORCHESTRATOR-READINESS.json", readiness), ("HANDOFF.json", handoff)):
        (root / name).write_bytes(json.dumps(value, indent=2, sort_keys=True).encode() + b"\n")
    files = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(root.iterdir())}
    return {"directories": [], "files": files, "symlinks": {}}


def main() -> int:
    before = runner._changed_paths(ROOT)
    baseline = runner.preflight(ROOT, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT, runner.FUTURE_PROCESS_ROOT)
    assert baseline["route"]["routeSHA256"] == runner.ROUTE_SHA256
    assert baseline["frozenInputCount"] == 6
    assert baseline["futureProcessRootAbsent"] is True
    assert baseline["dccChildStarts"] == 0
    assert baseline["processAStarts"] == 0
    assert baseline["pixelWrites"] == 0
    assert baseline["workerCreatedSchedule"] is False
    assert baseline["workerCreatedProcessReceipt"] is False
    assert baseline["workerCreatedAttemptMarker"] is False

    # The direct launch surface requires both explicit Integration paths.
    must_fail(lambda: runner.preflight(ROOT, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", None, RECEIPT, runner.FUTURE_PROCESS_ROOT), "missing schedule path")
    must_fail(lambda: runner.preflight(ROOT, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, None, runner.FUTURE_PROCESS_ROOT), "missing process receipt path")
    must_fail(lambda: runner.preflight(ROOT, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", "/tmp/schedule.json", RECEIPT, runner.FUTURE_PROCESS_ROOT), "absolute schedule path")
    must_fail(lambda: runner.preflight(ROOT, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", "docs/production/evidence/INTEGRATION/../schedule.json", RECEIPT, runner.FUTURE_PROCESS_ROOT), "dot-dot schedule path")
    must_fail(lambda: runner.preflight(ROOT, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", "docs/production/claims/schedule.json", RECEIPT, runner.FUTURE_PROCESS_ROOT), "non-Integration schedule path")
    must_fail(lambda: runner.preflight(ROOT, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT, "docs/production/evidence/PLAY-027/escape"), "wrong output root")

    # Exact JSON types and identity are checked before any future output path.
    for field, value in (("schema", True), ("task", 27)):
        mutated = copy.deepcopy(contract)
        mutated[field] = value
        must_fail(lambda mutated=mutated: runner.exact_types(mutated, contract), f"contract type {field}")
    for path, value in (("routeId", "forged"), ("authorityCommit", "0" * 40)):
        mutated = copy.deepcopy(contract)
        if path == "routeId":
            mutated["route"][path] = value
        else:
            mutated["route"][path] = value
        must_fail(lambda mutated=mutated: runner._verify_contract_bindings(ROOT, mutated), f"contract identity {path}")
    for field, value in (("sourceAuthority", 0), ("productionSelected", 0)):
        mutated = copy.deepcopy(contract)
        mutated["identity"][field] = value
        must_fail(lambda mutated=mutated: runner.exact_types(mutated, contract), f"bool/int {field}")
    mutated = copy.deepcopy(contract)
    mutated["integrationDirect"]["maximumDCCChildStarts"] = True
    must_fail(lambda: runner.exact_types(mutated, contract), "bool/int child limit")

    # Exercise the executable path purely in memory: the schedule and receipt
    # are real-byte validated, but no repository authority files are created
    # and no subprocess call is made.
    schedule = {
        "schema": 1, "task": "PLAY-027", "batch": "industrial_l04_directional_family",
        "claimSHA256": runner.CLAIM_SHA256, "authorityBase": runner.AUTHORITY_BASE, "trustedIntegrationHead": runner.AUTHORITY_BASE,
        "direction": "north", "process": "A", "slot": "north:A", "schedulePath": SCHEDULE,
        "orchestratorPath": runner.SOURCE_ROOT + "/launch_north_v13_process_a_v02.py", "orchestratorSHA256": runner.sha256_file(HERE / "launch_north_v13_process_a_v02.py"),
        "childPath": runner.SOURCE_ROOT + "/render_north_v13_process_a_child.py", "childSHA256": runner.sha256_file(HERE / "render_north_v13_process_a_child.py"),
        "outputRoot": runner.FUTURE_PROCESS_ROOT, "evidenceRoot": runner.EVIDENCE_ROOT,
        "attemptMarkerPath": runner.ATTEMPT_MARKER_PATH, "schedulePublicationCommit": runner.AUTHORITY_BASE,
        "maximumChildStarts": 1,
    }
    schedule_bytes = runner.canonical_bytes(schedule)
    receipt = {
        "schema": 1, "kind": "integration-process-receipt", "task": "PLAY-027",
        "schedulePath": SCHEDULE, "scheduleSHA256": runner.sha256_bytes(schedule_bytes),
        "schedulePublicationCommit": runner.AUTHORITY_BASE, "claimSHA256": runner.CLAIM_SHA256,
        "authorityBase": runner.AUTHORITY_BASE, "trustedIntegrationHead": runner.AUTHORITY_BASE,
        "workerHead": runner._git(ROOT, "rev-parse", "HEAD").decode().strip(), "direction": "north", "process": "A", "slot": "north:A",
        "orchestratorPath": schedule["orchestratorPath"], "orchestratorSHA256": schedule["orchestratorSHA256"],
        "childPath": schedule["childPath"], "childSHA256": schedule["childSHA256"],
        "outputRoot": runner.FUTURE_PROCESS_ROOT, "evidenceRoot": runner.EVIDENCE_ROOT,
        "attemptMarkerPath": schedule["attemptMarkerPath"], "attemptConsumed": True,
        "maximumChildStarts": 1, "receiptPath": RECEIPT,
    }
    receipt_bytes = runner.canonical_bytes(receipt)
    # A caller-authored schedule that is merely an ancestor-shaped object is
    # rejected because its exact path/blob is not present at the publication
    # commit.  The positive publication proof below uses a real temporary Git
    # repository rather than a mocked Git response.
    must_fail(lambda: runner.validate_direct_documents(ROOT, contract, SCHEDULE, RECEIPT, schedule_bytes, receipt_bytes), "ancestor-only uncommitted schedule forgery")
    with tempfile.TemporaryDirectory(prefix="north-v13-publication-") as temp:
        publication_root = Path(temp)
        subprocess.run(["git", "init", "-q"], cwd=publication_root, check=True)
        subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=publication_root, check=True)
        subprocess.run(["git", "config", "user.name", "North Test"], cwd=publication_root, check=True)
        published_path = "docs/production/evidence/INTEGRATION/SCHEDULE.json"
        published_file = publication_root / published_path
        published_file.parent.mkdir(parents=True)
        published_bytes = b'{"schema":1}\n'
        published_file.write_bytes(published_bytes)
        subprocess.run(["git", "add", published_path], cwd=publication_root, check=True)
        subprocess.run(["git", "commit", "-qm", "publish schedule"], cwd=publication_root, check=True)
        publication_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=publication_root, text=True).strip()
        runner._validate_publication(publication_root, publication_commit, published_path, published_bytes, publication_commit)
        published_file.write_bytes(b'{"schema":2}\n')
        must_fail(lambda: runner._validate_publication(publication_root, publication_commit, published_path, published_file.read_bytes(), publication_commit), "working-tree schedule differs from committed blob")
    command = runner.build_launch_command(ROOT, contract, SCHEDULE, RECEIPT)
    assert command[0] == runner.BLENDER and command.count(runner.BLENDER) == 1 and command.count("--python") == 1 and runner.ATTEMPT_MARKER_PATH in command
    for mutate, label in (
        (lambda d: d.__setitem__("scheduleSHA256", "0" * 64), "receipt schedule hash"),
        (lambda d: d.__setitem__("workerHead", "0" * 40), "receipt worker head"),
        (lambda d: d.__setitem__("maximumChildStarts", 2), "receipt multi-child"),
        (lambda d: d.__setitem__("attemptConsumed", False), "replayed receipt"),
        (lambda d: d.__setitem__("outputRoot", "docs/production/claims/escape"), "receipt output root"),
    ):
        forged = copy.deepcopy(receipt)
        mutate(forged)
        must_fail(lambda forged=forged: runner.validate_direct_documents(ROOT, contract, SCHEDULE, RECEIPT, schedule_bytes, runner.canonical_bytes(forged)), label)
    forged_schedule = copy.deepcopy(schedule)
    forged_schedule["orchestratorSHA256"] = "0" * 64
    must_fail(lambda: runner.validate_direct_documents(ROOT, contract, SCHEDULE, RECEIPT, runner.canonical_bytes(forged_schedule), receipt_bytes), "wrong orchestrator command binding")
    impossible = copy.deepcopy(schedule)
    impossible["attemptMarkerPath"] = runner.FUTURE_PROCESS_ROOT + "/ATTEMPT.json"
    must_fail(lambda: runner.validate_direct_documents(ROOT, contract, SCHEDULE, RECEIPT, runner.canonical_bytes(impossible), receipt_bytes), "impossible marker inside absent output root")
    incomplete = copy.deepcopy(receipt)
    incomplete.pop("receiptPath")
    must_fail(lambda: runner.validate_direct_documents(ROOT, contract, SCHEDULE, RECEIPT, schedule_bytes, runner.canonical_bytes(incomplete)), "incomplete receipt")
    must_fail(lambda: runner.prepare_integration_launch(ROOT, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT), "missing live authority files")

    # Assigned worktree identity is exact; aliases and copied roots fail before
    # Git/content inspection.
    with tempfile.TemporaryDirectory(prefix="north-v13-v02-root-") as temp:
        temp_root = Path(temp)
        alias = temp_root / "alias"
        alias.symlink_to(ROOT, target_is_directory=True)
        copied = temp_root / "copied"
        copied.mkdir()
        (copied / ".git").write_text("gitdir: attacker\n", encoding="utf-8")
        for candidate in (str(alias), str(ROOT) + "/.", str(ROOT) + "/../city-sim", str(ROOT) + "/", str(copied)):
            must_fail(lambda candidate=candidate: runner.preflight(candidate, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT, runner.FUTURE_PROCESS_ROOT), "root alias/copy")

    # Frozen inputs and carrier are repository-backed; a copied route or caller
    # supplied authority cannot replace those checks.
    mutated = copy.deepcopy(contract)
    mutated["inputs"] = []
    must_fail(lambda: runner.validate_frozen_inputs(ROOT, mutated), "empty immutable input set")

    # The child is a hard-stop contract until it proves the consumed
    # Integration marker and all repository-backed identities.  Env/flags
    # alone cannot cross that boundary and bpy is not imported on failure.
    must_fail(child.main, "direct child invocation")
    must_fail(lambda: child.main(["--integration-direct", "--repository-root", str(ROOT), "--contract", str(ROOT / runner.SOURCE_ROOT / "EXECUTION-CONTRACT.json"), "--schedule-path", SCHEDULE, "--process-receipt-path", RECEIPT, "--attempt-marker-path", runner.ATTEMPT_MARKER_PATH, "--output-root", str(ROOT / runner.FUTURE_PROCESS_ROOT), "--evidence-root", str(ROOT / runner.EVIDENCE_ROOT)]), "forged direct child env/flags")
    assert not hasattr(runner, "build_signer")
    assert not hasattr(runner, "build_token")
    assert not hasattr(runner, "consume_attempt")
    assert not hasattr(runner, "create_attempt")

    # A replayed consumed marker is a distinct state and cannot be reused as
    # the available one-shot lease.  The actual file transition is Integration
    # owned and therefore not performed by this worker suite.
    available_marker = runner._marker_template(schedule, receipt, SCHEDULE, RECEIPT, "available", False, runner.sha256_bytes(schedule_bytes), runner.sha256_bytes(receipt_bytes))
    consumed_marker = runner._marker_template(schedule, receipt, SCHEDULE, RECEIPT, "consumed", True, runner.sha256_bytes(schedule_bytes), runner.sha256_bytes(receipt_bytes))
    assert available_marker["state"] == "available" and consumed_marker["state"] == "consumed" and available_marker != consumed_marker

    # Mock the one child and return output larger than a pipe buffer.  The
    # launcher must use communicate(), never wait() with undrained pipes.
    class FakeProcess:
        returncode = 0
        def communicate(self):
            return (b"x" * (256 * 1024), b"y" * (256 * 1024))
    original_popen = runner.subprocess.Popen
    original_consume = runner._atomic_consume_attempt
    original_future = runner.FUTURE_PROCESS_ROOT
    with tempfile.TemporaryDirectory(prefix="north-v13-pipe-") as temp:
        temp_root = Path(temp)
        runner.FUTURE_PROCESS_ROOT = "output"
        runner.subprocess.Popen = lambda *args, **kwargs: FakeProcess()
        runner._atomic_consume_attempt = lambda *args, **kwargs: consumed_marker
        try:
            code = runner.execute_integration_direct({"attemptMarkerPath": runner.ATTEMPT_MARKER_PATH, "binding": {"schedule": schedule, "receipt": receipt, "scheduleSHA256": runner.sha256_bytes(schedule_bytes), "receiptSHA256": runner.sha256_bytes(receipt_bytes)}, "command": ["mock-blender"]}, temp_root)
        finally:
            runner.subprocess.Popen = original_popen
            runner._atomic_consume_attempt = original_consume
            runner.FUTURE_PROCESS_ROOT = original_future
        assert code == 0

    # Two fresh packet roots receive the same deterministic documents. No
    # wall-clock, PID, temporary path, or live authority is admitted.
    readiness, handoff = runner.build_documents(baseline, contract, ROOT)
    assert readiness["sourceAuthority"] is False
    assert readiness["productionSelected"] is False
    assert readiness["processA"] == "not_produced"
    assert readiness["executionAccounting"]["launchedJobs"] == []
    assert handoff["disposition"] == "predesign_ready"
    with tempfile.TemporaryDirectory(prefix="north-v13-v02-replay-") as temp:
        temp_root = Path(temp)
        first = fresh_packet(temp_root / "a", readiness, handoff)
        second = fresh_packet(temp_root / "b", readiness, handoff)
        assert first == second
        assert digest(first) == digest(second)
        assert first["directories"] == [] and first["symlinks"] == {}

    after = runner._changed_paths(ROOT)
    assert before == after
    assert not (ROOT / runner.FUTURE_PROCESS_ROOT).exists()
    assert not (ROOT / "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-NORTH-PROCESS-A-RECEIPT.json").exists()
    assert not (ROOT / "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-NORTH-PROCESS-A-SCHEDULE.json").exists()

    tree = ast.parse((HERE / "launch_north_v13_process_a_v02.py").read_text(encoding="utf-8"))
    calls = [node for node in ast.walk(tree) if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name) and node.func.value.id == "subprocess"]
    assert sorted(call.func.attr for call in calls) == ["Popen", "run"]
    for path in (HERE / "launch_north_v13_process_a_v02.py", HERE / "render_north_v13_process_a_child.py"):
        source = path.read_text(encoding="utf-8")
        assert "PIL" not in source and "SceneKit" not in source
        if path.name == "launch_north_v13_process_a_v02.py":
            assert "bpy" not in source
        assert "render(" not in source or path.name == "render_north_v13_process_a_child.py"

    print("PASS north-v13 integration-direct-r2 zeroChild=1 adversaries=33 freshRoots=2 carrierGit=verified dccChildren=0 processA=0 pixels=0 topology=unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
