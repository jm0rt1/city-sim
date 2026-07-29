#!/usr/bin/env python3
"""Build/prove/render the exact North art-v05 socket-facing portal scene."""

import argparse
import hashlib
import importlib.util
import json
import platform
import sys
from collections import deque
from pathlib import Path

import bpy
from mathutils import Vector


def fail(message):
    raise RuntimeError(message)


def canonical_bytes(value):
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def write_json(path, value):
    path.write_bytes(canonical_bytes(value))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_arguments():
    if "--" not in sys.argv:
        fail("script arguments must follow Blender's -- separator")
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--process-id", choices=["PREDESIGN", "A"], required=True)
    parser.add_argument("--predesign-proof-only", action="store_true")
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def inside(root, relative):
    candidate = (root / relative).resolve()
    candidate.relative_to(root)
    return candidate


def load_base_renderer(root, contract):
    path = inside(root, contract["baseRenderer"]["file"])
    if digest(path) != contract["baseRenderer"]["sha256"]:
        fail("base renderer hash drift")
    spec = importlib.util.spec_from_file_location("play027_art_v03_base", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def compact_bounds(points):
    if not points:
        return []
    return [
        min(point[0] for point in points),
        min(point[1] for point in points),
        max(point[0] for point in points) + 1,
        max(point[1] for point in points) + 1,
    ]


def largest_component(points):
    remaining = set(points)
    largest = []
    while remaining:
        start = remaining.pop()
        queue = deque([start])
        component = [start]
        while queue:
            x, y = queue.popleft()
            for neighbor in (
                (x - 1, y),
                (x + 1, y),
                (x, y - 1),
                (x, y + 1),
            ):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    queue.append(neighbor)
                    component.append(neighbor)
        if len(component) > len(largest):
            largest = component
    return largest


def minimum_chebyshev(points, targets):
    if not points or not targets:
        return 1_000_000
    return min(
        max(abs(point[0] - target[0]), abs(point[1] - target[1]))
        for point in points
        for target in targets
    )


def ray_visibility(scene, camera, scene_record):
    bpy.context.view_layer.update()
    width, height = 192, 128
    frame = camera.data.view_frame(scene=scene)
    minimum_x = min(point.x for point in frame)
    maximum_x = max(point.x for point in frame)
    minimum_y = min(point.y for point in frame)
    maximum_y = max(point.y for point in frame)
    direction = camera.matrix_world.to_quaternion() @ Vector((0, 0, -1))
    dependency_graph = bpy.context.evaluated_depsgraph_get()
    hit_names = []
    by_name = {}
    for y in range(height):
        row = []
        local_y = maximum_y - (float(y) + 0.5) / float(height) * (
            maximum_y - minimum_y
        )
        for x in range(width):
            local_x = minimum_x + (float(x) + 0.5) / float(width) * (
                maximum_x - minimum_x
            )
            origin = camera.matrix_world @ Vector((local_x, local_y, 0.0))
            hit, _, _, _, obj, _ = scene.ray_cast(
                dependency_graph,
                origin,
                direction,
                distance=1000.0,
            )
            name = obj.name if hit and obj is not None else ""
            row.append(name)
            if name:
                by_name.setdefault(name, []).append((x, y))
        hit_names.append(row)

    portal = scene_record["portal"]
    inset_points = by_name.get(portal["insetComponentID"], [])
    inset_component = largest_component(inset_points)
    inset_bounds = compact_bounds(inset_component)
    inset_width = inset_bounds[2] - inset_bounds[0] if inset_bounds else 0
    inset_height = inset_bounds[3] - inset_bounds[1] if inset_bounds else 0
    jambs = []
    for identifier in portal["jambComponentIDs"]:
        points = by_name.get(identifier, [])
        jambs.append(
            {
                "id": identifier,
                "visiblePixelCount": len(points),
                "bounds": compact_bounds(points),
            }
        )
    header_points = by_name.get(portal["headerComponentID"], [])
    header_bounds = compact_bounds(header_points)
    reveals = []
    for identifier in portal["revealComponentIDs"]:
        points = by_name.get(identifier, [])
        reveals.append(
            {
                "id": identifier,
                "visiblePixelCount": len(points),
                "bounds": compact_bounds(points),
            }
        )
    frame_passed = (
        all(
            record["bounds"]
            and record["bounds"][2] - record["bounds"][0] >= 2
            and record["bounds"][3] - record["bounds"][1] >= 2
            for record in jambs
        )
        and header_bounds
        and header_bounds[2] - header_bounds[0] >= 2
        and header_bounds[3] - header_bounds[1] >= 2
        and all(record["visiblePixelCount"] > 0 for record in reveals)
    )

    process_names = set(portal["processOccluderIDs"])
    hall_names = {
        item["id"]
        for item in scene_record["components"]
        if item["group"] in ("freight-hall", "raised-process-bay")
    }
    process_overlap = []
    hall_overlap = []
    if inset_bounds:
        for y in range(inset_bounds[1], inset_bounds[3]):
            for x in range(inset_bounds[0], inset_bounds[2]):
                name = hit_names[y][x]
                if name in process_names:
                    process_overlap.append(
                        {"x": x, "y": y, "componentID": name}
                    )
                if name in hall_names:
                    hall_overlap.append(
                        {"x": x, "y": y, "componentID": name}
                    )
    portal_passed = (
        inset_width >= int(portal["minimumCompactInsetPixels"][0])
        and inset_height >= int(portal["minimumCompactInsetPixels"][1])
        and not process_overlap
        and not hall_overlap
        and frame_passed
    )

    frontage = scene_record["frontageConnectivity"]
    apron_points = []
    apron_records = []
    for identifier in frontage["apronComponentIDs"]:
        points = by_name.get(identifier, [])
        apron_points.extend(points)
        apron_records.append(
            {
                "id": identifier,
                "visiblePixelCount": len(points),
                "bounds": compact_bounds(points),
            }
        )
    visible_apron = largest_component(apron_points)
    unique_apron_points = set(apron_points)
    threshold_points = []
    for identifier in frontage["portalThresholdComponentIDs"]:
        threshold_points.extend(by_name.get(identifier, []))
    socket = tuple(frontage["socketCompact"])
    threshold_distance = minimum_chebyshev(
        visible_apron,
        threshold_points,
    )
    socket_distance = minimum_chebyshev(visible_apron, [socket])
    frontage_passed = (
        bool(visible_apron)
        and all(record["visiblePixelCount"] > 0 for record in apron_records)
        and len(visible_apron) == len(unique_apron_points)
        and threshold_distance
        <= int(frontage["maximumPortalAdjacencyPixels"])
        and socket_distance <= int(frontage["maximumSocketDistancePixels"])
        and -28 < float(frontage["thresholdWorldX"]) < 28
        and frontage["outwardNormalWorld"] == [-1, 0, 0]
    )

    staff = scene_record["staffEntry"]
    staff_points = []
    staff_records = []
    for identifier in staff["componentIDs"]:
        points = by_name.get(identifier, [])
        staff_points.extend(points)
        staff_records.append(
            {
                "id": identifier,
                "visiblePixelCount": len(points),
                "bounds": compact_bounds(points),
            }
        )
    staff_bounds = compact_bounds(staff_points)
    staff_width = staff_bounds[2] - staff_bounds[0] if staff_bounds else 0
    staff_height = staff_bounds[3] - staff_bounds[1] if staff_bounds else 0
    staff_passed = (
        staff_width >= int(staff["minimumCompactBounds"][0])
        and staff_height >= int(staff["minimumCompactBounds"][1])
        and all(record["visiblePixelCount"] > 0 for record in staff_records)
    )

    rhythm = []
    for identifier in scene_record["roofRhythm"]["componentIDs"]:
        points = by_name.get(identifier, [])
        rhythm.append(
            {
                "id": identifier,
                "visiblePixelCount": len(points),
                "bounds": compact_bounds(points),
            }
        )
    rhythm_visible = sum(
        record["visiblePixelCount"] > 0 for record in rhythm
    )
    rhythm_passed = rhythm_visible >= int(
        scene_record["roofRhythm"]["minimumVisibleComponentCount"]
    )

    component_groups = {
        item["id"]: item["group"] for item in scene_record["components"]
    }
    group_points = {}
    for identifier, points in by_name.items():
        group = component_groups.get(identifier, "other")
        group_points.setdefault(group, []).extend(points)
    groups = {
        group: {
            "visiblePixelCount": len(points),
            "bounds": compact_bounds(points),
        }
        for group, points in sorted(group_points.items())
    }
    tier_groups = ("monitor-roof-edge", "process-roof-edge", "stack")
    tier_tops = [
        groups[group]["bounds"][1]
        for group in tier_groups
        if group in groups and groups[group]["bounds"]
    ]
    silhouette_passed = len(set(tier_tops)) >= 3
    occupied_points = []
    component_ids = {
        item["id"] for item in scene_record["components"]
    }
    for identifier, points in by_name.items():
        if identifier in component_ids:
            occupied_points.extend(points)
    occupied_bounds = compact_bounds(occupied_points)
    occupied_width = (
        occupied_bounds[2] - occupied_bounds[0] if occupied_bounds else 0
    )
    occupied_height = (
        occupied_bounds[3] - occupied_bounds[1] if occupied_bounds else 0
    )
    v03_bounds = [64, 59, 126, 109]
    accepted_l3_bounds = [70, 64, 123, 113]
    envelope_passed = (
        occupied_width >= v03_bounds[2] - v03_bounds[0]
        and occupied_height >= v03_bounds[3] - v03_bounds[1]
        and occupied_width
        >= accepted_l3_bounds[2] - accepted_l3_bounds[0]
        and occupied_height
        >= accepted_l3_bounds[3] - accepted_l3_bounds[1]
    )

    return {
        "schema": 1,
        "task": "PLAY-027",
        "contract": "CONTRACT-020",
        "compactDimensions": [width, height],
        "portalInset": {
            "id": portal["insetComponentID"],
            "visiblePixelCount": len(inset_points),
            "largestContiguousPixelCount": len(inset_component),
            "largestContiguousBounds": inset_bounds,
            "width": inset_width,
            "height": inset_height,
        },
        "portalJambs": jambs,
        "portalHeader": {
            "id": portal["headerComponentID"],
            "visiblePixelCount": len(header_points),
            "bounds": header_bounds,
        },
        "portalReveals": reveals,
        "processOccluderPixelCountInsidePortalBounds": len(process_overlap),
        "processOccluderPixelsInsidePortalBounds": process_overlap,
        "hallOccluderPixelCountInsidePortalBounds": len(hall_overlap),
        "hallOccluderPixelsInsidePortalBounds": hall_overlap,
        "portalVisibilityPassed": portal_passed,
        "frontageConnectivity": {
            "apronComponents": apron_records,
            "largestContiguousVisibleApronPixelCount": len(visible_apron),
            "largestContiguousVisibleApronBounds": compact_bounds(visible_apron),
            "portalThresholdComponentIDs": frontage[
                "portalThresholdComponentIDs"
            ],
            "minimumPortalAdjacencyPixels": threshold_distance,
            "socketCompact": list(socket),
            "minimumSocketDistancePixels": socket_distance,
            "usesVisibleRayHitPixelsOnly": True,
            "hiddenConnectorCount": 0,
            "thresholdWorldX": frontage["thresholdWorldX"],
            "thresholdInsideFootprint": (
                -28 < float(frontage["thresholdWorldX"]) < 28
            ),
            "outwardNormalWorld": frontage["outwardNormalWorld"],
            "outwardNormalPassed": (
                frontage["outwardNormalWorld"] == [-1, 0, 0]
            ),
            "passed": frontage_passed,
        },
        "staffEntry": {
            "components": staff_records,
            "bounds": staff_bounds,
            "width": staff_width,
            "height": staff_height,
            "passed": staff_passed,
        },
        "roofRhythmComponents": rhythm,
        "roofRhythmVisibleComponentCount": rhythm_visible,
        "roofRhythmPassed": rhythm_passed,
        "silhouetteTierGroups": list(tier_groups),
        "silhouetteTierTopPixels": tier_tops,
        "silhouetteHeightBreakCount": len(set(tier_tops)),
        "silhouetteBreaksPassed": silhouette_passed,
        "occupiedCompactBounds": occupied_bounds,
        "occupiedCompactWidth": occupied_width,
        "occupiedCompactHeight": occupied_height,
        "returnedV03CompactBounds": v03_bounds,
        "acceptedL3CompactBounds": accepted_l3_bounds,
        "noOccupiedEnvelopeShrinkPassed": envelope_passed,
        "frontageConnectivityPassed": frontage_passed,
        "staffEntryPassed": staff_passed,
        "visibleGroups": groups,
    }


def shadow_proof(base, scene, camera, scene_record):
    offset = scene_record["shadow"]["offsetWorldXZ"]
    start = base.source_pixel(scene, camera, [0.0, 0.0, 0.0])
    end = base.source_pixel(
        scene,
        camera,
        [float(offset[0]), 0.0, float(offset[1])],
    )
    actual = [end[0] - start[0], end[1] - start[1]]
    expected = scene_record["light"]["shadowVectorSource"]
    expected_actual = [-8.0, 12.0]
    passed = (
        expected == [2, 1]
        and all(
            abs(actual[index] - expected_actual[index]) <= 0.001
            for index in range(2)
        )
    )
    result = {
        "schema": 1,
        "task": "PLAY-027",
        "authoredOffsetWorldXZ": offset,
        "expectedDirectionSource": expected,
        "expectedActualProjectedVectorFromV03": expected_actual,
        "actualProjectedVectorSource": actual,
        "direction": scene_record["light"]["shadowDirection"],
        "shadowPolygonWorldXZ": scene_record["shadow"]["polygonWorldXZ"],
        "shadowPassed": passed,
    }
    if not passed:
        fail(f"shadow proof failed: {result}")
    return result


def main():
    args = parse_arguments()
    root = Path(args.repository_root).resolve()
    contract_path = inside(root, args.contract)
    output = Path(args.output_root).resolve()
    if output.exists():
        fail(f"output root must be absent: {output}")
    output.mkdir(parents=True)
    contract = json.loads(contract_path.read_text())
    scene_path = inside(root, contract["scene"]["file"])
    materials_path = inside(root, contract["materials"]["file"])
    if digest(scene_path) != contract["scene"]["sha256"]:
        fail("scene hash drift")
    if digest(materials_path) != contract["materials"]["sha256"]:
        fail("material hash drift")
    scene_record = json.loads(scene_path.read_text())
    material_root = json.loads(materials_path.read_text())
    if scene_record["sourceRevision"] != "blender-art-v05":
        fail("source revision")
    if scene_record["viewDirection"] != "north":
        fail("direction")
    if scene_record["orientationTransform"] != "none":
        fail("orientation")
    if scene_record["registration"]["frontageWorld"]["roadEdgeX"] != -28:
        fail("North road edge")
    if scene_record["registration"]["frontageWorld"]["portalFacing"] != "negative-x":
        fail("socket-facing portal")
    if int(scene_record["cycles"]["samples"]) < 64:
        fail("minimum Cycles samples")

    base = load_base_renderer(root, contract)
    base.clean_scene()
    materials = {
        record["id"]: base.make_material(record)
        for record in material_root["materials"]
    }
    objects = []
    for item in scene_record["components"]:
        material = materials.get(item["materialID"])
        if material is None:
            fail(f"unresolved material: {item['materialID']}")
        objects.append(base.add_component(item, material))
    shadow_material = base.make_shadow_material(
        scene_record["shadow"]["opacity"]
    )
    base.add_contact_shadow(scene_record, shadow_material)
    camera = base.configure_camera(scene_record)
    base.configure_light(scene_record)
    base.configure_cycles(bpy.context.scene, scene_record, output / "raw.png")

    mapping = base.object_manifest(scene_record, objects, materials)
    ground = base.projection_proof(bpy.context.scene, camera, scene_record)
    visibility = ray_visibility(bpy.context.scene, camera, scene_record)
    shadow = shadow_proof(
        base,
        bpy.context.scene,
        camera,
        scene_record,
    )
    values = base.material_value_report(material_root["materials"])
    frontage_values = base.frontage_value_report(material_root["materials"])
    write_json(output / "OBJECT-MANIFEST.json", mapping)
    write_json(output / "GROUND-PROJECTION.json", ground)
    write_json(output / "PORTAL-VISIBILITY.json", visibility)
    write_json(output / "SHADOW-PROJECTION.json", shadow)
    write_json(output / "ANALYTIC-192-ENVELOPE.json", values)
    write_json(output / "FRONTAGE-VALUE.json", frontage_values)

    proof_passed = (
        ground["projectionPassed"]
        and shadow["shadowPassed"]
        and visibility["portalVisibilityPassed"]
        and visibility["silhouetteBreaksPassed"]
        and visibility["roofRhythmPassed"]
        and visibility["frontageConnectivityPassed"]
        and visibility["staffEntryPassed"]
        and visibility["noOccupiedEnvelopeShrinkPassed"]
        and frontage_values["passed"]
    )
    if args.predesign_proof_only:
        if args.process_id != "PREDESIGN":
            fail("predesign proof requires PREDESIGN process ID")
        write_json(
            output / "PREDESIGN-RESULT.json",
            {
                "schema": 1,
                "task": "PLAY-027",
                "disposition": (
                    "PASS_ZERO_PIXEL_PREDESIGN"
                    if proof_passed
                    else "REJECT_ZERO_PIXEL_PREDESIGN"
                ),
                "sceneSHA256": digest(scene_path),
                "materialLibrarySHA256": digest(materials_path),
                "contractSHA256": digest(contract_path),
                "componentCount": mapping["componentCount"],
                "materialCount": mapping["materialCount"],
                "groundProjectionPassed": ground["projectionPassed"],
                "shadowProjectionPassed": shadow["shadowPassed"],
                "portalVisibilityPassed": visibility["portalVisibilityPassed"],
                "frontageConnectivityPassed": visibility[
                    "frontageConnectivityPassed"
                ],
                "staffEntryPassed": visibility["staffEntryPassed"],
                "roofRhythmPassed": visibility["roofRhythmPassed"],
                "silhouetteBreaksPassed": visibility["silhouetteBreaksPassed"],
                "noOccupiedEnvelopeShrinkPassed": visibility[
                    "noOccupiedEnvelopeShrinkPassed"
                ],
                "frontageValuePassed": frontage_values["passed"],
                "rawProcessCount": 0,
                "sourceAuthority": False,
                "productionSelected": False,
            },
        )
        if not proof_passed:
            fail(f"zero-pixel proof failed: {visibility}")
        return
    if not proof_passed:
        fail(f"pre-render proof failed: {visibility}")
    if args.process_id != "A":
        fail("art-v05 authority permits process A only")

    bpy.ops.render.render(write_still=True)
    write_json(
        output / "provenance.json",
        {
            "schema": 1,
            "task": "PLAY-027",
            "contract": "CONTRACT-020",
            "processID": "A",
            "blender": {
                "version": bpy.app.version_string,
                "buildHash": bpy.app.build_hash.decode("utf-8"),
                "pythonVersion": platform.python_version(),
                "machineArchitecture": platform.machine(),
            },
            "inputs": {
                "sceneSHA256": digest(scene_path),
                "materialLibrarySHA256": digest(materials_path),
                "contractSHA256": digest(contract_path),
                "scriptSHA256": digest(Path(__file__).resolve()),
                "baseRendererSHA256": contract["baseRenderer"]["sha256"],
            },
            "cycles": scene_record["cycles"],
            "componentCount": mapping["componentCount"],
            "materialCount": mapping["materialCount"],
            "projectionProofSHA256": digest(output / "GROUND-PROJECTION.json"),
            "portalVisibilityProofSHA256": digest(
                output / "PORTAL-VISIBILITY.json"
            ),
            "shadowProofSHA256": digest(output / "SHADOW-PROJECTION.json"),
            "rawFileSHA256": digest(output / "raw.png"),
            "sourceAuthority": False,
            "productionSelected": False,
        },
    )


if __name__ == "__main__":
    main()
