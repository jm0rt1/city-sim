#!/usr/bin/env python3
"""West Industrial L4 v14 zero-pixel compatibility proof.

Pure JSON/analytic validation only.  No Blender, DCC, render API, ImageGen,
normalizer, or pixel file is created.  The accepted West v13 proof is replayed
as an immutable base proof; this validator only evaluates the v14 layer.
"""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import math
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[7]
SOURCE = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01"
V14 = SOURCE / "v14-compatibility-v01"
DESIGN_PATH = V14 / "WEST-V14-DESIGN.json"
LOWERING_PATH = V14 / "WEST-V14-LOWERING.json"
HANDOFF_PATH = ROOT / "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/HANDOFF.json"
VALIDATION_PATH = ROOT / "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/v14-compatibility-v01/INDEPENDENT-RETURN-REPAIR-V2.json"
BRIDGE_PATH = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
BASE_DESIGN = SOURCE / "v13-compatibility-v01/WEST-V13-DESIGN.json"
BASE_LOWERING = SOURCE / "v13-compatibility-v01/WEST-V13-LOWERING.json"
BASE_MATERIALS = SOURCE / "v13-compatibility-v01/WEST-V13-MATERIALS.json"
BASE_VALIDATOR = SOURCE / "test_v13_compatibility_v02.py"
BASE_RESULT = ROOT / "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/v13-compatibility-v02/V13-LITERAL-REPAIR-RESULT.json"
BRIDGE_SHA = "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
BASE_DESIGN_SHA = "265ea5b27e0dd7982cb587b2efb944de462bf67650bb41b2000597deebc0b621"
BASE_LOWERING_SHA = "a9a316c8050e39779f806398f5f1ef5982c7ddf7d357c84cbf2eaf0700ea2743"
BASE_MATERIALS_SHA = "d867f8dd3cc49c8899b4b6a48e65337c76a1c20e2f68ec0024535cdf43d0cf11"
BASE_RESULT_SHA = "a610e358a60120f38d20dfadb77423fcb021daafbfe72dfa67973652c2722bbe"
CLAIM_SHA = "d08480b230073ef884c8979f3dc80d57c165f3177e6a2fd12b0baab9e286dafb"
DESIGN_CLAIM_SHA = "6b9608a7854afc60676ac27e7c7a8a7c4420161805a4ef59c68649acdd6a901d"
PUBLISHED_BASE = "ea26fdac05169e0375b65d7c5dc65b4fbe00d977"
AUTHORITY_COMMIT = "1d7c6510fd99299c88d3f4412caa982e020c1941"
NORTH_AUTHORITY_SHA = "e439d9f8de08474bbaf31c2308491dad486ec953bf45605c043731f68b44edbb"
NORTH_TARGET_JSON_SHA = "bd9df3b979eb521af9823de19063c39ece702648736eddb79e6a6e498fbf713d"
NORTH_TARGET_PNG_SHA = "a5ea4e52eeacd1820a9bd576c3df48850ba39f6543ff4e2a284ebd7753c2e7f1"
EXPECTED_ROUTE = "quality-v1:play-081-industrial-l04-v14-west-prelock-v1"
EXPECTED_ROUTE_SHA = "38d26484c0cff5e66aeb5e585f1900a311c5c99e0c2e840a51f1c891da38df33"
REPAIR_ROUTE = "quality-v2:play-081-west-v14-exact-closure-r2"
EXPECTED_HEAD = "81aff53f4276208c8065e76a29f1f99c30a5ceec"
EXPECTED_COMPONENT_KINDS = {"surrounding-shell", "foundation", "frontage-apron", "portal-frame-jamb", "portal-frame-header", "aperture-void", "portal-depth-reveal", "freight-recess-beat", "roof-tier", "clerestory-lantern", "crown-break", "process-vessel", "pipe-cluster", "process-stack", "roof-plant", "control-annex", "staff-glazing", "service-door", "loading-rails", "roof-edge", "apron-marking", "roof-truss"}
PIXEL_SUFFIXES = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr", ".blend"}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def fail(message: str) -> None:
    raise AssertionError(message)


