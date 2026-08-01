#!/usr/bin/env python3
"""Pure-data West v13 compatibility proof; never launches DCC or reads sibling geometry."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parents[6]
SOURCE_ROOT = REPOSITORY_ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01"
V13_ROOT = SOURCE_ROOT / "v13-compatibility-v01"
EVIDENCE_ROOT = REPOSITORY_ROOT / "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/v13-compatibility-v01"
DESIGN_PATH = V13_ROOT / "WEST-V13-DESIGN.json"
MATERIAL_PATH = V13_ROOT / "WEST-V13-MATERIALS.json"
LOWERING_PATH = V13_ROOT / "WEST-V13-LOWERING.json"
RESULT_PATH = EVIDENCE_ROOT / "V13-COMPATIBILITY-RESULT.json"
PUBLISHED_DESIGN = REPOSITORY_ROOT / "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/design-authority-v01/DESIGN-AUTHORITY.json"
PUBLISHED_MATERIALS = REPOSITORY_ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/DESIGN-MATERIALS.json"
EXPECTED_DESIGN_SHA = "1b1006403081c3933c54451b6c506af74493a2ac3b253fdd9f1f79098d7c1bed"
EXPECTED_MATERIALS_SHA = "c8179b77a184e41b723e26b34e7da2ef256b09e93b54a47e76cc5103f22b8cab"
EXPECTED_CLAIM_SHA = "f3b51269139bef088e4661f578dd882139a685d1c7fde26db8473f15c536882e"
EXPECTED_BASE = "d010d453af87c040ac13e8b3b7280366cb5094c1"
EXPECTED_ROLES = {
    "grounded-foundation", "integrated-operating-apron", "warm-foundry-masonry",
    "warm-control-masonry", "charcoal-structural-steel", "portal-crown-steel",
    "weathered-bluegreen-roof", "clerestory-and-roof-edge", "deep-freight-void",
    "oxidized-process-machinery", "restrained-hot-process", "warm-staff-glazing",
}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def intersects(left: dict[str, list[float]], right: dict[str, list[float]]) -> bool:
    return all(left["min"][axis] < right["max"][axis] and right["min"][axis] < left["max"][axis] for axis in ("x", "y", "z"))


def main() -> int:
    design = load(DESIGN_PATH)
    materials = load(MATERIAL_PATH)
    lowering = load(LOWERING_PATH)
    result = load(RESULT_PATH)
    published_design = load(PUBLISHED_DESIGN)
    published_materials = load(PUBLISHED_MATERIALS)

    require(sha256(PUBLISHED_DESIGN) == EXPECTED_DESIGN_SHA, "published design authority drift")
    require(sha256(PUBLISHED_MATERIALS) == EXPECTED_MATERIALS_SHA, "published material authority drift")
    require(published_design.get("design", {}).get("conceptName") == "Portal Crown Foundry", "design vocabulary binding")
    published_roles = {item["role"] for item in published_materials["materials"]}
    require(published_roles == EXPECTED_ROLES, "published role set drift")

    require(design["task"] == "PLAY-081" and design["direction"] == "west", "task or direction")
    require(design["authorityBindings"]["publishedBase"] == EXPECTED_BASE, "published base")
    require(design["authorityBindings"]["claim"]["sha256"] == EXPECTED_CLAIM_SHA, "claim hash")
    require(design["independence"]["orientationTransform"] == "none", "orientation transform")
    require(design["independence"]["siblingInputsConsumed"] == [], "sibling inputs")
    require(design["sourceAuthority"] is False and design["pixelRenderingAuthorized"] is False, "source boundary")

    registration = design["registration"]
    require(registration["frontageEdge"] == "west", "frontage")
    require(registration["frontageSocketWorldXYZ"] == [-28, 0, 0], "CitySim West socket")
    require(registration["frontageSocketBlenderXYZ"] == [0, -28, 0], "Blender bridge socket")
    require(registration["frontageSocketSourceXY"] == [640, 704], "source socket")
    require(registration["groundPivotWorldXYZ"] == [28, 0, 28], "pivot")
    require(registration["contactPolygonWorldXZ"] == [[-28, -28], [28, -28], [28, 28], [-28, 28]], "footprint")
    require(design["camera"]["projection"] == "orthographic-2:1", "camera projection")

    def project(x: float, y: float, z: float) -> tuple[float, float]:
        return (768 + (32 / 7) * (x - z), 768 + (16 / 7) * (x + z) - 8 * y)

    require(project(-28, 0, 0) == (640.0, 704.0), "socket projection")
    require(project(28, 0, 28) == (768.0, 896.0), "pivot projection")
    require(lowering["projection"]["registrationErrorSourcePixels"] == 0, "lowering registration")
    require(lowering["registration"]["sourceSocket"] == [640, 704], "lowering socket")

    aperture = design["portalCrown"]["apertureInteriorAABBWorldXYZ"]
    for component in design["components"]:
        if component.get("processOccluder"):
            require(not intersects(component["aabb"], aperture), f"process intrudes aperture: {component['id']}")
    require(design["portalCrown"]["processOcclusionAreaPixels"] == 0, "process occlusion")
    require(design["portalCrown"]["silhouetteBreakCount"] >= 3, "silhouette breaks")
    require(design["literal192Feasibility"]["portalInsetWidthPixels"] >= 14, "literal portal width")
    require(design["literal192Feasibility"]["portalInsetHeightPixels"] >= 12, "literal portal height")
    require(design["literal192Feasibility"]["registrationErrorPixels"] == 0, "literal registration")

    component_ids = [component["id"] for component in design["components"]]
    require(len(component_ids) == len(set(component_ids)), "duplicate component IDs")
    bound_roles = {item["role"] for item in materials["roleBindings"]}
    require(bound_roles == EXPECTED_ROLES, "material role completeness")
    require({item["role"] for item in materials["roleBindings"]} == published_roles, "material alias or omission")
    require(materials["publishedRoleAuthority"]["sha256"] == EXPECTED_MATERIALS_SHA, "material authority binding")

    zero = design["zeroPixelBoundary"]
    require(all(zero[key] == 0 for key in ("blenderProcessLaunches", "dccInvocations", "renderInvocations", "pixelFiles")), "zero-pixel activity")
    require(all(lowering["zeroPixelBoundary"][key] == 0 for key in ("blenderProcessLaunches", "dccInvocations", "renderInvocations", "imageGenInvocations", "normalizerInvocations", "pixelFiles")), "lowering activity")
    require(result["result"] == "PASS", "evidence result")
    require(result["task"] == "PLAY-081" and result["direction"] == "west", "evidence identity")
    require(result["sourceReady"] is False and result["candidateReadyForIndependentReview"] is True, "evidence readiness")
    require(result["westBinding"]["siblingInputsConsumed"] == [] and result["westBinding"]["orientationTransform"] == "none", "evidence isolation")
    require(result["bindings"]["design"]["sha256"] == sha256(DESIGN_PATH), "design evidence hash")
    require(result["bindings"]["materials"]["sha256"] == sha256(MATERIAL_PATH), "materials evidence hash")
    require(result["bindings"]["lowering"]["sha256"] == sha256(LOWERING_PATH), "lowering evidence hash")
    require(result["analyticProof"]["socketSourceXY"] == [640, 704], "analytic socket evidence")
    require(result["analyticProof"]["processOcclusionAreaPixels"] == 0, "analytic occlusion evidence")
    require(result["activity"]["blenderProcessLaunches"] == 0 and result["activity"]["pixelFiles"] == 0, "evidence activity")

    pixel_suffixes = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr", ".blend"}
    generated = [path for path in V13_ROOT.rglob("*") if path.is_file() and path.suffix.lower() in pixel_suffixes]
    require(not generated, f"pixel or binary output present: {generated}")
    print("PASS v13-west-compatibility portal=PASS socket=PASS pivot=PASS footprint=PASS aperture=PASS materials=PASS literal192=PASS zeroPixel=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
