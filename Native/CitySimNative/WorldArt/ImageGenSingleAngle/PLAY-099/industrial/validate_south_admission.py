#!/usr/bin/env python3
"""Mechanical PLAY-099 South admission and full-canvas registration gate."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from validate_raw_candidates import read_png


ROOT = Path(__file__).resolve().parent
EXPECTED = [f"industrial_l{level:02d}_v{variant:02d}" for level in range(1, 5) for variant in range(3)]
CANVASES = {"source-rgba.png": (1536, 1024), "block.png": (1024, 683), "neighborhood.png": (512, 342), "city.png": (256, 171)}
ROUTE_ID = "four-view-v3:play-099-south-admission"
ROUTE_SHA = "5669c3e28d23b46d4e213886809214fa1843988ecb313413ecab9ae39a44116e"
RAW_HASHES = {
    item["logicalId"]: item["rawSha256"]
    for item in json.loads((ROOT / "provenance/PLAY-099-industrial-raw-provenance.json").read_text())["candidates"]
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    failures: list[str] = []
    receipts = json.loads((ROOT / "receipts/south/all-south-receipts.json").read_text())
    handoff = json.loads((ROOT / "handoff/PLAY-099-industrial-south-admission-v3.json").read_text())
    provenance = json.loads((ROOT / "provenance/south-admission-provenance-v3.json").read_text())
    if [item["logicalId"] for item in receipts] != EXPECTED:
        failures.append("receipt identity coverage/order")
    if handoff["routeId"] != ROUTE_ID or handoff["routeSha256"] != ROUTE_SHA:
        failures.append("handoff route binding")
    if provenance["routeId"] != ROUTE_ID or provenance["routeSha256"] != ROUTE_SHA:
        failures.append("provenance route binding")
    for record in (handoff, provenance):
        if record["candidateReadyForIndependentReview"] is not True or record["sourceReady"] is not False or record["integrationAdmitted"] is not False or record["productionSelected"] is not False:
            failures.append("candidate-only disposition flags")

    normalized_hashes: list[str] = []
    lod_hashes: list[str] = []
    for receipt in receipts:
        logical_id = receipt["logicalId"]
        if receipt["direction"] != "south" or receipt["rawBytesPreserved"] is not True:
            failures.append(f"{logical_id}: South/raw preservation binding")
        raw = ROOT / receipt["rawPath"]
        if not raw.exists() or sha(raw) != RAW_HASHES.get(logical_id) or sha(raw) != receipt["rawSha256"]:
            failures.append(f"{logical_id}: raw hash changed or missing")
        normalized = ROOT / receipt["normalizedPath"]
        try:
            width, height, channels, _, pixels = read_png(normalized)
            if (width, height) != CANVASES["source-rgba.png"] or channels != 4:
                failures.append(f"{logical_id}: normalized source encoding/canvas")
            if any(pixels[index] or pixels[index + 1] or pixels[index + 2] for index in range(0, len(pixels), 4) if pixels[index + 3] == 0):
                failures.append(f"{logical_id}: hidden RGB under transparent pixels")
            if any(pixels[index + 3] != 0 for index in (0, (width - 1) * 4, (height - 1) * width * 4, (height * width - 1) * 4)):
                failures.append(f"{logical_id}: frame-edge alpha")
            if sha(normalized) != receipt["normalizedSha256"]:
                failures.append(f"{logical_id}: normalized receipt hash")
            normalized_hashes.append(sha(normalized))
        except Exception as error:  # noqa: BLE001
            failures.append(f"{logical_id}: normalized decode {error}")
        if receipt["groundPivotSource"] != [768, 896] or receipt["frontageSocketSource"] != [640, 832] or receipt["footprintPolygonSource"] != [[768, 640], [1024, 768], [768, 896], [512, 768]]:
            failures.append(f"{logical_id}: registration geometry")
        for lod in receipt["lods"]:
            path = ROOT / lod["path"]
            try:
                width, height, channels, _, pixels = read_png(path)
                if (width, height) != tuple(lod["canvas"]) or (width, height) != CANVASES[lod["name"] + ".png"] or channels != 4:
                    failures.append(f"{logical_id}/{lod['name']}: LOD canvas/encoding")
                visible_alpha = 0
                visible_rgb = 0
                hidden_rgb = 0
                for index in range(0, len(pixels), 4):
                    red, green, blue, alpha = pixels[index:index + 4]
                    visible_alpha += alpha != 0
                    visible_rgb += alpha != 0 and (red != 0 or green != 0 or blue != 0)
                    hidden_rgb += alpha == 0 and (red != 0 or green != 0 or blue != 0)
                if not visible_alpha or not visible_rgb:
                    failures.append(f"{logical_id}/{lod['name']}: empty alpha/RGB payload")
                if hidden_rgb:
                    failures.append(f"{logical_id}/{lod['name']}: hidden RGB under transparent pixels")
                edge_alpha = 0
                for x in range(width):
                    edge_alpha += pixels[x * 4 + 3] != 0
                    edge_alpha += pixels[((height - 1) * width + x) * 4 + 3] != 0
                for y in range(1, height - 1):
                    edge_alpha += pixels[(y * width) * 4 + 3] != 0
                    edge_alpha += pixels[(y * width + width - 1) * 4 + 3] != 0
                if edge_alpha:
                    failures.append(f"{logical_id}/{lod['name']}: frame-edge alpha")
                if sha(path) != lod["sha256"]:
                    failures.append(f"{logical_id}/{lod['name']}: LOD receipt hash")
                lod_hashes.append(sha(path))
            except Exception as error:  # noqa: BLE001
                failures.append(f"{logical_id}/{lod['name']}: LOD decode {error}")
    if len(set(normalized_hashes)) != 12 or len(set(lod_hashes)) != 36:
        failures.append("normalized/LOD aliases")
    print(f"PLAY-099 South admission: identities={len(receipts)} normalizedSources={len(normalized_hashes)} lods={len(lod_hashes)}")
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        return 1
    print("PASS: raw bytes preserved, full-canvas RGBA registration, deterministic receipts, and candidate-only handoff")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
