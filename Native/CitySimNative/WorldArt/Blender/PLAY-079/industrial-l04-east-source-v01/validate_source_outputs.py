#!/usr/bin/env python3
"""Direction-local validators for future post-lock PLAY-079 East pixels.

Pre-lock use is limited to ``--mode prelock``, which reads no pixel file and
reports every pixel gate as not_run. ``--mode pixels`` is intentionally
unreachable until all deterministic A/B/C outputs exist.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import struct
import sys
import zlib
from collections import Counter
from typing import Any


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
CONTRACT_PATH = SOURCE_ROOT / "RUNNER-CONTRACT.json"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def load_json(path: pathlib.Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected JSON object")
    return value


def paeth(left: int, up: int, upper_left: int) -> int:
    estimate = left + up - upper_left
    left_distance = abs(estimate - left)
    up_distance = abs(estimate - up)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= up_distance and left_distance <= upper_left_distance:
        return left
    if up_distance <= upper_left_distance:
        return up
    return upper_left


def decode_rgba_png(path: pathlib.Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path}: invalid PNG signature")
    offset = len(PNG_SIGNATURE)
    width = height = 0
    compressed = bytearray()
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        expected_crc = struct.unpack(">I", data[offset + 8 + length : offset + 12 + length])[0]
        if zlib.crc32(kind + payload) & 0xFFFFFFFF != expected_crc:
            raise ValueError(f"{path}: invalid {kind!r} CRC")
        offset += 12 + length
        if kind == b"IHDR":
            width, height, depth, color_type, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if (depth, color_type, compression, filtering, interlace) != (8, 6, 0, 0, 0):
                raise ValueError(f"{path}: expected non-interlaced 8-bit RGBA PNG")
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
    if width <= 0 or height <= 0:
        raise ValueError(f"{path}: missing IHDR")
    raw = zlib.decompress(bytes(compressed))
    stride = width * 4
    expected_length = height * (stride + 1)
    if len(raw) != expected_length:
        raise ValueError(f"{path}: decoded scanline length mismatch")
    decoded = bytearray(width * height * 4)
    prior = bytearray(stride)
    raw_offset = 0
    for row_index in range(height):
        filter_type = raw[raw_offset]
        scanline = bytearray(raw[raw_offset + 1 : raw_offset + 1 + stride])
        raw_offset += stride + 1
        for index in range(stride):
            left = scanline[index - 4] if index >= 4 else 0
            up = prior[index]
            upper_left = prior[index - 4] if index >= 4 else 0
            if filter_type == 1:
                scanline[index] = (scanline[index] + left) & 0xFF
            elif filter_type == 2:
                scanline[index] = (scanline[index] + up) & 0xFF
            elif filter_type == 3:
                scanline[index] = (scanline[index] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                scanline[index] = (scanline[index] + paeth(left, up, upper_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"{path}: unsupported PNG filter {filter_type}")
        start = row_index * stride
        decoded[start : start + stride] = scanline
        prior = scanline
    return width, height, bytes(decoded)


def pixels(rgba: bytes) -> list[tuple[int, int, int, int]]:
    return [tuple(rgba[index : index + 4]) for index in range(0, len(rgba), 4)]


def validate_alpha_chroma_hidden_rgb(rgba: bytes) -> dict[str, int]:
    decoded = pixels(rgba)
    hidden_rgb_channels = sum(
        sum(channel != 0 for channel in pixel[:3]) for pixel in decoded if pixel[3] == 0
    )
    visible_chroma = sum(pixel[:3] == (255, 0, 255) and pixel[3] > 0 for pixel in decoded)
    if hidden_rgb_channels or visible_chroma:
        raise ValueError(
            f"alpha/chroma failure hidden={hidden_rgb_channels} chroma={visible_chroma}"
        )
    return {
        "hiddenRgbNonzeroChannels": hidden_rgb_channels,
        "visibleChromaPixels": visible_chroma,
    }


def occupied_bounds(width: int, height: int, rgba: bytes) -> dict[str, Any]:
    occupied = [
        (index % width, index // width)
        for index, pixel in enumerate(pixels(rgba))
        if pixel[3] > 0
    ]
    if not occupied:
        raise ValueError("source has no occupied pixels")
    min_x = min(point[0] for point in occupied)
    max_x = max(point[0] for point in occupied)
    min_y = min(point[1] for point in occupied)
    max_y = max(point[1] for point in occupied)
    padding = {
        "left": min_x,
        "top": min_y,
        "right": width - 1 - max_x,
        "bottom": height - 1 - max_y,
    }
    if min(padding.values()) < 4:
        raise ValueError(f"source padding below four pixels: {padding}")
    return {
        "bounds": [min_x, min_y, max_x, max_y],
        "size": [max_x - min_x + 1, max_y - min_y + 1],
        "padding": padding,
        "occupiedPixelCount": len(occupied),
    }


def downsample_semantic(
    width: int,
    height: int,
    rgba: bytes,
    target_width: int,
    target_height: int,
) -> list[tuple[int, int, int, int]]:
    if width % target_width or height % target_height:
        raise ValueError("literal-192 scale must divide source dimensions exactly")
    scale_x = width // target_width
    scale_y = height // target_height
    source = pixels(rgba)
    result: list[tuple[int, int, int, int]] = []
    for target_y in range(target_height):
        for target_x in range(target_width):
            block = Counter(
                source[(target_y * scale_y + y) * width + target_x * scale_x + x]
                for y in range(scale_y)
                for x in range(scale_x)
            )
            result.append(block.most_common(1)[0][0])
    return result


def literal192_proof(
    width: int,
    height: int,
    semantic_rgba: bytes,
    contract: dict[str, Any],
) -> dict[str, Any]:
    target_width, target_height = contract["invariants"]["camera"]["literalResolution"]
    compact = downsample_semantic(width, height, semantic_rgba, target_width, target_height)
    portal_rgb = (16, 16, 16)
    portal = [
        (index % target_width, index // target_width)
        for index, pixel in enumerate(compact)
        if pixel[:3] == portal_rgb and pixel[3] > 0
    ]
    if not portal:
        raise ValueError("literal-192 portal void is absent")
    portal_bounds = [
        min(point[0] for point in portal),
        min(point[1] for point in portal),
        max(point[0] for point in portal),
        max(point[1] for point in portal),
    ]
    portal_size = [
        portal_bounds[2] - portal_bounds[0] + 1,
        portal_bounds[3] - portal_bounds[1] + 1,
    ]
    minimum = contract["invariants"]["pixelValidation"]["literal192PortalInsetMinimum"]
    if portal_size[0] < minimum[0] or portal_size[1] < minimum[1]:
        raise ValueError(f"literal-192 portal below minimum: {portal_size}")

    skyline: list[int | None] = []
    for x in range(target_width):
        ys = [
            y
            for y in range(target_height)
            if compact[y * target_width + x][3] > 0
        ]
        skyline.append(min(ys) if ys else None)
    breaks = 0
    previous: int | None = None
    for current in skyline:
        if current is not None and previous is not None and abs(current - previous) >= 1:
            breaks += 1
        if current is not None:
            previous = current
    minimum_breaks = contract["invariants"]["pixelValidation"][
        "literal192SilhouetteBreaksMinimum"
    ]
    if breaks < minimum_breaks:
        raise ValueError(f"literal-192 silhouette breaks below minimum: {breaks}")
    return {
        "resolution": [target_width, target_height],
        "portalBounds": portal_bounds,
        "portalSize": portal_size,
        "silhouetteBreakCount": breaks,
    }


def validate_provenance(
    contract: dict[str, Any],
    process_id: str,
    path: pathlib.Path,
) -> dict[str, Any]:
    value = load_json(path)
    bridge = contract["invariants"]["coordinateBridge"]["v06"]
    expected = {
        "taskId": "PLAY-079",
        "direction": "east",
        "processId": process_id,
        "sceneSha256": bridge["projectionAdapterSha256"],
        "contractSha256": sha256_bytes(CONTRACT_PATH.read_bytes()),
        "factoryStartup": True,
        "autoexecDisabled": True,
        "renderApiCalls": 2,
    }
    for key, expected_value in expected.items():
        if value.get(key) != expected_value:
            raise ValueError(f"{path}: provenance {key} mismatch")
    return value


def resolve_output_paths(contract: dict[str, Any], process_id: str) -> dict[str, pathlib.Path]:
    root = REPOSITORY_ROOT / contract["outputInventory"]["root"]
    return {
        key: root / relative
        for key, relative in contract["outputInventory"]["processes"][process_id].items()
    }


def pixel_validation(forbidden_hashes: set[str]) -> dict[str, Any]:
    contract = load_json(CONTRACT_PATH)
    coordinate_bridge = contract["invariants"]["coordinateBridge"]
    if coordinate_bridge["state"] != "validated_v06":
        raise ValueError("pixel validation blocked pending v06 coordinate-bridge revalidation")
    bridge = coordinate_bridge["v06"]
    if any(
        bridge.get(key) is None
        for key in (
            "projectionAdapterSha256",
            "blenderNativeDirectionalSocket",
            "blenderNativeGroundPivot",
            "blenderNativeFootprintCorners",
            "blenderContactCornerOrder",
        )
    ):
        raise ValueError("pixel validation blocked by incomplete v06 coordinate bridge")
    decoded: dict[str, dict[str, tuple[int, int, bytes]]] = {}
    provenance: dict[str, dict[str, Any]] = {}
    for process_id in ("A", "B", "C"):
        paths = resolve_output_paths(contract, process_id)
        decoded[process_id] = {
            "raw": decode_rgba_png(paths["raw"]),
            "semantic": decode_rgba_png(paths["semantic"]),
        }
        provenance[process_id] = validate_provenance(contract, process_id, paths["provenance"])

    raw_hashes = {sha256_bytes(decoded[process_id]["raw"][2]) for process_id in ("A", "B", "C")}
    semantic_hashes = {
        sha256_bytes(decoded[process_id]["semantic"][2]) for process_id in ("A", "B", "C")
    }
    if len(raw_hashes) != 1 or len(semantic_hashes) != 1:
        raise ValueError("A/B/C decoded RGBA identity failed")
    if raw_hashes & forbidden_hashes or semantic_hashes & forbidden_hashes:
        raise ValueError("East output aliases a forbidden decoded-RGBA hash")
    if raw_hashes == semantic_hashes:
        raise ValueError("raw and semantic decoded RGBA must be distinct")

    width, height, raw_rgba = decoded["A"]["raw"]
    semantic_width, semantic_height, semantic_rgba = decoded["A"]["semantic"]
    expected_resolution = contract["invariants"]["camera"]["resolution"]
    if [width, height] != expected_resolution or [semantic_width, semantic_height] != expected_resolution:
        raise ValueError("source output resolution mismatch")

    alpha = validate_alpha_chroma_hidden_rgb(raw_rgba)
    bounds = occupied_bounds(width, height, raw_rgba)
    compact = literal192_proof(width, height, semantic_rgba, contract)
    registration = {
        "canonicalCitySimEastSocket": coordinate_bridge["canonicalCitySimEastSocket"],
        "sourcePixelEastSocket": coordinate_bridge["sourcePixelEastSocket"],
        "blenderNativeDirectionalSocket": bridge["blenderNativeDirectionalSocket"],
        "blenderNativeGroundPivot": bridge["blenderNativeGroundPivot"],
        "blenderNativeFootprintCorners": bridge["blenderNativeFootprintCorners"],
        "blenderContactCornerOrder": bridge["blenderContactCornerOrder"],
        "tolerance": contract["invariants"]["registration"]["sourcePixelTolerance"],
        "projectionAdapterSha256": bridge["projectionAdapterSha256"],
        "result": "PASS",
    }
    return {
        "schema": "citysim.world-art.direction-output-validation.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "result": "PASS",
        "freshProcessProvenance": {
            "result": "PASS",
            "processIds": sorted(provenance),
            "blenderBuildHashes": sorted(
                {value["blenderBuildHash"] for value in provenance.values()}
            ),
        },
        "decodedRgbaIdentity": {
            "result": "PASS",
            "rawSha256": next(iter(raw_hashes)),
            "semanticSha256": next(iter(semantic_hashes)),
        },
        "alphaChromaHiddenRgb": alpha,
        "occupiedBounds": bounds,
        "registration": registration,
        "literal192": compact,
        "nonAliasing": {
            "result": "PASS",
            "forbiddenHashCount": len(forbidden_hashes),
        },
        "abcEquality": "PASS",
        "normalization": "not_run",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("prelock", "pixels"), required=True)
    parser.add_argument("--forbidden-decoded-rgba-sha256", action="append", default=[])
    args = parser.parse_args()
    if args.mode == "prelock":
        result = {
            "schema": "citysim.world-art.direction-output-validation.v1",
            "taskId": "PLAY-079",
            "direction": "east",
            "result": "PASS",
            "pixelFilesRead": 0,
            "freshProcessProvenance": "not_run",
            "decodedRgbaIdentity": "not_run",
            "alphaChromaHiddenRgb": "not_run",
            "occupiedBounds": "not_run",
            "registration": "not_run",
            "literal192": "not_run",
            "nonAliasing": "not_run",
            "abcEquality": "not_run",
            "normalization": "not_run",
        }
    else:
        result = pixel_validation(set(args.forbidden_decoded_rgba_sha256))
    sys.stdout.buffer.write(canonical_bytes(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