def numeric(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def aabb(raw: Any) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    if not isinstance(raw, dict) or set(raw) != {"min", "max"}: fail("aabb-schema")
    lo, hi = raw["min"], raw["max"]
    if not isinstance(lo, list) or not isinstance(hi, list) or len(lo) != 3 or len(hi) != 3 or not all(numeric(x) for x in lo + hi): fail("aabb-coordinate")
    lower, upper = tuple(float(x) for x in lo), tuple(float(x) for x in hi)
    if any(x >= y for x, y in zip(lower, upper)): fail("aabb-order")
    return lower, upper


def intersects(left: tuple[tuple[float, float, float], tuple[float, float, float]], right: tuple[tuple[float, float, float], tuple[float, float, float]]) -> bool:
    return all(a < d and c < b for a, b, c, d in zip(left[0], left[1], right[0], right[1]))


def run_base_proof() -> str:
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run([sys.executable, str(BASE_VALIDATOR)], capture_output=True, text=True, env=env, check=False)
    if result.returncode != 0 or not result.stdout.startswith("PASS v13-west-literal-repair-v2"):
        fail("accepted v13 base proof failed")
    return result.stdout.strip()


def audit(design: dict[str, Any], lowering: dict[str, Any], *, files: bool = False) -> list[str]:
    errors: list[str] = []
    def bad(code: str) -> None: errors.append(code)
    if design.get("task") != "PLAY-081" or design.get("direction") != "west" or design.get("logicalBuildingID") != "industrial_l04" or design.get("variantID") != "variant-0": bad("identity")
    if design.get("direction") != "west" or design.get("sourceRevision") != "west-v14-compatibility-01" or design.get("orientationTransform") != "none" or design.get("siblingInputsConsumed") != []: bad("direction-isolation")
    bindings = design.get("authorityBindings", {})
    if bindings.get("publishedBase") != PUBLISHED_BASE or bindings.get("authorityCommit") != AUTHORITY_COMMIT or bindings.get("claimRevision") != 10 or bindings.get("claimSHA256") != DESIGN_CLAIM_SHA or bindings.get("bridgeSHA256") != BRIDGE_SHA: bad("authority")
    if bindings.get("northV14AuthoritySHA256") != NORTH_AUTHORITY_SHA or bindings.get("northV14TargetJSONSHA256") != NORTH_TARGET_JSON_SHA or bindings.get("northV14TargetPixelsSHA256") != NORTH_TARGET_PNG_SHA: bad("family-authority")
    if design.get("sourceAuthority") is not False or design.get("pixelRenderingAuthorized") is not False or design.get("productionSelected") is not False: bad("zero-pixel-boundary")
    expected_base = {"designSHA256": BASE_DESIGN_SHA, "loweringSHA256": BASE_LOWERING_SHA, "materialsSHA256": BASE_MATERIALS_SHA, "preserveAllBytes": True}
    if any(design.get("baseProof", {}).get(k) != v for k, v in expected_base.items()): bad("base-proof")
    bridge = design.get("coordinateBridge", {})
    if bridge.get("sha256") != BRIDGE_SHA or lowering.get("coordinateBridge", {}).get("sha256") != BRIDGE_SHA or bridge.get("basisFormula") != "B(CitySim[x,y,z])=Blender[z,x,y]": bad("bridge")
    if files and any((not p.is_file() or sha(p) != h) for p, h in ((BASE_DESIGN, BASE_DESIGN_SHA), (BASE_LOWERING, BASE_LOWERING_SHA), (BASE_MATERIALS, BASE_MATERIALS_SHA), (BASE_RESULT, BASE_RESULT_SHA), (BRIDGE_PATH, BRIDGE_SHA))): bad("base-file-drift")
    registration = design.get("registration", {})
    if registration.get("frontageEdge") != "west" or registration.get("frontageSocketWorldXYZ") != [-28, 0, 0] or registration.get("frontageSocketBlenderXYZ") != [0, -28, 0] or registration.get("frontageSocketSourceXY") != [640, 704] or registration.get("groundPivotWorldXYZ") != [28, 0, 28] or registration.get("groundPivotSourceXY") != [768, 896] or registration.get("verticalEnvelopeWorld") != [0, 44]: bad("registration")
    camera = design.get("camera", {})
    if camera.get("projection") != "orthographic-2:1" or camera.get("renderViewportPixels") != [1536, 1024] or camera.get("literalViewportPixels") != [192, 128] or camera.get("actualCameraProcessCount") != 0: bad("camera")
    if design.get("lightAndContact", {}).get("keyDirection") != "northwest" or design.get("lightAndContact", {}).get("contactShadowDirection") != "southeast": bad("light-contact")
    components = design.get("components", [])
    if len(components) != 29 or design.get("semanticCoverage", {}).get("componentCount") != 29: bad("component-count")
    ids = [c.get("id") for c in components if isinstance(c, dict)]
    if len(ids) != len(set(ids)): bad("component-alias")
    if {c.get("kind") for c in components} != EXPECTED_COMPONENT_KINDS: bad("component-kinds")
    boxes: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]] = {}
    object_ids: list[str] = []
    for component in components:
        try: boxes[component["id"]] = aabb(component["aabb"])
        except (KeyError, TypeError, AssertionError): bad("component-aabb"); continue
        if not isinstance(component.get("builderObjects"), list) or not component["builderObjects"]: bad("builder-coverage")
        object_ids.extend(component.get("builderObjects", []))
        if boxes[component["id"]][1][1] > 44 or boxes[component["id"]][0][0] < -28 or boxes[component["id"]][1][0] > 28 or boxes[component["id"]][0][2] < -28 or boxes[component["id"]][1][2] > 28: bad("footprint-envelope")
    if len(object_ids) != 34 or len(object_ids) != len(set(object_ids)): bad("object-identity")
    lowering_components = lowering.get("componentLowering", {}).get("components", [])
    if len(lowering_components) != 29 or {x.get("id") for x in lowering_components} != set(ids): bad("lowering-coverage")
    for item in lowering_components:
        source = next((c for c in components if c["id"] == item["id"]), None)
        if source is None:
            bad("lowering-object-binding")
            continue
        if item.get("objects") != source.get("builderObjects") or not isinstance(item.get("builder"), str): bad("lowering-object-binding")
    aperture = boxes.get("west-v14-deep-freight-aperture")
    allowed_overlap = {"west-v14-foundry-shell", "west-v14-operating-apron", "west-v14-portal-left-jamb", "west-v14-portal-right-jamb", "west-v14-portal-header", "west-v14-inner-reveal", "west-v14-crown-west", "west-v14-crown-center", "west-v14-crown-east", "west-v14-roof-edge", "west-v14-freight-recess-1", "west-v14-freight-recess-2", "west-v14-freight-recess-3"}
    if aperture:
        intruders = [cid for cid, box in boxes.items() if cid != "west-v14-deep-freight-aperture" and intersects(box, aperture) and cid not in allowed_overlap]
        if intruders: bad("aperture-solid-intrusion")
    portal = design.get("portalAndHierarchy", {})
    if len(portal.get("freightBeatIDs", [])) != 3 or len(portal.get("roofTierIDs", [])) != 3 or portal.get("silhouetteBreakCount", 0) < 5 or portal.get("portalFirstRead") is not True: bad("portal-hierarchy")
    if design.get("occlusionProof", {}).get("apertureSolidIntrusionCount") != 0 or design.get("occlusionProof", {}).get("processOccluderSourceOverlapPixels") != 0 or design.get("occlusionProof", {}).get("processOccluderIDs") != []: bad("occlusion")
    targets = design.get("literal192Targets", {})
    if targets.get("portalMinimumLiteralWidth") != 20 or targets.get("portalMinimumLiteralHeight") != 26 or targets.get("freightBeatCount") != 3 or targets.get("freightSeparatorMinimumSourcePixels") != 2 or targets.get("staffGlazingMinimumLiteralPixels") != [5, 8] or targets.get("silhouetteBreakMinimum") < 5: bad("literal-targets")
    analytic = lowering.get("analyticProjection", {})
    if analytic.get("silhouetteBreakCount") != 6 or analytic.get("apertureSolidIntrusionCount") != 0 or analytic.get("processOccluderSourceOverlapPixels") != 0 or analytic.get("registrationErrorSourcePixels") != 0: bad("analytic-projection")
    if design.get("futureProcessAReadiness", {}).get("ready") is not False: bad("source-ready")
    for container in (design.get("zeroPixelBoundary", {}), lowering.get("zeroPixelBoundary", {})):
        for key in ("blenderProcessLaunches", "dccInvocations", "renderInvocations", "imageGenInvocations", "normalizerInvocations", "pixelFiles"):
            if container.get(key) != 0: bad("zero-pixel")
    if files and any(p.is_file() and p.suffix.lower() in PIXEL_SUFFIXES for p in V14.rglob("*")): bad("pixel-file")
    return errors


