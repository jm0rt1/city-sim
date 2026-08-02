"""Static reference proof for North v14; never starts Blender or emits pixels."""
from __future__ import annotations

import ast
import copy
import importlib.util
import json
import os
import tempfile
import hashlib
import shutil
import atexit
from pathlib import Path
from typing import Any, Callable

PROCESS = Path(__file__).resolve().parent
ROOT = PROCESS.parents[6]
SOURCE_ROOT = Path("Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14")


def module(path: Path, name: str) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


LAUNCHER = module(PROCESS / "launch_north_process_a.py", "north_v14_reference_launcher_test")
CHILD = module(PROCESS / "render_north_process_a_child.py", "north_v14_reference_child_test")
ADVERSARIES = 0
_ISOLATED_ROOTS: list[Path] = []


def isolated_root_if_needed(root: Path, contract: dict[str, Any]) -> Path:
    """Run the proof against a fresh checkout-shaped root when history retains output."""
    output = root / contract["outputRoot"]
    if not output.exists() and not output.is_symlink():
        return root
    parent = Path(tempfile.mkdtemp(prefix="north-v14-binding-root-", dir="/private/tmp"))
    fixture = parent / "city-sim"
    source = root / SOURCE_ROOT

    def ignore(directory: str, names: list[str]) -> set[str]:
        return {name for name in names if name in {"process-a-output", "process-a-failure-v1", "__pycache__"}}

    shutil.copytree(source, fixture / SOURCE_ROOT, ignore=ignore)
    shutil.copy2(root / ".git", fixture / ".git")
    _ISOLATED_ROOTS.append(parent)
    return fixture


def _cleanup_isolated_roots() -> None:
    for path in _ISOLATED_ROOTS:
        shutil.rmtree(path, ignore_errors=True)


atexit.register(_cleanup_isolated_roots)


def load(name: str) -> dict[str, Any]:
    return json.loads((PROCESS / name).read_text())


def write_json(path: Path, value: Any) -> None:
    path.write_bytes(LAUNCHER.canonical(value))


def rejects(fn: Callable[[], Any]) -> None:
    global ADVERSARIES
    ADVERSARIES += 1
    try:
        fn()
    except (AssertionError, KeyError, OSError, RuntimeError, TypeError, ValueError):
        return
    raise AssertionError("adversary unexpectedly passed")


def direct_documents(
    directory: Path,
    contract: dict[str, Any],
    schedule_mutation: Callable[[dict[str, Any]], None] | None = None,
    grant_mutation: Callable[[dict[str, Any]], None] | None = None,
    session_mutation: Callable[[dict[str, Any]], None] | None = None,
) -> tuple[Path, Path, Path]:
    directory.mkdir(parents=True, exist_ok=True)
    schedule = {
        "schema": 1,
        "task": "PLAY-027",
        "batch": contract["batch"],
        "direction": "north",
        "process": "A",
        "slot": "north:A",
        "maximumChildStarts": 1,
        "contractSHA256": LAUNCHER.sha256(ROOT / LAUNCHER.CONTRACT_PATH),
        "launcherSHA256": LAUNCHER.sha256(ROOT / LAUNCHER.LAUNCHER_PATH),
        "childSHA256": LAUNCHER.sha256(ROOT / LAUNCHER.CHILD_PATH),
        "frozenInputs": copy.deepcopy(contract["frozenInputs"]),
        "outputRoot": contract["outputRoot"],
    }
    if schedule_mutation:
        schedule_mutation(schedule)
    schedule_path = directory / "SCHEDULE.json"
    write_json(schedule_path, schedule)
    session_id = "north-v14-static-reference-session"
    grant = {
        "schema": 1,
        "grantId": "north:A",
        "direction": "north",
        "process": "A",
        "maximumChildStarts": 1,
        "scheduleSHA256": LAUNCHER.sha256(schedule_path),
        "outputRoot": contract["outputRoot"],
        "sessionId": session_id,
    }
    if grant_mutation:
        grant_mutation(grant)
    grant_path = directory / "GRANT.json"
    write_json(grant_path, grant)
    session = {
        "schema": 1,
        "sessionId": session_id,
        "expectedWorkerHead": LAUNCHER.git_head(ROOT),
        "scheduleSHA256": LAUNCHER.sha256(schedule_path),
        "grantSHA256": LAUNCHER.sha256(grant_path),
        "outputRoot": contract["outputRoot"],
        "state": "integration-issued",
    }
    if session_mutation:
        session_mutation(session)
    session_path = directory / "SESSION.json"
    write_json(session_path, session)
    return schedule_path, grant_path, session_path


