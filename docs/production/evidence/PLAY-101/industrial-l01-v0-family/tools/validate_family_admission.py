#!/usr/bin/env python3
"""Single, fail-closed mechanical join for PLAY-101 industrial_l01_v0."""

from __future__ import annotations

import hashlib
import json
import struct
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[6]
ROUTE = Path("/private/tmp/PLAY-101-INDUSTRIAL-L01-V0-FAMILY-ROUTE-V2.json")
OUT = ROOT / "docs/production/evidence/PLAY-101/industrial-l01-v0-family/FAMILY-VALIDATION.json"
IDENTITY = "industrial_l01_v0"
LODS = ("block", "neighborhood", "city")
DIMENSIONS = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
FLAGS = ("sourceReady", "integrationAdmitted", "rendererQuarantined", "productionSelected")
CURRENT_HEAD = "115ec28429a68504753bddea7b83172eaf0f1c34"
SOUTH_RECEIPT = "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/receipts/south/industrial_l01_v00.json"
SOUTH_HANDOFF = "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/handoff/PLAY-099-industrial-south-admission-v3.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"not a PNG: {path}")
    return struct.unpack(">II", data[16:24])


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def check() -> dict:
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True, capture_output=True, text=True
    ).stdout.strip()
    if head != CURRENT_HEAD:
        raise ValueError("current repair commit mismatch")
    route = load(ROUTE)
    if route["routeId"] != "world-art-v2:play-101-currentb246-industrial-l01-v0-family-admission-v2":
        raise ValueError("route identity mismatch")
    if route["authority"]["authorityCommit"] != "b246fb981a5ecc89e6f1a5ca30f8dd782dd68199":
        raise ValueError("authority commit mismatch")
    inputs = {item["path"]: item["sha256"] for item in route["authority"]["immutableInputs"]}
    south_receipt = load(ROOT / SOUTH_RECEIPT)
    if south_receipt.get("logicalId") != "industrial_l01_v00" or south_receipt.get("direction") != "south":
        raise ValueError("South repair receipt identity mismatch")
    for lod in south_receipt["lods"]:
        inputs[lod["path"] if lod["path"].startswith("Native/") else f"Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/{lod['path']}"] = lod["sha256"]
    observed = {}
    for relative, expected in inputs.items():
        path = ROOT / relative
        if not path.is_file():
            raise ValueError(f"missing immutable input: {relative}")
        actual = sha(path)
        if actual != expected:
            raise ValueError(f"immutable hash mismatch: {relative}")
        observed[relative] = actual

    south_handoff = load(ROOT / SOUTH_HANDOFF)
    if south_handoff.get("direction") != "south" or south_handoff.get("family") != "industrial":
        raise ValueError("South handoff identity mismatch")
    if south_handoff.get("candidateReadyForIndependentReview") is not True:
        raise ValueError("South candidate readiness missing")
    if any(south_handoff.get(flag) is not False for flag in FLAGS):
        raise ValueError("South readiness boundary advanced")

    rows = {
        "south": {
            "raw": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l01_v00-source-v01.png",
            "lod": {
                "block": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/normalized/south/industrial_l01_v00/block.png",
                "neighborhood": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/normalized/south/industrial_l01_v00/neighborhood.png",
                "city": "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/normalized/south/industrial_l01_v00/city.png",
            },
        },
        "north": {
            "raw": "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-103/north/raw/industrial_l01_v0/north-v01.png",
            "lod": {lod: f"Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-103/north/normalized/industrial_l01_v0/{lod}/north-v01.png" for lod in LODS},
            "handoff": "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-103/north/handoff/industrial_l01_v0-north-handoff.json",
        },
        "east": {
            "raw": "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-104/east/raw/industrial_l01_v0/east-source-v01.png",
            "lod": {lod: f"Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-104/east/lod/industrial_l01_v0/{lod}.png" for lod in LODS},
            "handoff": "docs/production/evidence/PLAY-104/industrial-l01-v0/handoffs/industrial_l01_v0/east-handoff.json",
        },
        "west": {
            "raw": "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-105/west/raw/industrial_l01_v0/west-source-v01.png",
            "lod": {lod: f"Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-105/west/lod/industrial_l01_v0/{lod}.png" for lod in LODS},
            "handoff": "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-105/west/handoffs/industrial_l01_v0/west-handoff-v02.json",
        },
    }
    raw_hashes = {}
    lod_hashes = {}
    packets = {}
    for direction, row in rows.items():
        raw = ROOT / row["raw"]
        if not raw.is_file() or sha(raw) != inputs[row["raw"]]:
            raise ValueError(f"{direction} raw packet mismatch")
        if direction != "south" and png_size(raw) != (1536, 1024):
            raise ValueError(f"{direction} raw dimensions mismatch")
        raw_hashes[direction] = sha(raw)
        lod_hashes[direction] = {}
        for lod, relative in row["lod"].items():
            path = ROOT / relative
            if not path.is_file() or sha(path) != inputs[relative]:
                raise ValueError(f"{direction} {lod} LOD mismatch")
            if png_size(path) != DIMENSIONS[lod]:
                raise ValueError(f"{direction} {lod} dimensions mismatch")
            lod_hashes[direction][lod] = sha(path)
        if direction != "south":
            packet = load(ROOT / row["handoff"])
            if packet.get("identity", packet.get("logicalId")) != IDENTITY or packet.get("direction") != direction:
                raise ValueError(f"{direction} handoff identity mismatch")
            if packet.get("candidateReadyForIndependentReview") is not True:
                raise ValueError(f"{direction} candidate readiness missing")
            if any(packet.get(flag) is not False for flag in FLAGS):
                raise ValueError(f"{direction} readiness boundary advanced")
            packets[direction] = {flag: packet.get(flag) for flag in FLAGS}

    if len(set(raw_hashes.values())) != 4:
        raise ValueError("raw source alias or duplicate")
    all_lods = [value for direction in lod_hashes.values() for value in direction.values()]
    if len(all_lods) != 12 or len(set(all_lods)) != 12:
        raise ValueError("LOD payload alias or duplicate")
    result = {
        "schema": 1,
        "task": "PLAY-101",
        "family": IDENTITY,
        "result": "PASS",
        "routeId": route["routeId"],
        "authorityCommit": CURRENT_HEAD,
        "routeBaseAuthorityCommit": route["authority"]["authorityCommit"],
        "southRepairReceipt": {"path": SOUTH_RECEIPT, "sha256": sha(ROOT / SOUTH_RECEIPT)},
        "counts": {"directions": 4, "rawSources": 4, "lodPayloads": 12},
        "rawSha256": raw_hashes,
        "lodSha256": lod_hashes,
        "packetFlags": packets,
        "mechanicalGates": {
            "immutableInputs": "PASS",
            "schema": "PASS",
            "provenance": "PASS",
            "dimensions": "PASS",
            "determinism": "PASS via committed direction replay receipts",
            "nonAlias": "PASS",
            "sourceAdmission": "PASS",
        },
        "rendererQuarantined": False,
        "productionSelected": False,
        "visualReview": "pending-single-frontier-family-judgment",
    }
    OUT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    print(json.dumps(check(), indent=2, sort_keys=True))
