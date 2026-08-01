"""Pure-data/adversarial closure tests; intentionally starts no child process."""

from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True


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
FIXTURE_KEY = b"north-v13-test-only-fixture-key-v01"


def expect_failure(mutator, label: str) -> None:
    candidate = copy.deepcopy(contract)
    mutator(candidate)
    try:
        runner.validate_contract(ROOT, candidate)
    except (ValueError, OSError, KeyError):
        return
    raise AssertionError(f"adversary passed: {label}")


def expect_fixture_failure(mutator, label: str) -> None:
    authority = runner.build_test_fixture_authority(contract, FIXTURE_KEY, ROOT)
    mutator(authority["binding"])
    authority["signature"] = runner._fixture_signature(authority["binding"], FIXTURE_KEY)
    try:
        runner.validate_fixture_authority(authority, contract, ROOT, FIXTURE_KEY)
    except (ValueError, OSError, KeyError):
        return
    raise AssertionError(f"fixture adversary passed: {label}")


def snapshot(root: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for base, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if d != ".git"]
        base_path = Path(base)
        for name in files:
            path = base_path / name
            rel = path.relative_to(root).as_posix()
            if path.is_symlink():
                result[rel] = "symlink:" + os.readlink(path)
            else:
                result[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def main() -> int:
    before = snapshot(ROOT)
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
        temp_root = Path(tmp)
        existing = temp_root / contract["output"]["runRoot"]
        existing.mkdir(parents=True, exist_ok=True)
        try:
            runner.validate_owned_output(temp_root, contract["output"]["runRoot"], contract)
        except ValueError:
            pass
        else:
            raise AssertionError("preexisting future output root accepted")
        try:
            runner.validate_owned_output(ROOT, "docs/production/claims", contract)
        except ValueError:
            pass
        else:
            raise AssertionError("path escape accepted")
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

    # A signed test-only fixture binds every route, authority, identity, root,
    # child-limit, and zero-activity field. It is never written or consumed as
    # a live schedule/grant.
    authority = runner.build_test_fixture_authority(contract, FIXTURE_KEY, ROOT)
    state = {"consumptionId": runner.EXPECTED_CONSUMPTION_ID, "consumed": False}
    consumed = runner.consume_test_fixture(authority, contract, ROOT, FIXTURE_KEY, state)
    assert consumed == {"consumed": True, "startedChild": False, "dccStarts": 0, "renderedPixels": 0, "outputCreated": False}
    try:
        runner.consume_test_fixture(authority, contract, ROOT, FIXTURE_KEY, state)
    except ValueError as exc:
        assert "replay" in str(exc)
    else:
        raise AssertionError("replayed fixture authority accepted")

    for mutator, label in (
        (lambda b: b.__setitem__("routeCanonicalSHA256", "0" * 64), "canonical route"),
        (lambda b: b.__setitem__("carrierCommit", "0" * 40), "carrier"),
        (lambda b: b.__setitem__("receiptPath", "docs/production/claims"), "receipt path"),
        (lambda b: b.__setitem__("receiptSHA256", "0" * 64), "receipt hash"),
        (lambda b: b.__setitem__("assignmentThreadId", "forged"), "thread"),
        (lambda b: b.__setitem__("grantId", "south:A"), "grant"),
        (lambda b: b.__setitem__("evidenceRoot", "docs/production/claims"), "evidence root"),
        (lambda b: b.__setitem__("allowedRoots", ["docs/production/claims"]), "allowed roots"),
        (lambda b: b.__setitem__("dccChildLimit", 2), "DCC child limit"),
        (lambda b: b.__setitem__("candidateHead", "0" * 40), "candidate HEAD"),
        (lambda b: b.__setitem__("childStarts", 1), "child activity"),
        (lambda b: b.__setitem__("dccStarts", 1), "DCC activity"),
        (lambda b: b.__setitem__("renderedPixels", 1), "pixel activity"),
    ):
        expect_fixture_failure(mutator, label)
    forged = runner.build_test_fixture_authority(contract, FIXTURE_KEY, ROOT)
    forged["signature"] = "0" * 64
    try:
        runner.validate_fixture_authority(forged, contract, ROOT, FIXTURE_KEY)
    except ValueError:
        pass
    else:
        raise AssertionError("forged fixture signature accepted")

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
    assert not (ROOT / contract["output"]["exclusiveFutureProcessRoot"]).exists()
    after = snapshot(ROOT)
    assert before == after, "prelaunch test mutated repository filesystem"
    print("PASS north-v13 zero-child prelaunch-repair adversaries=29 freshRoots=2 children=0 dcc=0 pixels=0 filesystem=unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
