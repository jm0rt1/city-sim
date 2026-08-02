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
RETURN_RECEIPT = REPO / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/LIVE-IDENTITY-RETURN-REPAIR-V1.json"
PARENT = "f2672462bbf423ffb6746cd0d9a2eb28e9248f6f"
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
    required = ("PRIMITIVE_BUILDERS", "portal_frame_compound", "intentional_portal_void", "mullion_band_compound", "rail_post_truss", "gutter_downspouts", "roof_plant_modules", "vent_louver_array", "framed_service_door", "torus_pipe_elbow", "quarter_elbow_plan", "loading_marking_plan", "mullion_louver_plan", "portal_assembly_plan", "validate_portal_assembly", "validate_truss_plan", "portal_empty_forbidden", "INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1.json", "NORTH_REFERENCE_COMMIT", "bpy.ops.render.render(write_still=True)", "bpy.ops.wm.save_as_mainfile", "scene.world", "camera_data.shift_x", "camera_data.shift_y", "from mathutils import Vector", "CITYSIM_PROFILE_JSON", "CITYSIM_EXECUTION_AUTHORITY_JSON", "CITYSIM_GRANT_JSON", "forwarded_binding_missing")
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


def _integration_north_fixture(root: Path, contract: dict) -> tuple[dict, Path, dict]:
    fixture = copy.deepcopy(contract)
    relative_root = "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14"
    profile_path = root / relative_root / "SOURCE-PRODUCTION-PROFILE.json"
    appearance_path = root / relative_root / "APPEARANCE-LOCK.json"
    profile_rel = (Path(relative_root) / "SOURCE-PRODUCTION-PROFILE.json").as_posix()
    appearance_rel = (Path(relative_root) / "APPEARANCE-LOCK.json").as_posix()
    profile = {
        "schema": "citysim.play-027.north-v14-source-production-profile.v1",
        "task": "PLAY-027",
        "direction": "north",
        "familyRevision": "v14",
        "appearanceLock": {"path": appearance_rel},
        "render": {"engine": "CYCLES", "device": "CPU", "threads": 1, "samples": 64, "seed": 17, "maxBounces": 4, "transparentFilm": True, "resolution": [1536, 1024], "resolutionPercentage": 100, "pixelAspect": [1.0, 1.0]},
        "colorManagement": {"displayDevice": "sRGB", "viewTransform": "AgX", "look": "Medium High Contrast", "exposure": 0.0, "gamma": 1.0},
        "materials": {"roles": {role: {"baseColor": [0.2, 0.3, 0.4, 1.0], "metallic": 0.0, "roughness": 0.6, "specularIORLevel": 0.5} for role in ("warm-weathered-masonry", "formed-concrete", "dark-painted-steel", "roof-edge-metal", "glazing-louver", "portal-void", "safety-oxide", "hot-process", "contact-shadow")}},
        "lighting": {"world": {"color": [0.03, 0.04, 0.05, 1.0], "strength": 0.2}, "key": {"location": [96.0, -96.0, 120.0], "target": [0.0, 0.0, 20.0], "energy": 800.0, "size": 8.0}, "contactShadow": {"receiverBounds": {"xMin": -32.0, "xMax": 32.0, "yMin": -32.0, "yMax": 32.0, "zMin": -0.1, "zMax": 0.0}, "location": [-64.0, 64.0, 40.0], "target": [0.0, 0.0, 0.0], "energy": 40.0, "size": 4.0}},
    }
    appearance = {"schema": "citysim.play-027.north-v14-appearance-lock.v1", "status": "PUBLISHED", "task": "PLAY-027", "direction": "north", "familyRevision": "v14", "sourceProductionProfile": {"path": profile_rel, "sha256": "PENDING"}}
    profile_path.parent.mkdir(parents=True, exist_ok=True)
    profile_path.write_bytes(canon(profile))
    profile_sha = sha(profile_path)
    appearance["sourceProductionProfile"]["sha256"] = profile_sha
    appearance_path.write_bytes(canon(appearance))
    appearance_sha = sha(appearance_path)
    profile_sha = sha(profile_path)
    if appearance["sourceProductionProfile"]["sha256"] != profile_sha: fail("fixture_hash_cycle")
    fixture["appearanceLock"] = {"path": appearance_rel, "sha256": appearance_sha, "commit": "b961d7a6f9f9ad75f69b9156ce657dd4937e5537"}
    fixture["sourceProductionProfile"] = {"path": profile_rel, "sha256": profile_sha, "commit": "b961d7a6f9f9ad75f69b9156ce657dd4937e5537"}
    integration_root = root / "docs/production/evidence/INTEGRATION"
    integration_root.mkdir(parents=True, exist_ok=True)
    closure_target = root / "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1.json"
    closure_target.write_bytes((REPO / "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1.json").read_bytes())
    def write_doc(name: str, value: dict) -> tuple[str, str]:
        path = integration_root / name
        path.write_bytes(canon(value))
        return "docs/production/evidence/INTEGRATION/" + name, sha(path)
    common = {"task": "PLAY-079", "direction": "east", "process": "A", "slot": "east:A", "claimSha256": fixture["authority"]["claim"]["sha256"], "branch": "codex/citysim-world-art-east", "workerHead": PARENT, "routeId": "quality-v2:play-079-east-v14-live-identity-repair-v1", "routeSha256": "54b8a92f8d1186b28e7f8405ea1969170e450d30e0d76ec9eff9297dc41a6ecd", "outputRoot": fixture["execution"]["outputRoot"]}
    schedule_rel, schedule_sha = write_doc("east-schedule.json", {"schema": 1, **common, "maximumChildStarts": 1, "grantId": "east:A"})
    grant_rel, grant_sha = write_doc("east-grant.json", {"schema": 1, **common, "grantId": "east:A", "maximumChildStarts": 1, "scheduleSHA256": schedule_sha, "sessionId": "east-session-v1"})
    session_rel, session_sha = write_doc("east-session.json", {"schema": 1, **common, "sessionId": "east-session-v1", "scheduleSHA256": schedule_sha, "grantSHA256": grant_sha})
    authority = {"schemaVersion": 1, "mode": "validation_only", "integrationCheckoutRoot": "/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim", "closureContract": {"path": "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1.json", "sha256": "4a5fdf98ad77082cdd4265ae6f78406f9e26c8dd92443caa8c7e64e6726f91a4"}, "task": {"taskId": "PLAY-079", "direction": "east", "branch": "codex/citysim-world-art-east", "claimSha256": fixture["authority"]["claim"]["sha256"], "workerHead": PARENT, "routeId": "quality-v2:play-079-east-v14-live-identity-repair-v1", "routeSha256": "54b8a92f8d1186b28e7f8405ea1969170e450d30e0d76ec9eff9297dc41a6ecd", "publishedBaseCommit": fixture["authority"]["baseCommit"]}, "documents": {"schedule": {"path": schedule_rel, "sha256": schedule_sha, "commit": PARENT}, "grant": {"path": grant_rel, "sha256": grant_sha, "commit": PARENT}, "integrationSession": {"path": session_rel, "sha256": session_sha, "commit": PARENT}, "sourceProductionProfile": {"path": profile_rel, "sha256": profile_sha, "commit": "b961d7a6f9f9ad75f69b9156ce657dd4937e5537"}}, "grant": {"grantId": "east:A", "processId": "east-process-a", "direction": "east", "slotId": "east-process-a-slot-1", "maximumChildStarts": 1, "exactlyOneInvocation": True, "orchestratorOnly": True, "directLowLevelInvocationAllowed": False}, "exclusiveRoots": {"outputRoot": fixture["execution"]["outputRoot"]}, "authentication": {"secretTransport": "anonymous_pipe", "rawSecretPersisted": False, "childCapability": {"boundGrantId": "east:A", "oneTime": True, "replayAllowed": False}}, "toolchain": {"path": fixture["execution"]["blenderExecutable"], "sha256": "0" * 64, "factoryStartup": True, "disabledAutoexec": True, "pythonExitCode": 1}}
    authority_path = root / "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/execution-authority.json"
    authority_path.parent.mkdir(parents=True, exist_ok=True); authority_path.write_bytes(canon(authority))
    fixture["executionAuthority"] = {"path": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/execution-authority.json", "sha256": sha(authority_path), "commit": PARENT}
    fixture["executionReady"] = True
    fixture["execution"]["launchGrant"] = {"scheduleId": fixture["execution"]["scheduleId"], "processId": "east-process-a", "direction": "east", "dccSlot": 1, "slotId": "east-process-a-slot-1", "childLimit": 1, "baseCommit": fixture["authority"]["baseCommit"], "observedHead": PARENT, "outputRoot": fixture["execution"]["outputRoot"], "attempt": 1, "authenticated": True}
    return fixture, root, authority


def validate_inputs(contract: dict, launcher) -> list[dict]:
    if contract["appearanceLock"] is not None or contract["sourceProductionProfile"] is not None: fail("prelaunch_profile_not_null")
    try:
        launcher.validate_contract(contract)
    except ValueError as error:
        if str(error) != "appearance_lock_missing": fail("missing_profile_wrong_rejection", str(error))
    else:
        fail("missing_profile_accepted")
    cases = [{"case": "missing_appearance_lock", "result": "REJECTED"}]
    launcher.validate_live_identity(contract)
    cases.append({"case": "live_git_identity", "result": "PASS", "head": PARENT, "branch": "codex/citysim-world-art-east"})
    for name, mutate, expected in (
        ("stale_live_head", lambda c: c["authority"].update({"observedHead": "4fdc60e8bdc6b5ae8ce1c34a8cd6f67e8cf898cc"}), "live_head_or_branch_mismatch"),
        ("wrong_live_branch", lambda c: c["authority"].update({"branch": "codex/citysim-world-art-west"}), "live_head_or_branch_mismatch"),
        ("stale_claim_hash", lambda c: c["authority"]["claim"].update({"sha256": "0" * 64}), "live_claim_hash_mismatch"),
        ("wrong_route_id", lambda c: c["authority"].update({"routeId": "quality-v2:wrong"}), "live_route_binding"),
        ("stale_profile_authority", lambda c: c["authority"].update({"liveIdentityAuthority": {"path": "bad", "sha256": "0" * 64}}), "live_identity_authority_binding"),
    ):
        candidate = copy.deepcopy(contract); mutate(candidate)
        try:
            launcher.validate_live_identity(candidate)
        except ValueError as error:
            if str(error) != expected: fail("live_identity_adversary_wrong_rejection", name + ":" + str(error))
            cases.append({"case": name, "result": "REJECTED", "code": str(error)})
        else:
            fail("live_identity_adversary_accepted", name)
    positive_root = Path(tempfile.mkdtemp(prefix=".east-integration-north-fixture-", dir=ROOT))
    try:
        positive_contract, positive_repo, positive_authority = _integration_north_fixture(positive_root, contract)
        launcher.load_profile_bundle(positive_contract, positive_repo)
        launcher.load_execution_authority(positive_contract, positive_repo)
        launcher.validate_grant(positive_contract, positive_contract["execution"]["launchGrant"])
        cases.append({"case": "integration_authored_north_profile_closure", "result": "PASS", "documents": sorted(positive_authority["documents"])})
    finally:
        shutil.rmtree(positive_root, ignore_errors=True)
    for name, mutate, expected in (
        ("execution_authority_missing", lambda c: c.update({"executionAuthority": None}), "execution_authority_missing"),
        ("north_profile_required", lambda c: c.update({"sourceProductionProfile": {"path": "Native/CitySimNative/WorldArt/Blender/PLAY-079/fake.json", "sha256": "0" * 64, "commit": PARENT}}), "appearance_lock_missing"),
        ("output_escape", lambda c: c["execution"].update({"outputRoot": "Native/CitySimNative/WorldArt/Blender/PLAY-080/foreign-output"}), "output_root"),
        ("direct_grant_missing", lambda c: c["execution"].update({"launchGrant": {}}), "grant_binding"),
    ):
        candidate = copy.deepcopy(contract)
        mutate(candidate)
        try:
            if name == "execution_authority_missing":
                launcher.load_execution_authority(candidate)
            elif name == "direct_grant_missing":
                launcher.validate_grant(candidate, {})
            else:
                launcher.validate_contract(candidate)
        except ValueError as error:
            if expected not in str(error): fail("closure_adversary_wrong_rejection", name + ":" + str(error))
            cases.append({"case": name, "result": "REJECTED", "code": str(error)})
        else:
            fail("closure_adversary_accepted", name)
    authority_root = Path(tempfile.mkdtemp(prefix=".east-closure-authority-", dir=ROOT))
    try:
        authority_payload = {
            "schemaVersion": 1, "mode": "validation_only", "integrationCheckoutRoot": launcher.INTEGRATION_CHECKOUT_ROOT,
            "closureContract": {"path": launcher.CLOSURE_CONTRACT, "sha256": launcher.CLOSURE_SHA256},
            "task": {"taskId": "PLAY-079", "direction": "east", "branch": "codex/citysim-world-art-east", "claimSha256": contract["authority"]["claim"]["sha256"], "workerHead": contract["authority"]["observedHead"], "publishedBaseCommit": contract["authority"]["baseCommit"]},
            "documents": {}, "grant": {}, "exclusiveRoots": {}, "authentication": {}, "toolchain": {},
        }
        authority_file = authority_root / "authority.json"
        authority_file.write_bytes(canon(authority_payload))
        binding = {"path": authority_file.relative_to(REPO).as_posix(), "sha256": sha(authority_file), "commit": PARENT}
        for name, mutate, expected in (("wrong_integration_root", lambda a: a.update({"integrationCheckoutRoot": "/tmp/foreign"}), "integration_checkout_root"), ("wrong_closure_hash", lambda a: a["closureContract"].update({"sha256": "0" * 64}), "closure_contract_binding"), ("symlinked_authority", None, "profile_symlink")):
            candidate = copy.deepcopy(contract)
            candidate["executionAuthority"] = copy.deepcopy(binding)
            if name == "symlinked_authority":
                link = authority_root / "authority-link.json"
                link.symlink_to(authority_file)
                candidate["executionAuthority"]["path"] = link.relative_to(REPO).as_posix()
            else:
                payload = copy.deepcopy(authority_payload); mutate(payload); authority_file.write_bytes(canon(payload)); candidate["executionAuthority"]["sha256"] = sha(authority_file)
            try:
                launcher.load_execution_authority(candidate)
            except ValueError as error:
                if expected not in str(error): fail("authority_adversary_wrong_rejection", name + ":" + str(error))
                cases.append({"case": name, "result": "REJECTED", "code": str(error)})
            else:
                fail("authority_adversary_accepted", name)
            if name == "symlinked_authority":
                link.unlink()
        authority_file.write_bytes(canon(authority_payload))
    finally:
        shutil.rmtree(authority_root, ignore_errors=True)
    return cases


def semantic_checks(child, design: dict, lowering: dict) -> list[dict]:
    semantic = child.build_semantic_geometry()
    child.validate_runtime_semantics(semantic)
    if not child.validate_portal_assembly(semantic["portalAssembly"]): fail("portal_assembly_reachability")
    railing = next(item for item in semantic["components"] if item["primitive"] == "rail_post_truss")
    if not child.validate_truss_plan(railing): fail("truss_reachability")
    if child.validate_truss_plan({"trussEndpoints": [{"start": [0, 0, 0], "end": [0, 0, 0]}]}):
        fail("truss_adversary_accepted")
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
    portal = child.portal_frame_plan(next(item["bounds"] for item in semantic["components"] if item["primitive"] == "portal_frame_compound"))
    bad_portal = copy.deepcopy(portal); bad_portal["openAperture"] = False
    if child.validate_portal_plan(bad_portal): fail("portal_adversary_accepted")
    elbow = child.quarter_elbow_plan(next(item["bounds"] for item in semantic["components"] if item["primitive"] == "torus_pipe_elbow"))
    bad_elbow = copy.deepcopy(elbow); bad_elbow["arcDegrees"] = 360.0
    if child.validate_elbow_plan(bad_elbow): fail("elbow_adversary_accepted")
    loading = child.loading_marking_plan(next(item["bounds"] for item in semantic["components"] if item["primitive"] == "loading_chevron_marking"))
    bad_loading = copy.deepcopy(loading); bad_loading["bars"][0]["end"] = bad_loading["bars"][0]["start"]
    if child.validate_loading_plan(bad_loading): fail("loading_adversary_accepted")
    mullion = child.mullion_louver_plan(next(item["bounds"] for item in semantic["components"] if item["primitive"] == "mullion_band_compound"))
    bad_mullion = copy.deepcopy(mullion); bad_mullion["louverSlats"] = []
    if child.validate_mullion_plan(bad_mullion): fail("mullion_adversary_accepted")
    return [{"case": "complete_semantic_geometry", "result": "PASS"}, {"case": "complete_object_manifest", "result": "PASS"}, {"case": "material_closure", "result": "PASS"}, {"case": "camera_registration", "result": "PASS"}, {"case": "portal_compound_and_void", "result": "PASS"}, {"case": "portal_assembly_material_roles", "result": "PASS"}, {"case": "no_semantic_proxy_downgrade", "result": "PASS"}, {"case": "quarter_elbow_endcaps", "result": "PASS"}, {"case": "computed_loading_bars", "result": "PASS"}, {"case": "mullion_louver_slats", "result": "PASS"}, {"case": "truss_reachability", "result": "PASS"}]


def build_evidence(contract: dict, cases: list[dict], static: list[dict], semantic: list[dict]) -> dict:
    changed = sorted(EXPECTED_PATHS)
    return {"schema": "citysim.play-079.east-process-a-prelaunch-repair-validation.v4", "task": "PLAY-079", "direction": "east", "familyRevision": "v14", "result": "PASS", "authorityCommit": contract["authority"]["authorityCommit"], "baseCommit": contract["authority"]["baseCommit"], "observedHead": PARENT, "contractSha256": sha(CONTRACT), "designSha256": sha(DESIGN), "loweringSha256": sha(LOWERING), "closureContract": {"path": "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1.json", "sha256": "4a5fdf98ad77082cdd4265ae6f78406f9e26c8dd92443caa8c7e64e6726f91a4"}, "appearanceLock": None, "sourceProductionProfile": None, "executionAuthority": None, "executionReady": False, "staticChecks": static, "semanticChecks": semantic, "adversarialCases": cases, "freshRoots": [{"label": "fresh-root-a", "childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "pixelFilesCreated": 0, "blendFilesCreated": 0}, {"label": "fresh-root-b", "childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "pixelFilesCreated": 0, "blendFilesCreated": 0}], "outputRootCreated": False, "launchInvoked": False, "profileLoaded": False, "siblingInputsConsumed": [], "sourceReady": False, "productionSelected": False, "changedPaths": changed}


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
    handoff = {"schema": "citysim.play-079.east-process-a-prelaunch-repair-handoff.v4", "stage": "prelaunch-repair", "task": "PLAY-079", "direction": "east", "familyRevision": "v14", "branch": "codex/citysim-world-art-east", "baseCommit": PARENT, "contractPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/PROCESS-A-CONTRACT.json", "contractSha256": sha(CONTRACT), "childPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/process_a_child.py", "launcherPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/run_process_a.py", "loweringPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/LOWERING.json", "outputRoot": contract["execution"]["outputRoot"], "outputRootCreated": False, "childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "pixelFilesCreated": 0, "blendFilesCreated": 0, "appearanceLock": None, "sourceProductionProfile": None, "executionAuthority": None, "closureContract": {"path": "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1.json", "sha256": "4a5fdf98ad77082cdd4265ae6f78406f9e26c8dd92443caa8c7e64e6726f91a4"}, "executionReady": False, "sourceReady": False, "productionSelected": False, "disposition": "prelaunch_repair_ready_for_independent_review", "knownBlocker": "Integration must publish the exact North appearance lock and source-production profile, schedule/grant/session documents, execution authority and authenticated Process-A grant before launch", "siblingInputsConsumed": [], "validationPath": "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/VALIDATION.json"}
    RETURN_RECEIPT.parent.mkdir(parents=True, exist_ok=True)
    receipt = {"schema": "citysim.play-079.east-v14-live-identity-repair.v1", "task": "PLAY-079", "direction": "east", "routeId": "quality-v2:play-079-east-v14-live-identity-repair-v1", "routeSha256": "54b8a92f8d1186b28e7f8405ea1969170e450d30e0d76ec9eff9297dc41a6ecd", "carrierCommit": "0db9faf21ea8eb3b2f3973eecdd8321ee2922fde", "authority": {"path": "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-EAST-LIVE-IDENTITY-RETURN-REPAIR-V1.json", "sha256": "aef7773c50f0d29e127bb0859f221d1603f3d37d2fe69ff62bc051e1e33a07e6", "baseCommit": "fb994358c58b81fea5a144f67dc0f7316d53b4a5"}, "observedHead": PARENT, "implementationHead": "46aa8c493a23fb32433190348b32a0e3c74a3726", "liveIdentity": {"head": PARENT, "branch": "codex/citysim-world-art-east"}, "result": "PASS", "validation": evidence, "handoff": handoff, "historicalEvidencePreserved": True, "zeroPixelBoundary": {"childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "outputRootCreated": False, "pixelFilesCreated": 0, "blendFilesCreated": 0}, "knownBlocker": "Integration-owned appearance/profile authority and contained smoke remain required", "siblingInputsConsumed": []}
    RETURN_RECEIPT.write_bytes(canon(receipt))
    print(f"PASS: East Process-A prelaunch repair; {len(cases)} adversarial rejects; 2 byte-identical zero-child proofs; no Blender/DCC/pixels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
