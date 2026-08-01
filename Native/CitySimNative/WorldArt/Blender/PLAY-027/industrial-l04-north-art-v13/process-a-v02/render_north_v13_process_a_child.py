"""Blender child for the Integration-owned North v13 Process-A launch.

The child is intentionally inert unless the high-level runner supplies the
Integration-direct flag and environment. Worker tests import this module and
exercise only the fail-closed direct-invocation boundary; they never import
``bpy`` or call the render path.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys


BLENDER_DIRECT_FLAG = "--integration-direct"
SOURCE_ROOT = "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13"
PROCESS_ROOT = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a"


def canonical(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if type(value) is not dict:
        raise RuntimeError(f"JSON object required: {path}")
    return value


def args(values: list[str] | None = None) -> argparse.Namespace:
    if values is None:
        if "--" not in sys.argv:
            raise RuntimeError("direct child invocation forbidden; Integration flag missing")
        values = sys.argv[sys.argv.index("--") + 1 :]
    parser = argparse.ArgumentParser()
    parser.add_argument(BLENDER_DIRECT_FLAG, action="store_true")
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--schedule-path", required=True)
    parser.add_argument("--process-receipt-path", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--evidence-root", required=True)
    parsed = parser.parse_args(values)
    if not parsed.integration_direct or os.environ.get("CITYSIM_INTEGRATION_DIRECT") != "1":
        raise RuntimeError("direct child invocation forbidden; Integration direct boundary missing")
    return parsed


def citysim_to_blender(point: list[float]) -> tuple[float, float, float]:
    return float(point[2]), float(point[0]), float(point[1])


def material_map(materials: dict) -> dict[str, dict]:
    return {item["role"]: item for item in materials["materials"]}


def component_boxes(component: dict) -> list[tuple[str, str, list[list[float]]]]:
    role = component["materialRole"]
    result: list[tuple[str, str, list[list[float]]]] = []
    if "boundsXYZ" in component:
        result.append((component["id"], role, component["boundsXYZ"]))
    for key in ("solidRegions", "members", "recesses", "parts"):
        for index, child in enumerate(component.get(key, [])):
            if isinstance(child, dict) and "boundsXYZ" in child:
                result.append((f"{component['id']}:{child.get('id', index)}", child.get("materialRole", role), child["boundsXYZ"]))
    return result


def configure_materials(bpy, materials: dict) -> dict[str, object]:
    created: dict[str, object] = {}
    for item in materials["materials"]:
        material = bpy.data.materials.new(item["id"])
        material.use_nodes = True
        node = material.node_tree.nodes.get("Principled BSDF")
        color = tuple(float(value) for value in item["baseColorRGBA"])
        if node is not None:
            node.inputs["Base Color"].default_value = color
            node.inputs["Roughness"].default_value = float(item["roughness"])
            node.inputs["Metallic"].default_value = float(item["metalness"])
            if "emissionStrength" in item:
                node.inputs["Emission Color"].default_value = color
                node.inputs["Emission Strength"].default_value = float(item["emissionStrength"])
        created[item["role"]] = material
    return created


def build_geometry(bpy, scene: dict, material_by_role: dict[str, object]) -> list[dict]:
    manifest: list[dict] = []
    for component in scene["components"]:
        for identifier, role, bounds in component_boxes(component):
            minimum, maximum = bounds
            center = [(float(minimum[i]) + float(maximum[i])) / 2.0 for i in range(3)]
            size = [float(maximum[i]) - float(minimum[i]) for i in range(3)]
            bpy.ops.mesh.primitive_cube_add(location=citysim_to_blender(center))
            obj = bpy.context.object
            obj.name = identifier
            obj.dimensions = (size[2], size[0], size[1])
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            obj.data.materials.append(material_by_role[role])
            manifest.append({"id": identifier, "materialRole": role, "boundsXYZ": bounds, "shape": "box"})
        if component.get("primitive") == "octagonal-vessel":
            center = citysim_to_blender(component["centerXYZ"])
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=float(component["radius"]), depth=float(component["height"]), location=center)
            obj = bpy.context.object
            obj.name = component["id"]
            obj.data.materials.append(material_by_role[component["materialRole"]])
            manifest.append({"id": component["id"], "materialRole": component["materialRole"], "shape": "octagonal-vessel"})
    return manifest


def configure_camera(bpy, scene: dict) -> None:
    camera_data = bpy.data.cameras.new("NorthV13Camera")
    camera = bpy.data.objects.new("NorthV13Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    width, height = scene["camera"]["renderViewportPixels"]
    camera_data.ortho_scale = 2.0 * float(scene["camera"]["orthographicScale"]) * float(width) / float(height)
    camera_data.shift_x = 0.0
    camera_data.shift_y = float(scene["camera"]["postProjectionOffsetPixels"][1]) / float(width)
    camera.location = citysim_to_blender(scene["camera"]["positionWorld"])
    target = citysim_to_blender(scene["camera"]["targetWorld"])
    direction = __import__("mathutils").Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera


def write_exclusive(path: Path, value: object) -> None:
    with path.open("xb") as stream:
        stream.write(canonical(value))


def render_process(parsed: argparse.Namespace) -> int:
    import bpy  # Imported only inside Blender's Integration-owned child.

    root = Path(parsed.repository_root)
    contract_path = root / parsed.contract
    contract = load(contract_path)
    scene_path = root / SOURCE_ROOT / "DESIGN-SCENE.json"
    materials_path = root / SOURCE_ROOT / "DESIGN-MATERIALS.json"
    lowering_path = root / SOURCE_ROOT / "lowering-v01" / "LOWERING-CONTRACT.json"
    for path in (scene_path, materials_path, lowering_path):
        if path.is_symlink() or not path.is_file():
            raise RuntimeError("frozen input path invalid")
    scene = load(scene_path)
    materials = load(materials_path)
    lowering = load(lowering_path)
    if contract["identity"]["viewDirection"] != "north" or contract["identity"]["processID"] != "A":
        raise RuntimeError("North/A identity mismatch")
    output = Path(parsed.output_root)
    if output != (root / PROCESS_ROOT).resolve():
        raise RuntimeError("output root mismatch")
    if not output.is_dir() or output.is_symlink():
        raise RuntimeError("exclusive output root is not a directory")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    render_scene = bpy.context.scene
    render_scene.render.engine = "CYCLES"
    render_scene.cycles.device = "CPU"
    render_scene.cycles.samples = 64
    render_scene.cycles.use_denoising = False
    render_scene.render.film_transparent = True
    render_scene.render.resolution_x = 1536
    render_scene.render.resolution_y = 1024
    render_scene.render.resolution_percentage = 100
    material_by_role = configure_materials(bpy, materials)
    manifest = build_geometry(bpy, scene, material_by_role)
    configure_camera(bpy, scene)
    render_scene.render.filepath = str(output / "raw.png")
    bpy.ops.render.render(write_still=True)
    if not (output / "raw.png").is_file():
        raise RuntimeError("Blender did not emit raw.png")
    write_exclusive(output / "OBJECT-MANIFEST.json", {"schema": 1, "objects": manifest})
    write_exclusive(output / "INPUT-BINDINGS.json", {"scene": sha256(scene_path), "materials": sha256(materials_path), "lowering": sha256(lowering_path), "contract": sha256(contract_path)})
    write_exclusive(output / "provenance.json", {"schema": 1, "task": "PLAY-027", "direction": "north", "process": "A", "sceneGeometryID": contract["identity"]["sceneGeometryID"], "sourceAuthority": False, "productionSelected": False, "cycles": {"device": "CPU", "samples": 64, "denoising": False}, "rawSHA256": sha256(output / "raw.png")})
    return 0


def main(values: list[str] | None = None) -> int:
    parsed = args(values)
    return render_process(parsed)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(78)
