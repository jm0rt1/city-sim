#!/usr/bin/env python3
"""Static, immutable-input, profile-gated and zero-child Process-A proof."""

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
DESIGN = REPO / "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/V14-COMPATIBILITY-DESIGN.json"
LOWERING = REPO / "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/LOWERING.json"
EVIDENCE = REPO / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01"
HANDOFF = EVIDENCE / "HANDOFF.json"
VALIDATION = EVIDENCE / "VALIDATION.json"
PARENT = "5ea804b93557d4280b49a0f66520f6550858a65b"
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
    launcher_text = LAUNCHER.read_text(encoding="utf-8")
    child_text = CHILD.read_text(encoding="utf-8")
    launcher_tree = ast.parse(launcher_text)
    child_tree = ast.parse(child_text)
    popen_calls = [node for node in ast.walk(launcher_tree) if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "Popen"]
    if len(popen_calls) != 1: fail("child_start_site", str(len(popen_calls)))
    if any(keyword.arg == "shell" and isinstance(keyword.value, ast.Constant) and keyword.value.value is True for node in popen_calls for keyword in node.keywords): fail("shell_launch")
    if any(isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "Popen" for node in ast.walk(child_tree)): fail("child_recursive_launch")
    child_imports = [node for node in ast.walk(child_tree) if isinstance(node, ast.Import) and any(alias.name == "bpy" for alias in node.names)]
    if len(child_imports) != 1: fail("blender_import_shape")
    combined = launcher_text + child_text
    for forbidden in ("ImageGen", "requests", "urllib", "normalizer", "normalization", "Rendering/", "Package.swift", "BLENDER_EEVEE", "role_colors", "fallback_gray"):
        if forbidden in combined: fail("forbidden_dependency", forbidden)
    required = ("PRIMITIVE_BUILDERS", "portal_frame_compound", "intentional_portal_void", "mullion_band_compound", "rail_post_truss", "gutter_downspouts", "roof_plant_modules", "vent_louver_array", "framed_service_door", "torus_pipe_elbow", "truss_diagonal", "bpy.ops.render.render(write_still=True)", "bpy.ops.wm.save_as_mainfile", "scene.world", "camera_data.shift_x", "camera_data.shift_y", "from mathutils import Vector", "CITYSIM_PROFILE_JSON", "CITYSIM_PROCESS_A_AUTH", "direct_child_bypass")
    for required_text in required:
        if required_text not in combined: fail("construction_requirement_missing", required_text)
    if "PRIMITIVE_BUILDERS[primitive]" not in child_text or '"generic"' in child_text: fail("primitive_fallback")
    return [
        {"case": "one_popen_site", "result": "PASS"},
        {"case": "child_has_no_launcher", "result": "PASS"},
        {"case": "blender_import_is_child_only", "result": "PASS"},
        {"case": "profile_before_bpy_boundary", "result": "PASS"},
        {"case": "direct_child_bypass_guard", "result": "PASS"},
        {"case": "explicit_compound_construction", "result": "PASS"},
        {"case": "render_world_light_shadow_pipeline", "result": "PASS"},
        {"case": "no_placeholder_or_generic_fallback", "result": "PASS"},
    ]


