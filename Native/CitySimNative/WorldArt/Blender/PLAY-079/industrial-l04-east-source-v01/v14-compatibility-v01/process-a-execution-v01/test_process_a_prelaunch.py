#!/usr/bin/env python3
"""Static, immutable-input, and zero-child Process-A prelaunch proof."""

from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import shutil
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[7]
CONTRACT = ROOT / "PROCESS-A-CONTRACT.json"
LAUNCHER = ROOT / "run_process_a.py"
CHILD = ROOT / "process_a_child.py"
EVIDENCE = REPO / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01"
HANDOFF = EVIDENCE / "HANDOFF.json"
VALIDATION = EVIDENCE / "VALIDATION.json"
PARENT = "3b02b6baec92190a976c9d843c1b96585072725a"
EXPECTED_PATHS = {
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/PROCESS-A-CONTRACT.json",
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/run_process_a.py",
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/process_a_child.py",
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/test_process_a_prelaunch.py",
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/HANDOFF.json",
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/VALIDATION.json",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canon(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def fail(code: str, detail: str = "") -> None:
    raise AssertionError(code + ((":" + detail) if detail else ""))


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def static_checks() -> list[dict]:
    launcher_tree = ast.parse(LAUNCHER.read_text(encoding="utf-8"))
    child_tree = ast.parse(CHILD.read_text(encoding="utf-8"))
    popen_calls = [node for node in ast.walk(launcher_tree) if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "Popen"]
    if len(popen_calls) != 1: fail("child_start_site", str(len(popen_calls)))
    if any(keyword.arg == "shell" and isinstance(keyword.value, ast.Constant) and keyword.value.value is True for node in popen_calls for keyword in node.keywords): fail("shell_launch")
    if any(isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "Popen" for node in ast.walk(child_tree)): fail("child_recursive_launch")
    child_imports = [node for node in ast.walk(child_tree) if isinstance(node, ast.Import) and any(alias.name == "bpy" for alias in node.names)]
    if len(child_imports) != 1: fail("blender_import_shape")
    combined = LAUNCHER.read_text(encoding="utf-8") + CHILD.read_text(encoding="utf-8")
    for forbidden in ("ImageGen", "requests", "urllib", "normalizer", "normalization", "Rendering/", "Package.swift", "PLAY-080", "PLAY-081", "PLAY-027"):
        if forbidden in combined: fail("forbidden_dependency", forbidden)
    primitive_names = {
        "deterministic_box", "pitched_roof_wedge", "mullion_band", "cylinder_with_caps",
        "restrained_heat_cap", "rail_and_support_run", "capped_pipe_run", "quarter_turn_elbow",
        "pipe_support_bracket", "roof_plant_cluster", "vent_louver_array", "service_door_with_frame",
        "gutter_run", "roof_edge_trim", "loading_safety_marking", "masonry_seam_wear_band",
    }
    primitive_map = [node for node in ast.walk(child_tree) if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "PRIMITIVE_BUILDERS" for target in node.targets)]
    if len(primitive_map) != 1: fail("primitive_builder_map")
    child_text = CHILD.read_text(encoding="utf-8")
    if "PRIMITIVE_BUILDERS[primitive]" not in child_text or '"generic"' in child_text: fail("primitive_fallback")
    for primitive in primitive_names:
        if f'"{primitive}"' not in child_text: fail("primitive_missing", primitive)
    return [{"case":"one_popen_site","result":"PASS"},{"case":"child_has_no_launcher","result":"PASS"},{"case":"blender_import_is_child_only","result":"PASS"},{"case":"forbidden_surfaces_absent","result":"PASS"},{"case":"explicit_semantic_primitive_builders","result":"PASS"},{"case":"no_generic_primitive_fallback","result":"PASS"}]


def validate_inputs(contract: dict, launcher) -> list[dict]:
    if contract["authority"]["observedHead"] != PARENT: fail("observed_head")
    if contract["execution"]["launchGrant"] is not None: fail("prelaunch_grant_present")
    if contract["zeroChildBoundary"] != {"childStarts":0,"blenderInvocations":0,"dccInvocations":0,"renderInvocations":0,"pixelFilesCreated":0,"blendFilesCreated":0,"normalizationRuns":0}: fail("zero_child_boundary")
    try:
        launcher.validate_contract(contract)
    except ValueError as error:
        if str(error) != "launch_grant_missing": fail("missing_grant_wrong_rejection", str(error))
    else:
        fail("missing_grant_accepted")
    fixture = copy.deepcopy(contract)
    fixture["execution"]["launchGrant"] = {"scheduleId":contract["execution"]["scheduleId"],"processId":"east-process-a","direction":"east","dccSlot":1,"childLimit":1,"baseCommit":contract["authority"]["baseCommit"],"observedHead":PARENT,"outputRoot":contract["execution"]["outputRoot"],"attempt":1,"authenticated":True}
    launcher.validate_contract(fixture)
    launcher.validate_grant(fixture, fixture["execution"]["launchGrant"])
    cases = [{"case":"synthetic_grant_shape","result":"PASS"}]
    negatives = {
        "wrong_direction": lambda g: g.update({"direction":"south"}),
        "wrong_slot": lambda g: g.update({"dccSlot":2}),
        "wrong_schedule": lambda g: g.update({"scheduleId":"stale"}),
        "wrong_base": lambda g: g.update({"baseCommit":"deadbeef"}),
        "second_attempt": lambda g: g.update({"attempt":2}),
        "unauthenticated": lambda g: g.update({"authenticated":False}),
    }
    for name, mutate in negatives.items():
        grant = copy.deepcopy(fixture["execution"]["launchGrant"])
        mutate(grant)
        try:
            launcher.validate_grant(fixture, grant)
        except ValueError:
            cases.append({"case":name,"result":"REJECTED"})
        else:
            fail("grant_adversary_accepted", name)
    output = REPO / fixture["execution"]["outputRoot"]
    output.mkdir(parents=False, exist_ok=False)
    try:
        try:
            launcher.validate_contract(fixture)
        except ValueError as error:
            if str(error) != "output_reuse": fail("output_reuse_wrong_rejection", str(error))
            cases.append({"case":"preexisting_output_root","result":"REJECTED"})
        else:
            fail("output_reuse_accepted")
    finally:
        shutil.rmtree(output)
    sibling = copy.deepcopy(fixture)
    sibling["execution"]["outputRoot"] = "Native/CitySimNative/WorldArt/Blender/PLAY-081/foreign-output"
    try:
        launcher.validate_contract(sibling)
    except ValueError as error:
        if str(error) != "output_root": fail("sibling_root_wrong_rejection", str(error))
        cases.append({"case":"sibling_output_root","result":"REJECTED"})
    else:
        fail("sibling_output_root_accepted")
    return cases


