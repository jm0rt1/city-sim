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
VALIDATION_PATH = ROOT / "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/INDEPENDENT-RETURN-REPAIR-V1.json"
BRIDGE_PATH = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
CLAIM_SHA = "6b9608a7854afc60676ac27e7c7a8a7c4420161805a4ef59c68649acdd6a901d"
PUBLISHED_BASE = "6b4145d35d358ddebb645cf7ca892406435bbd1b"
AUTHORITY_COMMIT = "9beafc0819a6dfbbf58bba5bd2f48657b1f526a8"
NORTH_REFERENCE_COMMIT = "ebe649d550b1a0811b72f75184bf188b86b343dc"
DESIGN_SHA = "07951aa7101c1c917c050a449f255e13f8de95b30b8ea1828e080bf7fa231a18"
LOWERING_SHA = "a54374313e335d5af53f2441363db435f9d6e44edc0a3e68daee1704d451f172"
BRIDGE_SHA = "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
ROUTE = "quality-v1:play-081-industrial-l04-v14-west-process-a-prelaunch-repair-v2"
ROUTE_SHA = "05884249492edfdc1c4c295a6b479470b6fe17dacf661285682cd34bc13163ec"
REPAIR_ROUTE = "quality-v2:play-081-west-v14-independent-return-repair-v1"
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
    if contract.get("publishedBase") != PUBLISHED_BASE or contract.get("authorityCommit") != AUTHORITY_COMMIT or contract.get("northStructuralReference", {}).get("commit") != NORTH_REFERENCE_COMMIT: fail("current authority/reference")
    if contract.get("schedule") != {"phase": "prelaunch", "direction": "west", "slot": "A", "queue": "industrial-l04-v14", "childStarts": 0, "maxChildStarts": 1}: fail("schedule/slot/direction")
    if contract.get("executionMode") != "integration_direct" or contract.get("sourceReady") is not False or contract.get("pixelRenderingAuthorized") is not False: fail("execution boundary")
    if contract.get("blender", {}).get("device") != "CPU" or contract.get("blender", {}).get("threads") != 1 or contract.get("blender", {}).get("transparentFilm") is not True: fail("determinism")
    if contract.get("camera", {}).get("projection") != "orthographic-2:1" or contract.get("registration", {}).get("socketWorldXYZ") != [-28, 0, 0] or contract.get("registration", {}).get("socketSourceXY") != [640, 704]: fail("camera/registration")
    if not contract.get("materialRoles") or not contract.get("builderKinds"): fail("semantic contract")
    output = contract.get("futureOutputRoot", "")
    if not output.startswith(contract.get("sourceRoot", "") + "/") or "PLAY-079" in output or "PLAY-080" in output or "PLAY-027" in output: fail("output root")
    if contract.get("outputRootExists") is True: fail("output root reuse")
    if contract.get("childStartCount", 0) != 0: fail("second child")
    if contract.get("outputPolicy") != {"createExclusiveRootBeforeRenderAndSave": True, "allowGenericAABBFallback": False, "requireAimedLights": True, "requireNonDegenerateFaces": True}: fail("output/semantic policy")


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
    required_child = ("load_exact_profile", "_add_wedge_mesh", "_add_portal_frame_mesh", "_add_compound_recessed_portal", "portal-recessed-dark-back-plane", "clerestory-and-roof-edge", "deep-freight-void", "runtime_portal", "_add_mullion_mesh", "_add_pipe_segment", "_pipe_elbow_control_points", "_add_pipe_elbow", "use_fill_caps", "BEZIER", "_oriented_beam_parts", "_add_truss_cluster", "_add_truss_member", "_configure_camera", "_configure_lighting", "bpy.data.cameras.new", "to_track_quat", "light.rotation_euler", "CYCLES", "world", "AREA", "film_transparent", "color_mode", "view_transform", "use_adaptive_sampling", "_assert_output_path_is_lexical", "output_root.mkdir", "write_still=True", "save_as_mainfile", "sourceProductionProfile")
    if any(token not in child_source for token in required_child): fail("real Blender construction contract")
    if "bpy.ops.mesh.primitive_cube_add" in child_source or "bpy.ops.mesh.primitive_cylinder_add" in child_source or "diffuse_color = (0.35" in child_source: fail("semantic primitive/material downgrade")
    if child_source.index("profile = load_exact_profile()") > child_source.index("import bpy"): fail("profile gate after bpy import")
    top_level_bpy = [n for n in child.body if isinstance(n, ast.Import) and any(a.name == "bpy" for a in n.names)]
    if top_level_bpy: fail("top-level Blender import")
    for forbidden in ("requests", "urllib", "socket", "ImageGen", "normaliz", "Package.swift", "Rendering/", "PLAY-079", "PLAY-080", "PLAY-027"):
        if forbidden in launcher_source or forbidden in child_source: fail("forbidden access: " + forbidden)
    if "semantic_manifest" not in child_source or "_build_component" not in child_source or "_make_materials" not in child_source: fail("semantic builder missing")
    if "placeholder" in child_source.lower(): fail("placeholder builder")
    if not any(isinstance(n, ast.Import) and any(a.name == "bpy" for a in n.names) for n in ast.walk(child)): fail("Blender child import missing")
    if 'contract["sourceRoot"]' not in launcher_source or 'contract["futureOutputRoot"]' not in launcher_source: fail("root binding")
    build_start = child_source.index("def build_scene")
    if child_source.index("output_root.mkdir", build_start) > child_source.index("    _configure_render", build_start) or child_source.index("    _configure_render", build_start) > child_source.index("    write_provenance", build_start): fail("output-order")
    if "return [_add_box_mesh(bpy, name, lower, upper, material) for name in names]" in child_source: fail("generic AABB fallback")


