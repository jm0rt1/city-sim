#!/usr/bin/env python3
"""Exact PLAY-027 Industrial L4 v18 North transfer into Blender/Cycles.

The committed descriptor and material JSON remain the art authority. This file
is deliberately direction- and revision-bound; it is not a general DCC
framework and may not accept siblings or alternate revisions.
"""

import argparse
import hashlib
import json
import math
import os
import platform
import sys
from pathlib import Path

import bpy
from mathutils import Vector


EXPECTED_DESCRIPTOR_SHA = (
    "3696b813e6c3e0f46251e689582163bdbdcc5d84a3a9c1125bfbefba37da2630"
)
EXPECTED_MATERIAL_SHA = (
    "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"
)
EXPECTED_REVISION = "source-v18-prepixel"
EXPECTED_GEOMETRY = "industrial-l04-crucible-gantry-v18-north-single-foundation"
EXPECTED_COMPONENT_COUNT = 51
EXPECTED_MATERIAL_COUNT = 13


def fail(message):
    raise RuntimeError(message)


def sha256_bytes(value):
    return hashlib.sha256(value).hexdigest()


def file_sha256(path):
    return sha256_bytes(path.read_bytes())


def canonical_bytes(value):
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def write_json(path, value):
    path.write_bytes(canonical_bytes(value))


def parse_arguments():
    argv = sys.argv
    if "--" not in argv:
        fail("script arguments must follow Blender's -- separator")
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--process-id", required=True, choices=["A", "B", "C"])
    return parser.parse_args(argv[argv.index("--") + 1 :])


def resolve_inside(root, relative):
    candidate = (root / relative).resolve()
    try:
        candidate.relative_to(root)
    except ValueError:
        fail(f"path escapes repository root: {relative}")
    return candidate


def clean_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def blender_point(world):
    # CitySim: x horizontal, y up, z depth. Blender: x horizontal, y depth,
    # z up. No rotation or sibling transform is introduced.
    return (float(world[0]), float(world[2]), float(world[1]))


def blender_dimensions(dimensions):
    return (
        float(dimensions[0]),
        float(dimensions[2]),
        float(dimensions[1]),
    )


def make_principled_material(record):
    material = bpy.data.materials.new(record["id"])
    material.use_nodes = True
    material.diffuse_color = tuple(float(v) for v in record["baseColorRGBA"])
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    rgba = tuple(float(v) for v in record["baseColorRGBA"])
    shader.inputs["Base Color"].default_value = rgba
    shader.inputs["Metallic"].default_value = float(record["metalness"])
    shader.inputs["Roughness"].default_value = float(record["roughness"])
    shader.inputs["Alpha"].default_value = rgba[3]
    if record["id"] == "v14-process-heat":
        shader.inputs["Emission Color"].default_value = rgba
        shader.inputs["Emission Strength"].default_value = 0.75
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def make_shadow_material():
    material = bpy.data.materials.new("authored-southeast-contact-shadow")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    diffuse.inputs["Color"].default_value = (0.025, 0.03, 0.028, 1.0)
    diffuse.inputs["Roughness"].default_value = 1.0
    mix = nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = 0.18
    material.node_tree.links.new(transparent.outputs[0], mix.inputs[1])
    material.node_tree.links.new(diffuse.outputs[0], mix.inputs[2])
    material.node_tree.links.new(mix.outputs[0], output.inputs["Surface"])
    return material


def add_box(name, dimensions, position, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=blender_point(position))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = blender_dimensions(dimensions)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def add_cylinder(name, dimensions, position, material):
    diameter = min(float(dimensions[0]), float(dimensions[2]))
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32,
        radius=diameter / 2.0,
        depth=float(dimensions[1]),
        end_fill_type="NGON",
        location=blender_point(position),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def object_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = [min(point[index] for point in points) for index in range(3)]
    maximum = [max(point[index] for point in points) for index in range(3)]
    return {
        "minimumBlenderXYZ": minimum,
        "maximumBlenderXYZ": maximum,
        "minimumCitySimXYZ": [minimum[0], minimum[2], minimum[1]],
        "maximumCitySimXYZ": [maximum[0], maximum[2], maximum[1]],
    }


