#!/usr/bin/env python3
"""Deterministic East Process-A Blender child; imported only after launch authority."""

from __future__ import annotations

import json
import math
import stat
from pathlib import Path


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[7]
DESIGN = REPO / "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/V14-COMPATIBILITY-DESIGN.json"
LOWERING = REPO / "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/LOWERING.json"
CONTRACT = ROOT / "PROCESS-A-CONTRACT.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _descriptor(component: dict, object_id: str, primitive: str, **extra: object) -> dict:
    result = {
        "objectId": object_id,
        "primitive": primitive,
        "bounds": component["bounds"],
        "semanticRole": component["semanticRole"],
        "materialRole": component["materialRole"],
    }
    result.update(extra)
    return result


def build_portal_frame(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "portal_frame_compound", parts=["jamb_left", "jamb_right", "header", "reveal", "inset"], openAperture=True, voidObjectId=object_id + "_void")


def build_portal_void(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "intentional_portal_void", intentionalVoid=True, parts=[])


def build_box(component: dict, object_id: str) -> dict:
    kind = component["kind"]
    if kind == "portal-frame":
        return build_portal_frame(component, object_id)
    if kind == "portal-inset":
        return build_portal_void(component, object_id)
    return _descriptor(component, object_id, "deterministic_box", parts=["solid_mass"])


def build_roof_wedge(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "pitched_roof_wedge", parts=["wedge_shell", "ridge"])


def build_mullioned_glazing(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "mullion_band_compound", parts=["frame", "mullion_0", "mullion_1", "mullion_2", "louver_slats_0", "louver_slats_1", "louver_slats_2", "louver_slats_3"])


def build_capped_vessel(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "capped_vessel_stack", parts=["cylinder", "top_cap", "base_ring"])


def build_heat_cap(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "restrained_heat_cap", parts=["vessel", "cap", "process_nozzle"])


def build_railing(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "rail_post_truss", parts=["posts", "top_rail", "mid_rail", "truss_diagonals"], trussEndpoints=[{"start":[component["bounds"]["xMin"],component["bounds"]["yMin"],component["bounds"]["zMin"]],"end":[component["bounds"]["xMax"],component["bounds"]["yMin"],component["bounds"]["zMax"]]}, {"start":[component["bounds"]["xMin"],component["bounds"]["yMin"],component["bounds"]["zMax"]],"end":[component["bounds"]["xMax"],component["bounds"]["yMin"],component["bounds"]["zMin"]]}])


def build_pipe_run(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "capped_pipe_run", parts=["cylinder", "end_cap_a", "end_cap_b"])


def build_pipe_elbow(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "torus_pipe_elbow", parts=["quarter_turn", "end_cap_a", "end_cap_b"], startAngle=0.0, endAngle=math.pi / 2.0, arcDegrees=90.0, endCaps=2, majorSegments=12)


def build_pipe_support(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "pipe_support_saddle", parts=["post_a", "post_b", "saddle"])


def build_roof_plant(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "roof_plant_modules", parts=["housing", "vent_a", "vent_b", "service_cap"])


def build_vent_array(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "vent_louver_array", parts=["frame", "louver_0", "louver_1", "louver_2", "louver_3"])


def build_service_door(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "framed_service_door", parts=["leaf", "frame_left", "frame_right", "frame_header", "handle"])


def build_gutter(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "gutter_downspouts", parts=["gutter", "downspout_a", "downspout_b"])


def build_roof_edge(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "roof_edge_flashing", parts=["trim", "flashing"])


def build_loading_marking(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "loading_chevron_marking", parts=["chevron_a", "chevron_b", "chevron_c"], bars=[{"id": object_id + "_bar_a", "angleDegrees": 45.0}, {"id": object_id + "_bar_b", "angleDegrees": -45.0}, {"id": object_id + "_bar_c", "angleDegrees": 45.0}])


def build_seam_band(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "masonry_seam_wear_band", parts=["seam_0", "seam_1", "seam_2", "soot_band"])


BUILDERS = {
    "box": build_box,
    "roof_wedge": build_roof_wedge,
    "mullioned_glazing": build_mullioned_glazing,
    "capped_vessel": build_capped_vessel,
    "heat_cap": build_heat_cap,
    "railing": build_railing,
    "pipe_run": build_pipe_run,
    "pipe_elbow": build_pipe_elbow,
    "pipe_support": build_pipe_support,
    "roof_plant": build_roof_plant,
    "vent_array": build_vent_array,
    "service_door": build_service_door,
    "gutter": build_gutter,
    "roof_edge": build_roof_edge,
    "loading_marking": build_loading_marking,
    "seam_band": build_seam_band,
}


def build_semantic_geometry() -> dict:
    design = _load(DESIGN)
    lowering = _load(LOWERING)
    components = {item["id"]: item for item in design["components"]}
    lowered = []
    for record in lowering["components"]:
        component = components[record["componentId"]]
        if len(record["objectIDs"]) != 1:
            raise ValueError("lowering_object_id_arity")
        builder = BUILDERS[record["builder"]]
        lowered.append(builder(component, record["objectIDs"][0]))
    portal_ids = {"east-v14-portal-south-jamb", "east-v14-portal-north-jamb", "east-v14-portal-header", "east-v14-freight-void"}
    portal_components = [components[item_id] for item_id in portal_ids]
    portal_bounds = {
        "xMin": min(item["bounds"]["xMin"] for item in portal_components), "xMax": max(item["bounds"]["xMax"] for item in portal_components),
        "yMin": min(item["bounds"]["yMin"] for item in portal_components), "yMax": max(item["bounds"]["yMax"] for item in portal_components),
        "zMin": min(item["bounds"]["zMin"] for item in portal_components), "zMax": max(item["bounds"]["zMax"] for item in portal_components),
    }
    return {
        "components": lowered,
        "camera": design["camera"],
        "registration": design["eastRegistration"],
        "light": design["light"],
        "materialRoles": sorted(set(item["materialRole"] for item in lowered)),
        "portalAssembly": portal_assembly_plan(portal_bounds),
    }


