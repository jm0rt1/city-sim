"""Blender child for the bounded PLAY-090 North runtime repair.

All grant, marker, root, route, tool and frozen-input checks complete before
``bpy`` is imported. The child lowers the committed text scene only; it does
not create Integration authority or declare source acceptance.
"""
from __future__ import annotations

import argparse
import binascii
import json
import math
import os
from pathlib import Path
import struct
import sys


_CHILD_SCRIPT_PATH = Path(__file__)
if not _CHILD_SCRIPT_PATH.is_absolute():
    raise RuntimeError("PLAY-090 child script path must be absolute")
_CHILD_SCRIPT_REAL_PATH = _CHILD_SCRIPT_PATH.resolve(strict=True)
if _CHILD_SCRIPT_PATH != _CHILD_SCRIPT_REAL_PATH:
    raise RuntimeError("PLAY-090 child script path must be canonical and non-aliased")
_CHILD_SCRIPT_DIRECTORY = _CHILD_SCRIPT_REAL_PATH.parent
if _CHILD_SCRIPT_DIRECTORY.is_symlink():
    raise RuntimeError("PLAY-090 child script directory symlink rejected")
sys.path[:] = [entry for entry in sys.path if entry != str(_CHILD_SCRIPT_DIRECTORY)]
sys.path.insert(0, str(_CHILD_SCRIPT_DIRECTORY))

import launch_residential_l01_process_a as runner


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
NONDETERMINISTIC_BLENDER_TEXT_KEYS = frozenset({
    b"File", b"Date", b"RenderTime", b"cycles.ViewLayer.total_time",
    b"cycles.ViewLayer.render_time", b"cycles.ViewLayer.synchronization_time",
})


def validated_png_chunks(data: bytes) -> list[dict]:
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("PNG signature mismatch")
    chunks: list[dict] = []
    offset = len(PNG_SIGNATURE)
    saw_ihdr = False
    saw_idat = False
    saw_iend = False
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError("truncated PNG chunk framing")
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError("truncated PNG chunk payload")
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        stored_crc = struct.unpack(">I", data[offset + 8 + length:end])[0]
        computed_crc = binascii.crc32(kind + payload) & 0xFFFFFFFF
        if stored_crc != computed_crc:
            raise ValueError(f"PNG chunk CRC mismatch: {kind!r}")
        if not chunks and kind != b"IHDR":
            raise ValueError("PNG IHDR must be first")
        if kind == b"IHDR":
            if saw_ihdr or length != 13:
                raise ValueError("PNG IHDR shape invalid")
            saw_ihdr = True
        elif kind == b"IDAT":
            saw_idat = True
        elif kind == b"IEND":
            if saw_iend or length != 0 or end != len(data):
                raise ValueError("PNG IEND framing invalid")
            saw_iend = True
        if kind == b"tEXt":
            if b"\0" not in payload:
                raise ValueError("PNG tEXt keyword separator missing")
            keyword, text = payload.split(b"\0", 1)
            if not 1 <= len(keyword) <= 79 or b"\0" in text:
                raise ValueError("PNG tEXt payload invalid")
        else:
            keyword = None
        chunks.append({"kind": kind, "payload": payload, "keyword": keyword,
                       "raw": data[offset:end], "offset": offset})
        offset = end
        if kind == b"IEND":
            break
    if not saw_ihdr or not saw_idat or not saw_iend or offset != len(data):
        raise ValueError("PNG required chunk sequence incomplete")
    return chunks


def canonical_png_bytes(data: bytes) -> tuple[bytes, dict]:
    chunks = validated_png_chunks(data)
    removed = [chunk["keyword"] for chunk in chunks
               if chunk["kind"] == b"tEXt" and chunk["keyword"] in NONDETERMINISTIC_BLENDER_TEXT_KEYS]
    canonical = PNG_SIGNATURE + b"".join(
        chunk["raw"] for chunk in chunks
        if not (chunk["kind"] == b"tEXt" and chunk["keyword"] in NONDETERMINISTIC_BLENDER_TEXT_KEYS)
    )
    canonical_chunks = validated_png_chunks(canonical)
    remaining = {chunk["keyword"] for chunk in canonical_chunks if chunk["kind"] == b"tEXt"}
    if remaining & NONDETERMINISTIC_BLENDER_TEXT_KEYS:
        raise ValueError("nondeterministic Blender PNG text remained")
    report = {"schema": 1, "method": "preserve-chunks-strip-nondeterministic-blender-text-v1",
              "removedTextKeywords": sorted(keyword.decode("latin1") for keyword in removed),
              "canonicalSHA256": runner.sha256_bytes(canonical)}
    return canonical, report


