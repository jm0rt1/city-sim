#!/usr/bin/env python3
"""Authenticated one-child Process-A launcher; never called by prelaunch tests."""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import stat
from pathlib import Path


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[7]
CONTRACT = ROOT / "PROCESS-A-CONTRACT.json"
PROCESS_ROOT = "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01"
CLOSURE_CONTRACT = "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1.json"
CLOSURE_SHA256 = "4a5fdf98ad77082cdd4265ae6f78406f9e26c8dd92443caa8c7e64e6726f91a4"
RETURN_REPAIR_AUTHORITY = "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-DIRECTION-CLOSURE-RETURN-REPAIR-V1.json"
RETURN_REPAIR_SHA256 = "078fafb0028dbea461ba91c3f256fd4b8b8d2c1a96b527c593202fee0b26cd03"
LIVE_RETURN_REPAIR_AUTHORITY = "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-EAST-LIVE-IDENTITY-RETURN-REPAIR-V1.json"
LIVE_RETURN_REPAIR_SHA256 = "aef7773c50f0d29e127bb0859f221d1603f3d37d2fe69ff62bc051e1e33a07e6"
DYNAMIC_REPAIR_AUTHORITY = "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-EAST-DYNAMIC-LIVE-IDENTITY-RETURN-REPAIR-V1.md"
DYNAMIC_REPAIR_SHA256 = "a530e9e21357931a5ea926e90f9a27e2398ec09b6471207921c91557bc7e1841"
AUTHORING_ROUTE_ID = "quality-v2:play-079-east-v14-dynamic-identity-repair-v2"
AUTHORING_ROUTE_SHA256 = "c0627cb0e098aa28383d1ff978188e9007bb84e1bc7adddd391ea5c17807542b"
CLAIM_PATH = "docs/production/claims/PLAY-079.world-art-east.md"
CLAIM_SHA256 = "f7e7fb8079032d70446c346bf49a47e68861aab32027940145664c338e2d723f"
NORTH_REFERENCE_COMMIT = "b961d7a6f9f9ad75f69b9156ce657dd4937e5537"
INTEGRATION_CHECKOUT_ROOT = "/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim"
TRUSTED_AUTHORITY_REF = "refs/remotes/origin/master"
AUTHORITY_BINDING_ENV = "CITYSIM_EXECUTION_AUTHORITY_BINDING_JSON"

