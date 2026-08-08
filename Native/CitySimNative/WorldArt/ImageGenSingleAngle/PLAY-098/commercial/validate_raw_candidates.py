#!/usr/bin/env python3
"""Objective PLAY-098 raw-source checks; intentionally not a normalizer."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import zlib


ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"
EXPECTED = [f"commercial_l{level:02d}_v{variant:02d}" for level in range(1, 5) for variant in range(3)]
MAGENTA = (255, 0, 255)


def png_pixels(path: Path) -> tuple[int, int, int, bytes]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("invalid PNG signature")
    pos = 8
    idat = bytearray()
    width = height = bit_depth = color_type = None
    interlace = None
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += length + 12
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
        elif kind == b"IDAT":
            idat.extend(chunk)
        elif kind == b"IEND":
            break
    if None in (width, height, bit_depth, color_type, interlace):
        raise ValueError("missing IHDR")
    if (bit_depth, color_type, interlace) != (8, 2, 0):
        raise ValueError(f"expected non-interlaced 8-bit RGB, got {(bit_depth, color_type, interlace)}")
    row_bytes = width * 3
    decoded = zlib.decompress(bytes(idat))
    if len(decoded) != height * (row_bytes + 1):
        raise ValueError("unexpected decompressed scanline length")
    rows: list[bytearray] = []
    offset = 0
    for _ in range(height):
        filter_type = decoded[offset]
        raw = bytearray(decoded[offset + 1 : offset + 1 + row_bytes])
        offset += row_bytes + 1
        prior = rows[-1] if rows else bytearray(row_bytes)
        for i in range(row_bytes):
            left = raw[i - 3] if i >= 3 else 0
            up = prior[i]
            up_left = prior[i - 3] if i >= 3 else 0
            if filter_type == 1:
                raw[i] = (raw[i] + left) & 255
            elif filter_type == 2:
                raw[i] = (raw[i] + up) & 255
            elif filter_type == 3:
                raw[i] = (raw[i] + ((left + up) // 2)) & 255
            elif filter_type == 4:
                p = left + up - up_left
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - up_left)
                predictor = left if pa <= pb and pa <= pc else up if pb <= pc else up_left
                raw[i] = (raw[i] + predictor) & 255
            elif filter_type != 0:
                raise ValueError(f"unsupported PNG filter {filter_type}")
        rows.append(raw)
    return width, height, 3, b"".join(rows)


def check_one(logical_id: str) -> dict[str, object]:
    path = RAW / f"{logical_id}-source-v01.png"
    result: dict[str, object] = {"logicalId": logical_id, "path": str(path.relative_to(ROOT.parent.parent.parent.parent.parent.parent))}
    try:
        width, height, channels, pixels = png_pixels(path)
        result.update({
            "status": "PASS",
            "width": width,
            "height": height,
            "channels": channels,
            "decodedSha256": hashlib.sha256(pixels).hexdigest(),
            "rawSha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        })
        if (width, height, channels) != (1536, 1024, 3):
            raise ValueError("expected 1536x1024 RGB source")
        def rgb(x: int, y: int) -> tuple[int, int, int]:
            start = (y * width + x) * 3
            return tuple(pixels[start : start + 3])  # type: ignore[return-value]
        corners = [rgb(0, 0), rgb(width - 1, 0), rgb(0, height - 1), rgb(width - 1, height - 1)]
        if any(pixel != MAGENTA for pixel in corners):
            raise ValueError("all four corners must be exact #ff00ff")
        edge_pixels = [rgb(x, 0) for x in range(width)] + [rgb(x, height - 1) for x in range(width)]
        edge_pixels += [rgb(0, y) for y in range(1, height - 1)] + [rgb(width - 1, y) for y in range(1, height - 1)]
        if any(pixel != MAGENTA for pixel in edge_pixels):
            raise ValueError("subject or shadow touches frame edge")
        non_matte = [(x, y) for y in range(height) for x in range(width) if rgb(x, y) != MAGENTA]
        if not non_matte:
            raise ValueError("source contains no visible subject")
        xs, ys = zip(*non_matte)
        bbox = [min(xs), min(ys), max(xs), max(ys)]
        result["nonMagentaBoundingBox"] = bbox
        result["nonMagentaPixels"] = len(non_matte)
        result["transparentReadyPadding"] = {
            "left": bbox[0], "top": bbox[1], "right": width - 1 - bbox[2], "bottom": height - 1 - bbox[3]
        }
        return result
    except Exception as exc:  # keep every identity independently reportable
        result.update({"status": "FAIL", "error": str(exc)})
        return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--family", required=True)
    args = parser.parse_args()
    if args.family != "commercial":
        print(json.dumps({"status": "FAIL", "error": "PLAY-098 validator only accepts --family commercial"}))
        return 2
    with ThreadPoolExecutor(max_workers=len(EXPECTED)) as pool:
        results = list(pool.map(check_one, EXPECTED))
    decoded = [item.get("decodedSha256") for item in results if item.get("status") == "PASS"]
    report = {
        "task": "PLAY-098",
        "family": "commercial",
        "rawOnly": True,
        "normalization": "not_run",
        "expectedCount": len(EXPECTED),
        "resultCount": len(results),
        "uniqueDecodedCount": len(set(decoded)),
        "status": "PASS" if len(results) == len(EXPECTED) and all(item.get("status") == "PASS" for item in results) and len(set(decoded)) == len(EXPECTED) else "FAIL",
        "records": results,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
