#!/usr/bin/env python3
"""North v14 nine-phase Blender diagnostic child; callable only with consumed authority."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import Any, TextIO

SOURCE_ROOT = Path("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14")
PHASE_ROOT = SOURCE_ROOT / "process-a-phase-ladder-v01"
CONTRACT_PATH = PHASE_ROOT / "DIAGNOSTIC-CONTRACT.json"
GOVERNED_CHILD = SOURCE_ROOT / "process-a-execution-v01/render_north_process_a_child.py"
PHASES = (
    "python_entered", "frozen_inputs_verified", "source_module_loaded", "bpy_imported",
    "scene_configured", "all_96_meshes_created", "pre_micro_render", "post_micro_render", "complete",
)


class ChildAuthorityError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ChildAuthorityError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_object(path: Path) -> dict[str, Any]:
    require(path.is_file() and not path.is_symlink(), f"regular JSON required: {path}")
    value = json.loads(path.read_bytes())
    require(type(value) is dict, f"JSON object required: {path}")
    return value


def emit_phase(name: str, sequence: int, stream: TextIO = sys.stdout) -> None:
    require(sequence < len(PHASES) and PHASES[sequence] == name, "phase sequence drift")
    stream.write(json.dumps({"play027Phase": name, "sequence": sequence}, sort_keys=True, separators=(",", ":")) + "\n")
    stream.flush()


def load_governed_child(root: Path) -> Any:
    path = root / GOVERNED_CHILD
    spec = importlib.util.spec_from_file_location("play027_v14_governed_child", path)
    require(spec is not None and spec.loader is not None, "governed child import unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_consumed_launch(marker: dict[str, Any], start: dict[str, Any], *, parent_pid: int, worker_head: str) -> None:
    require(marker.get("state") == "CONSUMED", "attempt must be consumed by launcher")
    require(type(marker.get("launcherPID")) is int and marker["launcherPID"] == parent_pid, "launcher parent mismatch")
    require(start == {"launcherPID": parent_pid, "state": "CHILD_STARTED", "workerHead": worker_head}, "child-start binding drift")


def validate_child_authority(args: argparse.Namespace) -> tuple[Path, dict[str, Any], dict[str, Any]]:
    root = Path(args.repository_root).resolve(strict=True)
    contract_path = Path(args.contract).resolve(strict=True)
    require(contract_path == root / CONTRACT_PATH, "diagnostic contract path drift")
    contract = load_object(contract_path)
    output = Path(args.output_root).resolve(strict=True)
    require(output == root / contract["futureStageB"]["outputRoot"], "output root drift")
    require(output.is_dir() and not output.is_symlink() and not any(output.iterdir()), "fresh empty output root required")
    documents = {"schedule": Path(args.schedule), "grant": Path(args.grant), "session": Path(args.session), "staticApproval": Path(args.static_approval)}
    # Reuse the production launcher's repository-backed closure; no env/flag-only path exists.
    launcher_path = root / PHASE_ROOT / "launch_phase_ladder.py"
    spec = importlib.util.spec_from_file_location("play027_phase_launcher_child_validation", launcher_path)
    require(spec is not None and spec.loader is not None, "launcher validation unavailable")
    launcher = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(launcher)
    static_contract, identity = launcher.validate_static(root, require_output_absent=False)
    authority = launcher.validate_direct_documents(root, static_contract, identity, documents, expected_attempt_state=contract["externalAuthority"]["consumedState"])
    require(authority["outputRoot"] == output, "validated output root mismatch")
    marker = load_object(authority["attemptPath"])
    child_start = authority["attemptPath"].with_name(authority["attemptPath"].name + ".child-start")
    require(child_start.is_file() and not child_start.is_symlink(), "child-start marker missing")
    start = load_object(child_start)
    validate_consumed_launch(marker, start, parent_pid=os.getppid(), worker_head=identity["head"])
    return root, contract, authority


def construct_scene_and_micro_render(root: Path, contract: dict[str, Any], output: Path, bpy: Any) -> None:
    governed = load_governed_child(root)
    execution_contract = load_object(root / contract["immutableInputs"]["executionContract"]["path"])
    scene_data = load_object(root / contract["immutableInputs"]["scene"]["path"])
    materials = load_object(root / contract["immutableInputs"]["materials"]["path"])
    lighting = load_object(root / contract["immutableInputs"]["lighting"]["path"])
    packet = governed.construct_semantic_geometry(root, execution_contract)
    specs = governed.build_mesh_specs(packet["manifest"])
    require(packet["report"]["componentCount"] == 33 and packet["report"]["objectCount"] == 97, "semantic inventory drift")
    configured = governed.configure_scene(bpy, execution_contract, scene_data, materials, lighting)
    emit_phase("scene_configured", 4)
    item_by_id = {item["id"]: item for item in packet["manifest"]["objects"]}
    objects = []
    for mesh_spec in specs["solidSpecs"]:
        item = item_by_id[mesh_spec["id"]]
        objects.append(governed.mesh_object(bpy, mesh_spec, configured["materials"][item["materialRole"]]))
    require(len(objects) == 96, "Blender object count drift")
    emit_phase("all_96_meshes_created", 5)
    scene = configured["scene"]
    profile = contract["futureStageB"]["microRender"]
    require(profile == {"engine": "CYCLES", "device": "CPU", "threads": 1, "samples": 8, "resolution": [8, 8], "nonShipping": True}, "micro-render profile drift")
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 8
    scene.cycles.use_adaptive_sampling = False
    scene.cycles.use_denoising = False
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 1
    scene.render.resolution_x = 8
    scene.render.resolution_y = 8
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(output / "micro.png")
    emit_phase("pre_micro_render", 6)
    bpy.ops.render.render(write_still=True)
    require((output / "micro.png").is_file(), "micro-render output missing")
    emit_phase("post_micro_render", 7)


def parse_args(values: list[str] | None = None) -> argparse.Namespace:
    if values is None:
        require("--" in sys.argv, "Blender separator required")
        values = sys.argv[sys.argv.index("--") + 1 :]
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--schedule", required=True)
    parser.add_argument("--grant", required=True)
    parser.add_argument("--session", required=True)
    parser.add_argument("--static-approval", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(values)


def main(values: list[str] | None = None) -> int:
    emit_phase("python_entered", 0)
    args = parse_args(values)
    root, contract, authority = validate_child_authority(args)
    for binding in contract["immutableInputs"].values():
        path = root / binding["path"]
        require(path.is_file() and not path.is_symlink() and sha256(path) == binding["sha256"], f"frozen input drift: {binding['path']}")
    emit_phase("frozen_inputs_verified", 1)
    load_governed_child(root)
    emit_phase("source_module_loaded", 2)
    import bpy  # type: ignore  # imported only after repository-backed authority closure
    emit_phase("bpy_imported", 3)
    construct_scene_and_micro_render(root, contract, authority["outputRoot"], bpy)
    emit_phase("complete", 8)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
