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
ROUTE_ID = "four-view-v8:play-102-qa-prereg-validator-repair-v1"
ROUTE_SHA = "96562cae15824514adfeba94bd3201a7a39b655c689753472e76f30d2e22bbde"
AUTHORITY = "b36e69a0a15b34c9aea03588f97bbc8621bb7d47"
WORKER_HEAD = "c5285c899119dd417d466d9f82f1e6456f0a028b"
CLAIM_PATH = "docs/production/claims/PLAY-102.playtest-single-angle.md"
CLAIM_SHA = "bab508b648ce1b585ad66ec10b2b54574fe0f0d1741b7b4b33fa12253f34e704"


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
    if route["dispatchPath"] != "docs/production/evidence/INTEGRATION/MODEL-ROUTING-PLAY-102-QA-PREREG-VALIDATOR-REPAIR-V1.json":
        fail("dispatch receipt path mismatch")

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
    if rubric["matrix"] != {"directions": DIRECTIONS, "lods": LODS, "layouts": LAYOUTS, "captureCount": 24}:
        fail("rubric matrix mismatch")
    if rehearsal["matrix"] != rubric["matrix"] or rehearsal["status"] != "BLOCKED_BY_ROUTE_NO_APP_LAUNCH":
        fail("rehearsal plan is not candidate-neutral")

    forbidden_bound_fields = {"candidateCommit", "candidateReceipt", "rendererCandidateReceipt", "resourceManifest", "fixtureAdmission", "fixtureAdmissionReceipt"}
    packets = {"PREREGISTRATION.json": prereg, "FIXTURE.json": load("FIXTURE.json"), "fixture-manifest.json": fixture, "MEASUREMENT-PLAN.json": plan, "RENDERER-CANDIDATE-RECEIPT.json": receipt, "REHEARSAL-PLAN.json": rehearsal}
    def walk(value: object, path: str, packet: str) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                child_path = f"{path}.{key}"
                if key in forbidden_bound_fields and child is not None:
                    fail(f"{packet}:{child_path} must remain null")
                if key == "candidateEvidenceCreated" and child is not False:
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

    print("PASS: PLAY-102 candidate-neutral 24-capture preregistration")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"RETURN: {error}", file=sys.stderr)
        raise SystemExit(1)
