#!/usr/bin/env python3
"""Build the deterministic visual-repair v02 LOD and contact-sheet packet."""

from __future__ import annotations

import hashlib
import json
import math
import struct
import zlib
from pathlib import Path


FAMILY = Path(__file__).resolve().parents[1]
REPO = next(parent for parent in FAMILY.parents if (parent / ".git").exists())
OUTPUT = FAMILY / "visual-repair-v02"
CANVAS = (1536, 1024)
LOD_SIZES = {
    "block": (1024, 683),
    "neighborhood": (512, 342),
    "city": (256, 171),
}
DIRECTIONS = ("south", "north", "east", "west")
GENERATED_DIRECTIONS = DIRECTIONS
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
CHECKER = ((42, 48, 54), (68, 74, 80))
REJECTED_RECEIPT = FAMILY / "BUILD-RECEIPT.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    choices = (left, above, upper_left)
    distances = tuple(abs(estimate - value) for value in choices)
    return choices[distances.index(min(distances))]


def decode_png(path: Path) -> tuple[int, int, int, bytes]:
    payload = path.read_bytes()
    if not payload.startswith(PNG_SIGNATURE):
        raise ValueError(f"not a PNG: {path}")
    offset = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = interlace = None
    idat = bytearray()
    while offset < len(payload):
        length = struct.unpack(">I", payload[offset:offset + 4])[0]
        kind = payload[offset + 4:offset + 8]
        body = payload[offset + 8:offset + 8 + length]
        offset += length + 12
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
    channels = {2: 3, 6: 4}.get(color_type)
    if width is None or height is None or channels is None:
        raise ValueError(f"unsupported PNG header: {path}")
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


def encode_png(size: tuple[int, int], channels: int, pixels: bytes) -> bytes:
    width, height = size
    if channels not in (3, 4) or len(pixels) != width * height * channels:
        raise ValueError("pixel byte length does not match dimensions")
    stride = width * channels
    scanlines = b"".join(
        b"\x00" + pixels[row * stride:(row + 1) * stride]
        for row in range(height)
    )
    header = struct.pack(">IIBBBBB", width, height, 8, 2 if channels == 3 else 6, 0, 0, 0)
    return (
        PNG_SIGNATURE
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(scanlines, level=9))
        + _chunk(b"IEND", b"")
    )


def write_png(path: Path, size: tuple[int, int], channels: int, pixels: bytes) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = encode_png(size, channels, pixels)
    path.write_bytes(payload)
    return hashlib.sha256(payload).hexdigest()


def is_keyed_magenta(red: int, green: int, blue: int) -> bool:
    return red >= 150 and blue >= 120 and green <= 125 and red + blue >= 2 * green + 150


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
            if red * 100 > green * 135 and blue * 100 > green * 125:
                spill = max(0, min(red, blue) - green)
                red = max(green, red - spill)
                blue = max(green, blue - spill)
            output[target_offset:target_offset + 4] = bytes((red, green, blue, 255))
    return bytes(output)


def boundary_residual_indices(size: tuple[int, int], pixels: bytes) -> list[int]:
    width, height = size
    residuals: list[int] = []
    for y in range(height):
        for x in range(width):
            index = y * width + x
            offset = index * 4
            red, green, blue, alpha = pixels[offset:offset + 4]
            if not 1 <= alpha <= 254 or max(red, blue) < 64 or red + blue - 2 * green < 64:
                continue
            neighbors = []
            if x:
                neighbors.append(index - 1)
            if x + 1 < width:
                neighbors.append(index + 1)
            if y:
                neighbors.append(index - width)
            if y + 1 < height:
                neighbors.append(index + width)
            if any(pixels[item * 4 + 3] == 0 for item in neighbors):
                residuals.append(index)
    return residuals


def cleanup_boundary_residuals(size: tuple[int, int], pixels: bytes) -> bytes:
    output = bytearray(pixels)
    for index in boundary_residual_indices(size, pixels):
        offset = index * 4
        red, green, blue = output[offset:offset + 3]
        output[offset] = min(red, green + 31)
        output[offset + 2] = min(blue, green + 31)
    return bytes(output)


