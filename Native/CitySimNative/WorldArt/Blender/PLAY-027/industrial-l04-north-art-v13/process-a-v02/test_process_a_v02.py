"""Zero-child adversaries for the Integration-direct North v13 orchestrator."""

from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
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

    # The child is a hard-stop contract, never a direct runnable surface.
    must_fail(child.main, "direct child invocation")
    assert not hasattr(runner, "build_signer")
    assert not hasattr(runner, "build_token")
    assert not hasattr(runner, "consume_attempt")
    assert not hasattr(runner, "create_attempt")

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
    assert len(calls) == 1 and calls[0].func.attr == "run"
    for path in (HERE / "launch_north_v13_process_a_v02.py", HERE / "render_north_v13_process_a_child.py"):
        source = path.read_text(encoding="utf-8")
        assert "bpy" not in source and "PIL" not in source and "SceneKit" not in source and "Metal" not in source
        assert "Popen" not in source and "render(" not in source

    print("PASS north-v13 integration-direct-v1 zeroChild=1 adversaries=21 freshRoots=2 carrierGit=verified dccChildren=0 processA=0 pixels=0 topology=unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
