#!/usr/bin/env python3
"""Camera-only semantic visibility proof for PLAY-027 North v07."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections import deque
from pathlib import Path
from typing import Any

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


COMPACT_WIDTH = 192
COMPACT_HEIGHT = 128


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


def basis(vector: list[float]) -> list[float]:
    return [float(vector[2]), float(vector[0]), float(vector[1])]


def look_at(obj: Any, target: list[float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def box_mesh(name: str, dimensions: list[float]) -> Any:
    dx, dy, dz = [float(value) / 2.0 for value in dimensions]
    vertices = [
        (-dx, -dy, -dz),
        (dx, -dy, -dz),
        (dx, dy, -dz),
        (-dx, dy, -dz),
        (-dx, -dy, dz),
        (dx, -dy, dz),
        (dx, dy, dz),
        (-dx, dy, dz),
    ]
    faces = [
        (0, 1, 2, 3),
        (4, 7, 6, 5),
        (0, 4, 5, 1),
        (1, 5, 6, 2),
        (2, 6, 7, 3),
        (4, 0, 3, 7),
    ]
    mesh = bpy.data.meshes.new(f"{name}-mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    return mesh


def octagonal_mesh(name: str, dimensions: list[float]) -> Any:
    radius_x = float(dimensions[0]) / 2.0
    radius_y = float(dimensions[1]) / 2.0
    half_height = float(dimensions[2]) / 2.0
    vertices = []
    for height in (-half_height, half_height):
        for index in range(8):
            angle = 2.0 * math.pi * float(index) / 8.0
            vertices.append(
                (
                    math.cos(angle) * radius_x,
                    math.sin(angle) * radius_y,
                    height,
                )
            )
    faces = [tuple(range(7, -1, -1)), tuple(range(8, 16))]
    for index in range(8):
        next_index = (index + 1) % 8
        faces.append((index, next_index, next_index + 8, index + 8))
    mesh = bpy.data.meshes.new(f"{name}-mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    return mesh


def add_component(component: dict[str, Any]) -> Any:
    dimensions_blender = basis(component["dimensions"])
    if component["shape"] == "box":
        mesh = box_mesh(component["id"], dimensions_blender)
    elif component["shape"] == "octagonal-prism":
        mesh = octagonal_mesh(component["id"], dimensions_blender)
    else:
        raise RuntimeError(f"unsupported shape {component['shape']}")
    obj = bpy.data.objects.new(component["id"], mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = basis(component["position"])
    return obj


def configure_camera(scene_record: dict[str, Any]) -> tuple[Any, Any]:
    camera_record = scene_record["camera"]
    scene = bpy.context.scene
    width, height = camera_record["renderViewportPixels"]
    scene.render.resolution_x = int(width)
    scene.render.resolution_y = int(height)
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = 1.0
    scene.render.pixel_aspect_y = 1.0
    data = bpy.data.cameras.new("north-v07-contract-camera")
    data.type = "ORTHO"
    data.ortho_scale = (
        2.0
        * float(camera_record["orthographicScale"])
        * (float(width) / float(height))
    )
    data.shift_x = (
        float(camera_record["postProjectionOffsetPixels"][0]) / float(width)
    )
    data.shift_y = (
        float(camera_record["postProjectionOffsetPixels"][1]) / float(width)
    )
    data.clip_start = 0.1
    data.clip_end = 1000.0
    camera = bpy.data.objects.new("north-v07-contract-camera", data)
    scene.collection.objects.link(camera)
    camera.location = basis(camera_record["positionWorld"])
    look_at(camera, basis(camera_record["targetWorld"]))
    scene.camera = camera
    bpy.context.view_layer.update()
    return scene, camera


def source_pixel(
    scene: Any,
    camera: Any,
    citysim_point: list[float],
) -> list[float]:
    projected = world_to_camera_view(
        scene,
        camera,
        Vector(basis(citysim_point)),
    )
    return [
        round(float(projected.x) * float(scene.render.resolution_x), 12),
        round(
            (1.0 - float(projected.y)) * float(scene.render.resolution_y),
            12,
        ),
    ]


def camera_ray(
    scene: Any,
    camera: Any,
    compact_x: int,
    compact_y: int,
) -> tuple[Vector, Vector]:
    ndc_x = (float(compact_x) + 0.5) / float(COMPACT_WIDTH)
    ndc_y = 1.0 - (float(compact_y) + 0.5) / float(COMPACT_HEIGHT)
    frame = camera.data.view_frame(scene=scene)
    minimum_x = min(point.x for point in frame)
    maximum_x = max(point.x for point in frame)
    minimum_y = min(point.y for point in frame)
    maximum_y = max(point.y for point in frame)
    local_x = minimum_x + (maximum_x - minimum_x) * ndc_x
    local_y = minimum_y + (maximum_y - minimum_y) * ndc_y
    local_origin = Vector((local_x, local_y, -float(camera.data.clip_start)))
    origin = camera.matrix_world @ local_origin
    direction = (
        camera.matrix_world.to_quaternion() @ Vector((0.0, 0.0, -1.0))
    ).normalized()
    return origin, direction


def semantic_raster(scene: Any, camera: Any) -> dict[str, set[tuple[int, int]]]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    result: dict[str, set[tuple[int, int]]] = {}
    for y in range(COMPACT_HEIGHT):
        for x in range(COMPACT_WIDTH):
            origin, direction = camera_ray(scene, camera, x, y)
            hit, _, _, _, obj, _ = scene.ray_cast(
                depsgraph,
                origin,
                direction,
                distance=2000.0,
            )
            if hit and obj is not None:
                result.setdefault(obj.name, set()).add((x, y))
    return result


def pixel_bounds(pixels: set[tuple[int, int]]) -> list[int] | None:
    if not pixels:
        return None
    xs = [point[0] for point in pixels]
    ys = [point[1] for point in pixels]
    return [min(xs), min(ys), max(xs), max(ys)]


def bounds_size(value: list[int] | None) -> list[int]:
    if value is None:
        return [0, 0]
    return [value[2] - value[0] + 1, value[3] - value[1] + 1]


def connected_components(
    pixels: set[tuple[int, int]],
) -> list[set[tuple[int, int]]]:
    remaining = set(pixels)
    components = []
    while remaining:
        start = remaining.pop()
        component = {start}
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    component.add(neighbor)
                    queue.append(neighbor)
        components.append(component)
    return sorted(components, key=len, reverse=True)


def chebyshev_distance(
    point: tuple[int, int],
    pixels: set[tuple[int, int]],
) -> int:
    if not pixels:
        return 1_000_000
    return min(max(abs(point[0] - x), abs(point[1] - y)) for x, y in pixels)


def projected_aabb(
    scene: Any,
    camera: Any,
    minimum: list[float],
    maximum: list[float],
) -> list[int]:
    points = []
    for x in (minimum[0], maximum[0]):
        for y in (minimum[1], maximum[1]):
            for z in (minimum[2], maximum[2]):
                source = source_pixel(scene, camera, [x, y, z])
                points.append(
                    (
                        int(math.floor(source[0] / 8.0)),
                        int(math.floor(source[1] / 8.0)),
                    )
                )
    return [
        min(point[0] for point in points),
        min(point[1] for point in points),
        max(point[0] for point in points),
        max(point[1] for point in points),
    ]


def main() -> None:
    argv = []
    if "--" in __import__("sys").argv:
        argv = __import__("sys").argv[
            __import__("sys").argv.index("--") + 1 :
        ]
    parser = argparse.ArgumentParser()
    parser.add_argument("--scene", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)

    scene_path = args.scene.resolve()
    scene_record = load_json(scene_path)
    for component in scene_record["components"]:
        add_component(component)
    scene, camera = configure_camera(scene_record)
    semantic = semantic_raster(scene, camera)
    targets = scene_record["visibilityTargets"]

    registration = scene_record["registration"]
    contact_world = [
        [point[0], 0, point[1]]
        for point in registration["contactPolygonWorld"]
    ]
    actual_footprint = [
        source_pixel(scene, camera, point) for point in contact_world
    ]
    expected_footprint = registration["footprintPolygonSource"]
    footprint_deltas = [
        [
            abs(actual[0] - expected[0]),
            abs(actual[1] - expected[1]),
        ]
        for actual, expected in zip(actual_footprint, expected_footprint)
    ]
    pivot_actual = source_pixel(
        scene,
        camera,
        registration["groundPivotWorld"],
    )
    pivot_delta = [
        abs(pivot_actual[index] - registration["groundPivotSource"][index])
        for index in range(2)
    ]
    socket_actual = source_pixel(
        scene,
        camera,
        registration["frontageSocketWorld"],
    )
    socket_delta = [
        abs(socket_actual[index] - registration["frontageSocketSource"][index])
        for index in range(2)
    ]
    source_socket = registration["frontageSocketSource"]
    compact_socket = (
        int(round(float(source_socket[0]) / 8.0)),
        int(round(float(source_socket[1]) / 8.0)),
    )

    court_pixels = set()
    for component_id in targets["courtComponentIDs"]:
        court_pixels.update(semantic.get(component_id, set()))
    court_components = connected_components(court_pixels)
    largest_court = court_components[0] if court_components else set()
    court_socket_distance = chebyshev_distance(compact_socket, largest_court)

    frame_ids = scene_record["architecture"]["monumentalThroatFrameIDs"]
    frame_visibility = {
        component_id: {
            "visiblePixels": len(semantic.get(component_id, set())),
            "bounds": pixel_bounds(semantic.get(component_id, set())),
            "boundsSize": bounds_size(
                pixel_bounds(semantic.get(component_id, set()))
            ),
        }
        for component_id in frame_ids
    }
    aperture_bounds = projected_aabb(
        scene,
        camera,
        *targets["throatApertureCitySimAABB"],
    )
    aperture_court_pixels = {
        point
        for point in court_pixels
        if aperture_bounds[0] <= point[0] <= aperture_bounds[2]
        and aperture_bounds[1] <= point[1] <= aperture_bounds[3]
    }
    aperture_visible_bounds = pixel_bounds(aperture_court_pixels)
    aperture_visible_size = bounds_size(aperture_visible_bounds)

    reveal_ids = [
        "north-v07-throat-reveal-west",
        "north-v07-throat-reveal-east",
        "north-v07-throat-inner-header",
    ]
    visible_reveal_count = sum(
        1 for component_id in reveal_ids if semantic.get(component_id)
    )
    freight_ids = scene_record["architecture"]["freightRecessIDs"]
    visible_freight_count = sum(
        1 for component_id in freight_ids if semantic.get(component_id)
    )
    monitor_ids = [
        component["id"]
        for component in scene_record["components"]
        if component["group"] == "roof-monitor"
    ]
    visible_monitor_count = sum(
        1 for component_id in monitor_ids if semantic.get(component_id)
    )
    staff_id = targets["staffEntryComponentID"]
    staff_pixels = semantic.get(staff_id, set())
    staff_size = bounds_size(pixel_bounds(staff_pixels))

    group_top_heights: dict[str, float] = {}
    for component in scene_record["components"]:
        top = float(component["position"][1]) + float(
            component["dimensions"][1]
        ) / 2.0
        group_top_heights[component["group"]] = max(
            group_top_heights.get(component["group"], 0.0),
            top,
        )
    height_tiers = sorted(
        {
            round(value, 3)
            for value in group_top_heights.values()
            if value >= 14.0
        }
    )

    all_pixels = set().union(*semantic.values()) if semantic else set()
    occupied_bounds = pixel_bounds(all_pixels)
    occupied_size = bounds_size(occupied_bounds)
    registration_maximum = max(
        [max(value) for value in footprint_deltas]
        + [max(pivot_delta), max(socket_delta)]
    )
    frame_minimum = int(targets["minimumFrameThicknessPixels"])
    jamb_sizes = [
        frame_visibility["north-v07-throat-jamb-west"]["boundsSize"],
        frame_visibility["north-v07-throat-jamb-east"]["boundsSize"],
    ]
    header_size = frame_visibility["north-v07-throat-header"]["boundsSize"]
    passed = (
        registration_maximum <= 0.001
        and len(largest_court) >= targets["minimumVisibleCourtPixels"]
        and court_socket_distance <= targets["maximumSocketDistancePixels"]
        and aperture_visible_size[0]
        >= targets["minimumThroatCompactBounds"][0]
        and aperture_visible_size[1]
        >= targets["minimumThroatCompactBounds"][1]
        and all(
            size[0] >= frame_minimum and size[1] >= frame_minimum
            for size in jamb_sizes
        )
        and header_size[0] >= frame_minimum
        and header_size[1] >= frame_minimum
        and visible_reveal_count >= targets["minimumVisibleRevealCount"]
        and visible_freight_count
        >= targets["minimumVisibleFreightRecessCount"]
        and visible_monitor_count >= targets["minimumVisibleMonitorCount"]
        and staff_size[0] >= targets["minimumStaffCompactBounds"][0]
        and staff_size[1] >= targets["minimumStaffCompactBounds"][1]
        and len(height_tiers) >= targets["minimumSilhouetteHeightBreakCount"]
        and occupied_size[0] >= 56
        and occupied_size[1] >= 49
    )

    report = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "predesign-actual-camera",
        "sceneSHA256": sha256(scene_path),
        "proofToolSHA256": sha256(Path(__file__).resolve()),
        "coordinateBridge": scene_record["coordinateBridge"],
        "camera": {
            "citySimPosition": scene_record["camera"]["positionWorld"],
            "citySimTarget": scene_record["camera"]["targetWorld"],
            "blenderPosition": [
                round(float(value), 12) for value in camera.location
            ],
            "orthographicScale": round(
                float(camera.data.ortho_scale),
                12,
            ),
            "shiftY": round(float(camera.data.shift_y), 12),
        },
        "registration": {
            "descriptorOrder": scene_record["coordinateBridge"][
                "descriptorOrder"
            ],
            "footprintExpectedSource": expected_footprint,
            "footprintActualSource": actual_footprint,
            "footprintAbsoluteDeltaSourcePixels": footprint_deltas,
            "pivotExpectedSource": registration["groundPivotSource"],
            "pivotActualSource": pivot_actual,
            "pivotAbsoluteDeltaSourcePixels": pivot_delta,
            "socketExpectedSource": registration["frontageSocketSource"],
            "socketActualSource": socket_actual,
            "socketAbsoluteDeltaSourcePixels": socket_delta,
            "maximumAbsoluteDeltaSourcePixels": registration_maximum,
        },
        "court": {
            "componentIDs": targets["courtComponentIDs"],
            "visiblePixels": len(court_pixels),
            "connectedComponentCount": len(court_components),
            "largestConnectedVisiblePixels": len(largest_court),
            "largestBounds": pixel_bounds(largest_court),
            "compactSocket": list(compact_socket),
            "socketDistancePixels": court_socket_distance,
            "touchesCanonicalNorthSocket": court_socket_distance
            <= targets["maximumSocketDistancePixels"],
        },
        "monumentalThroat": {
            "apertureProjectedBounds": aperture_bounds,
            "visibleCourtPixelsInsideAperture": len(aperture_court_pixels),
            "visibleApertureBounds": aperture_visible_bounds,
            "visibleApertureBoundsSize": aperture_visible_size,
            "frame": frame_visibility,
            "visibleRevealCount": visible_reveal_count,
        },
        "freightRecesses": {
            "componentIDs": freight_ids,
            "visibleCount": visible_freight_count,
            "perComponentVisiblePixels": {
                component_id: len(semantic.get(component_id, set()))
                for component_id in freight_ids
            },
        },
        "staffEntry": {
            "componentID": staff_id,
            "visiblePixels": len(staff_pixels),
            "bounds": pixel_bounds(staff_pixels),
            "boundsSize": staff_size,
        },
        "roofAndSilhouette": {
            "monitorIDs": monitor_ids,
            "visibleMonitorCount": visible_monitor_count,
            "heightTiersWorld": height_tiers,
            "heightBreakCount": len(height_tiers),
            "occupiedCompactBounds": occupied_bounds,
            "occupiedCompactBoundsSize": occupied_size,
        },
        "semanticVisiblePixelCounts": {
            key: len(value) for key, value in sorted(semantic.items())
        },
        "pixelInvocationCounts": {
            "render": 0,
            "imageGen": 0,
            "normalizer": 0,
            "contactSheet": 0,
            "raw": 0,
        },
        "sourceAuthority": False,
        "productionSelected": False,
        "validationPassed": passed,
    }
    write_json(args.output.resolve(), report)
    if not passed:
        raise RuntimeError("North v07 actual-camera predesign proof failed")
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
