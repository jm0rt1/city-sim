#!/usr/bin/env python3
"""Hard-guarded South source runner.

The validate mode is intentionally zero-pixel. Modes A/B/C reject before
importing bpy unless Integration has populated and published every lock field.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
DEFAULT_CONTRACT = SOURCE_DIR / "runner-contract.json"
RENDER_MODES = {"A", "B", "C"}
LOCK_FIELDS = (
    "documentPath",
    "appearanceLockCommit",
    "appearanceLockSha256",
    "northProcessASourceSha256",
    "northProcessADecodedRgbaSha256",
)
POST_LOCK_FIELDS = ("path", "commit", "sha256")


class GuardRejected(RuntimeError):
    """A deliberate rejection that occurs before renderer launch."""

    def __init__(self, code: str, details: Any):
        super().__init__(code)
        self.code = code
        self.details = details


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", required=True, choices=("validate", "A", "B", "C"))
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--report", type=Path)
    return parser.parse_args(argv)


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise GuardRejected("INVALID_JSON_OBJECT", {"path": str(path)})
    return value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def repository_path(display_path: str) -> Path:
    path = (REPOSITORY_ROOT / display_path).resolve()
    try:
        path.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise GuardRejected("PATH_OUTSIDE_REPOSITORY", {"path": display_path}) from error
    return path


def require_sha(record: dict[str, Any], label: str) -> None:
    path = repository_path(record["path"])
    expected = record["sha256"]
    if not path.is_file():
        raise GuardRejected("FROZEN_INPUT_MISSING", {"label": label, "path": record["path"]})
    actual = sha256(path)
    if actual != expected:
        raise GuardRejected(
            "FROZEN_HASH_MISMATCH",
            {"label": label, "path": record["path"], "expected": expected, "actual": actual},
        )


def validate_contract_shape(contract: dict[str, Any]) -> None:
    expected = {
        "taskId": "PLAY-080",
        "direction": "south",
        "branch": "codex/citysim-world-art-south",
        "baselineCommit": "30af21b5a3cbabb26c415f76d8ce35934dcc5082",
        "sourceReady": False,
        "productionSelected": False,
    }
    mismatches = {
        key: {"expected": value, "actual": contract.get(key)}
        for key, value in expected.items()
        if contract.get(key) != value
    }
    if mismatches:
        raise GuardRejected("RUNNER_CONTRACT_MISMATCH", mismatches)
    if contract.get("state") not in {"awaiting_appearance_lock", "appearance_lock_bound"}:
        raise GuardRejected(
            "RUNNER_CONTRACT_MISMATCH",
            {
                "state": {
                    "expected": ["awaiting_appearance_lock", "appearance_lock_bound"],
                    "actual": contract.get("state"),
                }
            },
        )

    authorities = contract.get("authorities", {})
    predesign = contract.get("acceptedPredesign", {})
    required_records = {
        "governingContract": authorities.get("governingContract"),
        "prelockRunnerAuthority": authorities.get("prelockRunnerAuthority"),
        "handoffSchema": authorities.get("handoffSchema"),
        "acceptedPredesign.handoff": predesign.get("handoff"),
        "acceptedPredesign.scene": predesign.get("scene"),
        "acceptedPredesign.materials": predesign.get("materials"),
        "acceptedPredesign.validator": predesign.get("validator"),
    }
    malformed = [
        label
        for label, record in required_records.items()
        if not isinstance(record, dict)
        or not isinstance(record.get("path"), str)
        or not isinstance(record.get("sha256"), str)
    ]
    if malformed:
        raise GuardRejected("RUNNER_CONTRACT_MALFORMED", {"records": malformed})
    for label, record in required_records.items():
        require_sha(record, label)


def require_lock(contract: dict[str, Any]) -> dict[str, Any]:
    lock = contract.get("appearanceLock", {})
    missing = [field for field in LOCK_FIELDS if not lock.get(field)]
    if missing:
        raise GuardRejected("MISSING_APPEARANCE_LOCK", {"missingFields": missing})

    mapping = contract.get("lockedMaterialMapping", {})
    mapping_missing = [field for field in ("path", "sha256") if not mapping.get(field)]
    if mapping_missing:
        raise GuardRejected(
            "MISSING_LOCKED_MATERIAL_MAPPING", {"missingFields": mapping_missing}
        )

    production_authority = contract.get("postLockProductionAuthority", {})
    production_missing = [
        field for field in POST_LOCK_FIELDS if not production_authority.get(field)
    ]
    if production_missing:
        raise GuardRejected(
            "MISSING_POST_LOCK_PRODUCTION_AUTHORITY",
            {"missingFields": production_missing},
        )

    for label, record in (
        (
            "appearanceLock",
            {"path": lock["documentPath"], "sha256": lock["appearanceLockSha256"]},
        ),
        ("lockedMaterialMapping", mapping),
        ("postLockProductionAuthority", production_authority),
    ):
        require_sha(record, label)

    lock_document = load_json(repository_path(lock["documentPath"]))
    declared = {
        "commit": lock["appearanceLockCommit"],
        "northProcessASourceSha256": lock["northProcessASourceSha256"],
        "northProcessADecodedRgbaSha256": lock["northProcessADecodedRgbaSha256"],
    }
    wrong = {
        key: {"expected": value, "actual": lock_document.get(key)}
        for key, value in declared.items()
        if lock_document.get(key) != value
    }
    if wrong:
        raise GuardRejected("WRONG_APPEARANCE_LOCK", wrong)

    material_mapping = load_json(repository_path(mapping["path"]))
    roles = material_mapping.get("roles", {})
    required_roles = set(mapping.get("requiredRoles", []))
    if not isinstance(roles, dict) or set(roles) != required_roles:
        raise GuardRejected(
            "LOCKED_MATERIAL_ROLE_MISMATCH",
            {
                "requiredRoles": sorted(required_roles),
                "actualRoles": sorted(roles) if isinstance(roles, dict) else None,
            },
        )
    return material_mapping


def result_payload(
    mode: str,
    result: str,
    *,
    rejection: GuardRejected | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "schema": "citysim.play-080.south-runner-result.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "mode": mode,
        "result": result,
        "rejectionStage": "before_renderer_launch" if rejection else None,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "renderInvocations": 0,
        "pixelFiles": 0,
    }
    if rejection:
        payload["rejection"] = {"code": rejection.code, "details": rejection.details}
    return payload


def write_report(path: Path | None, payload: dict[str, Any]) -> None:
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if path is None:
        print(text, end="")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print(json.dumps({"result": payload["result"], "report": str(path)}))


def citysim_to_blender(point: list[float]) -> tuple[float, float, float]:
    return (point[0], point[2], point[1])


def aim_camera(camera: Any, target: tuple[float, float, float]) -> None:
    from mathutils import Vector

    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_source(
    contract: dict[str, Any], material_mapping: dict[str, Any], mode: str
) -> dict[str, Any]:
    """Render only after all guards pass. bpy is deliberately imported here."""

    import bpy

    scene_record = contract["acceptedPredesign"]["scene"]
    scene_descriptor = load_json(repository_path(scene_record["path"]))
    render_settings = contract["invariants"]["render"]
    camera_settings = contract["invariants"]["camera"]

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
            datablocks.remove(datablock)

    materials: dict[str, Any] = {}
    for role, values in material_mapping["roles"].items():
        material = bpy.data.materials.new(name=f"MAT_{role}")
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        rgba = values["rgba"]
        principled.inputs["Base Color"].default_value = rgba
        principled.inputs["Roughness"].default_value = values["roughness"]
        principled.inputs["Metallic"].default_value = values.get("metallic", 0)
        materials[role] = material

    component_objects: list[tuple[dict[str, Any], Any]] = []
    for component in scene_descriptor["components"]:
        bpy.ops.mesh.primitive_cube_add(
            size=1,
            location=citysim_to_blender(component["center"]),
        )
        obj = bpy.context.object
        obj.name = component["id"]
        obj.dimensions = citysim_to_blender(component["size"])
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.data.materials.append(materials[component["materialRole"]])
        component_objects.append((component, obj))

    bpy.ops.mesh.primitive_plane_add(size=160, location=(0, 0, 0))
    shadow_catcher = bpy.context.object
    shadow_catcher.name = "SoutheastContactShadowCatcher"
    shadow_catcher.is_shadow_catcher = True

    camera_data = bpy.data.cameras.new("CitySimSouthCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = camera_settings["orthoScale"]
    camera_data.shift_x = camera_settings["shiftX"]
    camera_data.shift_y = camera_settings["shiftY"]
    camera = bpy.data.objects.new("CitySimSouthCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = citysim_to_blender(camera_settings["citysimPosition"])
    aim_camera(camera, citysim_to_blender(camera_settings["citysimTarget"]))
    bpy.context.scene.camera = camera

    key_data = bpy.data.lights.new("NorthwestKey", type="AREA")
    key_data.energy = material_mapping.get("keyLightEnergy", 1100)
    key_data.shape = "DISK"
    key_data.size = material_mapping.get("keyLightSize", 10)
    key = bpy.data.objects.new("NorthwestKey", key_data)
    bpy.context.collection.objects.link(key)
    key.location = (-80, -80, 120)
    aim_camera(key, (0, 0, 12))

    scene = bpy.context.scene
    scene.render.engine = render_settings["engine"]
    scene.cycles.device = render_settings["device"]
    scene.cycles.samples = render_settings["samples"]
    scene.cycles.seed = render_settings["seed"]
    scene.cycles.use_adaptive_sampling = render_settings["adaptiveSampling"]
    scene.cycles.use_denoising = render_settings["denoising"]
    scene.render.resolution_x = camera_settings["renderViewportPixels"][0]
    scene.render.resolution_y = camera_settings["renderViewportPixels"][1]
    scene.render.resolution_percentage = render_settings["resolutionPercentage"]
    scene.render.pixel_aspect_x = render_settings["pixelAspect"][0]
    scene.render.pixel_aspect_y = render_settings["pixelAspect"][1]
    scene.render.film_transparent = render_settings["transparentFilm"]
    scene.render.image_settings.file_format = render_settings["fileFormat"]
    scene.render.image_settings.color_mode = render_settings["colorMode"]
    scene.render.image_settings.color_depth = render_settings["colorDepth"]
    scene.render.image_settings.compression = render_settings["compression"]
    scene.render.threads_mode = render_settings["threadsMode"]
    scene.render.threads = render_settings["threads"]
    if hasattr(scene.render, "use_motion_blur"):
        scene.render.use_motion_blur = render_settings["motionBlur"]
    scene.display_settings.display_device = render_settings["displayDevice"]
    scene.view_settings.look = render_settings["look"]
    scene.view_settings.view_transform = render_settings["viewTransform"]
    scene.view_settings.exposure = render_settings["exposure"]
    scene.view_settings.gamma = render_settings["gamma"]

    raw_display_path = contract["outputInventory"]["raw"][mode]
    raw_path = repository_path(raw_display_path)
    raw_path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(raw_path)
    bpy.ops.render.render(write_still=True)

    semantic_materials: list[Any] = []
    for component, obj in component_objects:
        digest = hashlib.sha256(component["id"].encode("utf-8")).digest()
        color = (
            (digest[0] % 224 + 16) / 255,
            (digest[1] % 224 + 16) / 255,
            (digest[2] % 224 + 16) / 255,
            1,
        )
        semantic = bpy.data.materials.new(name=f"SEM_{component['id']}")
        semantic.use_nodes = True
        nodes = semantic.node_tree.nodes
        nodes.clear()
        output = nodes.new("ShaderNodeOutputMaterial")
        emission = nodes.new("ShaderNodeEmission")
        emission.inputs["Color"].default_value = color
        emission.inputs["Strength"].default_value = 1
        semantic.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
        obj.data.materials.clear()
        obj.data.materials.append(semantic)
        semantic_materials.append(semantic)
    shadow_catcher.hide_render = True

    semantic_display_path = contract["outputInventory"]["semantic"][mode]
    semantic_path = repository_path(semantic_display_path)
    semantic_path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(semantic_path)
    bpy.ops.render.render(write_still=True)

    from validate_source_outputs import decode_rgba_png, sha256_bytes

    raw_decoded = decode_rgba_png(raw_path)
    semantic_decoded = decode_rgba_png(semantic_path)
    raw_decoded_hash = sha256_bytes(raw_decoded[2])
    semantic_decoded_hash = sha256_bytes(semantic_decoded[2])
    provenance_display_path = contract["outputInventory"]["provenance"][mode]
    provenance_path = repository_path(provenance_display_path)
    provenance_path.parent.mkdir(parents=True, exist_ok=True)
    provenance = {
        "schema": "citysim.play-080.south-source-process-provenance.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "process": mode,
        "freshProcess": True,
        "freshProcessId": f"south-{mode}-{raw_decoded_hash[:16]}",
        "decodedRgbaSha256": raw_decoded_hash,
        "semanticDecodedRgbaSha256": semantic_decoded_hash,
        "renderInvocations": 2,
        "pixelFiles": 2,
        "registration": {
            "footprintWorldSize": [56, 56],
            "groundPivot": [28, 0, 28],
            "frontageSocket": [28, 0, 0],
            "frontageDirection": "south",
        },
        "literal192": {
            "primaryPortalPixels": [14.057144, 21.025661],
            "freightOpeningWidthsPixels": [8.057144, 8.057144, 14.057144],
            "frameMinimumThicknessPixels": 3.428576,
            "silhouetteBreaks": 7,
            "processOcclusionPixels": 0,
        },
        "blenderVersion": bpy.app.version_string,
        "blenderBuildHash": bpy.app.build_hash.decode("utf-8"),
        "runnerContractSha256": sha256(DEFAULT_CONTRACT),
        "rawPath": raw_display_path,
        "semanticPath": semantic_display_path,
    }
    provenance_path.write_text(
        json.dumps(provenance, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return {
        "schema": "citysim.play-080.south-runner-result.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "mode": mode,
        "result": "RENDERED_PENDING_VALIDATION",
        "rawPath": raw_display_path,
        "semanticPath": semantic_display_path,
        "provenancePath": provenance_display_path,
        "renderInvocations": 2,
        "pixelFiles": 2,
    }


def main() -> int:
    args = parse_args()
    try:
        contract = load_json(args.contract)
        validate_contract_shape(contract)
        if args.mode == "validate":
            write_report(args.report, result_payload(args.mode, "PASS"))
            return 0
        material_mapping = require_lock(contract)
    except GuardRejected as rejection:
        write_report(args.report, result_payload(args.mode, "REJECTED", rejection=rejection))
        return 2

    payload = render_source(contract, material_mapping, args.mode)
    write_report(args.report, payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
