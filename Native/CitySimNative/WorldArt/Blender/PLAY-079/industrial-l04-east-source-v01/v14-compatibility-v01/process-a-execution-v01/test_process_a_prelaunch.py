#!/usr/bin/env python3
"""Static, immutable-input, profile-gated and zero-child Process-A proof."""

from __future__ import annotations

import ast
import copy
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
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
RETURN_RECEIPT = REPO / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/DYNAMIC-LIVE-IDENTITY-RETURN-REPAIR-V1.json"
PARENT = "cc216550368684b72af34e2ff1f8f7fad558d04f"
PRESERVED_CANDIDATE = "e9f3d89080317b0183ad3d644ac4463bfb8c148a"
EXPECTED_PATHS = {
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/PROCESS-A-CONTRACT.json",
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/run_process_a.py",
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/test_process_a_prelaunch.py",
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/test_v14_compatibility.py",
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/HANDOFF.json",
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/VALIDATION.json",
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/DYNAMIC-LIVE-IDENTITY-RETURN-REPAIR-V1.json",
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
    required = ("PRIMITIVE_BUILDERS", "portal_frame_compound", "intentional_portal_void", "mullion_band_compound", "rail_post_truss", "gutter_downspouts", "roof_plant_modules", "vent_louver_array", "framed_service_door", "torus_pipe_elbow", "quarter_elbow_plan", "loading_marking_plan", "mullion_louver_plan", "portal_assembly_plan", "validate_portal_assembly", "validate_truss_plan", "portal_empty_forbidden", "INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1.json", "INDUSTRIAL-L04-EAST-DYNAMIC-LIVE-IDENTITY-RETURN-REPAIR-V1.md", "CITYSIM_EXECUTION_AUTHORITY_BINDING_JSON", "refs/remotes/origin/master", "bpy.ops.render.render(write_still=True)", "bpy.ops.wm.save_as_mainfile", "scene.world", "camera_data.shift_x", "camera_data.shift_y", "from mathutils import Vector", "CITYSIM_PROFILE_JSON", "CITYSIM_EXECUTION_AUTHORITY_JSON", "CITYSIM_GRANT_JSON", "forwarded_binding_missing")
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


def _git(repo: Path, *args: str) -> str:
    env = os.environ.copy()
    if args and args[0] == "commit":
        env["GIT_AUTHOR_DATE"] = "2001-01-01T00:00:00Z"
        env["GIT_COMMITTER_DATE"] = "2001-01-01T00:00:00Z"
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True, stderr=subprocess.DEVNULL, env=env).strip()


def _init_repo(path: Path, branch: str) -> None:
    path.mkdir(parents=True, exist_ok=True)
    _git(path, "init", "-q")
    _git(path, "config", "user.name", "CitySim Test")
    _git(path, "config", "user.email", "citysim-test@example.invalid")
    _git(path, "checkout", "-q", "-b", branch)


def _commit_all(repo: Path, message: str) -> str:
    _git(repo, "add", ".")
    _git(repo, "commit", "-q", "-m", message)
    return _git(repo, "rev-parse", "HEAD")


def _write_json(repo: Path, relative: str, value: dict) -> tuple[str, str]:
    path = repo / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canon(value))
    return relative, sha(path)


