#!/usr/bin/env python3
"""Pure-data West v13 proof and adversarial audit.

The proof consumes only the West JSON packet and the published semantic
authorities.  It never opens a sibling scene, launches Blender, calls a DCC,
or creates pixel output.  Geometry metrics are derived from component AABBs
and the versioned affine lowering rather than copied target values.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
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
EXPECTED_ROUTE = {
    "routeId": "quality-v1:west-v13-proof-repair",
    "canonicalRouteSha256": "acc25d6756a8e8882eaca36e51938673411646006da9aefc5663d42412281394",
    "carrierCommit": "61fa4fcf14b9c469e4e34f58dfef75ebcbfec316",
    "receiptPath": "docs/production/evidence/INTEGRATION/MODEL-ROUTING-QUALITY-DIRECTION-V13-PROOF-REPAIRS-V1.json",
    "receiptSha256": "04d50bc3556f5f169394ad83484de15c34d81acaf1f319a2d60dfc60e69d29d3",
    "authorityCommit": "d010d453af87c040ac13e8b3b7280366cb5094c1",
    "expectedStartingHead": "b173ecefea76319d7a5e3303072d34991e2c55ef",
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
EPSILON = 1e-9


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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


def parse_aabb(raw: Any, label: str, errors: list[str]) -> tuple[tuple[float, float, float], tuple[float, float, float]] | None:
    """Validate the strict min/max-array AABB contract and return numeric tuples."""
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


def intersects(left: tuple[tuple[float, float, float], tuple[float, float, float]], right: tuple[tuple[float, float, float], tuple[float, float, float]]) -> bool:
    return all(a_min < b_max and b_min < a_max for a_min, a_max, b_min, b_max in zip(left[0], left[1], right[0], right[1]))


def process_occluder(component: dict[str, Any]) -> bool:
    """Accept the component-level flag and audit nested forged flag locations too."""
    if component.get("processOccluder") is True:
        return True
    for container_key in ("metadata", "validation", "proof"):
        container = component.get(container_key)
        if isinstance(container, dict) and container.get("processOccluder") is True:
            return True
    return False


def project(world: tuple[float, float, float], affine: dict[str, Any]) -> tuple[float, float]:
    origin = affine["sourceOriginXY"]
    x_coeff = affine["sourceXCoefficients"]
    y_coeff = affine["sourceYCoefficients"]
    x, y, z = world
    return (
        float(origin[0]) + float(x_coeff["cityX"]) * x + float(x_coeff["cityY"]) * y + float(x_coeff["cityZ"]) * z,
        float(origin[1]) + float(y_coeff["cityX"]) * x + float(y_coeff["cityY"]) * y + float(y_coeff["cityZ"]) * z,
    )


def projected_bounds(component_ids: list[str], component_boxes: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]], affine: dict[str, Any]) -> dict[str, Any] | None:
    points: list[tuple[float, float]] = []
    for component_id in component_ids:
        box = component_boxes.get(component_id)
        if box is None:
            return None
        for x in (box[0][0], box[1][0]):
            for y in (box[0][1], box[1][1]):
                for z in (box[0][2], box[1][2]):
                    points.append(project((x, y, z), affine))
    source_min = [min(point[index] for point in points) for index in (0, 1)]
    source_max = [max(point[index] for point in points) for index in (0, 1)]
    literal_min = [math.floor(value / 8.0) for value in source_min]
    literal_max = [math.ceil(value / 8.0) for value in source_max]
    return {
        "source": {"min": source_min, "max": source_max},
        "literal": {"min": literal_min, "max": literal_max},
        "literalWidth": literal_max[0] - literal_min[0],
        "literalHeight": literal_max[1] - literal_min[1],
    }


def world_span(component_ids: list[str], component_boxes: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]], axis: int) -> float | None:
    boxes = [component_boxes.get(component_id) for component_id in component_ids]
    if any(box is None for box in boxes):
        return None
    lower = min(box[0][axis] for box in boxes if box is not None)
    upper = max(box[1][axis] for box in boxes if box is not None)
    return upper - lower


def derived_metrics(design: dict[str, Any], component_boxes: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]], affine: dict[str, Any]) -> dict[str, Any] | None:
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
    groups = {
        "aperture": [aperture_id] if isinstance(aperture_id, str) else [],
        "frame": frame_ids,
        "crown": crown_ids,
        "jamb": jamb_ids,
        "header": header_ids,
        "silhouette": silhouette_ids,
    }
    projected = {name: projected_bounds(ids, component_boxes, affine) for name, ids in groups.items()}
    if any(value is None for value in projected.values()):
        return None
    silhouette_heights = [component_boxes[component_id][1][1] for component_id in silhouette_ids]
    return {
        "aperture": projected["aperture"],
        "frame": projected["frame"],
        "crown": projected["crown"],
        "jamb": projected["jamb"],
        "header": projected["header"],
        "portalOuterWidthWorld": world_span(frame_ids, component_boxes, 2),
        "portalOuterHeightWorld": world_span(frame_ids, component_boxes, 1),
        "portalJambThicknessWorld": world_span(jamb_ids, component_boxes, 2),
        "portalHeaderThicknessWorld": world_span(header_ids, component_boxes, 1),
        "silhouetteHeightsWorld": silhouette_heights,
        "silhouetteBreakCount": len(set(silhouette_heights)),
    }


def path_is_owned(path_value: Any) -> bool:
    if not isinstance(path_value, str):
        return False
    path = Path(path_value)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        return False
    normalized = path.as_posix()
    return any(normalized == root or normalized.startswith(root + "/") for root in OWNED_ROOTS)


def audit_geometry(design: dict[str, Any], lowering: dict[str, Any], errors: list[str]) -> tuple[dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]], dict[str, Any] | None]:
    components = design.get("components")
    if not isinstance(components, list):
        add_error(errors, "components-schema")
        return {}, None
    component_ids = [component.get("id") for component in components if isinstance(component, dict)]
    if len(component_ids) != len(set(component_ids)):
        add_error(errors, "component-alias", "duplicate-id")
    boxes: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]] = {}
    for component in components:
        if not isinstance(component, dict) or not isinstance(component.get("id"), str):
            add_error(errors, "component-schema")
            continue
        component_id = component["id"]
        raw_aabb = component.get("aabb")
        if isinstance(raw_aabb, dict) and any(key in raw_aabb for key in ("isAperture", "processOccluder")):
            add_error(errors, "aabb-schema", f"flags-must-be-component-level:{component_id}")
        parsed = parse_aabb(raw_aabb, component_id, errors)
        if parsed is not None:
            boxes[component_id] = parsed
    aperture_components = [component for component in components if isinstance(component, dict) and component.get("isAperture") is True]
    if len(aperture_components) != 1:
        add_error(errors, "aperture-schema", f"count={len(aperture_components)}")
        return boxes, None
    aperture_id = aperture_components[0].get("id")
    aperture_box = boxes.get(aperture_id)
    if aperture_box is None:
        add_error(errors, "aperture-schema", "missing-aabb")
        return boxes, None
    for component in components:
        if not isinstance(component, dict):
            continue
        component_id = component.get("id")
        box = boxes.get(component_id)
        if box is not None and component_id != aperture_id and intersects(box, aperture_box):
            add_error(errors, "solid-overlaps-aperture", str(component_id))
    process_ids = {component.get("id") for component in components if isinstance(component, dict) and process_occluder(component)}
    declared_process_ids = set(design.get("portalCrown", {}).get("processOccluderIDs", []))
    if process_ids != declared_process_ids:
        add_error(errors, "process-occluder-binding")
    expected_aperture_id = design.get("geometryProof", {}).get("apertureComponentID")
    if expected_aperture_id != aperture_id:
        add_error(errors, "geometry-proof-aperture")
    affine = lowering.get("projection", {}).get("affine")
    if not isinstance(affine, dict):
        add_error(errors, "projection-affine-schema")
        return boxes, None
    metrics = derived_metrics(design, boxes, affine)
    if metrics is None:
        add_error(errors, "geometry-proof-components")
    return boxes, metrics


def compare_derived(design: dict[str, Any], lowering: dict[str, Any], metrics: dict[str, Any] | None, errors: list[str]) -> None:
    if metrics is None:
        return
    portal = design.get("portalCrown", {})
    literal = design.get("literal192Feasibility", {})
    aperture = metrics["aperture"]
    frame = metrics["frame"]
    jamb = metrics["jamb"]
    header = metrics["header"]
    checks = {
        "design:portalOuterWidthWorld": (portal.get("portalOuterWidthWorld"), metrics["portalOuterWidthWorld"]),
        "design:portalOuterHeightWorld": (portal.get("portalOuterHeightWorld"), metrics["portalOuterHeightWorld"]),
        "design:portalJambThicknessWorld": (portal.get("portalJambThicknessWorld"), metrics["portalJambThicknessWorld"]),
        "design:portalHeaderThicknessWorld": (portal.get("portalHeaderThicknessWorld"), metrics["portalHeaderThicknessWorld"]),
        "design:silhouetteBreakHeightsWorld": (portal.get("crownBreakHeightsWorld"), metrics["silhouetteHeightsWorld"]),
        "design:silhouetteBreakCount": (portal.get("silhouetteBreakCount"), metrics["silhouetteBreakCount"]),
        "design:portalInsetWidthPixels": (literal.get("portalInsetWidthPixels"), aperture["literalWidth"]),
        "design:portalInsetHeightPixels": (literal.get("portalInsetHeightPixels"), aperture["literalHeight"]),
        "design:portalOuterWidthPixels": (literal.get("portalOuterWidthPixels"), frame["literalWidth"]),
        "design:portalOuterHeightPixels": (literal.get("portalOuterHeightPixels"), frame["literalHeight"]),
        "design:portalJambThicknessPixels": (literal.get("portalJambThicknessPixels"), jamb["literalWidth"]),
        "design:portalHeaderThicknessPixels": (literal.get("portalHeaderThicknessPixels"), header["literalHeight"]),
    }
    for label, (actual, expected) in checks.items():
        if not same_value(actual, expected):
            add_error(errors, "derived-drift", label)
    lower_aperture = lowering.get("portalAperture", {})
    lower_frame = lowering.get("portalFrame", {})
    lower_silhouette = lowering.get("silhouette", {})
    proof = design.get("geometryProof", {})
    if lower_frame.get("componentIDs") != proof.get("portalFrameComponentIDs"):
        add_error(errors, "derived-drift", "lowering:frame-components")
    if lower_silhouette.get("componentIDs") != proof.get("silhouetteComponentIDs"):
        add_error(errors, "derived-drift", "lowering:silhouette-components")
    lower_checks = {
        "lowering:aperture-source": (lower_aperture.get("sourceAnalyticBounds"), aperture["source"]),
        "lowering:aperture-literal": (lower_aperture.get("literal192Bounds"), aperture["literal"]),
        "lowering:aperture-width": (lower_aperture.get("literal192WidthPixels"), aperture["literalWidth"]),
        "lowering:aperture-height": (lower_aperture.get("literal192HeightPixels"), aperture["literalHeight"]),
        "lowering:frame-source": (lower_frame.get("sourceAnalyticBounds"), frame["source"]),
        "lowering:frame-literal": (lower_frame.get("literal192Bounds"), frame["literal"]),
        "lowering:frame-width": (lower_frame.get("literal192WidthPixels"), frame["literalWidth"]),
        "lowering:frame-height": (lower_frame.get("literal192HeightPixels"), frame["literalHeight"]),
        "lowering:crown-width": (lower_silhouette.get("portalCrownWidthPixels"), metrics["crown"]["literalWidth"]),
        "lowering:silhouette-heights": (lower_silhouette.get("breakHeightsWorld"), metrics["silhouetteHeightsWorld"]),
        "lowering:silhouette-count": (lower_silhouette.get("breakCount"), metrics["silhouetteBreakCount"]),
    }
    for label, (actual, expected) in lower_checks.items():
        if not same_value(actual, expected):
            add_error(errors, "derived-drift", label)


def audit_bundle(design: dict[str, Any], materials: dict[str, Any], lowering: dict[str, Any], result: dict[str, Any], verify_files: bool) -> list[str]:
    errors: list[str] = []
    if design.get("task") != "PLAY-081" or design.get("direction") != "west":
        add_error(errors, "identity", "design")
    if design.get("authorityBindings", {}).get("publishedBase") != EXPECTED_BASE:
        add_error(errors, "authority", "base")
    if design.get("authorityBindings", {}).get("claim", {}).get("sha256") != EXPECTED_CLAIM_SHA:
        add_error(errors, "authority", "claim")
    independence = design.get("independence", {})
    if independence.get("orientationTransform") != "none":
        add_error(errors, "direction", "orientation")
    if independence.get("siblingInputsConsumed") != []:
        add_error(errors, "direction", "siblings")
    if design.get("sourceAuthority") is not False or design.get("pixelRenderingAuthorized") is not False:
        add_error(errors, "boundary", "source-or-pixel")

    registration = design.get("registration", {})
    expected_registration = {
        "frontageEdge": "west",
        "frontageSocketWorldXYZ": [-28, 0, 0],
        "frontageSocketBlenderXYZ": [0, -28, 0],
        "frontageSocketSourceXY": [640, 704],
        "groundPivotWorldXYZ": [28, 0, 28],
        "contactPolygonWorldXZ": [[-28, -28], [28, -28], [28, 28], [-28, 28]],
    }
    for key, expected in expected_registration.items():
        if registration.get(key) != expected:
            add_error(errors, "registration", key)
    if design.get("camera", {}).get("projection") != "orthographic-2:1":
        add_error(errors, "camera", "projection")

    boxes, metrics = audit_geometry(design, lowering, errors)
    compare_derived(design, lowering, metrics, errors)
    affine = lowering.get("projection", {}).get("affine")
    if isinstance(affine, dict):
        try:
            socket_source = [round(value, 9) for value in project(tuple(registration["frontageSocketWorldXYZ"]), affine)]
            pivot_source = [round(value, 9) for value in project(tuple(registration["groundPivotWorldXYZ"]), affine)]
            if socket_source != registration.get("frontageSocketSourceXY"):
                add_error(errors, "registration", "socket-projection")
            if pivot_source != registration.get("groundPivotSourceXY"):
                add_error(errors, "registration", "pivot-projection")
            if lowering.get("registration", {}).get("sourceSocket") != socket_source:
                add_error(errors, "registration", "lowering-socket")
            if lowering.get("registration", {}).get("groundPivotSourceXY") != pivot_source:
                add_error(errors, "registration", "lowering-pivot")
        except (KeyError, TypeError, ValueError):
            add_error(errors, "projection-affine-schema")
    if lowering.get("projection", {}).get("registrationErrorSourcePixels") != 0:
        add_error(errors, "registration", "lowering-error")
    if lowering.get("orientationTransform") != "none":
        add_error(errors, "direction", "lowering-orientation")

    camera = design.get("camera", {})
    lowering_camera = lowering.get("camera", {})
    for camera_key in ("projection", "positionWorldXYZ", "targetWorldXYZ", "orthographicScaleWorld", "renderViewportPixels", "literalViewportPixels", "shiftX", "shiftY"):
        if not same_value(lowering_camera.get(camera_key), camera.get(camera_key)):
            add_error(errors, "camera", f"lowering-drift:{camera_key}")
    if lowering.get("registration", {}).get("frontage") != "west":
        add_error(errors, "registration", "lowering-frontage")
    if lowering.get("portalAperture", {}).get("worldAABB") != design.get("portalCrown", {}).get("apertureInteriorAABBWorldXYZ"):
        add_error(errors, "derived-drift", "aperture-world-aabb")

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
        if not isinstance(item, dict):
            continue
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
    west_binding = result.get("westBinding", {})
    if west_binding.get("siblingInputsConsumed") != [] or west_binding.get("orientationTransform") != "none":
        add_error(errors, "evidence", "direction-isolation")
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
    if metrics is not None:
        if analytic.get("portalInsetWidthPixels") != metrics["aperture"]["literalWidth"] or analytic.get("portalInsetHeightPixels") != metrics["aperture"]["literalHeight"]:
            add_error(errors, "evidence-derived-drift", "aperture")
        if analytic.get("portalOuterWidthPixels") != metrics["frame"]["literalWidth"] or analytic.get("portalOuterHeightPixels") != metrics["frame"]["literalHeight"]:
            add_error(errors, "evidence-derived-drift", "frame")
        if analytic.get("silhouetteBreaks") != metrics["silhouetteBreakCount"]:
            add_error(errors, "evidence-derived-drift", "silhouette")
    if analytic.get("socketSourceXY") != [640, 704] or analytic.get("pivotSourceXY") != [768, 896]:
        add_error(errors, "evidence", "registration")
    activity = result.get("activity", {})
    if any(activity.get(key) != 0 for key in ("blenderProcessLaunches", "dccInvocations", "renderInvocations", "blenderRenderApiCalls", "imageGenInvocations", "normalizerInvocations", "contactSheetInvocations", "sourceProcessABC", "pixelFiles", "sourceCandidatePackets")):
        add_error(errors, "zero-pixel", "evidence")
    return errors


def run_adversaries(bundle: tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]) -> dict[str, str]:
    names: dict[str, str] = {}

    def expect_reject(label: str, mutate: Any) -> None:
        candidate = tuple(copy.deepcopy(item) for item in bundle)
        mutate(candidate)
        errors = audit_bundle(*candidate, verify_files=False)
        require(errors, f"adversary accepted: {label}")
        names[label] = errors[0]

    def nested_occluder(candidate: tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]) -> None:
        design = candidate[0]
        process = next(item for item in design["components"] if item["id"] == "west-v13-hot-process")
        aperture = next(item for item in design["components"] if item.get("isAperture") is True)
        process["processOccluder"] = False
        process["metadata"] = {"processOccluder": True}
        process["aabb"] = copy.deepcopy(aperture["aabb"])

    def invalid_aabb(candidate: tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]) -> None:
        candidate[0]["components"][0]["aabb"]["min"][0] = "not-a-number"

    def collision(candidate: tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]) -> None:
        design = candidate[0]
        aperture = next(item for item in design["components"] if item.get("isAperture") is True)
        reveal = next(item for item in design["components"] if item["id"] == "west-v13-inner-reveal")
        reveal["aabb"] = copy.deepcopy(aperture["aabb"])

    def width_drift(candidate: tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]) -> None:
        candidate[0]["literal192Feasibility"]["portalInsetWidthPixels"] += 1

    def bounds_drift(candidate: tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]) -> None:
        candidate[2]["portalAperture"]["literal192Bounds"]["min"][0] += 1

    def camera_drift(candidate: tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]) -> None:
        candidate[2]["camera"]["orthographicScaleWorld"] += 1

    def alias(candidate: tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]) -> None:
        candidate[1]["roleBindings"][0]["usedBy"].append("west-v13-foundry-hall")

    def path_escape(candidate: tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]) -> None:
        candidate[3]["bindings"]["design"]["path"] = "../sibling/WEST-V13-DESIGN.json"

    adversaries = {
        "nested-occluder": nested_occluder,
        "invalid-aabb": invalid_aabb,
        "solid-aperture-collision": collision,
        "width-drift": width_drift,
        "bounds-drift": bounds_drift,
        "camera-drift": camera_drift,
        "material-alias": alias,
        "path-escape": path_escape,
    }
    for label, mutate in adversaries.items():
        expect_reject(label, mutate)
    return names


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

    bundle = (design, materials, lowering, result)
    errors = audit_bundle(*bundle, verify_files=True)
    require(not errors, "proof audit failed: " + "; ".join(errors))
    adversaries = run_adversaries(bundle)
    require(len(adversaries) == 8, "adversary coverage")

    generated = [path for path in V13_ROOT.rglob("*") if path.is_file() and path.suffix.lower() in PIXEL_SUFFIXES]
    require(not generated, f"pixel or binary output present: {generated}")
    print("PASS v13-west-proof-repair derived=PASS aabb=PASS aperture=PASS camera=PASS alias=PASS adversaries=8 zeroPixel=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
