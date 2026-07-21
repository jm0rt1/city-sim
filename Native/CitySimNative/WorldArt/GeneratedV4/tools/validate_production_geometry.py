#!/usr/bin/env python3
"""Validate PLAY-022 physical registration without loading gameplay code."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT.parent
ATLAS = PACKAGE / "Sources" / "CitySimNative" / "Resources" / "WorldAssets.atlas"
MANIFEST = ATLAS / "generated-v4-manifest.json"
DETAILS = ("city", "neighborhood", "block")
NEIGHBOR_OFFSETS = ((36.0, 18.0), (36.0, -18.0), (-36.0, -18.0), (-36.0, 18.0))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def translated(points: list[list[float]], offset: tuple[float, float]) -> list[tuple[float, float]]:
    return [(point[0] + offset[0], point[1] + offset[1]) for point in points]


def projections(points: list[tuple[float, float]], axis: tuple[float, float]) -> tuple[float, float]:
    values = [point[0] * axis[0] + point[1] * axis[1] for point in points]
    return min(values), max(values)


def polygons_overlap(first: list[tuple[float, float]], second: list[tuple[float, float]], tolerance: float = 0.01) -> bool:
    for polygon in (first, second):
        for index, point in enumerate(polygon):
            following = polygon[(index + 1) % len(polygon)]
            axis = (-(following[1] - point[1]), following[0] - point[0])
            first_min, first_max = projections(first, axis)
            second_min, second_max = projections(second, axis)
            if first_max <= second_min + tolerance or second_max <= first_min + tolerance:
                return False
    return True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures: list[str] = []
    pivot_drift: dict[str, dict[str, float]] = {}
    active_bytes: dict[str, int] = {}
    collisions: list[dict[str, object]] = []

    if manifest.get("schema") != 4 or not manifest.get("production_selection"):
        failures.append("manifest is not the approved production schema-4 selection")

    inventory_names: set[str] = set()
    for item in manifest["inventory"]:
        name = item["file"]
        if name in inventory_names:
            failures.append(f"duplicate inventory entry: {name}")
        inventory_names.add(name)
        path = ATLAS / name
        if not path.exists():
            failures.append(f"missing inventory file: {name}")
        elif sha256(path) != item["sha256"]:
            failures.append(f"hash mismatch: {name}")
        expected_bytes = item["pixels"][0] * item["pixels"][1] * 4
        if item["decoded_byte_estimate"] != expected_bytes:
            failures.append(f"decoded byte mismatch: {name}")

    logical_ids: set[str] = set()
    collidable_assets = []
    for asset in manifest["assets"]:
        logical_id = asset["logical_id"]
        if logical_id in logical_ids:
            failures.append(f"duplicate logical ID: {logical_id}")
        logical_ids.add(logical_id)
        if asset["footprint_tiles"] != [1, 1]:
            failures.append(f"{logical_id} invents multi-tile presentation ownership")

        contact = asset["ground_contact_polygon_world"]
        if len(contact) < 4:
            failures.append(f"{logical_id} has no ground-contact polygon")
        for point in contact:
            if abs(point[0]) / 36.0 + abs(point[1]) / 18.0 > 1.0001:
                failures.append(f"{logical_id} ground contact leaves its authoritative tile")
        if asset["family"] not in {"terrain", "network-material", "frontage"}:
            collidable_assets.append(asset)

        entrance = asset["entrance_socket_world"]
        if asset["frontage_edge"] != "none":
            if not any(
                rect[0] <= entrance[0] <= rect[0] + rect[2]
                and rect[1] <= entrance[1] <= rect[1] + rect[3]
                for rect in asset["prop_exclusion_rects_world"]
            ):
                failures.append(f"{logical_id} entrance is not protected by a prop exclusion")

        source_width, source_height = asset["source_canvas_pixels"]
        source_pivot_x, source_pivot_y = asset["ground_pivot_source"]
        pivot_drift[logical_id] = {}
        for detail in DETAILS:
            lod = asset["lods"][detail]
            pixel_width, pixel_height = lod["pixels"]
            trim_x, trim_y, trim_width, trim_height = lod["trim_rect_pixels"]
            expected_anchor_x = (source_pivot_x * pixel_width / source_width - trim_x) / trim_width
            expected_anchor_y = (trim_y + trim_height - source_pivot_y * pixel_height / source_height) / trim_height
            drift_pixels = max(
                abs(lod["anchor"][0] - expected_anchor_x) * trim_width,
                abs(lod["anchor"][1] - expected_anchor_y) * trim_height,
            )
            pivot_drift[logical_id][detail] = round(drift_pixels, 6)
            if drift_pixels > 0.5:
                failures.append(f"{logical_id}.{detail} pivot drift {drift_pixels:.4f}px exceeds 0.5px")
            if not (0 <= trim_x < pixel_width and 0 <= trim_y < pixel_height
                    and trim_x + trim_width <= pixel_width and trim_y + trim_height <= pixel_height):
                failures.append(f"{logical_id}.{detail} trim leaves its source canvas")

    for first in collidable_assets:
        first_polygon = [(point[0], point[1]) for point in first["ground_contact_polygon_world"]]
        for second in collidable_assets:
            for offset in NEIGHBOR_OFFSETS:
                overlap = polygons_overlap(
                    first_polygon,
                    translated(second["ground_contact_polygon_world"], offset),
                )
                collisions.append({
                    "first": first["logical_id"],
                    "second": second["logical_id"],
                    "neighbor_offset": list(offset),
                    "overlap": overlap,
                })
                if overlap:
                    failures.append(
                        f"ground collision: {first['logical_id']} / {second['logical_id']} at {offset}"
                    )

    road_lods = manifest["compiled_network"]["lods"]
    for detail in DETAILS:
        bytes_for_assets = sum(asset["lods"][detail]["decoded_byte_estimate"] for asset in manifest["assets"])
        bytes_for_roads = road_lods[detail]["decoded_bytes_per_texture"] * 16
        active_bytes[detail] = bytes_for_assets + bytes_for_roads
        if active_bytes[detail] > 96 * 1024 * 1024:
            failures.append(f"{detail} active residency exceeds 96 MiB")

    report = {
        "schema": 1,
        "manifest_sha256": sha256(MANIFEST),
        "asset_count": len(manifest["assets"]),
        "inventory_count": len(manifest["inventory"]),
        "authoritative_footprint": [1, 1],
        "pivot_drift_pixels": pivot_drift,
        "active_decoded_bytes": active_bytes,
        "reciprocal_ground_collision_checks": len(collisions),
        "reciprocal_ground_collisions": [item for item in collisions if item["overlap"]],
        "failures": failures,
        "result": "pass" if not failures else "fail",
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