def static_adversaries() -> list[str]:
    source = CHILD_PATH.read_text(encoding="utf-8")
    required = ("_add_wedge_mesh", "_add_portal_frame_mesh", "_add_compound_recessed_portal", "portal-recessed-dark-back-plane", "runtime_portal", "_add_mullion_mesh", "_add_pipe_segment", "_pipe_elbow_control_points", "_add_pipe_elbow", "use_fill_caps", "BEZIER", "_oriented_beam_parts", "_add_truss_cluster", "_configure_camera", "_configure_lighting", "bpy.data.cameras.new", "to_track_quat", "light.rotation_euler", "_assert_output_path_is_lexical", "output_root.mkdir", "write_still=True", "save_as_mainfile", "PLAY081_PROCESS_A_AUTHENTICATED")
    cases = [("cube-downgrade", "_add_wedge_mesh"), ("missing-portal-assembly", "_add_compound_recessed_portal"), ("missing-portal-back-plane", "portal-recessed-dark-back-plane"), ("missing-portal-material-reconciliation", "runtime_portal"), ("missing-topology", "_oriented_beam_parts"), ("missing-truss-reachability", "_add_truss_cluster"), ("missing-elbow-controls", "_pipe_elbow_control_points"), ("missing-elbow", "_add_pipe_elbow"), ("uncapped-elbow", "use_fill_caps"), ("camera-without-data", "bpy.data.cameras.new"), ("camera-without-aim", "to_track_quat"), ("unaimed-light", "light.rotation_euler"), ("missing-light-world", "_configure_lighting"), ("unsafe-output-root", "_assert_output_path_is_lexical"), ("output-root-order", "output_root.mkdir"), ("missing-render", "write_still=True"), ("missing-blend-write", "save_as_mainfile"), ("low-level-bypass", "PLAY081_PROCESS_A_AUTHENTICATED")]
    passed = []
    for name, token in cases:
        mutant = source.replace(token, "")
        if all(item in mutant for item in required):
            fail("static adversary accepted: " + name)
        passed.append(name)
    return passed


def runtime_semantic_checks() -> list[str]:
    """Exercise pure geometry helpers without importing Blender or starting a child."""
    spec = __import__("importlib.util").util.spec_from_file_location("west_process_a_child", CHILD_PATH)
    if spec is None or spec.loader is None: fail("child import unavailable")
    module = __import__("importlib.util").util.module_from_spec(spec)
    spec.loader.exec_module(module)
    manifest = module.semantic_manifest()
    if manifest["componentCount"] != 29 or manifest["objectCount"] != 34: fail("semantic coverage counts")
    builders = {item["builder"] for item in manifest["objects"]}
    if "truss_chords_diagonals" not in builders or "pipe_run_with_elbows" not in builders or "compound_portal_frame" not in builders or "mullioned_glazing_band" not in builders: fail("required semantic reachability")
    if not {"west-v14-truss-chord-left", "west-v14-truss-chord-right", "west-v14-truss-diagonal"}.issubset({item["id"] for item in manifest["objects"]}): fail("truss objects unreachable")
    portal = manifest.get("runtimePortal", {})
    if portal.get("compound") is not True or portal.get("derivedFromAperture") != "west-v14-deep-freight-aperture": fail("portal runtime reachability")
    portal_materials = {item["id"]: item["materialRole"] for item in portal.get("objects", [])}
    if portal_materials.get("west-v14-portal-reveal-surface") != "clerestory-and-roof-edge" or portal_materials.get("west-v14-portal-recessed-dark-back-plane") != "deep-freight-void": fail("portal material assignment")
    elbow = manifest.get("pipeElbow", {})
    if elbow.get("explicitEndpoints") is not True or elbow.get("capped") is not True or elbow.get("nonCollinear") is not True or not any(abs(value) > 1.0e-6 for value in elbow.get("nonCollinearCrossProduct", [])): fail("elbow geometry proof")
    vertices, faces = module._oriented_beam_parts((-1.0, 0.0, -1.0), (1.0, 2.0, 1.0), 0.2)
    if len(vertices) < 8 or not faces or any(len(face) < 3 or len(set(face)) != len(face) for face in faces): fail("truss topology")
    if any(index < 0 or index >= len(vertices) for face in faces for index in face): fail("truss indices")
    return ["closed-truss-beam", "nondegenerate-faces", "no-blender-import"]


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
    names = adversaries(contract) + static_adversaries() + runtime_semantic_checks()
    handoff, validation = load(HANDOFF_PATH), load(VALIDATION_PATH)
    proof = validation.get("processProof", {})
    expected_validator = str(Path(__file__).resolve().relative_to(ROOT))
    if handoff.get("stage") != "prelaunch" or handoff.get("sourceReady") is not False or handoff.get("execution", {}).get("childStarts") != 0: fail("handoff boundary")
    if validation.get("result") != "PASS" or validation.get("routeId") != REPAIR_ROUTE or proof.get("validatorPath") != expected_validator or proof.get("validatorSHA256") != sha(Path(__file__)): fail("validation binding")
    if proof.get("contractSHA256") != sha(CONTRACT_PATH) or proof.get("childSHA256") != sha(CHILD_PATH) or proof.get("launcherSHA256") != sha(LAUNCHER_PATH): fail("implementation hash binding")
    if proof.get("adversaries", {}).get("count") != len(names) or proof.get("freshReplay", {}).get("manifestSHA256") != manifest_sha or proof.get("freshReplay", {}).get("byteIdentical") is not True: fail("validation proof")
    print(f"PASS west-v14-process-a-prelaunch contract=PASS semanticManifest=PASS materialClosure=PASS cameraRegistration=PASS adversaries={len(names)} freshReplay=BYTE_IDENTICAL childStarts=0 dcc=0 pixels=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
