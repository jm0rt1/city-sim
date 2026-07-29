#!/usr/bin/env python3
"""Build the immutable PLAY-027 Industrial L4 North art-v05 scene."""

import copy
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[6]
SOURCE = (
    ROOT
    / "Native/CitySimNative/WorldArt/Blender/PLAY-027"
    / "industrial-l04-north-art-v03/SCENE.json"
)
OUTPUT = Path(__file__).resolve().with_name("SCENE.json")
SOURCE_SHA256 = "e333caca586c78aa5f1cf7f10d8c962a130b887e9cbafdd1465753f1405254f0"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def component(
    identifier,
    group,
    dimensions,
    position,
    material_id,
    bevel,
):
    return {
        "id": identifier,
        "shape": "box",
        "group": group,
        "dimensions": dimensions,
        "position": position,
        "materialID": material_id,
        "bevel": bevel,
    }


def canonical_bytes(value):
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def main():
    if digest(SOURCE) != SOURCE_SHA256:
        raise RuntimeError("immutable v03 scene hash drift")
    if OUTPUT.exists():
        raise RuntimeError(f"output must be absent: {OUTPUT}")
    scene = copy.deepcopy(json.loads(SOURCE.read_text()))
    scene["sourceRevision"] = "blender-art-v05"
    scene["sceneGeometryID"] = (
        "industrial-l04-blender-north-art-v05-socket-facing-portal"
    )
    scene["registration"]["frontageWorld"] = {
        "roadEdgeX": -28,
        "courtMinimum": [-28, -16],
        "courtMaximum": [-20, 16],
        "portalFacing": "negative-x",
    }
    scene["portal"]["minimumCompactInsetPixels"] = [15, 13]
    scene["portal"]["revealComponentIDs"] = [
        "foundry-portal-reveal-north",
        "foundry-portal-reveal-south",
        "foundry-portal-reveal-top",
    ]
    scene["staffEntry"]["minimumCompactBounds"] = [4, 8]
    scene["frontageConnectivity"] = {
        "apronComponentIDs": [
            "foundry-v05-socket-court",
            "foundry-v05-threshold",
        ],
        "portalThresholdComponentIDs": ["foundry-v05-threshold"],
        "socketWorld": [-28, 0, 0],
        "thresholdWorldX": -20.4,
        "outwardNormalWorld": [-1, 0, 0],
        "socketCompact": [112, 88],
        "maximumPortalAdjacencyPixels": 2,
        "maximumSocketDistancePixels": 2,
    }

    removed = {
        "foundry-private-apron",
        "foundry-v03-north-apron-link",
        "foundry-v03-socket-apron-link",
        "foundry-hall-west-core",
        "foundry-facade-north-segment",
        "foundry-facade-south-segment",
        "foundry-facade-upper-header",
        "foundry-portal-inset",
        "foundry-portal-jamb-north",
        "foundry-portal-jamb-south",
        "foundry-portal-header",
        "foundry-portal-reveal-north",
        "foundry-portal-reveal-south",
        "foundry-portal-reveal-top",
        "foundry-lower-hall-roof",
        "foundry-lower-hall-roof-edge",
    }
    components = [
        copy.deepcopy(item)
        for item in scene["components"]
        if item["id"] not in removed
    ]

    process_ids = {
        "foundry-process-bay",
        "foundry-process-bay-masonry-return",
        "foundry-clerestory",
        "foundry-clerestory-glazing",
        "foundry-clerestory-louver-a",
        "foundry-clerestory-louver-b",
        "foundry-process-roof",
        "foundry-process-roof-edge",
        "foundry-stack",
        "foundry-stack-band",
        "foundry-roof-vent-a",
        "foundry-roof-vent-a-cap",
        "foundry-roof-vent-b",
        "foundry-roof-vent-b-cap",
    }
    monitor_ids = {
        f"foundry-monitor-{letter}"
        for letter in ("a", "b", "c", "d")
    } | {
        f"foundry-monitor-{letter}-cap"
        for letter in ("a", "b", "c", "d")
    }
    for item in components:
        if item["id"] in process_ids:
            item["position"][0] += 8
        if item["id"] in monitor_ids:
            item["position"][0] = -6.5
            item["dimensions"][0] = (
                26 if item["id"].endswith("-cap") else 25
            )

    additions = [
        component(
            "foundry-v05-socket-court",
            "apron",
            [7.2, 0.25, 32],
            [-24.4, 0.925, 0],
            "foundry-v03-apron-concrete",
            0.08,
        ),
        component(
            "foundry-v05-threshold",
            "portal-threshold",
            [0.8, 0.25, 32],
            [-20.4, 0.925, 0],
            "foundry-v03-apron-concrete",
            0.04,
        ),
        component(
            "foundry-hall-east-core",
            "freight-hall",
            [28, 18, 48],
            [-6, 9, 0],
            "foundry-warm-masonry",
            0.28,
        ),
        component(
            "foundry-hall-west-north-return",
            "freight-hall",
            [8, 18, 8],
            [-24, 9, -20],
            "foundry-warm-masonry",
            0.24,
        ),
        component(
            "foundry-hall-west-south-return",
            "freight-hall",
            [8, 18, 8],
            [-24, 9, 20],
            "foundry-warm-masonry",
            0.24,
        ),
        component(
            "foundry-east-facade-restoration",
            "freight-hall",
            [6, 18, 48],
            [11, 9, 0],
            "foundry-warm-masonry",
            0.24,
        ),
        component(
            "foundry-portal-inset",
            "portal-inset",
            [0.7, 16, 32],
            [-20.35, 9, 0],
            "foundry-deep-portal",
            0.05,
        ),
        component(
            "foundry-portal-jamb-north",
            "portal-frame",
            [4, 17, 2],
            [-26, 9.5, -17],
            "foundry-v03-portal-frame",
            0.18,
        ),
        component(
            "foundry-portal-jamb-south",
            "portal-frame",
            [4, 17, 2],
            [-26, 9.5, 17],
            "foundry-v03-portal-frame",
            0.18,
        ),
        component(
            "foundry-portal-header",
            "portal-frame",
            [8, 1.8, 36],
            [-24, 18.5, 0],
            "foundry-v03-portal-frame",
            0.22,
        ),
        component(
            "foundry-portal-reveal-north",
            "portal-depth",
            [7.5, 16, 0.75],
            [-24.1, 9, -16.4],
            "foundry-v03-portal-reveal",
            0.08,
        ),
        component(
            "foundry-portal-reveal-south",
            "portal-depth",
            [7.5, 16, 0.75],
            [-24.1, 9, 16.4],
            "foundry-v03-portal-reveal",
            0.08,
        ),
        component(
            "foundry-portal-reveal-top",
            "portal-depth",
            [7.5, 0.6, 32],
            [-24.1, 17.3, 0],
            "foundry-v03-portal-reveal",
            0.08,
        ),
        component(
            "foundry-lower-hall-roof-core",
            "hall-roof",
            [30, 1.2, 50],
            [-5, 18.6, 0],
            "foundry-bluegreen-steel",
            0.2,
        ),
        component(
            "foundry-lower-hall-roof-north-return",
            "hall-roof",
            [8, 1.2, 9],
            [-24, 18.6, -20.5],
            "foundry-bluegreen-steel",
            0.18,
        ),
        component(
            "foundry-lower-hall-roof-south-return",
            "hall-roof",
            [8, 1.2, 9],
            [-24, 18.6, 20.5],
            "foundry-bluegreen-steel",
            0.18,
        ),
        component(
            "foundry-lower-hall-roof-edge-core",
            "hall-roof-edge",
            [30, 0.5, 50],
            [-5, 19.45, 0],
            "foundry-roof-edge",
            0.12,
        ),
        component(
            "foundry-lower-hall-roof-edge-north-return",
            "hall-roof-edge",
            [8, 0.5, 9],
            [-24, 19.45, -20.5],
            "foundry-roof-edge",
            0.1,
        ),
        component(
            "foundry-lower-hall-roof-edge-south-return",
            "hall-roof-edge",
            [8, 0.5, 9],
            [-24, 19.45, 20.5],
            "foundry-roof-edge",
            0.1,
        ),
    ]
    scene["components"] = components + additions
    OUTPUT.write_bytes(canonical_bytes(scene))
    print(digest(OUTPUT))


if __name__ == "__main__":
    main()
