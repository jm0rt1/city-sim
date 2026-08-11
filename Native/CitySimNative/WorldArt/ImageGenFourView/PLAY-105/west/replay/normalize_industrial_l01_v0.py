#!/usr/bin/env python3
"""Portable PLAY-105 West derived LOD and contact-sheet replay.

The raw West master is an immutable RGB source.  This task-local replay uses
the proven East keyed-magenta predicate and the proven standard-library
premultiplied bilinear resize.  It emits only the three claimed LODs and the
three task-local contact sheets; no source-rgba.png is materialized.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import zlib


CANVAS = (1536, 1024)
LOD_SIZES = {
    "block": (1024, 683),
    "neighborhood": (512, 342),
    "city": (256, 171),
}
CHECKER = ((42, 48, 54), (64, 70, 76))
CONTACT_GAP = 24
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    distances = (
        abs(estimate - left),
        abs(estimate - above),
        abs(estimate - upper_left),
    )
    return (left, above, upper_left)[distances.index(min(distances))]


def decode_png(path: Path) -> tuple[int, int, int, bytes]:
    payload = path.read_bytes()
    if not payload.startswith(PNG_SIGNATURE):
        raise ValueError(f"not a PNG: {path}")
    offset = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = interlace = None
    idat = bytearray()
    while offset < len(payload):
        if offset + 12 > len(payload):
            raise ValueError(f"truncated PNG chunk: {path}")
        length = struct.unpack(">I", payload[offset:offset + 4])[0]
        kind = payload[offset + 4:offset + 8]
        body_start = offset + 8
        body_end = body_start + length
        if body_end + 4 > len(payload):
            raise ValueError(f"truncated PNG payload: {path}")
        body = payload[body_start:body_end]
        offset = body_end + 4
        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", body
            )
            if bit_depth != 8 or compression != 0 or filtering != 0 or interlace != 0:
                raise ValueError(f"unsupported PNG structure: {path}")
        elif kind == b"IDAT":
            idat.extend(body)
        elif kind == b"IEND":
            break
    if width is None or height is None or bit_depth != 8 or interlace != 0:
        raise ValueError(f"missing or unsupported PNG header: {path}")
    if color_type == 2:
        channels = 3
    elif color_type == 6:
        channels = 4
    else:
        raise ValueError(f"unsupported PNG color type {color_type}: {path}")
    scanlines = zlib.decompress(bytes(idat))
    row_bytes = width * channels
    if len(scanlines) != height * (row_bytes + 1):
        raise ValueError(f"PNG scanline length mismatch: {path}")
    decoded = bytearray(height * row_bytes)
    cursor = 0
    for row_index in range(height):
        filter_type = scanlines[cursor]
        cursor += 1
        filtered = scanlines[cursor:cursor + row_bytes]
        cursor += row_bytes
        row = bytearray(row_bytes)
        previous_start = (row_index - 1) * row_bytes
        row_start = row_index * row_bytes
        for index, value in enumerate(filtered):
            left = row[index - channels] if index >= channels else 0
            above = decoded[previous_start + index] if row_index else 0
            upper_left = (
                decoded[previous_start + index - channels]
                if row_index and index >= channels
                else 0
            )
            if filter_type == 0:
                restored = value
            elif filter_type == 1:
                restored = value + left
            elif filter_type == 2:
                restored = value + above
            elif filter_type == 3:
                restored = value + ((left + above) // 2)
            elif filter_type == 4:
                restored = value + _paeth(left, above, upper_left)
            else:
                raise ValueError(f"unsupported PNG filter {filter_type}: {path}")
            row[index] = restored & 255
        decoded[row_start:row_start + row_bytes] = row
    return width, height, channels, bytes(decoded)


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def encode_rgba_png(size: tuple[int, int], rgba: bytes) -> bytes:
    width, height = size
    if len(rgba) != width * height * 4:
        raise ValueError("RGBA byte length does not match dimensions")
    stride = width * 4
    scanlines = b"".join(
        b"\x00" + rgba[row * stride:(row + 1) * stride]
        for row in range(height)
    )
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        PNG_SIGNATURE
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(scanlines, level=9))
        + _chunk(b"IEND", b"")
    )


def is_keyed_magenta(red: int, green: int, blue: int, alpha: int = 255) -> bool:
    # Exact PLAY-104 portable-replay predicate.
    return (
        alpha > 0
        and red >= 180
        and blue >= 150
        and green <= 110
        and red + blue >= 4 * green
    )


def keyed_rgba(width: int, height: int, channels: int, source: bytes) -> bytes:
    if (width, height) != CANVAS or channels != 3:
        raise ValueError(f"raw source must be RGB {CANVAS}, got {(width, height, channels)}")
    output = bytearray(width * height * 4)
    for source_offset in range(0, len(source), 3):
        red, green, blue = source[source_offset:source_offset + 3]
        target_offset = (source_offset // 3) * 4
        if is_keyed_magenta(red, green, blue):
            output[target_offset:target_offset + 4] = b"\x00\x00\x00\x00"
        else:
            output[target_offset:target_offset + 4] = bytes((red, green, blue, 255))
    return bytes(output)


def premultiplied_bilinear_resize(
    source_size: tuple[int, int],
    source: bytes,
    target_size: tuple[int, int],
) -> bytes:
    """PLAY-081 proven deterministic premultiplied standard-library resize."""
    source_width, source_height = source_size
    target_width, target_height = target_size
    output = bytearray(target_width * target_height * 4)
    for target_y in range(target_height):
        source_y = ((2 * target_y + 1) * source_height - target_height) / (
            2 * target_height
        )
        y0 = max(0, min(source_height - 1, math.floor(source_y)))
        y1 = min(source_height - 1, y0 + 1)
        fy = source_y - y0
        for target_x in range(target_width):
            source_x = ((2 * target_x + 1) * source_width - target_width) / (
                2 * target_width
            )
            x0 = max(0, min(source_width - 1, math.floor(source_x)))
            x1 = min(source_width - 1, x0 + 1)
            fx = source_x - x0
            weights = (
                ((1 - fx) * (1 - fy), x0, y0),
                (fx * (1 - fy), x1, y0),
                ((1 - fx) * fy, x0, y1),
                (fx * fy, x1, y1),
            )
            alpha_value = sum(
                source[(y * source_width + x) * 4 + 3] * weight
                for weight, x, y in weights
            )
            alpha = max(0, min(255, round(alpha_value)))
            output_offset = (target_y * target_width + target_x) * 4
            output[output_offset + 3] = alpha
            if alpha == 0:
                output[output_offset:output_offset + 3] = b"\x00\x00\x00"
                continue
            for channel in range(3):
                premultiplied = sum(
                    source[(y * source_width + x) * 4 + channel]
                    * source[(y * source_width + x) * 4 + 3]
                    * weight
                    for weight, x, y in weights
                )
                output[output_offset + channel] = max(
                    0,
                    min(255, round(premultiplied / alpha_value)),
                )
    return bytes(output)


def composite_checker(
    size: tuple[int, int], rgba: bytes, grayscale: bool = False
) -> bytes:
    width, height = size
    output = bytearray(width * height * 4)
    for index in range(width * height):
        offset = index * 4
        red, green, blue, alpha = rgba[offset:offset + 4]
        if grayscale:
            value = (54 * red + 183 * green + 19 * blue + 128) // 256
            red = green = blue = value
        x = index % width
        y = index // width
        background = CHECKER[(x // 32 + y // 32) % 2]
        inverse_alpha = 255 - alpha
        output[offset:offset + 4] = bytes(
            (
                (red * alpha + background[0] * inverse_alpha + 127) // 255,
                (green * alpha + background[1] * inverse_alpha + 127) // 255,
                (blue * alpha + background[2] * inverse_alpha + 127) // 255,
                255,
            )
        )
    return bytes(output)


def write(path: Path, size: tuple[int, int], rgba: bytes) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = encode_rgba_png(size, rgba)
    path.write_bytes(data)
    return hashlib.sha256(data).hexdigest()


def build_contact_sheets(
    source: bytes,
    lods: dict[str, tuple[tuple[int, int], bytes]],
    output_root: Path,
) -> dict[str, str]:
    sheets: dict[str, tuple[tuple[int, int], bytes]] = {
        "west-source-size-contact-sheet.png": (
            CANVAS,
            composite_checker(CANVAS, source),
        )
    }
    total_height = sum(size[1] for size, _pixels in lods.values()) + CONTACT_GAP * (len(lods) - 1)
    sheet_size = (LOD_SIZES["block"][0], total_height)
    for grayscale, name in (
        (False, "west-literal-game-scale-color-contact-sheet.png"),
        (True, "west-literal-game-scale-grayscale-contact-sheet.png"),
    ):
        sheet = bytearray(sheet_size[0] * sheet_size[1] * 4)
        for index in range(sheet_size[0] * sheet_size[1]):
            x = index % sheet_size[0]
            y = index // sheet_size[0]
            color = CHECKER[(x // 32 + y // 32) % 2]
            offset = index * 4
            sheet[offset:offset + 4] = bytes((*color, 255))
        y_offset = 0
        for lod_name, (size, pixels) in lods.items():
            tile = composite_checker(size, pixels, grayscale)
            x_offset = (sheet_size[0] - size[0]) // 2
            for row in range(size[1]):
                source_offset = row * size[0] * 4
                target_offset = ((y_offset + row) * sheet_size[0] + x_offset) * 4
                sheet[target_offset:target_offset + size[0] * 4] = tile[
                    source_offset:source_offset + size[0] * 4
                ]
            y_offset += size[1] + CONTACT_GAP
        sheets[name] = (sheet_size, bytes(sheet))
    return {
        name: write(output_root / name, size, pixels)
        for name, (size, pixels) in sheets.items()
    }


def build(source_path: Path, lod_root: Path, contact_root: Path) -> dict[str, object]:
    width, height, channels, raw = decode_png(source_path)
    normalized = keyed_rgba(width, height, channels, raw)
    lods: dict[str, tuple[tuple[int, int], bytes]] = {}
    hashes: dict[str, str] = {}
    for name, size in LOD_SIZES.items():
        pixels = premultiplied_bilinear_resize(CANVAS, normalized, size)
        lods[name] = (size, pixels)
        hashes[name] = write(lod_root / f"{name}.png", size, pixels)
    sheet_hashes = build_contact_sheets(normalized, lods, contact_root)
    return {
        "sourceSha256": sha256(source_path),
        "sourceCanvas": list(CANVAS),
        "normalization": {
            "keyPredicate": "PLAY-104 keyed-magenta strict predicate",
            "resampling": "PLAY-081 deterministic-premultiplied-bilinear-standard-library",
            "transparentRgb": "zeroed",
        },
        "lods": hashes,
        "contactSheets": sheet_hashes,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--lod-root", required=True, type=Path)
    parser.add_argument("--contact-root", required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(build(args.source.resolve(), args.lod_root.resolve(), args.contact_root.resolve()), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
