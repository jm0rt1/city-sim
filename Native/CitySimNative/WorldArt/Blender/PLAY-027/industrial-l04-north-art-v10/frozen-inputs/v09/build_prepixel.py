#!/usr/bin/env python3
"""Deterministic no-DCC analytic preview and validator for PLAY-027 North v09."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import zlib
from pathlib import Path
from typing import Any


BACKGROUND = (48, 52, 50, 255)
BRIDGE_SHA = "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
EXPECTED_PIVOT = [768, 896]
EXPECTED_SOCKET = [896, 704]
EXPECTED_FOOTPRINT = [[768, 640], [1024, 768], [768, 896], [512, 768]]
VIEW = (96.0, 78.3836717690617, 96.0)
VIEW_LENGTH = math.sqrt(sum(value * value for value in VIEW))
FORWARD = tuple(-value / VIEW_LENGTH for value in VIEW)
SEMANTIC_COLORS = {
    "foundation": (83, 91, 87, 255),
    "operating-court": (112, 104, 83, 255),
    "primary-mass": (177, 116, 72, 255),
    "roof-edge": (133, 177, 163, 255),
    "roof-equipment": (107, 146, 122, 255),
    "facade-articulation": (218, 178, 92, 255),
    "integrated-portal": (238, 154, 61, 255),
    "freight-recess": (34, 40, 41, 255),
    "freight-frame": (218, 164, 77, 255),
    "subordinate-gantry": (75, 102, 105, 255),
    "hot-process": (246, 118, 34, 255),
    "stack-and-boiler": (72, 88, 89, 255),
    "staff-entry": (221, 198, 112, 255),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    rows = bytearray()
    stride = width * 4
    for y in range(height):
        rows.append(0)
        rows.extend(rgba[y * stride : (y + 1) * stride])
    payload = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(
            b"IHDR",
            struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0),
        )
        + png_chunk(b"IDAT", zlib.compress(bytes(rows), level=9))
        + png_chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path: Path) -> tuple[int, int, bytes]:
    payload = path.read_bytes()
    if payload[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError(f"not PNG: {path}")
    offset = 8
    width = height = color_type = 0
    compressed = bytearray()
    while offset < len(payload):
        length = struct.unpack(">I", payload[offset : offset + 4])[0]
        kind = payload[offset + 4 : offset + 8]
        body = payload[offset + 8 : offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, depth, color_type, _, _, _ = struct.unpack(
                ">IIBBBBB", body
            )
            if depth != 8 or color_type not in (2, 6):
                raise RuntimeError(f"unsupported PNG format: {path}")
        elif kind == b"IDAT":
            compressed.extend(body)
        elif kind == b"IEND":
            break
    channels = 4 if color_type == 6 else 3
    raw = zlib.decompress(bytes(compressed))
    stride = width * channels
    prior = bytearray(stride)
    decoded = bytearray()
    cursor = 0
    for _ in range(height):
        filter_kind = raw[cursor]
        cursor += 1
        row = bytearray(raw[cursor : cursor + stride])
        cursor += stride
        for index in range(stride):
            left = row[index - channels] if index >= channels else 0
            above = prior[index]
            upper_left = prior[index - channels] if index >= channels else 0
            if filter_kind == 1:
                row[index] = (row[index] + left) & 0xFF
            elif filter_kind == 2:
                row[index] = (row[index] + above) & 0xFF
            elif filter_kind == 3:
                row[index] = (row[index] + ((left + above) // 2)) & 0xFF
            elif filter_kind == 4:
                row[index] = (
                    row[index] + paeth(left, above, upper_left)
                ) & 0xFF
            elif filter_kind != 0:
                raise RuntimeError(f"unsupported PNG filter {filter_kind}")
        prior = row
        if channels == 4:
            decoded.extend(row)
        else:
            for index in range(0, len(row), 3):
                decoded.extend(row[index : index + 3])
                decoded.append(255)
    return width, height, bytes(decoded)


def vector_sub(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
) -> tuple[float, float, float]:
    return tuple(first[index] - second[index] for index in range(3))


def cross(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
) -> tuple[float, float, float]:
    return (
        first[1] * second[2] - first[2] * second[1],
        first[2] * second[0] - first[0] * second[2],
        first[0] * second[1] - first[1] * second[0],
    )


def normalize(
    value: tuple[float, float, float],
) -> tuple[float, float, float]:
    length = math.sqrt(sum(component * component for component in value))
    return tuple(component / length for component in value)


def dot(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
) -> float:
    return sum(first[index] * second[index] for index in range(3))


def project(
    point: tuple[float, float, float],
    scale: float,
) -> tuple[float, float, float]:
    x, y, z = point
    source_x = 768.0 + (x - z) * (256.0 / 56.0)
    source_y = 768.0 + (x + z) * (128.0 / 56.0) - y * 5.598
    depth = dot(point, FORWARD)
    return source_x * scale, source_y * scale, depth


def component_mesh(
    component: dict[str, Any],
) -> tuple[
    list[tuple[float, float, float]],
    list[tuple[int, ...]],
]:
    px, py, pz = (float(value) for value in component["position"])
    dx, dy, dz = (float(value) / 2.0 for value in component["dimensions"])
    if component["shape"] == "box":
        vertices = [
            (px - dx, py - dy, pz - dz),
            (px + dx, py - dy, pz - dz),
            (px + dx, py - dy, pz + dz),
            (px - dx, py - dy, pz + dz),
            (px - dx, py + dy, pz - dz),
            (px + dx, py + dy, pz - dz),
            (px + dx, py + dy, pz + dz),
            (px - dx, py + dy, pz + dz),
        ]
        faces = [
            (0, 3, 2, 1),
            (4, 5, 6, 7),
            (0, 1, 5, 4),
            (1, 2, 6, 5),
            (2, 3, 7, 6),
            (3, 0, 4, 7),
        ]
        return vertices, faces
    if component["shape"] != "octagonal-prism":
        raise RuntimeError(f"unsupported shape {component['shape']}")
    vertices = []
    for height in (py - dy, py + dy):
        for index in range(8):
            angle = 2.0 * math.pi * float(index) / 8.0
            vertices.append(
                (
                    px + math.cos(angle) * dx,
                    height,
                    pz + math.sin(angle) * dz,
                )
            )
    faces = [tuple(range(7, -1, -1)), tuple(range(8, 16))]
    for index in range(8):
        following = (index + 1) % 8
        faces.append((index, following, following + 8, index + 8))
    return vertices, faces


def triangle_area(
    a: tuple[float, float],
    b: tuple[float, float],
    c: tuple[float, float],
) -> float:
    return (
        (b[0] - a[0]) * (c[1] - a[1])
        - (b[1] - a[1]) * (c[0] - a[0])
    )


def render(
    scene: dict[str, Any],
    materials: dict[str, Any],
    width: int,
    height: int,
) -> tuple[bytes, list[str | None], list[str | None]]:
    scale = float(width) / 1536.0
    pixels = bytearray(BACKGROUND * (width * height))
    depths = [float("inf")] * (width * height)
    owners: list[str | None] = [None] * (width * height)
    groups: list[str | None] = [None] * (width * height)
    material_by_id = {
        material["id"]: material for material in materials["materials"]
    }
    light = normalize((-1.0, 1.5, -1.0))
    triangles = []
    for component in scene["components"]:
        vertices, faces = component_mesh(component)
        projected = [project(vertex, scale) for vertex in vertices]
        material = material_by_id[component["materialID"]]
        base = tuple(
            int(round(float(value) * 255.0))
            for value in material["baseColorRGBA"][:3]
        )
        for face in faces:
            p0, p1, p2 = (
                vertices[face[0]],
                vertices[face[1]],
                vertices[face[2]],
            )
            normal = normalize(cross(vector_sub(p1, p0), vector_sub(p2, p0)))
            if dot(normal, VIEW) <= 0.0:
                continue
            shade = 0.55 + 0.45 * max(0.0, dot(normal, light))
            color = tuple(
                max(0, min(255, int(round(channel * shade))))
                for channel in base
            ) + (255,)
            for index in range(1, len(face) - 1):
                triangles.append(
                    (
                        component,
                        color,
                        projected[face[0]],
                        projected[face[index]],
                        projected[face[index + 1]],
                    )
                )
    for component, color, first, second, third in triangles:
        a = (first[0], first[1])
        b = (second[0], second[1])
        c = (third[0], third[1])
        area = triangle_area(a, b, c)
        if abs(area) < 0.000001:
            continue
        min_x = max(0, int(math.floor(min(a[0], b[0], c[0]))))
        max_x = min(width - 1, int(math.ceil(max(a[0], b[0], c[0]))))
        min_y = max(0, int(math.floor(min(a[1], b[1], c[1]))))
        max_y = min(height - 1, int(math.ceil(max(a[1], b[1], c[1]))))
        for y in range(min_y, max_y + 1):
            for x in range(min_x, max_x + 1):
                point = (float(x) + 0.5, float(y) + 0.5)
                w0 = triangle_area(b, c, point) / area
                w1 = triangle_area(c, a, point) / area
                w2 = triangle_area(a, b, point) / area
                if min(w0, w1, w2) < -0.000001:
                    continue
                depth = w0 * first[2] + w1 * second[2] + w2 * third[2]
                offset = y * width + x
                if depth >= depths[offset]:
                    continue
                depths[offset] = depth
                owners[offset] = component["id"]
                groups[offset] = component["group"]
                rgba_offset = offset * 4
                pixels[rgba_offset : rgba_offset + 4] = bytes(color)
    return bytes(pixels), owners, groups


def grayscale(rgba: bytes) -> bytes:
    result = bytearray(rgba)
    for index in range(0, len(result), 4):
        value = (
            54 * result[index]
            + 183 * result[index + 1]
            + 19 * result[index + 2]
            + 128
        ) // 256
        result[index : index + 3] = bytes((value, value, value))
    return bytes(result)


def semantic_image(groups: list[str | None]) -> bytes:
    result = bytearray(BACKGROUND * len(groups))
    for index, group in enumerate(groups):
        if group is None:
            continue
        result[index * 4 : index * 4 + 4] = bytes(
            SEMANTIC_COLORS.get(group, (235, 235, 235, 255))
        )
    return bytes(result)


def silhouette_image(owners: list[str | None]) -> bytes:
    result = bytearray((20, 22, 21, 255) * len(owners))
    for index, owner in enumerate(owners):
        if owner is not None:
            result[index * 4 : index * 4 + 4] = bytes((232, 232, 228, 255))
    return bytes(result)


def bounds_for(indices: list[int], width: int) -> list[int] | None:
    if not indices:
        return None
    xs = [index % width for index in indices]
    ys = [index // width for index in indices]
    return [min(xs), min(ys), max(xs) + 1, max(ys) + 1]


def luma_values(
    rgba: bytes,
    indices: list[int],
) -> list[int]:
    result = []
    for index in indices:
        offset = index * 4
        result.append(
            (
                54 * rgba[offset]
                + 183 * rgba[offset + 1]
                + 19 * rgba[offset + 2]
                + 128
            )
            // 256
        )
    return sorted(result)


def median(values: list[int]) -> int:
    if not values:
        return 0
    return values[len(values) // 2]


def component_bounds(component: dict[str, Any]) -> tuple[list[float], list[float]]:
    minimum = [
        float(component["position"][axis])
        - float(component["dimensions"][axis]) / 2.0
        for axis in range(3)
    ]
    maximum = [
        float(component["position"][axis])
        + float(component["dimensions"][axis]) / 2.0
        for axis in range(3)
    ]
    return minimum, maximum


def overlap(
    first: tuple[list[float], list[float]],
    second: tuple[list[float], list[float]],
) -> list[float]:
    return [
        min(first[1][axis], second[1][axis])
        - max(first[0][axis], second[0][axis])
        for axis in range(3)
    ]


def structural_validation(scene: dict[str, Any]) -> dict[str, Any]:
    components = scene["components"]
    bounds = {component["id"]: component_bounds(component) for component in components}
    footprint_violations = [
        component["id"]
        for component in components
        if bounds[component["id"]][0][0] < -28.000001
        or bounds[component["id"]][1][0] > 28.000001
        or bounds[component["id"]][0][2] < -28.000001
        or bounds[component["id"]][1][2] > 28.000001
        or bounds[component["id"]][0][1] < -0.000001
    ]
    primary = [component for component in components if component["group"] == "primary-mass"]
    primary_overlaps = []
    for index, first in enumerate(primary):
        for second in primary[index + 1 :]:
            amount = overlap(bounds[first["id"]], bounds[second["id"]])
            if min(amount) > 0.001:
                primary_overlaps.append(
                    {"first": first["id"], "second": second["id"], "overlap": amount}
                )
    structural_groups = {"primary-mass", "roof-edge", "roof-equipment", "stack-and-boiler"}
    structural = [component for component in components if component["group"] in structural_groups]
    plane_conflicts = []
    for index, first in enumerate(structural):
        for second in structural[index + 1 :]:
            first_bounds = bounds[first["id"]]
            second_bounds = bounds[second["id"]]
            for axis in range(3):
                others = [value for value in range(3) if value != axis]
                shared = [
                    min(first_bounds[1][value], second_bounds[1][value])
                    - max(first_bounds[0][value], second_bounds[0][value])
                    for value in others
                ]
                if min(shared) <= 0.001:
                    continue
                faces = [
                    (first_bounds[0][axis], second_bounds[0][axis]),
                    (first_bounds[0][axis], second_bounds[1][axis]),
                    (first_bounds[1][axis], second_bounds[0][axis]),
                    (first_bounds[1][axis], second_bounds[1][axis]),
                ]
                if any(abs(left - right) <= 0.000001 for left, right in faces):
                    plane_conflicts.append(
                        {
                            "first": first["id"],
                            "second": second["id"],
                            "axis": axis,
                            "overlapOnOtherAxes": shared,
                        }
                    )
    return {
        "footprintViolations": footprint_violations,
        "primaryVolumeOverlaps": primary_overlaps,
        "coincidentVisiblePlanes": plane_conflicts,
        "passed": not footprint_violations and not primary_overlaps and not plane_conflicts,
    }


def crop_left_half(path: Path) -> bytes:
    width, height, rgba = read_png(path)
    if width != 384 or height != 128:
        raise RuntimeError("accepted L3 comparison dimensions changed")
    result = bytearray()
    for y in range(height):
        offset = y * width * 4
        result.extend(rgba[offset : offset + 192 * 4])
    return bytes(result)


def side_by_side(left: bytes, right: bytes, width: int, height: int) -> bytes:
    result = bytearray()
    stride = width * 4
    for y in range(height):
        result.extend(left[y * stride : (y + 1) * stride])
        result.extend(right[y * stride : (y + 1) * stride])
    return bytes(result)


def analyze(
    scene: dict[str, Any],
    rgba: bytes,
    owners: list[str | None],
    groups: list[str | None],
    accepted_l3: bytes,
) -> dict[str, Any]:
    component_ids = {component["id"] for component in scene["components"]}
    component_pixels = {
        component_id: [
            index for index, owner in enumerate(owners) if owner == component_id
        ]
        for component_id in component_ids
    }
    group_pixels = {
        group: [index for index, value in enumerate(groups) if value == group]
        for group in sorted({value for value in groups if value is not None})
    }
    occupied = [index for index, owner in enumerate(owners) if owner is not None]
    occupied_bounds = bounds_for(occupied, 192)
    if occupied_bounds is None:
        raise RuntimeError("empty analytic preview")
    occupied_size = [
        occupied_bounds[2] - occupied_bounds[0],
        occupied_bounds[3] - occupied_bounds[1],
    ]
    component_metrics = {}
    for component_id, indices in sorted(component_pixels.items()):
        component_metrics[component_id] = {
            "exactSemanticCorePixels": len(indices),
            "bounds": bounds_for(indices, 192),
            "medianLuma": median(luma_values(rgba, indices)),
        }
    group_medians = {
        group: median(luma_values(rgba, indices))
        for group, indices in group_pixels.items()
    }
    primary_facade = [
        index
        for index, owner in enumerate(owners)
        if owner is not None
        and next(
            component for component in scene["components"] if component["id"] == owner
        )["materialID"]
        == "v09-warm-foundry-masonry"
    ]
    freight_frame = group_pixels.get("freight-frame", [])
    heat_band = component_pixels["north-v09-furnace-heat-band"]
    furnace_surround = []
    for name in (
        "north-v09-furnace-body",
        "north-v09-furnace-shoulder",
        "north-v09-furnace-mouth",
    ):
        furnace_surround.extend(component_pixels[name])
    tier_ids = {
        "primaryFacade": {"v09-warm-foundry-masonry"},
        "roofHighBay": {"v09-bluegreen-roof", "v09-roof-edge"},
        "equipmentProcess": {"v09-oxidized-machinery"},
    }
    component_by_id = {component["id"]: component for component in scene["components"]}
    tiers = {}
    for name, material_ids in tier_ids.items():
        indices = [
            index
            for index, owner in enumerate(owners)
            if owner is not None
            and component_by_id[owner]["materialID"] in material_ids
        ]
        tiers[name] = {
            "pixels": len(indices),
            "medianLuma": median(luma_values(rgba, indices)),
        }
    l3_occupied = []
    l3_luma = []
    for index in range(192 * 128):
        offset = index * 4
        rgb = accepted_l3[offset : offset + 3]
        if sum((int(rgb[channel]) - BACKGROUND[channel]) ** 2 for channel in range(3)) > 16:
            l3_occupied.append(index)
            l3_luma.append(
                (54 * rgb[0] + 183 * rgb[1] + 19 * rgb[2] + 128) // 256
            )
    l3_bounds = bounds_for(l3_occupied, 192)
    portal_jambs = [
        component_metrics["north-v09-portal-jamb-west"]["exactSemanticCorePixels"],
        component_metrics["north-v09-portal-jamb-east"]["exactSemanticCorePixels"],
    ]
    freight_delta = median(luma_values(rgba, freight_frame)) - median(
        luma_values(rgba, primary_facade)
    )
    hot_delta = median(luma_values(rgba, heat_band)) - median(
        luma_values(rgba, furnace_surround)
    )
    tier_values = sorted(value["medianLuma"] for value in tiers.values())
    tier_gaps = [
        tier_values[index + 1] - tier_values[index]
        for index in range(len(tier_values) - 1)
    ]
    gates = {
        "bothPortalJambsAtLeastEightPixels": min(portal_jambs) >= 8,
        "freightFrameAtLeastFifteenAboveFacade": freight_delta >= 15,
        "hotProcessAtLeastThirtyAboveSurround": hot_delta >= 30,
        "threeCoherentGrayscaleMassTiers": min(tier_gaps) >= 12,
        "compactEnvelopeAtMost64x60": occupied_size[0] <= 64 and occupied_size[1] <= 60,
        "compactEnvelopeAtLeastNinetyFivePercentL3OccupiedPixels": (
            len(occupied) >= int(math.ceil(float(len(l3_occupied)) * 0.95))
        ),
        "portalFrameComplete": all(
            component_metrics[name]["exactSemanticCorePixels"] > 0
            for name in (
                "north-v09-portal-jamb-west",
                "north-v09-portal-jamb-east",
                "north-v09-portal-header",
                "north-v09-portal-inset",
            )
        ),
        "threeFreightRecessesVisible": all(
            component_metrics[f"north-v09-freight-recess-{suffix}"][
                "exactSemanticCorePixels"
            ]
            >= 8
            for suffix in ("a", "b", "c")
        ),
    }
    return {
        "analyticOnly": True,
        "sourceAuthority": False,
        "productionSelected": False,
        "rawProcessCount": 0,
        "dccProcessCount": 0,
        "normalizerProcessCount": 0,
        "occupied": {
            "bounds": occupied_bounds,
            "size": occupied_size,
            "pixels": len(occupied),
        },
        "acceptedL3": {
            "bounds": l3_bounds,
            "pixels": len(l3_occupied),
            "medianLuma": median(sorted(l3_luma)),
        },
        "portalJambCorePixels": portal_jambs,
        "freightFrameMinusFacadeMedianLuma": freight_delta,
        "hotProcessMinusFurnaceSurroundMedianLuma": hot_delta,
        "grayscaleTiers": tiers,
        "grayscaleTierGaps": tier_gaps,
        "groupMedianLuma": group_medians,
        "components": component_metrics,
        "gates": gates,
        "twoSecondRecognitionSurrogatePassed": all(gates.values()),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scene", type=Path, required=True)
    parser.add_argument("--materials", type=Path, required=True)
    parser.add_argument("--accepted-l3-comparison", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    scene = load_json(args.scene)
    materials = load_json(args.materials)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if scene["coordinateBridge"]["sha256"] != BRIDGE_SHA:
        raise RuntimeError("coordinate bridge drift")
    if scene["materialLibrary"]["sha256"] != sha256(args.materials):
        raise RuntimeError("material hash drift")
    if scene["registration"]["groundPivotSource"] != EXPECTED_PIVOT:
        raise RuntimeError("pivot drift")
    if scene["registration"]["frontageSocketSource"] != EXPECTED_SOCKET:
        raise RuntimeError("socket drift")
    if scene["registration"]["footprintPolygonSource"] != EXPECTED_FOOTPRINT:
        raise RuntimeError("footprint drift")
    if scene["pixelProduction"] != "not_produced":
        raise RuntimeError("pixel-production boundary violated")
    structural = structural_validation(scene)
    source_rgba, _, _ = render(scene, materials, 1536, 1024)
    literal_rgba, literal_owners, literal_groups = render(
        scene, materials, 192, 128
    )
    accepted_l3 = crop_left_half(args.accepted_l3_comparison)
    metrics = analyze(
        scene,
        literal_rgba,
        literal_owners,
        literal_groups,
        accepted_l3,
    )
    metrics["structuralValidation"] = structural
    metrics["sceneSHA256"] = sha256(args.scene)
    metrics["materialsSHA256"] = sha256(args.materials)
    metrics["validationPassed"] = (
        structural["passed"]
        and metrics["twoSecondRecognitionSurrogatePassed"]
    )
    write_png(output / "SOURCE-COLOR.png", 1536, 1024, source_rgba)
    write_png(
        output / "SOURCE-GRAYSCALE.png",
        1536,
        1024,
        grayscale(source_rgba),
    )
    write_png(output / "EXACT-192-COLOR.png", 192, 128, literal_rgba)
    write_png(
        output / "EXACT-192-GRAYSCALE.png",
        192,
        128,
        grayscale(literal_rgba),
    )
    write_png(
        output / "EXACT-192-SEMANTIC.png",
        192,
        128,
        semantic_image(literal_groups),
    )
    silhouette = silhouette_image(literal_owners)
    write_png(output / "EXACT-192-SILHOUETTE.png", 192, 128, silhouette)
    write_png(
        output / "ACCEPTED-L3-VS-V09-COLOR.png",
        384,
        128,
        side_by_side(accepted_l3, literal_rgba, 192, 128),
    )
    write_png(
        output / "ACCEPTED-L3-VS-V09-GRAYSCALE.png",
        384,
        128,
        side_by_side(grayscale(accepted_l3), grayscale(literal_rgba), 192, 128),
    )
    l3_owner = [
        None
        if sum(
            (
                int(accepted_l3[index * 4 + channel]) - BACKGROUND[channel]
            )
            ** 2
            for channel in range(3)
        )
        <= 16
        else "accepted-l3"
        for index in range(192 * 128)
    ]
    write_png(
        output / "ACCEPTED-L3-VS-V09-SILHOUETTE.png",
        384,
        128,
        side_by_side(
            silhouette_image(l3_owner),
            silhouette,
            192,
            128,
        ),
    )
    write_json(output / "METRICS.json", metrics)
    if not metrics["validationPassed"]:
        raise RuntimeError("v09 analytic validation failed")


if __name__ == "__main__":
    main()
