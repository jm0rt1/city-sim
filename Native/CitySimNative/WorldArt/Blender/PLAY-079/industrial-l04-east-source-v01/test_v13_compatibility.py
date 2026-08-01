#!/usr/bin/env python3
"""Validate the East v13 zero-pixel compatibility/lowering packet."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PACKET = ROOT / "V13-COMPATIBILITY-DESIGN.json"
EVIDENCE_ROOT = ROOT.parents[5] / "docs" / "production" / "evidence" / "PLAY-079" / "industrial-l04-east-source-v01" / "v13-compatibility-v01"
RESULT = EVIDENCE_ROOT / "V13-COMPATIBILITY-RESULT.json"
CLAIM = ROOT.parents[5] / "docs" / "production" / "claims" / "PLAY-079.world-art-east.md"
EAST_SCENE = ROOT.parent / "industrial-l04-east-predesign-v01" / "scene.json"
EAST_MATERIALS = ROOT.parent / "industrial-l04-east-predesign-v01" / "materials.json"
SEMANTIC_AUTHORITY = ROOT.parents[5] / "docs" / "production" / "evidence" / "PLAY-027" / "industrial-l04" / "l04" / "blender-north-art-v13" / "design-authority-v01" / "DESIGN-AUTHORITY.json"
SEMANTIC_MATERIALS = ROOT.parents[5] / "Native" / "CitySimNative" / "WorldArt" / "Blender" / "PLAY-027" / "industrial-l04-north-art-v13" / "DESIGN-MATERIALS.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def load(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AssertionError(f"{path} must contain an object")
    return value


def evaluate() -> dict:
    packet = load(PACKET)
    east_scene = load(EAST_SCENE)
    east_materials = load(EAST_MATERIALS)
    semantic = load(SEMANTIC_AUTHORITY)
    semantic_materials = load(SEMANTIC_MATERIALS)

    assert packet["schema"] == "citysim.play-079.east-v13-compatibility-design.v1"
    assert packet["task"] == "PLAY-079" and packet["direction"] == "east"
    assert packet["phase"] == "V13_ZERO_PIXEL_COMPATIBILITY"
    assert packet["sourceAuthority"] is False
    assert packet["productionSelected"] is False
    assert packet["pixelRenderingAllowed"] is False

    provenance = packet["provenance"]
    assert provenance["siblingSceneInputs"] == []
    assert provenance["copiedGeometry"] is False
    assert provenance["mirroredGeometry"] is False
    assert provenance["rotatedGeometry"] is False
    assert provenance["transformedSiblingGeometry"] is False
    assert provenance["orientationTransform"] == "none"

    authority = packet["authority"]
    assert authority["authorityCommit"] == "d010d453af87c040ac13e8b3b7280366cb5094c1"
    assert authority["baseCommit"] == authority["authorityCommit"]
    assert authority["routeId"] == "quality-v1:east-v13-compatibility"
    assert authority["routeSha256"] == "8479bc9cc5fab282d7bac4f67967b828e8c6bc045a8bc7051e996da2f3d03e4a"
    assert authority["claim"]["sha256"] == "abccb0be0550e092565ecca076db717f73f45ed833fe485853338a8de1bff017"
    assert sha(CLAIM) == authority["claim"]["sha256"]
    assert sha(SEMANTIC_AUTHORITY) == authority["publishedSemanticInputs"][0]["sha256"]
    assert sha(SEMANTIC_MATERIALS) == authority["publishedSemanticInputs"][1]["sha256"]

    registration = packet["eastRegistration"]
    assert registration["citySimFootprint"] == {"width": 72.0, "depth": 72.0}
    assert registration["dccFootprint"] == {"width": 56.0, "depth": 56.0, "halfExtent": 28.0}
    assert registration["citySimSocket"] == [28.0, 0.0, 0.0]
    assert registration["sourceSocket"] == [896.0, 832.0]
    assert registration["groundPivot"] == [28.0, -28.0, 0.0]
    assert registration["sourceGroundPivot"] == [768.0, 896.0]
    assert registration["orientationTransform"] == "none"

    camera = packet["camera"]
    assert camera["projection"] == "orthographic"
    assert camera["view"] == "southeast-looking-northwest"
    assert camera["literalResolution"] == [192, 128]
    assert camera["resolution"] == [1536, 1024]
    assert camera["orthoScale"] == east_scene["camera"]["orthoScale"]
    assert camera["shift"] == [east_scene["camera"]["shiftX"], east_scene["camera"]["shiftY"]]
    assert camera["literalResolution"] == east_scene["camera"]["literalResolution"]

    light = packet["light"]
    assert light["keySemantic"] == "northwest-key-southeast-contact"
    assert light["shadowVectorSign"] == [1.0, -1.0]

    required_semantic_roles = {item["id"] for item in semantic_materials["materials"]}
    mapping = packet["materialRoleMapping"]
    assert set(mapping) == required_semantic_roles
    existing_roles = {item["id"] for item in east_materials["roles"]}
    assert set(mapping.values()) == existing_roles
    assert semantic["literal192ExitCriteria"]["silhouette"]["minimumDistinctRoofHeightBreaks"] == 3
    assert packet["literal192Targets"]["minimumSilhouetteBreaks"] == 3

    plan = packet["eastFacadePlan"]
    assert plan["roadFacing"] == "east"
    assert len(plan["components"]) == len({item["id"] for item in plan["components"]})
    assert all(item["id"].startswith("east-v13-") for item in plan["components"])
    assert sorted({item["silhouetteTier"] for item in plan["components"]}) == [0, 1, 2, 3, 4, 5, 6]
    for item in plan["components"]:
        bounds = item["bounds"]
        assert -28.0 <= bounds["xMin"] <= bounds["xMax"] <= 28.0
        assert -28.0 <= bounds["yMin"] <= bounds["yMax"] <= 28.0
        assert 0.0 <= bounds["zMin"] <= bounds["zMax"]
    portal = plan["portal"]
    assert portal["clearInsetWidthWorld"] >= 14.0
    assert portal["clearInsetHeightWorld"] >= 12.0
    assert portal["jambThicknessWorld"] >= 3.0
    assert portal["headerThicknessWorld"] >= 3.0
    assert portal["freightBeatCount"] == 3
    assert portal["minimumProcessOccluders"] == 0
    assert portal["apronTerminatesAtSocket"] is True
    assert plan["silhouette"]["distinctRoofHeightBreaks"] >= 3

    source_bindings = packet["sourceBindings"]
    assert source_bindings["eastScene"]["sha256"] == sha(EAST_SCENE)
    assert source_bindings["eastMaterials"]["sha256"] == sha(EAST_MATERIALS)
    assert source_bindings["eastScene"]["consumedAs"] == "registration-and-camera-only"
    assert source_bindings["eastMaterials"]["consumedAs"] == "existing-role-inventory-only"

    boundary = packet["zeroPixelBoundary"]
    assert all(boundary[key] == 0 for key in ("blenderInvocations", "dccInvocations", "renderInvocations", "pixelFilesCreated", "normalizationRuns", "sourcePacketsCreated"))
    assert boundary["candidateReadyForIndependentReview"] is True
    assert boundary["independentReviewRequired"] is True

    proof = {
        "schema": "citysim.play-079.east-v13-compatibility-proof.v1",
        "task": "PLAY-079",
        "direction": "east",
        "phase": "V13_ZERO_PIXEL_COMPATIBILITY",
        "result": "PASS",
        "checks": {
            "routeAndAuthority": "PASS",
            "eastSocketAndPivot": "PASS",
            "cameraAndLiteral192": "PASS",
            "portalAndSilhouette": "PASS",
            "materialCompleteness": "PASS",
            "independentGeometry": "PASS",
            "pathIsolation": "PASS",
        },
        "socket": {"citySim": registration["citySimSocket"], "source": registration["sourceSocket"]},
        "literal192": packet["literal192Targets"],
        "portal": portal,
        "componentCount": len(plan["components"]),
        "silhouetteBreakCount": plan["silhouette"]["distinctRoofHeightBreaks"],
        "materialRoleCount": len(mapping),
        "siblingSceneInputs": [],
        "renderInvocations": 0,
        "imagesWritten": 0,
        "sourceAuthority": False,
        "productionSelected": False,
        "sourceHashes": {
            "packetSHA256": sha(PACKET),
            "eastSceneSHA256": sha(EAST_SCENE),
            "eastMaterialsSHA256": sha(EAST_MATERIALS),
            "claimSHA256": sha(CLAIM),
            "semanticAuthoritySHA256": sha(SEMANTIC_AUTHORITY),
            "semanticMaterialsSHA256": sha(SEMANTIC_MATERIALS),
        },
    }
    return proof


def main() -> int:
    first = evaluate()
    second = evaluate()
    first_bytes = canonical(first)
    second_bytes = canonical(second)
    assert first_bytes == second_bytes, "two compatibility validations were not byte-identical"
    result = dict(first)
    result["repeatValidation"] = {
        "runs": 2,
        "byteIdentical": True,
        "proofSHA256": hashlib.sha256(first_bytes).hexdigest(),
    }
    EVIDENCE_ROOT.mkdir(parents=True, exist_ok=True)
    RESULT.write_bytes(canonical(result))
    print("PASS: East v13 compatibility; literal-192/static; zero DCC/pixels; 2 byte-identical runs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
