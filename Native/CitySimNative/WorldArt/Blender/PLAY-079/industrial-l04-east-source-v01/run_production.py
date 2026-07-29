#!/usr/bin/env python3
"""Hard-guarded PLAY-079 East production entry point.

The ordinary Python process validates all frozen inputs and the exact
Integration-published appearance lock before it may launch Blender. The
Blender worker repeats the same guard before importing bpy or calling a render
API. With the pre-lock contract committed in this directory, A/B/C always
fail closed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import subprocess
import sys
from typing import Any, Callable, Iterable


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
CONTRACT_PATH = SOURCE_ROOT / "RUNNER-CONTRACT.json"
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]


class GuardRejected(RuntimeError):
    """Expected fail-closed production guard rejection."""

    def __init__(self, code: str, detail: str):
        super().__init__(detail)
        self.code = code
        self.detail = detail


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json(path: pathlib.Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise GuardRejected("invalid_json_input", f"{path}: {error}") from error
    if not isinstance(value, dict):
        raise GuardRejected("invalid_json_input", f"{path}: expected object")
    return value


def repository_path(relative: str) -> pathlib.Path:
    path = (REPOSITORY_ROOT / relative).resolve()
    try:
        path.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise GuardRejected("path_escape", relative) from error
    return path


def validate_frozen_inputs(contract: dict[str, Any]) -> dict[str, str]:
    records: list[dict[str, str]] = []
    records.extend(contract["authorities"].values())
    accepted = contract["acceptedPredesign"]
    records.extend(
        accepted[key]
        for key in ("handoff", "scene", "materials", "validator", "staticProof", "actualCameraProof")
    )
    actual: dict[str, str] = {}
    for record in records:
        path = repository_path(record["path"])
        try:
            digest = sha256_bytes(path.read_bytes())
        except OSError as error:
            raise GuardRejected("missing_frozen_input", str(path)) from error
        if digest != record["sha256"]:
            raise GuardRejected(
                "frozen_hash_mismatch",
                f"{record['path']}: expected {record['sha256']}, got {digest}",
            )
        actual[record["path"]] = digest
    if accepted["orientationTransform"] != "none" or accepted["siblingInputs"]:
        raise GuardRejected("direction_independence_failed", "East predesign provenance changed")
    return actual


def validate_contract(contract: dict[str, Any]) -> dict[str, Any]:
    if contract.get("taskId") != "PLAY-079":
        raise GuardRejected("contract_task_mismatch", str(contract.get("taskId")))
    if contract.get("direction") != "east":
        raise GuardRejected("contract_direction_mismatch", str(contract.get("direction")))
    if contract.get("branch") != "codex/citysim-world-art-east":
        raise GuardRejected("contract_branch_mismatch", str(contract.get("branch")))
    if contract.get("baselineCommit") != "30af21b5a3cbabb26c415f76d8ce35934dcc5082":
        raise GuardRejected("contract_baseline_mismatch", str(contract.get("baselineCommit")))
    if contract.get("sourceReady") or contract.get("productionSelected"):
        raise GuardRejected("unauthorized_disposition", "pre-lock runner cannot claim source/production")
    if contract.get("processModes") != ["validate", "A", "B", "C"]:
        raise GuardRejected("process_mode_contract_mismatch", str(contract.get("processModes")))

    invariants = contract["invariants"]
    if invariants["registration"]["frontage"] != "east":
        raise GuardRejected("frontage_mismatch", str(invariants["registration"]["frontage"]))
    if invariants["registration"]["groundPivot"] != [28.0, -28.0, 0.0]:
        raise GuardRejected("pivot_mismatch", str(invariants["registration"]["groundPivot"]))
    if invariants["registration"]["frontageSocket"] != [28.0, 0.0, 0.0]:
        raise GuardRejected("socket_mismatch", str(invariants["registration"]["frontageSocket"]))
    cycles = invariants["cycles"]
    expected_cycles = {
        "engine": "CYCLES",
        "device": "CPU",
        "threads": 1,
        "seed": 2704,
        "samples": 64,
        "adaptiveSampling": False,
        "denoising": False,
        "motionBlur": False,
        "transparentFilm": True,
        "maxBounces": 4,
    }
    if cycles != expected_cycles:
        raise GuardRejected("cycles_invariant_mismatch", str(cycles))
    return {
        "taskId": contract["taskId"],
        "direction": contract["direction"],
        "baselineCommit": contract["baselineCommit"],
        "frozenHashes": validate_frozen_inputs(contract),
    }


def validate_appearance_lock(
    contract: dict[str, Any],
    appearance_lock_path: pathlib.Path | None,
) -> dict[str, Any]:
    binding = contract["appearanceLock"]
    required_binding = (
        "documentPath",
        "commit",
        "documentSha256",
        "northProcessASourceSha256",
        "northProcessADecodedRgbaSha256",
    )
    if appearance_lock_path is None:
        raise GuardRejected("missing_appearance_lock", "no --appearance-lock was supplied")
    if any(binding.get(key) is None for key in required_binding):
        raise GuardRejected(
            "unpublished_or_wrong_appearance_lock",
            "runner contract has no Integration-published appearance-lock binding",
        )
    if contract.get("appearanceLockCommit") != binding["commit"]:
        raise GuardRejected("appearance_lock_commit_mismatch", "top-level and bound lock commit differ")
    if contract.get("appearanceLockSha256") != binding["documentSha256"]:
        raise GuardRejected("appearance_lock_hash_mismatch", "top-level and bound lock hash differ")
    mapping_digest = contract.get("lockedMaterialMappingSha256")
    if mapping_digest is None:
        raise GuardRejected("missing_locked_material_mapping", "material mapping is not bound")

    expected_path = repository_path(binding["documentPath"])
    candidate_path = appearance_lock_path.resolve()
    if candidate_path != expected_path:
        raise GuardRejected(
            "wrong_appearance_lock_path",
            f"expected {expected_path}, got {candidate_path}",
        )
    try:
        candidate_bytes = candidate_path.read_bytes()
    except OSError as error:
        raise GuardRejected("missing_appearance_lock", str(candidate_path)) from error
    candidate_digest = sha256_bytes(candidate_bytes)
    if candidate_digest != binding["documentSha256"]:
        raise GuardRejected(
            "wrong_appearance_lock_hash",
            f"expected {binding['documentSha256']}, got {candidate_digest}",
        )
    lock = load_json(candidate_path)
    if lock.get("commit") != binding["commit"]:
        raise GuardRejected("wrong_appearance_lock_commit", str(lock.get("commit")))
    north = lock.get("northProcessA")
    if not isinstance(north, dict):
        raise GuardRejected("missing_north_process_a", "lock has no northProcessA object")
    if north.get("sourceSha256") != binding["northProcessASourceSha256"]:
        raise GuardRejected("wrong_north_source_hash", str(north.get("sourceSha256")))
    if north.get("decodedRgbaSha256") != binding["northProcessADecodedRgbaSha256"]:
        raise GuardRejected("wrong_north_rgba_hash", str(north.get("decodedRgbaSha256")))
    mapping = lock.get("materialRoleMapping")
    if not isinstance(mapping, dict) or not mapping:
        raise GuardRejected("missing_locked_material_mapping", "lock has no materialRoleMapping")
    if sha256_bytes(canonical_bytes(mapping)) != mapping_digest:
        raise GuardRejected("wrong_material_mapping_hash", "locked material mapping differs")
    return lock


def output_paths(contract: dict[str, Any], process_id: str) -> dict[str, pathlib.Path]:
    inventory = contract["outputInventory"]
    root = repository_path(inventory["root"])
    process = inventory["processes"][process_id]
    return {name: root / relative for name, relative in process.items()}


def launch_blender(
    contract: dict[str, Any],
    process_id: str,
    appearance_lock_path: pathlib.Path,
) -> int:
    toolchain = contract["toolchain"]
    paths = output_paths(contract, process_id)
    for path in paths.values():
        path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        toolchain["executable"],
        *toolchain["requiredArguments"],
        "--python",
        str(pathlib.Path(__file__).resolve()),
        "--",
        "--blender-worker",
        "--mode",
        process_id,
        "--appearance-lock",
        str(appearance_lock_path.resolve()),
    ]
    return subprocess.run(command, cwd=REPOSITORY_ROOT, check=False).returncode


def execute(
    mode: str,
    appearance_lock_path: pathlib.Path | None,
    launcher: Callable[[dict[str, Any], str, pathlib.Path], int] = launch_blender,
) -> dict[str, Any]:
    contract = load_json(CONTRACT_PATH)
    contract_result = validate_contract(contract)
    if mode == "validate":
        return {
            "result": "PASS",
            "mode": "validate",
            "state": contract["state"],
            "contract": contract_result,
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "pixelFiles": 0,
        }
    lock = validate_appearance_lock(contract, appearance_lock_path)
    if appearance_lock_path is None:
        raise AssertionError("appearance lock guard returned without a path")
    returncode = launcher(contract, mode, appearance_lock_path)
    if returncode:
        raise RuntimeError(f"Blender process {mode} failed with status {returncode}")
    return {
        "result": "PASS",
        "mode": mode,
        "appearanceLockCommit": lock["commit"],
        "blenderProcessLaunches": 1,
    }


def hex_rgba(value: str) -> tuple[float, float, float, float]:
    raw = value.removeprefix("#")
    if len(raw) != 6:
        raise GuardRejected("invalid_material_color", value)
    return tuple(int(raw[index : index + 2], 16) / 255.0 for index in (0, 2, 4)) + (1.0,)


def look_at(obj: Any, target: Any) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def build_blender_scene(
    bpy: Any,
    vector_type: Any,
    contract: dict[str, Any],
    scene_data: dict[str, Any],
    material_mapping: dict[str, Any],
) -> tuple[Any, dict[str, Any]]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    invariants = contract["invariants"]
    camera_spec = invariants["camera"]
    cycles = invariants["cycles"]
    color = invariants["color"]

    scene.render.engine = cycles["engine"]
    scene.cycles.device = cycles["device"]
    scene.render.threads_mode = "FIXED"
    scene.render.threads = cycles["threads"]
    scene.cycles.seed = cycles["seed"]
    scene.cycles.samples = cycles["samples"]
    scene.cycles.use_adaptive_sampling = cycles["adaptiveSampling"]
    scene.cycles.use_denoising = cycles["denoising"]
    scene.cycles.max_bounces = cycles["maxBounces"]
    scene.render.use_motion_blur = cycles["motionBlur"]
    scene.render.film_transparent = cycles["transparentFilm"]
    scene.render.use_file_extension = True
    scene.render.image_settings.file_format = color["outputFormat"]
    scene.render.image_settings.color_mode = color["colorMode"]
    scene.render.image_settings.color_depth = color["colorDepth"]
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_x = camera_spec["resolution"][0]
    scene.render.resolution_y = camera_spec["resolution"][1]
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = camera_spec["pixelAspect"][0]
    scene.render.pixel_aspect_y = camera_spec["pixelAspect"][1]
    scene.display_settings.display_device = color["displayDevice"]
    scene.view_settings.view_transform = color["viewTransform"]
    scene.view_settings.look = color["look"]
    scene.view_settings.exposure = color["exposure"]
    scene.view_settings.gamma = color["gamma"]

    camera_data = bpy.data.cameras.new("PLAY-079-East-Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = camera_spec["orthoScale"]
    camera_data.shift_x = camera_spec["shiftX"]
    camera_data.shift_y = camera_spec["shiftY"]
    camera = bpy.data.objects.new("PLAY-079-East-Camera", camera_data)
    scene.collection.objects.link(camera)
    target = vector_type(camera_spec["target"])
    yaw = math.radians(camera_spec["yawDegrees"])
    elevation = math.radians(camera_spec["elevationDegrees"])
    horizontal = camera_spec["distance"] * math.cos(elevation)
    camera.location = vector_type(
        (
            target.x + horizontal * math.cos(yaw),
            target.y - horizontal * math.sin(yaw),
            target.z + camera_spec["distance"] * math.sin(elevation),
        )
    )
    look_at(camera, target)
    scene.camera = camera

    materials: dict[str, Any] = {}
    semantic_materials: dict[str, Any] = {}
    semantic_palette = invariants["semanticPalette"]
    required_roles = scene_data["materialBindings"]["requiredRoles"]
    if set(material_mapping) != set(required_roles):
        raise GuardRejected("locked_material_role_mismatch", "appearance lock roles differ from East")
    for role in sorted(required_roles):
        spec = material_mapping[role]
        if not isinstance(spec, dict):
            raise GuardRejected("invalid_material_mapping", role)
        material = bpy.data.materials.new(f"PLAY-079::{role}")
        material.diffuse_color = hex_rgba(spec["baseColorSRGB"])
        material.metallic = float(spec["metallic"])
        material.roughness = float(spec["roughness"])
        materials[role] = material
        semantic = bpy.data.materials.new(f"PLAY-079::semantic::{role}")
        semantic.diffuse_color = hex_rgba(semantic_palette[role])
        semantic_materials[role] = semantic

    objects: list[tuple[Any, str]] = []
    for spec in scene_data["objects"]:
        if spec["kind"] == "box":
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=spec["center"])
            obj = bpy.context.object
            obj.dimensions = spec["dimensions"]
        elif spec["kind"] == "cylinder":
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=spec["vertices"],
                radius=spec["radius"],
                depth=spec["depth"],
                location=spec["center"],
            )
            obj = bpy.context.object
        else:
            raise GuardRejected("unsupported_object_kind", str(spec["kind"]))
        obj.name = spec["id"]
        obj.data.name = f"{spec['id']}-mesh"
        obj.data.materials.append(materials[spec["materialRole"]])
        objects.append((obj, spec["materialRole"]))

    def add_polygon(name: str, coordinates: list[list[float]], role: str) -> None:
        mesh = bpy.data.meshes.new(f"{name}-mesh")
        mesh.from_pydata(coordinates, [], [list(range(len(coordinates)))])
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        scene.collection.objects.link(obj)
        obj.data.materials.append(materials[role])
        objects.append((obj, role))

    contact = scene_data["contact"]
    add_polygon("east-contact-shadow", contact["polygon"], contact["materialRole"])
    add_polygon("east-road-apron", contact["roadApron"], "formed-concrete")

    light_spec = invariants["light"]
    sun_data = bpy.data.lights.new("PLAY-079-Northwest-Key", type="SUN")
    sun_data.energy = 2.2
    sun_data.angle = 0.08
    sun = bpy.data.objects.new("PLAY-079-Northwest-Key", sun_data)
    scene.collection.objects.link(sun)
    sun.location = light_spec["keyOrigin"]
    look_at(sun, vector_type((0.0, 0.0, 0.0)))
    scene.world.color = (0.28, 0.28, 0.28)
    bpy.context.view_layer.update()
    return scene, {"objects": objects, "semanticMaterials": semantic_materials}


def blender_worker(mode: str, appearance_lock_path: pathlib.Path) -> int:
    contract = load_json(CONTRACT_PATH)
    validate_contract(contract)
    lock = validate_appearance_lock(contract, appearance_lock_path)

    # The hard guard above must complete before this process imports bpy.
    import bpy  # type: ignore
    from mathutils import Vector  # type: ignore

    scene_data = load_json(repository_path(contract["acceptedPredesign"]["scene"]["path"]))
    scene, built = build_blender_scene(
        bpy,
        Vector,
        contract,
        scene_data,
        lock["materialRoleMapping"],
    )
    paths = output_paths(contract, mode)
    scene.render.filepath = str(paths["raw"])
    bpy.ops.render.render(write_still=True)
    for obj, role in built["objects"]:
        obj.data.materials.clear()
        obj.data.materials.append(built["semanticMaterials"][role])
    scene.render.filepath = str(paths["semantic"])
    bpy.ops.render.render(write_still=True)
    provenance = {
        "schema": "citysim.world-art.blender-process-provenance.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "processId": mode,
        "appearanceLockCommit": lock["commit"],
        "sceneSha256": contract["acceptedPredesign"]["scene"]["sha256"],
        "contractSha256": sha256_bytes(CONTRACT_PATH.read_bytes()),
        "blenderVersion": bpy.app.version_string,
        "blenderBuildHash": bpy.app.build_hash.decode("utf-8"),
        "factoryStartup": True,
        "autoexecDisabled": True,
        "renderApiCalls": 2,
    }
    paths["provenance"].write_bytes(canonical_bytes(provenance))
    return 0


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("validate", "A", "B", "C"), required=True)
    parser.add_argument("--appearance-lock", type=pathlib.Path)
    parser.add_argument("--blender-worker", action="store_true")
    return parser.parse_args(list(argv))


def main() -> int:
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    args = parse_arguments(arguments)
    try:
        if args.blender_worker:
            if args.mode == "validate" or args.appearance_lock is None:
                raise GuardRejected("invalid_blender_worker_request", "worker requires A/B/C and lock")
            return blender_worker(args.mode, args.appearance_lock)
        result = execute(args.mode, args.appearance_lock)
        sys.stdout.buffer.write(canonical_bytes(result))
        return 0
    except GuardRejected as rejection:
        result = {
            "result": "REJECTED",
            "stage": "before_renderer_launch",
            "code": rejection.code,
            "detail": rejection.detail,
            "mode": args.mode,
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "pixelFiles": 0,
        }
        sys.stdout.buffer.write(canonical_bytes(result))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
