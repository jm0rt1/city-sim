#!/usr/bin/env python3
"""Validate East v13 pure-data lowering, projection, and adversarial proof."""

from __future__ import annotations

import copy
import hashlib
import json
import math
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parents[5]
PACKET = ROOT / "V13-COMPATIBILITY-DESIGN-V05.json"
EVIDENCE_ROOT = ROOT.parents[5] / "docs" / "production" / "evidence" / "PLAY-079" / "industrial-l04-east-source-v01" / "v13-compatibility-v02"
RESULT = EVIDENCE_ROOT / "V13-COMPATIBILITY-RESULT.json"
CLAIM = ROOT.parents[5] / "docs" / "production" / "claims" / "PLAY-079.world-art-east.md"
EAST_SCENE = ROOT.parent / "industrial-l04-east-predesign-v01" / "scene.json"
EAST_MATERIALS = ROOT.parent / "industrial-l04-east-predesign-v01" / "materials.json"
SEMANTIC_AUTHORITY = ROOT.parents[5] / "docs" / "production" / "evidence" / "PLAY-027" / "industrial-l04" / "l04" / "blender-north-art-v13" / "design-authority-v01" / "DESIGN-AUTHORITY.json"
SEMANTIC_MATERIALS = ROOT.parents[5] / "Native" / "CitySimNative" / "WorldArt" / "Blender" / "PLAY-027" / "industrial-l04-north-art-v13" / "DESIGN-MATERIALS.json"
BRIDGE = ROOT.parents[5] / "Native" / "CitySimNative" / "WorldArt" / "Blender" / "PLAY-027" / "industrial-l04-direction-bridge-v06" / "MAPPING-CONTRACT.json"
PARENT_CANDIDATE = "c297e663bc0f1c5b4ca9cf6b733b21bc6a3fb66f"
EXPECTED_SOURCE_REVISION = "east-v13-compatibility-v05-literal-repair-v1"
EXPECTED_GEOMETRY_ORIGIN = "independently-authored-east-from-published-v13-semantic-requirements"
EXPECTED_CLAIM_PATH = "docs/production/claims/PLAY-079.world-art-east.md"
EXPECTED_EAST_SCENE_PATH = "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-predesign-v01/scene.json"
EXPECTED_SUCCESSOR_PATHS = {
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/V13-COMPATIBILITY-DESIGN-V05.json",
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/test_v13_compatibility_v05.py",
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v13-compatibility-v02/V13-COMPATIBILITY-RESULT.json",
}
EXPECTED_SEMANTIC_INPUTS = [
    {
        "path": "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/design-authority-v01/DESIGN-AUTHORITY.json",
        "sha256": "1b1006403081c3933c54451b6c506af74493a2ac3b253fdd9f1f79098d7c1bed",
        "consumedAs": "semantic-requirements-only",
    },
    {
        "path": "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/DESIGN-MATERIALS.json",
        "sha256": "c8179b77a184e41b723e26b34e7da2ef256b09e93b54a47e76cc5103f22b8cab",
        "consumedAs": "published-material-roles-only",
    },
]
EXPECTED_SOURCE_MAPPING = {
    "v13-grounded-foundation": "formed-concrete",
    "v13-integrated-operating-apron": "contact-shadow",
    "v13-warm-foundry-masonry": "warm-weathered-masonry",
    "v13-warm-control-masonry": "formed-concrete",
    "v13-charcoal-structural-steel": "dark-painted-steel",
    "v13-portal-crown-steel": "roof-edge-metal",
    "v13-weathered-bluegreen-roof": "roof-edge-metal",
    "v13-clerestory-and-roof-edge": "glazing-louver",
    "v13-deep-freight-void": "portal-void",
    "v13-oxidized-process-machinery": "safety-oxide",
    "v13-restrained-hot-process": "hot-process",
    "v13-warm-staff-glazing": "glazing-louver",
}
EXPECTED_COMPONENT_BINDINGS = {
    "east-v13-grounded-foundation": ("foundation", "v13-grounded-foundation", "formed-concrete"),
    "east-v13-operating-apron": ("apron", "v13-integrated-operating-apron", "contact-shadow"),
    "east-v13-foundry-hall": ("mass", "v13-warm-foundry-masonry", "warm-weathered-masonry"),
    "east-v13-portal-south-jamb": ("portal-frame", "v13-charcoal-structural-steel", "dark-painted-steel"),
    "east-v13-portal-north-jamb": ("portal-frame", "v13-charcoal-structural-steel", "dark-painted-steel"),
    "east-v13-portal-header": ("portal-frame", "v13-warm-control-masonry", "formed-concrete"),
    "east-v13-deep-freight-void": ("portal-inset", "v13-deep-freight-void", "portal-void"),
    "east-v13-crown-lower": ("portal-crown", "v13-portal-crown-steel", "roof-edge-metal"),
    "east-v13-crown-middle": ("portal-crown", "v13-weathered-bluegreen-roof", "roof-edge-metal"),
    "east-v13-crown-high": ("portal-crown", "v13-clerestory-and-roof-edge", "glazing-louver"),
    "east-v13-hot-process": ("hot-process", "v13-restrained-hot-process", "hot-process"),
    "east-v13-northwest-process-stack": ("process-stack", "v13-oxidized-process-machinery", "safety-oxide"),
    "east-v13-south-staff-annex": ("staff-annex", "v13-warm-staff-glazing", "glazing-louver"),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    value = {}
    for key, item in pairs:
        if key in value:
            raise AssertionError(f"duplicate_json_field:{key}")
        value[key] = item
    return value


def parse_json(text: str) -> dict:
    value = json.loads(text, object_pairs_hook=_unique_object)
    if not isinstance(value, dict):
        raise AssertionError("not_object")
    return value


def load(path: Path) -> dict:
    return parse_json(path.read_text(encoding="utf-8"))


def fail(code: str, detail: str = "") -> None:
    raise AssertionError(code + (":" + detail if detail else ""))


def overlap(a: dict[str, float], b: dict[str, float]) -> float:
    width = max(0.0, min(a["xMax"], b["xMax"]) - max(a["xMin"], b["xMin"]))
    height = max(0.0, min(a["yMax"], b["yMax"]) - max(a["yMin"], b["yMin"]))
    depth = max(0.0, min(a["zMax"], b["zMax"]) - max(a["zMin"], b["zMin"]))
    return width * height * depth


def city_to_blender(bounds: dict[str, float]) -> dict[str, float]:
    return {
        "xMin": bounds["zMin"], "xMax": bounds["zMax"],
        "yMin": bounds["xMin"], "yMax": bounds["xMax"],
        "zMin": bounds["yMin"], "zMax": bounds["yMax"],
    }


def _normalize(vector: list[float]) -> list[float]:
    length = math.sqrt(sum(value * value for value in vector))
    return [value / length for value in vector]


def _subtract(left: list[float], right: list[float]) -> list[float]:
    return [a - b for a, b in zip(left, right)]


def _cross(left: list[float], right: list[float]) -> list[float]:
    return [left[1] * right[2] - left[2] * right[1], left[2] * right[0] - left[0] * right[2], left[0] * right[1] - left[1] * right[0]]


def _dot(left: list[float], right: list[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def projected_bounds(bounds: dict[str, float], camera: dict) -> dict[str, float]:
    forward = _normalize(_subtract(camera["target"], camera["position"]))
    right = _normalize(_cross(forward, [0.0, 0.0, 1.0]))
    up = _cross(right, forward)
    width, height = camera["resolution"]
    corners = [[x, y, z] for x in (bounds["xMin"], bounds["xMax"]) for y in (bounds["yMin"], bounds["yMax"]) for z in (bounds["zMin"], bounds["zMax"])]
    points = []
    for point in corners:
        delta = _subtract(point, camera["target"])
        points.append((width * (0.5 + _dot(delta, right) / camera["orthoScale"]), height * (0.5 - _dot(delta, up) / camera["orthoScale"]) + camera["shift"][1] * height))
    literal_x = camera["literalResolution"][0] / width
    literal_y = camera["literalResolution"][1] / height
    return {
        "minX": min(x for x, _ in points) * literal_x,
        "maxX": max(x for x, _ in points) * literal_x,
        "minY": min(y for _, y in points) * literal_y,
        "maxY": max(y for _, y in points) * literal_y,
        "width": (max(x for x, _ in points) - min(x for x, _ in points)) * literal_x,
        "height": (max(y for _, y in points) - min(y for _, y in points)) * literal_y,
    }


def union_bounds(items: list[dict[str, float]]) -> dict[str, float]:
    return {key: (min(item[key] for item in items) if key.endswith("Min") else max(item[key] for item in items)) for key in ("xMin", "xMax", "yMin", "yMax", "zMin", "zMax")}


def derived_component_signature(components: list[dict]) -> str:
    payload = [{key: item[key] for key in ("id", "kind", "bounds", "semanticRole", "targetRole", "materialRole")} for item in components]
    return hashlib.sha256(canonical(payload)).hexdigest()


def flatten_components(components: list[dict]) -> list[dict]:
    flattened = []
    for component in components:
        flattened.append(component)
        children = component.get("children", [])
        if not isinstance(children, list):
            fail("recursive_geometry")
        flattened.extend(flatten_components(children))
    return flattened


def field_occurrences(value: object, field: str, path: str = "$") -> list[tuple[str, object]]:
    occurrences = []
    if isinstance(value, dict):
        for key, item in value.items():
            item_path = f"{path}.{key}"
            if key == field:
                occurrences.append((item_path, item))
            occurrences.extend(field_occurrences(item, field, item_path))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            occurrences.extend(field_occurrences(item, field, f"{path}[{index}]"))
    return occurrences


def derived_raw_geometry_signature(components: list[dict]) -> str:
    payload = [{"id": item["id"], "bounds": item["bounds"]} for item in flatten_components(components)]
    return hashlib.sha256(canonical(payload)).hexdigest()


def _bounds_key(bounds: dict[str, float]) -> tuple[float, ...]:
    return tuple(round(float(bounds[key]), 9) for key in ("xMin", "xMax", "yMin", "yMax", "zMin", "zMax"))


def _moving_interval_overlap(center: float, half_width: float, direction: float, low: float, high: float) -> tuple[float, float]:
    other_center = (low + high) / 2.0
    combined_half_width = half_width + (high - low) / 2.0
    if abs(direction) < 1e-12:
        return (-float("inf"), float("inf")) if abs(center - other_center) < combined_half_width else (1.0, 0.0)
    endpoints = (
        (other_center - center - combined_half_width) / direction,
        (other_center - center + combined_half_width) / direction,
    )
    return min(endpoints), max(endpoints)


def camera_occludes_aperture(bounds: dict[str, float], aperture: dict[str, float], camera: dict) -> bool:
    direction = _normalize(_subtract(camera["position"], camera["target"]))
    intervals = [
        _moving_interval_overlap((aperture["xMin"] + aperture["xMax"]) / 2.0, (aperture["xMax"] - aperture["xMin"]) / 2.0, direction[0], bounds["xMin"], bounds["xMax"]),
        _moving_interval_overlap(aperture["yMax"], 0.0, direction[1], bounds["yMin"], bounds["yMax"]),
        _moving_interval_overlap((aperture["zMin"] + aperture["zMax"]) / 2.0, (aperture["zMax"] - aperture["zMin"]) / 2.0, direction[2], bounds["zMin"], bounds["zMax"]),
    ]
    near = max(1e-6, *(interval[0] for interval in intervals))
    far = min(interval[1] for interval in intervals)
    return near < far


def validate_packet(packet: dict, check_files: bool = True) -> dict:
    if packet.get("schema") != "citysim.play-079.east-v13-compatibility-design.v1": fail("schema")
    if packet.get("task") != "PLAY-079" or packet.get("direction") != "east": fail("identity")
    if packet.get("logicalBuildingID") != "industrial_l04" or packet.get("variant") != 0: fail("logical_identity")
    if packet.get("phase") != "V13_ZERO_PIXEL_COMPATIBILITY": fail("phase")
    if packet.get("sourceRevision") != EXPECTED_SOURCE_REVISION: fail("source_revision_binding")
    source_ready = field_occurrences(packet, "sourceReady")
    production_selected = field_occurrences(packet, "productionSelected")
    if source_ready != [("$.sourceReady", False)]: fail("source_ready_boundary")
    if production_selected != [("$.productionSelected", False)]: fail("production_selection_boundary")
    if packet.get("sourceAuthority") is not False or packet.get("pixelRenderingAllowed") is not False: fail("authority_boundary")

    provenance = packet["provenance"]
    if provenance.get("geometryOrigin") != EXPECTED_GEOMETRY_ORIGIN: fail("geometry_origin_binding")
    if provenance["siblingSceneInputs"] != []: fail("sibling_geometry_input")
    if any(provenance[key] is not False for key in ("copiedGeometry", "mirroredGeometry", "rotatedGeometry", "transformedSiblingGeometry")): fail("geometry_alias")
    if provenance["orientationTransform"] != "none": fail("orientation_transform")

    authority = packet["authority"]
    if authority["authorityCommit"] != "d010d453af87c040ac13e8b3b7280366cb5094c1" or authority["baseCommit"] != authority["authorityCommit"]: fail("authority")
    if authority["routeId"] != "quality-v1:east-v13-literal-repair-v1" or authority["routeSha256"] != "01ba44d5c7b275a0298725440f9baaa0856664f28c3cc36530f25c02d243f2ef": fail("route_binding")
    if authority["dispatchReceipt"] != {
        "carrierCommit": "af89c2fc2a542535fea8162b9f7ca78d38506d30",
        "path": "docs/production/evidence/INTEGRATION/MODEL-ROUTING-QUALITY-INDUSTRIAL-L04-V13-LITERAL-REPAIR-LUNA-V1.json",
        "sha256": "59c87bf291a8545e29e09be2c0e8c3d8b2e8ccb1021619b2bcf18bedcc00e838",
    }: fail("route_binding")
    if authority["claim"] != {"path": EXPECTED_CLAIM_PATH, "sha256": "93bcc57e69bc4cd1ff492ce0dfbf5d6244c3782db524e7e16fc0d9dd78431a77"}: fail("claim_binding")
    if authority["publishedSemanticInputs"] != EXPECTED_SEMANTIC_INPUTS: fail("semantic_input_binding")
    if check_files:
        if sha(CLAIM) != authority["claim"]["sha256"]: fail("claim_hash")
        if sha(SEMANTIC_AUTHORITY) != authority["publishedSemanticInputs"][0]["sha256"]: fail("semantic_authority_hash")
        if sha(SEMANTIC_MATERIALS) != authority["publishedSemanticInputs"][1]["sha256"]: fail("semantic_materials_hash")
        if sha(BRIDGE) != packet["coordinateBridge"]["sha256"]: fail("bridge_hash")

    bridge_contract = load(BRIDGE)
    bridge_direction = bridge_contract["directions"]["east"]
    bridge_registration = bridge_contract["registration"]
    bridge_camera = bridge_contract["camera"]
    registration = packet["eastRegistration"]
    if registration["citySimFootprint"] != {"width": 72.0, "depth": 72.0}: fail("citysim_footprint")
    if registration["dccFootprint"] != {"width": 56.0, "depth": 56.0, "halfExtent": 28.0}: fail("dcc_footprint")
    if registration["citySimSocket"] != [28.0, 0.0, 0.0] or registration["sourceSocket"] != [896.0, 832.0]: fail("east_socket")
    if registration["groundPivot"] != bridge_registration["pivotBlender"] or registration["sourceGroundPivot"] != bridge_registration["pivotSource"]: fail("east_pivot")
    if registration["orientationTransform"] != "none": fail("registration_transform")
    if registration["citySimSocket"] != bridge_direction["socketCitySim"] or registration["sourceSocket"] != bridge_direction["socketSource"]: fail("east_socket")

    camera = packet["camera"]
    if camera["projection"] != "orthographic" or camera["view"] != "southeast-looking-northwest": fail("camera_kind")
    expected_position = bridge_camera["blenderPosition"]
    expected_target = bridge_camera["blenderTarget"]
    expected_distance = math.sqrt(sum((actual - target) ** 2 for actual, target in zip(expected_position, expected_target)))
    camera_delta = _subtract(camera["position"], camera["target"])
    derived_yaw = math.degrees(math.atan2(camera_delta[1], camera_delta[0]))
    derived_elevation = math.degrees(math.asin(camera_delta[2] / camera["distance"]))
    if camera["position"] != expected_position or camera["target"] != expected_target or not math.isclose(camera["distance"], expected_distance, rel_tol=0, abs_tol=1e-9): fail("camera_drift")
    if not math.isclose(camera["yawDegrees"], derived_yaw, rel_tol=0, abs_tol=1e-9) or not math.isclose(camera["elevationDegrees"], derived_elevation, rel_tol=0, abs_tol=1e-9): fail("camera_drift")
    if camera["shift"] != [bridge_camera["shiftX"], bridge_camera["shiftY"]] or camera.get("derivedFromBridge") is not True: fail("camera_drift")
    if camera["resolution"] != bridge_camera["renderViewportPixels"] or camera["literalResolution"] != [192, 128]: fail("camera_resolution")
    if camera["orthoScale"] != bridge_camera["blenderOrthographicScale"]: fail("camera_drift")
    if packet["sourceBindings"]["eastScene"] != {
        "path": EXPECTED_EAST_SCENE_PATH,
        "sha256": "e19c70693ea57a7f23669d5e93354eee0a8fa42be16e68b38d00f5608a500db7",
        "consumedAs": "historical-byte-preservation-only",
    }: fail("east_scene_binding")
    if check_files:
        east_scene = load(EAST_SCENE)
        east_materials = load(EAST_MATERIALS)
        if camera["literalResolution"] != east_scene["camera"]["literalResolution"]: fail("camera_literal_drift")
        scene_registration = east_scene["registration"]
        if registration["citySimFootprint"] != scene_registration["citySimFootprint"] or registration["dccFootprint"]["width"] != scene_registration["dccFootprint"]["width"] or registration["dccFootprint"]["depth"] != scene_registration["dccFootprint"]["depth"]: fail("east_registration")
        if registration["citySimSocket"] != scene_registration["frontageSocket"]: fail("east_registration")
        if registration["sourceSocket"] != scene_registration["expectedSourcePixels"]["frontageSocket"] or registration["sourceGroundPivot"] != scene_registration["expectedSourcePixels"]["groundPivot"]: fail("east_registration")
        if packet["sourceBindings"]["eastScene"]["sha256"] != sha(EAST_SCENE): fail("east_scene_binding")
        if packet["sourceBindings"]["eastMaterials"]["sha256"] != sha(EAST_MATERIALS) or packet["sourceBindings"]["eastMaterials"]["consumedAs"] != "existing-role-inventory-only": fail("east_material_binding")
    else:
        east_materials = load(EAST_MATERIALS)

    bridge = packet["coordinateBridge"]
    if bridge["formula"] != "B(CitySim[x,y,z])=Blender[z,x,y]" or bridge["matrixRows"] != [[0, 0, 1], [1, 0, 0], [0, 1, 0]]: fail("bridge_formula")
    if bridge["determinant"] != 1 or bridge["perDirectionTransforms"] is not False or bridge["windingChange"] is not False: fail("bridge_transform")
    if bridge["eastSocketBlender"] != bridge_direction["socketBlender"] or bridge["eastOutwardBlender"] != bridge_direction["outwardBlender"]: fail("bridge_east_socket")
    city_socket = registration["citySimSocket"]
    expected_blender_socket = [city_socket[2], city_socket[0], city_socket[1]]
    if bridge["eastSocketBlender"] != expected_blender_socket: fail("bridge_east_socket")
    projection = packet["lowering"]["cameraProjection"]
    if packet["lowering"]["targetCollapse"] is not False or packet["lowering"]["unresolvedComponents"] or packet["lowering"]["fallbackRoles"]: fail("target_collapse")
    if not math.isclose(projection["sourcePixelsPerWorldUnit"][0], 1536.0 / packet["camera"]["orthoScale"], rel_tol=0, abs_tol=0.001): fail("projection_x")
    if not math.isclose(projection["sourcePixelsPerWorldUnit"][1], 1024.0 / packet["camera"]["orthoScale"], rel_tol=0, abs_tol=0.001): fail("projection_y")

    semantic_materials = load(SEMANTIC_MATERIALS)
    semantic_roles = {item["id"] for item in semantic_materials["materials"]}
    mapping = packet["materialRoleMapping"]
    source_mapping = packet["sourceRoleMapping"]
    existing_roles = {item["id"] for item in east_materials["roles"]}
    if mapping != {role: role for role in semantic_roles}: fail("target_role_injective")
    if source_mapping != EXPECTED_SOURCE_MAPPING or set(source_mapping) != semantic_roles or set(source_mapping.values()) != existing_roles: fail("source_material_mapping")
    if set(packet["targetMaterialRoles"]) != semantic_roles or len(packet["targetMaterialRoles"]) != 12: fail("target_role_injective")

    plan = packet["eastFacadePlan"]
    components = plan["components"]
    ids = [item["id"] for item in components]
    all_components = flatten_components(components)
    all_ids = [item["id"] for item in all_components]
    if len(all_ids) != len(set(all_ids)): fail("raw_geometry_alias")
    if plan["roadFacing"] != "east" or len(ids) != len(set(ids)): fail("portal_identity")
    if set(ids) != set(EXPECTED_COMPONENT_BINDINGS): fail("component_identity")
    if any(not item["id"].startswith("east-v13-") for item in components): fail("structural_alias")
    if any(item.get("semanticRole") not in mapping or item.get("targetRole") != item.get("semanticRole") or item.get("materialRole") not in existing_roles for item in components): fail("unresolved_material")
    for item in components:
        expected_kind, expected_semantic, expected_source = EXPECTED_COMPONENT_BINDINGS[item["id"]]
        if (item["kind"], item["semanticRole"], item["materialRole"]) != (expected_kind, expected_semantic, expected_source): fail("component_material_binding", item["id"])
        if item["targetRole"] != expected_semantic or item["materialRole"] != source_mapping[expected_semantic]: fail("component_material_binding", item["id"])
        bounds = item["bounds"]
        if not (-28.0 <= bounds["xMin"] <= bounds["xMax"] <= 28.0 and -28.0 <= bounds["yMin"] <= bounds["yMax"] <= 28.0 and 0.0 <= bounds["zMin"] <= bounds["zMax"]): fail("component_bounds", item["id"])

    rules = packet["loweringRules"]
    if len(rules) != len(all_components) or {rule["componentId"] for rule in rules} != set(all_ids): fail("lowering_coverage")
    by_id = {item["id"]: item for item in all_components}
    for rule in rules:
        item = by_id[rule["componentId"]]
        expected_semantic = item["semanticRole"]
        expected_source = source_mapping[expected_semantic]
        if rule["semanticRole"] != item["semanticRole"] or rule["targetRole"] != item["targetRole"] or rule["sourceRole"] != item["materialRole"]: fail("unresolved_material", rule["componentId"])
        if rule["semanticRole"] != expected_semantic or rule["targetRole"] != expected_semantic or rule["sourceRole"] != expected_source or rule["sourceRole"] != source_mapping[expected_semantic]: fail("lowering_material_binding", rule["componentId"])
        if rule["targetRole"] not in semantic_roles or rule["sourceRole"] not in existing_roles: fail("unresolved_material", rule["componentId"])
        if city_to_blender(rule["citySimBounds"]) != item["bounds"]: fail("lowering_projection", rule["componentId"])
    if len({item["targetRole"] for item in all_components}) != 12 or len({rule["targetRole"] for rule in rules}) != 12: fail("target_role_injective")

    portal = plan["portal"]
    if not isinstance(portal, dict): fail("missing_portal")
    if portal["apertureComponentID"] not in by_id or portal["apertureComponentID"] != "east-v13-deep-freight-void": fail("aperture_relocated")
    if packet["apertureAudit"]["clearApertureBounds"] != by_id[portal["apertureComponentID"]]["bounds"]: fail("aperture_relocated")
    if set(portal["jambComponentIDs"]) != {"east-v13-portal-south-jamb", "east-v13-portal-north-jamb"} or portal["headerComponentID"] != "east-v13-portal-header": fail("missing_portal")
    if portal["freightBeatCount"] != 3 or portal["minimumProcessOccluders"] != 0 or portal["apronTerminatesAtSocket"] is not True: fail("portal_requirements")
    if portal["clearInsetWidthWorld"] < 28.0 or portal["clearInsetHeightWorld"] < 26.0 or portal["jambThicknessWorld"] < 6.0 or portal["headerThicknessWorld"] < 6.0: fail("portal_literal_targets")
    aperture_bounds = by_id[portal["apertureComponentID"]]["bounds"]
    outward = bridge["eastOutwardBlender"]
    if outward != [0.0, 1.0, 0.0]: fail("bridge_east_socket")
    frontage_coordinate = bridge["eastSocketBlender"][1]
    if aperture_bounds["yMax"] != frontage_coordinate or aperture_bounds["yMin"] >= frontage_coordinate: fail("east_aperture_placement")
    if not math.isclose((aperture_bounds["xMin"] + aperture_bounds["xMax"]) / 2.0, bridge["eastSocketBlender"][0], rel_tol=0, abs_tol=1e-9): fail("east_aperture_placement")
    frontage_ids = portal["jambComponentIDs"] + [portal["headerComponentID"], "east-v13-operating-apron"]
    if any(by_id[component_id]["bounds"]["yMax"] != frontage_coordinate for component_id in frontage_ids): fail("east_aperture_placement")
    crown_ids = plan["silhouette"]["crownComponentIDs"]
    crown_spans = {tuple((by_id[item]["bounds"]["zMin"], by_id[item]["bounds"]["zMax"])) for item in crown_ids}
    derived_break_count = len({by_id[item]["bounds"]["zMin"] for item in crown_ids})
    if len(crown_ids) != 3 or len(crown_spans) != 3 or plan["silhouette"]["distinctRoofHeightBreaks"] != derived_break_count or derived_break_count < 3: fail("crown_collapse" if len(crown_spans) != 3 else "silhouette_breaks")
    ordered_crowns = [by_id[item]["bounds"] for item in crown_ids]
    minimum_world = plan["silhouette"].get("minimumTierEnvelopeSeparationWorld")
    if minimum_world != 10.0 or any(
        upper["zMin"] - lower["zMin"] < minimum_world or upper["zMax"] - lower["zMax"] < minimum_world
        for lower, upper in zip(ordered_crowns, ordered_crowns[1:])
    ): fail("crown_envelope_collapse")

    measured = packet["measuredLiteral192"]
    portal_projection = projected_bounds(union_bounds([by_id[item]["bounds"] for item in portal["jambComponentIDs"] + [portal["headerComponentID"], portal["apertureComponentID"]]]), camera)
    void_projection = projected_bounds(by_id[portal["apertureComponentID"]]["bounds"], camera)
    crown_projection = projected_bounds(union_bounds([by_id[item]["bounds"] for item in crown_ids]), camera)
    crown_band_heights = [projected_bounds(by_id[item]["bounds"], camera)["height"] for item in crown_ids]
    crown_projected_tops = [projected_bounds(by_id[item]["bounds"], camera)["minY"] for item in crown_ids]
    minimum_projected = plan["silhouette"].get("minimumProjectedTierBreakSeparationPixels")
    if minimum_projected != 3.0 or any(abs(upper - lower) < minimum_projected for lower, upper in zip(crown_projected_tops, crown_projected_tops[1:])): fail("crown_envelope_collapse")
    if not math.isclose(measured["portalBoundsPixels"]["outerWidth"], portal_projection["width"], rel_tol=0, abs_tol=0.001) or not math.isclose(measured["portalBoundsPixels"]["outerHeight"], portal_projection["height"], rel_tol=0, abs_tol=0.001): fail("inflated_literal_metric")
    if not math.isclose(measured["portalBoundsPixels"]["clearInsetWidth"], void_projection["width"], rel_tol=0, abs_tol=0.001) or not math.isclose(measured["portalBoundsPixels"]["clearInsetHeight"], void_projection["height"], rel_tol=0, abs_tol=0.001): fail("inflated_literal_metric")
    jamb_widths = [projected_bounds(by_id[item]["bounds"], camera)["width"] for item in portal["jambComponentIDs"]]
    header_height = projected_bounds(by_id[portal["headerComponentID"]]["bounds"], camera)["height"]
    if any(not math.isclose(measured["portalBoundsPixels"]["jambThicknessEach"], width, rel_tol=0, abs_tol=0.001) for width in jamb_widths): fail("inflated_literal_metric")
    if not math.isclose(measured["portalBoundsPixels"]["headerThickness"], header_height, rel_tol=0, abs_tol=0.001): fail("inflated_literal_metric")
    if not math.isclose(measured["crownBoundsPixels"]["width"], crown_projection["width"], rel_tol=0, abs_tol=0.001) or not math.isclose(measured["crownBoundsPixels"]["height"], crown_projection["height"], rel_tol=0, abs_tol=0.001): fail("inflated_literal_metric")
    if any(not math.isclose(actual, expected, rel_tol=0, abs_tol=0.001) for actual, expected in zip(measured["crownBoundsPixels"]["heightBreaks"], crown_band_heights)): fail("inflated_literal_metric")
    beat_width = void_projection["width"] / portal["freightBeatCount"]
    expected_beats = [[beat_width, void_projection["height"]] for _ in range(portal["freightBeatCount"])]
    if len(measured["freightBeatBoundsPixels"]) != portal["freightBeatCount"] or any(
        not math.isclose(actual, expected, rel_tol=0, abs_tol=0.001)
        for actual_pair, expected_pair in zip(measured["freightBeatBoundsPixels"], expected_beats)
        for actual, expected in zip(actual_pair, expected_pair)
    ): fail("inflated_literal_metric")
    if measured["portalBoundsPixels"]["outerWidth"] < 24 or measured["portalBoundsPixels"]["outerHeight"] < 22 or measured["portalBoundsPixels"]["clearInsetWidth"] < 18 or measured["portalBoundsPixels"]["clearInsetHeight"] < 18: fail("literal_portal_bounds")
    if measured["crownBoundsPixels"]["width"] < 28 or len(measured["crownBoundsPixels"]["heightBreaks"]) != 3 or min(measured["crownBoundsPixels"]["heightBreaks"]) < 13: fail("literal_crown_bounds")
    if any(pair[0] < 6 or pair[1] < 18 for pair in measured["freightBeatBoundsPixels"]): fail("literal_freight_headroom")
    if any(abs(upper - lower) < 3 for lower, upper in zip(crown_projected_tops, crown_projected_tops[1:])): fail("literal_crown_bounds")
    apron = by_id["east-v13-operating-apron"]["bounds"]
    socket_gap_world = max(0.0, bridge["eastSocketBlender"][1] - apron["yMax"])
    expected_socket_gap = socket_gap_world * camera["literalResolution"][0] / camera["resolution"][0]
    if measured["processOccluderCount"] != 0 or not math.isclose(measured["socketApronGapPixels"], expected_socket_gap, rel_tol=0, abs_tol=0.001) or measured["socketApronGapPixels"] > 2: fail("literal_occlusion")

    aperture = packet["apertureAudit"]["clearApertureBounds"]
    void_id = "east-v13-deep-freight-void"
    for item in all_components:
        semantic = item.get("semanticRole")
        if semantic not in source_mapping or item.get("targetRole") != semantic or item.get("materialRole") != source_mapping[semantic]: fail("component_material_binding", item.get("id", "missing-id"))
    non_void = [item for item in all_components if item["id"] != void_id]
    audit = packet["apertureAudit"]["auditedComponents"]
    if packet["apertureAudit"]["nonApertureSolidCount"] != len(non_void) or packet["apertureAudit"]["recursivelyAuditedSolidCount"] != len(non_void): fail("aperture_coverage")
    audit_ids = [item["componentId"] for item in audit]
    if len(audit_ids) != len(set(audit_ids)) or set(audit_ids) != {item["id"] for item in non_void}: fail("aperture_coverage")
    projected_occluders = []
    for item in non_void:
        if overlap(item["bounds"], aperture) > 0: fail("aperture_collision", item["id"])
        if camera_occludes_aperture(item["bounds"], aperture, camera):
            projected_occluders.append(item["id"])
    if projected_occluders: fail("camera_projected_occlusion", projected_occluders[0])
    if packet["apertureAudit"].get("cameraProjectedOccluderCount") != 0: fail("camera_projected_occlusion")
    if packet["apertureAudit"]["allIntrusions"] is not False or any(item["intrudes"] or item["overlapAreaWorld2"] != 0.0 for item in audit): fail("aperture_collision")

    occupied = measured.get("occupiedBuildingBoundsPixels")
    if not isinstance(occupied, dict) or not isinstance(occupied.get("continuous"), dict) or not isinstance(occupied.get("quantized"), dict): fail("occupied_envelope_missing")
    building_projection = projected_bounds(union_bounds([item["bounds"] for item in components]), camera)
    expected_quantized = {
        "minX": math.floor(building_projection["minX"]), "maxX": math.ceil(building_projection["maxX"]),
        "minY": math.floor(building_projection["minY"]), "maxY": math.ceil(building_projection["maxY"]),
        "width": math.ceil(building_projection["maxX"]) - math.floor(building_projection["minX"]),
        "height": math.ceil(building_projection["maxY"]) - math.floor(building_projection["minY"]),
    }
    if any(not math.isclose(occupied["continuous"][key], value, rel_tol=0, abs_tol=0.001) for key, value in building_projection.items()): fail("occupied_envelope_stale")
    if occupied.get("quantization") != "floor-min-ceil-max-source-pixel-envelope" or occupied["quantized"] != expected_quantized: fail("occupied_envelope_stale")
    if expected_quantized["width"] < 60 or expected_quantized["height"] < 58: fail("occupied_envelope_undersized")
    targets = packet["literal192Targets"]
    if targets.get("minimumOccupiedWidthPixels") != 60 or targets.get("minimumOccupiedHeightPixels") != 58: fail("occupied_envelope_target")
    if targets.get("minimumOuterPortalWidthPixels") != 24 or targets.get("minimumOuterPortalHeightPixels") != 22 or targets.get("minimumClearInsetWidthPixels") != 18 or targets.get("minimumClearInsetHeightPixels") != 18 or targets.get("portalCrownMinimumWidthPixels") != 28: fail("literal_headroom_targets")
    if targets.get("minimumFreightBeatWidthPixels") != 6 or targets.get("minimumFreightBeatHeightPixels") != 18 or targets.get("minimumCrownBreakSeparationPixels") != 3: fail("literal_headroom_targets")
    if plan["silhouette"].get("minimumPortalHeadroomPixels") != 4.0 or plan["silhouette"].get("minimumFreightBeatHeadroomPixels") != 1.0: fail("literal_headroom_targets")

    alias = packet["nonAliasProof"]
    expected_signature = "east-v13-portal-crown::foundation-apron-hall-jamb-jamb-header-void-crown-crown-crown-hot-stack-annex"
    geometry_keys = [_bounds_key(item["bounds"]) for item in all_components]
    if len(geometry_keys) != len(set(geometry_keys)): fail("raw_geometry_alias")
    if alias["structuralSignature"] != expected_signature or alias["derivedComponentSignatureSHA256"] != derived_component_signature(components) or alias["derivedRawGeometrySHA256"] != derived_raw_geometry_signature(components) or alias["targetCollapse"] is not False or alias["siblingInputsConsumed"] != []: fail("structural_alias")
    if any(old_id in ids for old_id in alias["priorEastRevisionComponentIDs"]): fail("structural_alias")

    changed = packet["changedPathAudit"]
    if changed["parentCandidate"] != PARENT_CANDIDATE or changed["siblingInputsConsumed"] != []: fail("path_escape")
    allowed = ("Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/", "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v13-compatibility-v02/")
    if not changed["changedPaths"]: fail("changed_path_inventory")
    if not changed["allWithinAllowedRoots"] or any(".." in path or not path.startswith(allowed) for path in changed["changedPaths"]): fail("path_escape")
    committed_paths = subprocess.check_output(["git", "diff", "--name-only", PARENT_CANDIDATE, "HEAD"], cwd=REPO_ROOT, text=True).splitlines()
    working_paths = subprocess.check_output(["git", "diff", "--name-only", PARENT_CANDIDATE], cwd=REPO_ROOT, text=True).splitlines()
    expected_paths = (set(committed_paths) | set(working_paths) | EXPECTED_SUCCESSOR_PATHS)
    if set(changed["changedPaths"]) != expected_paths: fail("changed_path_inventory")

    boundary = packet["zeroPixelBoundary"]
    if any(boundary[key] != 0 for key in ("blenderInvocations", "dccInvocations", "renderInvocations", "pixelFilesCreated", "normalizationRuns", "sourcePacketsCreated")): fail("pixel_boundary")
    if boundary.get("productionSelection") is not False: fail("production_selection_boundary")
    if boundary["candidateReadyForIndependentReview"] is not True or boundary["independentReviewRequired"] is not True: fail("review_boundary")

    return {
        "schema": "citysim.play-079.east-v13-compatibility-proof.v3",
        "task": "PLAY-079", "direction": "east", "phase": "V13_ZERO_PIXEL_COMPATIBILITY", "result": "PASS",
        "logicalBuildingID": packet["logicalBuildingID"], "variant": packet["variant"],
        "authority": {"commit": packet["authority"]["authorityCommit"], "routeId": packet["authority"]["routeId"], "routeSha256": packet["authority"]["routeSha256"], "dispatchReceipt": packet["authority"]["dispatchReceipt"]},
        "checks": {"routeAndAuthority": "PASS", "immutableIdentityBindings": "PASS", "readinessSelectionBoundary": "PASS", "bridgeAndLowering": "PASS", "recursiveLoweringCoverage": "PASS", "eastSocketAndPivot": "PASS", "cameraAndLiteral192": "PASS", "eastAperturePlacement": "PASS", "portalAndSilhouette": "PASS", "materialResolution": "PASS", "recursiveApertureAudit": "PASS", "cameraProjectedOcclusion": "PASS", "rawGeometryNonAlias": "PASS", "pathIsolation": "PASS"},
        "socket": {"citySim": registration["citySimSocket"], "blender": bridge["eastSocketBlender"], "source": registration["sourceSocket"]},
        "literal192": measured, "componentCount": len(components), "loweringRuleCount": len(rules), "silhouetteBreakCount": plan["silhouette"]["distinctRoofHeightBreaks"],
        "changedPaths": changed["changedPaths"], "apertureAudit": packet["apertureAudit"],
        "materialRoleCount": len(mapping), "adversarialCases": ["missing_portal", "unresolved_material", "target_collapse", "camera_drift", "yaw_drift", "elevation_drift", "inflated_literal_metric", "missing_occupied_envelope", "undersized_occupied_width", "undersized_occupied_height", "stale_occupied_envelope", "relocated_aperture", "aperture_collision", "nested_aperture_occluder", "camera_projected_occluder", "coherent_west_aperture_relocation", "crown_collapse", "near_identical_crown_envelopes", "empty_changed_paths", "wrong_known_material_membership", "duplicate_raw_geometry", "structural_alias", "path_escape"],
        "siblingSceneInputs": [], "renderInvocations": 0, "imagesWritten": 0, "sourceAuthority": False, "sourceReady": False, "productionSelected": False,
        "sourceHashes": {"packetSHA256": sha(PACKET), "eastSceneSHA256": sha(EAST_SCENE), "eastMaterialsSHA256": sha(EAST_MATERIALS), "claimSHA256": sha(CLAIM), "semanticAuthoritySHA256": sha(SEMANTIC_AUTHORITY), "semanticMaterialsSHA256": sha(SEMANTIC_MATERIALS), "bridgeSHA256": sha(BRIDGE)},
    }


def adversarial_cases(base: dict) -> list[dict[str, str]]:
    cases = []

    def add_nested(packet: dict, bounds: dict[str, float], child_id: str, include_rule: bool = True, include_audit: bool = True) -> None:
        parent = packet["eastFacadePlan"]["components"][2]
        child = {
            "id": child_id, "kind": "nested-solid", "bounds": bounds,
            "semanticRole": parent["semanticRole"], "targetRole": parent["targetRole"], "materialRole": parent["materialRole"],
        }
        parent["children"] = [child]
        if include_rule:
            packet["loweringRules"].append({
                "componentId": child_id,
                "semanticRole": child["semanticRole"],
                "targetRole": child["targetRole"],
                "sourceRole": child["materialRole"],
                "citySimBounds": {
                    "xMin": bounds["yMin"], "xMax": bounds["yMax"],
                    "yMin": bounds["zMin"], "yMax": bounds["zMax"],
                    "zMin": bounds["xMin"], "zMax": bounds["xMax"],
                },
            })
        if include_audit:
            packet["apertureAudit"]["auditedComponents"].append({"componentId": child_id, "intrudes": False, "overlapAreaWorld2": 0.0})
        packet["apertureAudit"]["nonApertureSolidCount"] += 1
        packet["apertureAudit"]["recursivelyAuditedSolidCount"] += 1
        packet["nonAliasProof"]["derivedRawGeometrySHA256"] = derived_raw_geometry_signature(packet["eastFacadePlan"]["components"])

    def relocate_west(packet: dict) -> None:
        component_ids = {
            "east-v13-operating-apron", "east-v13-portal-south-jamb", "east-v13-portal-north-jamb",
            "east-v13-portal-header", "east-v13-deep-freight-void",
        }
        for component in packet["eastFacadePlan"]["components"]:
            if component["id"] in component_ids:
                bounds = component["bounds"]
                bounds["yMin"], bounds["yMax"] = -bounds["yMax"], -bounds["yMin"]
        for rule in packet["loweringRules"]:
            if rule["componentId"] in component_ids:
                bounds = rule["citySimBounds"]
                bounds["xMin"], bounds["xMax"] = -bounds["xMax"], -bounds["xMin"]
        aperture = packet["eastFacadePlan"]["components"][6]["bounds"]
        packet["apertureAudit"]["clearApertureBounds"] = copy.deepcopy(aperture)

    def near_identical_crown(packet: dict) -> None:
        middle = packet["eastFacadePlan"]["components"][8]["bounds"]
        high = packet["eastFacadePlan"]["components"][9]["bounds"]
        high.update({key: value + 0.0001 for key, value in middle.items()})
        packet["loweringRules"][9]["citySimBounds"] = {
            "xMin": high["yMin"], "xMax": high["yMax"], "yMin": high["zMin"],
            "yMax": high["zMax"], "zMin": high["xMin"], "zMax": high["xMax"],
        }

    def duplicate_raw_geometry(packet: dict) -> None:
        source = packet["eastFacadePlan"]["components"][10]["bounds"]
        packet["eastFacadePlan"]["components"][12]["bounds"] = copy.deepcopy(source)
        packet["loweringRules"][12]["citySimBounds"] = {
            "xMin": source["yMin"], "xMax": source["yMax"], "yMin": source["zMin"],
            "yMax": source["zMax"], "zMin": source["xMin"], "zMax": source["xMax"],
        }

    mutations = {
        "forged_source_revision": lambda p: p.update({"sourceRevision": "east-v13-forged"}),
        "forged_geometry_origin": lambda p: p["provenance"].update({"geometryOrigin": "caller-authored-shape-only"}),
        "forged_claim_path": lambda p: p["authority"]["claim"].update({"path": "docs/production/claims/PLAY-080.world-art-south.md"}),
        "forged_semantic_authority_path": lambda p: p["authority"]["publishedSemanticInputs"][0].update({"path": "docs/production/evidence/PLAY-080/forged.json"}),
        "forged_semantic_material_path": lambda p: p["authority"]["publishedSemanticInputs"][1].update({"path": "Native/CitySimNative/WorldArt/Blender/PLAY-081/forged.json"}),
        "forged_east_scene_path": lambda p: p["sourceBindings"]["eastScene"].update({"path": "Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-predesign-v01/scene.json"}),
        "missing_source_ready": lambda p: p.pop("sourceReady"),
        "contradictory_source_ready": lambda p: p.update({"sourceReady": True}),
        "duplicate_source_ready_declaration": lambda p: p["zeroPixelBoundary"].update({"sourceReady": False}),
        "missing_production_selected": lambda p: p.pop("productionSelected"),
        "contradictory_production_selected": lambda p: p.update({"productionSelected": True}),
        "duplicate_production_selected_declaration": lambda p: p["zeroPixelBoundary"].update({"productionSelected": False}),
        "missing_portal": lambda p: p["eastFacadePlan"].update({"portal": None}),
        "unresolved_material": lambda p: p["eastFacadePlan"]["components"][0].update({"semanticRole": "missing-role"}),
        "target_collapse": lambda p: p["lowering"].update({"targetCollapse": True}),
        "camera_drift": lambda p: p["camera"].update({"orthoScale": 1.0}),
        "yaw_drift": lambda p: p["camera"].update({"yawDegrees": 44.0}),
        "elevation_drift": lambda p: p["camera"].update({"elevationDegrees": 29.0}),
        "inflated_literal_metric": lambda p: p["measuredLiteral192"]["portalBoundsPixels"].update({"outerWidth": 999.0}),
        "missing_occupied_envelope": lambda p: p["measuredLiteral192"].pop("occupiedBuildingBoundsPixels"),
        "undersized_occupied_width": lambda p: p["measuredLiteral192"]["occupiedBuildingBoundsPixels"]["quantized"].update({"width": 59}),
        "undersized_occupied_height": lambda p: p["measuredLiteral192"]["occupiedBuildingBoundsPixels"]["quantized"].update({"height": 57}),
        "stale_occupied_envelope": lambda p: p["measuredLiteral192"]["occupiedBuildingBoundsPixels"]["continuous"].update({"maxX": 129.0}),
        "relocated_aperture": lambda p: p["apertureAudit"].update({"clearApertureBounds": {"xMin": -8.0, "xMax": 8.0, "yMin": 23.0, "yMax": 28.0, "zMin": 2.0, "zMax": 22.0}}),
        "aperture_collision": lambda p: (p["eastFacadePlan"]["components"][0]["bounds"].update({"xMin": -2.0, "xMax": 2.0, "yMin": 24.0, "yMax": 26.0, "zMin": 4.0, "zMax": 8.0}), p["loweringRules"][0].update({"citySimBounds": {"xMin": 24.0, "xMax": 26.0, "yMin": 4.0, "yMax": 8.0, "zMin": -2.0, "zMax": 2.0}})),
        "nested_aperture_occluder": lambda p: add_nested(p, {"xMin": -2.0, "xMax": 2.0, "yMin": 24.0, "yMax": 26.0, "zMin": 4.0, "zMax": 8.0}, "east-v13-nested-aperture-occluder"),
        "camera_projected_occluder": lambda p: add_nested(p, {"xMin": 3.0, "xMax": 7.0, "yMin": 31.0, "yMax": 35.0, "zMin": 14.0, "zMax": 19.0}, "east-v13-camera-projected-occluder"),
        "nested_without_lowering_rule": lambda p: add_nested(p, {"xMin": -6.0, "xMax": -4.0, "yMin": 2.0, "yMax": 4.0, "zMin": 2.0, "zMax": 4.0}, "east-v13-unlowered-nested-solid", include_rule=False),
        "nested_without_audit_row": lambda p: add_nested(p, {"xMin": -6.0, "xMax": -4.0, "yMin": 2.0, "yMax": 4.0, "zMin": 2.0, "zMax": 4.0}, "east-v13-unaudited-nested-solid", include_audit=False),
        "coherent_west_aperture_relocation": relocate_west,
        "crown_collapse": lambda p: (p["eastFacadePlan"]["components"][9]["bounds"].update(copy.deepcopy(p["eastFacadePlan"]["components"][8]["bounds"])), p["loweringRules"][9].update({"citySimBounds": copy.deepcopy(p["loweringRules"][8]["citySimBounds"])})),
        "near_identical_crown_envelopes": near_identical_crown,
        "empty_changed_paths": lambda p: p["changedPathAudit"].update({"changedPaths": []}),
        "wrong_known_material_membership": lambda p: (p["eastFacadePlan"]["components"][0].update({"materialRole": "dark-painted-steel"}), p["loweringRules"][0].update({"sourceRole": "dark-painted-steel"})),
        "duplicate_raw_geometry": duplicate_raw_geometry,
        "structural_alias": lambda p: p["eastFacadePlan"]["components"][0].update({"id": "east-monumental-portal-inset"}),
        "path_escape": lambda p: p["changedPathAudit"].update({"changedPaths": ["../PLAY-080/foreign.json"]}),
    }
    expected_codes = {
        "forged_source_revision": "source_revision_binding", "forged_geometry_origin": "geometry_origin_binding",
        "forged_claim_path": "claim_binding", "forged_semantic_authority_path": "semantic_input_binding",
        "forged_semantic_material_path": "semantic_input_binding", "forged_east_scene_path": "east_scene_binding",
        "missing_source_ready": "source_ready_boundary", "contradictory_source_ready": "source_ready_boundary",
        "duplicate_source_ready_declaration": "source_ready_boundary", "missing_production_selected": "production_selection_boundary",
        "contradictory_production_selected": "production_selection_boundary", "duplicate_production_selected_declaration": "production_selection_boundary",
        "missing_portal": "missing_portal", "unresolved_material": "unresolved_material", "target_collapse": "target_collapse",
        "camera_drift": "camera_drift", "yaw_drift": "camera_drift", "elevation_drift": "camera_drift",
        "inflated_literal_metric": "inflated_literal_metric", "relocated_aperture": "aperture_relocated",
        "missing_occupied_envelope": "occupied_envelope_missing", "undersized_occupied_width": "occupied_envelope_stale",
        "undersized_occupied_height": "occupied_envelope_stale", "stale_occupied_envelope": "occupied_envelope_stale",
        "aperture_collision": "aperture_collision", "nested_aperture_occluder": "aperture_collision",
        "camera_projected_occluder": "camera_projected_occlusion", "coherent_west_aperture_relocation": "east_aperture_placement",
        "nested_without_lowering_rule": "lowering_coverage", "nested_without_audit_row": "aperture_coverage",
        "crown_collapse": "crown_collapse", "near_identical_crown_envelopes": "crown_envelope_collapse",
        "empty_changed_paths": "changed_path_inventory", "wrong_known_material_membership": "component_material_binding",
        "duplicate_raw_geometry": "raw_geometry_alias", "structural_alias": "component_identity", "path_escape": "path_escape",
    }
    for name, mutate in mutations.items():
        candidate = copy.deepcopy(base)
        mutate(candidate)
        try:
            validate_packet(candidate, check_files=False)
        except AssertionError as error:
            if not str(error).startswith(expected_codes[name]):
                fail("adversary_wrong_rejection", name + ":" + str(error))
            cases.append({"case": name, "result": "REJECTED", "code": str(error).split(":", 1)[0]})
        else:
            fail("adversary_accepted", name)
    for field in ("sourceReady", "productionSelected"):
        raw = json.dumps(base)
        marker = f'"{field}": false'
        duplicate = raw.replace(marker, marker + ", " + marker, 1)
        name = f"duplicate_json_{field}"
        try:
            parse_json(duplicate)
        except AssertionError as error:
            if not str(error).startswith("duplicate_json_field"):
                fail("adversary_wrong_rejection", name + ":" + str(error))
            cases.append({"case": name, "result": "REJECTED", "code": "duplicate_json_field"})
        else:
            fail("adversary_accepted", name)
    return cases


def main() -> int:
    base = load(PACKET)
    first = validate_packet(base, check_files=True)
    adversaries = adversarial_cases(base)
    first["adversarialCases"] = [item["case"] for item in adversaries]
    first["adversarialResults"] = adversaries
    second = validate_packet(load(PACKET), check_files=True)
    second["adversarialCases"] = [item["case"] for item in adversaries]
    second["adversarialResults"] = adversaries
    first_bytes = canonical(first)
    second_bytes = canonical(second)
    if first_bytes != second_bytes: fail("non_deterministic_proof")
    result = dict(first)
    result["repeatValidation"] = {"runs": 2, "byteIdentical": True, "proofSHA256": hashlib.sha256(first_bytes).hexdigest()}
    EVIDENCE_ROOT.mkdir(parents=True, exist_ok=True)
    RESULT.write_bytes(canonical(result))
    print(f"PASS: East v13 derived lowering; camera projection; {len(adversaries)} adversarial rejects; 2 byte-identical zero-pixel runs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
