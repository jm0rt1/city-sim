#!/usr/bin/env python3
"""Validate the saved Blender source and four-view raster alignment."""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


PIPELINE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = PIPELINE_DIR / "pipeline.json"
EXAMPLE_DIR = PIPELINE_DIR / "example"
EPSILON = 1e-4
sys.dont_write_bytecode = True
sys.path.insert(0, str(PIPELINE_DIR))

from png_canonical import decode_rgba_png  # noqa: E402


def fail(code: str, detail: str) -> None:
    raise RuntimeError(f"{code}: {detail}")


def close(actual: float, expected: float, label: str, tolerance: float = EPSILON) -> None:
    if abs(actual - expected) > tolerance:
        fail("VALUE_MISMATCH", f"{label}: {actual} != {expected}")


def close_vector(actual, expected, label: str, tolerance: float = EPSILON) -> None:
    if len(actual) != len(expected):
        fail("VECTOR_LENGTH_MISMATCH", label)
    for index, (left, right) in enumerate(zip(actual, expected)):
        close(float(left), float(right), f"{label}[{index}]", tolerance)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_image(path: Path, expected_size: tuple[int, int]) -> tuple[bytes, tuple[int, int, int, int]]:
    if not path.is_file():
        fail("MISSING_OUTPUT", str(path))
    width, height, pixels = decode_rgba_png(path)
    if (width, height) != expected_size:
        fail("OUTPUT_SIZE_MISMATCH", f"{path.name}: {(width, height)} != {expected_size}")
    occupied_x = []
    occupied_y = []
    for index in range(3, len(pixels), 4):
        if pixels[index] > 0:
            pixel = index // 4
            occupied_x.append(pixel % width)
            occupied_y.append(pixel // width)
    if not occupied_x:
        fail("EMPTY_ALPHA", path.name)
    bounds = (min(occupied_x), min(occupied_y), max(occupied_x), max(occupied_y))
    if bounds == (0, 0, width - 1, height - 1):
        fail("OPAQUE_OR_TRIMMED_CANVAS", path.name)
    return pixels, bounds


def projected_pixel(scene: bpy.types.Scene, camera: bpy.types.Object, point: Vector) -> tuple[float, float]:
    ndc = world_to_camera_view(scene, camera, point)
    return (
        ndc.x * scene.render.resolution_x,
        (1.0 - ndc.y) * scene.render.resolution_y,
    )


def validate_scene(config: dict) -> dict[str, tuple[float, float]]:
    scene = bpy.context.scene
    numeric_version = ".".join(str(value) for value in bpy.app.version)
    if numeric_version != config["toolchain"]["blenderVersion"]:
        fail("BLENDER_VERSION_MISMATCH", numeric_version)
    if scene.render.engine != config["toolchain"]["renderEngine"]:
        fail("RENDER_ENGINE_MISMATCH", scene.render.engine)
    canvas = config["canvas"]
    if (scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage) != (canvas["width"], canvas["height"], 100):
        fail("CANVAS_MISMATCH", str((scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage)))
    if not scene.render.film_transparent or not canvas["transparent"] or canvas["trim"]:
        fail("TRANSPARENCY_OR_TRIM_POLICY_MISMATCH", "expected transparent untrimmed output")
    if scene.get("postRenderCompensation") != "none" or config["output"]["postRenderCompensation"] != "none":
        fail("POST_RENDER_COMPENSATION_FORBIDDEN", "must be none")

    root = bpy.data.objects.get(config["root"]["name"])
    pivot = bpy.data.objects.get(config["root"]["pivotName"])
    if root is None or pivot is None:
        fail("MISSING_ROOT_OR_PIVOT", "AssetRoot and FootprintPivot are required")
    close_vector(root.location, config["root"]["location"], "root.location")
    close_vector(root.rotation_euler, config["root"]["rotationEuler"], "root.rotation")
    close_vector(root.scale, config["root"]["scale"], "root.scale")
    close_vector(pivot.matrix_world.translation, config["root"]["location"], "pivot.worldLocation")
    if pivot.parent != root:
        fail("PIVOT_PARENT_MISMATCH", pivot.parent.name if pivot.parent else "none")
    if root.get("sourcePixelsReused") is not False or root.get("liveAsset") is not False:
        fail("EXAMPLE_PROVENANCE_MISMATCH", "example must be original and non-live")

    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if len(meshes) < 18:
        fail("REFERENCE_HOUSE_TOO_SIMPLE", f"expected reusable-detail proof; found {len(meshes)} mesh parts")
    for obj in meshes:
        if obj.parent != root:
            fail("MESH_OUTSIDE_ASSET_ROOT", obj.name)
        close_vector(obj.scale, (1.0, 1.0, 1.0), f"{obj.name}.scale")
        close_vector(obj.rotation_euler, (0.0, 0.0, 0.0), f"{obj.name}.rotation")

    lights = list(bpy.data.objects)
    lights = [obj for obj in lights if obj.type == "LIGHT"]
    if [light.name for light in lights] != [config["lighting"]["name"]]:
        fail("LIGHT_CONVENTION_MISMATCH", str([light.name for light in lights]))
    light = lights[0]
    if light.data.type != config["lighting"]["type"]:
        fail("LIGHT_TYPE_MISMATCH", light.data.type)
    close_vector(light.location, config["lighting"]["location"], "light.location")
    close(light.data.energy, config["lighting"]["energy"], "light.energy")
    close(light.data.size, config["lighting"]["size"], "light.size")

    expected_names = [view["name"] for view in config["cameraRig"]["views"]]
    cameras = [obj for obj in bpy.data.objects if obj.type == "CAMERA"]
    if sorted(camera.name for camera in cameras) != sorted(expected_names):
        fail("CAMERA_NAMING_MISMATCH", str([camera.name for camera in cameras]))
    projected = {}
    azimuths = []
    for view in config["cameraRig"]["views"]:
        camera = bpy.data.objects[view["name"]]
        if camera.data.type != "ORTHO":
            fail("CAMERA_NOT_ORTHOGRAPHIC", camera.name)
        close(camera.data.ortho_scale, config["cameraRig"]["orthoScale"], f"{camera.name}.orthoScale", 1e-5)
        close(camera.data.shift_x, 0.0, f"{camera.name}.shiftX")
        close(camera.data.shift_y, config["cameraRig"]["shiftY"], f"{camera.name}.shiftY")
        horizontal = math.hypot(camera.location.x, camera.location.y)
        distance = math.sqrt(horizontal * horizontal + camera.location.z * camera.location.z)
        elevation = math.degrees(math.atan2(camera.location.z, horizontal))
        azimuth = math.degrees(math.atan2(camera.location.x, camera.location.y)) % 360.0
        close(distance, config["cameraRig"]["distance"], f"{camera.name}.distance", 1e-3)
        close(elevation, config["grid"]["elevationDegrees"], f"{camera.name}.elevation", 1e-4)
        close(azimuth, view["azimuthDegrees"], f"{camera.name}.azimuth", 1e-4)
        forward = camera.rotation_euler.to_quaternion() @ Vector((0.0, 0.0, -1.0))
        expected_forward = (Vector((0.0, 0.0, 0.0)) - camera.location).normalized()
        if forward.dot(expected_forward) < 0.999999:
            fail("CAMERA_NOT_AIMED_AT_SHARED_PIVOT", camera.name)
        projected[camera.name] = projected_pixel(scene, camera, Vector((0.0, 0.0, 0.0)))
        close_vector(projected[camera.name], canvas["footprintPivotPixel"], f"{camera.name}.pivotPixel", 0.01)
        azimuths.append(azimuth)
    for left, right in zip(azimuths, azimuths[1:] + [azimuths[0] + 360.0]):
        close(right - left, 90.0, "camera.azimuthInterval", 1e-4)

    tile = config["grid"]["worldTileSize"]
    camera = bpy.data.objects[expected_names[0]]
    corners = [
        projected_pixel(scene, camera, Vector((-tile / 2, -tile / 2, 0.0))),
        projected_pixel(scene, camera, Vector((tile / 2, -tile / 2, 0.0))),
        projected_pixel(scene, camera, Vector((tile / 2, tile / 2, 0.0))),
        projected_pixel(scene, camera, Vector((-tile / 2, tile / 2, 0.0))),
    ]
    width = max(point[0] for point in corners) - min(point[0] for point in corners)
    height = max(point[1] for point in corners) - min(point[1] for point in corners)
    close_vector((width, height), config["grid"]["projectedTilePixels"], "projectedTilePixels", 0.01)
    close(width / height, 2.0, "projectedTileRatio", 1e-4)
    return projected


def validate_outputs(config: dict) -> dict[str, tuple[int, int, int, int]]:
    expected_size = (config["canvas"]["width"], config["canvas"]["height"])
    bounds = {}
    for view in config["cameraRig"]["views"]:
        name = view["name"]
        path = EXAMPLE_DIR / "renders" / config["output"]["filePattern"].format(camera=name)
        _pixels, alpha_bounds = load_image(path, expected_size)
        bounds[name] = alpha_bounds

    contact_path = EXAMPLE_DIR / config["output"]["contactSheet"]
    contact_size = (expected_size[0] * 2 + 16, expected_size[1] * 2 + 16)
    _contact, _contact_bounds = load_image(contact_path, contact_size)

    manifest_path = EXAMPLE_DIR / config["output"]["manifest"]
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest["pipelineSchema"] != config["schema"] or manifest["assetId"] != config["output"]["assetId"]:
        fail("MANIFEST_IDENTITY_MISMATCH", str(manifest_path))
    if manifest["status"] != "source-example-only-not-live" or manifest["liveAsset"] is not False:
        fail("MANIFEST_LIVE_STATUS_MISMATCH", str(manifest_path))
    if manifest["postRenderCompensation"] != "none":
        fail("MANIFEST_COMPENSATION_FORBIDDEN", str(manifest_path))
    if manifest["cameraOrder"] != [view["name"] for view in config["cameraRig"]["views"]]:
        fail("MANIFEST_CAMERA_ORDER_MISMATCH", str(manifest["cameraOrder"]))
    for artifact in manifest["artifacts"]:
        path = PIPELINE_DIR / artifact["path"]
        if not path.is_file():
            fail("MANIFEST_ARTIFACT_MISSING", artifact["path"])
        if path.stat().st_size != artifact["bytes"] or sha256(path) != artifact["sha256"]:
            fail("MANIFEST_ARTIFACT_DRIFT", artifact["path"])
        if path.suffix.lower() == ".png":
            width, height, rgba = decode_rgba_png(path)
            if artifact.get("dimensions") != [width, height]:
                fail("MANIFEST_PNG_DIMENSION_DRIFT", artifact["path"])
            if artifact.get("decodedRgbaSha256") != hashlib.sha256(rgba).hexdigest():
                fail("MANIFEST_DECODED_RGBA_DRIFT", artifact["path"])
    return bounds


def main() -> None:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    projected = validate_scene(config)
    bounds = validate_outputs(config)
    print("FOUR_VIEW_PIPELINE_PASS")
    print(json.dumps({"alphaBoundsTopOrigin": bounds, "pivotPixelsTopOrigin": projected}, sort_keys=True))


if __name__ == "__main__":
    main()
