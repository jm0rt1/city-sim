#!/usr/bin/env python3
"""Fail-closed static validator for the PLAY-102 candidate-neutral packet."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent
DIRECTIONS = ["north", "east", "south", "west"]
LODS = ["city", "neighborhood", "block"]
LAYOUTS = ["regular", "compact-900x600"]
ROUTE_ID = "four-view-v16:play-102-current-master-metadata-rebind-v2"
ROUTE_SHA = "ad8396db363a778e098d8079b0634699a0c75e43f53bc8fb473c0a1d8ff70ec0"
AUTHORITY = "5b4c040a182d0a07f4f0f0e32e598797d4314c0e"
WORKER_HEAD = "f2721cb59137cbd61ba55cc1427fa58ff7efaa98"
CLAIM_PATH = "docs/production/claims/PLAY-102.playtest-single-angle.md"
CLAIM_SHA = "bab508b648ce1b585ad66ec10b2b54574fe0f0d1741b7b4b33fa12253f34e704"
DISPATCH_PATH = "docs/production/evidence/INTEGRATION/MODEL-ROUTING-PLAY-101-102-CURRENT-MASTER-METADATA-REBIND-V2.json"
ROTATION_CONTRACT_PATH = "docs/production/decisions/CONTRACT-027-world-rotation-authored-view-mapping.md"
ROTATION_CONTRACT_SHA = "693831b3d8fac49330ac21adce626b632351c7eeba901ebff6719687e5f330e7"


def load(name: str) -> dict:
    with (ROOT / name).open() as handle:
        return json.load(handle)


def digest(name: str) -> str:
    return hashlib.sha256((ROOT / name).read_bytes()).hexdigest()


def fail(message: str) -> None:
    raise ValueError(message)


def main() -> int:
    prereg = load("PREREGISTRATION.json")
    fixture = load("fixture-manifest.json")
    camera = load("CAMERA-STATES.json")
    rubric = load("RUBRIC.json")
    plan = load("MEASUREMENT-PLAN.json")
    receipt = load("RENDERER-CANDIDATE-RECEIPT.json")
    rehearsal = load("REHEARSAL-PLAN.json")

    authority = prereg["authority"]
    if (authority["authorityCommit"], authority["baseCommit"], authority["expectedWorkerHead"]) != (AUTHORITY, AUTHORITY, WORKER_HEAD):
        fail("route authority/base/expected head mismatch")
    if (authority["claimPath"], authority["claimSha256"]) != (CLAIM_PATH, CLAIM_SHA):
        fail("claim identity mismatch")
    route = prereg["route"]
    if (route["routeId"], route["canonicalModelRouteSha256"]) != (ROUTE_ID, ROUTE_SHA):
        fail("route identity mismatch")
    if route["dispatchPath"] != DISPATCH_PATH:
        fail("dispatch receipt path mismatch")
    if prereg["rotationContract"] != {"path": ROTATION_CONTRACT_PATH, "sha256": ROTATION_CONTRACT_SHA}:
        fail("rotation contract identity mismatch")

    expected_tuples = [(f"{direction}-{lod}-{'compact' if layout == 'compact-900x600' else layout}", direction, lod, layout) for layout in LAYOUTS for lod in LODS for direction in DIRECTIONS]
    expected = [row[0] for row in expected_tuples]
    actual_camera = camera["captureMatrix"]
    actual_tuples = [(row.get("id"), row.get("direction"), row.get("lod"), row.get("layout")) for row in actual_camera]
    if len(actual_camera) != 24 or camera["captureCount"] != 24 or set(actual_tuples) != set(expected_tuples) or len(set(actual_tuples)) != 24:
        fail("camera matrix is not the exact ordered 4x3x2 set")
    if actual_tuples != expected_tuples:
        fail("camera matrix ordering differs from the frozen 4x3x2 set")

    sequence = plan["captureSequence"]
    if [row["id"] for row in sequence] != expected or [row["cameraState"] for row in sequence] != expected:
        fail("measurement sequence diverges from camera matrix")
    if any(row["capture"] != f"screenshots/{row['id']}.png" for row in sequence):
        fail("measurement capture path mismatch")
    if prereg["scriptedMeasurementPlan"]["captureNames"] != expected or prereg["camera"]["captureCount"] != 24:
        fail("preregistration capture names mismatch")
    if fixture["captureCount"] != 24 or fixture["directions"] != DIRECTIONS or fixture["lods"] != LODS or fixture["layouts"] != LAYOUTS:
        fail("fixture matrix mismatch")
    if fixture["logicalIdentityCount"] != 43 or fixture["authoredSourceSpriteCount"] != 172 or fixture["explicitLodPayloadCount"] != 516:
        fail("fixture admission expectations mismatch")
    source = fixture["sourceFixture"]
    if source["id"] != prereg["fixture"]["id"] or source["version"] != prereg["fixture"]["version"]:
        fail("fixture source identity mismatch")
    if source["path"] != prereg["fixture"]["sourcePath"] or source["fileSha256"] != prereg["fixture"]["sourceSha256"] or source["stateHash"] != prereg["fixture"]["stateHash"]:
        fail("fixture source binding mismatch")
    source_path = ROOT.parents[3] / source["path"]
    if not source_path.is_file() or hashlib.sha256(source_path.read_bytes()).hexdigest() != source["fileSha256"]:
        fail("fixture source bytes mismatch")
    if fixture["admissionExpectations"] != {"logicalIdentityCount": 43, "authoredSourceSpriteCount": 172, "explicitLodPayloadCount": 516}:
        fail("admission expectation record mismatch")
    if prereg["familyContract"]["logicalIdentityCount"] != 43 or prereg["familyContract"]["authoredSourceSpriteCount"] != 172 or prereg["familyContract"]["normalizedPayloadCount"] != 516:
        fail("preregistration family expectations mismatch")
    expected_matrix = {"count": 24, "directions": DIRECTIONS, "lods": LODS, "layouts": LAYOUTS}
    if plan.get("captureMatrix") != expected_matrix:
        fail("measurement plan captureMatrix mismatch")
    if rubric["matrix"] != {"directions": DIRECTIONS, "lods": LODS, "layouts": LAYOUTS, "captureCount": 24}:
        fail("rubric matrix mismatch")
    if rehearsal["matrix"] != rubric["matrix"] or rehearsal["status"] != "BLOCKED_BY_ROUTE_NO_APP_LAUNCH":
        fail("rehearsal plan is not candidate-neutral")

    forbidden_bound_fields = {"candidateCommit", "candidateReceipt", "rendererCandidateReceipt", "resourceManifest", "fixtureAdmission", "fixtureAdmissionReceipt", "measurementReceipt"}
    packets = {"PREREGISTRATION.json": prereg, "FIXTURE.json": load("FIXTURE.json"), "fixture-manifest.json": fixture, "MEASUREMENT-PLAN.json": plan, "RENDERER-CANDIDATE-RECEIPT.json": receipt, "REHEARSAL-PLAN.json": rehearsal}
    def walk(value: object, path: str, packet: str) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                child_path = f"{path}.{key}"
                if key in forbidden_bound_fields and child is not None:
                    fail(f"{packet}:{child_path} must remain null")
                if key == "candidateEvidenceCreated" and child is not False:
                    fail(f"{packet}:{child_path} must remain false")
                if key == "productionSelection" and child is not False:
                    fail(f"{packet}:{child_path} must remain false")
                walk(child, child_path, packet)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, f"{path}[{index}]", packet)
    for packet, value in packets.items():
        walk(value, "$", packet)
    if fixture["observedValues"] != "UNMEASURED" or rehearsal["preconditions"]["observedValues"] != "UNMEASURED":
        fail("observations must remain UNMEASURED")

    for key, name in (("definitionSha256", "fixture-manifest.json"),):
        if prereg["fixture"][key] != digest(name):
            fail(f"fixture {key} mismatch")
    for section, key, name in (("camera", "stateSha256", "CAMERA-STATES.json"), ("rubric", "sha256", "RUBRIC.json"), ("scriptedMeasurementPlan", "sha256", "MEASUREMENT-PLAN.json"), ("defectPacket", "schemaSha256", "DEFECT-PACKET-SCHEMA.json")):
        if prereg[section][key] != digest(name):
            fail(f"{section} digest mismatch")
    if prereg["rehearsalPlan"]["sha256"] != digest("REHEARSAL-PLAN.json"):
        fail("rehearsal plan digest mismatch")

    print("PASS: PLAY-102 candidate-neutral 24-capture preregistration")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"RETURN: {error}", file=sys.stderr)
        raise SystemExit(1)
