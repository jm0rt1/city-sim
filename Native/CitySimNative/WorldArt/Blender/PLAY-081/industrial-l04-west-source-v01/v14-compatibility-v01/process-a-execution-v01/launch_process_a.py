#!/usr/bin/env python3
"""Integration-direct one-child Process-A launch boundary.

Prelaunch tests inspect this file but never invoke it.  Only a validated
Integration grant may reach the single child-start site.
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[8]
PACKAGE = Path(__file__).resolve().parent
CONTRACT = PACKAGE / "PROCESS-A-CONTRACT.json"
CHILD = PACKAGE / "blender_process_a.py"


def load() -> dict[str, Any]:
    return json.loads(CONTRACT.read_text(encoding="utf-8"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_grant(grant: dict[str, Any]) -> dict[str, Any]:
    contract = load()
    required = {"phase": "prelaunch", "direction": "west", "slot": "A", "queue": "industrial-l04-v14", "childStarts": 0, "maxChildStarts": 1}
    if grant != required:
        raise PermissionError("schedule/slot/direction grant mismatch")
    if contract["schedule"] != grant or contract["direction"] != "west" or contract["processID"] != "west-v14-process-a":
        raise PermissionError("contract authority mismatch")
    if sha(ROOT / contract["designPath"]) != contract["designSHA256"] or sha(ROOT / contract["loweringPath"]) != contract["loweringSHA256"]:
        raise PermissionError("frozen input hash mismatch")
    output = ROOT / contract["futureOutputRoot"]
    if output.exists() or output.is_symlink():
        raise FileExistsError("immutable output root already exists")
    if not str(output).startswith(str(ROOT / contract["sourceRoot"])):
        raise PermissionError("output root escape")
    return contract


def launch(grant: dict[str, Any]) -> None:
    contract = validate_grant(grant)
    command = [contract["blender"]["executable"], "--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1", "--python", str(CHILD)]
    env = dict(os.environ)
    env["PLAY081_PROCESS_A_AUTHENTICATED"] = "1"
    # Exactly one child-start site; Integration owns the future invocation.
    subprocess.Popen(command, cwd=str(ROOT), env=env, close_fds=True)


if __name__ == "__main__":
    raise SystemExit("integration_direct only; no caller launch")
