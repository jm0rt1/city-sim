#!/usr/bin/env python3
"""Build a BLOCKED, nonshipping East adapter draft for a Renderer proposal."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import pathlib
import subprocess
import sys
from typing import Any


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
EVIDENCE_ROOT = (
    REPOSITORY_ROOT
    / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01"
)
INVENTORY_PATH = EVIDENCE_ROOT / "RENDERER-LOCATOR-INVENTORY.json"
INVENTORY_SHA256 = "c2b673414dfe31bf894e1b959335b4a9a41ec93a720922c64c88a48eb58ef3b8"
INVENTORY_VALIDATOR_PATH = SOURCE_ROOT / "validate_renderer_locator_inventory.py"
INVENTORY_VALIDATOR_SHA256 = (
    "68edf60fc818469dcc972cde6f08849647ff439ba1a434c4511b0dff085f8ca7"
)
SOURCE_STAGE_SCHEMA_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/INTEGRATION/"
    "industrial-l04-source-stage-handoff-schema-v2.json"
)
SOURCE_STAGE_SCHEMA_SHA256 = (
    "93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7"
)
PROPOSAL_COMMIT = "b92406460499bef17b87e8e95622cae1a990b15c"
PROPOSAL_PATH = (
    "docs/production/evidence/PLAY-073/industrial-l04-v2-atomic-assembly-prep/"
    "ASSEMBLY-INPUT-MANIFEST-V1-PROPOSAL.md"
)
PROPOSAL_SHA256 = "ec2e293fbbfa1df900dc50479331d9849da8ed7f1863179c9dd448a9f93c7e1c"
ADAPTER_BASE_COMMIT = "c61be146fc7fe6e64c4d353417770761a12d0e11"
FIXTURE_PATH = SOURCE_ROOT / "fixtures/ASSEMBLY-INPUT-ADAPTER-DRY-FIXTURE.json"
OUTPUT_PATH = EVIDENCE_ROOT / "ASSEMBLY-INPUT-PROPOSAL-ADAPTER-DRY-EVIDENCE.json"
SOURCE_PREFIX = "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/"
EVIDENCE_PREFIX = "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
HEX_DIGITS = frozenset("0123456789abcdef")


class AdapterRejected(RuntimeError):
    """Stable fail-closed adapter rejection."""

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


def repository_relative(path: pathlib.Path) -> str:
    try:
        return str(path.resolve().relative_to(REPOSITORY_ROOT))
    except ValueError as error:
        raise AdapterRejected("path_outside_repository", str(path)) from error


def repository_path(value: str, label: str) -> pathlib.Path:
    if not value or value.startswith("/") or "\\" in value:
        raise AdapterRejected("path_not_repo_relative", f"{label}: {value!r}")
    pure = pathlib.PurePosixPath(value)
    if any(part in {"", ".", ".."} for part in pure.parts):
        raise AdapterRejected("path_traversal", f"{label}: {value!r}")
    resolved = (REPOSITORY_ROOT / pure).resolve()
    try:
        resolved.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise AdapterRejected("path_outside_repository", f"{label}: {value!r}") from error
    return resolved


def require_hex(value: str, length: int, label: str) -> str:
    if len(value) != length or any(character not in HEX_DIGITS for character in value):
        raise AdapterRejected("invalid_hash_or_commit", f"{label}: {value!r}")
    return value


def load_json(path: pathlib.Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise AdapterRejected(f"{label}_unreadable", str(error)) from error
    if not isinstance(value, dict):
        raise AdapterRejected(f"{label}_not_object", repr(type(value)))
    return value


def validate_file_hash(path: pathlib.Path, expected: str, label: str) -> str:
    require_hex(expected, 64, label)
    try:
        actual = sha256_file(path)
    except OSError as error:
        raise AdapterRejected(f"{label}_missing", str(path)) from error
    if actual != expected:
        raise AdapterRejected(
            f"stale_{label}_hash",
            f"expected {expected}, got {actual}",
        )
    return actual


def git_blob(commit: str, path: str) -> bytes:
    require_hex(commit, 40, "proposal_commit")
    repository_path(path, "proposal_path")
    result = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), "show", f"{commit}:{path}"],
        check=False,
        capture_output=True,
    )
    if result.returncode:
        raise AdapterRejected(
            "proposal_blob_missing",
            result.stderr.decode("utf-8", errors="replace").strip(),
        )
    return result.stdout


def validate_git_context() -> None:
    branch = subprocess.run(
        ["git", "-C", str(REPOSITORY_ROOT), "branch", "--show-current"],
        check=False,
        capture_output=True,
        text=True,
    )
    if branch.returncode or branch.stdout.strip() != "codex/citysim-world-art-east":
        raise AdapterRejected("branch_mismatch", branch.stdout.strip())
    ancestor = subprocess.run(
        [
            "git",
            "-C",
            str(REPOSITORY_ROOT),
            "merge-base",
            "--is-ancestor",
            ADAPTER_BASE_COMMIT,
            "HEAD",
        ],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if ancestor.returncode:
        raise AdapterRejected("adapter_base_ancestry_mismatch", ADAPTER_BASE_COMMIT)


def load_inventory_validator() -> Any:
    validate_file_hash(
        INVENTORY_VALIDATOR_PATH,
        INVENTORY_VALIDATOR_SHA256,
        "inventory_validator",
    )
    spec = importlib.util.spec_from_file_location(
        "play079_renderer_locator_validator",
        INVENTORY_VALIDATOR_PATH,
    )
    if spec is None or spec.loader is None:
        raise AdapterRejected("inventory_validator_load_failed", str(INVENTORY_VALIDATOR_PATH))
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def validate_static_bindings() -> tuple[dict[str, Any], dict[str, Any]]:
    validate_git_context()
    validate_file_hash(INVENTORY_PATH, INVENTORY_SHA256, "inventory")
    validate_file_hash(SOURCE_STAGE_SCHEMA_PATH, SOURCE_STAGE_SCHEMA_SHA256, "schema")
    proposal = git_blob(PROPOSAL_COMMIT, PROPOSAL_PATH)
    actual_proposal_sha = sha256_bytes(proposal)
    if actual_proposal_sha != PROPOSAL_SHA256:
        raise AdapterRejected(
            "stale_proposal_hash",
            f"expected {PROPOSAL_SHA256}, got {actual_proposal_sha}",
        )
    validator = load_inventory_validator()
    try:
        inventory = validator.load_inventory(INVENTORY_PATH)
        inventory_result = validator.validate_inventory(inventory)
    except Exception as error:
        code = getattr(error, "code", "inventory_validation_failed")
        detail = getattr(error, "detail", str(error))
        raise AdapterRejected(str(code), str(detail)) from error
    schema = load_json(SOURCE_STAGE_SCHEMA_PATH, "schema")
    if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
        raise AdapterRejected("schema_identity_mismatch", repr(schema.get("$schema")))
    return inventory, inventory_result


def validate_fixture(fixture: dict[str, Any]) -> None:
    expected_keys = {
        "schema",
        "mode",
        "proposal",
        "locatorInventory",
        "sourceStageSchema",
        "requestedOutputPath",
        "syntheticOnly",
    }
    if set(fixture) != expected_keys:
        raise AdapterRejected("fixture_keys_invalid", repr(sorted(fixture)))
    if fixture["schema"] != "citysim.play-079.assembly-input-adapter.synthetic-fixture.v1":
        raise AdapterRejected("fixture_schema_invalid", repr(fixture["schema"]))
    if fixture["mode"] != "synthetic_blocked_dry_evidence":
        raise AdapterRejected("fixture_mode_invalid", repr(fixture["mode"]))
    expected_proposal = {
        "commit": PROPOSAL_COMMIT,
        "path": PROPOSAL_PATH,
        "sha256": PROPOSAL_SHA256,
        "authorityStatus": "proposal_only",
    }
    if fixture["proposal"] != expected_proposal:
        if fixture.get("proposal", {}).get("sha256") != PROPOSAL_SHA256:
            raise AdapterRejected("stale_proposal_hash", repr(fixture.get("proposal")))
        raise AdapterRejected("proposal_binding_mismatch", repr(fixture["proposal"]))
    expected_inventory = {
        "path": repository_relative(INVENTORY_PATH),
        "sha256": INVENTORY_SHA256,
        "recordCount": 59,
    }
    if fixture["locatorInventory"] != expected_inventory:
        if fixture.get("locatorInventory", {}).get("sha256") != INVENTORY_SHA256:
            raise AdapterRejected("stale_inventory_hash", repr(fixture.get("locatorInventory")))
        raise AdapterRejected("inventory_binding_mismatch", repr(fixture["locatorInventory"]))
    expected_schema = {
        "path": repository_relative(SOURCE_STAGE_SCHEMA_PATH),
        "sha256": SOURCE_STAGE_SCHEMA_SHA256,
    }
    if fixture["sourceStageSchema"] != expected_schema:
        if fixture.get("sourceStageSchema", {}).get("sha256") != SOURCE_STAGE_SCHEMA_SHA256:
            raise AdapterRejected("stale_schema_hash", repr(fixture.get("sourceStageSchema")))
        raise AdapterRejected("schema_binding_mismatch", repr(fixture["sourceStageSchema"]))
    output_value = fixture["requestedOutputPath"]
    if not isinstance(output_value, str):
        raise AdapterRejected("output_path_invalid", repr(output_value))
    output = repository_path(output_value, "requested_output")
    if output != OUTPUT_PATH.resolve():
        raise AdapterRejected("output_path_not_task_owned", output_value)
    if not output_value.startswith(EVIDENCE_PREFIX):
        raise AdapterRejected("output_path_not_east_evidence", output_value)
    expected_synthetic = {
        "acceptedL3Baseline": None,
        "appearanceLock": None,
        "sourceProductionProfile": None,
        "postLockProductionAuthority": None,
        "selectedProcess": None,
        "sourceCommit": None,
        "integrationSourceAdmission": None,
        "rendererQuarantineReceipt": None,
        "fixturePreparation": None,
        "camera": None,
        "atlasSlot": None,
    }
    if fixture["syntheticOnly"] != expected_synthetic:
        raise AdapterRejected("invented_authority_or_source_value", repr(fixture["syntheticOnly"]))


def expect_rejection(fixture: dict[str, Any], mutation: str, value: Any, code: str) -> dict[str, Any]:
    candidate = copy.deepcopy(fixture)
    if mutation == "locatorInventory.sha256":
        candidate["locatorInventory"]["sha256"] = value
    elif mutation == "sourceStageSchema.sha256":
        candidate["sourceStageSchema"]["sha256"] = value
    elif mutation == "proposal.sha256":
        candidate["proposal"]["sha256"] = value
    elif mutation == "requestedOutputPath":
        candidate["requestedOutputPath"] = value
    else:
        raise AdapterRejected("unknown_self_test_mutation", mutation)
    try:
        validate_fixture(candidate)
    except AdapterRejected as error:
        if error.code != code:
            raise AdapterRejected(
                "self_test_wrong_rejection",
                f"{mutation}: expected {code}, got {error.code}",
            ) from error
        return {"mutation": mutation, "value": value, "rejectionCode": error.code}
    raise AdapterRejected("self_test_failed_open", mutation)


def run_negative_tests(fixture: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        expect_rejection(
            fixture,
            "locatorInventory.sha256",
            "0" * 64,
            "stale_inventory_hash",
        ),
        expect_rejection(
            fixture,
            "sourceStageSchema.sha256",
            "0" * 64,
            "stale_schema_hash",
        ),
        expect_rejection(
            fixture,
            "proposal.sha256",
            "0" * 64,
            "stale_proposal_hash",
        ),
        expect_rejection(
            fixture,
            "requestedOutputPath",
            "../ASSEMBLY-INPUT-PROPOSAL-ADAPTER-DRY-EVIDENCE.json",
            "path_traversal",
        ),
        expect_rejection(
            fixture,
            "requestedOutputPath",
            "docs/production/evidence/INTEGRATION/ASSEMBLY-INPUT.json",
            "output_path_not_task_owned",
        ),
    ]


def artifact_path(record: dict[str, Any]) -> str | None:
    path = record.get("path")
    return path if isinstance(path, str) else None


def build_mapping(inventory: dict[str, Any]) -> dict[str, Any]:
    processes = inventory["outputs"]["processes"]
    normalization = inventory["outputs"]["normalization"]
    review = inventory["outputs"]["review"]
    descriptor = inventory["inputs"]["acceptedPredesignDescriptor"]
    contact = inventory["outputs"]["registrationAndContact"]
    packet = inventory["outputs"]["receiptsAndHandoffs"]["sourceStageHandoff"]
    return {
        "status": "BLOCKED",
        "direction": "east",
        "packet": {
            "status": "BLOCKED_MISSING_FUTURE_BYTES",
            "path": artifact_path(packet),
            "sha256": None,
        },
        "sourceAdmission": {
            "status": "BLOCKED_INTEGRATION_AUTHORITY_MISSING",
            "path": None,
            "sha256": None,
        },
        "quarantineReceipt": {
            "status": "BLOCKED_RENDERER_AUTHORITY_MISSING",
            "path": None,
            "sha256": None,
        },
        "locators": {
            "raw": {
                "status": "BLOCKED_SELECTION_AND_PIXELS_MISSING",
                "path": None,
                "sha256": None,
                "candidatePaths": {
                    process_id: artifact_path(processes[process_id]["raw"])
                    for process_id in ("A", "B", "C")
                },
            },
            "provenance": {
                "status": "BLOCKED_SELECTION_AND_BYTES_MISSING",
                "path": None,
                "sha256": None,
                "candidatePaths": {
                    process_id: artifact_path(processes[process_id]["provenance"])
                    for process_id in ("A", "B", "C")
                },
            },
            "normalization": {
                "status": "BLOCKED_SINGULAR_MAPPING_UNPUBLISHED_AND_BYTES_MISSING",
                "path": None,
                "sha256": None,
                "run1CandidatePaths": {
                    detail: artifact_path(normalization["run1"][detail])
                    for detail in ("city", "neighborhood", "block")
                },
                "run2CandidatePaths": {
                    detail: artifact_path(normalization["run2"][detail])
                    for detail in ("city", "neighborhood", "block")
                },
            },
            "descriptor": {
                "status": "BLOCKED_FUTURE_SOURCE_AUTHORITY_FALSE",
                "path": artifact_path(descriptor),
                "sha256": descriptor["sha256"],
                "futureSourceAuthority": descriptor["futureSourceAuthority"],
            },
            "contact": {
                "status": "BLOCKED_STANDALONE_BYTE_LOCATOR_MISSING",
                "path": None,
                "sha256": None,
                "inlineContainers": [
                    {
                        "containerPath": contact["predesignContact"]["containerPath"],
                        "jsonPointer": contact["predesignContact"]["jsonPointer"],
                    },
                    {
                        "containerPath": contact["sourceCandidateContact"]["containerPath"],
                        "jsonPointer": contact["sourceCandidateContact"]["jsonPointer"],
                    },
                ],
            },
            "review": {
                "status": "BLOCKED_REVIEW_BYTES_AND_SHARED_MAPPING_MISSING",
                "path": artifact_path(review["reviewManifest"]),
                "sha256": None,
                "alternativeReservedSurfaces": [
                    artifact_path(review[name])
                    for name in (
                        "colorSource",
                        "colorNative2x",
                        "colorLiteral192",
                        "grayscaleSource",
                        "grayscaleNative2x",
                        "grayscaleLiteral192",
                        "contactSheet",
                    )
                ],
            },
        },
    }


def build_evidence(
    fixture: dict[str, Any],
    inventory: dict[str, Any],
    inventory_result: dict[str, Any],
    negative_tests: list[dict[str, Any]],
) -> dict[str, Any]:
    blockers = [
        "assembly_input_manifest_v1_is_proposal_only",
        "canonical_integration_schema_and_document_binding_missing",
        "accepted_l3_baseline_missing",
        "appearance_lock_missing",
        "source_production_profile_missing",
        "post_lock_production_authority_missing",
        "source_commit_missing",
        "selected_process_missing",
        "worker_packet_bytes_and_hash_missing",
        "integration_source_admission_missing",
        "renderer_quarantine_receipt_missing",
        "raw_and_provenance_bytes_missing",
        "singular_normalization_locator_authority_missing",
        "descriptor_future_source_authority_false",
        "standalone_contact_byte_locator_missing",
        "review_bytes_and_singular_mapping_missing",
        "four_direction_admitted_quarantined_set_missing",
    ]
    return {
        "schema": "citysim.play-079.assembly-input-proposal-adapter-dry-evidence.v1",
        "schemaVersion": 1,
        "taskId": "PLAY-079",
        "direction": "east",
        "branch": "codex/citysim-world-art-east",
        "adapterDisposition": "BLOCKED",
        "proposalOnly": True,
        "nonshipping": True,
        "adapterBaseCommit": ADAPTER_BASE_COMMIT,
        "bindings": {
            "adapter": {
                "path": repository_relative(pathlib.Path(__file__)),
                "sha256": sha256_file(pathlib.Path(__file__)),
            },
            "syntheticFixture": {
                "path": repository_relative(FIXTURE_PATH),
                "sha256": sha256_file(FIXTURE_PATH),
            },
            "proposal": fixture["proposal"],
            "locatorInventory": fixture["locatorInventory"],
            "sourceStageSchema": fixture["sourceStageSchema"],
        },
        "mapping": build_mapping(inventory),
        "blockedFields": blockers,
        "authorityAndSourceValues": fixture["syntheticOnly"],
        "validation": {
            "result": "PASS_BLOCKED",
            "locatorInventoryValidation": inventory_result,
            "negativeCases": negative_tests,
            "allRejectionsBeforeWrite": True,
        },
        "writeBoundary": {
            "assemblyInputManifestWritten": False,
            "atomicAdmissionLedgerWritten": False,
            "sharedFilesWritten": 0,
            "runtimeFilesWritten": 0,
            "shippingFilesWritten": 0,
            "atlasFilesWritten": 0,
            "fixtureFilesWritten": 0,
            "dryEvidenceFilesWritten": 1,
        },
        "zeroPixelBoundary": {
            "blenderInvocations": 0,
            "renderInvocations": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "pixelFilesCreated": 0,
            "sourceReady": False,
            "integrationAdmitted": False,
            "rendererQuarantined": False,
            "productionSelected": False,
        },
    }


def prepare() -> tuple[dict[str, Any], dict[str, Any], list[dict[str, Any]], dict[str, Any]]:
    inventory, inventory_result = validate_static_bindings()
    fixture = load_json(FIXTURE_PATH, "fixture")
    validate_fixture(fixture)
    negative_tests = run_negative_tests(fixture)
    evidence = build_evidence(fixture, inventory, inventory_result, negative_tests)
    return fixture, inventory_result, negative_tests, evidence


def write_evidence(evidence: dict[str, Any]) -> None:
    output_value = repository_relative(OUTPUT_PATH)
    if not output_value.startswith(EVIDENCE_PREFIX):
        raise AdapterRejected("output_path_not_east_evidence", output_value)
    OUTPUT_PATH.write_bytes(canonical_bytes(evidence))


def validate_existing(evidence: dict[str, Any]) -> None:
    try:
        actual = OUTPUT_PATH.read_bytes()
    except OSError as error:
        raise AdapterRejected("dry_evidence_missing", str(error)) from error
    expected = canonical_bytes(evidence)
    if actual != expected:
        raise AdapterRejected(
            "dry_evidence_drift",
            f"expected {sha256_bytes(expected)}, got {sha256_bytes(actual)}",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--validate-only", action="store_true")
    mode.add_argument("--self-test", action="store_true")
    mode.add_argument("--write-dry-evidence", action="store_true")
    mode.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    try:
        _, inventory_result, negative_tests, evidence = prepare()
        if arguments.write_dry_evidence:
            write_evidence(evidence)
        elif arguments.check:
            validate_existing(evidence)
        result = {
            "result": "PASS_BLOCKED",
            "adapterDisposition": "BLOCKED",
            "proposalOnly": True,
            "nonshipping": True,
            "inventoryRecordsValidated": inventory_result["locatorRecordsValidated"],
            "negativeCasesPassed": len(negative_tests),
            "dryEvidenceWritten": bool(arguments.write_dry_evidence),
            "existingEvidenceValidated": bool(arguments.check),
            "blenderInvocations": 0,
            "pixelFilesCreated": 0,
        }
    except AdapterRejected as error:
        print(
            json.dumps(
                {"result": "REJECTED", "code": error.code, "detail": error.detail},
                sort_keys=True,
            )
        )
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
