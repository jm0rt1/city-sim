#!/usr/bin/env python3
"""Zero-DCC executable-reference tests using real writers and fake processes."""
from __future__ import annotations

import ast
import copy
import importlib.util
import io
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[7]
PHASE_ROOT = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14/process-a-phase-ladder-v01"
CONTRACT_PATH = PHASE_ROOT / "DIAGNOSTIC-CONTRACT.json"
PHASES = ["python_entered", "frozen_inputs_verified", "source_module_loaded", "bpy_imported", "scene_configured", "all_96_meshes_created", "pre_micro_render", "post_micro_render", "complete"]


def module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def rejects(fn, contains: str | None = None):
    try:
        fn()
    except BaseException as error:
        if contains is not None:
            assert contains in str(error), (contains, str(error))
        return
    raise AssertionError("adversary unexpectedly accepted")


class FlushSpy(io.StringIO):
    def __init__(self):
        super().__init__()
        self.flushes = 0

    def flush(self):
        self.flushes += 1
        return super().flush()


class FakeProcess:
    def __init__(self, stdout: bytes, stderr: bytes = b"", returncode: int = 0, pid: int = 4242, timeout_once: bool = False, error_once: bool = False):
        self.pid = pid
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr
        self.timeout_once = timeout_once
        self.error_once = error_once
        self.calls = 0

    def communicate(self, timeout=None):
        self.calls += 1
        if self.timeout_once and self.calls == 1:
            raise subprocess.TimeoutExpired(["fake"], timeout)
        if self.error_once and self.calls == 1:
            raise OSError("injected communicate failure")
        return self.stdout, self.stderr


def git(root: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(root), *args], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return result.stdout.decode().strip()


def published_fixture(launcher, contract: dict, temp: Path):
    repo = temp / "publication"
    repo.mkdir()
    git(repo, "init")
    git(repo, "checkout", "-b", "master")
    git(repo, "config", "user.name", "PLAY-027 Test")
    git(repo, "config", "user.email", "play027@example.invalid")
    for relative in (launcher.CONTRACT_PATH, launcher.CHILD_PATH, launcher.ROOT_REL / "launch_phase_ladder.py"):
        target = repo / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, target)
    (repo / "seed").write_text("seed\n")
    git(repo, "add", ".")
    git(repo, "commit", "-m", "seed")
    worker_head = git(repo, "rev-parse", "HEAD")
    output_root = contract["futureStageB"]["outputRoot"]
    attempt = temp / "attempt.json"
    common = {"task": "PLAY-027", "direction": "north", "workerHead": worker_head, "routeId": contract["route"]["routeId"], "outputRoot": output_root, "sourceAuthority": False, "productionSelected": False}
    docs_root = repo / "docs/production/evidence/INTEGRATION"
    docs_root.mkdir(parents=True)
    paths = {name: docs_root / f"phase-{name}.json" for name in contract["externalAuthority"]["requiredDocuments"]}
    schedule = {**common, "kind": "industrial-l04-north-v14-phase-schedule-v1", "publication": {"path": paths["schedule"].relative_to(repo).as_posix()}, "claimSHA256": contract["route"]["claim"]["sha256"], "routeCarrierCommit": contract["route"]["carrierCommit"], "routeReceiptSHA256": contract["route"]["receiptSHA256"], "modelRouteSHA256": contract["route"]["modelRouteSHA256"], "blender": contract["blender"], "allowedOutputLeaves": contract["futureStageB"]["allowedOutputLeaves"], "microRender": contract["futureStageB"]["microRender"], "maximumChildStarts": 1, "maximumConcurrentDCCProcesses": 1, "timeoutSeconds": 120, "contractSHA256": launcher.sha256(repo / launcher.CONTRACT_PATH), "launcherSHA256": launcher.sha256(repo / launcher.ROOT_REL / "launch_phase_ladder.py"), "childSHA256": launcher.sha256(repo / launcher.CHILD_PATH), "attemptMarkerPath": str(attempt)}
    paths["schedule"].write_bytes(launcher.canonical(schedule))
    schedule_hash = launcher.sha256(paths["schedule"])
    grant = {**common, "kind": "industrial-l04-north-v14-phase-grant-v1", "publication": {"path": paths["grant"].relative_to(repo).as_posix()}, "scheduleSHA256": schedule_hash, "grantId": "north:phase-ladder:stage-b", "sessionId": "fixture-session", "maximumChildStarts": 1}
    paths["grant"].write_bytes(launcher.canonical(grant))
    grant_hash = launcher.sha256(paths["grant"])
    session = {**common, "kind": "industrial-l04-north-v14-phase-session-v1", "publication": {"path": paths["session"].relative_to(repo).as_posix()}, "scheduleSHA256": schedule_hash, "grantSHA256": grant_hash, "grantId": "north:phase-ladder:stage-b", "sessionId": "fixture-session", "dccSlot": "dcc-1"}
    paths["session"].write_bytes(launcher.canonical(session))
    approval = {**common, "kind": "industrial-l04-north-v14-phase-staticApproval-v1", "publication": {"path": paths["staticApproval"].relative_to(repo).as_posix()}, "scheduleSHA256": schedule_hash, "approved": True, "approvedCandidateHead": worker_head}
    paths["staticApproval"].write_bytes(launcher.canonical(approval))
    git(repo, "add", "docs")
    git(repo, "commit", "-m", "publish phase authority")
    fixture_contract = copy.deepcopy(contract)
    fixture_contract["externalAuthority"]["publicationRef"] = "refs/heads/master"
    hashes = {name: launcher.sha256(path) for name, path in paths.items()}
    attempt.write_bytes(launcher.canonical({"state": "AVAILABLE", "scheduleSHA256": hashes["schedule"], "grantSHA256": hashes["grant"], "sessionSHA256": hashes["session"], "staticApprovalSHA256": hashes["staticApproval"]}))
    identity = {"head": worker_head, "branch": "test", "root": str(repo)}
    return repo, fixture_contract, paths, identity, attempt


