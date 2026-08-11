#!/usr/bin/env python3
"""Deterministic normalization and source-admission packet for PLAY-097 v03."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path


FAMILY = Path(__file__).resolve().parents[1]
REPO = next(parent for parent in FAMILY.parents if (parent / ".git").exists())
BASE_PIPELINE_PATH = FAMILY / "tools/build_residential_l01_v2_visual_repair.py"
BASE_SPEC = importlib.util.spec_from_file_location("v02_pipeline", BASE_PIPELINE_PATH)
if BASE_SPEC is None or BASE_SPEC.loader is None:
    raise RuntimeError("base pipeline import failed")
BASE = importlib.util.module_from_spec(BASE_SPEC)
BASE_SPEC.loader.exec_module(BASE)

RAW_ROOT = FAMILY / "raw-revisions/v03"
OUTPUT = FAMILY / "normalized-v03"
EVIDENCE = REPO / "docs/production/evidence/PLAY-097/residential-l01-v2-family"
LOGICAL_NORMALIZED_ROOT = "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/residential_l01_v2/normalized-v03"
DIRECTIONS = ("south", "north", "east", "west")
LOD_SIZES = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
RAW_SIZE = (1774, 887)
CANVAS = (1536, 1024)
CONTENT_SIZE = (1536, 768)
CONTENT_ORIGIN = (0, 128)
PIVOT = (768, 896)
SOCKETS = {"east": [896, 832], "north": [896, 704], "south": [640, 832], "west": [640, 704]}
FOOTPRINT = [[768, 640], [1024, 768], [768, 896], [512, 768]]
CLAIM = "docs/production/claims/PLAY-097.world-art-residential-l01-v2-current88ea.md"
CLAIM_SHA = "c9e58426ab4b8b88b87a9ba1cb7b55286c27bb9396f762e8e64afcde6039bdf4"
BASE_HEAD = "514d14746076d67170a0ce37b584381c8c00a3c0"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def repo_path(path: Path) -> str:
    try:
        return path.relative_to(REPO).as_posix()
    except ValueError:
        return path.as_posix()


def logical_output_id(relative: str) -> str:
    return f"{LOGICAL_NORMALIZED_ROOT}/{relative}"


def keyed_rgba(width: int, height: int, channels: int, source: bytes) -> bytes:
    if channels != 3:
        raise ValueError(f"raw source must be RGB, got channels={channels}")
    output = bytearray(width * height * 4)
    for source_offset in range(0, len(source), 3):
        red, green, blue = source[source_offset:source_offset + 3]
        target_offset = (source_offset // 3) * 4
        if BASE.is_keyed_magenta(red, green, blue):
            output[target_offset:target_offset + 4] = b"\x00\x00\x00\x00"
        else:
            if red * 100 > green * 135 and blue * 100 > green * 125:
                spill = max(0, min(red, blue) - green)
                red = max(green, red - spill)
                blue = max(green, blue - spill)
            output[target_offset:target_offset + 4] = bytes((red, green, blue, 255))
    return bytes(output)


def paste_rgba(canvas: bytearray, canvas_size: tuple[int, int], tile: bytes, tile_size: tuple[int, int], origin: tuple[int, int]) -> None:
    canvas_width, _ = canvas_size
    tile_width, tile_height = tile_size
    origin_x, origin_y = origin
    for row in range(tile_height):
        source_start = row * tile_width * 4
        target_start = ((origin_y + row) * canvas_width + origin_x) * 4
        canvas[target_start:target_start + tile_width * 4] = tile[source_start:source_start + tile_width * 4]


def normalize_source(path: Path) -> tuple[bytes, dict[str, object]]:
    width, height, channels, source = BASE.decode_png(path)
    if (width, height) != RAW_SIZE or channels != 3:
        raise ValueError(f"{path.name}: expected RGB {RAW_SIZE}, got {(width, height, channels)}")
    keyed = keyed_rgba(width, height, channels, source)
    fitted = BASE.resize_rgba(RAW_SIZE, keyed, CONTENT_SIZE)
    normalized = bytearray(CANVAS[0] * CANVAS[1] * 4)
    paste_rgba(normalized, CANVAS, fitted, CONTENT_SIZE, CONTENT_ORIGIN)
    normalized_bytes = bytes(normalized)
    metrics = BASE.rgba_metrics(CANVAS, normalized_bytes)
    return normalized_bytes, metrics


def build_direction(direction: str, output_root: Path) -> dict[str, object]:
    if direction not in DIRECTIONS:
        raise ValueError(f"unknown direction: {direction}")
    output_root.mkdir(parents=True, exist_ok=True)
    raw_path = RAW_ROOT / f"{direction}-source-v03.png"
    raw_width, raw_height, raw_channels, _ = BASE.decode_png(raw_path)
    normalized_bytes, metrics = normalize_source(raw_path)
    normalized_relative = f"source/{direction}.png"
    normalized_path = output_root / normalized_relative
    BASE.write_png(normalized_path, CANVAS, 4, normalized_bytes)
    normalized_record = {"path": logical_output_id(normalized_relative), "sha256": sha256(normalized_path), "dimensions": list(CANVAS), "mode": "RGBA", **metrics}

    lod_bytes: dict[str, bytes] = {}
    lod_records: dict[str, dict[str, object]] = {}
    generated = [logical_output_id(normalized_relative)]
    for lod, size in LOD_SIZES.items():
        pixels = BASE.resize_rgba(CANVAS, normalized_bytes, size)
        lod_bytes[lod] = pixels
        lod_relative = f"lod/{direction}/{lod}.png"
        lod_path = output_root / lod_relative
        BASE.write_png(lod_path, size, 4, pixels)
        lod_records[lod] = {"path": logical_output_id(lod_relative), "sha256": sha256(lod_path), "dimensions": list(size), "mode": "RGBA", **BASE.rgba_metrics(size, pixels)}
        generated.append(logical_output_id(lod_relative))

    return {
        "direction": direction,
        "raw": {"path": repo_path(raw_path), "sha256": sha256(raw_path), "dimensions": [raw_width, raw_height], "mode": "RGB"},
        "normalized": normalized_record,
        "lods": lod_records,
        "generatedFiles": generated,
        "_normalizedBytes": normalized_bytes,
        "_lodBytes": lod_bytes,
    }


def checker_sheet(root: Path, normalized: dict[str, bytes], lods: dict[str, dict[str, bytes]]) -> dict[str, dict[str, object]]:
    sheets: dict[str, dict[str, object]] = {}
    source_sheet_size = (1536, 1024)
    source_sheet = BASE.checker_canvas(source_sheet_size)
    for index, direction in enumerate(DIRECTIONS):
        tile_size = (768, 512)
        tile = BASE.resize_rgba(CANVAS, normalized[direction], tile_size)
        BASE.paste_rgb(source_sheet, source_sheet_size, BASE.composite_checker(tile_size, tile), tile_size, ((index % 2) * 768, (index // 2) * 512))
    source_path = root / "contact-sheets/family-source-four-view-v03.png"
    BASE.write_png(source_path, source_sheet_size, 3, bytes(source_sheet))
    sheets["sourceFourView"] = {"path": logical_output_id(source_path.relative_to(root).as_posix()), "sha256": sha256(source_path), "dimensions": list(source_sheet_size)}

    gap = 24
    column_width = LOD_SIZES["block"][0]
    lod_sheet_size = (len(DIRECTIONS) * column_width + (len(DIRECTIONS) - 1) * gap, sum(size[1] for size in LOD_SIZES.values()) + (len(LOD_SIZES) - 1) * gap)
    for grayscale, name, key in ((False, "family-literal-lod-color-v03.png", "literalColor"), (True, "family-literal-lod-grayscale-v03.png", "grayscale")):
        canvas = BASE.checker_canvas(lod_sheet_size)
        y = 0
        for lod, size in LOD_SIZES.items():
            for column, direction in enumerate(DIRECTIONS):
                tile = BASE.composite_checker(size, lods[direction][lod], grayscale)
                x = column * (column_width + gap) + (column_width - size[0]) // 2
                BASE.paste_rgb(canvas, lod_sheet_size, tile, size, (x, y))
            y += size[1] + gap
        sheet_path = root / f"contact-sheets/{name}"
        BASE.write_png(sheet_path, lod_sheet_size, 3, bytes(canvas))
        sheets[key] = {"path": logical_output_id(sheet_path.relative_to(root).as_posix()), "sha256": sha256(sheet_path), "dimensions": list(lod_sheet_size)}
    return sheets


def build_outputs(output_root: Path = OUTPUT) -> dict[str, object]:
    output_root.mkdir(parents=True, exist_ok=True)
    normalized: dict[str, bytes] = {}
    normalized_records: dict[str, dict[str, object]] = {}
    lod_records: dict[str, dict[str, object]] = {direction: {} for direction in DIRECTIONS}
    lod_bytes: dict[str, dict[str, bytes]] = {direction: {} for direction in DIRECTIONS}
    generated: list[Path] = []

    raw_records: dict[str, dict[str, object]] = {}
    for direction in DIRECTIONS:
        direction_output = build_direction(direction, output_root)
        normalized[direction] = direction_output["_normalizedBytes"]
        normalized_records[direction] = direction_output["normalized"]
        lod_bytes[direction] = direction_output["_lodBytes"]
        lod_records[direction] = direction_output["lods"]
        generated.extend(output_root / logical_id.removeprefix(f"{LOGICAL_NORMALIZED_ROOT}/") for logical_id in direction_output["generatedFiles"])
        raw_path = RAW_ROOT / f"{direction}-source-v03.png"
        raw_width, raw_height, raw_channels, _ = BASE.decode_png(raw_path)
        raw_records[direction] = {"path": repo_path(raw_path), "sha256": sha256(raw_path), "dimensions": [raw_width, raw_height], "mode": "RGB"}

    sheets = checker_sheet(output_root, normalized, lod_bytes)
    generated.extend(output_root.glob("contact-sheets/*.png"))
    record = {
        "schema": "citysim.play-097.residential-l01-v2.normalization-v03.v1",
        "family": "residential_l01_v2",
        "candidateRevision": "v03",
        "claim": {"path": CLAIM, "sha256": CLAIM_SHA},
        "baseHead": BASE_HEAD,
        "directions": list(DIRECTIONS),
        "rawSources": raw_records,
        "normalizedSources": normalized_records,
        "lods": lod_records,
        "contactSheets": sheets,
        "geometry": {"rawInputCanvas": list(RAW_SIZE), "canvas": list(CANVAS), "fitContent": list(CONTENT_SIZE), "fitOrigin": list(CONTENT_ORIGIN), "pivot": list(PIVOT), "footprint": FOOTPRINT, "sockets": SOCKETS},
        "derivation": "keyed RGB raw master -> deterministic premultiplied bilinear fit to 1536x768 at y=128 -> RGBA 1536x1024 -> deterministic block/neighborhood/city premultiplied bilinear LODs",
        "sourceAdmitted": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "generatedFiles": sorted(logical_output_id(path.relative_to(output_root).as_posix()) for path in generated),
    }
    write_json(output_root / "NORMALIZATION-RECEIPT.json", record)
    write_json(output_root / "PROVENANCE.json", {"schema": "citysim.play-097.residential-l01-v2.provenance-v03.v1", "candidateOnly": True, "family": "residential_l01_v2", "directions": raw_records, "normalized": normalized_records, "lods": lod_records, "siblingInputsConsumed": {direction: ["north architectural identity reference only"] if direction != "north" else [] for direction in DIRECTIONS}, "mirrored": False, "rotated": False, "copiedPixels": False, "sourceAdmitted": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False})
    if output_root == OUTPUT:
        write_json(EVIDENCE / "SOURCE-ADMISSION-RECEIPT-V03.json", {"schema": "citysim.play-097.residential-l01-v2.source-admission-handoff-v03.v1", "result": "PASS_CANDIDATE_SOURCE_HANDOFF", "candidateOnly": True, "claim": {"path": CLAIM, "sha256": CLAIM_SHA}, "baseHead": BASE_HEAD, "normalizationReceipt": {"path": logical_output_id("NORMALIZATION-RECEIPT.json"), "sha256": sha256(output_root / "NORMALIZATION-RECEIPT.json")}, "rawSources": raw_records, "normalizedSources": normalized_records, "lods": lod_records, "sourceAdmitted": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False})
        write_json(EVIDENCE / "MATRIX-SELECTION-V03.json", {"schema": "citysim.play-097.residential-l01-v2.matrix-v03.v1", "family": "residential_l01_v2", "directions": list(DIRECTIONS), "rawCount": len(raw_records), "normalizedCount": len(normalized_records), "lodCount": sum(len(rows) for rows in lod_records.values()), "uniqueRaw": len({row["sha256"] for row in raw_records.values()}), "uniqueNormalized": len({row["sha256"] for row in normalized_records.values()}), "uniqueLod": len({row["sha256"] for rows in lod_records.values() for row in rows.values()}), "result": "PASS_CANDIDATE_SOURCE_HANDOFF", "candidateOnly": True})
        write_json(EVIDENCE / "REGISTRATION-REPORT-V03.json", {"schema": "citysim.play-097.residential-l01-v2.registration-v03.v1", "result": "PASS", "profile": "citysim-registration-profile-v1 building_1536x1024", "canvas": list(CANVAS), "pivot": list(PIVOT), "footprint": FOOTPRINT, "sockets": SOCKETS, "lodRegistration": {lod: {"dimensions": list(size), "pivot": [size[0] // 2, round(PIVOT[1] * size[1] / CANVAS[1])]} for lod, size in LOD_SIZES.items()}, "method": "fixed code-owned fit and pivot; no pixel-inferred geometry"})
    return record


def main() -> int:
    record = build_outputs()
    print(json.dumps({"result": "PASS", "normalized": 4, "lods": 12, "generatedFiles": len(record["generatedFiles"])}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
