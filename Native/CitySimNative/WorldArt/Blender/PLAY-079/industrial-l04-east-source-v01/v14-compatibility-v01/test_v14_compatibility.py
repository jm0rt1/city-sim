#!/usr/bin/env python3
"""East v14 zero-pixel compatibility and prelock proof."""

from __future__ import annotations

import copy
import hashlib
import json
import math
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[6]
PACKET = ROOT / "V14-COMPATIBILITY-DESIGN.json"
EVIDENCE = REPO / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01"
HANDOFF = EVIDENCE / "HANDOFF.json"
VALIDATION = EVIDENCE / "VALIDATION.json"
PARENT = "fef6e902aca9d3a17bdd9af41f64588c2e8115c3"
CLAIM = REPO / "docs/production/claims/PLAY-079.world-art-east.md"
SCENE = REPO / "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-predesign-v01/scene.json"
MATERIALS = REPO / "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-predesign-v01/materials.json"
EXPECTED_PATHS = {
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/V14-COMPATIBILITY-DESIGN.json",
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/test_v14_compatibility.py",
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/HANDOFF.json",
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/VALIDATION.json",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canon(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def fail(code: str, detail: str = "") -> None:
    raise AssertionError(code + ((":" + detail) if detail else ""))


def normalize(v: list[float]) -> list[float]:
    n = math.sqrt(sum(x * x for x in v))
    return [x / n for x in v]


def sub(a: list[float], b: list[float]) -> list[float]:
    return [x - y for x, y in zip(a, b)]


def dot(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def cross(a: list[float], b: list[float]) -> list[float]:
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def project(bounds: dict, camera: dict) -> dict:
    forward = normalize(sub(camera["target"], camera["position"]))
    right = normalize(cross(forward, [0.0, 0.0, 1.0]))
    up = cross(right, forward)
    points = []
    for x in (bounds["xMin"], bounds["xMax"]):
        for y in (bounds["yMin"], bounds["yMax"]):
            for z in (bounds["zMin"], bounds["zMax"]):
                delta = sub([x, y, z], camera["target"])
                points.append((192 * (0.5 + dot(delta, right) / camera["orthoScale"]), 128 * (0.5 - dot(delta, up) / camera["orthoScale"]) + camera["shift"][1] * 128))
    xs, ys = zip(*points)
    return {"minX": min(xs), "maxX": max(xs), "minY": min(ys), "maxY": max(ys), "width": max(xs) - min(xs), "height": max(ys) - min(ys)}


def union(items: list[dict]) -> dict:
    return {key: (min(item[key] for item in items) if key.endswith("Min") else max(item[key] for item in items)) for key in ("xMin", "xMax", "yMin", "yMax", "zMin", "zMax")}


def overlap(a: dict, b: dict) -> float:
    return max(0.0, min(a["xMax"], b["xMax"]) - max(a["xMin"], b["xMin"])) * max(0.0, min(a["yMax"], b["yMax"]) - max(a["yMin"], b["yMin"])) * max(0.0, min(a["zMax"], b["zMax"]) - max(a["zMin"], b["zMin"]))


def moving_interval(center: float, half_width: float, direction: float, low: float, high: float) -> tuple[float, float]:
    other_center = (low + high) / 2.0
    combined_half_width = half_width + (high - low) / 2.0
    if abs(direction) < 1e-12:
        return (-float("inf"), float("inf")) if abs(center - other_center) < combined_half_width else (1.0, 0.0)
    endpoints = ((other_center - center - combined_half_width) / direction, (other_center - center + combined_half_width) / direction)
    return min(endpoints), max(endpoints)


def camera_occludes(bounds: dict, aperture: dict, camera: dict) -> bool:
    direction = normalize(sub(camera["position"], camera["target"]))
    intervals = [
        moving_interval((aperture["xMin"] + aperture["xMax"]) / 2.0, (aperture["xMax"] - aperture["xMin"]) / 2.0, direction[0], bounds["xMin"], bounds["xMax"]),
        moving_interval(aperture["yMax"], 0.0, direction[1], bounds["yMin"], bounds["yMax"]),
        moving_interval((aperture["zMin"] + aperture["zMax"]) / 2.0, (aperture["zMax"] - aperture["zMin"]) / 2.0, direction[2], bounds["zMin"], bounds["zMax"]),
    ]
    near = max(1e-6, *(item[0] for item in intervals))
    return near < min(item[1] for item in intervals)


def validate(packet: dict, check_files: bool = True) -> dict:
    if packet.get("schema") != "citysim.play-079.east-v14-compatibility-design.v1": fail("schema")
    if (packet.get("task"), packet.get("direction"), packet.get("family"), packet.get("familyRevision")) != ("PLAY-079", "east", "industrial_l04", "v14"): fail("identity")
    if packet.get("phase") != "V14_ZERO_PIXEL_COMPATIBILITY" or packet.get("sourceRevision") != "east-v14-compatibility-v1": fail("phase_revision")
    if packet.get("sourceAuthority") is not False or packet.get("sourceReady") is not False or packet.get("productionSelected") is not False or packet.get("pixelRenderingAllowed") is not False: fail("readiness_boundary")
    provenance = packet["provenance"]
    if provenance["siblingInputsConsumed"] != [] or provenance["orientationTransform"] != "none" or any(provenance[key] is not False for key in ("copiedGeometry", "mirroredGeometry", "rotatedGeometry", "tracedGeometry", "transformedSiblingGeometry")): fail("sibling_or_transform")
    authority = packet["authority"]
    if authority["authorityCommit"] != "1d7c6510fd99299c88d3f4412caa982e020c1941" or authority["baseCommit"] != "ea26fdac05169e0375b65d7c5dc65b4fbe00d977": fail("authority")
    if authority["dispatch"] != {"carrierCommit":"9aa5be01d72f0471538d0efd1620f1a50cb0f815","path":"docs/production/evidence/INTEGRATION/MODEL-ROUTING-INDUSTRIAL-L04-V14-PRELOCK-FANOUT-V1.json","sha256":"2b2558835d5382d15f92f58a538c5795f82d3875867e17dd686b23dc8d738e00"}: fail("dispatch_binding")
    if authority["routeId"] != "quality-v1:play-079-industrial-l04-v14-east-prelock-v1" or authority["routeSha256"] != "7b927087a66ff6312931743d404a0de776a3418173d52f8d65be09841b43e4da": fail("route_binding")
    if authority["claim"] != {"path":"docs/production/claims/PLAY-079.world-art-east.md","sha256":"93bcc57e69bc4cd1ff492ce0dfbf5d6244c3782db524e7e16fc0d9dd78431a77"}: fail("claim_binding")
    if authority["familyAuthority"] != {"path":"docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-NORTH-V14-HERO-REBUILD-AUTHORITY-V1.md","sha256":"e439d9f8de08474bbaf31c2308491dad486ec953bf45605c043731f68b44edbb"}: fail("family_authority_binding")
    if check_files and (sha(CLAIM) != authority["claim"]["sha256"] or sha(SCENE) != packet["sourceBindings"]["eastScene"]["sha256"] or sha(MATERIALS) != packet["sourceBindings"]["eastMaterials"]["sha256"]): fail("input_hash")
    registration = packet["eastRegistration"]
    if registration["citySimFootprint"] != {"width":72.0,"depth":72.0} or registration["dccFootprint"] != {"width":56.0,"depth":56.0,"halfExtent":28.0}: fail("footprint")
    if registration["citySimSocket"] != [28.0,0.0,0.0] or registration["sourceSocket"] != [896.0,832.0] or registration["groundPivot"] != [28.0,28.0,0.0] or registration["sourceGroundPivot"] != [768.0,896.0] or registration["orientationTransform"] != "none": fail("socket_pivot")
    camera = packet["camera"]
    if camera["projection"] != "orthographic" or camera["view"] != "southeast-looking-northwest" or camera["position"] != [96.0,96.0,101.24557426726288] or camera["target"] != [0.0,0.0,22.861902498201186] or camera["literalResolution"] != [192,128] or camera["resolution"] != [1536,1024] or camera["orthoScale"] != 237.5878601074218 or camera["shift"] != [0.0,0.08333333333333333]: fail("camera")
    bridge = packet["coordinateBridge"]
    if bridge["formula"] != "B(CitySim[x,y,z])=Blender[z,x,y]" or bridge["matrixRows"] != [[0,0,1],[1,0,0],[0,1,0]] or bridge["eastSocketBlender"] != [0.0,28.0,0.0] or bridge["eastOutwardBlender"] != [0.0,1.0,0.0] or bridge["perDirectionTransforms"] is not False: fail("bridge")
    mapping = packet["materialRoleMapping"]
    if len(mapping) != 9 or len(set(mapping.values())) != 9: fail("material_roles")
    components = packet["components"]
    by_id = {item["id"]: item for item in components}
    if len(components) != 16 or len(by_id) != len(components) or any(not item["id"].startswith("east-v14-") for item in components): fail("component_coverage")
    for item in components:
        b = item["bounds"]
        if item["semanticRole"] not in mapping or item["materialRole"] != mapping[item["semanticRole"]]: fail("material_binding", item["id"])
        if not (-28 <= b["xMin"] <= b["xMax"] <= 28 and -28 <= b["yMin"] <= b["yMax"] <= 28 and 0 <= b["zMin"] <= b["zMax"]): fail("footprint_bounds", item["id"])
        if item["kind"] == "stack" and b["zMax"] > 44: fail("stack_height")
        if item["kind"] != "stack" and b["zMax"] > 40: fail("non_stack_height", item["id"])
    portal = packet["portal"]
    if portal["roadFacing"] != "east" or by_id[portal["socketComponent"]]["bounds"]["yMax"] != 28 or by_id[portal["apertureComponent"]]["bounds"]["yMax"] != 28: fail("portal_frontage")
    aperture = by_id[portal["apertureComponent"]]["bounds"]
    for item in components:
        if item["id"] == portal["apertureComponent"]: continue
        if overlap(item["bounds"], aperture) > 0 or camera_occludes(item["bounds"], aperture, camera): fail("portal_occlusion", item["id"])
    outer = project(union([by_id[i]["bounds"] for i in portal["jambComponents"] + [portal["headerComponent"], portal["apertureComponent"]]]), camera)
    clear = project(aperture, camera)
    envelope = project(union([item["bounds"] for item in components]), camera)
    quantized = {"minX":math.floor(envelope["minX"]),"maxX":math.ceil(envelope["maxX"]),"minY":math.floor(envelope["minY"]),"maxY":math.ceil(envelope["maxY"]),"width":math.ceil(envelope["maxX"])-math.floor(envelope["minX"]),"height":math.ceil(envelope["maxY"])-math.floor(envelope["minY"])}
    targets = packet["literal192Targets"]
    if quantized["width"] < targets["minimumOccupiedWidthPixels"] or quantized["height"] < targets["minimumOccupiedHeightPixels"] or outer["width"] < targets["minimumPortalOuterWidthPixels"] or clear["width"] < targets["minimumPortalClearWidthPixels"] or clear["height"] < targets["minimumPortalClearHeightPixels"]: fail("literal_scale")
    breaks = [project(by_id[i]["bounds"], camera)["minY"] for i in packet["silhouette"]["breakComponentIDs"]]
    if packet["silhouette"]["meaningfulBreaks"] < 5 or len(breaks) != len(set(breaks)) or any(abs(a-b) < packet["silhouette"]["minimumProjectedBreakSeparationPixels"] for a,b in zip(breaks, breaks[1:])): fail("silhouette")
    future = packet["futureProcessA"]
    if future["appearanceLock"] is not None or future["sourceProductionProfile"] is not None or future["sourceReady"] is not False or future["launchAuthorized"] is not False: fail("future_authority_boundary")
    changed = packet["changedPathAudit"]
    if changed["parentCandidate"] != PARENT or changed["siblingInputsConsumed"] != [] or set(changed["changedPaths"]) != EXPECTED_PATHS or not changed["allWithinAllowedRoots"]: fail("path_isolation")
    if any(".." in p or not (p.startswith("Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/") or p.startswith("docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/")) for p in changed["changedPaths"]): fail("path_escape")
    boundary = packet["zeroPixelBoundary"]
    if any(boundary[key] != 0 for key in ("blenderInvocations","dccInvocations","renderInvocations","pixelFilesCreated","normalizationRuns","sourcePacketsCreated")) or boundary["appearanceLockConsumed"] is not False or boundary["sourceReady"] is not False or boundary["productionSelected"] is not False: fail("zero_pixel_boundary")
    return {"schema":"citysim.play-079.east-v14-compatibility-validation.v1","task":"PLAY-079","direction":"east","family":"industrial_l04","familyRevision":"v14","result":"PASS","authority":authority,"registration":registration,"camera":camera,"literal192":{"occupiedEnvelope":envelope,"quantizedEnvelope":quantized,"portalOuter":outer,"portalClear":clear},"componentCount":len(components),"meaningfulSilhouetteBreaks":len(breaks),"futureProcessA":"blocked-until-appearance-lock-and-post-lock-grant","changedPaths":sorted(changed["changedPaths"]),"siblingInputsConsumed":[],"zeroPixel":{"blenderInvocations":0,"dccInvocations":0,"renderInvocations":0,"pixelFilesCreated":0,"normalizationRuns":0,"sourcePacketsCreated":0}}


def adversaries(base: dict) -> list[dict]:
    cases = {
        "missing_appearance_lock": lambda p: p["futureProcessA"].update({"appearanceLock": {}}),
        "wrong_socket": lambda p: p["eastRegistration"].update({"sourceSocket": [896.0,704.0]}),
        "stale_camera": lambda p: p["camera"].update({"orthoScale": 1.0}),
        "sibling_path": lambda p: p["changedPathAudit"].update({"changedPaths": ["Native/CitySimNative/WorldArt/Blender/PLAY-080/foreign.json"]}),
        "orientation_transform": lambda p: p["provenance"].update({"orientationTransform": "rotate-z-90"}),
        "undersized_envelope": lambda p: p["literal192Targets"].update({"minimumOccupiedHeightPixels": 100}),
        "portal_occluder": lambda p: p["components"][2]["bounds"].update({"yMax": 27}),
        "process_a_forged": lambda p: p["futureProcessA"].update({"sourceReady": True, "launchAuthorized": True}),
    }
    expected = {"missing_appearance_lock":"future_authority_boundary","wrong_socket":"socket_pivot","stale_camera":"camera","sibling_path":"path_isolation","orientation_transform":"sibling_or_transform","undersized_envelope":"literal_scale","portal_occluder":"portal_occlusion","process_a_forged":"future_authority_boundary"}
    out = []
    for name, mutate in cases.items():
        candidate = copy.deepcopy(base)
        mutate(candidate)
        try:
            validate(candidate, check_files=False)
        except AssertionError as error:
            if not str(error).startswith(expected[name]): fail("adversary_wrong_rejection", name + ":" + str(error))
            out.append({"case":name,"result":"REJECTED","code":str(error).split(":",1)[0]})
        else:
            fail("adversary_accepted", name)
    return out


def main() -> int:
    packet = load(PACKET)
    first = validate(packet)
    cases = adversaries(packet)
    first["adversaries"] = cases
    second = validate(load(PACKET))
    second["adversaries"] = cases
    if canon(first) != canon(second): fail("non_deterministic_validation")
    proof = hashlib.sha256(canon(first)).hexdigest()
    result = dict(first)
    result["repeatValidation"] = {"runs":2,"byteIdentical":True,"proofSHA256":proof}
    handoff = {
        "schema":"citysim.play-079.east-v14-compatibility-handoff.v1", "stage":"predesign", "task":"PLAY-079", "direction":"east", "family":"industrial_l04", "familyRevision":"v14", "branch":"codex/citysim-world-art-east", "baseCommit":PARENT,
        "claim":packet["authority"]["claim"], "sourceRevision":packet["sourceRevision"],
        "familyContract":{"path":packet["authority"]["familyAuthority"]["path"],"sha256":packet["authority"]["familyAuthority"]["sha256"],"version":"industrial-l04-v14"},
        "sceneMaterialBindings":packet["sourceBindings"], "toolchain":{"blender":"not_run","dcc":"not_run","render":"not_run"},
        "registration":packet["eastRegistration"], "camera":packet["camera"], "light":packet["light"], "portal":packet["portal"], "silhouette":packet["silhouette"],
        "directionRootMap":{"sceneRoot":"Native/CitySimNative/WorldArt/Blender/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01","evidenceRoot":"docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01","handoff":"docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/HANDOFF.json","parallelReceipt":None},
        "validationReportPaths":["docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/v14-compatibility-v01/VALIDATION.json"], "disposition":"predesign_ready", "candidateReadyForIndependentReview":True,
        "sourceReady":False, "integrationAdmitted":False, "rendererQuarantined":False, "productionSelected":False,
        "knownBlocker":"appearance lock and post-lock Process-A grant are Integration-owned and absent", "siblingInputsConsumed":[], "pixelProduction":"not_produced", "abC":"not_produced"
    }
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    VALIDATION.write_bytes(canon(result))
    HANDOFF.write_bytes(canon(handoff))
    print(f"PASS: East v14 zero-pixel compatibility; {len(cases)} adversarial rejects; 2 byte-identical validations; no DCC/pixels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
