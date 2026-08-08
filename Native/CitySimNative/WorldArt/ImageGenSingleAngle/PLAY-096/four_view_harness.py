#!/usr/bin/env python3
"""PLAY-096 CONTRACT-025 task-local four-view contract repair.

This is a mechanical contract and receipt harness.  It does not generate art,
touch the renderer, or admit a family.  Existing single-angle evidence stays
in place; the repair writes only new four-view evidence and updated task-local
schemas/inventory records.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import tempfile
from pathlib import Path
from pathlib import PurePosixPath
from typing import Mapping

# Import the dependency-free PNG primitives from the preserved implementation.
from single_angle_harness import (  # noqa: E402
    build_literal_scale_sheet,
    canonical_json,
    decode_png,
    encode_png,
    git_identity,
    resize_rgba,
    sha256_bytes,
    sha256_file,
    validate_rgba,
    write_json,
)


TASK = "PLAY-096"
CONTRACT = "CONTRACT-025"
REGISTRATION_CONTRACT = "CONTRACT-026"
SCHEMA_VERSION = 2
CANVAS = (1536, 1024)
GROUND_PIVOT = (768, 896)
DIRECTIONS = ("north", "east", "south", "west")
LODS = {"city": (256, 171), "neighborhood": (512, 342), "block": (1024, 683)}
CLAIM_PATH = "docs/production/claims/PLAY-096.world-art-pipeline.md"
CLAIM_SHA256 = "d88dc773cb2cd86a608d45e9bd8bc0a1bbf8339598e7029457b1fed6a823c007"
AUTHORITY = "65825389d586a128ddf6feb5356c33661ba9a8e8"
BASE = "a61ab80101f596f56ffc1dd7e37b32bd1b220357"
BRANCH = "codex/citysim-world-art-pipeline"
ROUTE_ID = "four-view-v3:play-096-contract-repair"
ROUTE_SHA256 = "d1cb7182e48313f5d9ea9599d1f319511c82bb93b795a295d9effc0116bfd8b0"
REGISTRATION_PROFILE_PATH = "docs/production/decisions/CONTRACT-026-registration-profiles-v1.json"
REGISTRATION_PROFILE_SHA256 = "6663482339e953bdcbcb86bcfc876676989fbcb7f74a91f3f1b480d124fe3bd8"
REGISTRATION_PROFILE = {
    "sourceCanvas": [1536, 1024],
    "groundPivotSource": [768, 896],
    "footprintTiles": [1, 1],
    "footprintPolygonSource": [[768, 640], [1024, 768], [768, 896], [512, 768]],
    "frontageSocketSource": {
        "north": [896, 704],
        "east": [896, 832],
        "south": [640, 832],
        "west": [640, 704],
    },
    "lods": {
        "block": {"canvas": [1024, 683], "filter": "lanczos", "rounding": "round-half-even"},
        "neighborhood": {"canvas": [512, 342], "filter": "lanczos", "rounding": "round-half-even"},
        "city": {"canvas": [256, 171], "filter": "lanczos", "rounding": "round-half-even"},
    },
}
CALIBRATION_SOURCE = "Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/residential_l01/source-v01.png"
CALIBRATION_SOURCE_SHA256 = "e15a388c2a1a0a55488457211c23939f70eca255cbae733ee0f7b39b141c962e"
NORMALIZER_REFERENCE = "Native/CitySimNative/WorldArt/GeneratedV4/tools/normalize_calibration_asset.py"
NORMALIZER_REFERENCE_SHA256 = "0901077cf90151ea1bda1fbe0f21f3c4cebadc72733c762e8d7122480f2a6048"
CONSUMERS = tuple(f"PLAY-{number:03d}" for number in range(97, 106))
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[5]


def exact_identities() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for family in ("residential", "commercial", "industrial"):
        for level in range(1, 5):
            for variant in range(3):
                rows.append({
                    "logical_id": f"{family}_l{level:02d}_v{variant}",
                    "family": family,
                    "level": level,
                    "variant": variant,
                    "kind": "building",
                })
    for kind in ("park", "power_plant", "water_tower", "fire_station", "police_station", "school", "city_hall"):
        rows.append({"logical_id": f"civic_{kind}_v0", "family": "civic", "level": 1, "variant": 0, "kind": kind})
    return rows


def registration_for(identity: Mapping[str, object]) -> dict[str, object]:
    """Return the immutable CONTRACT-026 source registration profile."""
    return {
        "registration_contract": REGISTRATION_CONTRACT,
        "registration_profile_path": REGISTRATION_PROFILE_PATH,
        "registration_profile_sha256": REGISTRATION_PROFILE_SHA256,
        "canvas_pixels": list(REGISTRATION_PROFILE["sourceCanvas"]),
        "ground_pivot": list(REGISTRATION_PROFILE["groundPivotSource"]),
        "footprint_world_points": list(REGISTRATION_PROFILE["footprintTiles"]),
        "footprint_polygon_source": [list(point) for point in REGISTRATION_PROFILE["footprintPolygonSource"]],
        "frontage_sockets_source": {direction: list(point) for direction, point in REGISTRATION_PROFILE["frontageSocketSource"].items()},
        "lod_profile": {lod: dict(profile) for lod, profile in REGISTRATION_PROFILE["lods"].items()},
        "coordinate_owner": "PLAY-096 code-owned registration table",
        "scale_source": "CONTRACT-026-full-canvas-registration",
    }


def inventory_document() -> dict[str, object]:
    identities = exact_identities()
    direction_rows = []
    for identity in identities:
        for direction in DIRECTIONS:
            direction_rows.append({
                "logical_id": identity["logical_id"],
                "direction": direction,
                "identity_direction_key": f"{identity['logical_id']}:{direction}",
                "registration": registration_for(identity),
            })
    return {
        "schema": SCHEMA_VERSION,
        "task": TASK,
        "contract": CONTRACT,
        "view_policy": "four-authored-views",
        "identity_count": len(identities),
        "direction_count": len(direction_rows),
        "directions": list(DIRECTIONS),
        "registration_profile": {
            "contract": REGISTRATION_CONTRACT,
            "path": REGISTRATION_PROFILE_PATH,
            "sha256": REGISTRATION_PROFILE_SHA256,
        },
        "identities": identities,
        "direction_rows": direction_rows,
        "matrix_policy": "43 logical identities x north/east/south/west = 172 direction rows",
    }


def validate_inventory(document: Mapping[str, object]) -> list[str]:
    errors: list[str] = []
    expected = inventory_document()
    if set(document) != set(expected):
        errors.append("inventory schema contains missing or unsupported fields")
    if document.get("schema") != SCHEMA_VERSION or document.get("task") != TASK or document.get("contract") != CONTRACT:
        errors.append("inventory schema/task/contract mismatch")
    if document.get("directions") != list(DIRECTIONS) or document.get("matrix_policy") != expected["matrix_policy"]:
        errors.append("inventory direction policy mismatch")
    if document.get("registration_profile") != expected["registration_profile"]:
        errors.append("inventory CONTRACT-026 registration profile binding mismatch")
    identities = document.get("identities")
    rows = document.get("direction_rows")
    if not isinstance(identities, list) or len(identities) != 43:
        errors.append("inventory must contain exactly 43 identities")
        identities = []
    if not isinstance(rows, list) or len(rows) != 172:
        errors.append("inventory must contain exactly 172 direction rows")
        rows = []
    expected_ids = {str(row["logical_id"]) for row in expected["identities"]}
    expected_by_id = {str(row["logical_id"]): row for row in expected["identities"]}
    actual_ids = {str(row.get("logical_id")) for row in identities if isinstance(row, dict)}
    if actual_ids != expected_ids:
        errors.append("identity set does not equal integrated CONTRACT-025 IDs")
    for identity in identities:
        if not isinstance(identity, dict):
            continue
        logical_id = identity.get("logical_id")
        if logical_id in expected_by_id and identity != expected_by_id[logical_id]:
            errors.append(f"{logical_id}: family/level/variant/kind binding does not match integrated identity")
    expected_keys = {str(row["identity_direction_key"]) for row in expected["direction_rows"]}
    actual_keys = {str(row.get("identity_direction_key")) for row in rows if isinstance(row, dict)}
    if actual_keys != expected_keys or len(actual_keys) != len(rows):
        errors.append("direction rows do not equal the unique 43x4 matrix")
    expected_rows = {str(row["identity_direction_key"]): row for row in expected["direction_rows"]}
    for row in rows:
        if not isinstance(row, dict):
            errors.append("direction row must be an object")
            continue
        key = row.get("identity_direction_key")
        logical_id = row.get("logical_id")
        direction = row.get("direction")
        if direction not in DIRECTIONS:
            errors.append(f"invalid direction {row.get('direction')}")
        if key not in expected_rows or key != f"{logical_id}:{direction}":
            errors.append(f"{key}: logical_id/direction/key binding does not match integrated matrix")
        registration = row.get("registration")
        if not isinstance(registration, dict):
            errors.append(f"missing registration for {key}")
        else:
            errors.extend(validate_registration(registration, logical_id))
            if key in expected_rows and registration != expected_rows[key]["registration"]:
                errors.append(f"{key}: direction registration cross-binding mismatch")
    return errors


def validate_registration(registration: Mapping[str, object], logical_id: object = None) -> list[str]:
    errors: list[str] = []
    expected = registration_for({"logical_id": logical_id})
    if registration.get("registration_contract") != REGISTRATION_CONTRACT:
        errors.append(f"{logical_id}: registration contract must be CONTRACT-026")
    if registration.get("registration_profile_path") != REGISTRATION_PROFILE_PATH or registration.get("registration_profile_sha256") != REGISTRATION_PROFILE_SHA256:
        errors.append(f"{logical_id}: registration profile binding drift")
    if registration.get("canvas_pixels") != list(CANVAS):
        errors.append(f"{logical_id}: registration canvas must be 1536x1024")
    if registration.get("ground_pivot") != list(GROUND_PIVOT):
        errors.append(f"{logical_id}: registration pivot drift")
    for key in ("footprint_polygon_source", "frontage_sockets_source", "lod_profile"):
        if key not in registration:
            errors.append(f"{logical_id}: missing {key}")
    if registration.get("scale_source") != "CONTRACT-026-full-canvas-registration":
        errors.append(f"{logical_id}: scale must be code-owned")
    if registration.get("coordinate_owner") != "PLAY-096 code-owned registration table":
        errors.append(f"{logical_id}: coordinate owner drift")
    if registration != expected:
        errors.append(f"{logical_id}: registration does not equal the immutable CONTRACT-026 profile")
    if any(key in registration for key in ("derived_from_pixels", "source_bbox", "shadow_bbox", "authoring_size_pixels", "authoring_origin_pixels", "scale_pixels_per_world_point")):
        errors.append(f"{logical_id}: pixel-derived registration is forbidden")
    return errors


def provenance_record(logical_id: str, direction: str, status: str = "not_generated") -> dict[str, object]:
    return {
        "schema": SCHEMA_VERSION,
        "task": TASK,
        "logical_id": logical_id,
        "direction": direction,
        "status": status,
        "prompt_text": "",
        "south_reference": {"path": None, "sha256": None},
        "references": [],
        "reference_hashes": [],
        "tool": {"name": "OpenAI built-in ImageGen", "model": "built-in/model-not-exposed"},
        "cleanup_command": "",
        "gameplay_meaning": "",
        "raw_path": None,
        "raw_sha256": None,
        "record_path": None,
        "record_sha256": None,
        "prompt_complete": False,
        "references_complete": False,
        "reference_hashes_complete": False,
        "cleanup_complete": False,
        "gameplay_meaning_complete": False,
    }


def validate_provenance(record: Mapping[str, object], require_complete: bool = False, root: Path | None = None) -> list[str]:
    required = ("schema", "task", "logical_id", "direction", "status", "prompt_text", "south_reference", "references", "reference_hashes", "tool", "cleanup_command", "gameplay_meaning", "raw_path", "raw_sha256", "record_path", "record_sha256", "prompt_complete", "references_complete", "reference_hashes_complete", "cleanup_complete", "gameplay_meaning_complete")
    errors = [f"provenance missing {key}" for key in required if key not in record]
    if record.get("schema") != SCHEMA_VERSION or record.get("task") != TASK:
        errors.append("provenance schema/task mismatch")
    if record.get("direction") not in DIRECTIONS:
        errors.append("provenance direction invalid")
    status = record.get("status")
    if status not in {"not_generated", "source_candidate"}:
        errors.append("provenance status invalid")
    south = record.get("south_reference")
    references = record.get("references")
    reference_hashes = record.get("reference_hashes")
    if not isinstance(south, dict) or set(south) != {"path", "sha256"}:
        errors.append("South reference binding must contain exactly path and sha256")
    elif status == "not_generated":
        if south != {"path": None, "sha256": None}:
            errors.append("not_generated provenance must not bind a South source")
    else:
        errors.extend(_validate_binding(south, "South reference", root, True))
    if not isinstance(references, list) or not isinstance(reference_hashes, list):
        errors.append("provenance references and reference_hashes must be lists")
    elif status == "not_generated":
        if references or reference_hashes:
            errors.append("not_generated provenance must not contain source references")
    else:
        if not references:
            errors.append("source provenance requires references")
        if len(references) != len(reference_hashes):
            errors.append("reference and reference_hash counts must match")
        for index, reference in enumerate(references):
            if not isinstance(reference, dict) or set(reference) != {"path", "role", "sha256"}:
                errors.append(f"reference {index} must bind path, role, and sha256")
                continue
            errors.extend(_validate_repo_relative_path(reference.get("path"), f"reference {index}"))
            errors.extend(_validate_sha(reference.get("sha256"), f"reference {index}.sha256"))
            if not isinstance(reference.get("role"), str) or not reference["role"].strip():
                errors.append(f"reference {index} role must be non-empty")
            if root is not None and not errors:
                reference_path = root / str(reference["path"])
                if not reference_path.is_file():
                    errors.append(f"reference {index} path does not resolve to a file")
                elif sha256_file(reference_path) != reference["sha256"]:
                    errors.append(f"reference {index} hash does not match repository-relative file")
            if index < len(reference_hashes) and reference.get("sha256") != reference_hashes[index]:
                errors.append(f"reference {index} hash does not match reference_hashes")
    for path_key, digest_key in (("raw_path", "raw_sha256"), ("record_path", "record_sha256")):
        binding = {"path": record.get(path_key), "sha256": record.get(digest_key)}
        if status == "not_generated":
            if binding != {"path": None, "sha256": None}:
                errors.append(f"not_generated provenance must not bind {path_key}")
        else:
            errors.extend(_validate_binding(binding, path_key, root, True))
    complete = all(bool(record.get(key)) for key in ("prompt_complete", "references_complete", "reference_hashes_complete", "cleanup_complete", "gameplay_meaning_complete"))
    if require_complete or status == "source_candidate":
        if not complete:
            errors.append("incomplete prompt/references/hashes/cleanup/gameplay-meaning provenance")
        if not isinstance(record.get("prompt_text"), str) or not record["prompt_text"].strip():
            errors.append("complete provenance requires prompt_text")
        if not isinstance(record.get("references"), list) or not record["references"]:
            errors.append("complete provenance requires references")
        if not isinstance(record.get("reference_hashes"), list) or not record["reference_hashes"] or not all(isinstance(x, str) and HEX64.fullmatch(x) for x in record["reference_hashes"]):
            errors.append("complete provenance requires 64-hex reference hashes")
        if not isinstance(record.get("cleanup_command"), str) or not record["cleanup_command"].strip():
            errors.append("complete provenance requires cleanup command")
        if not isinstance(record.get("gameplay_meaning"), str) or not record["gameplay_meaning"].strip():
            errors.append("complete provenance requires gameplay meaning")
    return errors


def empty_direction_row(identity: Mapping[str, object], direction: str) -> dict[str, object]:
    return {
        "logical_id": identity["logical_id"],
        "direction": direction,
        "identity_direction_key": f"{identity['logical_id']}:{direction}",
        "raw": {"status": "not_generated", "path": None, "sha256": None},
        "record": {"status": "not_generated", "path": None, "sha256": None},
        "lods": [{"lod": lod, "status": "not_generated", "path": None, "sha256": None} for lod in LODS],
        "south_reference": {"path": None, "sha256": None},
        "provenance": provenance_record(str(identity["logical_id"]), direction),
        "registration": registration_for(identity),
        "alias": {"alias_of": None, "transform": "none"},
        "readiness": {
            "candidateReadyForIndependentReview": False,
            "sourceReady": False,
            "integrationAdmitted": False,
            "rendererQuarantined": False,
            "productionSelected": False,
            "consumerReadiness": {consumer: False for consumer in CONSUMERS},
        },
    }


def direction_handoff_document(inventory: Mapping[str, object]) -> dict[str, object]:
    identity_by_id = {str(row["logical_id"]): row for row in inventory["identities"]}
    rows = [empty_direction_row(identity_by_id[str(row["logical_id"])], str(row["direction"])) for row in inventory["direction_rows"]]
    return {
        "schema": SCHEMA_VERSION,
        "task": TASK,
        "contract": CONTRACT,
        "stage": "four-view-contract-repair",
        "branch": BRANCH,
        "base_authority": BASE,
        "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA256},
        "registration_profile": {
            "contract": REGISTRATION_CONTRACT,
            "path": REGISTRATION_PROFILE_PATH,
            "sha256": REGISTRATION_PROFILE_SHA256,
        },
        "inventory": {
            "path": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-096/single-angle-inventory.json",
            "sha256": sha256_bytes(canonical_json(inventory)),
        },
        "identity_count": 43,
        "direction_count": 172,
        "directions": list(DIRECTIONS),
        "rows": rows,
        "family_readiness": {consumer: False for consumer in CONSUMERS},
        "source_production": "not_produced",
        "integration_admitted": False,
        "production_selected": False,
    }


def _validate_repo_relative_path(value: object, label: str) -> list[str]:
    if not isinstance(value, str) or not value:
        return [f"{label} path must be a non-empty repo-relative path"]
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "." in path.parts or "\\" in value:
        return [f"{label} path must be normalized repo-relative"]
    return []


def _validate_sha(value: object, label: str) -> list[str]:
    if not isinstance(value, str) or not HEX64.fullmatch(value):
        return [f"{label} must be lowercase SHA-256"]
    return []


def _validate_binding(binding: object, label: str, root: Path | None, required: bool) -> list[str]:
    if not isinstance(binding, dict) or set(binding) != {"path", "sha256"}:
        return [f"{label} binding must contain exactly path and sha256"]
    path, digest = binding["path"], binding["sha256"]
    if not required and path is None and digest is None:
        return []
    errors = _validate_repo_relative_path(path, label)
    errors.extend(_validate_sha(digest, f"{label}.sha256"))
    if root is not None and not errors:
        candidate = root / str(path)
        if not candidate.is_file():
            errors.append(f"{label} path does not resolve to a file")
        elif sha256_file(candidate) != digest:
            errors.append(f"{label} hash does not match repository-relative file")
    return errors


def validate_direction_handoff(document: Mapping[str, object], root: Path | None = None) -> list[str]:
    errors: list[str] = []
    expected_top_level = {
        "schema", "task", "contract", "stage", "branch", "base_authority", "claim", "registration_profile", "inventory",
        "identity_count", "direction_count", "directions", "rows", "family_readiness", "source_production",
        "integration_admitted", "production_selected",
    }
    if set(document) != expected_top_level:
        errors.append("handoff top-level schema is not substantive or contains unknown fields")
    if document.get("schema") != SCHEMA_VERSION or document.get("task") != TASK or document.get("contract") != CONTRACT:
        errors.append("handoff schema/task/contract mismatch")
    if document.get("stage") != "four-view-contract-repair" or document.get("branch") != BRANCH or document.get("base_authority") != BASE:
        errors.append("handoff stage/branch/base binding mismatch")
    if document.get("identity_count") != 43 or document.get("direction_count") != 172 or document.get("directions") != list(DIRECTIONS):
        errors.append("handoff must bind the exact 43 identity x four direction matrix")
    claim = document.get("claim")
    if claim != {"path": CLAIM_PATH, "sha256": CLAIM_SHA256}:
        errors.append("handoff claim binding mismatch")
    if document.get("registration_profile") != {"contract": REGISTRATION_CONTRACT, "path": REGISTRATION_PROFILE_PATH, "sha256": REGISTRATION_PROFILE_SHA256}:
        errors.append("handoff CONTRACT-026 registration profile binding mismatch")
    elif root is not None:
        errors.extend(_validate_binding({"path": REGISTRATION_PROFILE_PATH, "sha256": REGISTRATION_PROFILE_SHA256}, "registration_profile", root, True))
    inventory = document.get("inventory")
    if not isinstance(inventory, dict) or set(inventory) != {"path", "sha256"}:
        errors.append("handoff inventory binding is missing or malformed")
    elif root is not None:
        errors.extend(_validate_binding(inventory, "inventory", root, True))
    rows = document.get("rows")
    if not isinstance(rows, list) or len(rows) != 172:
        return errors + ["handoff must contain exactly 172 rows"]
    keys: set[str] = set()
    expected_inventory = inventory_document()
    expected_identities = {str(item["logical_id"]): item for item in expected_inventory["identities"]}
    expected_keys = {str(item["identity_direction_key"]) for item in expected_inventory["direction_rows"]}
    seen_digests: dict[str, str] = {}
    seen_paths: dict[str, str] = {}
    row_keys = set()
    for row in rows:
        if not isinstance(row, dict):
            errors.append("handoff row must be an object")
            continue
        expected_row_fields = {"logical_id", "direction", "identity_direction_key", "raw", "record", "lods", "south_reference", "provenance", "registration", "alias", "readiness"}
        if set(row) != expected_row_fields:
            errors.append(f"row schema is not substantive for {row.get('identity_direction_key')}")
        key = row.get("identity_direction_key")
        if not isinstance(key, str) or key in keys:
            errors.append(f"duplicate or missing identity-direction key {key}")
        keys.add(key)
        logical_id = row.get("logical_id")
        direction = row.get("direction")
        if logical_id not in expected_identities or direction not in DIRECTIONS:
            errors.append(f"{key}: logical ID or direction is outside the integrated matrix")
            expected_identity = None
        else:
            expected_identity = expected_identities[logical_id]
            expected_key = f"{logical_id}:{direction}"
            row_keys.add(expected_key)
            if key != expected_key:
                errors.append(f"{key}: logical_id/direction/key cross-binding mismatch")
            if row.get("registration") != registration_for(expected_identity):
                errors.append(f"{key}: registration is not the code-owned identity registration")
        if direction not in DIRECTIONS:
            errors.append(f"invalid handoff direction {row.get('direction')}")
        raw = row.get("raw")
        if not isinstance(raw, dict) or set(raw) != {"status", "path", "sha256"}:
            errors.append(f"{key}: raw digest record shape invalid")
        else:
            errors.extend(validate_digest_record(raw, "raw", key, root, seen_digests, seen_paths))
        record = row.get("record")
        if not isinstance(record, dict) or set(record) != {"status", "path", "sha256"}:
            errors.append(f"{key}: provenance record digest shape invalid")
        else:
            errors.extend(validate_digest_record(record, "record", key, root, None, None))
        lods = row.get("lods")
        if not isinstance(lods, list) or [item.get("lod") for item in lods if isinstance(item, dict)] != list(LODS):
            errors.append(f"{key}: LOD digest set must be city/neighborhood/block")
        else:
            for lod in lods:
                errors.extend(validate_digest_record(lod, str(lod["lod"]), key, root, seen_digests, seen_paths))
        provenance = row.get("provenance", {})
        ready = isinstance(row.get("readiness"), dict) and row["readiness"].get("candidateReadyForIndependentReview") is True
        errors.extend(validate_provenance(provenance, require_complete=ready, root=root))
        if isinstance(provenance, dict):
            if provenance.get("logical_id") != logical_id or provenance.get("direction") != direction:
                errors.append(f"{key}: provenance logical_id/direction cross-binding mismatch")
            south = row.get("south_reference")
            if south != provenance.get("south_reference"):
                errors.append(f"{key}: South reference cross-binding mismatch")
            if isinstance(raw, dict) and {"path": provenance.get("raw_path"), "sha256": provenance.get("raw_sha256")} != {"path": raw.get("path"), "sha256": raw.get("sha256")}:
                errors.append(f"{key}: raw/provenance hash binding mismatch")
            if isinstance(record, dict) and {"path": provenance.get("record_path"), "sha256": provenance.get("record_sha256")} != {"path": record.get("path"), "sha256": record.get("sha256")}:
                errors.append(f"{key}: record/provenance hash binding mismatch")
        if not isinstance(row.get("south_reference"), dict):
            errors.append(f"{key}: South reference binding missing")
        elif row["south_reference"] != {"path": None, "sha256": None} and not ready:
            errors.extend(_validate_binding(row["south_reference"], f"{key}.south_reference", root, True))
        if not isinstance(row.get("registration"), dict):
            errors.append(f"{key}: registration missing")
        else:
            errors.extend(validate_registration(row["registration"], key))
        alias = row.get("alias")
        if not isinstance(alias, dict) or set(alias) != {"alias_of", "transform"} or alias.get("alias_of") is not None or alias.get("transform") != "none":
            errors.append(f"{key}: aliases and transforms are forbidden")
        readiness = row.get("readiness")
        if not isinstance(readiness, dict):
            errors.append(f"{key}: readiness missing")
        else:
            if set(readiness) != {"candidateReadyForIndependentReview", "sourceReady", "integrationAdmitted", "rendererQuarantined", "productionSelected", "consumerReadiness"}:
                errors.append(f"{key}: readiness schema is incomplete")
            for field in ("candidateReadyForIndependentReview", "sourceReady", "integrationAdmitted", "rendererQuarantined", "productionSelected"):
                if field != "candidateReadyForIndependentReview" and readiness.get(field) is not False:
                    errors.append(f"{key}: {field} must remain false")
            if set(readiness.get("consumerReadiness", {})) != set(CONSUMERS) or any(readiness.get("consumerReadiness", {}).get(consumer) is not False for consumer in CONSUMERS):
                errors.append(f"{key}: PLAY-097..105 readiness must remain false")
            if ready:
                if not isinstance(raw, dict) or raw.get("status") != "source_candidate" or not isinstance(record, dict) or record.get("status") != "source_candidate":
                    errors.append(f"{key}: candidateReady requires source raw and provenance record")
                if not isinstance(lods, list) or any(item.get("status") != "source_candidate" for item in lods if isinstance(item, dict)):
                    errors.append(f"{key}: candidateReady requires all normalized LODs")
                if not isinstance(provenance, dict) or validate_provenance(provenance, require_complete=True, root=root):
                    errors.append(f"{key}: candidateReady requires complete source provenance")
                if row.get("south_reference") == {"path": None, "sha256": None}:
                    errors.append(f"{key}: candidateReady requires a bound South reference")
    if row_keys != expected_keys:
        errors.append("handoff identity-direction rows do not equal the exact integrated 43x4 matrix")
    if len(keys) != 172:
        errors.append("handoff identity-direction keys are not unique")
    if document.get("family_readiness") != {consumer: False for consumer in CONSUMERS}:
        errors.append("family readiness must remain false for PLAY-097..105")
    return errors


def validate_handoff_json_schema(document: Mapping[str, object]) -> list[str]:
    """Validate the committed handoff with its local, file-relative schemas."""
    import jsonschema

    schema_root = Path(__file__).resolve().parent / "schemas"
    schema_path = schema_root / "family-handoff.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    resolver = jsonschema.RefResolver(schema_path.as_uri(), schema)
    validator = jsonschema.Draft202012Validator(schema, resolver=resolver)
    return [f"{list(error.path)}: {error.message}" for error in validator.iter_errors(document)]


def validate_digest_record(record: Mapping[str, object], label: str, key: object, root: Path | None, seen: dict[str, str] | None, seen_paths: dict[str, str] | None) -> list[str]:
    errors: list[str] = []
    allowed_keys = {"status", "path", "sha256"} | ({"lod"} if label in LODS else set())
    if set(record) != allowed_keys:
        return [f"{key}: {label} digest record shape invalid"]
    status, path, digest = record["status"], record["path"], record["sha256"]
    if status == "not_generated":
        if path is not None or digest is not None:
            errors.append(f"{key}: {label} not_generated must have null path/digest")
        return errors
    if status != "source_candidate":
        errors.append(f"{key}: {label} status invalid")
    errors.extend(_validate_repo_relative_path(path, f"{key}: {label}"))
    if not isinstance(digest, str) or not HEX64.fullmatch(digest):
        errors.append(f"{key}: {label} digest must be lowercase SHA-256")
    source_label = f"{key}:{label}"
    if seen is not None and isinstance(digest, str) and HEX64.fullmatch(digest):
        if digest in seen and seen[digest] != source_label:
            errors.append(f"{key}: {label} aliases digest from {seen[digest]}")
        seen[digest] = source_label
    if seen_paths is not None and isinstance(path, str):
        if path in seen_paths and seen_paths[path] != source_label:
            errors.append(f"{key}: {label} aliases path from {seen_paths[path]}")
        seen_paths[path] = source_label
    if root is not None and isinstance(path, str) and isinstance(digest, str) and HEX64.fullmatch(digest):
        candidate = root / path
        if not candidate.is_file() or sha256_file(candidate) != digest:
            errors.append(f"{key}: {label} digest does not match repo-relative file")
    return errors


def normalize_full_canvas(width: int, height: int, rgba: bytearray, registration: Mapping[str, object]) -> tuple[int, int, bytearray, dict[str, object]]:
    if (width, height) != CANVAS:
        raise ValueError("full-canvas normalizer requires 1536x1024 source")
    # Matte extraction may clear only border-connected chroma. Registration
    # owns scale, origin, and pivot; occupied bounds never crop, resize, or
    # reposition the authored canvas.
    seen: set[tuple[int, int]] = set()
    from collections import deque
    queue = deque()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))
    def matte(index: int) -> bool:
        r, g, b = rgba[index:index + 3]
        return r >= 180 and b >= 150 and g <= 110 and r + b >= g * 4
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen:
            continue
        index = (y * width + x) * 4
        if not matte(index):
            continue
        seen.add((x, y))
        rgba[index:index + 4] = b"\x00\x00\x00\x00"
        if x: queue.append((x - 1, y))
        if x + 1 < width: queue.append((x + 1, y))
        if y: queue.append((x, y - 1))
        if y + 1 < height: queue.append((x, y + 1))
    for index in range(0, len(rgba), 4):
        r, g, b, alpha = rgba[index:index + 4]
        if not alpha:
            rgba[index:index + 4] = b"\x00\x00\x00\x00"
        elif r > g * 1.35 and b > g * 1.25:
            spill = min(r, b) - g
            rgba[index:index + 4] = bytes((max(g, int(r - spill)), g, max(g, int(b - spill)), alpha))
    occupied = [(i // 4 % width, i // 4 // width) for i in range(0, len(rgba), 4) if rgba[i + 3]]
    if not occupied:
        raise ValueError("normalization rejected: no subject after chroma extraction")
    left, top = min(x for x, _ in occupied), min(y for _, y in occupied)
    right, bottom = max(x for x, _ in occupied) + 1, max(y for _, y in occupied) + 1
    return CANVAS[0], CANVAS[1], rgba, {
        "registration": dict(registration),
        "source_occupied_bounds": [left, top, right, bottom],
        "scale_source": "CONTRACT-026-full-canvas-registration",
    }


def _relative(root: Path, path: Path) -> str:
    return str(path.resolve().relative_to(root.resolve()))


def _render_replay(source_root: Path, output_root: Path, logical_prefix: str, registration: Mapping[str, object]) -> dict[str, object]:
    source = source_root / CALIBRATION_SOURCE
    width, height, rgba = decode_png(source.read_bytes())
    width, height, normalized, registration_report = normalize_full_canvas(width, height, rgba, registration)
    if validate_rgba(width, height, normalized, CANVAS):
        raise ValueError("full-canvas normalized calibration failed")
    lod_paths = []
    lod_records = []
    for lod, size in LODS.items():
        pixels = normalized if size == CANVAS else resize_rgba(width, height, normalized, *size)
        if validate_rgba(size[0], size[1], pixels, size):
            raise ValueError(f"{lod} normalized calibration failed")
        path = output_root / "normalized" / f"generated_v4_residential_l01_v0_south_{lod}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(encode_png(size[0], size[1], pixels))
        lod_paths.append((lod, path))
        lod_records.append({"lod": lod, "path": f"{logical_prefix}/normalized/{path.name}", "sha256": sha256_file(path), "decoded_sha256": sha256_bytes(bytes(pixels)), "pixels": list(size)})
    sheets = []
    for grayscale in (False, True):
        path = output_root / "sheets" / ("literal-scale-grayscale.png" if grayscale else "literal-scale-color.png")
        sheet = build_literal_scale_sheet(lod_paths, path, grayscale=grayscale)
        sheet["file"] = f"{logical_prefix}/sheets/{path.name}"
        sheets.append(sheet)
    return {"registration": registration_report, "lods": lod_records, "sheets": sheets}


def _materialize_repository_root(source_root: Path, target_root: Path, inventory_path: Path) -> None:
    """Create an independent minimal checkout root for portability proof."""
    for relative in (CALIBRATION_SOURCE, REGISTRATION_PROFILE_PATH, str(inventory_path.relative_to(source_root))):
        source = source_root / relative
        target = target_root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def run_repair(repeat: int, evidence_root: Path) -> dict[str, object]:
    if repeat != 2:
        raise ValueError("the focused repair gate requires exactly two replays")
    root = repo_root()
    source = root / CALIBRATION_SOURCE
    if sha256_file(source) != CALIBRATION_SOURCE_SHA256:
        raise ValueError("retained calibration source hash drift")
    inventory = inventory_document()
    if validate_inventory(inventory):
        raise ValueError("four-view inventory failed")
    inventory_path = root / "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-096/single-angle-inventory.json"
    write_json(inventory_path, inventory)
    identity = next(row for row in inventory["identities"] if row["logical_id"] == "residential_l01_v0")
    registration = registration_for(identity)
    final_runs = []
    for number in (1, 2):
        final_runs.append(_render_replay(root, evidence_root / f"four-view-repair/replay-{number:02d}", f"docs/production/evidence/PLAY-096/four-view-repair/replay-{number:02d}", registration))
    if [(x["sha256"], x["decoded_sha256"]) for x in final_runs[0]["lods"]] != [(x["sha256"], x["decoded_sha256"]) for x in final_runs[1]["lods"]]:
        raise ValueError("two repository replays differ")
    with tempfile.TemporaryDirectory(prefix="play096-four-view-root-a-") as first, tempfile.TemporaryDirectory(prefix="play096-four-view-root-b-") as second:
        first_root, second_root = Path(first), Path(second)
        _materialize_repository_root(root, first_root, inventory_path)
        _materialize_repository_root(root, second_root, inventory_path)
        fresh_output = Path("docs/production/evidence/PLAY-096/four-view-repair/fresh-root-replay")
        first_run = _render_replay(first_root, first_root / fresh_output, str(fresh_output), registration)
        second_run = _render_replay(second_root, second_root / fresh_output, str(fresh_output), registration)
        if canonical_json(first_run) != canonical_json(second_run):
            raise ValueError("fresh-root receipts are not byte-identical")
        fresh_root_sha = sha256_bytes(canonical_json(first_run))
    handoff = direction_handoff_document(inventory)
    if validate_direction_handoff(handoff, root=root):
        raise ValueError("four-view handoff failed")
    handoff_path = evidence_root / "four-view-repair/direction-handoff.json"
    write_json(handoff_path, handoff)
    receipt = {
        "schema": SCHEMA_VERSION,
        "task": TASK,
        "contract": CONTRACT,
        "route_id": ROUTE_ID,
        "route_sha256": ROUTE_SHA256,
        "authority": AUTHORITY,
        "base": BASE,
        "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA256},
        "identity": git_identity(root),
        "inventory": {"path": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-096/single-angle-inventory.json", "identity_count": 43, "direction_count": 172, "sha256": sha256_file(inventory_path)},
        "handoff": {"path": "docs/production/evidence/PLAY-096/four-view-repair/direction-handoff.json", "sha256": sha256_file(handoff_path)},
        "normalization": {"canvas_pixels": list(CANVAS), "pivot": list(GROUND_PIVOT), "scale_source": "CONTRACT-026-full-canvas-registration", "bbox_shadow_prop_derived": False, "registration_profile": {"path": REGISTRATION_PROFILE_PATH, "sha256": REGISTRATION_PROFILE_SHA256}},
        "replays": final_runs,
        "fresh_root_comparison": {"byte_identical": True, "canonical_sha256": fresh_root_sha, "paths_repo_relative": True, "materialized_repository_roots": 2, "root_labels": ["fresh-root-a", "fresh-root-b"]},
        "product_art_generated": False,
        "integration_admitted": False,
        "production_selected": False,
        "previous_evidence_preserved": ["docs/production/evidence/PLAY-096/calibration-receipt.json", "docs/production/evidence/PLAY-096/calibration/replay-01", "docs/production/evidence/PLAY-096/calibration/replay-02"],
    }
    receipt_path = evidence_root / "four-view-repair/repair-receipt.json"
    receipt["receipt_path"] = "docs/production/evidence/PLAY-096/four-view-repair/repair-receipt.json"
    write_json(receipt_path, receipt)
    rejection = {
        "schema": 1,
        "task": TASK,
        "contract": CONTRACT,
        "preserved_prior_candidate": True,
        "returned_defects": [
            "integrated civic IDs and 43x4 direction matrix",
            "per-identity/per-direction raw and LOD digest handoff plus readiness",
            "repo-relative byte-identical fresh-root receipts",
            "full-canvas code-owned pivot and per-identity scale",
            "complete prompt/reference/hash/cleanup/gameplay-meaning provenance",
        ],
        "prior_evidence": receipt["previous_evidence_preserved"],
        "product_art_generated": False,
    }
    write_json(evidence_root / "four-view-repair/rejection-trail.json", rejection)
    return receipt
