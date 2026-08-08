#!/usr/bin/env python3
"""Adversarial tests for all five CONTRACT-025 PLAY-096 repair defects."""

from __future__ import annotations

import copy
import sys

from four_view_harness import (
    CANVAS,
    DIRECTIONS,
    GROUND_PIVOT,
    CONSUMERS,
    exact_identities,
    inventory_document,
    normalize_full_canvas,
    provenance_record,
    registration_for,
    validate_direction_handoff,
    validate_handoff_json_schema,
    validate_inventory,
    validate_provenance,
)


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def valid_source_provenance(logical_id: str, direction: str) -> dict[str, object]:
    record = provenance_record(logical_id, direction, "source_candidate")
    record.update({
        "prompt_text": "One authored building view with the named identity and governed frontage.",
        "south_reference": {"path": "Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/residential_l01/source-v01.png", "sha256": "a" * 64},
        "references": [{"path": "ref.png", "role": "appearance", "sha256": "b" * 64}],
        "reference_hashes": ["b" * 64],
        "cleanup_command": "python3 normalize.py --input raw.png --output normalized",
        "gameplay_meaning": "completed maintained building appearance only",
        "raw_path": "docs/production/evidence/PLAY-096/four-view-repair/raw/example.png",
        "raw_sha256": "c" * 64,
        "record_path": "docs/production/evidence/PLAY-096/four-view-repair/provenance/example.json",
        "record_sha256": "d" * 64,
        "prompt_complete": True,
        "references_complete": True,
        "reference_hashes_complete": True,
        "cleanup_complete": True,
        "gameplay_meaning_complete": True,
    })
    return record


def complete_candidate_row(handoff: dict[str, object]) -> dict[str, object]:
    row = copy.deepcopy(handoff["rows"][0])
    row["raw"] = {"status": "source_candidate", "path": "raw/example.png", "sha256": "1" * 64}
    row["record"] = {"status": "source_candidate", "path": "provenance/example.json", "sha256": "2" * 64}
    row["lods"] = [
        {"lod": "city", "status": "source_candidate", "path": "normalized/city.png", "sha256": "3" * 64},
        {"lod": "neighborhood", "status": "source_candidate", "path": "normalized/neighborhood.png", "sha256": "4" * 64},
        {"lod": "block", "status": "source_candidate", "path": "normalized/block.png", "sha256": "5" * 64},
    ]
    row["provenance"] = valid_source_provenance(row["logical_id"], row["direction"])
    row["provenance"]["south_reference"] = {"path": "south/reference.png", "sha256": "6" * 64}
    row["provenance"]["raw_path"] = row["raw"]["path"]
    row["provenance"]["raw_sha256"] = row["raw"]["sha256"]
    row["provenance"]["record_path"] = row["record"]["path"]
    row["provenance"]["record_sha256"] = row["record"]["sha256"]
    row["south_reference"] = copy.deepcopy(row["provenance"]["south_reference"])
    row["readiness"]["candidateReadyForIndependentReview"] = True
    return row