def canonicalize_blender_png(path: Path) -> dict:
    canonical, report = canonical_png_bytes(path.read_bytes())
    temporary = path.with_name(f".{path.name}.canonical.tmp")
    runner.write_exclusive(temporary, canonical)
    try:
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
    if runner.sha256_file(path) != report["canonicalSHA256"]:
        raise RuntimeError("canonical PNG replacement drift")
    return report


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
    bridge_path = runner.safe_repo_path(root, lowering["coordinateBridge"]["authorityPath"])
    if not bridge_path.is_file() or runner.sha256_file(bridge_path) != lowering["coordinateBridge"]["authoritySHA256"]:
        raise ValueError("CONTRACT-020 bridge authority drift")
    bridge = runner.load_json(bridge_path)
    validate_bridge_binding(lowering, bridge)
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
            "loweringPath": lowering_path, "bridgePath": bridge_path, "bridge": bridge}


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


def validate_bridge_binding(lowering: dict, bridge: dict) -> None:
    coordinate = lowering["coordinateBridge"]
    camera = lowering["camera"]
    registration = lowering["registration"]
    if (coordinate["contract"] != bridge["contract"] or coordinate["formula"] != bridge["basis"]["formula"] or
            coordinate["matrixRows"] != bridge["basis"]["matrixRows"]):
        raise ValueError("coordinate bridge basis mismatch")
    expected_camera = {
        "type": "ORTHO", "projection": "orthographic-2:1",
        "citySimPosition": bridge["camera"]["citySimPosition"],
        "citySimTarget": bridge["camera"]["citySimTarget"],
        "blenderOrthographicScale": bridge["camera"]["blenderOrthographicScale"],
        "renderViewportPixels": bridge["camera"]["renderViewportPixels"],
        "shift": [bridge["camera"]["shiftX"], bridge["camera"]["shiftY"]],
        "sourceGroundCenter": bridge["camera"]["sourceGroundCenter"],
        "sourceSocket": bridge["directions"]["north"]["socketSource"],
        "registrationTolerancePixels": bridge["toleranceSourcePixels"],
    }
    expected_registration = {
        "originCitySim": bridge["registration"]["originCitySim"],
        "originSource": bridge["registration"]["originSource"],
        "footprintCitySimXYZ": bridge["registration"]["contactPolygonCitySimXYZ"],
        "footprintSource": bridge["registration"]["footprintSource"],
        "pivotCitySim": bridge["registration"]["pivotCitySim"],
        "pivotSource": bridge["registration"]["pivotSource"],
        "northSocketCitySim": bridge["directions"]["north"]["socketCitySim"],
        "northSocketSource": bridge["directions"]["north"]["socketSource"],
    }
    if camera != expected_camera or registration != expected_registration:
        raise ValueError("camera bridge projection binding mismatch")


def project_bridge_citysim(point: list[float], lowering: dict) -> list[float]:
    camera = lowering["camera"]
    registration = lowering["registration"]

    def subtract(first, second):
        return tuple(float(first[index]) - float(second[index]) for index in range(3))

    def normalize(vector):
        magnitude = math.sqrt(sum(value * value for value in vector))
        if magnitude == 0:
            raise ValueError("zero-length camera bridge vector")
        return tuple(value / magnitude for value in vector)

    def cross(first, second):
        return (first[1] * second[2] - first[2] * second[1],
                first[2] * second[0] - first[0] * second[2],
                first[0] * second[1] - first[1] * second[0])

    def dot(first, second):
        return sum(first[index] * second[index] for index in range(3))

    position = citysim_to_blender(camera["citySimPosition"])
    target = citysim_to_blender(camera["citySimTarget"])
    forward = normalize(subtract(target, position))
    right = normalize(cross(forward, (0.0, 0.0, 1.0)))
    up = normalize(cross(right, forward))
    origin = citysim_to_blender(registration["originCitySim"])
    delta = subtract(citysim_to_blender(point), origin)
    width = float(camera["renderViewportPixels"][0])
    pixels_per_unit = width / float(camera["blenderOrthographicScale"])
    source_origin = registration["originSource"]
    return [float(source_origin[0]) + dot(delta, right) * pixels_per_unit,
            float(source_origin[1]) - dot(delta, up) * pixels_per_unit]


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


