#!/usr/bin/env python3
"""Focused, dependency-free PLAY-105 West source-candidate validator."""

from __future__ import annotations

import hashlib
import json
import struct
import subprocess
import zlib
from pathlib import Path


REPO = next(parent for parent in Path(__file__).resolve().parents if (parent / ".git").exists())
WEST = REPO / "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-105/west"
EVIDENCE = REPO / "docs/production/evidence/PLAY-105/industrial-l01-v0"
RAW = WEST / "raw/industrial_l01_v0/west-source-v01.png"
RAW_SHA = "376874c84307060b2f9b58337c8d7be40038fe5b8c8b7454334158687530d71b"
ROUTE_RAW_SHA = "5d5752a6e42a3cba297aea3b51dcfd9294c96914b7c3f40185eee96ec5c396b7"
ROUTE_CANONICAL_SHA = "1dc897a9d3e717693f77d4d57b60a46dbf1137221185d8299f641fcf7a8cfb23"
DISPATCH_RAW_SHA = "49ad2ac5f7690a490469a05d7f8c9f632cc63e6b3907e2ad23a187f143fd094d"
DISPATCH_CANONICAL_SHA = "e9e989a5b322d1a8235cc018d256788d16102518d68f80992f02f4a68288718f"
ROUTE_ID = "west-v2:play-105-currentd3be-industrial-l01-v0-recent-image-v1"
EXPECTED_HEAD = "d3bed770eb3bf79194df7b15737a19bddafdcd42"
LODS = {
    "block.png": ((1024, 683), "285be1bc558691afed536e4b71885547e2deaa910d4d5a2707cf988cce871a7b"),
    "neighborhood.png": ((512, 342), "6269f03695e6d7f30e1c320c388045109d7579b42f00501207238cf82cc342b8"),
    "city.png": ((256, 171), "a3f747241ae260908bc1fbacafd763e7c5745c6d152896cdf44bc816cedfde42"),
}
SHEETS = {
    "west-source-size-contact-sheet.png": ((1536, 1024), "75a9a74966e8c9753257db781c541f2b4f4bfbc372a4a70cf04d7870f8255541"),
    "west-literal-game-scale-color-contact-sheet.png": ((1024, 1244), "fe3fd8609c293dc4c1f81cd65d61e6abdfab7dbfa41a3e1d3b39e74a4eade524"),
    "west-literal-game-scale-grayscale-contact-sheet.png": ((1024, 1244), "77f40be713f2748edfeef5264e3205204402044b0f4ea837d3535a3361b05ec2"),
}
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_sha(path: Path) -> str:
    value = json.loads(path.read_text())
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def decode_png(path: Path) -> tuple[int, int, int, list[tuple[int, ...]]]:
    payload = path.read_bytes()
    if not payload.startswith(PNG_SIGNATURE):
        raise ValueError("invalid PNG signature")
    offset = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = interlace = None
    idat = bytearray()
    while offset < len(payload):
        length = struct.unpack(">I", payload[offset:offset + 4])[0]
        kind = payload[offset + 4:offset + 8]
        body = payload[offset + 8:offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", body)
            if compression != 0 or filtering != 0:
                raise ValueError("unsupported PNG compression")
        elif kind == b"IDAT":
            idat.extend(body)
        elif kind == b"IEND":
            break
    if width is None or height is None or bit_depth != 8 or interlace != 0 or color_type not in (2, 6):
        raise ValueError("unsupported PNG format")
    channels = 3 if color_type == 2 else 4
    scanlines = zlib.decompress(bytes(idat))
    row_bytes = width * channels
    rows: list[bytes] = []
    cursor = 0
    for row_index in range(height):
        filter_type = scanlines[cursor]
        cursor += 1
        filtered = scanlines[cursor:cursor + row_bytes]
        cursor += row_bytes
        previous = rows[row_index - 1] if row_index else bytes(row_bytes)
        row = bytearray(row_bytes)
        for index, value in enumerate(filtered):
            left = row[index - channels] if index >= channels else 0
            above = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                restored = value
            elif filter_type == 1:
                restored = value + left
            elif filter_type == 2:
                restored = value + above
            elif filter_type == 3:
                restored = value + ((left + above) // 2)
            elif filter_type == 4:
                estimate = left + above - upper_left
                distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
                predictor = (left, above, upper_left)[distances.index(min(distances))]
                restored = value + predictor
            else:
                raise ValueError(f"unsupported PNG filter: {filter_type}")
            row[index] = restored & 255
        rows.append(bytes(row))
    pixels = []
    for row in rows:
        pixels.extend(tuple(row[index:index + channels]) for index in range(0, row_bytes, channels))
    return width, height, channels, pixels


def check_rgba(path: Path, size: tuple[int, int], errors: list[str]) -> dict[str, int | list[int]]:
    try:
        width, height, channels, pixels = decode_png(path)
    except Exception as error:
        errors.append(f"unreadable PNG {path}: {error}")
        return {}
    if (width, height) != size or channels != 4:
        errors.append(f"format mismatch {path}: {(width, height)} channels={channels}")
    hidden = sum(1 for red, green, blue, alpha in pixels if alpha == 0 and (red or green or blue))
    purple = sum(1 for red, green, blue, alpha in pixels if alpha and red >= 180 and blue >= 150 and green <= 110 and red + blue >= 4 * green)
    edge = sum(1 for x in range(width) for y in (0, height - 1) if pixels[y * width + x][3])
    edge += sum(1 for y in range(height) for x in (0, width - 1) if pixels[y * width + x][3])
    nonempty = sum(1 for pixel in pixels if pixel[3])
    if hidden:
        errors.append(f"hidden RGB in {path}: {hidden}")
    if purple:
        errors.append(f"visible chroma in {path}: {purple}")
    if edge:
        errors.append(f"frame-edge alpha in {path}: {edge}")
    if not nonempty:
        errors.append(f"empty alpha payload: {path}")
    return {"size": [width, height], "hiddenRgb": hidden, "visibleChroma": purple, "frameEdgeAlpha": edge, "nonemptyAlpha": nonempty}


def main() -> int:
    errors: list[str] = []
    stats: dict[str, object] = {}
    route = EVIDENCE / "route-snapshot/MODEL-ROUTE-PLAY-105-WEST-V2.json"
    dispatch = EVIDENCE / "route-snapshot/PLAY-105-WEST-DISPATCH-V2.json"
    if not route.is_file() or sha256(route) != ROUTE_RAW_SHA or canonical_sha(route) != ROUTE_CANONICAL_SHA:
        errors.append("route snapshot hash mismatch")
    elif json.loads(route.read_text()).get("routeId") != ROUTE_ID:
        errors.append("routeId mismatch")
    if not dispatch.is_file() or sha256(dispatch) != DISPATCH_RAW_SHA or canonical_sha(dispatch) != DISPATCH_CANONICAL_SHA:
        errors.append("dispatch snapshot hash mismatch")
    try:
        raw_width, raw_height, raw_channels, _ = decode_png(RAW)
        if sha256(RAW) != RAW_SHA or (raw_width, raw_height, raw_channels) != (1536, 1024, 3):
            errors.append("raw format or hash mismatch")
        stats["raw"] = {"size": [raw_width, raw_height], "channels": raw_channels}
    except Exception as error:
        errors.append(f"raw unreadable: {error}")
    for name, (size, expected) in LODS.items():
        path = WEST / "lod/industrial_l01_v0" / name
        if (sha256(path) if path.is_file() else None) != expected:
            errors.append(f"LOD hash mismatch: {path}")
        stats[name] = check_rgba(path, size, errors)
    for name, (size, expected) in SHEETS.items():
        path = WEST / "contact-sheets" / name
        if (sha256(path) if path.is_file() else None) != expected:
            errors.append(f"contact sheet hash mismatch: {path}")
        try:
            width, height, _, _ = decode_png(path)
            if (width, height) != size:
                errors.append(f"contact sheet dimensions mismatch: {path}")
        except Exception as error:
            errors.append(f"contact sheet unreadable {path}: {error}")
    required = (
        EVIDENCE / "validation/geometry-registration.json",
        EVIDENCE / "validation/normalization-replay-receipt.json",
        EVIDENCE / "source-candidate-receipt.json",
        WEST / "receipts/parallel-execution-receipt.json",
        WEST / "provenance/industrial_l01_v0/west-provenance-v02.json",
        WEST / "handoffs/industrial_l01_v0/west-handoff-v02.json",
    )
    for path in required:
        if not path.is_file():
            errors.append(f"missing evidence record: {path}")
    geometry = EVIDENCE / "validation/geometry-registration.json"
    if geometry.is_file():
        value = json.loads(geometry.read_text())
        if value.get("pivotPx") != [768, 896] or value.get("frontage") != "west":
            errors.append("registration binding mismatch")
    replay = EVIDENCE / "validation/normalization-replay-receipt.json"
    if replay.is_file() and json.loads(replay.read_text()).get("status") != "PASS":
        errors.append("deterministic replay receipt not PASS")
    parallel = WEST / "receipts/parallel-execution-receipt.json"
    if parallel.is_file() and json.loads(parallel.read_text()).get("siblingInputsConsumed") != []:
        errors.append("sibling input inventory is not empty")
    provenance = WEST / "provenance/industrial_l01_v0/west-provenance-v02.json"
    if provenance.is_file():
        value = json.loads(provenance.read_text())
        if value.get("transport") != "central_view_image_recent_image_bridge" or value.get("rawSha256") != RAW_SHA:
            errors.append("provenance binding mismatch")
    handoff = WEST / "handoffs/industrial_l01_v0/west-handoff-v02.json"
    if handoff.is_file():
        value = json.loads(handoff.read_text())
        expected = {"direction": "west", "identity": "industrial_l01_v0", "candidateReadyForIndependentReview": True, "sourceReady": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False}
        for key, wanted in expected.items():
            if value.get(key) != wanted:
                errors.append(f"handoff {key} mismatch")
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, text=True, capture_output=True, check=True).stdout.strip()
    if head != EXPECTED_HEAD:
        errors.append(f"unexpected pre-commit HEAD: {head}")
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1
    print(json.dumps({"status": "PASS", "task": "PLAY-105", "identity": "industrial_l01_v0", "direction": "west", "stats": stats}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
