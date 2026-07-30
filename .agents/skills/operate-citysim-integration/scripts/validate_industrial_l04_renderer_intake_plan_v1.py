#!/usr/bin/env python3
"""Fail-closed validation for the Industrial L4 Renderer intake-ahead plan."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

SHA256 = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")
BASE = "9217e64c796fef3e9d45d0726453157e70b4ef16"
DIRECTIONS = ("north", "east", "south", "west")
LODS = (
    ("city", (256, 171)),
    ("neighborhood", (512, 342)),
    ("block", (1024, 683)),
)

EXPECTED_INPUTS = {
    "accepted_master_non_alias_input": (
        "docs/production/evidence/INTEGRATION/industrial-l04-accepted-master-non-alias-input-v1.json",
        "d1d75fdc30d9a2f21d49b59fd13dbc6fe7d81669f76f801d1087b35a7fb70044",
    ),
    "arrival_gate_preparation_authority": (
        "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-ARRIVAL-GATE-PREP-AUTHORITY.md",
        "67f364ec42d31ad97a09b896d6625029c02875b15c2f1adbb47201249ea2ffa6",
    ),
    "atomic_assembler": (
        "docs/production/evidence/PLAY-073/industrial-l04-v2-atomic-assembly-prep/tools/assemble_quarantined_family.sh",
        "f5a4c672a76b005385fb66fbcf87a55b71477b9cd67f59a63ae313371cf8a5ab",
    ),
    "atomic_assembler_harness": (
        "Native/CitySimNative/Tests/CitySimNativeTests/IndustrialL4V2SourceAdmissionHarnessTests.swift",
        "bebe5b098a6d4603d5a680a123eded0a0b5cb5fd8dde6c2c1a5cff7b9aeffdc1",
    ),
    "atomic_manifest_proposal": (
        "docs/production/evidence/PLAY-073/industrial-l04-v2-atomic-assembly-prep/ASSEMBLY-INPUT-MANIFEST-V1-PROPOSAL.md",
        "ec2e293fbbfa1df900dc50479331d9849da8ed7f1863179c9dd448a9f93c7e1c",
    ),
    "direction_bridge": (
        "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json",
        "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7",
    ),
    "direction_quarantine_packet_schema": (
        "docs/production/evidence/PLAY-073/industrial-l04-direction-quarantine-v1/DIRECTION-PACKET-SCHEMA.json",
        "4b4d0b6e48cd23535d79b0dc6f515be5de5367d931099aaed391c7983f866c83",
    ),
    "family_contract": (
        "docs/production/decisions/CONTRACT-010-directional-building-art.md",
        "0ee2d68a9dba4694d92a864bfeb5a91970c88fe87d893e1898de7b26d38609af",
    ),
    "industrial_l3_catalog": (
        "Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-073-industrial-l3-directions.json",
        "e9fa8eda7330385d478fbcac358bdce444e996ce6e4e7c373271426cba4cd136",
    ),
    "industrial_l3_source_manifest": (
        "docs/production/evidence/PLAY-027/industrial-l03/l03/source-v06-complete-family-v01/FAMILY-MANIFEST.json",
        "78fef5beed40229d0637ba74e85737c939bbaa460f42a17b49f24769e92704a1",
    ),
    "mature_city_fixture": (
        "docs/production/evidence/PLAY-075/industrial-l4-family-preregistration-v1/fixtures/industrial-l03-directional-mature-city-v1.json",
        "b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5",
    ),
    "mature_city_fixture_manifest": (
        "docs/production/evidence/PLAY-075/industrial-l4-family-preregistration-v1/fixtures/industrial-l03-directional-mature-city-manifest-v1.json",
        "48b23638572993f76c087c95113475b2c0e3d59e89525a12fcb7ee38005f2a2d",
    ),
    "parallel_cells_contract": (
        "docs/production/decisions/CONTRACT-021-parallel-directional-art-cells.md",
        "f80844c928d904498510b8b151381f40315e072d52d81695aafcd6b91081ae4c",
    ),
    "qa_camera_preflight": (
        "docs/production/evidence/PLAY-075/industrial-l4-family-preregistration-v1/production-quality-rubric-v2/FIXTURE-CAMERA-PREFLIGHT.json",
        "d8cf5a73c4f23e13aa6be939eedda303627856f4c202cf1e38ac81f9a24ac985",
    ),
    "quarantine_preparation_authority": (
        "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-RENDERER-QUARANTINE-PREP-AUTHORITY.md",
        "a9e60a2db3bdcaa4e2594311f5bd5415a124ce22b2119bf5aba1ec7a2f55e743",
    ),
    "shipping_manifest": (
        "Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/generated-v4-manifest.json",
        "317802265010fc758b232bea9198f18ec0ca4d75b5ceb6f759206238717cec92",
    ),
    "source_admission_receipt_schema": (
        "docs/production/evidence/INTEGRATION/industrial-l04-source-admission-receipt-schema-v1.json",
        "08ad183eb90dc8eb14567a432c00841b010f90f8d8e4d359b60d4735c4ca4f66",
    ),
    "source_admission_receipt_validator": (
        ".agents/skills/operate-citysim-integration/scripts/validate_industrial_l04_source_admission_receipt_v1.py",
        "46a9af769c1d3cf291c4859c79858373c576a70e17c8ccffd62d5619db0ef731",
    ),
    "source_stage_schema": (
        "docs/production/evidence/INTEGRATION/industrial-l04-source-stage-handoff-schema-v2.json",
        "85f6a2824c273a1e63354df79a97e5a59c2909a68771613b325664d649ac53ec",
    ),
    "source_stage_semantic_validator": (
        "Native/CitySimNative/WorldArt/Shared/validate_source_stage_handoff_v2.py",
        "7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340",
    ),
}

EXPECTED_TASK = {
    "north": "PLAY-027",
    "east": "PLAY-079",
    "south": "PLAY-080",
    "west": "PLAY-081",
}
EXPECTED_REGISTRATION = {
    "north": {
        "frontageEdge": "north",
        "frontageSocketSource": [896, 704],
        "frontageSource": [[768, 640], [1024, 768]],
        "socketCitySim": [0, 0, -28],
    },
    "east": {
        "frontageEdge": "east",
        "frontageSocketSource": [896, 832],
        "frontageSource": [[1024, 768], [768, 896]],
        "socketCitySim": [28, 0, 0],
    },
    "south": {
        "frontageEdge": "south",
        "frontageSocketSource": [640, 832],
        "frontageSource": [[768, 896], [512, 768]],
        "socketCitySim": [0, 0, 28],
    },
    "west": {
        "frontageEdge": "west",
        "frontageSocketSource": [640, 704],
        "frontageSource": [[512, 768], [768, 640]],
        "socketCitySim": [-28, 0, 0],
    },
}
EXPECTED_REJECTIONS = {
    "missing_or_extra_direction",
    "logical_id_or_slot_mismatch",
    "duplicate_source_or_lod_hash",
    "accepted_master_alias",
    "sibling_alias",
    "mirror_rotation_or_other_d4_transform",
    "fallback_or_substitution",
    "frontage_or_socket_drift",
    "pivot_footprint_contact_or_canvas_drift",
    "lod_count_order_or_canvas_drift",
    "family_contract_or_bridge_drift",
    "source_admission_or_quarantine_receipt_drift",
    "production_selected_input",
    "partial_family_activation",
    "path_escape_or_symlink_escape",
    "runtime_shipping_or_package_mutation",
}
EXPECTED_ALLOWED = {
    "prepare_direction_id_and_slot_assertions",
    "prepare_read_only_fixture_placement_descriptors",
    "prepare_camera_and_lod_expectations",
    "prepare_direction_local_quarantine_invocations",
    "prepare_nonshipping_atomic_assembler_invocation",
    "emit_task_owned_synthetic_validation_evidence",
}
EXPECTED_FORBIDDEN = {
    "source_pixel_creation_or_edit",
    "source_admission",
    "shipping_atlas_mutation",
    "shipping_manifest_mutation",
    "runtime_mapping_mutation",
    "package_or_build_resource_mutation",
    "production_selection",
    "partial_family_activation",
    "staged_app_build_launch_capture_or_score",
    "qa_disposition",
    "integration_or_push",
}


class IntakePlanError(ValueError):
    """A fail-closed intake-plan validation error."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise IntakePlanError(message)


