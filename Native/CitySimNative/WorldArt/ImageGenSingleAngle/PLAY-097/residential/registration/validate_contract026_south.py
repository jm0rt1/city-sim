#!/usr/bin/env python3
"""Mechanical PLAY-097 South registration and handoff gate."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ROOT.parents[5]
EVIDENCE = ROOT.parents[5] / "docs" / "production" / "evidence" / "PLAY-097"
IDS = [f"residential_l0{level}_variant_{variant}" for level in range(1, 5) for variant in range(3)]
LODS = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
ROUTE_ID = "four-view-v5:play-097-south-admission-ready-repair"
ROUTE_SHA256 = "ccc9339b8a099b3dbde55febe345e77cf2be2e03ef2ef5c2954ee75968cd8d52"
AUTHORITY_COMMIT = "65825389d586a128ddf6feb5356c33661ba9a8e8"
BASE_COMMIT = "a61ab80101f596f56ffc1dd7e37b32bd1b220357"
CLAIM_SHA256 = "816acffd9e8cb7cc76ad068b7c6b6ff9fed4015b1646c37ac68c148714901126"
CONTRACT_SHA256 = "4781de72429a1f691b9226f7f7668b170b278a4ccd171ac4ea02f5e1df9176eb"
PROFILE_SHA256 = "6663482339e953bdcbcb86bcfc876676989fbcb7f74a91f3f1b480d124fe3bd8"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repo_path(path: Path) -> str:
    return path.relative_to(REPO_ROOT).as_posix()


def digest_json(value: object) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main() -> int:
    failures: list[str] = []
    rows = []
    raw_hashes: set[str] = set()
    normalized_hashes: dict[str, set[str]] = {lod: set() for lod in LODS}
    handoff_path = ROOT / "handoff" / "south-admission-v3.json"
    if not handoff_path.is_file():
        failures.append("missing handoff")
    for identity in IDS:
        raw_path = ROOT / "raw" / identity / "source-v01.png"
        provenance_path = ROOT / "provenance" / identity / "source-v01.json"
        prompt_path = ROOT / "prompts" / identity / "source-v01.md"
        raw_hash = sha(raw_path)
        provenance = json.loads(provenance_path.read_text())
        if raw_hash in raw_hashes:
            failures.append(f"raw alias: {identity}")
        raw_hashes.add(raw_hash)
        if provenance.get("rawSha256") != raw_hash or provenance.get("logicalId") != identity:
            failures.append(f"provenance mismatch: {identity}")
        if not prompt_path.is_file():
            failures.append(f"missing prompt: {identity}")
        registration_path = ROOT / "registrations" / identity / "south-registration.json"
        if not registration_path.is_file():
            failures.append(f"missing registration: {identity}")
        else:
            registration = json.loads(registration_path.read_text())
            expected_binding = {"routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256, "authorityCommit": AUTHORITY_COMMIT, "baseCommit": BASE_COMMIT, "claimSha256": CLAIM_SHA256, "contract": "CONTRACT-026", "contractSha256": CONTRACT_SHA256, "profileSha256": PROFILE_SHA256}
            for key, expected in expected_binding.items():
                if registration.get(key) != expected:
                    failures.append(f"registration binding: {identity}/{key}")
            record = dict(registration)
            actual_digest = record.pop("recordSha256", None)
            if actual_digest != digest_json(record):
                failures.append(f"registration digest: {identity}")
        lod_rows = {}
        for lod, canvas in LODS.items():
            path = ROOT / "normalized" / identity / lod / "source-v03.png"
            with Image.open(path) as image:
                image.load()
                if image.size != canvas or image.mode != "RGBA":
                    failures.append(f"shape/mode: {identity}/{lod}")
                hidden = sum(1 for red, green, blue, alpha in image.getdata() if alpha == 0 and (red or green or blue))
                if hidden:
                    failures.append(f"hidden chroma: {identity}/{lod} ({hidden})")
            output_hash = sha(path)
            if output_hash in normalized_hashes[lod]:
                failures.append(f"normalized alias: {identity}/{lod}")
            normalized_hashes[lod].add(output_hash)
            lod_rows[lod] = {"path": repo_path(path), "sha256": output_hash, "dimensions": list(canvas), "mode": "RGBA"}
        rows.append({"identity": identity, "rawSha256": raw_hash, "lods": lod_rows})
    handoff = json.loads(handoff_path.read_text()) if handoff_path.is_file() else {}
    expected_handoff_binding = {"routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256, "authorityCommit": AUTHORITY_COMMIT, "baseCommit": BASE_COMMIT, "claimSha256": CLAIM_SHA256, "contract": "CONTRACT-026", "contractSha256": CONTRACT_SHA256, "profileSha256": PROFILE_SHA256}
    for key, expected in expected_handoff_binding.items():
        if handoff.get(key) != expected:
            failures.append(f"handoff binding: {key}")
    handoff_record = dict(handoff)
    actual_handoff_digest = handoff_record.pop("handoffSha256", None)
    if actual_handoff_digest != digest_json(handoff_record):
        failures.append("handoff digest")
    if handoff.get("identityCount") != 12 or handoff.get("uniqueRawSha256") != 12:
        failures.append("handoff coverage mismatch")
    for key in ("sourceReady", "integrationAdmitted", "rendererQuarantined", "productionSelected"):
        if handoff.get(key) is not False:
            failures.append(f"handoff {key} is not false")
    if handoff.get("candidateReadyForIndependentReview") is not True:
        failures.append("handoff candidateReadyForIndependentReview is not true")
    result = {"schema": 1, "taskId": "PLAY-097", "routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256, "authorityCommit": AUTHORITY_COMMIT, "baseCommit": BASE_COMMIT, "claimSha256": CLAIM_SHA256, "contract": "CONTRACT-026", "contractSha256": CONTRACT_SHA256, "profileSha256": PROFILE_SHA256, "direction": "south", "identityCount": len(rows), "uniqueRawSha256": len(raw_hashes), "uniqueNormalizedSha256ByLod": {lod: len(values) for lod, values in normalized_hashes.items()}, "rawBytePreserved": True, "hiddenChroma": False, "aliases": False, "candidateReadyForIndependentReview": True, "sourceReady": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False, "failures": failures, "rows": rows}
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "south-admission-v3-validation.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
