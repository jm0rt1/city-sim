#!/usr/bin/env python3
"""Strict standard-library decoder for PLAY-081 8-bit RGBA PNG outputs."""

from __future__ import annotations

import hashlib
import struct
import zlib
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left


def _unfilter(
    filter_type: int,
    encoded: bytes,
    prior: bytes,
    bytes_per_pixel: int,
) -> bytes:
    decoded = bytearray(encoded)
    for index in range(len(decoded)):
        left = decoded[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
        above = prior[index]
        upper_left = prior[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
        if filter_type == 0:
            predictor = 0
        elif filter_type == 1:
            predictor = left
        elif filter_type == 2:
            predictor = above
        elif filter_type == 3:
            predictor = (left + above) // 2
        elif filter_type == 4:
            predictor = _paeth(left, above, upper_left)
        else:
            raise ValueError(f"unsupported PNG filter {filter_type}")
        decoded[index] = (decoded[index] + predictor) & 0xFF
    return bytes(decoded)


def decode_rgba_png_bytes(
    data: bytes,
    *,
    label: str = "<bytes>",
) -> tuple[tuple[int, int], bytes]:
    """Decode one non-interlaced 8-bit RGBA PNG and verify every chunk CRC."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{label}: invalid PNG signature")
    offset = len(PNG_SIGNATURE)
    width = height = 0
    saw_header = False
    saw_end = False
    compressed = bytearray()
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError(f"{label}: truncated PNG chunk")
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_end = offset + 12 + length
        if chunk_end > len(data):
            raise ValueError(f"{label}: truncated PNG payload")
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        expected_crc = struct.unpack(
            ">I",
            data[offset + 8 + length : chunk_end],
        )[0]
        actual_crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise ValueError(f"{label}: invalid {kind!r} CRC")
        offset = chunk_end

        if kind == b"IHDR":
            if saw_header or length != 13:
                raise ValueError(f"{label}: invalid IHDR")
            width, height, depth, color_type, compression, filtering, interlace = (
                struct.unpack(">IIBBBBB", payload)
            )
            if width <= 0 or height <= 0:
                raise ValueError(f"{label}: invalid PNG dimensions")
            if (depth, color_type, compression, filtering, interlace) != (
                8,
                6,
                0,
                0,
                0,
            ):
                raise ValueError(
                    f"{label}: expected non-interlaced 8-bit RGBA PNG"
                )
            saw_header = True
        elif kind == b"IDAT":
            if not saw_header or saw_end:
                raise ValueError(f"{label}: IDAT outside image stream")
            compressed.extend(payload)
        elif kind == b"IEND":
            if length != 0:
                raise ValueError(f"{label}: invalid IEND")
            saw_end = True
            break

    if not saw_header or not saw_end or not compressed:
        raise ValueError(f"{label}: incomplete PNG")
    packed = zlib.decompress(bytes(compressed))
    stride = width * 4
    if len(packed) != height * (stride + 1):
        raise ValueError(f"{label}: decoded scanline length mismatch")

    rows: list[bytes] = []
    cursor = 0
    prior = bytes(stride)
    for _ in range(height):
        filter_type = packed[cursor]
        encoded = packed[cursor + 1 : cursor + 1 + stride]
        cursor += stride + 1
        row = _unfilter(filter_type, encoded, prior, 4)
        rows.append(row)
        prior = row
    return (width, height), b"".join(rows)


def decode_rgba_png(path: Path) -> tuple[tuple[int, int], bytes]:
    return decode_rgba_png_bytes(path.read_bytes(), label=str(path))


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def _encode_filtered_row(
    raw: bytes,
    prior: bytes,
    filter_type: int,
) -> bytes:
    encoded = bytearray(len(raw))
    for index, value in enumerate(raw):
        left = raw[index - 4] if index >= 4 else 0
        above = prior[index]
        upper_left = prior[index - 4] if index >= 4 else 0
        if filter_type == 0:
            predictor = 0
        elif filter_type == 1:
            predictor = left
        elif filter_type == 2:
            predictor = above
        elif filter_type == 3:
            predictor = (left + above) // 2
        elif filter_type == 4:
            predictor = _paeth(left, above, upper_left)
        else:
            raise ValueError("self-test filter must be in 0...4")
        encoded[index] = (value - predictor) & 0xFF
    return bytes([filter_type]) + bytes(encoded)


def self_test() -> dict[str, object]:
    """Exercise all five PNG filters entirely in memory."""
    rows = [
        bytes((10 + row, 20 + row, 30 + row, 255, 40 + row, 50 + row, 60 + row, 128))
        for row in range(5)
    ]
    prior = bytes(8)
    encoded_rows = []
    for filter_type, raw in enumerate(rows):
        encoded_rows.append(_encode_filtered_row(raw, prior, filter_type))
        prior = raw
    header = struct.pack(">IIBBBBB", 2, 5, 8, 6, 0, 0, 0)
    fixture = (
        PNG_SIGNATURE
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(b"".join(encoded_rows), level=9))
        + _chunk(b"IEND", b"")
    )
    size, decoded = decode_rgba_png_bytes(fixture, label="<self-test>")
    expected = b"".join(rows)
    passed = size == (2, 5) and decoded == expected
    return {
        "implementation": "python-standard-library",
        "modules": ["hashlib", "struct", "zlib"],
        "supportedFormat": "non-interlaced-8-bit-rgba-png",
        "filtersExercised": [0, 1, 2, 3, 4],
        "fixtureSize": list(size),
        "decodedRgbaSha256": hashlib.sha256(decoded).hexdigest(),
        "passed": passed,
    }
