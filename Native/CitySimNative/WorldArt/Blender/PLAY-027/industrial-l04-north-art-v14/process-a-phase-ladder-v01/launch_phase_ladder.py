#!/usr/bin/env python3
"""Inert Stage-A launcher; it cannot create a child, output root, or pixels."""
from __future__ import annotations

import argparse
import ast
import json
from pathlib import Path
from typing import Any

CONTRACT_PATH = Path("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14/process-a-phase-ladder-v01/DIAGNOSTIC-CONTRACT.json")
STAGE_B_CHILD_START_SITES = 1
CHILD_START_COUNT = 0


class StageBNotAuthorized(RuntimeError):
    pass


def load_contract(root: Path) -> dict[str, Any]:
    value = json.loads((root / CONTRACT_PATH).read_text())
    if type(value) is not dict or value.get("stageAExecution", {}).get("stageBLaunchReachable") is not False:
        raise RuntimeError("diagnostic contract drift")
    return value


def safe_output_leaf(root: Path, relative: str, contract: dict[str, Any]) -> Path:
    if Path(relative).is_absolute() or relative.startswith("../") or "/../" in relative:
        raise RuntimeError("output path escapes exclusive root")
    candidate = (root / relative).resolve(strict=False)
    allowed_root = (root / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14/process-a-phase-ladder-v01").resolve()
    if allowed_root not in candidate.parents:
        raise RuntimeError("output path outside phase root")
    if candidate.name not in contract["allowedOutputLeaves"]:
        raise RuntimeError("output leaf not allowlisted")
    if candidate.exists() or candidate.is_symlink():
        raise RuntimeError("output leaf must be absent")
    return candidate


def prepare_zero_child(root: Path) -> dict[str, Any]:
    root = root.resolve(strict=True)
    contract = load_contract(root)
    output_root = root / contract["futureStageB"]["outputRoot"]
    if output_root.exists() or output_root.is_symlink():
        raise RuntimeError("future Stage-B output root must remain absent")
    return {
        "status": "STATIC_REFERENCE_CANDIDATE",
        "architectureState": contract["architectureState"],
        "childStarts": 0,
        "dccProcessCount": 0,
        "pixelWrites": 0,
        "outputRootCreated": 0,
        "phases": 9,
        "stageBRequired": True,
    }


def launch_stage_b(*_args: Any, **_kwargs: Any) -> None:
    raise StageBNotAuthorized("Stage-B launch requires a separately published Integration authority")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=".")
    parser.add_argument("--zero-child", action="store_true")
    args = parser.parse_args(argv)
    if not args.zero_child:
        raise StageBNotAuthorized("Stage-A launcher is zero-child only")
    print(json.dumps(prepare_zero_child(Path(args.repository_root)), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