def portal_frame_plan(bounds: dict) -> dict:
    """Describe an open portal: jambs/header, reveal and inset, never a solid AABB."""
    x0, x1, y0, y1, z0, z1 = (bounds[key] for key in ("xMin", "xMax", "yMin", "yMax", "zMin", "zMax"))
    sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
    trim = max(min(sx, sz) * 0.12, 0.01)
    reveal_depth = max(sy * 0.18, 0.01)
    return {"openAperture": True, "pieces": [
        {"id": "jamb_left", "materialRole": "dark-painted-steel", "bounds": {"xMin": x0, "xMax": x0 + trim, "yMin": y0, "yMax": y1, "zMin": z0, "zMax": z1}},
        {"id": "jamb_right", "materialRole": "dark-painted-steel", "bounds": {"xMin": x1 - trim, "xMax": x1, "yMin": y0, "yMax": y1, "zMin": z0, "zMax": z1}},
        {"id": "header", "materialRole": "formed-concrete", "bounds": {"xMin": x0 + trim, "xMax": x1 - trim, "yMin": y0, "yMax": y1, "zMin": z1 - trim, "zMax": z1}},
        {"id": "reveal", "materialRole": "dark-painted-steel", "bounds": {"xMin": x0 + trim, "xMax": x1 - trim, "yMin": y1 - reveal_depth, "yMax": y1, "zMin": z0 + trim, "zMax": z1 - trim}},
        {"id": "inset", "materialRole": "portal-void", "bounds": {"xMin": x0 + trim * 1.5, "xMax": x1 - trim * 1.5, "yMin": y1 - reveal_depth * 1.2, "yMax": y1 - reveal_depth, "zMin": z0 + trim * 1.5, "zMax": z1 - trim * 1.5}},
    ], "void": {"id": "void", "bounds": bounds}}


def portal_assembly_plan(bounds: dict) -> dict:
    plan = portal_frame_plan(bounds)
    plan["assemblyId"] = "east_v14_freight_portal_assembly"
    plan["revealSurfaces"] = ["reveal", "inset"]
    plan["backPlaneMaterial"] = "portal-void"
    plan["reachableFromLowering"] = True
    return plan


def quarter_elbow_plan(bounds: dict) -> dict:
    size = (bounds["xMax"] - bounds["xMin"], bounds["yMax"] - bounds["yMin"], bounds["zMax"] - bounds["zMin"])
    radius = min(value for value in size if value > 0) * 0.22
    return {"startAngle": 0.0, "endAngle": math.pi / 2.0, "arcDegrees": 90.0, "majorRadius": max(min(size[0], size[1]) * 0.30, radius * 2), "tubeRadius": radius, "segments": 12, "endCaps": 2}


def loading_marking_plan(bounds: dict) -> dict:
    x0, x1, y0, y1, z0, z1 = (bounds[key] for key in ("xMin", "xMax", "yMin", "yMax", "zMin", "zMax"))
    sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
    bars = []
    for index, sign in enumerate((1.0, -1.0, 1.0)):
        start_x = x0 + sx * (0.18 + index * 0.28)
        start = (start_x, y0, z0 + sz * 0.08)
        end = (start_x + sx * 0.18 * sign, y1, z0 + sz * 0.92)
        bars.append({"id": f"bar_{index}", "start": start, "end": end, "angleDegrees": 45.0 * sign})
    return {"bars": bars, "diagonal": True}


def mullion_louver_plan(bounds: dict) -> dict:
    x0, x1, y0, y1, z0, z1 = (bounds[key] for key in ("xMin", "xMax", "yMin", "yMax", "zMin", "zMax"))
    sx, sz = x1 - x0, z1 - z0
    frame = max(min(sx, sz) * 0.12, 0.01)
    slats = []
    for index in range(4):
        z = z0 + sz * (index + 1) / 5
        slats.append({"id": f"louver_{index}", "bounds": {"xMin": x0 + frame, "xMax": x1 - frame, "yMin": y0, "yMax": y1, "zMin": z - frame * 0.35, "zMax": z + frame * 0.35}})
    return {"frame": True, "mullions": 3, "louverSlats": slats}


def validate_runtime_semantics(semantic: dict) -> None:
    if not validate_portal_assembly(semantic.get("portalAssembly")):
        raise ValueError("portal_assembly_unreachable")
    for item in semantic["components"]:
        primitive = item["primitive"]
        if primitive == "portal_frame_compound":
            plan = portal_frame_plan(item["bounds"])
            if not validate_portal_plan(plan):
                raise ValueError("portal_frame_not_open")
        elif primitive == "torus_pipe_elbow":
            plan = quarter_elbow_plan(item["bounds"])
            if not validate_elbow_plan(plan):
                raise ValueError("elbow_not_bounded_quarter")
        elif primitive == "loading_chevron_marking":
            plan = loading_marking_plan(item["bounds"])
            if not validate_loading_plan(plan):
                raise ValueError("loading_marking_not_computed")
        elif primitive == "mullion_band_compound":
            plan = mullion_louver_plan(item["bounds"])
            if not validate_mullion_plan(plan):
                raise ValueError("mullion_louver_missing")
        elif primitive == "rail_post_truss":
            if not validate_truss_plan(item):
                raise ValueError("truss_unreachable")