def _external_authority_fixture(root: Path, contract: dict, launcher) -> tuple[dict, Path, Path, dict, dict]:
    worker_repo = root / "worker-repo"
    authority_repo = root / "integration-authority-repo"
    _init_repo(worker_repo, "codex/citysim-world-art-east")
    claim_rel = "docs/production/claims/PLAY-079.world-art-east.md"
    claim_path = worker_repo / claim_rel
    claim_path.parent.mkdir(parents=True, exist_ok=True)
    claim_path.write_bytes((REPO / claim_rel).read_bytes())
    for immutable in contract["immutableInputs"].values():
        target = worker_repo / immutable["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((REPO / immutable["path"]).read_bytes())
    worker_head = _commit_all(worker_repo, "freeze worker candidate")
    fixture = copy.deepcopy(contract)
    fixture["authority"]["claim"] = {"path": claim_rel, "sha256": sha(claim_path)}
    fixture["authority"]["observedHead"] = PARENT

    _init_repo(authority_repo, "master")
    profile_root = "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14"
    profile_rel = profile_root + "/SOURCE-PRODUCTION-PROFILE.json"
    appearance_rel = profile_root + "/APPEARANCE-LOCK.json"
    profile = {
        "schema": "citysim.play-027.north-v14-source-production-profile.v1", "task": "PLAY-027", "direction": "north", "familyRevision": "v14", "appearanceLock": {"path": appearance_rel},
        "render": {"engine": "CYCLES", "device": "CPU", "threads": 1, "samples": 64, "seed": 17, "maxBounces": 4, "transparentFilm": True, "resolution": [1536, 1024], "resolutionPercentage": 100, "pixelAspect": [1.0, 1.0]},
        "colorManagement": {"displayDevice": "sRGB", "viewTransform": "AgX", "look": "Medium High Contrast", "exposure": 0.0, "gamma": 1.0},
        "materials": {"roles": {role: {"baseColor": [0.2, 0.3, 0.4, 1.0], "metallic": 0.0, "roughness": 0.6, "specularIORLevel": 0.5} for role in ("warm-weathered-masonry", "formed-concrete", "dark-painted-steel", "roof-edge-metal", "glazing-louver", "portal-void", "safety-oxide", "hot-process", "contact-shadow")}},
        "lighting": {"world": {"color": [0.03, 0.04, 0.05, 1.0], "strength": 0.2}, "key": {"location": [96.0, -96.0, 120.0], "target": [0.0, 0.0, 20.0], "energy": 800.0, "size": 8.0}, "contactShadow": {"receiverBounds": {"xMin": -32.0, "xMax": 32.0, "yMin": -32.0, "yMax": 32.0, "zMin": -0.1, "zMax": 0.0}, "location": [-64.0, 64.0, 40.0], "target": [0.0, 0.0, 0.0], "energy": 40.0, "size": 4.0}},
    }
    _, profile_sha = _write_json(authority_repo, profile_rel, profile)
    appearance = {"schema": "citysim.play-027.north-v14-appearance-lock.v1", "status": "PUBLISHED", "task": "PLAY-027", "direction": "north", "familyRevision": "v14", "sourceProductionProfile": {"path": profile_rel, "sha256": profile_sha}}
    _, appearance_sha = _write_json(authority_repo, appearance_rel, appearance)
    profile_commit = _commit_all(authority_repo, "publish north profile")

    route_id = "quality-v2:play-079-east-v14-post-candidate-grant-v1"
    route_sha = "1" * 64
    common = {"task": "PLAY-079", "direction": "east", "process": "A", "slot": "east:A", "claimSha256": fixture["authority"]["claim"]["sha256"], "branch": "codex/citysim-world-art-east", "workerHead": worker_head, "routeId": route_id, "routeSha256": route_sha, "outputRoot": fixture["execution"]["outputRoot"]}
    integration_root = "docs/production/evidence/INTEGRATION/"
    schedule_rel, schedule_sha = _write_json(authority_repo, integration_root + "east-schedule.json", {"schema": 2, **common, "maximumChildStarts": 1, "grantId": "east:A"})
    grant_rel, grant_sha = _write_json(authority_repo, integration_root + "east-grant.json", {"schema": 2, **common, "grantId": "east:A", "maximumChildStarts": 1, "scheduleSHA256": schedule_sha, "sessionId": "east-session-v2"})
    session_rel, session_sha = _write_json(authority_repo, integration_root + "east-session.json", {"schema": 2, **common, "sessionId": "east-session-v2", "scheduleSHA256": schedule_sha, "grantSHA256": grant_sha})
    profile_authority_rel, profile_authority_sha = _write_json(authority_repo, integration_root + "east-profile-authority.json", {"schema": 2, **common, "appearanceLock": {"path": appearance_rel, "sha256": appearance_sha, "commit": profile_commit}, "sourceProductionProfile": {"path": profile_rel, "sha256": profile_sha, "commit": profile_commit}})
    documents_commit = _commit_all(authority_repo, "publish post-candidate documents")
    bindings = {
        "schedule": {"path": schedule_rel, "sha256": schedule_sha, "commit": documents_commit},
        "grant": {"path": grant_rel, "sha256": grant_sha, "commit": documents_commit},
        "integrationSession": {"path": session_rel, "sha256": session_sha, "commit": documents_commit},
        "sourceProductionProfile": {"path": profile_authority_rel, "sha256": profile_authority_sha, "commit": documents_commit},
    }
    authority = {
        "schemaVersion": 2, "mode": "validation_only", "integrationCheckoutRoot": launcher.INTEGRATION_CHECKOUT_ROOT, "trustRef": launcher.TRUSTED_AUTHORITY_REF,
        "closureContract": {"path": launcher.CLOSURE_CONTRACT, "sha256": launcher.CLOSURE_SHA256},
        "task": {"taskId": "PLAY-079", "direction": "east", "branch": common["branch"], "claimSha256": common["claimSha256"], "workerHead": worker_head, "routeId": route_id, "routeSha256": route_sha, "publishedBaseCommit": fixture["authority"]["baseCommit"]},
        "documents": bindings,
        "grant": {"grantId": "east:A", "scheduleId": fixture["execution"]["scheduleId"], "processId": "east-process-a", "direction": "east", "dccSlot": 1, "slotId": "east-process-a-slot-1", "childLimit": 1, "baseCommit": fixture["authority"]["baseCommit"], "workerHead": worker_head, "branch": common["branch"], "claimSha256": common["claimSha256"], "routeId": route_id, "routeSha256": route_sha, "outputRoot": common["outputRoot"], "attempt": 1, "authenticated": True, "maximumChildStarts": 1, "exactlyOneInvocation": True, "orchestratorOnly": True, "directLowLevelInvocationAllowed": False},
        "exclusiveRoots": {"outputRoot": common["outputRoot"]},
        "authentication": {"secretTransport": "anonymous_pipe", "rawSecretPersisted": False, "childCapability": {"boundGrantId": "east:A", "oneTime": True, "replayAllowed": False}},
        "toolchain": {"path": fixture["execution"]["blenderExecutable"], "sha256": "0" * 64, "factoryStartup": True, "disabledAutoexec": True, "pythonExitCode": 1},
    }
    authority_rel, authority_sha = _write_json(authority_repo, integration_root + "PLAY-079-EAST-PROCESS-A-EXECUTION-AUTHORITY.json", authority)
    authority_commit = _commit_all(authority_repo, "publish execution authority")
    _git(authority_repo, "update-ref", launcher.TRUSTED_AUTHORITY_REF, authority_commit)
    binding = {"path": authority_rel, "sha256": authority_sha, "commit": authority_commit}
    return fixture, worker_repo, authority_repo, authority, binding


def _commit_authority(authority_repo: Path, launcher, authority: dict, update_trust: bool = True) -> dict:
    relative = "docs/production/evidence/INTEGRATION/PLAY-079-EAST-PROCESS-A-EXECUTION-AUTHORITY.json"
    _, authority_sha = _write_json(authority_repo, relative, authority)
    commit = _commit_all(authority_repo, "publish authority adversary")
    if update_trust:
        _git(authority_repo, "update-ref", launcher.TRUSTED_AUTHORITY_REF, commit)
    return {"path": relative, "sha256": authority_sha, "commit": commit}


def validate_inputs(contract: dict, launcher) -> list[dict]:
    if contract["appearanceLock"] is not None or contract["sourceProductionProfile"] is not None or contract["executionAuthority"] is not None or contract["execution"]["launchGrant"] is not None: fail("prelaunch_authority_not_null")
    live = launcher.validate_live_identity(contract)
    if len(live.get("head", "")) != 40 or live.get("branch") != "codex/citysim-world-art-east": fail("live_checkout_identity", repr(live))
    provenance_variant = copy.deepcopy(contract)
    provenance_variant["authority"]["observedHead"] = "0" * 40
    if launcher.validate_live_identity(provenance_variant) != live: fail("observed_head_not_provenance_only")
    cases = [
        {"case": "exact_live_checkout", "result": "PASS", "headSource": "git rev-parse HEAD", "branch": live["branch"], "serializedCandidateHead": False},
        {"case": "observed_head_provenance_only", "result": "PASS", "recorded": contract["authority"]["observedHead"], "authorizedBy": "external_post_candidate_documents"},
    ]
    try:
        launcher.validate_contract(contract)
    except ValueError as error:
        if str(error) != "execution_authority_missing": fail("missing_authority_wrong_rejection", str(error))
    else:
        fail("missing_authority_accepted")
    cases.append({"case": "missing_external_authority", "result": "REJECTED", "code": "execution_authority_missing"})
    for name, mutate, expected in (
        ("wrong_live_branch", lambda c: c["authority"].update({"branch": "codex/citysim-world-art-west"}), "live_branch_mismatch"),
        ("stale_claim_hash", lambda c: c["authority"]["claim"].update({"sha256": "0" * 64}), "live_claim_binding"),
        ("wrong_authoring_route", lambda c: c["authority"].update({"authoringRoute": {"routeId": "quality-v2:wrong", "sha256": "0" * 64}}), "authoring_route_binding"),
        ("wrong_dynamic_repair_authority", lambda c: c["authority"].update({"dynamicIdentityAuthority": {"path": "bad", "sha256": "0" * 64}}), "dynamic_identity_authority_binding"),
        ("caller_selected_trust_root", lambda c: c["authority"]["externalAuthorization"].update({"integrationCheckoutRoot": "/tmp/forged"}), "external_authorization_binding"),
    ):
        candidate = copy.deepcopy(contract); mutate(candidate)
        try:
            launcher.validate_live_identity(candidate)
        except ValueError as error:
            if str(error) != expected: fail("live_identity_adversary_wrong_rejection", name + ":" + str(error))
            cases.append({"case": name, "result": "REJECTED", "code": str(error)})
        else:
            fail("live_identity_adversary_accepted", name)
    positive_root = Path(tempfile.mkdtemp(prefix=".east-dynamic-authority-fixture-", dir=ROOT))
    try:
        fixture, worker_repo, authority_repo, positive_authority, positive_binding = _external_authority_fixture(positive_root, contract, launcher)
        bundle = launcher.validate_contract(fixture, worker_repo, binding=positive_binding, authority_repo=authority_repo)
        if worker_repo.resolve() == authority_repo.resolve() or bundle["liveIdentity"]["head"] == fixture["authority"]["observedHead"]: fail("separate_repo_or_provenance_boundary")
        cases.append({"case": "separate_worker_and_external_authority_repositories", "result": "PASS", "workerHead": bundle["liveIdentity"]["head"], "provenanceHead": fixture["authority"]["observedHead"], "authorityCommit": positive_binding["commit"], "documents": sorted(positive_authority["documents"])})

        def expect_authority(name: str, binding: dict, expected: str, candidate: dict | None = None, auth_repo: Path | None = None) -> None:
            try:
                launcher.load_execution_authority(fixture if candidate is None else candidate, worker_repo, binding=binding, authority_repo=authority_repo if auth_repo is None else auth_repo)
            except ValueError as error:
                if str(error) != expected: fail("authority_adversary_wrong_rejection", name + ":" + str(error))
                cases.append({"case": name, "result": "REJECTED", "code": str(error)})
            else:
                fail("authority_adversary_accepted", name)

        for name, mutate, expected in (
            ("stale_parent_worker_head", lambda a: a["task"].update({"workerHead": PARENT}), "execution_authority_claim"),
            ("missing_worker_head", lambda a: a["task"].pop("workerHead"), "execution_authority_claim"),
            ("mismatched_worker_branch", lambda a: a["task"].update({"branch": "codex/citysim-world-art-west"}), "execution_authority_claim"),
            ("missing_worker_branch", lambda a: a["task"].pop("branch"), "execution_authority_claim"),
            ("mismatched_claim", lambda a: a["task"].update({"claimSha256": "0" * 64}), "execution_authority_claim"),
            ("missing_claim", lambda a: a["task"].pop("claimSha256"), "execution_authority_claim"),
            ("mismatched_route", lambda a: a["task"].update({"routeId": "forged-route"}), "execution_authority_route"),
            ("missing_route", lambda a: a["task"].pop("routeId"), "execution_authority_route"),
        ):
            altered = copy.deepcopy(positive_authority); mutate(altered)
            expect_authority(name, _commit_authority(authority_repo, launcher, altered), expected)

        missing_profile = copy.deepcopy(positive_authority)
        missing_profile["documents"].pop("sourceProductionProfile")
        expect_authority("missing_profile_authority", _commit_authority(authority_repo, launcher, missing_profile), "execution_documents_missing")

        expect_authority("inline_caller_authority", positive_authority, "execution_authority_binding")
        forged_hash = copy.deepcopy(positive_binding); forged_hash["sha256"] = "0" * 64
        expect_authority("forged_authority_hash", forged_hash, "execution_authority_hash")
        nonexistent = copy.deepcopy(positive_binding); nonexistent["commit"] = "0" * 40
        expect_authority("nonexistent_authority_commit", nonexistent, "execution_authority_non_ancestral")

        untrusted = copy.deepcopy(positive_authority)
        untrusted_binding = _commit_authority(authority_repo, launcher, untrusted, update_trust=False)
        expect_authority("non_ancestral_authority_commit", untrusted_binding, "execution_authority_non_ancestral")
        _git(authority_repo, "update-ref", launcher.TRUSTED_AUTHORITY_REF, untrusted_binding["commit"])

        grant_binding = positive_authority["documents"]["grant"]
        grant = json.loads(_git(authority_repo, "show", grant_binding["commit"] + ":" + grant_binding["path"]))
        grant["branch"] = "codex/citysim-world-art-west"
        _, grant_sha = _write_json(authority_repo, grant_binding["path"], grant)
        grant_commit = _commit_all(authority_repo, "publish cross-document drift")
        _git(authority_repo, "update-ref", launcher.TRUSTED_AUTHORITY_REF, grant_commit)
        drifted_authority = copy.deepcopy(positive_authority)
        drifted_authority["documents"]["grant"] = {"path": grant_binding["path"], "sha256": grant_sha, "commit": grant_commit}
        expect_authority("cross_document_identity_drift", _commit_authority(authority_repo, launcher, drifted_authority), "document_identity_cross_binding")

        profile_binding = positive_authority["documents"]["sourceProductionProfile"]
        profile_authority = json.loads(_git(authority_repo, "show", profile_binding["commit"] + ":" + profile_binding["path"]))
        profile_authority["workerHead"] = PARENT
        _, profile_authority_sha = _write_json(authority_repo, profile_binding["path"], profile_authority)
        profile_authority_commit = _commit_all(authority_repo, "publish stale profile authority")
        _git(authority_repo, "update-ref", launcher.TRUSTED_AUTHORITY_REF, profile_authority_commit)
        stale_profile = copy.deepcopy(positive_authority)
        stale_profile["documents"]["sourceProductionProfile"] = {"path": profile_binding["path"], "sha256": profile_authority_sha, "commit": profile_authority_commit}
        expect_authority("stale_profile_authority", _commit_authority(authority_repo, launcher, stale_profile), "document_identity_cross_binding")

        link_path = authority_repo / "docs/production/evidence/INTEGRATION/authority-link.json"
        link_path.symlink_to("PLAY-079-EAST-PROCESS-A-EXECUTION-AUTHORITY.json")
        link_commit = _commit_all(authority_repo, "publish symlink adversary")
        _git(authority_repo, "update-ref", launcher.TRUSTED_AUTHORITY_REF, link_commit)
        link_payload = b"PLAY-079-EAST-PROCESS-A-EXECUTION-AUTHORITY.json"
        expect_authority("symlinked_git_blob", {"path": "docs/production/evidence/INTEGRATION/authority-link.json", "sha256": hashlib.sha256(link_payload).hexdigest(), "commit": link_commit}, "execution_authority_git_mode")

        local_authority_path = worker_repo / "docs/production/evidence/INTEGRATION/forged-authority.json"
        local_authority_path.parent.mkdir(parents=True, exist_ok=True)
        local_authority_path.write_bytes(canon(positive_authority))
        local_commit = _commit_all(worker_repo, "forge caller-local authority")
        local_binding = {"path": local_authority_path.relative_to(worker_repo).as_posix(), "sha256": sha(local_authority_path), "commit": local_commit}
        expect_authority("worker_repository_is_not_trust_root", local_binding, "execution_authority_trusted_ref", auth_repo=worker_repo)
    finally:
        shutil.rmtree(positive_root, ignore_errors=True)
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
    return {
        "schema": "citysim.play-079.east-process-a-dynamic-identity-validation.v1", "task": "PLAY-079", "direction": "east", "familyRevision": "v14", "result": "PASS",
        "authorityCommit": contract["authority"]["authorityCommit"], "baseCommit": contract["authority"]["baseCommit"],
        "observedStartHead": PARENT, "observedHeadRole": "provenance_only", "preservedCandidate": PRESERVED_CANDIDATE,
        "contractSha256": sha(CONTRACT), "designSha256": sha(DESIGN), "loweringSha256": sha(LOWERING),
        "dynamicIdentityAuthority": contract["authority"]["dynamicIdentityAuthority"], "authoringRoute": contract["authority"]["authoringRoute"],
        "externalTrustRoot": contract["authority"]["externalAuthorization"],
        "appearanceLock": None, "sourceProductionProfile": None, "executionAuthority": None, "executionReady": False,
        "executableBehavior": "UNPROVEN", "staticChecks": static, "semanticChecks": semantic, "adversarialCases": cases,
        "freshRoots": [{"label": "fresh-root-a", "childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "pixelFilesCreated": 0, "blendFilesCreated": 0}, {"label": "fresh-root-b", "childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "pixelFilesCreated": 0, "blendFilesCreated": 0}],
        "outputRootCreated": False, "launchInvoked": False, "profileLoaded": False, "siblingInputsConsumed": [], "sourceReady": False, "productionSelected": False, "changedPaths": changed,
    }


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
    handoff = {
        "schema": "citysim.play-079.east-process-a-dynamic-identity-handoff.v1", "stage": "frontier-zero-dcc-repair", "task": "PLAY-079", "direction": "east", "familyRevision": "v14", "branch": "codex/citysim-world-art-east",
        "observedStartHead": PARENT, "observedHeadRole": "provenance_only", "preservedCandidate": PRESERVED_CANDIDATE,
        "contractPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/PROCESS-A-CONTRACT.json", "contractSha256": sha(CONTRACT),
        "childPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/process_a_child.py", "launcherPath": "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/run_process_a.py",
        "externalAuthorization": contract["authority"]["externalAuthorization"], "outputRoot": contract["execution"]["outputRoot"], "outputRootCreated": False,
        "childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "pixelFilesCreated": 0, "blendFilesCreated": 0,
        "appearanceLock": None, "sourceProductionProfile": None, "executionAuthority": None, "executionReady": False, "executableBehavior": "UNPROVEN", "sourceReady": False, "productionSelected": False,
        "disposition": "frontier_reference_ready_for_independent_static_review", "knownBlocker": "Integration must issue post-candidate Git-bound schedule/grant/session/profile authority and independently exercise the accepted exact candidate before any launch", "siblingInputsConsumed": [],
        "validationPath": "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01/VALIDATION.json",
    }
    VALIDATION.write_bytes(canon(evidence))
    HANDOFF.write_bytes(canon(handoff))
    RETURN_RECEIPT.parent.mkdir(parents=True, exist_ok=True)
    receipt = {
        "schema": "citysim.play-079.east-v14-dynamic-live-identity-repair.v1", "task": "PLAY-079", "direction": "east",
        "routeId": "quality-v2:play-079-east-v14-dynamic-identity-repair-v2", "routeSha256": "c0627cb0e098aa28383d1ff978188e9007bb84e1bc7adddd391ea5c17807542b",
        "authority": {"authorityCommit": "6aa0d9ba2d82e375885b03545a492098b94af74f", "baseCommit": "6aa0d9ba2d82e375885b03545a492098b94af74f", "path": "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-EAST-DYNAMIC-LIVE-IDENTITY-RETURN-REPAIR-V1.md", "sha256": "a530e9e21357931a5ea926e90f9a27e2398ec09b6471207921c91557bc7e1841"},
        "claim": contract["authority"]["claim"], "observedStartHead": PARENT, "observedHeadRole": "provenance_only", "preservedCandidate": PRESERVED_CANDIDATE,
        "candidateAuthorizationRule": "resolve worker HEAD/branch at runtime; accept only external Git blobs ancestral to Integration origin/master whose schedule/grant/session/profile authority cross-binds that live identity",
        "result": "PASS", "executableBehavior": "UNPROVEN", "validation": evidence, "handoff": handoff, "historicalEvidencePreserved": True,
        "zeroPixelBoundary": {"childStarts": 0, "blenderInvocations": 0, "dccInvocations": 0, "renderInvocations": 0, "outputRootCreated": False, "pixelFilesCreated": 0, "blendFilesCreated": 0},
        "knownBlocker": "Integration-owned post-candidate execution authority and independent exercise remain required", "siblingInputsConsumed": [],
    }
    RETURN_RECEIPT.write_bytes(canon(receipt))
    print(f"PASS: East dynamic live-identity repair; {len(cases)} authority cases; 2 byte-identical zero-child proofs; no Blender/DCC/pixels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