def add_authored_contact_shadow(descriptor, material):
    polygon = descriptor["registration"]["contactPolygonWorld"]
    # SceneKit's source shadow offset [56, 28] is exactly +15.75 CitySim
    # world units on x under the frozen 72x36 projection.
    shadow_offset_world_x = 15.75
    vertices = [
        (float(point[0]) + shadow_offset_world_x, float(point[1]), 0.02)
        for point in polygon
    ]
    mesh = bpy.data.meshes.new("authored-southeast-contact-shadow-mesh")
    mesh.from_pydata(vertices, [], [[0, 1, 2, 3]])
    mesh.update()
    obj = bpy.data.objects.new("authored-southeast-contact-shadow", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_camera(descriptor):
    camera_record = descriptor["camera"]
    data = bpy.data.cameras.new("contract-camera")
    data.type = "ORTHO"
    # SceneKit orthographicScale is a half-height. Blender ortho_scale is the
    # complete vertical span.
    data.ortho_scale = float(camera_record["orthographicScale"]) * 2.0
    data.lens = 50.0
    data.clip_start = 0.1
    data.clip_end = 1000.0
    data.shift_x = float(camera_record["postProjectionOffsetPixels"][0]) / float(
        camera_record["renderViewportPixels"][0]
    )
    data.shift_y = float(camera_record["postProjectionOffsetPixels"][1]) / float(
        camera_record["renderViewportPixels"][1]
    )
    obj = bpy.data.objects.new("contract-camera", data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = blender_point(camera_record["positionWorld"])
    look_at(obj, blender_point(camera_record["targetWorld"]))
    bpy.context.scene.camera = obj
    return obj


def configure_light(descriptor, settings):
    data = bpy.data.lights.new("northwest-key", type="SUN")
    data.energy = float(settings["northwestSunEnergy"])
    data.angle = float(settings["northwestSunAngleRadians"])
    obj = bpy.data.objects.new("northwest-key", data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = blender_point(descriptor["light"]["keyOrigin"])
    look_at(obj, blender_point([0.0, 0.0, 0.0]))
    return obj


def configure_cycles(scene, settings, output_path):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.threads_mode = "FIXED"
    scene.render.threads = int(settings["threads"])
    scene.cycles.seed = int(settings["seed"])
    scene.cycles.samples = int(settings["samples"])
    scene.cycles.use_adaptive_sampling = False
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = int(settings["maxBounces"])
    scene.cycles.diffuse_bounces = 2
    scene.cycles.glossy_bounces = 2
    scene.cycles.transmission_bounces = 0
    scene.render.use_motion_blur = False
    scene.render.film_transparent = True
    scene.render.resolution_x = int(settings["resolution"][0])
    scene.render.resolution_y = int(settings["resolution"][1])
    scene.render.resolution_percentage = int(settings["resolutionPercentage"])
    scene.render.pixel_aspect_x = float(settings["pixelAspect"][0])
    scene.render.pixel_aspect_y = float(settings["pixelAspect"][1])
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.filepath = str(output_path)
    color = settings["colorManagement"]
    scene.display_settings.display_device = color["displayDevice"]
    scene.view_settings.view_transform = color["viewTransform"]
    scene.view_settings.look = color["look"]
    scene.view_settings.exposure = float(color["exposure"])
    scene.view_settings.gamma = float(color["gamma"])
    scene.view_settings.use_curve_mapping = False
    world = bpy.data.worlds.new("contract-world")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.34, 0.39, 0.42, 1.0)
    background.inputs["Strength"].default_value = float(settings["worldStrength"])
    scene.world = world


def stable_semantic_rgba(index):
    levels = [32, 72, 112, 152, 192, 232]
    return (
        levels[index % 6],
        levels[(index // 6) % 6],
        levels[(index // 36) % 6],
        255,
    )


def make_emission_material(name, rgba):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = tuple(value / 255.0 for value in rgba)
    emission.inputs["Strength"].default_value = 1.0
    material.node_tree.links.new(emission.outputs[0], output.inputs["Surface"])
    return material


def build_scene(descriptor, material_records):
    materials = {
        record["id"]: make_principled_material(record)
        for record in material_records
    }
    if len(materials) != EXPECTED_MATERIAL_COUNT:
        fail(f"material count drift: {len(materials)}")
    components = []
    foundation_dimensions = descriptor["building"]["foundationDimensions"]
    foundation_position = descriptor["building"]["foundationPositionWorld"]
    foundation_material = descriptor["building"]["foundationMaterialID"]
    foundation = add_box(
        "foundation",
        foundation_dimensions,
        foundation_position,
        materials[foundation_material],
    )
    components.append(
        {
            "nodeName": "foundation",
            "sourceKind": "foundation",
            "sourceIndex": 0,
            "dimensionsCitySimXYZ": foundation_dimensions,
            "positionCitySimXYZ": foundation_position,
            "materialID": foundation_material,
            "primitive": "box",
            "bounds": object_bounds(foundation),
        }
    )
    for index, block in enumerate(descriptor["building"]["massBlocks"]):
        if block["materialID"] not in materials:
            fail(f"missing material for mass block {block['id']}")
        obj = add_box(
            block["id"],
            block["dimensions"],
            block["positionWorld"],
            materials[block["materialID"]],
        )
        components.append(
            {
                "nodeName": block["id"],
                "sourceKind": "massBlock",
                "sourceIndex": index,
                "dimensionsCitySimXYZ": block["dimensions"],
                "positionCitySimXYZ": block["positionWorld"],
                "materialID": block["materialID"],
                "primitive": "box",
                "bounds": object_bounds(obj),
            }
        )
    for index, prop in enumerate(descriptor["props"]):
        if prop["kind"] != "explicit-cylinder":
            fail(f"unsupported exact-v18 prop kind: {prop['kind']}")
        if prop["materialID"] not in materials:
            fail(f"missing material for prop {prop['id']}")
        obj = add_cylinder(
            prop["id"],
            prop["dimensions"],
            prop["positionWorld"],
            materials[prop["materialID"]],
        )
        components.append(
            {
                "nodeName": prop["id"],
                "sourceKind": "prop",
                "sourceIndex": index,
                "dimensionsCitySimXYZ": prop["dimensions"],
                "positionCitySimXYZ": prop["positionWorld"],
                "materialID": prop["materialID"],
                "primitive": "cylinder-32",
                "bounds": object_bounds(obj),
            }
        )
    if len(components) != EXPECTED_COMPONENT_COUNT:
        fail(f"rendered component count drift: {len(components)}")
    if descriptor["building"]["usesExplicitComponentGeometry"] is not True:
        fail("exact v18 must use explicit component geometry")
    if descriptor["building"]["roofVolumes"]:
        fail("unexpected roof volumes in exact v18")
    if descriptor["building"]["trimBands"]:
        fail("unexpected trim bands in exact v18")
    return components, materials


def render_semantic(scene, components, shadow, output_path):
    semantic = []
    for index, component in enumerate(components):
        rgba = stable_semantic_rgba(index)
        obj = bpy.data.objects[component["nodeName"]]
        obj.data.materials.clear()
        obj.data.materials.append(
            make_emission_material(f"semantic-{index:02d}", rgba)
        )
        semantic.append(
            {
                "nodeName": component["nodeName"],
                "rgba8": list(rgba),
                "index": index,
            }
        )
    shadow.hide_render = True
    scene.render.filepath = str(output_path)
    bpy.ops.render.render(write_still=True)
    return semantic


def validate_binding(config, descriptor, materials, descriptor_sha, material_sha):
    if descriptor_sha != EXPECTED_DESCRIPTOR_SHA:
        fail(f"descriptor SHA drift: {descriptor_sha}")
    if material_sha != EXPECTED_MATERIAL_SHA:
        fail(f"material SHA drift: {material_sha}")
    if config["descriptor"]["sha256"] != descriptor_sha:
        fail("config descriptor binding drift")
    if config["materialLibrary"]["sha256"] != material_sha:
        fail("config material binding drift")
    if descriptor["logicalBuildingID"] != "industrial_l04":
        fail("logical building identity drift")
    if descriptor["variantID"] != "variant-0":
        fail("variant identity drift")
    if descriptor["viewDirection"] != "n":
        fail("direction drift")
    if descriptor["sourceRevision"] != EXPECTED_REVISION:
        fail("source revision drift")
    if descriptor["sceneGeometryID"] != EXPECTED_GEOMETRY:
        fail("geometry identity drift")
    if descriptor["registration"]["orientationTransform"] != "none":
        fail("orientation transform is forbidden")
    if descriptor["productionSelected"] is not False:
        fail("production selection must remain false")
    if descriptor["sourceAuthority"] is not False:
        fail("source authority must remain false")
    if len(materials) != EXPECTED_MATERIAL_COUNT:
        fail("material library count drift")


def main():
    args = parse_arguments()
    repository_root = Path(args.repository_root).resolve()
    if not (repository_root / ".git").exists():
        fail("repository root is not a Git worktree")
    output_root = Path(args.output_root).resolve()
    if output_root.exists():
        fail(f"output root must be absent: {output_root}")
    output_root.mkdir(parents=True, exist_ok=False)
    config_path = resolve_inside(repository_root, args.config)
    config = json.loads(config_path.read_text(encoding="utf-8"))
    descriptor_path = resolve_inside(repository_root, config["descriptor"]["file"])
    material_path = resolve_inside(
        repository_root, config["materialLibrary"]["file"]
    )
    descriptor_sha = file_sha256(descriptor_path)
    material_sha = file_sha256(material_path)
    descriptor = json.loads(descriptor_path.read_text(encoding="utf-8"))
    material_root = json.loads(material_path.read_text(encoding="utf-8"))
    material_records = material_root["materials"]
    validate_binding(
        config,
        descriptor,
        material_records,
        descriptor_sha,
        material_sha,
    )
    clean_scene()
    scene = bpy.context.scene
    configure_cycles(scene, config["cycles"], output_root / "raw.png")
    components, _ = build_scene(descriptor, material_records)
    shadow = add_authored_contact_shadow(
        descriptor, make_shadow_material()
    )
    camera = configure_camera(descriptor)
    configure_light(descriptor, config["cycles"])
    component_names = sorted(component["nodeName"] for component in components)
    if len(set(component_names)) != EXPECTED_COMPONENT_COUNT:
        fail("component names are not unique")
    mapping = {
        "schema": 1,
        "task": "PLAY-027",
        "contract": "CONTRACT-020",
        "calibrationID": config["calibrationID"],
        "descriptorSHA256": descriptor_sha,
        "materialLibrarySHA256": material_sha,
        "sourceRevision": descriptor["sourceRevision"],
        "sceneGeometryID": descriptor["sceneGeometryID"],
        "direction": descriptor["viewDirection"],
        "orientationTransform": descriptor["registration"][
            "orientationTransform"
        ],
        "renderedComponentCount": len(components),
        "components": sorted(components, key=lambda item: item["nodeName"]),
        "skippedByExplicitComponentContract": [
            "building.chimney",
            "facades",
            "entrance",
        ],
        "technicalObjects": [
            {
                "nodeName": shadow.name,
                "purpose": "authored southeast contact-shadow polygon",
                "sourcePixelVector": descriptor["light"]["shadowVectorSource"],
                "derivedCitySimWorldOffset": [15.75, 0.0],
            },
            {
                "nodeName": camera.name,
                "purpose": "exact descriptor camera and registration",
            },
            {
                "nodeName": "northwest-key",
                "purpose": "descriptor northwest key-light semantics",
            },
        ],
        "registration": {
            "groundPivotSource": descriptor["registration"][
                "groundPivotSource"
            ],
            "frontageSocketSource": descriptor["registration"][
                "frontageSocketSource"
            ],
            "footprintPolygonSource": descriptor["registration"][
                "footprintPolygonSource"
            ],
            "contactPolygonWorld": descriptor["registration"][
                "contactPolygonWorld"
            ],
            "shadowVectorSource": descriptor["light"]["shadowVectorSource"],
            "renderViewportPixels": descriptor["camera"][
                "renderViewportPixels"
            ],
        },
        "artRedesignOccurred": False,
        "sourceAuthority": False,
        "productionSelected": False,
    }
    mapping["mappingSHA256"] = sha256_bytes(canonical_bytes(mapping))
    write_json(output_root / "object-mapping.json", mapping)
    bpy.ops.render.render(write_still=True)
    raw_path = output_root / "raw.png"
    if not raw_path.exists():
        fail("Cycles did not emit raw.png")
    semantic_mapping = render_semantic(
        scene, components, shadow, output_root / "semantic.png"
    )
    script_path = Path(__file__).resolve()
    provenance = {
        "schema": 1,
        "task": "PLAY-027",
        "contract": "CONTRACT-020",
        "calibrationID": config["calibrationID"],
        "processID": args.process_id,
        "processKind": "fresh-headless-factory-startup-cycles-cpu",
        "blender": {
            "version": bpy.app.version_string,
            "buildHash": bpy.app.build_hash.decode("utf-8"),
            "executableSHA256": file_sha256(Path(bpy.app.binary_path)),
            "pythonVersion": sys.version.split()[0],
            "machineArchitecture": platform.machine(),
            "operatingSystem": platform.platform(),
        },
        "inputs": {
            "configSHA256": file_sha256(config_path),
            "scriptSHA256": file_sha256(script_path),
            "descriptorSHA256": descriptor_sha,
            "materialLibrarySHA256": material_sha,
        },
        "cycles": config["cycles"],
        "commandTemplate": config["commandTemplate"],
        "outputs": {
            "rawPNG": "raw.png",
            "rawPNGSHA256": file_sha256(raw_path),
            "semanticPNG": "semantic.png",
            "semanticPNGSHA256": file_sha256(output_root / "semantic.png"),
            "objectMapping": "object-mapping.json",
            "objectMappingSHA256": file_sha256(
                output_root / "object-mapping.json"
            ),
        },
        "semanticObjectColors": semantic_mapping,
        "renderedComponentCount": len(components),
        "rawRendererProcessCount": 1,
        "normalizerProcessCount": 0,
        "sourceAuthority": False,
        "productionSelected": False,
    }
    write_json(output_root / "provenance.json", provenance)


if __name__ == "__main__":
    main()
