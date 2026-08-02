"""Deterministic, zero-pixel v14 North design proof."""
from __future__ import annotations

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


def main() -> None:
    scene, materials, lighting = load("DESIGN-SCENE.json"), load("DESIGN-MATERIALS.json"), load("LIGHTING-CONTRACT.json")
    first = MODULE.run()
    second = MODULE.run()
    if MODULE.canonical(first) != MODULE.canonical(second):
        raise AssertionError("two in-memory lowerings differ")
    manifest, report = first["manifest"], first["report"]
    assert report["componentToObjectCoverage"]["percent"] == 100.0
    assert report["componentCount"] == len(scene["components"]) == 33
    assert len({c["id"] for c in scene["components"]}) == report["componentCount"]
    assert report["registration"] == {
        "bridge": "B(x,y,z)=(z,x,y)",
        "descriptorOrder": [0, 1, 2, 3],
        "pivotSource": [768, 896],
        "socketSource": [896, 704],
        "footprint": [56, 56],
        "northRoadZ": -28,
    }
    assert report["envelope"]["observedNonStackMaxY"] <= 40
    assert report["envelope"]["observedStackMaxY"] <= 44
    assert report["silhouette"]["passes"] and report["silhouette"]["meaningfulBreaks"] >= 5
    assert report["portal"]["passes"] and report["portal"]["socketConnected"]
    assert report["portal"]["occludingObjects"] == []
    assert report["portal"]["estimatedCompactPixels"]["width"] >= 14
    assert report["portal"]["estimatedCompactPixels"]["height"] >= 12
    assert report["portal"]["depthLayers"] == ["header", "jambs", "empty-aperture", "inset-back", "threshold"]
    assert report["materialRoles"]["passes"]
    assert lighting["engine"] == "CYCLES" and lighting["device"] == "CPU"
    assert lighting["samples"] >= 64 and lighting["threads"] == 1
    assert lighting["adaptiveSampling"] is False and lighting["denoising"] is False
    assert report["literalScaleProxy"]["semanticProxyOnly"] is True
    assert report["dccProcessCount"] == 0 and report["pixelWrites"] == 0
    assert report["sourceAuthority"] is False and report["productionSelected"] is False
    assert len(manifest["objects"]) == report["objectCount"]
    print(json.dumps({
        "status": "PASS",
        "revision": scene["revision"],
        "componentCount": report["componentCount"],
        "objectCount": report["objectCount"],
        "coveragePercent": report["componentToObjectCoverage"]["percent"],
        "portal": report["portal"],
        "silhouetteBreaks": report["silhouette"]["meaningfulBreaks"],
        "dccProcessCount": report["dccProcessCount"],
        "pixelWrites": report["pixelWrites"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