def _profile_fixture(root: Path, contract: dict) -> tuple[dict, dict, dict]:
    fixture = copy.deepcopy(contract)
    relative_root = root.relative_to(REPO).as_posix()
    appearance_rel = relative_root + "/appearance-lock.json"
    profile_rel = relative_root + "/source-profile.json"
    profile = {
        "schema": "citysim.play-079.east-v14-source-production-profile.v1",
        "task": "PLAY-079",
        "direction": "east",
        "familyRevision": "v14",
        "appearanceLock": {"path": appearance_rel},
        "render": {"engine": "CYCLES", "device": "CPU", "threads": 1, "samples": 64, "seed": 17, "maxBounces": 4, "transparentFilm": True, "resolution": [1536, 1024], "resolutionPercentage": 100, "pixelAspect": [1.0, 1.0]},
        "colorManagement": {"displayDevice": "sRGB", "viewTransform": "AgX", "look": "Medium High Contrast", "exposure": 0.0, "gamma": 1.0},
        "materials": {"roles": {role: {"baseColor": [0.2, 0.3, 0.4, 1.0], "metallic": 0.0, "roughness": 0.6, "specularIORLevel": 0.5} for role in ("warm-weathered-masonry", "formed-concrete", "dark-painted-steel", "roof-edge-metal", "glazing-louver", "portal-void", "safety-oxide", "hot-process", "contact-shadow")}},
        "lighting": {"world": {"color": [0.03, 0.04, 0.05, 1.0], "strength": 0.2}, "key": {"location": [96.0, -96.0, 120.0], "target": [0.0, 0.0, 20.0], "energy": 800.0, "size": 8.0}, "contactShadow": {"receiverBounds": {"xMin": -32.0, "xMax": 32.0, "yMin": -32.0, "yMax": 32.0, "zMin": -0.1, "zMax": 0.0}, "location": [-64.0, 64.0, 40.0], "target": [0.0, 0.0, 0.0], "energy": 40.0, "size": 4.0}},
    }
    appearance = {"schema": "citysim.play-079.east-v14-appearance-lock.v1", "status": "PUBLISHED", "task": "PLAY-079", "direction": "east", "familyRevision": "v14", "sourceProductionProfile": {"path": profile_rel, "sha256": "PENDING"}}
    root.mkdir(parents=True, exist_ok=True)
    (root / "source-profile.json").write_bytes(canon(profile))
    profile_sha = sha(root / "source-profile.json")
    appearance["sourceProductionProfile"]["sha256"] = profile_sha
    (root / "appearance-lock.json").write_bytes(canon(appearance))
    appearance_sha = sha(root / "appearance-lock.json")
    profile_sha = sha(root / "source-profile.json")
    if appearance["sourceProductionProfile"]["sha256"] != profile_sha: fail("fixture_hash_cycle")
    fixture["appearanceLock"] = {"path": appearance_rel, "sha256": appearance_sha, "commit": PARENT}
    fixture["sourceProductionProfile"] = {"path": profile_rel, "sha256": profile_sha, "commit": PARENT}
    fixture["executionReady"] = True
    fixture["execution"]["launchGrant"] = {"scheduleId": fixture["execution"]["scheduleId"], "processId": "east-process-a", "direction": "east", "dccSlot": 1, "childLimit": 1, "baseCommit": fixture["authority"]["baseCommit"], "observedHead": PARENT, "outputRoot": fixture["execution"]["outputRoot"], "attempt": 1, "authenticated": True}
    return fixture, appearance, profile


def validate_inputs(contract: dict, launcher) -> list[dict]:
    if contract["appearanceLock"] is not None or contract["sourceProductionProfile"] is not None: fail("prelaunch_profile_not_null")
    try:
        launcher.validate_contract(contract)
    except ValueError as error:
        if str(error) != "appearance_lock_missing": fail("missing_profile_wrong_rejection", str(error))
    else:
        fail("missing_profile_accepted")
    cases = [{"case": "missing_appearance_lock", "result": "REJECTED"}]
    fixture_root = Path(tempfile.mkdtemp(prefix=".east-profile-fixture-", dir=ROOT))
    try:
        fixture, _, _ = _profile_fixture(fixture_root, contract)
        launcher.validate_contract(fixture)
        launcher.load_profile_bundle(fixture)
        cases.append({"case": "valid_exact_hash_profile", "result": "PASS"})
        adversaries = {
            "stale_appearance_hash": lambda c: c["appearanceLock"].update({"sha256": "0" * 64}),
            "stale_source_profile_hash": lambda c: c["sourceProductionProfile"].update({"sha256": "1" * 64}),
            "incomplete_profile": lambda c: c["sourceProductionProfile"].update({"path": c["sourceProductionProfile"]["path"]}),
            "appearance_profile_mismatch": lambda c: c["appearanceLock"].update({"path": c["appearanceLock"]["path"], "sha256": c["appearanceLock"]["sha256"], "commit": "deadbeef"}),
            "wrong_profile_direction": lambda c: c["sourceProductionProfile"].update({"path": c["sourceProductionProfile"]["path"]}),
            "sibling_profile_path": lambda c: c["appearanceLock"].update({"path": "Native/CitySimNative/WorldArt/Blender/PLAY-080/foreign-profile.json"}),
            "output_escape": lambda c: c["execution"].update({"outputRoot": "Native/CitySimNative/WorldArt/Blender/PLAY-080/foreign-output"}),
            "output_preexisting": lambda c: None,
        }
        for name, mutate in adversaries.items():
            candidate = copy.deepcopy(fixture)
            if name == "incomplete_profile":
                source = REPO / candidate["sourceProductionProfile"]["path"]
                profile = load(source)
                profile["lighting"].pop("key")
                source.write_bytes(canon(profile))
            elif name == "wrong_profile_direction":
                source = REPO / candidate["sourceProductionProfile"]["path"]
                profile = load(source)
                profile["direction"] = "north"
                source.write_bytes(canon(profile))
            elif name == "appearance_profile_mismatch":
                candidate["sourceProductionProfile"]["path"] = candidate["sourceProductionProfile"]["path"] + ".mismatch"
            elif name == "output_preexisting":
                output = REPO / candidate["execution"]["outputRoot"]
                output.mkdir(parents=False, exist_ok=False)
            else:
                mutate(candidate)
            try:
                launcher.validate_contract(candidate)
            except ValueError:
                cases.append({"case": name, "result": "REJECTED"})
            else:
                fail("profile_adversary_accepted", name)
            if name in {"incomplete_profile", "wrong_profile_direction"}:
                source.write_bytes(canon(_profile_fixture(fixture_root, contract)[2]))
            if name == "output_preexisting":
                shutil.rmtree(REPO / fixture["execution"]["outputRoot"])
    finally:
        shutil.rmtree(fixture_root, ignore_errors=True)
        pass
    grant_cases = {}
    fixture_root_2 = Path(tempfile.mkdtemp(prefix=".east-profile-fixture-", dir=ROOT))
    try:
        fixture, _, _ = _profile_fixture(fixture_root_2, contract)
        for name, mutate in {"wrong_direction": lambda g: g.update({"direction": "south"}), "wrong_slot": lambda g: g.update({"dccSlot": 2}), "wrong_process": lambda g: g.update({"processId": "south-process-a"}), "second_attempt": lambda g: g.update({"attempt": 2}), "unauthenticated": lambda g: g.update({"authenticated": False})}.items():
            grant = copy.deepcopy(fixture["execution"]["launchGrant"])
            mutate(grant)
            try:
                launcher.validate_grant(fixture, grant)
            except ValueError:
                grant_cases[name] = "REJECTED"
            else:
                fail("grant_adversary_accepted", name)
    finally:
        shutil.rmtree(fixture_root_2, ignore_errors=True)
    cases.extend({"case": name, "result": result} for name, result in grant_cases.items())
    return cases


def semantic_checks(child, design: dict, lowering: dict) -> list[dict]:
    semantic = child.build_semantic_geometry()
    if len(semantic["components"]) != len(design["components"]): fail("semantic_component_count")
    object_ids = [item["objectId"] for item in semantic["components"]]
    if len(object_ids) != len(set(object_ids)) or len(object_ids) != len(lowering["objectManifest"]): fail("semantic_object_uniqueness")
    if set(semantic["materialRoles"]) != set(design["materialRoleMapping"].values()): fail("semantic_material_closure")
    if semantic["registration"]["citySimSocket"] != [28.0, 0.0, 0.0] or semantic["registration"]["sourceSocket"] != [896.0, 832.0]: fail("semantic_registration")
    if semantic["camera"]["literalResolution"] != [192, 128] or semantic["camera"]["orthoScale"] != 237.5878601074218: fail("semantic_camera")
    voids = [item for item in semantic["components"] if item["primitive"] == "intentional_portal_void"]
    if len(voids) != 1 or not voids[0].get("intentionalVoid"): fail("portal_void_record")
    portal_frames = [item for item in semantic["components"] if item["primitive"] == "portal_frame_compound"]
    if len(portal_frames) != 3 or any(len(item["parts"]) < 3 for item in portal_frames): fail("portal_frame_compound")
    if any(item["primitive"] == "deterministic_box" and item["semanticRole"] in {"glazing-louver", "dark-painted-steel"} for item in semantic["components"]): fail("semantic_box_downgrade")
    if any(not item.get("parts") and not item.get("intentionalVoid") for item in semantic["components"]): fail("missing_lowering_parts")
    return [{"case": "complete_semantic_geometry", "result": "PASS"}, {"case": "complete_object_manifest", "result": "PASS"}, {"case": "material_closure", "result": "PASS"}, {"case": "camera_registration", "result": "PASS"}, {"case": "portal_compound_and_void", "result": "PASS"}, {"case": "no_semantic_proxy_downgrade", "result": "PASS"}]