def validate_portal_plan(plan: dict) -> bool:
    return bool(plan.get("openAperture")) and len(plan.get("pieces", [])) == 5 and all(p.get("bounds", {}).get("xMax", 0) > p.get("bounds", {}).get("xMin", 0) for p in plan.get("pieces", []))


def validate_elbow_plan(plan: dict) -> bool:
    return abs(plan.get("arcDegrees", 0.0) - 90.0) <= 1e-6 and plan.get("endCaps") == 2 and int(plan.get("segments", 0)) >= 8 and plan.get("startAngle") != plan.get("endAngle")


def validate_loading_plan(plan: dict) -> bool:
    return bool(plan.get("diagonal")) and len(plan.get("bars", [])) == 3 and all(abs(bar["end"][0] - bar["start"][0]) > 0 and abs(bar["end"][2] - bar["start"][2]) > 0 for bar in plan["bars"])


def validate_mullion_plan(plan: dict) -> bool:
    return plan.get("mullions") == 3 and len(plan.get("louverSlats", [])) == 4 and all(s.get("bounds", {}).get("xMax", 0) > s.get("bounds", {}).get("xMin", 0) for s in plan["louverSlats"])


def validate_truss_plan(item: dict) -> bool:
    endpoints = item.get("trussEndpoints", [])
    return len(endpoints) >= 2 and all(endpoint.get("start") != endpoint.get("end") for endpoint in endpoints) and len({tuple(endpoint["start"]) + tuple(endpoint["end"]) for endpoint in endpoints}) == len(endpoints)


def _center(bounds: dict) -> tuple[float, float, float]:
    return ((bounds["xMin"] + bounds["xMax"]) / 2, (bounds["yMin"] + bounds["yMax"]) / 2, (bounds["zMin"] + bounds["zMax"]) / 2)


def _size(bounds: dict) -> tuple[float, float, float]:
    return (bounds["xMax"] - bounds["xMin"], bounds["yMax"] - bounds["yMin"], bounds["zMax"] - bounds["zMin"])


def _add_box_bounds(bpy, bounds: dict, name: str):
    bpy.ops.mesh.primitive_cube_add(size=1, location=_center(bounds))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = _size(bounds)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def _add_box(bpy, item: dict):
    return _add_box_bounds(bpy, item["bounds"], item["objectId"])


def _add_roof_wedge(bpy, item: dict):
    b = item["bounds"]
    x0, x1, y0, y1, z0, z1 = b["xMin"], b["xMax"], b["yMin"], b["yMax"], b["zMin"], b["zMax"]
    mesh = bpy.data.meshes.new(item["objectId"] + "_wedge_mesh")
    mesh.from_pydata(
        [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1 - (z1 - z0) * 0.2), (x0, y1, z1 - (z1 - z0) * 0.2)],
        [],
        [(0, 1, 2, 3), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0), (4, 7, 6, 5)],
    )
    mesh.update()
    obj = bpy.data.objects.new(item["objectId"], mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _add_capped_vessel(bpy, item: dict):
    b = item["bounds"]
    size = _size(b)
    radius = min(size[0], size[1]) / 2
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=size[2], location=_center(b))
    obj = bpy.context.object
    obj.name = item["objectId"]
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=radius, radius2=radius * 0.78, depth=max(size[2] * 0.12, 0.01), location=(obj.location.x, obj.location.y, b["zMax"] + max(size[2] * 0.06, 0.01)))
    cap = bpy.context.object
    cap.name = item["objectId"] + "_top_cap"
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8, major_radius=radius * 0.82, minor_radius=max(radius * 0.08, 0.01), location=(obj.location.x, obj.location.y, b["zMin"]))
    ring = bpy.context.object
    ring.name = item["objectId"] + "_base_ring"
    return obj


def _add_heat_cap(bpy, item: dict):
    obj = _add_capped_vessel(bpy, item)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=max(_size(item["bounds"])) * 0.07, depth=max(_size(item["bounds"])[2] * 0.2, 0.01), location=(obj.location.x, obj.location.y, item["bounds"]["zMax"]))
    nozzle = bpy.context.object
    nozzle.name = item["objectId"] + "_process_nozzle"
    return obj


def _add_pipe_between(bpy, start: tuple[float, float, float], end: tuple[float, float, float], radius: float, name: str):
    from mathutils import Vector
    start_v, end_v = Vector(start), Vector(end)
    delta = end_v - start_v
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=delta.length, location=(start_v + end_v) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return obj