def validate_authored_topology(vertices: list[tuple[float, float, float]],
                               faces: list[tuple[int, ...]], identifier: str) -> dict:
    if len(vertices) < 4 or len(faces) < 4:
        raise ValueError(f"insufficient authored topology: {identifier}")
    if any(len(vertex) != 3 or any(not math.isfinite(float(value)) for value in vertex) for vertex in vertices):
        raise ValueError(f"non-finite authored vertex: {identifier}")
    edge_counts: dict[tuple[int, int], int] = {}
    canonical_faces: set[frozenset[int]] = set()
    for face in faces:
        if len(face) < 3 or any(type(index) is not int or index < 0 or index >= len(vertices) for index in face):
            raise ValueError(f"invalid authored face index: {identifier}")
        if len(set(face)) != len(face):
            raise ValueError(f"repeated authored face vertex: {identifier}")
        canonical = frozenset(face)
        if canonical in canonical_faces:
            raise ValueError(f"duplicate authored face: {identifier}")
        canonical_faces.add(canonical)
        for offset, first in enumerate(face):
            second = face[(offset + 1) % len(face)]
            edge = (min(first, second), max(first, second))
            edge_counts[edge] = edge_counts.get(edge, 0) + 1
    if not edge_counts or any(count != 2 for count in edge_counts.values()):
        raise ValueError(f"authored mesh is not closed two-manifold topology: {identifier}")
    if len(vertices) - len(edge_counts) + len(faces) != 2:
        raise ValueError(f"authored mesh Euler invariant failed: {identifier}")
    return {"vertices": len(vertices), "edges": len(edge_counts), "faces": len(faces), "closed": True}


def validate_blender_mesh(mesh, identifier: str) -> None:
    corrected = mesh.validate(verbose=False, clean_customdata=True)
    if corrected:
        raise RuntimeError(f"Blender corrected invalid authored mesh: {identifier}")
    mesh.update(calc_edges=True)


