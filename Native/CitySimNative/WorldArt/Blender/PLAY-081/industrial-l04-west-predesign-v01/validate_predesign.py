#!/usr/bin/env python3
"""Static, zero-pixel validation for the independently authored PLAY-081 scene."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--scene", required=True)
    parser.add_argument("--materials", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    scene_path = (root / args.scene).resolve()
    materials_path = (root / args.materials).resolve()
    output_path = (root / args.output).resolve()
    scene = json.loads(scene_path.read_text())
    materials = json.loads(materials_path.read_text())

    failures: list[str] = []
    checks: list[dict[str, object]] = []

    def check(name: str, condition: bool, detail: object) -> None:
        checks.append({"name": name, "passed": condition, "detail": detail})
        if not condition:
            failures.append(name)

    independence = scene["independence"]
    check("task-and-direction", scene["task"] == "PLAY-081" and scene["direction"] == "west", {
        "task": scene["task"],
        "direction": scene["direction"],
    })
    check("predesign-only-authority", not any([
        scene["sourceAuthority"],
        scene["productionSelected"],
        scene["pixelRenderingAuthorized"],
        scene["normalizationAuthorized"],
        scene["rendererIngestionAuthorized"],
    ]), scene["disposition"])
    check("independent-no-transform", (
        not independence["authoredFromSiblingScene"]
        and not independence["siblingSceneOpened"]
        and not independence["siblingGeometryConsumed"]
        and not independence["mirror"]
        and not independence["rotation"]
        and not independence["transform"]
        and independence["orientationTransform"] == "none"
    ), independence)
    check("catalog-missing-not-aliased", (
        scene["catalogAudit"]["publishedAcceptedDirectionalSources"] == 0
        and scene["catalogAudit"]["disposition"] == "MISSING_NOT_ALIASED"
    ), scene["catalogAudit"])

    registration = scene["registration"]
    check("frozen-footprint", registration["contactPolygonWorldXZ"] == [
        [-28, -28], [28, -28], [28, 28], [-28, 28]
    ], registration["contactPolygonWorldXZ"])
    check("west-socket", (
        registration["frontageSocketWorldXYZ"] == [-28, 0, 0]
        and registration["frontageSocketExpectedSource"] == [640, 704]
        and registration["frontageEdge"] == "west"
    ), {
        "world": registration["frontageSocketWorldXYZ"],
        "source": registration["frontageSocketExpectedSource"],
    })
    check("frozen-pivot", (
        registration["groundPivotWorldXYZ"] == [28, 0, 28]
        and registration["groundPivotExpectedSource"] == [768, 896]
    ), {
        "world": registration["groundPivotWorldXYZ"],
        "source": registration["groundPivotExpectedSource"],
    })

    component_ids = [component["id"] for component in scene["components"]]
    check("unique-component-ids", len(component_ids) == len(set(component_ids)), component_ids)
    role_names = set(materials["roles"])
    missing_roles = sorted({
        component["materialRole"] for component in scene["components"]
    } - role_names)
    check("complete-material-binding", not missing_roles, missing_roles)
    check("provisional-material-lock", (
        materials["bindingState"] == "PROVISIONAL_NUMERIC_ROLES_PENDING_NORTH_FAMILY_MATERIAL_LOCK"
        and not materials["familyMaterialLockConsumed"]
        and not materials["pixelRenderingAuthorized"]
    ), materials["bindingState"])

    out_of_bounds: list[dict[str, object]] = []
    below_ground: list[str] = []
    above_envelope: list[str] = []
    envelope_top = registration["verticalEnvelopeWorld"][1]
    for component in scene["components"]:
        center = component["centerWorldXYZ"]
        size = component["sizeWorldXYZ"]
        bounds = [
            center[index] - size[index] / 2 for index in range(3)
        ] + [
            center[index] + size[index] / 2 for index in range(3)
        ]
        if bounds[0] < -28 or bounds[3] > 28 or bounds[2] < -28 or bounds[5] > 28:
            out_of_bounds.append({"id": component["id"], "bounds": bounds})
        if bounds[1] < 0:
            below_ground.append(component["id"])
        if bounds[4] > envelope_top:
            above_envelope.append(component["id"])
    check("all-components-inside-footprint", not out_of_bounds, out_of_bounds)
    check("all-components-on-ground", not below_ground, below_ground)
    check("vertical-envelope", not above_envelope, above_envelope)

    portal = scene["portal"]
    required_portal_ids = {
        portal["insetComponentID"],
        portal["headerComponentID"],
        *portal["jambComponentIDs"],
        *portal["frameComponentIDs"],
    }
    check("complete-monumental-portal", required_portal_ids.issubset(component_ids), sorted(required_portal_ids))
    socket_line = portal["socketConnectionPolylineWorldXYZ"]
    check("apron-connects-exact-west-socket", (
        socket_line[0] == registration["frontageSocketWorldXYZ"]
        and socket_line[-1][0] == -20
    ), socket_line)

    values = {name: role["grayscaleTarget"] for name, role in materials["roles"].items()}
    targets = scene["literal192Targets"]
    check("frame-wall-value-separation", (
        abs(values["portal-frame"] - values["masonry-mid"])
        >= targets["portalFrameToWallMinimumGrayscaleDelta"]
    ), abs(values["portal-frame"] - values["masonry-mid"]))
    check("frame-process-value-separation", (
        abs(values["portal-frame"] - values["gantry-steel"])
        >= targets["portalFrameToProcessMinimumGrayscaleDelta"]
    ), abs(values["portal-frame"] - values["gantry-steel"]))
    check("zero-pixel-processes", all(value == 0 for value in scene["processCounts"].values()), scene["processCounts"])

    report = {
        "schema": 1,
        "task": "PLAY-081",
        "proof": "STATIC_ZERO_PIXEL_PREDESIGN",
        "predesignID": scene["predesignID"],
        "sceneSHA256": sha256(scene_path),
        "materialBindingSHA256": sha256(materials_path),
        "checks": checks,
        "failureCount": len(failures),
        "failures": failures,
        "passed": not failures,
        "processCounts": scene["processCounts"],
        "sourceAuthority": False,
        "productionSelected": False,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
