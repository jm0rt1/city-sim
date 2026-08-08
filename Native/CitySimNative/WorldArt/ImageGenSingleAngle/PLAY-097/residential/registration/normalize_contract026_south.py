#!/usr/bin/env python3
"""PLAY-097 South admission: task-local CONTRACT-026 mechanical normalizer."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ROOT.parents[5]
IDS = [f"residential_l0{level}_variant_{variant}" for level in range(1, 5) for variant in range(3)]
LODS = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
ROUTE_ID = "four-view-v5:play-097-south-admission-ready-repair"
ROUTE_SHA256 = "ccc9339b8a099b3dbde55febe345e77cf2be2e03ef2ef5c2954ee75968cd8d52"
AUTHORITY_COMMIT = "65825389d586a128ddf6feb5356c33661ba9a8e8"
BASE_COMMIT = "a61ab80101f596f56ffc1dd7e37b32bd1b220357"
CLAIM_SHA256 = "816acffd9e8cb7cc76ad068b7c6b6ff9fed4015b1646c37ac68c148714901126"
PROFILE_SHA256 = "6663482339e953bdcbcb86bcfc876676989fbcb7f74a91f3f1b480d124fe3bd8"
CONTRACT_SHA256 = "4781de72429a1f691b9226f7f7668b170b278a4ccd171ac4ea02f5e1df9176eb"
PIVOT = [768, 896]
FOOTPRINT = [[768, 640], [1024, 768], [768, 896], [512, 768]]
SOCKET = [640, 832]


def digest_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def digest_json(value: object) -> str:
    return digest_bytes(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())


def repo_path(path: Path) -> str:
    return path.relative_to(REPO_ROOT).as_posix()


def round_half_even_ratio(numerator: int, denominator: int) -> int:
    quotient, remainder = divmod(numerator, denominator)
    doubled = remainder * 2
    if doubled < denominator:
        return quotient
    if doubled > denominator:
        return quotient + 1
    return quotient + (quotient & 1)


def lod_point(point: list[int], canvas: tuple[int, int]) -> list[int]:
    return [round_half_even_ratio(point[0] * canvas[0], 1536), round_half_even_ratio(point[1] * canvas[1], 1024)]


def registration(canvas: tuple[int, int]) -> dict:
    return {
        "canvas": list(canvas),
        "groundPivotSource": PIVOT,
        "groundPivotLod": lod_point(PIVOT, canvas),
        "footprintPolygonSource": FOOTPRINT,
        "footprintPolygonLod": [lod_point(point, canvas) for point in FOOTPRINT],
        "frontageSocketSource": SOCKET,
        "frontageSocketLod": lod_point(SOCKET, canvas),
        "coordinateRule": "exact rational source coordinate multiplied by destination dimension divided by source dimension, independently rounded half to even",
    }


def raw_info(path: Path) -> tuple[bytes, dict]:
    raw = path.read_bytes()
    with Image.open(path) as image:
        image.load()
        if image.size != (1536, 1024) or image.mode not in ("RGB", "RGBA"):
            raise ValueError(f"unexpected raw shape/mode: {image.size} {image.mode}")
        if image.mode == "RGBA" and image.getextrema()[3] != (255, 255):
            raise ValueError("raw alpha is not fully opaque")
        corners = [image.convert("RGB").getpixel(point) for point in ((0, 0), (1535, 0), (0, 1023), (1535, 1023))]
    return raw, {"sha256": digest_bytes(raw), "bytes": len(raw), "dimensions": [1536, 1024], "mode": "RGB", "cornerRGB": [list(corner) for corner in corners]}


def normalize(raw_path: Path, output_path: Path, canvas: tuple[int, int]) -> dict:
    with Image.open(raw_path) as source:
        rgba = source.convert("RGBA")
        pixels = rgba.load()
        # Fixed source-key rule only. It never infers a crop, pivot, socket, or geometry.
        for y in range(rgba.height):
            for x in range(rgba.width):
                red, green, blue, _ = pixels[x, y]
                if red >= 200 and blue >= 180 and green <= 90:
                    pixels[x, y] = (0, 0, 0, 0)
        resized = rgba.resize(canvas, Image.Resampling.LANCZOS)
        clean = []
        for red, green, blue, alpha in resized.getdata():
            clean.append((0, 0, 0, 0) if alpha == 0 else (red, green, blue, alpha))
        resized.putdata(clean)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        resized.save(output_path, format="PNG", optimize=False, compress_level=9)
    with Image.open(output_path) as result:
        result.load()
        if result.mode != "RGBA" or result.size != canvas:
            raise ValueError("normalized output shape/mode mismatch")
        if any((red or green or blue) and alpha == 0 for red, green, blue, alpha in result.getdata()):
            raise ValueError("hidden chroma in transparent output")
    data = output_path.read_bytes()
    return {"path": repo_path(output_path), "sha256": digest_bytes(data), "bytes": len(data), "dimensions": list(canvas), "mode": "RGBA"}


def main() -> int:
    normalized_root = ROOT / "normalized"
    registration_root = ROOT / "registrations"
    rows = []
    raw_hashes: set[str] = set()
    record_hashes: set[str] = set()
    for identity in IDS:
        raw_path = ROOT / "raw" / identity / "source-v01.png"
        prompt_path = ROOT / "prompts" / identity / "source-v01.md"
        provenance_path = ROOT / "provenance" / identity / "source-v01.json"
        raw, info = raw_info(raw_path)
        raw_hash = info["sha256"]
        if raw_hash in raw_hashes:
            raise ValueError(f"raw alias: {identity}")
        raw_hashes.add(raw_hash)
        if not prompt_path.is_file() or not provenance_path.is_file():
            raise ValueError(f"incomplete provenance: {identity}")
        provenance = json.loads(provenance_path.read_text())
        required = {"logicalId", "rawPath", "rawSha256", "promptPath", "artifactPath", "model", "tool"}
        if not required.issubset(provenance) or provenance["logicalId"] != identity or provenance["rawSha256"] != raw_hash:
            raise ValueError(f"provenance mismatch: {identity}")
        lods = {}
        for lod, canvas in LODS.items():
            output_path = normalized_root / identity / lod / "source-v03.png"
            lods[lod] = normalize(raw_path, output_path, canvas)
        identity_record = {"schema": 1, "taskId": "PLAY-097", "routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256, "authorityCommit": AUTHORITY_COMMIT, "baseCommit": BASE_COMMIT, "claimSha256": CLAIM_SHA256, "contract": "CONTRACT-026", "contractSha256": CONTRACT_SHA256, "profileSha256": PROFILE_SHA256, "identity": identity, "family": "residential", "direction": "south", "sourceRevision": "source-v01", "raw": {"path": repo_path(raw_path), **info}, "promptPath": repo_path(prompt_path), "provenancePath": repo_path(provenance_path), "southReference": {"kind": "preserved_south_anchor", "path": repo_path(raw_path), "sha256": raw_hash}, "registration": {"sourceCanvas": [1536, 1024], "groundPivotSource": PIVOT, "footprintPolygonSource": FOOTPRINT, "frontageSocketSource": SOCKET}, "lods": lods, "candidateReadyForIndependentReview": True, "sourceReady": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False}
        identity_record["recordSha256"] = digest_json(identity_record)
        record_hashes.add(identity_record["recordSha256"])
        registration_path = registration_root / identity / "south-registration.json"
        registration_path.parent.mkdir(parents=True, exist_ok=True)
        registration_path.write_text(json.dumps(identity_record, indent=2) + "\n")
        rows.append(identity_record)
    handoff = {"schema": 1, "taskId": "PLAY-097", "routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256, "authorityCommit": AUTHORITY_COMMIT, "baseCommit": BASE_COMMIT, "claimSha256": CLAIM_SHA256, "contract": "CONTRACT-026", "contractSha256": CONTRACT_SHA256, "profileSha256": PROFILE_SHA256, "branch": "codex/citysim-world-art-residential", "direction": "south", "family": "residential", "sourceRevision": "source-v01", "identityCount": len(rows), "uniqueRawSha256": len(raw_hashes), "uniqueRecordSha256": len(record_hashes), "rawBytePreserved": True, "normalization": "task-local full-canvas Lanczos with fixed chroma-key and no pixel-derived geometry", "identities": rows, "candidateReadyForIndependentReview": True, "sourceReady": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False, "siblingInputsConsumed": [], "knownBlockers": ["frontier visual review and Integration admission remain required", "production selection remains false"]}
    handoff["handoffSha256"] = digest_json(handoff)
    handoff_path = ROOT / "handoff" / "south-admission-v3.json"
    handoff_path.parent.mkdir(parents=True, exist_ok=True)
    handoff_path.write_text(json.dumps(handoff, indent=2) + "\n")
    print(json.dumps({"taskId": "PLAY-097", "routeId": ROUTE_ID, "direction": "south", "identities": len(rows), "uniqueRawSha256": len(raw_hashes), "uniqueRecordSha256": len(record_hashes), "handoff": handoff_path.as_posix(), "productionSelected": False}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
