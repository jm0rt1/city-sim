"""Adversarial zero-DCC tests for the North v13 frontier repair R2."""

from __future__ import annotations

import ast
from concurrent.futures import ThreadPoolExecutor
import copy
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
FIXTURE_KEY = b"north-v13-frontier-repair-r2-test-fixture-v01"


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load("north_v13_frontier_runner", HERE / "launch_north_v13_prelaunch.py")
child = load("north_v13_frontier_child", HERE / "render_north_v13_process_a_child.py")
contract = runner.load_json(HERE / "EXECUTION-CONTRACT.json")


def expect_contract_failure(mutator, label: str) -> None:
    candidate = copy.deepcopy(contract)
    mutator(candidate)
    try:
        runner.validate_contract(ROOT, candidate)
    except (ValueError, OSError, KeyError, json.JSONDecodeError):
        return
    raise AssertionError(f"contract adversary passed: {label}")


def fixture() -> dict:
    return runner.build_test_fixture_authority(contract, FIXTURE_KEY, ROOT)


def expect_fixture_failure(mutator, label: str, *, resign: bool = True) -> None:
    authority = fixture()
    mutator(authority)
    if resign and isinstance(authority.get("binding"), dict):
        authority["signature"] = runner._fixture_signature(authority["binding"], FIXTURE_KEY)
    try:
        runner.validate_fixture_authority(authority, contract, ROOT, FIXTURE_KEY)
    except (ValueError, OSError, KeyError):
        return
    raise AssertionError(f"fixture adversary passed: {label}")


def assert_same_fresh_roots(first: Path, second: Path) -> dict:
    first_topology = runner.snapshot_topology(first)
    second_topology = runner.snapshot_topology(second)
    assert first_topology == second_topology
    assert first_topology["directories"] == []
    assert sorted(first_topology["files"]) == ["PRELAUNCH-VALIDATION.json", "ZERO-CHILD-CLOSURE.json"]
    assert first_topology["symlinks"] == {}
    return first_topology


def fixture_state_path(authority: dict) -> Path:
    return Path("/private/tmp") / runner._fixture_state_name(authority["binding"])


def remove_fixture_state(authority: dict) -> None:
    state = fixture_state_path(authority)
    marker = state / "CONSUMED.json"
    if marker.exists():
        marker.unlink()
    if state.exists():
        state.rmdir()


