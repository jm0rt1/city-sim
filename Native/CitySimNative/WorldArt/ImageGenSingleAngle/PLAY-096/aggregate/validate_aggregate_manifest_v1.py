#!/usr/bin/env python3
"""Deterministic, candidate-only PLAY-106 aggregate manifest validator.

The validator intentionally builds its manifest from the preserved repository
inputs instead of accepting a caller-controlled manifest.  This keeps the
mechanical proof hash-bound and fail-closed while South directional payloads
remain ungenerated.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


TASK = "PLAY-106"
MASTER = "65c0f4dd2054baa0446d4e9c9a3673dfb4a01521"
DIRECTIONS = ("north", "east", "south", "west")
LODS = ("city", "neighborhood", "block")
EXPECTED_COUNTS = {
    "identities": 43,
    "directions": 172,
    "lod_payloads": 516,
    "physical_raw": 44,
}
ANCHOR_PATH = "docs/production/decisions/PLAY-106-RAW-SOUTH-ANCHOR-AUTHORITY.md"
ANCHOR_SHA = "f70e5c2dd95c6642c682a0b93a52873a66005304ae618d37c6c5c5b4c6b59b7b"
INVENTORY_PATH = "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-096/single-angle-inventory.json"
INVENTORY_SHA = "3879048afa719ac3dd898d62f8cdfe2422d6972b5cc866ed0e2cc381d1bc4a95"
HANDOFF_PATH = "docs/production/evidence/PLAY-096/four-view-repair/direction-handoff.json"
HANDOFF_SHA = "6945c482a4a35240d757ee62522f0f71ff8bc573891031ea77c6a092c169e089"
INDUSTRIAL_CANONICAL_ID = "industrial_l01_v0"
INDUSTRIAL_CANONICAL_PATH = (
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/"
    "industrial_l01_v00-source-v01.png"
)
INDUSTRIAL_CANONICAL_SHA = "7ca3e26234e7e15df9a46775a83f7132f89e1ea1f22d97c42ca6d3502099bbd2"
INDUSTRIAL_EXCLUDED_PATH = (
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/"
    "industrial_l01_v00-source-v02.png"
)
INDUSTRIAL_EXCLUDED_SHA = "8e33dafb3a40f7dac6f5ca8c9c5cb81df2b63011d3fd0d4a0302ec04a99d264a"
INDUSTRIAL_EXCLUDED_DISPOSITION = "RETURN_source_v02_chroma_gate_failed"
AUTHORING_READINESS = {
    "sourceReady": False,
    "integrationAdmitted": False,
    "rendererQuarantined": False,
    "productionSelected": False,
}

# The South raw inventory is an immutable input to this validator.  Both
# Industrial v00 files remain physically preserved, but only v01 is canonical
# for the 43-row South authoring ledger.
EXPECTED_RAW_SHA256 = {
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l01_variant_0/source-v01.png": "a808c5da11450418afa26505261cac196480d7d98578e2e8ac796288c7ee0e57",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l01_variant_1/source-v01.png": "ef1dab1277f0c2dd6cd3a37a1e459e94c417b013fadda5f4f46b6b21187e3577",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l01_variant_2/source-v01.png": "984aeffd2cee62634ebc78055b3ef15953cf0df139b56d8346fcddac1750fed3",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l02_variant_0/source-v01.png": "cf99ef863be82f1092c721c99ff48e9fbc8856d3f429574fd99b99fb363e46d4",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l02_variant_1/source-v01.png": "e7b97d6ac595ebec80da2ecb7d748e71a2149c40a66c5029d03f60d11528f31b",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l02_variant_2/source-v01.png": "6b6d185e9325f8e6da6b51794abbe4c5808fc532f9a4a5fbac8379de45722b14",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l03_variant_0/source-v01.png": "e5aa4e2f198cf424ac6dff4903ec5838e920f510056b320e6ed60fc539f5aea0",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l03_variant_1/source-v01.png": "bae0cad8794a6ce1c50974bc9afbfb8a435394070827ad3a3493532af522d904",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l03_variant_2/source-v01.png": "c663f1ab3b916fda055459db764c7d573f06de53e2ab328ea9fce7947b97c16b",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l04_variant_0/source-v01.png": "6cdcebf9c39823f67634a1118c762e702b396934def40bb635bf0ff9491ab932",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l04_variant_1/source-v01.png": "50d78828ef4461dd6cbbb9e9a6110109619c646c4efec8b7f811215ceb2051bf",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/residential_l04_variant_2/source-v01.png": "e6be10cf0cf31df9c987d98d1b55ef9b223ff10ef8e57910a564184715671c15",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l01_v00-source-v01.png": "01549d72d951079a326470d29daf1b55825b389c56e2caab8a0b4626419a9fef",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l01_v01-source-v01.png": "bb2d8504fe1fc5d07bbdc6fc91780171d7d4df275cb646f514b1550121dcc570",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l01_v02-source-v01.png": "bd60b5a47c47b666d38f1889401694bd89a097ddf2e56bfae8dc7ac2d626f12c",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l02_v00-source-v01.png": "62a4694e3940d1643ca511622f9ab7276ab56a4b5a5931e001a174f0adcf4eb1",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l02_v01-source-v01.png": "468c4c5ab264c683f968eb2c9fcd3fe6260a9cc47d6216bcff8cc9f3e0b8baaa",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l02_v02-source-v01.png": "81a31adf0f943660f1252bdca222683e68f56726bca330199d45dc2b0595cb78",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l03_v00-source-v01.png": "264ca814ab761015ffc41b9a11eb7eb8de35c9968962c94f0a8759c21b3211ce",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l03_v01-source-v01.png": "c06539e8a56dff42c03fec405afdc396890a65c229a666de94f7bc176f04d063",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l03_v02-source-v01.png": "4eb85c7d03882075fde4679ef33edaf0c56835f01b1c7ed6e6985e3c70eb66b8",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l04_v00-source-v01.png": "d6dfdf166b6eab24a48898123f3a7d882cf1dac993bb1883edae5120a0d19be0",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l04_v01-source-v01.png": "aac09d5dff2eb0598ec2394238c5ffb4beba0141f8bc0224baca2b00450e4483",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/commercial_l04_v02-source-v01.png": "3937bc91fa2b3958b98fb697ff870ba92d0aa569a3b4b8e49880b3036295363f",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l01_v00-source-v01.png": "7ca3e26234e7e15df9a46775a83f7132f89e1ea1f22d97c42ca6d3502099bbd2",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l01_v00-source-v02.png": "8e33dafb3a40f7dac6f5ca8c9c5cb81df2b63011d3fd0d4a0302ec04a99d264a",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l01_v01-source-v01.png": "1c5132289691f74a6cbff9b9ad38fad2d0d92ebfe6560e73e886246be5a3ae9b",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l01_v02-source-v01.png": "3da2842a0a36ae3aa27d00703572d16e094b49be2e15f36c63e7e1afece0caa5",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l02_v00-source-v01.png": "294817873333d7ebb9d763f5932624a8f83cd7784cdddb9ab7b5c90d8a64574a",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l02_v01-source-v01.png": "008c6ccf5785ef9be39db539a9a5b230292542c8ff269d8eeeaa9b18685e2912",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l02_v02-source-v01.png": "94e8031146b34e8025b6045410480fd9a51e99770a4c651e48bcd0f7d68ec55b",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l03_v00-source-v01.png": "22260fb870a981bf18b0f39f10d84f8c1bce594577756ce715bf0f130c31cea1",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l03_v01-source-v01.png": "1f11174b58be21d640fdb122626d5c0f06452dda4f36706f34d51363f220fa72",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l03_v02-source-v01.png": "4cde35c09d4d3ef86880133420d3f14872f4820fd8207c4c286b17092029c830",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l04_v00-source-v01.png": "6c631be5f372c351fbeb6a9ac9f0343569a7c2a43cbf172bdb83512aef38cef1",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l04_v01-source-v01.png": "81dd05f26b3b5dc0234bcf9cde55a0f961a6fa0b4f0f87e7cfc1065e3bcc240b",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l04_v02-source-v01.png": "dcfda7c8f86192cd330fcdc9075e5b2583a1db8497da64d7b5ea99bfae8c55cb",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-100/civic/raw/city-hall-v01.png": "89701d7c1e95644267bd72627fb1f97d21aea09ca930ad3b73ebb05ddaedb819",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-100/civic/raw/fire-station-v01.png": "33e2d69e44120f0ba6b81e54ccd22eeb3ef9021265b264831d4d2ccfc67403bf",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-100/civic/raw/park-v01.png": "e5797cf8900a6390965ae01bf57be172e2e98e26d17fefafc7b759f372d8caf7",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-100/civic/raw/police-station-v01.png": "af934e9cd1b3e5f76ece34f0ea1a5b51600e074db297e1039972be3586ed935d",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-100/civic/raw/power-plant-v01.png": "752c75b1fd0c2d5b869d371738df7f4abd6a3675ab420edb6c2f32e463a9bffb",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-100/civic/raw/school-v01.png": "62d7cd7fbbc16fd5fe770120476ae970a6ffec56972a2a1f332c6495cb3a46ed",
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-100/civic/raw/water-tower-v01.png": "731a166771d75b97c32c3ebc9e0708fed175f349c20467a72645d45a30c55ff0",
}


def canonical(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def report_path_for_display(report_path: Path, root: Path) -> str:
    try:
        return str(report_path.relative_to(root))
    except ValueError:
        return str(report_path)


def repo_root() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "Native").is_dir() and (parent / ".git").exists():
            return parent
    raise RuntimeError("could not locate repository root")


def git_head(root: Path) -> str:
    return subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def canonical_id(raw_path: str) -> str:
    path = Path(raw_path)
    family = next(part for part in path.parts if part in {"residential", "commercial", "industrial", "civic"})
    if family == "residential":
        return path.parent.name.replace("_variant_", "_v")
    if family in {"commercial", "industrial"}:
        logical_id = path.name.split("-source-", 1)[0]
        return logical_id.replace("_v00", "_v0").replace("_v01", "_v1").replace("_v02", "_v2")
    return f"civic_{path.stem.removesuffix('-v01').replace('-', '_')}_v0"


def identity_rows(root: Path) -> list[dict[str, Any]]:
    inventory = json.loads((root / INVENTORY_PATH).read_text(encoding="utf-8"))
    identities = inventory.get("identities")
    if not isinstance(identities, list):
        raise ValueError("PLAY-096 inventory identities is not a list")
    return identities


def raw_records(root: Path) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    for relative in sorted(EXPECTED_RAW_SHA256):
        path = root / relative
        if not path.is_file():
            records.append({"path": relative, "sha256": "", "logicalId": canonical_id(relative), "status": "missing"})
            continue
        records.append({"path": relative, "sha256": file_sha(path), "logicalId": canonical_id(relative), "status": "available"})
    return records


def authoring_duplicate_policy() -> dict[str, Any]:
    return {
        "canonicalId": INDUSTRIAL_CANONICAL_ID,
        "canonicalPath": INDUSTRIAL_CANONICAL_PATH,
        "canonicalSha256": INDUSTRIAL_CANONICAL_SHA,
        "decision": "CANONICAL_V01_PRESERVE",
        "excludedDisposition": INDUSTRIAL_EXCLUDED_DISPOSITION,
        "excludedPath": INDUSTRIAL_EXCLUDED_PATH,
        "excludedSha256": INDUSTRIAL_EXCLUDED_SHA,
        "unresolved": False,
    }


def canonical_authoring_rows(
    identities: list[dict[str, Any]], records: list[dict[str, str]]
) -> list[dict[str, Any]]:
    by_id: dict[str, list[dict[str, str]]] = {}
    by_path = {record["path"]: record for record in records}
    for record in records:
        by_id.setdefault(record["logicalId"], []).append(record)

    rows: list[dict[str, Any]] = []
    for identity in identities:
        logical_id = identity["logicalId"]
        if logical_id == INDUSTRIAL_CANONICAL_ID:
            selected = by_path.get(INDUSTRIAL_CANONICAL_PATH)
        else:
            candidates = by_id.get(logical_id, [])
            selected = candidates[0] if len(candidates) == 1 else None
        rows.append(
            {
                "authoringDisposition": "CANONICAL_SOUTH_AUTHORING_ANCHOR",
                "family": identity["family"],
                "kind": identity["kind"],
                "level": identity["level"],
                "logicalId": logical_id,
                "path": selected["path"] if selected else None,
                "readiness": dict(AUTHORING_READINESS),
                "sha256": selected["sha256"] if selected else None,
                "status": selected["status"] if selected else "missing_or_ambiguous",
                "variant": identity["variant"],
            }
        )
    return rows


def excluded_raw_evidence(records: list[dict[str, str]]) -> list[dict[str, Any]]:
    by_path = {record["path"]: record for record in records}
    record = by_path.get(INDUSTRIAL_EXCLUDED_PATH)
    return [
        {
            "countsToward": {
                "canonicalDigest": False,
                "direction": False,
                "identity": False,
                "sourceAdmission": False,
            },
            "disposition": INDUSTRIAL_EXCLUDED_DISPOSITION,
            "logicalId": INDUSTRIAL_CANONICAL_ID,
            "path": INDUSTRIAL_EXCLUDED_PATH,
            "retryAllowed": False,
            "sha256": record["sha256"] if record else None,
            "status": record["status"] if record else "missing",
        }
    ]


def canonical_authoring_digest(rows: list[dict[str, Any]]) -> str:
    return sha256_bytes(canonical(rows).encode("utf-8"))


def validate_authoring_projection(report: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    rows = report.get("canonicalSouthAuthoringRows", [])
    raw_files = report.get("rawFiles", [])
    identity_ids = report.get("identityIds", [])
    excluded = report.get("excludedRawEvidence", [])

    if len(rows) != EXPECTED_COUNTS["identities"]:
        errors.append(f"canonical_authoring_row_count:{len(rows)}!=43")
    row_ids = [row.get("logicalId") for row in rows]
    if len(row_ids) != len(set(row_ids)):
        errors.append("duplicate_canonical_authoring_ids")
    if row_ids != identity_ids:
        errors.append("canonical_authoring_identity_order_or_set_mismatch")

    expected_paths_by_id: dict[str, list[str]] = {}
    for path in EXPECTED_RAW_SHA256:
        if path == INDUSTRIAL_EXCLUDED_PATH:
            continue
        expected_paths_by_id.setdefault(canonical_id(path), []).append(path)
    raw_by_path = {record.get("path"): record for record in raw_files}
    for row in rows:
        logical_id = row.get("logicalId")
        expected_paths = expected_paths_by_id.get(logical_id, [])
        if len(expected_paths) != 1 or row.get("path") != expected_paths[0]:
            errors.append(f"canonical_authoring_path_mismatch:{logical_id}")
            continue
        expected_path = expected_paths[0]
        expected_sha = EXPECTED_RAW_SHA256[expected_path]
        if row.get("sha256") != expected_sha:
            errors.append(f"canonical_authoring_sha_mismatch:{logical_id}")
        if row.get("status") != "available":
            errors.append(f"canonical_authoring_unavailable:{logical_id}")
        if row.get("readiness") != AUTHORING_READINESS:
            errors.append(f"canonical_authoring_readiness_not_false:{logical_id}")
        if row.get("authoringDisposition") != "CANONICAL_SOUTH_AUTHORING_ANCHOR":
            errors.append(f"canonical_authoring_disposition_mismatch:{logical_id}")
        raw = raw_by_path.get(expected_path)
        if raw is None or raw.get("sha256") != expected_sha or raw.get("status") != "available":
            errors.append(f"canonical_authoring_raw_binding_mismatch:{logical_id}")

    expected_excluded = excluded_raw_evidence(raw_files)
    if excluded != expected_excluded:
        errors.append("excluded_raw_evidence_mismatch")
    elif excluded[0].get("sha256") != INDUSTRIAL_EXCLUDED_SHA:
        errors.append("excluded_raw_evidence_sha_mismatch")
    if report.get("duplicatePolicy") != authoring_duplicate_policy():
        errors.append("authoring_duplicate_policy_mismatch")
    if report.get("canonicalSouthAuthoringDigestSha256") != canonical_authoring_digest(rows):
        errors.append("canonical_authoring_digest_mismatch")
    return sorted(set(errors))


def build_manifest(root: Path) -> dict[str, Any]:
    identities = identity_rows(root)
    records = raw_records(root)
    by_id: dict[str, list[dict[str, str]]] = {}
    for record in records:
        by_id.setdefault(record["logicalId"], []).append(record)

    rows: list[dict[str, Any]] = []
    for identity in identities:
        logical_id = identity["logical_id"]
        raw_candidates = by_id.get(logical_id, [])
        if len(raw_candidates) == 1:
            raw = {
                "path": raw_candidates[0]["path"],
                "sha256": raw_candidates[0]["sha256"] or None,
                "status": raw_candidates[0]["status"],
            }
        else:
            raw = {"path": None, "sha256": None, "status": "unresolved_duplicate"}
        for direction in DIRECTIONS:
            rows.append(
                {
                    "logicalId": logical_id,
                    "direction": direction,
                    "identityDirectionKey": f"{logical_id}:{direction}",
                    "alias": {"aliasOf": None, "transform": "none"},
                    "raw": raw,
                    "record": {"path": None, "sha256": None, "status": "not_generated"},
                    "lods": [
                        {"lod": lod, "path": None, "sha256": None, "status": "not_generated"}
                        for lod in LODS
                    ],
                    "readiness": {
                        "candidateReadyForIndependentReview": False,
                        "sourceReady": False,
                        "integrationAdmitted": False,
                        "rendererQuarantined": False,
                        "productionSelected": False,
                    },
                }
            )
    return {
        "schema": 1,
        "task": TASK,
        "contract": {
            "authoredFourView": "CONTRACT-025",
            "registration": "CONTRACT-026",
            "rotation": "CONTRACT-027",
            "lodChroma": "CONTRACT-028",
        },
        "authority": {
            # Bind the aggregate report to the immutable Integration
            # authority, not the worker's moving post-checkpoint HEAD.  A
            # continuation replay must produce the same manifest digest after
            # the worker commits its own validator/report checkpoint.
            "master": MASTER,
            "southAnchorDecision": {"path": ANCHOR_PATH, "sha256": ANCHOR_SHA},
        },
        "scope": {
            "identityCount": len(identities),
            "directionCount": len(rows),
            "lodPayloadCount": sum(len(row["lods"]) for row in rows),
            "physicalRawCount": len(records),
            "directions": list(DIRECTIONS),
            "lods": list(LODS),
        },
        "identities": [
            {
                "family": item["family"],
                "kind": item["kind"],
                "level": item["level"],
                "logicalId": item["logical_id"],
                "variant": item["variant"],
            }
            for item in identities
        ],
        "rows": rows,
        "rawFiles": records,
        "flags": {
            "sourceReady": False,
            "integrationAdmitted": False,
            "rendererQuarantined": False,
            "productionSelected": False,
            "readinessMutation": False,
            "runtimeMutation": False,
            "productionSelection": False,
            "runtimeSelectorImplemented": False,
        },
        "duplicatePolicy": {
            "canonicalId": "industrial_l01_v0",
            "decision": "CANONICAL_V01_PRESERVE",
            "unresolved": True,
        },
    }


def validate_manifest(root: Path, manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    scope = manifest.get("scope", {})
    identities = manifest.get("identities", [])
    rows = manifest.get("rows", [])
    records = manifest.get("rawFiles", [])
    if manifest.get("schema") != 1 or manifest.get("task") != TASK:
        errors.append("manifest_schema_or_task_mismatch")
    if manifest.get("contract") != {
        "authoredFourView": "CONTRACT-025",
        "registration": "CONTRACT-026",
        "rotation": "CONTRACT-027",
        "lodChroma": "CONTRACT-028",
    }:
        errors.append("contract_binding_mismatch")
    if scope.get("identityCount") != EXPECTED_COUNTS["identities"]:
        errors.append(f"identity_count:{scope.get('identityCount')}!=43")
    if scope.get("directionCount") != EXPECTED_COUNTS["directions"]:
        errors.append(f"direction_count:{scope.get('directionCount')}!=172")
    if scope.get("lodPayloadCount") != EXPECTED_COUNTS["lod_payloads"]:
        errors.append(f"lod_payload_count:{scope.get('lodPayloadCount')}!=516")
    if scope.get("physicalRawCount") != EXPECTED_COUNTS["physical_raw"]:
        errors.append(f"physical_raw_count:{scope.get('physicalRawCount')}!=44")
    identity_ids = [item.get("logicalId") for item in identities]
    if len(identity_ids) != len(set(identity_ids)):
        errors.append("duplicate_logical_identities")
    if len(identities) != EXPECTED_COUNTS["identities"]:
        errors.append("identity_matrix_incomplete")
    expected_keys = {f"{logical_id}:{direction}" for logical_id in identity_ids for direction in DIRECTIONS}
    actual_keys = {row.get("identityDirectionKey") for row in rows}
    if len(rows) != EXPECTED_COUNTS["directions"] or actual_keys != expected_keys:
        errors.append("direction_matrix_incomplete_or_duplicate")
    if len(records) != EXPECTED_COUNTS["physical_raw"]:
        errors.append("raw_inventory_incomplete")

    expected_paths = set(EXPECTED_RAW_SHA256)
    actual_paths = {record.get("path") for record in records}
    if actual_paths != expected_paths:
        errors.append("raw_path_set_mismatch")
    by_id: dict[str, list[dict[str, str]]] = {}
    for record in records:
        path = record.get("path")
        logical_id = record.get("logicalId")
        by_id.setdefault(logical_id, []).append(record)
        expected_sha = EXPECTED_RAW_SHA256.get(path)
        resolved = root / path if isinstance(path, str) else None
        if expected_sha is None:
            errors.append(f"unexpected_raw_path:{path}")
        elif record.get("sha256") != expected_sha:
            errors.append(f"raw_sha_mismatch:{path}")
        elif resolved is None or not resolved.is_file():
            errors.append(f"raw_missing:{path}")
        elif file_sha(resolved) != expected_sha:
            errors.append(f"raw_bytes_changed:{path}")
        if record.get("status") != "available":
            errors.append(f"raw_not_available:{path}")

    duplicate_ids = sorted(key for key, values in by_id.items() if len(values) > 1)
    if duplicate_ids != ["industrial_l01_v0"]:
        # Retain the explicit canonical v0 duplicate decision even if a future
        # filename is malformed.
        errors.append(f"unexpected_duplicate_identity_set:{duplicate_ids}")
    if manifest.get("duplicatePolicy") != {
        "canonicalId": "industrial_l01_v0",
        "decision": "CANONICAL_V01_PRESERVE",
        "unresolved": True,
    }:
        errors.append("industrial_duplicate_policy_mismatch")
    flags = manifest.get("flags", {})
    for key, value in flags.items():
        if value is not False:
            errors.append(f"flag_not_false:{key}")
    for row in rows:
        if row.get("alias") != {"aliasOf": None, "transform": "none"}:
            errors.append(f"alias_or_transform_present:{row.get('identityDirectionKey')}")
        readiness = row.get("readiness", {})
        for key, value in readiness.items():
            if value is not False:
                errors.append(f"readiness_not_false:{row.get('identityDirectionKey')}:{key}")
        lods = row.get("lods", [])
        if len(lods) != len(LODS) or [lod.get("lod") for lod in lods] != list(LODS):
            errors.append(f"lod_matrix_incomplete:{row.get('identityDirectionKey')}")
        if row.get("record", {}).get("status") != "not_generated":
            errors.append(f"record_unexpectedly_generated:{row.get('identityDirectionKey')}")
        if any(lod.get("status") != "not_generated" for lod in lods):
            errors.append(f"lod_unexpectedly_generated:{row.get('identityDirectionKey')}")
    if any(row.get("record", {}).get("status") == "not_generated" for row in rows):
        errors.append("directional_payloads_incomplete")

    for path, expected in (
        (INVENTORY_PATH, INVENTORY_SHA),
        (ANCHOR_PATH, ANCHOR_SHA),
        (HANDOFF_PATH, HANDOFF_SHA),
    ):
        resolved = root / path
        if not resolved.is_file():
            errors.append(f"dependency_missing:{path}")
        elif file_sha(resolved) != expected:
            errors.append(f"dependency_sha_mismatch:{path}")

    handoff_path = root / HANDOFF_PATH
    if handoff_path.is_file() and file_sha(handoff_path) == HANDOFF_SHA:
        handoff = json.loads(handoff_path.read_text(encoding="utf-8"))
        handoff_rows = handoff.get("rows", [])
        if len(handoff_rows) != EXPECTED_COUNTS["directions"]:
            errors.append("handoff_direction_count_mismatch")
        for handoff_row in handoff_rows:
            readiness = handoff_row.get("readiness", {})
            for key in ("sourceReady", "integrationAdmitted", "rendererQuarantined", "productionSelected"):
                if readiness.get(key) is not False:
                    errors.append(f"handoff_flag_not_false:{handoff_row.get('identity_direction_key', handoff_row.get('identityDirectionKey'))}:{key}")
            if handoff_row.get("record", {}).get("status") not in {None, "not_generated"}:
                errors.append("handoff_record_generated")
    return sorted(set(errors))


def run_once(root: Path) -> dict[str, Any]:
    manifest = build_manifest(root)
    errors = validate_manifest(root, manifest)
    authoring_rows = canonical_authoring_rows(manifest["identities"], manifest["rawFiles"])
    excluded_evidence = excluded_raw_evidence(manifest["rawFiles"])
    report = {
        "schema": 1,
        "task": TASK,
        "validator": "validate_aggregate_manifest_v1",
        "status": "FAIL_CLOSED" if errors else "PASS",
        "authority": manifest["authority"],
        "scope": manifest["scope"],
        "identityIds": [identity["logicalId"] for identity in manifest["identities"]],
        "canonicalSouthAuthoringRows": authoring_rows,
        "canonicalSouthAuthoringDigestSha256": canonical_authoring_digest(authoring_rows),
        "excludedRawEvidence": excluded_evidence,
        "rawFiles": manifest["rawFiles"],
        "duplicatePolicy": authoring_duplicate_policy(),
        "flags": manifest["flags"],
        "manifestSha256": sha256_bytes(canonical(manifest).encode("utf-8")),
        "errors": [],
        "checks": {
            "exact43Identities": manifest["scope"]["identityCount"] == 43,
            "exact43CanonicalSouthRows": len(authoring_rows) == 43,
            "uniqueCanonicalSouthIds": len({row["logicalId"] for row in authoring_rows}) == 43,
            "exact172DirectionRows": manifest["scope"]["directionCount"] == 172,
            "exact516LodPayloads": manifest["scope"]["lodPayloadCount"] == 516,
            "exact44PhysicalRawFiles": manifest["scope"]["physicalRawCount"] == 44,
            "rawPathShaBindings": not any(error.startswith("raw_") for error in errors),
            "canonicalIndustrialV01Selected": any(
                row["logicalId"] == INDUSTRIAL_CANONICAL_ID
                and row["path"] == INDUSTRIAL_CANONICAL_PATH
                and row["sha256"] == INDUSTRIAL_CANONICAL_SHA
                for row in authoring_rows
            ),
            "excludedIndustrialV02Preserved": excluded_evidence
            == excluded_raw_evidence(manifest["rawFiles"]),
            "duplicateResolvedForSouthAuthoring": authoring_duplicate_policy()["unresolved"] is False,
            "directionalPayloadsIncomplete": "directional_payloads_incomplete" in errors,
            "allFlagsFalse": all(value is False for value in manifest["flags"].values()),
        },
    }
    errors = sorted(set(errors + validate_authoring_projection(report)))
    report["errors"] = errors
    report["status"] = "FAIL_CLOSED" if errors else "PASS"
    report["checks"]["canonicalSouthDigestValid"] = "canonical_authoring_digest_mismatch" not in errors
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--fail-closed", action="store_true")
    parser.add_argument("--output-root", default="docs/production/evidence/PLAY-106/aggregate-validator")
    args = parser.parse_args(argv)
    if args.repeat < 1:
        print("FAIL: --repeat must be positive")
        return 2
    try:
        root = repo_root()
        reports = [run_once(root) for _ in range(args.repeat)]
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}")
        return 2
    equal = all(canonical(report) == canonical(reports[0]) for report in reports[1:])
    final = dict(reports[0])
    final["repeat"] = {"requested": args.repeat, "runsEqual": equal}
    if not equal:
        final["status"] = "FAIL_CLOSED"
        final["errors"] = sorted(set(final["errors"] + ["nondeterministic_repeat_output"]))
    output_root = root / args.output_root
    output_root.mkdir(parents=True, exist_ok=True)
    report_path = output_root / "PLAY-106-AGGREGATE-VALIDATOR-REPORT-v1.json"
    report_path.write_text(json.dumps(final, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{final['status']}: {len(final['errors'])} validation error(s); repeat_equal={equal}")
    print(f"report={report_path_for_display(report_path, root)}")
    if final["status"] == "FAIL_CLOSED" and not args.fail_closed:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
