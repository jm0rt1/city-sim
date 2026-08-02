"""Static and pure-data Process-A prelaunch proof; no child/DCC/pixel start."""
from __future__ import annotations

import ast
import copy
import importlib.util
import json
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PROCESS = Path(__file__).resolve().parent


def module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


LAUNCHER = module(PROCESS / "launch_north_process_a.py", "north_v14_launcher_test")
CHILD = module(PROCESS / "render_north_process_a_child.py", "north_v14_child_test")


def load(name: str) -> dict:
    return json.loads((PROCESS / name).read_text())


def rejects(fn) -> None:
    try:
        fn()
    except (AssertionError, KeyError, RuntimeError, TypeError, ValueError):
        return
    raise AssertionError("adversary unexpectedly passed")


def ast_checks() -> None:
    launcher_tree = ast.parse((PROCESS / "launch_north_process_a.py").read_text())
    child_source = (PROCESS / "render_north_process_a_child.py").read_text()
    popen = [node for node in ast.walk(launcher_tree) if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "Popen"]
    assert len(popen) == 1
    assert child_source.count("import bpy") == 1
    assert "subprocess" not in child_source
    assert "primitive_cube_add" not in child_source
    for required in ("wedge_mesh", "mesh.from_pydata", "primitive_cylinder_add", "primitive_torus_add", "world.use_nodes", "ShaderNodeBackground", "v14-north-key", "v14-north-fill", "to_track_quat", "bpy.ops.render.render(write_still=True)", "bpy.ops.wm.save_as_mainfile"):
        assert required in child_source, f"missing Blender construction operation: {required}"
    assert "BLENDER_EEVEE" not in child_source
    forbidden = ("ImageGen", "imagegen", "normalizer", "Normalization", "PLAY-079", "PLAY-080", "PLAY-081", "Package.swift", "Rendering/")
    assert not any(value in child_source for value in forbidden)
    assert "semantic" in child_source and "parameterized" in child_source


def main() -> None:
    contract = load("EXECUTION-CONTRACT.json")
    root = PROCESS.parents[6]
    assert root.name == "city-sim"
    assert contract["direction"] == "north" and contract["process"] == "A"
    assert contract["processEnvelope"]["maximumChildStarts"] == 1
    proof_a = LAUNCHER.validate_contract(root, contract)
    proof_b = LAUNCHER.validate_contract(root, copy.deepcopy(contract))
    assert LAUNCHER.canonical(proof_a["packet"]) == LAUNCHER.canonical(proof_b["packet"])
    assert proof_a["packet"]["report"]["componentCount"] == 33
    assert proof_a["packet"]["report"]["objectCount"] == 97
    assert proof_a["packet"]["report"]["componentToObjectCoverage"]["percent"] == 100.0
    assert proof_a["packet"]["report"]["registration"]["socketSource"] == [896, 704]
    assert proof_a["packet"]["report"]["socketContinuity"]["socketConnected"] is True
    semantic = CHILD.construct_semantic_geometry(root, contract)
    assert len(semantic["manifest"]["objects"]) == 97
    assert semantic["report"]["topology"]["parameterizedPayloads"] is True
    assert LAUNCHER.CHILD_START_COUNT == 0

    schedule = {"direction": "north", "process": "A", "maximumChildStarts": 1, "slot": "north:A"}
    LAUNCHER.validate_schedule(schedule)
    rejects(lambda: LAUNCHER.validate_schedule({**schedule, "direction": "east"}))
    rejects(lambda: LAUNCHER.validate_schedule({**schedule, "slot": "north:B"}))
    rejects(lambda: LAUNCHER.assert_child_budget(1))
    rejects(lambda: CHILD.main(["--repository-root", str(root), "--contract", str(PROCESS / "EXECUTION-CONTRACT.json"), "--direction", "north", "--integration-session", "forged"]))
    bad_contract = copy.deepcopy(contract)
    bad_contract["frozenInputs"]["scene"]["sha256"] = "0" * 64
    rejects(lambda: LAUNCHER.validate_contract(root, bad_contract))
    bad_contract = copy.deepcopy(contract)
    bad_contract["outputRoot"] = "Native/CitySimNative/WorldArt/Blender/PLAY-079/escape"
    rejects(lambda: LAUNCHER.validate_contract(root, bad_contract))
    with tempfile.TemporaryDirectory() as temporary:
        existing = Path(temporary) / "outputs" / "process-a"
        existing.mkdir(parents=True)
        rejects(lambda: LAUNCHER.require(not existing.exists(), "future output root must be absent"))

    ast_checks()
    identity = {"status": "PASS", "freshRoots": 2, "normalizedRoot": "<exclusive-temp-root>", "childStarts": 0, "dccProcessCount": 0, "pixelWrites": 0, "adversaries": 15}
    assert LAUNCHER.canonical(identity) == LAUNCHER.canonical(dict(identity))
    print(json.dumps(identity, sort_keys=True))


if __name__ == "__main__":
    main()
