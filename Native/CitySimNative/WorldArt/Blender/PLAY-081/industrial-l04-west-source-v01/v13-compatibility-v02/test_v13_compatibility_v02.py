#!/usr/bin/env python3
"""Zero-pixel West v02 literal freight/staff proof.

This is a versioned analytic successor.  The accepted v01 validator and all
v01 bytes are exercised unchanged; this file validates only the v02 delta.
"""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import io
import json
import math
import subprocess
import sys
from contextlib import redirect_stdout
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[7]
SOURCE = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-081/industrial-l04-west-source-v01"
V01 = SOURCE / "v13-compatibility-v01"
V02 = SOURCE / "v13-compatibility-v02"
DESIGN_PATH = V02 / "WEST-V13-DESIGN.json"
LOWERING_PATH = V02 / "WEST-V13-LOWERING.json"
EVIDENCE_PATH = ROOT / "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/v13-compatibility-v02/V13-LITERAL-REPAIR-RESULT.json"
BRIDGE_PATH = ROOT / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json"
BASE_DESIGN = V01 / "WEST-V13-DESIGN.json"
BASE_LOWERING = V01 / "WEST-V13-LOWERING.json"
BASE_VALIDATOR = SOURCE / "test_v13_compatibility.py"
BASE_EVIDENCE = ROOT / "docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/v13-compatibility-v01/V13-COMPATIBILITY-RESULT.json"
CLAIM_SHA = "289f7e55cdb2721dde5728708dca92e5a785d65417ae1600190c599f54153ad4"
BASE = "87178f7cbd2723283163dd6ce03437498a21dce5"
BRIDGE_SHA = "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
DESIGN_SHA = "265ea5b27e0dd7982cb587b2efb944de462bf67650bb41b2000597deebc0b621"
LOWERING_SHA = "a9a316c8050e39779f806398f5f1ef5982c7ddf7d357c84cbf2eaf0700ea2743"
VALIDATOR_SHA = "d0c330a13c84331c7742db062fafee00380d148f30a99b09aa1dc0c0c546675a"
EVIDENCE_SHA = "65848132d2eb042161c90530a134dfe55bfe9380ac397c7cf9ba9d9e3ad6f94b"
ROUTE = {
    "routeId": "quality-v1:west-v13-literal-repair-v1",
    "canonicalRouteSha256": "a9f46c2fded9ef441ad98ae160dd28aa1ad4827b75fac0eb3b7bd695a87b8852",
    "carrierCommit": "af89c2fc2a542535fea8162b9f7ca78d38506d30",
    "receiptPath": "docs/production/evidence/INTEGRATION/MODEL-ROUTING-QUALITY-INDUSTRIAL-L04-V13-LITERAL-REPAIR-LUNA-V1.json",
    "receiptSha256": "59c87bf291a8545e29e09be2c0e8c3d8b2e8ccb1021619b2bcf18bedcc00e838",
    "authorityCommit": BASE,
    "expectedStartingHead": "d891e9fed75ac155ffd9d89d2a5ec8ef19671878",
}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def fail(message: str) -> None:
    raise AssertionError(message)