def exact_keys(value: object, keys: set[str], label: str) -> dict:
    require(isinstance(value, dict), f"{label} must be an object")
    require(set(value) == keys, f"{label} fields do not match v1")
    return value


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resolve_artifact(root: Path, path: str, label: str) -> Path:
    require(isinstance(path, str) and path and not path.startswith("/"), f"{label}.path must be repository-relative")
    require(".." not in Path(path).parts, f"{label}.path contains traversal")
    resolved_root = root.resolve()
    resolved = (resolved_root / path).resolve(strict=True)
    require(resolved.is_relative_to(resolved_root), f"{label}.path escapes repository")
    require(resolved.is_file(), f"{label}.path is not a file")
    return resolved


def validate_artifact(root: Path, value: object, label: str) -> tuple[str, str]:
    artifact = exact_keys(value, {"path", "sha256"}, label)
    path = artifact["path"]
    sha = artifact["sha256"]
    require(isinstance(sha, str) and SHA256.fullmatch(sha) is not None, f"{label}.sha256 is invalid")
    resolved = resolve_artifact(root, path, label)
    require(digest(resolved) == sha, f"{label}.sha256 is stale")
    return path, sha


def validate_nullable(value: object, label: str) -> None:
    expected = {
        "path": None,
        "sha256": None,
        "status": "unbound_until_integration_admitted",
    }
    require(value == expected, f"{label} must remain an unbound Integration placeholder")


