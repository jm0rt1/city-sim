#!/usr/bin/env python3
"""Deterministic East Process-A Blender child; imported only after launch authority."""

from __future__ import annotations

import json
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
    return _descriptor(component, object_id, "portal_frame_compound", parts=["primary", "reveal", "header_or_jamb"])


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
    return _descriptor(component, object_id, "mullion_band_compound", parts=["frame", "mullion_0", "mullion_1", "mullion_2", "louver_slats"])


def build_capped_vessel(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "capped_vessel_stack", parts=["cylinder", "top_cap", "base_ring"])


def build_heat_cap(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "restrained_heat_cap", parts=["vessel", "cap", "process_nozzle"])


def build_railing(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "rail_post_truss", parts=["posts", "top_rail", "mid_rail", "truss_diagonals"])


def build_pipe_run(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "capped_pipe_run", parts=["cylinder", "end_cap_a", "end_cap_b"])


def build_pipe_elbow(component: dict, object_id: str) -> dict:
    return _descriptor(component, object_id, "torus_pipe_elbow", parts=["quarter_turn", "end_cap_a", "end_cap_b"])


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
    return _descriptor(component, object_id, "loading_chevron_marking", parts=["chevron_a", "chevron_b", "chevron_c"])


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
    return {
        "components": lowered,
        "camera": design["camera"],
        "registration": design["eastRegistration"],
        "light": design["light"],
        "materialRoles": sorted(set(item["materialRole"] for item in lowered)),
    }


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
    b = item["bounds"]
    size = _size(b)
    bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=10, major_radius=min(size[0], size[1]) / 2, minor_radius=min(size) / 3, location=_center(b))
    obj = bpy.context.object
    obj.name = item["objectId"]
    return obj


def _add_portal_frame(bpy, item: dict):
    b = item["bounds"]
    primary = _add_box_bounds(bpy, b, item["objectId"])
    depth = max((b["yMax"] - b["yMin"]) * 0.18, 0.01)
    reveal = dict(b)
    reveal["yMin"] = b["yMax"] - depth
    reveal["yMax"] = b["yMax"]
    reveal["zMin"] = b["zMin"] + (b["zMax"] - b["zMin"]) * 0.15
    reveal["zMax"] = b["zMax"] - (b["zMax"] - b["zMin"]) * 0.15
    _add_box_bounds(bpy, reveal, item["objectId"] + "_reveal")
    return primary


def _add_portal_void(bpy, item: dict):
    obj = bpy.data.objects.new(item["objectId"], None)
    bpy.context.collection.objects.link(obj)
    obj["intentionalVoid"] = True
    obj["apertureBounds"] = [item["bounds"][key] for key in ("xMin", "xMax", "yMin", "yMax", "zMin", "zMax")]
    return obj


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
    b = item["bounds"]
    sx, sy, sz = _size(b)
    bar = max(sy, sz) * 0.35
    primary = _add_box_bounds(bpy, {"xMin": b["xMin"], "xMax": b["xMin"] + sx * 0.2, "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMin"], "zMax": b["zMin"] + sz}, item["objectId"] + "_chevron_a")
    for index, start in enumerate((b["xMin"] + sx * 0.4, b["xMin"] + sx * 0.7), 1):
        _add_box_bounds(bpy, {"xMin": start, "xMax": start + sx * 0.2, "yMin": b["yMin"], "yMax": b["yMax"], "zMin": b["zMin"], "zMax": b["zMin"] + sz}, item["objectId"] + f"_chevron_{index}")
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

    for item in semantic["components"]:
        primitive = item["primitive"]
        if primitive not in PRIMITIVE_BUILDERS:
            raise ValueError("unsupported_semantic_primitive:" + primitive)
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
    if os.environ.get("CITYSIM_PROCESS_A_AUTH") != contract["authority"]["routeSha256"]:
        raise RuntimeError("direct_child_bypass")
    if not os.environ.get("CITYSIM_PROFILE_JSON"):
        raise RuntimeError("profile_not_forwarded")
    import bpy  # imported only in the launched Blender child

    output = Path(os.environ["CITYSIM_OUTPUT_ROOT"])
    profile_bundle = json.loads(os.environ["CITYSIM_PROFILE_JSON"])
    output.mkdir(parents=True, exist_ok=False)
    construct_blender_scene(bpy, build_semantic_geometry(), profile_bundle, output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
