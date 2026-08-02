#!/usr/bin/env python3
"""North v14 Blender child reference; Blender is never imported by static tests."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import os
import struct
import sys
import zlib
from pathlib import Path
from typing import Any

SOURCE_ROOT = Path("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14")
PROCESS_ROOT = SOURCE_ROOT / "process-a-execution-v01"
LAUNCHER_PATH = PROCESS_ROOT / "launch_north_process_a.py"
ALLOWED_OUTPUTS = {
    "raw.png", "semantic.png", "north-v14-process-a.blend", "OBJECT-MANIFEST.json",
    "GROUND-PROJECTION.json", "INPUT-BINDINGS.json", "provenance.json", "PROCESS-RECEIPT.json",
}
RECTANGULAR_BUILDERS = {
    "annex": "annex-volume",
    "apron-road-link": "road-linked-apron-slab",
    "apron-service-pad": "service-pad-slab",
    "articulated-member": "articulated-rectangular-member",
    "box": "authored-box-volume",
    "clerestory-frame": "clerestory-frame-volume",
    "clerestory-glass": "clerestory-glazing-volume",
    "freight-recess": "freight-inset-back-plane",
    "inset-plane": "portal-inset-back-plane",
    "loading-stripe": "loading-stripe-slab",
    "portal-header": "portal-header-volume",
    "portal-jamb": "portal-jamb-volume",
    "reveal-header": "portal-reveal-header",
    "reveal-jamb": "portal-reveal-jamb",
    "service-door": "service-door-leaf",
    "shared-eave": "shared-eave-beam",
    "stack-cap": "stack-cap-volume",
    "staff-frame": "staff-entry-frame",
    "staff-leaf": "staff-entry-leaf",
    "threshold-edge": "threshold-edge-beam",
    "threshold-slab": "threshold-slab",
}
SUPPORTED_KINDS = set(RECTANGULAR_BUILDERS) | {
    "contact-shadow", "cylindrical-shaft", "heat-cap", "octagonal-body",
    "octagonal-rim", "octagonal-shoulder", "pipe-elbow", "pipe-segment",
    "pipe-support", "plant-unit", "portal-frame", "sawtooth-peak",
    "sawtooth-slope-face", "stack-bands", "truss-chord", "truss-diagonal", "void",
}
# The authored area-light values are retained as immutable inputs. These fixed
# Blender-lowering gains compensate for their 115-154 world-unit throw at the
# governed source scale; they are provenance-bound below and tested exactly.
KEY_ENERGY_SCALE = 12.0
FILL_ENERGY_SCALE = 40.0


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text())
    require(type(value) is dict, f"JSON object required: {path}")
    return value


def load_module(path: Path, name: str) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"module unavailable: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def construct_semantic_geometry(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    lowerer = load_module(root / SOURCE_ROOT / "lower_v14_scene.py", "play027_v14_child_lowerer")
    packet = lowerer.run()
    report, manifest = packet["report"], packet["manifest"]
    require(report["componentCount"] == 33 and report["objectCount"] == 97, "semantic object count drift")
    require(report["componentToObjectCoverage"]["percent"] == 100.0, "semantic coverage incomplete")
    require(report["registration"]["socketCitySim"] == [0, 0, -28] and report["registration"]["socketBlender"] == [-28, 0, 0], "semantic socket drift")
    require(report["portal"]["socketConnected"] and report["topology"]["parameterizedPayloads"], "semantic portal/topology proof missing")
    for name, binding in contract["frozenInputs"].items():
        path = root / binding["path"]
        require(path.is_file() and not path.is_symlink(), f"frozen input unavailable: {name}")
        require(sha256(path) == binding["sha256"], f"frozen input hash drift: {name}")
    return {"manifest": manifest, "report": report, "inputHashes": packet["inputHashes"]}


def bridge(point: list[float]) -> list[float]:
    """Frozen v06 bridge: CitySim [x,y,z] -> Blender [z,x,y]."""
    return [point[2], point[0], point[1]]


def bridge_determinant() -> int:
    """The frozen cyclic permutation B(x,y,z)=(z,x,y) has determinant +1."""
    matrix = ((0, 0, 1), (1, 0, 0), (0, 1, 0))
    return (
        matrix[0][0] * (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1])
        - matrix[0][1] * (matrix[1][0] * matrix[2][2] - matrix[1][2] * matrix[2][0])
        + matrix[0][2] * (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0])
    )


def add(a: list[float], b: list[float]) -> list[float]:
    return [a[i] + b[i] for i in range(3)]


def subtract(a: list[float], b: list[float]) -> list[float]:
    return [a[i] - b[i] for i in range(3)]


def scale(a: list[float], value: float) -> list[float]:
    return [a[i] * value for i in range(3)]


def dot(a: list[float], b: list[float]) -> float:
    return sum(a[i] * b[i] for i in range(3))


def cross(a: list[float], b: list[float]) -> list[float]:
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def magnitude(a: list[float]) -> float:
    return math.sqrt(dot(a, a))


def normalized(a: list[float]) -> list[float]:
    length = magnitude(a)
    require(length > 1.0e-9, "zero-length vector")
    return scale(a, 1.0 / length)


def triangle_area(a: list[float], b: list[float], c: list[float]) -> float:
    return magnitude(cross(subtract(b, a), subtract(c, a))) / 2.0


def mesh_spec(name: str, kind: str, builder: str, vertices: list[list[float]], faces: list[list[int]], **metadata: Any) -> dict[str, Any]:
    spec = {"id": name, "geometryKind": kind, "builder": builder, "vertices": vertices, "faces": faces, "metadata": metadata}
    validate_mesh_spec(spec)
    return spec


def validate_mesh_spec(spec: dict[str, Any]) -> None:
    vertices, faces = spec["vertices"], spec["faces"]
    require(vertices and faces, f"empty mesh: {spec['id']}")
    require(all(len(v) == 3 and all(math.isfinite(float(c)) for c in v) for v in vertices), f"invalid vertices: {spec['id']}")
    used: set[int] = set()
    for face in faces:
        require(len(face) >= 3 and len(set(face)) == len(face), f"invalid face: {spec['id']}")
        require(all(type(index) is int and 0 <= index < len(vertices) for index in face), f"face index drift: {spec['id']}")
        used.update(face)
        anchor = vertices[face[0]]
        area = sum(triangle_area(anchor, vertices[face[i]], vertices[face[i + 1]]) for i in range(1, len(face) - 1))
        require(area > 1.0e-8, f"degenerate face: {spec['id']}")
    require(used == set(range(len(vertices))), f"unused mesh vertex: {spec['id']}")


def face_normal(vertices: list[list[float]], face: list[int]) -> list[float]:
    return cross(subtract(vertices[face[1]], vertices[face[0]]), subtract(vertices[face[2]], vertices[face[0]]))


def face_center(vertices: list[list[float]], face: list[int]) -> list[float]:
    return [sum(vertices[index][axis] for index in face) / len(face) for axis in range(3)]


def connected_face_shells(spec: dict[str, Any]) -> list[list[int]]:
    faces = spec["faces"]
    vertex_faces: dict[int, list[int]] = {}
    for face_index, face in enumerate(faces):
        for vertex_index in face:
            vertex_faces.setdefault(vertex_index, []).append(face_index)
    remaining = set(range(len(faces)))
    shells: list[list[int]] = []
    while remaining:
        pending = [remaining.pop()]
        shell: list[int] = []
        while pending:
            face_index = pending.pop()
            shell.append(face_index)
            neighbors = {
                candidate
                for vertex_index in faces[face_index]
                for candidate in vertex_faces[vertex_index]
                if candidate in remaining
            }
            remaining.difference_update(neighbors)
            pending.extend(neighbors)
        shells.append(sorted(shell))
    return shells


def orientation_report(spec: dict[str, Any]) -> dict[str, Any]:
    vertices, faces = spec["vertices"], spec["faces"]
    if spec["metadata"].get("shadowCatcher"):
        normals = [face_normal(vertices, face) for face in faces]
        upward = sum(normal[2] > 1.0e-9 for normal in normals)
        return {
            "id": spec["id"], "classification": "open-two-sided-shadow-receiver",
            "faceCount": len(faces), "outwardFaces": upward, "inwardFaces": len(faces) - upward,
            "shells": 1, "passes": upward == len(faces),
        }
    if spec["builder"] == "pipe-elbow-torus":
        center = spec["metadata"]["joint"]
        major_radius = 0.34
        scores = []
        for face in faces:
            center_face = face_center(vertices, face)
            angle = math.atan2(center_face[1] - center[1], center_face[0] - center[0])
            tube_center = [
                center[0] + major_radius * math.cos(angle),
                center[1] + major_radius * math.sin(angle),
                center[2],
            ]
            scores.append(dot(face_normal(vertices, face), subtract(center_face, tube_center)))
        inward = sum(score <= 1.0e-9 for score in scores)
        return {
            "id": spec["id"], "classification": "closed-analytic-torus",
            "faceCount": len(faces), "outwardFaces": len(faces) - inward, "inwardFaces": inward,
            "shells": 1, "passes": inward == 0,
        }
    inward = 0
    shell_reports = []
    for shell in connected_face_shells(spec):
        shell_vertices = sorted({index for face_index in shell for index in faces[face_index]})
        center = [sum(vertices[index][axis] for index in shell_vertices) / len(shell_vertices) for axis in range(3)]
        scores = [
            dot(face_normal(vertices, faces[face_index]), subtract(face_center(vertices, faces[face_index]), center))
            for face_index in shell
        ]
        shell_inward = sum(score <= 1.0e-9 for score in scores)
        inward += shell_inward
        shell_reports.append({"faceCount": len(shell), "inwardFaces": shell_inward})
    return {
        "id": spec["id"], "classification": "closed-outward-shells",
        "faceCount": len(faces), "outwardFaces": len(faces) - inward, "inwardFaces": inward,
        "shells": len(shell_reports), "shellReports": shell_reports, "passes": inward == 0,
    }


def citysim_box_geometry(bounds: list[list[float]]) -> tuple[list[list[float]], list[list[int]]]:
    x0, y0, z0 = bounds[0]
    x1, y1, z1 = bounds[1]
    city_vertices = [
        [x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0],
        [x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1],
    ]
    faces = [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [4, 0, 3, 7]]
    # B(x,y,z)=(z,x,y) is an orientation-preserving cyclic permutation. The
    # authored CitySim box faces are inward, so reverse their winding once.
    return [bridge(v) for v in city_vertices], [list(reversed(face)) for face in faces]


def box_spec(item: dict[str, Any], builder: str | None = None) -> dict[str, Any]:
    vertices, faces = citysim_box_geometry(item["boundsXYZ"])
    return mesh_spec(item["id"], item["geometryKind"], builder or RECTANGULAR_BUILDERS[item["geometryKind"]], vertices, faces)


def merge_specs(name: str, kind: str, builder: str, specs: list[dict[str, Any]], **metadata: Any) -> dict[str, Any]:
    vertices: list[list[float]] = []
    faces: list[list[int]] = []
    for spec in specs:
        offset = len(vertices)
        vertices.extend(spec["vertices"])
        faces.extend([[index + offset for index in face] for face in spec["faces"]])
    return mesh_spec(name, kind, builder, vertices, faces, **metadata)


def cylinder_spec_between(name: str, kind: str, builder: str, start_city: list[float], end_city: list[float], radius: float, sides: int = 12, radius_end: float | None = None) -> dict[str, Any]:
    start, end = bridge(start_city), bridge(end_city)
    axis = normalized(subtract(end, start))
    reference = [0.0, 0.0, 1.0] if abs(dot(axis, [0.0, 0.0, 1.0])) < 0.9 else [0.0, 1.0, 0.0]
    u = normalized(cross(axis, reference))
    v = normalized(cross(axis, u))
    end_radius = radius if radius_end is None else radius_end
    vertices: list[list[float]] = []
    for center, ring_radius in ((start, radius), (end, end_radius)):
        for index in range(sides):
            angle = 2.0 * math.pi * index / sides
            radial = add(scale(u, math.cos(angle) * ring_radius), scale(v, math.sin(angle) * ring_radius))
            vertices.append(add(center, radial))
    faces = [list(reversed(range(sides))), list(range(sides, sides * 2))]
    for index in range(sides):
        nxt = (index + 1) % sides
        faces.append([index, nxt, sides + nxt, sides + index])
    return mesh_spec(name, kind, builder, vertices, faces, axisStart=start, axisEnd=end, radiusStart=radius, radiusEnd=end_radius)


def vertical_cylinder_from_bounds(item: dict[str, Any], builder: str, sides: int, taper: float = 1.0) -> dict[str, Any]:
    bounds = item["boundsXYZ"]
    center_x = (bounds[0][0] + bounds[1][0]) / 2.0
    center_z = (bounds[0][2] + bounds[1][2]) / 2.0
    radius = min(bounds[1][0] - bounds[0][0], bounds[1][2] - bounds[0][2]) / 2.0
    return cylinder_spec_between(item["id"], item["geometryKind"], builder, [center_x, bounds[0][1], center_z], [center_x, bounds[1][1], center_z], radius, sides, radius * taper)


def torus_spec(item: dict[str, Any]) -> dict[str, Any]:
    center = bridge(item["parameters"]["joint"])
    major_radius, minor_radius = 0.34, 0.12
    major_segments, minor_segments = 16, 6
    vertices: list[list[float]] = []
    for major in range(major_segments):
        a = 2.0 * math.pi * major / major_segments
        for minor in range(minor_segments):
            b = 2.0 * math.pi * minor / minor_segments
            vertices.append([
                center[0] + (major_radius + minor_radius * math.cos(b)) * math.cos(a),
                center[1] + (major_radius + minor_radius * math.cos(b)) * math.sin(a),
                center[2] + minor_radius * math.sin(b),
            ])
    faces: list[list[int]] = []
    for major in range(major_segments):
        for minor in range(minor_segments):
            faces.append([
                major * minor_segments + minor,
                ((major + 1) % major_segments) * minor_segments + minor,
                ((major + 1) % major_segments) * minor_segments + (minor + 1) % minor_segments,
                major * minor_segments + (minor + 1) % minor_segments,
            ])
    return mesh_spec(item["id"], item["geometryKind"], "pipe-elbow-torus", vertices, faces, joint=center)


def sawtooth_slope_spec(item: dict[str, Any]) -> dict[str, Any]:
    x0, y0, z0 = item["boundsXYZ"][0]
    x1, y1, z1 = item["boundsXYZ"][1]
    thickness = min(0.28, (y1 - y0) * 0.08)
    city = [
        [x0, y0, z0], [x0, y0, z1], [x1, y1, z1], [x1, y1, z0],
        [x0, y0 - thickness, z0], [x0, y0 - thickness, z1], [x1, y1 - thickness, z1], [x1, y1 - thickness, z0],
    ]
    faces = [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]
    return mesh_spec(item["id"], item["geometryKind"], "inclined-sawtooth-roof-plane", [bridge(v) for v in city], faces)


def sawtooth_peak_spec(item: dict[str, Any]) -> dict[str, Any]:
    bounds = item["boundsXYZ"]
    x0, y0, z0 = bounds[0]
    x1, y1, z1 = bounds[1]
    width = min(0.22, (x1 - x0) * 0.08)
    peak_bounds = [[x1 - width, y0 + (y1 - y0) * 0.38, z0], [x1, y1, z1]]
    proxy = {**item, "boundsXYZ": peak_bounds}
    return box_spec(proxy, "vertical-sawtooth-peak-riser")


def portal_frame_spec(item: dict[str, Any]) -> dict[str, Any]:
    x0, y0, z0 = item["boundsXYZ"][0]
    x1, y1, z1 = item["boundsXYZ"][1]
    jamb = min(0.55, (x1 - x0) * 0.08)
    header = min(0.55, (y1 - y0) * 0.08)
    parts = []
    for index, bounds in enumerate((
        [[x0, y0, z0], [x0 + jamb, y1, z1]],
        [[x1 - jamb, y0, z0], [x1, y1, z1]],
        [[x0 + jamb, y1 - header, z0], [x1 - jamb, y1, z1]],
    )):
        vertices, faces = citysim_box_geometry(bounds)
        parts.append(mesh_spec(f"{item['id']}-part-{index}", item["geometryKind"], "portal-frame-part", vertices, faces))
    return merge_specs(item["id"], item["geometryKind"], "three-part-open-portal-frame", parts, apertureCenter=bridge([(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2]))


def stack_bands_spec(item: dict[str, Any]) -> dict[str, Any]:
    bounds = item["boundsXYZ"]
    count = int(item["parameters"]["count"])
    height = bounds[1][1] - bounds[0][1]
    specs = []
    for index in range(count):
        lower = bounds[0][1] + height * (index + 0.18) / count
        upper = bounds[0][1] + height * (index + 0.58) / count
        piece = {**item, "id": f"{item['id']}-band-{index}", "boundsXYZ": [[bounds[0][0], lower, bounds[0][2]], [bounds[1][0], upper, bounds[1][2]]]}
        specs.append(vertical_cylinder_from_bounds(piece, "stack-band-ring", 12))
    return merge_specs(item["id"], item["geometryKind"], "separated-stack-band-rings", specs, count=count)


def shadow_receiver_spec(item: dict[str, Any]) -> dict[str, Any]:
    x0, y0, z0 = item["boundsXYZ"][0]
    x1, y1, z1 = item["boundsXYZ"][1]
    y = (y0 + y1) / 2.0
    vertices = [bridge([x0, y, z0]), bridge([x1, y, z0]), bridge([x1, y, z1]), bridge([x0, y, z1])]
    return mesh_spec(item["id"], item["geometryKind"], "cycles-shadow-catcher-plane", vertices, [[3, 2, 1, 0]], shadowCatcher=True)


def mesh_spec_for(item: dict[str, Any]) -> dict[str, Any] | None:
    kind = item["geometryKind"]
    require(kind in SUPPORTED_KINDS, f"unsupported semantic kind: {kind}")
    if kind == "void":
        return None
    if kind in RECTANGULAR_BUILDERS:
        return box_spec(item)
    if kind == "portal-frame":
        return portal_frame_spec(item)
    if kind == "sawtooth-slope-face":
        return sawtooth_slope_spec(item)
    if kind == "sawtooth-peak":
        return sawtooth_peak_spec(item)
    if kind == "pipe-segment":
        return cylinder_spec_between(item["id"], kind, "endpoint-oriented-pipe-cylinder", item["parameters"]["start"], item["parameters"]["end"], 0.22, 12)
    if kind == "pipe-elbow":
        return torus_spec(item)
    if kind == "pipe-support":
        b = item["boundsXYZ"]
        center_x, center_z = (b[0][0] + b[1][0]) / 2, (b[0][2] + b[1][2]) / 2
        return cylinder_spec_between(item["id"], kind, "vertical-pipe-support", [center_x, b[0][1], center_z], [center_x, b[1][1], center_z], 0.14, 8)
    if kind == "truss-chord":
        b = item["boundsXYZ"]
        y, z = (b[0][1] + b[1][1]) / 2, (b[0][2] + b[1][2]) / 2
        return cylinder_spec_between(item["id"], kind, "endpoint-oriented-truss-chord", [b[0][0], y, z], [b[1][0], y, z], 0.22, 8)
    if kind == "truss-diagonal":
        b = item["boundsXYZ"]
        return cylinder_spec_between(item["id"], kind, "endpoint-oriented-truss-diagonal", b[0], b[1], 0.18, 8)
    if kind == "octagonal-body":
        return vertical_cylinder_from_bounds(item, "octagonal-vessel-body", 8)
    if kind == "octagonal-shoulder":
        return vertical_cylinder_from_bounds(item, "tapered-octagonal-vessel-shoulder", 8, 0.72)
    if kind == "octagonal-rim":
        return vertical_cylinder_from_bounds(item, "octagonal-vessel-rim", 8)
    if kind == "cylindrical-shaft":
        return vertical_cylinder_from_bounds(item, "stack-shaft", int(item["parameters"].get("sides", 12)))
    if kind == "stack-bands":
        return stack_bands_spec(item)
    if kind == "plant-unit":
        sides = 8 if item["primitive"] == "vent-bank" else 12
        builder = "roof-vent-cylinder" if item["primitive"] == "vent-bank" else "roof-process-tank"
        return vertical_cylinder_from_bounds(item, builder, sides)
    if kind == "heat-cap":
        return vertical_cylinder_from_bounds(item, "furnace-heat-cap", 8, 0.72)
    if kind == "contact-shadow":
        return shadow_receiver_spec(item)
    raise RuntimeError(f"semantic kind has no explicit builder: {kind}")


def build_mesh_specs(manifest: dict[str, Any]) -> dict[str, Any]:
    require(bridge_determinant() == 1, "coordinate bridge determinant drift")
    kinds = {item["geometryKind"] for item in manifest["objects"]}
    require(kinds == SUPPORTED_KINDS, f"semantic-kind closure drift: {sorted(kinds ^ SUPPORTED_KINDS)}")
    solid_specs: list[dict[str, Any]] = []
    void_ids: list[str] = []
    for item in manifest["objects"]:
        spec = mesh_spec_for(item)
        if spec is None:
            void_ids.append(item["id"])
        else:
            solid_specs.append(spec)
    require(len(solid_specs) == 96 and len(void_ids) == 1, "solid/void object count drift")
    require(len({item["id"] for item in solid_specs}) == len(solid_specs), "duplicate mesh spec id")
    require(all(item["builder"] != "generic" for item in solid_specs), "generic builder forbidden")
    orientation_reports = [orientation_report(spec) for spec in solid_specs]
    failed_orientation = [report["id"] for report in orientation_reports if not report["passes"]]
    require(not failed_orientation, f"mesh orientation drift: {failed_orientation}")
    return {
        "solidSpecs": solid_specs,
        "voidIDs": void_ids,
        "supportedKinds": sorted(SUPPORTED_KINDS),
        "orientationReports": orientation_reports,
        "closedOutwardObjects": sum(report["classification"].startswith("closed-") for report in orientation_reports),
        "openTwoSidedObjects": sum(report["classification"].startswith("open-two-sided") for report in orientation_reports),
    }


def mesh_object(bpy: Any, spec: dict[str, Any], material: Any) -> Any:
    mesh = bpy.data.meshes.new(f"{spec['id']}-mesh")
    mesh.from_pydata(spec["vertices"], [], spec["faces"])
    mesh.validate(verbose=False, clean_customdata=False)
    mesh.update(calc_edges=True)
    require(len(mesh.vertices) == len(spec["vertices"]) and len(mesh.polygons) == len(spec["faces"]), f"Blender mesh topology drift: {spec['id']}")
    obj = bpy.data.objects.new(spec["id"], mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    if spec["metadata"].get("shadowCatcher"):
        obj.is_shadow_catcher = True
    return obj


def configure_materials(bpy: Any, materials: dict[str, Any]) -> dict[str, Any]:
    material_by_role: dict[str, Any] = {}
    for role in materials["materials"]:
        mat = bpy.data.materials.new(role["id"])
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        node = nodes.get("Principled BSDF")
        require(node is not None, f"Principled node unavailable: {role['id']}")
        node.inputs["Base Color"].default_value = role["baseColorRGBA"]
        node.inputs["Roughness"].default_value = role["roughness"]
        node.inputs["Metallic"].default_value = role["metalness"]
        node.inputs["Alpha"].default_value = role["baseColorRGBA"][3]
        if "emissionStrength" in role:
            node.inputs["Emission Color"].default_value = role["baseColorRGBA"]
            node.inputs["Emission Strength"].default_value = role["emissionStrength"]
        mat.diffuse_color = role["baseColorRGBA"]
        material_by_role[role["role"]] = mat
    require(set(material_by_role) == set(materials["roles"]), "material-role closure drift")
    return material_by_role


def aim(object_value: Any, target_blender: list[float]) -> None:
    from mathutils import Vector
    object_value.rotation_euler = (Vector(target_blender) - object_value.location).to_track_quat("-Z", "Y").to_euler()


def render_profile(contract: dict[str, Any], lighting: dict[str, Any]) -> dict[str, Any]:
    cycles = contract["cycles"]
    require(lighting["engine"] == "CYCLES" and lighting["device"] == cycles["device"], "lighting/engine drift")
    require(lighting["samples"] == cycles["samples"] and lighting["threads"] == cycles["threads"], "lighting/Cycles sample drift")
    require(lighting["seed"] == cycles["seed"] and lighting["adaptiveSampling"] == cycles["adaptiveSampling"] and lighting["denoising"] == cycles["denoising"], "lighting/Cycles determinism drift")
    return {
        "engine": "CYCLES",
        "device": cycles["device"],
        "samples": cycles["samples"],
        "seed": cycles["seed"],
        "threadsMode": "FIXED",
        "threads": cycles["threads"],
        "adaptiveSampling": cycles["adaptiveSampling"],
        "denoising": cycles["denoising"],
        "motionBlur": cycles["motionBlur"],
        "transparentFilm": cycles["transparentFilm"],
        "resolution": cycles["resolution"],
        "resolutionPercentage": 100,
        "pixelAspect": cycles["pixelAspect"],
        "image": {"fileFormat": "PNG", "colorMode": "RGBA", "colorDepth": "8", "compression": 15},
        "colorManagement": cycles["colorManagement"],
    }


def camera_profile(scene_data: dict[str, Any]) -> dict[str, Any]:
    camera = scene_data["camera"]
    aspect = camera["renderViewportPixels"][0] / camera["renderViewportPixels"][1]
    profile = {
        "type": "ORTHO",
        "orthoScale": 2.0 * camera["orthographicScale"] * aspect,
        "shiftX": camera["postProjectionOffsetPixels"][0] / camera["renderViewportPixels"][0],
        "shiftY": camera["postProjectionOffsetPixels"][1] / camera["renderViewportPixels"][0],
        "positionBlender": bridge(camera["positionWorld"]),
        "targetBlender": bridge(camera["targetWorld"]),
        "clipStart": 0.1,
        "clipEnd": 1000.0,
    }
    require(abs(profile["orthoScale"] - 237.5878601074218) < 1.0e-9, "R3 orthographic scale drift")
    return profile


def source_ground_point(point_citysim: list[float]) -> list[float]:
    x, y, z = point_citysim
    require(abs(y) < 1.0e-9, "ground projection requires CitySim y=0")
    return [768.0 + (32.0 / 7.0) * (x - z), 768.0 + (16.0 / 7.0) * (x + z)]


def ground_projection_report(scene_data: dict[str, Any]) -> dict[str, Any]:
    footprint = scene_data["registration"]["footprintWorld"]
    projected = [source_ground_point(point) for point in footprint]
    pivot = source_ground_point(scene_data["registration"]["pivotWorld"])
    socket = source_ground_point(scene_data["registration"]["socketCitySim"])
    expected_footprint = [[768.0, 640.0], [1024.0, 768.0], [768.0, 896.0], [512.0, 768.0]]
    require(projected == expected_footprint, "camera ground footprint drift")
    require(pivot == [768.0, 896.0] and socket == [896.0, 704.0], "camera pivot/socket drift")
    return {
        "footprintSource": projected,
        "pivotSource": pivot,
        "socketSource": socket,
        "orthoScale": camera_profile(scene_data)["orthoScale"],
        "shift": [camera_profile(scene_data)["shiftX"], camera_profile(scene_data)["shiftY"]],
        "registrationLocked": True,
    }


def light_profile(lighting: dict[str, Any]) -> dict[str, Any]:
    key = lighting["key"]
    fill_origin_citysim = [72.0, 70.0, 72.0]
    key_origin = bridge(key["originWorld"])
    key_target = bridge(key["targetWorld"])
    fill_origin = bridge(fill_origin_citysim)
    return {
        "key": {
            **key,
            "authoredEnergyWatts": key["energyWatts"],
            "effectiveEnergyWatts": key["energyWatts"] * KEY_ENERGY_SCALE,
            "originBlender": key_origin,
            "targetBlender": key_target,
            "distanceToTarget": magnitude(subtract(key_target, key_origin)),
            "aimDirection": normalized(subtract(key_target, key_origin)),
        },
        "fill": {
            **lighting["optionalFill"],
            "authoredEnergyWatts": lighting["optionalFill"]["energyWatts"],
            "effectiveEnergyWatts": lighting["optionalFill"]["energyWatts"] * FILL_ENERGY_SCALE,
            "originCitySim": fill_origin_citysim,
            "originBlender": fill_origin,
            "targetBlender": key_target,
            "distanceToTarget": magnitude(subtract(key_target, fill_origin)),
            "aimDirection": normalized(subtract(key_target, fill_origin)),
        },
        "world": lighting["world"],
        "lowering": {"keyEnergyScale": KEY_ENERGY_SCALE, "fillEnergyScale": FILL_ENERGY_SCALE},
    }


def configure_scene(bpy: Any, contract: dict[str, Any], scene_data: dict[str, Any], materials: dict[str, Any], lighting: dict[str, Any]) -> dict[str, Any]:
    scene = bpy.context.scene
    profile = render_profile(contract, lighting)
    scene.render.engine = profile["engine"]
    scene.cycles.device = profile["device"]
    scene.cycles.samples = profile["samples"]
    scene.cycles.use_adaptive_sampling = profile["adaptiveSampling"]
    scene.cycles.use_denoising = profile["denoising"]
    scene.cycles.seed = profile["seed"]
    scene.render.threads_mode = profile["threadsMode"]
    scene.render.threads = profile["threads"]
    scene.render.use_motion_blur = profile["motionBlur"]
    scene.render.film_transparent = profile["transparentFilm"]
    scene.render.resolution_x, scene.render.resolution_y = profile["resolution"]
    scene.render.resolution_percentage = profile["resolutionPercentage"]
    scene.render.pixel_aspect_x, scene.render.pixel_aspect_y = profile["pixelAspect"]
    scene.render.image_settings.file_format = profile["image"]["fileFormat"]
    scene.render.image_settings.color_mode = profile["image"]["colorMode"]
    scene.render.image_settings.color_depth = profile["image"]["colorDepth"]
    scene.render.image_settings.compression = profile["image"]["compression"]
    scene.display_settings.display_device = profile["colorManagement"]["displayDevice"]
    scene.view_settings.view_transform = profile["colorManagement"]["viewTransform"]
    scene.view_settings.look = profile["colorManagement"]["look"]
    scene.view_settings.exposure = profile["colorManagement"]["exposure"]
    scene.view_settings.gamma = profile["colorManagement"]["gamma"]
    material_by_role = configure_materials(bpy, materials)

    world = bpy.data.worlds.new("v14-north-world")
    world.use_nodes = True
    scene.world = world
    nodes = world.node_tree.nodes
    nodes.clear()
    background = nodes.new("ShaderNodeBackground")
    background.inputs["Color"].default_value = lighting["world"]["backgroundColorRGBA"]
    background.inputs["Strength"].default_value = lighting["world"]["backgroundStrength"]
    output = nodes.new("ShaderNodeOutputWorld")
    world.node_tree.links.new(background.outputs["Background"], output.inputs["Surface"])

    camera_settings = camera_profile(scene_data)
    camera_data = bpy.data.cameras.new("v14-north-camera")
    camera = bpy.data.objects.new("v14-north-camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = camera_settings["orthoScale"]
    camera_data.shift_x = camera_settings["shiftX"]
    camera_data.shift_y = camera_settings["shiftY"]
    camera_data.clip_start = camera_settings["clipStart"]
    camera_data.clip_end = camera_settings["clipEnd"]
    camera.location = camera_settings["positionBlender"]
    target_blender = camera_settings["targetBlender"]
    aim(camera, target_blender)
    scene.camera = camera

    lights = light_profile(lighting)
    key = lights["key"]
    key_data = bpy.data.lights.new("v14-north-key", type=key["type"])
    key_data.energy = key["effectiveEnergyWatts"]
    key_data.shape = key["shape"]
    key_data.size = key["sizeWorld"]
    key_data.color = key["colorRGB"]
    key_object = bpy.data.objects.new("v14-north-key", key_data)
    bpy.context.collection.objects.link(key_object)
    key_object.location = key["originBlender"]
    aim(key_object, key["targetBlender"])

    fill = lights["fill"]
    fill_object = None
    if fill["enabled"]:
        fill_data = bpy.data.lights.new("v14-north-fill", type=fill["type"])
        fill_data.energy = fill["effectiveEnergyWatts"]
        fill_data.shape = "DISK"
        fill_data.size = fill["sizeWorld"]
        fill_data.color = fill["colorRGB"]
        fill_object = bpy.data.objects.new("v14-north-fill", fill_data)
        bpy.context.collection.objects.link(fill_object)
        fill_object.location = fill["originBlender"]
        aim(fill_object, fill["targetBlender"])
    return {
        "scene": scene,
        "materials": material_by_role,
        "camera": camera,
        "key": key_object,
        "fill": fill_object,
        "fillOriginCitySim": fill["originCitySim"],
        "targetBlender": target_blender,
    }


def safe_output_leaf(output: Path, name: str) -> Path:
    require(name in ALLOWED_OUTPUTS and Path(name).name == name, f"output leaf forbidden: {name}")
    candidate = output / name
    require(candidate.parent.resolve(strict=True) == output.resolve(strict=True), "output leaf escapes root")
    require(not candidate.exists() and not candidate.is_symlink(), f"output overwrite forbidden: {name}")
    return candidate


def write_json_exclusive(output: Path, name: str, value: Any) -> Path:
    path = safe_output_leaf(output, name)
    with path.open("x", encoding="utf-8") as stream:
        stream.write(canonical(value).decode())
    return path


def decode_png_rgba8(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n", f"PNG signature invalid: {path.name}")
    position = 8
    width = height = 0
    compressed: list[bytes] = []
    seen_end = False
    while position < len(data):
        require(position + 12 <= len(data), f"PNG chunk truncated: {path.name}")
        length = struct.unpack(">I", data[position : position + 4])[0]
        chunk_type = data[position + 4 : position + 8]
        chunk_data = data[position + 8 : position + 8 + length]
        chunk_crc = data[position + 8 + length : position + 12 + length]
        require(len(chunk_data) == length and len(chunk_crc) == 4, f"PNG chunk length invalid: {path.name}")
        require((zlib.crc32(chunk_type + chunk_data) & 0xFFFFFFFF) == struct.unpack(">I", chunk_crc)[0], f"PNG CRC invalid: {path.name}")
        if chunk_type == b"IHDR":
            width, height, depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", chunk_data)
            require(depth == 8 and color_type == 6 and compression == 0 and filtering == 0 and interlace == 0, "RGBA8 noninterlaced PNG required")
        elif chunk_type == b"IDAT":
            compressed.append(chunk_data)
        elif chunk_type == b"IEND":
            seen_end = True
        position += 12 + length
    require(width > 0 and height > 0 and compressed and seen_end, f"PNG structure incomplete: {path.name}")
    inflated = zlib.decompress(b"".join(compressed))
    stride = width * 4
    require(len(inflated) == height * (stride + 1), f"PNG scanline size drift: {path.name}")

    def paeth(left: int, above: int, upper_left: int) -> int:
        prediction = left + above - upper_left
        distances = (abs(prediction - left), abs(prediction - above), abs(prediction - upper_left))
        return (left, above, upper_left)[distances.index(min(distances))]

    pixels: list[tuple[int, int, int, int]] = []
    previous = bytearray(stride)
    for row_index in range(height):
        start = row_index * (stride + 1)
        filter_type = inflated[start]
        require(filter_type in (0, 1, 2, 3, 4), f"PNG filter unsupported: {filter_type}")
        source = inflated[start + 1 : start + 1 + stride]
        row = bytearray(stride)
        for index, value in enumerate(source):
            left = row[index - 4] if index >= 4 else 0
            above = previous[index]
            upper_left = previous[index - 4] if index >= 4 else 0
            predictor = 0 if filter_type == 0 else left if filter_type == 1 else above if filter_type == 2 else (left + above) // 2 if filter_type == 3 else paeth(left, above, upper_left)
            row[index] = (value + predictor) & 0xFF
        pixels.extend(tuple(row[index : index + 4]) for index in range(0, stride, 4))
        previous = row
    return {"width": width, "height": height, "pixels": pixels}


def semantic_linear_color(component_id: str) -> list[float]:
    digest = hashlib.sha256(component_id.encode()).digest()
    return [0.18 + digest[index] / 255.0 * 0.72 for index in range(3)]


def linear_to_srgb8(value: float) -> int:
    encoded = 12.92 * value if value <= 0.0031308 else 1.055 * value ** (1.0 / 2.4) - 0.055
    return max(0, min(255, round(encoded * 255.0)))


def semantic_srgb8(component_id: str) -> tuple[int, int, int]:
    return tuple(linear_to_srgb8(value) for value in semantic_linear_color(component_id))


def percentile(values: list[float], fraction: float) -> float:
    require(values and 0.0 <= fraction <= 1.0, "percentile input invalid")
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * fraction)]


def pixel_luma(pixel: tuple[int, int, int, int]) -> float:
    return (0.2126 * pixel[0] + 0.7152 * pixel[1] + 0.0722 * pixel[2]) / 255.0


def evaluate_visibility_pixels(
    width: int,
    height: int,
    raw_pixels: list[tuple[int, int, int, int]],
    semantic_pixels: list[tuple[int, int, int, int]],
    gates: dict[str, Any],
) -> dict[str, Any]:
    require(width > 0 and height > 0 and len(raw_pixels) == len(semantic_pixels) == width * height, "visibility image dimensions drift")
    occupied = [index for index, pixel in enumerate(raw_pixels) if pixel[3] > 0]
    require(occupied, "render has no occupied pixels")
    xs = [index % width for index in occupied]
    ys = [index // width for index in occupied]
    bounds = {"x": min(xs), "y": min(ys), "width": max(xs) - min(xs) + 1, "height": max(ys) - min(ys) + 1}
    lumas = [pixel_luma(raw_pixels[index]) for index in occupied]
    median_luma, p95_luma = percentile(lumas, 0.5), percentile(lumas, 0.95)

    frame_ids = [
        "v14-monumental-portal-west-jamb",
        "v14-monumental-portal-east-jamb",
        "v14-monumental-portal-header",
    ]
    depth_ids = ["v14-freight-bay-west", "v14-freight-bay-center", "v14-freight-bay-east"]
    semantic_targets = {component_id: semantic_srgb8(component_id) for component_id in frame_ids + depth_ids}
    tolerance = 6
    component_pixels: dict[str, list[int]] = {component_id: [] for component_id in semantic_targets}
    for index, pixel in enumerate(semantic_pixels):
        if pixel[3] < 250:
            continue
        matches = [component_id for component_id, target in semantic_targets.items() if max(abs(pixel[channel] - target[channel]) for channel in range(3)) <= tolerance]
        if len(matches) == 1:
            component_pixels[matches[0]].append(index)
    counts = {component_id: len(indices) for component_id, indices in component_pixels.items()}
    frame_indices = [index for component_id in frame_ids for index in component_pixels[component_id]]
    depth_indices = [index for component_id in depth_ids for index in component_pixels[component_id]]
    frame_median = percentile([pixel_luma(raw_pixels[index]) for index in frame_indices], 0.5) if frame_indices else 0.0
    depth_median = percentile([pixel_luma(raw_pixels[index]) for index in depth_indices], 0.5) if depth_indices else 0.0
    frame_delta = frame_median - depth_median
    checks = {
        "occupiedWidth": bounds["width"] / width >= 0.30,
        "occupiedHeight": bounds["height"] / height >= 0.30,
        "medianLuma": gates["medianLumaMin"] <= median_luma <= gates["medianLumaMax"],
        "p95Luma": gates["p95LumaMin"] <= p95_luma <= gates["p95LumaMax"],
        "westJambCore": counts[frame_ids[0]] >= 8,
        "eastJambCore": counts[frame_ids[1]] >= 8,
        "headerCore": counts[frame_ids[2]] >= 8,
        "freightDepthCore": sum(counts[component_id] for component_id in depth_ids) >= 24,
        "portalFrameDelta": frame_delta >= gates["portalFrameDelta"],
    }
    return {
        "passes": all(checks.values()),
        "checks": checks,
        "failed": [name for name, passed in checks.items() if not passed],
        "dimensions": [width, height],
        "alphaBounds": bounds,
        "occupiedFractions": {"width": bounds["width"] / width, "height": bounds["height"] / height},
        "luma": {"median": median_luma, "p95": p95_luma},
        "frontage": {"componentCorePixels": counts, "frameMedianLuma": frame_median, "depthMedianLuma": depth_median, "frameDepthDelta": frame_delta},
    }


def evaluate_post_render_visibility(raw_path: Path, semantic_path: Path, lighting: dict[str, Any]) -> dict[str, Any]:
    raw = decode_png_rgba8(raw_path)
    semantic = decode_png_rgba8(semantic_path)
    require((raw["width"], raw["height"]) == (semantic["width"], semantic["height"]), "raw/semantic dimension mismatch")
    return evaluate_visibility_pixels(raw["width"], raw["height"], raw["pixels"], semantic["pixels"], lighting["gates"])


def validate_child_authority(root: Path, contract: dict[str, Any], args: argparse.Namespace) -> dict[str, Any]:
    require(args.direction == "north", "North-only child")
    require(os.environ.get("CITYSIM_PROCESS_A_LIVE") == "1", "direct child invocation rejected")
    launcher = load_module(root / LAUNCHER_PATH, "play027_v14_child_launcher_contract")
    documents = launcher.validate_direct_documents(root, contract, Path(args.schedule), Path(args.grant), Path(args.integration_session))
    require(os.environ.get("CITYSIM_PROCESS_A_SCHEDULE_SHA256") == documents["scheduleSHA256"], "schedule environment drift")
    require(os.environ.get("CITYSIM_PROCESS_A_GRANT_SHA256") == documents["grantSHA256"], "grant environment drift")
    require(os.environ.get("CITYSIM_PROCESS_A_SESSION_SHA256") == documents["sessionSHA256"], "session environment drift")
    output = Path(args.output_root)
    expected_output = root / contract["outputRoot"]
    require(output.is_absolute() and output == expected_output, "output argument drift")
    require(output.exists() and output.is_dir() and not output.is_symlink(), "launcher-created output root required")
    require(output.resolve(strict=True) == expected_output.resolve(strict=True), "output root containment drift")
    require(str(output.stat().st_ino) == os.environ.get("CITYSIM_PROCESS_A_OUTPUT_INODE"), "output root inode drift")
    require(not any(output.iterdir()), "output root must be empty at child start")
    return {"launcher": launcher, "documents": documents, "outputRoot": output}


def semantic_material(bpy: Any, component_id: str) -> Any:
    color = semantic_linear_color(component_id) + [1.0]
    material = bpy.data.materials.new(f"semantic::{component_id}")
    material.use_nodes = True
    node = material.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = [0.0, 0.0, 0.0, 1.0]
    node.inputs["Roughness"].default_value = 1.0
    node.inputs["Metallic"].default_value = 0.0
    node.inputs["Emission Color"].default_value = color
    node.inputs["Emission Strength"].default_value = 1.0
    return material


def render_semantic_pass(bpy: Any, scene: Any, output: Path, objects_by_id: dict[str, Any], item_by_id: dict[str, dict[str, Any]]) -> None:
    originals: dict[str, Any] = {}
    catcher_state: dict[str, bool] = {}
    for object_id, obj in objects_by_id.items():
        originals[object_id] = obj.data.materials[0]
        catcher_state[object_id] = bool(obj.is_shadow_catcher)
        obj.is_shadow_catcher = False
        obj.data.materials[0] = semantic_material(bpy, item_by_id[object_id]["componentID"])
    original_view_transform = scene.view_settings.view_transform
    original_look = scene.view_settings.look
    original_exposure = scene.view_settings.exposure
    original_gamma = scene.view_settings.gamma
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    semantic_path = safe_output_leaf(output, "semantic.png")
    scene.render.filepath = str(semantic_path)
    bpy.ops.render.render(write_still=True)
    require(semantic_path.is_file(), "semantic render missing")
    scene.view_settings.view_transform = original_view_transform
    scene.view_settings.look = original_look
    scene.view_settings.exposure = original_exposure
    scene.view_settings.gamma = original_gamma
    for object_id, obj in objects_by_id.items():
        obj.data.materials[0] = originals[object_id]
        obj.is_shadow_catcher = catcher_state[object_id]


def parse_args(values: list[str] | None = None) -> argparse.Namespace:
    if values is None:
        require("--" in sys.argv, "Blender separator required")
        values = sys.argv[sys.argv.index("--") + 1 :]
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--direction", required=True)
    parser.add_argument("--schedule", required=True)
    parser.add_argument("--grant", required=True)
    parser.add_argument("--integration-session", required=True)
    parser.add_argument("--output-root", required=True)
    return parser.parse_args(values)


def main(values: list[str] | None = None) -> int:
    args = parse_args(values)
    root = Path(args.repository_root).resolve(strict=True)
    contract_path = Path(args.contract).resolve(strict=True)
    require(contract_path == root / PROCESS_ROOT / "EXECUTION-CONTRACT.json", "contract path drift")
    contract = load_json(contract_path)
    authority = validate_child_authority(root, contract, args)
    output = authority["outputRoot"]
    scene_data = load_json(root / contract["frozenInputs"]["scene"]["path"])
    materials = load_json(root / contract["frozenInputs"]["materials"]["path"])
    lighting = load_json(root / contract["frozenInputs"]["lighting"]["path"])
    packet = construct_semantic_geometry(root, contract)
    specs = build_mesh_specs(packet["manifest"])

    # Import Blender only after all authority, identity, path, and pure-data topology checks pass.
    import bpy  # type: ignore

    configured = configure_scene(bpy, contract, scene_data, materials, lighting)
    item_by_id = {item["id"]: item for item in packet["manifest"]["objects"]}
    objects_by_id: dict[str, Any] = {}
    for spec in specs["solidSpecs"]:
        item = item_by_id[spec["id"]]
        objects_by_id[spec["id"]] = mesh_object(bpy, spec, configured["materials"][item["materialRole"]])
    require(len(objects_by_id) == 96, "Blender object construction count drift")

    raw_path = safe_output_leaf(output, "raw.png")
    configured["scene"].render.filepath = str(raw_path)
    bpy.ops.render.render(write_still=True)
    require(raw_path.is_file(), "raw render missing")
    render_semantic_pass(bpy, configured["scene"], output, objects_by_id, item_by_id)
    visibility = evaluate_post_render_visibility(raw_path, output / "semantic.png", lighting)
    require(visibility["passes"], f"post-render visibility gate failed: {visibility['failed']}")
    blend_path = safe_output_leaf(output, "north-v14-process-a.blend")
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    require(blend_path.is_file(), "blend evidence missing")

    runtime_manifest = {
        **packet["manifest"],
        "runtimeObjects": [
            {
                "id": spec["id"], "geometryKind": spec["geometryKind"], "builder": spec["builder"],
                "vertexCount": len(spec["vertices"]), "faceCount": len(spec["faces"]),
                "materialRole": item_by_id[spec["id"]]["materialRole"],
            }
            for spec in specs["solidSpecs"]
        ],
        "voidIDs": specs["voidIDs"],
        "orientation": {
            "closedOutwardObjects": specs["closedOutwardObjects"],
            "openTwoSidedObjects": specs["openTwoSidedObjects"],
            "reports": specs["orientationReports"],
        },
    }
    write_json_exclusive(output, "OBJECT-MANIFEST.json", runtime_manifest)
    write_json_exclusive(output, "GROUND-PROJECTION.json", packet["report"]["registration"])
    write_json_exclusive(output, "INPUT-BINDINGS.json", {
        "frozenInputs": contract["frozenInputs"],
        "scheduleSHA256": authority["documents"]["scheduleSHA256"],
        "grantSHA256": authority["documents"]["grantSHA256"],
        "sessionSHA256": authority["documents"]["sessionSHA256"],
    })
    object_manifest_path = output / "OBJECT-MANIFEST.json"
    projection_path = output / "GROUND-PROJECTION.json"
    bindings_path = output / "INPUT-BINDINGS.json"
    provenance = {
        "task": "PLAY-027", "direction": "north", "process": "A",
        "inputHashes": packet["inputHashes"], "childStarts": 1, "dccProcessCount": 1,
        "coordinateBridge": "B(x,y,z)=(z,x,y)",
        "postRenderVisibility": visibility,
        "cameraGroundProjection": ground_projection_report(scene_data),
        "lightLowering": light_profile(lighting),
        "outputHashes": {
            "raw.png": sha256(raw_path), "semantic.png": sha256(output / "semantic.png"),
            "north-v14-process-a.blend": sha256(blend_path),
            "OBJECT-MANIFEST.json": sha256(object_manifest_path),
            "GROUND-PROJECTION.json": sha256(projection_path),
            "INPUT-BINDINGS.json": sha256(bindings_path),
        },
        "sourceAuthority": False, "productionSelected": False,
    }
    write_json_exclusive(output, "provenance.json", provenance)
    write_json_exclusive(output, "PROCESS-RECEIPT.json", {
        "status": "PROCESS_A_COMPLETE", "direction": "north", "childStarts": 1,
        "renderPath": "raw.png", "semanticPath": "semantic.png", "blendPath": "north-v14-process-a.blend",
        "postRenderVisibility": visibility,
        "sourceAuthority": False, "productionSelected": False,
    })
    require({path.name for path in output.iterdir()} == ALLOWED_OUTPUTS, "output inventory drift")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
