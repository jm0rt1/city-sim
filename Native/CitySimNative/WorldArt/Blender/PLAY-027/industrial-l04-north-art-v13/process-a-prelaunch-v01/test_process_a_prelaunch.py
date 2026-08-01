"""Pure-data/adversarial closure tests; intentionally starts no child process."""

from __future__ import annotations

import ast
import copy
import importlib.util
import json
from pathlib import Path
import tempfile


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load("north_prelaunch_runner", HERE / "launch_north_v13_prelaunch.py")
child = load("north_prelaunch_child", HERE / "render_north_v13_process_a_child.py")
contract = runner.load_json(HERE / "EXECUTION-CONTRACT.json")


def expect_failure(mutator, label: str) -> None:
    candidate = copy.deepcopy(contract)
    mutator(candidate)
    try:
        runner.validate_contract(ROOT, candidate)
    except (ValueError, OSError, KeyError):
        return
    raise AssertionError(f"adversary passed: {label}")


def main() -> int:
    result = runner.validate_contract(ROOT, contract)
    assert result["inputCount"] == 6
    assert result["futureProcessRootAbsent"] is True
    assert result["liveAuthorityAbsent"] is True

    expect_failure(lambda c: c["route"].__setitem__("routeId", "forged"), "route")
    expect_failure(lambda c: c["route"].__setitem__("baseCommit", "0" * 40), "base")
    expect_failure(lambda c: c["claim"].__setitem__("sha256", "0" * 64), "claim")
    expect_failure(lambda c: c["identity"].__setitem__("viewDirection", "west"), "direction")
    expect_failure(lambda c: c["identity"].__setitem__("processID", "B"), "process")
    expect_failure(lambda c: c["identity"].__setitem__("slotID", "south:A"), "slot")
    expect_failure(lambda c: c["identity"].__setitem__("sceneGeometryID", "wrong"), "geometry")
    expect_failure(lambda c: c["inputs"][0].__setitem__("sha256", "0" * 64), "input")
    expect_failure(lambda c: c["authorityState"].__setitem__("scheduleCreated", True), "schedule")
    expect_failure(lambda c: c["authorityState"].__setitem__("leaseCreated", True), "lease")
    expect_failure(lambda c: c["authorityState"].__setitem__("secretCreated", True), "secret")
    expect_failure(lambda c: c["authorityState"].__setitem__("grantCreated", True), "grant")
    expect_failure(lambda c: c["output"].__setitem__("runRoot", "docs/production/evidence/PLAY-027/other"), "wrong root")
    expect_failure(lambda c: c.__setitem__("route", dict(c["route"], expectedStartingHEAD="0" * 40)), "head")

    with tempfile.TemporaryDirectory(prefix="north-v13-prelaunch-adversary-") as tmp:
        future = ROOT / contract["output"]["runRoot"]
        future.mkdir(parents=True, exist_ok=True)
        try:
            try:
                runner.validate_contract(ROOT, contract)
            except ValueError:
                pass
            else:
                raise AssertionError("preexisting future output root accepted")
        finally:
            future.rmdir()
        # Distinct fresh evidence roots receive the same canonical bytes.
        outputs = []
        for suffix in ("a", "b"):
            out = Path(tmp) / suffix
            out.mkdir()
            validation, closure = runner._stable_receipt(contract, ROOT)
            for name, value in (("PRELAUNCH-VALIDATION.json", validation), ("ZERO-CHILD-CLOSURE.json", closure)):
                p = out / name
                p.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
                outputs.append(p.read_bytes())
        assert outputs[0] == outputs[2] and outputs[1] == outputs[3]

    try:
        child.main([])
    except RuntimeError as exc:
        assert "forbidden" in str(exc)
    else:
        raise AssertionError("direct child invocation accepted")

    for path in (HERE / "launch_north_v13_prelaunch.py", HERE / "render_north_v13_process_a_child.py"):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        imports = {alias.name.split(".")[0] for node in ast.walk(tree) if isinstance(node, ast.Import) for alias in node.names}
        imports |= {node.module.split(".")[0] for node in ast.walk(tree) if isinstance(node, ast.ImportFrom) and node.module}
        assert not imports.intersection({"bpy", "subprocess", "PIL", "Metal", "SceneKit"})
        source = path.read_text(encoding="utf-8")
        assert "render(" not in source and "Popen" not in source

    validation, closure = runner._stable_receipt(contract, ROOT)
    assert validation["counts"]["processA"] == 0
    assert validation["counts"]["blender"] == 0
    assert validation["counts"]["pixels"] == 0
    assert closure["executionAccounting"]["readyNow"] == []
    assert closure["executionAccounting"]["running"] == []
    assert closure["executionAccounting"]["capacity"]["dccSlots"] == 0
    print("PASS north-v13 zero-child prelaunch adversaries=14 freshRoots=2 children=0 dcc=0 pixels=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