REQUIRED_PROFILE_FIELDS = (
    ("schema",),
    ("task",),
    ("direction",),
    ("familyRevision",),
    ("appearanceLock", "path"),
    ("render", "engine"),
    ("render", "device"),
    ("render", "threads"),
    ("render", "samples"),
    ("render", "seed"),
    ("render", "maxBounces"),
    ("render", "transparentFilm"),
    ("render", "resolution"),
    ("render", "resolutionPercentage"),
    ("render", "pixelAspect"),
    ("colorManagement", "displayDevice"),
    ("colorManagement", "viewTransform"),
    ("colorManagement", "look"),
    ("colorManagement", "exposure"),
    ("colorManagement", "gamma"),
    ("lighting", "world", "color"),
    ("lighting", "world", "strength"),
    ("lighting", "key", "location"),
    ("lighting", "key", "target"),
    ("lighting", "key", "energy"),
    ("lighting", "key", "size"),
    ("lighting", "contactShadow", "receiverBounds"),
    ("lighting", "contactShadow", "location"),
    ("lighting", "contactShadow", "target"),
    ("lighting", "contactShadow", "energy"),
    ("lighting", "contactShadow", "size"),
    ("materials", "roles"),
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_contract() -> dict:
    return json.loads(CONTRACT.read_text(encoding="utf-8"))


def _inside(relative: str, prefix: str) -> bool:
    return relative == prefix or relative.startswith(prefix.rstrip("/") + "/")


def _safe_repo_path(relative: str, repo: Path, allow_north: bool = False) -> Path:
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute():
        raise ValueError("profile_path")
    path = Path(relative)
    if any(part in ("", ".", "..") for part in path.parts):
        raise ValueError("profile_path")
    if any(marker in relative for marker in (("PLAY-080", "PLAY-081") if allow_north else ("PLAY-027", "PLAY-080", "PLAY-081"))):
        raise ValueError("profile_sibling_path")
    resolved = (repo / path).resolve()
    if repo.resolve() not in resolved.parents:
        raise ValueError("profile_path")
    cursor = repo.resolve()
    for part in path.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise ValueError("profile_symlink")
    return repo / path


def _read_binding(binding: dict, label: str, repo: Path, allow_north: bool = False) -> dict:
    if not isinstance(binding, dict) or set(binding) - {"path", "sha256", "commit"} or not isinstance(binding.get("sha256"), str):
        raise ValueError(label + "_binding")
    path = _safe_repo_path(binding.get("path"), repo, allow_north=allow_north)
    if not path.is_file() or path.is_symlink() or digest(path) != binding["sha256"]:
        raise ValueError(label + "_hash")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise ValueError(label + "_json") from error
    if not isinstance(value, dict):
        raise ValueError(label + "_shape")
    return value


def _get(value: dict, path: tuple[str, ...]):
    current = value
    for key in path:
        if not isinstance(current, dict) or key not in current:
            raise ValueError("profile_missing:" + ".".join(path))
        current = current[key]
    return current


def _numeric(value: object, label: str) -> None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError("profile_numeric:" + label)


def _numeric_vector(value: object, length: int, label: str) -> None:
    if not isinstance(value, list) or len(value) != length:
        raise ValueError("profile_vector:" + label)
    for item in value:
        _numeric(item, label)


def _validate_profile_shape(profile: dict, appearance_ref: dict, profile_ref: dict) -> None:
    if profile.get("schema") != "citysim.play-027.north-v14-source-production-profile.v1": raise ValueError("profile_schema")
    if profile.get("task") != "PLAY-027" or profile.get("direction") != "north" or profile.get("familyRevision") != "v14": raise ValueError("profile_identity")
    if profile.get("appearanceLock", {}).get("path") != appearance_ref.get("path"): raise ValueError("profile_appearance_binding")
    for path in REQUIRED_PROFILE_FIELDS:
        _get(profile, path)
    render = profile["render"]
    if render["engine"] != "CYCLES" or render["device"] != "CPU" or render["threads"] != 1: raise ValueError("profile_render_authority")
    if not isinstance(render["resolution"], list) or len(render["resolution"]) != 2 or not all(isinstance(x, int) and x > 0 for x in render["resolution"]): raise ValueError("profile_resolution")
    if not isinstance(render["pixelAspect"], list) or len(render["pixelAspect"]) != 2: raise ValueError("profile_pixel_aspect")
    for field in ("threads", "samples", "seed", "maxBounces", "resolutionPercentage"):
        _numeric(render[field], "render." + field)
    _numeric_vector(render["pixelAspect"], 2, "render.pixelAspect")
    for field in ("exposure", "gamma"):
        _numeric(profile["colorManagement"][field], "colorManagement." + field)
    _numeric_vector(profile["lighting"]["world"]["color"], 4, "lighting.world.color")
    _numeric(profile["lighting"]["world"]["strength"], "lighting.world.strength")
    for light_name in ("key", "contactShadow"):
        light = profile["lighting"][light_name]
        _numeric_vector(light["location"], 3, "lighting." + light_name + ".location")
        _numeric_vector(light["target"], 3, "lighting." + light_name + ".target")
        _numeric(light["energy"], "lighting." + light_name + ".energy")
        _numeric(light["size"], "lighting." + light_name + ".size")
    for bound in ("xMin", "xMax", "yMin", "yMax", "zMin", "zMax"):
        _numeric(profile["lighting"]["contactShadow"]["receiverBounds"][bound], "lighting.contactShadow.receiverBounds." + bound)
    roles = profile["materials"]["roles"]
    expected_roles = {"warm-weathered-masonry", "formed-concrete", "dark-painted-steel", "roof-edge-metal", "glazing-louver", "portal-void", "safety-oxide", "hot-process", "contact-shadow"}
    if set(roles) != expected_roles: raise ValueError("profile_material_roles")
    for spec in roles.values():
        if not isinstance(spec, dict) or set(spec) != {"baseColor", "metallic", "roughness", "specularIORLevel"}: raise ValueError("profile_material_fields")
        _numeric_vector(spec["baseColor"], 4, "materials.baseColor")
        for field in ("metallic", "roughness", "specularIORLevel"):
            _numeric(spec[field], "materials." + field)


def load_profile_bundle(contract: dict, repo: Path = REPO) -> dict:
    appearance_ref = contract.get("appearanceLock")
    profile_ref = contract.get("sourceProductionProfile")
    if appearance_ref is None: raise ValueError("appearance_lock_missing")
    if profile_ref is None: raise ValueError("source_profile_missing")
    appearance = _read_binding(appearance_ref, "appearance_lock", repo, allow_north=True)
    profile = _read_binding(profile_ref, "source_profile", repo, allow_north=True)
    _validate_profile_shape(profile, appearance_ref, profile_ref)
    if appearance.get("schema") != "citysim.play-027.north-v14-appearance-lock.v1" or appearance.get("status") != "PUBLISHED": raise ValueError("appearance_lock_state")
    if appearance.get("task") != "PLAY-027" or appearance.get("direction") != "north" or appearance.get("familyRevision") != "v14": raise ValueError("appearance_lock_identity")
    bound_profile = appearance.get("sourceProductionProfile")
    if not isinstance(bound_profile, dict) or bound_profile.get("path") != profile_ref.get("path") or bound_profile.get("sha256") != profile_ref.get("sha256"): raise ValueError("appearance_profile_mismatch")
    return {"appearanceLock": appearance, "sourceProductionProfile": profile, "appearanceLockRef": appearance_ref, "sourceProductionProfileRef": profile_ref}


def resolve_live_identity(repo: Path = REPO) -> dict:
    try:
        head = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
        branch = subprocess.check_output(["git", "-C", str(repo), "branch", "--show-current"], text=True).strip()
    except (OSError, subprocess.CalledProcessError) as error:
        raise ValueError("live_git_identity_unavailable") from error
    if len(head) != 40 or branch != "codex/citysim-world-art-east":
        raise ValueError("live_git_identity")
    return {"head": head, "branch": branch}


def validate_live_identity(contract: dict, repo: Path = REPO) -> dict:
    actual = resolve_live_identity(repo)
    provenance = contract.get("authority", {})
    if provenance.get("observedHeadRole") != "provenance_only" or not re.fullmatch(r"[0-9a-f]{40}", str(provenance.get("observedHead", ""))):
        raise ValueError("observed_head_provenance")
    if actual["branch"] != provenance.get("branch"):
        raise ValueError("live_branch_mismatch")
    claim = provenance.get("claim", {})
    if claim != {"path": CLAIM_PATH, "sha256": CLAIM_SHA256}:
        raise ValueError("live_claim_binding")
    claim_path = _safe_repo_path(claim.get("path"), repo)
    if not claim_path.is_file() or claim_path.is_symlink() or digest(claim_path) != claim.get("sha256"):
        raise ValueError("live_claim_hash_mismatch")
    if provenance.get("dynamicIdentityAuthority") != {"path": DYNAMIC_REPAIR_AUTHORITY, "sha256": DYNAMIC_REPAIR_SHA256}:
        raise ValueError("dynamic_identity_authority_binding")
    if provenance.get("authoringRoute") != {"routeId": AUTHORING_ROUTE_ID, "sha256": AUTHORING_ROUTE_SHA256}:
        raise ValueError("authoring_route_binding")
    if provenance.get("externalAuthorization") != {"integrationCheckoutRoot": INTEGRATION_CHECKOUT_ROOT, "trustedRef": TRUSTED_AUTHORITY_REF, "bindingEnvironment": AUTHORITY_BINDING_ENV, "runtimeIdentityFields": ["branch", "workerHead", "claimSha256", "routeId", "routeSha256"]}:
        raise ValueError("external_authorization_binding")
    return actual


def _git_bytes(repo: Path, args: list[str], label: str) -> bytes:
    try:
        return subprocess.check_output(["git", "-C", str(repo), *args], stderr=subprocess.DEVNULL)
    except (OSError, subprocess.CalledProcessError) as error:
        raise ValueError(label) from error


def _git_text(repo: Path, args: list[str], label: str) -> str:
    return _git_bytes(repo, args, label).decode("utf-8").strip()


def _read_git_binding(binding: dict, label: str, authority_repo: Path, allowed_prefix: str) -> dict:
    if not isinstance(binding, dict) or set(binding) != {"path", "sha256", "commit"}:
        raise ValueError(label + "_binding")
    relative = binding.get("path")
    commit = binding.get("commit")
    expected_sha = binding.get("sha256")
    if not isinstance(relative, str) or not _inside(relative, allowed_prefix) or Path(relative).is_absolute() or any(part in ("", ".", "..") for part in Path(relative).parts):
        raise ValueError(label + "_path")
    if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit) or not isinstance(expected_sha, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_sha):
        raise ValueError(label + "_binding")
    trusted_ref = _git_text(authority_repo, ["rev-parse", TRUSTED_AUTHORITY_REF], label + "_trusted_ref")
    try:
        subprocess.run(["git", "-C", str(authority_repo), "merge-base", "--is-ancestor", commit, trusted_ref], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.CalledProcessError) as error:
        raise ValueError(label + "_non_ancestral") from error
    object_spec = commit + ":" + relative
    if _git_text(authority_repo, ["cat-file", "-t", object_spec], label + "_git_object") != "blob":
        raise ValueError(label + "_non_blob")
    tree_row = _git_text(authority_repo, ["ls-tree", commit, "--", relative], label + "_git_mode")
    if not tree_row or tree_row.split(None, 1)[0] not in {"100644", "100755"}:
        raise ValueError(label + "_git_mode")
    payload = _git_bytes(authority_repo, ["show", object_spec], label + "_git_blob")
    if hashlib.sha256(payload).hexdigest() != expected_sha:
        raise ValueError(label + "_hash")
    try:
        value = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as error:
        raise ValueError(label + "_json") from error
    if not isinstance(value, dict):
        raise ValueError(label + "_shape")
    return value


