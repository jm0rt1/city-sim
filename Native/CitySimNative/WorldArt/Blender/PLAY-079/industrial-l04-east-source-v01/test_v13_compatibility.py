#!/usr/bin/env python3
"""Validate East v13 pure-data lowering, projection, and adversarial proof."""

from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PACKET = ROOT / "V13-COMPATIBILITY-DESIGN.json"
EVIDENCE_ROOT = ROOT.parents[5] / "docs" / "production" / "evidence" / "PLAY-079" / "industrial-l04-east-source-v01" / "v13-compatibility-v01"
RESULT = EVIDENCE_ROOT / "V13-COMPATIBILITY-RESULT.json"
CLAIM = ROOT.parents[5] / "docs" / "production" / "claims" / "PLAY-079.world-art-east.md"
EAST_SCENE = ROOT.parent / "industrial-l04-east-predesign-v01" / "scene.json"
EAST_MATERIALS = ROOT.parent / "industrial-l04-east-predesign-v01" / "materials.json"
SEMANTIC_AUTHORITY = ROOT.parents[5] / "docs" / "production" / "evidence" / "PLAY-027" / "industrial-l04" / "l04" / "blender-north-art-v13" / "design-authority-v01" / "DESIGN-AUTHORITY.json"
SEMANTIC_MATERIALS = ROOT.parents[5] / "Native" / "CitySimNative" / "WorldArt" / "Blender" / "PLAY-027" / "industrial-l04-north-art-v13" / "DESIGN-MATERIALS.json"
BRIDGE = ROOT.parents[5] / "Native" / "CitySimNative" / "WorldArt" / "Blender" / "PLAY-027" / "industrial-l04-direction-bridge-v06" / "MAPPING-CONTRACT.json"


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
    if authority["routeId"] != "quality-v1:east-v13-proof-repair" or authority["routeSha256"] != "99481b7ae4bfb254a8a01f909650641a482c2122b02712eaa81e9d2cd27633d2": fail("route_binding")
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

    camera = packet["camera"]
    if camera["projection"] != "orthographic" or camera["view"] != "southeast-looking-northwest": fail("camera_kind")
    if camera["resolution"] != [1536, 1024] or camera["literalResolution"] != [192, 128]: fail("camera_resolution")
    if camera["orthoScale"] != 237.5878601074218: fail("camera_drift")
    if check_files:
        east_scene = load(EAST_SCENE)
        east_materials = load(EAST_MATERIALS)
        if camera["orthoScale"] != east_scene["camera"]["orthoScale"] or camera["shift"] != [east_scene["camera"]["shiftX"], east_scene["camera"]["shiftY"]]: fail("camera_drift")
        if camera["literalResolution"] != east_scene["camera"]["literalResolution"]: fail("camera_literal_drift")
    else:
        east_materials = load(EAST_MATERIALS)

    bridge = packet["coordinateBridge"]
    if bridge["formula"] != "B(CitySim[x,y,z])=Blender[z,x,y]" or bridge["matrixRows"] != [[0, 0, 1], [1, 0, 0], [0, 1, 0]]: fail("bridge_formula")
    if bridge["determinant"] != 1 or bridge["perDirectionTransforms"] is not False or bridge["windingChange"] is not False: fail("bridge_transform")
    if bridge["eastSocketBlender"] != [0.0, 28.0, 0.0] or bridge["eastOutwardBlender"] != [0.0, 1.0, 0.0]: fail("bridge_east_socket")
    projection = packet["lowering"]["cameraProjection"]
    if packet["lowering"]["targetCollapse"] is not False or packet["lowering"]["unresolvedComponents"] or packet["lowering"]["fallbackRoles"]: fail("target_collapse")
    if not math.isclose(projection["sourcePixelsPerWorldUnit"][0], 1536.0 / packet["camera"]["orthoScale"], rel_tol=0, abs_tol=0.001): fail("projection_x")
    if not math.isclose(projection["sourcePixelsPerWorldUnit"][1], 1024.0 / packet["camera"]["orthoScale"], rel_tol=0, abs_tol=0.001): fail("projection_y")

    semantic_materials = load(SEMANTIC_MATERIALS)
    semantic_roles = {item["id"] for item in semantic_materials["materials"]}
    mapping = packet["materialRoleMapping"]
    existing_roles = {item["id"] for item in east_materials["roles"]}
    if set(mapping) != semantic_roles or set(mapping.values()) != existing_roles: fail("material_mapping")

    plan = packet["eastFacadePlan"]
    components = plan["components"]
    ids = [item["id"] for item in components]
    if plan["roadFacing"] != "east" or len(ids) != len(set(ids)): fail("portal_identity")
    if any(not item["id"].startswith("east-v13-") for item in components): fail("structural_alias")
    if any(item.get("semanticRole") not in mapping for item in components): fail("unresolved_material")
    for item in components:
        bounds = item["bounds"]
        if not (-28.0 <= bounds["xMin"] <= bounds["xMax"] <= 28.0 and -28.0 <= bounds["yMin"] <= bounds["yMax"] <= 28.0 and 0.0 <= bounds["zMin"] <= bounds["zMax"]): fail("component_bounds", item["id"])

    rules = packet["loweringRules"]
    if len(rules) != len(components) or {rule["componentId"] for rule in rules} != set(ids): fail("lowering_coverage")
    by_id = {item["id"]: item for item in components}
    for rule in rules:
        item = by_id[rule["componentId"]]
        if rule["semanticRole"] != item["semanticRole"] or rule["targetRole"] != item["materialRole"]: fail("unresolved_material", rule["componentId"])
        if rule["targetRole"] not in existing_roles or rule["semanticRole"] not in semantic_roles: fail("unresolved_material", rule["componentId"])
        if city_to_blender(rule["citySimBounds"]) != item["bounds"]: fail("lowering_projection", rule["componentId"])

    portal = plan["portal"]
    if not isinstance(portal, dict): fail("missing_portal")
    if portal["freightBeatCount"] != 3 or portal["minimumProcessOccluders"] != 0 or portal["apronTerminatesAtSocket"] is not True: fail("portal_requirements")
    if portal["clearInsetWidthWorld"] < 14.0 or portal["clearInsetHeightWorld"] < 12.0 or portal["jambThicknessWorld"] < 3.0 or portal["headerThicknessWorld"] < 3.0: fail("portal_literal_targets")
    if plan["silhouette"]["distinctRoofHeightBreaks"] < 3: fail("silhouette_breaks")

    measured = packet["measuredLiteral192"]
    if measured["portalBoundsPixels"]["outerWidth"] < 20 or measured["portalBoundsPixels"]["outerHeight"] < 18 or measured["portalBoundsPixels"]["clearInsetWidth"] < 14 or measured["portalBoundsPixels"]["clearInsetHeight"] < 12: fail("literal_portal_bounds")
    if measured["crownBoundsPixels"]["width"] < 20 or len(measured["crownBoundsPixels"]["heightBreaks"]) != 3: fail("literal_crown_bounds")
    if measured["processOccluderCount"] != 0 or measured["socketApronGapPixels"] > 2: fail("literal_occlusion")

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
    if alias["structuralSignature"] != expected_signature or alias["targetCollapse"] is not False or alias["siblingInputsConsumed"] != []: fail("structural_alias")
    if any(old_id in ids for old_id in alias["priorEastRevisionComponentIDs"]): fail("structural_alias")

    changed = packet["changedPathAudit"]
    if changed["parentCandidate"] != "cafc6178856ede400af19927a2fdf3f1bfdb8bf4" or changed["siblingInputsConsumed"] != []: fail("path_escape")
    allowed = ("Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/", "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v13-compatibility-v01/")
    if not changed["allWithinAllowedRoots"] or any(".." in path or not path.startswith(allowed) for path in changed["changedPaths"]): fail("path_escape")

    boundary = packet["zeroPixelBoundary"]
    if any(boundary[key] != 0 for key in ("blenderInvocations", "dccInvocations", "renderInvocations", "pixelFilesCreated", "normalizationRuns", "sourcePacketsCreated")): fail("pixel_boundary")
    if boundary["candidateReadyForIndependentReview"] is not True or boundary["independentReviewRequired"] is not True: fail("review_boundary")

    return {
        "schema": "citysim.play-079.east-v13-compatibility-proof.v2",
        "task": "PLAY-079", "direction": "east", "phase": "V13_ZERO_PIXEL_COMPATIBILITY", "result": "PASS",
        "logicalBuildingID": packet["logicalBuildingID"], "variant": packet["variant"],
        "authority": {"commit": packet["authority"]["authorityCommit"], "routeId": packet["authority"]["routeId"], "routeSha256": packet["authority"]["routeSha256"]},
        "checks": {"routeAndAuthority": "PASS", "bridgeAndLowering": "PASS", "eastSocketAndPivot": "PASS", "cameraAndLiteral192": "PASS", "portalAndSilhouette": "PASS", "materialResolution": "PASS", "apertureAudit": "PASS", "nonAlias": "PASS", "pathIsolation": "PASS"},
        "socket": {"citySim": registration["citySimSocket"], "blender": bridge["eastSocketBlender"], "source": registration["sourceSocket"]},
        "literal192": measured, "componentCount": len(components), "loweringRuleCount": len(rules), "silhouetteBreakCount": plan["silhouette"]["distinctRoofHeightBreaks"],
        "changedPaths": changed["changedPaths"], "apertureAudit": packet["apertureAudit"],
        "materialRoleCount": len(mapping), "adversarialCases": ["missing_portal", "unresolved_material", "target_collapse", "camera_drift", "aperture_collision", "structural_alias", "path_escape"],
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
        "aperture_collision": lambda p: (p["eastFacadePlan"]["components"][0]["bounds"].update({"xMin": 24.0, "xMax": 26.0, "yMin": -2.0, "yMax": 2.0, "zMin": 4.0, "zMax": 8.0}), p["loweringRules"][0].update({"citySimBounds": {"xMin": -2.0, "xMax": 2.0, "yMin": 4.0, "yMax": 8.0, "zMin": 24.0, "zMax": 26.0}})),
        "structural_alias": lambda p: p["eastFacadePlan"]["components"][0].update({"id": "east-monumental-portal-inset"}),
        "path_escape": lambda p: p["changedPathAudit"].update({"changedPaths": ["../PLAY-080/foreign.json"]}),
    }
    for name, mutate in mutations.items():
        candidate = copy.deepcopy(base)
        mutate(candidate)
        try:
            validate_packet(candidate, check_files=False)
        except AssertionError as error:
            if not str(error).startswith(name.split("_")[0]) and name not in str(error):
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
    print("PASS: East v13 derived lowering; camera projection; 7 adversarial rejects; 2 byte-identical zero-pixel runs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
