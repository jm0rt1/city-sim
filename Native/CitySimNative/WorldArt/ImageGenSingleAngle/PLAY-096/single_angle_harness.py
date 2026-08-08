#!/usr/bin/env python3
"""Deterministic, dependency-free PLAY-096 source and handoff harness.

This module owns only the shared single-angle source-toolchain packet.  It does
not call ImageGen and it never writes to the shipping resource tree.  The
calibration replay uses the retained residential_l01 calibration master as a
frozen executable reference for the normalizer and receipt shape.
"""

from __future__ import annotations

import binascii
import hashlib
import json
import struct
import subprocess
import zlib
from collections import deque
from pathlib import Path
from typing import Iterable, Mapping, Sequence


TASK = "PLAY-096"
CONTRACT = "CONTRACT-024"
SCHEMA_VERSION = 1
CANVAS = (1536, 1024)
GROUND_PIVOT = (768, 896)
LODS: Mapping[str, tuple[int, int]] = {
    "block": (1024, 683),
    "neighborhood": (512, 342),
    "city": (256, 171),
}
CHROMA = (255, 0, 255)
CLAIM_PATH = "docs/production/claims/PLAY-096.world-art-pipeline.md"
CLAIM_SHA256 = "aabb201e183679ea6a3f9ce99e64ff08a3947e25a46ebbc06d044a6e8da9d3df"
AUTHORITY = "004bd2dbcb88e57330425a833505d81ce00e9f90"
BASE = "690c46bc9019b641c023f264c46bf8aadb506619"
BRANCH = "codex/citysim-world-art-pipeline"
ROUTE_ID = "single-angle-v1:play-096"
ROUTE_SHA256 = "250d7999fd2ee19bac1240faf019c41a13c3dd68b8eb12576d3640a999f232ba"
CALIBRATION_SOURCE = (
    "Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/"
    "residential_l01/source-v01.png"
)
CALIBRATION_SOURCE_SHA256 = "e15a388c2a1a0a55488457211c23939f70eca255cbae733ee0f7b39b141c962e"
NORMALIZER_REFERENCE = (
    "Native/CitySimNative/WorldArt/GeneratedV4/tools/normalize_calibration_asset.py"
)
NORMALIZER_REFERENCE_SHA256 = "0901077cf90151ea1bda1fbe0f21f3c4cebadc72733c762e8d7122480f2a6048"
APPEARANCE_REFERENCE = "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png"
APPEARANCE_REFERENCE_SHA256 = "b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425"
REGISTRATION_REFERENCE = "Native/CitySimNative/WorldArt/GeneratedV4/templates/registration-1x1.png"
REGISTRATION_REFERENCE_SHA256 = "6ad1db2e7b8f670718ff4a4eb8c183737b0dec859559a2eab6a25746b53cff67"


