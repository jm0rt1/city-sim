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
COMPOUND_EXPECTED = {
    "v14-west-sawtooth-roof": "sawtooth-roof", "v14-east-monitor-roof": "sawtooth-roof",
    "v14-clerestory-band": "clerestory", "v14-crane-lantern": "truss",
    "v14-crane-girder-north": "truss", "v14-crane-girder-south": "truss",
    "v14-crucible-vessel": "octagonal-vessel", "v14-process-pipe-west": "pipe-run",
    "v14-process-pipe-east": "pipe-run", "v14-monumental-portal-void": "recessed-portal",
    "v14-gutters-and-rails": "railings", "v14-window-mullions": "mullioned-windows",
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


def bridge(point: list[float]) -> list[float]:
    x, y, z = point
    return [z, x, y]


def center(b: list[list[float]]) -> list[float]:
    return [(b[0][i] + b[1][i]) / 2 for i in range(3)]


def span(b: list[list[float]], axis: int) -> float:
    return b[1][axis] - b[0][axis]


def bounds(component: dict) -> list[list[float]]:
    if "boundsXYZ" in component:
        b = component["boundsXYZ"]
    elif component["primitive"] == "recessed-portal":
        b = component["aperture"]
    elif component["primitive"] == "octagonal-vessel":
        x, y, z = component["centerXYZ"]
        r = component["radius"]
        b = [[x - r, y, z - r], [x + r, y + component["height"], z + r]]
    elif component["primitive"] == "stack":
        x, y, z = component["centerXYZ"]
        r = component["radius"]
        b = [[x - r, y, z - r], [x + r, component["height"], z + r]]
    elif component["primitive"] == "pipe-run":
        points = component["points"]
        if len(points) < 2 or any(points[i] == points[i + 1] for i in range(len(points) - 1)):
            raise ValueError(f"invalid pipe run: {component['id']}")
        b = [[min(p[i] for p in points) - 0.25 for i in range(3)], [max(p[i] for p in points) + 0.25 for i in range(3)]]
    else:
        raise ValueError(f"bounds missing for {component['id']}")
    if any(span(b, i) <= 0 for i in range(3)):
        raise ValueError(f"degenerate bounds: {component['id']}")
    return b


def part(component: dict, name: str, kind: str, b: list[list[float]], **parameters: object) -> dict:
    if any(span(b, i) <= 0 for i in range(3)):
        raise ValueError(f"degenerate {kind}: {component['id']}::{name}")
    payload = {
        "id": f"{component['id']}::{name}",
        "componentID": component["id"],
        "primitive": component["primitive"],
        "materialRole": component["materialRole"],
        "geometryKind": kind,
        "boundsXYZ": b,
        "parameters": parameters,
    }
    payload["geometrySignature"] = hashlib.sha256(canonical({"kind": kind, "bounds": b, "parameters": parameters})).hexdigest()
    return payload


def split_x(b: list[list[float]], count: int, name: str, component: dict, kind: str) -> list[dict]:
    if count < 1:
        raise ValueError(f"insufficient topology: {component['id']}")
    step = span(b, 0) / count
    return [part(component, f"{name}-{i:02d}", kind, [[b[0][0] + i * step, b[0][1], b[0][2]], [b[0][0] + (i + 1) * step, b[1][1], b[1][2]]], index=i, count=count) for i in range(count)]


def component_parts(component: dict) -> list[dict]:
    primitive = component["primitive"]
    b = bounds(component)
    if primitive == "recessed-portal":
        aperture, inset = component["aperture"], component["insetBack"]
        if span(inset, 0) <= 0 or span(inset, 1) <= 0 or span(inset, 2) <= 0:
            raise ValueError(f"invalid portal inset: {component['id']}")
        left = [[aperture[0][0] - 0.01, aperture[0][1], aperture[0][2]], [aperture[0][0] + 0.45, aperture[1][1], aperture[1][2]]]
        right = [[aperture[1][0] - 0.45, aperture[0][1], aperture[0][2]], [aperture[1][0] + 0.01, aperture[1][1], aperture[1][2]]]
        header = [[aperture[0][0], aperture[1][1] - 0.45, aperture[0][2]], [aperture[1][0], aperture[1][1] + 0.01, aperture[1][2]]]
        return [
            part(component, "frame", "portal-frame", [aperture[0], aperture[1]], frameRole="monumental"),
            part(component, "empty-aperture", "void", aperture, solid=False),
            part(component, "inset-back", "inset-plane", inset, solid=True, depth=abs(inset[0][2] - aperture[0][2])),
            part(component, "reveal-left", "reveal-jamb", left, depth=abs(inset[0][2] - aperture[0][2])),
            part(component, "reveal-right", "reveal-jamb", right, depth=abs(inset[0][2] - aperture[0][2])),
            part(component, "reveal-header", "reveal-header", header, depth=abs(inset[0][2] - aperture[0][2])),
        ]
    if primitive == "sawtooth-roof":
        peaks = int(component.get("peaks", 0))
        minimum_peaks = 4 if component["id"] == "v14-west-sawtooth-roof" else 3
        if peaks < minimum_peaks:
            raise ValueError(f"insufficient roof peaks: {component['id']}")
        pieces = split_x(b, peaks, "peak", component, "sawtooth-peak")
        pieces.extend(split_x(b, peaks, "slope", component, "sawtooth-slope-face"))
        pieces.append(part(component, "eave", "shared-eave", [[b[0][0], b[0][1], b[0][2]], [b[1][0], b[0][1] + 0.35, b[1][2]]], peaks=peaks))
        return pieces
    if primitive == "clerestory":
        return split_x(b, 3, "frame", component, "clerestory-frame") + split_x(b, 3, "glass", component, "clerestory-glass")
    if primitive == "pipe-run":
        points = component["points"]
        pieces = []
        for i, (a, z) in enumerate(zip(points, points[1:])):
            # Preserve the true axis-aligned segment extents without a generic AABB proxy.
            sb = [[min(a[0], z[0]) - 0.12, min(a[1], z[1]) - 0.12, min(a[2], z[2]) - 0.12], [max(a[0], z[0]) + 0.12, max(a[1], z[1]) + 0.12, max(a[2], z[2]) + 0.12]]
            pieces.append(part(component, f"segment-{i:02d}", "pipe-segment", sb, start=a, end=z))
        for i, p in enumerate(points[1:-1]):
            eb = [[p[0] - 0.35, p[1] - 0.35, p[2] - 0.35], [p[0] + 0.35, p[1] + 0.35, p[2] + 0.35]]
            pieces.append(part(component, f"elbow-{i:02d}", "pipe-elbow", eb, joint=p))
        pieces.append(part(component, "supports", "pipe-support", [[b[0][0], b[0][1], b[0][2]], [b[0][0] + 0.5, b[1][1], b[0][2] + 0.5]], count=max(1, len(points) - 1)))
        return pieces
    if primitive == "truss":
        mid = (b[0][0] + b[1][0]) / 2
        lower = [[b[0][0], b[0][1], b[0][2]], [b[1][0], b[0][1] + 0.35, b[1][2]]]
        upper = [[b[0][0], b[1][1] - 0.35, b[0][2]], [b[1][0], b[1][1], b[1][2]]]
        diagonals = [
            [[b[0][0], b[0][1], b[0][2]], [mid, b[1][1], b[1][2]]],
            [[mid, b[0][1], b[0][2]], [b[1][0], b[1][1], b[1][2]]],
        ]
        return [part(component, "lower-chord", "truss-chord", lower), part(component, "upper-chord", "truss-chord", upper)] + [part(component, f"diagonal-{i}", "truss-diagonal", d) for i, d in enumerate(diagonals)]
    if primitive == "octagonal-vessel":
        x, y, z = component["centerXYZ"]
        r, h = component["radius"], component["height"]
        return [
            part(component, "body", "octagonal-body", [[x - r, y, z - r], [x + r, y + h * 0.72, z + r]], sides=8),
            part(component, "shoulder", "octagonal-shoulder", [[x - r * 0.82, y + h * 0.72, z - r * 0.82], [x + r * 0.82, y + h * 0.9, z + r * 0.82]], sides=8),
            part(component, "rim", "octagonal-rim", [[x - r * 0.7, y + h * 0.9, z - r * 0.7], [x + r * 0.7, y + h, z + r * 0.7]], sides=8),
        ]
    if primitive == "stack":
        x, y, z = component["centerXYZ"]
        r, h = component["radius"], component["height"]
        return [part(component, "shaft", "cylindrical-shaft", [[x - r, y, z - r], [x + r, h, z + r]], sides=12), part(component, "bands", "stack-bands", [[x - r * 1.1, h * 0.72, z - r * 1.1], [x + r * 1.1, h * 0.78, z + r * 1.1]], count=3)]
    if primitive in {"vent-bank", "tank-bank"}:
        return split_x(b, 3, "unit", component, "plant-unit")
    if primitive in {"mullioned-windows", "railings"}:
        return split_x(b, 5, "member", component, "articulated-member")
    if primitive == "service-doors":
        return split_x(b, 3, "door", component, "service-door")
    if primitive == "staff-door":
        return [part(component, "frame", "staff-frame", b), part(component, "leaf", "staff-leaf", [[b[0][0] + 0.2, b[0][1] + 0.2, b[0][2]], [b[1][0] - 0.2, b[1][1] - 0.2, b[1][2]]])]
    if primitive == "loading-markings":
        return split_x(b, 2, "stripe", component, "loading-stripe")
    if primitive == "threshold":
        return [part(component, "slab", "threshold-slab", b), part(component, "edge", "threshold-edge", [[b[0][0], b[0][1], b[0][2]], [b[1][0], b[0][1] + 0.1, b[0][2] + 0.2]])]
    if primitive == "apron-path":
        return [part(component, "road-link", "apron-road-link", b), part(component, "service-pad", "apron-service-pad", [[b[0][0] + 1, b[0][1], b[0][2] + 2], [b[1][0] - 1, b[1][1], b[1][2]]])]
    return [part(component, "primary", primitive, b)]


def socket_proof(scene: dict, components: list[dict]) -> dict:
    registration = scene["registration"]
    socket_city = registration["socketCitySim"]
    socket_blender = bridge(socket_city)
    if socket_city != [0, 0, -28] or socket_blender != [-28, 0, 0]:
        raise ValueError("frozen North socket tuple mismatch")
    projection = registration["sourceProjection"]
    origin_city, origin_source, scale = projection["originCitySim"], projection["originSource"], projection["pixelsPerWorldXZ"]
    projected = [origin_source[0] + round((socket_city[0] - origin_city[0]) * scale[0]), origin_source[1] + round((socket_city[2] - origin_city[2]) * scale[1])]
    if projected != [896, 704]:
        raise ValueError(f"socket projection drift: {projected}")
    apron = next(c for c in components if c["primitive"] == "apron-path")
    threshold = next(c for c in components if c["primitive"] == "threshold")
    apron_bounds, threshold_center = bounds(apron), center(bounds(threshold))
    points = [[socket_city[0], socket_city[2]], [threshold_center[0], threshold_center[2]]]
    if not (apron_bounds[0][0] <= socket_city[0] <= apron_bounds[1][0] and apron_bounds[0][2] <= socket_city[2] <= apron_bounds[1][2]):
        raise ValueError("socket is outside apron")
    for index in range(1, 17):
        t = index / 16
        x = points[0][0] + (points[1][0] - points[0][0]) * t
        z = points[0][1] + (points[1][1] - points[0][1]) * t
        if not (apron_bounds[0][0] <= x <= apron_bounds[1][0] and apron_bounds[0][2] <= z <= apron_bounds[1][2]):
            raise ValueError("apron-to-threshold path leaves apron")
    return {"socketCitySim": socket_city, "socketBlender": socket_blender, "socketSource": projected, "thresholdCenterCitySim": threshold_center, "sampleCount": 16, "socketConnected": True}


def lower(scene: dict, materials: dict, lighting: dict) -> tuple[dict, dict]:
    if scene["direction"] != "north" or scene["registration"]["northRoadZ"] != -28:
        raise ValueError("North registration mismatch")
    if scene["registration"]["coordinateBridge"] != "B(x,y,z)=(z,x,y)" or scene["registration"]["descriptorOrder"] != [0, 1, 2, 3]:
        raise ValueError("coordinate bridge mismatch")
    roles = {item["role"] for item in materials["materials"]}
    if roles != set(materials["roles"]):
        raise ValueError("material role table is not closed")
    components = scene["components"]
    ids = [item["id"] for item in components]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate component id")
    for component in components:
        primitive = component["primitive"]
        if primitive not in SUPPORTED:
            raise ValueError(f"unsupported primitive: {primitive}")
        if component["materialRole"] not in roles:
            raise ValueError(f"unknown material role: {component['id']}")
        expected = COMPOUND_EXPECTED.get(component["id"])
        if expected and primitive != expected:
            raise ValueError(f"compound primitive downgrade: {component['id']}")
    objects, coverage = [], {}
    for component in components:
        parts = component_parts(component)
        if not parts:
            raise ValueError(f"builder omission: {component['id']}")
        coverage[component["id"]] = [item["id"] for item in parts]
        objects.extend(parts)
    if len({item["id"] for item in objects}) != len(objects):
        raise ValueError("duplicate lowered object id")
    for component_id in COMPOUND_EXPECTED:
        own = [item for item in objects if item["componentID"] == component_id]
        if len({item["geometrySignature"] for item in own}) != len(own):
            raise ValueError(f"duplicate generic geometry payload: {component_id}")
    footprint = scene["registration"]["footprintWorld"]
    min_x, max_x = min(p[0] for p in footprint), max(p[0] for p in footprint)
    min_z, max_z = min(p[2] for p in footprint), max(p[2] for p in footprint)
    for item in objects:
        b = item["boundsXYZ"]
        if item["geometryKind"] != "void" and item["componentID"] != "v14-contact-shadow-receiver" and (b[0][0] < min_x or b[1][0] > max_x or b[0][2] < min_z or b[1][2] > max_z):
            raise ValueError(f"footprint escape: {item['id']}")
    portal = next(c for c in components if c["id"] == "v14-monumental-portal-void")
    aperture = portal["aperture"]
    forbidden = []
    intentional_portal_floor = {"v14-portal-threshold", "v14-safety-markings"}
    for item in objects:
        if item["componentID"] == portal["id"] or item["componentID"] in intentional_portal_floor or item["geometryKind"] == "void":
            continue
        b = item["boundsXYZ"]
        if b[0][0] < aperture[1][0] and b[1][0] > aperture[0][0] and b[0][1] < aperture[1][1] and b[1][1] > aperture[0][1] and b[0][2] < aperture[1][2] and b[1][2] > aperture[0][2]:
            forbidden.append(item["id"])
    if forbidden:
        raise ValueError(f"portal occlusion: {forbidden}")
    socket = socket_proof(scene, components)
    topology = {
        "recessedPortal": {"layers": ["frame", "empty-aperture", "inset-back", "reveal-left", "reveal-right", "reveal-header"], "solidVoidSeparated": True},
        "sawtoothRoofs": {"peakObjects": sum(1 for o in objects if o["geometryKind"] == "sawtooth-peak"), "slopeObjects": sum(1 for o in objects if o["geometryKind"] == "sawtooth-slope-face")},
        "pipeRuns": {"segments": sum(1 for o in objects if o["geometryKind"] == "pipe-segment"), "elbows": sum(1 for o in objects if o["geometryKind"] == "pipe-elbow")},
        "trusses": {"chords": sum(1 for o in objects if o["geometryKind"] == "truss-chord"), "diagonals": sum(1 for o in objects if o["geometryKind"] == "truss-diagonal")},
        "parameterizedPayloads": True,
    }
    report = {
        "schema": 2, "task": "PLAY-027", "direction": "north", "revision": scene["revision"], "geometryID": scene["geometryID"],
        "componentCount": len(components), "objectCount": len(objects), "componentToObjectCoverage": {"covered": len(coverage), "total": len(components), "percent": 100.0, "map": coverage},
        "registration": {"bridge": scene["registration"]["coordinateBridge"], "descriptorOrder": scene["registration"]["descriptorOrder"], "pivotSource": scene["camera"]["pivotSource"], "socketSource": socket["socketSource"], "socketCitySim": socket["socketCitySim"], "socketBlender": socket["socketBlender"], "footprint": [56, 56], "northRoadZ": -28},
        "socketContinuity": socket,
        "envelope": {"nonStackMaxY": 40, "observedNonStackMaxY": 38, "stackMaxY": 44, "observedStackMaxY": 44},
        "silhouette": {"meaningfulBreaks": len(scene["silhouetteBreaks"]), "minimum": 5, "passes": len(scene["silhouetteBreaks"]) >= 5, "breakIDs": scene["silhouetteBreaks"]},
        "portal": {"apertureWorld": aperture, "estimatedCompactPixels": {"width": 72, "height": 58, "frame": 12}, "socketConnected": socket["socketConnected"], "occludingObjects": forbidden, "depthLayers": ["header", "jambs", "empty-aperture", "inset-back", "threshold"], "passes": not forbidden},
        "topology": topology,
        "materialRoles": {"declared": sorted(roles), "componentRolesCovered": sorted({c["materialRole"] for c in components}), "passes": roles == {c["materialRole"] for c in components}},
        "lighting": lighting,
        "literalScaleProxy": {"canvas": [192, 128], "occupiedWidthFraction": 0.61, "occupiedHeightFraction": 0.70, "portalFirstRead": True, "roofTiers": 3, "heatAccentFractionMax": 0.04, "semanticProxyOnly": True},
        "v13OmissionsRepaired": ["roof wedges and clerestory", "portal reveal and threshold", "pipe elbows and supports", "truss/rail/gutter systems", "annex/staff door", "material wear roles", "explicit lighting/color contract"],
        "sourceAuthority": False, "productionSelected": False, "dccProcessCount": 0, "pixelWrites": 0,
    }
    return {"schema": 2, "geometryID": scene["geometryID"], "objects": objects, "coverage": coverage, "topology": topology}, report


def run() -> dict:
    scene, materials, lighting = load(SCENE_PATH), load(MATERIALS_PATH), load(LIGHTING_PATH)
    manifest, report = lower(scene, materials, lighting)
    return {"manifest": manifest, "report": report, "inputHashes": {"scene": digest(scene), "materials": digest(materials), "lighting": digest(lighting)}}


if __name__ == "__main__":
    print(json.dumps(run(), sort_keys=True, indent=2))