def _binding_from_environment() -> dict:
    raw = os.environ.get(AUTHORITY_BINDING_ENV)
    if not raw:
        raise ValueError("execution_authority_missing")
    try:
        binding = json.loads(raw)
    except ValueError as error:
        raise ValueError("execution_authority_binding") from error
    if not isinstance(binding, dict) or set(binding) != {"path", "sha256", "commit"}:
        raise ValueError("execution_authority_binding")
    return binding


def _profile_bundle_from_authority(profile_authority: dict, authority_repo: Path) -> dict:
    appearance_ref = profile_authority.get("appearanceLock")
    profile_ref = profile_authority.get("sourceProductionProfile")
    appearance = _read_git_binding(appearance_ref, "appearance_lock", authority_repo, "Native/CitySimNative/WorldArt/Blender/PLAY-027/")
    profile = _read_git_binding(profile_ref, "source_profile", authority_repo, "Native/CitySimNative/WorldArt/Blender/PLAY-027/")
    _validate_profile_shape(profile, appearance_ref, profile_ref)
    if appearance.get("schema") != "citysim.play-027.north-v14-appearance-lock.v1" or appearance.get("status") != "PUBLISHED":
        raise ValueError("appearance_lock_state")
    if appearance.get("task") != "PLAY-027" or appearance.get("direction") != "north" or appearance.get("familyRevision") != "v14":
        raise ValueError("appearance_lock_identity")
    if appearance.get("sourceProductionProfile") != {"path": profile_ref["path"], "sha256": profile_ref["sha256"]}:
        raise ValueError("appearance_profile_mismatch")
    return {"appearanceLock": appearance, "sourceProductionProfile": profile, "appearanceLockRef": appearance_ref, "sourceProductionProfileRef": profile_ref}


