#!/usr/bin/env python3
"""Validate Brickline Rowhouse source, four-view alignment, and manifest."""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


HERE = Path(__file__).resolve().parent
BLENDER_DIR = HERE.parents[1]
CANONICAL_DIR = BLENDER_DIR / "FourViewPipeline"
ASSET_ID = "brickline_rowhouse_apartments"
ASSET_DIR = HERE / ASSET_ID
CONFIG = json.loads((CANONICAL_DIR / "pipeline.json").read_text(encoding="utf-8"))
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL_DIR))
from png_canonical import decode_rgba_png  # noqa: E402


def fail(code: str, detail: str) -> None:
    raise RuntimeError(f"{code}: {detail}")


def close(actual: float, expected: float, label: str, tolerance: float = 1e-4) -> None:
    if abs(actual - expected) > tolerance:
        fail("VALUE_MISMATCH", f"{label}: {actual} != {expected}")


def close_vector(actual, expected, label: str, tolerance: float = 1e-4) -> None:
    for index, (left, right) in enumerate(zip(actual, expected)):
        close(float(left), float(right), f"{label}[{index}]", tolerance)


def projected_pixel(scene, camera, point: Vector) -> tuple[float, float]:
    ndc = world_to_camera_view(scene, camera, point)
    return ndc.x * scene.render.resolution_x, (1.0 - ndc.y) * scene.render.resolution_y


def alpha_bounds(path: Path) -> tuple[int, int, int, int]:
    width, height, rgba = decode_rgba_png(path)
    if (width, height) != (384, 384):
        fail("PNG_DIMENSION_MISMATCH", path.name)
    occupied = [(index // 4 % width, index // 4 // width) for index in range(3, len(rgba), 4) if rgba[index] > 0]
    if not occupied:
        fail("EMPTY_ALPHA", path.name)
    xs, ys = zip(*occupied)
    bounds = min(xs), min(ys), max(xs), max(ys)
    if bounds == (0, 0, width - 1, height - 1):
        fail("TRIMMED_OR_OPAQUE_CANVAS", path.name)
    return bounds


def validate_scene() -> dict[str, list[float]]:
    scene = bpy.context.scene
    if ".".join(map(str, bpy.app.version)) != CONFIG["toolchain"]["blenderVersion"]:
        fail("BLENDER_VERSION_MISMATCH", str(bpy.app.version))
    root = bpy.data.objects.get(CONFIG["root"]["name"])
    pivot = bpy.data.objects.get(CONFIG["root"]["pivotName"])
    if root is None or pivot is None or pivot.parent != root:
        fail("ROOT_OR_PIVOT_MISMATCH", "missing canonical parented root/pivot")
    close_vector(root.location, (0, 0, 0), "root.location")
    close_vector(root.rotation_euler, (0, 0, 0), "root.rotation")
    close_vector(root.scale, (1, 1, 1), "root.scale")
    if root.get("liveAsset") is not False or root.get("sourcePixelsReused") is not False:
        fail("PROVENANCE_MISMATCH", "asset must remain original and non-live")
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if len(meshes) < 100:
        fail("ASSET_DETAIL_TOO_LOW", str(len(meshes)))
    for obj in meshes:
        if obj.parent != root:
            fail("MESH_OUTSIDE_ROOT", obj.name)
        close_vector(obj.scale, (1, 1, 1), f"{obj.name}.scale")
        close_vector(obj.rotation_euler, (0, 0, 0), f"{obj.name}.rotation")

    lights = [obj for obj in bpy.data.objects if obj.type == "LIGHT"]
    if len(lights) != 1 or lights[0].name != CONFIG["lighting"]["name"]:
        fail("LIGHT_RIG_MISMATCH", str([obj.name for obj in lights]))
    close_vector(lights[0].location, CONFIG["lighting"]["location"], "light.location")
    close(lights[0].data.energy, CONFIG["lighting"]["energy"], "light.energy")
    close_vector(lights[0].data.color, CONFIG["lighting"]["color"], "light.color")

    result = {}
    for view in CONFIG["cameraRig"]["views"]:
        camera = bpy.data.objects.get(view["name"])
        if camera is None or camera.data.type != "ORTHO":
            fail("CAMERA_MISSING_OR_PERSPECTIVE", view["name"])
        close(camera.data.ortho_scale, CONFIG["cameraRig"]["orthoScale"], f"{camera.name}.orthoScale", 1e-5)
        horizontal = math.hypot(camera.location.x, camera.location.y)
        close(math.degrees(math.atan2(camera.location.z, horizontal)), 30, f"{camera.name}.elevation")
        close(math.degrees(math.atan2(camera.location.x, camera.location.y)) % 360, view["azimuthDegrees"], f"{camera.name}.azimuth")
        pixel = projected_pixel(scene, camera, Vector((0, 0, 0)))
        close_vector(pixel, (192, 300), f"{camera.name}.pivot", .01)
        result[camera.name] = [pixel[0], pixel[1]]

    tile = CONFIG["grid"]["worldTileSize"]
    camera = bpy.data.objects[CONFIG["cameraRig"]["views"][0]["name"]]
    points = [projected_pixel(scene, camera, Vector((x, y, 0))) for x, y in ((-tile/2, -tile/2), (tile/2, -tile/2), (tile/2, tile/2), (-tile/2, tile/2))]
    width = max(p[0] for p in points) - min(p[0] for p in points)
    height = max(p[1] for p in points) - min(p[1] for p in points)
    close_vector((width, height), (88, 44), "projectedTilePixels", .01)
    return result


def validate_outputs() -> dict[str, tuple[int, int, int, int]]:
    manifest_path = ASSET_DIR / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest["status"] != "source-only-not-live" or manifest["liveAsset"] is not False:
        fail("LIVE_STATUS_MISMATCH", str(manifest_path))
    if manifest["projectedTilePixels"] != [88, 44] or manifest["canvas"]["footprintPivotPixel"] != [192, 300]:
        fail("MANIFEST_GRID_MISMATCH", str(manifest_path))
    if manifest["postRenderCompensation"] != "none" or manifest["worldFootprintTiles"] != [2, 2]:
        fail("MANIFEST_TRANSFORM_OR_FOOTPRINT_MISMATCH", str(manifest_path))
    bounds = {}
    for view in CONFIG["cameraRig"]["views"]:
        path = ASSET_DIR / "renders" / f"{ASSET_ID}_{view['name']}.png"
        bounds[view["name"]] = alpha_bounds(path)
    for artifact in manifest["artifacts"]:
        path = HERE / artifact["path"]
        if not path.is_file() or path.stat().st_size != artifact["bytes"]:
            fail("ARTIFACT_MISSING_OR_SIZE_DRIFT", artifact["path"])
        if hashlib.sha256(path.read_bytes()).hexdigest() != artifact["sha256"]:
            fail("ARTIFACT_HASH_DRIFT", artifact["path"])
        if path.suffix.lower() == ".png":
            width, height, rgba = decode_rgba_png(path)
            if artifact["dimensions"] != [width, height] or artifact["decodedRgbaSha256"] != hashlib.sha256(rgba).hexdigest():
                fail("PNG_DECODED_DRIFT", artifact["path"])
    return bounds


def main() -> None:
    pivots = validate_scene()
    bounds = validate_outputs()
    print("RESIDENTIAL_EXPANSION_VALIDATION_PASS")
    print(json.dumps({"pivotPixels": pivots, "alphaBounds": bounds}, sort_keys=True))


if __name__ == "__main__":
    main()