def require_git_base(root: Path) -> None:
    require(COMMIT.fullmatch(BASE) is not None, "published base is malformed")
    exists = subprocess.run(
        ["git", "cat-file", "-e", f"{BASE}^{{commit}}"],
        cwd=root,
        capture_output=True,
        check=False,
    )
    require(exists.returncode == 0, "published base is not a repository commit")
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", BASE, "HEAD"],
        cwd=root,
        capture_output=True,
        check=False,
    )
    require(ancestor.returncode == 0, "published base is not an ancestor of HEAD")


def validate_bound_inputs(root: Path, entries: object) -> dict[str, tuple[str, str]]:
    require(isinstance(entries, list), "boundInputs must be an array")
    found: dict[str, tuple[str, str]] = {}
    seen_paths: set[str] = set()
    for index, raw in enumerate(entries):
        entry = exact_keys(raw, {"role", "path", "sha256"}, f"boundInputs[{index}]")
        role = entry["role"]
        require(isinstance(role, str) and role not in found, "bound input roles must be unique")
        path, sha = validate_artifact(
            root,
            {"path": entry["path"], "sha256": entry["sha256"]},
            f"boundInputs[{role}]",
        )
        require(path not in seen_paths, f"bound input path is duplicated: {path}")
        seen_paths.add(path)
        found[role] = (path, sha)
    require(found == EXPECTED_INPUTS, "boundInputs do not exactly match the frozen master inputs")
    return found


def validate_family(value: object) -> None:
    family = exact_keys(
        value,
        {
            "batch",
            "family",
            "level",
            "variant",
            "directionOrder",
            "sharedRegistration",
            "light",
            "runtimeDirectionSelection",
        },
        "family",
    )
    require(family["batch"] == "industrial_l04_directional_family", "wrong family batch")
    require((family["family"], family["level"], family["variant"]) == ("industrial", 4, 0), "wrong family identity")
    require(family["directionOrder"] == list(DIRECTIONS), "direction order must be N/E/S/W")
    require(
        family["sharedRegistration"]
        == {
            "canvasPixels": [1536, 1024],
            "footprintTiles": [1, 1],
            "groundPivotSource": [768, 896],
            "contactPolygonCitySimXZ": [[-28, -28], [28, -28], [28, 28], [-28, 28]],
            "tileBasisPoints": [72, 36],
        },
        "shared registration drift",
    )
    require(family["light"] == {"key": "northwest", "shadow": "southeast"}, "light or shadow drift")
    require(
        family["runtimeDirectionSelection"] == "authoritative_adjacent_road_frontage_only",
        "runtime direction selection must remain frontage-owned",
    )