def main() -> None:
    inventory = inventory_document()
    check(len(exact_identities()) == 43, "integrated identity count must be 43")
    check(len(inventory["direction_rows"]) == 172, "integrated direction count must be 172")
    check(not validate_inventory(inventory), "frozen four-view inventory must validate")

    civic = {row["logical_id"] for row in inventory["identities"] if row["family"] == "civic"}
    check(civic == {"civic_park_v0", "civic_power_plant_v0", "civic_water_tower_v0", "civic_fire_station_v0", "civic_police_station_v0", "civic_school_v0", "civic_city_hall_v0"}, "civic IDs must match integrated matrix")
    broken_inventory = copy.deepcopy(inventory)
    broken_inventory["identities"][0]["logical_id"] = "residential_l01"
    check(validate_inventory(broken_inventory), "old single-angle ID must fail")
    broken_inventory = copy.deepcopy(inventory)
    broken_inventory["direction_rows"].pop()
    check(validate_inventory(broken_inventory), "incomplete 172-row matrix must fail")
    broken_inventory = copy.deepcopy(inventory)
    broken_inventory["identities"][0]["family"] = "commercial"
    check(validate_inventory(broken_inventory), "identity family binding must fail")
    broken_inventory = copy.deepcopy(inventory)
    broken_inventory["identities"][0]["level"] = 4
    check(validate_inventory(broken_inventory), "identity level binding must fail")
    broken_inventory = copy.deepcopy(inventory)
    broken_inventory["identities"][0]["kind"] = "civic"
    check(validate_inventory(broken_inventory), "identity kind binding must fail")

    handoff = {"schema": 2, "task": "PLAY-096", "contract": "CONTRACT-025", "rows": []}
    from four_view_harness import direction_handoff_document
    handoff = direction_handoff_document(inventory)
    check(not validate_direction_handoff(handoff), "empty four-view handoff must validate as not-generated")
    check(not validate_handoff_json_schema(handoff), "JSON Schema must accept its own committed handoff")
    broken_schema = copy.deepcopy(handoff)
    broken_schema["rows"][0]["registration"].pop("registration_profile_sha256")
    check(validate_handoff_json_schema(broken_schema), "JSON Schema must reject incomplete registration")
    broken = copy.deepcopy(handoff)
    broken["rows"][0]["raw"] = {"status": "source_candidate", "path": "/absolute/raw.png", "sha256": "a" * 64}
    check(validate_direction_handoff(broken), "absolute raw path must fail")
    broken = copy.deepcopy(handoff)
    broken["rows"][0]["logical_id"] = "commercial_l01_v0"
    check(validate_direction_handoff(broken), "logical ID/key cross-binding must fail")
    broken = copy.deepcopy(handoff)
    broken["rows"][0]["alias"]["alias_of"] = "residential_l01_v0:south"
    check(validate_direction_handoff(broken), "alias must fail")
    broken = copy.deepcopy(handoff)
    broken["rows"][0]["readiness"]["sourceReady"] = True
    check(validate_direction_handoff(broken), "premature source readiness must fail")

    registration = registration_for(inventory["identities"][0])
    check(registration["canvas_pixels"] == list(CANVAS) and registration["ground_pivot"] == list(GROUND_PIVOT), "full canvas/pivot must be code-owned")
    check(registration["scale_source"] == "CONTRACT-026-full-canvas-registration" and registration["footprint_world_points"] == [1, 1], "CONTRACT-026 registration profile must be code-owned")
    broken = copy.deepcopy(handoff)
    broken["rows"][0]["registration"]["source_bbox"] = [0, 0, 1, 1]
    check(validate_direction_handoff(broken), "bbox-derived registration must fail")

    candidate = complete_candidate_row(handoff)
    ready_handoff = copy.deepcopy(handoff)
    ready_handoff["rows"][0] = candidate
    check(not validate_direction_handoff(ready_handoff), "complete source candidate may be ready for independent review")
    broken = copy.deepcopy(ready_handoff)
    broken["rows"][0]["lods"][1]["sha256"] = broken["rows"][0]["lods"][0]["sha256"]
    check(validate_direction_handoff(broken), "normalized LOD alias must fail")
    broken = copy.deepcopy(ready_handoff)
    broken["rows"][0]["lods"][0]["sha256"] = broken["rows"][0]["raw"]["sha256"]
    check(validate_direction_handoff(broken), "raw/normalized LOD alias must fail")
    broken = copy.deepcopy(ready_handoff)
    broken["rows"][0]["provenance"]["direction"] = "south"
    check(validate_direction_handoff(broken), "provenance direction cross-binding must fail")
    broken = copy.deepcopy(ready_handoff)
    broken["rows"][0]["record"]["sha256"] = "7" * 64
    check(validate_direction_handoff(broken), "record/provenance hash cross-binding must fail")
    broken = copy.deepcopy(ready_handoff)
    broken["rows"][0]["provenance"]["gameplay_meaning_complete"] = False
    check(validate_direction_handoff(broken), "candidate readiness with incomplete provenance must fail")
    broken = copy.deepcopy(ready_handoff)
    broken["rows"][0]["south_reference"] = {"path": "south/other.png", "sha256": "8" * 64}
    check(validate_direction_handoff(broken), "South provenance cross-binding must fail")

    rgba = bytearray(CANVAS[0] * CANVAS[1] * 4)
    offset = (100 * CANVAS[0] + 120) * 4
    rgba[offset:offset + 4] = bytes((10, 20, 30, 255))
    width, height, normalized, report = normalize_full_canvas(CANVAS[0], CANVAS[1], rgba, registration)
    check((width, height) == CANVAS, "normalizer must preserve the full authoring canvas")
    check(normalized[offset:offset + 4] == bytes((10, 20, 30, 255)), "normalizer must not crop/rescale occupied pixels")
    check(report["scale_source"] == "CONTRACT-026-full-canvas-registration", "normalizer must report CONTRACT-026 scale")

    provenance = valid_source_provenance("residential_l01_v0", "south")
    check(not validate_provenance(provenance, require_complete=True), "complete provenance must validate")
    for field in ("prompt_text", "references", "reference_hashes", "cleanup_command", "gameplay_meaning"):
        broken_provenance = copy.deepcopy(provenance)
        if field == "references" or field == "reference_hashes":
            broken_provenance[field] = []
        else:
            broken_provenance[field] = ""
        broken_provenance[field.replace("prompt_text", "prompt_complete").replace("references", "references_complete").replace("reference_hashes", "reference_hashes_complete").replace("cleanup_command", "cleanup_complete").replace("gameplay_meaning", "gameplay_meaning_complete")] = False
        check(validate_provenance(broken_provenance, require_complete=True), f"incomplete {field} provenance must fail")
    check(set(DIRECTIONS) == {"north", "east", "south", "west"} and set(CONSUMERS) == {f"PLAY-{n:03d}" for n in range(97, 106)}, "direction or consumer set drifted")
    print("PASS: PLAY-096 V3 validator/handoff adversarial suite")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise
