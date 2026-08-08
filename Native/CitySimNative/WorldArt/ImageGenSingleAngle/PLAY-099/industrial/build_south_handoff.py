#!/usr/bin/env python3
"""Assemble PLAY-099 South mechanical provenance and handoff records."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from datetime import date
from pathlib import Path


ROUTE_ID = "four-view-v3:play-099-south-admission"
ROUTE_SHA256 = "5669c3e28d23b46d4e213886809214fa1843988ecb313413ecab9ae39a44116e"
AUTHORITY = "b38fbfcf5e9e8fd9d092e9eb4abdc8a9d15b900b"
INPUT_HEAD = "a544c5d95f6ef1084dc6ee410f64445261d7af43"
BASE = "a61ab80101f596f56ffc1dd7e37b32bd1b220357"
PROFILE_PATH = "docs/production/decisions/CONTRACT-026-registration-profiles-v1.json"
PROFILE_SHA256 = "6663482339e953bdcbcb86bcfc876676989fbcb7f74a91f3f1b480d124fe3bd8"
CLAIM_PATH = "docs/production/claims/PLAY-099.world-art-industrial.md"
CLAIM_SHA256 = "d5a42e16f9e7d5a4dc0a9667e797022651737535b190fb7917650504a28f108b"
CONTRACT_PATH = "docs/production/decisions/CONTRACT-026-authored-four-view-registration.md"
CONTRACT_SHA256 = "4781de72429a1f691b9226f7f7668b170b278a4ccd171ac4ea02f5e1df9176eb"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parent
    provenance = json.loads((root / "provenance/PLAY-099-industrial-raw-provenance.json").read_text())
    receipts = json.loads((root / "receipts/south/all-south-receipts.json").read_text())
    expected = [f"industrial_l{level:02d}_v{variant:02d}" for level in range(1, 5) for variant in range(3)]
    if [item["logicalId"] for item in provenance["candidates"]] != expected:
        raise SystemExit("provenance identity order/coverage mismatch")
    if [item["logicalId"] for item in receipts] != expected:
        raise SystemExit("receipt identity order/coverage mismatch")
    prompt_common = provenance["promptCommon"]
    by_id = {item["logicalId"]: item for item in provenance["candidates"]}
    evidence = []
    for receipt in receipts:
        source = by_id[receipt["logicalId"]]
        if receipt["direction"] != "south" or not receipt["rawBytesPreserved"]:
            raise SystemExit(f"receipt binding failure: {receipt['logicalId']}")
        evidence.append({
            "logicalId": receipt["logicalId"],
            "level": receipt["level"],
            "variant": receipt["variant"],
            "direction": "south",
            "prompt": prompt_common + "\nSubject: " + source["subject"],
            "referenceRoles": provenance["references"],
            "artifactId": source["artifactId"],
            "intendedGameplayMeaning": source["intendedGameplayMeaning"],
            "rawPath": receipt["rawPath"],
            "rawSha256": receipt["rawSha256"],
            "normalizedPath": receipt["normalizedPath"],
            "normalizedSha256": receipt["normalizedSha256"],
            "groundPivotSource": receipt["groundPivotSource"],
            "frontageSocketSource": receipt["frontageSocketSource"],
            "footprintPolygonSource": receipt["footprintPolygonSource"],
            "lods": receipt["lods"],
            "disposition": "south_candidate_pending_frontier_review",
        })

    process_root = root / "process/south"
    process_root.mkdir(parents=True, exist_ok=True)
    script_path = root / "normalize_south.swift"
    process = {
        "schema": "PLAY-099-south-process-v3",
        "task": "PLAY-099",
        "routeId": ROUTE_ID,
        "routeSha256": ROUTE_SHA256,
        "inputHead": INPUT_HEAD,
        "normalizer": script_path.relative_to(root).as_posix(),
        "normalizerSha256": sha256(script_path),
        "compiler": "swiftc -framework CoreImage -framework CoreGraphics -framework ImageIO -framework UniformTypeIdentifiers -framework Foundation -framework CryptoKit",
        "filter": "CILanczosScaleTransform",
        "sourceTransform": "whole-canvas only; no crop, trim, recenter, resize-to-bounds, or pixel-derived geometry",
        "geometryAuthority": CONTRACT_PATH,
        "profile": PROFILE_PATH,
        "created": date.today().isoformat(),
    }
    (process_root / "normalizer-build.json").write_text(json.dumps(process, indent=2, sort_keys=True) + "\n")

    provenance_out = {
        "schema": "PLAY-099-south-provenance-v3",
        "task": "PLAY-099",
        "family": "industrial",
        "direction": "south",
        "authorityCommit": AUTHORITY,
        "inputHead": INPUT_HEAD,
        "baseCommit": BASE,
        "routeId": ROUTE_ID,
        "routeSha256": ROUTE_SHA256,
        "contract": {"path": CONTRACT_PATH, "sha256": CONTRACT_SHA256},
        "profile": {"path": PROFILE_PATH, "sha256": PROFILE_SHA256},
        "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA256},
        "tool": "task-local deterministic normalizer; no ImageGen call",
        "sourceCanvas": [1536, 1024],
        "groundPivotSource": [768, 896],
        "frontageSocketSource": [640, 832],
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "candidates": evidence,
    }
    provenance_path = root / "provenance/south-admission-provenance-v3.json"
    provenance_path.write_text(json.dumps(provenance_out, indent=2, sort_keys=True) + "\n")

    handoff = {
        "schema": "PLAY-099-south-admission-handoff-v3",
        "task": "PLAY-099",
        "family": "industrial",
        "direction": "south",
        "authorityCommit": AUTHORITY,
        "inputHead": INPUT_HEAD,
        "baseCommit": BASE,
        "routeId": ROUTE_ID,
        "routeSha256": ROUTE_SHA256,
        "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA256},
        "contract": {"path": CONTRACT_PATH, "sha256": CONTRACT_SHA256},
        "profile": {"path": PROFILE_PATH, "sha256": PROFILE_SHA256},
        "sourceRevision": "source-v01-preserved-south",
        "directionRootMap": {
            "raw": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw",
            "normalized": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/normalized/south",
            "process": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/process/south",
            "output": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/normalized/south",
            "evidence": "docs/production/evidence/PLAY-099",
            "handoff": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/handoff",
        },
        "parallelExecutionReceipt": {"routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256},
        "registration": {"groundPivotSource": [768, 896], "frontageSocketSource": [640, 832], "footprintPolygonSource": [[768, 640], [1024, 768], [768, 896], [512, 768]]},
        "lodMapping": {"filter": "CILanczosScaleTransform", "rounding": "round-half-even", "canvas": {"block": [1024, 683], "neighborhood": [512, 342], "city": [256, 171]}},
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "visualAcceptance": "not performed; frontier-owned",
        "identities": evidence,
    }
    handoff_root = root / "handoff"
    handoff_root.mkdir(parents=True, exist_ok=True)
    (handoff_root / "PLAY-099-industrial-south-admission-v3.json").write_text(json.dumps(handoff, indent=2, sort_keys=True) + "\n")

    report = {
        "schema": "PLAY-099-south-admission-report-v3",
        "routeId": ROUTE_ID,
        "routeSha256": ROUTE_SHA256,
        "rawCount": len(evidence),
        "normalizedSourceCount": len(evidence),
        "lodCount": sum(len(item["lods"]) for item in evidence),
        "rawBytesPreserved": all(item["rawSha256"] == by_id[item["logicalId"]]["rawSha256"] for item in evidence),
        "candidateReadyForIndependentReview": True,
        "integrationAdmitted": False,
        "productionSelected": False,
        "unrun": ["frontier visual acceptance", "Integration semantic admission", "aggregate/full gates", "runtime mapping"],
    }
    # industrial -> PLAY-099 -> ImageGenSingleAngle -> WorldArt ->
    # CitySimNative -> Native -> repository root.
    repo_root = root.parents[5]
    evidence_root = repo_root / "docs/production/evidence/PLAY-099"
    evidence_root.mkdir(parents=True, exist_ok=True)
    (evidence_root / "south-admission-report-v3.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")

    print(json.dumps(report, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