def validate_directions(entries: object, bridge: dict) -> None:
    require(isinstance(entries, list) and len(entries) == 4, "directionIntake must contain exactly four entries")
    seen_ids: set[str] = set()
    seen_slots: set[str] = set()
    for index, direction in enumerate(DIRECTIONS):
        entry = exact_keys(
            entries[index],
            {"direction", "sourceTask", "logicalID", "lods", "registration", "futureInputs"},
            f"directionIntake[{index}]",
        )
        require(entry["direction"] == direction, "directionIntake order drift")
        require(entry["sourceTask"] == EXPECTED_TASK[direction], f"{direction} source task drift")
        logical_id = f"industrial_l04_v0_{direction}"
        require(entry["logicalID"] == logical_id and logical_id not in seen_ids, f"{direction} logical ID drift or alias")
        seen_ids.add(logical_id)
        lods = entry["lods"]
        require(isinstance(lods, list) and len(lods) == 3, f"{direction} requires three LODs")
        for lod_index, (detail, canvas) in enumerate(LODS):
            expected_lod = {
                "detail": detail,
                "atlasSlot": f"{logical_id}/{detail}",
                "canvasPixels": list(canvas),
            }
            require(lods[lod_index] == expected_lod, f"{direction} {detail} LOD binding drift")
            require(lods[lod_index]["atlasSlot"] not in seen_slots, "atlas slot alias")
            seen_slots.add(lods[lod_index]["atlasSlot"])
        require(entry["registration"] == EXPECTED_REGISTRATION[direction], f"{direction} registration drift")
        bridge_direction = bridge["directions"][direction]
        require(
            entry["registration"]["frontageSocketSource"] == bridge_direction["socketSource"]
            and entry["registration"]["frontageSource"] == bridge_direction["frontageSource"]
            and entry["registration"]["socketCitySim"] == bridge_direction["socketCitySim"],
            f"{direction} does not match the bound bridge",
        )
        future = exact_keys(
            entry["futureInputs"],
            {"sourcePacket", "sourceAdmission", "quarantineReceipt"},
            f"{direction}.futureInputs",
        )
        for key in ("sourcePacket", "sourceAdmission", "quarantineReceipt"):
            validate_nullable(future[key], f"{direction}.futureInputs.{key}")
    require(len(seen_ids) == 4 and len(seen_slots) == 12, "direction or LOD identities are not unique")


def validate_graph(value: object) -> None:
    graph = exact_keys(value, {"execution", "directionJobs", "join"}, "quarantineGraph")
    require(graph["execution"] == "direction_local_parallel", "quarantine execution must be direction-local parallel")
    jobs = graph["directionJobs"]
    require(isinstance(jobs, list) and len(jobs) == 4, "quarantine graph requires four jobs")
    roots: set[str] = set()
    for index, direction in enumerate(DIRECTIONS):
        expected_root = f"docs/production/evidence/PLAY-073/industrial-l04-renderer-intake-plan-v1/{direction}"
        expected = {
            "id": f"quarantine-{direction}",
            "direction": direction,
            "dependsOn": ["integration_source_admission_receipt"],
            "state": "prepared_blocked_waiting_source_admission",
            "exclusiveOutputRoot": expected_root,
            "failureIsolation": "return_this_direction_only",
            "shippingMutationAllowed": False,
        }
        require(jobs[index] == expected, f"{direction} quarantine job drift")
        require(expected_root not in roots, "quarantine output roots must be exclusive")
        roots.add(expected_root)
    require(
        graph["join"]
        == {
            "requires": [f"quarantine-{direction}" for direction in DIRECTIONS],
            "partialDisposition": "quarantined_incomplete",
            "completeDisposition": "ready_for_atomic_assembly_nonshipping",
            "activationAllowed": False,
        },
        "4/4 quarantine join drift",
    )


