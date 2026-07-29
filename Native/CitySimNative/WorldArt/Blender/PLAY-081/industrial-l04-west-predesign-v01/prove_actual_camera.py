#!/usr/bin/env python3
"""Build the PLAY-081 scene in Blender and emit projection-only proof.

This script never calls bpy.ops.render and never writes an image.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    values = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--scene", required=True)
    parser.add_argument("--materials", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args(values)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def citysim_to_blender(point: list[float]) -> Vector:
    # The accepted DCC camera binding reflects CitySim X into Blender X while
    # mapping CitySim ground-Z to Blender depth-Y and CitySim Y-up to Blender Z.
    # This preserves the published source registration handedness.
    return Vector((-point[0], point[2], point[1]))


def source_point(scene: bpy.types.Scene, camera: bpy.types.Object, point: list[float]) -> list[float]:
    normalized = world_to_camera_view(scene, camera, citysim_to_blender(point))
    return [
        normalized.x * scene.render.resolution_x,
        (1.0 - normalized.y) * scene.render.resolution_y,
    ]


def rounded_pair(point: list[float]) -> list[float]:
    return [round(point[0], 6), round(point[1], 6)]


def box_corners(component: dict[str, object]) -> list[list[float]]:
    center = component["centerWorldXYZ"]
    size = component["sizeWorldXYZ"]
    corners: list[list[float]] = []
    for sx in (-0.5, 0.5):
        for sy in (-0.5, 0.5):
            for sz in (-0.5, 0.5):
                corners.append([
                    center[0] + sx * size[0],
                    center[1] + sy * size[1],
                    center[2] + sz * size[2],
                ])
    return corners


def projected_bounds(scene: bpy.types.Scene, camera: bpy.types.Object, component: dict[str, object]) -> list[float]:
    points = [source_point(scene, camera, point) for point in box_corners(component)]
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return [min(xs), min(ys), max(xs), max(ys)]


def literal_metrics(bounds: list[float]) -> dict[str, float]:
    return {
        "width": round((bounds[2] - bounds[0]) / 8.0, 6),
        "height": round((bounds[3] - bounds[1]) / 8.0, 6),
    }


def intersection_area_literal(a: list[float], b: list[float]) -> float:
    width = max(0.0, min(a[2], b[2]) - max(a[0], b[0]))
    height = max(0.0, min(a[3], b[3]) - max(a[1], b[1]))
    return (width * height) / 64.0


def create_component(component: dict[str, object]) -> bpy.types.Object:
    center = citysim_to_blender(component["centerWorldXYZ"])
    size = component["sizeWorldXYZ"]
    blender_scale = (size[0], size[2], size[1])
    if component["shape"] == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=32,
            radius=max(size[0], size[2]) / 2.0,
            depth=size[1],
            location=center,
        )
        obj = bpy.context.active_object
    else:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
        obj = bpy.context.active_object
        obj.dimensions = blender_scale
        bpy.context.view_layer.update()
    obj.name = component["id"]
    obj["materialRole"] = component["materialRole"]
    obj["task"] = "PLAY-081"
    obj["direction"] = "west"
    return obj


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    scene_path = (root / args.scene).resolve()
    materials_path = (root / args.materials).resolve()
    output_path = (root / args.output).resolve()
    contract = json.loads(scene_path.read_text())

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    camera_contract = contract["camera"]
    scene.render.resolution_x = camera_contract["renderViewportPixels"][0]
    scene.render.resolution_y = camera_contract["renderViewportPixels"][1]
    scene.render.resolution_percentage = 100

    camera_data = bpy.data.cameras.new("PLAY-081-West-Actual-Camera")
    camera = bpy.data.objects.new("PLAY-081-West-Actual-Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = citysim_to_blender(camera_contract["positionWorldXYZ"])
    target = citysim_to_blender(camera_contract["targetWorldXYZ"])
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = camera_contract["blenderOrthographicScale"]
    camera_data.shift_x = camera_contract["shiftX"]
    camera_data.shift_y = camera_contract["shiftY"]
    scene.camera = camera
    bpy.context.view_layer.update()

    objects = {component["id"]: create_component(component) for component in contract["components"]}
    bpy.context.view_layer.update()
    component_by_id = {component["id"]: component for component in contract["components"]}
    bounds = {
        component_id: projected_bounds(scene, camera, component)
        for component_id, component in component_by_id.items()
    }

    registration = contract["registration"]
    projected_footprint = [
        source_point(scene, camera, [point[0], 0, point[1]])
        for point in registration["contactPolygonWorldXZ"]
    ]
    registration_pairs = {
        "footprint": [
            {
                "actual": rounded_pair(actual),
                "expected": expected,
                "absoluteError": rounded_pair([
                    abs(actual[0] - expected[0]),
                    abs(actual[1] - expected[1]),
                ]),
            }
            for actual, expected in zip(projected_footprint, registration["footprintExpectedSource"])
        ],
        "origin": {
            "actual": rounded_pair(source_point(scene, camera, registration["groundOriginWorldXYZ"])),
            "expected": registration["groundOriginExpectedSource"],
        },
        "pivot": {
            "actual": rounded_pair(source_point(scene, camera, registration["groundPivotWorldXYZ"])),
            "expected": registration["groundPivotExpectedSource"],
        },
        "westSocket": {
            "actual": rounded_pair(source_point(scene, camera, registration["frontageSocketWorldXYZ"])),
            "expected": registration["frontageSocketExpectedSource"],
        },
    }
    registration_errors: list[float] = []
    for item in registration_pairs["footprint"]:
        registration_errors.extend(item["absoluteError"])
    for key in ("origin", "pivot", "westSocket"):
        actual = registration_pairs[key]["actual"]
        expected = registration_pairs[key]["expected"]
        error = [abs(actual[0] - expected[0]), abs(actual[1] - expected[1])]
        registration_pairs[key]["absoluteError"] = rounded_pair(error)
        registration_errors.extend(error)
    maximum_registration_error = max(registration_errors)

    portal = contract["portal"]
    targets = contract["literal192Targets"]
    inset_bounds = bounds[portal["insetComponentID"]]
    inset_metrics = literal_metrics(inset_bounds)
    jamb_metrics = {
        component_id: literal_metrics(bounds[component_id])
        for component_id in portal["jambComponentIDs"]
    }
    header_metrics = literal_metrics(bounds[portal["headerComponentID"]])
    process_intersections = {
        component_id: round(intersection_area_literal(inset_bounds, bounds[component_id]), 6)
        for component_id in portal["processOccluderComponentIDs"]
    }

    marker_projection = []
    for marker in contract["silhouetteMarkers"]:
        marker_projection.append({
            "id": marker["id"],
            "componentID": marker["componentID"],
            "source": rounded_pair(source_point(scene, camera, marker["worldXYZ"])),
        })
    marker_projection.sort(key=lambda marker: marker["source"][0])
    silhouette_transitions = []
    for left, right in zip(marker_projection, marker_projection[1:]):
        x_separation = right["source"][0] - left["source"][0]
        y_delta = abs(right["source"][1] - left["source"][1])
        qualifies = x_separation >= 8 and y_delta >= 16
        silhouette_transitions.append({
            "left": left["id"],
            "right": right["id"],
            "xSeparationSourcePixels": round(x_separation, 6),
            "heightDeltaSourcePixels": round(y_delta, 6),
            "qualifies": qualifies,
        })
    silhouette_break_count = sum(1 for item in silhouette_transitions if item["qualifies"])

    portal_passed = (
        inset_metrics["width"] >= targets["portalInsetMinimumWidthPixels"]
        and inset_metrics["height"] >= targets["portalInsetMinimumHeightPixels"]
        and all(metrics["width"] >= targets["portalJambMinimumThicknessPixels"] for metrics in jamb_metrics.values())
        and header_metrics["height"] >= targets["portalHeaderMinimumThicknessPixels"]
    )
    process_occlusion_passed = all(
        area <= targets["maximumProcessOcclusionAreaPixels"]
        for area in process_intersections.values()
    )
    silhouette_passed = silhouette_break_count >= targets["minimumSilhouetteBreaks"]
    registration_passed = maximum_registration_error <= registration["maximumProjectionErrorSourcePixels"]

    object_manifest = [
        {
            "id": component_id,
            "type": objects[component_id].type,
            "materialRole": component_by_id[component_id]["materialRole"],
            "projectedBoundsSource": [round(value, 6) for value in bounds[component_id]],
        }
        for component_id in sorted(objects)
    ]
    report = {
        "schema": 1,
        "task": "PLAY-081",
        "proof": "BLENDER_ACTUAL_CAMERA_ZERO_PIXEL_PREDESIGN",
        "predesignID": contract["predesignID"],
        "blenderVersion": bpy.app.version_string,
        "sceneSHA256": sha256(scene_path),
        "materialBindingSHA256": sha256(materials_path),
        "camera": camera_contract,
        "registration": registration_pairs,
        "maximumRegistrationErrorSourcePixels": round(maximum_registration_error, 6),
        "registrationPassed": registration_passed,
        "portalLiteral192": {
            "inset": inset_metrics,
            "jambs": jamb_metrics,
            "header": header_metrics,
            "targets": targets,
            "passed": portal_passed,
        },
        "processOcclusionAgainstPortalInsetLiteral192": {
            "intersectionAreaPixels": process_intersections,
            "passed": process_occlusion_passed,
        },
        "silhouette": {
            "markers": marker_projection,
            "transitions": silhouette_transitions,
            "breakCount": silhouette_break_count,
            "minimumBreakCount": targets["minimumSilhouetteBreaks"],
            "passed": silhouette_passed,
        },
        "objectManifest": object_manifest,
        "objectCount": len(object_manifest),
        "renderInvocationCount": 0,
        "pixelOutputCount": 0,
        "sourceAuthority": False,
        "productionSelected": False,
        "passed": registration_passed and portal_passed and process_occlusion_passed and silhouette_passed,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
