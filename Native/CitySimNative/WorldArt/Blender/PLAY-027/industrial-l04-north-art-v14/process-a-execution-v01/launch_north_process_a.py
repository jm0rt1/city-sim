#!/usr/bin/env python3
"""North v14 Process-A launcher; prelaunch tests never call launch()."""
from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import json
import os
import subprocess
from pathlib import Path
from typing import Any

SOURCE_ROOT = Path("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14")
PROCESS_ROOT = SOURCE_ROOT / "process-a-execution-v01"
CONTRACT_PATH = PROCESS_ROOT / "EXECUTION-CONTRACT.json"
CHILD_PATH = PROCESS_ROOT / "render_north_process_a_child.py"
CHILD_START_COUNT = 0


class LaunchError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise LaunchError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text())
    require(type(value) is dict, f"object required: {path}")
    return value


def resolve_regular(root: Path, relative: str, label: str) -> Path:
    require(relative and not relative.startswith("/"), f"{label} must be relative")
    lexical = root / relative
    current = root
    for part in Path(relative).parts:
        current /= part
        require(not current.is_symlink(), f"{label} symlink")
    resolved = lexical.resolve(strict=True)
    require(resolved.is_relative_to(root.resolve()), f"{label} escapes repository")
    require(resolved.is_file() and not resolved.is_symlink(), f"{label} must be regular")
    return resolved


def load_lowerer(root: Path) -> Any:
    path = root / SOURCE_ROOT / "lower_v14_scene.py"
    spec = importlib.util.spec_from_file_location("play027_v14_lowerer", path)
    require(spec is not None and spec.loader is not None, "lowerer import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_contract(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    require(contract["task"] == "PLAY-027" and contract["direction"] == "north" and contract["process"] == "A", "contract identity drift")
    require(contract["outputRoot"].startswith(str(PROCESS_ROOT) + "/"), "output root leaves exclusive Process-A root")
    require(contract["evidenceRoot"].startswith("docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v14/process-a-execution-v01"), "evidence root leaves exclusive North root")
    require(contract["registration"]["socketCitySim"] == [0, 0, -28], "socket CitySim drift")
    require(contract["registration"]["socketBlender"] == [-28, 0, 0], "socket Blender drift")
    require(contract["registration"]["socketSource"] == [896, 704], "socket source drift")
    require(contract["cycles"] == {"device": "CPU", "threads": 1, "seed": 17, "samples": 64, "adaptiveSampling": False, "denoising": False, "motionBlur": False, "transparentFilm": True, "resolution": [1536, 1024], "pixelAspect": [1, 1], "colorManagement": {"displayDevice": "sRGB", "viewTransform": "Standard", "look": "Medium High Contrast", "exposure": 0.0, "gamma": 1.0}}, "Cycles contract drift")
    frozen = {}
    for name, binding in contract["frozenInputs"].items():
        path = resolve_regular(root, binding["path"], name)
        require(sha256(path) == binding["sha256"], f"{name} hash drift")
        frozen[name] = path
    lowerer = load_lowerer(root)
    packet = lowerer.run()
    report = packet["report"]
    require(report["componentCount"] == 33 and report["objectCount"] == 97, "frozen v14 lowering drift")
    require(report["componentToObjectCoverage"]["percent"] == 100.0 and report["portal"]["socketConnected"], "lowering proof incomplete")
    output = root / contract["outputRoot"]
    require(not output.exists() and not output.is_symlink(), "future output root must be absent")
    return {"frozen": frozen, "packet": packet, "outputRoot": output}


def validate_schedule(schedule: dict[str, Any]) -> None:
    require(schedule.get("direction") == "north" and schedule.get("process") == "A", "schedule direction/process drift")
    require(schedule.get("maximumChildStarts") == 1 and schedule.get("slot") == "north:A", "schedule slot drift")


def assert_child_budget(started: int) -> None:
    require(started == 0, "second child forbidden")


def build_command(root: Path, contract: dict[str, Any]) -> list[str]:
    return [contract["blender"]["executable"], "--factory-startup", "--background", "--python-exit-code", "1", "--python", str(root / CHILD_PATH), "--", "--repository-root", str(root), "--contract", str(root / CONTRACT_PATH), "--direction", "north"]


def launch(root: Path, schedule: dict[str, Any], grant: dict[str, Any]) -> dict[str, Any]:
    """Integration-only path; tests deliberately never call this function."""
    global CHILD_START_COUNT
    contract = load(root / CONTRACT_PATH)
    validate_schedule(schedule)
    proof = validate_contract(root, contract)
    require(grant.get("grantId") == "north:A" and grant.get("direction") == "north", "grant drift")
    assert_child_budget(CHILD_START_COUNT)
    require(not proof["outputRoot"].exists(), "output root reuse")
    command = build_command(root, contract)
    CHILD_START_COUNT += 1
    process = subprocess.Popen(command, cwd=root, start_new_session=True)
    return {"pid": process.pid, "command": command, "childStarts": CHILD_START_COUNT}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=".")
    parser.add_argument("--zero-child", action="store_true")
    args = parser.parse_args(argv)
    root = Path(args.repository_root).resolve()
    contract = load(root / CONTRACT_PATH)
    validate_contract(root, contract)
    if args.zero_child:
        print(json.dumps({"status": "PASS", "childStarts": 0, "dccProcessCount": 0, "pixelWrites": 0}, sort_keys=True))
        return 0
    raise LaunchError("live Integration schedule/grant required; prelaunch does not self-authorize")


if __name__ == "__main__":
    raise SystemExit(main())
