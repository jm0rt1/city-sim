#!/usr/bin/env python3
"""Objective pre-screen for PLAY-099 Industrial raw ImageGen candidates.

This is deliberately a raw-stage checker. It does not normalize, infer a
pivot, create LODs, or make a visual acceptance decision.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
from pathlib import Path


EXPECTED = tuple(
    f"industrial_l{level:02d}_v{variant:02d}-source-v01.png"
    for level in range(1, 5)
    for variant in range(3)
)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
CHROMA_DISTANCE_THRESHOLD = 140


def read_png(path: Path) -> tuple[int, int, int, int, bytes]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("not a PNG")
    offset = len(PNG_SIGNATURE)
    idat = bytearray()
    width = height = bit_depth = color_type = None
    interlace = None
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        chunk = data[offset + 8 : offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
        elif kind == b"IDAT":
            idat.extend(chunk)
        elif kind == b"IEND":
            break
    if None in (width, height, bit_depth, color_type, interlace):
        raise ValueError("missing IHDR")
    if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
        raise ValueError(
            f"unsupported PNG encoding bit_depth={bit_depth} color_type={color_type} interlace={interlace}"
        )
    channels = 3 if color_type == 2 else 4
    raw = __import__("zlib").decompress(bytes(idat))
    row_bytes = width * channels
    expected = height * (row_bytes + 1)
    if len(raw) != expected:
        raise ValueError(f"unexpected decompressed byte count {len(raw)} != {expected}")
    rows: list[bytes] = []
    previous = bytearray(row_bytes)
    cursor = 0
    for _ in range(height):
        filter_type = raw[cursor]
        cursor += 1
        current = bytearray(raw[cursor : cursor + row_bytes])
        cursor += row_bytes
        for index in range(row_bytes):
            left = current[index - channels] if index >= channels else 0
            up = previous[index]
            up_left = previous[index - channels] if index >= channels else 0
            if filter_type == 1:
                current[index] = (current[index] + left) & 0xFF
            elif filter_type == 2:
                current[index] = (current[index] + up) & 0xFF
            elif filter_type == 3:
                current[index] = (current[index] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                estimate = left + up - up_left
                pa = abs(estimate - left)
                pb = abs(estimate - up)
                pc = abs(estimate - up_left)
                predictor = left if pa <= pb and pa <= pc else up if pb <= pc else up_left
                current[index] = (current[index] + predictor) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"unsupported PNG filter {filter_type}")
        rows.append(bytes(current))
        previous = current
    pixels = b"".join(rows)
    return width, height, channels, color_type, pixels


def pixel(pixels: bytes, width: int, channels: int, x: int, y: int) -> tuple[int, int, int, int]:
    start = (y * width + x) * channels
    values = pixels[start : start + channels]
    return values[0], values[1], values[2], values[3] if channels == 4 else 255


def magenta_distance(rgb: tuple[int, int, int]) -> int:
    return abs(rgb[0] - 255) + abs(rgb[1]) + abs(rgb[2] - 255)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--family", required=True)
    args = parser.parse_args()
    if args.family != "industrial":
        print(f"FAIL: unsupported family {args.family!r}")
        return 2

    root = Path(__file__).resolve().parent
    raw_root = root / "raw"
    files = sorted(raw_root.glob("*.png"))
    actual = tuple(path.name for path in files)
    failures: list[str] = []
    if actual != EXPECTED:
        missing = sorted(set(EXPECTED) - set(actual))
        extra = sorted(set(actual) - set(EXPECTED))
        if missing:
            failures.append(f"missing={missing}")
        if extra:
            failures.append(f"extra={extra}")

    file_hashes: dict[str, str] = {}
    decoded_hashes: dict[str, str] = {}
    for path in files:
        try:
            width, height, channels, _, pixels = read_png(path)
            if (width, height) != (1536, 1024):
                failures.append(f"{path.name}: dimensions={width}x{height}")
            border_points = []
            for x in range(0, width, 32):
                border_points.extend((pixel(pixels, width, channels, x, 0), pixel(pixels, width, channels, x, height - 1)))
            for y in range(0, height, 32):
                border_points.extend((pixel(pixels, width, channels, 0, y), pixel(pixels, width, channels, width - 1, y)))
            border_magenta = sum(
                magenta_distance(p[:3]) <= CHROMA_DISTANCE_THRESHOLD
                for p in border_points
            )
            if border_magenta / len(border_points) < 0.90:
                failures.append(f"{path.name}: border_chroma_ratio={border_magenta/len(border_points):.3f}")
            center = pixel(pixels, width, channels, width // 2, height // 2)
            if magenta_distance(center[:3]) <= CHROMA_DISTANCE_THRESHOLD:
                failures.append(f"{path.name}: center remains chroma-only")
            file_hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
            decoded_hashes[path.name] = hashlib.sha256(pixels).hexdigest()
        except Exception as error:  # noqa: BLE001 - report candidate-local failures
            failures.append(f"{path.name}: {error}")

    duplicate_files = {value for value in file_hashes.values() if list(file_hashes.values()).count(value) > 1}
    duplicate_decoded = {value for value in decoded_hashes.values() if list(decoded_hashes.values()).count(value) > 1}
    if duplicate_files:
        failures.append(f"duplicate_file_hashes={sorted(duplicate_files)}")
    if duplicate_decoded:
        failures.append(f"duplicate_decoded_hashes={sorted(duplicate_decoded)}")

    print(f"PLAY-099 raw candidates: count={len(files)} expected={len(EXPECTED)}")
    print(f"unique_file_hashes={len(set(file_hashes.values()))} unique_decoded_hashes={len(set(decoded_hashes.values()))}")
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        return 1
    print("PASS: objective raw dimensions, PNG encoding, border chroma, center coverage, and uniqueness")
    return 0


if __name__ == "__main__":
    sys.exit(main())
