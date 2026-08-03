"""Blender child for the bounded PLAY-090 North runtime repair.

All grant, marker, root, route, tool and frozen-input checks complete before
``bpy`` is imported. The child lowers the committed text scene only; it does
not create Integration authority or declare source acceptance.
"""
from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import sys

import launch_residential_l01_process_a as runner


def parse_args(values: list[str] | None = None) -> argparse.Namespace:
    if values is None:
        if "--" not in sys.argv:
            raise ValueError("direct child invocation missing Blender separator")
        values = sys.argv[sys.argv.index("--") + 1 :]
    parser = argparse.ArgumentParser()
    parser.add_argument("--integration-direct", action="store_true")
    parser.add_argument("--runtime-replay", action="store_true")
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--schedule-path", required=True)
    parser.add_argument("--grant-path", required=True)
    parser.add_argument("--process-receipt-path", required=True)
    parser.add_argument("--attempt-marker-path", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(values)


def expected_marker(binding: dict) -> dict:
    return {
        "schema": 2, "kind": "play090-runtime-attempt", "state": "consumed", "task": "PLAY-090",
        "routeId": runner.ROUTE_ID, "workerHead": binding["currentHead"],
        "scheduleSHA256": binding["scheduleSHA256"], "grantSHA256": binding["grantSHA256"],
        "receiptSHA256": binding["receiptSHA256"],
        "outputRoot": "<fixture>/output" if binding["fixture"] else runner.FUTURE_PROCESS_ROOT,
        "maximumChildStarts": 1, "childStartMarker": "<attempt>.child-start",
        "sourceAuthority": False, "productionSelected": False,
    }


def build_scene_spec(root: Path) -> dict:
    scene_path = root / runner.SOURCE_ROOT / "DESIGN-SCENE.json"
    materials_path = root / runner.SOURCE_ROOT / "MATERIALS.json"
    lowering_path = root / runner.SOURCE_ROOT / runner.LOWERING_NAME
    scene = runner.load_json(scene_path)
    materials = runner.load_json(materials_path)
    lowering = runner.load_json(lowering_path)
    components = scene.get("components", [])
    ids = [item.get("id") for item in components]
    if len(components) != 19 or len(set(ids)) != 19 or None in ids:
        raise ValueError("exactly 19 uniquely identified authored components required")
    material_ids = {item.get("id") for item in materials.get("materials", [])}
    if None in material_ids or any(item.get("materialID") not in material_ids for item in components):
        raise ValueError("component material binding mismatch")
    kinds = {item.get("kind") for item in components}
    if not kinds <= set(lowering["geometry"]["supportedKinds"]) or kinds != {"box", "gablePrism", "shedPrism"}:
        raise ValueError("component lowering kinds mismatch")
    if runner.sha256_file(scene_path) != lowering["sceneSHA256"] or runner.sha256_file(materials_path) != lowering["materialsSHA256"]:
        raise ValueError("lowering frozen inputs drifted")
    return {"scene": scene, "materials": materials, "lowering": lowering, "componentIDs": ids,
            "materialIDs": sorted(material_ids), "scenePath": scene_path, "materialsPath": materials_path,
            "loweringPath": lowering_path}


def validate_launch(args: argparse.Namespace) -> dict:
    if not args.integration_direct or os.environ.get("CITYSIM_PLAY090_INTEGRATION_DIRECT") != "1":
        raise ValueError("direct child capability missing")
    root = runner.exact_repository_root(args.repository_root)
    route = runner.verify_route(root)
    contract = runner.validate_contract(root, args.contract)
    runner.verify_blender(root)
    binding = runner.validate_documents(root, contract, args.schedule_path, args.grant_path,
                                        args.process_receipt_path, args.output_root, args.runtime_replay)
    marker_path = Path(args.attempt_marker_path)
    if marker_path != binding["attempt"] or marker_path.is_symlink() or not marker_path.is_file():
        raise ValueError("consumed marker path mismatch")
    marker = runner.load_json(marker_path)
    if marker != expected_marker(binding):
        raise ValueError("consumed marker binding mismatch")
    output: Path = binding["output"]
    if output.is_symlink() or not output.is_dir() or any(output.iterdir()):
        raise ValueError("exclusive output root is missing, aliased, or nonempty")
    child_start = Path(os.fspath(marker_path) + ".child-start")
    start = runner.load_json(child_start)
    if start != {"schema": 1, "attemptSHA256": runner.sha256_file(marker_path),
                  "commandSHA256": start.get("commandSHA256"), "maximumChildStarts": 1}:
        raise ValueError("child-start marker binding mismatch")
    if type(start.get("commandSHA256")) is not str or len(start["commandSHA256"]) != 64:
        raise ValueError("child-start command hash invalid")
    spec = build_scene_spec(root)
    return {"root": root, "route": route, "contract": contract, "binding": binding,
            "marker": marker, "markerPath": marker_path, "output": output, "spec": spec}


def citysim_to_blender(point: list[float] | tuple[float, float, float]) -> tuple[float, float, float]:
    return float(point[2]), float(point[0]), float(point[1])


def create_materials(bpy, materials: dict) -> dict[str, object]:
    created: dict[str, object] = {}
    for item in materials["materials"]:
        material = bpy.data.materials.new(f"PLAY090::{item['id']}")
        material.use_nodes = True
        node = material.node_tree.nodes.get("Principled BSDF")
        if node is None:
            raise RuntimeError("Principled material node unavailable")
        color = tuple(float(value) for value in item["baseColorRGBA"])
        node.inputs["Base Color"].default_value = color
        node.inputs["Roughness"].default_value = float(item["roughness"])
        node.inputs["Metallic"].default_value = float(item["metalness"])
        created[item["id"]] = material
    return created


def source_mesh_for(component: dict, lowering: dict) -> tuple[list[tuple[float, float, float]], list[tuple[int, ...]]]:
    kind = component["kind"]
    if kind == "gablePrism":
        footprint = component["footprintWorld"]
        xs, zs = [float(p[0]) for p in footprint], [float(p[1]) for p in footprint]
        xmin, xmax, zmin, zmax = min(xs), max(xs), min(zs), max(zs)
        eave, ridge = float(component["eaveHeight"]), float(component["ridgeHeight"])
        if component["ridgeAxis"] == "z":
            middle = (xmin + xmax) / 2.0
            vertices = [(xmin, eave, zmin), (xmax, eave, zmin), (middle, ridge, zmin),
                        (xmin, eave, zmax), (xmax, eave, zmax), (middle, ridge, zmax)]
        elif component["ridgeAxis"] == "x":
            middle = (zmin + zmax) / 2.0
            vertices = [(xmin, eave, zmin), (xmin, eave, zmax), (xmin, ridge, middle),
                        (xmax, eave, zmin), (xmax, eave, zmax), (xmax, ridge, middle)]
        else:
            raise ValueError("unsupported gable ridge axis")
        faces = [(0, 3, 4, 1), (0, 1, 2), (3, 5, 4), (0, 2, 5, 3), (2, 1, 4, 5)]
        return vertices, faces
    if kind == "shedPrism":
        footprint = component["footprintWorld"]
        xs, zs = [float(p[0]) for p in footprint], [float(p[1]) for p in footprint]
        low, high = float(component["lowEdgeHeight"]), float(component["highEdgeHeight"])
        high_edge = component["highEdge"]
        def top_height(x: float, z: float) -> float:
            high_here = ((high_edge == "west" and x == min(xs)) or (high_edge == "east" and x == max(xs)) or
                         (high_edge == "north" and z == min(zs)) or (high_edge == "south" and z == max(zs)))
            return high if high_here else low
        tops = [(float(x), top_height(float(x), float(z)), float(z)) for x, z in footprint]
        thickness = float(lowering["geometry"]["shedVerticalThickness"])
        bottoms = [(x, y - thickness, z) for x, y, z in tops]
        vertices = bottoms + tops
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        return vertices, faces
    raise ValueError("mesh lowering requested for non-mesh component")


def create_geometry(bpy, scene: dict, lowering: dict, materials: dict[str, object]) -> list[dict]:
    manifest: list[dict] = []
    for component in scene["components"]:
        identifier, kind = component["id"], component["kind"]
        if kind == "box":
            bpy.ops.mesh.primitive_cube_add(location=citysim_to_blender(component["centerWorld"]))
            obj = bpy.context.object
            dx, dy, dz = [float(value) for value in component["dimensions"]]
            obj.dimensions = (dz, dx, dy)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            vertex_count, face_count = 8, 6
        else:
            source_vertices, faces = source_mesh_for(component, lowering)
            mesh = bpy.data.meshes.new(f"PLAY090::{identifier}::mesh")
            mesh.from_pydata([citysim_to_blender(point) for point in source_vertices], [], faces)
            mesh.validate(verbose=False)
            mesh.update(calc_edges=True)
            if not mesh.is_valid:
                raise RuntimeError(f"invalid closed mesh: {identifier}")
            obj = bpy.data.objects.new(identifier, mesh)
            bpy.context.collection.objects.link(obj)
            vertex_count, face_count = len(source_vertices), len(faces)
        obj.name = identifier
        obj.data.name = f"PLAY090::{identifier}::mesh"
        obj.data.materials.append(materials[component["materialID"]])
        manifest.append({"id": identifier, "kind": kind, "materialID": component["materialID"],
                         "semanticRole": component["semanticRole"], "vertexCount": vertex_count,
                         "faceCount": face_count, "closed": True})
    return manifest


def configure_camera(bpy, scene_doc: dict, lowering: dict) -> tuple[object, dict]:
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector

    data = bpy.data.cameras.new("PLAY090::NorthCamera")
    camera = bpy.data.objects.new("PLAY090::NorthCamera", data)
    bpy.context.collection.objects.link(camera)
    data.type = "ORTHO"
    width, height = [int(value) for value in scene_doc["camera"]["renderViewportPixels"]]
    analytic_scale = 256.0 / 56.0
    data.ortho_scale = float(height) * math.sqrt(0.5) / analytic_scale
    data.shift_x = 0.0
    data.shift_y = 0.25
    camera.location = citysim_to_blender(scene_doc["camera"]["positionWorld"])
    target = Vector(citysim_to_blender(scene_doc["camera"]["targetWorld"]))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera

    def project(source: list[float]) -> list[float]:
        ndc = world_to_camera_view(bpy.context.scene, camera, Vector(citysim_to_blender(source)))
        return [float(ndc.x) * width, (1.0 - float(ndc.y)) * height]
    ground = project([0, 0, 0])
    socket = project(scene_doc["registration"]["frontageSocketWorld"])
    target_ground = [float(v) for v in lowering["camera"]["sourceGroundCenter"]]
    target_socket = [float(v) for v in lowering["camera"]["sourceSocket"]]
    tolerance = float(lowering["camera"]["registrationTolerancePixels"])
    if max(abs(ground[i] - target_ground[i]) for i in range(2)) > tolerance:
        raise RuntimeError(f"ground registration drift: {ground}")
    if max(abs(socket[i] - target_socket[i]) for i in range(2)) > tolerance:
        raise RuntimeError(f"socket registration drift: {socket}")
    return camera, {"schema": 1, "viewport": [width, height], "groundPivotSource": ground,
                    "expectedGroundPivotSource": target_ground, "frontageSocketSource": socket,
                    "expectedFrontageSocketSource": target_socket, "tolerancePixels": tolerance,
                    "orthoScale": data.ortho_scale, "shift": [data.shift_x, data.shift_y]}


def point_area_light(bpy, name: str, origin: list[float], target: list[float], energy: float,
                     size: float, color: list[float] | tuple[float, ...]) -> object:
    from mathutils import Vector
    data = bpy.data.lights.new(name, type="AREA")
    data.shape = "DISK"
    data.energy = energy
    data.size = size
    data.color = tuple(float(value) for value in color[:3])
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = citysim_to_blender(origin)
    obj.rotation_euler = (Vector(citysim_to_blender(target)) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def configure_lighting_and_ground(bpy, scene_doc: dict, lowering: dict) -> dict:
    world = bpy.data.worlds.new("PLAY090::World")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background is None:
        raise RuntimeError("world background node unavailable")
    background.inputs["Color"].default_value = tuple(float(v) for v in scene_doc["light"]["ambientColorRGBA"])
    background.inputs["Strength"].default_value = float(lowering["lighting"]["worldStrength"])
    bpy.context.scene.world = world
    key_doc = lowering["lighting"]["key"]
    point_area_light(bpy, "PLAY090::Key", scene_doc["light"]["keyOrigin"], [0, 12, 0],
                     float(key_doc["energyWatts"]), float(key_doc["sizeWorld"]), scene_doc["light"]["keyColorRGBA"])
    fill_doc = lowering["lighting"]["fill"]
    point_area_light(bpy, "PLAY090::Fill", fill_doc["originWorld"], fill_doc["targetWorld"],
                     float(fill_doc["energyWatts"]), float(fill_doc["sizeWorld"]), fill_doc["colorRGB"])
    receiver = lowering["lighting"]["shadowReceiver"]
    bpy.ops.mesh.primitive_plane_add(size=float(receiver["sizeWorld"]), location=(0.0, 0.0, float(receiver["heightWorld"])))
    ground = bpy.context.object
    ground.name = "PLAY090::TransparentShadowReceiver"
    ground.is_shadow_catcher = True
    return {"worldStrength": lowering["lighting"]["worldStrength"], "keyOriginWorld": scene_doc["light"]["keyOrigin"],
            "fillOriginWorld": fill_doc["originWorld"], "shadowReceiver": ground.name,
            "shadowReceiverSizeWorld": receiver["sizeWorld"]}


def write_json(path: Path, value: object) -> None:
    runner.write_exclusive(path, runner.pretty_bytes(value))


def render_process(validated: dict) -> int:
    import bpy  # type: ignore

    if bpy.app.binary_path != runner.BLENDER or runner.sha256_file(Path(bpy.app.binary_path)) != runner.BLENDER_SHA256:
        raise RuntimeError("running Blender binary is not the admitted x86_64 executable")
    root, output, spec = validated["root"], validated["output"], validated["spec"]
    scene_doc, materials_doc, lowering = spec["scene"], spec["materials"], spec["lowering"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    render = lowering["render"]
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = int(render["samples"])
    scene.cycles.seed = int(render["seed"])
    scene.cycles.use_animated_seed = False
    scene.cycles.use_adaptive_sampling = False
    scene.cycles.use_denoising = False
    scene.render.use_motion_blur = False
    scene.render.film_transparent = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = int(render["threads"])
    scene.render.resolution_x, scene.render.resolution_y = [int(v) for v in render["resolution"]]
    scene.render.resolution_percentage = int(render["resolutionPercentage"])
    scene.render.pixel_aspect_x, scene.render.pixel_aspect_y = [float(v) for v in render["pixelAspect"]]
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 9
    scene.display_settings.display_device = render["colorManagement"]["displayDevice"]
    scene.view_settings.view_transform = render["colorManagement"]["viewTransform"]
    scene.view_settings.look = render["colorManagement"]["look"]
    scene.view_settings.exposure = float(render["colorManagement"]["exposure"])
    scene.view_settings.gamma = float(render["colorManagement"]["gamma"])

    materials = create_materials(bpy, materials_doc)
    manifest = create_geometry(bpy, scene_doc, lowering, materials)
    _, registration = configure_camera(bpy, scene_doc, lowering)
    lighting = configure_lighting_and_ground(bpy, scene_doc, lowering)
    if len(manifest) != 19 or {item["id"] for item in manifest} != set(spec["componentIDs"]):
        raise RuntimeError("authored component manifest mismatch")
    raw_path = output / "raw.png"
    blend_path = output / "scene.blend"
    scene.render.filepath = str(raw_path)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    bpy.ops.render.render(write_still=True)
    if not raw_path.is_file() or raw_path.stat().st_size == 0 or not blend_path.is_file() or blend_path.stat().st_size == 0:
        raise RuntimeError("Blender omitted nonempty render artifacts")
    input_bindings = {"schema": 1, "sceneSHA256": runner.sha256_file(spec["scenePath"]),
                      "materialsSHA256": runner.sha256_file(spec["materialsPath"]),
                      "loweringSHA256": runner.sha256_file(spec["loweringPath"]),
                      "contractSHA256": runner.sha256_file(root / runner.SOURCE_ROOT / runner.CONTRACT_NAME)}
    provenance = {"schema": 1, "task": "PLAY-090", "direction": "north", "process": "A",
                  "sceneGeometryID": scene_doc["sceneGeometryID"], "routeId": runner.ROUTE_ID,
                  "blender": {"path": runner.BLENDER, "sha256": runner.BLENDER_SHA256, "version": "4.5.12 LTS", "buildHash": "84afd5f785f7", "architecture": "x86_64", "translation": "Rosetta"},
                  "cycles": {"device": "CPU", "samples": render["samples"], "seed": render["seed"], "threads": render["threads"], "adaptiveSampling": False, "denoising": False},
                  "lighting": lighting, "rawPNGContainerSHA256": runner.sha256_file(raw_path),
                  "sourceAuthority": False, "productionSelected": False}
    process_receipt = {"schema": 1, "kind": "play090-child-process-receipt", "result": "PASS",
                       "routeId": runner.ROUTE_ID, "workerHead": validated["binding"]["currentHead"],
                       "componentCount": 19, "componentIDs": spec["componentIDs"], "materialIDs": spec["materialIDs"],
                       "cameraCount": 1, "lightCount": 2, "shadowReceiverCount": 1,
                       "artifacts": lowering["artifacts"], "sourceAuthority": False, "productionSelected": False}
    write_json(output / "OBJECT-MANIFEST.json", {"schema": 1, "authoredComponentCount": 19, "objects": manifest,
                                                  "shadowReceiver": "PLAY090::TransparentShadowReceiver"})
    write_json(output / "GROUND-REGISTRATION.json", registration)
    write_json(output / "INPUT-BINDINGS.json", input_bindings)
    write_json(output / "PROVENANCE.json", provenance)
    write_json(output / "PROCESS-RECEIPT.json", process_receipt)
    return 0


def main(values: list[str] | None = None) -> int:
    args = parse_args(values)
    validated = validate_launch(args)
    return render_process(validated)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"PLAY-090 child failure: {exc}", file=sys.stderr)
        raise SystemExit(78)