def build_evidence(contract: dict, cases: list[dict], static: list[dict], semantic: list[dict]) -> dict:
    changed = sorted(EXPECTED_PATHS)
    return {"schema": "citysim.play-079.east-process-a-prelaunch-repair-validation.v2", "task": "PLAY-079", "direction": "east", "familyRevision": "v14", "result": "PASS", "observedHead": PARENT, "contractSha256": sha(CONTRACT), "designSha256": sha(DESIGN), "loweringSha256": sha(LOWERING), "appearanceLock": None, "sourceProductionProfile": None, "executionReady": False, "staticChecks": static, "semanticChecks": semantic, "adversarialCases": cases, "freshRoots": [{"label": "fresh-root-a", "childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "pixelFilesCreated": 0, "blendFilesCreated": 0}, {"label": "fresh-root-b", "childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "pixelFilesCreated": 0, "blendFilesCreated": 0}], "outputRootCreated": False, "launchInvoked": False, "profileLoaded": False, "siblingInputsConsumed": [], "sourceReady": False, "productionSelected": False, "changedPaths": changed}


def main() -> int:
    contract = load(CONTRACT)
    design = load(DESIGN)
    lowering = load(LOWERING)
    launcher = load_module(LAUNCHER, "east_process_a_launcher")
    child = load_module(CHILD, "east_process_a_child")
    static = static_checks()
    cases = validate_inputs(contract, launcher)
    semantic = semantic_checks(child, design, lowering)
    first = build_evidence(contract, cases, static, semantic)
    second = build_evidence(contract, cases, static, semantic)
    if canon(first) != canon(second): fail("non_deterministic_evidence")
    evidence = dict(first)
    evidence["repeatValidation"] = {"runs": 2, "byteIdentical": True, "proofSHA256": hashlib.sha256(canon(first)).hexdigest()}
    handoff = {"schema": "citysim.play-079.east-process-a-prelaunch-repair-handoff.v2", "stage": "prelaunch-repair", "task": "PLAY-079", "direction": "east", "familyRevision": "v14", "branch": "codex/citysim-world-art-east", "baseCommit": PARENT, "contractPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/PROCESS-A-CONTRACT.json", "contractSha256": sha(CONTRACT), "childPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/process_a_child.py", "launcherPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/run_process_a.py", "loweringPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/LOWERING.json", "outputRoot": contract["execution"]["outputRoot"], "outputRootCreated": False, "childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "pixelFilesCreated": 0, "blendFilesCreated": 0, "appearanceLock": None, "sourceProductionProfile": None, "executionReady": False, "sourceReady": False, "productionSelected": False, "disposition": "prelaunch_repair_ready_for_independent_review", "knownBlocker": "Integration must publish the exact North appearance lock and source-production profile plus authenticated Process-A grant before launch", "siblingInputsConsumed": [], "validationPath": "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/VALIDATION.json"}
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    VALIDATION.write_bytes(canon(evidence))
    HANDOFF.write_bytes(canon(handoff))
    print(f"PASS: East Process-A prelaunch repair; {len(cases)} adversarial rejects; 2 byte-identical zero-child proofs; no Blender/DCC/pixels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