def repo_root() -> Path:
    return Path(__file__).resolve().parents[5]


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def canonical_json(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")


def inventory_entries() -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    for family in ("residential", "commercial", "industrial"):
        for level in range(1, 5):
            for variant in range(3):
                logical_id = f"{family}_l{level:02d}_v{variant}"
                entries.append(
                    {
                        "logical_id": logical_id,
                        "family": family,
                        "level": level,
                        "variant": variant,
                        "asset_kind": "building",
                        "source_status": "not_generated",
                    }
                )
    for logical_id, family, name in (
        ("park_l01", "park", "park"),
        ("power_plant_l01", "civic-service", "power plant"),
        ("water_tower_l01", "utility", "water tower"),
        ("fire_station_l01", "civic-service", "fire station"),
        ("police_station_l01", "civic-service", "police station"),
        ("school_l01", "civic-service", "school"),
        ("city_hall_l01", "civic", "city hall"),
    ):
        entries.append(
            {
                "logical_id": logical_id,
                "family": family,
                "level": 1,
                "variant": 0,
                "asset_kind": "building",
                "display_name": name,
                "source_status": "not_generated",
            }
        )
    return entries


def inventory_document() -> dict[str, object]:
    entries = inventory_entries()
    return {
        "schema": SCHEMA_VERSION,
        "task": TASK,
        "contract": CONTRACT,
        "view": "single-angle",
        "count": len(entries),
        "identity_policy": "one-authored-image-per-logical-id; no alias, mirror, or rotation",
        "entries": entries,
    }


def validate_inventory(document: Mapping[str, object]) -> list[str]:
    errors: list[str] = []
    expected = inventory_document()
    if document.get("schema") != SCHEMA_VERSION:
        errors.append("inventory schema must be 1")
    if document.get("task") != TASK or document.get("contract") != CONTRACT:
        errors.append("inventory task/contract binding mismatch")
    entries = document.get("entries")
    if not isinstance(entries, list):
        return errors + ["inventory entries must be a list"]
    if document.get("count") != len(entries) or len(entries) != 43:
        errors.append(f"inventory count must be exactly 43, got {len(entries)}")
    expected_by_id = {entry["logical_id"]: entry for entry in expected["entries"]}
    seen: set[str] = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            errors.append(f"entry {index} is not an object")
            continue
        logical_id = entry.get("logical_id")
        if not isinstance(logical_id, str) or not logical_id:
            errors.append(f"entry {index} has no logical_id")
            continue
        if logical_id in seen:
            errors.append(f"duplicate logical_id {logical_id}")
        seen.add(logical_id)
        if logical_id not in expected_by_id:
            errors.append(f"unexpected logical_id {logical_id}")
            continue
        for key in ("family", "level", "variant", "asset_kind", "source_status"):
            if entry.get(key) != expected_by_id[logical_id].get(key):
                errors.append(f"{logical_id}: {key} does not match frozen inventory")
    if seen != set(expected_by_id):
        errors.append("inventory identity set does not equal the frozen 43-ID set")
    return errors


def prompt_provenance_template(logical_id: str) -> dict[str, object]:
    return {
        "schema": SCHEMA_VERSION,
        "task": TASK,
        "logical_id": logical_id,
        "source_kind": "built-in-imagegen",
        "status": "required-before-source-candidate",
        "prompt": {
            "text": "",
            "references": [],
            "reference_hashes": [],
        },
        "tool": {"name": "OpenAI built-in ImageGen", "model": "built-in/model-not-exposed"},
        "chroma_key": "#ff00ff",
        "cleanup_command": "",
        "intended_gameplay_meaning": "",
        "reviewer": "frontier-authority",
        "disposition": "not_generated",
    }


def validate_prompt_provenance(record: Mapping[str, object]) -> list[str]:
    required = ("schema", "task", "logical_id", "source_kind", "status", "prompt", "tool", "chroma_key", "cleanup_command", "intended_gameplay_meaning", "reviewer", "disposition")
    errors = [f"provenance missing {key}" for key in required if key not in record]
    if record.get("schema") != SCHEMA_VERSION or record.get("task") != TASK:
        errors.append("provenance task/schema binding mismatch")
    if record.get("source_kind") != "built-in-imagegen":
        errors.append("provenance source_kind must be built-in-imagegen")
    if record.get("chroma_key") != "#ff00ff":
        errors.append("provenance chroma key must be #ff00ff")
    prompt = record.get("prompt")
    if not isinstance(prompt, dict) or not isinstance(prompt.get("references"), list) or not isinstance(prompt.get("reference_hashes"), list):
        errors.append("provenance prompt references must be lists")
    tool = record.get("tool")
    if not isinstance(tool, dict) or tool.get("name") != "OpenAI built-in ImageGen":
        errors.append("provenance tool must identify built-in ImageGen")
    return errors


def family_handoff_document(inventory: Mapping[str, object], receipt: Mapping[str, object]) -> dict[str, object]:
    return {
        "schema": SCHEMA_VERSION,
        "task": TASK,
        "stage": "shared-toolchain-calibration",
        "branch": BRANCH,
        "base_authority": BASE,
        "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA256},
        "family": "shared-toolchain",
        "direction": "single-angle",
        "inventory_count": inventory["count"],
        "inventory_sha256": sha256_bytes(canonical_json(inventory)),
        "calibration_receipt": receipt["receipt_path"],
        "source_production": "not_produced",
        "candidateReadyForIndependentReview": False,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "known_blockers": ["family pixels require separate family claims and frontier review"],
    }


def validate_family_handoff(document: Mapping[str, object]) -> list[str]:
    errors: list[str] = []
    if document.get("schema") != SCHEMA_VERSION or document.get("task") != TASK:
        errors.append("handoff task/schema binding mismatch")
    if document.get("stage") != "shared-toolchain-calibration":
        errors.append("handoff stage must be shared-toolchain-calibration")
    if document.get("inventory_count") != 43:
        errors.append("handoff inventory_count must be 43")
    for key in ("candidateReadyForIndependentReview", "sourceReady", "integrationAdmitted", "rendererQuarantined", "productionSelected"):
        if document.get(key) is not False:
            errors.append(f"handoff {key} must remain false")
    return errors


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else b if pb <= pc else c


def decode_png(data: bytes) -> tuple[int, int, bytearray]:
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    position = 8
    width = height = bit_depth = color_type = interlace = None
    compressed = bytearray()
    while position < len(data):
        length = struct.unpack(">I", data[position : position + 4])[0]
        kind = data[position + 4 : position + 8]
        chunk = data[position + 8 : position + 8 + length]
        position += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", chunk)
            if bit_depth != 8 or compression or filtering or interlace or color_type not in (2, 6):
                raise ValueError("only non-interlaced 8-bit RGB/RGBA PNGs are supported")
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break
    if width is None or height is None or bit_depth is None or color_type is None:
        raise ValueError("PNG is missing IHDR")
    bpp = 3 if color_type == 2 else 4
    row_bytes = width * bpp
    raw = zlib.decompress(bytes(compressed))
    expected = height * (row_bytes + 1)
    if len(raw) != expected:
        raise ValueError("PNG scanline length mismatch")
    rows: list[bytearray] = []
    offset = 0
    previous = bytearray(row_bytes)
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        row = bytearray(raw[offset : offset + row_bytes])
        offset += row_bytes
        for i in range(row_bytes):
            left = row[i - bpp] if i >= bpp else 0
            up = previous[i]
            upper_left = previous[i - bpp] if i >= bpp else 0
            if filter_type == 1:
                row[i] = (row[i] + left) & 255
            elif filter_type == 2:
                row[i] = (row[i] + up) & 255
            elif filter_type == 3:
                row[i] = (row[i] + ((left + up) // 2)) & 255
            elif filter_type == 4:
                row[i] = (row[i] + _paeth(left, up, upper_left)) & 255
            elif filter_type != 0:
                raise ValueError(f"unsupported PNG filter {filter_type}")
        rows.append(row)
        previous = row
    rgba = bytearray(width * height * 4)
    for y, row in enumerate(rows):
        for x in range(width):
            src = x * bpp
            dst = (y * width + x) * 4
            rgba[dst : dst + 3] = row[src : src + 3]
            rgba[dst + 3] = row[src + 3] if bpp == 4 else 255
    return width, height, rgba


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", binascii.crc32(kind + payload) & 0xFFFFFFFF)


def encode_png(width: int, height: int, rgba: bytes | bytearray) -> bytes:
    if len(rgba) != width * height * 4:
        raise ValueError("RGBA buffer length mismatch")
    scanlines = bytearray()
    for y in range(height):
        scanlines.append(0)
        start = y * width * 4
        scanlines.extend(rgba[start : start + width * 4])
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + _png_chunk(b"IHDR", ihdr) + _png_chunk(b"IDAT", zlib.compress(bytes(scanlines), 9)) + _png_chunk(b"IEND", b"")


def _is_matte(r: int, g: int, b: int) -> bool:
    return r >= 180 and b >= 150 and g <= 110 and r + b >= g * 4


def normalize_rgba(width: int, height: int, rgba: bytearray, asset_id: str = "residential_l01") -> tuple[int, int, bytearray, dict[str, object]]:
    if (width, height) != CANVAS:
        raise ValueError(f"calibration canvas must be {CANVAS}, got {(width, height)}")
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen:
            continue
        index = (y * width + x) * 4
        if not _is_matte(rgba[index], rgba[index + 1], rgba[index + 2]):
            continue
        seen.add((x, y))
        rgba[index : index + 4] = b"\x00\x00\x00\x00"
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    for index in range(0, len(rgba), 4):
        r, g, b, a = rgba[index : index + 4]
        if not a:
            rgba[index : index + 4] = b"\x00\x00\x00\x00"
        elif r > g * 1.35 and b > g * 1.25:
            spill = min(r, b) - g
            rgba[index : index + 4] = bytes((max(g, int(r - spill)), g, max(g, int(b - spill)), a))
    occupied = [(i // 4 % width, i // 4 // width) for i in range(0, len(rgba), 4) if rgba[i + 3]]
    if not occupied:
        raise ValueError("normalization rejected: source contains no subject pixels")
    left = min(x for x, _ in occupied)
    top = min(y for _, y in occupied)
    right = max(x for x, _ in occupied) + 1
    bottom = max(y for _, y in occupied) + 1
    subject_w, subject_h = right - left, bottom - top
    target_w = 390
    target_h = round(subject_h * target_w / subject_w)
    if target_h > 790:
        target_h = 790
        target_w = round(subject_w * target_h / subject_h)
    subject = crop_rgba(width, height, rgba, (left, top, right, bottom))
    subject = resize_rgba(subject_w, subject_h, subject, target_w, target_h)
    canvas = bytearray(CANVAS[0] * CANVAS[1] * 4)
    origin_x, origin_y = GROUND_PIVOT[0] - target_w // 2, GROUND_PIVOT[1] - target_h
    for y in range(target_h):
        dst = ((origin_y + y) * CANVAS[0] + origin_x) * 4
        src = y * target_w * 4
        canvas[dst : dst + target_w * 4] = subject[src : src + target_w * 4]
    return CANVAS[0], CANVAS[1], canvas, {
        "mode": "uniform-object-registration",
        "asset_id": asset_id,
        "source_bbox": [left, top, right, bottom],
        "target_size": [target_w, target_h],
        "target_ground_pivot": list(GROUND_PIVOT),
        "target_origin": [origin_x, origin_y],
    }


def crop_rgba(width: int, height: int, rgba: bytes | bytearray, box: Sequence[int]) -> bytearray:
    left, top, right, bottom = box
    if not (0 <= left < right <= width and 0 <= top < bottom <= height):
        raise ValueError("invalid crop")
    out = bytearray((right - left) * (bottom - top) * 4)
    for y in range(bottom - top):
        src = ((top + y) * width + left) * 4
        dst = y * (right - left) * 4
        out[dst : dst + (right - left) * 4] = rgba[src : src + (right - left) * 4]
    return out


def resize_rgba(width: int, height: int, rgba: bytes | bytearray, new_width: int, new_height: int) -> bytearray:
    """Deterministic center-sampled resize with integer-stable bilinear math."""
    out = bytearray(new_width * new_height * 4)
    for y in range(new_height):
        source_y = ((2 * y + 1) * height - new_height) / (2 * new_height)
        y0 = max(0, min(height - 1, int(source_y)))
        y1 = min(height - 1, y0 + 1)
        fy = max(0.0, min(1.0, source_y - y0))
        for x in range(new_width):
            source_x = ((2 * x + 1) * width - new_width) / (2 * new_width)
            x0 = max(0, min(width - 1, int(source_x)))
            x1 = min(width - 1, x0 + 1)
            fx = max(0.0, min(1.0, source_x - x0))
            dst = (y * new_width + x) * 4
            for channel in range(4):
                a = rgba[(y0 * width + x0) * 4 + channel]
                b = rgba[(y0 * width + x1) * 4 + channel]
                c = rgba[(y1 * width + x0) * 4 + channel]
                d = rgba[(y1 * width + x1) * 4 + channel]
                out[dst + channel] = round(a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy)
    return out


def rgba_bbox(width: int, height: int, rgba: bytes | bytearray) -> tuple[int, int, int, int] | None:
    points = [(i // 4 % width, i // 4 // width) for i in range(0, len(rgba), 4) if rgba[i + 3]]
    if not points:
        return None
    return min(x for x, _ in points), min(y for _, y in points), max(x for x, _ in points) + 1, max(y for _, y in points) + 1


def validate_rgba(width: int, height: int, rgba: bytes | bytearray, expected: tuple[int, int] | None = None) -> list[str]:
    errors: list[str] = []
    if expected and (width, height) != expected:
        errors.append(f"dimensions {(width, height)} != {expected}")
    for i in range(0, len(rgba), 4):
        if rgba[i + 3] == 0 and any(rgba[i : i + 3]):
            errors.append("hidden RGB is nonzero")
            break
        if rgba[i + 3] and _is_matte(rgba[i], rgba[i + 1], rgba[i + 2]):
            errors.append("visible chroma spill remains")
            break
    bbox = rgba_bbox(width, height, rgba)
    if bbox is None:
        errors.append("image has no visible subject")
    elif bbox[0] <= 2 or bbox[1] <= 2 or bbox[2] >= width - 2 or bbox[3] >= height - 2:
        errors.append(f"inadequate transparent padding {bbox}")
    if width and height:
        for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
            if rgba[(y * width + x) * 4 + 3]:
                errors.append("transparent corners required")
                break
    return errors


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_json(value))


def build_literal_scale_sheet(inputs: Iterable[tuple[str, Path]], output: Path, grayscale: bool = False) -> dict[str, object]:
    decoded = [(name, *decode_png(path.read_bytes())) for name, path in inputs]
    width = max(item[1] for item in decoded)
    gap = 12
    height = sum(item[2] for item in decoded) + gap * (len(decoded) - 1)
    sheet = bytearray(width * height * 4)
    y_offset = 0
    placements = []
    for name, image_width, image_height, rgba in decoded:
        if grayscale:
            for i in range(0, len(rgba), 4):
                value = round(0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2])
                rgba[i : i + 3] = bytes((value, value, value))
        x_offset = (width - image_width) // 2
        for row in range(image_height):
            src = row * image_width * 4
            dst = ((y_offset + row) * width + x_offset) * 4
            sheet[dst : dst + image_width * 4] = rgba[src : src + image_width * 4]
        placements.append({"lod": name, "x": x_offset, "y": y_offset, "width": image_width, "height": image_height})
        y_offset += image_height + gap
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(encode_png(width, height, sheet))
    return {"file": str(output), "sha256": sha256_file(output), "pixels": [width, height], "placements": placements, "grayscale": grayscale}


def git_identity(root: Path) -> dict[str, str]:
    def run(*args: str) -> str:
        return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()
    return {"branch": run("branch", "--show-current"), "head": run("rev-parse", "HEAD")}


def run_calibration(repeat: int, evidence_root: Path) -> dict[str, object]:
    if repeat < 2:
        raise ValueError("calibration receipt requires at least two replays")
    root = repo_root()
    source = root / CALIBRATION_SOURCE
    if sha256_file(source) != CALIBRATION_SOURCE_SHA256:
        raise ValueError("calibration source hash drift")
    inventory = inventory_document()
    inventory_errors = validate_inventory(inventory)
    if inventory_errors:
        raise ValueError("inventory: " + "; ".join(inventory_errors))
    inventory_path = root / "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-096/single-angle-inventory.json"
    write_json(inventory_path, inventory)
    replay_records = []
    for replay in range(1, repeat + 1):
        replay_root = evidence_root / f"calibration/replay-{replay:02d}"
        source_width, source_height, source_rgba = decode_png(source.read_bytes())
        width, height, normalized, registration = normalize_rgba(source_width, source_height, source_rgba)
        validation = validate_rgba(width, height, normalized, CANVAS)
        if validation:
            raise ValueError("normalized calibration: " + "; ".join(validation))
        lods = []
        lod_paths = []
        for lod, size in LODS.items():
            pixels = normalized if size == CANVAS else resize_rgba(width, height, normalized, *size)
            errors = validate_rgba(size[0], size[1], pixels, size)
            if errors:
                raise ValueError(f"{lod}: " + "; ".join(errors))
            path = replay_root / f"normalized/generated_v4_residential_l01_{lod}.png"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(encode_png(size[0], size[1], pixels))
            lod_paths.append((lod, path))
            lods.append({"lod": lod, "file": str(path.relative_to(root)), "pixels": list(size), "byte_sha256": sha256_file(path), "decoded_sha256": sha256_bytes(bytes(pixels))})
        sheets = [
            build_literal_scale_sheet(lod_paths, replay_root / "sheets/literal-scale-color.png"),
            build_literal_scale_sheet(lod_paths, replay_root / "sheets/literal-scale-grayscale.png", grayscale=True),
        ]
        replay_records.append({"replay": replay, "registration": registration, "lods": lods, "sheets": sheets})
    first = replay_records[0]
    for record in replay_records[1:]:
        if [(x["byte_sha256"], x["decoded_sha256"]) for x in record["lods"]] != [(x["byte_sha256"], x["decoded_sha256"]) for x in first["lods"]]:
            raise ValueError("calibration replay is not byte/digest deterministic")
        if [x["sha256"] for x in record["sheets"]] != [x["sha256"] for x in first["sheets"]]:
            raise ValueError("literal-scale sheets are not deterministic")
    receipt_path = evidence_root / "calibration-receipt.json"
    receipt = {
        "schema": SCHEMA_VERSION,
        "task": TASK,
        "route_id": ROUTE_ID,
        "route_sha256": ROUTE_SHA256,
        "authority": AUTHORITY,
        "base": BASE,
        "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA256},
        "identity": git_identity(root),
        "calibration": {
            "source": CALIBRATION_SOURCE,
            "source_sha256": CALIBRATION_SOURCE_SHA256,
            "normalizer_reference": NORMALIZER_REFERENCE,
            "normalizer_reference_sha256": NORMALIZER_REFERENCE_SHA256,
            "appearance_reference": {"path": APPEARANCE_REFERENCE, "sha256": APPEARANCE_REFERENCE_SHA256},
            "registration_reference": {"path": REGISTRATION_REFERENCE, "sha256": REGISTRATION_REFERENCE_SHA256},
            "product_art_generated": False,
            "replay_count": repeat,
            "replays": replay_records,
        },
        "inventory": {"path": str(inventory_path.relative_to(root)), "count": inventory["count"], "sha256": sha256_file(inventory_path)},
        "deterministic_replay": True,
        "visual_acceptance": "not_performed; frontier-owned",
        "integration_admitted": False,
        "production_selected": False,
        "receipt_path": str(receipt_path.relative_to(root)),
    }
    write_json(receipt_path, receipt)
    handoff = family_handoff_document(inventory, receipt)
    handoff_path = evidence_root / "family-handoff.json"
    handoff["calibration_receipt"] = str(receipt_path.relative_to(root))
    handoff_errors = validate_family_handoff(handoff)
    if handoff_errors:
        raise ValueError("handoff: " + "; ".join(handoff_errors))
    write_json(handoff_path, handoff)
    return receipt
