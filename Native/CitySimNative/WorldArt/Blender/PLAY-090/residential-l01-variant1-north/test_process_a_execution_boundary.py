#!/usr/bin/env python3
"""Adversarial and real Blender replay gate for PLAY-090 North repair."""
from __future__ import annotations

import argparse
import ast
import binascii
import hashlib
import importlib.util
import inspect
import json
from pathlib import Path
import shutil
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parents[6]
SOURCE = Path(__file__).resolve().parent
sys.path.insert(0, str(SOURCE))
import launch_residential_l01_process_a as runner  # noqa: E402
import render_residential_l01_process_a_child as child  # noqa: E402

CONTRACT = f"{runner.SOURCE_ROOT}/{runner.CONTRACT_NAME}"
EVIDENCE = ROOT / "docs/production/evidence/PLAY-090/residential-l01-variant1-north-runtime-repair-v2"
DETERMINISTIC_RECEIPTS = ("OBJECT-MANIFEST.json", "GROUND-REGISTRATION.json", "INPUT-BINDINGS.json", "PROVENANCE.json", "PROCESS-RECEIPT.json")


def sha_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha_file(path: Path) -> str:
    return sha_bytes(path.read_bytes())


def write_json(path: Path, value: object) -> bytes:
    payload = runner.pretty_bytes(value)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    path.write_bytes(payload)
    return payload


def fail(fn, label: str) -> None:
    try:
        fn()
    except (ValueError, RuntimeError, SystemExit, AssertionError):
        return
    raise AssertionError(f"adversary unexpectedly passed: {label}")


def bootstrap_without_ambient_source() -> dict:
    child_path = (SOURCE / runner.CHILD_NAME).resolve(strict=True)
    launcher_path = (SOURCE / "launch_residential_l01_process_a.py").resolve(strict=True)
    original_path = list(sys.path)
    original_runner = sys.modules.pop("launch_residential_l01_process_a", None)
    original_popen = runner.subprocess.Popen

    def is_source_entry(entry: object) -> bool:
        if type(entry) is not str:
            return False
        try:
            return Path(entry or ".").resolve() == SOURCE
        except OSError:
            return False

    def reject_dcc(*_args, **_kwargs):
        raise AssertionError("bootstrap-only regression attempted to start a child process")

    try:
        sys.path[:] = [entry for entry in sys.path if not is_source_entry(entry)]
        if any(is_source_entry(entry) for entry in sys.path):
            raise AssertionError("source directory remained in initial bootstrap sys.path")
        runner.subprocess.Popen = reject_dcc
        spec = importlib.util.spec_from_file_location("play090_child_bootstrap_probe", child_path)
        if spec is None or spec.loader is None:
            raise AssertionError("child bootstrap import specification unavailable")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        loaded_launcher = Path(module.runner.__file__).resolve(strict=True)
        if loaded_launcher != launcher_path:
            raise AssertionError("child bootstrap imported a non-adjacent launcher")
        if not sys.path or Path(sys.path[0]).resolve() != SOURCE:
            raise AssertionError("child bootstrap did not prioritize its canonical script directory")
        return {"child": str(child_path), "launcher": str(loaded_launcher), "dccStarts": 0}
    finally:
        runner.subprocess.Popen = original_popen
        sys.path[:] = original_path
        sys.modules.pop("launch_residential_l01_process_a", None)
        if original_runner is not None:
            sys.modules["launch_residential_l01_process_a"] = original_runner


def host_binding_zero_dcc() -> dict:
    receipt_host = {
        "nativeArchitecture": "arm64", "macOSVersion": "26.6", "macOSBuild": "25G72",
        "executionArchitecture": "x86_64", "translation": "Rosetta",
    }
    original_popen = runner.subprocess.Popen

    def reject_dcc(*_args, **_kwargs):
        raise AssertionError("host-binding-only regression attempted to start a child process")

    try:
        runner.subprocess.Popen = reject_dcc
        native = runner.resolve_host_context("arm64", 0)
        translated = runner.resolve_host_context("x86_64", 1)
        runner.validate_host_binding(receipt_host, native)
        runner.validate_host_binding(receipt_host, translated)
        fail(lambda: runner.resolve_host_context("arm64", 1), "arm64 Rosetta execution")
        fail(lambda: runner.validate_host_binding(receipt_host, {
            "nativeArchitecture": "x86_64", "executionArchitecture": "x86_64", "translation": "native"
        }), "wrong native host")
        fail(lambda: runner.validate_host_binding(receipt_host, {
            "nativeArchitecture": "arm64", "executionArchitecture": "arm64", "translation": "Rosetta"
        }), "wrong translated execution")
        return {"native": native, "translated": translated, "dccStarts": 0}
    finally:
        runner.subprocess.Popen = original_popen