def assert_static_source_boundaries() -> None:
    launcher_tree = ast.parse((PROCESS / "launch_north_process_a.py").read_text())
    child_tree = ast.parse((PROCESS / "render_north_process_a_child.py").read_text())
    launcher_popen = [
        node for node in ast.walk(launcher_tree)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "Popen"
    ]
    assert len(launcher_popen) == 1
    child_imports = [node for node in ast.walk(child_tree) if isinstance(node, (ast.Import, ast.ImportFrom))]
    assert sum(any(alias.name == "bpy" for alias in node.names) for node in child_imports if isinstance(node, ast.Import)) == 1
    child_source = (PROCESS / "render_north_process_a_child.py").read_text()
    assert "primitive_cube_add" not in child_source
    assert "subprocess" not in child_source
    assert "generic" not in {builder for builder in CHILD.RECTANGULAR_BUILDERS.values()}
    forbidden = ("ImageGen", "imagegen", "normalizer", "Normalization", "PLAY-079", "PLAY-080", "PLAY-081", "Package.swift", "Rendering/")
    assert not any(value in child_source for value in forbidden)


def assert_blender_binding(contract: dict[str, Any]) -> None:
    expected = {
        "executable": "/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender",
        "sha256": "0fa2ab6500e41bfd8114485b218a1e4aebf15b3d8cea90dc8398535291061506",
        "architecture": "arm64",
        "version": "4.5.12 LTS",
        "buildHash": "84afd5f785f7",
        "officialImageSHA256": "f4afdca92c56a9e231e45226445e6750879a70a0d2322cee80d82ce021a99fb0",
        "factoryStartup": True,
        "autoexecDisabled": True,
    }
    assert contract["blender"] == expected
    assert LAUNCHER.resolve_blender_binding(contract) == Path(expected["executable"])
    assert Path(expected["executable"]).is_file()
    assert hashlib.sha256(Path(expected["executable"]).read_bytes()).hexdigest() == expected["sha256"]


