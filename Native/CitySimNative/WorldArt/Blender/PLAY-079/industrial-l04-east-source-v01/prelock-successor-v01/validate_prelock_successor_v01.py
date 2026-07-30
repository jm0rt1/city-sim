#!/usr/bin/env python3
"""Validate the additive PLAY-079 East prelock successor without DCC or pixels."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
from typing import Any, NoReturn


VERSION_ROOT = pathlib.Path(__file__).resolve().parent
SOURCE_ROOT = VERSION_ROOT.parent
REPOSITORY_ROOT = VERSION_ROOT.parents[6]
CONTRACT_PATH = VERSION_ROOT / "SUCCESSOR-CONTRACT.json"
SCRIPT_PATH = VERSION_ROOT / "validate_prelock_successor_v01.py"
PUBLISHED_MASTER = "642acc81992e5358768e71c4d8594b24c8d291a9"
AUTHORED_BRANCH = "codex/citysim-world-art-east"
ALLOWED_REPLAY_BRANCHES = {AUTHORED_BRANCH, "master"}
SOURCE_ROOT_RELATIVE = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
    "industrial-l04-east-source-v01/"
)
EVIDENCE_ROOT_RELATIVE = (
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
)
VERSION_SOURCE_ROOT_RELATIVE = f"{SOURCE_ROOT_RELATIVE}prelock-successor-v01/"
VERSION_EVIDENCE_ROOT_RELATIVE = f"{EVIDENCE_ROOT_RELATIVE}prelock-successor-v01/"
CONTRACT_RELATIVE = f"{VERSION_SOURCE_ROOT_RELATIVE}SUCCESSOR-CONTRACT.json"
SCRIPT_RELATIVE = f"{VERSION_SOURCE_ROOT_RELATIVE}validate_prelock_successor_v01.py"
HANDOFF_RELATIVE = f"{VERSION_EVIDENCE_ROOT_RELATIVE}HANDOFF.json"
PROOF_RELATIVE = f"{VERSION_EVIDENCE_ROOT_RELATIVE}PROOF.json"
PIXEL_SUFFIXES = {
    ".bmp",
    ".exr",
    ".jpeg",
    ".jpg",
    ".png",
    ".tif",
    ".tiff",
    ".webp",
}


class SuccessorRejected(RuntimeError):
    """Stable fail-closed successor rejection."""

    def __init__(self, code: str, detail: object):
        super().__init__(str(detail))
        self.code = code
        self.detail = str(detail)


def reject(code: str, detail: object) -> NoReturn:
    raise SuccessorRejected(code, detail)


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def load_hardened_module() -> Any:
    path = SOURCE_ROOT / "replay_current_master_inputs.py"
    spec = importlib.util.spec_from_file_location("play079_hardened_replay", path)
    if spec is None or spec.loader is None:
        reject("hardened_replay_import_failed", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


HARDENED = load_hardened_module()


EXPECTED_BINDINGS = {
    "claim": {
        "path": "docs/production/claims/PLAY-079.world-art-east.md",
        "sha256": "5439d720e0a4c90e7310a7fd94ad1a94dd18497df4ef048de726e33405670fab",
    },
    "hardenedReplay": {
        "path": f"{SOURCE_ROOT_RELATIVE}replay_current_master_inputs.py",
        "sha256": "3a019fcdc14b6db8d4ed7a40bceaf212abda9cecc9846d6ea3c2b4adc434ebbb",
    },
    "runner": {
        "path": f"{SOURCE_ROOT_RELATIVE}RUNNER-CONTRACT.json",
        "sha256": "5302750257a0bc158f6b460f78a48dccd22c2194f169deb8e46e5c61f1204da8",
    },
    "bridgeAuthority": {
        "path": (
            "docs/production/evidence/PLAY-027/"
            "INDUSTRIAL-L04-DIRECTIONAL-COORDINATE-BRIDGE-V06-AUTHORITY.md"
        ),
        "sha256": "5b8cbe06a430b48cd955ba0ec722873ec4c739b7919e22ddac2776561d2910b4",
    },
    "bridgeAcceptance": {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "INDUSTRIAL-L04-DIRECTIONAL-BRIDGE-V06-ACCEPTANCE.md"
        ),
        "sha256": "9765d88191d8a555de41dcccfb83b3da16d8f1423d534d66312ffa98a4615208",
    },
    "bridgeMapping": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
            "industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
        ),
        "sha256": "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7",
    },
    "scene": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-predesign-v01/scene.json"
        ),
        "sha256": "e19c70693ea57a7f23669d5e93354eee0a8fa42be16e68b38d00f5608a500db7",
    },
    "materials": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-predesign-v01/materials.json"
        ),
        "sha256": "1d0eda7be1e50d9fd98247cb63035443e904a2724583df1fbb328140b63ef9b9",
    },
    "predesignValidator": {
        "path": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-predesign-v01/validate_predesign.py"
        ),
        "sha256": "86dd6b3fad5502c6c9f898d802c9fc5eb4da57e7864c981494ad5ad9f75dde33",
    },
    "sourceStageSchema": {
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-source-stage-handoff-schema-v2.json"
        ),
        "sha256": "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7",
    },
}

EXPECTED_ACCEPTED_PREDESIGN = {
    "handoff": {
        "path": "docs/production/evidence/PLAY-079/PLAY-079-EAST-PREDESIGN-HANDOFF.json",
        "sha256": "bb8b2a00b4bf3ffa99112947d08e11cc92cae8d1ea7709e3fa79a4c58f40f390",
    },
    "staticProof": {
        "path": "docs/production/evidence/PLAY-079/STATIC-PREDESIGN-PROOF.json",
        "sha256": "9d804fd9780f8404c5127d915140f94820a2c84ffb19c6c4e9da95100b7726f6",
    },
    "actualCameraProof": {
        "path": "docs/production/evidence/PLAY-079/ACTUAL-CAMERA-PREDESIGN-PROOF.json",
        "sha256": "2f50758068b2ce39c6e4cbeb4828e35481740830a35048ffe233a90ab84b0738",
    },
}

EXPECTED_CAMERA = {
    "projection": "orthographic",
    "view": "southeast-looking-northwest",
    "citySimPosition": [96.0, 101.24557426726288, 96.0],
    "citySimTarget": [0.0, 22.861902498201186, 0.0],
    "blenderPosition": [96.0, 96.0, 101.24557426726288],
    "blenderTarget": [0.0, 0.0, 22.861902498201186],
    "orthoScale": 237.5878601074218,
    "shiftX": 0.0,
    "shiftY": 0.08333333333333333,
    "resolution": [1536, 1024],
    "literalResolution": [192, 128],
    "pixelAspect": [1.0, 1.0],
}
EXPECTED_SOCKET = {
    "citySim": [28.0, 0.0, 0.0],
    "blenderNative": [0.0, 28.0, 0.0],
    "sourcePixel": [896.0, 832.0],
}
EXPECTED_BRIDGE = {
    "acceptedSourceCandidateCommit": "3e01ca6738d7574718f9aeff4b66771eee109feb",
    "formula": "B(CitySim[x,y,z])=Blender[z,x,y]",
    "orientationTransform": "none",
    "perDirectionTransforms": False,
    "sourceOrder": [0, 1, 2, 3],
}
EXPECTED_OUTPUTS = {
    "sourceRoot": SOURCE_ROOT_RELATIVE,
    "evidenceRoot": EVIDENCE_ROOT_RELATIVE,
    "versionedSourceRoot": VERSION_SOURCE_ROOT_RELATIVE,
    "versionedEvidenceRoot": VERSION_EVIDENCE_ROOT_RELATIVE,
    "handoff": HANDOFF_RELATIVE,
    "proof": PROOF_RELATIVE,
}


def require_object(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject("contract_shape_invalid", f"{label}: expected object")
    return value


def load_json(payload: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(payload)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SuccessorRejected(f"{label}_json_invalid", error) from error
    return require_object(value, label)


def git_text(*arguments: str) -> str:
    completed = subprocess.run(
        ["git", *arguments],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        reject(
            "git_identity_unavailable",
            f"git {' '.join(arguments)}: {completed.stderr.strip()}",
        )
    return completed.stdout.strip()


def require_equal(actual: object, expected: object, code: str) -> None:
    if actual != expected:
        reject(code, f"{actual!r} != {expected!r}")


def validate_branch_and_ancestry() -> dict[str, object]:
    replay_branch = git_text("branch", "--show-current")
    if replay_branch not in ALLOWED_REPLAY_BRANCHES:
        reject("replay_branch_mismatch", replay_branch)
    head = git_text("rev-parse", "HEAD")
    if (
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", PUBLISHED_MASTER, head],
            cwd=REPOSITORY_ROOT,
            check=False,
            capture_output=True,
        ).returncode
        != 0
    ):
        reject("published_master_not_ancestor", f"{PUBLISHED_MASTER} !<= {head}")
    return {
        "authoredBranch": AUTHORED_BRANCH,
        "replayBranch": replay_branch,
        "publishedMaster": PUBLISHED_MASTER,
        "publishedMasterAncestorOfReplayHead": True,
    }


def validate_published_binding(
    name: str, declared: object, expected: dict[str, str]
) -> tuple[dict[str, str], bytes]:
    binding = require_object(declared, f"binding.{name}")
    require_equal(binding.get("path"), expected["path"], f"{name}_path_mismatch")
    require_equal(binding.get("sha256"), expected["sha256"], f"{name}_hash_mismatch")
    try:
        blob, tree = HARDENED.git_blob(
            PUBLISHED_MASTER, expected["path"], f"successor.{name}"
        )
        working = HARDENED.capture_repository_file(
            expected["path"], f"successor.{name}"
        )
    except HARDENED.ReplayRejected as error:
        raise SuccessorRejected(error.code, error.detail) from error
    blob_hash = sha256_bytes(blob)
    working_hash = sha256_bytes(working)
    require_equal(blob_hash, expected["sha256"], f"{name}_git_blob_hash_mismatch")
    require_equal(working_hash, expected["sha256"], f"{name}_working_hash_mismatch")
    return {
        "path": expected["path"],
        "sha256": expected["sha256"],
        "authorityCommit": PUBLISHED_MASTER,
        "gitMode": tree["mode"],
        "gitObjectId": tree["objectId"],
    }, working


def validate_output_path(value: object, label: str, expected: str) -> str:
    require_equal(value, expected, f"{label}_mismatch")
    if not isinstance(value, str):
        reject("unsafe_output_path", f"{label}: not a string")
    try:
        HARDENED.safe_repo_relative(value, label)
    except HARDENED.ReplayRejected as error:
        raise SuccessorRejected("unsafe_output_path", error.detail) from error
    if not value.startswith(EVIDENCE_ROOT_RELATIVE) and not value.startswith(
        SOURCE_ROOT_RELATIVE
    ):
        reject("unsafe_output_path", f"{label}: outside PLAY-079 East roots")
    current = REPOSITORY_ROOT
    for part in pathlib.PurePosixPath(value).parts:
        current = current / part
        if not current.exists() and not current.is_symlink():
            break
        if current.is_symlink():
            reject("unsafe_output_path", f"{label}: symlink component {part}")
    return value


def validate_contract(value: dict[str, Any]) -> dict[str, Any]:
    require_equal(
        value.get("schema"),
        "citysim.world-art.east-prelock-successor.v1",
        "schema_mismatch",
    )
    require_equal(value.get("schemaVersion"), 1, "schema_version_mismatch")
    require_equal(value.get("taskId"), "PLAY-079", "task_mismatch")
    require_equal(value.get("direction"), "east", "direction_mismatch")
    require_equal(value.get("authoredBranch"), AUTHORED_BRANCH, "branch_mismatch")
    require_equal(
        value.get("publishedMaster"), PUBLISHED_MASTER, "published_master_mismatch"
    )

    claim = require_object(value.get("claim"), "claim")
    require_equal(claim, EXPECTED_BINDINGS["claim"], "claim_hash_mismatch")
    validated_bindings: dict[str, dict[str, str]] = {}
    payloads: dict[str, bytes] = {}
    claim_binding, claim_payload = validate_published_binding(
        "claim", claim, EXPECTED_BINDINGS["claim"]
    )
    validated_bindings["claim"] = claim_binding
    payloads["claim"] = claim_payload

    bindings = require_object(value.get("bindings"), "bindings")
    require_equal(set(bindings), set(EXPECTED_BINDINGS) - {"claim"}, "bindings_mismatch")
    for name in sorted(bindings):
        validated, payload = validate_published_binding(
            name, bindings[name], EXPECTED_BINDINGS[name]
        )
        validated_bindings[name] = validated
        payloads[name] = payload

    accepted = require_object(value.get("acceptedPredesign"), "acceptedPredesign")
    require_equal(accepted, EXPECTED_ACCEPTED_PREDESIGN, "accepted_predesign_mismatch")
    for name in sorted(accepted):
        validated, payload = validate_published_binding(
            f"accepted{name[0].upper()}{name[1:]}",
            accepted[name],
            EXPECTED_ACCEPTED_PREDESIGN[name],
        )
        validated_bindings[f"acceptedPredesign.{name}"] = validated
        payloads[f"acceptedPredesign.{name}"] = payload

    require_equal(value.get("camera"), EXPECTED_CAMERA, "camera_mismatch")
    require_equal(value.get("socket"), EXPECTED_SOCKET, "socket_mismatch")
    require_equal(value.get("bridge"), EXPECTED_BRIDGE, "bridge_mismatch")
    outputs = require_object(value.get("outputs"), "outputs")
    for name, expected in EXPECTED_OUTPUTS.items():
        validate_output_path(outputs.get(name), f"outputs.{name}", expected)

    authority_inputs = require_object(
        value.get("authorityInputs"), "authorityInputs"
    )
    absent = {"state": "missing", "path": None, "commit": None, "sha256": None}
    require_equal(
        authority_inputs.get("appearanceLock"),
        absent,
        "appearance_lock_must_be_absent",
    )
    require_equal(
        authority_inputs.get("sourceProductionProfile"),
        absent,
        "source_profile_must_be_absent",
    )
    gates = require_object(value.get("gates"), "gates")
    expected_gates = {
        "sourceReady": False,
        "dccAllowed": False,
        "pixelRenderingAllowed": False,
        "productionSelected": False,
        "integrationAdmitted": False,
    }
    require_equal(gates, expected_gates, "closed_gates_mismatch")

    runner = load_json(payloads["runner"], "runner")
    scene = load_json(payloads["scene"], "scene")
    materials = load_json(payloads["materials"], "materials")
    mapping = load_json(payloads["bridgeMapping"], "bridgeMapping")
    schema = load_json(payloads["sourceStageSchema"], "sourceStageSchema")

    require_equal(runner.get("taskId"), "PLAY-079", "runner_task_mismatch")
    require_equal(runner.get("direction"), "east", "runner_direction_mismatch")
    require_equal(runner.get("sourceReady"), False, "runner_source_ready_open")
    require_equal(runner.get("productionSelected"), False, "runner_selected")
    require_equal(runner.get("appearanceLock"), {
        "documentPath": None,
        "commit": None,
        "documentSha256": None,
        "northProcessASourceSha256": None,
        "northProcessADecodedRgbaSha256": None,
    }, "runner_appearance_lock_present")
    source_stage = require_object(runner.get("sourceStage"), "runner.sourceStage")
    require_equal(
        source_stage.get("appearanceAuthority"),
        {
            "state": "missing",
            "publishedBaseline": None,
            "lockedMaterialMapping": None,
            "postLockProductionAuthority": None,
        },
        "runner_appearance_authority_present",
    )
    require_equal(
        source_stage.get("sourceProductionProfile"),
        absent,
        "runner_source_profile_present",
    )
    require_equal(
        source_stage.get("schema"),
        {
            "state": "BOUND_IMMUTABLE_V2",
            "path": EXPECTED_BINDINGS["sourceStageSchema"]["path"],
            "sha256": EXPECTED_BINDINGS["sourceStageSchema"]["sha256"],
            "authorityCommit": "9950906e8dbbc3cf48a0dc5b05e9a7d38b7a76d8",
        },
        "runner_schema_binding_mismatch",
    )
    invariants = require_object(runner.get("invariants"), "runner.invariants")
    require_equal(invariants.get("camera"), EXPECTED_CAMERA, "runner_camera_mismatch")
    registration = require_object(invariants.get("registration"), "registration")
    require_equal(
        registration.get("canonicalCitySimFrontageSocket"),
        EXPECTED_SOCKET["citySim"],
        "runner_citysim_socket_mismatch",
    )
    require_equal(
        registration.get("sourcePixelFrontageSocket"),
        EXPECTED_SOCKET["sourcePixel"],
        "runner_source_socket_mismatch",
    )
    coordinate_bridge = require_object(
        invariants.get("coordinateBridge"), "coordinateBridge"
    )
    require_equal(
        coordinate_bridge.get("blenderNativeEastSocket"),
        EXPECTED_SOCKET["blenderNative"],
        "runner_blender_socket_mismatch",
    )
    require_equal(
        coordinate_bridge.get("basis", {}).get("perDirectionTransforms"),
        False,
        "runner_direction_transform_present",
    )

    require_equal(scene.get("task"), "PLAY-079", "scene_task_mismatch")
    require_equal(scene.get("direction"), "east", "scene_direction_mismatch")
    require_equal(
        scene.get("orientationTransform"), "none", "scene_orientation_transform"
    )
    require_equal(
        scene.get("registration", {}).get("frontageSocket"),
        EXPECTED_SOCKET["citySim"],
        "scene_socket_mismatch",
    )
    require_equal(
        scene.get("registration", {})
        .get("expectedSourcePixels", {})
        .get("frontageSocket"),
        EXPECTED_SOCKET["sourcePixel"],
        "scene_source_socket_mismatch",
    )
    scene_camera = require_object(scene.get("camera"), "scene.camera")
    for key in (
        "projection",
        "view",
        "orthoScale",
        "shiftX",
        "shiftY",
        "resolution",
        "literalResolution",
        "pixelAspect",
    ):
        require_equal(scene_camera.get(key), EXPECTED_CAMERA[key], "scene_camera_mismatch")

    require_equal(materials.get("task"), "PLAY-079", "materials_task_mismatch")
    require_equal(materials.get("direction"), "east", "materials_direction_mismatch")
    require_equal(materials.get("sourceAuthority"), False, "materials_source_authority")
    require_equal(
        materials.get("pixelRenderingAllowed"), False, "materials_pixel_gate_open"
    )
    require_equal(mapping.get("basis", {}).get("formula"), EXPECTED_BRIDGE["formula"], "bridge_formula_mismatch")
    require_equal(
        mapping.get("basis", {}).get("perDirectionTransforms"),
        False,
        "bridge_direction_transform_present",
    )
    require_equal(
        mapping.get("directions", {}).get("east", {}).get("socketCitySim"),
        [28, 0, 0],
        "bridge_citysim_socket_mismatch",
    )
    require_equal(
        mapping.get("directions", {}).get("east", {}).get("socketBlender"),
        [0, 28, 0],
        "bridge_blender_socket_mismatch",
    )
    require_equal(
        mapping.get("directions", {}).get("east", {}).get("socketSource"),
        [896, 832],
        "bridge_source_socket_mismatch",
    )
    require_equal(
        schema.get("$id"),
        "citysim://integration/industrial-l04-source-stage-handoff-v2",
        "source_stage_schema_identity_mismatch",
    )

    pixels = []
    for root in (VERSION_ROOT, REPOSITORY_ROOT / VERSION_EVIDENCE_ROOT_RELATIVE):
        if root.exists():
            pixels.extend(
                sorted(
                    str(path.relative_to(REPOSITORY_ROOT))
                    for path in root.rglob("*")
                    if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES
                )
            )
    if pixels:
        reject("successor_pixel_file_present", pixels)
    return {
        "status": "PASS",
        "identity": {
            "taskId": "PLAY-079",
            "direction": "east",
            **validate_branch_and_ancestry(),
        },
        "bindings": validated_bindings,
        "camera": EXPECTED_CAMERA,
        "socket": EXPECTED_SOCKET,
        "orientationTransform": "none",
        "appearanceLockState": "missing",
        "sourceProductionProfileState": "missing",
        "sourceReady": False,
        "dccAllowed": False,
        "pixelRenderingAllowed": False,
        "pixelFiles": pixels,
    }


def set_pointer(value: dict[str, Any], pointer: tuple[str, ...], replacement: object) -> None:
    current: Any = value
    for part in pointer[:-1]:
        current = current[part]
    current[pointer[-1]] = replacement


def adversarial_cases(contract: dict[str, Any]) -> list[dict[str, str]]:
    cases = [
        ("stale_master", ("publishedMaster",), "0" * 40, "published_master_mismatch"),
        (
            "stale_harness",
            ("bindings", "hardenedReplay", "sha256"),
            "0" * 64,
            "hardenedReplay_hash_mismatch",
        ),
        (
            "stale_runner",
            ("bindings", "runner", "sha256"),
            "0" * 64,
            "runner_hash_mismatch",
        ),
        ("wrong_claim", ("claim", "sha256"), "0" * 64, "claim_hash_mismatch"),
        (
            "wrong_bridge",
            ("bindings", "bridgeMapping", "sha256"),
            "0" * 64,
            "bridgeMapping_hash_mismatch",
        ),
        (
            "wrong_socket",
            ("socket", "citySim"),
            [-28.0, 0.0, 0.0],
            "socket_mismatch",
        ),
        (
            "sibling_path",
            ("outputs", "versionedEvidenceRoot"),
            "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/",
            "outputs.versionedEvidenceRoot_mismatch",
        ),
        (
            "orientation_transform",
            ("bridge", "orientationTransform"),
            "rotate-90",
            "bridge_mismatch",
        ),
        (
            "unsafe_output",
            ("outputs", "proof"),
            f"{EVIDENCE_ROOT_RELATIVE}../PLAY-080/PROOF.json",
            "outputs.proof_mismatch",
        ),
        (
            "appearance_lock_injected",
            ("authorityInputs", "appearanceLock", "state"),
            "present",
            "appearance_lock_must_be_absent",
        ),
        (
            "source_profile_injected",
            ("authorityInputs", "sourceProductionProfile", "state"),
            "present",
            "source_profile_must_be_absent",
        ),
    ]
    results = []
    for name, pointer, replacement, expected_code in cases:
        mutated = copy.deepcopy(contract)
        set_pointer(mutated, pointer, replacement)
        try:
            validate_contract(mutated)
        except SuccessorRejected as error:
            require_equal(error.code, expected_code, f"{name}_wrong_rejection")
            results.append({"case": name, "result": "REJECTED", "code": error.code})
        else:
            reject("adversary_accepted", name)
    return results


def validate_implementation(commit: str) -> dict[str, dict[str, str]]:
    if not commit or len(commit) != 40:
        reject("implementation_commit_invalid", commit)
    if (
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", PUBLISHED_MASTER, commit],
            cwd=REPOSITORY_ROOT,
            check=False,
            capture_output=True,
        ).returncode
        != 0
    ):
        reject("implementation_not_descendant", commit)
    result = {}
    for label, relative in (
        ("contract", CONTRACT_RELATIVE),
        ("validator", SCRIPT_RELATIVE),
    ):
        try:
            blob, tree = HARDENED.git_blob(commit, relative, f"implementation.{label}")
            working = HARDENED.capture_repository_file(
                relative, f"implementation.{label}"
            )
        except HARDENED.ReplayRejected as error:
            raise SuccessorRejected(error.code, error.detail) from error
        require_equal(
            sha256_bytes(working),
            sha256_bytes(blob),
            f"implementation_{label}_working_mismatch",
        )
        result[label] = {
            "path": relative,
            "sha256": sha256_bytes(blob),
            "commit": commit,
            "gitMode": tree["mode"],
            "gitObjectId": tree["objectId"],
        }
    return result


def build_bundle(contract: dict[str, Any], implementation_commit: str) -> dict[str, Any]:
    first = validate_contract(contract)
    second = validate_contract(contract)
    first_bytes = canonical_bytes(first)
    second_bytes = canonical_bytes(second)
    require_equal(first_bytes, second_bytes, "repeat_validation_byte_mismatch")
    negatives = adversarial_cases(contract)
    implementation = validate_implementation(implementation_commit)
    contract_hash = implementation["contract"]["sha256"]
    validation_hash = sha256_bytes(first_bytes)
    common = {
        "schemaVersion": 1,
        "taskId": "PLAY-079",
        "direction": "east",
        "publishedMaster": PUBLISHED_MASTER,
        "authoredBranch": AUTHORED_BRANCH,
        "replayBranch": first["identity"]["replayBranch"],
        "implementationCommit": implementation_commit,
        "contract": implementation["contract"],
        "validator": implementation["validator"],
    }
    handoff = {
        "schema": "citysim.world-art.east-prelock-successor-handoff.v1",
        **common,
        "stage": "prelock_successor",
        "state": "BLOCKED_MISSING_APPEARANCE_LOCK_AND_SOURCE_PRODUCTION_PROFILE",
        "sourceReady": False,
        "candidateReadyForIndependentReview": False,
        "integrationAdmitted": False,
        "productionSelected": False,
        "authorities": first["bindings"],
        "camera": first["camera"],
        "socket": first["socket"],
        "orientationTransform": "none",
        "appearanceLock": {"state": "missing", "path": None, "commit": None, "sha256": None},
        "sourceProductionProfile": {
            "state": "missing",
            "path": None,
            "commit": None,
            "sha256": None,
        },
        "gates": {
            "dccAllowed": False,
            "pixelRenderingAllowed": False,
            "sourceReady": False,
        },
        "invocationCounts": {
            "blender": 0,
            "dcc": 0,
            "imageGen": 0,
            "normalizer": 0,
            "render": 0,
            "sourceProcessA": 0,
            "sourceProcessB": 0,
            "sourceProcessC": 0,
        },
        "outputs": {
            "sourceA": None,
            "sourceB": None,
            "sourceC": None,
            "pixelFiles": [],
        },
        "blockers": [
            "Integration-published Industrial L4 appearance lock is absent.",
            "Integration-published East source-production profile is absent.",
        ],
    }
    proof = {
        "schema": "citysim.world-art.east-prelock-successor-proof.v1",
        **common,
        "status": "PASS_ZERO_PIXEL_PRELOCK_BLOCKED",
        "contractSha256": contract_hash,
        "repeatValidation": {
            "runs": 2,
            "byteIdentical": True,
            "runSha256": [validation_hash, validation_hash],
        },
        "adversarialCases": negatives,
        "adversarialRejectedCount": len(negatives),
        "captureProtectionsInheritedFromHardenedReplay": {
            "parentDirectoryDescriptors": True,
            "oNoFollow": True,
            "beforeAfterFstat": True,
            "postReadLstat": True,
            "gitMode120000Rejected": True,
        },
        "acceptedPredesignPreserved": {
            "sceneSha256": EXPECTED_BINDINGS["scene"]["sha256"],
            "materialsSha256": EXPECTED_BINDINGS["materials"]["sha256"],
            "validatorSha256": EXPECTED_BINDINGS["predesignValidator"]["sha256"],
            "handoffSha256": EXPECTED_ACCEPTED_PREDESIGN["handoff"]["sha256"],
            "staticProofSha256": EXPECTED_ACCEPTED_PREDESIGN["staticProof"]["sha256"],
            "actualCameraProofSha256": EXPECTED_ACCEPTED_PREDESIGN["actualCameraProof"]["sha256"],
        },
        "authorityAbsenceProof": {
            "appearanceLock": "missing",
            "sourceProductionProfile": "missing",
            "sourceReady": False,
            "dccAllowed": False,
            "pixelRenderingAllowed": False,
        },
        "invocationCounts": handoff["invocationCounts"],
        "pixelFiles": [],
    }
    return {"handoff": handoff, "proof": proof}


def validate_evidence(
    bundle: dict[str, Any], evidence_commit: str
) -> dict[str, dict[str, str]]:
    result = {}
    for label, relative, expected in (
        ("handoff", HANDOFF_RELATIVE, bundle["handoff"]),
        ("proof", PROOF_RELATIVE, bundle["proof"]),
    ):
        expected_bytes = canonical_bytes(expected)
        try:
            blob, tree = HARDENED.git_blob(
                evidence_commit, relative, f"evidence.{label}"
            )
            working = HARDENED.capture_repository_file(relative, f"evidence.{label}")
        except HARDENED.ReplayRejected as error:
            raise SuccessorRejected(error.code, error.detail) from error
        require_equal(blob, expected_bytes, f"{label}_evidence_content_mismatch")
        require_equal(working, expected_bytes, f"{label}_working_content_mismatch")
        result[label] = {
            "path": relative,
            "sha256": sha256_bytes(blob),
            "commit": evidence_commit,
            "gitMode": tree["mode"],
            "gitObjectId": tree["objectId"],
        }
    return result


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        choices=("validate", "self-test", "bundle", "verify-evidence"),
        default="validate",
    )
    parser.add_argument("--implementation-commit")
    parser.add_argument("--evidence-commit")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        contract = load_json(
            HARDENED.capture_repository_file(CONTRACT_RELATIVE, "successorContract"),
            "successorContract",
        )
        if arguments.mode == "validate":
            output: object = validate_contract(contract)
        elif arguments.mode == "self-test":
            output = {
                "status": "PASS",
                "cases": adversarial_cases(contract),
                "invocationCounts": {"dcc": 0, "render": 0, "pixels": 0},
            }
        else:
            if not arguments.implementation_commit:
                reject("implementation_commit_required", arguments.mode)
            bundle = build_bundle(contract, arguments.implementation_commit)
            if arguments.mode == "bundle":
                output = bundle
            else:
                if not arguments.evidence_commit:
                    reject("evidence_commit_required", arguments.mode)
                output = {
                    "status": "PASS",
                    "evidence": validate_evidence(
                        bundle, arguments.evidence_commit
                    ),
                }
        sys.stdout.buffer.write(canonical_bytes(output))
        return 0
    except (SuccessorRejected, HARDENED.ReplayRejected) as error:
        sys.stderr.buffer.write(
            canonical_bytes(
                {
                    "status": "REJECTED",
                    "code": error.code,
                    "detail": error.detail,
                }
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