def _add_pipe_run(bpy, item: dict):
    b = item["bounds"]
    size = _size(b)
    axis = max(range(3), key=lambda index: size[index])
    center = list(_center(b))
    start = list(center)
    end = list(center)
    axis_min = (b["xMin"], b["yMin"], b["zMin"])[axis]
    axis_max = (b["xMax"], b["yMax"], b["zMax"])[axis]
    start[axis], end[axis] = axis_min, axis_max
    radius = min(value for value in size if value > 0) / 2
    obj = _add_pipe_between(bpy, tuple(start), tuple(end), radius, item["objectId"])
    for suffix, location in (("_end_cap_a", tuple(start)), ("_end_cap_b", tuple(end))):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=radius, location=location)
        bpy.context.object.name = item["objectId"] + suffix
    return obj


def _add_pipe_elbow(bpy, item: dict):
    from mathutils import Vector
    b = item["bounds"]
    spec = quarter_elbow_plan(b)
    center = Vector((_center(b)[0], _center(b)[1], _center(b)[2]))
    major, tube = spec["majorRadius"], spec["tubeRadius"]
    vertices, faces = [], []
    radial_segments = 8
    for i in range(spec["segments"] + 1):
        angle = spec["startAngle"] + (spec["endAngle"] - spec["startAngle"]) * i / spec["segments"]
        ring_center = center + Vector((major * math.cos(angle), major * math.sin(angle), 0.0))
        tangent = Vector((-math.sin(angle), math.cos(angle), 0.0))
        for j in range(radial_segments):
            phi = 2.0 * math.pi * j / radial_segments
            vertices.append(tuple(ring_center + tube * (math.cos(phi) * Vector((0.0, 0.0, 1.0)) + math.sin(phi) * Vector((math.cos(angle), math.sin(angle), 0.0)))))
    for i in range(spec["segments"]):
        for j in range(radial_segments):
            a = i * radial_segments + j
            bidx = i * radial_segments + (j + 1) % radial_segments
            c = (i + 1) * radial_segments + (j + 1) % radial_segments
            d = (i + 1) * radial_segments + j
            faces.append((a, bidx, c, d))
    # Explicit end caps close the bounded quarter shell.
    start_center = len(vertices); vertices.append(tuple(center + Vector((major, 0.0, 0.0))))
    end_center = len(vertices); vertices.append(tuple(center + Vector((0.0, major, 0.0))))
    for j in range(radial_segments):
        faces.append((start_center, (j + 1) % radial_segments, j))
        end_base = spec["segments"] * radial_segments
        faces.append((end_center, end_base + j, end_base + (j + 1) % radial_segments))
    mesh = bpy.data.meshes.new(item["objectId"] + "_quarter_elbow_mesh")
    mesh.from_pydata(vertices, [], faces); mesh.update()
    obj = bpy.data.objects.new(item["objectId"], mesh)
    bpy.context.collection.objects.link(obj)
    for suffix, location in (("_end_cap_a", tuple(center + Vector((major, 0.0, 0.0)))), ("_end_cap_b", tuple(center + Vector((0.0, major, 0.0))))):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=tube, location=location)
        bpy.context.object.name = item["objectId"] + suffix
    return obj


def _add_portal_frame(bpy, item: dict):
    plan = portal_frame_plan(item["bounds"])
    primary = None
    for piece in plan["pieces"]:
        obj = _add_box_bounds(bpy, piece["bounds"], item["objectId"] + "_" + piece["id"])
        primary = primary or obj
    _add_portal_void(bpy, {"objectId": item["objectId"] + "_void", "bounds": plan["void"]["bounds"]})
    return primary


def _add_portal_assembly(bpy, plan: dict):
    primary = None
    for piece in plan["pieces"]:
        obj = _add_box_bounds(bpy, piece["bounds"], "east_v14_freight_portal_" + piece["id"])
        obj["materialRole"] = piece.get("materialRole", "dark-painted-steel")
        primary = primary or obj
    # The aperture is recessed, with a visible dark back plane; no Empty proxy.
    inset = next(piece for piece in plan["pieces"] if piece["id"] == "inset")
    back = _add_box_bounds(bpy, inset["bounds"], "east_v14_freight_portal_back_plane")
    back["portalBackPlane"] = True
    back["materialRole"] = "portal-void"
    return primary


def _add_portal_void(bpy, item: dict):
    raise ValueError("portal_empty_forbidden")


def _add_mullion_band(bpy, item: dict):
    b = item["bounds"]
    sx, sy, sz = _size(b)
    frame = min(sx, sz) * 0.12
    parts = [
        (dict(xMin=b["xMin"], xMax=b["xMax"], yMin=b["yMin"], yMax=b["yMax"], zMin=b["zMin"], zMax=b["zMin"] + frame), "_frame_bottom"),
        (dict(xMin=b["xMin"], xMax=b["xMax"], yMin=b["yMin"], yMax=b["yMax"], zMin=b["zMax"] - frame, zMax=b["zMax"]), "_frame_top"),
        (dict(xMin=b["xMin"], xMax=b["xMin"] + frame, yMin=b["yMin"], yMax=b["yMax"], zMin=b["zMin"], zMax=b["zMax"]), "_frame_left"),
        (dict(xMin=b["xMax"] - frame, xMax=b["xMax"], yMin=b["yMin"], yMax=b["yMax"], zMin=b["zMin"], zMax=b["zMax"]), "_frame_right"),
    ]
    primary = _add_box_bounds(bpy, parts[0][0], item["objectId"] + parts[0][1])
    for bounds, suffix in parts[1:]:
        _add_box_bounds(bpy, bounds, item["objectId"] + suffix)
    for index in range(3):
        x = b["xMin"] + sx * (index + 1) / 4
        _add_box_bounds(bpy, {"xMin": x - frame / 2, "xMax": x + frame / 2, "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMin"] + frame, "zMax": b["zMax"] - frame}, item["objectId"] + f"_mullion_{index}")
    for index, slat in enumerate(mullion_louver_plan(b)["louverSlats"]):
        _add_box_bounds(bpy, slat["bounds"], item["objectId"] + f"_louver_{index}")
    return primary