def api_compatibility_zero_dcc() -> dict:
    original_popen = runner.subprocess.Popen

    def reject_dcc(*_args, **_kwargs):
        raise AssertionError("API-compatibility regression attempted to start a child process")

    class FakeMesh:
        def __init__(self, corrected: bool):
            self.corrected = corrected
            self.validate_calls: list[dict] = []
            self.update_calls: list[dict] = []

        def validate(self, **kwargs):
            self.validate_calls.append(kwargs)
            return self.corrected

        def update(self, **kwargs):
            self.update_calls.append(kwargs)

    try:
        runner.subprocess.Popen = reject_dcc
        spec = child.build_scene_spec(ROOT)
        mesh_components = [item for item in spec["scene"]["components"] if item["kind"] != "box"]
        results = []
        for component in mesh_components:
            vertices, faces = child.source_mesh_for(component, spec["lowering"])
            results.append(child.validate_authored_topology(vertices, faces, component["id"]))
        if not mesh_components or any(not item["closed"] for item in results):
            raise AssertionError("authored mesh topology coverage missing")
        vertices, faces = child.source_mesh_for(mesh_components[0], spec["lowering"])
        fail(lambda: child.validate_authored_topology(vertices, faces[:-1], "open-mesh"), "open topology")
        repeated = list(faces)
        repeated[0] = (repeated[0][0], repeated[0][0], *repeated[0][2:])
        fail(lambda: child.validate_authored_topology(vertices, repeated, "repeated-index"), "repeated face index")
        valid_mesh = FakeMesh(False)
        child.validate_blender_mesh(valid_mesh, "valid")
        if valid_mesh.validate_calls != [{"verbose": False, "clean_customdata": True}] or valid_mesh.update_calls != [{"calc_edges": True}]:
            raise AssertionError("Mesh.validate/update API contract drift")
        fail(lambda: child.validate_blender_mesh(FakeMesh(True), "corrected"), "Mesh.validate correction")
        if ".is_valid" in (SOURCE / runner.CHILD_NAME).read_text(encoding="utf-8"):
            raise AssertionError("unsupported Blender Mesh.is_valid access remains")
        targets = child.registration_targets(spec["scene"], spec["lowering"])
        if (targets["groundPivotSource"] != [768.0, 896.0] or
                targets["preOffsetCameraCenter"] != [768.0, 768.0] or
                targets["frontageSocketSource"] != [896.0, 704.0] or
                targets["tolerancePixels"] != 0.001):
            raise AssertionError("authoritative registration target binding drift")
        aliased_scene = json.loads(json.dumps(spec["scene"]))
        aliased_scene["registration"]["groundPivotSource"] = [768, 768]
        fail(lambda: child.registration_targets(aliased_scene, spec["lowering"]), "pre-offset center as final pivot")
        return {"meshComponents": len(mesh_components), "topologyChecks": len(results),
                "meshValidateSemantics": "true-means-corrected-and-rejected",
                "groundPivotSource": targets["groundPivotSource"],
                "preOffsetCameraCenter": targets["preOffsetCameraCenter"], "dccStarts": 0}
    finally:
        runner.subprocess.Popen = original_popen


