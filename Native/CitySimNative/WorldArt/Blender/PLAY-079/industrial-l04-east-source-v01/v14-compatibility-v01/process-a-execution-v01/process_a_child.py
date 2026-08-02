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


def build_box(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "deterministic_box", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_roof_wedge(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "pitched_roof_wedge", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_mullioned_glazing(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "mullion_band", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_capped_vessel(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "cylinder_with_caps", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_heat_cap(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "restrained_heat_cap", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_railing(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "rail_and_support_run", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_pipe_run(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "capped_pipe_run", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_pipe_elbow(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "quarter_turn_elbow", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_pipe_support(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "pipe_support_bracket", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_roof_plant(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "roof_plant_cluster", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_vent_array(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "vent_louver_array", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_service_door(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "service_door_with_frame", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_gutter(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "gutter_run", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_roof_edge(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "roof_edge_trim", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_loading_marking(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "loading_safety_marking", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


def build_seam_band(component: dict, object_id: str) -> dict:
    return {"objectId": object_id, "primitive": "masonry_seam_wear_band", "bounds": component["bounds"], "semanticRole": component["semanticRole"], "materialRole": component["materialRole"]}


BUILDERS = {
    "box": build_box, "roof_wedge": build_roof_wedge, "mullioned_glazing": build_mullioned_glazing,
    "capped_vessel": build_capped_vessel, "heat_cap": build_heat_cap, "railing": build_railing,
    "pipe_run": build_pipe_run, "pipe_elbow": build_pipe_elbow, "pipe_support": build_pipe_support,
    "roof_plant": build_roof_plant, "vent_array": build_vent_array, "service_door": build_service_door,
    "gutter": build_gutter, "roof_edge": build_roof_edge, "loading_marking": build_loading_marking,
    "seam_band": build_seam_band,
}


def build_semantic_geometry() -> dict:
    design = _load(DESIGN)
    lowering = _load(LOWERING)
    components = {item["id"]: item for item in design["components"]}
    lowered = []
    for record in lowering["components"]:
        component = components[record["componentId"]]
        builder = BUILDERS[record["builder"]]
        lowered.append(builder(component, record["objectIDs"][0]))
    return {"components": lowered, "camera": design["camera"], "registration": design["eastRegistration"], "light": design["light"], "materialRoles": sorted(set(item["materialRole"] for item in lowered))}


def _center(bounds: dict) -> tuple[float, float, float]:
    return ((bounds["xMin"] + bounds["xMax"]) / 2, (bounds["yMin"] + bounds["yMax"]) / 2, (bounds["zMin"] + bounds["zMax"]) / 2)


def _size(bounds: dict) -> tuple[float, float, float]:
    return (bounds["xMax"] - bounds["xMin"], bounds["yMax"] - bounds["yMin"], bounds["zMax"] - bounds["zMin"])


def _add_box(bpy, item: dict):
    bpy.ops.mesh.primitive_cube_add(size=1, location=_center(item["bounds"]))
    obj = bpy.context.object
    obj.dimensions = _size(item["bounds"])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def _add_roof_wedge(bpy, item: dict):
    b = item["bounds"]
    x0, x1, y0, y1, z0, z1 = b["xMin"], b["xMax"], b["yMin"], b["yMax"], b["zMin"], b["zMax"]
    mesh = bpy.data.meshes.new(item["objectId"] + "_wedge_mesh")
    mesh.from_pydata([(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1-0.6),(x0,y1,z1-0.6)], [], [(0,1,2,3),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0),(4,7,6,5)])
    obj = bpy.data.objects.new(item["objectId"], mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _add_capped_vessel(bpy, item: dict):
    b = item["bounds"]
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=max(b["xMax"]-b["xMin"], b["yMax"]-b["yMin"]) / 2, depth=b["zMax"]-b["zMin"], location=_center(b))
    return bpy.context.object


def _add_pipe_run(bpy, item: dict):
    b = item["bounds"]
    size = _size(b)
    axis = max(range(3), key=lambda index: size[index])
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=min(size) / 2, depth=max(size), location=_center(b))
    obj = bpy.context.object
    if axis == 0: obj.rotation_euler[1] = 1.57079632679
    if axis == 1: obj.rotation_euler[0] = 1.57079632679
    return obj


def _add_pipe_elbow(bpy, item: dict):
    b = item["bounds"]
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8, major_radius=max(b["xMax"]-b["xMin"], b["yMax"]-b["yMin"]) / 2, minor_radius=min(_size(b)) / 4, location=_center(b))
    return bpy.context.object


def _add_mullion_band(bpy, item: dict):
    obj = _add_box(bpy, item)
    obj["mullions"] = 3
    obj["louvered"] = True
    return obj


def _add_heat_cap(bpy, item: dict):
    obj = _add_capped_vessel(bpy, item)
    obj["emissiveRole"] = "restrained-amber-orange"
    obj["emissiveAreaLimit"] = 0.04
    return obj


def _add_railing(bpy, item: dict):
    obj = _add_box(bpy, item)
    obj["railCount"] = 3
    obj["supportSpacing"] = 2.0
    return obj


def _add_pipe_support(bpy, item: dict):
    obj = _add_box(bpy, item)
    obj["bracket"] = "saddle-support"
    return obj


def _add_roof_plant(bpy, item: dict):
    obj = _add_box(bpy, item)
    obj["plantModules"] = ["housing", "vent", "service-cap"]
    return obj


def _add_vent_array(bpy, item: dict):
    obj = _add_box(bpy, item)
    obj["ventCount"] = 4
    return obj


def _add_service_door(bpy, item: dict):
    obj = _add_box(bpy, item)
    obj["frame"] = True
    obj["handle"] = "service-pull"
    return obj


def _add_gutter(bpy, item: dict):
    obj = _add_box(bpy, item)
    obj["downspouts"] = 2
    return obj


def _add_roof_edge(bpy, item: dict):
    obj = _add_box(bpy, item)
    obj["flashing"] = True
    return obj


def _add_loading_marking(bpy, item: dict):
    obj = _add_box(bpy, item)
    obj["marking"] = "safety-chevron"
    return obj


def _add_seam_band(bpy, item: dict):
    obj = _add_box(bpy, item)
    obj["wearBand"] = "masonry-seam-and-soot"
    return obj


PRIMITIVE_BUILDERS = {
    "deterministic_box": _add_box,
    "pitched_roof_wedge": _add_roof_wedge,
    "mullion_band": _add_mullion_band,
    "cylinder_with_caps": _add_capped_vessel,
    "restrained_heat_cap": _add_heat_cap,
    "rail_and_support_run": _add_railing,
    "capped_pipe_run": _add_pipe_run,
    "quarter_turn_elbow": _add_pipe_elbow,
    "pipe_support_bracket": _add_pipe_support,
    "roof_plant_cluster": _add_roof_plant,
    "vent_louver_array": _add_vent_array,
    "service_door_with_frame": _add_service_door,
    "gutter_run": _add_gutter,
    "roof_edge_trim": _add_roof_edge,
    "loading_safety_marking": _add_loading_marking,
    "masonry_seam_wear_band": _add_seam_band,
}


def construct_blender_scene(bpy, semantic: dict, output_root: Path) -> None:
    """Construct named semantic objects only after the authenticated child starts."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 64
    scene.cycles.seed = 17
    scene.cycles.max_bounces = 4
    scene.render.threads = 1
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    role_colors = {
        "warm-weathered-masonry": (0.34, 0.20, 0.12, 1.0),
        "formed-concrete": (0.42, 0.44, 0.40, 1.0),
        "dark-painted-steel": (0.06, 0.08, 0.09, 1.0),
        "roof-edge-metal": (0.12, 0.25, 0.24, 1.0),
        "glazing-louver": (0.08, 0.20, 0.22, 1.0),
        "portal-void": (0.015, 0.012, 0.01, 1.0),
        "safety-oxide": (0.48, 0.16, 0.06, 1.0),
        "hot-process": (0.62, 0.22, 0.03, 1.0),
        "contact-shadow": (0.01, 0.01, 0.01, 1.0),
    }
    materials = {}
    for role in semantic["materialRoles"]:
        material = bpy.data.materials.new("east_v14_material_" + role)
        material.diffuse_color = role_colors[role]
        materials[role] = material
    for item in semantic["components"]:
        primitive = item["primitive"]
        if primitive not in PRIMITIVE_BUILDERS:
            raise ValueError("unsupported_semantic_primitive:" + primitive)
        obj = PRIMITIVE_BUILDERS[primitive](bpy, item)
        obj.name = item["objectId"]
        obj["semanticRole"] = item["semanticRole"]
        obj["materialRole"] = item["materialRole"]
        if hasattr(obj.data, "materials"):
            obj.data.materials.append(materials[item["materialRole"]])
    camera_data = bpy.data.cameras.new("east_v14_camera")
    camera = bpy.data.objects.new("east_v14_camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = semantic["camera"]["position"]
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = semantic["camera"]["orthoScale"]
    try:
        from mathutils import Vector
        camera.rotation_euler = (Vector(semantic["camera"]["target"]) - camera.location).to_track_quat("-Z", "Y").to_euler()
    except ImportError:
        raise RuntimeError("blender_mathutils_required")
    bpy.context.scene.camera = camera
    registration = semantic["registration"]
    registration_data = bpy.data.objects.new("east_v14_registration", None)
    bpy.context.collection.objects.link(registration_data)
    registration_data["citySimSocket"] = list(registration["citySimSocket"])
    registration_data["sourceSocket"] = list(registration["sourceSocket"])
    registration_data["sourceGroundPivot"] = list(registration["sourceGroundPivot"])
    registration_data["orientationTransform"] = registration.get("orientationTransform", "none")
    ground = bpy.data.objects.new("east_v14_ground_pivot", None)
    ground.location = registration.get("groundPivot", [28.0, 28.0, 0.0])
    bpy.context.collection.objects.link(ground)
    ground["registrationRole"] = "groundPivot"
    key_data = bpy.data.lights.new("east_v14_northwest_key", type="AREA")
    key = bpy.data.objects.new("east_v14_northwest_key", key_data)
    bpy.context.collection.objects.link(key)
    key.rotation_euler = (0.6, -0.4, -0.7)
    key_data.energy = 1200
    key_data.size = 8
    bpy.ops.wm.save_as_mainfile(filepath=str(output_root / "east-v14-process-a.blend"))


def main() -> int:
    import bpy  # imported only in the launched Blender child
    output = Path(__import__("os").environ["CITYSIM_OUTPUT_ROOT"])
    output.mkdir(parents=True, exist_ok=False)
    construct_blender_scene(bpy, build_semantic_geometry(), output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
