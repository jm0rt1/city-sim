#!/usr/bin/env python3
"""PLAY-079 East zero-pixel predesign validator.

Static mode uses only Python's standard library. Blender mode reconstructs the
task-owned scene in memory and projects it through the configured bpy camera.
Neither mode invokes a render operation or writes an image.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import sys
from typing import Any, Iterable


ROOT = pathlib.Path(__file__).resolve().parent
SCENE_PATH = ROOT / "scene.json"
MATERIALS_PATH = ROOT / "materials.json"


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json(path: pathlib.Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def fail(message: str) -> None:
    raise ValueError(message)


def bounds_for_object(obj: dict[str, Any]) -> tuple[list[float], list[float]]:
    cx, cy, cz = obj["center"]
    if obj["kind"] == "box":
        dx, dy, dz = obj["dimensions"]
    elif obj["kind"] == "cylinder":
        dx = dy = 2.0 * obj["radius"]
        dz = obj["depth"]
    else:
        fail(f"unsupported object kind: {obj['kind']}")
    return (
        [cx - dx / 2.0, cy - dy / 2.0, cz - dz / 2.0],
        [cx + dx / 2.0, cy + dy / 2.0, cz + dz / 2.0],
    )


def corners_for_bounds(bounds: tuple[list[float], list[float]]) -> list[list[float]]:
    lo, hi = bounds
    return [[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]


def polygon_area_xy(points: list[list[float]]) -> float:
    area = 0.0
    for index, point in enumerate(points):
        following = points[(index + 1) % len(points)]
        area += point[0] * following[1] - following[0] * point[1]
    return abs(area) / 2.0


def is_within_footprint(point: Iterable[float], half_extent: float = 28.0) -> bool:
    x, y, _ = point
    return abs(x) <= half_extent + 1e-9 and abs(y) <= half_extent + 1e-9


def static_proof(scene: dict[str, Any], materials: dict[str, Any]) -> dict[str, Any]:
    validator_source = pathlib.Path(__file__).read_text(encoding="utf-8")
    forbidden_render_calls = [
        "bpy.ops." + "render",
        "write_" + "still",
        "save_" + "render",
    ]
    present_render_calls = [token for token in forbidden_render_calls if token in validator_source]
    if present_render_calls:
        fail(f"zero-pixel validator contains render API calls: {present_render_calls}")

    if scene["schema"] != "citysim.world-art.blender-predesign.v1":
        fail("unexpected scene schema")
    if scene["task"] != "PLAY-079" or scene["direction"] != "east":
        fail("task/direction mismatch")
    if scene["phase"] != "PREDESIGN_ZERO_PIXEL":
        fail("scene is not zero-pixel predesign")
    if scene["sourceAuthority"] or scene["productionSelected"] or scene["pixelRenderingAllowed"]:
        fail("predesign may not claim source, production, or pixel authority")
    if scene["orientationTransform"] != "none":
        fail("orientationTransform must be none")

    provenance = scene["provenance"]
    independence = {
        "geometryOrigin": provenance["geometryOrigin"],
        "siblingSceneInputCount": len(provenance["siblingSceneInputs"]),
        "copiedGeometry": provenance["copiedGeometry"],
        "mirroredGeometry": provenance["mirroredGeometry"],
        "rotatedGeometry": provenance["rotatedGeometry"],
        "transformedSiblingGeometry": provenance["transformedSiblingGeometry"],
    }
    if independence != {
        "geometryOrigin": "independently-authored-east-from-published-contracts-only",
        "siblingSceneInputCount": 0,
        "copiedGeometry": False,
        "mirroredGeometry": False,
        "rotatedGeometry": False,
        "transformedSiblingGeometry": False,
    }:
        fail("independent East provenance failed")

    registration = scene["registration"]
    if registration["citySimFootprint"] != {"width": 72.0, "depth": 72.0}:
        fail("CitySim footprint must remain 72x72")
    if registration["dccFootprint"]["width"] != 56.0 or registration["dccFootprint"]["depth"] != 56.0:
        fail("DCC footprint must preserve the published 7/9 registration scale")
    if registration["groundPivot"] != [28.0, -28.0, 0.0]:
        fail("East ground pivot mismatch")
    if registration["frontageSocket"] != [28.0, 0.0, 0.0]:
        fail("East frontage socket mismatch")

    material_roles = {role["id"]: role for role in materials["roles"]}
    required_roles = set(scene["materialBindings"]["requiredRoles"])
    if required_roles != set(material_roles):
        fail("material role inventory mismatch")
    if materials["lockState"] != "PROVISIONAL_ROLES_AWAITING_ACCEPTED_NORTH_FAMILY_MATERIAL_LOCK":
        fail("material binding must remain provisional")

    objects = scene["objects"]
    object_ids = [obj["id"] for obj in objects]
    if len(object_ids) != len(set(object_ids)):
        fail("duplicate object IDs")
    if not all(object_id.startswith("east-") for object_id in object_ids):
        fail("all object IDs must be East-owned")
    if any(obj["materialRole"] not in material_roles for obj in objects):
        fail("object references an unknown material role")

    out_of_footprint: list[str] = []
    below_ground: list[str] = []
    object_manifest: list[dict[str, Any]] = []
    for obj in objects:
        bounds = bounds_for_object(obj)
        if not all(is_within_footprint(point) for point in corners_for_bounds(bounds)):
            out_of_footprint.append(obj["id"])
        if bounds[0][2] < -1e-9:
            below_ground.append(obj["id"])
        object_manifest.append(
            {
                "id": obj["id"],
                "kind": obj["kind"],
                "category": obj["category"],
                "bounds": bounds,
                "materialRole": obj["materialRole"],
                "silhouetteTier": obj["silhouetteTier"],
            }
        )
    if out_of_footprint:
        fail(f"objects exceed footprint: {out_of_footprint}")
    if below_ground:
        fail(f"objects extend below true ground: {below_ground}")

    portal = scene["portal"]
    portal_ids = {
        portal["insetObjectID"],
        portal["headerObjectID"],
        portal["revealObjectID"],
        *portal["jambObjectIDs"],
    }
    if not portal_ids.issubset(set(object_ids)):
        fail("portal component inventory incomplete")
    if portal["frontage"] != "east" or not portal["roadServed"] or not portal["apronConnectsToSocket"]:
        fail("portal is not bound to the East road frontage")

    contact = scene["contact"]
    if not all(is_within_footprint(point) for point in contact["polygon"] + contact["roadApron"]):
        fail("contact or apron leaves governed footprint")
    if polygon_area_xy(contact["polygon"]) >= 56.0 * 56.0 * 0.55:
        fail("contact field is too broad")
    if registration["frontageSocket"] not in contact["roadApron"]:
        fail("road apron does not terminate at East socket")

    light = scene["light"]
    if not (
        light["keyOrigin"][0] < 0
        and light["keyOrigin"][1] > 0
        and light["authoredShadowVector"][0] > 0
        and light["authoredShadowVector"][1] < 0
    ):
        fail("northwest light / southeast shadow semantic mismatch")

    tiers = sorted(
        {
            obj["silhouetteTier"]
            for obj in objects
            if obj["category"] in {"hall", "administration", "roof", "process", "gantry"}
        }
    )
    static_breaks = max(0, len(tiers) - 1)
    if static_breaks < portal["literal192Targets"]["minimumSilhouetteBreaks"]:
        fail("fewer than three authored silhouette breaks")

    return {
        "schema": "citysim.world-art.static-predesign-proof.v1",
        "task": "PLAY-079",
        "direction": "east",
        "phase": "PREDESIGN_ZERO_PIXEL",
        "result": "PASS",
        "independence": independence,
        "registration": {
            "citySimFootprint": registration["citySimFootprint"],
            "dccHorizontalScale": registration["dccHorizontalScale"],
            "dccFootprint": registration["dccFootprint"],
            "groundPivot": registration["groundPivot"],
            "frontageSocket": registration["frontageSocket"],
        },
        "portal": {
            "frontage": portal["frontage"],
            "roadServed": portal["roadServed"],
            "componentIDs": sorted(portal_ids),
            "apronConnectsToSocket": portal["apronConnectsToSocket"],
        },
        "contact": {
            "area": polygon_area_xy(contact["polygon"]),
            "footprintArea": 56.0 * 56.0,
            "coverageFraction": polygon_area_xy(contact["polygon"]) / (56.0 * 56.0),
            "broadDarkMatForbidden": contact["broadDarkMatForbidden"],
        },
        "light": light,
        "materialBinding": {
            "lockState": materials["lockState"],
            "roleCount": len(material_roles),
            "roles": sorted(material_roles),
        },
        "silhouette": {
            "authoredTiers": tiers,
            "authoredBreakCount": static_breaks,
            "minimumBreakCount": portal["literal192Targets"]["minimumSilhouetteBreaks"],
        },
        "objectCount": len(objects),
        "objectManifest": object_manifest,
        "renderInvocations": 0,
        "imagesWritten": 0,
        "renderAPIReferencesInValidator": len(present_render_calls),
        "sourceHashes": {
            "sceneSHA256": sha256_bytes(SCENE_PATH.read_bytes()),
            "materialsSHA256": sha256_bytes(MATERIALS_PATH.read_bytes()),
            "validatorSHA256": sha256_bytes(pathlib.Path(__file__).read_bytes()),
        },
    }


def rectangle_overlap(a: dict[str, float], b: dict[str, float]) -> dict[str, float]:
    width = max(0.0, min(a["maxX"], b["maxX"]) - max(a["minX"], b["minX"]))
    height = max(0.0, min(a["maxY"], b["maxY"]) - max(a["minY"], b["minY"]))
    return {"width": width, "height": height, "area": width * height}


def blender_proof(scene_data: dict[str, Any], materials_data: dict[str, Any]) -> dict[str, Any]:
    try:
        import bpy  # type: ignore
        from bpy_extras.object_utils import world_to_camera_view  # type: ignore
        from mathutils import Vector  # type: ignore
    except ImportError as error:
        fail(f"Blender mode requires bpy: {error}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    camera_spec = scene_data["camera"]
    width, height = camera_spec["resolution"]
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = camera_spec["resolutionPercentage"]
    scene.render.pixel_aspect_x = camera_spec["pixelAspect"][0]
    scene.render.pixel_aspect_y = camera_spec["pixelAspect"][1]

    camera_data = bpy.data.cameras.new("PLAY-079-East-Predesign-Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = camera_spec["orthoScale"]
    camera_data.shift_x = camera_spec["shiftX"]
    camera_data.shift_y = camera_spec["shiftY"]
    camera = bpy.data.objects.new("PLAY-079-East-Predesign-Camera", camera_data)
    scene.collection.objects.link(camera)
    target = Vector(camera_spec["target"])
    yaw = math.radians(camera_spec["yawDegrees"])
    elevation = math.radians(camera_spec["elevationDegrees"])
    distance = camera_spec["distance"]
    horizontal = distance * math.cos(elevation)
    camera.location = Vector(
        (
            target.x + horizontal * math.cos(yaw),
            target.y - horizontal * math.sin(yaw),
            target.z + distance * math.sin(elevation),
        )
    )
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    bpy.context.view_layer.update()

    role_map = {role["id"]: role for role in materials_data["roles"]}
    material_map: dict[str, Any] = {}
    for role_id, role in sorted(role_map.items()):
        material = bpy.data.materials.new(f"PLAY-079::{role_id}")
        hex_color = role["baseColorSRGB"].lstrip("#")
        rgb = tuple(int(hex_color[index : index + 2], 16) / 255.0 for index in (0, 2, 4))
        material.diffuse_color = (*rgb, 1.0)
        material_map[role_id] = material

    blender_objects: dict[str, Any] = {}
    for spec in scene_data["objects"]:
        if spec["kind"] == "box":
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=spec["center"])
            obj = bpy.context.object
            obj.dimensions = spec["dimensions"]
        elif spec["kind"] == "cylinder":
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=spec["vertices"],
                radius=spec["radius"],
                depth=spec["depth"],
                location=spec["center"],
            )
            obj = bpy.context.object
        else:
            fail(f"unsupported Blender object kind: {spec['kind']}")
        obj.name = spec["id"]
        obj.data.name = f"{spec['id']}-mesh"
        obj["play079_category"] = spec["category"]
        obj["play079_material_role"] = spec["materialRole"]
        obj.data.materials.append(material_map[spec["materialRole"]])
        blender_objects[spec["id"]] = obj
    bpy.context.view_layer.update()

    def project(point: Iterable[float]) -> dict[str, float]:
        coordinate = world_to_camera_view(scene, camera, Vector(point))
        return {
            "x": coordinate.x * width,
            "y": (1.0 - coordinate.y) * height,
            "depth": coordinate.z,
        }

    def projected_bounds(obj: Any) -> dict[str, float]:
        coordinates = [project(obj.matrix_world @ Vector(corner)) for corner in obj.bound_box]
        return {
            "minX": min(item["x"] for item in coordinates),
            "minY": min(item["y"] for item in coordinates),
            "maxX": max(item["x"] for item in coordinates),
            "maxY": max(item["y"] for item in coordinates),
            "minDepth": min(item["depth"] for item in coordinates),
            "maxDepth": max(item["depth"] for item in coordinates),
        }

    registration = scene_data["registration"]
    actual_registration = {
        "footprint": [
            [project(point)["x"], project(point)["y"]]
            for point in registration["dccFootprint"]["corners"]
        ],
        "groundOrigin": [
            project(registration["groundOrigin"])["x"],
            project(registration["groundOrigin"])["y"],
        ],
        "groundPivot": [
            project(registration["groundPivot"])["x"],
            project(registration["groundPivot"])["y"],
        ],
        "frontageSocket": [
            project(registration["frontageSocket"])["x"],
            project(registration["frontageSocket"])["y"],
        ],
    }
    expected_registration = registration["expectedSourcePixels"]
    registration_errors: dict[str, Any] = {}
    max_error = 0.0
    for key in ("footprint", "groundOrigin", "groundPivot", "frontageSocket"):
        actual_points = actual_registration[key]
        expected_points = expected_registration[key]
        if key != "footprint":
            actual_points = [actual_points]
            expected_points = [expected_points]
        errors = []
        for actual, expected in zip(actual_points, expected_points):
            error = math.dist(actual, expected)
            max_error = max(max_error, error)
            errors.append(error)
        registration_errors[key] = errors
    if max_error > registration["sourcePixelTolerance"]:
        fail(
            "actual Blender camera registration drift "
            f"{max_error:.6f}px exceeds {registration['sourcePixelTolerance']:.6f}px; "
            f"actual={actual_registration}"
        )

    portal = scene_data["portal"]
    inset_bounds = projected_bounds(blender_objects[portal["insetObjectID"]])
    header_bounds = projected_bounds(blender_objects[portal["headerObjectID"]])
    jamb_bounds = [projected_bounds(blender_objects[obj_id]) for obj_id in portal["jambObjectIDs"]]
    literal_scale_x = camera_spec["literalResolution"][0] / width
    literal_scale_y = camera_spec["literalResolution"][1] / height
    literal_portal = {
        "insetWidth": (inset_bounds["maxX"] - inset_bounds["minX"]) * literal_scale_x,
        "insetHeight": (inset_bounds["maxY"] - inset_bounds["minY"]) * literal_scale_y,
        "jambThicknesses": [
            min(
                (bounds["maxX"] - bounds["minX"]) * literal_scale_x,
                (bounds["maxY"] - bounds["minY"]) * literal_scale_y,
            )
            for bounds in jamb_bounds
        ],
        "headerThickness": min(
            (header_bounds["maxX"] - header_bounds["minX"]) * literal_scale_x,
            (header_bounds["maxY"] - header_bounds["minY"]) * literal_scale_y,
        ),
    }
    targets = portal["literal192Targets"]
    if literal_portal["insetWidth"] < targets["insetMinimumWidth"]:
        fail(f"literal portal width failed: {literal_portal['insetWidth']}")
    if literal_portal["insetHeight"] < targets["insetMinimumHeight"]:
        fail(f"literal portal height failed: {literal_portal['insetHeight']}")
    if min(literal_portal["jambThicknesses"]) < targets["jambMinimumThickness"]:
        fail(f"literal jamb thickness failed: {literal_portal['jambThicknesses']}")
    if literal_portal["headerThickness"] < targets["headerMinimumThickness"]:
        fail(f"literal header thickness failed: {literal_portal['headerThickness']}")

    process_ids = [
        spec["id"]
        for spec in scene_data["objects"]
        if spec["category"] in {"process", "gantry"}
    ]
    process_overlaps = []
    for process_id in process_ids:
        bounds = projected_bounds(blender_objects[process_id])
        overlap = rectangle_overlap(inset_bounds, bounds)
        if overlap["area"] > 1e-9:
            process_overlaps.append({"objectID": process_id, "overlap": overlap})
    if len(process_overlaps) > targets["maximumProcessOccluders"]:
        fail(f"process geometry overlaps portal projection: {process_overlaps}")

    silhouette_specs = [
        spec
        for spec in scene_data["objects"]
        if spec["category"] in {"hall", "administration", "roof", "process", "gantry"}
    ]
    silhouettes = [
        {"id": spec["id"], "tier": spec["silhouetteTier"], "bounds": projected_bounds(blender_objects[spec["id"]])}
        for spec in silhouette_specs
    ]
    skyline: list[float | None] = []
    for source_x in range(width):
        candidates = [
            entry["bounds"]["minY"]
            for entry in silhouettes
            if entry["bounds"]["minX"] <= source_x <= entry["bounds"]["maxX"]
        ]
        skyline.append(min(candidates) if candidates else None)
    breaks = 0
    previous: float | None = None
    for value in skyline:
        if value is None:
            continue
        if previous is not None and abs(value - previous) >= 8.0:
            breaks += 1
        previous = value
    if breaks < targets["minimumSilhouetteBreaks"]:
        fail(f"actual-camera silhouette breaks failed: {breaks}")

    object_manifest = []
    for spec in scene_data["objects"]:
        obj = blender_objects[spec["id"]]
        mesh_coordinates = [
            [round(coordinate, 9) for coordinate in vertex.co]
            for vertex in obj.data.vertices
        ]
        object_manifest.append(
            {
                "id": spec["id"],
                "category": spec["category"],
                "materialRole": spec["materialRole"],
                "location": [round(value, 9) for value in obj.location],
                "dimensions": [round(value, 9) for value in obj.dimensions],
                "meshVertexSHA256": sha256_bytes(canonical_bytes(mesh_coordinates)),
                "projectedBounds": projected_bounds(obj),
            }
        )

    return {
        "schema": "citysim.world-art.actual-camera-predesign-proof.v1",
        "task": "PLAY-079",
        "direction": "east",
        "phase": "PREDESIGN_ZERO_PIXEL",
        "result": "PASS",
        "blender": {
            "version": bpy.app.version_string,
            "versionTuple": list(bpy.app.version),
            "buildHash": bpy.app.build_hash.decode("utf-8"),
            "background": bpy.app.background,
            "factoryStartupRequiredByInvocation": True,
            "autoexecDisabledRequiredByInvocation": True
        },
        "camera": {
            "projection": camera_data.type,
            "location": list(camera.location),
            "target": camera_spec["target"],
            "yawDegrees": camera_spec["yawDegrees"],
            "elevationDegrees": camera_spec["elevationDegrees"],
            "orthoScale": camera_data.ortho_scale,
            "shiftX": camera_data.shift_x,
            "shiftY": camera_data.shift_y,
            "resolution": [width, height],
        },
        "registration": {
            "actualSourcePixels": actual_registration,
            "expectedSourcePixels": expected_registration,
            "errors": registration_errors,
            "maximumError": max_error,
            "tolerance": registration["sourcePixelTolerance"],
        },
        "literal192": {
            "portal": literal_portal,
            "targets": targets,
            "silhouetteBreakCount": breaks,
        },
        "occlusion": {
            "processObjectCount": len(process_ids),
            "portalProcessOverlapCount": len(process_overlaps),
            "overlaps": process_overlaps,
            "disposition": "ZERO_PROCESS_OCCLUSION",
        },
        "objectCount": len(object_manifest),
        "objectManifest": object_manifest,
        "renderInvocations": 0,
        "imagesWritten": 0,
        "renderAPIReferencesInValidator": 0,
        "sourceHashes": {
            "sceneSHA256": sha256_bytes(SCENE_PATH.read_bytes()),
            "materialsSHA256": sha256_bytes(MATERIALS_PATH.read_bytes()),
            "validatorSHA256": sha256_bytes(pathlib.Path(__file__).read_bytes()),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        choices=("static", "blender"),
        default="blender" if "bpy" in sys.modules else "static",
    )
    args, _ = parser.parse_known_args()
    scene = load_json(SCENE_PATH)
    materials = load_json(MATERIALS_PATH)
    if args.mode == "static":
        proof = static_proof(scene, materials)
    else:
        proof = blender_proof(scene, materials)
    sys.stdout.buffer.write(canonical_bytes(proof))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"FAIL PLAY-079 {error}", file=sys.stderr)
        raise
