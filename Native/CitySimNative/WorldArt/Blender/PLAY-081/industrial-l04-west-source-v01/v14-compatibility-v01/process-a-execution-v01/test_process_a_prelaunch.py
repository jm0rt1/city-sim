#!/usr/bin/env python3
"""Static and zero-child Process-A prelaunch proof for West v14."""
from __future__ import annotations

import ast
import copy
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[8]
PACKAGE = Path(__file__).resolve().parent
CONTRACT_PATH = PACKAGE / "PROCESS-A-CONTRACT.json"
DESIGN_PATH = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/WEST-V14-DESIGN.json"
LOWERING_PATH = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/WEST-V14-LOWERING.json"
LAUNCHER_PATH = PACKAGE / "launch_process_a.py"
CHILD_PATH = PACKAGE / "blender_process_a.py"
HANDOFF_PATH = ROOT / "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/process-a-execution-v01/HANDOFF.json"
VALIDATION_PATH = ROOT / "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/process-a-execution-v01/VALIDATION.json"
BRIDGE_PATH = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
CLAIM_SHA = "6b9608a7854afc60676ac27e7c7a8a7c4420161805a4ef59c68649acdd6a901d"
DESIGN_SHA = "334ab5ed19734d6a4f90e499cf8f15872a3c11677a2cb437a912b6a96d0617ad"
LOWERING_SHA = "b15466c78dedc19d1009ddc9cb691002ed7d5dd192c1caf8be05023fb42376dd"
BRIDGE_SHA = "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
ROUTE = "quality-v1:play-081-industrial-l04-v14-west-process-a-prelaunch-v1"
ROUTE_SHA = "5bc7a82740c48fb778b4d081022da629e686af214bdf79598a670492fe880ea3"
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr", ".blend"}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def fail(message: str) -> None:
    raise AssertionError(message)


def validate_contract(contract: dict[str, Any]) -> None:
    if contract.get("task") != "PLAY-081" or contract.get("direction") != "west" or contract.get("stage") != "process-a-prelaunch": fail("identity")
    if contract.get("claimSHA256") != CLAIM_SHA or contract.get("designSHA256") != DESIGN_SHA or contract.get("loweringSHA256") != LOWERING_SHA or contract.get("bridgeSHA256") != BRIDGE_SHA: fail("authority/hash")
    if contract.get("schedule") != {"phase": "prelaunch", "direction": "west", "slot": "A", "queue": "industrial-l04-v14", "childStarts": 0, "maxChildStarts": 1}: fail("schedule/slot/direction")
    if contract.get("executionMode") != "integration_direct" or contract.get("sourceReady") is not False or contract.get("pixelRenderingAuthorized") is not False: fail("execution boundary")
    if contract.get("blender", {}).get("device") != "CPU" or contract.get("blender", {}).get("threads") != 1 or contract.get("blender", {}).get("transparentFilm") is not True: fail("determinism")
    if contract.get("camera", {}).get("projection") != "orthographic-2:1" or contract.get("registration", {}).get("socketWorldXYZ") != [-28, 0, 0] or contract.get("registration", {}).get("socketSourceXY") != [640, 704]: fail("camera/registration")
    if not contract.get("materialRoles") or not contract.get("builderKinds"): fail("semantic contract")
    output = contract.get("futureOutputRoot", "")
    if not output.startswith(contract.get("sourceRoot", "") + "/") or "PLAY-079" in output or "PLAY-080" in output or "PLAY-027" in output: fail("output root")
    if contract.get("outputRootExists") is True: fail("output root reuse")
    if contract.get("childStartCount", 0) != 0: fail("second child")


def ast_tree(path: Path) -> ast.AST:
    return ast.parse(path.read_text(encoding="utf-8"), filename=str(path))


def static_checks(contract: dict[str, Any]) -> None:
    launcher_source = LAUNCHER_PATH.read_text(encoding="utf-8")
    child_source = CHILD_PATH.read_text(encoding="utf-8")
    launcher = ast_tree(LAUNCHER_PATH)
    child = ast_tree(CHILD_PATH)
    popen_calls = [n for n in ast.walk(launcher) if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == "Popen"]
    if len(popen_calls) != 1 or "subprocess.run" in launcher_source or "os.system" in launcher_source: fail("launcher child-start boundary")
    if "--factory-startup" not in launcher_source or "--disable-autoexec" not in launcher_source or "PLAY081_PROCESS_A_AUTHENTICATED" not in launcher_source: fail("launcher flags/auth")
    top_level_bpy = [n for n in child.body if isinstance(n, ast.Import) and any(a.name == "bpy" for a in n.names)]
    if top_level_bpy: fail("top-level Blender import")
    for forbidden in ("requests", "urllib", "socket", "ImageGen", "normaliz", "Package.swift", "Rendering/", "PLAY-079", "PLAY-080", "PLAY-027"):
        if forbidden in launcher_source or forbidden in child_source: fail("forbidden access: " + forbidden)
    if "semantic_manifest" not in child_source or "_build_component" not in child_source or "_make_materials" not in child_source: fail("semantic builder missing")
    if "placeholder" in child_source.lower(): fail("placeholder builder")
    if not any(isinstance(n, ast.Import) and any(a.name == "bpy" for a in n.names) for n in ast.walk(child)): fail("Blender child import missing")
    if 'contract["sourceRoot"]' not in launcher_source or 'contract["futureOutputRoot"]' not in launcher_source: fail("root binding")


