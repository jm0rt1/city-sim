#!/usr/bin/env python3
"""Pure-data West v13 bridge/camera/source-space proof.

This validator consumes the frozen v06 mapping and West JSON only.  It never
opens a sibling scene, launches Blender, invokes a DCC, or creates pixels.
Every projection, signature, and metric is derived at validation time and is
also replayed by two fresh Python processes.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
import subprocess
import sys
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
BRIDGE_PATH = REPOSITORY_ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
PUBLISHED_DESIGN = REPOSITORY_ROOT / "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/design-authority-v01/DESIGN-AUTHORITY.json"
PUBLISHED_MATERIALS = REPOSITORY_ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/DESIGN-MATERIALS.json"

EXPECTED_DESIGN_SHA = "1b1006403081c3933c54451b6c506af74493a2ac3b253fdd9f1f79098d7c1bed"
EXPECTED_MATERIALS_SHA = "c8179b77a184e41b723e26b34e7da2ef256b09e93b54a47e76cc5103f22b8cab"
EXPECTED_BRIDGE_SHA = "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
EXPECTED_CLAIM_SHA = "f3b51269139bef088e4661f578dd882139a685d1c7fde26db8473f15c536882e"
EXPECTED_BASE = "d010d453af87c040ac13e8b3b7280366cb5094c1"
EXPECTED_ROUTE = {
    "routeId": "quality-v1:west-v13-frontier-recovery",
    "canonicalRouteSha256": "2bb82b131d0369d2cb4bb896d138cacbcbb406bd27a2bcef58ea6476e99f42d9",
    "carrierCommit": "a07c8c9d10852b3fda7aeff3bfe0e78bec373a39",
    "receiptPath": "docs/production/evidence/INTEGRATION/MODEL-ROUTING-QUALITY-SOUTH-WEST-V13-FRONTIER-RECOVERY-V1.json",
    "receiptSha256": "6deba0b456b4f2ce55d1ee806bac99100daa3ea1d6d42994f627212b85ab9bef",
    "authorityCommit": "d010d453af87c040ac13e8b3b7280366cb5094c1",
    "expectedStartingHead": "b9a9a59930e5e6562d4b5ff389e4045fb8e6c1f2",
}
EXPECTED_ROLES = {
    "grounded-foundation", "integrated-operating-apron", "warm-foundry-masonry",
    "warm-control-masonry", "charcoal-structural-steel", "portal-crown-steel",
    "weathered-bluegreen-roof", "clerestory-and-roof-edge", "deep-freight-void",
    "oxidized-process-machinery", "restrained-hot-process", "warm-staff-glazing",
}
OWNED_ROOTS = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01",
    "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/v13-compatibility-v01",
)
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr", ".blend"}
EPSILON = 1e-8


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def same_value(left: Any, right: Any) -> bool:
    if isinstance(left, (int, float)) and isinstance(right, (int, float)):
        return is_number(left) and is_number(right) and math.isclose(float(left), float(right), rel_tol=EPSILON, abs_tol=EPSILON)
    if isinstance(left, list) and isinstance(right, list):
        return len(left) == len(right) and all(same_value(a, b) for a, b in zip(left, right))
    if isinstance(left, dict) and isinstance(right, dict):
        return set(left) == set(right) and all(same_value(left[key], right[key]) for key in left)
    return left == right


def add_error(errors: list[str], code: str, detail: str = "") -> None:
    errors.append(f"{code}:{detail}" if detail else code)


def vector_sub(left: list[float], right: list[float]) -> list[float]:
    return [float(a) - float(b) for a, b in zip(left, right)]


def vector_dot(left: list[float], right: list[float]) -> float:
    return sum(float(a) * float(b) for a, b in zip(left, right))


def vector_cross(left: list[float], right: list[float]) -> list[float]:
    return [
        left[1] * right[2] - left[2] * right[1],
        left[2] * right[0] - left[0] * right[2],
        left[0] * right[1] - left[1] * right[0],
    ]


def vector_normalize(value: list[float]) -> list[float]:
    length = math.sqrt(vector_dot(value, value))
    if length <= EPSILON:
        raise ValueError("zero camera basis vector")
    return [component / length for component in value]


def parse_aabb(raw: Any, label: str, errors: list[str]) -> tuple[tuple[float, float, float], tuple[float, float, float]] | None:
    if not isinstance(raw, dict) or set(raw) != {"min", "max"}:
        add_error(errors, "aabb-schema", label)
        return None
    lower, upper = raw["min"], raw["max"]
    if not isinstance(lower, list) or not isinstance(upper, list) or len(lower) != 3 or len(upper) != 3:
        add_error(errors, "aabb-schema", label)
        return None
    if not all(is_number(value) for value in lower + upper):
        add_error(errors, "aabb-coordinate", label)
        return None
    lower_tuple = tuple(float(value) for value in lower)
    upper_tuple = tuple(float(value) for value in upper)
    if any(lo >= hi for lo, hi in zip(lower_tuple, upper_tuple)):
        add_error(errors, "aabb-order", label)
        return None
    return lower_tuple, upper_tuple


def intersects_world(left: tuple[tuple[float, float, float], tuple[float, float, float]], right: tuple[tuple[float, float, float], tuple[float, float, float]]) -> bool:
    return all(a_min < b_max and b_min < a_max for a_min, a_max, b_min, b_max in zip(left[0], left[1], right[0], right[1]))


def intersects_source(left: dict[str, Any], right: dict[str, Any]) -> bool:
    return left["min"][0] < right["max"][0] and right["min"][0] < left["max"][0] and left["min"][1] < right["max"][1] and right["min"][1] < left["max"][1]


def process_flags(component: dict[str, Any], errors: list[str]) -> tuple[bool | None, bool | None]:
    top = component.get("processOccluder") if "processOccluder" in component else None
    if top is not None and not isinstance(top, bool):
        add_error(errors, "occluder-flag-schema", str(component.get("id")))
        top = None
    nested_values: list[bool] = []

    def visit(value: Any, path: str) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                child_path = f"{path}.{key}" if path else key
                if key == "processOccluder":
                    if not isinstance(child, bool):
                        add_error(errors, "occluder-flag-schema", f"{component.get('id')}:{child_path}")
                    else:
                        nested_values.append(child)
                else:
                    visit(child, child_path)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                visit(child, f"{path}[{index}]")

    for key, value in component.items():
        if key != "processOccluder":
            visit(value, key)
    nested = nested_values[0] if nested_values else None
    if len(set(nested_values)) > 1:
        add_error(errors, "occluder-flag-disagreement", str(component.get("id")))
    if nested is not None and top is None:
        add_error(errors, "occluder-flag-nesting", str(component.get("id")))
    if nested is not None and top is not None and nested != top:
        add_error(errors, "occluder-flag-disagreement", str(component.get("id")))
    return top, nested


def derive_affine_from_bridge(bridge: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    basis = bridge["basis"]
    if basis["formula"] != "B(CitySim[x,y,z])=Blender[z,x,y]" or basis["matrixRows"] != [[0, 0, 1], [1, 0, 0], [0, 1, 0]] or basis["sourceOrder"] != [0, 1, 2, 3] or basis["determinant"] != 1:
        raise ValueError("bridge basis drift")
    camera = bridge["camera"]
    width, height = camera["renderViewportPixels"]
    if not all(is_number(value) for value in (width, height, camera["sceneKitOrthographicScale"])) or width <= 0 or height <= 0:
        raise ValueError("bridge camera schema")
    forward = vector_normalize(vector_sub(camera["citySimTarget"], camera["citySimPosition"]))
    right = vector_normalize(vector_cross(forward, [0.0, 1.0, 0.0]))
    up = vector_normalize(vector_cross(right, forward))
    ground_scale = float(height) / (2.0 * float(camera["sceneKitOrthographicScale"]))
    origin = camera["sourceGroundCenter"]
    samples = bridge["directions"]

    def slope(direction_names: tuple[str, ...], world_axis: int, source_axis: int) -> float:
        values = []
        for name in direction_names:
            world = samples[name]["socketCitySim"]
            source = samples[name]["socketSource"]
            delta_world = float(world[world_axis])
            if abs(delta_world) <= EPSILON:
                continue
            values.append((float(source[source_axis]) - float(origin[source_axis])) / delta_world)
        if not values or max(values) - min(values) > 1e-6:
            raise ValueError("bridge registration slope drift")
        return sum(values) / len(values)

    city_x_source_x = slope(("west", "east"), 0, 0)
    city_z_source_x = slope(("north", "south"), 2, 0)
    city_x_source_y = slope(("west", "east"), 0, 1)
    city_z_source_y = slope(("north", "south"), 2, 1)
    affine = {
        "sourceOriginXY": [float(origin[0]), float(origin[1])],
        "sourceXCoefficients": {
            "cityX": city_x_source_x,
            "cityY": ground_scale * right[1],
            "cityZ": city_z_source_x,
        },
        "sourceYCoefficients": {
            "cityX": city_x_source_y,
            "cityY": -ground_scale * up[1],
            "cityZ": city_z_source_y,
        },
    }
    metadata = {
        "forwardCitySim": forward,
        "rightCitySim": right,
        "upCitySim": up,
        "groundScale": ground_scale,
        "bridgeBasis": basis["formula"],
    }
    return affine, metadata


def project(world: tuple[float, float, float], affine: dict[str, Any]) -> tuple[float, float]:
    origin = affine["sourceOriginXY"]
    x_coeff = affine["sourceXCoefficients"]
    y_coeff = affine["sourceYCoefficients"]
    x, y, z = world
    return (
        float(origin[0]) + float(x_coeff["cityX"]) * x + float(x_coeff["cityY"]) * y + float(x_coeff["cityZ"]) * z,
        float(origin[1]) + float(y_coeff["cityX"]) * x + float(y_coeff["cityY"]) * y + float(y_coeff["cityZ"]) * z,
    )


def projected_bounds_for_box(box: tuple[tuple[float, float, float], tuple[float, float, float]], affine: dict[str, Any]) -> dict[str, Any]:
    points = [project((x, y, z), affine) for x in (box[0][0], box[1][0]) for y in (box[0][1], box[1][1]) for z in (box[0][2], box[1][2])]
    source_min = [min(point[index] for point in points) for index in (0, 1)]
    source_max = [max(point[index] for point in points) for index in (0, 1)]
    literal_min = [math.floor(value / 8.0) for value in source_min]
    literal_max = [math.ceil(value / 8.0) for value in source_max]
    return {
        "min": source_min,
        "max": source_max,
        "literalMin": literal_min,
        "literalMax": literal_max,
        "literalWidth": literal_max[0] - literal_min[0],
        "literalHeight": literal_max[1] - literal_min[1],
    }


def world_span(component_ids: list[str], boxes: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]], axis: int) -> float | None:
    selected = [boxes.get(component_id) for component_id in component_ids]
    if any(box is None for box in selected):
        return None
    return max(box[1][axis] for box in selected if box is not None) - min(box[0][axis] for box in selected if box is not None)


def derived_metrics(design: dict[str, Any], boxes: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]], projections: dict[str, dict[str, Any]]) -> dict[str, Any] | None:
    proof = design.get("geometryProof")
    if not isinstance(proof, dict):
        return None
    aperture_id = proof.get("apertureComponentID")
    frame_ids = proof.get("portalFrameComponentIDs")
    crown_ids = proof.get("crownComponentIDs")
    jamb_ids = proof.get("jambComponentIDs")
    header_ids = proof.get("headerComponentIDs")
    silhouette_ids = proof.get("silhouetteComponentIDs")
    if not all(isinstance(value, list) for value in (frame_ids, crown_ids, jamb_ids, header_ids, silhouette_ids)):
        return None
    if not all(component_id in projections for component_id in [aperture_id, *frame_ids, *crown_ids, *jamb_ids, *header_ids, *silhouette_ids]):
        return None
    heights = [boxes[component_id][1][1] for component_id in silhouette_ids]
    return {
        "aperture": projections[aperture_id],
        "frame": merge_projection_records(frame_ids, projections),
        "crown": merge_projection_records(crown_ids, projections),
        "jamb": merge_projection_records(jamb_ids, projections),
        "header": merge_projection_records(header_ids, projections),
        "portalOuterWidthWorld": world_span(frame_ids, boxes, 2),
        "portalOuterHeightWorld": world_span(frame_ids, boxes, 1),
        "portalJambThicknessWorld": world_span(jamb_ids, boxes, 2),
        "portalHeaderThicknessWorld": world_span(header_ids, boxes, 1),
        "silhouetteHeightsWorld": heights,
        "silhouetteBreakCount": len(set(heights)),
    }


def merge_projection_records(component_ids: list[str], projections: dict[str, dict[str, Any]]) -> dict[str, Any]:
    records = [projections[component_id] for component_id in component_ids]
    source_min = [min(record["min"][axis] for record in records) for axis in (0, 1)]
    source_max = [max(record["max"][axis] for record in records) for axis in (0, 1)]
    literal_min = [math.floor(value / 8.0) for value in source_min]
    literal_max = [math.ceil(value / 8.0) for value in source_max]
    return {"min": source_min, "max": source_max, "literalMin": literal_min, "literalMax": literal_max, "literalWidth": literal_max[0] - literal_min[0], "literalHeight": literal_max[1] - literal_min[1]}


def signature_records(design: dict[str, Any], boxes: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]], projections: dict[str, dict[str, Any]]) -> tuple[dict[str, Any], list[str]]:
    records = []
    for component in design["components"]:
        component_id = component["id"]
        box = boxes[component_id]
        projection = projections[component_id]
        record = {
            "id": component_id,
            "geometry": digest({"shape": "axis-aligned-box", "aabb": {"min": list(box[0]), "max": list(box[1])}}),
            "kind": digest({"kind": component["kind"]}),
            "role": digest({"role": component["role"]}),
            "silhouette": digest({"topY": box[1][1], "literalMin": projection["literalMin"], "literalMax": projection["literalMax"]}),
            "projection": digest({"min": projection["min"], "max": projection["max"]}),
        }
        records.append(record)
    duplicates: list[str] = []
    seen: dict[str, str] = {}
    for record in records:
        previous = seen.get(record["geometry"])
        if previous is not None:
            duplicates.extend([previous, record["id"]])
        seen[record["geometry"]] = record["id"]
    signatures = {
        "geometry": digest(sorted((record["id"], record["geometry"]) for record in records)),
        "kind": digest(sorted((record["id"], record["kind"]) for record in records)),
        "role": digest(sorted((record["id"], record["role"]) for record in records)),
        "silhouette": digest(sorted((record["id"], record["silhouette"]) for record in records)),
        "projection": digest(sorted((record["id"], record["projection"]) for record in records)),
        "records": records,
    }
    return signatures, sorted(set(duplicates))


def compute_derived(design: dict[str, Any], lowering: dict[str, Any], bridge: dict[str, Any]) -> dict[str, Any]:
    affine, camera_basis = derive_affine_from_bridge(bridge)
    boxes: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]] = {}
    for component in design["components"]:
        parsed = parse_aabb(component["aabb"], component["id"], [])
        if parsed is None:
            raise ValueError("invalid component AABB")
        boxes[component["id"]] = parsed
    projections = {component_id: projected_bounds_for_box(box, affine) for component_id, box in boxes.items()}
    metrics = derived_metrics(design, boxes, projections)
    if metrics is None:
        raise ValueError("derived geometry groups missing")
    signatures, duplicates = signature_records(design, boxes, projections)
    if duplicates:
        raise ValueError("duplicate geometry signature")
    aperture_id = design["geometryProof"]["apertureComponentID"]
    return {
        "affine": affine,
        "cameraBasis": camera_basis,
        "projections": projections,
        "metrics": metrics,
        "signatures": signatures,
        "sourceOverlapIDs": sorted(component_id for component_id, projection in projections.items() if component_id != aperture_id and intersects_source(projection, projections[aperture_id])),
    }


def path_is_owned(path_value: Any) -> bool:
    if not isinstance(path_value, str):
        return False
    path = Path(path_value)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        return False
    normalized = path.as_posix()
    return any(normalized == root or normalized.startswith(root + "/") for root in OWNED_ROOTS)


def audit_bundle(design: dict[str, Any], materials: dict[str, Any], lowering: dict[str, Any], result: dict[str, Any], bridge: dict[str, Any], verify_files: bool) -> list[str]:
    errors: list[str] = []
    if design.get("task") != "PLAY-081" or design.get("direction") != "west" or design.get("logicalBuildingID") != "industrial_l04" or design.get("variantID") != "variant-0" or design.get("variantIndex") != 0:
        add_error(errors, "identity", "logical-building-or-variant")
    if design.get("authorityBindings", {}).get("publishedBase") != EXPECTED_BASE:
        add_error(errors, "authority", "base")
    if design.get("authorityBindings", {}).get("claim", {}).get("sha256") != EXPECTED_CLAIM_SHA:
        add_error(errors, "authority", "claim")
    independence = design.get("independence", {})
    if independence.get("orientationTransform") != "none" or independence.get("siblingInputsConsumed") != []:
        add_error(errors, "direction", "isolation")
    if design.get("sourceAuthority") is not False or design.get("pixelRenderingAuthorized") is not False:
        add_error(errors, "boundary", "source-or-pixel")

    components = design.get("components")
    if not isinstance(components, list) or not components:
        add_error(errors, "components", "schema")
        components = []
    component_ids = [component.get("id") for component in components if isinstance(component, dict)]
    if len(component_ids) != len(set(component_ids)):
        add_error(errors, "component-alias", "duplicate-id")
    parsed_boxes: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]] = {}
    process_ids: set[str] = set()
    aperture_components = []
    for component in components:
        if not isinstance(component, dict) or not isinstance(component.get("id"), str) or not isinstance(component.get("kind"), str) or not isinstance(component.get("role"), str):
            add_error(errors, "component", "identity-schema")
            continue
        parsed = parse_aabb(component.get("aabb"), component["id"], errors)
        if parsed is not None:
            parsed_boxes[component["id"]] = parsed
        top_flag, nested_flag = process_flags(component, errors)
        if top_flag is True or nested_flag is True:
            process_ids.add(component["id"])
        if component.get("isAperture") is True:
            aperture_components.append(component)
    if len(aperture_components) != 1:
        add_error(errors, "aperture", f"count={len(aperture_components)}")
    if len(aperture_components) == 1:
        aperture_box = parsed_boxes.get(aperture_components[0]["id"])
        if aperture_box is not None:
            for component in components:
                if not isinstance(component, dict) or component.get("id") == aperture_components[0]["id"]:
                    continue
                box = parsed_boxes.get(component.get("id"))
                if box is not None and intersects_world(box, aperture_box):
                    add_error(errors, "solid-overlaps-aperture", str(component.get("id")))
    if process_ids != set(design.get("portalCrown", {}).get("processOccluderIDs", [])):
        add_error(errors, "process-occluder-binding")

    bridge_binding = design.get("coordinateBridge", {})
    lowering_bridge_binding = lowering.get("coordinateBridge", {})
    expected_bridge_binding = {
        "path": "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json",
        "sha256": EXPECTED_BRIDGE_SHA,
        "sourceRevision": "direction-bridge-v06",
        "basisFormula": "B(CitySim[x,y,z])=Blender[z,x,y]",
        "basisMatrixRows": [[0, 0, 1], [1, 0, 0], [0, 1, 0]],
        "sourceOrder": [0, 1, 2, 3],
    }
    if bridge_binding != expected_bridge_binding or lowering_bridge_binding != expected_bridge_binding:
        add_error(errors, "bridge", "binding")
    if verify_files and (not BRIDGE_PATH.is_file() or sha256(BRIDGE_PATH) != EXPECTED_BRIDGE_SHA):
        add_error(errors, "bridge", "content")
    try:
        derived = compute_derived(design, lowering, bridge)
    except (KeyError, TypeError, ValueError, IndexError) as exc:
        add_error(errors, "derived", str(exc))
        derived = None
    if derived is not None:
        if not same_value(lowering.get("projection", {}).get("derivedAffine"), derived["affine"]):
            add_error(errors, "camera", "affine-not-derived")
        if not same_value(lowering.get("projection", {}).get("cameraBasis"), derived["cameraBasis"]):
            add_error(errors, "camera", "basis-not-derived")
        if not same_value(lowering.get("projection", {}).get("sourceProjectionSignature"), derived["signatures"]["projection"]):
            add_error(errors, "projection", "signature")
        if not same_value(lowering.get("nonAliasSignatures"), {key: derived["signatures"][key] for key in ("geometry", "kind", "role", "silhouette", "projection")}):
            add_error(errors, "non-alias", "signature")
        allowlist = design.get("geometryProof", {}).get("portalProjectionAllowlist", {})
        overlap_ids = set(derived["sourceOverlapIDs"])
        process_overlap_ids = sorted(overlap_ids & process_ids)
        for component_id in process_overlap_ids:
            add_error(errors, "process-occluder-source-overlap", component_id)
        if not isinstance(allowlist, dict):
            add_error(errors, "projection", "allowlist-schema")
        else:
            for component_id in overlap_ids:
                if component_id not in allowlist:
                    add_error(errors, "source-overlap", component_id)
            for component_id, reason in allowlist.items():
                if component_id not in derived["projections"] or not isinstance(reason, str) or not reason:
                    add_error(errors, "projection", f"allowlist:{component_id}")
        if derived["sourceOverlapIDs"] != lowering.get("projectionAudit", {}).get("sourceOverlapIDs"):
            add_error(errors, "projection", "audit-record")
        if process_overlap_ids != lowering.get("projectionAudit", {}).get("processOccluderOverlapIDs"):
            add_error(errors, "projection", "process-occluder-audit-record")
        if process_overlap_ids != result.get("derivedProof", {}).get("processOccluderSourceOverlapIDs"):
            add_error(errors, "evidence-derived-drift", "process-occluder-overlap")
        if lowering.get("projectionAudit", {}).get("solidCount") != len(design.get("components", [])):
            add_error(errors, "projection", "solid-count")
        metrics = derived["metrics"]
        portal = design.get("portalCrown", {})
        literal = design.get("literal192Feasibility", {})
        declared = {
            "portalOuterWidthWorld": portal.get("portalOuterWidthWorld"),
            "portalOuterHeightWorld": portal.get("portalOuterHeightWorld"),
            "portalJambThicknessWorld": portal.get("portalJambThicknessWorld"),
            "portalHeaderThicknessWorld": portal.get("portalHeaderThicknessWorld"),
            "crownBreakHeightsWorld": portal.get("crownBreakHeightsWorld"),
            "silhouetteBreakCount": portal.get("silhouetteBreakCount"),
            "portalInsetWidthPixels": literal.get("portalInsetWidthPixels"),
            "portalInsetHeightPixels": literal.get("portalInsetHeightPixels"),
            "portalOuterWidthPixels": literal.get("portalOuterWidthPixels"),
            "portalOuterHeightPixels": literal.get("portalOuterHeightPixels"),
            "portalJambThicknessPixels": literal.get("portalJambThicknessPixels"),
            "portalHeaderThicknessPixels": literal.get("portalHeaderThicknessPixels"),
        }
        expected = {
            "portalOuterWidthWorld": metrics["portalOuterWidthWorld"],
            "portalOuterHeightWorld": metrics["portalOuterHeightWorld"],
            "portalJambThicknessWorld": metrics["portalJambThicknessWorld"],
            "portalHeaderThicknessWorld": metrics["portalHeaderThicknessWorld"],
            "crownBreakHeightsWorld": metrics["silhouetteHeightsWorld"],
            "silhouetteBreakCount": metrics["silhouetteBreakCount"],
            "portalInsetWidthPixels": metrics["aperture"]["literalWidth"],
            "portalInsetHeightPixels": metrics["aperture"]["literalHeight"],
            "portalOuterWidthPixels": metrics["frame"]["literalWidth"],
            "portalOuterHeightPixels": metrics["frame"]["literalHeight"],
            "portalJambThicknessPixels": metrics["jamb"]["literalWidth"],
            "portalHeaderThicknessPixels": metrics["header"]["literalHeight"],
        }
        for key, actual in declared.items():
            if not same_value(actual, expected[key]):
                add_error(errors, "derived-drift", key)
        lower_aperture = lowering.get("portalAperture", {})
        lower_frame = lowering.get("portalFrame", {})
        lower_silhouette = lowering.get("silhouette", {})
        lower_checks = {
            "aperture-source": (lower_aperture.get("sourceAnalyticBounds"), {"min": metrics["aperture"]["min"], "max": metrics["aperture"]["max"]}),
            "aperture-literal": (lower_aperture.get("literal192Bounds"), {"min": metrics["aperture"]["literalMin"], "max": metrics["aperture"]["literalMax"]}),
            "aperture-width": (lower_aperture.get("literal192WidthPixels"), metrics["aperture"]["literalWidth"]),
            "aperture-height": (lower_aperture.get("literal192HeightPixels"), metrics["aperture"]["literalHeight"]),
            "frame-source": (lower_frame.get("sourceAnalyticBounds"), {"min": metrics["frame"]["min"], "max": metrics["frame"]["max"]}),
            "frame-literal": (lower_frame.get("literal192Bounds"), {"min": metrics["frame"]["literalMin"], "max": metrics["frame"]["literalMax"]}),
            "frame-width": (lower_frame.get("literal192WidthPixels"), metrics["frame"]["literalWidth"]),
            "frame-height": (lower_frame.get("literal192HeightPixels"), metrics["frame"]["literalHeight"]),
            "crown-width": (lower_silhouette.get("portalCrownWidthPixels"), metrics["crown"]["literalWidth"]),
            "silhouette-heights": (lower_silhouette.get("breakHeightsWorld"), metrics["silhouetteHeightsWorld"]),
            "silhouette-count": (lower_silhouette.get("breakCount"), metrics["silhouetteBreakCount"]),
        }
        for label, (actual, expected_value) in lower_checks.items():
            if not same_value(actual, expected_value):
                add_error(errors, "derived-drift", f"lowering:{label}")

    registration = design.get("registration", {})
    expected_registration = {
        "frontageEdge": "west",
        "frontageSocketWorldXYZ": [-28, 0, 0],
        "frontageSocketBlenderXYZ": [0, -28, 0],
        "frontageSocketSourceXY": [640, 704],
        "groundPivotWorldXYZ": [28, 0, 28],
        "groundPivotSourceXY": [768, 896],
        "contactPolygonWorldXZ": [[-28, -28], [28, -28], [28, 28], [-28, 28]],
    }
    for key, expected in expected_registration.items():
        if registration.get(key) != expected:
            add_error(errors, "registration", key)
    if design.get("camera", {}).get("projection") != "orthographic-2:1":
        add_error(errors, "camera", "projection")

    bridge_camera = bridge.get("camera", {})
    lower_camera = lowering.get("camera", {})
    expected_lower_camera = {
        "projection": "orthographic-2:1",
        "positionWorldXYZ": bridge_camera.get("citySimPosition"),
        "targetWorldXYZ": bridge_camera.get("citySimTarget"),
        "orthographicScaleWorld": bridge_camera.get("sceneKitOrthographicScale"),
        "renderViewportPixels": bridge_camera.get("renderViewportPixels"),
        "shiftX": bridge_camera.get("shiftX"),
        "shiftY": bridge_camera.get("shiftY"),
        "blenderPositionXYZ": bridge_camera.get("blenderPosition"),
        "blenderTargetXYZ": bridge_camera.get("blenderTarget"),
        "blenderOrthographicScale": bridge_camera.get("blenderOrthographicScale"),
        "postProjectionOffsetPixels": bridge_camera.get("postProjectionOffsetPixels"),
        "sourceGroundCenter": bridge_camera.get("sourceGroundCenter"),
    }
    for key, expected in expected_lower_camera.items():
        if not same_value(lower_camera.get(key), expected):
            add_error(errors, "camera", f"binding:{key}")
    for key, expected in (("positionWorldXYZ", bridge_camera.get("citySimPosition")), ("targetWorldXYZ", bridge_camera.get("citySimTarget")), ("orthographicScaleWorld", bridge_camera.get("sceneKitOrthographicScale")), ("renderViewportPixels", bridge_camera.get("renderViewportPixels")), ("shiftX", bridge_camera.get("shiftX")), ("shiftY", bridge_camera.get("shiftY"))):
        if not same_value(design.get("camera", {}).get(key), expected):
            add_error(errors, "camera", f"design-binding:{key}")
    if lowering.get("orientationTransform") != "none":
        add_error(errors, "direction", "lowering-orientation")

    component_ids = [component.get("id") for component in design.get("components", []) if isinstance(component, dict)]
    bound_roles = {item.get("role") for item in materials.get("roleBindings", []) if isinstance(item, dict)}
    if bound_roles != EXPECTED_ROLES:
        add_error(errors, "materials", "role-completeness")
    if materials.get("publishedRoleAuthority", {}).get("sha256") != EXPECTED_MATERIALS_SHA:
        add_error(errors, "materials", "authority")
    role_usage = [component_id for item in materials.get("roleBindings", []) if isinstance(item, dict) for component_id in item.get("usedBy", [])]
    if len(role_usage) != len(set(role_usage)) or set(role_usage) != set(component_ids):
        add_error(errors, "material-alias", "usedBy")
    role_by_id = {component.get("id"): component.get("role") for component in design.get("components", []) if isinstance(component, dict)}
    for item in materials.get("roleBindings", []):
        if isinstance(item, dict):
            for component_id in item.get("usedBy", []):
                if role_by_id.get(component_id) != item.get("role"):
                    add_error(errors, "material-alias", str(component_id))

    for key in ("blenderProcessLaunches", "dccInvocations", "renderInvocations", "pixelFiles"):
        if design.get("zeroPixelBoundary", {}).get(key) != 0:
            add_error(errors, "zero-pixel", f"design:{key}")
    for key in ("blenderProcessLaunches", "dccInvocations", "renderInvocations", "imageGenInvocations", "normalizerInvocations", "pixelFiles"):
        if lowering.get("zeroPixelBoundary", {}).get(key) != 0:
            add_error(errors, "zero-pixel", f"lowering:{key}")
    if lowering.get("zeroPixelBoundary", {}).get("sourceReady") is not False:
        add_error(errors, "boundary", "source-ready")

    if result.get("result") != "PASS" or result.get("task") != "PLAY-081" or result.get("direction") != "west":
        add_error(errors, "evidence", "identity")
    if result.get("sourceReady") is not False or result.get("candidateReadyForIndependentReview") is not True:
        add_error(errors, "evidence", "readiness")
    if result.get("route") != EXPECTED_ROUTE:
        add_error(errors, "route", "binding")
    if result.get("claim", {}).get("sha256") != EXPECTED_CLAIM_SHA:
        add_error(errors, "evidence", "claim")
    if result.get("westBinding", {}).get("siblingInputsConsumed") != [] or result.get("westBinding", {}).get("orientationTransform") != "none":
        add_error(errors, "evidence", "direction-isolation")
    if result.get("proofRepair", {}).get("repairAttempt") != 2 or result.get("proofRepair", {}).get("frontierRecoveryAttempt") != 1:
        add_error(errors, "evidence", "repair-attempt")
    fresh = result.get("freshReplay", {})
    if fresh.get("independentProcessCount") != 2 or fresh.get("byteIdentical") is not True or fresh.get("processIsolation") is not True:
        add_error(errors, "replay", "fresh-process")
    expected_paths = {
        "design": "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/v13-compatibility-v01/WEST-V13-DESIGN.json",
        "materials": "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/v13-compatibility-v01/WEST-V13-MATERIALS.json",
        "lowering": "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/v13-compatibility-v01/WEST-V13-LOWERING.json",
        "validator": "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01/test_v13_compatibility.py",
    }
    for key, expected_path in expected_paths.items():
        bound = result.get("bindings", {}).get(key, {})
        if bound.get("path") != expected_path or not path_is_owned(bound.get("path")):
            add_error(errors, "path-safety", key)
        if verify_files:
            actual_path = REPOSITORY_ROOT / expected_path
            if not actual_path.is_file() or bound.get("sha256") != sha256(actual_path):
                add_error(errors, "evidence-hash", key)
    analytic = result.get("analyticProof", {})
    if derived is not None:
        metrics = derived["metrics"]
        if analytic.get("portalInsetWidthPixels") != metrics["aperture"]["literalWidth"] or analytic.get("portalInsetHeightPixels") != metrics["aperture"]["literalHeight"]:
            add_error(errors, "evidence-derived-drift", "aperture")
        if analytic.get("portalOuterWidthPixels") != metrics["frame"]["literalWidth"] or analytic.get("portalOuterHeightPixels") != metrics["frame"]["literalHeight"]:
            add_error(errors, "evidence-derived-drift", "frame")
        if analytic.get("silhouetteBreaks") != metrics["silhouetteBreakCount"]:
            add_error(errors, "evidence-derived-drift", "silhouette")
        if result.get("derivedProof", {}).get("sourceProjectionSignature") != derived["signatures"]["projection"]:
            add_error(errors, "evidence-derived-drift", "projection-signature")
    if analytic.get("socketSourceXY") != [640, 704] or analytic.get("pivotSourceXY") != [768, 896]:
        add_error(errors, "evidence", "registration")
    activity = result.get("activity", {})
    if any(activity.get(key) != 0 for key in ("blenderProcessLaunches", "dccInvocations", "renderInvocations", "blenderRenderApiCalls", "imageGenInvocations", "normalizerInvocations", "contactSheetInvocations", "sourceProcessABC", "pixelFiles", "sourceCandidatePackets")):
        add_error(errors, "zero-pixel", "evidence")
    return errors


def run_adversaries(bundle: tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]) -> dict[str, str]:
    names: dict[str, str] = {}

    def expect_reject(label: str, mutate: Any, expected_error: str | None = None) -> None:
        candidate = tuple(copy.deepcopy(item) for item in bundle)
        mutate(candidate)
        errors = audit_bundle(candidate[0], candidate[1], candidate[2], candidate[3], candidate[4], verify_files=False)
        require(errors, f"adversary accepted: {label}")
        if expected_error is not None:
            require(any(error.startswith(expected_error) for error in errors), f"adversary missed required failure {label}: {errors}")
            names[label] = next(error for error in errors if error.startswith(expected_error))
        else:
            names[label] = errors[0]

    def nested_flag_only(candidate: tuple[Any, ...]) -> None:
        component = next(item for item in candidate[0]["components"] if item["id"] == "west-v13-stack")
        component["processOccluder"] = False
        component["metadata"] = {"processOccluder": True}

    def camera_null_axis(candidate: tuple[Any, ...]) -> None:
        design = candidate[0]
        decoy = next(item for item in design["components"] if item["id"] == "west-v13-hot-process")
        shell = next(item for item in design["components"] if item["id"] == "west-v13-foundry-hall")
        decoy["aabb"] = copy.deepcopy(shell["aabb"])

    def camera_position(candidate: tuple[Any, ...]) -> None:
        candidate[2]["camera"]["positionWorldXYZ"][0] += 1

    def camera_viewport(candidate: tuple[Any, ...]) -> None:
        candidate[2]["camera"]["renderViewportPixels"][0] += 1

    def camera_shift(candidate: tuple[Any, ...]) -> None:
        candidate[2]["camera"]["shiftY"] += 0.01

    def identity(candidate: tuple[Any, ...]) -> None:
        candidate[0]["logicalBuildingID"] = "industrial_l03"

    def geometry_alias(candidate: tuple[Any, ...]) -> None:
        source = next(item for item in candidate[0]["components"] if item["id"] == "west-v13-hot-process")
        target = next(item for item in candidate[0]["components"] if item["id"] == "west-v13-stack")
        for key in ("kind", "role", "aabb"):
            target[key] = copy.deepcopy(source[key])

    def raw_geometry_alias_relabel(candidate: tuple[Any, ...]) -> None:
        source = next(item for item in candidate[0]["components"] if item["id"] == "west-v13-hot-process")
        target = next(item for item in candidate[0]["components"] if item["id"] == "west-v13-stack")
        target["aabb"] = copy.deepcopy(source["aabb"])

    def allowlisted_process_occluder(candidate: tuple[Any, ...]) -> None:
        design = candidate[0]
        component = next(item for item in design["components"] if item["id"] == "west-v13-foundry-hall")
        component["processOccluder"] = True
        design["portalCrown"]["processOccluderIDs"].append(component["id"])

    def allowlisted_process_occluder_nested_coherent(candidate: tuple[Any, ...]) -> None:
        design = candidate[0]
        component = next(item for item in design["components"] if item["id"] == "west-v13-roof-edge")
        component["processOccluder"] = True
        component["metadata"] = {"processOccluder": True}
        component["proof"] = {"processOccluder": True}
        design["portalCrown"]["processOccluderIDs"].append(component["id"])

    def allowlisted_process_occluder_deep_nested(candidate: tuple[Any, ...]) -> None:
        design = candidate[0]
        component = next(item for item in design["components"] if item["id"] == "west-v13-staff-annex")
        component["metadata"] = {"validation": {"flags": [{"processOccluder": True}]}}
        design["portalCrown"]["processOccluderIDs"].append(component["id"])

    def invalid_aabb(candidate: tuple[Any, ...]) -> None:
        candidate[0]["components"][0]["aabb"]["min"][0] = "not-a-number"

    def collision(candidate: tuple[Any, ...]) -> None:
        design = candidate[0]
        aperture = next(item for item in design["components"] if item.get("isAperture") is True)
        reveal = next(item for item in design["components"] if item["id"] == "west-v13-inner-reveal")
        reveal["aabb"] = copy.deepcopy(aperture["aabb"])

    def width_drift(candidate: tuple[Any, ...]) -> None:
        candidate[0]["literal192Feasibility"]["portalInsetWidthPixels"] += 1

    def bounds_drift(candidate: tuple[Any, ...]) -> None:
        candidate[2]["portalAperture"]["literal192Bounds"]["min"][0] += 1

    def material_alias(candidate: tuple[Any, ...]) -> None:
        candidate[1]["roleBindings"][0]["usedBy"].append("west-v13-foundry-hall")

    def path_escape(candidate: tuple[Any, ...]) -> None:
        candidate[3]["bindings"]["design"]["path"] = "../sibling/WEST-V13-DESIGN.json"

    def same_memory_replay(candidate: tuple[Any, ...]) -> None:
        candidate[3]["freshReplay"]["processIsolation"] = False
        candidate[3]["freshReplay"]["independentProcessCount"] = 1

    adversaries: dict[str, tuple[Any, str | None]] = {
        "nested-flag-only": (nested_flag_only, None),
        "camera-null-axis-occlusion": (camera_null_axis, None),
        "camera-position-drift": (camera_position, None),
        "camera-viewport-drift": (camera_viewport, None),
        "camera-shift-drift": (camera_shift, None),
        "identity-drift": (identity, None),
        "geometry-alias": (geometry_alias, "derived:duplicate geometry signature"),
        "raw-geometry-alias-relabel": (raw_geometry_alias_relabel, "derived:duplicate geometry signature"),
        "allowlisted-process-occluder": (allowlisted_process_occluder, "process-occluder-source-overlap:"),
        "allowlisted-process-occluder-nested-coherent": (allowlisted_process_occluder_nested_coherent, "process-occluder-source-overlap:"),
        "allowlisted-process-occluder-deep-nested": (allowlisted_process_occluder_deep_nested, "process-occluder-source-overlap:"),
        "invalid-aabb": (invalid_aabb, None),
        "solid-aperture-collision": (collision, None),
        "width-drift": (width_drift, None),
        "bounds-drift": (bounds_drift, None),
        "material-alias": (material_alias, None),
        "path-escape": (path_escape, None),
        "same-memory-replay": (same_memory_replay, None),
    }
    for label, (mutate, expected_error) in adversaries.items():
        expect_reject(label, mutate, expected_error)
    return names


def fresh_process_replay() -> tuple[bool, str, float]:
    outputs = []
    started = __import__("time").perf_counter()
    for _ in range(2):
        completed = subprocess.run([sys.executable, str(Path(__file__).resolve()), "--emit-derived"], check=False, capture_output=True)
        require(completed.returncode == 0, "fresh derived process failed")
        outputs.append(completed.stdout)
    elapsed = __import__("time").perf_counter() - started
    require(outputs[0] == outputs[1], "fresh derived outputs differ")
    return True, hashlib.sha256(outputs[0]).hexdigest(), elapsed


def emit_derived() -> int:
    design = load(DESIGN_PATH)
    lowering = load(LOWERING_PATH)
    bridge = load(BRIDGE_PATH)
    sys.stdout.buffer.write(canonical(compute_derived(design, lowering, bridge)))
    return 0


def main() -> int:
    if "--emit-derived" in sys.argv[1:]:
        return emit_derived()
    design = load(DESIGN_PATH)
    materials = load(MATERIAL_PATH)
    lowering = load(LOWERING_PATH)
    result = load(RESULT_PATH)
    bridge = load(BRIDGE_PATH)
    published_design = load(PUBLISHED_DESIGN)
    published_materials = load(PUBLISHED_MATERIALS)
    require(sha256(PUBLISHED_DESIGN) == EXPECTED_DESIGN_SHA, "published design authority drift")
    require(sha256(PUBLISHED_MATERIALS) == EXPECTED_MATERIALS_SHA, "published material authority drift")
    require(sha256(BRIDGE_PATH) == EXPECTED_BRIDGE_SHA, "bridge authority drift")
    require(published_design.get("design", {}).get("conceptName") == "Portal Crown Foundry", "design vocabulary binding")
    require({item["role"] for item in published_materials["materials"]} == EXPECTED_ROLES, "published role set drift")

    bundle = (design, materials, lowering, result, bridge)
    errors = audit_bundle(*bundle, verify_files=True)
    require(not errors, "proof audit failed: " + "; ".join(errors))
    adversaries = run_adversaries(bundle)
    require(len(adversaries) == 18, "adversary coverage")
    identical, replay_sha, replay_seconds = fresh_process_replay()
    require(identical and replay_sha == result.get("freshReplay", {}).get("outputSha256"), "fresh replay evidence drift")

    generated = [path for path in V13_ROOT.rglob("*") if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES]
    require(not generated, f"pixel or binary output present: {generated}")
    print("PASS v13-west-frontier-recovery bridge=PASS camera=DERIVED sourceProjection=PASS processOccluderOverlap=REJECTED identity=PASS rawGeometryNonAlias=PASS freshReplay=BYTE_IDENTICAL adversaries=18 zeroPixel=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
