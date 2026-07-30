#!/usr/bin/env python3
"""Capability-gated Blender child for the future North v12 Process A."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import platform
import stat
import sys
from pathlib import Path
from typing import Any


ALLOWED_CHILD_OUTPUTS = {
    "raw.png",
    "semantic.png",
    "OBJECT-MANIFEST.json",
    "GROUND-PROJECTION.json",
    "INPUT-BINDINGS.json",
    "provenance.json",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON object required: {path.name}")
    return value


def arguments(values: list[str] | None = None) -> argparse.Namespace:
    if values is None:
        require("--" in sys.argv, "Blender child arguments require -- separator")
        values = sys.argv[sys.argv.index("--") + 1 :]
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--child-grant", required=True)
    parser.add_argument("--capability-fd", required=True, type=int)
    return parser.parse_args(values)


def load_module(path: Path, name: str) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"{name} import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_one_use_capability(descriptor: int) -> dict[str, Any]:
    require(descriptor >= 3, "inherited launcher capability fd missing")
    try:
        descriptor_stat = os.fstat(descriptor)
    except OSError as error:
        raise RuntimeError("inherited launcher capability fd missing") from error
    require(stat.S_ISFIFO(descriptor_stat.st_mode), "launcher capability must be an anonymous pipe")
    with os.fdopen(descriptor, "rb", closefd=True) as handle:
        payload = handle.read(8193)
    require(0 < len(payload) <= 8192, "launcher capability payload size invalid")
    value = json.loads(payload.decode("utf-8"))
    require(isinstance(value, dict), "launcher capability payload must be an object")
    return value


def verify_capability(
    repository_root: Path,
    contract: dict[str, Any],
    contract_path: Path,
    output_root: Path,
    child_grant_path: Path,
    capability_payload: dict[str, Any],
) -> dict[str, Any]:
    require(
        set(capability_payload)
        == {
            "capability",
            "grantId",
            "launcherPID",
            "launcherSHA256",
            "scheduleSHA256",
        },
        "launcher capability payload fields drift",
    )
    capability = capability_payload["capability"]
    require(
        isinstance(capability, str) and len(capability) == 64,
        "launcher capability missing",
    )
    require(
        capability_payload["launcherPID"] == os.getppid(),
        "launcher parent PID mismatch",
    )
    expected_output = (repository_root / contract["processOutputRoot"]).absolute()
    require(output_root.absolute() == expected_output, "child output root drift")
    require(output_root.is_dir() and not output_root.is_symlink(), "launcher-created output root required")
    require(
        child_grant_path.absolute() == output_root / "CHILD-GRANT.json",
        "exact child grant path required",
    )
    grant = load_json(child_grant_path)
    require(
        set(grant)
        == {
            "schema",
            "task",
            "direction",
            "process",
            "grantId",
            "slotId",
            "schedulePath",
            "scheduleSHA256",
            "contractSHA256",
            "launcherSHA256",
            "launcherPID",
            "childEntrypointSHA256",
            "outputRoot",
            "capabilitySHA256",
            "childStartCount",
        },
        "child grant fields drift",
    )
    require(grant["task"] == "PLAY-027", "child grant task drift")
    require(grant["direction"] == "north", "child grant direction drift")
    require(grant["process"] == "A", "child grant process drift")
    require(grant["slotId"] == "dcc-1", "child grant slot drift")
    require(grant["launcherPID"] == os.getppid(), "child grant parent PID drift")
    require(grant["childStartCount"] == 1, "child grant start count drift")
    require(grant["outputRoot"] == contract["processOutputRoot"], "child grant output drift")
    require(grant["contractSHA256"] == sha256(contract_path), "child contract hash drift")
    require(grant["launcherSHA256"] == contract["launcher"]["sha256"], "child launcher hash drift")
    require(
        grant["childEntrypointSHA256"] == contract["childEntrypoint"]["sha256"],
        "child entrypoint hash drift",
    )
    require(
        grant["capabilitySHA256"] == sha256_bytes(capability.encode("utf-8")),
        "launcher capability mismatch",
    )
    require(
        capability_payload["grantId"] == grant["grantId"],
        "launcher capability grant drift",
    )
    require(
        capability_payload["scheduleSHA256"] == grant["scheduleSHA256"],
        "launcher capability schedule drift",
    )
    require(
        capability_payload["launcherSHA256"] == grant["launcherSHA256"],
        "launcher capability source drift",
    )
    schedule_relative = grant["schedulePath"]
    require(
        isinstance(schedule_relative, str) and not schedule_relative.startswith("/"),
        "child schedule path must be repository-relative",
    )
    schedule_path = repository_root / schedule_relative
    require(not schedule_path.is_symlink(), "child schedule path contains a symlink")
    require(schedule_path.is_file(), "child schedule is missing")
    require(sha256(schedule_path) == grant["scheduleSHA256"], "child schedule bytes drift")
    adapter = load_module(
        repository_root / contract["scheduleAdapter"]["consumer"]["path"],
        "play027_child_schedule_adapter",
    )
    schedule_grant = adapter.consume_published_schedule(
        repository_root,
        repository_root / contract["scheduleAdapter"]["contract"]["path"],
        schedule_path,
    )
    require(schedule_grant["grantId"] == grant["grantId"], "child schedule grantId drift")
    require(
        schedule_grant["orchestrator"] == contract["launcher"],
        "child schedule launcher binding drift",
    )
    existing = {path.name for path in output_root.iterdir()}
    require(existing == {"CHILD-GRANT.json"}, "child output root was reused")
    return grant


def write_exclusive(root: Path, name: str, value: Any) -> None:
    require(name in ALLOWED_CHILD_OUTPUTS, f"unapproved child output: {name}")
    path = root / name
    descriptor = os.open(
        path,
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
        0o644,
    )
    try:
        payload = canonical_bytes(value)
        offset = 0
        while offset < len(payload):
            offset += os.write(descriptor, payload[offset:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def semantic_rgba(index: int) -> tuple[float, float, float, float]:
    levels = (32, 72, 112, 152, 192, 232)
    return (
        levels[index % 6] / 255.0,
        levels[(index // 6) % 6] / 255.0,
        levels[(index // 36) % 6] / 255.0,
        1.0,
    )


def configure_cycles(scene: Any, cycles: dict[str, Any], output: Path) -> None:
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.threads_mode = "FIXED"
    scene.render.threads = int(cycles["threads"])
    scene.cycles.seed = int(cycles["seed"])
    scene.cycles.samples = int(cycles["samples"])
    scene.cycles.use_adaptive_sampling = False
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = int(cycles["maxBounces"])
    scene.render.use_motion_blur = False
    scene.render.film_transparent = True
    scene.render.resolution_x = int(cycles["resolution"][0])
    scene.render.resolution_y = int(cycles["resolution"][1])
    scene.render.resolution_percentage = int(cycles["resolutionPercentage"])
    scene.render.pixel_aspect_x = float(cycles["pixelAspect"][0])
    scene.render.pixel_aspect_y = float(cycles["pixelAspect"][1])
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.filepath = str(output)
    colors = cycles["colorManagement"]
    scene.display_settings.display_device = colors["displayDevice"]
    scene.view_settings.view_transform = colors["viewTransform"]
    scene.view_settings.look = colors["look"]
    scene.view_settings.exposure = float(colors["exposure"])
    scene.view_settings.gamma = float(colors["gamma"])
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.18, 0.22, 0.20, 1.0)
    background.inputs["Strength"].default_value = float(cycles["worldStrength"])


def make_shadow_material(bpy: Any, opacity: float) -> Any:
    material = bpy.data.materials.new("play027-v12-authored-contact-shadow")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    diffuse.inputs["Color"].default_value = (0.025, 0.031, 0.029, 1.0)
    mix = nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = opacity
    material.node_tree.links.new(transparent.outputs[0], mix.inputs[1])
    material.node_tree.links.new(diffuse.outputs[0], mix.inputs[2])
    material.node_tree.links.new(mix.outputs[0], output.inputs["Surface"])
    return material


def make_semantic_material(bpy: Any, name: str, rgba: tuple[float, ...]) -> Any:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = rgba
    emission.inputs["Strength"].default_value = 1.0
    material.node_tree.links.new(emission.outputs[0], output.inputs["Surface"])
    return material


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    contract_path = Path(options.contract).resolve(strict=True)
    output_root = Path(options.output_root).absolute()
    child_grant_path = Path(options.child_grant).absolute()
    capability_payload = read_one_use_capability(options.capability_fd)
    execution_root = Path(__file__).resolve().parent
    launcher = load_module(
        execution_root / "launch_north_process_a.py",
        "play027_process_a_launcher_validation",
    )
    contract = launcher.validate_execution_contract(repository_root, contract_path)
    verify_capability(
        repository_root,
        contract,
        contract_path,
        output_root,
        child_grant_path,
        capability_payload,
    )
    require(
        sha256(Path(__file__).resolve()) == contract["childEntrypoint"]["sha256"],
        "child entrypoint bytes drift",
    )
    lowering_root = (
        repository_root
        / "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
        "industrial-l04-north-art-v12/blender-lowering-v01"
    )
    sys.path.insert(0, str(lowering_root))
    lowerer = load_module(
        lowering_root / "lower_v12_scene.py",
        "play027_v12_lowerer",
    )
    importer = load_module(
        lowering_root / "import_v12_scene.py",
        "play027_v12_importer",
    )
    import bpy

    actual_build_hash = (
        bpy.app.build_hash.decode("utf-8")
        if isinstance(bpy.app.build_hash, bytes)
        else str(bpy.app.build_hash)
    )
    require(bpy.app.version_string == contract["blender"]["version"], "Blender version drift")
    require(actual_build_hash == contract["blender"]["buildHash"], "Blender build drift")
    lowering_contract = load_json(
        repository_root / contract["frozenNorthV12Inputs"]["loweringContract"]["path"]
    )
    lowered = lowerer.lower_scene(repository_root, lowering_contract)
    mesh_ir = lowered["CANONICAL-MESH-IR.json"]
    importer.clear_factory_scene()
    materials = importer.create_materials(mesh_ir["materials"])
    objects = importer.create_mesh_objects(mesh_ir, materials)
    shadow_manifest = importer.create_authored_shadow(mesh_ir)
    shadow_object = bpy.data.objects[shadow_manifest["objectName"]]
    shadow_object.data.materials.append(
        make_shadow_material(bpy, float(mesh_ir["authoredShadow"]["opacity"]))
    )
    scene, camera = importer.configure_camera(mesh_ir["camera"])
    light = importer.create_light(mesh_ir)
    configure_cycles(scene, contract["cycles"], output_root / "raw.png")
    bpy.context.view_layer.update()
    projection = importer.projection_proof(scene, camera, mesh_ir)
    object_manifest = {
        "schema": 1,
        "task": "PLAY-027",
        "direction": "north",
        "process": "A",
        "semanticObjectCount": len(objects),
        "physicalComponentCount": lowering_contract["expected"]["physicalComponentCount"],
        "objects": objects,
        "authoredShadow": shadow_manifest,
        "cameraObject": camera.name,
        "light": light,
        "allComponentsMapped": True,
    }
    input_bindings = {
        "schema": 1,
        "task": "PLAY-027",
        "executionContract": {
            "path": str(contract_path.relative_to(repository_root)),
            "sha256": sha256(contract_path),
        },
        "scene": contract["frozenNorthV12Inputs"]["scene"],
        "materials": contract["frozenNorthV12Inputs"]["materials"],
        "loweringContract": contract["frozenNorthV12Inputs"]["loweringContract"],
        "lowerer": contract["frozenNorthV12Inputs"]["lowerer"],
        "importer": contract["frozenNorthV12Inputs"]["importer"],
        "launcher": contract["launcher"],
        "childEntrypoint": contract["childEntrypoint"],
    }
    write_exclusive(output_root, "OBJECT-MANIFEST.json", object_manifest)
    write_exclusive(output_root, "GROUND-PROJECTION.json", projection)
    write_exclusive(output_root, "INPUT-BINDINGS.json", input_bindings)
    bpy.ops.render.render(write_still=True)
    raw_path = output_root / "raw.png"
    require(raw_path.is_file(), "raw render missing")
    for index, item in enumerate(objects):
        item_object = bpy.data.objects[item["objectName"]]
        item_object.data.materials.clear()
        item_object.data.materials.append(
            make_semantic_material(
                bpy,
                f"play027-semantic-{index:02d}",
                semantic_rgba(index),
            )
        )
    shadow_object.hide_render = True
    scene.render.filepath = str(output_root / "semantic.png")
    bpy.ops.render.render(write_still=True)
    semantic_path = output_root / "semantic.png"
    require(semantic_path.is_file(), "semantic render missing")
    provenance = {
        "schema": 1,
        "task": "PLAY-027",
        "contract": "CONTRACT-020",
        "direction": "north",
        "process": "A",
        "blenderProcessCount": 1,
        "renderInvocationCount": 2,
        "blender": {
            "version": bpy.app.version_string,
            "buildHash": actual_build_hash,
            "executableSHA256": contract["blender"]["executableSHA256"],
            "pythonVersion": platform.python_version(),
            "machineArchitecture": platform.machine(),
        },
        "cycles": contract["cycles"],
        "rawFileSHA256": sha256(raw_path),
        "semanticFileSHA256": sha256(semantic_path),
        "objectManifestSHA256": sha256(output_root / "OBJECT-MANIFEST.json"),
        "projectionSHA256": sha256(output_root / "GROUND-PROJECTION.json"),
        "inputBindingsSHA256": sha256(output_root / "INPUT-BINDINGS.json"),
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    write_exclusive(output_root, "provenance.json", provenance)


if __name__ == "__main__":
    main()