def main() -> int:
    repository_before = runner.snapshot_topology(ROOT)
    result = runner.validate_contract(ROOT, contract)
    assert result["inputCount"] == 6
    assert result["executionBaseHEAD"] == runner.EXECUTION_BASE_HEAD
    assert result["executionBaseIsAncestor"] is True
    assert result["descendantDeltaRestrictedToTaskRoots"] is True
    assert result["futureProcessRootAbsent"] is True
    assert result["liveAuthorityAbsent"] is True
    assert result["carrier"]["receiptSHA256"] == runner.EXPECTED_RECEIPT_SHA256
    assert result["carrier"]["canonicalRouteSHA256"] == runner.ROUTE_CANONICAL_SHA256

    contract_adversaries = (
        (lambda c: c.__setitem__("unknown", 1), "unknown top-level field"),
        (lambda c: c.pop("registration"), "missing top-level field"),
        (lambda c: c["route"].__setitem__("routeId", "forged"), "route"),
        (lambda c: c["route"].__setitem__("canonicalSHA256", "0" * 64), "canonical route"),
        (lambda c: c["route"].__setitem__("carrierCommit", "0" * 40), "carrier"),
        (lambda c: c["route"].__setitem__("receiptSHA256", "0" * 64), "receipt hash"),
        (lambda c: c["route"].__setitem__("executionBaseHEAD", "0" * 40), "execution base"),
        (lambda c: c["route"].__setitem__("baseCommit", "0" * 40), "base"),
        (lambda c: c["claim"].__setitem__("sha256", "0" * 64), "claim"),
        (lambda c: c["assignment"].__setitem__("threadId", "forged"), "thread"),
        (lambda c: c["identity"].__setitem__("logicalBuildingID", "industrial_l03"), "logical building"),
        (lambda c: c["identity"].__setitem__("variantID", "variant-1"), "variant"),
        (lambda c: c["identity"].__setitem__("viewDirection", "west"), "direction"),
        (lambda c: c["identity"].__setitem__("processID", "B"), "process"),
        (lambda c: c["identity"].__setitem__("slotID", "south:A"), "slot"),
        (lambda c: c["identity"].__setitem__("sceneGeometryID", "wrong"), "geometry"),
        (lambda c: c["identity"].__setitem__("sourceAuthority", True), "source authority boolean"),
        (lambda c: c["identity"].__setitem__("productionSelected", True), "production selection boolean"),
        (lambda c: c["inputs"][0].__setitem__("sha256", "0" * 64), "input"),
        (lambda c: c.__setitem__("inputs", []), "empty input set"),
        (lambda c: c["inputs"].pop(), "missing input"),
        (lambda c: c["inputs"].append({"path": "extra", "sha256": "0" * 64}), "extra input"),
        (lambda c: c.__setitem__("inputs", list(reversed(c["inputs"]))), "reordered inputs"),
        (lambda c: c["authorityState"].__setitem__("scheduleCreated", True), "schedule"),
        (lambda c: c["authorityState"].__setitem__("leaseCreated", True), "lease"),
        (lambda c: c["authorityState"].__setitem__("secretCreated", True), "secret"),
        (lambda c: c["authorityState"].__setitem__("grantCreated", True), "grant"),
        (lambda c: c["output"].__setitem__("runRoot", "docs/production/evidence/PLAY-027/escape"), "root"),
    )
    for mutator, label in contract_adversaries:
        expect_contract_failure(mutator, label)

    binding_adversaries = (
        (lambda a: a["binding"].__setitem__("unknownActivity", 0), "unknown binding field"),
        (lambda a: a["binding"].pop("grantId"), "missing binding field"),
        (lambda a: a["binding"].__setitem__("carrierCommit", "0" * 40), "signed carrier"),
        (lambda a: a["binding"].__setitem__("executionBaseHEAD", "0" * 40), "signed execution base"),
        (lambda a: a["binding"].__setitem__("assignmentThreadId", "forged"), "signed thread"),
        (lambda a: a["binding"].__setitem__("logicalBuildingID", "industrial_l03"), "signed logical building"),
        (lambda a: a["binding"].__setitem__("variantID", "variant-1"), "signed variant"),
        (lambda a: a["binding"].__setitem__("sourceAuthority", True), "signed source authority"),
        (lambda a: a["binding"].__setitem__("productionSelected", True), "signed production selection"),
        (lambda a: a["binding"].__setitem__("inputs", []), "signed empty inputs"),
        (lambda a: a["binding"]["inputs"].pop(), "signed missing input"),
        (lambda a: a["binding"]["inputs"].append({"path": "extra", "sha256": "0" * 64}), "signed extra input"),
        (lambda a: a["binding"].__setitem__("inputs", list(reversed(a["binding"]["inputs"]))), "signed reordered inputs"),
        (lambda a: a["binding"].__setitem__("grantId", "south:A"), "signed grant"),
        (lambda a: a["binding"].__setitem__("evidenceRoot", "docs/production/claims"), "signed evidence root"),
        (lambda a: a["binding"].__setitem__("allowedRoots", ["docs/production/claims"]), "signed allowed roots"),
        (lambda a: a["binding"].__setitem__("dccChildLimit", 2), "signed child limit"),
        (lambda a: a["binding"]["activity"].__setitem__("mystery", 0), "unknown activity"),
        (lambda a: a["binding"]["activity"].pop("pixelWrites"), "missing activity"),
        (lambda a: a["binding"]["activity"].__setitem__("childStarts", 1), "child activity"),
        (lambda a: a["binding"]["activity"].__setitem__("processAStarts", 1), "Process-A activity"),
        (lambda a: a["binding"]["activity"].__setitem__("blenderStarts", 1), "Blender activity"),
        (lambda a: a["binding"]["activity"].__setitem__("dccStarts", 1), "DCC activity"),
        (lambda a: a["binding"]["activity"].__setitem__("renderStarts", 1), "render activity"),
        (lambda a: a["binding"]["activity"].__setitem__("normalizerStarts", 1), "normalizer activity"),
        (lambda a: a["binding"]["activity"].__setitem__("pixelWrites", 1), "pixel activity"),
    )
    for mutator, label in binding_adversaries:
        expect_fixture_failure(mutator, label)
    expect_fixture_failure(lambda a: a.__setitem__("unknown", True), "unknown authority field", resign=False)
    expect_fixture_failure(lambda a: a.__setitem__("signature", "0" * 64), "forged signature", resign=False)

    # The adapter derives one immutable store from the authenticated binding;
    # no caller-selected parent or direct consume surface is accepted. Two
    # simultaneous consumers of the same signed authority race for one marker.
    authority = fixture()
    state = fixture_state_path(authority)
    assert not state.exists(), f"stale fixture state: {state}"
    binding = authority["binding"]
    direct = runner._AuthenticatedTestOneShotAdapter(runner._ADAPTER_FACTORY_TOKEN, binding)
    try:
        direct.consume(binding)
    except ValueError as exc:
        assert "direct adapter" in str(exc)
    else:
        raise AssertionError("direct adapter.consume bypass accepted")
    try:
        runner._AuthenticatedTestOneShotAdapter(object(), binding)
    except ValueError as exc:
        assert "construction" in str(exc)
    else:
        raise AssertionError("caller constructed an adapter")
    for caller_store in (Path("/private/tmp/caller-store-a"), Path("/private/tmp/caller-store-b")):
        try:
            runner.consume_test_fixture(authority, contract, ROOT, FIXTURE_KEY, store_parent=caller_store)
        except TypeError as exc:
            assert "store_parent" in str(exc)
        else:
            raise AssertionError("caller-selected fixture store accepted")

    try:
        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = [
                executor.submit(runner.consume_test_fixture, authority, contract, ROOT, FIXTURE_KEY)
                for _ in range(2)
            ]
            outcomes = []
            for future in futures:
                try:
                    outcomes.append(("success", future.result()))
                except ValueError as exc:
                    outcomes.append(("failure", str(exc)))
        successes = [value for kind, value in outcomes if kind == "success"]
        failures = [value for kind, value in outcomes if kind == "failure"]
        assert successes == [{
            "consumed": True, "startedDCCChild": False, "dccStarts": 0,
            "renderStarts": 0, "pixelWrites": 0, "outputCreated": False,
        }]
        assert len(failures) == 1 and "already exists or consumed" in failures[0]
        try:
            runner.consume_test_fixture(authority, contract, ROOT, FIXTURE_KEY)
        except ValueError as exc:
            assert "already exists or consumed" in str(exc)
        else:
            raise AssertionError("same signed consumption replay accepted")
    finally:
        remove_fixture_state(authority)
    assert not state.exists()

    with tempfile.TemporaryDirectory(prefix="north-v13-writer-") as tmp:
        parent = Path(tmp)
        first = parent / "fresh-a"
        second = parent / "fresh-b"
        first_hashes = runner.write_canonical_evidence(ROOT, first)
        second_hashes = runner.write_canonical_evidence(ROOT, second)
        assert first_hashes == second_hashes
        topology = assert_same_fresh_roots(first, second)
        try:
            runner.write_canonical_evidence(ROOT, first)
        except ValueError as exc:
            assert "absent" in str(exc)
        else:
            raise AssertionError("writer overwrote existing root")
        assert len(topology["files"]) == 2

    evidence_root = ROOT / runner.EXPECTED_EVIDENCE_ROOT
    topology_receipt = runner.load_json(evidence_root / "FRESH-ROOT-TOPOLOGY.json")
    expected_inventory = runner.bytes_sha256(runner.canonical_bytes(topology))
    assert topology_receipt["inventorySHA256"] == expected_inventory
    assert topology_receipt["replayCount"] == 2
    assert topology_receipt["byteIdentical"] is True
    assert topology_receipt["fileAndDirectoryTopologyIdentical"] is True
    for replay in topology_receipt["replays"]:
        assert replay["directories"] == topology["directories"]
        assert replay["files"] == topology["files"]
        assert replay["symlinks"] == topology["symlinks"]

    try:
        child.main([])
    except RuntimeError as exc:
        assert "forbidden" in str(exc)
    else:
        raise AssertionError("direct child invocation accepted")

    runner_tree = ast.parse((HERE / "launch_north_v13_prelaunch.py").read_text(encoding="utf-8"))
    subprocess_calls = [
        node for node in ast.walk(runner_tree)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
        and isinstance(node.func.value, ast.Name) and node.func.value.id == "subprocess"
    ]
    assert len(subprocess_calls) == 1 and subprocess_calls[0].func.attr == "run"
    for path in (HERE / "launch_north_v13_prelaunch.py", HERE / "render_north_v13_process_a_child.py"):
        source = path.read_text(encoding="utf-8")
        tree = ast.parse(source)
        imports = {alias.name.split(".")[0] for node in ast.walk(tree) if isinstance(node, ast.Import) for alias in node.names}
        imports |= {node.module.split(".")[0] for node in ast.walk(tree) if isinstance(node, ast.ImportFrom) and node.module}
        assert not imports.intersection({"bpy", "PIL", "Metal", "SceneKit"})
        assert "render(" not in source and "Popen" not in source

    validation, closure = runner._canonical_documents(contract, ROOT)
    assert validation["counts"]["processA"] == 0
    assert validation["counts"]["blender"] == 0
    assert validation["counts"]["pixels"] == 0
    assert validation["canonicalWallClockFieldCount"] == 0
    assert closure["launchReady"] is False
    assert not (ROOT / contract["output"]["exclusiveFutureProcessRoot"]).exists()
    repository_after = runner.snapshot_topology(ROOT)
    assert repository_before == repository_after, "test changed repository file/directory/symlink topology"

    adversary_count = len(contract_adversaries) + len(binding_adversaries) + 14
    print(
        "PASS north-v13 frontier-repair-r2 "
        f"adversaries={adversary_count} freshRoots=2 carrierGit=verified "
        "files=2 directories=0 dccChildren=0 processA=0 pixels=0 topology=unchanged"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
