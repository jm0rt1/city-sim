#!/usr/bin/env python3
"""Minimal deterministic reader/writer for non-interlaced RGBA8 PNG files."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path


SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _paeth(left: int, up: int, upper_left: int) -> int:
    estimate = left + up - upper_left
    left_distance = abs(estimate - left)
    up_distance = abs(estimate - up)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= up_distance and left_distance <= upper_left_distance:
        return left
    if up_distance <= upper_left_distance:
        return up
    return upper_left


def decode_rgba_png(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if not data.startswith(SIGNATURE):
        raise ValueError(f"INVALID_PNG_SIGNATURE: {path}")
    cursor = len(SIGNATURE)
    width = height = 0
    compressed = bytearray()
    saw_end = False
    while cursor < len(data):
        if cursor + 12 > len(data):
            raise ValueError(f"TRUNCATED_PNG_CHUNK: {path}")
        length = struct.unpack(">I", data[cursor : cursor + 4])[0]
        kind = data[cursor + 4 : cursor + 8]
        chunk = data[cursor + 8 : cursor + 8 + length]
        expected_crc = struct.unpack(">I", data[cursor + 8 + length : cursor + 12 + length])[0]
        actual_crc = zlib.crc32(kind + chunk) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise ValueError(f"PNG_CRC_MISMATCH: {path}: {kind!r}")
        cursor += length + 12
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", chunk)
            if (depth, color, compression, filtering, interlace) != (8, 6, 0, 0, 0):
                raise ValueError(f"UNSUPPORTED_PNG_FORMAT: {path}")
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            saw_end = True
            break
    if width <= 0 or height <= 0 or not saw_end:
        raise ValueError(f"INCOMPLETE_PNG: {path}")

    packed = zlib.decompress(bytes(compressed))
    stride = width * 4
    expected_length = height * (stride + 1)
    if len(packed) != expected_length:
        raise ValueError(f"PNG_DECODED_LENGTH_MISMATCH: {path}")
    output = bytearray(width * height * 4)
    previous = bytearray(stride)
    source_offset = 0
    for row_index in range(height):
        filter_type = packed[source_offset]
        source_offset += 1
        filtered = packed[source_offset : source_offset + stride]
        source_offset += stride
        row = bytearray(stride)
        for index, value in enumerate(filtered):
            left = row[index - 4] if index >= 4 else 0
            up = previous[index]
            upper_left = previous[index - 4] if index >= 4 else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = up
            elif filter_type == 3:
                predictor = (left + up) // 2
            elif filter_type == 4:
                predictor = _paeth(left, up, upper_left)
            else:
                raise ValueError(f"UNSUPPORTED_PNG_FILTER: {path}: {filter_type}")
            row[index] = (value + predictor) & 0xFF
        start = row_index * stride
        output[start : start + stride] = row
        previous = row
    return width, height, bytes(output)


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def encode_rgba_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    stride = width * 4
    if len(rgba) != stride * height:
        raise ValueError(f"RGBA_LENGTH_MISMATCH: {path}")
    scanlines = bytearray()
    for row_index in range(height):
        scanlines.append(0)
        start = row_index * stride
        scanlines.extend(rgba[start : start + stride])
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    encoded = SIGNATURE + _chunk(b"IHDR", header) + _chunk(b"IDAT", zlib.compress(bytes(scanlines), 9)) + _chunk(b"IEND", b"")
    path.write_bytes(encoded)


def canonicalize_png(path: Path) -> tuple[int, int, bytes]:
    width, height, rgba = decode_rgba_png(path)
    encode_rgba_png(path, width, height, rgba)
    return width, height, rgba
