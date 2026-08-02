#!/usr/bin/env python3
"""Authenticated one-child Process-A launcher; never called by prelaunch tests."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[7]
CONTRACT = ROOT / "PROCESS-A-CONTRACT.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_contract() -> dict:
    return json.loads(CONTRACT.read_text(encoding="utf-8"))


def _inside(relative: str, prefix: str) -> bool:
    return relative == prefix or relative.startswith(prefix.rstrip("/") + "/")


def validate_contract(contract: dict, repo: Path = REPO) -> dict:
    if contract.get("schema") != "citysim.play-079.east-v14-process-a-contract.v1": raise ValueError("contract_schema")
    if contract.get("task") != "PLAY-079" or contract.get("direction") != "east" or contract.get("familyRevision") != "v14": raise ValueError("identity")
    if contract["authority"]["observedHead"] != "3b02b6baec92190a976c9d843c1b96585072725a": raise ValueError("observed_head")
    for binding in contract["immutableInputs"].values():
        path = repo / binding["path"]
        if not path.is_file() or path.is_symlink() or digest(path) != binding["sha256"]: raise ValueError("immutable_input")
    if contract["execution"]["direction"] != "east" or contract["execution"]["childLimit"] != 1 or contract["execution"]["dccSlot"] != 1: raise ValueError("execution_binding")
    output = contract["execution"]["outputRoot"]
    if not _inside(output, "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-output-v01"): raise ValueError("output_root")
    output_path = repo / output
    if output_path.exists() or output_path.is_symlink(): raise ValueError("output_reuse")
    if contract["execution"]["launchGrant"] is None: raise ValueError("launch_grant_missing")
    return contract


def validate_grant(contract: dict, grant: dict) -> None:
    expected = {
        "scheduleId": contract["execution"]["scheduleId"],
        "processId": contract["execution"]["processId"],
        "direction": "east",
        "dccSlot": 1,
        "childLimit": 1,
        "baseCommit": contract["authority"]["baseCommit"],
        "observedHead": contract["authority"]["observedHead"],
        "outputRoot": contract["execution"]["outputRoot"],
    }
    if any(grant.get(key) != value for key, value in expected.items()): raise ValueError("grant_binding")
    if grant.get("attempt") != 1 or grant.get("authenticated") is not True: raise ValueError("grant_authentication")


def launch(contract: dict, grant: dict, repo: Path = REPO) -> int:
    validate_contract(contract, repo)
    validate_grant(contract, grant)
    child = ROOT / contract["execution"]["child"]
    command = [contract["execution"]["blenderExecutable"], "--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1", "--python", str(child)]
    env = {"PATH": os.environ.get("PATH", ""), "CITYSIM_PROCESS_ID": contract["execution"]["processId"], "CITYSIM_OUTPUT_ROOT": str(repo / contract["execution"]["outputRoot"])}
    proc = subprocess.Popen(command, cwd=str(repo), env=env)
    return proc.wait()


def main(argv: list[str]) -> int:
    contract = load_contract()
    if argv[1:] != ["--launch"]:  # dry structural validation remains child-free
        try:
            validate_contract(contract)
        except ValueError as error:
            print(f"BLOCKED:{error}")
            return 2
        print("READY: launch grant required; zero child started")
        return 0
    grant = contract.get("execution", {}).get("launchGrant")
    if not isinstance(grant, dict):
        print("BLOCKED:launch_grant_missing")
        return 2
    return launch(contract, grant)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
