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
PROCESS_ROOT = "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/process-a-execution-v01"

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


def _safe_repo_path(relative: str, repo: Path) -> Path:
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute():
        raise ValueError("profile_path")
    path = Path(relative)
    if any(part in ("", ".", "..") for part in path.parts):
        raise ValueError("profile_path")
    if any(marker in relative for marker in ("PLAY-027", "PLAY-080", "PLAY-081")):
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


def _read_binding(binding: dict, label: str, repo: Path) -> dict:
    if not isinstance(binding, dict) or set(binding) - {"path", "sha256", "commit"} or not isinstance(binding.get("sha256"), str):
        raise ValueError(label + "_binding")
    path = _safe_repo_path(binding.get("path"), repo)
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
    if profile.get("schema") not in {"citysim.play-079.east-v14-source-production-profile.v1", "citysim.play-079.north-v14-source-production-profile.v1"}: raise ValueError("profile_schema")
    if profile.get("task") != "PLAY-079" or profile.get("direction") not in {"east", "north"} or profile.get("familyRevision") != "v14": raise ValueError("profile_identity")
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
    appearance = _read_binding(appearance_ref, "appearance_lock", repo)
    profile = _read_binding(profile_ref, "source_profile", repo)
    _validate_profile_shape(profile, appearance_ref, profile_ref)
    if appearance.get("schema") not in {"citysim.play-079.east-v14-appearance-lock.v1", "citysim.play-079.north-v14-appearance-lock.v1"} or appearance.get("status") != "PUBLISHED": raise ValueError("appearance_lock_state")
    if appearance.get("task") != "PLAY-079" or appearance.get("direction") not in {"east", "north"} or appearance.get("familyRevision") != "v14": raise ValueError("appearance_lock_identity")
    bound_profile = appearance.get("sourceProductionProfile")
    if not isinstance(bound_profile, dict) or bound_profile.get("path") != profile_ref.get("path") or bound_profile.get("sha256") != profile_ref.get("sha256"): raise ValueError("appearance_profile_mismatch")
    return {"appearanceLock": appearance, "sourceProductionProfile": profile, "appearanceLockRef": appearance_ref, "sourceProductionProfileRef": profile_ref}


def load_execution_authority(contract: dict, repo: Path = REPO) -> dict:
    binding = contract.get("executionAuthority")
    if binding is None:
        raise ValueError("execution_authority_missing")
    authority = _read_binding(binding, "execution_authority", repo)
    if authority.get("schemaVersion") != 1 or authority.get("mode") != "validation_only":
        raise ValueError("execution_authority_schema")
    task = authority.get("task", {})
    if task.get("taskId") != "PLAY-079" or task.get("direction") != "east":
        raise ValueError("execution_authority_identity")
    if task.get("branch") != "codex/citysim-world-art-east" or task.get("claimSha256") != contract["authority"]["claim"]["sha256"]:
        raise ValueError("execution_authority_claim")
    if task.get("publishedBaseCommit") != contract["authority"]["baseCommit"]:
        raise ValueError("execution_authority_base")
    grant = authority.get("grant", {})
    if grant.get("direction") != "east" or grant.get("processId") != contract["execution"]["processId"] or grant.get("slotId") != "east-process-a-slot-1":
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
    return authority


def validate_forwarded_authority(contract: dict, authority: dict, grant: dict, env: dict) -> None:
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
    profile_bundle = json.loads(env.get("CITYSIM_PROFILE_JSON", "{}"))
    if profile_bundle.get("sourceProductionProfileRef", {}).get("sha256") != contract["sourceProductionProfile"]["sha256"]:
        raise ValueError("profile_forward_mismatch")


def validate_contract(contract: dict, repo: Path = REPO) -> dict:
    if contract.get("schema") != "citysim.play-079.east-v14-process-a-contract.v1": raise ValueError("contract_schema")
    if contract.get("task") != "PLAY-079" or contract.get("direction") != "east" or contract.get("familyRevision") != "v14": raise ValueError("identity")
    for binding in contract["immutableInputs"].values():
        path = repo / binding["path"]
        if not path.is_file() or path.is_symlink() or digest(path) != binding["sha256"]: raise ValueError("immutable_input")
    if contract["execution"]["direction"] != "east" or contract["execution"]["childLimit"] != 1 or contract["execution"]["dccSlot"] != 1: raise ValueError("execution_binding")
    output = contract["execution"]["outputRoot"]
    if not _inside(output, PROCESS_ROOT) or output == PROCESS_ROOT: raise ValueError("output_root")
    output_path = repo / output
    if output_path.exists() or output_path.is_symlink(): raise ValueError("output_reuse")
    load_profile_bundle(contract, repo)
    load_execution_authority(contract, repo)
    if contract["execution"]["launchGrant"] is None: raise ValueError("launch_grant_missing")
    if contract.get("executionReady") is not True: raise ValueError("execution_not_ready")
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
    if grant.get("slotId") != "east-process-a-slot-1": raise ValueError("grant_slot")
    if grant.get("attempt") != 1 or grant.get("authenticated") is not True: raise ValueError("grant_authentication")


def launch(contract: dict, grant: dict, repo: Path = REPO) -> int:
    validate_contract(contract, repo)
    validate_grant(contract, grant)
    profile_bundle = load_profile_bundle(contract, repo)
    authority = load_execution_authority(contract, repo)
    child = ROOT / contract["execution"]["child"]
    command = [contract["execution"]["blenderExecutable"], "--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1", "--python", str(child)]
    env = {
        "PATH": os.environ.get("PATH", ""),
        "CITYSIM_PROCESS_ID": contract["execution"]["processId"],
        "CITYSIM_OUTPUT_ROOT": str(repo / contract["execution"]["outputRoot"]),
        "CITYSIM_EXECUTION_AUTHORITY_JSON": json.dumps(authority, sort_keys=True, separators=(",", ":")),
        "CITYSIM_GRANT_JSON": json.dumps(grant, sort_keys=True, separators=(",", ":")),
        "CITYSIM_PROFILE_JSON": json.dumps(profile_bundle, sort_keys=True, separators=(",", ":")),
    }
    validate_forwarded_authority(contract, authority, grant, env)
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
    grant = contract.get("execution", {}).get("launchGrant")
    if not isinstance(grant, dict):
        print("BLOCKED:launch_grant_missing")
        return 2
    return launch(contract, grant)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