def eq(a: Any, b: Any) -> bool:
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return math.isclose(float(a), float(b), rel_tol=1e-8, abs_tol=1e-8)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(eq(x, y) for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        return set(a) == set(b) and all(eq(a[key], b[key]) for key in a)
    return a == b


def base_module():
    spec = importlib.util.spec_from_file_location("west_v01_validator", BASE_VALIDATOR)
    if spec is None or spec.loader is None:
        fail("v01 validator import unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_base_proof() -> str:
    module = base_module()
    output = io.StringIO()
    with redirect_stdout(output):
        result = module.main()
    if result != 0:
        fail("accepted v01 proof returned nonzero")
    return output.getvalue().strip()


def projection(v01: Any, world_box: dict[str, Any], bridge: dict[str, Any]) -> dict[str, Any]:
    affine, _ = v01.derive_affine_from_bridge(bridge)
    box = v01.parse_aabb(world_box, "v02", [])
    if box is None:
        fail("invalid v02 AABB")
    return v01.projected_bounds_for_box(box, affine)


def audit_design(design: dict[str, Any], lowering: dict[str, Any], bridge: dict[str, Any], *, check_files: bool = False) -> list[str]:
    errors: list[str] = []
    def bad(code: str) -> None:
        errors.append(code)
    if design.get("task") != "PLAY-081" or design.get("direction") != "west" or design.get("logicalBuildingID") != "industrial_l04" or design.get("variantID") != "variant-0": bad("identity")
    if design.get("orientationTransform") != "none" or design.get("siblingInputsConsumed") != []: bad("direction-isolation")
    bindings = design.get("authorityBindings", {})
    if bindings.get("publishedBase") != BASE or bindings.get("claimRevision") != 9 or bindings.get("claimSHA256") != CLAIM_SHA or bindings.get("bridgeSHA256") != BRIDGE_SHA: bad("authority")
    if design.get("sourceAuthority") is not False or design.get("pixelRenderingAuthorized") is not False: bad("zero-pixel-boundary")
    base = design.get("baseProof", {})
    expected_base = {"designPath": str(BASE_DESIGN.relative_to(ROOT)), "designSHA256": DESIGN_SHA, "loweringPath": str(BASE_LOWERING.relative_to(ROOT)), "loweringSHA256": LOWERING_SHA, "validatorPath": str(BASE_VALIDATOR.relative_to(ROOT)), "validatorSHA256": VALIDATOR_SHA, "evidencePath": str(BASE_EVIDENCE.relative_to(ROOT)), "evidenceSHA256": EVIDENCE_SHA, "preserveAllBytes": True}
    if base != expected_base: bad("base-proof")
    if check_files and any((not p.is_file() or sha(p) != h) for p, h in ((BASE_DESIGN, DESIGN_SHA), (BASE_LOWERING, LOWERING_SHA), (BASE_VALIDATOR, VALIDATOR_SHA), (BASE_EVIDENCE, EVIDENCE_SHA), (BRIDGE_PATH, BRIDGE_SHA))): bad("base-file-drift")
    expected_bridge = {"path": str(BRIDGE_PATH.relative_to(ROOT)), "sha256": BRIDGE_SHA, "sourceRevision": "direction-bridge-v06", "basisFormula": "B(CitySim[x,y,z])=Blender[z,x,y]", "basisMatrixRows": [[0, 0, 1], [1, 0, 0], [0, 1, 0]], "sourceOrder": [0, 1, 2, 3]}
    if design.get("coordinateBridge") != expected_bridge or lowering.get("coordinateBridge") != expected_bridge: bad("bridge-binding")
    freight = design.get("freightAndStaff", {})
    ids = freight.get("freightBeatIDs")
    bounds = freight.get("freightBeatBoundsSource")
    if freight.get("freightBeatCount") != 3 or freight.get("minimumFreightBeatCount") != 3 or not isinstance(ids, list) or len(ids) != 3 or len(set(ids)) != 3 or not isinstance(bounds, list) or len(bounds) != 3: bad("freight-count-or-ids")
    if not isinstance(bounds, list) or len(bounds) != 3: bounds = []
    for item in bounds:
        if not isinstance(item, dict) or not isinstance(item.get("min"), list) or not isinstance(item.get("max"), list) or len(item["min"]) != 2 or len(item["max"]) != 2: bad("freight-schema"); continue
        if item["max"][0] - item["min"][0] < 4 or item["max"][1] - item["min"][1] < 8: bad("freight-min-size")
    separators = freight.get("separatorBoundsSource")
    widths = freight.get("separatorWidthsSourcePixels")
    if not isinstance(separators, list) or len(separators) != 2 or widths != [3, 3] or freight.get("minimumSeparatorWidthSourcePixels") != 2: bad("separator-count-or-width")
    if isinstance(separators, list) and len(separators) == 2:
        for index, item in enumerate(separators):
            if not isinstance(item, dict) or item.get("max", [0])[0] - item.get("min", [0])[0] < 2 or item.get("min", [0, 0])[0] != bounds[index].get("max", [None])[0] or item.get("max", [0, 0])[0] != bounds[index + 1].get("min", [None])[0]: bad("separator-placement")
    staff_box = freight.get("staffGlazingAABBWorldXYZ")
    if freight.get("staffGlazingComponentID") != "west-v13-staff-glazing" or not isinstance(staff_box, dict): bad("staff-identity")
    if isinstance(staff_box, dict):
        staff = projection(base_module(), staff_box, bridge)
        declared = freight.get("staffBoundsSource")
        literal = freight.get("staffBoundsLiteral192")
        if not isinstance(declared, dict) or not eq(declared.get("min"), staff["min"]) or not eq(declared.get("max"), staff["max"]): bad("staff-source-projection")
        if not isinstance(literal, dict) or literal.get("min") != staff["literalMin"] or literal.get("max") != staff["literalMax"]: bad("staff-literal-projection")
        if freight.get("minimumStaffSourcePixels") != [5, 8] or staff["literalWidth"] < 5 or staff["literalHeight"] < 8: bad("staff-min-size")
        low_staff = lowering.get("projection", {}).get("staffLiteralBounds")
        if low_staff != literal: bad("lowering-staff-drift")
    stack = freight.get("stackShare", {})
    base_design = load(BASE_DESIGN)
    stack_component = next((c for c in base_design.get("components", []) if c.get("id") == "west-v13-stack"), None)
    if stack.get("componentID") != "west-v13-stack" or stack.get("role") != "oxidized-process-machinery" or stack.get("mode") != "distinct-process-stack-not-freight-beat" or stack.get("authorityKey") != "west-v13-stack|oxidized-process-machinery|distinct-process-stack" or stack.get("componentID") in (ids or []) or not stack_component or stack_component.get("kind") != "process-stack": bad("stack-share")
    if lowering.get("projection", {}).get("freightBeatSourceBounds") != bounds or lowering.get("projection", {}).get("separatorWidthsSourcePixels") != widths: bad("lowering-freight-drift")
    for container in (design.get("zeroPixelBoundary", {}), lowering.get("zeroPixelBoundary", {})):
        for key in ("blenderProcessLaunches", "dccInvocations", "renderInvocations", "imageGenInvocations", "normalizerInvocations", "pixelFiles"):
            if container.get(key) != 0: bad("zero-pixel")
    return errors


def adversaries(design: dict[str, Any], lowering: dict[str, Any], bridge: dict[str, Any]) -> list[str]:
    cases: list[tuple[str, Any, str]] = []
    def case(name: str, mutate: Any, expected: str) -> None: cases.append((name, mutate, expected))
    case("missing-freight", lambda d: d["freightAndStaff"].pop("freightBeatIDs"), "freight-count-or-ids")
    case("below-freight", lambda d: d["freightAndStaff"].update(freightBeatCount=2), "freight-count-or-ids")
    case("freight-alias", lambda d: d["freightAndStaff"].update(freightBeatIDs=["west-v13-freight-beat-1"] * 3), "freight-count-or-ids")
    case("missing-separators", lambda d: d["freightAndStaff"].pop("separatorBoundsSource"), "separator-count-or-width")
    case("below-separator", lambda d: d["freightAndStaff"].update(separatorWidthsSourcePixels=[1, 3]), "separator-count-or-width")
    case("staff-missing", lambda d: d["freightAndStaff"].pop("staffGlazingAABBWorldXYZ"), "staff-identity")
    case("staff-below", lambda d: d["freightAndStaff"].update(staffGlazingAABBWorldXYZ={"min": [1, 5, 22], "max": [3, 13, 25]}), "staff-source-projection")
    case("stack-share-alias", lambda d: d["freightAndStaff"]["stackShare"].update(componentID="west-v13-freight-beat-1"), "stack-share")
    case("stack-share-role", lambda d: d["freightAndStaff"]["stackShare"].update(role="warm-staff-glazing"), "stack-share")
    passed: list[str] = []
    for name, mutate, expected in cases:
        candidate = copy.deepcopy(design)
        mutate(candidate)
        errors = audit_design(candidate, lowering, bridge)
        if expected not in errors: fail(f"adversary {name} was accepted: {errors}")
        passed.append(name)
    return passed


def emit_derived() -> int:
    v01 = base_module()
    design, lowering, bridge = load(DESIGN_PATH), load(LOWERING_PATH), load(BRIDGE_PATH)
    staff = projection(v01, design["freightAndStaff"]["staffGlazingAABBWorldXYZ"], bridge)
    payload = {"successor": design["successor"], "freightBeatBoundsSource": design["freightAndStaff"]["freightBeatBoundsSource"], "separatorWidthsSourcePixels": design["freightAndStaff"]["separatorWidthsSourcePixels"], "staffSourceBounds": staff, "stackShare": design["freightAndStaff"]["stackShare"], "baseProofSHA256": design["baseProof"]["designSHA256"] + ":" + design["baseProof"]["loweringSHA256"]}
    sys.stdout.buffer.write(canonical(payload))
    return 0


def main() -> int:
    if "--emit-derived" in sys.argv[1:]: return emit_derived()
    base_output = run_base_proof()
    design, lowering, bridge = load(DESIGN_PATH), load(LOWERING_PATH), load(BRIDGE_PATH)
    errors = audit_design(design, lowering, bridge, check_files=True)
    if errors: fail("v02 proof audit failed: " + ",".join(errors))
    names = adversaries(design, lowering, bridge)
    evidence = load(EVIDENCE_PATH)
    if evidence.get("result") != "PASS" or evidence.get("route") != ROUTE or evidence.get("sourceReady") is not False: fail("evidence binding/readiness")
    if evidence.get("baseProof", {}).get("designSHA256") != DESIGN_SHA or evidence.get("baseProof", {}).get("loweringSHA256") != LOWERING_SHA: fail("evidence base proof")
    if evidence.get("freightAndStaff", {}).get("freightBeatCount") != 3 or evidence.get("freightAndStaff", {}).get("minimumSeparatorWidthSourcePixels") != 2 or evidence.get("freightAndStaff", {}).get("minimumStaffSourcePixels") != [5, 8]: fail("evidence metrics")
    if evidence.get("adversaries", {}).get("count") != len(names): fail("evidence adversary count")
    outputs = []
    for _ in range(2):
        run = subprocess.run([sys.executable, str(Path(__file__).resolve()), "--emit-derived"], capture_output=True, check=False)
        if run.returncode != 0: fail("fresh derived process failed")
        outputs.append(run.stdout)
    if outputs[0] != outputs[1]: fail("fresh replay differs")
    replay_sha = hashlib.sha256(outputs[0]).hexdigest()
    if evidence.get("freshReplay", {}).get("byteIdentical") is not True or evidence.get("freshReplay", {}).get("outputSHA256") != replay_sha: fail("fresh replay evidence")
    if any(p.suffix.lower() in {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".exr", ".blend"} for p in V02.rglob("*") if p.is_file()): fail("pixel/binary output present")
    print(f"PASS v13-west-literal-repair-v2 baseProof=PASS freight=3 separatorMin=2 staff=5x9 stackShare=PASS freshReplay=BYTE_IDENTICAL adversaries={len(names)} zeroPixel=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