def resize_rgba(
    source_size: tuple[int, int], source: bytes, target_size: tuple[int, int]
) -> bytes:
    source_width, source_height = source_size
    target_width, target_height = target_size
    output = bytearray(target_width * target_height * 4)
    for target_y in range(target_height):
        source_y = ((2 * target_y + 1) * source_height - target_height) / (2 * target_height)
        y0 = max(0, min(source_height - 1, math.floor(source_y)))
        y1 = min(source_height - 1, y0 + 1)
        fy = max(0.0, min(1.0, source_y - y0))
        for target_x in range(target_width):
            source_x = ((2 * target_x + 1) * source_width - target_width) / (2 * target_width)
            x0 = max(0, min(source_width - 1, math.floor(source_x)))
            x1 = min(source_width - 1, x0 + 1)
            fx = max(0.0, min(1.0, source_x - x0))
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
            offset = (target_y * target_width + target_x) * 4
            if alpha == 0:
                output[offset:offset + 4] = b"\x00\x00\x00\x00"
                continue
            for channel in range(3):
                premultiplied = sum(
                    source[(y * source_width + x) * 4 + channel]
                    * source[(y * source_width + x) * 4 + 3]
                    * weight
                    for weight, x, y in weights
                )
                output[offset + channel] = max(0, min(255, round(premultiplied / alpha_value)))
            output[offset + 3] = alpha
    for x in range(target_width):
        for y in (0, target_height - 1):
            offset = (y * target_width + x) * 4
            output[offset:offset + 4] = b"\x00\x00\x00\x00"
    for y in range(target_height):
        for x in (0, target_width - 1):
            offset = (y * target_width + x) * 4
            output[offset:offset + 4] = b"\x00\x00\x00\x00"
    for offset in range(0, len(output), 4):
        if output[offset + 3] == 0 or is_keyed_magenta(*output[offset:offset + 3]):
            output[offset:offset + 4] = b"\x00\x00\x00\x00"
    return cleanup_boundary_residuals(target_size, bytes(output))


def rgba_metrics(size: tuple[int, int], pixels: bytes) -> dict[str, int]:
    width, height = size
    visible = rgb = hidden = keyed = 0
    frame_edge = 0
    for index in range(width * height):
        offset = index * 4
        red, green, blue, alpha = pixels[offset:offset + 4]
        if alpha:
            visible += 1
            if red or green or blue:
                rgb += 1
            if is_keyed_magenta(red, green, blue):
                keyed += 1
            x = index % width
            y = index // width
            if x in (0, width - 1) or y in (0, height - 1):
                frame_edge += 1
        elif red or green or blue:
            hidden += 1
    return {
        "visiblePixels": visible,
        "nonzeroRgbPixels": rgb,
        "hiddenRgbPixels": hidden,
        "keyedMagentaPixels": keyed,
        "boundaryResidualChromaPixels": len(boundary_residual_indices(size, pixels)),
        "frameEdgeOpaquePixels": frame_edge,
    }