def child_manifest_replay() -> tuple[bytes, str]:
    env = dict(os.environ); env["PYTHONDONTWRITEBYTECODE"] = "1"
    outputs = []
    for _ in range(2):
        result = subprocess.run([sys.executable, str(CHILD_PATH), "--emit-manifest"], capture_output=True, env=env, check=False)
        if result.returncode != 0: fail("child semantic manifest failed")
        outputs.append(result.stdout)
    if outputs[0] != outputs[1]: fail("manifest replay differs")
    return outputs[0], hashlib.sha256(outputs[0]).hexdigest()


def adversaries(contract: dict[str, Any]) -> list[str]:
    cases = [
        ("wrong-direction", lambda c: c.update(direction="east")),
        ("wrong-design-hash", lambda c: c.update(designSHA256="deadbeef")),
        ("wrong-lowering-hash", lambda c: c.update(loweringSHA256="deadbeef")),
        ("wrong-slot", lambda c: c["schedule"].update(slot="B")),
        ("second-child", lambda c: c.update(childStartCount=1)),
        ("reused-output", lambda c: c.update(outputRootExists=True)),
        ("sibling-root", lambda c: c.update(futureOutputRoot="Native/CitySimNative/WorldArt/Blender/PLAY-079/east")),
        ("unauthenticated-mode", lambda c: c.update(executionMode="delegated_authenticated")),
        ("gpu", lambda c: c["blender"].update(device="METAL")),
        ("pixel-authority", lambda c: c.update(pixelRenderingAuthorized=True)),
    ]
    passed = []
    for name, mutate in cases:
        candidate = copy.deepcopy(contract)
        mutate(candidate)
        try:
            validate_contract(candidate)
        except AssertionError:
            passed.append(name)
        else:
            fail("adversary accepted: " + name)
    return passed


def emit_derived() -> int:
    contract = load(CONTRACT_PATH)
    manifest, manifest_sha = child_manifest_replay()
    payload = {"contractSHA256": sha(CONTRACT_PATH), "designSHA256": DESIGN_SHA, "loweringSHA256": LOWERING_SHA, "bridgeSHA256": BRIDGE_SHA, "manifestSHA256": manifest_sha, "manifestBytes": len(manifest), "componentCount": len(load(DESIGN_PATH)["components"]), "objectCount": sum(len(c["builderObjects"]) for c in load(DESIGN_PATH)["components"]), "childStarts": 0, "dccInvocations": 0, "pixelFiles": 0, "futureOutputAbsent": not (ROOT / contract["futureOutputRoot"]).exists()}
    sys.stdout.buffer.write(canonical(payload))
    return 0


def main() -> int:
    if "--emit-derived" in sys.argv[1:]: return emit_derived()
    contract = load(CONTRACT_PATH)
    validate_contract(contract)
    static_checks(contract)
    if sha(DESIGN_PATH) != DESIGN_SHA or sha(LOWERING_PATH) != LOWERING_SHA or sha(BRIDGE_PATH) != BRIDGE_SHA: fail("input file drift")
    manifest, manifest_sha = child_manifest_replay()
    if (ROOT / contract["futureOutputRoot"]).exists(): fail("future output root exists")
    if any(p.is_file() and p.suffix.lower() in PIXEL_SUFFIXES for p in PACKAGE.rglob("*")): fail("pixel/binary output present")
    names = adversaries(contract)
    handoff, validation = load(HANDOFF_PATH), load(VALIDATION_PATH)
    expected_validator = str(Path(__file__).resolve().relative_to(ROOT))
    if handoff.get("stage") != "prelaunch" or handoff.get("sourceReady") is not False or handoff.get("execution", {}).get("childStarts") != 0: fail("handoff boundary")
    if validation.get("result") != "PASS" or validation.get("routeId") != ROUTE or validation.get("routeSHA256") != ROUTE_SHA or validation.get("validatorPath") != expected_validator or validation.get("validatorSHA256") != sha(Path(__file__)): fail("validation binding")
    if validation.get("adversaries", {}).get("count") != len(names) or validation.get("freshReplay", {}).get("manifestSHA256") != manifest_sha or validation.get("freshReplay", {}).get("byteIdentical") is not True: fail("validation proof")
    print(f"PASS west-v14-process-a-prelaunch contract=PASS semanticManifest=PASS materialClosure=PASS cameraRegistration=PASS adversaries={len(names)} freshReplay=BYTE_IDENTICAL childStarts=0 dcc=0 pixels=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
