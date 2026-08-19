#!/usr/bin/env python3
"""Independently validate the bounded CitySim commercial-variety source family."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import sys
import tempfile
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE = Path(__file__).resolve().parent
PRODUCTION = HERE.parent
BLENDER_ROOT = PRODUCTION.parent
CANONICAL = BLENDER_ROOT / "FourViewPipeline"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))
from png_canonical import decode_rgba_png  # noqa: E402


def load_builder():
    spec = importlib.util.spec_from_file_location("citysim_commercial_variety_builder", HERE / "build_and_render.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("COMMERCIAL_VARIETY_BUILDER_UNAVAILABLE")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


builder = load_builder()
CONFIG = json.loads((HERE / "pipeline.json").read_text(encoding="utf-8"))
CANONICAL_CONFIG = json.loads((CANONICAL / "pipeline.json").read_text(encoding="utf-8"))


def require(condition, code, detail):
    if not condition:
        raise RuntimeError(f"{code}: {detail}")


def close(actual, expected, tolerance, label):
    require(abs(float(actual) - float(expected)) <= tolerance, "VALUE_MISMATCH", f"{label}: {actual} != {expected}")


def vector(actual, expected, tolerance, label):
    require(len(actual) == len(expected), "VECTOR_LENGTH_MISMATCH", label)
    for index, (actual_value, expected_value) in enumerate(zip(actual, expected)):
        close(actual_value, expected_value, tolerance, f"{label}[{index}]")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def projected_pixel(scene, camera, point):
    projected = world_to_camera_view(scene, camera, Vector(point))
    return Vector((projected.x * 384, (1 - projected.y) * 384))


def mesh_bounds(meshes):
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    require(points, "EMPTY_GEOMETRY", "no mesh bounds")
    return {
        "minimum": [min(point[axis] for point in points) for axis in range(3)],
        "maximum": [max(point[axis] for point in points) for axis in range(3)],
    }


def validate_locked_contract():
    for key in ("toolchain", "grid", "canvas", "cameraRig", "root", "lighting"):
        require(CONFIG[key] == CANONICAL_CONFIG[key], "CANONICAL_CONTRACT_DRIFT", key)
    require(CONFIG["postRenderCompensation"] == "none", "POST_RENDER_COMPENSATION_FORBIDDEN", CONFIG["postRenderCompensation"])
    require(len(CONFIG["assets"]) == 2, "ASSET_COUNT_MISMATCH", len(CONFIG["assets"]))
    require(
        [asset["assetId"] for asset in CONFIG["assets"]]
        == ["sunbrick_market_lofts", "copperglass_exchange_annex"],
        "ASSET_ID_SET_MISMATCH",
        [asset["assetId"] for asset in CONFIG["assets"]],
    )


def validate_scene(asset):
    path = HERE / asset["assetId"] / f"{asset['assetId']}.blend"
    require(path.is_file(), "MISSING_BLEND", path)
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    require(scene.render.engine == CONFIG["toolchain"]["renderEngine"], "ENGINE_MISMATCH", scene.render.engine)
    require((scene.render.resolution_x, scene.render.resolution_y) == (384, 384), "CANVAS_MISMATCH", asset["assetId"])
    require(scene.render.film_transparent, "CANVAS_NOT_TRANSPARENT", asset["assetId"])
    require(scene.get("postRenderCompensation") == "none", "SCENE_COMPENSATION_FORBIDDEN", asset["assetId"])
    root = bpy.data.objects.get("AssetRoot")
    pivot = bpy.data.objects.get("FootprintPivot")
    require(root is not None and pivot is not None and pivot.parent == root, "ROOT_PIVOT_MISMATCH", asset["assetId"])
    vector(root.location, (0, 0, 0), 1e-5, "root.location")
    vector(root.rotation_euler, (0, 0, 0), 1e-5, "root.rotation")
    vector(root.scale, (1, 1, 1), 1e-5, "root.scale")
    vector(pivot.location, (0, 0, 0), 1e-5, "pivot.location")
    vector(pivot.rotation_euler, (0, 0, 0), 1e-5, "pivot.rotation")
    vector(pivot.scale, (1, 1, 1), 1e-5, "pivot.scale")
    require(root.get("assetId") == asset["assetId"], "ROOT_IDENTITY_MISMATCH", asset["assetId"])
    require(root.get("assetFamily") == asset["assetFamily"] and root.get("zone") == "commercial", "ROOT_FAMILY_MISMATCH", asset["assetId"])
    require(root.get("densityLevel") == asset["densityLevel"], "ROOT_DENSITY_MISMATCH", asset["assetId"])
    require(list(root.get("worldFootprintTiles")) == [2, 2], "ROOT_FOOTPRINT_MISMATCH", asset["assetId"])
    require(root.get("sourcePixelsReused") is False and root.get("cedarMarketReused") is False, "PROVENANCE_MISMATCH", asset["assetId"])
    require(root.get("liveAsset") is False and root.get("postRenderCompensation") == "none", "SHIPPING_STATUS_MISMATCH", asset["assetId"])

    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    require(len(meshes) >= asset["minimumMeshCount"], "GEOMETRY_TOO_SIMPLE", f"{asset['assetId']}: {len(meshes)}")
    for obj in meshes:
        require(obj.parent == root, "MESH_OUTSIDE_ROOT", obj.name)
        vector(obj.scale, (1, 1, 1), 1e-5, obj.name + ".scale")
        vector(obj.rotation_euler, (0, 0, 0), 1e-5, obj.name + ".rotation")
    bounds = mesh_bounds(meshes)
    require(bounds["minimum"][2] >= -0.21, "GEOMETRY_BELOW_LOT", bounds)
    require(asset["minimumHeight"] <= bounds["maximum"][2] <= asset["maximumHeight"], "HEIGHT_OUTSIDE_CONTRACT", bounds)
    lot = next((obj for obj in meshes if obj.name.endswith("LotGround")), None)
    require(lot is not None, "MISSING_GROUNDED_LOT", asset["assetId"])
    require(list(lot.get("worldFootprintTiles")) == [2, 2] and list(lot.get("exactWorldFootprint")) == [4.0, 4.0], "LOT_GRID_MISMATCH", asset["assetId"])

    required_names = {
        "sunbrick_market_lofts": {"SunbrickMarketPodium", "SunbrickPassageRecess", "SunbrickConservatoryGlass", "SunbrickFireEscapeSlab0"},
        "copperglass_exchange_annex": {"CopperglassLobbyPodium", "CopperglassMiddleSetback", "CopperglassUpperLantern", "CopperglassEntryCanopy"},
    }[asset["assetId"]]
    names = {obj.name for obj in bpy.data.objects}
    require(required_names <= names, "SEMANTIC_GEOMETRY_MISSING", sorted(required_names - names))

    lights = [obj for obj in bpy.data.objects if obj.type == "LIGHT"]
    require(len(lights) == 1 and lights[0].name == "CitySimKey", "LIGHT_SET_MISMATCH", [obj.name for obj in lights])
    light = lights[0]
    vector(light.location, CONFIG["lighting"]["location"], 1e-5, "light.location")
    close(light.data.energy, CONFIG["lighting"]["energy"], 1e-5, "light.energy")
    close(light.data.size, CONFIG["lighting"]["size"], 1e-5, "light.size")
    vector(light.data.color, CONFIG["lighting"]["color"], 1e-5, "light.color")

    expected_names = [view["name"] for view in CONFIG["cameraRig"]["views"]]
    cameras = [obj for obj in bpy.data.objects if obj.type == "CAMERA"]
    require(sorted(camera.name for camera in cameras) == sorted(expected_names), "CAMERA_SET_MISMATCH", [camera.name for camera in cameras])
    axes = {}
    for view in CONFIG["cameraRig"]["views"]:
        camera = bpy.data.objects[view["name"]]
        require(camera.data.type == "ORTHO", "CAMERA_NOT_ORTHO", camera.name)
        close(camera.data.ortho_scale, CONFIG["cameraRig"]["orthoScale"], 1e-5, camera.name + ".orthoScale")
        close(camera.data.shift_y, CONFIG["cameraRig"]["shiftY"], 1e-5, camera.name + ".shiftY")
        origin = projected_pixel(scene, camera, (0, 0, 0))
        vector(origin, (192, 300), 0.01, camera.name + ".pivotPixel")
        horizontal = math.hypot(camera.location.x, camera.location.y)
        close(math.degrees(math.atan2(camera.location.z, horizontal)), 30, 0.0001, camera.name + ".elevation")
        close(math.degrees(math.atan2(camera.location.x, camera.location.y)) % 360, view["azimuthDegrees"], 0.0001, camera.name + ".azimuth")
        x_axis = projected_pixel(scene, camera, (2, 0, 0)) - origin
        y_axis = projected_pixel(scene, camera, (0, 2, 0)) - origin
        vector((abs(x_axis.x), abs(x_axis.y)), (44, 22), 0.01, camera.name + ".xAxisPixels")
        vector((abs(y_axis.x), abs(y_axis.y)), (44, 22), 0.01, camera.name + ".yAxisPixels")
        axes[camera.name] = [[round(x_axis.x), round(x_axis.y)], [round(y_axis.x), round(y_axis.y)]]
    require(len({str(value) for value in axes.values()}) == 4, "VIEW_ORIENTATION_NOT_UNIQUE", axes)
    return len(meshes), bounds, axes


def validate_artifact(item, base: Path):
    path = base / item["path"]
    require(path.is_file(), "MISSING_ARTIFACT", path)
    require(path.stat().st_size == item["bytes"] and sha256(path) == item["sha256"], "ARTIFACT_HASH_DRIFT", path)
    if path.suffix != ".png":
        return None
    width, height, rgba = decode_rgba_png(path)
    require([width, height] == item["dimensions"], "PNG_DIMENSION_DRIFT", path)
    require(hashlib.sha256(rgba).hexdigest() == item["decodedRgbaSha256"], "RGBA_HASH_DRIFT", path)
    return width, height, rgba


def validate_asset_manifest(asset):
    output_dir = HERE / asset["assetId"]
    path = output_dir / "manifest.json"
    require(path.is_file(), "MISSING_MANIFEST", path)
    data = json.loads(path.read_text(encoding="utf-8"))
    require(data["assetId"] == asset["assetId"] and data["assetFamily"] == asset["assetFamily"], "MANIFEST_IDENTITY_MISMATCH", path)
    require(data["status"] == "source-only-not-live" and data["liveAsset"] is False, "MANIFEST_STATUS_MISMATCH", path)
    require(data["originalGeometry"] is True and data["sourcePixelsReused"] is False and data["cedarMarketReused"] is False, "MANIFEST_PROVENANCE_MISMATCH", path)
    require(data["postRenderCompensation"] == "none", "MANIFEST_COMPENSATION_FORBIDDEN", path)
    require(data["perViewCompensation"] == {"crop": False, "offsetPixels": [0, 0], "rotationDegrees": 0.0, "scale": 1.0, "skew": [0.0, 0.0]}, "PER_VIEW_COMPENSATION_FORBIDDEN", path)
    expected_sources = {"build_and_render.py", "pipeline.json", "run_pipeline.sh", "validate.py"}
    require({item["path"] for item in data["sourceFiles"]} == expected_sources, "SOURCE_FILE_SET_MISMATCH", path)
    for source in data["sourceFiles"]:
        source_path = HERE / source["path"]
        require(source_path.is_file() and sha256(source_path) == source["sha256"], "SOURCE_HASH_DRIFT", source_path)
    render_hashes = {}
    for artifact in data["artifacts"]:
        decoded = validate_artifact(artifact, output_dir)
        if decoded is None:
            continue
        width, height, rgba = decoded
        expected = (784, 840) if "contact-sheet" in artifact["path"] else (384, 384)
        require((width, height) == expected, "PNG_CANVAS_MISMATCH", f"{artifact['path']}: {(width, height)}")
        if expected == (384, 384):
            alpha = rgba[3::4]
            require(any(alpha) and any(value == 0 for value in alpha), "ALPHA_POLICY_MISMATCH", artifact["path"])
            visible = [(index % width, index // width) for index, value in enumerate(alpha) if value]
            xs = [point[0] for point in visible]
            ys = [point[1] for point in visible]
            bounds = {"minX": min(xs), "minY": min(ys), "maxX": max(xs), "maxY": max(ys), "width": max(xs)-min(xs)+1, "height": max(ys)-min(ys)+1}
            require(bounds == artifact["alpha"]["boundsTopOrigin"], "ALPHA_BOUNDS_DRIFT", artifact["path"])
            require(min(xs) >= 2 and max(xs) <= 381 and min(ys) >= 2, "CANVAS_CLIPPING", bounds)
            require(330 <= max(ys) <= 350, "GROUND_CONTACT_ROW_MISMATCH", f"{artifact['path']}: {max(ys)}")
            require(rgba[(300 * width + 192) * 4 + 3] > 0, "PIVOT_CONTACT_MISSING", artifact["path"])
            render_hashes[Path(artifact["path"]).name] = artifact["sha256"]
    require(len(render_hashes) == 4, "FOUR_VIEW_RENDER_COUNT_MISMATCH", render_hashes)
    return render_hashes


def deterministic_asset_rerender(asset, temp_root):
    scene, _, cameras = builder.build_asset(asset)
    paths = builder.baseline.render_views(scene, cameras, asset["assetId"], temp_root / asset["assetId"] / "renders")
    hashes = {}
    for path in paths:
        original = HERE / asset["assetId"] / "renders" / path.name
        require(sha256(path) == sha256(original), "DETERMINISTIC_VIEW_RERENDER_MISMATCH", path.name)
        _, _, rgba = decode_rgba_png(path)
        _, _, original_rgba = decode_rgba_png(original)
        require(hashlib.sha256(rgba).hexdigest() == hashlib.sha256(original_rgba).hexdigest(), "DECODED_PIXEL_RERENDER_MISMATCH", path.name)
        hashes[path.name] = sha256(path)
    sheet = builder.baseline.contact_sheet(paths, temp_root / asset["assetId"] / f"{asset['assetId']}_contact-sheet.png")
    original_sheet = HERE / asset["assetId"] / sheet.name
    require(sha256(sheet) == sha256(original_sheet), "DETERMINISTIC_CONTACT_SHEET_MISMATCH", sheet.name)
    return hashes, sha256(sheet)


def validate_preview(temp_root):
    manifest_path = HERE / "preview/manifest.json"
    require(manifest_path.is_file(), "MISSING_PREVIEW_MANIFEST", manifest_path)
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(data["approvedFamilyContractOnly"] is True and data["cedarMarketReused"] is False, "PREVIEW_FAMILY_POLICY_MISMATCH", manifest_path)
    require(len(data["placements"]) == 4, "PREVIEW_ASSET_COUNT_MISMATCH", len(data["placements"]))
    require({item["assetId"] for item in data["placements"]} == {"market_arcade_midrise", "sunbrick_market_lofts", "aurora_exchange_tower", "copperglass_exchange_annex"}, "PREVIEW_ASSET_SET_MISMATCH", data["placements"])
    require({item["role"] for item in data["placements"]} == {"approved-medium-sibling", "new-medium-candidate", "approved-high-sibling", "new-high-candidate"}, "PREVIEW_ROLE_SET_MISMATCH", data["placements"])
    for placement in data["placements"]:
        require(placement["perAssetTransformCompensation"] == "none", "PREVIEW_TRANSFORM_COMPENSATION_FORBIDDEN", placement["assetId"])
        require(all(abs(float(value) / 2.0 - round(float(value) / 2.0)) < 1e-6 for value in placement["originWorld"][:2]), "PREVIEW_OFF_GRID", placement)
        source = BLENDER_ROOT / placement["sourceBlend"]
        require(source.is_file() and sha256(source) == placement["sourceBlendSha256"], "PREVIEW_SOURCE_DRIFT", source)
    dimensions = set()
    preview_hashes = {}
    for artifact in data["artifacts"]:
        decoded = validate_artifact(artifact, HERE)
        if decoded is not None:
            width, height, _ = decoded
            dimensions.add((width, height))
            preview_hashes[Path(artifact["path"]).name] = artifact["sha256"]
    require(dimensions == {(1280, 800), (900, 600)}, "PREVIEW_DIMENSIONS_MISMATCH", dimensions)

    bpy.ops.wm.open_mainfile(filepath=str(HERE / "preview/copper-row-commercial-block.blend"))
    camera = bpy.data.objects.get("camNE_CommercialBlockPreview")
    require(camera is not None and camera.data.type == "ORTHO", "PREVIEW_CAMERA_MISSING", camera)
    close(camera.data.ortho_scale, CONFIG["preview"]["camera"]["orthoScale"], 1e-5, "preview.orthoScale")
    target = Vector(CONFIG["preview"]["camera"]["targetWorld"])
    offset = camera.location - target
    close(math.degrees(math.atan2(offset.z, math.hypot(offset.x, offset.y))), 30, 0.0001, "preview.elevation")
    close(math.degrees(math.atan2(offset.x, offset.y)) % 360, 45, 0.0001, "preview.azimuth")
    lights = [obj for obj in bpy.data.objects if obj.type == "LIGHT"]
    require(len(lights) == 1 and lights[0].name == "CitySimKey", "PREVIEW_LIGHT_MISMATCH", [obj.name for obj in lights])
    for placement in data["placements"]:
        obj = bpy.data.objects.get("Placement_" + placement["assetId"])
        require(obj is not None, "PREVIEW_PLACEMENT_MISSING", placement["assetId"])
        vector(obj.location, placement["originWorld"], 1e-5, obj.name + ".location")
        vector(obj.rotation_euler, (0, 0, 0), 1e-5, obj.name + ".rotation")
        vector(obj.scale, (1, 1, 1), 1e-5, obj.name + ".scale")
    for road_name in ("XAxisRoad", "YAxisRoad"):
        road = bpy.data.objects.get(road_name)
        require(road is not None, "PREVIEW_ROAD_MISSING", road_name)
        vector(road.rotation_euler, (0, 0, 0), 1e-5, road_name + ".rotation")
        vector(road.scale, (1, 1, 1), 1e-5, road_name + ".scale")

    generated = builder.build_preview(temp_root)
    rerender_hashes = {}
    for path in generated:
        if path.suffix != ".png":
            continue
        original = HERE / "preview" / path.name
        require(sha256(path) == sha256(original), "PREVIEW_DETERMINISTIC_RERENDER_MISMATCH", path.name)
        rerender_hashes[path.name] = sha256(path)
    require(rerender_hashes == preview_hashes, "PREVIEW_RERENDER_HASH_SET_MISMATCH", rerender_hashes)
    return preview_hashes, rerender_hashes


def validate_family_manifest():
    path = HERE / "family-manifest.json"
    require(path.is_file(), "MISSING_FAMILY_MANIFEST", path)
    data = json.loads(path.read_text(encoding="utf-8"))
    require(data["assetIds"] == ["sunbrick_market_lofts", "copperglass_exchange_annex"] and data["assetCount"] == 2, "FAMILY_IDENTITY_MISMATCH", data)
    require(data["status"] == "source-only-not-live" and data["liveAsset"] is False, "FAMILY_STATUS_MISMATCH", data)
    require(data["originalGeometry"] is True and data["sourcePixelsReused"] is False and data["cedarMarketReused"] is False, "FAMILY_PROVENANCE_MISMATCH", data)
    require(data["lockedContract"] == {key: CONFIG[key] for key in ("toolchain", "grid", "canvas", "cameraRig", "root", "lighting")}, "FAMILY_CONTRACT_DRIFT", path)
    png_count = 0
    for artifact in data["artifacts"]:
        decoded = validate_artifact(artifact, HERE)
        png_count += int(decoded is not None)
    require(png_count == 12, "FAMILY_PNG_COUNT_MISMATCH", png_count)
    require({item["assetId"] for item in data["approvedStyleBaseline"]} == {"market_arcade_midrise", "aurora_exchange_tower"}, "BASELINE_SOURCE_SET_MISMATCH", data["approvedStyleBaseline"])
    for item in data["approvedStyleBaseline"]:
        source = BLENDER_ROOT / item["sourceBlend"]
        require(source.is_file() and sha256(source) == item["sha256"], "BASELINE_SOURCE_DRIFT", source)


def report_path() -> Path:
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if "--report" not in args:
        return HERE / "validation/validator-output.txt"
    return Path(args[args.index("--report") + 1])


def main():
    actual = ".".join(map(str, bpy.app.version))
    require(actual == CONFIG["toolchain"]["blenderVersion"], "BLENDER_VERSION_MISMATCH", actual)
    validate_locked_contract()
    results = {
        "schema": "citysim.world-art.commercial-variety-validation.v1",
        "status": "PASS",
        "blenderVersion": actual,
        "assets": {},
        "contract": {
            "projectedTilePixels": [88, 44],
            "pivotPixels": [192, 300],
            "cameraOrder": [view["name"] for view in CONFIG["cameraRig"]["views"]],
            "postRenderCompensation": "none",
            "deterministicRerender": "byte-identical canonical views, contact sheets, and composed previews",
        },
    }
    with tempfile.TemporaryDirectory(prefix="citysim-commercial-variety-") as temp_dir:
        temp_root = Path(temp_dir)
        for asset in CONFIG["assets"]:
            mesh_count, bounds, axes = validate_scene(asset)
            manifest_hashes = validate_asset_manifest(asset)
            rerender_hashes, sheet_hash = deterministic_asset_rerender(asset, temp_root)
            require(manifest_hashes == rerender_hashes, "ASSET_RERENDER_HASH_SET_MISMATCH", asset["assetId"])
            results["assets"][asset["assetId"]] = {
                "meshCount": mesh_count,
                "worldBounds": bounds,
                "projectedAxisPixels": axes,
                "deterministicCanonicalPngSha256": rerender_hashes,
                "deterministicContactSheetSha256": sheet_hash,
            }
        preview_hashes, preview_rerenders = validate_preview(temp_root)
        results["previewPngSha256"] = preview_hashes
        results["previewDeterministicRerenderSha256"] = preview_rerenders
    validate_family_manifest()
    report = json.dumps(results, indent=2, sort_keys=True) + "\nCOMMERCIAL_VARIETY_VALIDATION_PASS\n"
    path = report_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(report, encoding="utf-8")
    print(report, end="")


if __name__ == "__main__":
    main()
