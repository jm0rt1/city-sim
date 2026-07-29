#!/usr/bin/env python3
"""Prepare a fail-closed PLAY-079 East v2 launch-bound handoff.

Production mode accepts only Integration-published appearance-lock and
source-production-profile artifacts. Dry structural mode accepts only the
task-owned non-production fixture bundle and never writes files.
"""

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
from typing import Any, Iterable


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
CONTRACT_PATH = SOURCE_ROOT / "RUNNER-CONTRACT.json"
DRIVER_PATH = SOURCE_ROOT / "run_production.py"
FIXTURE_ROOT = SOURCE_ROOT / "fixtures"
SCHEMA_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-stage-handoff-schema-v2.json"
)
SCHEMA_SHA256 = "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7"
SEMANTIC_VALIDATOR_PATH = (
    REPOSITORY_ROOT
    / "Native/CitySimNative/WorldArt/Shared/validate_source_stage_handoff_v2.py"
)
SEMANTIC_VALIDATOR_SHA256 = (
    "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340"
)
INTEGRATION_AUTHORITY_ROOT = "docs/production/evidence/INTEGRATION/"
HEX_DIGITS = frozenset("0123456789abcdef")


class PreparationRejected(RuntimeError):
    """Stable fail-closed launch-preparation rejection."""

    def __init__(self, code: str, detail: str):
        super().__init__(detail)
        self.code = code
        self.detail = detail


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    return sha256_bytes(path.read_bytes())


def require_hex(value: str, length: int, code: str, label: str) -> str:
    if len(value) != length or any(character not in HEX_DIGITS for character in value):
        raise PreparationRejected(code, f"{label}: {value}")
    return value


def load_json(path: pathlib.Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PreparationRejected(code, f"{path}: {error}") from error
    if not isinstance(value, dict):
        raise PreparationRejected(code, f"{path}: expected JSON object")
    return value


def repository_path(value: pathlib.Path | str) -> pathlib.Path:
    path = pathlib.Path(value)
    resolved = path.resolve() if path.is_absolute() else (REPOSITORY_ROOT / path).resolve()
    try:
        resolved.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise PreparationRejected("path_outside_repository", str(value)) from error
    return resolved


def repository_relative(path: pathlib.Path) -> str:
    try:
        return str(path.resolve().relative_to(REPOSITORY_ROOT))
    except ValueError as error:
        raise PreparationRejected("path_outside_repository", str(path)) from error


def require_integration_authority_path(path: pathlib.Path, label: str) -> str:
    relative = repository_relative(path)
    if not relative.startswith(INTEGRATION_AUTHORITY_ROOT):
        raise PreparationRejected(
            f"{label}_outside_integration_authority_root",
            relative,
        )
    return relative


def validate_file_hash(path: pathlib.Path, expected: str, label: str) -> str:
    require_hex(expected, 64, f"{label}_invalid_sha256", label)
    try:
        actual = sha256_file(path)
    except OSError as error:
        raise PreparationRejected(f"{label}_missing", str(path)) from error
    if actual != expected:
        raise PreparationRejected(
            f"{label}_sha256_mismatch",
            f"expected {expected}, got {actual}",
        )
    return actual


def require_commit(commit: str, label: str) -> str:
    require_hex(commit, 40, f"{label}_invalid_commit", label)
    result = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), "cat-file", "-e", f"{commit}^{{commit}}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode:
        raise PreparationRejected(f"{label}_missing_commit", commit)
    return commit


def require_ancestor(older: str, newer: str, label: str) -> None:
    result = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), "merge-base", "--is-ancestor", older, newer],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode:
        raise PreparationRejected(f"{label}_ancestry_mismatch", f"{older} !<= {newer}")


def require_file_at_commit(
    commit: str,
    relative: str,
    expected_sha256: str,
    label: str,
) -> None:
    result = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), "show", f"{commit}:{relative}"],
        check=False,
        capture_output=True,
    )
    if result.returncode:
        raise PreparationRejected(
            f"{label}_not_in_commit",
            f"{commit}:{relative}",
        )
    actual = sha256_bytes(result.stdout)
    if actual != expected_sha256:
        raise PreparationRejected(
            f"{label}_commit_content_mismatch",
            f"expected {expected_sha256}, got {actual}",
        )