def validate_preparation(value: object) -> None:
    prep = exact_keys(
        value,
        {"mode", "rendererEvidenceRoot", "fixture", "cameraStates", "allowedWork", "forbiddenWork"},
        "preparation",
    )
    require(prep["mode"] == "candidate_neutral_nonshipping", "preparation must remain candidate-neutral")
    require(
        prep["rendererEvidenceRoot"]
        == "docs/production/evidence/PLAY-073/industrial-l04-renderer-intake-plan-v1",
        "Renderer evidence root drift",
    )
    require(
        prep["fixture"]
        == {
            "path": EXPECTED_INPUTS["mature_city_fixture"][0],
            "sha256": EXPECTED_INPUTS["mature_city_fixture"][1],
            "status": "accepted_l3_read_only_reference",
            "mutationAllowed": False,
        },
        "fixture preparation binding drift",
    )
    expected_cameras = []
    for width, pixels in (("regular", [1278, 768]), ("compact", [900, 652])):
        for detail, scale in (("city", 0.74), ("neighborhood", 0.66), ("block", 0.5)):
            expected_cameras.append(
                {
                    "id": f"{width}-{detail}",
                    "width": width,
                    "semanticLOD": detail,
                    "canonicalCameraScale": scale,
                    "decoratedCapturePixels": pixels,
                    "appCaptureAuthorized": False,
                }
            )
    require(prep["cameraStates"] == expected_cameras, "camera preparation binding drift")
    require(
        isinstance(prep["allowedWork"], list)
        and len(prep["allowedWork"]) == len(set(prep["allowedWork"]))
        and set(prep["allowedWork"]) == EXPECTED_ALLOWED,
        "allowed candidate-neutral preparation changed",
    )
    require(
        isinstance(prep["forbiddenWork"], list)
        and len(prep["forbiddenWork"]) == len(set(prep["forbiddenWork"]))
        and set(prep["forbiddenWork"]) == EXPECTED_FORBIDDEN,
        "forbidden preparation boundary changed",
    )


def validate_manifest_template(value: object) -> None:
    template = exact_keys(
        value,
        {
            "schemaVersion",
            "disposition",
            "acceptedL3Baseline",
            "directions",
            "runtimeActivated",
            "shippingResourcesMutated",
            "productionSelected",
        },
        "atomicAssembly.manifestTemplate",
    )
    require(template["schemaVersion"] == 1, "assembly template schema drift")
    require(
        template["disposition"] == "integration_assembly_input_unbound_template",
        "assembly template must remain unbound",
    )
    require(
        template["runtimeActivated"] is False
        and template["shippingResourcesMutated"] is False
        and template["productionSelected"] is False,
        "assembly template cannot activate or select",
    )
    baseline = template["acceptedL3Baseline"]
    require(
        baseline
        == {
            "commit": BASE,
            "catalog": {
                "path": EXPECTED_INPUTS["industrial_l3_catalog"][0],
                "sha256": EXPECTED_INPUTS["industrial_l3_catalog"][1],
            },
            "industrialL3Manifest": {
                "path": EXPECTED_INPUTS["industrial_l3_source_manifest"][0],
                "sha256": EXPECTED_INPUTS["industrial_l3_source_manifest"][1],
            },
        },
        "assembly baseline drift",
    )
    directions = template["directions"]
    require(isinstance(directions, list) and len(directions) == 4, "assembly template requires four directions")
    for index, direction in enumerate(DIRECTIONS):
        entry = exact_keys(
            directions[index],
            {"direction", "packet", "sourceAdmission", "quarantineReceipt", "locators"},
            f"manifestTemplate.{direction}",
        )
        require(entry["direction"] == direction, "assembly template direction order drift")
        for key in ("packet", "sourceAdmission", "quarantineReceipt"):
            validate_nullable(entry[key], f"manifestTemplate.{direction}.{key}")
        locators = exact_keys(
            entry["locators"],
            {"raw", "provenance", "normalization", "descriptor", "contact", "review"},
            f"manifestTemplate.{direction}.locators",
        )
        for key, locator in locators.items():
            validate_nullable(locator, f"manifestTemplate.{direction}.locators.{key}")


