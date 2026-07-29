#!/usr/bin/env python3
"""Post-lock South pixel validator.

Pre-lock use is limited to --mode describe. The validate mode is intentionally
present but remains unrun until Integration publishes the appearance lock and
post-lock production authority.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import zlib
from pathlib import Path
from typing import Any


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
DEFAULT_CONTRACT = SOURCE_DIR / "runner-contract.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("describe", "validate"), required=True)
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--non-alias-inventory", type=Path)
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repository_path(display_path: str) -> Path:
    path = (REPOSITORY_ROOT / display_path).resolve()
    path.relative_to(REPOSITORY_ROOT)
    return path


def paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left


def decode_rgba_png(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    cursor = 8
    idat = bytearray()
    width = height = 0
    while cursor < len(data):
        length = struct.unpack(">I", data[cursor : cursor + 4])[0]
        chunk_type = data[cursor + 4 : cursor + 8]
        chunk_data = data[cursor + 8 : cursor + 8 + length]
        cursor += 12 + length
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = (
                struct.unpack(">IIBBBBB", chunk_data)
            )
            if (bit_depth, color_type, compression, filtering, interlace) != (
                8,
                6,
                0,
                0,
                0,
            ):
                raise ValueError(f"{path} must be non-interlaced 8-bit RGBA")
        elif chunk_type == b"IDAT":
            idat.extend(chunk_data)
        elif chunk_type == b"IEND":
            break
    packed = zlib.decompress(bytes(idat))
    stride = width * 4
    rows: list[bytearray] = []
    offset = 0
    for _ in range(height):
        filter_type = packed[offset]
        offset += 1
        source = packed[offset : offset + stride]
        offset += stride
        row = bytearray(stride)
        previous = rows[-1] if rows else bytearray(stride)
        for index, byte in enumerate(source):
            left = row[index - 4] if index >= 4 else 0
            above = previous[index]
            upper_left = previous[index - 4] if index >= 4 else 0
            if filter_type == 0:
                value = byte
            elif filter_type == 1:
                value = byte + left
            elif filter_type == 2:
                value = byte + above
            elif filter_type == 3:
                value = byte + ((left + above) // 2)
            elif filter_type == 4:
                value = byte + paeth(left, above, upper_left)
            else:
                raise ValueError(f"{path} uses unsupported PNG filter {filter_type}")
            row[index] = value & 0xFF
        rows.append(row)
    return width, height, b"".join(rows)


def pixel_metrics(width: int, height: int, rgba: bytes) -> dict[str, Any]:
    occupied: list[tuple[int, int]] = []
    hidden_rgb = 0
    visible_chroma = 0
    for index in range(0, len(rgba), 4):
        red, green, blue, alpha = rgba[index : index + 4]
        pixel = index // 4
        x, y = pixel % width, pixel // width
        if alpha:
            occupied.append((x, y))
            if red >= 250 and green <= 5 and blue >= 250:
                visible_chroma += 1
        elif red or green or blue:
            hidden_rgb += 1
    bounds = None
    if occupied:
        xs = [point[0] for point in occupied]
        ys = [point[1] for point in occupied]
        bounds = [min(xs), min(ys), max(xs) + 1, max(ys) + 1]
    return {
        "occupiedBounds": bounds,
        "occupiedPixelCount": len(occupied),
        "hiddenRgbPixels": hidden_rgb,
        "visibleChromaPixels": visible_chroma,
    }


def validate_provenance(
    contract: dict[str, Any],
    decoded_hashes: dict[str, str],
    semantic_decoded_hashes: dict[str, str],
) -> tuple[bool, list[dict[str, Any]]]:
    records = []
    process_ids = set()
    for mode in ("A", "B", "C"):
        path = repository_path(contract["outputInventory"]["provenance"][mode])
        record = load_json(path)
        process_ids.add(record.get("freshProcessId"))
        expected = {
            "taskId": "PLAY-080",
            "direction": "south",
            "process": mode,
            "freshProcess": True,
            "decodedRgbaSha256": decoded_hashes[mode],
            "semanticDecodedRgbaSha256": semantic_decoded_hashes[mode],
            "renderInvocations": 2,
        }
        mismatches = {
            key: {"expected": value, "actual": record.get(key)}
            for key, value in expected.items()
            if record.get(key) != value
        }
        records.append({"process": mode, "path": str(path), "mismatches": mismatches})
    return len(process_ids) == 3 and None not in process_ids and all(
        not record["mismatches"] for record in records
    ), records


def literal_metrics_pass(provenance: dict[str, Any], contract: dict[str, Any]) -> bool:
    metrics = provenance.get("literal192", {})
    targets = contract["invariants"]["pixelValidation"]
    portal = metrics.get("primaryPortalPixels", [0, 0])
    freight = metrics.get("freightOpeningWidthsPixels", [])
    return (
        len(portal) == 2
        and portal[0] >= targets["literal192PrimaryPortalMinimumPixels"][0]
        and portal[1] >= targets["literal192PrimaryPortalMinimumPixels"][1]
        and len(freight) == 3
        and min(freight) >= targets["literal192FreightOpeningMinimumWidthPixels"]
        and metrics.get("frameMinimumThicknessPixels", 0)
        >= targets["literal192FrameMinimumThicknessPixels"]
        and metrics.get("silhouetteBreaks", 0) >= targets["minimumSilhouetteBreaks"]
        and metrics.get("processOcclusionPixels")
        == targets["maximumProcessOcclusionPixels"]
    )


def forbidden_decoded_rgba_hashes(
    common_input_path: Path, contract: dict[str, Any]
) -> set[str]:
    common_record = contract["authorities"]["nonAliasInput"]
    if common_input_path.resolve() != repository_path(common_record["path"]):
        raise ValueError("non-alias input path does not match the runner contract")
    if sha256_file(common_input_path) != common_record["sha256"]:
        raise ValueError("non-alias input hash does not match the runner contract")
    common_input = load_json(common_input_path)
    derived = common_input["authorityInputs"]["derivedInventory"]
    derived_path = repository_path(derived["path"])
    if sha256_file(derived_path) != derived["sha256"]:
        raise ValueError("derived non-alias inventory hash mismatch")
    masters = load_json(derived_path).get("masters", [])
    hashes = [master["decodedRGBASHA256"] for master in masters]
    hashes_are_canonical = all(
        isinstance(value, str)
        and len(value) == 64
        and all(character in "0123456789abcdef" for character in value)
        for value in hashes
    )
    canonical = (
        "".join(f"{value}\n" for value in sorted(hashes))
        if hashes_are_canonical
        else ""
    )
    actual_set_sha = sha256_bytes(canonical.encode("ascii"))
    if (
        common_input.get("counts", {}).get("total") != 44
        or common_input.get("forbiddenDecodedRgbaSha256Count") != 44
        or len(hashes) != 44
        or len(set(hashes)) != 44
        or not hashes_are_canonical
        or actual_set_sha != common_input.get("forbiddenSetSha256")
    ):
        raise ValueError("common non-alias input does not resolve to canonical 44")
    return set(hashes)


def main() -> int:
    args = parse_args()
    contract = load_json(args.contract)
    bridge = contract.get("coordinateBridge", {})
    checks = [
        "fresh-process provenance",
        "decoded raw RGBA A/B/C identity",
        "decoded semantic RGBA A/B/C identity",
        "alpha, chroma, and hidden-RGB cleanliness",
        "occupied-bounds identity",
        "footprint, pivot, and South socket registration",
        "literal-192 portal, freight, frame, silhouette, and occlusion survival",
        "logical and directional non-aliasing",
    ]
    if args.mode == "describe":
        print(
            json.dumps(
                {
                    "schema": "citysim.play-080.source-output-validator-description.v1",
                    "taskId": "PLAY-080",
                    "direction": "south",
                    "coordinateBridgeRevalidation": bridge.get("state"),
                    "canonicalCitySimSouthSocket": bridge.get(
                        "canonicalCitySimSouthSocket"
                    ),
                    "sourceSocketPixels": bridge.get("sourceSocketPixels"),
                    "blenderNativeDirectionalSocket": bridge.get(
                        "blenderNativeDirectionalSocket"
                    ),
                    "literal192Measurement": (
                        "analytic-v06-camera-semantic-cells-v1"
                    ),
                    "literal192FiveFieldValidator": [
                        "primaryPortalPixels",
                        "freightOpeningWidthsPixels",
                        "frameMinimumThicknessPixels",
                        "silhouetteBreaks",
                        "processOcclusionPixels",
                    ],
                    "nonAliasInput": contract.get("authorities", {}).get(
                        "nonAliasInput"
                    ),
                    "checks": checks,
                    "rgba": "not_run",
                    "literal192": "not_run",
                    "abcIdentity": "not_run",
                    "normalization": "not_run",
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 0

    if args.non_alias_inventory is None or args.output is None:
        raise SystemExit("--mode validate requires --non-alias-inventory and --output")
    if bridge.get("state") != "v06_revalidated":
        raise SystemExit("pixel validation blocked pending v06 coordinate-bridge revalidation")
    raw_results: dict[str, dict[str, Any]] = {}
    semantic_results: dict[str, dict[str, Any]] = {}
    raw_hashes: dict[str, str] = {}
    semantic_hashes: dict[str, str] = {}
    for mode in ("A", "B", "C"):
        raw = decode_rgba_png(repository_path(contract["outputInventory"]["raw"][mode]))
        semantic = decode_rgba_png(
            repository_path(contract["outputInventory"]["semantic"][mode])
        )
        raw_hashes[mode] = sha256_bytes(raw[2])
        semantic_hashes[mode] = sha256_bytes(semantic[2])
        raw_results[mode] = {
            "size": [raw[0], raw[1]],
            "decodedRgbaSha256": raw_hashes[mode],
            **pixel_metrics(*raw),
        }
        semantic_results[mode] = {
            "size": [semantic[0], semantic[1]],
            "decodedRgbaSha256": semantic_hashes[mode],
            **pixel_metrics(*semantic),
        }

    provenance_ok, provenance_records = validate_provenance(
        contract, raw_hashes, semantic_hashes
    )
    provenance_a = load_json(
        repository_path(contract["outputInventory"]["provenance"]["A"])
    )
    forbidden_hashes = forbidden_decoded_rgba_hashes(
        args.non_alias_inventory, contract
    )
    raw_identity = len(set(raw_hashes.values())) == 1
    semantic_identity = len(set(semantic_hashes.values())) == 1
    bounds_identity = len(
        {tuple(value["occupiedBounds"] or []) for value in raw_results.values()}
    ) == 1
    cleanliness = all(
        value["hiddenRgbPixels"] == 0 and value["visibleChromaPixels"] == 0
        for value in raw_results.values()
    )
    registration = provenance_a.get("registration") == {
        "footprintWorldSize": [56, 56],
        "groundPivot": [28, 0, 28],
        "canonicalCitySimFrontageSocket": [0, 0, 28],
        "sourceSocketPixels": [640, 832],
        "blenderNativeDirectionalSocket": bridge["blenderNativeDirectionalSocket"],
        "frontageDirection": "south",
    }
    literal192 = literal_metrics_pass(provenance_a, contract)
    non_alias = not (set(raw_hashes.values()) & forbidden_hashes)
    results = {
        "freshProcessProvenance": provenance_ok,
        "rawDecodedRgbaIdentity": raw_identity,
        "semanticDecodedRgbaIdentity": semantic_identity,
        "alphaChromaHiddenRgb": cleanliness,
        "occupiedBoundsIdentity": bounds_identity,
        "registration": registration,
        "literal192": literal192,
        "nonAliasing": non_alias,
    }
    report = {
        "schema": "citysim.play-080.source-output-validation.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "result": "PASS" if all(results.values()) else "FAIL",
        "results": results,
        "raw": raw_results,
        "semantic": semantic_results,
        "provenance": provenance_records,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"result": report["result"], "output": str(args.output)}))
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