def load_module(path: pathlib.Path, expected_sha256: str, name: str) -> Any:
    validate_file_hash(path, expected_sha256, name)
    shared_root = str(path.parent)
    if shared_root not in sys.path:
        sys.path.insert(0, shared_root)
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise PreparationRejected(f"{name}_load_failed", str(path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_driver() -> Any:
    spec = importlib.util.spec_from_file_location("play079_launch_runner", DRIVER_PATH)
    if spec is None or spec.loader is None:
        raise PreparationRejected("runner_load_failed", str(DRIVER_PATH))
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def validate_profile_shape(profile: dict[str, Any]) -> None:
    required = {
        "schema",
        "familyIdentity",
        "appearanceLock",
        "lockedMaterialMapping",
        "sourceStageSchema",
        "directionProcesses",
        "computeEnvelope",
        "grants",
    }
    if set(profile) != required:
        raise PreparationRejected(
            "source_profile_schema_invalid",
            f"keys: {sorted(profile)}",
        )
    if profile["schema"] != "citysim.integration.world-art-source-production-profile.v1":
        raise PreparationRejected("source_profile_schema_invalid", str(profile["schema"]))
    if profile["familyIdentity"] != {"family": "industrial", "level": 4, "variant": 0}:
        raise PreparationRejected("source_profile_family_mismatch", repr(profile["familyIdentity"]))
    if profile["sourceStageSchema"] != {
        "path": repository_relative(SCHEMA_PATH),
        "sha256": SCHEMA_SHA256,
    }:
        raise PreparationRejected(
            "source_profile_schema_binding_mismatch",
            repr(profile["sourceStageSchema"]),
        )
    if profile["directionProcesses"] != {
        "north": ["B", "C"],
        "east": ["A", "B", "C"],
        "south": ["A", "B", "C"],
        "west": ["A", "B", "C"],
    }:
        raise PreparationRejected(
            "source_profile_process_release_mismatch",
            repr(profile["directionProcesses"]),
        )
    envelope = profile["computeEnvelope"]
    if (
        not isinstance(envelope, dict)
        or set(envelope) != {"maximumConcurrentDccProcesses", "exceptionOwner"}
        or not isinstance(envelope["maximumConcurrentDccProcesses"], int)
        or envelope["maximumConcurrentDccProcesses"] < 1
        or envelope["exceptionOwner"] != "Integration"
    ):
        raise PreparationRejected("source_profile_compute_envelope_invalid", repr(envelope))
    if profile["grants"] != {
        "sourceAcceptance": False,
        "rendererAdmission": False,
        "productionSelection": False,
        "shippingActivation": False,
    }:
        raise PreparationRejected("source_profile_authority_escalation", repr(profile["grants"]))


def fixed_authorities(contract: dict[str, Any]) -> dict[str, Any]:
    bridge = contract["invariants"]["coordinateBridge"]["v06"]
    return {
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
    }


def profile_authorities(
    contract: dict[str, Any],
    profile: dict[str, Any],
    profile_record: dict[str, str],
) -> dict[str, Any]:
    return {
        **fixed_authorities(contract),
        "appearanceLock": profile["appearanceLock"],
        "lockedMaterialMapping": profile["lockedMaterialMapping"],
        "sourceProductionProfile": profile_record,
    }


def bind_contract(
    contract: dict[str, Any],
    profile: dict[str, Any],
    profile_record: dict[str, str],
) -> dict[str, Any]:
    bound = copy.deepcopy(contract)
    appearance = profile["appearanceLock"]
    appearance_path = repository_path(appearance["documentPath"])
    lock = load_json(appearance_path, "appearance_lock_invalid_json")
    mapping = lock.get("materialRoleMapping")
    if not isinstance(mapping, dict) or not mapping:
        raise PreparationRejected(
            "appearance_lock_material_mapping_missing",
            appearance["documentPath"],
        )
    bound["appearanceLock"] = appearance
    bound["appearanceLockCommit"] = appearance["commit"]
    bound["appearanceLockSha256"] = appearance["documentSha256"]
    bound["lockedMaterialMappingSha256"] = sha256_bytes(canonical_bytes(mapping))
    bound["sourceStage"]["appearanceAuthority"] = {
        "state": "bound",
        "publishedBaseline": bound["baselineCommit"],
        "lockedMaterialMapping": profile["lockedMaterialMapping"],
        "postLockProductionAuthority": profile_record,
    }
    bound["sourceStage"]["sourceProductionProfile"] = {
        "state": "bound",
        **profile_record,
    }
    return bound


def validate_production_authorities(
    appearance_lock_path: pathlib.Path,
    source_profile_path: pathlib.Path,
    source_profile_commit: str,
    source_profile_sha256: str,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, str], Any]:
    profile_relative = require_integration_authority_path(
        source_profile_path,
        "source_profile",
    )
    require_integration_authority_path(appearance_lock_path, "appearance_lock")
    validate_file_hash(source_profile_path, source_profile_sha256, "source_profile")
    require_commit(source_profile_commit, "source_profile")
    require_ancestor(source_profile_commit, "origin/master", "source_profile_publication")
    require_file_at_commit(
        source_profile_commit,
        profile_relative,
        source_profile_sha256,
        "source_profile",
    )
    profile = load_json(source_profile_path, "source_profile_invalid_json")
    validate_profile_shape(profile)
    appearance_record = profile.get("appearanceLock")
    if not isinstance(appearance_record, dict):
        raise PreparationRejected("source_profile_schema_invalid", "appearanceLock")
    expected_appearance = repository_path(appearance_record.get("documentPath", ""))
    if appearance_lock_path.resolve() != expected_appearance:
        raise PreparationRejected(
            "appearance_lock_path_mismatch",
            f"expected {expected_appearance}, got {appearance_lock_path.resolve()}",
        )

    contract = load_json(CONTRACT_PATH, "runner_contract_invalid_json")
    profile_record = {
        "path": profile_relative,
        "commit": source_profile_commit,
        "sha256": source_profile_sha256,
    }
    authorities = profile_authorities(contract, profile, profile_record)
    semantic = load_module(
        SEMANTIC_VALIDATOR_PATH,
        SEMANTIC_VALIDATOR_SHA256,
        "citysim_launch_semantic_v2",
    )
    try:
        semantic.verify_authority_artifacts(REPOSITORY_ROOT, authorities)
    except (semantic.HandoffError, KeyError, TypeError, ValueError) as error:
        raise PreparationRejected(
            "published_authority_validation_failed",
            str(error),
        ) from error

    driver = load_driver()
    bound = bind_contract(contract, profile, profile_record)
    try:
        driver.validate_contract(bound)
        driver.validate_source_stage_authority(bound, appearance_lock_path)
        driver.validate_coordinate_bridge(bound)
    except driver.GuardRejected as error:
        raise PreparationRejected(error.code, error.detail) from error
    return bound, authorities, profile_record, semantic


def build_guard_receipt(
    contract: dict[str, Any],
    authorities: dict[str, Any],
    cell_content_commit: str,
    *,
    fixture_only: bool,
) -> dict[str, Any]:
    return {
        "schema": "citysim.world-art.source-stage-launch-guard.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "branch": "codex/citysim-world-art-east",
        "cellContentCommit": cell_content_commit,
        "result": "PASS",
        "appearanceAuthorityResult": "PASS",
        "sourceProductionProfileResult": "PASS",
        "schemaValidationResult": "PASS",
        "nonAliasInputResult": "PASS",
        "outputRootIsolationResult": "PASS",
        "fixtureOnly": fixture_only,
        "authorities": {
            "appearanceLock": authorities["appearanceLock"],
            "lockedMaterialMapping": authorities["lockedMaterialMapping"],
            "sourceProductionProfile": authorities["sourceProductionProfile"],
        },
        "invocations": {
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "renderInvocations": 0,
        },
        "pixelFiles": 0,
        "candidateReadyForIndependentReview": False,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }


def build_launch_bound_packet(
    contract: dict[str, Any],
    authorities: dict[str, Any],
    guard_receipt: dict[str, Any],
    cell_content_commit: str,
) -> dict[str, Any]:
    source_stage = contract["sourceStage"]
    receipt_path = source_stage["guardReceiptPath"]
    receipt_record = {
        "path": receipt_path,
        "sha256": sha256_bytes(canonical_bytes(guard_receipt)),
    }
    prelaunch_path = repository_path(source_stage["prelaunchHandoff"]["path"])
    launch_root = contract["outputInventory"]["root"]
    return {
        "schemaVersion": 2,
        "stage": "launch_bound",
        "identity": source_stage["identity"],
        "lineage": {
            "publishedBaseline": contract["baselineCommit"],
            "cellContentCommit": cell_content_commit,
        },
        "authorities": authorities,
        "inputs": {
            "prelaunchHandoff": {
                "path": repository_relative(prelaunch_path),
                "sha256": sha256_file(prelaunch_path),
            },
            "frozenInputManifest": source_stage["frozenInputManifest"],
            "runnerContract": {
                "path": repository_relative(CONTRACT_PATH),
                "sha256": sha256_file(CONTRACT_PATH),
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


def validate_packet_structure(packet: dict[str, Any]) -> None:
    import jsonschema

    validate_file_hash(SCHEMA_PATH, SCHEMA_SHA256, "source_stage_schema")
    schema = load_json(SCHEMA_PATH, "source_stage_schema_invalid_json")
    jsonschema.Draft202012Validator.check_schema(schema)
    errors = sorted(
        jsonschema.Draft202012Validator(schema).iter_errors(packet),
        key=lambda error: list(error.path),
    )
    if errors:
        error = errors[0]
        raise PreparationRejected(
            "source_stage_schema_rejected",
            f"{list(error.path)}: {error.message}",
        )


def write_exclusive_atomic(path: pathlib.Path, payload: bytes) -> None:
    if path.exists():
        raise PreparationRejected("launch_artifact_already_exists", repository_relative(path))
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    if temporary.exists():
        raise PreparationRejected("launch_artifact_temporary_exists", str(temporary))
    try:
        with temporary.open("xb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except OSError as error:
        raise PreparationRejected(
            "launch_artifact_write_failed",
            f"{repository_relative(path)}: {error}",
        ) from error
    finally:
        if temporary.exists():
            temporary.unlink()


def prepare_launch(
    appearance_lock: pathlib.Path | None,
    source_profile: pathlib.Path | None,
    source_profile_commit: str | None,
    source_profile_sha256: str | None,
    cell_content_commit: str | None,
) -> dict[str, Any]:
    if source_profile is None:
        raise PreparationRejected(
            "missing_source_production_profile_input",
            "--source-production-profile is required",
        )
    if appearance_lock is None:
        raise PreparationRejected(
            "missing_appearance_lock_input",
            "--appearance-lock is required",
        )
    if source_profile_commit is None:
        raise PreparationRejected(
            "missing_source_profile_commit",
            "--source-profile-commit is required",
        )
    if source_profile_sha256 is None:
        raise PreparationRejected(
            "missing_source_profile_sha256",
            "--source-profile-sha256 is required",
        )
    if cell_content_commit is None:
        raise PreparationRejected(
            "missing_cell_content_commit",
            "--cell-content-commit is required",
        )

    appearance_path = repository_path(appearance_lock)
    profile_path = repository_path(source_profile)
    content_commit = require_commit(cell_content_commit, "cell_content")
    require_ancestor(
        "3ca37996953230b7255f6a22ac1f977c99e56e03",
        content_commit,
        "reviewed_candidate",
    )
    require_ancestor(content_commit, "HEAD", "cell_content")
    bound, authorities, _profile_record, semantic = validate_production_authorities(
        appearance_path,
        profile_path,
        source_profile_commit,
        source_profile_sha256,
    )
    require_ancestor(bound["baselineCommit"], content_commit, "published_baseline")
    receipt = build_guard_receipt(
        bound,
        authorities,
        content_commit,
        fixture_only=False,
    )
    packet = build_launch_bound_packet(bound, authorities, receipt, content_commit)
    validate_packet_structure(packet)

    receipt_path = repository_path(bound["sourceStage"]["guardReceiptPath"])
    handoff_path = repository_path(bound["sourceStage"]["handoffOutputPath"])
    if receipt_path.exists() or handoff_path.exists():
        raise PreparationRejected(
            "launch_artifact_already_exists",
            f"{repository_relative(receipt_path)} or {repository_relative(handoff_path)}",
        )
    receipt_written = False
    handoff_written = False
    try:
        write_exclusive_atomic(receipt_path, canonical_bytes(receipt))
        receipt_written = True
        write_exclusive_atomic(handoff_path, canonical_bytes(packet))
        handoff_written = True
        try:
            semantic_result = semantic.validate(
                REPOSITORY_ROOT,
                SCHEMA_PATH,
                SCHEMA_SHA256,
                handoff_path,
            )
        except (
            semantic.HandoffError,
            json.JSONDecodeError,
            OSError,
            KeyError,
            TypeError,
            ValueError,
        ) as error:
            raise PreparationRejected(
                "source_stage_semantic_validation_failed",
                str(error),
            ) from error
        if semantic_result.get("result") != "PASS" or semantic_result.get("stage") != "launch_bound":
            raise PreparationRejected(
                "source_stage_semantic_validation_failed",
                repr(semantic_result),
            )
    except Exception:
        if handoff_written and handoff_path.exists():
            handoff_path.unlink()
        if receipt_written and receipt_path.exists():
            receipt_path.unlink()
        raise
    return {
        "schema": "citysim.world-art.launch-bound-preparation.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "result": "PASS",
        "stage": "launch_bound",
        "guardReceiptPath": repository_relative(receipt_path),
        "guardReceiptSha256": sha256_file(receipt_path),
        "handoffPath": repository_relative(handoff_path),
        "handoffSha256": sha256_file(handoff_path),
        "semanticValidation": "PASS",
        "filesWritten": 2,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "pixelFiles": 0,
        "sourceReady": False,
        "productionSelected": False,
    }


def dry_structural_fixture(
    fixture_bundle: pathlib.Path | None,
    cell_content_commit: str | None,
) -> dict[str, Any]:
    if fixture_bundle is None:
        raise PreparationRejected("missing_fixture_bundle", "--fixture-bundle is required")
    if cell_content_commit is None:
        raise PreparationRejected(
            "missing_cell_content_commit",
            "--cell-content-commit is required",
        )
    bundle_path = repository_path(fixture_bundle)
    try:
        bundle_path.relative_to(FIXTURE_ROOT)
    except ValueError as error:
        raise PreparationRejected("fixture_outside_task_root", str(bundle_path)) from error
    bundle = load_json(bundle_path, "fixture_bundle_invalid_json")
    if bundle.get("nonProductionFixture") is not True:
        raise PreparationRejected("fixture_disposition_invalid", str(bundle.get("nonProductionFixture")))
    content_commit = require_commit(cell_content_commit, "cell_content")
    profile_path = repository_path(bundle["sourceProductionProfilePath"])
    appearance_path = repository_path(bundle["appearanceLockPath"])
    mapping_path = repository_path(bundle["lockedMaterialMappingPath"])
    for path in (profile_path, appearance_path, mapping_path):
        try:
            path.relative_to(FIXTURE_ROOT)
        except ValueError as error:
            raise PreparationRejected("fixture_outside_task_root", str(path)) from error

    profile = load_json(profile_path, "fixture_source_profile_invalid_json")
    validate_profile_shape(profile)
    appearance_record = {
        "documentPath": repository_relative(appearance_path),
        "commit": content_commit,
        "documentSha256": sha256_file(appearance_path),
        **bundle["northProcessA"],
    }
    mapping_record = {
        "path": repository_relative(mapping_path),
        "commit": content_commit,
        "sha256": sha256_file(mapping_path),
    }
    if profile["appearanceLock"] != appearance_record:
        raise PreparationRejected("fixture_appearance_binding_mismatch", repr(profile["appearanceLock"]))
    if profile["lockedMaterialMapping"] != mapping_record:
        raise PreparationRejected("fixture_material_binding_mismatch", repr(profile["lockedMaterialMapping"]))
    profile_record = {
        "path": repository_relative(profile_path),
        "commit": content_commit,
        "sha256": sha256_file(profile_path),
    }
    contract = load_json(CONTRACT_PATH, "runner_contract_invalid_json")
    authorities = profile_authorities(contract, profile, profile_record)
    receipt = build_guard_receipt(
        contract,
        authorities,
        content_commit,
        fixture_only=True,
    )
    packet = build_launch_bound_packet(contract, authorities, receipt, content_commit)
    validate_packet_structure(packet)
    return {
        "schema": "citysim.world-art.launch-bound-dry-structural-fixture.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "result": "PASS",
        "fixtureOnly": True,
        "fixtureBundle": repository_relative(bundle_path),
        "packetSchemaVersion": packet["schemaVersion"],
        "packetStage": packet["stage"],
        "packetSha256": sha256_bytes(canonical_bytes(packet)),
        "semanticValidation": "not_run_nonproduction_fixture",
        "filesWritten": 0,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "pixelFiles": 0,
        "sourceReady": False,
        "productionSelected": False,
    }


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("prepare", "dry-structural"), required=True)
    parser.add_argument("--appearance-lock", type=pathlib.Path)
    parser.add_argument("--source-production-profile", type=pathlib.Path)
    parser.add_argument("--source-profile-commit")
    parser.add_argument("--source-profile-sha256")
    parser.add_argument("--cell-content-commit")
    parser.add_argument("--fixture-bundle", type=pathlib.Path)
    return parser.parse_args(list(argv))


def main() -> int:
    args = parse_arguments(sys.argv[1:])
    try:
        if args.mode == "prepare":
            result = prepare_launch(
                args.appearance_lock,
                args.source_production_profile,
                args.source_profile_commit,
                args.source_profile_sha256,
                args.cell_content_commit,
            )
        else:
            result = dry_structural_fixture(
                args.fixture_bundle,
                args.cell_content_commit,
            )
        sys.stdout.buffer.write(canonical_bytes(result))
        return 0
    except PreparationRejected as rejection:
        result = {
            "schema": "citysim.world-art.launch-bound-preparation.v1",
            "taskId": "PLAY-079",
            "direction": "east",
            "result": "REJECTED",
            "stage": "before_blender_or_pixels",
            "code": rejection.code,
            "detail": rejection.detail,
            "filesWritten": 0,
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "pixelFiles": 0,
        }
        sys.stdout.buffer.write(canonical_bytes(result))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