def assert_mesh_topology(packet: dict[str, Any]) -> dict[str, Any]:
    mesh_set = CHILD.build_mesh_specs(packet["manifest"])
    assert len(mesh_set["solidSpecs"]) == 96
    assert mesh_set["voidIDs"] == ["v14-monumental-portal-void::empty-aperture"]
    assert mesh_set["closedOutwardObjects"] == 95 and mesh_set["openTwoSidedObjects"] == 1
    assert len(mesh_set["orientationReports"]) == 96
    assert all(item["passes"] and item["inwardFaces"] == 0 for item in mesh_set["orientationReports"])
    assert set(mesh_set["supportedKinds"]) == {item["geometryKind"] for item in packet["manifest"]["objects"]}
    assert all(spec["builder"] != "generic" for spec in mesh_set["solidSpecs"])
    assert all(len(spec["vertices"]) >= 4 and len(spec["faces"]) >= 1 for spec in mesh_set["solidSpecs"])

    by_id = {spec["id"]: spec for spec in mesh_set["solidSpecs"]}
    frame = by_id["v14-monumental-portal-void::frame"]
    assert frame["builder"] == "three-part-open-portal-frame" and len(frame["vertices"]) == 24
    frame_item = next(item for item in packet["manifest"]["objects"] if item["id"] == frame["id"])
    bounds = frame_item["boundsXYZ"]
    for y_fraction in (0.25, 0.5, 0.75):
        for z_fraction in (0.2, 0.4, 0.6):
            sample_y = bounds[0][0] + (bounds[1][0] - bounds[0][0]) * y_fraction
            sample_z = bounds[0][1] + (bounds[1][1] - bounds[0][1]) * z_fraction
            for face in frame["faces"]:
                ys = [frame["vertices"][index][1] for index in face]
                zs = [frame["vertices"][index][2] for index in face]
                assert not (min(ys) < sample_y < max(ys) and min(zs) < sample_z < max(zs))

    pipes = [spec for spec in mesh_set["solidSpecs"] if spec["geometryKind"] == "pipe-segment"]
    trusses = [spec for spec in mesh_set["solidSpecs"] if spec["geometryKind"] in {"truss-chord", "truss-diagonal"}]
    assert len(pipes) == 6 and all(len(spec["vertices"]) == 24 and len(spec["faces"]) == 14 for spec in pipes)
    assert len(trusses) == 12 and all(spec["metadata"]["axisStart"] != spec["metadata"]["axisEnd"] for spec in trusses)
    assert all(spec["builder"].startswith("endpoint-oriented") for spec in pipes + trusses)
    shadows = [spec for spec in mesh_set["solidSpecs"] if spec["geometryKind"] == "contact-shadow"]
    assert len(shadows) == 1 and shadows[0]["metadata"]["shadowCatcher"] is True
    assert CHILD.bridge([0, 0, -28]) == [-28, 0, 0]
    assert CHILD.bridge([28, 0, 28]) == [28, 28, 0]
    return mesh_set


