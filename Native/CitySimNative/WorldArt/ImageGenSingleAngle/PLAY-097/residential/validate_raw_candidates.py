#!/usr/bin/env python3
"""PLAY-097 raw Residential candidate pre-screen; no normalization or acceptance."""
from __future__ import annotations
import argparse, hashlib, json, struct, sys, zlib
from pathlib import Path

IDS = [f"residential_l0{level}_variant_{variant}" for level in range(1, 5) for variant in range(3)]
ROOT = Path(__file__).resolve().parent

def png_info(path: Path) -> dict:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not PNG")
    pos = 8
    ihdr = None
    idat = bytearray()
    while pos < len(data):
        n = struct.unpack(">I", data[pos:pos+4])[0]
        kind = data[pos+4:pos+8]
        chunk = data[pos+8:pos+8+n]
        pos += n + 12
        if kind == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            idat.extend(chunk)
        elif kind == b"IEND":
            break
    if ihdr is None:
        raise ValueError("missing IHDR")
    width, height, depth, color_type, _, _, interlace = ihdr
    result = {"width": width, "height": height, "depth": depth, "colorType": color_type, "interlace": interlace, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
    if (width, height, depth, color_type, interlace) == (1536, 1024, 8, 2, 0):
        decoded = zlib.decompress(bytes(idat))
        stride = width * 3
        rows, offset, previous = [], 0, bytearray(stride)
        def paeth(a: int, b: int, c: int) -> int:
            estimate = a + b - c
            distances = (abs(estimate - a), abs(estimate - b), abs(estimate - c))
            return (a, b, c)[distances.index(min(distances))]
        for _ in range(height):
            filter_type = decoded[offset]
            offset += 1
            row = bytearray(decoded[offset:offset + stride])
            offset += stride
            for index in range(stride):
                left = row[index - 3] if index >= 3 else 0
                up = previous[index]
                upper_left = previous[index - 3] if index >= 3 else 0
                if filter_type == 1:
                    row[index] = (row[index] + left) & 255
                elif filter_type == 2:
                    row[index] = (row[index] + up) & 255
                elif filter_type == 3:
                    row[index] = (row[index] + ((left + up) // 2)) & 255
                elif filter_type == 4:
                    row[index] = (row[index] + paeth(left, up, upper_left)) & 255
            rows.append(row)
            previous = row
        corners = [list(rows[y][x * 3:x * 3 + 3]) for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1))]
        result["cornerRGB"] = corners
        result["flatMagentaCorners"] = all(pixel == [255, 0, 255] for pixel in corners)
    return result

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--family", required=True)
    args = parser.parse_args()
    if args.family != "residential":
        print("FAIL: only residential is claimed")
        return 1
    rows, hashes, failures = [], set(), []
    for identity in IDS:
        path = ROOT / "raw" / identity / "source-v01.png"
        row = {"identity": identity, "path": str(path)}
        try:
            info = png_info(path)
            row.update(info)
            if info["width"] != 1536 or info["height"] != 1024 or info["depth"] != 8 or info["colorType"] not in (2, 6) or info["interlace"] != 0:
                failures.append(f"{identity}: unexpected PNG shape or encoding")
            if info.get("colorType") == 2 and not info.get("flatMagentaCorners", False):
                failures.append(f"{identity}: source corners are not exact flat #ff00ff chroma")
            if info["sha256"] in hashes:
                failures.append(f"{identity}: duplicate raw SHA-256")
            hashes.add(info["sha256"])
        except Exception as exc:
            failures.append(f"{identity}: {exc}")
        rows.append(row)
    result = {"taskId":"PLAY-097","family":"residential","count":len(rows),"uniqueRawHashes":len(hashes),"rows":rows,"failures":failures,"normalization":"blocked_pending_exact_PLAY-096_harness"}
    print(json.dumps(result, indent=2))
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())
