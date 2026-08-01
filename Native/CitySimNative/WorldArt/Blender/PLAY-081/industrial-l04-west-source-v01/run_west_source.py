#!/usr/bin/env python3
"""Hard-guarded PLAY-081 West source runner.

The system-Python entry point validates every frozen input and the complete
Integration appearance-lock binding before it can launch Blender. It never
imports Blender's Python API. In the pre-lock state, A/B/C always stop with a
machine-readable rejection before ``subprocess.run`` can reach Blender.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

from validate_locator_authority import validate_locator_authority

from west_launch_authority import (
    validate_future_authorities,
    validate_output_root_isolation,
)
from west_path_safety import (
    PathSafetyError,
    expected_process_paths,
    lexical_repository_path,
    validate_pipeline_layout,
)


DEFAULT_CONTRACT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01/RUNNER-CONTRACT.json"
)
REQUIRED_LOCK_FIELDS = (
    "documentPath",
    "commit",
    "documentSha256",
    "northProcessASourceSha256",
    "northProcessADecodedRgbaSha256",
)
CLOSURE_ORCHESTRATOR = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01/west_execution_orchestration_v2.py"
)
CLOSURE_RUNNER = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01/run_west_source.py"
)
CLOSURE_ZERO_ACTIVITY = {
    "dccStarts": 0,
    "childStarts": 0,
    "renders": 0,
    "pixels": 0,
    "normalizerInvocations": 0,
    "sourcePackets": 0,
}


class ContractError(RuntimeError):
    """Raised when immutable runner inputs or structure are invalid."""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ContractError(f"expected JSON object: {path}")
    return value


def repository_path(root: Path, relative: str) -> Path:
    if not relative or Path(relative).is_absolute():
        raise ContractError(f"path must be repository-relative: {relative!r}")
    resolved = (root / relative).resolve()
    try:
        resolved.relative_to(root)
    except ValueError as error:
        raise ContractError(f"path escapes repository: {relative}") from error
    return resolved


def validate_execution_closure_boundary(
    shared_validation: dict[str, Any],
    authority: dict[str, Any],
    *,
    direct_invocation: bool,
) -> dict[str, Any]:
    """Reach the low-level runner contract without starting any child.

    Only the task-owned high-level orchestrator calls this function after the
    Integration validator returns PASS. The public CLI always sets
    ``direct_invocation`` and therefore remains non-invocable.
    """
    errors: list[str] = []
    if direct_invocation:
        errors.append("direct-runner:forbidden")
    expected_shared = {
        "result": "PASS",
        "taskId": "PLAY-081",
        "direction": "west",
        "validationOnly": True,
        "dccStarts": 0,
        "childStarts": 0,
        "renders": 0,
        "pixels": 0,
    }
    if not isinstance(shared_validation, dict):
        errors.append("shared-validation:shape")
    else:
        for field, expected in expected_shared.items():
            if shared_validation.get(field) != expected:
                errors.append(f"shared-validation:{field}")
        if shared_validation.get("process") not in {"A", "B", "C"}:
            errors.append("shared-validation:process")

    if not isinstance(authority, dict):
        errors.append("authority:shape")
        artifacts: dict[str, Any] = {}
        grant: dict[str, Any] = {}
        authentication: dict[str, Any] = {}
        disposition: dict[str, Any] = {}
    else:
        artifacts = authority.get("artifacts", {})
        grant = authority.get("grant", {})
        authentication = authority.get("authentication", {})
        disposition = authority.get("disposition", {})
        if authority.get("mode") != "validation_only":
            errors.append("authority:mode")
        if authority.get("task", {}).get("direction") != "west":
            errors.append("authority:direction")

    high_level = artifacts.get("highLevelOrchestrator", {})
    runner = artifacts.get("runnerEntrypoint", {})
    if high_level.get("path") != CLOSURE_ORCHESTRATOR:
        errors.append("authority:high-level-orchestrator")
    if runner.get("path") != CLOSURE_RUNNER:
        errors.append("authority:runner-entrypoint")
    if (
        grant.get("orchestratorOnly") is not True
        or grant.get("directLowLevelInvocationAllowed") is not False
        or grant.get("exactlyOneInvocation") is not True
        or grant.get("maximumChildStarts") != 1
    ):
        errors.append("authority:grant-boundary")
    if (
        authentication.get("secretTransport") != "anonymous_pipe"
        or authentication.get("rawSecretPersisted") is not False
        or authentication.get("childCapability", {}).get("boundGrantId")
        != grant.get("grantId")
        or authentication.get("childCapability", {}).get("oneTime") is not True
        or authentication.get("childCapability", {}).get("replayAllowed")
        is not False
    ):
        errors.append("authority:authentication")
    if disposition.get("validationOnly") is not True or any(
        value is not False
        for key, value in disposition.items()
        if key != "validationOnly"
    ):
        errors.append("authority:disposition")

    return {
        "schema": "citysim.play-081.west-low-level-validation-boundary.v1",
        "taskId": "PLAY-081",
        "direction": "west",
        "process": (
            shared_validation.get("process")
            if isinstance(shared_validation, dict)
            else None
        ),
        "result": "PASS" if not errors else "BLOCKED",
        "errors": sorted(set(errors)),
        "directInvocation": direct_invocation,
        "runnerValidationBoundaryReached": not errors,
        "childStartAuthorized": False,
        "activity": dict(CLOSURE_ZERO_ACTIVITY),
    }


def hash_binding_errors(
    root: Path, name: str, binding: dict[str, Any]
) -> list[str]:
    path_value = binding.get("path")
    expected = binding.get("sha256")
    if not isinstance(path_value, str) or not isinstance(expected, str):
        return [f"{name}:invalid-binding"]
    try:
        path = repository_path(root, path_value)
    except ContractError:
        return [f"{name}:invalid-path"]
    if not path.is_file():
        return [f"{name}:missing"]
    if sha256(path) != expected:
        return [f"{name}:sha256-mismatch"]
    return []


def frozen_input_errors(root: Path, contract: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    expected_scalars = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "branch": "codex/citysim-world-art-west",
        "baselineCommit": "f9cb5fbae1be459ba297a8605347c4174f912ba0",
        "sourceReady": False,
        "productionSelected": False,
    }
    for key, expected in expected_scalars.items():
        if contract.get(key) != expected:
            errors.append(f"contract:{key}")

    for name in (
        "authority",
        "repairAuthority",
        "handoffSchema",
        "governingContract",
    ):
        value = contract.get(name)
        if not isinstance(value, dict):
            errors.append(f"{name}:missing-binding")
        else:
            errors.extend(hash_binding_errors(root, name, value))

    predesign = contract.get("acceptedPredesign")
    if not isinstance(predesign, dict):
        errors.append("acceptedPredesign:missing")
    else:
        for name in (
            "handoff",
            "scene",
            "materials",
            "validator",
            "actualCameraProofScript",
            "staticProof",
            "actualCameraProof",
            "repeatIdentity",
        ):
            binding = predesign.get(name)
            if not isinstance(binding, dict):
                errors.append(f"acceptedPredesign.{name}:missing-binding")
            else:
                errors.extend(
                    hash_binding_errors(root, f"acceptedPredesign.{name}", binding)
                )
        historical_proof = predesign.get("actualCameraProofScript", {})
        if (
            historical_proof.get("authorityScope")
            != "historical-zero-pixel-evidence-only"
            or historical_proof.get("futureSourceAuthority") is not False
        ):
            errors.append(
                "acceptedPredesign.actualCameraProofScript:future-authority-scope"
            )

    invariants = contract.get("invariants", {})
    registration = invariants.get("registration", {})
    camera = invariants.get("camera", {})
    light = invariants.get("lightAndContact", {})
    pipeline = invariants.get("renderPipeline", {})
    exact_invariants = (
        (invariants.get("orientationTransform"), "none", "orientation-transform"),
        (registration.get("frontageEdge"), "west", "frontage-edge"),
        (
            registration.get("frontageSocketWorldXYZ"),
            [-28, 0, 0],
            "frontage-socket",
        ),
        (
            registration.get("groundPivotWorldXYZ"),
            [28, 0, 28],
            "ground-pivot",
        ),
        (
            camera.get("renderViewportPixels"),
            [1536, 1024],
            "source-resolution",
        ),
        (
            camera.get("literalViewportPixels"),
            [192, 128],
            "literal-resolution",
        ),
        (light.get("keyDirection"), "northwest", "key-direction"),
        (light.get("contactDirection"), "southeast", "contact-direction"),
        (pipeline.get("engine"), "CYCLES", "render-engine"),
        (pipeline.get("device"), "CPU", "cycles-device"),
        (pipeline.get("threads"), 1, "render-threads"),
        (pipeline.get("samples"), 64, "render-samples"),
        (pipeline.get("adaptiveSampling"), False, "adaptive-sampling"),
        (pipeline.get("denoising"), False, "denoising"),
        (pipeline.get("motionBlur"), False, "motion-blur"),
        (pipeline.get("transparentFilm"), True, "transparent-film"),
    )
    for actual, expected, name in exact_invariants:
        if actual != expected:
            errors.append(f"invariant:{name}")

    bridge = contract.get("coordinateBridge", {})
    canonical = bridge.get("canonicalCitySim", {})
    historical = bridge.get("historicalProjectionAdapter", {})
    bridge_v06 = bridge.get("v06", {})
    bridge_invariants = (
        (bridge.get("holdIsStop"), False, "hold-is-not-stop"),
        (bridge.get("state"), "validated_v06", "validated-v06-state"),
        (canonical.get("direction"), "west", "canonical-direction"),
        (
            canonical.get("frontageSocketWorldXYZ"),
            [-28, 0, 0],
            "canonical-world-socket",
        ),
        (
            canonical.get("frontageSocketExpectedSource"),
            [640, 704],
            "canonical-source-socket",
        ),
        (
            historical.get("authorityScope"),
            "retained-predesign-proof-only",
            "historical-adapter-scope",
        ),
        (
            historical.get("futureSourceAuthority"),
            False,
            "historical-adapter-not-source-authority",
        ),
        (
            bridge_v06.get("authorityCommit"),
            "3e01ca6738d7574718f9aeff4b66771eee109feb",
            "legacy-source-candidate-alias",
        ),
        (
            bridge_v06.get("sourceCandidateCommit"),
            "3e01ca6738d7574718f9aeff4b66771eee109feb",
            "source-candidate-provenance",
        ),
        (
            bridge_v06.get("integratedProofCommit"),
            "3d76fab8a45807c34198a6d8bb1dd1eeff7be51e",
            "integrated-proof-execution-authority",
        ),
        (
            bridge_v06.get("mappingContractSha256"),
            "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7",
            "mapping-contract-sha256",
        ),
        (
            bridge_v06.get("basisFormula"),
            "B(CitySim[x,y,z])=Blender[z,x,y]",
            "basis-formula",
        ),
        (bridge_v06.get("sourceOrder"), [0, 1, 2, 3], "source-order"),
        (
            bridge_v06.get("frontageSocketCitySimXYZ"),
            [-28, 0, 0],
            "v06-citysim-socket",
        ),
        (
            bridge_v06.get("frontageSocketBlenderXYZ"),
            [0, -28, 0],
            "v06-blender-socket",
        ),
        (
            bridge_v06.get("frontageSocketSourceXY"),
            [640, 704],
            "v06-source-socket",
        ),
        (
            bridge_v06.get("perDirectionTransform"),
            False,
            "no-per-direction-transform",
        ),
        (bridge_v06.get("windingChange"), False, "no-winding-change"),
    )
    for actual, expected, name in bridge_invariants:
        if actual != expected:
            errors.append(f"coordinate-bridge:{name}")
    if historical:
        errors.extend(
            hash_binding_errors(root, "coordinateBridge.historicalAdapter", historical)
        )
    bridge_bindings = (
        ("acceptance", "acceptancePath", "acceptanceSha256"),
        ("authority", "authorityPath", "authoritySha256"),
        ("mappingContract", "mappingContractPath", "mappingContractSha256"),
        ("adapter", "adapterPath", "adapterSha256"),
        ("proofTool", "proofToolPath", "proofToolSha256"),
    )
    for name, path_key, hash_key in bridge_bindings:
        errors.extend(
            hash_binding_errors(
                root,
                f"coordinateBridge.v06.{name}",
                {
                    "path": bridge_v06.get(path_key),
                    "sha256": bridge_v06.get(hash_key),
                },
            )
        )
    try:
        mapping = load_json(
            repository_path(root, bridge_v06["mappingContractPath"])
        )
        west = mapping["directions"]["west"]
        if (
            mapping["basis"]["formula"] != bridge_v06.get("basisFormula")
            or mapping["basis"]["sourceOrder"] != bridge_v06.get("sourceOrder")
            or mapping["basis"]["perDirectionTransforms"] is not False
            or mapping["basis"]["windingChange"] is not False
            or west["socketCitySim"]
            != bridge_v06.get("frontageSocketCitySimXYZ")
            or west["socketBlender"]
            != bridge_v06.get("frontageSocketBlenderXYZ")
            or west["socketSource"] != bridge_v06.get("frontageSocketSourceXY")
        ):
            errors.append("coordinate-bridge:mapping-content")
    except (ContractError, KeyError, OSError, json.JSONDecodeError):
        errors.append("coordinate-bridge:mapping-invalid")

    source_stage = contract.get("sourceStage", {})
    schema_binding = source_stage.get("handoffSchema", {})
    if (
        schema_binding.get("state") != "bound_integration_v2"
        or schema_binding.get("path")
        != (
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-source-stage-handoff-schema-v2.json"
        )
        or schema_binding.get("sha256")
        != "85f6a2824c273a1e63354df79a97e5a59c2909a68771613b325664d649ac53ec"
        or schema_binding.get("schemaId")
        != "citysim://integration/industrial-l04-source-stage-handoff-v2"
    ):
        errors.append("source-stage-schema:v2-binding")
    for name in (
        "schemaAuthority",
        "handoffSchema",
        "nonAliasInput",
        "nonAliasLoader",
        "semanticValidator",
        "canonicalDecoder",
        "pngDecoder",
    ):
        binding = source_stage.get(name)
        if not isinstance(binding, dict):
            errors.append(f"source-stage:{name}:missing-binding")
        else:
            errors.extend(
                hash_binding_errors(root, f"source-stage.{name}", binding)
            )
    non_alias = source_stage.get("nonAliasInput", {})
    if (
        non_alias.get("forbiddenDecodedRgbaSha256Count") != 44
        or non_alias.get("forbiddenSetSha256")
        != "265c564785a5fa4ce14fbd04898ef04aaed883e2ca56f6a0660a9937464926ea"
    ):
        errors.append("source-stage:non-alias-contract")
    try:
        non_alias_document = load_json(
            repository_path(root, non_alias["path"])
        )
        if (
            non_alias_document.get("forbiddenDecodedRgbaSha256Count") != 44
            or non_alias_document.get("forbiddenSetSha256")
            != non_alias.get("forbiddenSetSha256")
        ):
            errors.append("source-stage:non-alias-content")
    except (ContractError, KeyError, OSError, json.JSONDecodeError):
        errors.append("source-stage:non-alias-invalid")
    source_profile = source_stage.get("sourceProductionProfile", {})
    if source_profile.get("state") == "not_published":
        if source_profile != {
            "state": "not_published",
            "path": None,
            "commit": None,
            "sha256": None,
        }:
            errors.append("source-production-profile:prelock-state")
    elif source_profile.get("state") == "bound_integration_profile":
        if (
            set(source_profile) != {"state", "path", "commit", "sha256"}
            or any(
                not source_profile.get(field)
                for field in ("path", "commit", "sha256")
            )
        ):
            errors.append("source-production-profile:bound-state")
    else:
        errors.append("source-production-profile:state")

    implementation = contract.get("runnerImplementation", {})
    for name, key in (
        ("blender-script", "blenderScriptPath"),
        ("launch-authority-validator", "launchAuthorityValidatorPath"),
        ("path-safety", "pathSafetyPath"),
        ("launch-bound-assembler", "launchBoundAssemblerPath"),
        ("post-source-pipeline", "postSourcePipelinePath"),
        ("locator-authority-validator", "locatorAuthorityValidatorPath"),
    ):
        value = implementation.get(key)
        if not isinstance(value, str):
            errors.append(f"runnerImplementation:{name}-path")
        else:
            try:
                if not repository_path(root, value).is_file():
                    errors.append(f"runnerImplementation:{name}-missing")
            except ContractError:
                errors.append(f"runnerImplementation:{name}-invalid")

    locator_authority = validate_locator_authority(root, contract)
    errors.extend(
        f"source-candidate-locator:{error}"
        for error in locator_authority["errors"]
    )

    counts = contract.get("invocationCounts", {})
    if not isinstance(counts, dict) or any(value != 0 for value in counts.values()):
        errors.append("invocation-counts:nonzero")
    return sorted(set(errors))


def _validate_lock_document(
    lock_document: dict[str, Any], appearance: dict[str, Any]
) -> list[str]:
    errors: list[str] = []
    binding = lock_document.get("appearanceLockBinding")
    if not isinstance(binding, dict):
        return ["appearance-lock:binding-missing"]
    expected = {
        "commit": appearance["commit"],
        "northProcessASourceSha256": appearance["northProcessASourceSha256"],
        "northProcessADecodedRgbaSha256": appearance[
            "northProcessADecodedRgbaSha256"
        ],
    }
    for key, value in expected.items():
        if binding.get(key) != value:
            errors.append(f"appearance-lock:{key}-binding-mismatch")
    return errors


def _validate_material_mapping(
    mapping: dict[str, Any],
    appearance_sha256: str,
    required_roles: set[str],
) -> list[str]:
    errors: list[str] = []
    if mapping.get("schemaVersion") != 1:
        errors.append("locked-materials:schema-version")
    if mapping.get("direction") != "west":
        errors.append("locked-materials:direction")
    if mapping.get("appearanceLockSha256") != appearance_sha256:
        errors.append("locked-materials:appearance-lock-binding")
    roles = mapping.get("roles")
    if not isinstance(roles, dict):
        return errors + ["locked-materials:roles-missing"]
    if set(roles) != required_roles:
        errors.append("locked-materials:role-set")
    for name, role in roles.items():
        if not isinstance(role, dict):
            errors.append(f"locked-materials:{name}:invalid")
            continue
        color = role.get("baseColorSrgb")
        if (
            not isinstance(color, list)
            or len(color) != 4
            or any(not isinstance(value, (int, float)) for value in color)
        ):
            errors.append(f"locked-materials:{name}:base-color")
        for key in ("roughness", "metallic"):
            value = role.get(key)
            if not isinstance(value, (int, float)) or not 0 <= value <= 1:
                errors.append(f"locked-materials:{name}:{key}")
    return errors


def evaluate_render_guard(
    root: Path, contract: dict[str, Any], mode: str
) -> dict[str, Any]:
    """Return a deterministic pre-launch decision without launching Blender."""
    errors = frozen_input_errors(root, contract)
    authority_report = validate_future_authorities(root, contract)
    errors.extend(authority_report["errors"])
    bridge = contract.get("coordinateBridge")
    bridge_v06: dict[str, Any] = {}
    if not isinstance(bridge, dict):
        errors.append("coordinate-bridge:missing")
    else:
        bridge_v06 = bridge.get("v06", {})
        if bridge.get("state") != "validated_v06":
            errors.append("coordinate-bridge:pending-v06")
        required_bridge_fields = (
            "acceptancePath",
            "acceptanceSha256",
            "authorityPath",
            "sourceCandidateCommit",
            "integratedProofCommit",
            "authoritySha256",
            "mappingContractPath",
            "mappingContractSha256",
            "adapterPath",
            "adapterSha256",
            "proofToolPath",
            "proofToolSha256",
            "basisFormula",
            "sourceOrder",
            "frontageSocketCitySimXYZ",
            "frontageSocketBlenderXYZ",
            "frontageSocketSourceXY",
        )
        if not isinstance(bridge_v06, dict) or any(
            not bridge_v06.get(field) for field in required_bridge_fields
        ):
            errors.append("coordinate-bridge:v06-binding-incomplete")
        else:
            try:
                for name, path_key, hash_key in (
                    ("acceptance", "acceptancePath", "acceptanceSha256"),
                    ("authority", "authorityPath", "authoritySha256"),
                    (
                        "mapping-contract",
                        "mappingContractPath",
                        "mappingContractSha256",
                    ),
                    ("adapter", "adapterPath", "adapterSha256"),
                    ("proof-tool", "proofToolPath", "proofToolSha256"),
                ):
                    path = repository_path(root, bridge_v06[path_key])
                    if (
                        not path.is_file()
                        or sha256(path) != bridge_v06[hash_key]
                    ):
                        errors.append(
                            f"coordinate-bridge:{name}-sha256-mismatch"
                        )
            except (ContractError, OSError):
                errors.append("coordinate-bridge:v06-binding-invalid")
            if not _commit_is_ancestor(
                root,
                bridge_v06["integratedProofCommit"],
            ):
                errors.append("coordinate-bridge:integrated-proof-not-ancestor")
    appearance = contract.get("appearanceLock")
    if not isinstance(appearance, dict):
        errors.append("appearance-lock:missing-object")
        appearance = {}
    missing_fields = [
        field for field in REQUIRED_LOCK_FIELDS if not appearance.get(field)
    ]
    for field in ("appearanceLockCommit", "appearanceLockSha256"):
        if not contract.get(field):
            missing_fields.append(field)
    material_binding = contract.get("lockedMaterialMapping")
    if not isinstance(material_binding, dict):
        material_binding = {}
        errors.append("locked-materials:missing-object")
    for field in ("path", "sha256"):
        if not material_binding.get(field):
            missing_fields.append(f"lockedMaterialMapping.{field}")
    if contract.get("state") != "ready_for_source_render":
        missing_fields.append("state.ready_for_source_render")
    if missing_fields:
        errors.append("appearance-lock:missing")

    if not missing_fields:
        if contract["appearanceLockCommit"] != appearance["commit"]:
            errors.append("appearance-lock:commit-alias-mismatch")
        if contract["appearanceLockSha256"] != appearance["documentSha256"]:
            errors.append("appearance-lock:sha256-alias-mismatch")
        try:
            lock_path = repository_path(root, appearance["documentPath"])
            if not lock_path.is_file():
                errors.append("appearance-lock:document-missing")
            elif sha256(lock_path) != appearance["documentSha256"]:
                errors.append("appearance-lock:document-sha256-mismatch")
            else:
                errors.extend(
                    _validate_lock_document(load_json(lock_path), appearance)
                )
        except (ContractError, OSError, json.JSONDecodeError):
            errors.append("appearance-lock:document-invalid")

        try:
            mapping_path = repository_path(root, material_binding["path"])
            if not mapping_path.is_file():
                errors.append("locked-materials:file-missing")
            elif sha256(mapping_path) != material_binding["sha256"]:
                errors.append("locked-materials:sha256-mismatch")
            else:
                predesign_materials = load_json(
                    repository_path(
                        root, contract["acceptedPredesign"]["materials"]["path"]
                    )
                )
                errors.extend(
                    _validate_material_mapping(
                        load_json(mapping_path),
                        appearance["documentSha256"],
                        set(predesign_materials["roles"]),
                    )
                )
        except (ContractError, OSError, json.JSONDecodeError, KeyError):
            errors.append("locked-materials:file-invalid")

    process = contract.get("outputInventory", {}).get("processes", {}).get(mode)
    if not isinstance(process, dict):
        errors.append("output:process-missing")
    else:
        expected_directory = (
            "docs/production/evidence/PLAY-081/"
            f"industrial-l04-west-source-v01/process-{mode}"
        )
        if process.get("directory") != expected_directory:
            errors.append("output:non-deterministic-directory")
    isolation_report = validate_output_root_isolation(
        root,
        contract,
        require_absent=True,
    )
    errors.extend(isolation_report["errors"])
    pipeline_layout = validate_pipeline_layout(root, contract)
    errors.extend(
        f"pipeline-output:{error}" for error in pipeline_layout["errors"]
    )

    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "mode": mode,
        "decision": "reject" if errors else "allow",
        "rejectionStage": "before_renderer_launch",
        "reasonCodes": sorted(set(errors)),
        "authorityValidation": authority_report,
        "outputRootIsolation": isolation_report,
        "pipelineOutputIsolation": pipeline_layout,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "renderInvocations": 0,
        "pixelFiles": 0,
    }


def _commit_is_ancestor(root: Path, commit: str) -> bool:
    object_check = subprocess.run(
        ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
        cwd=root,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if object_check.returncode:
        return False
    ancestry = subprocess.run(
        ["git", "merge-base", "--is-ancestor", commit, "HEAD"],
        cwd=root,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return ancestry.returncode == 0


def _verify_lock_commit_ancestry(
    root: Path,
    commit: str,
    name: str,
) -> None:
    if not _commit_is_ancestor(root, commit):
        raise ContractError(f"{name} commit is not an ancestor of HEAD")


def launch_blender(
    root: Path, contract_path: Path, contract: dict[str, Any], mode: str
) -> int:
    """Launch Blender only after ``evaluate_render_guard`` returned allow."""
    appearance = contract["appearanceLock"]
    _verify_lock_commit_ancestry(
        root,
        contract["coordinateBridge"]["v06"]["integratedProofCommit"],
        "integrated v06 proof",
    )
    _verify_lock_commit_ancestry(
        root,
        appearance["commit"],
        "appearance lock",
    )
    pipeline = contract["invariants"]["renderPipeline"]
    executable = Path(pipeline["blenderExecutable"])
    if not executable.is_file() or sha256(executable) != pipeline["blenderExecutableSha256"]:
        raise ContractError("Blender executable fingerprint mismatch")
    script = repository_path(
        root, contract["runnerImplementation"]["blenderScriptPath"]
    )
    mapping = repository_path(root, contract["lockedMaterialMapping"]["path"])
    process = contract["outputInventory"]["processes"][mode]
    layout = validate_output_root_isolation(
        root,
        contract,
        require_absent=True,
    )
    if not layout["passed"]:
        raise ContractError(
            "unsafe output layout: " + ",".join(layout["errors"])
        )
    pipeline_layout = validate_pipeline_layout(root, contract)
    if not pipeline_layout["passed"]:
        raise ContractError(
            "unsafe pipeline output layout: "
            + ",".join(pipeline_layout["errors"])
        )
    expected = expected_process_paths(mode)
    try:
        process_root = lexical_repository_path(
            root,
            process["directory"],
            expected=expected["directory"],
        )
        raw_root = lexical_repository_path(
            root,
            process["rawRoot"],
            expected=expected["rawRoot"],
        )
        semantic_root = lexical_repository_path(
            root,
            process["semanticRoot"],
            expected=expected["semanticRoot"],
        )
        evidence_root = lexical_repository_path(
            root,
            process["evidenceRoot"],
            expected=expected["evidenceRoot"],
        )
    except PathSafetyError as error:
        raise ContractError(f"unsafe process output: {error}") from error
    command = [
        str(executable),
        *pipeline["startupArguments"],
        "--python",
        str(script),
        "--",
        "--repository-root",
        str(root),
        "--runner-contract",
        str(contract_path.relative_to(root)),
        "--locked-materials",
        str(mapping.relative_to(root)),
        "--process-id",
        mode,
        "--raw-root",
        str(raw_root.relative_to(root)),
        "--semantic-root",
        str(semantic_root.relative_to(root)),
        "--evidence-root",
        str(evidence_root.relative_to(root)),
    ]
    completed = subprocess.run(command, cwd=root, check=False)
    return completed.returncode


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument(
        "--mode",
        required=True,
        choices=("validate", "validate-execution-closure", "A", "B", "C"),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract_path = repository_path(root, args.contract)
    contract = load_json(contract_path)
    if args.mode == "validate-execution-closure":
        result = validate_execution_closure_boundary(
            {},
            {},
            direct_invocation=True,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 3
    if args.mode == "validate":
        errors = frozen_input_errors(root, contract)
        result = {
            "schemaVersion": 1,
            "taskId": "PLAY-081",
            "direction": "west",
            "mode": "validate",
            "passed": not errors,
            "errors": errors,
            "state": contract.get("state"),
            "renderInvocations": 0,
            "pixelFiles": 0,
        }
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if not errors else 1

    decision = evaluate_render_guard(root, contract, args.mode)
    if decision["decision"] != "allow":
        print(json.dumps(decision, indent=2, sort_keys=True))
        return 3
    try:
        return launch_blender(root, contract_path, contract, args.mode)
    except ContractError as error:
        rejected = copy.deepcopy(decision)
        rejected["decision"] = "reject"
        rejected["reasonCodes"] = [f"prelaunch:{error}"]
        print(json.dumps(rejected, indent=2, sort_keys=True))
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
