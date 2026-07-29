#!/usr/bin/env python3
"""Validate the PLAY-079 East renderer locator inventory without producing pixels."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import pathlib
import re
import sys
from typing import Any, Iterator


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
EVIDENCE_ROOT = (
    REPOSITORY_ROOT
    / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01"
)
INVENTORY_PATH = EVIDENCE_ROOT / "RENDERER-LOCATOR-INVENTORY.json"
SOURCE_PREFIX = "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/"
EVIDENCE_PREFIX = "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
INTEGRATION_PREFIX = "docs/production/evidence/INTEGRATION/"
EXPECTED_IDENTITY = {
    "taskId": "PLAY-079",
    "direction": "east",
    "branch": "codex/citysim-world-art-east",
    "stage": "prelock_zero_pixel",
}
PINNED_READ_ONLY_PATHS = {
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-predesign-v01/scene.json",
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-predesign-v01/materials.json",
    "docs/production/decisions/CONTRACT-010-directional-building-art.md",
    "docs/production/decisions/CONTRACT-021-parallel-directional-art-cells.md",
    "docs/production/evidence/INTEGRATION/industrial-l04-source-stage-handoff-schema-v2.json",
    "Native/CitySimNative/WorldArt/Shared/validate_source_stage_handoff_v2.py",
    "Native/CitySimNative/WorldArt/Shared/canonical_rgba_v1.swift",
    "docs/production/evidence/INTEGRATION/industrial-l04-accepted-master-non-alias-input-v1.json",
}
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
HEX_40 = re.compile(r"^[0-9a-f]{40}$")


class InventoryRejected(RuntimeError):
    """Stable fail-closed inventory rejection."""

    def __init__(self, code: str, detail: str):
        super().__init__(detail)
        self.code = code
        self.detail = detail


def load_inventory(path: pathlib.Path = INVENTORY_PATH) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise InventoryRejected("inventory_unreadable", str(error)) from error
    if not isinstance(value, dict):
        raise InventoryRejected("inventory_not_object", repr(type(value)))
    return value


def sha256_file(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_repo_relative(path: str, label: str) -> pathlib.Path:
    if not path or path.startswith("/") or "\\" in path:
        raise InventoryRejected("path_not_repo_relative", f"{label}: {path!r}")
    pure = pathlib.PurePosixPath(path)
    if any(part in {"", ".", ".."} for part in pure.parts):
        raise InventoryRejected("path_traversal", f"{label}: {path!r}")
    candidate = (REPOSITORY_ROOT / pure).resolve()
    try:
        candidate.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise InventoryRejected("path_outside_repository", f"{label}: {path!r}") from error
    if candidate.as_posix() != (REPOSITORY_ROOT / pure).as_posix():
        raise InventoryRejected("path_symlink_escape", f"{label}: {path!r}")
    return candidate


def locator_records(value: Any, label: str = "$") -> Iterator[tuple[str, dict[str, Any]]]:
    if isinstance(value, dict):
        if "locatorType" in value:
            yield label, value
            return
        for key, child in value.items():
            yield from locator_records(child, f"{label}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from locator_records(child, f"{label}[{index}]")


def validate_path_ownership(path: str, ownership: str, label: str) -> None:
    if ownership == "east_owned":
        if not (path.startswith(SOURCE_PREFIX) or path.startswith(EVIDENCE_PREFIX)):
            raise InventoryRejected("east_path_escape", f"{label}: {path}")
    elif ownership == "pinned_read_only":
        if path not in PINNED_READ_ONLY_PATHS:
            raise InventoryRejected("pinned_path_drift", f"{label}: {path}")
    elif ownership == "integration_authority":
        if not path.startswith(INTEGRATION_PREFIX):
            raise InventoryRejected("integration_path_escape", f"{label}: {path}")
    else:
        raise InventoryRejected("unknown_ownership", f"{label}: {ownership!r}")


def validate_file_record(label: str, record: dict[str, Any]) -> None:
    status = record.get("status")
    ownership = record.get("ownership")
    path = record.get("path")
    expected_exists = record.get("existsAtInventoryBase")
    if status == "unassigned":
        if path is not None or expected_exists is not False:
            raise InventoryRejected("unassigned_locator_not_null", label)
        if ownership != "integration_authority" and label.endswith("selectedSource"):
            return
        if ownership != "integration_authority":
            raise InventoryRejected("unassigned_ownership_invalid", label)
        return
    if status not in {"existing", "reserved"}:
        raise InventoryRejected("file_status_invalid", f"{label}: {status!r}")
    if not isinstance(path, str):
        raise InventoryRejected("file_path_missing", label)
    if not isinstance(ownership, str):
        raise InventoryRejected("file_ownership_missing", label)
    resolved = require_repo_relative(path, label)
    validate_path_ownership(path, ownership, label)
    actual_exists = resolved.exists()
    if actual_exists != expected_exists:
        raise InventoryRejected(
            "existence_status_mismatch",
            f"{label}: expected {expected_exists}, got {actual_exists}",
        )
    if status == "existing":
        if not actual_exists:
            raise InventoryRejected("existing_locator_missing", label)
        expected_sha = record.get("sha256")
        if not isinstance(expected_sha, str) or not HEX_64.fullmatch(expected_sha):
            raise InventoryRejected("existing_sha256_invalid", label)
        actual_sha = sha256_file(resolved)
        if actual_sha != expected_sha:
            raise InventoryRejected(
                "existing_sha256_mismatch",
                f"{label}: expected {expected_sha}, got {actual_sha}",
            )
    elif actual_exists:
        raise InventoryRejected("reserved_locator_already_exists", label)


def validate_inline_record(label: str, record: dict[str, Any]) -> None:
    if record.get("status") != "inline":
        raise InventoryRejected("inline_status_invalid", label)
    container = record.get("containerPath")
    pointer = record.get("jsonPointer")
    ownership = record.get("ownership")
    expected_exists = record.get("containerExistsAtInventoryBase")
    if not isinstance(container, str) or not isinstance(ownership, str):
        raise InventoryRejected("inline_container_invalid", label)
    if not isinstance(pointer, str) or not pointer.startswith("/"):
        raise InventoryRejected("inline_pointer_invalid", label)
    resolved = require_repo_relative(container, label)
    validate_path_ownership(container, ownership, label)
    if resolved.exists() != expected_exists:
        raise InventoryRejected("inline_container_existence_mismatch", label)


def validate_locator(label: str, record: dict[str, Any]) -> None:
    locator_type = record.get("locatorType")
    if locator_type in {"file", "directory"}:
        validate_file_record(label, record)
    elif locator_type == "inline":
        validate_inline_record(label, record)
    else:
        raise InventoryRejected("locator_type_invalid", f"{label}: {locator_type!r}")


def validate_source_commit_rules(inventory: dict[str, Any]) -> None:
    rules = inventory.get("sourceCommitPlaceholderRules")
    if not isinstance(rules, dict):
        raise InventoryRejected("source_commit_rules_missing", "")
    if rules.get("currentValue") is not None or rules.get("currentStatus") != "unassigned":
        raise InventoryRejected("premature_source_commit", repr(rules.get("currentValue")))
    if rules.get("acceptedPattern") != HEX_40.pattern:
        raise InventoryRejected("source_commit_pattern_drift", repr(rules.get("acceptedPattern")))
    forbidden = rules.get("forbiddenPlaceholders")
    required = {
        "HEAD",
        "TBD",
        "TODO",
        "UNKNOWN",
        "PENDING",
        "0000000000000000000000000000000000000000",
    }
    if not isinstance(forbidden, list) or set(forbidden) != required:
        raise InventoryRejected("source_commit_placeholders_incomplete", repr(forbidden))
    if rules.get("mustResolveToGitCommit") is not True:
        raise InventoryRejected("source_commit_resolution_not_required", "")
    if rules.get("mustContainCandidateBytes") is not True:
        raise InventoryRejected("source_commit_content_not_required", "")


def validate_runner_contract_binding(inventory: dict[str, Any]) -> None:
    contract = load_inventory(SOURCE_ROOT / "RUNNER-CONTRACT.json")
    output_root = contract.get("outputInventory", {}).get("root")
    if output_root != EVIDENCE_PREFIX:
        raise InventoryRejected("contract_output_root_drift", repr(output_root))
    processes = inventory["outputs"]["processes"]
    contract_processes = contract["outputInventory"]["processes"]
    for process_id, slug in (("A", "a"), ("B", "b"), ("C", "c")):
        process = processes[process_id]
        expected_root = f"{EVIDENCE_PREFIX}renders/process-{slug}/"
        if process["outputRoot"]["path"] != expected_root:
            raise InventoryRejected(
                "process_output_root_drift",
                f"{process_id}: {process['outputRoot']['path']}",
            )
        for artifact in ("raw", "semantic", "provenance"):
            expected = output_root + contract_processes[process_id][artifact]
            if process[artifact]["path"] != expected:
                raise InventoryRejected(
                    "process_locator_contract_drift",
                    f"{process_id}.{artifact}: {process[artifact]['path']} != {expected}",
                )
    contract_output = contract["outputInventory"]
    review = inventory["outputs"]["review"]
    review_bindings = {
        "colorSource": output_root + contract_output["color"]["source"],
        "colorNative2x": output_root + contract_output["color"]["native2x"],
        "colorLiteral192": output_root + contract_output["color"]["literal192"],
        "grayscaleSource": output_root + contract_output["grayscale"]["source"],
        "grayscaleNative2x": output_root + contract_output["grayscale"]["native2x"],
        "grayscaleLiteral192": output_root + contract_output["grayscale"]["literal192"],
        "contactSheet": output_root + contract_output["contactSheet"],
    }
    for name, expected in review_bindings.items():
        if review[name]["path"] != expected:
            raise InventoryRejected(
                "review_locator_contract_drift",
                f"{name}: {review[name]['path']} != {expected}",
            )
    registration = inventory["outputs"]["registrationAndContact"]["registrationReceipt"]
    if registration["path"] != output_root + contract_output["registration"]:
        raise InventoryRejected("registration_locator_contract_drift", registration["path"])


def validate_normalization_and_renderer_binding(inventory: dict[str, Any]) -> None:
    normalization = inventory["outputs"]["normalization"]
    lods = inventory["outputs"]["lods"]
    expected_sizes = {
        "city": [256, 171],
        "neighborhood": [512, 342],
        "block": [1024, 683],
    }
    for detail, size in expected_sizes.items():
        if lods[detail]["path"] != normalization["run1"][detail]["path"]:
            raise InventoryRejected("lod_normalization_path_drift", detail)
        if lods[detail]["canvasPixels"] != size:
            raise InventoryRejected("lod_canvas_drift", detail)
    derived = inventory.get("rendererDerived")
    expected_slots = {
        detail: f"industrial_l04_v0_east/{detail}" for detail in expected_sizes
    }
    if not isinstance(derived, dict):
        raise InventoryRejected("renderer_derived_missing", "")
    atlas = derived.get("atlasSlots")
    if (
        not isinstance(atlas, dict)
        or atlas.get("status") != "derived"
        or atlas.get("formula") != "<logicalID>/<detail>"
        or atlas.get("logicalID") != "industrial_l04_v0_east"
        or atlas.get("values") != expected_slots
    ):
        raise InventoryRejected("atlas_slot_derivation_drift", repr(atlas))
    fixture = derived.get("fixturePreparation")
    if not isinstance(fixture, dict) or fixture.get("status") != "unassigned":
        raise InventoryRejected("fixture_preparation_status_drift", repr(fixture))
    if fixture.get("expectedFrontage") != {"status": "derived", "value": "east"}:
        raise InventoryRejected("fixture_frontage_drift", repr(fixture.get("expectedFrontage")))
    for field in (
        "fixtureCoordinate",
        "soleRoadCoordinate",
        "cityCameraScale",
        "neighborhoodCameraScale",
        "blockCameraScale",
    ):
        if fixture.get(field) is not None:
            raise InventoryRejected("fixture_authority_invented", field)


def validate_inventory(inventory: dict[str, Any]) -> dict[str, Any]:
    if inventory.get("schema") != "citysim.play-079.renderer-locator-inventory.v1":
        raise InventoryRejected("schema_mismatch", repr(inventory.get("schema")))
    if inventory.get("schemaVersion") != 1:
        raise InventoryRejected("schema_version_mismatch", repr(inventory.get("schemaVersion")))
    for key, expected in EXPECTED_IDENTITY.items():
        if inventory.get(key) != expected:
            raise InventoryRejected("identity_mismatch", f"{key}: {inventory.get(key)!r}")
    authority = inventory.get("authority")
    if not isinstance(authority, dict):
        raise InventoryRejected("authority_missing", "")
    if authority.get("publishedMaster") != "b8c7725cd9df3ac58af1d2bc6446c4ae00cdb0b1":
        raise InventoryRejected("published_master_mismatch", repr(authority.get("publishedMaster")))
    if authority.get("inventoryBaseCommit") != "9c60c955d5f78f76161a6a4260a3ed0447e678a5":
        raise InventoryRejected("inventory_base_mismatch", repr(authority.get("inventoryBaseCommit")))
    for flag in (
        "appearanceLockPublished",
        "sourceProductionProfilePublished",
        "pixelProductionAuthorized",
    ):
        if authority.get(flag) is not False:
            raise InventoryRejected("zero_pixel_authority_drift", flag)
    validate_source_commit_rules(inventory)
    records = list(locator_records({"inputs": inventory.get("inputs"), "outputs": inventory.get("outputs")}))
    if not records:
        raise InventoryRejected("locator_inventory_empty", "")
    for label, record in records:
        validate_locator(label, record)
    validate_runner_contract_binding(inventory)
    validate_normalization_and_renderer_binding(inventory)
    boundary = inventory.get("zeroPixelBoundary")
    if not isinstance(boundary, dict):
        raise InventoryRejected("zero_pixel_boundary_missing", "")
    for key in (
        "blenderProcessInvocations",
        "blenderRenderApiCalls",
        "imageGenInvocations",
        "normalizerInvocations",
        "contactSheetInvocations",
        "pixelFilesCreated",
    ):
        if boundary.get(key) != 0:
            raise InventoryRejected("forbidden_invocation_recorded", key)
    for key in (
        "sourceReady",
        "integrationAdmitted",
        "rendererQuarantined",
        "productionSelected",
    ):
        if boundary.get(key) is not False:
            raise InventoryRejected("self_admission_recorded", key)
    return {
        "result": "PASS",
        "inventory": str(INVENTORY_PATH.relative_to(REPOSITORY_ROOT)),
        "locatorRecordsValidated": len(records),
        "zeroPixelBoundary": "PASS",
        "sourceCommitPlaceholderRules": "PASS",
    }


def run_escape_self_test(inventory: dict[str, Any]) -> dict[str, Any]:
    cases = (
        ("../escaped-east-root.png", "path_traversal"),
        ("/tmp/escaped-east-root.png", "path_not_repo_relative"),
        (
            "docs/production/evidence/INTEGRATION/escaped-east-root.png",
            "east_path_escape",
        ),
    )
    rejections: list[dict[str, str]] = []
    for value, expected_code in cases:
        fixture = copy.deepcopy(inventory)
        fixture["outputs"]["processes"]["A"]["raw"]["path"] = value
        try:
            validate_inventory(fixture)
        except InventoryRejected as error:
            if error.code != expected_code:
                raise InventoryRejected(
                    "escape_self_test_wrong_rejection",
                    f"{value}: expected {expected_code}, got {error.code}: {error.detail}",
                ) from error
            rejections.append({"mutatedValue": value, "rejectionCode": error.code})
            continue
        raise InventoryRejected("escape_self_test_failed_open", value)
    return {
        "result": "PASS",
        "mutation": "outputs.processes.A.raw.path",
        "cases": rejections,
        "blenderInvocations": 0,
        "pixelFilesCreated": 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--self-test-escape",
        action="store_true",
        help="Mutate an in-memory fixture and prove East-root escape rejection.",
    )
    arguments = parser.parse_args()
    try:
        inventory = load_inventory()
        result = (
            run_escape_self_test(inventory)
            if arguments.self_test_escape
            else validate_inventory(inventory)
        )
    except InventoryRejected as error:
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
