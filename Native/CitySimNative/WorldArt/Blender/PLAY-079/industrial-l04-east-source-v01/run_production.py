#!/usr/bin/env python3
"""Hard-guarded PLAY-079 East production entry point.

The ordinary Python process validates all frozen inputs and the exact
Integration-published appearance lock before it may launch Blender. The
Blender worker repeats the same guard before importing bpy or calling a render
API. With the pre-lock contract committed in this directory, A/B/C always
fail closed.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import pathlib
import subprocess
import sys
from typing import Any, Callable, Iterable


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
CONTRACT_PATH = SOURCE_ROOT / "RUNNER-CONTRACT.json"
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]


class GuardRejected(RuntimeError):
    """Expected fail-closed production guard rejection."""

    def __init__(self, code: str, detail: str):
        super().__init__(detail)
        self.code = code
        self.detail = detail


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json(path: pathlib.Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise GuardRejected("invalid_json_input", f"{path}: {error}") from error
    if not isinstance(value, dict):
        raise GuardRejected("invalid_json_input", f"{path}: expected object")
    return value


def repository_path(relative: str) -> pathlib.Path:
    path = (REPOSITORY_ROOT / relative).resolve()
    try:
        path.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise GuardRejected("path_escape", relative) from error
    return path


def load_frozen_shared_module(
    record: dict[str, str],
    module_name: str,
) -> Any:
    path = repository_path(record["path"])
    digest = sha256_bytes(path.read_bytes())
    if digest != record["sha256"]:
        raise GuardRejected(
            "shared_tool_hash_mismatch",
            f"{record['path']}: expected {record['sha256']}, got {digest}",
        )
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise GuardRejected("shared_tool_load_failed", record["path"])
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def validate_frozen_inputs(contract: dict[str, Any]) -> dict[str, str]:
    records: list[dict[str, str]] = []
    records.extend(contract["authorities"].values())
    accepted = contract["acceptedPredesign"]
    records.extend(
        accepted[key]
        for key in ("handoff", "scene", "materials", "validator", "staticProof", "actualCameraProof")
    )
    actual: dict[str, str] = {}
    for record in records:
        path = repository_path(record["path"])
        try:
            digest = sha256_bytes(path.read_bytes())
        except OSError as error:
            raise GuardRejected("missing_frozen_input", str(path)) from error
        if digest != record["sha256"]:
            raise GuardRejected(
                "frozen_hash_mismatch",
                f"{record['path']}: expected {record['sha256']}, got {digest}",
            )
        actual[record["path"]] = digest
    if accepted["orientationTransform"] != "none" or accepted["siblingInputs"]:
        raise GuardRejected("direction_independence_failed", "East predesign provenance changed")
    return actual


def validate_contract(contract: dict[str, Any]) -> dict[str, Any]:
    if contract.get("taskId") != "PLAY-079":
        raise GuardRejected("contract_task_mismatch", str(contract.get("taskId")))
    if contract.get("direction") != "east":
        raise GuardRejected("contract_direction_mismatch", str(contract.get("direction")))
    if contract.get("branch") != "codex/citysim-world-art-east":
        raise GuardRejected("contract_branch_mismatch", str(contract.get("branch")))
    if contract.get("baselineCommit") != "9950906e8dbbc3cf48a0dc5b05e9a7d38b7a76d8":
        raise GuardRejected("contract_baseline_mismatch", str(contract.get("baselineCommit")))
    if contract.get("sourceReady") or contract.get("productionSelected"):
        raise GuardRejected("unauthorized_disposition", "pre-lock runner cannot claim source/production")
    if contract.get("processModes") != ["validate", "A", "B", "C"]:
        raise GuardRejected("process_mode_contract_mismatch", str(contract.get("processModes")))

    invariants = contract["invariants"]
    registration = invariants["registration"]
    if registration["canonicalCitySimDirection"] != "east":
        raise GuardRejected(
            "canonical_direction_mismatch",
            str(registration["canonicalCitySimDirection"]),
        )
    if registration["canonicalCitySimFrontageSocket"] != [28.0, 0.0, 0.0]:
        raise GuardRejected(
            "canonical_citysim_socket_mismatch",
            str(registration["canonicalCitySimFrontageSocket"]),
        )
    if registration["sourcePixelFrontageSocket"] != [896.0, 832.0]:
        raise GuardRejected(
            "source_pixel_socket_mismatch",
            str(registration["sourcePixelFrontageSocket"]),
        )
    bridge = invariants["coordinateBridge"]
    if bridge["canonicalCitySimEastSocket"] != [28.0, 0.0, 0.0]:
        raise GuardRejected(
            "coordinate_bridge_citysim_socket_mismatch",
            str(bridge["canonicalCitySimEastSocket"]),
        )
    if bridge["sourcePixelEastSocket"] != [896.0, 832.0]:
        raise GuardRejected(
            "coordinate_bridge_source_socket_mismatch",
            str(bridge["sourcePixelEastSocket"]),
        )
    historical = bridge["historicalPredesignProjectionAdapter"]
    if historical["path"] != contract["acceptedPredesign"]["scene"]["path"]:
        raise GuardRejected(
            "historical_projection_adapter_path_mismatch",
            str(historical["path"]),
        )
    if historical["sha256"] != contract["acceptedPredesign"]["scene"]["sha256"]:
        raise GuardRejected(
            "historical_projection_adapter_hash_mismatch",
            str(historical["sha256"]),
        )
    if historical["futureSourceAuthority"] is not False:
        raise GuardRejected(
            "historical_projection_adapter_promoted",
            "accepted predesign projection adapter is not future source authority",
        )
    cycles = invariants["cycles"]
    expected_cycles = {
        "engine": "CYCLES",
        "device": "CPU",
        "threads": 1,
        "seed": 2704,
        "samples": 64,
        "adaptiveSampling": False,
        "denoising": False,
        "motionBlur": False,
        "transparentFilm": True,
        "maxBounces": 4,
    }
    if cycles != expected_cycles:
        raise GuardRejected("cycles_invariant_mismatch", str(cycles))
    source_stage = validate_source_stage_binding(contract)
    return {
        "taskId": contract["taskId"],
        "direction": contract["direction"],
        "baselineCommit": contract["baselineCommit"],
        "frozenHashes": validate_frozen_inputs(contract),
        "sourceStage": source_stage,
    }


def validate_artifact_record(record: dict[str, Any], code: str) -> str:
    path = repository_path(record["path"])
    try:
        digest = sha256_bytes(path.read_bytes())
    except OSError as error:
        raise GuardRejected(f"{code}_missing", str(path)) from error
    if digest != record["sha256"]:
        raise GuardRejected(
            f"{code}_hash_mismatch",
            f"{record['path']}: expected {record['sha256']}, got {digest}",
        )
    return digest


def validate_non_alias_input(contract: dict[str, Any]) -> dict[str, Any]:
    source_stage = contract["sourceStage"]
    binding = source_stage["nonAliasInput"]
    if binding != {
        "path": "docs/production/evidence/INTEGRATION/"
        "industrial-l04-accepted-master-non-alias-input-v1.json",
        "sha256": "c281dd8f3527363ad3ff56746f50e9110b2166898bdf4918ed628b5a429d27fb",
        "acceptedMasterCount": 44,
        "forbiddenSetSha256": "265c564785a5fa4ce14fbd04898ef04aaed883e2ca56f6a0660a9937464926ea",
    }:
        raise GuardRejected("non_alias_binding_mismatch", str(binding))
    loader = load_frozen_shared_module(
        contract["authorities"]["nonAliasLoader"],
        "citysim_shared_non_alias_v1",
    )
    try:
        forbidden = loader.load_forbidden_decoded_rgba(REPOSITORY_ROOT)
    except Exception as error:
        raise GuardRejected("shared_non_alias_loader_rejected", str(error)) from error
    if len(forbidden) != binding["acceptedMasterCount"]:
        raise GuardRejected("non_alias_forbidden_count_mismatch", str(len(forbidden)))
    forbidden_digest = sha256_bytes(
        "".join(f"{value}\n" for value in sorted(forbidden)).encode("ascii")
    )
    if forbidden_digest != binding["forbiddenSetSha256"]:
        raise GuardRejected(
            "non_alias_forbidden_set_hash_mismatch",
            f"expected {binding['forbiddenSetSha256']}, got {forbidden_digest}",
        )
    return {
        "result": "PASS",
        "path": binding["path"],
        "sha256": binding["sha256"],
        "acceptedMasterCount": 44,
        "forbiddenDecodedRgbaSha256Count": 44,
        "forbiddenSetSha256": forbidden_digest,
        "loaderPath": contract["authorities"]["nonAliasLoader"]["path"],
        "loaderSha256": contract["authorities"]["nonAliasLoader"]["sha256"],
        "sourceAcceptance": False,
        "rendererAdmission": False,
        "shippingActivation": False,
        "productionSelection": False,
    }


def validate_source_stage_binding(contract: dict[str, Any]) -> dict[str, Any]:
    source_stage = contract["sourceStage"]
    schema_binding = source_stage["schema"]
    expected_identity = {
        "taskId": "PLAY-079",
        "direction": "east",
        "branch": "codex/citysim-world-art-east",
        "family": "industrial",
        "level": 4,
        "variant": 0,
        "logicalID": "industrial_l04_v0_east",
        "sourceKey": "industrial_l04/variant-0/east/source-v01",
        "sourceRoot": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/"
        ),
        "evidenceRoot": (
            "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
        ),
        "orientationTransform": "none",
        "fallbackSourceKey": None,
    }
    if source_stage.get("stage") != "launch_bound":
        raise GuardRejected("source_stage_mismatch", str(source_stage.get("stage")))
    if source_stage.get("identity") != expected_identity:
        raise GuardRejected("source_stage_identity_mismatch", str(source_stage.get("identity")))
    expected_schema = {
        "state": "BOUND_IMMUTABLE_V2",
        "path": (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-source-stage-handoff-schema-v2.json"
        ),
        "sha256": "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7",
        "authorityCommit": "9950906e8dbbc3cf48a0dc5b05e9a7d38b7a76d8",
    }
    if schema_binding != expected_schema:
        raise GuardRejected("source_stage_schema_v2_binding_mismatch", str(schema_binding))
    if {
        "path": schema_binding["path"],
        "sha256": schema_binding["sha256"],
    } != contract["authorities"]["sourceStageSchemaV2"]:
        raise GuardRejected("source_stage_schema_v2_authority_mismatch", str(schema_binding))
    validate_artifact_record(contract["authorities"]["sourceStageSchemaV2"], "source_stage_schema_v2")
    schema = load_json(repository_path(schema_binding["path"]))
    if schema.get("$id") != "citysim://integration/industrial-l04-source-stage-handoff-v2":
        raise GuardRejected("source_stage_schema_v2_id_mismatch", str(schema.get("$id")))
    if source_stage["nonAliasInput"]["path"] != contract["authorities"]["nonAliasInput"]["path"]:
        raise GuardRejected(
            "source_stage_non_alias_path_mismatch",
            str(source_stage["nonAliasInput"]),
        )
    if source_stage["nonAliasInput"]["sha256"] != contract["authorities"]["nonAliasInput"]["sha256"]:
        raise GuardRejected(
            "source_stage_non_alias_hash_mismatch",
            str(source_stage["nonAliasInput"]),
        )
    if source_stage["frozenInputManifest"] != contract["authorities"][
        "sourceStageFrozenInputManifest"
    ]:
        raise GuardRejected(
            "source_stage_frozen_manifest_mismatch",
            str(source_stage["frozenInputManifest"]),
        )
    if source_stage["handoffOutputPath"] != (
        "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
        "SOURCE-STAGE-HANDOFF.json"
    ):
        raise GuardRejected(
            "source_stage_output_path_mismatch",
            str(source_stage["handoffOutputPath"]),
        )
    return {
        "result": "PASS",
        "stage": "launch_bound",
        "schemaState": "BOUND_IMMUTABLE_V2",
        "schemaPath": schema_binding["path"],
        "schemaSha256": schema_binding["sha256"],
        "schemaAuthorityCommit": schema_binding["authorityCommit"],
        "handoffOutputPath": source_stage["handoffOutputPath"],
        "handoffEmission": "blocked_missing_source_production_profile",
        "identity": expected_identity,
        "nonAlias": validate_non_alias_input(contract),
        "sourceReady": False,
        "productionSelected": False,
    }


def validate_appearance_lock(
    contract: dict[str, Any],
    appearance_lock_path: pathlib.Path | None,
) -> dict[str, Any]:
    binding = contract["appearanceLock"]
    required_binding = (
        "documentPath",
        "commit",
        "documentSha256",
        "northProcessASourceSha256",
        "northProcessADecodedRgbaSha256",
    )
    if appearance_lock_path is None:
        raise GuardRejected("missing_appearance_lock", "no --appearance-lock was supplied")
    if any(binding.get(key) is None for key in required_binding):
        raise GuardRejected(
            "unpublished_or_wrong_appearance_lock",
            "runner contract has no Integration-published appearance-lock binding",
        )
    if contract.get("appearanceLockCommit") != binding["commit"]:
        raise GuardRejected("appearance_lock_commit_mismatch", "top-level and bound lock commit differ")
    if contract.get("appearanceLockSha256") != binding["documentSha256"]:
        raise GuardRejected("appearance_lock_hash_mismatch", "top-level and bound lock hash differ")
    mapping_digest = contract.get("lockedMaterialMappingSha256")
    if mapping_digest is None:
        raise GuardRejected("missing_locked_material_mapping", "material mapping is not bound")

    expected_path = repository_path(binding["documentPath"])
    candidate_path = appearance_lock_path.resolve()
    if candidate_path != expected_path:
        raise GuardRejected(
            "wrong_appearance_lock_path",
            f"expected {expected_path}, got {candidate_path}",
        )
    try:
        candidate_bytes = candidate_path.read_bytes()
    except OSError as error:
        raise GuardRejected("missing_appearance_lock", str(candidate_path)) from error
    candidate_digest = sha256_bytes(candidate_bytes)
    if candidate_digest != binding["documentSha256"]:
        raise GuardRejected(
            "wrong_appearance_lock_hash",
            f"expected {binding['documentSha256']}, got {candidate_digest}",
        )
    lock = load_json(candidate_path)
    if lock.get("commit") != binding["commit"]:
        raise GuardRejected("wrong_appearance_lock_commit", str(lock.get("commit")))
    north = lock.get("northProcessA")
    if not isinstance(north, dict):
        raise GuardRejected("missing_north_process_a", "lock has no northProcessA object")
    if north.get("sourceSha256") != binding["northProcessASourceSha256"]:
        raise GuardRejected("wrong_north_source_hash", str(north.get("sourceSha256")))
    if north.get("decodedRgbaSha256") != binding["northProcessADecodedRgbaSha256"]:
        raise GuardRejected("wrong_north_rgba_hash", str(north.get("decodedRgbaSha256")))
    mapping = lock.get("materialRoleMapping")
    if not isinstance(mapping, dict) or not mapping:
        raise GuardRejected("missing_locked_material_mapping", "lock has no materialRoleMapping")
    if sha256_bytes(canonical_bytes(mapping)) != mapping_digest:
        raise GuardRejected("wrong_material_mapping_hash", "locked material mapping differs")
    return lock


def validate_source_production_profile(contract: dict[str, Any]) -> dict[str, Any]:
    binding = contract["sourceStage"]["sourceProductionProfile"]
    if binding.get("state") == "missing":
        raise GuardRejected(
            "missing_source_production_profile",
            "Integration has not published the Industrial L4 source-production profile",
        )
    if binding.get("state") != "bound":
        raise GuardRejected("stale_source_production_profile", str(binding.get("state")))
    record = {key: binding.get(key) for key in ("path", "commit", "sha256")}
    if any(record[key] is None for key in record):
        raise GuardRejected("stale_source_production_profile", str(binding))
    if not str(record["path"]).startswith("docs/production/evidence/INTEGRATION/"):
        raise GuardRejected("wrong_source_production_profile_path", str(record["path"]))
    validate_artifact_record(
        {"path": str(record["path"]), "sha256": str(record["sha256"])},
        "source_production_profile",
    )
    profile = load_json(repository_path(str(record["path"])))
    if profile.get("schema") != "citysim.integration.world-art-source-production-profile.v1":
        raise GuardRejected("source_production_profile_schema_mismatch", str(profile.get("schema")))
    return {
        "path": str(record["path"]),
        "commit": str(record["commit"]),
        "sha256": str(record["sha256"]),
        "profile": profile,
    }


def validate_appearance_authority(
    contract: dict[str, Any],
    appearance_lock_path: pathlib.Path | None,
) -> dict[str, Any]:
    source_stage = contract["sourceStage"]
    authority = source_stage["appearanceAuthority"]
    if appearance_lock_path is None:
        raise GuardRejected(
            "missing_appearance_authority",
            "no Integration-published appearance authority was supplied",
        )
    if authority.get("state") != "bound":
        raise GuardRejected(
            "stale_appearance_authority",
            "runner is not bound to a current Integration-published appearance authority",
        )
    if authority.get("publishedBaseline") != contract["baselineCommit"]:
        raise GuardRejected(
            "stale_appearance_authority",
            "appearance authority baseline differs from the runner baseline",
        )
    locked_mapping = authority.get("lockedMaterialMapping")
    post_lock = authority.get("postLockProductionAuthority")
    if not isinstance(locked_mapping, dict) or not isinstance(post_lock, dict):
        raise GuardRejected(
            "stale_appearance_authority",
            "locked material mapping or post-lock production authority is absent",
        )
    validate_artifact_record(locked_mapping, "locked_material_mapping")
    validate_artifact_record(post_lock, "post_lock_production_authority")
    lock = validate_appearance_lock(contract, appearance_lock_path)
    return {
        "appearanceLock": lock,
        "lockedMaterialMapping": locked_mapping,
        "postLockProductionAuthority": post_lock,
    }


def validate_source_stage_authority(
    contract: dict[str, Any],
    appearance_lock_path: pathlib.Path | None,
) -> dict[str, Any]:
    profile = validate_source_production_profile(contract)
    appearance = validate_appearance_authority(contract, appearance_lock_path)
    return {
        **appearance,
        "sourceProductionProfile": profile,
    }


def build_source_stage_handoff(
    contract: dict[str, Any],
    appearance_lock_path: pathlib.Path | None,
    guard_receipt_path: pathlib.Path,
    cell_candidate_commit: str,
) -> dict[str, Any]:
    """Build, but do not write, the future immutable-v2 launch-bound packet."""

    if contract["sourceStage"]["schema"].get("state") != "BOUND_IMMUTABLE_V2":
        raise GuardRejected(
            "source_stage_schema_v2_pending",
            "immutable source-stage schema v2 path/hash/authority commit are not published",
        )
    if len(cell_candidate_commit) != 40 or any(
        character not in "0123456789abcdef" for character in cell_candidate_commit
    ):
        raise GuardRejected("invalid_cell_candidate_commit", cell_candidate_commit)
    source_stage = validate_source_stage_binding(contract)
    authority = validate_source_stage_authority(contract, appearance_lock_path)
    expected_receipt = repository_path(contract["sourceStage"]["guardReceiptPath"])
    if guard_receipt_path.resolve() != expected_receipt:
        raise GuardRejected(
            "wrong_source_stage_guard_receipt_path",
            f"expected {expected_receipt}, got {guard_receipt_path.resolve()}",
        )
    receipt = load_json(expected_receipt)
    if (
        receipt.get("schema") != "citysim.world-art.source-stage-launch-guard.v1"
        or receipt.get("result") != "PASS"
        or receipt.get("appearanceAuthorityResult") != "PASS"
        or receipt.get("schemaValidationResult") != "PASS"
        or receipt.get("nonAliasInputResult") != "PASS"
    ):
        raise GuardRejected("source_stage_guard_receipt_failed", str(receipt.get("result")))
    if receipt.get("sourceReady") is not False or receipt.get("productionSelected") is not False:
        raise GuardRejected("source_stage_guard_receipt_disposition", str(receipt))

    receipt_record = {
        "path": str(expected_receipt.relative_to(REPOSITORY_ROOT)),
        "sha256": sha256_bytes(expected_receipt.read_bytes()),
    }
    bridge = contract["invariants"]["coordinateBridge"]["v06"]
    launch_root = contract["outputInventory"]["root"]
    prelaunch_path = repository_path(contract["sourceStage"]["prelaunchHandoff"]["path"])
    prelaunch_record = {
        "path": str(prelaunch_path.relative_to(REPOSITORY_ROOT)),
        "sha256": sha256_bytes(prelaunch_path.read_bytes()),
    }
    packet = {
        "schemaVersion": 2,
        "stage": "launch_bound",
        "identity": source_stage["identity"],
        "lineage": {
            "publishedBaseline": contract["baselineCommit"],
            "cellContentCommit": cell_candidate_commit,
        },
        "authorities": {
            "contract010": contract["authorities"]["contract010"],
            "contract021": {
                **contract["authorities"]["contract021"],
                "revision": 2,
            },
            "directionBridge": {
                "documentPath": contract["authorities"]["bridgeV06Acceptance"]["path"],
                "sourceCandidate": bridge["commit"],
                "integratedProofCommit": "3d76fab8a45807c34198a6d8bb1dd1eeff7be51e",
                "documentSha256": contract["authorities"]["bridgeV06Acceptance"]["sha256"],
                "mappingContractSha256": bridge["mappingContractSha256"],
                "coordinateSystem": "citysim_source_pixels_v1",
            },
            "appearanceLock": contract["appearanceLock"],
            "lockedMaterialMapping": authority["lockedMaterialMapping"],
            "sourceProductionProfile": {
                key: authority["sourceProductionProfile"][key]
                for key in ("path", "commit", "sha256")
            },
            "nonAliasInput": {
                "path": contract["sourceStage"]["nonAliasInput"]["path"],
                "sha256": contract["sourceStage"]["nonAliasInput"]["sha256"],
                "forbiddenDecodedRgbaSha256Count": 44,
                "forbiddenSetSha256": contract["sourceStage"]["nonAliasInput"][
                    "forbiddenSetSha256"
                ],
            },
            "nonAliasLoader": contract["authorities"]["nonAliasLoader"],
            "semanticValidator": contract["authorities"]["sourceStageSemanticValidator"],
            "canonicalDecoder": contract["authorities"]["canonicalDecoder"],
        },
        "inputs": {
            "prelaunchHandoff": prelaunch_record,
            "frozenInputManifest": contract["sourceStage"]["frozenInputManifest"],
            "runnerContract": {
                "path": str(CONTRACT_PATH.relative_to(REPOSITORY_ROOT)),
                "sha256": sha256_bytes(CONTRACT_PATH.read_bytes()),
            },
            "outputRoot": launch_root,
        },
        "launch": {
            "guardReceipt": receipt_record,
            "result": "PASS",
            "authorizedProcesses": ["A", "B", "C"],
            "isolatedOutputRoots": {
                "A": f"{launch_root}renders/process-a/",
                "B": f"{launch_root}renders/process-b/",
                "C": f"{launch_root}renders/process-c/",
            },
            "allOutputRootsDistinct": True,
            "outputRootIsolationReceipt": receipt_record,
        },
        "completion": None,
        "candidateReadyForIndependentReview": False,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }
    return packet


def validate_coordinate_bridge(contract: dict[str, Any]) -> dict[str, Any]:
    bridge = contract["invariants"]["coordinateBridge"]
    if bridge["state"] != "validated_v06":
        raise GuardRejected(
            "coordinate_bridge_pending_v06",
            "direction projection and Blender coordinate bridge require v06 revalidation",
        )
    binding = bridge["v06"]
    required = (
        "authorityPath",
        "commit",
        "documentSha256",
        "mappingContractPath",
        "mappingContractSha256",
        "blenderNativeDirectionalSocket",
        "blenderNativeGroundPivot",
        "blenderNativeFootprintCorners",
        "blenderContactCornerOrder",
    )
    if any(binding.get(key) is None for key in required):
        raise GuardRejected(
            "coordinate_bridge_incomplete",
            "v06 coordinate-bridge binding is incomplete",
        )
    mapping_path = repository_path(binding["mappingContractPath"])
    try:
        mapping_digest = sha256_bytes(mapping_path.read_bytes())
    except OSError as error:
        raise GuardRejected("coordinate_bridge_mapping_missing", str(mapping_path)) from error
    if mapping_digest != binding["mappingContractSha256"]:
        raise GuardRejected(
            "coordinate_bridge_mapping_hash_mismatch",
            f"expected {binding['mappingContractSha256']}, got {mapping_digest}",
        )
    authority_path = repository_path(binding["authorityPath"])
    try:
        authority_digest = sha256_bytes(authority_path.read_bytes())
    except OSError as error:
        raise GuardRejected("coordinate_bridge_authority_missing", str(authority_path)) from error
    if authority_digest != binding["documentSha256"]:
        raise GuardRejected(
            "coordinate_bridge_authority_hash_mismatch",
            f"expected {binding['documentSha256']}, got {authority_digest}",
        )
    mapping = load_json(mapping_path)
    expected_basis = {
        "formula": "B(CitySim[x,y,z])=Blender[z,x,y]",
        "matrixRows": [[0, 0, 1], [1, 0, 0], [0, 1, 0]],
        "determinant": 1,
        "sourceOrder": [0, 1, 2, 3],
        "perDirectionTransforms": False,
        "windingChange": False,
    }
    if mapping.get("basis") != expected_basis:
        raise GuardRejected("coordinate_bridge_basis_mismatch", str(mapping.get("basis")))
    east = mapping.get("directions", {}).get("east")
    expected_east = {
        "frontageCitySim": [[28, 0, -28], [28, 0, 28]],
        "frontageSource": [[1024, 768], [768, 896]],
        "socketCitySim": [28, 0, 0],
        "socketBlender": [0, 28, 0],
        "socketSource": [896, 832],
        "outwardCitySim": [1, 0, 0],
        "outwardBlender": [0, 1, 0],
    }
    if east != expected_east:
        raise GuardRejected("coordinate_bridge_east_mapping_mismatch", str(east))
    registration = mapping.get("registration", {})
    if registration.get("pivotCitySim") != [28, 0, 28]:
        raise GuardRejected("coordinate_bridge_citysim_pivot_mismatch", str(registration))
    if registration.get("pivotBlender") != [28, 28, 0]:
        raise GuardRejected("coordinate_bridge_blender_pivot_mismatch", str(registration))
    if registration.get("pivotSource") != [768, 896]:
        raise GuardRejected("coordinate_bridge_source_pivot_mismatch", str(registration))
    if registration.get("contactPolygonBlenderXYZ") != binding["blenderNativeFootprintCorners"]:
        raise GuardRejected("coordinate_bridge_footprint_mismatch", str(registration))
    if binding["blenderContactCornerOrder"] != [0, 1, 2, 3]:
        raise GuardRejected(
            "coordinate_bridge_contact_order_mismatch",
            str(binding["blenderContactCornerOrder"]),
        )
    if mapping.get("sourceAuthority") is not False or mapping.get("productionSelected") is not False:
        raise GuardRejected("coordinate_bridge_disposition_mismatch", "bridge is zero-pixel only")
    return {"binding": binding, "mapping": mapping}


def output_paths(contract: dict[str, Any], process_id: str) -> dict[str, pathlib.Path]:
    inventory = contract["outputInventory"]
    root = repository_path(inventory["root"])
    process = inventory["processes"][process_id]
    return {name: root / relative for name, relative in process.items()}


def launch_blender(
    contract: dict[str, Any],
    process_id: str,
    appearance_lock_path: pathlib.Path,
) -> int:
    toolchain = contract["toolchain"]
    paths = output_paths(contract, process_id)
    for path in paths.values():
        path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        toolchain["executable"],
        *toolchain["requiredArguments"],
        "--python",
        str(pathlib.Path(__file__).resolve()),
        "--",
        "--blender-worker",
        "--mode",
        process_id,
        "--appearance-lock",
        str(appearance_lock_path.resolve()),
    ]
    return subprocess.run(command, cwd=REPOSITORY_ROOT, check=False).returncode


def execute(
    mode: str,
    appearance_lock_path: pathlib.Path | None,
    launcher: Callable[[dict[str, Any], str, pathlib.Path], int] = launch_blender,
) -> dict[str, Any]:
    contract = load_json(CONTRACT_PATH)
    contract_result = validate_contract(contract)
    if mode == "validate":
        return {
            "result": "PASS",
            "mode": "validate",
            "state": contract["state"],
            "contract": contract_result,
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "pixelFiles": 0,
        }
    authority = validate_source_stage_authority(contract, appearance_lock_path)
    validate_coordinate_bridge(contract)
    if appearance_lock_path is None:
        raise AssertionError("appearance lock guard returned without a path")
    returncode = launcher(contract, mode, appearance_lock_path)
    if returncode:
        raise RuntimeError(f"Blender process {mode} failed with status {returncode}")
    return {
        "result": "PASS",
        "mode": mode,
        "appearanceLockCommit": authority["appearanceLock"]["commit"],
        "blenderProcessLaunches": 1,
    }


def hex_rgba(value: str) -> tuple[float, float, float, float]:
    raw = value.removeprefix("#")
    if len(raw) != 6:
        raise GuardRejected("invalid_material_color", value)
    return tuple(int(raw[index : index + 2], 16) / 255.0 for index in (0, 2, 4)) + (1.0,)


def look_at(obj: Any, target: Any) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def apply_citysim_to_blender(
    coordinate: Iterable[float],
    mapping: dict[str, Any],
) -> list[float]:
    values = list(coordinate)
    if len(values) != 3:
        raise GuardRejected("coordinate_dimension_mismatch", str(values))
    return [
        sum(float(row[index]) * float(values[index]) for index in range(3))
        for row in mapping["basis"]["matrixRows"]
    ]


def descriptor_point_to_blender(
    coordinate: Iterable[float],
    mapping: dict[str, Any],
) -> list[float]:
    descriptor = list(coordinate)
    if len(descriptor) != 3:
        raise GuardRejected("descriptor_dimension_mismatch", str(descriptor))
    citysim = [descriptor[0], descriptor[2], descriptor[1]]
    return apply_citysim_to_blender(citysim, mapping)


def build_blender_scene(
    bpy: Any,
    vector_type: Any,
    contract: dict[str, Any],
    scene_data: dict[str, Any],
    material_mapping: dict[str, Any],
    coordinate_mapping: dict[str, Any],
) -> tuple[Any, dict[str, Any]]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    invariants = contract["invariants"]
    camera_spec = invariants["camera"]
    cycles = invariants["cycles"]
    color = invariants["color"]

    scene.render.engine = cycles["engine"]
    scene.cycles.device = cycles["device"]
    scene.render.threads_mode = "FIXED"
    scene.render.threads = cycles["threads"]
    scene.cycles.seed = cycles["seed"]
    scene.cycles.samples = cycles["samples"]
    scene.cycles.use_adaptive_sampling = cycles["adaptiveSampling"]
    scene.cycles.use_denoising = cycles["denoising"]
    scene.cycles.max_bounces = cycles["maxBounces"]
    scene.render.use_motion_blur = cycles["motionBlur"]
    scene.render.film_transparent = cycles["transparentFilm"]
    scene.render.use_file_extension = True
    scene.render.image_settings.file_format = color["outputFormat"]
    scene.render.image_settings.color_mode = color["colorMode"]
    scene.render.image_settings.color_depth = color["colorDepth"]
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_x = camera_spec["resolution"][0]
    scene.render.resolution_y = camera_spec["resolution"][1]
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = camera_spec["pixelAspect"][0]
    scene.render.pixel_aspect_y = camera_spec["pixelAspect"][1]
    scene.display_settings.display_device = color["displayDevice"]
    scene.view_settings.view_transform = color["viewTransform"]
    scene.view_settings.look = color["look"]
    scene.view_settings.exposure = color["exposure"]
    scene.view_settings.gamma = color["gamma"]

    camera_data = bpy.data.cameras.new("PLAY-079-East-Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = camera_spec["orthoScale"]
    camera_data.shift_x = camera_spec["shiftX"]
    camera_data.shift_y = camera_spec["shiftY"]
    camera = bpy.data.objects.new("PLAY-079-East-Camera", camera_data)
    scene.collection.objects.link(camera)
    target = vector_type(camera_spec["blenderTarget"])
    camera.location = vector_type(camera_spec["blenderPosition"])
    look_at(camera, target)
    scene.camera = camera

    materials: dict[str, Any] = {}
    semantic_materials: dict[str, Any] = {}
    semantic_palette = invariants["semanticPalette"]
    required_roles = scene_data["materialBindings"]["requiredRoles"]
    if set(material_mapping) != set(required_roles):
        raise GuardRejected("locked_material_role_mismatch", "appearance lock roles differ from East")
    for role in sorted(required_roles):
        spec = material_mapping[role]
        if not isinstance(spec, dict):
            raise GuardRejected("invalid_material_mapping", role)
        material = bpy.data.materials.new(f"PLAY-079::{role}")
        material.diffuse_color = hex_rgba(spec["baseColorSRGB"])
        material.metallic = float(spec["metallic"])
        material.roughness = float(spec["roughness"])
        materials[role] = material
        semantic = bpy.data.materials.new(f"PLAY-079::semantic::{role}")
        semantic.diffuse_color = hex_rgba(semantic_palette[role])
        semantic_materials[role] = semantic

    objects: list[tuple[Any, str]] = []
    for spec in scene_data["objects"]:
        location = descriptor_point_to_blender(spec["center"], coordinate_mapping)
        if spec["kind"] == "box":
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
            obj = bpy.context.object
            obj.dimensions = descriptor_point_to_blender(spec["dimensions"], coordinate_mapping)
        elif spec["kind"] == "cylinder":
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=spec["vertices"],
                radius=spec["radius"],
                depth=spec["depth"],
                location=location,
            )
            obj = bpy.context.object
        else:
            raise GuardRejected("unsupported_object_kind", str(spec["kind"]))
        obj.name = spec["id"]
        obj.data.name = f"{spec['id']}-mesh"
        obj.data.materials.append(materials[spec["materialRole"]])
        objects.append((obj, spec["materialRole"]))

    def add_polygon(name: str, coordinates: list[list[float]], role: str) -> None:
        mesh = bpy.data.meshes.new(f"{name}-mesh")
        mapped = [
            descriptor_point_to_blender(coordinate, coordinate_mapping)
            for coordinate in coordinates
        ]
        mesh.from_pydata(mapped, [], [list(range(len(mapped)))])
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        scene.collection.objects.link(obj)
        obj.data.materials.append(materials[role])
        objects.append((obj, role))

    contact = scene_data["contact"]
    add_polygon("east-contact-shadow", contact["polygon"], contact["materialRole"])
    add_polygon("east-road-apron", contact["roadApron"], "formed-concrete")

    light_spec = invariants["light"]
    sun_data = bpy.data.lights.new("PLAY-079-Northwest-Key", type="SUN")
    sun_data.energy = 2.2
    sun_data.angle = 0.08
    sun = bpy.data.objects.new("PLAY-079-Northwest-Key", sun_data)
    scene.collection.objects.link(sun)
    sun.location = light_spec["blenderKeyOrigin"]
    look_at(sun, vector_type((0.0, 0.0, 0.0)))
    scene.world.color = (0.28, 0.28, 0.28)
    bpy.context.view_layer.update()
    return scene, {"objects": objects, "semanticMaterials": semantic_materials}


def blender_worker(mode: str, appearance_lock_path: pathlib.Path) -> int:
    contract = load_json(CONTRACT_PATH)
    validate_contract(contract)
    authority = validate_source_stage_authority(contract, appearance_lock_path)
    lock = authority["appearanceLock"]
    bridge_result = validate_coordinate_bridge(contract)
    bridge = bridge_result["binding"]
    coordinate_mapping = bridge_result["mapping"]

    # Both hard guards above must complete before this process imports bpy.
    import bpy  # type: ignore
    from mathutils import Vector  # type: ignore

    scene_data = load_json(repository_path(contract["acceptedPredesign"]["scene"]["path"]))
    scene, built = build_blender_scene(
        bpy,
        Vector,
        contract,
        scene_data,
        lock["materialRoleMapping"],
        coordinate_mapping,
    )
    paths = output_paths(contract, mode)
    scene.render.filepath = str(paths["raw"])
    bpy.ops.render.render(write_still=True)
    for obj, role in built["objects"]:
        obj.data.materials.clear()
        obj.data.materials.append(built["semanticMaterials"][role])
    scene.render.filepath = str(paths["semantic"])
    bpy.ops.render.render(write_still=True)
    provenance = {
        "schema": "citysim.world-art.blender-process-provenance.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "processId": mode,
        "appearanceLockCommit": lock["commit"],
        "sceneSha256": contract["acceptedPredesign"]["scene"]["sha256"],
        "coordinateMappingSha256": bridge["mappingContractSha256"],
        "contractSha256": sha256_bytes(CONTRACT_PATH.read_bytes()),
        "blenderVersion": bpy.app.version_string,
        "blenderBuildHash": bpy.app.build_hash.decode("utf-8"),
        "factoryStartup": True,
        "autoexecDisabled": True,
        "renderApiCalls": 2,
    }
    paths["provenance"].write_bytes(canonical_bytes(provenance))
    return 0


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("validate", "A", "B", "C"), required=True)
    parser.add_argument("--appearance-lock", type=pathlib.Path)
    parser.add_argument("--blender-worker", action="store_true")
    return parser.parse_args(list(argv))


def main() -> int:
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    args = parse_arguments(arguments)
    try:
        if args.blender_worker:
            if args.mode == "validate" or args.appearance_lock is None:
                raise GuardRejected("invalid_blender_worker_request", "worker requires A/B/C and lock")
            return blender_worker(args.mode, args.appearance_lock)
        result = execute(args.mode, args.appearance_lock)
        sys.stdout.buffer.write(canonical_bytes(result))
        return 0
    except GuardRejected as rejection:
        result = {
            "result": "REJECTED",
            "stage": "before_renderer_launch",
            "code": rejection.code,
            "detail": rejection.detail,
            "mode": args.mode,
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "pixelFiles": 0,
        }
        sys.stdout.buffer.write(canonical_bytes(result))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
