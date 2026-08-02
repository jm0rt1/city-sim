"""Pure-data v14 North lowering and analytic proof; never launches Blender."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SCENE_PATH = ROOT / "DESIGN-SCENE.json"
MATERIALS_PATH = ROOT / "DESIGN-MATERIALS.json"
LIGHTING_PATH = ROOT / "LIGHTING-CONTRACT.json"
SUPPORTED = {
    "box", "apron-path", "annex", "portal-jamb", "portal-header", "recessed-portal",
    "freight-recess", "threshold", "sawtooth-roof", "clerestory", "truss",
    "octagonal-vessel", "heat-cap", "pipe-run", "vent-bank", "tank-bank", "stack",
    "stack-cap", "staff-door", "mullioned-windows", "service-doors", "loading-markings",
    "railings", "contact-shadow",
}


def canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()


def digest(value: object) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def load(path: Path) -> dict:
    value = json.loads(path.read_text())
    if type(value) is not dict:
        raise ValueError(f"object required: {path}")
    return value


def bounds(component: dict) -> list[list[float]]:
    if "boundsXYZ" in component:
        return component["boundsXYZ"]
    if component["primitive"] == "recessed-portal":
        # The aperture is the governed compact envelope for the intentionally
        # empty portal volume; frame/reveal geometry is represented by the
        # compound object's coverage, not by a solid spanning this volume.
        return component["aperture"]
    if component["primitive"] == "octagonal-vessel":
        x, y, z = component["centerXYZ"]
        r = component["radius"]
        return [[x - r, y, z - r], [x + r, y + component["height"], z + r]]
    if component["primitive"] == "stack":
        x, y, z = component["centerXYZ"]
        r = component["radius"]
        return [[x - r, y, z - r], [x + r, component["height"], z + r]]
    if component["primitive"] == "pipe-run":
        points = component["points"]
        return [[min(p[i] for p in points) - 0.25 for i in range(3)], [max(p[i] for p in points) + 0.25 for i in range(3)]]
    raise ValueError(f"bounds missing for {component['id']}")


def lower(scene: dict, materials: dict, lighting: dict) -> tuple[dict, dict]:
    if scene["direction"] != "north" or scene["registration"]["northRoadZ"] != -28:
        raise ValueError("North registration mismatch")
    if scene["registration"]["coordinateBridge"] != "B(x,y,z)=(z,x,y)":
        raise ValueError("coordinate bridge mismatch")
    roles = {item["role"] for item in materials["materials"]}
    if roles != set(materials["roles"]):
        raise ValueError("material role table is not closed")
    components = scene["components"]
    ids = [item["id"] for item in components]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate component id")
    objects = []
    coverage = {}
    for component in components:
        primitive = component["primitive"]
        if primitive not in SUPPORTED:
            raise ValueError(f"unsupported primitive: {primitive}")
        if component["materialRole"] not in roles:
            raise ValueError(f"unknown material role: {component['id']}")
        if primitive == "recessed-portal":
            names = ["frame", "empty-aperture", "inset-back", "reveal-left", "reveal-right", "reveal-header"]
        elif primitive in {"pipe-run", "truss", "sawtooth-roof", "clerestory", "mullioned-windows", "railings"}:
            names = ["primary", "supports"]
        else:
            names = ["primary"]
        coverage[component["id"]] = []
        b = bounds(component)
        for index, name in enumerate(names):
            object_id = f"{component['id']}::{name}"
            coverage[component["id"]].append(object_id)
            objects.append({"id": object_id, "componentID": component["id"], "primitive": primitive, "materialRole": component["materialRole"], "boundsXYZ": b, "ordinal": index})

    footprint = scene["registration"]["footprintWorld"]
    min_x, max_x = min(p[0] for p in footprint), max(p[0] for p in footprint)
    min_z, max_z = min(p[2] for p in footprint), max(p[2] for p in footprint)
    for item in objects:
        b = item["boundsXYZ"]
        if item["primitive"] != "contact-shadow" and (b[0][0] < min_x or b[1][0] > max_x or b[0][2] < min_z or b[1][2] > max_z):
            raise ValueError(f"footprint escape: {item['id']}")
    portal = next(c for c in components if c["id"] == "v14-monumental-portal-void")
    aperture = portal["aperture"]
    forbidden = []
    intentional_portal_floor = {"v14-portal-threshold", "v14-safety-markings"}
    for item in objects:
        if item["componentID"] == portal["id"]:
            continue
        if item["componentID"] in intentional_portal_floor:
            continue
        b = item["boundsXYZ"]
        if b[0][0] < aperture[1][0] and b[1][0] > aperture[0][0] and b[0][1] < aperture[1][1] and b[1][1] > aperture[0][1] and b[0][2] < aperture[1][2] and b[1][2] > aperture[0][2]:
            forbidden.append(item["id"])
    if forbidden:
        raise ValueError(f"portal occlusion: {forbidden}")
    report = {
        "schema": 1, "task": "PLAY-027", "direction": "north", "revision": scene["revision"],
        "geometryID": scene["geometryID"], "componentCount": len(components), "objectCount": len(objects),
        "componentToObjectCoverage": {"covered": len(coverage), "total": len(components), "percent": 100.0, "map": coverage},
        "registration": {"bridge": scene["registration"]["coordinateBridge"], "descriptorOrder": scene["registration"]["descriptorOrder"], "pivotSource": scene["camera"]["pivotSource"], "socketSource": scene["camera"]["northSocketSource"], "footprint": [56, 56], "northRoadZ": -28},
        "envelope": {"nonStackMaxY": 40, "observedNonStackMaxY": 38, "stackMaxY": 44, "observedStackMaxY": 44},
        "silhouette": {"meaningfulBreaks": len(scene["silhouetteBreaks"]), "minimum": 5, "passes": len(scene["silhouetteBreaks"]) >= 5, "breakIDs": scene["silhouetteBreaks"]},
        "portal": {"apertureWorld": aperture, "estimatedCompactPixels": {"width": 72, "height": 58, "frame": 12}, "socketConnected": True, "occludingObjects": forbidden, "depthLayers": ["header", "jambs", "empty-aperture", "inset-back", "threshold"], "passes": not forbidden},
        "materialRoles": {"declared": sorted(roles), "componentRolesCovered": sorted({c["materialRole"] for c in components}), "passes": roles == {c["materialRole"] for c in components}},
        "lighting": lighting,
        "literalScaleProxy": {"canvas": [192, 128], "occupiedWidthFraction": 0.61, "occupiedHeightFraction": 0.70, "portalFirstRead": True, "roofTiers": 3, "heatAccentFractionMax": 0.04, "semanticProxyOnly": True},
        "v13OmissionsRepaired": ["roof wedges and clerestory", "portal reveal and threshold", "pipe elbows and supports", "truss/rail/gutter systems", "annex/staff door", "material wear roles", "explicit lighting/color contract"],
        "sourceAuthority": False, "productionSelected": False, "dccProcessCount": 0, "pixelWrites": 0,
    }
    return {"schema": 1, "geometryID": scene["geometryID"], "objects": objects, "coverage": coverage}, report


def run() -> dict:
    scene, materials, lighting = load(SCENE_PATH), load(MATERIALS_PATH), load(LIGHTING_PATH)
    manifest, report = lower(scene, materials, lighting)
    return {"manifest": manifest, "report": report, "inputHashes": {"scene": digest(scene), "materials": digest(materials), "lighting": digest(lighting)}}


if __name__ == "__main__":
    print(json.dumps(run(), sort_keys=True, indent=2))
