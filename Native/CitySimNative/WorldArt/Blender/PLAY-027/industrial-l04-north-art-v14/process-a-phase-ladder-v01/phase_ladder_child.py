#!/usr/bin/env python3
"""Inert Stage-A wrapper around immutable North v14 semantic helpers."""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
from typing import Any

SOURCE_ROOT = Path("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14")
CHILD_PATH = SOURCE_ROOT / "process-a-execution-v01/render_north_process_a_child.py"
PHASES = (
    "python_entered", "frozen_inputs_verified", "source_module_loaded", "bpy_imported",
    "scene_configured", "all_96_meshes_created", "pre_micro_render", "post_micro_render", "complete",
)


class StageBNotAuthorized(RuntimeError):
    pass


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text())
    if type(value) is not dict:
        raise RuntimeError(f"JSON object required: {path}")
    return value


def load_child(root: Path) -> Any:
    path = root / CHILD_PATH
    spec = importlib.util.spec_from_file_location("play027_v14_frozen_child", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("immutable child unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verify_frozen_inputs(root: Path, contract: dict[str, Any]) -> None:
    for binding in contract["immutableInputs"].values():
        path = root / binding["path"]
        if not path.is_file() or path.is_symlink() or sha256(path) != binding["sha256"]:
            raise RuntimeError(f"immutable input drift: {binding['path']}")


def build_static_reference(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    verify_frozen_inputs(root, contract)
    child = load_child(root)
    execution_contract = load_json(root / contract["immutableInputs"]["executionContract"]["path"])
    packet = child.construct_semantic_geometry(root, execution_contract)
    if packet["report"]["componentCount"] != 33 or packet["report"]["objectCount"] != 97:
        raise RuntimeError("frozen semantic inventory drift")
    if not packet["report"]["portal"]["socketConnected"]:
        raise RuntimeError("frozen North socket disconnected")
    return {"componentCount": packet["report"]["componentCount"], "objectCount": packet["report"]["objectCount"], "socketConnected": True, "helper": "construct_semantic_geometry"}


def phase_markers() -> list[dict[str, Any]]:
    return [{"phase": phase, "flushed": True, "observed": False, "durable": False} for phase in PHASES]


def require_stage_b_authority(authority: dict[str, Any] | None) -> None:
    if authority is None or authority.get("kind") != "integration-stage-b" or authority.get("approved") is not True:
        raise StageBNotAuthorized("Stage-B authority is required")


def stage_b_micro_render(authority: dict[str, Any] | None = None) -> None:
    require_stage_b_authority(authority)
    raise StageBNotAuthorized("Stage-B execution is intentionally unreachable in Stage A")


def main() -> int:
    raise StageBNotAuthorized("The child wrapper is inert until a separate Stage-B authority")


if __name__ == "__main__":
    raise SystemExit(main())