def camera_bridge_zero_dcc() -> dict:
    original_popen = runner.subprocess.Popen

    def reject_dcc(*_args, **_kwargs):
        raise AssertionError("camera-bridge regression attempted to start a child process")

    try:
        runner.subprocess.Popen = reject_dcc
        spec = child.build_scene_spec(ROOT)
        lowering, bridge = spec["lowering"], spec["bridge"]
        child.validate_bridge_binding(lowering, bridge)
        registration = lowering["registration"]
        tolerance = float(lowering["camera"]["registrationTolerancePixels"])

        def delta(actual, expected):
            return max(abs(float(actual[index]) - float(expected[index])) for index in range(2))

        proofs = {
            "origin": (registration["originCitySim"], registration["originSource"]),
            "pivot": (registration["pivotCitySim"], registration["pivotSource"]),
            "northSocket": (registration["northSocketCitySim"], registration["northSocketSource"]),
        }
        for index, point in enumerate(registration["footprintCitySimXYZ"]):
            proofs[f"footprint-{index}"] = (point, registration["footprintSource"][index])
        deltas = {name: delta(child.project_bridge_citysim(point, lowering), expected)
                  for name, (point, expected) in proofs.items()}
        if any(value > tolerance for value in deltas.values()):
            raise AssertionError(f"camera bridge projection drift: {deltas}")
        if (registration["originSource"] != [768, 768] or registration["pivotSource"] != [768, 896] or
                registration["northSocketSource"] != [896, 704] or tolerance != 0.001):
            raise AssertionError("camera bridge frozen targets drift")
        mutated = json.loads(json.dumps(lowering))
        mutated["camera"]["shift"][1] = 0.25
        fail(lambda: child.validate_bridge_binding(mutated, bridge), "variant-specific camera shift")

        def dotted_name(node) -> str:
            if isinstance(node, ast.Name):
                return node.id
            if isinstance(node, ast.Attribute):
                prefix = dotted_name(node.value)
                return f"{prefix}.{node.attr}" if prefix else node.attr
            return ""

        tree = ast.parse(inspect.getsource(child.configure_camera))
        function = tree.body[0]
        if not isinstance(function, ast.FunctionDef):
            raise AssertionError("camera configuration AST unavailable")
        camera_assignments = [node.lineno for node in function.body if isinstance(node, ast.Assign) and
                              any(dotted_name(target) == "bpy.context.scene.camera" for target in node.targets)]
        view_updates = [node.lineno for node in function.body if isinstance(node, ast.Expr) and
                        isinstance(node.value, ast.Call) and dotted_name(node.value.func) == "bpy.context.view_layer.update"]
        project_definitions = [node.lineno for node in function.body if isinstance(node, ast.FunctionDef) and node.name == "project"]
        if (len(camera_assignments) != 1 or len(view_updates) != 1 or len(project_definitions) != 1 or
                not camera_assignments[0] < view_updates[0] < project_definitions[0]):
            raise AssertionError("view-layer update must follow camera assignment and precede projection")
        return {"bridgePath": lowering["coordinateBridge"]["authorityPath"],
                "bridgeSHA256": lowering["coordinateBridge"]["authoritySHA256"],
                "projectionCount": len(proofs), "maximumDeltaPixels": max(deltas.values()),
                "viewLayerUpdateBeforeProjection": True, "dccStarts": 0}
    finally:
        runner.subprocess.Popen = original_popen


def fixture_documents(directory: Path, output: Path, current_head: str) -> tuple[Path, Path, Path]:
    schedule_path, grant_path, receipt_path = directory / "schedule.json", directory / "grant.json", directory / "receipt.json"
    launcher = ROOT / runner.SOURCE_ROOT / "launch_residential_l01_process_a.py"
    child_path = ROOT / runner.SOURCE_ROOT / runner.CHILD_NAME
    lowering = ROOT / runner.SOURCE_ROOT / runner.LOWERING_NAME
    schedule = {
        "schema": 2, "task": "PLAY-090", "routeId": runner.ROUTE_ID, "routeSHA256": runner.ROUTE_SHA256,
        "slot": "north:A", "direction": "north", "process": "A", "claimSHA256": runner.CLAIM_SHA256,
        "workerHead": current_head, "schedulePath": "<fixture>/schedule.json", "grantPath": "<fixture>/grant.json",
        "processReceiptPath": "<fixture>/receipt.json", "attemptMarkerPath": "<fixture>/attempt.json",
        "orchestratorPath": f"{runner.SOURCE_ROOT}/launch_residential_l01_process_a.py", "orchestratorSHA256": sha_file(launcher),
        "childPath": f"{runner.SOURCE_ROOT}/{runner.CHILD_NAME}", "childSHA256": sha_file(child_path),
        "loweringPath": f"{runner.SOURCE_ROOT}/{runner.LOWERING_NAME}", "loweringSHA256": sha_file(lowering),
        "outputRoot": "<fixture>/output", "maximumChildStarts": 1, "blenderPath": runner.BLENDER,
        "blenderSHA256": runner.BLENDER_SHA256, "sourceAuthority": False, "productionSelected": False,
    }
    schedule_bytes = write_json(schedule_path, schedule)
    grant = {"schema": 2, "grantId": "north:A", "scheduleSHA256": sha_bytes(schedule_bytes), "workerHead": current_head,
             "maximumChildStarts": 1, "consumed": False, "sourceAuthority": False, "productionSelected": False}
    write_json(grant_path, grant)
    receipt = {"schema": 2, "kind": "integration-process-receipt", "task": "PLAY-090", "routeId": runner.ROUTE_ID,
               "schedulePath": "<fixture>/schedule.json", "scheduleSHA256": sha_bytes(schedule_bytes), "grantId": "north:A",
               "workerHead": current_head, "attemptMarkerPath": "<fixture>/attempt.json", "outputRoot": "<fixture>/output",
               "maximumChildStarts": 1, "sourceAuthority": False, "productionSelected": False}
    write_json(receipt_path, receipt)
    if output.exists():
        raise AssertionError("fixture output must begin absent")
    return schedule_path, grant_path, receipt_path


