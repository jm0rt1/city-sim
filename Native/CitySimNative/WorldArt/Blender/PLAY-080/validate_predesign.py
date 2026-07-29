#!/usr/bin/env python3
"""Validate the PLAY-080 South predesign without producing pixels."""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import platform
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("static", "actual-camera"), required=True)
    parser.add_argument("--scene", type=Path, required=True)
    parser.add_argument("--materials", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def add_test(tests: list[dict], name: str, passed: bool, details: object) -> None:
    tests.append({"name": name, "pass": bool(passed), "details": details})


def bounds(component: dict) -> tuple[list[float], list[float]]:
    center = component["center"]
    size = component["size"]
    return (
        [center[index] - size[index] / 2 for index in range(3)],
        [center[index] + size[index] / 2 for index in range(3)],
    )


def box_corners(component: dict) -> list[list[float]]:
    lower, upper = bounds(component)
    return [
        [x, y, z]
        for x, y, z in itertools.product(
            (lower[0], upper[0]), (lower[1], upper[1]), (lower[2], upper[2])
        )
    ]


def component_map(scene: dict) -> dict[str, dict]:
    return {component["id"]: component for component in scene["components"]}


def static_proof(scene: dict, materials: dict) -> dict:
    tests: list[dict] = []
    components = scene.get("components", [])
    ids = [component.get("id") for component in components]
    roles = set(materials.get("roles", {}))
    used_roles = {component.get("materialRole") for component in components}
    registration = scene["registration"]
    footprint = registration["footprintWorld"]
    socket = registration["frontageSocket"]
    lighting = scene["lighting"]
    authored = scene["authorship"]

    add_test(
        tests,
        "governed-task-and-direction",
        scene.get("task") == "PLAY-080" and scene.get("direction") == "south",
        {"task": scene.get("task"), "direction": scene.get("direction")},
    )
    add_test(
        tests,
        "non-authority-zero-pixel-disposition",
        scene.get("sourceAuthority") is False
        and scene.get("productionSelected") is False
        and scene.get("pixelRenderAuthorized") is False,
        {
            "sourceAuthority": scene.get("sourceAuthority"),
            "productionSelected": scene.get("productionSelected"),
            "pixelRenderAuthorized": scene.get("pixelRenderAuthorized"),
        },
    )
    add_test(
        tests,
        "independent-south-authorship",
        scene.get("orientationTransform") == "none"
        and authored.get("siblingSceneOpened") is False
        and authored.get("siblingSceneCopied") is False
        and authored.get("siblingGeometryConsumed") is False,
        {
            "orientationTransform": scene.get("orientationTransform"),
            "siblingSceneOpened": authored.get("siblingSceneOpened"),
            "siblingSceneCopied": authored.get("siblingSceneCopied"),
            "siblingGeometryConsumed": authored.get("siblingGeometryConsumed"),
        },
    )
    add_test(
        tests,
        "unique-component-identities",
        len(ids) == len(set(ids)) and all(ids),
        {"componentCount": len(ids), "uniqueCount": len(set(ids))},
    )
    add_test(
        tests,
        "explicit-box-geometry",
        all(component.get("geometry") == "box" for component in components),
        {"geometryTypes": sorted({component.get("geometry") for component in components})},
    )
    add_test(
        tests,
        "material-role-coverage",
        used_roles <= roles and not (roles - used_roles),
        {
            "undefinedRoles": sorted(used_roles - roles),
            "unusedRoles": sorted(roles - used_roles),
            "roleCount": len(roles),
        },
    )
    add_test(
        tests,
        "material-lock-remains-pending",
        materials.get("provisional") is True
        and materials.get("familyMaterialLock", {}).get("status")
        == "pending-integration-north-lock"
        and materials.get("familyMaterialLock", {}).get("pixelRenderBlocked") is True,
        materials.get("familyMaterialLock"),
    )

    expected_corners = [
        [-28, 0, -28],
        [-28, 0, 28],
        [28, 0, 28],
        [28, 0, -28],
    ]
    add_test(
        tests,
        "exact-56x56-footprint",
        footprint.get("size") == [56, 56] and footprint.get("corners") == expected_corners,
        footprint,
    )
    add_test(
        tests,
        "south-socket-and-pivot",
        socket.get("position") == [28, 0, 0]
        and socket.get("outwardVector") == [1, 0, 0]
        and registration.get("groundPivot") == [28, 0, 28],
        {"socket": socket, "pivot": registration.get("groundPivot")},
    )

    outside = []
    for component in components:
        lower, upper = bounds(component)
        if lower[0] < -28 or upper[0] > 28 or lower[2] < -28 or upper[2] > 28:
            outside.append(
                {"id": component["id"], "groundBounds": [lower[0], lower[2], upper[0], upper[2]]}
            )
    add_test(tests, "all-grounded-mass-inside-footprint", not outside, outside)

    tagged = lambda tag: [
        component for component in components if tag in component.get("tags", [])
    ]
    portals = tagged("freight-opening")
    primary = tagged("primary-freight-portal")
    staff = tagged("staff-entrance")
    road_facing = all(bounds(component)[1][0] >= 20 for component in portals + staff)
    add_test(
        tests,
        "south-road-facing-frontage",
        len(portals) == 3 and len(primary) == 1 and len(staff) == 1 and road_facing,
        {
            "freightOpenings": [component["id"] for component in portals],
            "primaryPortal": [component["id"] for component in primary],
            "staffEntrance": [component["id"] for component in staff],
            "roadFacing": road_facing,
        },
    )

    primary_component = primary[0] if primary else {"size": [0, 0, 0]}
    frame = tagged("portal-frame")
    add_test(
        tests,
        "monumental-portal-world-envelope",
        primary_component["size"][1] >= 20
        and primary_component["size"][2] >= 22
        and len(tagged("portal-jamb")) == 2
        and len(tagged("portal-header")) == 1
        and len(tagged("portal-reveal")) == 1,
        {
            "primarySize": primary_component["size"],
            "frameComponents": [component["id"] for component in frame],
        },
    )

    silhouette_components = tagged("silhouette-break")
    silhouette_tops = sorted(
        {round(bounds(component)[1][1], 3) for component in silhouette_components}
    )
    add_test(
        tests,
        "static-silhouette-breaks",
        len(silhouette_tops) >= scene["literal192Targets"]["minimumSilhouetteBreaks"],
        {
            "uniqueWorldTopElevations": silhouette_tops,
            "taggedComponents": [component["id"] for component in silhouette_components],
        },
    )
    add_test(
        tests,
        "northwest-light-southeast-contact",
        lighting.get("keySourceDirection", [0, 0, 0])[0] < 0
        and lighting.get("keySourceDirection", [0, 0, 0])[2] < 0
        and lighting.get("keySourceDirection", [0, 0, 0])[1] > 0
        and lighting.get("contactShadowVector", [0, 0, 0])[0] > 0
        and lighting.get("contactShadowVector", [0, 0, 0])[2] > 0
        and lighting.get("contactShadowVector", [0, 0, 0])[1] == 0,
        lighting,
    )

    return {
        "schema": "citysim.play-080.predesign-static-proof.v1",
        "task": "PLAY-080",
        "direction": "south",
        "mode": "static-zero-pixel",
        "result": "PASS" if all(test["pass"] for test in tests) else "FAIL",
        "tests": tests,
    }


def convex_hull(points: list[list[float]]) -> list[list[float]]:
    unique = sorted({(round(point[0], 9), round(point[1], 9)) for point in points})
    if len(unique) <= 1:
        return [list(point) for point in unique]

    def cross(origin, a, b):
        return (a[0] - origin[0]) * (b[1] - origin[1]) - (
            a[1] - origin[1]
        ) * (b[0] - origin[0])

    lower = []
    for point in unique:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    upper = []
    for point in reversed(unique):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    return [list(point) for point in lower[:-1] + upper[:-1]]


def point_in_polygon(point: list[float], polygon: list[list[float]]) -> bool:
    inside = False
    j = len(polygon) - 1
    for i in range(len(polygon)):
        xi, yi = polygon[i]
        xj, yj = polygon[j]
        crosses = (yi > point[1]) != (yj > point[1])
        if crosses:
            x_at_y = (xj - xi) * (point[1] - yi) / (yj - yi) + xi
            if point[0] < x_at_y:
                inside = not inside
        j = i
    return inside


def segments_intersect(a, b, c, d) -> bool:
    def orientation(p, q, r):
        value = (q[1] - p[1]) * (r[0] - q[0]) - (q[0] - p[0]) * (
            r[1] - q[1]
        )
        if abs(value) < 1e-9:
            return 0
        return 1 if value > 0 else 2

    return (
        orientation(a, b, c) != orientation(a, b, d)
        and orientation(c, d, a) != orientation(c, d, b)
    )


def polygons_intersect(first: list[list[float]], second: list[list[float]]) -> bool:
    if any(point_in_polygon(point, second) for point in first):
        return True
    if any(point_in_polygon(point, first) for point in second):
        return True
    first_edges = list(zip(first, first[1:] + first[:1]))
    second_edges = list(zip(second, second[1:] + second[:1]))
    return any(
        segments_intersect(a, b, c, d)
        for a, b in first_edges
        for c, d in second_edges
    )


def make_box_object(bpy, component: dict):
    center = component["center"]
    size = component["size"]
    half = [value / 2 for value in size]
    citysim_vertices = [
        [center[0] + x, center[1] + y, center[2] + z]
        for x, y, z in itertools.product(
            (-half[0], half[0]), (-half[1], half[1]), (-half[2], half[2])
        )
    ]
    vertices = [(point[0], point[2], point[1]) for point in citysim_vertices]
    faces = [
        (0, 1, 3, 2),
        (4, 6, 7, 5),
        (0, 4, 5, 1),
        (2, 3, 7, 6),
        (0, 2, 6, 4),
        (1, 5, 7, 3),
    ]
    mesh = bpy.data.meshes.new(component["id"] + "-mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(component["id"], mesh)
    bpy.context.collection.objects.link(obj)
    obj["play080_material_role"] = component["materialRole"]
    obj["play080_tags"] = ",".join(component.get("tags", []))
    return obj


def actual_camera_proof(scene: dict, materials: dict) -> dict:
    import bpy
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector

    tests: list[dict] = []
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    render = scene["camera"]["renderViewportPixels"]
    bpy.context.scene.render.resolution_x = render[0]
    bpy.context.scene.render.resolution_y = render[1]
    bpy.context.scene.render.resolution_percentage = 100
    bpy.context.scene.render.pixel_aspect_x = scene["camera"]["pixelAspect"][0]
    bpy.context.scene.render.pixel_aspect_y = scene["camera"]["pixelAspect"][1]

    position = scene["camera"]["citysimPosition"]
    target = scene["camera"]["citysimTarget"]
    blender_position = Vector((position[0], position[2], position[1]))
    blender_target = Vector((target[0], target[2], target[1]))
    camera_data = bpy.data.cameras.new("PLAY-080-South-Actual-Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = scene["camera"]["orthoScale"]
    camera_data.shift_x = scene["camera"]["shiftX"]
    camera_data.shift_y = scene["camera"]["shiftY"]
    camera = bpy.data.objects.new("PLAY-080-South-Actual-Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = blender_position
    camera.rotation_euler = (blender_target - blender_position).to_track_quat(
        "-Z", "Y"
    ).to_euler()
    bpy.context.scene.camera = camera

    for component in scene["components"]:
        make_box_object(bpy, component)
    bpy.context.view_layer.update()

    def project(point: list[float]) -> list[float]:
        blender_point = Vector((point[0], point[2], point[1]))
        normalized = world_to_camera_view(bpy.context.scene, camera, blender_point)
        return [
            normalized.x * render[0],
            (1 - normalized.y) * render[1],
        ]

    def project_component(component: dict) -> dict:
        projected = [project(point) for point in box_corners(component)]
        hull = convex_hull(projected)
        xs = [point[0] for point in projected]
        ys = [point[1] for point in projected]
        return {
            "sourceHull": [[round(value, 6) for value in point] for point in hull],
            "sourceBounds": [
                round(min(xs), 6),
                round(min(ys), 6),
                round(max(xs), 6),
                round(max(ys), 6),
            ],
        }

    registration = scene["registration"]
    camera_targets = scene["camera"]["projectionTargets"]
    actual_footprint = [
        project(point) for point in registration["footprintWorld"]["corners"]
    ]
    actual_origin = project(registration["groundOrigin"])
    actual_pivot = project(registration["groundPivot"])
    actual_socket = project(registration["frontageSocket"]["position"])
    tolerance = camera_targets["toleranceSourcePixels"]

    def within(actual, expected):
        return all(abs(a - e) <= tolerance for a, e in zip(actual, expected))

    footprint_pass = all(
        within(actual, expected)
        for actual, expected in zip(actual_footprint, camera_targets["footprint"])
    )
    add_test(
        tests,
        "actual-camera-footprint",
        footprint_pass,
        {
            "actual": [[round(value, 6) for value in point] for point in actual_footprint],
            "expected": camera_targets["footprint"],
            "toleranceSourcePixels": tolerance,
        },
    )
    for name, actual, expected in (
        ("ground-origin", actual_origin, camera_targets["groundOrigin"]),
        ("ground-pivot", actual_pivot, camera_targets["groundPivot"]),
        ("south-frontage-socket", actual_socket, camera_targets["frontageSocket"]),
    ):
        add_test(
            tests,
            "actual-camera-" + name,
            within(actual, expected),
            {
                "actual": [round(value, 6) for value in actual],
                "expected": expected,
                "toleranceSourcePixels": tolerance,
            },
        )

    by_id = component_map(scene)
    portal = by_id["monumental-portal-inset"]
    portal_projection = project_component(portal)
    bounds_source = portal_projection["sourceBounds"]
    scale_x = render[0] / scene["camera"]["literalViewportPixels"][0]
    scale_y = render[1] / scene["camera"]["literalViewportPixels"][1]
    portal_literal = [
        bounds_source[0] / scale_x,
        bounds_source[1] / scale_y,
        bounds_source[2] / scale_x,
        bounds_source[3] / scale_y,
    ]
    portal_width = portal_literal[2] - portal_literal[0]
    portal_height = portal_literal[3] - portal_literal[1]
    portal_minimum = scene["literal192Targets"]["primaryPortalMinimumPixels"]
    add_test(
        tests,
        "literal-192-primary-portal-envelope",
        portal_width >= portal_minimum[0] and portal_height >= portal_minimum[1],
        {
            "literalBounds": [round(value, 6) for value in portal_literal],
            "literalSize": [round(portal_width, 6), round(portal_height, 6)],
            "minimum": portal_minimum,
        },
    )

    frame_minimum = scene["literal192Targets"]["frameMinimumThicknessPixels"]
    jamb_metrics = {}
    jamb_pass = True
    for component_id in (
        "monumental-portal-west-jamb",
        "monumental-portal-east-jamb",
    ):
        projected = project_component(by_id[component_id])["sourceBounds"]
        literal_width = (projected[2] - projected[0]) / scale_x
        jamb_metrics[component_id] = round(literal_width, 6)
        jamb_pass = jamb_pass and literal_width >= frame_minimum
    header_bounds = project_component(by_id["monumental-portal-header"])[
        "sourceBounds"
    ]
    header_thickness = (header_bounds[3] - header_bounds[1]) / scale_y
    add_test(
        tests,
        "literal-192-portal-frame",
        jamb_pass and header_thickness >= frame_minimum,
        {
            "jambProjectedWidths": jamb_metrics,
            "headerProjectedHeight": round(header_thickness, 6),
            "minimumThickness": frame_minimum,
        },
    )

    portal_hull = portal_projection["sourceHull"]
    occlusion = []
    for component in scene["components"]:
        if "process-occluder" not in component.get("tags", []):
            continue
        projected = project_component(component)
        if polygons_intersect(portal_hull, projected["sourceHull"]):
            occlusion.append(
                {
                    "id": component["id"],
                    "sourceHull": projected["sourceHull"],
                }
            )
    add_test(
        tests,
        "zero-process-portal-occlusion",
        not occlusion,
        {
            "intersections": occlusion,
            "processComponentCount": len(
                [
                    component
                    for component in scene["components"]
                    if "process-occluder" in component.get("tags", [])
                ]
            ),
        },
    )

    silhouette_rows = []
    for component in scene["components"]:
        if "silhouette-break" not in component.get("tags", []):
            continue
        upper = bounds(component)[1]
        top_center = [component["center"][0], upper[1], component["center"][2]]
        row = project(top_center)[1] / scale_y
        silhouette_rows.append({"id": component["id"], "literalRow": round(row, 6)})
    clusters: list[float] = []
    for row in sorted(item["literalRow"] for item in silhouette_rows):
        if not clusters or abs(row - clusters[-1]) >= 2:
            clusters.append(row)
    minimum_breaks = scene["literal192Targets"]["minimumSilhouetteBreaks"]
    add_test(
        tests,
        "actual-camera-silhouette-breaks",
        len(clusters) >= minimum_breaks,
        {
            "projectedTopRows": silhouette_rows,
            "distinctRowsAtLeastTwoPixelsApart": [round(row, 6) for row in clusters],
            "count": len(clusters),
            "minimum": minimum_breaks,
        },
    )

    freight_widths = {}
    freight_pass = True
    minimum_freight_width = scene["literal192Targets"][
        "freightOpeningMinimumWidthPixels"
    ]
    for component in scene["components"]:
        if "freight-opening" not in component.get("tags", []):
            continue
        projected = project_component(component)["sourceBounds"]
        literal_width = (projected[2] - projected[0]) / scale_x
        freight_widths[component["id"]] = round(literal_width, 6)
        freight_pass = freight_pass and literal_width >= minimum_freight_width
    add_test(
        tests,
        "literal-192-freight-opening-widths",
        freight_pass,
        {
            "projectedWidths": freight_widths,
            "minimum": minimum_freight_width,
        },
    )

    return {
        "schema": "citysim.play-080.predesign-actual-camera-proof.v1",
        "task": "PLAY-080",
        "direction": "south",
        "mode": "blender-actual-camera-zero-pixel",
        "renderInvocations": 0,
        "imageOutputs": 0,
        "blenderVersion": bpy.app.version_string,
        "blenderBuildHash": bpy.app.build_hash.decode("utf-8"),
        "pythonVersion": platform.python_version(),
        "camera": scene["camera"],
        "result": "PASS" if all(test["pass"] for test in tests) else "FAIL",
        "tests": tests,
    }


def main() -> int:
    args = parse_args()
    scene = load_json(args.scene)
    materials = load_json(args.materials)
    if args.mode == "static":
        report = static_proof(scene, materials)
    else:
        report = actual_camera_proof(scene, materials)

    report["inputs"] = {
        "scene": str(args.scene),
        "sceneSHA256": sha256(args.scene),
        "materials": str(args.materials),
        "materialsSHA256": sha256(args.materials),
        "validator": str(Path(__file__)),
        "validatorSHA256": sha256(Path(__file__)),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print(json.dumps({"mode": args.mode, "output": str(args.output), "result": report["result"]}))
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
