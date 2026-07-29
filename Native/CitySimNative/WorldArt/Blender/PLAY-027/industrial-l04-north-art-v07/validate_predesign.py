#!/usr/bin/env python3
"""Static fail-closed validator for PLAY-027 North art v07."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def inside(root: Path, relative: str) -> Path:
    path = (root / relative).resolve()
    path.relative_to(root)
    return path


def bounds(component: dict[str, Any]) -> list[list[float]]:
    return [
        [
            float(component["position"][axis])
            - float(component["dimensions"][axis]) / 2.0
            for axis in range(3)
        ],
        [
            float(component["position"][axis])
            + float(component["dimensions"][axis]) / 2.0
            for axis in range(3)
        ],
    ]


def intersects(first: list[list[float]], second: list[list[float]]) -> bool:
    return all(
        first[0][axis] < second[1][axis]
        and first[1][axis] > second[0][axis]
        for axis in range(3)
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--scene", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    root = args.repository_root.resolve()
    scene_path = inside(root, args.scene)
    output_path = inside(root, str(args.output))
    scene = load_json(scene_path)
    bridge_path = inside(root, scene["coordinateBridge"]["file"])
    materials_path = inside(root, scene["materialLibrary"]["file"])
    bridge = load_json(bridge_path)
    materials = load_json(materials_path)

    require(scene["schema"] == 1, "scene schema")
    require(scene["task"] == "PLAY-027", "task")
    require(scene["logicalBuildingID"] == "industrial_l04", "logical ID")
    require(scene["variantID"] == "variant-0", "variant")
    require(scene["viewDirection"] == "north", "direction")
    require(
        scene["sourceRevision"] == "blender-art-v07-prepixel",
        "revision",
    )
    require(scene["orientationTransform"] == "none", "orientation transform")
    require(scene["authoredIndependently"] is True, "authorship")
    require(scene["sourceAuthority"] is False, "source authority")
    require(scene["productionSelected"] is False, "production selection")
    require(scene["pixelProduction"] == "not_produced", "pixel production")
    require(
        scene["processes"]
        == {"A": "not_produced", "B": "not_produced", "C": "not_produced"},
        "process boundary",
    )

    require(
        sha256(bridge_path) == scene["coordinateBridge"]["sha256"],
        "bridge hash",
    )
    require(
        bridge["basis"]["formula"] == "B(CitySim[x,y,z])=Blender[z,x,y]",
        "bridge formula",
    )
    require(
        bridge["basis"]["sourceOrder"] == [0, 1, 2, 3],
        "descriptor order",
    )
    require(
        sha256(materials_path) == scene["materialLibrary"]["sha256"],
        "material hash",
    )

    registration = scene["registration"]
    require(
        registration["contactPolygonWorld"]
        == [[-28, -28], [28, -28], [28, 28], [-28, 28]],
        "contact polygon",
    )
    require(
        registration["footprintPolygonSource"]
        == [[768, 640], [1024, 768], [768, 896], [512, 768]],
        "footprint source",
    )
    require(registration["groundPivotWorld"] == [28, 0, 28], "pivot world")
    require(registration["groundPivotSource"] == [768, 896], "pivot source")
    require(
        registration["frontageSocketWorld"] == [0, 0, -28],
        "North socket world",
    )
    require(
        registration["frontageSocketSource"] == [896, 704],
        "North socket source",
    )
    require(
        registration["frontageWorld"]["roadEdgeZ"] == -28
        and registration["frontageWorld"]["outwardNormal"] == [0, 0, -1],
        "canonical North frontage",
    )

    components = scene["components"]
    component_ids = [component["id"] for component in components]
    require(len(component_ids) == len(set(component_ids)), "component IDs")
    allowed_shapes = {"box", "octagonal-prism"}
    require(
        all(component["shape"] in allowed_shapes for component in components),
        "component shape",
    )
    material_ids = {record["id"] for record in materials["materials"]}
    unresolved = sorted(
        {
            component["materialID"]
            for component in components
            if component["materialID"] not in material_ids
        }
    )
    require(not unresolved, f"unresolved materials: {unresolved}")

    component_bounds = {
        component["id"]: bounds(component) for component in components
    }
    for component_id, value in component_bounds.items():
        require(value[0][0] >= -28, f"x min {component_id}")
        require(value[1][0] <= 28, f"x max {component_id}")
        require(value[0][2] >= -28, f"z min {component_id}")
        require(value[1][2] <= 28, f"z max {component_id}")
        require(value[0][1] >= 0, f"ground bearing {component_id}")

    architecture = scene["architecture"]
    required_architecture_ids = set(
        architecture["northCourtComponentIDs"]
        + architecture["splitWingComponentIDs"]
        + architecture["monumentalThroatFrameIDs"]
        + architecture["freightRecessIDs"]
        + architecture["staffEntryIDs"]
    )
    require(
        required_architecture_ids.issubset(set(component_ids)),
        "architecture component references",
    )

    court_spine = component_bounds["north-v07-court-spine"]
    court_head = component_bounds["north-v07-court-head"]
    require(court_spine[0][2] == -28, "court must reach North road edge")
    require(court_spine[0][0] <= 0 <= court_spine[1][0], "socket x")
    require(court_spine[1][2] >= court_head[0][2], "court continuity")
    require(court_head[0][0] <= court_spine[0][0], "hammerhead west reach")
    require(court_head[1][0] >= court_spine[1][0], "hammerhead east reach")

    west_wing = component_bounds["north-v07-west-foundry-wing"]
    east_wing = component_bounds["north-v07-east-assembly-wing"]
    require(west_wing[1][0] <= -15, "west wing court clearance")
    require(east_wing[0][0] >= 15, "east wing court clearance")
    require(
        not intersects(west_wing, court_spine)
        and not intersects(east_wing, court_spine),
        "split wings overlap court",
    )

    aperture = scene["visibilityTargets"]["throatApertureCitySimAABB"]
    allowed_aperture = set(
        architecture["northCourtComponentIDs"]
        + architecture["monumentalThroatFrameIDs"]
    )
    aperture_overlap_ids = sorted(
        component_id
        for component_id, value in component_bounds.items()
        if component_id not in allowed_aperture and intersects(value, aperture)
    )
    require(
        not aperture_overlap_ids,
        f"aperture solid overlap: {aperture_overlap_ids}",
    )

    monitor_ids = [
        component_id
        for component_id in component_ids
        if component_id.startswith("north-v07-monitor-")
    ]
    require(len(monitor_ids) == 4, "four roof monitors")
    freight_ids = architecture["freightRecessIDs"]
    require(len(freight_ids) == 3, "three freight recesses")
    require(
        max(value[1][1] for value in component_bounds.values()) >= 56,
        "L4 vertical identity",
    )
    require(
        west_wing[0][0] == -28 and east_wing[1][0] == 28,
        "full footprint width",
    )

    report = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "predesign-static",
        "sceneSHA256": sha256(scene_path),
        "bridgeSHA256": sha256(bridge_path),
        "materialLibrarySHA256": sha256(materials_path),
        "componentCount": len(components),
        "materialCount": len(materials["materials"]),
        "unresolvedMaterialIDs": unresolved,
        "componentBoundsPassed": True,
        "canonicalNorthPassed": True,
        "descriptorOrder": bridge["basis"]["sourceOrder"],
        "courtReachesRoadEdge": True,
        "courtAndHammerheadConnected": True,
        "splitWingCourtClearancePassed": True,
        "apertureSolidOverlapIDs": aperture_overlap_ids,
        "monitorCount": len(monitor_ids),
        "freightRecessCount": len(freight_ids),
        "pixelInvocationCounts": {
            "render": 0,
            "imageGen": 0,
            "normalizer": 0,
            "contactSheet": 0,
            "raw": 0,
        },
        "sourceAuthority": False,
        "productionSelected": False,
        "validationPassed": True,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(canonical(report))


if __name__ == "__main__":
    main()