def extract_swift_manifest_shape(harness_path: Path) -> dict[str, set[str]]:
    text = harness_path.read_text()
    start = text.find("private static func validateManifestShape")
    end = text.find("private static func validateReceiptShape", start)
    require(start >= 0 and end > start, "bound Swift assembler manifest validator is missing")
    section = text[start:end]
    matches = re.findall(
        r"try exactKeys\(\s*(root|baseline|direction|locators),\s*\[(.*?)\]\s*\)",
        section,
        flags=re.DOTALL,
    )
    shape: dict[str, set[str]] = {}
    for label, body in matches:
        require(label not in shape, f"duplicate {label} exactKeys block in Swift assembler")
        shape[label] = set(re.findall(r'"([A-Za-z0-9]+)"', body))
    require(
        set(shape) == {"root", "baseline", "direction", "locators"},
        "could not derive exact manifest shape from bound Swift assembler",
    )
    return shape


def validate_actual_assembler_contract(
    root: Path,
    template: dict,
    assignment: dict,
) -> None:
    harness_path = resolve_artifact(
        root,
        EXPECTED_INPUTS["atomic_assembler_harness"][0],
        "atomic assembler harness",
    )
    shape = extract_swift_manifest_shape(harness_path)
    require(set(template) == shape["root"], "template top-level keys diverge from Swift assembler")
    require(
        set(template["acceptedL3Baseline"]) == shape["baseline"],
        "template acceptedL3Baseline keys diverge from Swift assembler",
    )
    for entry in template["directions"]:
        require(set(entry) == shape["direction"], "template direction keys diverge from Swift assembler")
        require(
            set(entry["locators"]) == shape["locators"],
            "template locator keys diverge from Swift assembler",
        )
    tool_path = resolve_artifact(
        root,
        assignment["tool"]["path"],
        "atomic assembler tool",
    )
    tool = tool_path.read_text()
    for token in (
        "CITYSIM_L4_CLAIMED_ROOT",
        "CITYSIM_L4_ASSEMBLY_MANIFEST_PATH",
        "CITYSIM_L4_ASSEMBLY_MANIFEST_SHA256",
        "CITYSIM_L4_ATOMIC_LEDGER_OUTPUT",
        "IndustrialL4V2SourceAdmissionHarnessTests/testCallerSuppliedAtomicAssemblyManifest",
    ):
        require(token in tool, f"atomic assembler tool no longer binds {token}")


def validate_atomic_assembly(root: Path, value: object) -> None:
    assembly = exact_keys(
        value,
        {
            "state",
            "trigger",
            "manifestTemplate",
            "manifestTransition",
            "assemblerAssignment",
            "output",
        },
        "atomicAssembly",
    )
    require(assembly["state"] == "template_only_unbound", "atomic assembly cannot be active")
    require(
        assembly["trigger"] == "same_turn_after_four_exact_renderer_quarantine_receipts",
        "atomic assembly trigger drift",
    )
    validate_manifest_template(assembly["manifestTemplate"])
    require(
        assembly["manifestTransition"]
        == {
            "fromDisposition": "integration_assembly_input_unbound_template",
            "toDisposition": "integration_assembly_input_admitted",
            "writer": "integration",
            "requires": [
                "north_exact_renderer_quarantine_receipt",
                "east_exact_renderer_quarantine_receipt",
                "south_exact_renderer_quarantine_receipt",
                "west_exact_renderer_quarantine_receipt",
                "integration_published_exact_path_and_sha_bindings",
            ],
            "admittedManifestMayBePublishedByThisPlan": False,
        },
        "atomic manifest disposition transition drift",
    )
    assignment = assembly["assemblerAssignment"]
    require(
        assignment
        == {
            "jobID": "industrial-l04-atomic-assembler-v1",
            "threadId": "019f7c8a-69a2-78c2-ae70-fa23ee7bfcd0",
            "branch": "codex/citysim-world-rendering",
            "worktree": "/Users/James/.codex/worktrees/cac1/city-sim",
            "claim": "PLAY-073",
            "tool": {
                "path": EXPECTED_INPUTS["atomic_assembler"][0],
                "sha256": EXPECTED_INPUTS["atomic_assembler"][1],
            },
            "harness": {
                "path": EXPECTED_INPUTS["atomic_assembler_harness"][0],
                "sha256": EXPECTED_INPUTS["atomic_assembler_harness"][1],
            },
            "inputAuthority": "integration_published_exact_4of4_manifest_only",
            "startCondition": "four_exact_renderer_quarantine_receipts_and_integration_dispatch",
            "singleGitIndexWriter": "019f7c8a-69a2-78c2-ae70-fa23ee7bfcd0",
            "shippingMutationAllowed": False,
        },
        "atomic assembler assignment drift",
    )
    validate_actual_assembler_contract(root, assembly["manifestTemplate"], assignment)
    require(
        assembly["output"]
        == {
            "schema": "atomic-admission-ledger-v1",
            "disposition": "ready_for_atomic_assembly_nonshipping",
            "runtimeActivated": False,
            "shippingResourcesMutated": False,
            "productionSelected": False,
        },
        "atomic assembly output boundary drift",
    )


