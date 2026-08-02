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
import subprocess
import sys


BLENDER_DIRECT_FLAG = "--integration-direct"
SOURCE_ROOT = "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13"
PROCESS_ROOT = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a"
EVIDENCE_ROOT = "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a-v02"
WORKTREE = "/Users/James/.codex/worktrees/0648/city-sim"
ATTEMPT_MARKER_PATH = "docs/production/evidence/INTEGRATION/PLAY-027-NORTH-V13-PROCESS-A-ATTEMPT.json"
AUTHORITY_BASE = "5ac54021604e25117f4ccb63bc0914209724754c"
CLAIM_SHA256 = "bf0b167a1d1e6f7007d609aeb657917fe9d3d0866d5a7a6e36b0e5a32faefa6f"
ROUTE_ID = "quality-v1:play-027-north-current-head-preflight-luna-v1"
ROUTE_SHA256 = "d1c3a1c8b2c6afd747b42641d29afc5e4d85320f267ffe19c89efc447cdb1940"
CARRIER_COMMIT = "5d84d521b3b25f9ddf11d7b88e81c885a5e86946"
EXECUTION_BASE = "d25d7a2767d92a8628849ca3911d28f4203dd674"


def canonical(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if type(value) is not dict:
        raise RuntimeError(f"JSON object required: {path}")
    return value


def _git(root: Path, *arguments: str) -> bytes:
    if not arguments or arguments[0] not in {"cat-file", "show", "rev-parse", "merge-base"}:
        raise RuntimeError("unapproved Git helper")
    result = subprocess.run(["git", *arguments], cwd=root, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode:
        raise RuntimeError("Git authority check failed")
    return result.stdout


def _no_symlink(root: Path, relative: str) -> Path:
    path = root / relative
    try:
        parts = path.relative_to(root).parts
    except ValueError as exc:
        raise RuntimeError("path escapes assigned repository") from exc
    current = root
    for part in parts:
        current /= part
        if current.is_symlink():
            raise RuntimeError("symlink path rejected")
    return path


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
    parser.add_argument("--attempt-marker-path", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--evidence-root", required=True)
    parsed = parser.parse_args(values)
    if not parsed.integration_direct:
        raise RuntimeError("direct child invocation forbidden; Integration flag missing")
    return parsed


def _require_full_sha(value: object, label: str) -> str:
    if type(value) is not str or len(value) != 64 or any(ch not in "0123456789abcdef" for ch in value):
        raise RuntimeError(f"{label} must be a full lowercase SHA-256")
    return value


def _require_commit(value: object, label: str) -> str:
    if type(value) is not str or len(value) != 40 or any(ch not in "0123456789abcdef" for ch in value):
        raise RuntimeError(f"{label} must be a full lowercase commit")
    return value


def _exact_int(value: object, expected: int) -> bool:
    return type(value) is int and value == expected


def _normalized_integration_path(root: Path, value: str, label: str) -> Path:
    if type(value) is not str or not value or Path(value).is_absolute() or Path(value).as_posix() != value or value.endswith("/") or ".." in Path(value).parts or "." in Path(value).parts:
        raise RuntimeError(f"{label} is not a normalized repository path")
    if not value.startswith("docs/production/evidence/INTEGRATION/"):
        raise RuntimeError(f"{label} is outside Integration authority")
    return _no_symlink(root, value)


def _claim_child_start(marker_path: Path, marker: dict) -> None:
    child_start = Path(os.fspath(marker_path) + ".child-start")
    if child_start.exists() or child_start.is_symlink():
        raise RuntimeError("attempt has already started a child")
    fd = os.open(child_start, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as stream:
        stream.write(canonical(marker))
        stream.flush()
        os.fsync(stream.fileno())


def validate_launch(parsed: argparse.Namespace) -> dict:
    root = Path(parsed.repository_root)
    if str(root) != WORKTREE or not root.is_absolute() or os.path.realpath(root) != WORKTREE or root.is_symlink() or not root.is_dir():
        raise RuntimeError("repository root is not the assigned worktree")
    contract_path = _no_symlink(root, f"{SOURCE_ROOT}/process-a-v02/EXECUTION-CONTRACT.json")
    if Path(parsed.contract) != contract_path:
        raise RuntimeError("caller-selected contract path is not the committed contract")
    contract = load(contract_path)
    identity = contract.get("identity", {})
    if identity.get("logicalBuildingID") != "industrial_l04" or identity.get("variantID") != "variant-0" or identity.get("viewDirection") != "north" or identity.get("processID") != "A" or identity.get("slotID") != "north:A" or identity.get("sourceAuthority") is not False or identity.get("productionSelected") is not False:
        raise RuntimeError("child identity mismatch")
    contract_route = contract.get("route", {})
    if contract_route.get("routeId") != ROUTE_ID or contract_route.get("canonicalSHA256") != ROUTE_SHA256 or contract_route.get("carrierCommit") != CARRIER_COMMIT or contract_route.get("authorityCommit") != AUTHORITY_BASE or contract_route.get("executionBaseHEAD") != EXECUTION_BASE:
        raise RuntimeError("child route or execution-base mismatch")
    if contract.get("claim", {}).get("sha256") != CLAIM_SHA256 or contract.get("claim", {}).get("revision") != 10:
        raise RuntimeError("child claim mismatch")
    if contract.get("route", {}).get("authorityCommit") != AUTHORITY_BASE:
        raise RuntimeError("child authority mismatch")
    expected_output = root / PROCESS_ROOT
    output = Path(parsed.output_root)
    if output != expected_output or output.is_symlink() or not output.is_dir():
        raise RuntimeError("child output root mismatch")
    evidence = _no_symlink(root, EVIDENCE_ROOT)
    if Path(parsed.evidence_root) != evidence:
        raise RuntimeError("child evidence root mismatch")
    schedule_path = parsed.schedule_path
    schedule_file = _normalized_integration_path(root, schedule_path, "schedule path")
    receipt_path = parsed.process_receipt_path
    receipt_file = _normalized_integration_path(root, receipt_path, "process receipt path")
    marker_path = _no_symlink(root, parsed.attempt_marker_path)
    if marker_path != root / ATTEMPT_MARKER_PATH or marker_path.is_symlink() or not marker_path.is_file():
        raise RuntimeError("child attempt marker path mismatch")
    schedule_bytes = schedule_file.read_bytes()
    receipt_bytes = receipt_file.read_bytes()
    schedule = load(schedule_file)
    receipt = load(receipt_file)
    current_head = _git(root, "rev-parse", "HEAD").decode().strip()
    _git(root, "merge-base", "--is-ancestor", EXECUTION_BASE, current_head)
    runner_path = root / SOURCE_ROOT / "process-a-v02" / "launch_north_v13_process_a_v02.py"
    child_path = root / SOURCE_ROOT / "process-a-v02" / "render_north_v13_process_a_child.py"
    if not _exact_int(schedule.get("schema"), 1) or schedule.get("task") != "PLAY-027" or schedule.get("batch") != "industrial_l04_directional_family" or schedule.get("direction") != "north" or schedule.get("process") != "A" or schedule.get("slot") != "north:A" or not _exact_int(schedule.get("maximumChildStarts"), 1) or schedule.get("schedulePath") != schedule_path or schedule.get("attemptMarkerPath") != ATTEMPT_MARKER_PATH or schedule.get("outputRoot") != PROCESS_ROOT or schedule.get("evidenceRoot") != EVIDENCE_ROOT or schedule.get("workerHead") is not None or schedule.get("claimSHA256") != CLAIM_SHA256 or schedule.get("trustedIntegrationHead") != AUTHORITY_BASE or schedule.get("schedulePublicationCommit") != AUTHORITY_BASE:
        raise RuntimeError("child schedule identity mismatch")
    if schedule.get("orchestratorPath") != f"{SOURCE_ROOT}/process-a-v02/launch_north_v13_process_a_v02.py" or schedule.get("childPath") != f"{SOURCE_ROOT}/process-a-v02/render_north_v13_process_a_child.py" or schedule.get("orchestratorSHA256") != sha256(runner_path) or schedule.get("childSHA256") != sha256(child_path):
        raise RuntimeError("child tool identity mismatch")
    publication = _require_commit(receipt.get("schedulePublicationCommit"), "receipt schedule publication commit")
    _git(root, "cat-file", "-e", publication + "^{commit}")
    _git(root, "merge-base", "--is-ancestor", publication, current_head)
    if _git(root, "show", f"{publication}:{schedule_path}") != schedule_bytes:
        raise RuntimeError("committed schedule blob differs from consumed schedule")
    if not _exact_int(receipt.get("schema"), 1) or receipt.get("kind") != "integration-process-receipt" or receipt.get("task") != "PLAY-027" or receipt.get("direction") != "north" or receipt.get("process") != "A" or receipt.get("slot") != "north:A" or not _exact_int(receipt.get("maximumChildStarts"), 1) or receipt.get("claimSHA256") != CLAIM_SHA256 or receipt.get("schedulePath") != schedule_path or receipt.get("scheduleSHA256") != sha256(schedule_file) or receipt.get("schedulePublicationCommit") != publication or receipt.get("workerHead") != current_head or receipt.get("outputRoot") != PROCESS_ROOT or receipt.get("evidenceRoot") != EVIDENCE_ROOT or receipt.get("attemptMarkerPath") != ATTEMPT_MARKER_PATH or receipt.get("receiptPath") != receipt_path or receipt.get("attemptConsumed") is not True:
        raise RuntimeError("child process receipt identity mismatch")
    if receipt.get("childPath") != f"{SOURCE_ROOT}/process-a-v02/render_north_v13_process_a_child.py" or receipt.get("orchestratorPath") != f"{SOURCE_ROOT}/process-a-v02/launch_north_v13_process_a_v02.py" or receipt.get("orchestratorSHA256") != sha256(runner_path) or receipt.get("childSHA256") != sha256(child_path):
        raise RuntimeError("child command identity mismatch")
    marker = load(marker_path)
    if not _exact_int(marker.get("schema"), 1) or marker.get("kind") != "integration-process-attempt" or marker.get("task") != "PLAY-027" or marker.get("slot") != "north:A" or marker.get("state") != "consumed" or marker.get("attemptConsumed") is not True or marker.get("schedulePath") != schedule_path or marker.get("scheduleSHA256") != sha256(schedule_file) or marker.get("schedulePublicationCommit") != publication or marker.get("receiptPath") != receipt_path or marker.get("receiptSHA256") != sha256(receipt_file) or marker.get("workerHead") != current_head or marker.get("outputRoot") != PROCESS_ROOT or marker.get("evidenceRoot") != EVIDENCE_ROOT or marker.get("childPath") != receipt.get("childPath") or marker.get("orchestratorPath") != receipt.get("orchestratorPath") or not _exact_int(marker.get("maximumChildStarts"), 1):
        raise RuntimeError("child consumed-attempt binding mismatch")
    for item in contract.get("inputs", []):
        frozen = _no_symlink(root, item["path"])
        if not frozen.is_file() or sha256(frozen) != item["sha256"]:
            raise RuntimeError("frozen input identity mismatch")
    claim_path = _no_symlink(root, contract["claim"]["path"])
    if not claim_path.is_file() or sha256(claim_path) != CLAIM_SHA256:
        raise RuntimeError("child claim bytes mismatch")
    if any(output.iterdir()):
        raise RuntimeError("exclusive output root is not empty")
    if marker.get("childStartMarker") != ATTEMPT_MARKER_PATH + ".child-start":
        raise RuntimeError("child start marker binding mismatch")
    return {"root": root, "contract": contract, "scenePath": root / SOURCE_ROOT / "DESIGN-SCENE.json", "materialsPath": root / SOURCE_ROOT / "DESIGN-MATERIALS.json", "loweringPath": root / SOURCE_ROOT / "lowering-v01" / "LOWERING-CONTRACT.json", "markerPath": marker_path, "schedulePath": schedule_file, "receiptPath": receipt_file, "marker": marker}


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


def render_process(parsed: argparse.Namespace, binding: dict) -> int:
    import bpy  # Imported only inside Blender's Integration-owned child.

    root = binding["root"]
    contract = binding["contract"]
    contract_path = root / SOURCE_ROOT / "process-a-v02" / "EXECUTION-CONTRACT.json"
    scene_path = binding["scenePath"]
    materials_path = binding["materialsPath"]
    lowering_path = binding["loweringPath"]
    scene = load(scene_path)
    materials = load(materials_path)
    lowering = load(lowering_path)
    if contract["identity"]["viewDirection"] != "north" or contract["identity"]["processID"] != "A":
        raise RuntimeError("North/A identity mismatch")
    output = Path(parsed.output_root)

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
    binding = validate_launch(parsed)
    _claim_child_start(binding["markerPath"], binding["marker"])
    return render_process(parsed, binding)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(78)
