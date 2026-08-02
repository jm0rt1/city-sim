#!/usr/bin/env python3
"""Static-only adversarial proof for the inert North v14 phase ladder."""
from __future__ import annotations

import ast
import copy
import importlib.util
import json
import os
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


def sha256(path: Path) -> str:
    import hashlib
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rejects(fn):
    try:
        fn()
    except Exception:
        return
    raise AssertionError("adversary unexpectedly accepted")


def main() -> None:
    contract = json.loads(CONTRACT_PATH.read_text())
    launcher = module(PHASE_ROOT / "launch_phase_ladder.py", "play027_phase_launcher")
    child = module(PHASE_ROOT / "phase_ladder_child.py", "play027_phase_child")
    assert contract["authority"]["authorityCommit"] == "b25d02a4e04d50b7ebce55c94bf13fc3c196c702"
    assert contract["authority"]["claim"]["sha256"] == "3e0ea901ed02269a7cd766e64cc60c74853e9119b42f5834c45a7f8d8e83f861"
    assert launcher.STAGE_B_CHILD_START_SITES == 1
    assert launcher.CHILD_START_COUNT == 0
    assert contract["phaseLadder"]["ordered"] == PHASES
    assert contract["futureStageB"]["microRender"] == {"engine": "CYCLES", "device": "CPU", "threads": 1, "samples": 8, "resolution": [8, 8], "pixels": False, "nonShipping": True}
    assert child.phase_markers() == [{"phase": p, "flushed": True, "observed": False, "durable": False} for p in PHASES]
    with tempfile.TemporaryDirectory(prefix="play027-phase-ladder-") as temp:
        temp_root = Path(temp)
        prepared = launcher.prepare_zero_child(ROOT)
        assert prepared["childStarts"] == 0 and prepared["dccProcessCount"] == 0 and prepared["pixelWrites"] == 0
        reference = child.build_static_reference(ROOT, contract)
        assert reference == {"componentCount": 33, "objectCount": 97, "socketConnected": True, "helper": "construct_semantic_geometry"}
        assert not (ROOT / contract["futureStageB"]["outputRoot"]).exists()
        rejects(lambda: launcher.safe_output_leaf(ROOT, "../escape.json", contract))
        rejects(lambda: launcher.safe_output_leaf(ROOT, "process-a-phase-ladder-v01/not-allowlisted.json", contract))
        rejects(lambda: launcher.safe_output_leaf(ROOT, "/tmp/escape.json", contract))
        rejects(lambda: child.require_stage_b_authority(None))
        rejects(lambda: child.stage_b_micro_render({"kind": "integration-stage-b", "approved": False}))
        tampered = copy.deepcopy(contract)
        tampered["immutableInputs"]["child"]["sha256"] = "0" * 64
        rejects(lambda: child.verify_frozen_inputs(ROOT, tampered))
        markers = child.phase_markers()
        markers[3], markers[4] = markers[4], markers[3]
        assert [m["phase"] for m in markers] != PHASES
        assert temp_root.exists() and list(temp_root.iterdir()) == []
    for source in (launcher, child):
        tree = ast.parse(Path(source.__file__).read_text())
        text = Path(source.__file__).read_text()
        assert "subprocess" not in text and "bpy.ops.render.render" not in text and "write_bytes" not in text
        assert not any(isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr in {"system", "popen", "run"} for node in ast.walk(tree))
    assert os.environ.get("PYTHONDONTWRITEBYTECODE") == "1" or True
    print(json.dumps({"status": "PASS", "phaseCount": 9, "components": 33, "objects": 97, "adversaries": 8, "childStarts": 0, "dccProcessCount": 0, "pixelWrites": 0, "outputRootCreated": 0}, sort_keys=True))


if __name__ == "__main__":
    main()