def adversaries(design: dict[str, Any], lowering: dict[str, Any]) -> list[str]:
    cases = [
        ("wrong-direction", lambda d: d.update(direction="north"), "direction-isolation"),
        ("socket-substitution", lambda d: d["registration"].update(frontageSocketWorldXYZ=[0, 0, -28]), "registration"),
        ("orientation-transform", lambda d: d.update(orientationTransform="rotate-z-90"), "direction-isolation"),
        ("builder-omission", lambda d: d["components"][0].update(builderObjects=[]), "builder-coverage"),
        ("component-alias", lambda d: d["components"][1].update(id=d["components"][0]["id"]), "component-alias"),
        ("roof-tier-loss", lambda d: d["portalAndHierarchy"].update(roofTierIDs=["west-v14-roof-tier-low"]), "portal-hierarchy"),
        ("silhouette-loss", lambda d: d["portalAndHierarchy"].update(silhouetteBreakCount=2), "portal-hierarchy"),
        ("aperture-occluder", lambda d: d["occlusionProof"].update(apertureSolidIntrusionCount=1), "occlusion"),
        ("pixel-authority", lambda d: d.update(pixelRenderingAuthorized=True), "zero-pixel-boundary"),
        ("source-ready", lambda d: d["futureProcessAReadiness"].update(ready=True), "source-ready"),
    ]
    passed = []
    for name, mutate, expected in cases:
        candidate = copy.deepcopy(design)
        mutate(candidate)
        errors = audit(candidate, lowering)
        if expected not in errors: fail(f"adversary accepted: {name}")
        passed.append(name)
    return passed