def adversaries(base: Path, current_head: str) -> int:
    directory, output = base / "authority", base / "output"
    directory.mkdir(mode=0o700, parents=True)
    schedule, grant, receipt = fixture_documents(directory, output, current_head)
    originals = {path: path.read_bytes() for path in (schedule, grant, receipt)}
    cases: list[str] = []
    def check(label: str, target: Path, mutate) -> None:
        for path, payload in originals.items():
            path.write_bytes(payload)
        value = json.loads(target.read_text())
        mutate(value)
        target.write_bytes(runner.pretty_bytes(value))
        fail(lambda: runner.validate_documents(ROOT, runner.validate_contract(ROOT, CONTRACT), str(schedule), str(grant), str(receipt), str(output), True), label)
        cases.append(label)
    check("wrong route", schedule, lambda value: value.__setitem__("routeId", "wrong"))
    check("wrong head", schedule, lambda value: value.__setitem__("workerHead", "0" * 40))
    check("wrong output", schedule, lambda value: value.__setitem__("outputRoot", "/tmp/escape"))
    check("wrong Blender", schedule, lambda value: value.__setitem__("blenderPath", "/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender"))
    check("wrong child hash", schedule, lambda value: value.__setitem__("childSHA256", "0" * 64))
    check("multi child", schedule, lambda value: value.__setitem__("maximumChildStarts", 2))
    check("consumed grant", grant, lambda value: value.__setitem__("consumed", True))
    check("receipt drift", receipt, lambda value: value.__setitem__("outputRoot", "docs/production/evidence/PLAY-090/residential-l01-variant1-process-a"))
    for path, payload in originals.items():
        path.write_bytes(payload)
    fail(lambda: child.validate_launch(argparse.Namespace(integration_direct=False, runtime_replay=True,
         repository_root=runner.WORKTREE, contract=CONTRACT, schedule_path=str(schedule), grant_path=str(grant),
         process_receipt_path=str(receipt), attempt_marker_path=str(base / "attempt.json"), output_root=str(output))), "direct child")
    cases.append("direct child")
    return len(cases)


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else b if pb <= pc else c