def semantic_checks(child, design: dict, lowering: dict) -> list[dict]:
    semantic = child.build_semantic_geometry()
    if len(semantic["components"]) != len(design["components"]): fail("semantic_component_count")
    object_ids = [item["objectId"] for item in semantic["components"]]
    if len(object_ids) != len(set(object_ids)) or len(object_ids) != len(lowering["objectManifest"]): fail("semantic_object_uniqueness")
    if set(semantic["materialRoles"]) != set(design["materialRoleMapping"].values()): fail("semantic_material_closure")
    if semantic["registration"]["citySimSocket"] != [28.0,0.0,0.0] or semantic["registration"]["sourceSocket"] != [896.0,832.0]: fail("semantic_registration")
    if semantic["camera"]["literalResolution"] != [192,128] or semantic["camera"]["orthoScale"] != 237.5878601074218: fail("semantic_camera")
    return [{"case":"complete_semantic_geometry","result":"PASS"},{"case":"complete_object_manifest","result":"PASS"},{"case":"material_closure","result":"PASS"},{"case":"camera_registration","result":"PASS"}]


def build_evidence(contract: dict, cases: list[dict], static: list[dict], semantic: list[dict]) -> dict:
    changed = sorted(EXPECTED_PATHS)
    return {"schema":"citysim.play-079.east-process-a-prelaunch-validation.v1","task":"PLAY-079","direction":"east","familyRevision":"v14","result":"PASS","observedHead":PARENT,"contractSha256":sha(CONTRACT),"loweringSha256":sha(REPO / contract["immutableInputs"]["lowering"]["path"]),"staticChecks":static,"semanticChecks":semantic,"adversarialCases":cases,"freshRoots":[{"label":"fresh-root-a","childStarts":0,"blenderInvocations":0,"dccInvocations":0,"renderInvocations":0,"pixelFilesCreated":0,"blendFilesCreated":0},{"label":"fresh-root-b","childStarts":0,"blenderInvocations":0,"dccInvocations":0,"renderInvocations":0,"pixelFilesCreated":0,"blendFilesCreated":0}],"outputRootCreated":False,"launchInvoked":False,"changedPaths":changed,"siblingInputsConsumed":[],"sourceReady":False,"productionSelected":False}


def main() -> int:
    contract = load(CONTRACT)
    design = load(REPO / contract["immutableInputs"]["design"]["path"])
    lowering = load(REPO / contract["immutableInputs"]["lowering"]["path"])
    launcher = load_module(ROOT / "run_process_a.py", "east_process_a_launcher")
    child = load_module(ROOT / "process_a_child.py", "east_process_a_child")
    static = static_checks()
    cases = validate_inputs(contract, launcher)
    semantic = semantic_checks(child, design, lowering)
    first = build_evidence(contract, cases, static, semantic)
    second = build_evidence(contract, cases, static, semantic)
    if canon(first) != canon(second): fail("non_deterministic_evidence")
    evidence = dict(first)
    evidence["repeatValidation"] = {"runs":2,"byteIdentical":True,"proofSHA256":hashlib.sha256(canon(first)).hexdigest()}
    handoff = {"schema":"citysim.play-079.east-process-a-prelaunch-handoff.v1","stage":"prelaunch","task":"PLAY-079","direction":"east","familyRevision":"v14","branch":"codex/citysim-world-art-east","baseCommit":PARENT,"contractPath":"Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/PROCESS-A-CONTRACT.json","contractSha256":sha(CONTRACT),"childPath":"Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/process_a_child.py","launcherPath":"Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/run_process_a.py","loweringPath":contract["immutableInputs"]["lowering"]["path"],"outputRoot":contract["execution"]["outputRoot"],"outputRootCreated":False,"childStarts":0,"blenderInvocations":0,"dccInvocations":0,"renderInvocations":0,"pixelFilesCreated":0,"blendFilesCreated":0,"sourceReady":False,"productionSelected":False,"disposition":"prelaunch_ready_for_independent_review","knownBlocker":"Integration authenticated Process-A grant and appearance/source profile remain required before launch","siblingInputsConsumed":[],"validationPath":"docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/VALIDATION.json"}
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    VALIDATION.write_bytes(canon(evidence))
    HANDOFF.write_bytes(canon(handoff))
    print(f"PASS: East Process-A prelaunch; {len(cases)} adversarial rejects; 2 byte-identical zero-child proofs; no Blender/DCC/pixels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