def marker_stream(child) -> bytes:
    spy = FlushSpy()
    for sequence, phase in enumerate(PHASES):
        child.emit_phase(phase, sequence, spy)
    assert spy.flushes == len(PHASES)
    return spy.getvalue().encode()


def main() -> None:
    contract = json.loads(CONTRACT_PATH.read_text())
    launcher = module(PHASE_ROOT / "launch_phase_ladder.py", "play027_phase_launcher")
    child = module(PHASE_ROOT / "phase_ladder_child.py", "play027_phase_child")
    prepared = launcher.prepare_zero_child(ROOT)
    assert prepared["status"] == "STATIC_REFERENCE_CANDIDATE" and prepared["childStarts"] == 0
    assert prepared["dccProcessCount"] == prepared["outputRootCreated"] == prepared["pixelWrites"] == 0
    assert prepared["executableBehavior"] == "UNPROVEN"
    assert contract["phaseLadder"]["ordered"] == PHASES
    governed = child.load_governed_child(ROOT)
    execution = child.load_object(ROOT / contract["immutableInputs"]["executionContract"]["path"])
    packet = governed.construct_semantic_geometry(ROOT, execution)
    specs = governed.build_mesh_specs(packet["manifest"])
    assert packet["report"]["componentCount"] == 33 and packet["report"]["objectCount"] == 97
    assert len(specs["solidSpecs"]) == 96
    assert not (ROOT / contract["futureStageB"]["outputRoot"]).exists()

    stream = marker_stream(child)
    assert len(launcher.parse_markers(stream, PHASES)) == 9
    rejects(lambda: launcher.parse_markers(stream.replace(b'"sequence":4', b'"sequence":5', 1), PHASES), "order")
    rejects(lambda: launcher.parse_markers(b'{"play027Phase":"python_entered","sequence":true}\n', PHASES), "types")
    rejects(lambda: child.emit_phase("complete", 0, FlushSpy()), "sequence")
    valid_marker = {"state": "CONSUMED", "launcherPID": 7}
    valid_start = {"launcherPID": 7, "state": "CHILD_STARTED", "workerHead": "h"}
    child.validate_consumed_launch(valid_marker, valid_start, parent_pid=7, worker_head="h")
    rejects(lambda: child.validate_consumed_launch({**valid_marker, "state": "AVAILABLE"}, valid_start, parent_pid=7, worker_head="h"), "consumed")
    rejects(lambda: child.validate_consumed_launch(valid_marker, valid_start, parent_pid=8, worker_head="h"), "parent")
    rejects(lambda: child.validate_consumed_launch(valid_marker, {**valid_start, "workerHead": "wrong"}, parent_pid=7, worker_head="h"), "binding")

    with tempfile.TemporaryDirectory(prefix="play027-phase-r2-") as temp_name:
        temp = Path(temp_name).resolve()
        repo, fixture_contract, paths, identity, attempt = published_fixture(launcher, contract, temp)
        authority = launcher.validate_direct_documents(repo, fixture_contract, identity, paths)
        assert authority["hashes"]["schedule"] == launcher.sha256(paths["schedule"])
        consumed = launcher.consume_attempt(attempt, authority, identity)
        assert consumed["state"] == "CONSUMED" and consumed["workerHead"] == identity["head"]
        rejects(lambda: launcher.consume_attempt(attempt, authority, identity), "already consumed")
        launcher.write_child_start(attempt, identity)
        rejects(lambda: launcher.write_child_start(attempt, identity), "File exists")

        wrong = copy.deepcopy(fixture_contract)
        wrong["futureStageB"]["timeoutSeconds"] = 121
        rejects(lambda: launcher.validate_direct_documents(repo, wrong, identity, paths, expected_attempt_state="CONSUMED"), "timeout")
        raw = paths["schedule"].read_bytes()
        paths["schedule"].write_bytes(raw + b" ")
        rejects(lambda: launcher.validate_direct_documents(repo, fixture_contract, identity, paths, expected_attempt_state="CONSUMED"), "published bytes")
        paths["schedule"].write_bytes(raw)
        alias = temp / "alias"
        alias.symlink_to(paths["grant"])
        alias_paths = dict(paths); alias_paths["grant"] = alias
        rejects(lambda: launcher.validate_direct_documents(repo, fixture_contract, identity, alias_paths, expected_attempt_state="CONSUMED"), "alias")

        success_root = temp / "success"; success_root.mkdir()
        result = launcher.capture_process(FakeProcess(stream), ["fake-blender"], success_root, contract, started_at="A", ended_at="B", timeout=120)
        assert result["status"] == "COMPLETE" and result["lastPhase"] == "complete"
        assert {p.name for p in success_root.iterdir()} == {"stdout.bin", "stderr.bin", "PHASE-MARKERS.jsonl", "DIAGNOSTIC-RECEIPT.json"}

        nonzero_root = temp / "nonzero"; nonzero_root.mkdir()
        failed = launcher.capture_process(FakeProcess(stream[:stream.rfind(b"\n", 0, -1) + 1], b"crash", 9), ["fake"], nonzero_root, contract, started_at="A", ended_at="B", timeout=120)
        assert failed["status"] == "FAILURE" and failed["returnCode"] == 9 and (nonzero_root / "FAILURE.json").is_file()

        signal_root = temp / "signal"; signal_root.mkdir()
        signaled = launcher.capture_process(FakeProcess(stream[:100], returncode=-11), ["fake"], signal_root, contract, started_at="A", ended_at="B", timeout=120)
        assert signaled["signal"] == 11 and signaled["status"] == "FAILURE"

        timeout_root = temp / "timeout"; timeout_root.mkdir(); killed = []
        timed = launcher.capture_process(FakeProcess(stream[:100], returncode=-9, timeout_once=True), ["fake"], timeout_root, contract, started_at="A", ended_at="B", timeout=1, kill_group=killed.append)
        assert timed["timedOut"] is True and killed == [4242] and timed["status"] == "FAILURE"

        error_root = temp / "communicate-error"; error_root.mkdir(); killed_error = []
        errored = launcher.capture_process(FakeProcess(stream, returncode=-9, error_once=True), ["fake"], error_root, contract, started_at="A", ended_at="B", timeout=1, kill_group=killed_error.append)
        assert errored["status"] == "FAILURE" and errored["communicationError"].startswith("OSError:") and killed_error == [4242]

        popen_root = temp / "popen-failure"; popen_root.mkdir()
        launch_failure = launcher.preserve_launch_failure(popen_root, contract, ["fake"], OSError("injected Popen failure"), "A")
        assert launch_failure["pid"] is None and launch_failure["status"] == "FAILURE" and (popen_root / "FAILURE.json").is_file()

        preexisting = temp / "preexisting"; preexisting.mkdir(); (preexisting / "stdout.bin").write_bytes(b"owned")
        rejects(lambda: launcher.capture_process(FakeProcess(stream), ["fake"], preexisting, contract, started_at="A", ended_at="B", timeout=1), "File exists")
        symlink_root = temp / "symlink-root"; symlink_root.symlink_to(success_root)
        rejects(lambda: launcher.capture_process(FakeProcess(stream), ["fake"], symlink_root, contract, started_at="A", ended_at="B", timeout=1), "owned output root")

    launcher_tree = ast.parse((PHASE_ROOT / "launch_phase_ladder.py").read_text())
    popen_sites = [node for node in ast.walk(launcher_tree) if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "Popen"]
    assert len(popen_sites) == 1
    child_text = (PHASE_ROOT / "phase_ladder_child.py").read_text()
    assert child_text.count("bpy.ops.render.render(write_still=True)") == 1
    assert "bpy.ops.wm.save_as_mainfile" not in child_text and "render_semantic_pass" not in child_text
    assert launcher.CHILD_START_COUNT == 0
    assert not (ROOT / contract["futureStageB"]["outputRoot"]).exists()
    print(json.dumps({"status": "PASS", "phaseCount": 9, "components": 33, "objects": 97, "solidObjects": 96, "adversaries": 23, "fakeProcessScenarios": 6, "childStartSites": 1, "childStarts": 0, "dccProcessCount": 0, "pixelWrites": 0, "outputRootCreated": 0, "executableBehavior": "UNPROVEN"}, sort_keys=True))


if __name__ == "__main__":
    main()