def validate(root: Path, plan_path: Path) -> dict:
    root = root.resolve()
    data = json.loads(plan_path.read_text())
    exact_keys(
        data,
        {
            "schemaVersion",
            "disposition",
            "publishedBase",
            "schema",
            "boundInputs",
            "family",
            "directionIntake",
            "quarantineGraph",
            "preparation",
            "rejectionGates",
            "atomicAssembly",
            "grants",
        },
        "plan",
    )
    require(data["schemaVersion"] == 1, "schemaVersion must equal 1")
    require(
        data["disposition"] == "candidate_neutral_renderer_intake_prepared",
        "wrong intake-plan disposition",
    )
    require(
        data["publishedBase"]
        == {"branch": "master", "commit": BASE, "remoteParityRequired": True},
        "published base drift",
    )
    require_git_base(root)
    schema_path, schema_sha = validate_artifact(root, data["schema"], "schema")
    require(
        (schema_path, schema_sha)
        == (
            "docs/production/evidence/INTEGRATION/industrial-l04-renderer-intake-plan-schema-v1.json",
            "a2f7fe762f3f79ea95286284224161dbaddf152e8af174ead6365fda3da060fa",
        ),
        "schema binding drift",
    )
    bindings = validate_bound_inputs(root, data["boundInputs"])
    bridge = json.loads((root / bindings["direction_bridge"][0]).read_text())
    require(bridge["sourceAuthority"] is False and bridge["productionSelected"] is False, "bridge cannot grant source authority")
    require(bridge["basis"]["perDirectionTransforms"] is False, "bridge must forbid per-direction transforms")
    validate_family(data["family"])
    validate_directions(data["directionIntake"], bridge)
    validate_graph(data["quarantineGraph"])
    validate_preparation(data["preparation"])
    gates = data["rejectionGates"]
    require(
        isinstance(gates, list) and len(gates) == len(set(gates)) and set(gates) == EXPECTED_REJECTIONS,
        "rejection gates are incomplete or changed",
    )
    validate_atomic_assembly(root, data["atomicAssembly"])
    require(
        data["grants"]
        == {
            "candidateNeutralPreparation": True,
            "sourceAcceptance": False,
            "rendererAdmission": False,
            "runtimeActivation": False,
            "shippingMutation": False,
            "productionSelection": False,
            "appLaunch": False,
            "qaDisposition": False,
            "integration": False,
            "push": False,
        },
        "authority grants exceed candidate-neutral preparation",
    )
    return {
        "result": "PASS",
        "plan": str(plan_path),
        "publishedBase": BASE,
        "boundInputCount": len(bindings),
        "directionCount": 4,
        "lodSlotCount": 12,
        "quarantineJobCount": 4,
        "assemblyState": "template_only_unbound",
        "runtimeActivated": False,
        "shippingResourcesMutated": False,
        "productionSelected": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "plan",
        nargs="?",
        default="docs/production/evidence/INTEGRATION/industrial-l04-renderer-intake-plan-v1.json",
    )
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()
    try:
        result = validate(Path(args.repo_root), Path(args.plan).resolve())
    except (OSError, KeyError, TypeError, json.JSONDecodeError, IntakePlanError) as error:
        print(json.dumps({"result": "FAIL", "reason": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
