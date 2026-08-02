#!/usr/bin/env python3
"""Authenticated West Process-A Blender child.

The future child has explicit mesh/curve builders for every v14 semantic
primitive.  The prelaunch validator uses only ``--emit-manifest``; that mode
does not import Blender, start a child, or create output.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import sys
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[8]
PACKAGE = Path(__file__).resolve().parent
CONTRACT = PACKAGE / "PROCESS-A-CONTRACT.json"
DESIGN = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/WEST-V14-DESIGN.json"
LOWERING = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/WEST-V14-LOWERING.json"


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def semantic_manifest() -> dict[str, Any]:
    contract, design, lowering = load(CONTRACT), load(DESIGN), load(LOWERING)
    if digest(DESIGN) != contract["designSHA256"] or digest(LOWERING) != contract["loweringSHA256"]:
        raise ValueError("frozen v14 input hash drift")
    components = design["components"]
    lowered = {item["id"]: item for item in lowering["componentLowering"]["components"]}
    if set(lowered) != {item["id"] for item in components}:
        raise ValueError("incomplete semantic component coverage")
    objects: list[dict[str, Any]] = []
    for component in components:
        item = lowered[component["id"]]
        if item["objects"] != component["builderObjects"] or item["builder"] not in contract["builderKinds"]:
            raise ValueError("missing semantic builder")
        for object_id in item["objects"]:
            objects.append({"id": object_id, "component": component["id"], "builder": item["builder"], "role": component["role"], "aabb": component["aabb"]})
    if len({item["id"] for item in objects}) != len(objects):
        raise ValueError("duplicate Blender object identity")
    return {"task": contract["task"], "direction": contract["direction"], "processID": contract["processID"], "camera": contract["camera"], "registration": contract["registration"], "materialRoles": contract["materialRoles"], "objects": objects, "componentCount": len(components), "objectCount": len(objects)}


def load_exact_profile() -> dict[str, Any]:
    """Resolve the future Integration profile before any bpy import."""
    contract = load(CONTRACT)
    if contract.get("appearanceLock") is None or contract.get("sourceProductionProfile") is None:
        raise PermissionError("appearance lock and source profile are required")
    profile_path = contract.get("sourceProductionProfilePath")
    profile_sha = contract.get("sourceProductionProfileSHA256")
    if not isinstance(profile_path, str) or not isinstance(profile_sha, str):
        raise PermissionError("source profile binding is incomplete")
    profile_file = ROOT / profile_path
    if not profile_file.is_file() or digest(profile_file) != profile_sha:
        raise PermissionError("source profile is absent or drifted")
    profile = load(profile_file)
    required = contract["profileRequiredFields"]
    if any(field not in profile for field in required):
        raise PermissionError("source profile omits required numeric domains")
    for role in contract["materialRoles"]:
        material = profile.get("materials", {}).get(role)
        if not isinstance(material, dict) or not all(key in material for key in ("baseColorRGBA", "metallic", "roughness")):
            raise PermissionError("material profile closure is incomplete")
    return profile


def _mesh_object(bpy: Any, name: str, vertices: list[tuple[float, float, float]], faces: list[tuple[int, ...]], material: Any) -> Any:
    if not vertices or not faces:
        raise ValueError("nonzero topology required")
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def _box_parts(lower: Iterable[float], upper: Iterable[float], offset: int = 0) -> tuple[list[tuple[float, float, float]], list[tuple[int, ...]]]:
    lo, hi = tuple(float(x) for x in lower), tuple(float(x) for x in upper)
    vertices = [(x, y, z) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
    faces = [(offset + 0, offset + 1, offset + 3, offset + 2), (offset + 4, offset + 6, offset + 7, offset + 5), (offset + 0, offset + 4, offset + 5, offset + 1), (offset + 2, offset + 3, offset + 7, offset + 6), (offset + 0, offset + 2, offset + 6, offset + 4), (offset + 1, offset + 5, offset + 7, offset + 3)]
    return vertices, faces


def _add_box_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    vertices, faces = _box_parts(lower, upper)
    return _mesh_object(bpy, name, vertices, faces, material)


def _add_wedge_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    lo, hi = tuple(float(x) for x in lower), tuple(float(x) for x in upper)
    vertices = [(lo[0], lo[1], lo[2]), (hi[0], lo[1], lo[2]), (hi[0], hi[1] - 1.5, lo[2]), (lo[0], hi[1], lo[2]), (lo[0], lo[1], hi[2]), (hi[0], lo[1], hi[2]), (hi[0], hi[1] - 1.5, hi[2]), (lo[0], hi[1], hi[2])]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (4, 0, 3, 7)]
    return _mesh_object(bpy, name, vertices, faces, material)


def _add_portal_frame_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    lo, hi = tuple(float(x) for x in lower), tuple(float(x) for x in upper)
    bars = [(lo, (hi[0], hi[1], lo[2] + 1.5)), ((lo[0], lo[1], hi[2] - 1.5), hi), (lo, (hi[0], lo[1] + 2.0, hi[2])), ((lo[0], hi[1] - 2.0, lo[2]), hi)]
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    for bar_lo, bar_hi in bars:
        part_vertices, part_faces = _box_parts(bar_lo, bar_hi, len(vertices))
        vertices.extend(part_vertices)
        faces.extend(part_faces)
    return _mesh_object(bpy, name, vertices, faces, material)


def _add_cylinder_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any, sides: int = 20) -> Any:
    lo, hi = tuple(float(x) for x in lower), tuple(float(x) for x in upper)
    radius = min(hi[0] - lo[0], hi[2] - lo[2]) / 2.0
    cx, cz = (lo[0] + hi[0]) / 2.0, (lo[2] + hi[2]) / 2.0
    vertices = [(cx + radius * math.cos(2 * math.pi * i / sides), lo[1], cz + radius * math.sin(2 * math.pi * i / sides)) for i in range(sides)] + [(cx + radius * math.cos(2 * math.pi * i / sides), hi[1], cz + radius * math.sin(2 * math.pi * i / sides)) for i in range(sides)]
    faces = [(i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides)] + [tuple(range(sides - 1, -1, -1)), tuple(range(sides, 2 * sides))]
    return _mesh_object(bpy, name, vertices, faces, material)


def _add_mullion_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    lo, hi = tuple(float(x) for x in lower), tuple(float(x) for x in upper)
    bars = [(lo, (hi[0], hi[1], lo[2] + 0.35)), ((lo[0], lo[1], hi[2] - 0.35), hi)]
    for z in (-0.33, 0.0, 0.33):
        bars.append(((lo[0], lo[1], (lo[2] + hi[2]) / 2 + z - 0.07), (hi[0], hi[1], (lo[2] + hi[2]) / 2 + z + 0.07)))
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    for bar_lo, bar_hi in bars:
        pv, pf = _box_parts(bar_lo, bar_hi, len(vertices))
        vertices.extend(pv); faces.extend(pf)
    return _mesh_object(bpy, name, vertices, faces, material)


def _add_rail_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    lo, hi = tuple(float(x) for x in lower), tuple(float(x) for x in upper)
    bars = [(lo, (hi[0], hi[1], lo[2] + 0.3)), ((lo[0], hi[1] - 0.3, lo[2]), hi)]
    for z in (lo[2], (lo[2] + hi[2]) / 2, hi[2]): bars.append(((lo[0], lo[1], z - 0.08), (hi[0], hi[1], z + 0.08)))
    vertices: list[tuple[float, float, float]] = []; faces: list[tuple[int, ...]] = []
    for bar_lo, bar_hi in bars:
        pv, pf = _box_parts(bar_lo, bar_hi, len(vertices)); vertices.extend(pv); faces.extend(pf)
    return _mesh_object(bpy, name, vertices, faces, material)


def _add_gutter_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    return _add_rail_mesh(bpy, name, lower, upper, material)


def _add_pipe_segment(bpy: Any, name: str, start: tuple[float, float, float], end: tuple[float, float, float], material: Any) -> Any:
    curve = bpy.data.curves.new(name + "Curve", type="CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.22
    curve.bevel_resolution = 3
    spline = curve.splines.new("POLY")
    spline.points.add(1)
    spline.points[0].co = (*start, 1.0)
    spline.points[1].co = (*end, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def _add_pipe_elbow(bpy: Any, name: str, start: tuple[float, float, float], corner: tuple[float, float, float], end: tuple[float, float, float], material: Any) -> Any:
    """Create a bounded, visibly curved three-point process elbow."""
    curve = bpy.data.curves.new(name + "Curve", type="CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.22
    curve.bevel_resolution = 3
    curve.resolution_u = 12
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(2)
    for point, co in zip(spline.bezier_points, (start, corner, end)):
        point.co = co
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def _add_pipe_cluster(bpy: Any, names: list[str], lower: list[float], upper: list[float], material: Any) -> list[Any]:
    lo, hi = tuple(float(x) for x in lower), tuple(float(x) for x in upper)
    start = (lo[0], lo[1], lo[2])
    corner = (hi[0], lo[1], lo[2])
    end = (hi[0], hi[1], lo[2])
    support_start = (lo[0], lo[1], hi[2])
    support_end = (hi[0], lo[1], hi[2])
    return [
        _add_pipe_segment(bpy, names[0], start, corner, material),
        _add_pipe_elbow(bpy, names[1], corner, (hi[0], (lo[1] + hi[1]) / 2.0, lo[2]), end, material),
        _add_pipe_segment(bpy, names[2], support_start, support_end, material),
    ]


def _oriented_beam_parts(start: tuple[float, float, float], end: tuple[float, float, float], radius: float, sides: int = 8) -> tuple[list[tuple[float, float, float]], list[tuple[int, ...]]]:
    """Return a closed, non-degenerate cylinder between two distinct points."""
    import math as _math
    axis = tuple(end[i] - start[i] for i in range(3))
    length = _math.sqrt(sum(v * v for v in axis))
    if length <= 1.0e-6:
        raise ValueError("zero-length oriented beam")
    axis = tuple(v / length for v in axis)
    reference = (0.0, 1.0, 0.0) if abs(axis[1]) < 0.9 else (1.0, 0.0, 0.0)
    u = (axis[1] * reference[2] - axis[2] * reference[1], axis[2] * reference[0] - axis[0] * reference[2], axis[0] * reference[1] - axis[1] * reference[0])
    u_len = _math.sqrt(sum(v * v for v in u)); u = tuple(v / u_len for v in u)
    v = (axis[1] * u[2] - axis[2] * u[1], axis[2] * u[0] - axis[0] * u[2], axis[0] * u[1] - axis[1] * u[0])
    vertices: list[tuple[float, float, float]] = []
    for center in (start, end):
        for index in range(sides):
            angle = 2.0 * _math.pi * index / sides
            vertices.append(tuple(center[i] + radius * (_math.cos(angle) * u[i] + _math.sin(angle) * v[i]) for i in range(3)))
    faces: list[tuple[int, ...]] = [tuple(reversed(range(sides))), tuple(range(sides, 2 * sides))]
    faces.extend((i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides))
    return vertices, faces


def _add_truss_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    lo, hi = tuple(float(x) for x in lower), tuple(float(x) for x in upper)
    left = (lo[0], lo[1], lo[2])
    peak = ((lo[0] + hi[0]) / 2.0, hi[1], hi[2])
    right = (hi[0], lo[1], lo[2])
    first_v, first_f = _oriented_beam_parts(left, peak, 0.24)
    second_v, second_f = _oriented_beam_parts(peak, right, 0.24)
    vertices = first_v + second_v
    faces = first_f + [tuple(index + len(first_v) for index in face) for face in second_f]
    return _mesh_object(bpy, name, vertices, faces, material)


def _add_recessed_reveal_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    lo, hi = tuple(float(x) for x in lower), tuple(float(x) for x in upper)
    inset = 0.45
    inner_lo = [lo[0] + inset, lo[1] + inset, lo[2] + inset]
    inner_hi = [hi[0] - inset, hi[1] - inset, hi[2] - inset]
    return _add_portal_frame_mesh(bpy, name, inner_lo, inner_hi, material)


def _add_freight_recess_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    lo, hi = tuple(float(x) for x in lower), tuple(float(x) for x in upper)
    return _add_box_mesh(bpy, name, [lo[0], lo[1] + 0.18, lo[2]], [hi[0], hi[1] - 0.18, hi[2]], material)


def _add_clerestory_band_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    return _add_mullion_mesh(bpy, name, lower, upper, material)


def _add_crown_break_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    return _add_wedge_mesh(bpy, name, lower, upper, material)


def _add_service_door_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    return _add_mullion_mesh(bpy, name, lower, upper, material)


def _add_apron_detail_mesh(bpy: Any, name: str, lower: list[float], upper: list[float], material: Any) -> Any:
    return _add_box_mesh(bpy, name, lower, upper, material)


def _build_component(bpy: Any, component: dict[str, Any], material: Any) -> list[Any]:
    lower, upper = component["aabb"]["min"], component["aabb"]["max"]
    builder = next(item for item in load(LOWERING)["componentLowering"]["components"] if item["id"] == component["id"])["builder"]
    names = component["builderObjects"]
    if builder == "recessed_void":
        return []
    if builder == "compound_portal_frame": return [_add_portal_frame_mesh(bpy, names[0], lower, upper, material)]
    if builder == "pitched_roof_wedge": return [_add_wedge_mesh(bpy, names[0], lower, upper, material)]
    if builder == "capped_vessel" or builder == "capped_stack": return [_add_cylinder_mesh(bpy, names[0], lower, upper, material)]
    if builder == "pipe_run_with_elbows": return _add_pipe_cluster(bpy, names, lower, upper, material)
    if builder == "mullioned_glazing_band": return [_add_mullion_mesh(bpy, names[0], lower, upper, material)]
    if builder == "railing_run": return [_add_rail_mesh(bpy, names[0], lower, upper, material)]
    if builder == "gutter_and_edge": return [_add_gutter_mesh(bpy, names[0], lower, upper, material)]
    if builder == "truss_chords_diagonals": return [_add_truss_mesh(bpy, names[0], lower, upper, material)]
    if builder == "union_safe_box": return [_add_box_mesh(bpy, names[0], lower, upper, material)]
    if builder == "recessed_reveal": return [_add_recessed_reveal_mesh(bpy, names[0], lower, upper, material)]
    if builder == "freight_recess_beat": return [_add_freight_recess_mesh(bpy, names[0], lower, upper, material)]
    if builder == "clerestory_band": return [_add_clerestory_band_mesh(bpy, names[0], lower, upper, material)]
    if builder == "crown_break": return [_add_crown_break_mesh(bpy, names[0], lower, upper, material)]
    if builder == "roof_plant": return [_add_box_mesh(bpy, names[0], lower, upper, material)]
    if builder == "service_door": return [_add_service_door_mesh(bpy, names[0], lower, upper, material)]
    if builder == "apron_surface_detail": return [_add_apron_detail_mesh(bpy, names[0], lower, upper, material)]
    raise ValueError(f"unbound semantic builder: {builder}")


def _make_materials(bpy: Any, roles: list[str], profile: dict[str, Any]) -> dict[str, Any]:
    materials = {}
    for role in roles:
        spec = profile["materials"][role]
        material = bpy.data.materials.new(name=f"PLAY081-{role}")
        material.diffuse_color = tuple(spec["baseColorRGBA"])
        material.metallic = float(spec["metallic"])
        material.roughness = float(spec["roughness"])
        materials[role] = material
    return materials


def _configure_camera(bpy: Any, contract: dict[str, Any]) -> Any:
    from mathutils import Vector
    spec = contract["camera"]
    data = bpy.data.cameras.new("PLAY081-west-v14-camera-data")
    data.type = "ORTHO"
    data.ortho_scale = float(spec["orthographicScaleWorld"])
    data.shift_x = float(spec["shiftX"])
    data.shift_y = float(spec["shiftY"])
    camera = bpy.data.objects.new("PLAY081-west-v14-camera", data)
    bpy.context.collection.objects.link(camera)
    camera.location = tuple(spec["positionWorldXYZ"])
    target = Vector(spec["targetWorldXYZ"])
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    return camera


def _configure_lighting(bpy: Any, contract: dict[str, Any], profile: dict[str, Any]) -> None:
    from mathutils import Vector
    scene = bpy.context.scene
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = tuple(profile["world"]["colorRGBA"])
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = float(profile["world"]["strength"])
    for name, spec in (("PLAY081-NW-key", profile["keyLight"]), ("PLAY081-sky-fill", profile["fillLight"])):
        data = bpy.data.lights.new(name, type="AREA")
        data.energy = float(spec["energy"])
        data.color = tuple(spec["colorRGBA"])
        data.shape = "DISK"
        data.size = float(spec["size"])
        light = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(light)
        light.location = tuple(spec["positionWorldXYZ"])
        target = tuple(spec.get("targetWorldXYZ", contract["camera"]["targetWorldXYZ"]))
        light.rotation_euler = (Vector(target) - light.location).to_track_quat("-Z", "Y").to_euler()
    shadow = profile["shadowReceiver"]
    _add_box_mesh(bpy, "PLAY081-southeast-shadow-receiver", shadow["min"], shadow["max"], _make_materials(bpy, [contract["materialRoles"][8]], profile)[contract["materialRoles"][8]])


def _configure_render(bpy: Any, contract: dict[str, Any], profile: dict[str, Any], output_root: Path) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = int(profile["cycles"]["samples"])
    scene.cycles.seed = int(profile["cycles"]["seed"])
    scene.cycles.max_bounces = int(profile["cycles"]["maxBounces"])
    scene.cycles.use_adaptive_sampling = bool(profile["cycles"].get("adaptiveSampling", False))
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = contract["camera"]["renderViewportPixels"]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.use_file_extension = True
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.pixel_aspect_x = 1.0
    scene.render.pixel_aspect_y = 1.0
    scene.render.use_motion_blur = False
    scene.display_settings.display_device = profile["colorManagement"].get("displayDevice", "sRGB")
    scene.view_settings.view_transform = profile["colorManagement"].get("viewTransform", "Standard")
    scene.view_settings.look = profile["colorManagement"]["look"]
    scene.view_settings.exposure = float(profile["colorManagement"]["exposure"])
    scene.view_settings.gamma = float(profile["colorManagement"]["gamma"])
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(output_root / contract["futureOutputFiles"][0])
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_root / contract["futureOutputFiles"][1]))


def write_provenance(output_root: Path, manifest: dict[str, Any], contract: dict[str, Any]) -> None:
    if not output_root.is_dir() or output_root.is_symlink():
        raise FileNotFoundError("exclusive output root must be created before render/save")
    (output_root / "manifest.json").write_bytes(json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode() + b"\n")
    (output_root / "provenance.json").write_bytes(json.dumps({"contract": contract["processID"], "designSHA256": contract["designSHA256"], "loweringSHA256": contract["loweringSHA256"]}, sort_keys=True).encode() + b"\n")
    (output_root / "receipt.json").write_bytes(json.dumps({"childStarts": 1, "dccInvocations": 1, "sourceReady": False}, sort_keys=True).encode() + b"\n")


def _assert_output_path_is_lexical(root: Path, output: Path) -> None:
    relative = output.relative_to(root)
    cursor = root
    for part in relative.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise PermissionError("output root symlink component is forbidden")


def build_scene() -> dict[str, Any]:
    profile = load_exact_profile()
    import bpy
    contract, design = load(CONTRACT), load(DESIGN)
    output_root = ROOT / contract["futureOutputRoot"]
    _assert_output_path_is_lexical(ROOT, output_root)
    if output_root.exists() or output_root.is_symlink():
        raise FileExistsError("immutable Process-A output root already exists")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = _make_materials(bpy, contract["materialRoles"], profile)
    for component in design["components"]:
        _build_component(bpy, component, materials[component["role"]])
    _configure_camera(bpy, contract)
    _configure_lighting(bpy, contract, profile)
    if output_root.parent.is_symlink() or (output_root.parent.exists() and not output_root.parent.is_dir()):
        raise PermissionError("exclusive output parent is invalid or symlinked")
    if not output_root.parent.exists():
        output_root.parent.mkdir(parents=False, exist_ok=False)
    output_root.mkdir(parents=False, exist_ok=False)
    _configure_render(bpy, contract, profile, output_root)
    manifest = semantic_manifest()
    write_provenance(output_root, manifest, contract)
    return manifest


def main() -> int:
    if "--emit-manifest" in sys.argv[1:]:
        sys.stdout.write(json.dumps(semantic_manifest(), sort_keys=True, separators=(",", ":")) + "\n")
        return 0
    if os.environ.get("PLAY081_PROCESS_A_AUTHENTICATED") != "1":
        raise PermissionError("authenticated Integration grant required")
    build_scene()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