def load_execution_authority(contract: dict, repo: Path = REPO, binding: dict | None = None, authority_repo: Path | None = None) -> dict:
    live = validate_live_identity(contract, repo)
    authority_root = Path(INTEGRATION_CHECKOUT_ROOT) if authority_repo is None else authority_repo
    authority_binding = _binding_from_environment() if binding is None else binding
    authority = _read_git_binding(authority_binding, "execution_authority", authority_root, "docs/production/evidence/INTEGRATION/")
    if authority.get("schemaVersion") != 2 or authority.get("mode") != "validation_only":
        raise ValueError("execution_authority_schema")
    if authority.get("integrationCheckoutRoot") != INTEGRATION_CHECKOUT_ROOT:
        raise ValueError("integration_checkout_root")
    closure = authority.get("closureContract")
    if not isinstance(closure, dict) or closure.get("path") != CLOSURE_CONTRACT or closure.get("sha256") != CLOSURE_SHA256:
        raise ValueError("closure_contract_binding")
    if authority.get("trustRef") != TRUSTED_AUTHORITY_REF:
        raise ValueError("authority_trust_ref")
    task = authority.get("task", {})
    if task.get("taskId") != "PLAY-079" or task.get("direction") != "east":
        raise ValueError("execution_authority_identity")
    if task.get("branch") != live["branch"] or task.get("workerHead") != live["head"] or task.get("claimSha256") != CLAIM_SHA256:
        raise ValueError("execution_authority_claim")
    if task.get("publishedBaseCommit") != contract["authority"]["baseCommit"]:
        raise ValueError("execution_authority_base")
    if not isinstance(task.get("routeId"), str) or not task["routeId"].startswith("quality-v2:") or not re.fullmatch(r"[0-9a-f]{64}", str(task.get("routeSha256", ""))):
        raise ValueError("execution_authority_route")
    documents = authority.get("documents")
    if not isinstance(documents, dict) or set(documents) != {"schedule", "grant", "integrationSession", "sourceProductionProfile"}:
        raise ValueError("execution_documents_missing")
    loaded_docs = {}
    for name, document_binding in documents.items():
        loaded_docs[name] = _read_git_binding(document_binding, name, authority_root, "docs/production/evidence/INTEGRATION/")
    schedule, grant_doc, session, profile_authority = loaded_docs["schedule"], loaded_docs["grant"], loaded_docs["integrationSession"], loaded_docs["sourceProductionProfile"]
    if schedule.get("task") != "PLAY-079" or schedule.get("direction") != "east" or schedule.get("process") != "A" or schedule.get("slot") != "east:A":
        raise ValueError("schedule_binding")
    for document in (schedule, grant_doc, session, profile_authority):
        if any(document.get(field) != schedule.get(field) for field in ("task", "direction", "process", "slot", "branch", "workerHead", "claimSha256", "routeId", "routeSha256", "outputRoot")):
            raise ValueError("document_identity_cross_binding")
    if any(schedule.get(field) != task.get(task_field) for field, task_field in (("branch", "branch"), ("workerHead", "workerHead"), ("claimSha256", "claimSha256"), ("routeId", "routeId"), ("routeSha256", "routeSha256"))):
        raise ValueError("document_authority_cross_binding")
    if grant_doc.get("grantId") != "east:A" or grant_doc.get("direction") != "east" or grant_doc.get("process") != "A":
        raise ValueError("grant_document_binding")
    if session.get("sessionId") != grant_doc.get("sessionId") or session.get("scheduleSHA256") != documents["schedule"].get("sha256") or session.get("grantSHA256") != documents["grant"].get("sha256"):
        raise ValueError("session_cross_binding")
    if schedule.get("claimSha256") != CLAIM_SHA256 or schedule.get("workerHead") != live["head"] or schedule.get("branch") != live["branch"] or schedule.get("outputRoot") != contract["execution"]["outputRoot"]:
        raise ValueError("schedule_identity")
    grant = authority.get("grant", {})
    if grant.get("grantId") != grant_doc.get("grantId") or grant.get("direction") != "east" or grant.get("processId") != contract["execution"]["processId"] or grant.get("slotId") != "east-process-a-slot-1":
        raise ValueError("execution_authority_grant")
    if grant.get("maximumChildStarts") != 1 or grant.get("exactlyOneInvocation") is not True or grant.get("orchestratorOnly") is not True or grant.get("directLowLevelInvocationAllowed") is not False:
        raise ValueError("execution_authority_direct_child")
    roots = authority.get("exclusiveRoots", {})
    if roots.get("outputRoot") != contract["execution"]["outputRoot"]:
        raise ValueError("execution_authority_root")
    auth = authority.get("authentication", {})
    if auth.get("secretTransport") != "anonymous_pipe" or auth.get("rawSecretPersisted") is not False:
        raise ValueError("execution_authority_auth")
    capability = auth.get("childCapability", {})
    if capability.get("boundGrantId") != grant.get("grantId") or capability.get("oneTime") is not True or capability.get("replayAllowed") is not False:
        raise ValueError("execution_authority_capability")
    toolchain = authority.get("toolchain", {})
    if toolchain.get("path") != contract["execution"]["blenderExecutable"] or not isinstance(toolchain.get("sha256"), str) or len(toolchain["sha256"]) != 64 or toolchain.get("factoryStartup") is not True or toolchain.get("disabledAutoexec") is not True or toolchain.get("pythonExitCode") != 1:
        raise ValueError("toolchain_binding")
    profile_bundle = _profile_bundle_from_authority(profile_authority, authority_root)
    return {"authority": authority, "profileBundle": profile_bundle, "liveIdentity": live, "binding": authority_binding}