def composite_checker(size: tuple[int, int], rgba: bytes, grayscale: bool = False) -> bytes:
    width, height = size
    output = bytearray(width * height * 3)
    for index in range(width * height):
        offset = index * 4
        red, green, blue, alpha = rgba[offset:offset + 4]
        if grayscale:
            value = (54 * red + 183 * green + 19 * blue + 128) // 256
            red = green = blue = value
        x = index % width
        y = index // width
        background = CHECKER[(x // 32 + y // 32) % 2]
        inverse = 255 - alpha
        target = index * 3
        output[target:target + 3] = bytes(
            (
                (red * alpha + background[0] * inverse + 127) // 255,
                (green * alpha + background[1] * inverse + 127) // 255,
                (blue * alpha + background[2] * inverse + 127) // 255,
            )
        )
    return bytes(output)


def checker_canvas(size: tuple[int, int]) -> bytearray:
    width, height = size
    output = bytearray(width * height * 3)
    for index in range(width * height):
        x = index % width
        y = index // width
        color = CHECKER[(x // 32 + y // 32) % 2]
        output[index * 3:index * 3 + 3] = bytes(color)
    return output


def paste_rgb(
    canvas: bytearray,
    canvas_size: tuple[int, int],
    tile: bytes,
    tile_size: tuple[int, int],
    origin: tuple[int, int],
) -> None:
    canvas_width, _ = canvas_size
    tile_width, tile_height = tile_size
    origin_x, origin_y = origin
    for row in range(tile_height):
        source_start = row * tile_width * 3
        target_start = ((origin_y + row) * canvas_width + origin_x) * 3
        canvas[target_start:target_start + tile_width * 3] = tile[
            source_start:source_start + tile_width * 3
        ]


def raw_path(direction: str) -> Path:
    return FAMILY / f"raw-revisions/{direction}-source-v02.png"


def lod_path(root: Path, direction: str, lod: str) -> Path:
    return root / f"lod/{direction}/{lod}.png"


def build_outputs(output_root: Path) -> dict[str, object]:
    output_root.mkdir(parents=True, exist_ok=True)
    keyed_sources: dict[str, bytes] = {}
    lod_records: dict[str, dict[str, object]] = {direction: {} for direction in DIRECTIONS}
    generated_paths: list[Path] = []
    for direction in DIRECTIONS:
        width, height, channels, source = decode_png(raw_path(direction))
        keyed_sources[direction] = keyed_rgba(width, height, channels, source)
    for direction in GENERATED_DIRECTIONS:
        for lod, size in LOD_SIZES.items():
            pixels = resize_rgba(CANVAS, keyed_sources[direction], size)
            destination = lod_path(output_root, direction, lod)
            digest = write_png(destination, size, 4, pixels)
            metrics = rgba_metrics(size, pixels)
            lod_records[direction][lod] = {
                "path": destination.relative_to(output_root).as_posix(),
                "sha256": digest,
                "dimensions": list(size),
                "mode": "RGBA",
                **metrics,
            }
            generated_paths.append(destination)
    source_sheet_size = (1536, 1024)
    source_sheet = checker_canvas(source_sheet_size)
    for index, direction in enumerate(DIRECTIONS):
        tile_size = (768, 512)
        tile = resize_rgba(CANVAS, keyed_sources[direction], tile_size)
        paste_rgb(
            source_sheet,
            source_sheet_size,
            composite_checker(tile_size, tile),
            tile_size,
            ((index % 2) * 768, (index // 2) * 512),
        )
    source_sheet_path = output_root / "contact-sheets/family-source-four-view.png"
    write_png(source_sheet_path, source_sheet_size, 3, bytes(source_sheet))
    generated_paths.append(source_sheet_path)

    gap = 24
    column_width = LOD_SIZES["block"][0]
    lod_sheet_size = (
        len(DIRECTIONS) * column_width + (len(DIRECTIONS) - 1) * gap,
        sum(size[1] for size in LOD_SIZES.values()) + (len(LOD_SIZES) - 1) * gap,
    )
    for grayscale, name in (
        (False, "family-literal-lod-color.png"),
        (True, "family-literal-lod-grayscale.png"),
    ):
        canvas = checker_canvas(lod_sheet_size)
        y = 0
        for lod, size in LOD_SIZES.items():
            for column, direction in enumerate(DIRECTIONS):
                path = lod_path(output_root, direction, lod)
                width, height, channels, pixels = decode_png(path)
                if (width, height, channels) != (*size, 4):
                    raise ValueError(f"{direction} {lod} decode mismatch")
                tile = composite_checker(size, pixels, grayscale)
                x = column * (column_width + gap) + (column_width - size[0]) // 2
                paste_rgb(canvas, lod_sheet_size, tile, size, (x, y))
            y += size[1] + gap
        sheet_path = output_root / f"contact-sheets/{name}"
        write_png(sheet_path, lod_sheet_size, 3, bytes(canvas))
        generated_paths.append(sheet_path)

    old_sheet_path = FAMILY / "contact-sheets/family-literal-lod-color.png"
    old_width, old_height, old_channels, old_pixels = decode_png(old_sheet_path)
    new_sheet_path = output_root / "contact-sheets/family-literal-lod-color.png"
    new_width, new_height, new_channels, new_pixels = decode_png(new_sheet_path)
    if (old_width, old_height, old_channels) != (*lod_sheet_size, 3):
        raise ValueError("rejected-family contact sheet shape mismatch")
    if (new_width, new_height, new_channels) != (*lod_sheet_size, 3):
        raise ValueError("replacement-family contact sheet shape mismatch")
    comparison_gap = 24
    comparison_size = (lod_sheet_size[0], lod_sheet_size[1] * 2 + comparison_gap)
    comparison = checker_canvas(comparison_size)
    paste_rgb(comparison, comparison_size, old_pixels, lod_sheet_size, (0, 0))
    paste_rgb(
        comparison,
        comparison_size,
        new_pixels,
        lod_sheet_size,
        (0, lod_sheet_size[1] + comparison_gap),
    )
    comparison_path = output_root / "contact-sheets/old-vs-new-gameplay-scale-color.png"
    write_png(comparison_path, comparison_size, 3, bytes(comparison))
    generated_paths.append(comparison_path)

    return {
        "schema": "citysim.play-097.residential-l01-v2.visual-repair-v02.build.v1",
        "family": "residential_l01_v2",
        "directions": list(DIRECTIONS),
        "lods": lod_records,
        "rawSources": {
            direction: {
                "path": raw_path(direction).relative_to(REPO).as_posix(),
                "sha256": sha256(raw_path(direction)),
                "dimensions": list(CANVAS),
                "mode": "RGB",
            }
            for direction in DIRECTIONS
        },
        "generatedFiles": sorted(path.relative_to(output_root).as_posix() for path in generated_paths),
        "derivation": "dependency-free CONTRACT-028 alpha-aware despill plus premultiplied bilinear",
        "rejectedFamilyReceipt": {
            "path": REJECTED_RECEIPT.relative_to(REPO).as_posix(),
            "sha256": sha256(REJECTED_RECEIPT),
            "disposition": "preserved visual-return predecessor; no bytes reused by v02",
        },
    }


def main() -> int:
    record = build_outputs(OUTPUT)
    receipt = OUTPUT / "BUILD-RECEIPT.json"
    receipt.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"result": "PASS", "receipt": str(receipt), "generated": len(record["generatedFiles"])}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