def _add_railing(bpy, item: dict):
    b = item["bounds"]
    sx, sy, sz = _size(b)
    radius = min(sx, sy, sz) * 0.12
    xs = [b["xMin"], (b["xMin"] + b["xMax"]) / 2, b["xMax"]]
    primary = _add_pipe_between(bpy, (xs[0], b["yMin"], b["zMin"]), (xs[0], b["yMin"], b["zMax"]), radius, item["objectId"] + "_post_0")
    for index, x in enumerate(xs[1:], 1):
        _add_pipe_between(bpy, (x, b["yMin"], b["zMin"]), (x, b["yMin"], b["zMax"]), radius, item["objectId"] + f"_post_{index}")
    for name, z in (("_top_rail", b["zMax"]), ("_mid_rail", b["zMin"] + sz * 0.5)):
        _add_pipe_between(bpy, (b["xMin"], b["yMin"], z), (b["xMax"], b["yMin"], z), radius, item["objectId"] + name)
    _add_pipe_between(bpy, (b["xMin"], b["yMin"], b["zMin"]), (b["xMin"] + sx * 0.5, b["yMin"], b["zMax"]), radius * 0.7, item["objectId"] + "_truss_diagonal_a")
    _add_pipe_between(bpy, (b["xMin"] + sx * 0.5, b["yMin"], b["zMax"]), (b["xMax"], b["yMin"], b["zMin"]), radius * 0.7, item["objectId"] + "_truss_diagonal_b")
    return primary


def _add_pipe_support(bpy, item: dict):
    b = item["bounds"]
    sx, sy, sz = _size(b)
    radius = min(sx, sy, sz) * 0.2
    primary = _add_box_bounds(bpy, {"xMin": b["xMin"], "xMax": b["xMin"] + sx * 0.25, "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMin"], "zMax": b["zMax"]}, item["objectId"] + "_post_a")
    _add_box_bounds(bpy, {"xMin": b["xMax"] - sx * 0.25, "xMax": b["xMax"], "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMin"], "zMax": b["zMax"]}, item["objectId"] + "_post_b")
    _add_pipe_between(bpy, (b["xMin"], b["yMin"], b["zMax"]), (b["xMax"], b["yMin"], b["zMax"]), radius, item["objectId"] + "_saddle")
    return primary


def _add_roof_plant(bpy, item: dict):
    b = item["bounds"]
    sx, sy, sz = _size(b)
    primary = _add_box_bounds(bpy, {"xMin": b["xMin"], "xMax": b["xMax"], "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMin"], "zMax": b["zMin"] + sz * 0.55}, item["objectId"] + "_housing")
    for index, x in enumerate((b["xMin"] + sx * 0.3, b["xMin"] + sx * 0.7)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=min(sx, sy) * 0.12, depth=sz * 0.4, location=(x, (b["yMin"] + b["yMax"]) / 2, b["zMin"] + sz * 0.75))
        bpy.context.object.name = item["objectId"] + f"_vent_{index}"
    _add_box_bounds(bpy, {"xMin": b["xMin"] + sx * 0.25, "xMax": b["xMax"] - sx * 0.25, "yMin": b["yMin"] + sy * 0.2, "yMax": b["yMax"] - sy * 0.2, "zMin": b["zMax"] - sz * 0.12, "zMax": b["zMax"]}, item["objectId"] + "_service_cap")
    return primary


def _add_vent_array(bpy, item: dict):
    b = item["bounds"]
    sx, sy, sz = _size(b)
    frame = min(sx, sy) * 0.12
    primary = _add_box_bounds(bpy, {"xMin": b["xMin"], "xMax": b["xMax"], "yMin": b["yMin"], "yMax": b["yMin"] + frame, "zMin": b["zMin"], "zMax": b["zMax"]}, item["objectId"] + "_frame")
    for index in range(4):
        z = b["zMin"] + sz * (index + 1) / 5
        _add_box_bounds(bpy, {"xMin": b["xMin"] + frame, "xMax": b["xMax"] - frame, "yMin": b["yMin"], "yMax": b["yMax"], "zMin": z - frame / 2, "zMax": z + frame / 2}, item["objectId"] + f"_louver_{index}")
    return primary


def _add_service_door(bpy, item: dict):
    b = item["bounds"]
    sx, sy, sz = _size(b)
    frame = min(sx, sz) * 0.12
    primary = _add_box_bounds(bpy, {"xMin": b["xMin"] + frame, "xMax": b["xMax"] - frame, "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMin"] + frame, "zMax": b["zMax"] - frame}, item["objectId"] + "_leaf")
    _add_box_bounds(bpy, {"xMin": b["xMin"], "xMax": b["xMin"] + frame, "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMin"], "zMax": b["zMax"]}, item["objectId"] + "_frame_left")
    _add_box_bounds(bpy, {"xMin": b["xMax"] - frame, "xMax": b["xMax"], "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMin"], "zMax": b["zMax"]}, item["objectId"] + "_frame_right")
    _add_box_bounds(bpy, {"xMin": b["xMin"], "xMax": b["xMax"], "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMax"] - frame, "zMax": b["zMax"]}, item["objectId"] + "_frame_header")
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=frame * 0.7, location=(b["xMax"] - frame * 0.55, b["yMin"] - frame * 0.1, (b["zMin"] + b["zMax"]) / 2))
    bpy.context.object.name = item["objectId"] + "_handle"
    return primary


