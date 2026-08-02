#!/usr/bin/env python3
"""Integration-direct North v14 Process-A launcher reference.

The worker-owned focused test exercises only validation and preparation. Only a
future Integration-owned contained-smoke authority may call ``launch``.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import signal
import subprocess
from pathlib import Path
from typing import Any

SOURCE_ROOT = Path("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14")
PROCESS_ROOT = SOURCE_ROOT / "process-a-execution-v01"
CONTRACT_PATH = PROCESS_ROOT / "EXECUTION-CONTRACT.json"
CHILD_PATH = PROCESS_ROOT / "render_north_process_a_child.py"
LAUNCHER_PATH = PROCESS_ROOT / "launch_north_process_a.py"
CHILD_START_COUNT = 0


class LaunchError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise LaunchError(message)


def canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text())
    require(type(value) is dict, f"object required: {path}")
    return value


def git_head(root: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    require(result.returncode == 0, "worker HEAD unavailable")
    value = result.stdout.strip()
    require(len(value) == 40 and all(c in "0123456789abcdef" for c in value), "worker HEAD invalid")
    return value


def resolve_regular(root: Path, relative: str, label: str) -> Path:
    require(relative and not relative.startswith("/"), f"{label} must be relative")
    require(".." not in Path(relative).parts, f"{label} dot-dot forbidden")
    current = root.resolve(strict=True)
    for part in Path(relative).parts:
        current /= part
        require(not current.is_symlink(), f"{label} symlink")
    resolved = (root / relative).resolve(strict=True)
    require(resolved.is_relative_to(root.resolve()), f"{label} escapes repository")
    require(resolved.is_file() and not resolved.is_symlink(), f"{label} must be regular")
    return resolved


def resolve_external_regular(path: Path, label: str) -> Path:
    require(path.is_absolute(), f"{label} must be absolute")
    require(".." not in path.parts, f"{label} dot-dot forbidden")
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current /= part
        require(not current.is_symlink(), f"{label} symlink")
    resolved = path.resolve(strict=True)
    require(resolved.is_file() and not resolved.is_symlink(), f"{label} must be regular")
    return resolved


def load_lowerer(root: Path) -> Any:
    path = root / SOURCE_ROOT / "lower_v14_scene.py"
    spec = importlib.util.spec_from_file_location("play027_v14_lowerer", path)
    require(spec is not None and spec.loader is not None, "lowerer import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def output_path(root: Path, contract: dict[str, Any]) -> Path:
    relative = contract["outputRoot"]
    require(relative == str(PROCESS_ROOT / "process-a-output"), "unexpected output root")
    candidate = root / relative
    require(candidate.parent.resolve(strict=True) == (root / PROCESS_ROOT).resolve(strict=True), "output parent drift")
    require(not candidate.exists() and not candidate.is_symlink(), "future output root must be absent")
    return candidate


def validate_contract(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    require(contract["task"] == "PLAY-027" and contract["direction"] == "north" and contract["process"] == "A", "contract identity drift")
    require(contract["evidenceRoot"].startswith("docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v14/process-a-execution-v01"), "evidence root leaves exclusive North root")
    require(contract["registration"]["socketCitySim"] == [0, 0, -28], "socket CitySim drift")
    require(contract["registration"]["socketBlender"] == [-28, 0, 0], "socket Blender drift")
    require(contract["registration"]["socketSource"] == [896, 704], "socket source drift")
    expected_cycles = {
        "device": "CPU", "threads": 1, "seed": 17, "samples": 64,
        "adaptiveSampling": False, "denoising": False, "motionBlur": False,
        "transparentFilm": True, "resolution": [1536, 1024], "pixelAspect": [1, 1],
        "colorManagement": {
            "displayDevice": "sRGB", "viewTransform": "Standard",
            "look": "Medium High Contrast", "exposure": 0.0, "gamma": 1.0,
        },
    }
    require(contract["cycles"] == expected_cycles, "Cycles contract drift")
    require(contract["allowedOutputs"] == [
        "raw.png", "semantic.png", "north-v14-process-a.blend", "OBJECT-MANIFEST.json",
        "GROUND-PROJECTION.json", "INPUT-BINDINGS.json", "provenance.json", "PROCESS-RECEIPT.json",
    ], "allowed output inventory drift")
    frozen: dict[str, Path] = {}
    for name, binding in contract["frozenInputs"].items():
        path = resolve_regular(root, binding["path"], name)
        require(sha256(path) == binding["sha256"], f"{name} hash drift")
        frozen[name] = path
    lowerer = load_lowerer(root)
    packet = lowerer.run()
    report = packet["report"]
    require(report["componentCount"] == 33 and report["objectCount"] == 97, "frozen v14 lowering drift")
    require(report["componentToObjectCoverage"]["percent"] == 100.0 and report["portal"]["socketConnected"], "lowering proof incomplete")
    return {"frozen": frozen, "packet": packet, "outputRoot": output_path(root, contract)}


def validate_direct_documents(
    root: Path,
    contract: dict[str, Any],
    schedule_path: Path,
    grant_path: Path,
    session_path: Path,
) -> dict[str, Any]:
    schedule_file = resolve_external_regular(schedule_path, "schedule")
    grant_file = resolve_external_regular(grant_path, "grant")
    session_file = resolve_external_regular(session_path, "session")
    schedule, grant, session = load(schedule_file), load(grant_file), load(session_file)
    require(schedule == {
        "schema": 1,
        "task": "PLAY-027",
        "batch": contract["batch"],
        "direction": "north",
        "process": "A",
        "slot": "north:A",
        "maximumChildStarts": 1,
        "contractSHA256": sha256(root / CONTRACT_PATH),
        "launcherSHA256": sha256(root / LAUNCHER_PATH),
        "childSHA256": sha256(root / CHILD_PATH),
        "frozenInputs": contract["frozenInputs"],
        "outputRoot": contract["outputRoot"],
    }, "schedule contract drift")
    schedule_hash = sha256(schedule_file)
    require(grant == {
        "schema": 1,
        "grantId": "north:A",
        "direction": "north",
        "process": "A",
        "maximumChildStarts": 1,
        "scheduleSHA256": schedule_hash,
        "outputRoot": contract["outputRoot"],
        "sessionId": session.get("sessionId"),
    }, "grant contract drift")
    grant_hash = sha256(grant_file)
    require(session == {
        "schema": 1,
        "sessionId": session.get("sessionId"),
        "expectedWorkerHead": git_head(root),
        "scheduleSHA256": schedule_hash,
        "grantSHA256": grant_hash,
        "outputRoot": contract["outputRoot"],
        "state": "integration-issued",
    }, "session contract drift")
    require(type(session["sessionId"]) is str and len(session["sessionId"]) >= 16, "session id invalid")
    return {
        "schedule": schedule,
        "grant": grant,
        "session": session,
        "schedulePath": schedule_file,
        "grantPath": grant_file,
        "sessionPath": session_file,
        "scheduleSHA256": schedule_hash,
        "grantSHA256": grant_hash,
        "sessionSHA256": sha256(session_file),
    }


def build_command(root: Path, contract: dict[str, Any], documents: dict[str, Any]) -> list[str]:
    return [
        contract["blender"]["executable"],
        "--background",
        "--factory-startup",
        "--disable-autoexec",
        "--python-exit-code", "1",
        "--python", str(root / CHILD_PATH),
        "--",
        "--repository-root", str(root),
        "--contract", str(root / CONTRACT_PATH),
        "--direction", "north",
        "--schedule", str(documents["schedulePath"]),
        "--grant", str(documents["grantPath"]),
        "--integration-session", str(documents["sessionPath"]),
        "--output-root", str(root / contract["outputRoot"]),
    ]


def build_environment(documents: dict[str, Any]) -> dict[str, str]:
    environment = dict(os.environ)
    environment.update({
        "CITYSIM_PROCESS_A_LIVE": "1",
        "CITYSIM_PROCESS_A_SCHEDULE_SHA256": documents["scheduleSHA256"],
        "CITYSIM_PROCESS_A_GRANT_SHA256": documents["grantSHA256"],
        "CITYSIM_PROCESS_A_SESSION_SHA256": documents["sessionSHA256"],
    })
    return environment


def prepare_launch(root: Path, schedule_path: Path, grant_path: Path, session_path: Path) -> dict[str, Any]:
    root = root.resolve(strict=True)
    contract = load(root / CONTRACT_PATH)
    proof = validate_contract(root, contract)
    documents = validate_direct_documents(root, contract, schedule_path, grant_path, session_path)
    require(CHILD_START_COUNT == 0, "second child forbidden")
    require(not proof["outputRoot"].exists(), "output root reuse")
    return {
        "contract": contract,
        "proof": proof,
        "documents": documents,
        "command": build_command(root, contract, documents),
        "environment": build_environment(documents),
        "outputRoot": proof["outputRoot"],
    }


def create_exclusive_output_root(path: Path) -> int:
    require(not path.exists() and not path.is_symlink(), "output root reuse")
    require(path.name not in {"", ".", ".."}, "output root leaf invalid")
    parent_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.mkdir(path.name, mode=0o700, dir_fd=parent_fd)
        output_fd = os.open(path.name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent_fd)
        try:
            inode = os.fstat(output_fd).st_ino
        finally:
            os.close(output_fd)
    finally:
        os.close(parent_fd)
    require(path.is_dir() and not path.is_symlink() and path.stat().st_ino == inode, "output root identity invalid")
    return inode


def launch(root: Path, schedule_path: Path, grant_path: Path, session_path: Path) -> dict[str, Any]:
    """Integration-only contained-smoke/Process-A entrypoint; uncalled here."""
    global CHILD_START_COUNT
    prepared = prepare_launch(root, schedule_path, grant_path, session_path)
    output = prepared["outputRoot"]
    inode = create_exclusive_output_root(output)
    environment = prepared["environment"]
    environment["CITYSIM_PROCESS_A_OUTPUT_INODE"] = str(inode)
    try:
        process = subprocess.Popen(
            prepared["command"],
            cwd=root,
            env=environment,
            start_new_session=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except Exception as error:
        raise LaunchError(f"Blender child start failed: {error}") from error
    CHILD_START_COUNT += 1
    try:
        stdout, stderr = process.communicate(timeout=prepared["contract"]["processEnvelope"]["timeoutSeconds"])
    except subprocess.TimeoutExpired as error:
        os.killpg(process.pid, signal.SIGKILL)
        stdout, stderr = process.communicate()
        raise LaunchError(f"Blender child timeout: stdout={len(stdout)} stderr={len(stderr)}") from error
    require(process.returncode == 0, f"Blender child failed: returncode={process.returncode}, stdout={len(stdout)}, stderr={len(stderr)}")
    return {
        "pid": process.pid,
        "command": prepared["command"],
        "childStarts": CHILD_START_COUNT,
        "returncode": process.returncode,
        "stdoutBytes": len(stdout),
        "stderrBytes": len(stderr),
        "outputRoot": str(output),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=".")
    parser.add_argument("--zero-child", action="store_true")
    parser.add_argument("--schedule")
    parser.add_argument("--grant")
    parser.add_argument("--integration-session")
    args = parser.parse_args(argv)
    root = Path(args.repository_root).resolve(strict=True)
    contract = load(root / CONTRACT_PATH)
    validate_contract(root, contract)
    if args.zero_child:
        require(args.schedule is None and args.grant is None and args.integration_session is None, "zero-child authority arguments forbidden")
        print(json.dumps({"status": "STATIC_REFERENCE_CANDIDATE", "executableBehavior": "UNPROVEN", "childStarts": 0, "dccProcessCount": 0, "pixelWrites": 0}, sort_keys=True))
        return 0
    require(args.schedule is not None and args.grant is not None and args.integration_session is not None, "live Integration schedule/grant/session required")
    result = launch(root, Path(args.schedule), Path(args.grant), Path(args.integration_session))
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