def emit_derived() -> int:
    design, lowering = load(DESIGN_PATH), load(LOWERING_PATH)
    payload = {"successor": design["successor"], "componentCount": len(design["components"]), "objectCount": sum(len(c["builderObjects"]) for c in design["components"]), "portal": design["portalAndHierarchy"], "analyticProjection": lowering["analyticProjection"], "zeroPixel": design["zeroPixelBoundary"]}
    sys.stdout.buffer.write(canonical(payload))
    return 0


def main() -> int:
    if "--emit-derived" in sys.argv[1:]: return emit_derived()
    run_base_proof()
    design, lowering = load(DESIGN_PATH), load(LOWERING_PATH)
    errors = audit(design, lowering, files=True)
    if errors: fail("v14 audit failed: " + ",".join(errors))
    names = adversaries(design, lowering)
    handoff, validation = load(HANDOFF_PATH), load(VALIDATION_PATH)
    expected_validator = str(Path(__file__).resolve().relative_to(ROOT))
    if handoff.get("stage") != "predesign" or handoff.get("sourceReady") is not False or handoff.get("candidateReadyForIndependentReview") is not True: fail("handoff readiness")
    if handoff.get("direction") != "west" or handoff.get("validatorPath") != expected_validator or handoff.get("designPath") != str(DESIGN_PATH.relative_to(ROOT)) or handoff.get("loweringPath") != str(LOWERING_PATH.relative_to(ROOT)): fail("handoff paths")
    if validation.get("result") != "PASS" or validation.get("routeId") != REPAIR_ROUTE or validation.get("claimSHA256") != CLAIM_SHA: fail("validation authority")
    if validation.get("validatorPath") != expected_validator or validation.get("validatorSHA256") != sha(Path(__file__)): fail("validator binding")
    if validation.get("adversaries", {}).get("count") != len(names): fail("adversary evidence")
    outputs = []
    env = dict(os.environ); env["PYTHONDONTWRITEBYTECODE"] = "1"
    for _ in range(2):
        result = subprocess.run([sys.executable, str(Path(__file__).resolve()), "--emit-derived"], capture_output=True, env=env, check=False)
        if result.returncode != 0: fail("fresh v14 replay failed")
        outputs.append(result.stdout)
    if outputs[0] != outputs[1]: fail("fresh replay differs")
    replay_sha = hashlib.sha256(outputs[0]).hexdigest()
    if validation.get("freshReplay", {}).get("byteIdentical") is not True or validation.get("freshReplay", {}).get("outputSHA256") != replay_sha: fail("fresh replay evidence")
    print(f"PASS v14-west-compatibility baseProof=PASS portal=PASS roofTiers=3 freightBeats=3 semanticCoverage=100% occlusion=REJECTED literal192=PASS adversaries={len(names)} freshReplay=BYTE_IDENTICAL zeroPixel=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
