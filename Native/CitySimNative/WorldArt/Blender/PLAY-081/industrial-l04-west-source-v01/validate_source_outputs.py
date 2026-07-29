#!/usr/bin/env python3
"""Post-lock PLAY-081 source-pixel validator.

This validator is committed pre-lock but must not be run until Integration
publishes the appearance lock and explicitly authorizes West A/B/C.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


DEFAULT_CONTRACT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/"
    "industrial-l04-west-source-v01/RUNNER-CONTRACT.json"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument("--catalog-decoded-hashes", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def repository_path(root: Path, relative: str) -> Path:
    resolved = (root / relative).resolve()
    resolved.relative_to(root)
    return resolved


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def decoded_rgba(path: Path) -> tuple[tuple[int, int], bytes]:
    from PIL import Image

    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        return rgba.size, rgba.tobytes()


def alpha_report(size: tuple[int, int], rgba: bytes) -> dict[str, Any]:
    width, height = size
    occupied: list[tuple[int, int]] = []
    hidden_rgb = 0
    visible_chroma = 0
    edge_contact = 0
    for index in range(width * height):
        red, green, blue, alpha = rgba[index * 4 : index * 4 + 4]
        x = index % width
        y = index // width
        if alpha:
            occupied.append((x, y))
            if red >= 230 and blue >= 230 and green <= 25:
                visible_chroma += 1
            if x in (0, width - 1) or y in (0, height - 1):
                edge_contact += 1
        elif red or green or blue:
            hidden_rgb += 1
    bounds = None
    if occupied:
        xs = [point[0] for point in occupied]
        ys = [point[1] for point in occupied]
        bounds = [min(xs), min(ys), max(xs), max(ys)]
    return {
        "occupiedBounds": bounds,
        "occupiedPixels": len(occupied),
        "hiddenRgbPixels": hidden_rgb,
        "visibleChromaSpillPixels": visible_chroma,
        "edgeContactPixels": edge_contact,
        "passed": (
            bool(occupied)
            and hidden_rgb == 0
            and visible_chroma == 0
            and edge_contact == 0
        ),
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract = json.loads(repository_path(root, args.contract).read_text())
    catalog = json.loads(
        repository_path(root, args.catalog_decoded_hashes).read_text()
    )
    catalog_hashes = set(catalog["decodedRgbaSha256"])
    failures: list[str] = []
    processes: dict[str, Any] = {}
    raw_hashes: dict[str, str] = {}
    semantic_hashes: dict[str, str] = {}
    occupied_bounds: dict[str, Any] = {}
    provenance_ids: list[str] = []

    for process_id in ("A", "B", "C"):
        inventory = contract["outputInventory"]["processes"][process_id]
        required = {
            name: repository_path(root, inventory[name])
            for name in (
                "raw",
                "semantic",
                "provenance",
                "objectMapping",
                "registration",
            )
        }
        missing = sorted(name for name, path in required.items() if not path.is_file())
        if missing:
            failures.append(f"process-{process_id}:missing:{','.join(missing)}")
            continue
        raw_size, raw_bytes = decoded_rgba(required["raw"])
        semantic_size, semantic_bytes = decoded_rgba(required["semantic"])
        raw_hashes[process_id] = sha256_bytes(raw_bytes)
        semantic_hashes[process_id] = sha256_bytes(semantic_bytes)
        alpha = alpha_report(raw_size, raw_bytes)
        occupied_bounds[process_id] = alpha["occupiedBounds"]
        if not alpha["passed"]:
            failures.append(f"process-{process_id}:alpha-chroma-hidden-rgb")
        if raw_size != tuple(contract["invariants"]["camera"]["renderViewportPixels"]):
            failures.append(f"process-{process_id}:raw-size")
        if semantic_size != raw_size:
            failures.append(f"process-{process_id}:semantic-size")

        provenance = json.loads(required["provenance"].read_text())
        registration = json.loads(required["registration"].read_text())
        provenance_ids.append(provenance.get("processId"))
        if provenance.get("processId") != process_id:
            failures.append(f"process-{process_id}:provenance-id")
        if (
            provenance.get("appearanceLock")
            != contract["appearanceLock"]
        ):
            failures.append(f"process-{process_id}:appearance-lock-provenance")
        if provenance.get("coordinateBridge") != contract["coordinateBridge"]["v06"]:
            failures.append(f"process-{process_id}:coordinate-bridge-provenance")
        expected_registration = contract["invariants"]["registration"]
        if registration.get("footprintWorldXZ") != expected_registration[
            "contactPolygonWorldXZ"
        ]:
            failures.append(f"process-{process_id}:footprint")
        if registration.get("pivotWorldXYZ") != expected_registration[
            "groundPivotWorldXYZ"
        ]:
            failures.append(f"process-{process_id}:pivot")
        if registration.get("socketWorldXYZ") != expected_registration[
            "frontageSocketWorldXYZ"
        ]:
            failures.append(f"process-{process_id}:socket")
        processes[process_id] = {
            "rawDecodedRgbaSha256": raw_hashes[process_id],
            "semanticDecodedRgbaSha256": semantic_hashes[process_id],
            "alpha": alpha,
            "rawSize": list(raw_size),
            "semanticSize": list(semantic_size),
        }

    abc_raw_equal = len(set(raw_hashes.values())) == 1 and len(raw_hashes) == 3
    abc_semantic_equal = (
        len(set(semantic_hashes.values())) == 1 and len(semantic_hashes) == 3
    )
    bounds_equal = (
        len({json.dumps(value) for value in occupied_bounds.values()}) == 1
        and len(occupied_bounds) == 3
    )
    provenance_unique = sorted(provenance_ids) == ["A", "B", "C"]
    if not abc_raw_equal:
        failures.append("abc:raw-decoded-rgba")
    if not abc_semantic_equal:
        failures.append("abc:semantic-decoded-rgba")
    if not bounds_equal:
        failures.append("abc:occupied-bounds")
    if not provenance_unique:
        failures.append("abc:fresh-process-provenance")
    accepted_hash = next(iter(raw_hashes.values()), "")
    non_alias = bool(accepted_hash) and accepted_hash not in catalog_hashes
    if not non_alias:
        failures.append("catalog:decoded-rgba-alias")

    literal_path = repository_path(
        root, contract["outputInventory"]["review"]["literal192Color"]
    )
    literal_size = None
    if literal_path.is_file():
        literal_size, _ = decoded_rgba(literal_path)
    literal_pass = literal_size == (192, 128)
    if not literal_pass:
        failures.append("literal192:not-192x128")

    report = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "processes": processes,
        "abcIdentity": {
            "rawDecodedRgbaEqual": abc_raw_equal,
            "semanticDecodedRgbaEqual": abc_semantic_equal,
            "occupiedBoundsEqual": bounds_equal,
            "freshProcessProvenance": provenance_unique,
        },
        "literal192": {
            "path": contract["outputInventory"]["review"]["literal192Color"],
            "size": list(literal_size) if literal_size else None,
            "passed": literal_pass,
        },
        "nonAliasing": {
            "candidateDecodedRgbaSha256": accepted_hash or None,
            "catalogHashCount": len(catalog_hashes),
            "passed": non_alias,
        },
        "failures": sorted(set(failures)),
        "passed": not failures,
        "productionSelected": False,
    }
    output = repository_path(root, args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