def _add_gutter(bpy, item: dict):
    b = item["bounds"]
    sx, sy, sz = _size(b)
    primary = _add_box_bounds(bpy, b, item["objectId"] + "_gutter")
    radius = min(sy, sz) * 0.35
    for index, x in enumerate((b["xMin"] + sx * 0.15, b["xMax"] - sx * 0.15)):
        _add_pipe_between(bpy, (x, (b["yMin"] + b["yMax"]) / 2, b["zMin"]), (x, (b["yMin"] + b["yMax"]) / 2, b["zMin"] - max(sz * 3, 0.1)), radius, item["objectId"] + f"_downspout_{index}")
    return primary


def _add_roof_edge(bpy, item: dict):
    b = item["bounds"]
    primary = _add_box_bounds(bpy, b, item["objectId"] + "_trim")
    _add_box_bounds(bpy, {"xMin": b["xMin"], "xMax": b["xMax"], "yMin": b["yMax"] - (b["yMax"] - b["yMin"]) * 0.35, "yMax": b["yMax"], "zMin": b["zMax"], "zMax": b["zMax"] + (b["zMax"] - b["zMin"]) * 0.5}, item["objectId"] + "_flashing")
    return primary


def _add_loading_marking(bpy, item: dict):
    from mathutils import Vector
    plan = loading_marking_plan(item["bounds"])
    primary = None
    for index, bar in enumerate(plan["bars"]):
        start, end = Vector(bar["start"]), Vector(bar["end"])
        delta = end - start
        bpy.ops.mesh.primitive_cube_add(size=1, location=(start + end) / 2)
        obj = bpy.context.object; obj.name = item["objectId"] + f"_bar_{index}"
        obj.dimensions = (delta.length, max(abs(item["bounds"]["yMax"] - item["bounds"]["yMin"]) * 0.18, 0.01), max(abs(item["bounds"]["zMax"] - item["bounds"]["zMin"]) * 0.12, 0.01))
        obj.rotation_euler = delta.to_track_quat("X", "Z").to_euler()
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        primary = primary or obj
    return primary


def _add_seam_band(bpy, item: dict):
    b = item["bounds"]
    sx, sy, sz = _size(b)
    primary = _add_box_bounds(bpy, {"xMin": b["xMin"], "xMax": b["xMax"], "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMin"], "zMax": b["zMin"] + sz * 0.25}, item["objectId"] + "_seam_0")
    for index, z in enumerate((b["zMin"] + sz * 0.5, b["zMin"] + sz * 0.75), 1):
        _add_box_bounds(bpy, {"xMin": b["xMin"], "xMax": b["xMax"], "yMin": b["yMin"], "yMax": b["yMax"], "zMin": z, "zMax": z + sz * 0.12}, item["objectId"] + f"_seam_{index}")
    _add_box_bounds(bpy, {"xMin": b["xMin"], "xMax": b["xMax"], "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMax"] - sz * 0.18, "zMax": b["zMax"]}, item["objectId"] + "_soot_band")
    return primary


PRIMITIVE_BUILDERS = {
    "deterministic_box": _add_box,
    "pitched_roof_wedge": _add_roof_wedge,
    "portal_frame_compound": _add_portal_frame,
    "intentional_portal_void": _add_portal_void,
    "mullion_band_compound": _add_mullion_band,
    "capped_vessel_stack": _add_capped_vessel,
    "restrained_heat_cap": _add_heat_cap,
    "rail_post_truss": _add_railing,
    "capped_pipe_run": _add_pipe_run,
    "torus_pipe_elbow": _add_pipe_elbow,
    "pipe_support_saddle": _add_pipe_support,
    "roof_plant_modules": _add_roof_plant,
    "vent_louver_array": _add_vent_array,
    "framed_service_door": _add_service_door,
    "gutter_downspouts": _add_gutter,
    "roof_edge_flashing": _add_roof_edge,
    "loading_chevron_marking": _add_loading_marking,
    "masonry_seam_wear_band": _add_seam_band,
}


def _write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")


def _aim(object_ref, target, Vector):
    object_ref.rotation_euler = (Vector(target) - object_ref.location).to_track_quat("-Z", "Y").to_euler()


