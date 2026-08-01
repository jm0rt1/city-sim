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
PACKET = ROOT / "V13-COMPATIBILITY-DESIGN.json"
EVIDENCE_ROOT = ROOT.parents[5] / "docs" / "production" / "evidence" / "PLAY-079" / "industrial-l04-east-source-v01" / "v13-compatibility-v01"
RESULT = EVIDENCE_ROOT / "V13-COMPATIBILITY-RESULT.json"
CLAIM = ROOT.parents[5] / "docs" / "production" / "claims" / "PLAY-079.world-art-east.md"
EAST_SCENE = ROOT.parent / "industrial-l04-east-predesign-v01" / "scene.json"
EAST_MATERIALS = ROOT.parent / "industrial-l04-east-predesign-v01" / "materials.json"
SEMANTIC_AUTHORITY = ROOT.parents[5] / "docs" / "production" / "evidence" / "PLAY-027" / "industrial-l04" / "l04" / "blender-north-art-v13" / "design-authority-v01" / "DESIGN-AUTHORITY.json"
SEMANTIC_MATERIALS = ROOT.parents[5] / "Native" / "CitySimNative" / "WorldArt" / "Blender" / "PLAY-027" / "industrial-l04-north-art-v13" / "DESIGN-MATERIALS.json"
BRIDGE = ROOT.parents[5] / "Native" / "CitySimNative" / "WorldArt" / "Blender" / "PLAY-027" / "industrial-l04-direction-bridge-v06" / "MAPPING-CONTRACT.json"
PARENT_CANDIDATE = "073a4d2c141ec8d7d93c98b8679d73ffe3e70c1e"
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


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def load(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AssertionError(f"not_object:{path}")
    return value


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


def expected_camera_position(camera: dict) -> list[float]:
    yaw = math.radians(camera["yawDegrees"])
    elevation = math.radians(camera["elevationDegrees"])
    horizontal = camera["distance"] * math.cos(elevation)
    return [
        camera["target"][0] + horizontal * math.cos(yaw),
        camera["target"][1] - horizontal * math.sin(yaw),
        camera["target"][2] + camera["distance"] * math.sin(elevation),
    ]


def derived_component_signature(components: list[dict]) -> str:
    payload = [{key: item[key] for key in ("id", "kind", "bounds", "semanticRole", "targetRole", "materialRole")} for item in components]
    return hashlib.sha256(canonical(payload)).hexdigest()


def validate_packet(packet: dict, check_files: bool = True) -> dict:
    if packet.get("schema") != "citysim.play-079.east-v13-compatibility-design.v1": fail("schema")
    if packet.get("task") != "PLAY-079" or packet.get("direction") != "east": fail("identity")
    if packet.get("logicalBuildingID") != "industrial_l04" or packet.get("variant") != 0: fail("logical_identity")
    if packet.get("phase") != "V13_ZERO_PIXEL_COMPATIBILITY": fail("phase")
    if packet.get("sourceAuthority") is not False or packet.get("productionSelected") is not False or packet.get("pixelRenderingAllowed") is not False: fail("authority_boundary")

    provenance = packet["provenance"]
    if provenance["siblingSceneInputs"] != []: fail("sibling_geometry_input")
    if any(provenance[key] is not False for key in ("copiedGeometry", "mirroredGeometry", "rotatedGeometry", "transformedSiblingGeometry")): fail("geometry_alias")
    if provenance["orientationTransform"] != "none": fail("orientation_transform")

    authority = packet["authority"]
    if authority["authorityCommit"] != "d010d453af87c040ac13e8b3b7280366cb5094c1" or authority["baseCommit"] != authority["authorityCommit"]: fail("authority")
    if authority["routeId"] != "quality-v1:east-v13-derived-proof-repair-r2b" or authority["routeSha256"] != "7bb3e27a97e347f368478da5fb4a2acb035ccff7dc23bc5fc54dea3632dba5a0": fail("route_binding")
    if authority["claim"]["sha256"] != "abccb0be0550e092565ecca076db717f73f45ed833fe485853338a8de1bff017": fail("claim_binding")
    if check_files:
        if sha(CLAIM) != authority["claim"]["sha256"]: fail("claim_hash")
        if sha(SEMANTIC_AUTHORITY) != authority["publishedSemanticInputs"][0]["sha256"]: fail("semantic_authority_hash")
        if sha(SEMANTIC_MATERIALS) != authority["publishedSemanticInputs"][1]["sha256"]: fail("semantic_materials_hash")
        if sha(BRIDGE) != packet["coordinateBridge"]["sha256"]: fail("bridge_hash")

    registration = packet["eastRegistration"]
    if registration["citySimFootprint"] != {"width": 72.0, "depth": 72.0}: fail("citysim_footprint")
    if registration["dccFootprint"] != {"width": 56.0, "depth": 56.0, "halfExtent": 28.0}: fail("dcc_footprint")
    if registration["citySimSocket"] != [28.0, 0.0, 0.0] or registration["sourceSocket"] != [896.0, 832.0]: fail("east_socket")
    if registration["groundPivot"] != [28.0, -28.0, 0.0] or registration["sourceGroundPivot"] != [768.0, 896.0]: fail("east_pivot")
    if registration["orientationTransform"] != "none": fail("registration_transform")
    expected_pivot = [registration["citySimSocket"][0], registration["citySimSocket"][1] - registration["dccFootprint"]["halfExtent"], registration["citySimSocket"][2]]
    if registration["groundPivot"] != expected_pivot: fail("east_pivot")

    camera = packet["camera"]
    if camera["projection"] != "orthographic" or camera["view"] != "southeast-looking-northwest": fail("camera_kind")
    if camera["target"] != [0.0, 0.0, 22.861902498201186] or camera["distance"] != 420.0: fail("camera_drift")
    if any(not math.isclose(actual, expected, rel_tol=0, abs_tol=1e-9) for actual, expected in zip(camera["position"], expected_camera_position(camera))): fail("camera_drift")
    if camera["yawDegrees"] != 45.0 or camera["elevationDegrees"] != 30.0: fail("camera_drift")
    if camera["shift"] != [0.0, 0.08333333333333333] or camera.get("derivedFromBridge") is not True: fail("camera_drift")
    if camera["resolution"] != [1536, 1024] or camera["literalResolution"] != [192, 128]: fail("camera_resolution")
    if camera["orthoScale"] != 237.5878601074218: fail("camera_drift")
    if check_files:
        east_scene = load(EAST_SCENE)
        east_materials = load(EAST_MATERIALS)
        if camera["orthoScale"] != east_scene["camera"]["orthoScale"] or camera["shift"] != [east_scene["camera"]["shiftX"], east_scene["camera"]["shiftY"]] or camera["distance"] != east_scene["camera"]["distance"]: fail("camera_drift")
        if camera["literalResolution"] != east_scene["camera"]["literalResolution"]: fail("camera_literal_drift")
        scene_registration = east_scene["registration"]
        if registration["citySimFootprint"] != scene_registration["citySimFootprint"] or registration["dccFootprint"]["width"] != scene_registration["dccFootprint"]["width"] or registration["dccFootprint"]["depth"] != scene_registration["dccFootprint"]["depth"]: fail("east_registration")
        if registration["citySimSocket"] != scene_registration["frontageSocket"] or registration["groundPivot"] != scene_registration["groundPivot"]: fail("east_registration")
        if registration["sourceSocket"] != scene_registration["expectedSourcePixels"]["frontageSocket"] or registration["sourceGroundPivot"] != scene_registration["expectedSourcePixels"]["groundPivot"]: fail("east_registration")
    else:
        east_materials = load(EAST_MATERIALS)

    bridge = packet["coordinateBridge"]
    if bridge["formula"] != "B(CitySim[x,y,z])=Blender[z,x,y]" or bridge["matrixRows"] != [[0, 0, 1], [1, 0, 0], [0, 1, 0]]: fail("bridge_formula")
    if bridge["determinant"] != 1 or bridge["perDirectionTransforms"] is not False or bridge["windingChange"] is not False: fail("bridge_transform")
    if bridge["eastSocketBlender"] != [0.0, 28.0, 0.0] or bridge["eastOutwardBlender"] != [0.0, 1.0, 0.0]: fail("bridge_east_socket")
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
    if plan["roadFacing"] != "east" or len(ids) != len(set(ids)): fail("portal_identity")
    if any(not item["id"].startswith("east-v13-") for item in components): fail("structural_alias")
    if any(item.get("semanticRole") not in mapping or item.get("targetRole") != item.get("semanticRole") or item.get("materialRole") not in existing_roles for item in components): fail("unresolved_material")
    for item in components:
        bounds = item["bounds"]
        if not (-28.0 <= bounds["xMin"] <= bounds["xMax"] <= 28.0 and -28.0 <= bounds["yMin"] <= bounds["yMax"] <= 28.0 and 0.0 <= bounds["zMin"] <= bounds["zMax"]): fail("component_bounds", item["id"])

    rules = packet["loweringRules"]
    if len(rules) != len(components) or {rule["componentId"] for rule in rules} != set(ids): fail("lowering_coverage")
    by_id = {item["id"]: item for item in components}
    for rule in rules:
        item = by_id[rule["componentId"]]
        if rule["semanticRole"] != item["semanticRole"] or rule["targetRole"] != item["targetRole"] or rule["sourceRole"] != item["materialRole"]: fail("unresolved_material", rule["componentId"])
        if rule["targetRole"] not in semantic_roles or rule["sourceRole"] not in existing_roles: fail("unresolved_material", rule["componentId"])
        if city_to_blender(rule["citySimBounds"]) != item["bounds"]: fail("lowering_projection", rule["componentId"])
    if len({item["targetRole"] for item in components}) != 12 or len({rule["targetRole"] for rule in rules}) != 12: fail("target_role_injective")

    portal = plan["portal"]
    if not isinstance(portal, dict): fail("missing_portal")
    if portal["apertureComponentID"] not in by_id or portal["apertureComponentID"] != "east-v13-deep-freight-void": fail("aperture_relocated")
    if packet["apertureAudit"]["clearApertureBounds"] != by_id[portal["apertureComponentID"]]["bounds"]: fail("aperture_relocated")
    if set(portal["jambComponentIDs"]) != {"east-v13-portal-south-jamb", "east-v13-portal-north-jamb"} or portal["headerComponentID"] != "east-v13-portal-header": fail("missing_portal")
    if portal["freightBeatCount"] != 3 or portal["minimumProcessOccluders"] != 0 or portal["apronTerminatesAtSocket"] is not True: fail("portal_requirements")
    if portal["clearInsetWidthWorld"] < 14.0 or portal["clearInsetHeightWorld"] < 12.0 or portal["jambThicknessWorld"] < 3.0 or portal["headerThicknessWorld"] < 3.0: fail("portal_literal_targets")
    crown_ids = plan["silhouette"]["crownComponentIDs"]
    crown_spans = {tuple((by_id[item]["bounds"]["zMin"], by_id[item]["bounds"]["zMax"])) for item in crown_ids}
    derived_break_count = len({by_id[item]["bounds"]["zMin"] for item in crown_ids})
    if len(crown_ids) != 3 or len(crown_spans) != 3 or plan["silhouette"]["distinctRoofHeightBreaks"] != derived_break_count or derived_break_count < 3: fail("crown_collapse" if len(crown_spans) != 3 else "silhouette_breaks")

    measured = packet["measuredLiteral192"]
    portal_projection = projected_bounds(union_bounds([by_id[item]["bounds"] for item in portal["jambComponentIDs"] + [portal["headerComponentID"], portal["apertureComponentID"]]]), camera)
    void_projection = projected_bounds(by_id[portal["apertureComponentID"]]["bounds"], camera)
    crown_projection = projected_bounds(union_bounds([by_id[item]["bounds"] for item in crown_ids]), camera)
    crown_band_heights = [projected_bounds(by_id[item]["bounds"], camera)["height"] for item in crown_ids]
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
    if measured["portalBoundsPixels"]["outerWidth"] < 20 or measured["portalBoundsPixels"]["outerHeight"] < 18 or measured["portalBoundsPixels"]["clearInsetWidth"] < 14 or measured["portalBoundsPixels"]["clearInsetHeight"] < 12: fail("literal_portal_bounds")
    if measured["crownBoundsPixels"]["width"] < 20 or len(measured["crownBoundsPixels"]["heightBreaks"]) != 3: fail("literal_crown_bounds")
    apron = by_id["east-v13-operating-apron"]["bounds"]
    socket_gap_world = max(0.0, registration["citySimSocket"][0] - apron["xMax"])
    expected_socket_gap = socket_gap_world * camera["literalResolution"][0] / camera["resolution"][0]
    if measured["processOccluderCount"] != 0 or not math.isclose(measured["socketApronGapPixels"], expected_socket_gap, rel_tol=0, abs_tol=0.001) or measured["socketApronGapPixels"] > 2: fail("literal_occlusion")

    aperture = packet["apertureAudit"]["clearApertureBounds"]
    void_id = "east-v13-deep-freight-void"
    non_void = [item for item in components if item["id"] != void_id]
    audit = packet["apertureAudit"]["auditedComponents"]
    if packet["apertureAudit"]["nonApertureSolidCount"] != len(non_void) or {item["componentId"] for item in audit} != {item["id"] for item in non_void}: fail("aperture_coverage")
    for item in non_void:
        if overlap(item["bounds"], aperture) > 0: fail("aperture_collision", item["id"])
    if packet["apertureAudit"]["allIntrusions"] is not False or any(item["intrudes"] or item["overlapAreaWorld2"] != 0.0 for item in audit): fail("aperture_collision")

    alias = packet["nonAliasProof"]
    expected_signature = "east-v13-portal-crown::foundation-apron-hall-jamb-jamb-header-void-crown-crown-crown-hot-stack-annex"
    if alias["structuralSignature"] != expected_signature or alias["derivedComponentSignatureSHA256"] != derived_component_signature(components) or alias["targetCollapse"] is not False or alias["siblingInputsConsumed"] != []: fail("structural_alias")
    if any(old_id in ids for old_id in alias["priorEastRevisionComponentIDs"]): fail("structural_alias")

    changed = packet["changedPathAudit"]
    if changed["parentCandidate"] != PARENT_CANDIDATE or changed["siblingInputsConsumed"] != []: fail("path_escape")
    allowed = ("Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/", "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v13-compatibility-v01/")
    if not changed["changedPaths"]: fail("changed_path_inventory")
    if not changed["allWithinAllowedRoots"] or any(".." in path or not path.startswith(allowed) for path in changed["changedPaths"]): fail("path_escape")
    committed_paths = subprocess.check_output(["git", "diff", "--name-only", PARENT_CANDIDATE, "HEAD"], cwd=REPO_ROOT, text=True).splitlines()
    working_paths = subprocess.check_output(["git", "diff", "--name-only", PARENT_CANDIDATE], cwd=REPO_ROOT, text=True).splitlines()
    expected_paths = set(committed_paths) | set(working_paths)
    expected_paths.add(RESULT.relative_to(REPO_ROOT).as_posix())
    if set(changed["changedPaths"]) != expected_paths: fail("changed_path_inventory")

    boundary = packet["zeroPixelBoundary"]
    if any(boundary[key] != 0 for key in ("blenderInvocations", "dccInvocations", "renderInvocations", "pixelFilesCreated", "normalizationRuns", "sourcePacketsCreated")): fail("pixel_boundary")
    if boundary["candidateReadyForIndependentReview"] is not True or boundary["independentReviewRequired"] is not True: fail("review_boundary")

    return {
        "schema": "citysim.play-079.east-v13-compatibility-proof.v2",
        "task": "PLAY-079", "direction": "east", "phase": "V13_ZERO_PIXEL_COMPATIBILITY", "result": "PASS",
        "logicalBuildingID": packet["logicalBuildingID"], "variant": packet["variant"],
        "authority": {"commit": packet["authority"]["authorityCommit"], "routeId": packet["authority"]["routeId"], "routeSha256": packet["authority"]["routeSha256"], "dispatchReceipt": packet["authority"]["dispatchReceipt"]},
        "checks": {"routeAndAuthority": "PASS", "bridgeAndLowering": "PASS", "eastSocketAndPivot": "PASS", "cameraAndLiteral192": "PASS", "portalAndSilhouette": "PASS", "materialResolution": "PASS", "apertureAudit": "PASS", "nonAlias": "PASS", "pathIsolation": "PASS"},
        "socket": {"citySim": registration["citySimSocket"], "blender": bridge["eastSocketBlender"], "source": registration["sourceSocket"]},
        "literal192": measured, "componentCount": len(components), "loweringRuleCount": len(rules), "silhouetteBreakCount": plan["silhouette"]["distinctRoofHeightBreaks"],
        "changedPaths": changed["changedPaths"], "apertureAudit": packet["apertureAudit"],
        "materialRoleCount": len(mapping), "adversarialCases": ["missing_portal", "unresolved_material", "target_collapse", "camera_drift", "yaw_drift", "elevation_drift", "inflated_literal_metric", "relocated_aperture", "aperture_collision", "crown_collapse", "empty_changed_paths", "wrong_known_material_role", "structural_alias", "path_escape"],
        "siblingSceneInputs": [], "renderInvocations": 0, "imagesWritten": 0, "sourceAuthority": False, "productionSelected": False,
        "sourceHashes": {"packetSHA256": sha(PACKET), "eastSceneSHA256": sha(EAST_SCENE), "eastMaterialsSHA256": sha(EAST_MATERIALS), "claimSHA256": sha(CLAIM), "semanticAuthoritySHA256": sha(SEMANTIC_AUTHORITY), "semanticMaterialsSHA256": sha(SEMANTIC_MATERIALS), "bridgeSHA256": sha(BRIDGE)},
    }


def adversarial_cases(base: dict) -> list[dict[str, str]]:
    cases = []
    mutations = {
        "missing_portal": lambda p: p["eastFacadePlan"].update({"portal": None}),
        "unresolved_material": lambda p: p["eastFacadePlan"]["components"][0].update({"semanticRole": "missing-role"}),
        "target_collapse": lambda p: p["lowering"].update({"targetCollapse": True}),
        "camera_drift": lambda p: p["camera"].update({"orthoScale": 1.0}),
        "yaw_drift": lambda p: p["camera"].update({"yawDegrees": 44.0}),
        "elevation_drift": lambda p: p["camera"].update({"elevationDegrees": 29.0}),
        "inflated_literal_metric": lambda p: p["measuredLiteral192"]["portalBoundsPixels"].update({"outerWidth": 999.0}),
        "relocated_aperture": lambda p: p["apertureAudit"].update({"clearApertureBounds": {"xMin": 20.0, "xMax": 25.0, "yMin": -11.0, "yMax": 11.0, "zMin": 2.0, "zMax": 22.0}}),
        "aperture_collision": lambda p: (p["eastFacadePlan"]["components"][0]["bounds"].update({"xMin": 24.0, "xMax": 26.0, "yMin": -2.0, "yMax": 2.0, "zMin": 4.0, "zMax": 8.0}), p["loweringRules"][0].update({"citySimBounds": {"xMin": -2.0, "xMax": 2.0, "yMin": 4.0, "yMax": 8.0, "zMin": 24.0, "zMax": 26.0}})),
        "crown_collapse": lambda p: (p["eastFacadePlan"]["components"][9]["bounds"].update(copy.deepcopy(p["eastFacadePlan"]["components"][8]["bounds"])), p["loweringRules"][9].update({"citySimBounds": copy.deepcopy(p["loweringRules"][8]["citySimBounds"])})),
        "empty_changed_paths": lambda p: p["changedPathAudit"].update({"changedPaths": []}),
        "wrong_known_material_role": lambda p: (p["eastFacadePlan"]["components"][0].update({"materialRole": "dark-painted-steel"}), p["loweringRules"][0].update({"sourceRole": "dark-painted-steel"}), p["sourceRoleMapping"].update({"v13-grounded-foundation": "dark-painted-steel"})),
        "structural_alias": lambda p: p["eastFacadePlan"]["components"][0].update({"id": "east-monumental-portal-inset"}),
        "path_escape": lambda p: p["changedPathAudit"].update({"changedPaths": ["../PLAY-080/foreign.json"]}),
    }
    expected_codes = {
        "missing_portal": "missing_portal", "unresolved_material": "unresolved_material", "target_collapse": "target_collapse",
        "camera_drift": "camera_drift", "yaw_drift": "camera_drift", "elevation_drift": "camera_drift",
        "inflated_literal_metric": "inflated_literal_metric", "relocated_aperture": "aperture_relocated",
        "aperture_collision": "aperture_collision", "crown_collapse": "crown_collapse", "empty_changed_paths": "changed_path_inventory",
        "wrong_known_material_role": "source_material_mapping", "structural_alias": "structural_alias", "path_escape": "path_escape",
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
    return cases


def main() -> int:
    base = load(PACKET)
    first = validate_packet(base, check_files=True)
    adversaries = adversarial_cases(base)
    first["adversarialResults"] = adversaries
    second = validate_packet(load(PACKET), check_files=True)
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