def main() -> None:
    global ROOT
    assert ROOT.name == "city-sim"
    contract = load("EXECUTION-CONTRACT.json")
    ROOT = isolated_root_if_needed(ROOT, contract)
    assert contract["direction"] == "north" and contract["process"] == "A"
    assert_blender_binding(contract)
    runner = load("RUNNER-CONTRACT.json")
    LAUNCHER.validate_runner_binding_data(contract, runner)
    assert contract["processEnvelope"]["maximumChildStarts"] == 1
    assert contract["outputRoot"].endswith("/process-a-output")
    proof_a = LAUNCHER.validate_contract(ROOT, contract)
    proof_b = LAUNCHER.validate_contract(ROOT, copy.deepcopy(contract))
    assert LAUNCHER.canonical(proof_a["packet"]) == LAUNCHER.canonical(proof_b["packet"])
    assert proof_a["packet"]["report"]["componentCount"] == 33
    assert proof_a["packet"]["report"]["objectCount"] == 97
    assert proof_a["packet"]["report"]["registration"]["socketSource"] == [896, 704]
    assert proof_a["packet"]["report"]["socketContinuity"]["socketConnected"] is True
    packet = CHILD.construct_semantic_geometry(ROOT, contract)
    mesh_set = assert_mesh_topology(packet)
    scene = json.loads((ROOT / contract["frozenInputs"]["scene"]["path"]).read_text())
    lighting = json.loads((ROOT / contract["frozenInputs"]["lighting"]["path"]).read_text())
    render_profile = CHILD.render_profile(contract, lighting)
    assert render_profile == {
        "engine": "CYCLES", "device": "CPU", "samples": 64, "seed": 17,
        "threadsMode": "FIXED", "threads": 1, "adaptiveSampling": False,
        "denoising": False, "motionBlur": False, "transparentFilm": True,
        "resolution": [1536, 1024], "resolutionPercentage": 100,
        "pixelAspect": [1, 1],
        "image": {"fileFormat": "PNG", "colorMode": "RGBA", "colorDepth": "8", "compression": 15},
        "colorManagement": {"displayDevice": "sRGB", "viewTransform": "Standard", "look": "Medium High Contrast", "exposure": 0.0, "gamma": 1.0},
    }
    camera_profile = CHILD.camera_profile(scene)
    assert camera_profile["orthoScale"] == 237.5878601074218
    assert camera_profile["positionBlender"] == [96, 96, 101.24557426726288]
    assert camera_profile["targetBlender"] == [0, 0, 22.861902498201186]
    assert camera_profile["shiftX"] == 0 and camera_profile["shiftY"] == 1 / 12
    ground_projection = CHILD.ground_projection_report(scene)
    assert ground_projection["footprintSource"] == [[768.0, 640.0], [1024.0, 768.0], [768.0, 896.0], [512.0, 768.0]]
    assert ground_projection["pivotSource"] == [768.0, 896.0]
    assert ground_projection["socketSource"] == [896.0, 704.0]
    assert ground_projection["registrationLocked"] is True
    light_profile = CHILD.light_profile(lighting)
    assert light_profile["key"]["originBlender"] == [-80, -80, 120]
    assert light_profile["key"]["targetBlender"] == [0, 0, 16]
    assert light_profile["fill"]["originBlender"] == [72.0, 72.0, 70.0]
    assert light_profile["key"]["effectiveEnergyWatts"] == 54000.0
    assert light_profile["fill"]["effectiveEnergyWatts"] == 7200.0
    assert light_profile["lowering"] == {"keyEnergyScale": 12.0, "fillEnergyScale": 40.0}
    assert light_profile["key"]["distanceToTarget"] > 150.0
    assert light_profile["fill"]["distanceToTarget"] > 100.0
    assert abs(sum(value * value for value in light_profile["key"]["aimDirection"]) - 1.0) < 1.0e-9
    assert abs(sum(value * value for value in light_profile["fill"]["aimDirection"]) - 1.0) < 1.0e-9
    assert LAUNCHER.CHILD_START_COUNT == 0

    with tempfile.TemporaryDirectory(prefix="north-v14-reference-", dir="/private/tmp") as temporary:
        temporary_root = Path(temporary)
        schedule_path, grant_path, session_path = direct_documents(temporary_root / "positive-a", contract)
        documents = LAUNCHER.validate_direct_documents(ROOT, contract, schedule_path, grant_path, session_path)
        prepared = LAUNCHER.prepare_launch(ROOT, schedule_path, grant_path, session_path)
        schedule_b, grant_b, session_b = direct_documents(temporary_root / "positive-b", contract)
        documents_b = LAUNCHER.validate_direct_documents(ROOT, contract, schedule_b, grant_b, session_b)
        prepared_b = LAUNCHER.prepare_launch(ROOT, schedule_b, grant_b, session_b)
        assert {key: documents[key] for key in ("scheduleSHA256", "grantSHA256", "sessionSHA256")} == {key: documents_b[key] for key in ("scheduleSHA256", "grantSHA256", "sessionSHA256")}
        assert prepared["contract"] == prepared_b["contract"] and prepared["proof"]["packet"] == prepared_b["proof"]["packet"]
        assert prepared["outputRoot"] == ROOT / contract["outputRoot"]
        assert not prepared["outputRoot"].exists()
        assert prepared["command"][0] == contract["blender"]["executable"]
        assert prepared["command"].count("--python") == 1
        assert prepared["command"].count(str(ROOT / LAUNCHER.CHILD_PATH)) == 1
        for flag, path in (("--schedule", schedule_path), ("--grant", grant_path), ("--integration-session", session_path), ("--output-root", ROOT / contract["outputRoot"])):
            index = prepared["command"].index(flag)
            assert prepared["command"][index + 1] == str(path)
        assert prepared["environment"]["CITYSIM_PROCESS_A_SCHEDULE_SHA256"] == documents["scheduleSHA256"]
        assert prepared["environment"]["CITYSIM_PROCESS_A_GRANT_SHA256"] == documents["grantSHA256"]
        assert prepared["environment"]["CITYSIM_PROCESS_A_SESSION_SHA256"] == documents["sessionSHA256"]

        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-direction", contract, schedule_mutation=lambda value: value.__setitem__("direction", "east"))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-slot", contract, schedule_mutation=lambda value: value.__setitem__("slot", "north:B"))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-limit", contract, schedule_mutation=lambda value: value.__setitem__("maximumChildStarts", 2))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-child", contract, schedule_mutation=lambda value: value.__setitem__("childSHA256", "0" * 64))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-launcher", contract, schedule_mutation=lambda value: value.__setitem__("launcherSHA256", "0" * 64))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-input", contract, schedule_mutation=lambda value: value["frozenInputs"]["scene"].__setitem__("sha256", "0" * 64))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-schedule-root", contract, schedule_mutation=lambda value: value.__setitem__("outputRoot", "escape"))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-grant-direction", contract, grant_mutation=lambda value: value.__setitem__("direction", "east"))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-grant-limit", contract, grant_mutation=lambda value: value.__setitem__("maximumChildStarts", 2))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-grant-schedule", contract, grant_mutation=lambda value: value.__setitem__("scheduleSHA256", "0" * 64))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-session-head", contract, session_mutation=lambda value: value.__setitem__("expectedWorkerHead", "0" * 40))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-session-state", contract, session_mutation=lambda value: value.__setitem__("state", "consumed"))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "bad-session-grant", contract, session_mutation=lambda value: value.__setitem__("grantSHA256", "0" * 64))))
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, *direct_documents(temporary_root / "short-session", contract, session_mutation=lambda value: value.__setitem__("sessionId", "short"))))

        for label, mutation in (
            ("intel-path", lambda value: value.__setitem__("executable", "/Applications/Blender.app/Contents/MacOS/Blender")),
            ("wrong-hash", lambda value: value.__setitem__("sha256", "0" * 64)),
            ("wrong-architecture", lambda value: value.__setitem__("architecture", "x86_64")),
            ("missing-path", lambda value: value.__setitem__("executable", "/Applications/missing-blender")),
            ("wrong-version", lambda value: value.__setitem__("version", "4.5.11 LTS")),
            ("wrong-build", lambda value: value.__setitem__("buildHash", "0" * 12)),
            ("wrong-image", lambda value: value.__setitem__("officialImageSHA256", "0" * 64)),
        ):
            bad = copy.deepcopy(contract)
            mutation(bad["blender"])
            rejects(lambda bad=bad: LAUNCHER.validate_contract(ROOT, bad))
        for label, mutation in (
            ("runner-path", lambda value: value.__setitem__("path", "/Applications/Blender.app/Contents/MacOS/Blender")),
            ("runner-hash", lambda value: value.__setitem__("sha256", "0" * 64)),
            ("runner-architecture", lambda value: value.__setitem__("architecture", "x86_64")),
            ("runner-version", lambda value: value.__setitem__("version", "4.5.11 LTS")),
            ("runner-build", lambda value: value.__setitem__("buildHash", "0" * 12)),
            ("runner-image", lambda value: value.__setitem__("officialImageSHA256", "0" * 64)),
        ):
            bad_runner = copy.deepcopy(runner)
            mutation(bad_runner["blenderBinding"])
            rejects(lambda bad_runner=bad_runner: LAUNCHER.validate_runner_binding_data(contract, bad_runner))
        symlink_path = Path(tempfile.mkdtemp(prefix="blender-binding-", dir="/private/tmp")) / "Blender"
        symlink_path.symlink_to(Path(contract["blender"]["executable"]))
        bad = copy.deepcopy(contract)
        bad["blender"]["executable"] = str(symlink_path)
        rejects(lambda: LAUNCHER.validate_contract(ROOT, bad))
        bad = copy.deepcopy(contract)
        bad["blender"]["executable"] = "/Applications/Blender.app/Contents/MacOS/Blender"
        rejects(lambda: LAUNCHER.validate_contract(ROOT, bad))

        symlink = temporary_root / "schedule-symlink.json"
        symlink.symlink_to(schedule_path)
        rejects(lambda: LAUNCHER.validate_direct_documents(ROOT, contract, symlink, grant_path, session_path))
        rejects(lambda: LAUNCHER.main(["--repository-root", str(ROOT)]))
        rejects(lambda: LAUNCHER.main(["--repository-root", str(ROOT), "--zero-child", "--schedule", str(schedule_path)]))
        rejects(lambda: CHILD.main(["--repository-root", str(ROOT), "--contract", str(PROCESS / "EXECUTION-CONTRACT.json"), "--direction", "north", "--schedule", str(schedule_path), "--grant", str(grant_path), "--integration-session", str(session_path), "--output-root", str(ROOT / contract["outputRoot"])]))

        output = temporary_root / "exclusive-output"
        inode = LAUNCHER.create_exclusive_output_root(output)
        assert inode == output.stat().st_ino and output.is_dir()
        rejects(lambda: LAUNCHER.create_exclusive_output_root(output))
        CHILD.write_json_exclusive(output, "OBJECT-MANIFEST.json", {"status": "fixture"})
        rejects(lambda: CHILD.write_json_exclusive(output, "OBJECT-MANIFEST.json", {"status": "overwrite"}))
        rejects(lambda: CHILD.write_json_exclusive(output, "../escape.json", {}))

    bad_contract = copy.deepcopy(contract)
    bad_contract["frozenInputs"]["scene"]["sha256"] = "0" * 64
    rejects(lambda: LAUNCHER.validate_contract(ROOT, bad_contract))
    bad_contract = copy.deepcopy(contract)
    bad_contract["registration"]["socketBlender"] = [0, 0, -28]
    rejects(lambda: LAUNCHER.validate_contract(ROOT, bad_contract))
    bad_contract = copy.deepcopy(contract)
    bad_contract["cycles"]["threads"] = 2
    rejects(lambda: LAUNCHER.validate_contract(ROOT, bad_contract))
    bad_contract = copy.deepcopy(contract)
    bad_contract["allowedOutputs"].append("escape.bin")
    rejects(lambda: LAUNCHER.validate_contract(ROOT, bad_contract))
    bad_manifest = copy.deepcopy(packet["manifest"])
    bad_manifest["objects"][0]["geometryKind"] = "unknown-fallback-kind"
    rejects(lambda: CHILD.build_mesh_specs(bad_manifest))
    rejects(lambda: CHILD.validate_mesh_spec({"id": "degenerate", "vertices": [[0, 0, 0], [1, 0, 0], [2, 0, 0]], "faces": [[0, 1, 2]]}))

    assert_static_source_boundaries()
    assert ADVERSARIES >= 24
    assert not (ROOT / contract["outputRoot"]).exists()
    identity = {
        "status": "STATIC_REFERENCE_CANDIDATE",
        "executableBehavior": "UNPROVEN",
        "freshRoots": 2,
        "normalizedRoot": "<exclusive-temp-root>",
        "components": 33,
        "parameterizedObjects": 97,
        "solidMeshSpecs": len(mesh_set["solidSpecs"]),
        "voidSpecs": len(mesh_set["voidIDs"]),
        "closedOutwardObjects": mesh_set["closedOutwardObjects"],
        "openTwoSidedObjects": mesh_set["openTwoSidedObjects"],
        "childStarts": 0,
        "dccProcessCount": 0,
        "pixelWrites": 0,
        "fixtureOutputRootsCreated": 1,
        "governedOutputRootsCreated": 0,
        "adversaries": ADVERSARIES,
    }
    print(json.dumps(identity, sort_keys=True))


if __name__ == "__main__":
    main()
