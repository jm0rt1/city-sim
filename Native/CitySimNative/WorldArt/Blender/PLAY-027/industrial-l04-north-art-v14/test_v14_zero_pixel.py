"""Deterministic, zero-pixel v14 North registration/lowering proof."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("v14_lower", ROOT / "lower_v14_scene.py")
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)
CHILD_SPEC = importlib.util.spec_from_file_location("v14_child_static", ROOT / "process-a-execution-v01/render_north_process_a_child.py")
CHILD = importlib.util.module_from_spec(CHILD_SPEC)
assert CHILD_SPEC.loader is not None
CHILD_SPEC.loader.exec_module(CHILD)


def load(name: str) -> dict:
    return json.loads((ROOT / name).read_text())


def rejects(scene: dict, materials: dict, lighting: dict, mutate) -> None:
    candidate = copy.deepcopy(scene)
    mutate(candidate)
    try:
        MODULE.lower(candidate, materials, lighting)
    except (AssertionError, KeyError, TypeError, ValueError):
        return
    raise AssertionError("adversary unexpectedly passed")


def main() -> None:
    scene, materials, lighting = load("DESIGN-SCENE.json"), load("DESIGN-MATERIALS.json"), load("LIGHTING-CONTRACT.json")
    first, second = MODULE.run(), MODULE.run()
    if MODULE.canonical(first) != MODULE.canonical(second):
        raise AssertionError("two in-memory lowerings differ")
    manifest, report = first["manifest"], first["report"]
    assert report["componentToObjectCoverage"]["percent"] == 100.0
    assert report["componentCount"] == len(scene["components"]) == 33
    assert report["objectCount"] == len(manifest["objects"] ) == 97
    assert len({c["id"] for c in scene["components"]}) == report["componentCount"]
    assert report["registration"]["socketCitySim"] == [0, 0, -28]
    assert report["registration"]["socketBlender"] == [-28, 0, 0]
    assert report["registration"]["socketSource"] == [896, 704]
    assert report["registration"]["bridge"] == "B(x,y,z)=(z,x,y)"
    assert report["registration"]["descriptorOrder"] == [0, 1, 2, 3]
    assert report["envelope"]["observedNonStackMaxY"] <= 40
    assert report["envelope"]["observedStackMaxY"] <= 44
    assert report["silhouette"]["passes"] and report["silhouette"]["meaningfulBreaks"] >= 5
    assert report["portal"]["passes"] and report["portal"]["socketConnected"] and report["portal"]["occludingObjects"] == []
    assert report["topology"]["parameterizedPayloads"]
    assert report["topology"]["recessedPortal"]["solidVoidSeparated"]
    assert report["topology"]["sawtoothRoofs"]["peakObjects"] == 7
    assert report["topology"]["pipeRuns"]["segments"] == 6 and report["topology"]["pipeRuns"]["elbows"] == 4
    assert report["topology"]["trusses"]["chords"] == 6 and report["topology"]["trusses"]["diagonals"] == 6
    assert report["materialRoles"]["passes"]
    assert lighting["engine"] == "CYCLES" and lighting["device"] == "CPU" and lighting["samples"] >= 64
    assert lighting["threads"] == 1 and lighting["adaptiveSampling"] is False and lighting["denoising"] is False
    assert report["literalScaleProxy"]["semanticProxyOnly"] is True
    assert report["dccProcessCount"] == 0 and report["pixelWrites"] == 0
    assert report["sourceAuthority"] is False and report["productionSelected"] is False

    material_by_role = {item["role"]: item for item in materials["materials"]}
    assert materials["revision"] == "industrial-l04-north-v14-materials-visual-r2"
    assert material_by_role["warm-masonry"]["baseColorRGBA"] == [0.48, 0.18, 0.09, 1.0]
    assert material_by_role["charcoal-steel"]["baseColorRGBA"] == [0.16, 0.19, 0.18, 1.0]
    assert material_by_role["freight-depth"]["baseColorRGBA"] == [0.018, 0.025, 0.028, 1.0]
    role_luma = lambda role: sum(weight * channel for weight, channel in zip((0.2126, 0.7152, 0.0722), material_by_role[role]["baseColorRGBA"][:3]))
    assert role_luma("charcoal-steel") - role_luma("freight-depth") >= 0.15
    assert role_luma("concrete-apron") > role_luma("weathered-roof-steel") > role_luma("warm-masonry") > role_luma("charcoal-steel") > role_luma("freight-depth")
    assert lighting["revision"] == "industrial-l04-north-v14-lighting-visual-r2"
    assert lighting["colorManagement"] == {"displayDevice": "sRGB", "viewTransform": "Standard", "look": "None", "exposure": 0.75, "gamma": 1.0}
    assert lighting["world"]["backgroundStrength"] == 1.2

    mesh_set = CHILD.build_mesh_specs(manifest)
    assert CHILD.bridge_determinant() == 1
    assert mesh_set["closedOutwardObjects"] == 95
    assert mesh_set["openTwoSidedObjects"] == 1
    assert len(mesh_set["orientationReports"]) == 96
    assert all(item["passes"] and item["inwardFaces"] == 0 for item in mesh_set["orientationReports"])
    shadow_orientation = next(item for item in mesh_set["orientationReports"] if item["id"] == "v14-contact-shadow-receiver::primary")
    assert shadow_orientation["classification"] == "open-two-sided-shadow-receiver"
    light_profile = CHILD.light_profile(lighting)
    assert light_profile["key"]["effectiveEnergyWatts"] == 108000.0
    assert light_profile["fill"]["effectiveEnergyWatts"] == 36000.0
    assert light_profile["key"]["targetBlender"] == [0, 0, 16]
    assert light_profile["fill"]["targetBlender"] == [0, 0, 16]
    projection = CHILD.ground_projection_report(scene)
    assert projection["footprintSource"] == [[768.0, 640.0], [1024.0, 768.0], [768.0, 896.0], [512.0, 768.0]]
    assert projection["pivotSource"] == [768.0, 896.0] and projection["socketSource"] == [896.0, 704.0]

    rejected_root = ROOT / "process-a-execution-v01/process-a-rejected-v4"
    retained_visibility = CHILD.evaluate_post_render_visibility(rejected_root / "raw.png", rejected_root / "semantic.png", lighting)
    assert retained_visibility["passes"] is False
    assert retained_visibility["alphaBounds"] == {"x": 511, "y": 517, "width": 514, "height": 380}
    assert retained_visibility["luma"]["median"] < lighting["gates"]["medianLumaMin"]
    assert retained_visibility["luma"]["p95"] < lighting["gates"]["p95LumaMin"]
    assert retained_visibility["frontage"]["frameDepthDelta"] < 0.0
    assert set(retained_visibility["failed"]) == {"medianLuma", "p95Luma", "portalFrameDelta"}

    width = height = 16
    raw_pixels = [(90, 90, 90, 255)] * (width * height)
    semantic_pixels = [(1, 1, 1, 255)] * (width * height)
    frame_ids = ["v14-monumental-portal-west-jamb", "v14-monumental-portal-east-jamb", "v14-monumental-portal-header"]
    depth_ids = ["v14-freight-bay-west", "v14-freight-bay-center", "v14-freight-bay-east"]
    for group_index, component_id in enumerate(frame_ids + depth_ids):
        for pixel_index in range(group_index * 10, group_index * 10 + 10):
            semantic_pixels[pixel_index] = (*CHILD.semantic_srgb8(component_id), 255)
            raw_pixels[pixel_index] = (205, 185, 165, 255) if component_id in frame_ids else (75, 70, 65, 255)
    synthetic_visibility = CHILD.evaluate_visibility_pixels(width, height, raw_pixels, semantic_pixels, lighting["gates"])
    assert synthetic_visibility["passes"] is True and synthetic_visibility["failed"] == []

    inverted_pixels = list(raw_pixels)
    for group_index, component_id in enumerate(frame_ids + depth_ids):
        for pixel_index in range(group_index * 10, group_index * 10 + 10):
            inverted_pixels[pixel_index] = (75, 70, 65, 255) if component_id in frame_ids else (205, 185, 165, 255)
    inverted_visibility = CHILD.evaluate_visibility_pixels(width, height, inverted_pixels, semantic_pixels, lighting["gates"])
    assert inverted_visibility["passes"] is False
    assert inverted_visibility["checks"]["medianLuma"] and inverted_visibility["checks"]["p95Luma"]
    assert inverted_visibility["failed"] == ["portalFrameDelta"] and inverted_visibility["frontage"]["frameDepthDelta"] < 0.0

    reversed_box = copy.deepcopy(mesh_set["solidSpecs"][0])
    reversed_box["faces"][0] = list(reversed(reversed_box["faces"][0]))
    assert CHILD.orientation_report(reversed_box)["passes"] is False
    dark_fixture = [(8, 8, 8, 255)] * (width * height)
    assert CHILD.evaluate_visibility_pixels(width, height, dark_fixture, semantic_pixels, lighting["gates"])["passes"] is False

    # Registration, connectivity, topology and parameter fail-closed adversaries.
    rejects(scene, materials, lighting, lambda s: s["registration"].update(socketCitySim=[0, 0, -27]))
    rejects(scene, materials, lighting, lambda s: s["registration"].update(sourceProjection={"originCitySim": [0, 0, -28], "originSource": [895, 704], "pixelsPerWorldXZ": [4, 4]}))
    rejects(scene, materials, lighting, lambda s: next(c for c in s["components"] if c["id"] == "v14-north-loading-apron").update(boundsXYZ=[[-14, 0.72, -20], [14, 1.0, -15]]))
    rejects(scene, materials, lighting, lambda s: next(c for c in s["components"] if c["id"] == "v14-west-sawtooth-roof").update(primitive="box"))
    rejects(scene, materials, lighting, lambda s: next(c for c in s["components"] if c["id"] == "v14-west-sawtooth-roof").update(peaks=3))
    rejects(scene, materials, lighting, lambda s: next(c for c in s["components"] if c["id"] == "v14-process-pipe-west").update(points=[[-10, 2, 4], [-10, 2, 4], [-6, 22, 4]]))
    rejects(scene, materials, lighting, lambda s: next(c for c in s["components"] if c["id"] == "v14-monumental-portal-void").update(insetBack=[[-9.5, 1.2, -22.5], [-9.5, 1.2, -22.5]]))

    print(json.dumps({"status": "PASS", "revision": scene["revision"], "componentCount": report["componentCount"], "objectCount": report["objectCount"], "coveragePercent": report["componentToObjectCoverage"]["percent"], "socket": report["socketContinuity"], "topology": report["topology"], "bridgeDeterminant": CHILD.bridge_determinant(), "closedOutwardObjects": mesh_set["closedOutwardObjects"], "openTwoSidedObjects": mesh_set["openTwoSidedObjects"], "retainedRenderRejected": True, "syntheticVisibilityPass": True, "invertedContrastRejected": True, "adversaries": 10, "dccProcessCount": 0, "pixelWrites": 0}, sort_keys=True))


if __name__ == "__main__":
    main()
