#!/usr/bin/env python3
"""Fail-closed validation for the PLAY-080 South Renderer locator inventory."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Iterator


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
INVENTORY_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/"
    "RENDERER-LOCATOR-INVENTORY.json"
)
CONTRACT_PATH = SOURCE_DIR / "runner-contract.json"

TASK_ID = "PLAY-080"
DIRECTION = "south"
BRANCH = "codex/citysim-world-art-south"
STAGE = "prelock_renderer_locator_inventory"
SOURCE_PREFIX = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
    "industrial-l04-south-source-v01/"
)
EVIDENCE_PREFIX = (
    "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/"
)
INTEGRATION_PREFIX = "docs/production/evidence/INTEGRATION/"
ROOTS = {
    "southSource": SOURCE_PREFIX,
    "southEvidence": EVIDENCE_PREFIX,
    "integrationAuthority": INTEGRATION_PREFIX,
}
PINNED_READ_ONLY_PATHS = {
    (
        "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
        "industrial-l04-south-predesign-v01.scene.json"
    ),
    (
        "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
        "industrial-l04-south-predesign-v01.materials.json"
    ),
    "docs/production/decisions/CONTRACT-010-directional-building-art.md",
    "docs/production/decisions/CONTRACT-021-parallel-directional-art-cells.md",
    (
        "docs/production/evidence/INTEGRATION/"
        "industrial-l04-source-stage-handoff-schema-v2.json"
    ),
    "Native/CitySimNative/WorldArt/Shared/validate_source_stage_handoff_v2.py",
    "Native/CitySimNative/WorldArt/Shared/canonical_rgba_v1.swift",
    (
        "docs/production/evidence/INTEGRATION/"
        "industrial-l04-accepted-master-non-alias-input-v1.json"
    ),
}
SHA256_PATTERN = frozenset("0123456789abcdef")
STATUS_SET = {"existing", "reserved", "inline", "derived", "unassigned"}
ZERO_COUNTERS = (
    "blenderProcessInvocations",
    "blenderRenderApiCalls",
    "imageGenInvocations",
    "normalizerInvocations",
    "contactSheetInvocations",
    "pixelFilesCreated",
)
FALSE_FLAGS = (
    "sourceReady",
    "integrationAdmitted",
    "rendererQuarantined",
    "productionSelected",
)


class InventoryRejected(RuntimeError):
    def __init__(self, code: str, detail: Any):
        super().__init__(code)
        self.code = code
        self.detail = detail


def reject(code: str, detail: Any) -> None:
    raise InventoryRejected(code, detail)


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        reject("INVALID_JSON", {"path": str(path), "detail": str(error)})
    if not isinstance(value, dict):
        reject("INVALID_JSON_OBJECT", str(path))
    return value


def git(*arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=REPOSITORY_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        reject(
            "GIT_COMMAND_FAILED",
            {"arguments": list(arguments), "stderr": result.stderr.strip()},
        )
    return result.stdout.strip()


def require_ancestor(ancestor: str, descendant: str, label: str) -> None:
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", ancestor, descendant],
        cwd=REPOSITORY_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        reject(
            "AUTHORITY_ANCESTRY_MISMATCH",
            {"label": label, "ancestor": ancestor, "descendant": descendant},
        )


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def valid_sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 64
        and set(value).issubset(SHA256_PATTERN)
    )


def require_repo_relative(value: Any, label: str) -> tuple[str, Path]:
    if not isinstance(value, str) or not value or "\\" in value:
        reject("ROOT_PATH_INVALID", {"label": label, "path": value})
    pure = PurePosixPath(value)
    if pure.is_absolute() or any(part in ("", ".", "..") for part in pure.parts):
        reject("ROOT_PATH_INVALID", {"label": label, "path": value})
    lexical = REPOSITORY_ROOT.joinpath(*pure.parts)
    canonical = lexical.resolve()
    try:
        canonical.relative_to(REPOSITORY_ROOT)
    except ValueError:
        reject("REPOSITORY_ESCAPE", {"label": label, "path": value})
    if canonical != lexical:
        reject(
            "SYMLINK_ESCAPE",
            {"label": label, "path": value, "resolved": str(canonical)},
        )
    return value, canonical


def locator_records(
    value: Any, prefix: str
) -> Iterator[tuple[str, dict[str, Any]]]:
    if isinstance(value, dict):
        if "locatorType" in value:
            yield prefix, value
            return
        for key, child in value.items():
            child_prefix = f"{prefix}.{key}" if prefix else key
            yield from locator_records(child, child_prefix)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from locator_records(child, f"{prefix}[{index}]")


def validate_ownership(
    ownership: Any, path_value: str | None, label: str
) -> None:
    if ownership == "south_owned":
        if path_value is not None and not path_value.startswith(
            (SOURCE_PREFIX, EVIDENCE_PREFIX)
        ):
            reject(
                "OWNERSHIP_ESCAPE",
                {"label": label, "ownership": ownership, "path": path_value},
            )
        return
    if ownership == "pinned_read_only":
        if path_value not in PINNED_READ_ONLY_PATHS:
            reject(
                "PINNED_PATH_NOT_ALLOWED",
                {"label": label, "path": path_value},
            )
        return
    if ownership == "integration_authority":
        if path_value is not None and not path_value.startswith(INTEGRATION_PREFIX):
            reject(
                "INTEGRATION_ROOT_ESCAPE",
                {"label": label, "path": path_value},
            )
        return
    reject("UNKNOWN_OWNERSHIP", {"label": label, "ownership": ownership})


def resolve_json_pointer(document: Any, pointer: str, label: str) -> Any:
    if pointer == "":
        return document
    if not pointer.startswith("/"):
        reject("INVALID_JSON_POINTER", {"label": label, "pointer": pointer})
    current = document
    for raw_part in pointer[1:].split("/"):
        part = raw_part.replace("~1", "/").replace("~0", "~")
        if isinstance(current, dict) and part in current:
            current = current[part]
        elif isinstance(current, list) and part.isdigit() and int(part) < len(current):
            current = current[int(part)]
        else:
            reject(
                "INLINE_POINTER_MISSING",
                {"label": label, "pointer": pointer, "part": part},
            )
    return current


def validate_locator(label: str, record: dict[str, Any]) -> str:
    locator_type = record.get("locatorType")
    status = record.get("status")
    ownership = record.get("ownership")
    if status not in STATUS_SET:
        reject("UNKNOWN_STATUS", {"label": label, "status": status})
    if locator_type not in {"file", "directory", "inline"}:
        reject(
            "UNKNOWN_LOCATOR_TYPE",
            {"label": label, "locatorType": locator_type},
        )

    if status == "inline":
        if locator_type != "inline" or "path" in record:
            reject("INLINE_LOCATOR_SHAPE", label)
        container_value = record.get("containerPath")
        container_path, resolved = require_repo_relative(
            container_value, f"{label}.containerPath"
        )
        validate_ownership(ownership, container_path, label)
        pointer = record.get("jsonPointer")
        if not isinstance(pointer, str) or not pointer.startswith("/"):
            reject("INVALID_JSON_POINTER", {"label": label, "pointer": pointer})
        expected_exists = record.get("containerExistsAtInventoryBase")
        if not isinstance(expected_exists, bool):
            reject("INVALID_CONTAINER_EXISTENCE_FLAG", label)
        actual_exists = resolved.is_file()
        if actual_exists != expected_exists:
            reject(
                "INLINE_CONTAINER_EXISTENCE_MISMATCH",
                {
                    "label": label,
                    "path": container_path,
                    "expected": expected_exists,
                    "actual": actual_exists,
                },
            )
        if actual_exists:
            resolve_json_pointer(load_json(resolved), pointer, label)
        return status

    path_value = record.get("path")
    if status == "unassigned":
        if path_value is not None or record.get("existsAtInventoryBase") is not False:
            reject("UNASSIGNED_LOCATOR_NOT_NULL", label)
        if "sha256" in record:
            reject("UNASSIGNED_LOCATOR_HAS_SHA", label)
        validate_ownership(ownership, None, label)
        return status

    path_value, resolved = require_repo_relative(path_value, f"{label}.path")
    validate_ownership(ownership, path_value, label)
    expected_exists = record.get("existsAtInventoryBase")
    if not isinstance(expected_exists, bool):
        reject("INVALID_EXISTENCE_FLAG", label)
    actual_exists = resolved.is_file() if locator_type == "file" else resolved.is_dir()
    if actual_exists != expected_exists:
        reject(
            "LOCATOR_EXISTENCE_MISMATCH",
            {
                "label": label,
                "path": path_value,
                "expected": expected_exists,
                "actual": actual_exists,
            },
        )
    if status == "existing":
        if not actual_exists:
            reject("EXISTING_LOCATOR_MISSING", {"label": label, "path": path_value})
        digest = record.get("sha256")
        if locator_type != "file" or not valid_sha256(digest):
            reject("EXISTING_LOCATOR_SHA_INVALID", label)
        actual_digest = sha256_file(resolved)
        if actual_digest != digest:
            reject(
                "EXISTING_LOCATOR_SHA_MISMATCH",
                {
                    "label": label,
                    "path": path_value,
                    "expected": digest,
                    "actual": actual_digest,
                },
            )
    elif status == "reserved":
        if actual_exists:
            reject("RESERVED_LOCATOR_EXISTS", {"label": label, "path": path_value})
        if "sha256" in record:
            reject("RESERVED_LOCATOR_HAS_SHA", label)
    else:
        reject(
            "STATUS_LOCATOR_TYPE_MISMATCH",
            {"label": label, "status": status, "locatorType": locator_type},
        )
    return status


def expect_locator_path(record: dict[str, Any], expected: str, label: str) -> None:
    if record.get("path") != expected:
        reject(
            "CONTRACT_LOCATOR_DRIFT",
            {"label": label, "expected": expected, "actual": record.get("path")},
        )


def validate_contract_bindings(
    inventory: dict[str, Any], contract: dict[str, Any]
) -> None:
    if contract.get("taskId") != TASK_ID or contract.get("direction") != DIRECTION:
        reject("RUNNER_CONTRACT_IDENTITY_DRIFT", None)
    if contract.get("branch") != BRANCH or contract.get("state") != "awaiting_appearance_lock":
        reject(
            "RUNNER_CONTRACT_STATE_DRIFT",
            {"branch": contract.get("branch"), "state": contract.get("state")},
        )
    future_authority_fields = {
        "appearanceLock": (
            "documentPath",
            "appearanceLockCommit",
            "appearanceLockSha256",
            "northProcessASourceSha256",
            "northProcessADecodedRgbaSha256",
        ),
        "lockedMaterialMapping": ("path", "commit", "sha256"),
        "sourceProductionProfile": ("path", "commit", "sha256"),
        "postLockProductionAuthority": ("path", "commit", "sha256"),
    }
    for authority_name, fields in future_authority_fields.items():
        record = contract.get(authority_name)
        if not isinstance(record, dict) or any(record.get(field) is not None for field in fields):
            reject(
                "PRELOCK_AUTHORITY_UNEXPECTEDLY_POPULATED",
                {"authority": authority_name, "fields": list(fields)},
            )

    processes = inventory["outputs"]["processes"]
    launch_plan = contract["launchPlan"]
    output_inventory = contract["outputInventory"]
    for process in ("A", "B", "C"):
        record = processes[process]
        expected = {
            "outputRoot": launch_plan["isolatedOutputRoots"][process],
            "evidenceRoot": launch_plan["isolatedEvidenceRoots"][process],
            "raw": output_inventory["raw"][process],
            "semantic": output_inventory["semantic"][process],
            "provenance": output_inventory["provenance"][process],
            "runnerReport": output_inventory["runnerReport"][process],
        }
        for field, path in expected.items():
            expect_locator_path(record[field], path, f"outputs.processes.{process}.{field}")

    output_roots = [
        processes[process]["outputRoot"]["path"] for process in ("A", "B", "C")
    ]
    evidence_roots = [
        processes[process]["evidenceRoot"]["path"] for process in ("A", "B", "C")
    ]
    if len(set(output_roots)) != 3 or len(set(evidence_roots)) != 3:
        reject("PROCESS_ROOTS_NOT_DISTINCT", None)

    candidate = contract["candidatePlan"]
    normalization = inventory["outputs"]["normalization"]
    expect_locator_path(
        normalization["normalizedRoot"],
        candidate["normalizedRoot"],
        "outputs.normalization.normalizedRoot",
    )
    expect_locator_path(
        normalization["normalizedSource"],
        candidate["normalizedRoot"] + "source.png",
        "outputs.normalization.normalizedSource",
    )
    expect_locator_path(
        normalization["repeatIdentityReceipt"],
        candidate["validationRoot"] + "normalization-repeat.json",
        "outputs.normalization.repeatIdentityReceipt",
    )

    expected_dimensions = {
        "city": [256, 171],
        "neighborhood": [512, 342],
        "block": [1024, 683],
    }
    for detail, dimensions in expected_dimensions.items():
        lod = inventory["outputs"]["lods"][detail]
        expect_locator_path(
            lod,
            candidate["lodRoot"] + detail + ".png",
            f"outputs.lods.{detail}",
        )
        if lod.get("canvasPixels") != dimensions:
            reject(
                "LOD_DIMENSION_DRIFT",
                {"detail": detail, "actual": lod.get("canvasPixels")},
            )
    expect_locator_path(
        inventory["outputs"]["lods"]["receipt"],
        candidate["validationRoot"] + "lods.json",
        "outputs.lods.receipt",
    )

    review = inventory["outputs"]["review"]
    review_expected = {
        "colorValidation": output_inventory["color"],
        "grayscaleValidation": output_inventory["grayscale"],
        "native2xValidation": output_inventory["native2x"],
        "literal192Validation": output_inventory["literal192"],
        "contactSheet": candidate["contactSheet"],
        "contactSheetReceipt": candidate["validationRoot"] + "contact-sheet.json",
        "sourceOutputValidation": (
            candidate["validationRoot"] + "source-output-validation.json"
        ),
        "reviewManifest": candidate["reviewManifest"],
    }
    for field, path in review_expected.items():
        expect_locator_path(review[field], path, f"outputs.review.{field}")

    receipts = inventory["outputs"]["receiptsAndHandoffs"]
    receipt_expected = {
        "launchGuardReceipt": output_inventory["launchGuardReceipt"],
        "outputRootIsolationReceipt": output_inventory["outputRootIsolationReceipt"],
        "launchBoundHandoff": output_inventory["launchBoundHandoff"],
        "parallelExecutionReceipt": candidate["parallelExecutionReceipt"],
        "rejectedAttemptInventory": candidate["rejectedAttemptInventory"],
        "candidateAssemblyReceipt": candidate["assemblyReceipt"],
    }
    for field, path in receipt_expected.items():
        expect_locator_path(
            receipts[field], path, f"outputs.receiptsAndHandoffs.{field}"
        )
    expect_locator_path(
        inventory["outputs"]["registrationAndContact"]["registrationReceipt"],
        output_inventory["registration"],
        "outputs.registrationAndContact.registrationReceipt",
    )
    expect_locator_path(
        inventory["inputs"]["frozenInputManifest"],
        output_inventory["frozenInputManifest"],
        "inputs.frozenInputManifest",
    )


def validate_derived(inventory: dict[str, Any]) -> None:
    derived = inventory.get("rendererDerived")
    expected_slots = {
        detail: f"industrial_l04_v0_south/{detail}"
        for detail in ("city", "neighborhood", "block")
    }
    if (
        not isinstance(derived, dict)
        or derived.get("atlasSlots", {}).get("status") != "derived"
        or derived["atlasSlots"].get("formula") != "<logicalID>/<detail>"
        or derived["atlasSlots"].get("logicalID") != "industrial_l04_v0_south"
        or derived["atlasSlots"].get("values") != expected_slots
    ):
        reject("RENDERER_DERIVED_ATLAS_DRIFT", derived)
    fixture = derived.get("fixturePreparation", {})
    if (
        fixture.get("status") != "unassigned"
        or fixture.get("expectedFrontage")
        != {"status": "derived", "value": "south"}
        or any(
            fixture.get(key) is not None
            for key in (
                "fixtureCoordinate",
                "soleRoadCoordinate",
                "cityCameraScale",
                "neighborhoodCameraScale",
                "blockCameraScale",
            )
        )
    ):
        reject("RENDERER_FIXTURE_AUTHORITY_DRIFT", fixture)


def validate_zero_pixel_boundary(inventory: dict[str, Any]) -> None:
    boundary = inventory.get("zeroPixelBoundary")
    if not isinstance(boundary, dict):
        reject("ZERO_PIXEL_BOUNDARY_MISSING", None)
    for key in ZERO_COUNTERS:
        if boundary.get(key) != 0:
            reject("ZERO_PIXEL_COUNTER_NONZERO", {"key": key, "value": boundary.get(key)})
    for key in FALSE_FLAGS:
        if boundary.get(key) is not False:
            reject("PRELOCK_FLAG_NOT_FALSE", {"key": key, "value": boundary.get(key)})


def validate_inventory(inventory: dict[str, Any]) -> dict[str, Any]:
    identity = {
        "schema": "citysim.play-080.renderer-locator-inventory.v1",
        "schemaVersion": 1,
        "taskId": TASK_ID,
        "direction": DIRECTION,
        "branch": BRANCH,
        "stage": STAGE,
    }
    for key, expected in identity.items():
        if inventory.get(key) != expected:
            reject(
                "INVENTORY_IDENTITY_DRIFT",
                {"key": key, "expected": expected, "actual": inventory.get(key)},
            )
    if inventory.get("roots") != ROOTS:
        reject("ROOT_DECLARATION_DRIFT", inventory.get("roots"))
    for label, root in ROOTS.items():
        require_repo_relative(root, f"roots.{label}")

    authority = inventory.get("authority", {})
    required_commits = {
        "acceptedSouthAncestor": "a4f0827e1a84108772a068daefdc0b098297355d",
        "publishedMaster": "e9e9ed38bd2abbd720cce9e337b77547494f6ea8",
        "inventoryBaseCommit": "61999bcf3f359976652b434e09ec97e20b380f90",
    }
    for key, expected in required_commits.items():
        if authority.get(key) != expected:
            reject(
                "AUTHORITY_COMMIT_DRIFT",
                {"key": key, "expected": expected, "actual": authority.get(key)},
            )
    for key in (
        "appearanceLockPublished",
        "sourceProductionProfilePublished",
        "pixelProductionAuthorized",
    ):
        if authority.get(key) is not False:
            reject("PRELOCK_AUTHORITY_FLAG_NOT_FALSE", key)
    if git("branch", "--show-current") != BRANCH:
        reject("WRONG_BRANCH", git("branch", "--show-current"))
    head = git("rev-parse", "HEAD")
    origin_master_observed = git("rev-parse", "origin/master")
    for key, commit in required_commits.items():
        require_ancestor(commit, head, f"{key}:HEAD")

    status_counts = {status: 0 for status in STATUS_SET}
    records = list(locator_records(inventory.get("inputs"), "inputs"))
    records.extend(locator_records(inventory.get("outputs"), "outputs"))
    if not records:
        reject("NO_LOCATORS", None)
    for label, record in records:
        status_counts[validate_locator(label, record)] += 1

    contract = load_json(CONTRACT_PATH)
    validate_contract_bindings(inventory, contract)
    validate_derived(inventory)
    validate_zero_pixel_boundary(inventory)
    return {
        "result": "PASS",
        "taskId": TASK_ID,
        "direction": DIRECTION,
        "stage": STAGE,
        "head": head,
        "publishedMaster": required_commits["publishedMaster"],
        "originMasterObserved": origin_master_observed,
        "rootsChecked": ROOTS,
        "locatorCount": len(records),
        "locatorStatusCounts": status_counts,
        "processRootsDistinct": True,
        "runnerContractBound": True,
        "rendererDerivedBound": True,
        "blenderInvocations": 0,
        "pixelFilesCreated": 0,
    }


def run_root_self_test(inventory: dict[str, Any]) -> dict[str, Any]:
    cases = {
        "parentTraversal": ("../escape.png", "ROOT_PATH_INVALID"),
        "absolutePath": ("/tmp/escape.png", "ROOT_PATH_INVALID"),
        "foreignLane": (
            "Native/CitySimNative/WorldArt/Blender/PLAY-999/"
            "foreign-source-v01/raw.png",
            "OWNERSHIP_ESCAPE",
        ),
        "sharedIntegrationRoot": (
            "docs/production/evidence/INTEGRATION/escape.png",
            "OWNERSHIP_ESCAPE",
        ),
        "reservedExistingFile": (
            SOURCE_PREFIX + "runner-contract.json",
            "LOCATOR_EXISTENCE_MISMATCH",
        ),
    }
    results: list[dict[str, str]] = []
    for name, (path, expected_code) in cases.items():
        mutated = copy.deepcopy(inventory)
        mutated["outputs"]["processes"]["A"]["raw"]["path"] = path
        try:
            validate_inventory(mutated)
        except InventoryRejected as error:
            if error.code != expected_code:
                reject(
                    "ROOT_SELF_TEST_WRONG_REJECTION",
                    {
                        "case": name,
                        "expected": expected_code,
                        "actual": error.code,
                    },
                )
            results.append({"case": name, "result": "REJECTED", "code": error.code})
        else:
            reject("ROOT_SELF_TEST_ACCEPTED_ESCAPE", name)
    return {
        "result": "PASS",
        "taskId": TASK_ID,
        "direction": DIRECTION,
        "selfTest": "fail_closed_root_checks",
        "cases": results,
        "blenderInvocations": 0,
        "pixelFilesCreated": 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--self-test-roots",
        action="store_true",
        help="Mutate in-memory locators and prove South/shared root rejection.",
    )
    arguments = parser.parse_args()
    try:
        inventory = load_json(INVENTORY_PATH)
        result = (
            run_root_self_test(inventory)
            if arguments.self_test_roots
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