def validate_forwarded_authority(contract: dict, authority: dict, grant: dict, profile_bundle: dict, env: dict) -> None:
    if env.get("CITYSIM_PROCESS_ID") != contract["execution"]["processId"]:
        raise ValueError("process_id_mismatch")
    if env.get("CITYSIM_OUTPUT_ROOT") != str(REPO / contract["execution"]["outputRoot"]):
        raise ValueError("output_root_mismatch")
    if env.get("CITYSIM_EXECUTION_AUTHORITY_JSON") != json.dumps(authority, sort_keys=True, separators=(",", ":")):
        raise ValueError("authority_forward_mismatch")
    if env.get("CITYSIM_GRANT_JSON") != json.dumps(grant, sort_keys=True, separators=(",", ":")):
        raise ValueError("grant_forward_mismatch")
    if grant.get("processId") != contract["execution"]["processId"] or grant.get("direction") != "east" or grant.get("slotId") != "east-process-a-slot-1":
        raise ValueError("grant_binding")
    forwarded_profile = json.loads(env.get("CITYSIM_PROFILE_JSON", "{}"))
    if forwarded_profile != profile_bundle or not re.fullmatch(r"[0-9a-f]{64}", str(profile_bundle.get("sourceProductionProfileRef", {}).get("sha256", ""))):
        raise ValueError("profile_forward_mismatch")