def registration_targets(scene_doc: dict, lowering: dict) -> dict:
    registration = scene_doc["registration"]
    bridge_registration = lowering["registration"]
    target_ground = [float(value) for value in bridge_registration["pivotSource"]]
    pre_offset_center = [float(value) for value in scene_doc["camera"]["sourceGroundCenter"]]
    lowering_center = [float(value) for value in lowering["camera"]["sourceGroundCenter"]]
    target_socket = [float(value) for value in bridge_registration["northSocketSource"]]
    scene_socket = [float(value) for value in registration["frontageSocketSource"]]
    tolerance = float(lowering["camera"]["registrationTolerancePixels"])
    scene_footprint = [[float(value) for value in point] for point in registration["footprintPolygonSource"]]
    bridge_footprint = [[float(value) for value in point] for point in bridge_registration["footprintSource"]]
    if pre_offset_center != lowering_center or lowering_center != [float(value) for value in bridge_registration["originSource"]]:
        raise ValueError("pre-offset camera center authority mismatch")
    if target_ground != [float(value) for value in registration["groundPivotSource"]] or scene_footprint != bridge_footprint:
        raise ValueError("footprint or placement pivot authority mismatch")
    if target_socket != scene_socket or target_socket != [float(value) for value in lowering["camera"]["sourceSocket"]]:
        raise ValueError("North frontage socket authority mismatch")
    if tolerance != 0.001:
        raise ValueError("bridge registration tolerance drift")
    return {"originCitySim": bridge_registration["originCitySim"],
            "originSource": [float(value) for value in bridge_registration["originSource"]],
            "footprintCitySimXYZ": bridge_registration["footprintCitySimXYZ"],
            "footprintSource": bridge_footprint, "pivotCitySim": bridge_registration["pivotCitySim"],
            "groundPivotSource": target_ground, "preOffsetCameraCenter": pre_offset_center,
            "northSocketCitySim": bridge_registration["northSocketCitySim"],
            "frontageSocketSource": target_socket, "tolerancePixels": tolerance}


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
            validate_authored_topology(source_vertices, faces, identifier)
            mesh = bpy.data.meshes.new(f"PLAY090::{identifier}::mesh")
            mesh.from_pydata([citysim_to_blender(point) for point in source_vertices], [], faces)
            validate_blender_mesh(mesh, identifier)
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
    camera_binding = lowering["camera"]
    width, height = [int(value) for value in camera_binding["renderViewportPixels"]]
    if [width, height] != [int(value) for value in scene_doc["camera"]["renderViewportPixels"]]:
        raise ValueError("scene viewport differs from bridge authority")
    data.ortho_scale = float(camera_binding["blenderOrthographicScale"])
    data.shift_x, data.shift_y = [float(value) for value in camera_binding["shift"]]
    camera.location = citysim_to_blender(camera_binding["citySimPosition"])
    target = Vector(citysim_to_blender(camera_binding["citySimTarget"]))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    bpy.context.view_layer.update()

    def project(source: list[float]) -> list[float]:
        ndc = world_to_camera_view(bpy.context.scene, camera, Vector(citysim_to_blender(source)))
        return [float(ndc.x) * width, (1.0 - float(ndc.y)) * height]
    targets = registration_targets(scene_doc, lowering)
    origin = project(targets["originCitySim"])
    footprint = [project(point) for point in targets["footprintCitySimXYZ"]]
    ground = project(targets["pivotCitySim"])
    socket = project(targets["northSocketCitySim"])
    target_ground = targets["groundPivotSource"]
    target_socket = targets["frontageSocketSource"]
    tolerance = targets["tolerancePixels"]
    if max(abs(origin[i] - targets["originSource"][i]) for i in range(2)) > tolerance:
        raise RuntimeError(f"origin registration drift: {origin}")
    for index, projected in enumerate(footprint):
        if max(abs(projected[i] - targets["footprintSource"][index][i]) for i in range(2)) > tolerance:
            raise RuntimeError(f"footprint registration drift at {index}: {projected}")
    if max(abs(ground[i] - target_ground[i]) for i in range(2)) > tolerance:
        raise RuntimeError(f"ground registration drift: {ground}")
    if max(abs(socket[i] - target_socket[i]) for i in range(2)) > tolerance:
        raise RuntimeError(f"socket registration drift: {socket}")
    return camera, {"schema": 1, "viewport": [width, height], "originSource": origin,
                    "expectedOriginSource": targets["originSource"], "footprintSource": footprint,
                    "expectedFootprintSource": targets["footprintSource"], "groundPivotSource": ground,
                    "expectedGroundPivotSource": target_ground,
                    "preOffsetCameraCenter": targets["preOffsetCameraCenter"], "frontageSocketSource": socket,
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
    png_canonicalization = canonicalize_blender_png(raw_path)
    input_bindings = {"schema": 1, "sceneSHA256": runner.sha256_file(spec["scenePath"]),
                      "materialsSHA256": runner.sha256_file(spec["materialsPath"]),
                      "loweringSHA256": runner.sha256_file(spec["loweringPath"]),
                      "coordinateBridgePath": lowering["coordinateBridge"]["authorityPath"],
                      "coordinateBridgeSHA256": runner.sha256_file(spec["bridgePath"]),
                      "contractSHA256": runner.sha256_file(root / runner.SOURCE_ROOT / runner.CONTRACT_NAME)}
    provenance = {"schema": 1, "task": "PLAY-090", "direction": "north", "process": "A",
                  "sceneGeometryID": scene_doc["sceneGeometryID"], "routeId": runner.ROUTE_ID,
                  "blender": {"path": runner.BLENDER, "sha256": runner.BLENDER_SHA256, "version": "4.5.12 LTS", "buildHash": "84afd5f785f7", "architecture": "x86_64", "translation": "Rosetta"},
                  "cycles": {"device": "CPU", "samples": render["samples"], "seed": render["seed"], "threads": render["threads"], "adaptiveSampling": False, "denoising": False},
                  "lighting": lighting, "pngCanonicalization": png_canonicalization,
                  "rawPNGContainerSHA256": runner.sha256_file(raw_path),
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
