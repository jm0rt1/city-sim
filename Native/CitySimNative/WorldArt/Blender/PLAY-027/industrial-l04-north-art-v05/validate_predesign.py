#!/usr/bin/env python3
"""Fail-closed static validation for North art-v05 portal relocation."""

import argparse
import hashlib
import json
from pathlib import Path


V03_SCENE_SHA256 = (
    "e333caca586c78aa5f1cf7f10d8c962a130b887e9cbafdd1465753f1405254f0"
)
MATERIAL_SHA256 = (
    "474952f3f28a880d5517bab4e964c8bcdd6d773ffa5349c515b1831f58e92fab"
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def bounds(item):
    position = item["position"]
    dimensions = item["dimensions"]
    return [
        position[index] - dimensions[index] / 2
        for index in range(3)
    ], [
        position[index] + dimensions[index] / 2
        for index in range(3)
    ]


def positive_overlap(first, second):
    first_min, first_max = bounds(first)
    second_min, second_max = bounds(second)
    return all(
        min(first_max[index], second_max[index])
        - max(first_min[index], second_min[index])
        > 0.0001
        for index in range(3)
    )


def canonical_bytes(value):
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--scene", required=True)
    parser.add_argument("--materials", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    root = Path(args.repository_root).resolve()
    scene_path = (root / args.scene).resolve()
    materials_path = (root / args.materials).resolve()
    output = Path(args.output).resolve()
    require(not output.exists(), f"output must be absent: {output}")
    v03_path = (
        root
        / "Native/CitySimNative/WorldArt/Blender/PLAY-027"
        / "industrial-l04-north-art-v03/SCENE.json"
    )
    require(digest(v03_path) == V03_SCENE_SHA256, "v03 scene drift")
    require(digest(materials_path) == MATERIAL_SHA256, "material drift")
    v03 = json.loads(v03_path.read_text())
    scene = json.loads(scene_path.read_text())
    materials = json.loads(materials_path.read_text())

    require(scene["sourceRevision"] == "blender-art-v05", "revision")
    require(scene["viewDirection"] == "north", "direction")
    require(scene["orientationTransform"] == "none", "orientation")
    require(scene["sourceAuthority"] is False, "source authority")
    require(scene["productionSelected"] is False, "production selection")
    for key in ("camera", "light", "shadow", "cycles"):
        require(scene[key] == v03[key], f"{key} drift")
    registration = scene["registration"]
    v03_registration = v03["registration"]
    for key in (
        "sceneFootprintUnits",
        "tileBasisPoints",
        "contactPolygonWorld",
        "footprintPolygonSource",
        "groundPivotSource",
        "frontageSocketSource",
        "presentationEnvelopeSource",
    ):
        require(
            registration[key] == v03_registration[key],
            f"registration drift: {key}",
        )
    require(
        registration["frontageWorld"]["roadEdgeX"] == -28,
        "North road edge",
    )
    require(
        registration["frontageWorld"]["portalFacing"] == "negative-x",
        "portal facing",
    )

    components = scene["components"]
    by_id = {item["id"]: item for item in components}
    require(len(by_id) == len(components), "duplicate component ID")
    material_ids = {item["id"] for item in materials["materials"]}
    unresolved = sorted(
        {
            item["materialID"]
            for item in components
            if item["materialID"] not in material_ids
        }
    )
    require(not unresolved, f"unresolved materials: {unresolved}")

    retired_ids = {
        "foundry-private-apron",
        "foundry-v03-north-apron-link",
        "foundry-v03-socket-apron-link",
        "foundry-hall-west-core",
        "foundry-facade-north-segment",
        "foundry-facade-south-segment",
        "foundry-facade-upper-header",
        "foundry-lower-hall-roof",
        "foundry-lower-hall-roof-edge",
    }
    require(not retired_ids.intersection(by_id), "retired v03 geometry remains")

    portal_ids = {
        "foundry-portal-inset",
        "foundry-portal-jamb-north",
        "foundry-portal-jamb-south",
        "foundry-portal-header",
        "foundry-portal-reveal-north",
        "foundry-portal-reveal-south",
        "foundry-portal-reveal-top",
        "foundry-v05-threshold",
    }
    require(portal_ids.issubset(by_id), "incomplete portal assembly")
    for identifier in (
        "foundry-portal-jamb-north",
        "foundry-portal-jamb-south",
        "foundry-portal-header",
        "foundry-v05-socket-court",
    ):
        minimum, _ = bounds(by_id[identifier])
        require(abs(minimum[0] + 28.0) <= 0.0001, f"X=-28 binding: {identifier}")
    threshold_minimum, threshold_maximum = bounds(
        by_id["foundry-v05-threshold"]
    )
    require(
        threshold_minimum[0] > -28.0
        and threshold_maximum[0] <= -20.0,
        "threshold must be inside footprint",
    )
    require(
        scene["frontageConnectivity"]["outwardNormalWorld"] == [-1, 0, 0],
        "threshold outward normal",
    )

    footprint = registration["contactPolygonWorld"]
    require(footprint == [[-28, -28], [28, -28], [28, 28], [-28, 28]], "footprint")
    for item in components:
        minimum, maximum = bounds(item)
        require(minimum[0] >= -28.0001 and maximum[0] <= 28.0001, f"X bounds: {item['id']}")
        require(minimum[2] >= -28.0001 and maximum[2] <= 28.0001, f"Z bounds: {item['id']}")
        require(minimum[1] >= -0.0001, f"ground penetration: {item['id']}")

    aperture = {
        "id": "governed-v05-aperture",
        "position": [-24, 9, 0],
        "dimensions": [7.4, 15.6, 31.2],
    }
    allowed_aperture = portal_ids | {
        "foundry-v05-socket-court",
        "foundry-v05-threshold",
    }
    aperture_conflicts = sorted(
        item["id"]
        for item in components
        if item["id"] not in allowed_aperture
        and positive_overlap(item, aperture)
    )
    require(
        not aperture_conflicts,
        f"solid overlaps portal aperture: {aperture_conflicts}",
    )

    process_ids = set(scene["portal"]["processOccluderIDs"])
    process_aperture_conflicts = sorted(
        identifier
        for identifier in process_ids
        if positive_overlap(by_id[identifier], aperture)
    )
    require(
        not process_aperture_conflicts,
        f"process overlaps portal: {process_aperture_conflicts}",
    )
    require(
        scene["frontageConnectivity"]["apronComponentIDs"]
        == ["foundry-v05-socket-court", "foundry-v05-threshold"],
        "visible court/threshold authority",
    )
    require(
        scene["portal"]["minimumCompactInsetPixels"] == [15, 13],
        "v03 portal compact minimum",
    )
    require(
        scene["staffEntry"]["minimumCompactBounds"] == [4, 8],
        "v03 staff compact minimum",
    )
    require(
        scene["roofRhythm"] == v03["roofRhythm"],
        "four-monitor contract drift",
    )
    require(
        scene["staffEntry"]["componentIDs"]
        == v03["staffEntry"]["componentIDs"],
        "staff component contract drift",
    )

    preserved_ids = (
        set(item["id"] for item in v03["components"])
        - retired_ids
        - portal_ids
    )
    changed = []
    v03_by_id = {item["id"]: item for item in v03["components"]}
    for identifier in sorted(preserved_ids & set(by_id)):
        if by_id[identifier] != v03_by_id[identifier]:
            changed.append(identifier)
    authorized_changed = {
        "foundry-monitor-a",
        "foundry-monitor-a-cap",
        "foundry-monitor-b",
        "foundry-monitor-b-cap",
        "foundry-monitor-c",
        "foundry-monitor-c-cap",
        "foundry-monitor-d",
        "foundry-monitor-d-cap",
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
    require(
        set(changed) == authorized_changed,
        f"unexpected preserved-component changes: {changed}",
    )

    result = {
        "schema": 1,
        "task": "PLAY-027",
        "sourceRevision": scene["sourceRevision"],
        "sceneGeometryID": scene["sceneGeometryID"],
        "sceneSHA256": digest(scene_path),
        "materialLibrarySHA256": digest(materials_path),
        "componentCount": len(components),
        "materialCount": len(materials["materials"]),
        "portalAssemblyComplete": True,
        "portalPlane": "X=-28 / negative-x",
        "apertureSolidOverlapCount": len(aperture_conflicts),
        "processApertureOverlapCount": len(process_aperture_conflicts),
        "footprintPreserved": True,
        "pivotPreserved": True,
        "socketPreserved": True,
        "cameraPreserved": True,
        "lightPreserved": True,
        "shadowPreserved": True,
        "cyclesPreserved": True,
        "staffContractPreserved": True,
        "roofRhythmContractPreserved": True,
        "authorizedChangedPreservedComponentIDs": changed,
        "rawProcessCount": 0,
        "sourceAuthority": False,
        "productionSelected": False,
        "validationPassed": True,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical_bytes(result))
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