def validate_contract(contract: dict, repo: Path = REPO, binding: dict | None = None, authority_repo: Path | None = None) -> dict:
    if contract.get("schema") != "citysim.play-079.east-v14-process-a-contract.v1": raise ValueError("contract_schema")
    if contract.get("task") != "PLAY-079" or contract.get("direction") != "east" or contract.get("familyRevision") != "v14": raise ValueError("identity")
    if contract.get("appearanceLock") is not None or contract.get("sourceProductionProfile") is not None or contract.get("executionAuthority") is not None or contract["execution"].get("launchGrant") is not None:
        raise ValueError("task_owned_runtime_authority_forbidden")
    for immutable_binding in contract["immutableInputs"].values():
        path = repo / immutable_binding["path"]
        if not path.is_file() or path.is_symlink() or digest(path) != immutable_binding["sha256"]: raise ValueError("immutable_input")
    if contract["execution"]["direction"] != "east" or contract["execution"]["childLimit"] != 1 or contract["execution"]["dccSlot"] != 1: raise ValueError("execution_binding")
    output = contract["execution"]["outputRoot"]
    if not _inside(output, PROCESS_ROOT) or output == PROCESS_ROOT: raise ValueError("output_root")
    output_path = repo / output
    if output_path.exists() or output_path.is_symlink(): raise ValueError("output_reuse")
    bundle = load_execution_authority(contract, repo, binding=binding, authority_repo=authority_repo)
    validate_grant(contract, bundle["authority"]["grant"], bundle["liveIdentity"], bundle["authority"])
    return bundle