def decode_rgba8_png(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError("PNG signature missing")
    offset, width, height, payloads = 8, 0, 0, []
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind, payload = data[offset + 4:offset + 8], data[offset + 8:offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if (depth, color_type, compression, filtering, interlace) != (8, 6, 0, 0, 0):
                raise AssertionError(f"expected noninterlaced RGBA8 PNG, got {(depth, color_type, interlace)}")
        elif kind == b"IDAT":
            payloads.append(payload)
        elif kind == b"IEND":
            break
    if not width or not height or not payloads:
        raise AssertionError("PNG structure incomplete")
    raw = zlib.decompress(b"".join(payloads))
    stride, prior, decoded, cursor = width * 4, bytearray(width * 4), bytearray(), 0
    for _ in range(height):
        filter_type, cursor = raw[cursor], cursor + 1
        scan = bytearray(raw[cursor:cursor + stride])
        cursor += stride
        for index in range(stride):
            left = scan[index - 4] if index >= 4 else 0
            up = prior[index]
            upper_left = prior[index - 4] if index >= 4 else 0
            if filter_type == 1:
                scan[index] = (scan[index] + left) & 255
            elif filter_type == 2:
                scan[index] = (scan[index] + up) & 255
            elif filter_type == 3:
                scan[index] = (scan[index] + ((left + up) // 2)) & 255
            elif filter_type == 4:
                scan[index] = (scan[index] + paeth(left, up, upper_left)) & 255
            elif filter_type != 0:
                raise AssertionError(f"unsupported PNG filter: {filter_type}")
        decoded.extend(scan)
        prior = scan
    return width, height, bytes(decoded)


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", binascii.crc32(kind + payload) & 0xFFFFFFFF)


def encode_rgba8_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    rows = b"".join(b"\x00" + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
    payload = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    payload += png_chunk(b"IDAT", zlib.compress(rows, 9)) + png_chunk(b"IEND", b"")
    path.write_bytes(payload)


def downsample_8x(rgba: bytes, width: int, height: int, grayscale: bool = False) -> tuple[int, int, bytes]:
    if width % 8 or height % 8:
        raise AssertionError("source dimensions are not literal-192 divisible")
    result = bytearray()
    for oy in range(height // 8):
        for ox in range(width // 8):
            sums = [0, 0, 0, 0]
            for sy in range(8):
                for sx in range(8):
                    index = ((oy * 8 + sy) * width + ox * 8 + sx) * 4
                    for channel in range(4):
                        sums[channel] += rgba[index + channel]
            pixel = [int((value + 32) // 64) for value in sums]
            if grayscale:
                luminance = int(round(0.2126 * pixel[0] + 0.7152 * pixel[1] + 0.0722 * pixel[2]))
                pixel[:3] = [luminance, luminance, luminance]
            result.extend(pixel)
    return width // 8, height // 8, bytes(result)


def contact_sheet(left: bytes, right: bytes, width: int, height: int) -> bytes:
    result = bytearray()
    row = width * 4
    for y in range(height):
        result.extend(left[y * row:(y + 1) * row])
        result.extend(right[y * row:(y + 1) * row])
    return bytes(result)


def image_metrics(width: int, height: int, rgba: bytes) -> dict:
    occupied, xs, ys, colors = 0, [], [], set()
    for index in range(0, len(rgba), 4):
        alpha = rgba[index + 3]
        if alpha:
            pixel = index // 4
            occupied += 1
            xs.append(pixel % width)
            ys.append(pixel // width)
            if alpha >= 128:
                colors.add(rgba[index:index + 3])
    if occupied < 2000 or occupied >= width * height or len(colors) < 8:
        raise AssertionError(f"render is blank or degenerate: occupied={occupied} colors={len(colors)}")
    return {"width": width, "height": height, "format": "RGBA8", "occupiedPixels": occupied,
            "transparentPixels": width * height - occupied, "occupiedBounds": [min(xs), min(ys), max(xs) + 1, max(ys) + 1],
            "opaqueColorCountMinimum": len(colors), "decodedRGBASHA256": sha_bytes(rgba)}


def run_replay(base: Path, label: str, current_head: str) -> dict:
    process_root, authority, output = base / label, base / label / "authority", base / label / "output"
    authority.mkdir(mode=0o700, parents=True)
    schedule, grant, receipt = fixture_documents(authority, output, current_head)
    run = runner.execute_one(ROOT, CONTRACT, str(schedule), str(grant), str(receipt), str(output), fixture=True)
    width, height, rgba = decode_rgba8_png(output / "raw.png")
    return {"label": label, "root": process_root, "output": output, "run": run, "width": width, "height": height,
            "rgba": rgba, "metrics": image_metrics(width, height, rgba)}


def write_panels(base: Path, first: dict, second: dict) -> dict:
    panels = base / "panels"
    panels.mkdir(mode=0o700)
    width, height, color_a = downsample_8x(first["rgba"], first["width"], first["height"])
    _, _, color_b = downsample_8x(second["rgba"], second["width"], second["height"])
    _, _, gray_a = downsample_8x(first["rgba"], first["width"], first["height"], True)
    _, _, gray_b = downsample_8x(second["rgba"], second["width"], second["height"], True)
    paths = {
        "aColor": panels / "replay-a-literal-192-color.png", "bColor": panels / "replay-b-literal-192-color.png",
        "aGrayscale": panels / "replay-a-literal-192-grayscale.png", "bGrayscale": panels / "replay-b-literal-192-grayscale.png",
        "colorAB": panels / "replay-ab-literal-192-color.png", "grayscaleAB": panels / "replay-ab-literal-192-grayscale.png",
    }
    encode_rgba8_png(paths["aColor"], width, height, color_a)
    encode_rgba8_png(paths["bColor"], width, height, color_b)
    encode_rgba8_png(paths["aGrayscale"], width, height, gray_a)
    encode_rgba8_png(paths["bGrayscale"], width, height, gray_b)
    encode_rgba8_png(paths["colorAB"], width * 2, height, contact_sheet(color_a, color_b, width, height))
    encode_rgba8_png(paths["grayscaleAB"], width * 2, height, contact_sheet(gray_a, gray_b, width, height))
    return {name: {"path": str(path), "sha256": sha_file(path)} for name, path in paths.items()}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bootstrap-only", action="store_true")
    parser.add_argument("--host-binding-only", action="store_true")
    parser.add_argument("--api-compatibility-only", action="store_true")
    parser.add_argument("--camera-bridge-only", action="store_true")
    parser.add_argument("--assert-zero-dcc", action="store_true")
    parser.add_argument("--contained-runtime-replay", action="store_true")
    parser.add_argument("--assert-nonblank", action="store_true")
    parser.add_argument("--output-root")
    args = parser.parse_args(argv)
    if args.bootstrap_only:
        if (not args.assert_zero_dcc or args.host_binding_only or args.api_compatibility_only or args.camera_bridge_only or
                args.contained_runtime_replay or
                args.assert_nonblank or args.output_root is not None):
            raise SystemExit("bootstrap-only requires zero-DCC assertion and no replay arguments")
        result = bootstrap_without_ambient_source()
        print(f"PASS PLAY-090 child-bootstrap adjacentLauncher={result['launcher']} dccStarts=0")
        return 0
    if args.host_binding_only:
        if (not args.assert_zero_dcc or args.api_compatibility_only or args.camera_bridge_only or args.contained_runtime_replay or
                args.assert_nonblank or args.output_root is not None):
            raise SystemExit("host-binding-only requires zero-DCC assertion and no replay arguments")
        result = host_binding_zero_dcc()
        print(f"PASS PLAY-090 host-binding native={result['native']} translated={result['translated']} dccStarts=0")
        return 0
    if args.api_compatibility_only:
        if (not args.assert_zero_dcc or args.camera_bridge_only or args.contained_runtime_replay or
                args.assert_nonblank or args.output_root is not None):
            raise SystemExit("API-compatibility-only requires zero-DCC assertion and no replay arguments")
        result = api_compatibility_zero_dcc()
        print(f"PASS PLAY-090 Blender-4.5 API compatibility meshComponents={result['meshComponents']} topologyChecks={result['topologyChecks']} groundPivot={result['groundPivotSource']} preOffsetCenter={result['preOffsetCameraCenter']} dccStarts=0")
        return 0
    if args.camera_bridge_only:
        if not args.assert_zero_dcc or args.contained_runtime_replay or args.assert_nonblank or args.output_root is not None:
            raise SystemExit("camera-bridge-only requires zero-DCC assertion and no replay arguments")
        result = camera_bridge_zero_dcc()
        print(f"PASS PLAY-090 camera-bridge projections={result['projectionCount']} maximumDeltaPixels={result['maximumDeltaPixels']:.9f} bridgeSHA256={result['bridgeSHA256']} dccStarts=0")
        return 0
    if args.assert_zero_dcc:
        raise SystemExit("zero-DCC assertion is valid only in a focused validation mode")
    if not args.contained_runtime_replay or not args.assert_nonblank:
        raise SystemExit("contained runtime replay and nonblank assertion are required")
    if args.output_root is None:
        raise SystemExit("contained runtime replay requires an output root")
    replay_root = runner.safe_private_path(args.output_root, allow_root=True)
    if replay_root != runner.RUNTIME_REPLAY_ROOT:
        raise ValueError("focused replay root mismatch")
    if replay_root.exists():
        if replay_root.is_symlink() or replay_root != Path("/private/tmp/play090-residential-north-runtime-repair-v2"):
            raise ValueError("unsafe disposable replay root")
        shutil.rmtree(replay_root)
    replay_root.mkdir(mode=0o700)
    current_head = runner._git(ROOT, "rev-parse", "HEAD").decode().strip()
    route = runner.verify_route(ROOT)
    runner.validate_contract(ROOT, CONTRACT)
    runner.verify_blender(ROOT)
    adversary_count = adversaries(replay_root / "adversarial", current_head)
    first = run_replay(replay_root, "replay-a", current_head)
    second = run_replay(replay_root, "replay-b", current_head)
    if first["metrics"] != second["metrics"] or first["rgba"] != second["rgba"]:
        raise AssertionError("decoded RGBA replay mismatch")
    if sha_file(first["output"] / "raw.png") != sha_file(second["output"] / "raw.png"):
        raise AssertionError("PNG container replay mismatch")
    receipt_hashes = {}
    for name in DETERMINISTIC_RECEIPTS:
        if (first["output"] / name).read_bytes() != (second["output"] / name).read_bytes():
            raise AssertionError(f"deterministic receipt mismatch: {name}")
        receipt_hashes[name] = sha_file(first["output"] / name)
    manifest = json.loads((first["output"] / "OBJECT-MANIFEST.json").read_text())
    registration = json.loads((first["output"] / "GROUND-REGISTRATION.json").read_text())
    if manifest["authoredComponentCount"] != 19 or len(manifest["objects"]) != 19 or not all(item["closed"] for item in manifest["objects"]):
        raise AssertionError("19-component closed lowering proof failed")
    panels = write_panels(replay_root, first, second)
    summary = {
        "schema": 1, "task": "PLAY-090", "stage": "north-runtime-repair", "result": "PASS",
        "proofLevel": "deterministic_replay", "routeId": runner.ROUTE_ID, "routeSHA256": runner.ROUTE_SHA256,
        "carrierCommit": runner.CARRIER_COMMIT, "workerInputHead": current_head,
        "blender": {"path": runner.BLENDER, "sha256": runner.BLENDER_SHA256, "architecture": "x86_64", "translation": "Rosetta", "version": "4.5.12 LTS", "buildHash": "84afd5f785f7"},
        "execution": {"replayRoot": str(replay_root), "freshProcesses": 2, "maximumConcurrentDCC": 1,
                      "queueOrder": ["replay-a", "replay-b"], "childStarts": 2, "perAttemptMaximumChildStarts": 1,
                      "adversaries": adversary_count,
                      "durationsSeconds": {"replay-a": first["run"]["result"]["durationSeconds"], "replay-b": second["run"]["result"]["durationSeconds"]},
                      "pids": {"replay-a": first["run"]["result"]["pid"], "replay-b": second["run"]["result"]["pid"]}},
        "render": {"rawPNGContainerSHA256": sha_file(first["output"] / "raw.png"), **first["metrics"]},
        "geometry": {"authoredComponentCount": 19, "componentIDs": [item["id"] for item in manifest["objects"]],
                     "allClosed": True, "materialBindingCount": len({item["materialID"] for item in manifest["objects"]}),
                     "cameraCount": 1, "lightCount": 2, "transparentShadowReceiverCount": 1},
        "registration": registration, "deterministicReceiptHashes": receipt_hashes, "panels": panels,
        "governedProductionRootWrites": 0, "sourceAuthority": False, "productionSelected": False,
        "visualAcceptance": False, "independentAcceptanceRequired": True,
    }
    handoff = {"schema": 1, "task": "PLAY-090", "disposition": "runtime_repair_candidate",
               "routeId": runner.ROUTE_ID, "routeSHA256": runner.ROUTE_SHA256, "workerInputHead": current_head,
               "evidence": "RUNTIME-REPAIR.json", "runtimeReplayRoot": str(replay_root),
               "focusedGate": "PASS", "sourceAuthority": False, "productionSelected": False,
               "independentAcceptanceRequired": True,
               "stopCondition": "Integration independently reruns and decides whether a later one-shot production schedule may be published."}
    EVIDENCE.mkdir(mode=0o700, parents=True, exist_ok=True)
    write_json(EVIDENCE / "RUNTIME-REPAIR.json", summary)
    write_json(EVIDENCE / "HANDOFF.json", handoff)
    print(f"PASS PLAY-090 runtime-repair freshProcesses=2 adversaries={adversary_count} components=19 occupiedPixels={first['metrics']['occupiedPixels']} decodedRGBA={first['metrics']['decodedRGBASHA256']} durations={first['run']['result']['durationSeconds']},{second['run']['result']['durationSeconds']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
