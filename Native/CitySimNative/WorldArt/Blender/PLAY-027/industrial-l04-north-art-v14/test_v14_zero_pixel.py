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

    # Registration, connectivity, topology and parameter fail-closed adversaries.
    rejects(scene, materials, lighting, lambda s: s["registration"].update(socketCitySim=[0, 0, -27]))
    rejects(scene, materials, lighting, lambda s: s["registration"].update(sourceProjection={"originCitySim": [0, 0, -28], "originSource": [895, 704], "pixelsPerWorldXZ": [4, 4]}))
    rejects(scene, materials, lighting, lambda s: next(c for c in s["components"] if c["id"] == "v14-north-loading-apron").update(boundsXYZ=[[-14, 0.72, -20], [14, 1.0, -15]]))
    rejects(scene, materials, lighting, lambda s: next(c for c in s["components"] if c["id"] == "v14-west-sawtooth-roof").update(primitive="box"))
    rejects(scene, materials, lighting, lambda s: next(c for c in s["components"] if c["id"] == "v14-west-sawtooth-roof").update(peaks=3))
    rejects(scene, materials, lighting, lambda s: next(c for c in s["components"] if c["id"] == "v14-process-pipe-west").update(points=[[-10, 2, 4], [-10, 2, 4], [-6, 22, 4]]))
    rejects(scene, materials, lighting, lambda s: next(c for c in s["components"] if c["id"] == "v14-monumental-portal-void").update(insetBack=[[-9.5, 1.2, -22.5], [-9.5, 1.2, -22.5]]))

    print(json.dumps({"status": "PASS", "revision": scene["revision"], "componentCount": report["componentCount"], "objectCount": report["objectCount"], "coveragePercent": report["componentToObjectCoverage"]["percent"], "socket": report["socketContinuity"], "topology": report["topology"], "adversaries": 7, "dccProcessCount": 0, "pixelWrites": 0}, sort_keys=True))


if __name__ == "__main__":
    main()