def validate_grant(contract: dict, grant: dict, live_identity: dict, authority: dict) -> None:
    task = authority.get("task", {})
    expected = {
        "scheduleId": contract["execution"]["scheduleId"],
        "processId": contract["execution"]["processId"],
        "direction": "east",
        "dccSlot": 1,
        "childLimit": 1,
        "baseCommit": contract["authority"]["baseCommit"],
        "workerHead": live_identity["head"],
        "branch": live_identity["branch"],
        "claimSha256": CLAIM_SHA256,
        "routeId": task.get("routeId"),
        "routeSha256": task.get("routeSha256"),
        "outputRoot": contract["execution"]["outputRoot"],
    }
    if any(grant.get(key) != value for key, value in expected.items()): raise ValueError("grant_binding")
    if grant.get("slotId") != "east-process-a-slot-1": raise ValueError("grant_slot")
    if grant.get("attempt") != 1 or grant.get("authenticated") is not True: raise ValueError("grant_authentication")


def launch(contract: dict, repo: Path = REPO) -> int:
    bundle = validate_contract(contract, repo)
    authority = bundle["authority"]
    profile_bundle = bundle["profileBundle"]
    grant = authority["grant"]
    child = ROOT / contract["execution"]["child"]
    output_path = repo / contract["execution"]["outputRoot"]
    if output_path.exists() or output_path.is_symlink():
        raise ValueError("output_reuse")
    output_path.mkdir(parents=False, exist_ok=False)
    output_stat = output_path.stat()
    if not stat.S_ISDIR(output_stat.st_mode):
        raise ValueError("output_not_directory")
    command = [authority["toolchain"]["path"], "--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1", "--python", str(child)]
    env = {
        "PATH": os.environ.get("PATH", ""),
        "CITYSIM_PROCESS_ID": contract["execution"]["processId"],
        "CITYSIM_OUTPUT_ROOT": str(repo / contract["execution"]["outputRoot"]),
        "CITYSIM_OUTPUT_ROOT_INODE": str(output_stat.st_ino),
        "CITYSIM_EXECUTION_AUTHORITY_JSON": json.dumps(authority, sort_keys=True, separators=(",", ":")),
        "CITYSIM_GRANT_JSON": json.dumps(grant, sort_keys=True, separators=(",", ":")),
        "CITYSIM_PROFILE_JSON": json.dumps(profile_bundle, sort_keys=True, separators=(",", ":")),
    }
    validate_forwarded_authority(contract, authority, grant, profile_bundle, env)
    proc = subprocess.Popen(command, cwd=str(repo), env=env)
    return proc.wait()


def main(argv: list[str]) -> int:
    contract = load_contract()
    if argv[1:] != ["--launch"]:
        try:
            validate_contract(contract)
        except ValueError as error:
            print(f"BLOCKED:{error}")
            return 2
        print("READY: exact Integration authority and grant required; zero child started")
        return 0
    return launch(contract)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
