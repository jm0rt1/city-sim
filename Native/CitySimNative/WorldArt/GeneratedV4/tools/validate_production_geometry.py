#!/usr/bin/env python3
"""Validate PLAY-022 physical registration without loading gameplay code.

The report deliberately distinguishes vertical visual volume from physical
ground occupancy.  Roofs and height may rise above a tile through the declared
top overhang, while ground contacts, entrances, shadows at the parcel edge,
and renderer-owned props must not intrude into neighboring road or lot space.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / "GeneratedV4"
PACKAGE = ROOT.parent
ATLAS = PACKAGE / "Sources" / "CitySimNative" / "Resources" / "WorldAssets.atlas"
MANIFEST = ATLAS / "generated-v4-manifest.json"
DETAILS = ("city", "neighborhood", "block")
NEIGHBOR_OFFSETS = ((36.0, 18.0), (36.0, -18.0), (-36.0, -18.0), (-36.0, 18.0))
SURFACE_FAMILIES = {"terrain", "network-material", "frontage"}
VALID_FRONTAGE_EDGES = {"none", "south", "nearest-road", "all-road-sockets"}
VALID_ORIENTATIONS = {
    "projection-fixed",
    "topology-compiled",
    "road-socket-selected",
    "south-facing-fixed",
}
GEOMETRY_TOLERANCE = 0.01
LOD_BOUNDS_TOLERANCE_WORLD = 1.25
SOCKET_TOLERANCE_WORLD = 0.5
FORBIDDEN_INTRUSION_TOLERANCE_WORLD = 0.5
TARGET_ACTIVE_BYTES = 96 * 1024 * 1024
HARD_ACTIVE_BYTES = 128 * 1024 * 1024


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError("not a PNG with a readable IHDR")
    return struct.unpack(">II", header[16:24])


def finite_values(values: Iterable[object], expected_count: int) -> bool:
    values = list(values)
    return len(values) == expected_count and all(
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
        for value in values
    )


def translated(points: list[list[float]] | list[tuple[float, float]], offset: tuple[float, float]) -> list[tuple[float, float]]:
    return [(float(point[0]) + offset[0], float(point[1]) + offset[1]) for point in points]


def projections(points: list[tuple[float, float]], axis: tuple[float, float]) -> tuple[float, float]:
    values = [point[0] * axis[0] + point[1] * axis[1] for point in points]
    return min(values), max(values)


def polygons_overlap(first: list[tuple[float, float]], second: list[tuple[float, float]], tolerance: float = GEOMETRY_TOLERANCE) -> bool:
    """Return true only for positive-area overlap between convex polygons."""
    if len(first) < 3 or len(second) < 3:
        return False
    for polygon in (first, second):
        for index, point in enumerate(polygon):
            following = polygon[(index + 1) % len(polygon)]
            axis = (-(following[1] - point[1]), following[0] - point[0])
            if abs(axis[0]) <= tolerance and abs(axis[1]) <= tolerance:
                continue
            first_min, first_max = projections(first, axis)
            second_min, second_max = projections(second, axis)
            if first_max <= second_min + tolerance or second_max <= first_min + tolerance:
                return False
    return True


def point_in_convex_polygon(point: tuple[float, float], polygon: list[tuple[float, float]], tolerance: float = GEOMETRY_TOLERANCE) -> bool:
    signs: set[bool] = set()
    for index, first in enumerate(polygon):
        second = polygon[(index + 1) % len(polygon)]
        cross = (second[0] - first[0]) * (point[1] - first[1]) - (second[1] - first[1]) * (point[0] - first[0])
        if abs(cross) > tolerance:
            signs.add(cross > 0)
    return len(signs) <= 1


def polygon_area(points: list[tuple[float, float]]) -> float:
    return abs(sum(
        point[0] * points[(index + 1) % len(points)][1]
        - points[(index + 1) % len(points)][0] * point[1]
        for index, point in enumerate(points)
    )) / 2


def rectangle_polygon(rectangle: list[float], offset: tuple[float, float] = (0.0, 0.0)) -> list[tuple[float, float]]:
    x, y, width, height = rectangle
    x += offset[0]
    y += offset[1]
    return [(x, y), (x + width, y), (x + width, y + height), (x, y + height)]


def rectangle_contains(rectangle: list[float], point: list[float], tolerance: float = GEOMETRY_TOLERANCE) -> bool:
    return (
        rectangle[0] - tolerance <= point[0] <= rectangle[0] + rectangle[2] + tolerance
        and rectangle[1] - tolerance <= point[1] <= rectangle[1] + rectangle[3] + tolerance
    )


def valid_bounds(bounds: object) -> bool:
    return (
        isinstance(bounds, list)
        and finite_values(bounds, 4)
        and float(bounds[0]) < float(bounds[2])
        and float(bounds[1]) < float(bounds[3])
    )


def diamond(half_width: float, half_height: float) -> list[tuple[float, float]]:
    return [(0.0, half_height), (half_width, 0.0), (0.0, -half_height), (-half_width, 0.0)]


def diamond_contains(point: list[float] | tuple[float, float], half_width: float, half_height: float) -> bool:
    return abs(float(point[0])) / half_width + abs(float(point[1])) / half_height <= 1 + GEOMETRY_TOLERANCE


def bounds_overhang(bounds_items: list[list[float]], half_width: float, half_height: float) -> list[float]:
    return [
        max(0.0, -half_width - min(float(bounds[0]) for bounds in bounds_items)),
        max(0.0, max(float(bounds[2]) for bounds in bounds_items) - half_width),
        max(0.0, -half_height - min(float(bounds[1]) for bounds in bounds_items)),
        max(0.0, max(float(bounds[3]) for bounds in bounds_items) - half_height),
    ]


def lod_presentation_bounds(asset: dict[str, object], lod: dict[str, object]) -> list[float]:
    offset_x, offset_y = (float(value) for value in asset["placement_offset_world"])
    anchor_x, anchor_y = (float(value) for value in lod["anchor"])
    width, height = (float(value) for value in lod["world_size"])
    return [
        offset_x - anchor_x * width,
        offset_y - anchor_y * height,
        offset_x + (1 - anchor_x) * width,
        offset_y + (1 - anchor_y) * height,
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures: list[str] = []
    pivot_drift: dict[str, dict[str, float]] = {}
    lod_bounds_error: dict[str, dict[str, float]] = {}
    active_bytes: dict[str, int] = {}
    active_residency: dict[str, dict[str, object]] = {}
    collisions: list[dict[str, object]] = []
    road_collisions: list[dict[str, object]] = []
    entrance_collisions: list[dict[str, object]] = []
    bounds_checks: list[dict[str, object]] = []
    frontage_checks: list[dict[str, object]] = []

    if manifest.get("schema") != 4 or not manifest.get("production_selection"):
        failures.append("manifest is not the approved production schema-4 selection")

    tile_points = manifest.get("world_tile_points")
    if not isinstance(tile_points, list) or not finite_values(tile_points, 2) or min(tile_points) <= 0:
        failures.append("manifest has invalid world tile geometry")
        tile_points = [72.0, 36.0]
    half_width = float(tile_points[0]) / 2
    half_height = float(tile_points[1]) / 2
    footprint_polygon = diamond(half_width, half_height)

    light_direction = str(manifest.get("light_direction", "")).lower()
    if "northwest" not in light_direction or "southeast" not in light_direction:
        failures.append("manifest light direction does not declare northwest key and southeast shadow")

    inventory_names: set[str] = set()
    inventory_by_name: dict[str, dict[str, object]] = {}
    maximum_pixels = manifest.get("page_limit", {}).get("maximum_pixels", [2048, 2048])
    if not finite_values(maximum_pixels, 2) or min(maximum_pixels) <= 0:
        failures.append("manifest page limit has invalid maximum pixel dimensions")
        maximum_pixels = [2048, 2048]
    if int(manifest.get("page_limit", {}).get("active", 0)) > 4:
        failures.append("manifest permits more than four active texture pages")

    for item in manifest.get("inventory", []):
        name = item.get("file")
        if not isinstance(name, str) or not name:
            failures.append("inventory contains an unnamed file")
            continue
        if name in inventory_names:
            failures.append(f"duplicate inventory entry: {name}")
        inventory_names.add(name)
        inventory_by_name[name] = item
        path = ATLAS / name
        if not path.exists():
            failures.append(f"missing inventory file: {name}")
        elif sha256(path) != item.get("sha256"):
            failures.append(f"hash mismatch: {name}")
        pixels = item.get("pixels", [])
        if not finite_values(pixels, 2) or min(pixels) <= 0:
            failures.append(f"invalid inventory pixel dimensions: {name}")
            continue
        if pixels[0] > maximum_pixels[0] or pixels[1] > maximum_pixels[1]:
            failures.append(f"inventory texture exceeds page dimensions: {name}")
        expected_bytes = int(pixels[0]) * int(pixels[1]) * 4
        if item.get("decoded_byte_estimate") != expected_bytes:
            failures.append(f"decoded byte mismatch: {name}")
        if path.exists():
            try:
                actual_pixels = png_dimensions(path)
            except ValueError as error:
                failures.append(f"invalid PNG payload: {name}: {error}")
            else:
                if actual_pixels != (int(pixels[0]), int(pixels[1])):
                    failures.append(
                        f"physical PNG dimensions disagree with inventory: {name}: "
                        f"{actual_pixels} != {(int(pixels[0]), int(pixels[1]))}"
                    )

    logical_ids: set[str] = set()
    residency_ids: set[str] = set()
    physical_assets: list[dict[str, object]] = []
    frontaged_assets: list[dict[str, object]] = []
    referenced_inventory: set[str] = set()
    assets = manifest.get("assets", [])
    for asset in assets:
        logical_id = asset.get("logical_id")
        if not isinstance(logical_id, str) or not logical_id:
            failures.append("manifest contains an asset without a logical ID")
            continue
        if logical_id in logical_ids:
            failures.append(f"duplicate logical ID: {logical_id}")
        logical_ids.add(logical_id)

        residency_id = asset.get("residency_id")
        if not isinstance(residency_id, str) or not residency_id:
            failures.append(f"{logical_id} has no residency identity")
        elif residency_id in residency_ids:
            failures.append(f"duplicate residency identity: {residency_id}")
        else:
            residency_ids.add(residency_id)

        footprint = asset.get("footprint_tiles")
        source_footprint = asset.get("source_footprint_tiles")
        if footprint != [1, 1]:
            failures.append(f"{logical_id} invents multi-tile presentation ownership")
        if (
            not isinstance(source_footprint, list)
            or len(source_footprint) != 2
            or any(not isinstance(value, int) or isinstance(value, bool) or value <= 0 for value in source_footprint)
        ):
            failures.append(f"{logical_id} has invalid source footprint geometry")

        orientation = asset.get("supported_orientation")
        frontage_edge = asset.get("frontage_edge")
        if orientation not in VALID_ORIENTATIONS:
            failures.append(f"{logical_id} has unsupported orientation {orientation!r}")
        if frontage_edge not in VALID_FRONTAGE_EDGES:
            failures.append(f"{logical_id} has unsupported frontage edge {frontage_edge!r}")
        if frontage_edge == "south" and orientation != "south-facing-fixed":
            failures.append(f"{logical_id} south frontage is not south-facing-fixed")
        if frontage_edge == "all-road-sockets" and orientation != "topology-compiled":
            failures.append(f"{logical_id} all-road-sockets asset is not topology-compiled")

        placement_offset = asset.get("placement_offset_world", [])
        source_canvas = asset.get("source_canvas_pixels", [])
        source_pivot = asset.get("ground_pivot_source", [])
        if not finite_values(placement_offset, 2):
            failures.append(f"{logical_id} has invalid world placement offset")
        if not finite_values(source_canvas, 2) or min(source_canvas) <= 0:
            failures.append(f"{logical_id} has invalid source canvas")
        if not finite_values(source_pivot, 2):
            failures.append(f"{logical_id} has invalid source ground pivot")
        elif finite_values(source_canvas, 2) and not (
            0 <= source_pivot[0] <= source_canvas[0]
            and 0 <= source_pivot[1] <= source_canvas[1]
        ):
            failures.append(f"{logical_id} source ground pivot leaves its canvas")

        contact_data = asset.get("ground_contact_polygon_world", [])
        contact: list[tuple[float, float]] = []
        if (
            not isinstance(contact_data, list)
            or len(contact_data) < 4
            or any(not isinstance(point, list) or not finite_values(point, 2) for point in contact_data)
        ):
            failures.append(f"{logical_id} has no valid ground-contact polygon")
        else:
            contact = [(float(point[0]), float(point[1])) for point in contact_data]
            if polygon_area(contact) <= GEOMETRY_TOLERANCE:
                failures.append(f"{logical_id} ground-contact polygon has no area")
            for point in contact:
                if not diamond_contains(point, half_width, half_height):
                    failures.append(f"{logical_id} ground contact leaves its authoritative tile")
                    break

        opaque = asset.get("opaque_bounds_world")
        shadow = asset.get("shadow_bounds_world")
        overhang = asset.get("allowed_overhang_world")
        if not valid_bounds(opaque):
            failures.append(f"{logical_id} has invalid opaque bounds")
        if not valid_bounds(shadow):
            failures.append(f"{logical_id} has invalid shadow bounds")
        if not isinstance(overhang, list) or not finite_values(overhang, 4) or min(overhang) < 0:
            failures.append(f"{logical_id} has invalid allowed overhang")
        if valid_bounds(opaque) and valid_bounds(shadow) and isinstance(overhang, list) and finite_values(overhang, 4):
            measured_overhang = bounds_overhang([opaque, shadow], half_width, half_height)
            overhang_error = max(abs(float(declared) - measured) for declared, measured in zip(overhang, measured_overhang))
            bounds_checks.append({
                "logical_id": logical_id,
                "opaque_bounds_world": opaque,
                "shadow_bounds_world": shadow,
                "declared_overhang_world": overhang,
                "measured_overhang_world": [round(value, 4) for value in measured_overhang],
                "overhang_error_world": round(overhang_error, 6),
            })
            if any(measured > float(declared) + GEOMETRY_TOLERANCE for declared, measured in zip(overhang, measured_overhang)):
                failures.append(f"{logical_id} opaque/shadow bounds exceed declared overhang")
            if overhang_error > GEOMETRY_TOLERANCE:
                failures.append(f"{logical_id} allowed overhang is not registered to its visual bounds")
            if any(float(overhang[index]) > FORBIDDEN_INTRUSION_TOLERANCE_WORLD for index in (0, 1, 2)):
                failures.append(f"{logical_id} declares forbidden lateral or road-edge overhang")

        exclusion_rectangles = asset.get("prop_exclusion_rects_world", [])
        valid_exclusions: list[list[float]] = []
        if not isinstance(exclusion_rectangles, list):
            failures.append(f"{logical_id} has invalid prop exclusion metadata")
        else:
            for index, rectangle in enumerate(exclusion_rectangles):
                if (
                    not isinstance(rectangle, list)
                    or not finite_values(rectangle, 4)
                    or rectangle[2] <= 0
                    or rectangle[3] <= 0
                ):
                    failures.append(f"{logical_id} prop exclusion {index} is invalid")
                    continue
                if (
                    rectangle[0] < -half_width - GEOMETRY_TOLERANCE
                    or rectangle[1] < -half_height - GEOMETRY_TOLERANCE
                    or rectangle[0] + rectangle[2] > half_width + GEOMETRY_TOLERANCE
                    or rectangle[1] + rectangle[3] > half_height + GEOMETRY_TOLERANCE
                ):
                    failures.append(f"{logical_id} prop exclusion {index} leaves its authoritative tile")
                valid_exclusions.append(rectangle)
            for first_index, first in enumerate(valid_exclusions):
                for second_index in range(first_index + 1, len(valid_exclusions)):
                    if polygons_overlap(rectangle_polygon(first), rectangle_polygon(valid_exclusions[second_index])):
                        failures.append(f"{logical_id} prop exclusions {first_index} and {second_index} overlap")

        entrance = asset.get("entrance_socket_world", [])
        setback = asset.get("road_setback_points")
        if frontage_edge != "none":
            frontaged_assets.append(asset)
            socket_failures: list[str] = []
            if not finite_values(entrance, 2) or not diamond_contains(entrance, half_width, half_height):
                socket_failures.append("invalid-or-outside-footprint")
            if not isinstance(setback, (int, float)) or isinstance(setback, bool) or not math.isfinite(float(setback)) or setback < 0:
                socket_failures.append("invalid-road-setback")
            if finite_values(entrance, 2) and isinstance(setback, (int, float)) and not isinstance(setback, bool):
                normalized_radius = abs(float(entrance[0])) / half_width + abs(float(entrance[1])) / half_height
                measured_setback = max(0.0, (1 - normalized_radius) * half_height)
                if abs(measured_setback - float(setback)) > SOCKET_TOLERANCE_WORLD:
                    socket_failures.append("socket-setback-mismatch")
                if frontage_edge == "south" and (entrance[1] >= 0 or abs(float(entrance[0])) > SOCKET_TOLERANCE_WORLD):
                    socket_failures.append("south-socket-misaligned")
            else:
                measured_setback = None
            protected = finite_values(entrance, 2) and any(rectangle_contains(rectangle, entrance) for rectangle in valid_exclusions)
            if not protected:
                socket_failures.append("entrance-not-protected")
            frontage_checks.append({
                "logical_id": logical_id,
                "frontage_edge": frontage_edge,
                "orientation": orientation,
                "entrance_socket_world": entrance,
                "declared_road_setback_points": setback,
                "measured_road_setback_points": None if measured_setback is None else round(measured_setback, 4),
                "protected_by_prop_exclusion": protected,
                "issues": socket_failures,
            })
            for issue in socket_failures:
                failures.append(f"{logical_id} frontage socket {issue}")

        lods = asset.get("lods", {})
        if not isinstance(lods, dict) or set(lods) != set(DETAILS):
            failures.append(f"{logical_id} does not declare exactly the three production LODs")
            lods = lods if isinstance(lods, dict) else {}
        pivot_drift[logical_id] = {}
        lod_bounds_error[logical_id] = {}
        asset_lod_bytes = 0
        for detail in DETAILS:
            lod = lods.get(detail)
            if not isinstance(lod, dict):
                failures.append(f"{logical_id} is missing {detail} LOD")
                continue
            pixels = lod.get("pixels", [])
            trim = lod.get("trim_rect_pixels", [])
            normalized_pixels = lod.get("source_pixels", [])
            normalized_trim = lod.get("source_trim_rect_pixels", [])
            anchor = lod.get("anchor", [])
            world_size = lod.get("world_size", [])
            if not finite_values(pixels, 2) or min(pixels) <= 0:
                failures.append(f"{logical_id}.{detail} has invalid pixel dimensions")
                continue
            if not finite_values(trim, 4) or trim[2] <= 0 or trim[3] <= 0:
                failures.append(f"{logical_id}.{detail} has invalid trim rectangle")
                continue
            if not finite_values(normalized_pixels, 2) or min(normalized_pixels) <= 0:
                failures.append(f"{logical_id}.{detail} has invalid normalized source dimensions")
                continue
            if not finite_values(normalized_trim, 4) or normalized_trim[2] <= 0 or normalized_trim[3] <= 0:
                failures.append(f"{logical_id}.{detail} has invalid normalized source trim")
                continue
            if not finite_values(anchor, 2) or any(value < 0 or value > 1 for value in anchor):
                failures.append(f"{logical_id}.{detail} has invalid anchor")
                continue
            if not finite_values(world_size, 2) or min(world_size) <= 0:
                failures.append(f"{logical_id}.{detail} has invalid world size")
                continue
            pixel_width, pixel_height = (float(value) for value in pixels)
            trim_x, trim_y, trim_width, trim_height = (float(value) for value in trim)
            if not (
                0 <= trim_x < pixel_width
                and 0 <= trim_y < pixel_height
                and trim_x + trim_width <= pixel_width
                and trim_y + trim_height <= pixel_height
            ):
                failures.append(f"{logical_id}.{detail} trim leaves its source canvas")

            if (
                abs(trim_x) > GEOMETRY_TOLERANCE
                or abs(trim_y) > GEOMETRY_TOLERANCE
                or abs(trim_width - pixel_width) > GEOMETRY_TOLERANCE
                or abs(trim_height - pixel_height) > GEOMETRY_TOLERANCE
            ):
                failures.append(f"{logical_id}.{detail} shipping trim does not fill its physical PNG payload")

            normalized_width, normalized_height = (float(value) for value in normalized_pixels)
            normalized_x, normalized_y, normalized_trim_width, normalized_trim_height = (
                float(value) for value in normalized_trim
            )
            if not (
                0 <= normalized_x < normalized_width
                and 0 <= normalized_y < normalized_height
                and normalized_x + normalized_trim_width <= normalized_width
                and normalized_y + normalized_trim_height <= normalized_height
            ):
                failures.append(f"{logical_id}.{detail} normalized trim leaves its immutable source canvas")
            if (
                abs(normalized_trim_width - pixel_width) > GEOMETRY_TOLERANCE
                or abs(normalized_trim_height - pixel_height) > GEOMETRY_TOLERANCE
            ):
                failures.append(f"{logical_id}.{detail} physical payload does not match its normalized source trim")

            if finite_values(source_canvas, 2) and finite_values(source_pivot, 2):
                source_width, source_height = (float(value) for value in source_canvas)
                source_pivot_x, source_pivot_y = (float(value) for value in source_pivot)
                expected_anchor_x = (
                    source_pivot_x * normalized_width / source_width - normalized_x
                ) / normalized_trim_width
                expected_anchor_y = (
                    normalized_y
                    + normalized_trim_height
                    - source_pivot_y * normalized_height / source_height
                ) / normalized_trim_height
                drift_pixels = max(
                    abs(float(anchor[0]) - expected_anchor_x) * normalized_trim_width,
                    abs(float(anchor[1]) - expected_anchor_y) * normalized_trim_height,
                )
                pivot_drift[logical_id][detail] = round(drift_pixels, 6)
                # The production pack intentionally uses one world-space
                # ground pivot across all three LODs.  Integer source trims
                # can place that pivot between source pixels, so retain the
                # source-pixel rounding measurement without treating it as a
                # registration failure.  validate_world_asset_pack.py enforces
                # the authoritative <= 0.5 world-point cross-LOD drift.

            if valid_bounds(opaque) and finite_values(placement_offset, 2):
                presented = lod_presentation_bounds(asset, lod)
                registration_error = max(abs(presented[index] - float(opaque[index])) for index in range(4))
                lod_bounds_error[logical_id][detail] = round(registration_error, 6)
                if registration_error > LOD_BOUNDS_TOLERANCE_WORLD:
                    failures.append(
                        f"{logical_id}.{detail} presentation bounds drift {registration_error:.4f}pt exceeds "
                        f"{LOD_BOUNDS_TOLERANCE_WORLD:.2f}pt"
                    )

            page_file = lod.get("page_file")
            if not isinstance(page_file, str) or not page_file:
                failures.append(f"{logical_id}.{detail} has no packed page")
            else:
                referenced_inventory.add(page_file)
                inventory_item = inventory_by_name.get(page_file)
                if inventory_item is None:
                    failures.append(f"{logical_id}.{detail} page is absent from inventory: {page_file}")
            normalized_relative = lod.get("normalized_file")
            normalized_file = PACKAGE.parent / str(normalized_relative)
            if not normalized_file.exists():
                failures.append(f"{logical_id}.{detail} normalized source file is missing")
            else:
                try:
                    actual_normalized_pixels = png_dimensions(normalized_file)
                except ValueError as error:
                    failures.append(f"{logical_id}.{detail} normalized source is invalid: {error}")
                else:
                    if actual_normalized_pixels != (int(normalized_width), int(normalized_height)):
                        failures.append(
                            f"{logical_id}.{detail} normalized source dimensions disagree with manifest: "
                            f"{actual_normalized_pixels} != {(int(normalized_width), int(normalized_height))}"
                        )
                if sha256(normalized_file) != lod.get("normalized_sha256"):
                    failures.append(f"{logical_id}.{detail} normalized source hash mismatch")
            expected_lod_bytes = int(pixel_width) * int(pixel_height) * 4
            if lod.get("decoded_byte_estimate") != expected_lod_bytes:
                failures.append(f"{logical_id}.{detail} decoded byte estimate is invalid")
            asset_lod_bytes += int(lod.get("decoded_byte_estimate", 0))
        if asset.get("decoded_byte_estimate") != asset_lod_bytes:
            failures.append(f"{logical_id} aggregate decoded byte estimate is invalid")

        if asset.get("family") not in SURFACE_FAMILIES and contact:
            physical_assets.append(asset)

    # Reciprocal lot checks use physical ground contacts.  Vertical roofs are
    # deliberately governed by their declared top overhang and depth role, not
    # misclassified as ground collisions in 2-D screen space.
    for first in physical_assets:
        first_polygon = [(float(point[0]), float(point[1])) for point in first["ground_contact_polygon_world"]]
        for second in physical_assets:
            for offset in NEIGHBOR_OFFSETS:
                overlap = polygons_overlap(
                    first_polygon,
                    translated(second["ground_contact_polygon_world"], offset),
                )
                collision = {
                    "first": first["logical_id"],
                    "second": second["logical_id"],
                    "neighbor_offset": list(offset),
                    "overlap": overlap,
                }
                collisions.append(collision)
                if overlap:
                    failures.append(
                        f"ground collision: {first['logical_id']} / {second['logical_id']} at {offset}"
                    )

    # A neighboring road owns a complete authoritative diamond.  Only
    # positive-area ground overlap is a collision; contact at a reciprocal
    # socket is allowed and separately governed by the declared setback.
    for asset in physical_assets:
        contact = [(float(point[0]), float(point[1])) for point in asset["ground_contact_polygon_world"]]
        for offset in NEIGHBOR_OFFSETS:
            overlap = polygons_overlap(contact, translated(footprint_polygon, offset))
            check = {
                "logical_id": asset["logical_id"],
                "road_neighbor_offset": list(offset),
                "overlap": overlap,
            }
            road_collisions.append(check)
            if overlap:
                failures.append(f"building/road ground collision: {asset['logical_id']} at {offset}")

    # Frontage exclusion zones must remain available when any physical object
    # occupies a reciprocal neighboring tile.  Assets with frontage `none`
    # (including ambient people, vehicles, and vegetation) do not claim an
    # entrance and therefore intentionally skip this rule.
    for asset in frontaged_assets:
        entrance = asset.get("entrance_socket_world", [])
        exclusions = [
            rectangle for rectangle in asset.get("prop_exclusion_rects_world", [])
            if isinstance(rectangle, list) and finite_values(rectangle, 4)
        ]
        for other in frontaged_assets:
            other_exclusions = [
                rectangle for rectangle in other.get("prop_exclusion_rects_world", [])
                if isinstance(rectangle, list) and finite_values(rectangle, 4)
            ]
            for offset in NEIGHBOR_OFFSETS:
                other_contact_data = other.get("ground_contact_polygon_world", [])
                other_contact = translated(other_contact_data, offset)
                entrance_overlap = (
                    finite_values(entrance, 2)
                    and len(other_contact) >= 3
                    and point_in_convex_polygon((float(entrance[0]), float(entrance[1])), other_contact)
                )
                exclusion_overlap = any(
                    polygons_overlap(
                        rectangle_polygon(rectangle),
                        rectangle_polygon(other_rectangle, offset),
                    )
                    for rectangle in exclusions
                    for other_rectangle in other_exclusions
                )
                check = {
                    "frontage": asset["logical_id"],
                    "neighbor": other["logical_id"],
                    "neighbor_offset": list(offset),
                    "entrance_overlap": entrance_overlap,
                    "prop_exclusion_overlap": exclusion_overlap,
                }
                entrance_collisions.append(check)
                if entrance_overlap or exclusion_overlap:
                    failures.append(
                        f"entrance/prop-exclusion collision: {asset['logical_id']} / "
                        f"{other['logical_id']} at {offset}"
                    )

    network = manifest.get("compiled_network", {})
    connection_masks = network.get("connection_masks")
    if connection_masks != 16:
        failures.append("compiled network does not declare all 16 reciprocal road masks")
        connection_masks = int(connection_masks or 0)
    road_lods = network.get("lods", {})
    for detail in DETAILS:
        network_lod = road_lods.get(detail, {})
        road_pixels = network_lod.get("pixels", [])
        if not finite_values(road_pixels, 2) or min(road_pixels) <= 0:
            failures.append(f"compiled network {detail} LOD has invalid pixels")
            road_bytes_per_texture = 0
        else:
            road_bytes_per_texture = int(road_pixels[0]) * int(road_pixels[1]) * 4
            if network_lod.get("decoded_bytes_per_texture") != road_bytes_per_texture:
                failures.append(f"compiled network {detail} decoded byte estimate is invalid")
        road_textures = network_lod.get("textures", {})
        if not isinstance(road_textures, dict) or len(road_textures) != connection_masks:
            failures.append(f"compiled network {detail} does not register all road masks")
            road_textures = road_textures if isinstance(road_textures, dict) else {}
        road_pages = {
            texture.get("page_file")
            for texture in road_textures.values()
            if isinstance(texture, dict) and isinstance(texture.get("page_file"), str)
        }
        referenced_inventory.update(road_pages)
        for page_file in road_pages:
            if page_file not in inventory_by_name:
                failures.append(f"compiled network page is absent from inventory: {page_file}")

        named_assets = []
        for asset in assets:
            lod = asset.get("lods", {}).get(detail, {})
            named_assets.append({
                "residency_id": asset.get("residency_id"),
                "file": lod.get("file"),
                "decoded_bytes": int(lod.get("decoded_byte_estimate", 0)),
            })
        named_assets.sort(key=lambda item: str(item["residency_id"]))
        bytes_for_assets = sum(item["decoded_bytes"] for item in named_assets)
        bytes_for_roads = road_bytes_per_texture * connection_masks
        total_bytes = bytes_for_assets + bytes_for_roads
        active_bytes[detail] = total_bytes
        active_residency[detail] = {
            "asset_texture_count": len(named_assets),
            "network_texture_count": connection_masks,
            "texture_count": len(named_assets) + connection_masks,
            "asset_decoded_bytes": bytes_for_assets,
            "network_decoded_bytes": bytes_for_roads,
            "total_decoded_bytes": total_bytes,
            "target_bytes": TARGET_ACTIVE_BYTES,
            "hard_high_water_bytes": HARD_ACTIVE_BYTES,
            "within_target": total_bytes <= TARGET_ACTIVE_BYTES,
            "named_assets": named_assets,
        }
        if total_bytes > TARGET_ACTIVE_BYTES:
            failures.append(f"{detail} active residency exceeds 96 MiB")
        if total_bytes > HARD_ACTIVE_BYTES:
            failures.append(f"{detail} active residency exceeds 128 MiB hard high-water")

    orphan_inventory = sorted(inventory_names - referenced_inventory)
    missing_inventory_references = sorted(referenced_inventory - inventory_names)
    for name in orphan_inventory:
        failures.append(f"orphan generated-v4 inventory entry: {name}")
    for name in missing_inventory_references:
        failures.append(f"missing generated-v4 inventory entry: {name}")

    report = {
        "schema": 2,
        "manifest_sha256": sha256(MANIFEST),
        "asset_count": len(assets),
        "inventory_count": len(manifest.get("inventory", [])),
        "authoritative_footprint": [1, 1],
        "world_tile_points": [float(tile_points[0]), float(tile_points[1])],
        "light_direction": manifest.get("light_direction"),
        "pivot_drift_pixels": pivot_drift,
        "lod_opaque_bounds_registration_error_world": lod_bounds_error,
        "opaque_shadow_overhang_checks": bounds_checks,
        "frontage_socket_checks": frontage_checks,
        "active_decoded_bytes": active_bytes,
        "active_detail_residency": active_residency,
        "repeated_lod_cycle": ["city", "neighborhood", "block", "neighborhood", "city"],
        "repeated_lod_cycle_high_water_decoded_bytes": max(active_bytes.values(), default=0),
        "reciprocal_ground_collision_checks": len(collisions),
        "reciprocal_ground_collisions": [item for item in collisions if item["overlap"]],
        "building_road_setback_checks": len(road_collisions),
        "building_road_collisions": [item for item in road_collisions if item["overlap"]],
        "entrance_prop_exclusion_neighbor_checks": len(entrance_collisions),
        "entrance_prop_exclusion_collisions": [
            item for item in entrance_collisions
            if item["entrance_overlap"] or item["prop_exclusion_overlap"]
        ],
        "orphan_inventory_entries": orphan_inventory,
        "missing_inventory_references": missing_inventory_references,
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
