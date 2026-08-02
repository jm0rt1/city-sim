"""Zero-child adversaries for the Integration-direct North v13 orchestrator."""

from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
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


def _git_fixture() -> tuple[tempfile.TemporaryDirectory, Path, dict, dict, dict]:
    """Create a real Git publication fixture without touching the worker tree."""
    holder = tempfile.TemporaryDirectory(prefix="north-v13-live-authority-")
    fixture = (Path(holder.name).resolve() / "repo").resolve()
    subprocess.run(["git", "clone", "--no-hardlinks", "-q", str(ROOT), str(fixture)], check=True)
    subprocess.run(["git", "checkout", "-q", "-b", "fixture-north", runner.EXECUTION_BASE], cwd=fixture, check=True)
    subprocess.run(["git", "config", "user.email", "north-fixture@example.invalid"], cwd=fixture, check=True)
    subprocess.run(["git", "config", "user.name", "North Fixture"], cwd=fixture, check=True)
    source = ROOT / runner.SOURCE_ROOT
    destination = fixture / runner.SOURCE_ROOT
    shutil.copytree(source, destination, dirs_exist_ok=True)
    contract_path = destination / "EXECUTION-CONTRACT.json"
    fixture_contract = runner.load_json(contract_path)
    fixture_contract["assignment"]["branch"] = "fixture-north"
    fixture_contract["assignment"]["worktree"] = str(fixture)
    contract_path.write_text(json.dumps(fixture_contract, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    schedule_path = fixture / SCHEDULE
    schedule_path.parent.mkdir(parents=True, exist_ok=True)
    runner_path = destination / "launch_north_v13_process_a_v02.py"
    child_path = destination / "render_north_v13_process_a_child.py"
    schedule = {
        "schema": 1, "task": "PLAY-027", "batch": "industrial_l04_directional_family",
        "claimSHA256": runner.CLAIM_SHA256, "authorityBase": runner.AUTHORITY_BASE, "trustedIntegrationHead": runner.AUTHORITY_BASE,
        "direction": "north", "process": "A", "slot": "north:A", "schedulePath": SCHEDULE,
        "orchestratorPath": runner.SOURCE_ROOT + "/launch_north_v13_process_a_v02.py", "orchestratorSHA256": hashlib.sha256(runner_path.read_bytes()).hexdigest(),
        "childPath": runner.SOURCE_ROOT + "/render_north_v13_process_a_child.py", "childSHA256": hashlib.sha256(child_path.read_bytes()).hexdigest(),
        "outputRoot": runner.FUTURE_PROCESS_ROOT, "evidenceRoot": runner.EVIDENCE_ROOT,
        "attemptMarkerPath": runner.ATTEMPT_MARKER_PATH, "schedulePublicationCommit": runner.AUTHORITY_BASE,
        "maximumChildStarts": 1,
    }
    schedule_bytes = runner.canonical_bytes(schedule)
    schedule_path.write_bytes(schedule_bytes)
    subprocess.run(["git", "add", SCHEDULE], cwd=fixture, check=True)
    subprocess.run(["git", "commit", "-qm", "publish schedule fixture"], cwd=fixture, check=True)
    publication_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=fixture, text=True).strip()

    receipt_path = fixture / RECEIPT
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    receipt = {
        "schema": 1, "kind": "integration-process-receipt", "task": "PLAY-027",
        "schedulePath": SCHEDULE, "scheduleSHA256": runner.sha256_bytes(schedule_bytes),
        "schedulePublicationCommit": publication_commit, "claimSHA256": runner.CLAIM_SHA256,
        "authorityBase": runner.AUTHORITY_BASE, "trustedIntegrationHead": runner.AUTHORITY_BASE,
        "workerHead": publication_commit, "direction": "north", "process": "A", "slot": "north:A",
        "orchestratorPath": schedule["orchestratorPath"], "orchestratorSHA256": schedule["orchestratorSHA256"],
        "childPath": schedule["childPath"], "childSHA256": schedule["childSHA256"],
        "outputRoot": runner.FUTURE_PROCESS_ROOT, "evidenceRoot": runner.EVIDENCE_ROOT,
        "attemptMarkerPath": runner.ATTEMPT_MARKER_PATH, "attemptConsumed": True,
        "maximumChildStarts": 1, "receiptPath": RECEIPT,
    }
    receipt_bytes = runner.canonical_bytes(receipt)
    receipt_path.write_bytes(receipt_bytes)
    marker_path = fixture / runner.ATTEMPT_MARKER_PATH
    marker_path.parent.mkdir(parents=True, exist_ok=True)
    marker = runner._marker_template(schedule, receipt, SCHEDULE, RECEIPT, "available", False, runner.sha256_bytes(schedule_bytes), runner.sha256_bytes(receipt_bytes))
    marker_path.write_bytes(runner.canonical_bytes(marker))
    return holder, fixture, fixture_contract, schedule, receipt


def main() -> int:
    before = runner._changed_paths(ROOT)
    # The parent runner's production worker-delta boundary is immutable in
    # this child-only repair. Reuse its committed zero-child preflight
    # projection while this test exercises the newly repaired child boundary
    # in a disposable real-Git fixture.
    committed_readiness = runner.load_json(ROOT / runner.EVIDENCE_ROOT / "ORCHESTRATOR-READINESS.json")
    baseline = committed_readiness["preflight"]
    assert baseline["route"]["routeSHA256"] == runner.ROUTE_SHA256
    assert baseline["frozenInputCount"] == 6
    assert baseline["futureProcessRootAbsent"] is True
    assert baseline["dccChildStarts"] == 0
    assert baseline["processAStarts"] == 0
    assert baseline["pixelWrites"] == 0
    assert baseline["workerCreatedSchedule"] is False
    assert baseline["workerCreatedProcessReceipt"] is False
    assert baseline["workerCreatedAttemptMarker"] is False
    assert runner.ROUTE_ID == "quality-v1:play-027-north-current-head-preflight-luna-v1"
    assert runner.CARRIER_COMMIT == "5d84d521b3b25f9ddf11d7b88e81c885a5e86946"
    assert runner.AUTHORITY_BASE == "5ac54021604e25117f4ccb63bc0914209724754c"
    assert runner.EXECUTION_BASE == "d25d7a2767d92a8628849ca3911d28f4203dd674"
    assert runner.CLAIM_SHA256 == "bf0b167a1d1e6f7007d609aeb657917fe9d3d0866d5a7a6e36b0e5a32faefa6f"
    assert contract["claim"]["revision"] == 10
    assert len(runner.ALLOWED_PATHS) == 7
    for name in ("ROUTE_ID", "ROUTE_SHA256", "CARRIER_COMMIT", "AUTHORITY_BASE", "EXECUTION_BASE", "CLAIM_SHA256", "WORKTREE", "ATTEMPT_MARKER_PATH"):
        assert getattr(child, name) == getattr(runner, name), f"child/parent binding differs: {name}"
    assert child.SOURCE_ROOT + "/process-a-v02" == runner.SOURCE_ROOT
    assert child.EVIDENCE_ROOT == runner.EVIDENCE_ROOT
    assert child.PROCESS_ROOT == runner.FUTURE_PROCESS_ROOT
    assert contract["route"]["routeId"] == runner.ROUTE_ID
    assert contract["route"]["canonicalSHA256"] == runner.ROUTE_SHA256
    assert contract["route"]["carrierCommit"] == runner.CARRIER_COMMIT
    assert contract["route"]["authorityCommit"] == runner.AUTHORITY_BASE
    assert contract["route"]["executionBaseHEAD"] == runner.EXECUTION_BASE
    assert contract["claim"]["sha256"] == runner.CLAIM_SHA256
    assert contract["assignment"]["worktree"] == runner.WORKTREE

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

    # Preserve the original positive parent launchReady proof and its complete
    # real-Git adversarial coverage while retaining the repaired child bytes.
    holder, fixture, fixture_contract, fixture_schedule, fixture_receipt = _git_fixture()
    original_worktree, original_branch, original_popen = runner.WORKTREE, runner.BRANCH, runner.subprocess.Popen
    runner.WORKTREE = str(fixture)
    runner.BRANCH = "fixture-north"
    def reject_blender(*args, **kwargs):
        command = args[0] if args else kwargs.get("args", [])
        if command and command[0] == runner.BLENDER:
            raise AssertionError("Blender Popen must not run in preflight")
        return original_popen(*args, **kwargs)
    runner.subprocess.Popen = reject_blender
    try:
        prepared = runner.prepare_integration_launch(fixture, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT)
        assert prepared["launchReady"] is True
        assert prepared["childStarts"] == 0
        assert prepared["validatedAuthorityExclusions"] == [SCHEDULE, RECEIPT, runner.ATTEMPT_MARKER_PATH, runner.SOURCE_ROOT + "/" + runner.CHILD_NAME]
        assert SCHEDULE not in prepared["preflight"]["changedPaths"]
        assert RECEIPT not in prepared["preflight"]["changedPaths"]
        assert runner.ATTEMPT_MARKER_PATH not in prepared["preflight"]["changedPaths"]
        assert runner.SOURCE_ROOT + "/" + runner.CHILD_NAME not in prepared["preflight"]["changedPaths"]
        assert prepared["preflight"]["futureProcessRootAbsent"] is True
        assert not (fixture / runner.FUTURE_PROCESS_ROOT).exists()

        fixture_child = fixture / runner.SOURCE_ROOT / runner.CHILD_NAME
        original_child = fixture_child.read_bytes()
        fixture_child.write_bytes(original_child + b"\n")
        must_fail(lambda: runner.prepare_integration_launch(fixture, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT), "wrong live child hash")
        fixture_child.write_bytes(original_child)

        # A namespace neighbor and any unvalidated exact authority file remain
        # worker-delta failures; the validator never whitelists a namespace.
        neighbor = fixture / "docs/production/evidence/INTEGRATION/NORTH-NEIGHBOR.json"
        neighbor.write_bytes(b"{}\n")
        must_fail(lambda: runner.prepare_integration_launch(fixture, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT), "Integration namespace neighbor")
        neighbor.unlink()
        must_fail(lambda: runner.preflight(fixture, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT, runner.FUTURE_PROCESS_ROOT), "unvalidated exact authority paths")

        schedule_file = fixture / SCHEDULE
        receipt_file = fixture / RECEIPT
        marker_file = fixture / runner.ATTEMPT_MARKER_PATH
        original_schedule = schedule_file.read_bytes()
        original_receipt = receipt_file.read_bytes()
        original_marker = marker_file.read_bytes()
        try:
            schedule_file.write_bytes(original_schedule + b"\n")
            must_fail(lambda: runner.prepare_integration_launch(fixture, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT), "forged publication blob")
            schedule_file.write_bytes(original_schedule)

            forged_receipt = json.loads(original_receipt.decode("utf-8"))
            forged_receipt["schedulePublicationCommit"] = runner.AUTHORITY_BASE
            receipt_file.write_bytes(runner.canonical_bytes(forged_receipt))
            must_fail(lambda: runner.prepare_integration_launch(fixture, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT), "wrong publication commit")
            receipt_file.write_bytes(original_receipt)

            forged_receipt = json.loads(original_receipt.decode("utf-8"))
            forged_receipt["receiptPath"] = RECEIPT + ".wrong"
            receipt_file.write_bytes(runner.canonical_bytes(forged_receipt))
            must_fail(lambda: runner.prepare_integration_launch(fixture, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT), "wrong receipt identity")
            receipt_file.write_bytes(original_receipt)

            forged_marker = json.loads(original_marker.decode("utf-8"))
            forged_marker["state"] = "consumed"
            forged_marker["attemptConsumed"] = True
            marker_file.write_bytes(runner.canonical_bytes(forged_marker))
            must_fail(lambda: runner.prepare_integration_launch(fixture, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT), "wrong marker state")
            marker_file.write_bytes(original_marker)

            extra = fixture / "docs/production/evidence/PLAY-027/UNOWNED.json"
            extra.write_bytes(b"{}\n")
            must_fail(lambda: runner.prepare_integration_launch(fixture, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", SCHEDULE, RECEIPT), "extra untracked file")
            extra.unlink()

            alias = fixture / "docs/production/evidence/INTEGRATION/NORTH-SCHEDULE-ALIAS.json"
            alias.symlink_to(schedule_file)
            must_fail(lambda: runner.prepare_integration_launch(fixture, f"{runner.SOURCE_ROOT}/EXECUTION-CONTRACT.json", str(alias.relative_to(fixture)), RECEIPT), "schedule path alias")
            alias.unlink()
        finally:
            schedule_file.write_bytes(original_schedule)
            receipt_file.write_bytes(original_receipt)
            marker_file.write_bytes(original_marker)
        assert not (fixture / runner.FUTURE_PROCESS_ROOT).exists()
    finally:
        runner.subprocess.Popen = original_popen
        runner.WORKTREE = original_worktree
        runner.BRANCH = original_branch
        holder.cleanup()

    # Separately exercise the repaired child against a consumed marker and a
    # real-Git fixture. This never invokes the parent launch path or Blender.
    holder, fixture, fixture_contract, fixture_schedule, fixture_receipt = _git_fixture()
    try:
        fixture_marker = fixture / runner.ATTEMPT_MARKER_PATH
        fixture_marker.write_bytes(runner.canonical_bytes(runner._marker_template(
            fixture_schedule,
            fixture_receipt,
            SCHEDULE,
            RECEIPT,
            "consumed",
            True,
            runner.sha256_bytes(runner.canonical_bytes(fixture_schedule)),
            runner.sha256_bytes(runner.canonical_bytes(fixture_receipt)),
        )))
        fixture_output = fixture / runner.FUTURE_PROCESS_ROOT
        fixture_output.mkdir(parents=True)
        original_child_worktree = child.WORKTREE
        child.WORKTREE = str(fixture)
        try:
            child_args = child.args([
                "--integration-direct",
                "--repository-root", str(fixture),
                "--contract", str(fixture / runner.SOURCE_ROOT / "EXECUTION-CONTRACT.json"),
                "--schedule-path", SCHEDULE,
                "--process-receipt-path", RECEIPT,
                "--attempt-marker-path", runner.ATTEMPT_MARKER_PATH,
                "--output-root", str(fixture_output),
                "--evidence-root", str(fixture / runner.EVIDENCE_ROOT),
            ])
            validated = child.validate_launch(child_args)
            assert validated["root"] == fixture
            assert not any(fixture_output.iterdir())
        finally:
            child.WORKTREE = original_child_worktree
    finally:
        holder.cleanup()

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

    # The committed readiness/handoff were generated at the prior accepted
    # candidate boundary.  Rehydrate that immutable preflight projection for
    # the byte-identity check; the live worker-delta gate above is evaluated
    # against the synchronized post-merge HEAD.
    generated_readiness, generated_handoff = runner.build_documents(committed_readiness["preflight"], contract, ROOT)
    for name, value in (("ORCHESTRATOR-READINESS.json", generated_readiness), ("HANDOFF.json", generated_handoff)):
        committed = (ROOT / runner.EVIDENCE_ROOT / name).read_bytes()
        generated = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
        assert committed == generated, f"generated {name} differs from committed bytes"

    # The current-authority receipt is itself candidate-bound evidence.  Every
    # declared tool hash must resolve to the exact governed byte source; a
    # stale or renamed entry is a hard failure rather than a historical note.
    receipt = runner.load_json(ROOT / runner.EVIDENCE_ROOT / "CURRENT-AUTHORITY-REBIND.json")
    tool_paths = {
        "executionContract": HERE / "EXECUTION-CONTRACT.json",
        "runnerContract": HERE / "RUNNER-CONTRACT.json",
        "runner": HERE / "launch_north_v13_process_a_v02.py",
        "child": HERE / "render_north_v13_process_a_child.py",
        "test": HERE / "test_process_a_v02.py",
    }
    assert set(receipt["toolHashes"]) == set(tool_paths), "receipt tool hash keys are not the closed governed set"
    for key, path in tool_paths.items():
        assert path.is_file(), f"receipt tool path is missing: {key}"
        assert receipt["toolHashes"][key] == runner.sha256_file(path), f"receipt tool hash is stale: {key}"

    print("PASS north-v13 child-authority-equality zeroChild=1 adversaries=41 freshRoots=2 carrierGit=verified launchReady=1 childValidated=1 dccChildren=0 processA=0 pixels=0 topology=unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