def construct_blender_scene(bpy, semantic: dict, profile_bundle: dict, output_root: Path) -> None:
    """Construct named semantic objects only after authenticated profile/grant validation."""
    from mathutils import Vector

    profile = profile_bundle["sourceProductionProfile"]
    render = profile["render"]
    color = profile["colorManagement"]
    lighting = profile["lighting"]
    scene = bpy.context.scene
    if render["engine"] != "CYCLES":
        raise ValueError("profile_engine")
    scene.render.engine = render["engine"]
    scene.cycles.device = render["device"]
    scene.cycles.samples = render["samples"]
    scene.cycles.seed = render["seed"]
    scene.cycles.max_bounces = render["maxBounces"]
    scene.render.threads = render["threads"]
    scene.render.resolution_x, scene.render.resolution_y = render["resolution"]
    scene.render.resolution_percentage = render["resolutionPercentage"]
    scene.render.pixel_aspect_x, scene.render.pixel_aspect_y = render["pixelAspect"]
    scene.render.film_transparent = render["transparentFilm"]
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = color["viewTransform"]
    scene.view_settings.look = color["look"]
    scene.view_settings.exposure = color["exposure"]
    scene.view_settings.gamma = color["gamma"]

    world = bpy.data.worlds.new("east_v14_world")
    scene.world = world
    world.use_nodes = True
    world_background = world.node_tree.nodes.get("Background")
    world_background.inputs["Color"].default_value = lighting["world"]["color"]
    world_background.inputs["Strength"].default_value = lighting["world"]["strength"]

    materials = {}
    for role, material_spec in profile["materials"]["roles"].items():
        material = bpy.data.materials.new("east_v14_material_" + role)
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = material_spec["baseColor"]
        bsdf.inputs["Metallic"].default_value = material_spec["metallic"]
        bsdf.inputs["Roughness"].default_value = material_spec["roughness"]
        bsdf.inputs["Specular IOR Level"].default_value = material_spec["specularIORLevel"]
        materials[role] = material

    portal_done = False
    for item in semantic["components"]:
        primitive = item["primitive"]
        if primitive not in PRIMITIVE_BUILDERS:
            raise ValueError("unsupported_semantic_primitive:" + primitive)
        if primitive in {"portal_frame_compound", "intentional_portal_void"}:
            if not portal_done:
                before_portal = set(bpy.data.objects)
                _add_portal_assembly(bpy, semantic["portalAssembly"])
                for candidate in [item for item in bpy.data.objects if item not in before_portal]:
                    role = candidate.get("materialRole", "portal-void")
                    if hasattr(candidate.data, "materials") and role in materials:
                        candidate.data.materials.append(materials[role])
                portal_done = True
            continue
        before = set(bpy.data.objects)
        obj = PRIMITIVE_BUILDERS[primitive](bpy, item)
        created = [candidate for candidate in bpy.data.objects if candidate not in before]
        if obj not in created:
            created.insert(0, obj)
        for index, candidate in enumerate(created):
            if candidate is obj:
                candidate.name = item["objectId"]
            candidate["sourceComponentId"] = item["objectId"]
            candidate["semanticRole"] = item["semanticRole"]
            candidate["materialRole"] = item["materialRole"]
            if hasattr(candidate.data, "materials") and item["materialRole"] in materials:
                candidate.data.materials.append(materials[item["materialRole"]])

    camera_spec = semantic["camera"]
    camera_data = bpy.data.cameras.new("east_v14_camera_data")
    camera = bpy.data.objects.new("east_v14_camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = camera_spec["position"]
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = camera_spec["orthoScale"]
    camera_data.shift_x, camera_data.shift_y = camera_spec["shift"]
    _aim(camera, camera_spec["target"], Vector)
    scene.camera = camera

    registration = semantic["registration"]
    registration_data = bpy.data.objects.new("east_v14_registration", None)
    bpy.context.collection.objects.link(registration_data)
    registration_data["citySimSocket"] = list(registration["citySimSocket"])
    registration_data["sourceSocket"] = list(registration["sourceSocket"])
    registration_data["sourceGroundPivot"] = list(registration["sourceGroundPivot"])
    registration_data["orientationTransform"] = registration.get("orientationTransform", "none")
    ground = bpy.data.objects.new("east_v14_ground_pivot", None)
    ground.location = registration["groundPivot"]
    bpy.context.collection.objects.link(ground)
    ground["registrationRole"] = "groundPivot"

    key_spec = lighting["key"]
    key_data = bpy.data.lights.new("east_v14_northwest_key_data", type="AREA")
    key = bpy.data.objects.new("east_v14_northwest_key", key_data)
    bpy.context.collection.objects.link(key)
    key.location = key_spec["location"]
    key_data.energy = key_spec["energy"]
    key_data.shape = "DISK"
    key_data.size = key_spec["size"]
    _aim(key, key_spec["target"], Vector)
    contact_spec = lighting["contactShadow"]
    receiver = _add_box_bounds(bpy, contact_spec["receiverBounds"], "east_v14_southeast_shadow_receiver")
    receiver["shadowDirection"] = semantic["light"]["contactShadowDirection"]
    contact_data = bpy.data.lights.new("east_v14_southeast_contact_data", type="AREA")
    contact = bpy.data.objects.new("east_v14_southeast_contact", contact_data)
    bpy.context.collection.objects.link(contact)
    contact.location = contact_spec["location"]
    contact_data.energy = contact_spec["energy"]
    contact_data.size = contact_spec["size"]
    _aim(contact, contact_spec["target"], Vector)

    scene.render.filepath = str(output_root / "east-v14-process-a.png")
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_root / "east-v14-process-a.blend"))
    manifest = {
        "schema": "citysim.play-079.east-v14-process-a-output.v1",
        "task": "PLAY-079",
        "direction": "east",
        "componentObjectCount": len(semantic["components"]),
        "profilePath": profile_bundle["sourceProductionProfileRef"]["path"],
        "profileSha256": profile_bundle["sourceProductionProfileRef"]["sha256"],
        "appearanceLockPath": profile_bundle["appearanceLockRef"]["path"],
        "appearanceLockSha256": profile_bundle["appearanceLockRef"]["sha256"],
        "rendered": True,
    }
    _write_json(output_root / "manifest.json", manifest)
    _write_json(output_root / "provenance.json", {"manifest": manifest, "semantic": semantic})
    _write_json(output_root / "receipt.json", {"schema": "citysim.play-079.east-v14-process-a-receipt.v1", "manifestSha256": __import__("hashlib").sha256(json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()).hexdigest()})


