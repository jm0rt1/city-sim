#!/usr/bin/env python3
"""Run the bounded PLAY-096 calibration, schema, and deterministic replay gate."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from four_view_harness import ROUTE_ID, ROUTE_SHA256, TASK, inventory_document, repo_root, run_repair, validate_direction_handoff, validate_handoff_json_schema, validate_inventory


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeat", type=int, default=2)
    args = parser.parse_args()
    inventory = inventory_document()
    errors = validate_inventory(inventory)
    if errors:
        raise SystemExit("FAIL: " + "; ".join(errors))
    root = repo_root()
    evidence_root = root / "docs/production/evidence/PLAY-096"
    receipt = run_repair(args.repeat, evidence_root)
    handoff = json.loads((evidence_root / "four-view-repair/direction-handoff.json").read_text(encoding="utf-8"))
    handoff_errors = validate_direction_handoff(handoff)
    if handoff_errors:
        raise SystemExit("FAIL: " + "; ".join(handoff_errors))
    schema_errors = validate_handoff_json_schema(handoff)
    if schema_errors:
        raise SystemExit("FAIL: JSON Schema: " + "; ".join(schema_errors))
    if receipt["route_id"] != ROUTE_ID or receipt["route_sha256"] != ROUTE_SHA256:
        raise SystemExit("FAIL: route binding drift")
    if receipt["task"] != TASK or not receipt["fresh_root_comparison"]["byte_identical"] or receipt["fresh_root_comparison"].get("materialized_repository_roots") != 2:
        raise SystemExit("FAIL: receipt binding or deterministic replay failure")
    print(json.dumps({
        "status": "PASS",
        "task": TASK,
        "identity_count": inventory["identity_count"],
        "direction_count": inventory["direction_count"],
        "route_id": receipt["route_id"],
        "route_sha256": receipt["route_sha256"],
        "replays": 2,
        "product_art_generated": receipt["product_art_generated"],
        "fresh_root_byte_identical": receipt["fresh_root_comparison"]["byte_identical"],
        "materialized_repository_roots": receipt["fresh_root_comparison"]["materialized_repository_roots"],
        "integration_admitted": receipt["integration_admitted"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
