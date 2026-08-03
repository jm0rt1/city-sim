#!/usr/bin/env python3
"""Deterministic, zero-DCC proof for the PLAY-090 North predesign."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent
EVIDENCE = ROOT.parents[5] / "docs" / "production" / "evidence" / "PLAY-090" / "residential-l01-variant1-north-prelock-v1"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def project(point):
    x, y, z = point
    source_x = 768.0 + (256.0 / 56.0) * x - (256.0 / 56.0) * z
    source_y = 768.0 + (128.0 / 56.0) * x + (128.0 / 56.0) * z - (256.0 / 56.0) * math.sqrt(1.5) * y
    return source_x, source_y


def vertices(component):
    kind = component["kind"]
    if kind == "box":
        cx, cy, cz = component["centerWorld"]
        dx, dy, dz = component["dimensions"]
        return [(cx + sx * dx / 2, cy + sy * dy / 2, cz + sz * dz / 2) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    footprint = component["footprintWorld"]
    if kind == "gablePrism":
        eave = component["eaveHeight"]
        ridge = component["ridgeHeight"]
        xs = [p[0] for p in footprint]
        zs = [p[1] for p in footprint]
        result = [(x, eave, z) for x, z in footprint]
        if component["ridgeAxis"] == "z":
            mid = (min(xs) + max(xs)) / 2
            result.extend([(mid, ridge, min(zs)), (mid, ridge, max(zs))])
        else:
            mid = (min(zs) + max(zs)) / 2
            result.extend([(min(xs), ridge, mid), (max(xs), ridge, mid)])
        return result
    if kind == "shedPrism":
        low = component["lowEdgeHeight"]
        high = component["highEdgeHeight"]
        xs = [p[0] for p in footprint]
        zs = [p[1] for p in footprint]
        high_edge = component["highEdge"]
        result = []
        for x, z in footprint:
            is_high = (high_edge == "west" and x == min(xs)) or (high_edge == "east" and x == max(xs)) or (high_edge == "north" and z == min(zs)) or (high_edge == "south" and z == max(zs))
            result.append((x, high if is_high else low, z))
        return result
    raise AssertionError(f"unsupported geometry kind: {kind}")


def projected_bounds(component):
    points = [project(p) for p in vertices(component)]
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return [min(xs), min(ys), max(xs), max(ys)]


def compact_bounds(bounds):
    return [math.floor(bounds[0] / 8), math.floor(bounds[1] / 8), math.ceil(bounds[2] / 8), math.ceil(bounds[3] / 8)]


def aabb_xz(component):
    verts = vertices(component)
    xs = [p[0] for p in verts]
    zs = [p[2] for p in verts]
    return min(xs), min(zs), max(xs), max(zs)


def overlaps_strict(a, b):
    return min(a[2], b[2]) > max(a[0], b[0]) and min(a[3], b[3]) > max(a[1], b[1])


def compute_metrics(scene, materials):
    components = scene["components"]
    by_id = {c["id"]: c for c in components}
    all_bounds = [projected_bounds(c) for c in components]
    envelope = [min(b[0] for b in all_bounds), min(b[1] for b in all_bounds), max(b[2] for b in all_bounds), max(b[3] for b in all_bounds)]
    compact = compact_bounds(envelope)
    door = compact_bounds(projected_bounds(by_id["entry-backplane"]))
    header = compact_bounds(projected_bounds(by_id["entry-header"]))
    west_jamb = compact_bounds(projected_bounds(by_id["entry-jamb-west"]))
    east_jamb = compact_bounds(projected_bounds(by_id["entry-jamb-east"]))
    secondary = compact_bounds(projected_bounds(by_id["east-wing"]))
    tiers = sorted({max(v[1] for v in vertices(c)) for c in components if c["semanticRole"] in {"primary-roof", "secondary-roof", "lantern-roof"}})
    corridor = (-3.5, -28.0, 3.5, -8.9)
    blockers = []
    for component in components:
        if component["semanticRole"] in {"socket-path", "entrance-frame", "entrance-void-backplane", "window"}:
            continue
        if overlaps_strict(aabb_xz(component), corridor):
            blockers.append(component["id"])
    material_by_id = {m["id"]: m for m in materials["materials"]}
    def luma(material_id):
        return material_by_id[material_id]["grayscaleLuma"]
    return {
        "componentCount": len(components),
        "compactEnvelope": compact,
        "compactEnvelopeSize": [compact[2] - compact[0], compact[3] - compact[1]],
        "entranceBackplaneCompactBounds": door,
        "entranceBackplaneCompactSize": [door[2] - door[0], door[3] - door[1]],
        "entryHeaderCompactSize": [header[2] - header[0], header[3] - header[1]],
        "entryWestJambCompactSize": [west_jamb[2] - west_jamb[0], west_jamb[3] - west_jamb[1]],
        "entryEastJambCompactSize": [east_jamb[2] - east_jamb[0], east_jamb[3] - east_jamb[1]],
        "secondaryVolumeCompactSize": [secondary[2] - secondary[0], secondary[3] - secondary[1]],
        "roofTierHeightsWorld": tiers,
        "socketToThresholdWorldLength": 20.1,
        "socketPathBlockers": blockers,
        "valueContrasts": {
            "primaryFacadeMinusRoof": round(luma("brick-honey") - luma("tile-umber"), 6),
            "entryFrameMinusDoor": round(luma("stone-buff") - luma("door-bluegreen"), 6),
            "secondaryFacadeMinusPrimary": round(luma("plaster-cream") - luma("brick-honey"), 6),
            "windowMinusPrimary": round(luma("window-amber") - luma("brick-honey"), 6)
        }
    }


def validate():
    scene_path = ROOT / "DESIGN-SCENE.json"
    materials_path = ROOT / "MATERIALS.json"
    validation_path = EVIDENCE / "VALIDATION.json"
    predesign_path = EVIDENCE / "PREDESIGN.json"
    handoff_path = EVIDENCE / "HANDOFF.json"
    scene = load(scene_path)
    materials = load(materials_path)
    evidence = load(validation_path)
    predesign = load(predesign_path)
    handoff = load(handoff_path)

    assert scene["task"] == "PLAY-090"
    assert scene["state"] == "predesign_ready"
    assert scene["logicalBuildingID"] == "residential_l01"
    assert scene["variantID"] == "variant-1"
    assert scene["viewDirection"] == "north"
    assert scene["authoredIndependently"] is True
    assert scene["productionSelected"] is False and scene["sourceAuthority"] is False
    assert scene["derivation"] == {"sourceKind": "independent-north-zero-pixel-design", "siblingSource": None, "mirror": False, "rotationDegrees": 0, "orientationTransform": "none"}
    assert scene["authority"]["workerHead"] == "2d1624af35aa268f4c5099b58a9bef2af53c8c83"
    assert scene["authority"]["scheduleSHA256"] == "ec8b66905f487b6197a4533a8060af6d4809591b2ffc564d41b02ff107915ae5"

    registration = scene["registration"]
    assert registration["tileBasisPoints"] == [72, 36]
    assert registration["sceneFootprintUnits"] == [72, 72]
    assert registration["footprintPolygonSource"] == [[768, 640], [1024, 768], [768, 896], [512, 768]]
    assert registration["groundPivotSource"] == [768, 896]
    assert registration["contactPolygonWorld"] == [[-28, -28], [28, -28], [28, 28], [-28, 28]]
    assert registration["frontageSocketWorld"] == [0, 0, -28]
    assert registration["frontageSocketSource"] == [896, 704]
    assert scene["camera"]["projection"] == "orthographic-2:1"
    assert scene["camera"]["renderViewportPixels"] == [1536, 1024]
    assert scene["camera"]["positionWorld"] == [180, 146.9693845669907, 180]
    assert scene["light"]["keyOrigin"] == [-120, 180, -120]
    assert scene["light"]["shadowVectorSource"] == [2, 1]

    ids = [c["id"] for c in scene["components"]]
    assert len(ids) == len(set(ids))
    material_ids = {m["id"] for m in materials["materials"]}
    assert all(c["materialID"] in material_ids for c in scene["components"])
    for material in materials["materials"]:
        r, g, b, a = material["baseColorRGBA"]
        assert a == 1.0
        calculated = round(0.2126 * r + 0.7152 * g + 0.0722 * b, 6)
        assert abs(calculated - material["grayscaleLuma"]) < 0.000001

    for component in scene["components"]:
        x0, z0, x1, z1 = aabb_xz(component)
        assert -28 <= x0 <= x1 <= 28
        assert -28 <= z0 <= z1 <= 28
        assert max(v[1] for v in vertices(component)) <= 40

    metrics = compute_metrics(scene, materials)
    assert metrics == evidence["metrics"]
    assert metrics["compactEnvelopeSize"][0] <= 64 and metrics["compactEnvelopeSize"][1] <= 60
    assert metrics["entranceBackplaneCompactSize"][0] >= 4 and metrics["entranceBackplaneCompactSize"][1] >= 8
    assert metrics["entryHeaderCompactSize"][0] >= 6 and metrics["entryHeaderCompactSize"][1] >= 2
    assert metrics["entryWestJambCompactSize"][0] >= 1 and metrics["entryWestJambCompactSize"][1] >= 10
    assert metrics["entryEastJambCompactSize"][0] >= 1 and metrics["entryEastJambCompactSize"][1] >= 10
    assert metrics["secondaryVolumeCompactSize"][0] >= 10 and metrics["secondaryVolumeCompactSize"][1] >= 14
    assert len(metrics["roofTierHeightsWorld"]) == 3
    assert metrics["socketPathBlockers"] == []
    targets = materials["valueTargets"]
    for key, minimum in targets.items():
        metric_key = key.removesuffix("Minimum")
        assert metrics["valueContrasts"][metric_key] >= minimum

    assert predesign["status"] == "predesign_ready"
    assert predesign["pixelAuthority"] == {"dccProcesses": 0, "renderedPixels": 0, "analyticProxyOnly": True}
    assert predesign["siblingInputsConsumed"] == []
    assert handoff["disposition"] == "predesign_ready"
    assert handoff["sourceAuthority"] is False and handoff["productionSelected"] is False
    assert handoff["inputHashes"]["designScene"] == sha(scene_path)
    assert handoff["inputHashes"]["materials"] == sha(materials_path)
    assert handoff["inputHashes"]["validation"] == sha(validation_path)
    assert evidence["validationPassed"] is True
    assert evidence["proofLevel"] == "static_only"
    assert evidence["dccProcessCount"] == 0 and evidence["renderedPixelCount"] == 0
    return metrics


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--print-metrics", action="store_true")
    args = parser.parse_args()
    result = validate()
    if args.print_metrics:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print("PASS: PLAY-090 North zero-pixel predesign")