def main() -> int:
    import os

    contract = _load(CONTRACT)
    authority_raw = os.environ.get("CITYSIM_EXECUTION_AUTHORITY_JSON")
    grant_raw = os.environ.get("CITYSIM_GRANT_JSON")
    profile_raw = os.environ.get("CITYSIM_PROFILE_JSON")
    if not authority_raw or not grant_raw or not profile_raw:
        raise RuntimeError("forwarded_binding_missing")
    authority = json.loads(authority_raw)
    grant = json.loads(grant_raw)
    profile_bundle = json.loads(profile_raw)
    if authority.get("schemaVersion") != 1 or authority.get("mode") != "validation_only":
        raise RuntimeError("authority_schema")
    if authority.get("task", {}).get("direction") != "east" or authority.get("task", {}).get("taskId") != "PLAY-079":
        raise RuntimeError("authority_identity")
    if authority.get("task", {}).get("claimSha256") != contract["authority"]["claim"]["sha256"]:
        raise RuntimeError("authority_claim")
    if authority.get("task", {}).get("publishedBaseCommit") != contract["authority"]["baseCommit"]:
        raise RuntimeError("authority_base")
    authority_binding = contract.get("executionAuthority")
    if authority_binding is None:
        raise RuntimeError("execution_authority_missing")
    if authority_binding is not None:
        authority_path = REPO / authority_binding["path"]
        if not authority_path.is_file() or authority_path.is_symlink():
            raise RuntimeError("authority_path")
        import hashlib
        if hashlib.sha256(authority_path.read_bytes()).hexdigest() != authority_binding.get("sha256") or _load(authority_path) != authority:
            raise RuntimeError("authority_hash_mismatch")
    if grant.get("processId") != contract["execution"]["processId"] or grant.get("direction") != "east" or grant.get("slotId") != "east-process-a-slot-1":
        raise RuntimeError("grant_binding")
    if grant.get("maximumChildStarts", 1) != 1 or grant.get("exactlyOneInvocation") is False:
        raise RuntimeError("grant_child_limit")
    if os.environ.get("CITYSIM_PROCESS_ID") != grant.get("processId"):
        raise RuntimeError("process_id_mismatch")
    if authority.get("exclusiveRoots", {}).get("outputRoot") != contract["execution"]["outputRoot"]:
        raise RuntimeError("output_root_mismatch")
    if profile_bundle.get("sourceProductionProfileRef", {}).get("sha256") != contract.get("sourceProductionProfile", {}).get("sha256"):
        raise RuntimeError("profile_hash_mismatch")
    if profile_bundle.get("appearanceLockRef", {}).get("sha256") != contract.get("appearanceLock", {}).get("sha256"):
        raise RuntimeError("appearance_hash_mismatch")
    profile = profile_bundle.get("sourceProductionProfile", {})
    appearance = profile_bundle.get("appearanceLock", {})
    if profile.get("schema") != "citysim.play-027.north-v14-source-production-profile.v1" or profile.get("task") != "PLAY-027" or profile.get("direction") != "north" or appearance.get("schema") != "citysim.play-027.north-v14-appearance-lock.v1" or appearance.get("task") != "PLAY-027" or appearance.get("direction") != "north":
        raise RuntimeError("north_profile_required")
    if authority.get("closureContract", {}).get("path") != "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-DIRECTION-EXECUTION-CLOSURE-V1.json":
        raise RuntimeError("closure_contract_binding")
    if contract.get("authority", {}).get("liveIdentityAuthority", {}).get("path") != "docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-EAST-LIVE-IDENTITY-RETURN-REPAIR-V1.json":
        raise RuntimeError("return_repair_authority_binding")
    documents = authority.get("documents", {})
    if set(documents) != {"schedule", "grant", "integrationSession", "sourceProductionProfile"}:
        raise RuntimeError("execution_documents_missing")
    if authority.get("toolchain", {}).get("factoryStartup") is not True or authority.get("toolchain", {}).get("disabledAutoexec") is not True:
        raise RuntimeError("toolchain_binding")
    import bpy  # imported only in the launched Blender child

    output = Path(os.environ["CITYSIM_OUTPUT_ROOT"])
    if not output.is_dir() or output.is_symlink() or str(output.stat().st_ino) != os.environ.get("CITYSIM_OUTPUT_ROOT_INODE"):
        raise RuntimeError("output_inode_mismatch")
    construct_blender_scene(bpy, build_semantic_geometry(), profile_bundle, output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

def validate_portal_assembly(plan: dict | None) -> bool:
    roles = {piece.get("materialRole") for piece in (plan or {}).get("pieces", [])}
    return bool(plan and plan.get("reachableFromLowering") and plan.get("assemblyId") == "east_v14_freight_portal_assembly" and validate_portal_plan(plan) and set(plan.get("revealSurfaces", [])) == {"reveal", "inset"} and plan.get("backPlaneMaterial") == "portal-void" and {"dark-painted-steel", "formed-concrete", "portal-void"}.issubset(roles))
