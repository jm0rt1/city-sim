#!/usr/bin/env python3
"""Deterministic, zero-pixel Residential L1 East prelock proof."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SCENE = ROOT / "scene.json"
VIEWPORT = (1536, 1024)
ENVELOPE = (256, 96, 1280, 920)


def project(point: list[float], camera: dict) -> list[float]:
    x, y, z = point
    scale = float(camera["orthographicScale"])
    u = (x - z) / math.sqrt(2.0)
    v = y * math.cos(math.radians(camera["elevationDegrees"])) - (x + z) * math.sin(math.radians(camera["elevationDegrees"])) / math.sqrt(2.0)
    return [round(VIEWPORT[0] / 2 + u * VIEWPORT[0] / scale, 4), round(VIEWPORT[1] * 0.75 - v * VIEWPORT[1] / scale, 4)]


def corners(bounds: list[list[float]]) -> list[list[float]]:
    (x0, y0, z0), (x1, y1, z1) = bounds
    return [[x, y, z] for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]


def fail(message: str) -> None:
    raise AssertionError(message)


def validate_once() -> dict:
    raw = SCENE.read_bytes()
    scene = json.loads(raw)
    if scene["task"] != "PLAY-091" or scene["variantID"] != "variant-1" or scene["viewDirection"] != "east":
        fail("identity is not the claimed East variant-one scene")
    if scene["productionSelected"] is not False or scene["authoredIndependently"] is not True:
        fail("prelock selection/independence boundary is invalid")
    derivation = scene["derivation"]
    if derivation != {"sourceKind": "independent-east-variant-one-blockout", "siblingSource": None, "mirror": False, "rotationDegrees": 0, "transform": "none"}:
        fail("sibling derivation or transform is present")
    if scene["familyContract"]["sha256"] != "18ed6b18ed7e1ecbcaba1eb1c7fab9dffae98d670334d4ce30c33e3d1ddb7eb0":
        fail("CONTRACT-023 hash mismatch")
    registration = scene["registration"]
    if registration["tileBasisPoints"] != [72, 36] or registration["groundPivotSource"] != [768, 896]:
        fail("registration basis or pivot mismatch")
    if registration["contactPolygonWorld"] != [[-28, -28], [28, -28], [28, 28], [-28, 28]]:
        fail("authoritative contact polygon mismatch")
    if registration["frontageSocketSource"] != [896, 832] or registration["orientationTransform"] != "none":
        fail("East socket or orientation binding mismatch")
    camera = scene["camera"]
    if camera["projection"] != "orthographic-2:1" or camera["yawDegrees"] != 45 or camera["elevationDegrees"] != 30:
        fail("camera projection mismatch")
    if camera["renderViewportPixels"] != [1536, 1024] or camera["oversamplingFactor"] != 2:
        fail("camera viewport mismatch")
    entrance = scene["entrance"]
    if entrance["facadeID"] != "east-facade" or entrance["roadFacingDirection"] != "east" or entrance["baseWorld"] != [28, 3, 0]:
        fail("road-facing East entrance mismatch")
    components = scene["components"]
    ids = [item["id"] for item in components]
    if len(ids) != len(set(ids)) or len(components) < 16:
        fail("component manifest is missing or non-unique")
    required_roles = {"primary_massing", "structural_secondary_volume", "entrance_reveal", "roofline", "roof_secondary_volume", "east_window", "entrance_steps"}
    if not required_roles <= {item["role"] for item in components}:
        fail("required structural roles are absent")
    if len(scene["silhouetteBreaks"]) < 6:
        fail("insufficient silhouette breaks")
    projected: list[list[float]] = []
    for item in components:
        bounds = item["boundsWorld"]
        if len(bounds) != 2 or any(len(p) != 3 for p in bounds):
            fail(f"invalid bounds for {item['id']}")
        (x0, y0, z0), (x1, y1, z1) = bounds
        if not (x0 < x1 and y0 < y1 and z0 < z1):
            fail(f"degenerate bounds for {item['id']}")
        if x0 < -28 or x1 > 34 or z0 < -28 or z1 > 28 or y0 < 0 or y1 > 46:
            fail(f"component escapes bounded Residential L1 envelope: {item['id']}")
        projected.extend(project(point, camera) for point in corners(bounds))
    min_x = min(point[0] for point in projected)
    min_y = min(point[1] for point in projected)
    max_x = max(point[0] for point in projected)
    max_y = max(point[1] for point in projected)
    if min_x < ENVELOPE[0] or min_y < ENVELOPE[1] or max_x > ENVELOPE[2] or max_y > ENVELOPE[3]:
        fail("camera-projected occupied envelope exceeds registration envelope")
    socket_px = project([float(value) for value in entrance["baseWorld"]], camera)
    if not (socket_px[0] > 850 and 760 < socket_px[1] < 900):
        fail(f"East socket is not visible in the road-facing camera: {socket_px}")
    result = {
        "result": "PASS",
        "task": "PLAY-091",
        "stage": "predesign_ready",
        "direction": "east",
        "variant": "residential_l01/variant-1/east/source-v01",
        "sceneSha256": hashlib.sha256(raw).hexdigest(),
        "componentCount": len(components),
        "silhouetteBreakCount": len(scene["silhouetteBreaks"]),
        "occupiedEnvelopePixels": [round(min_x, 4), round(min_y, 4), round(max_x, 4), round(max_y, 4)],
        "eastSocketProjectedPixel": socket_px,
        "camera": {"projection": camera["projection"], "yawDegrees": camera["yawDegrees"], "elevationDegrees": camera["elevationDegrees"], "viewport": camera["renderViewportPixels"]},
        "pixelProduction": "not_produced",
        "dccProcesses": 0,
        "siblingInputsConsumed": []
    }
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeat", type=int, default=2)
    parser.add_argument("--compare-governed-bytes", action="store_true")
    args = parser.parse_args()
    if args.repeat < 2:
        raise SystemExit("--repeat must be at least 2")
    results = [validate_once() for _ in range(args.repeat)]
    encoded = [json.dumps(item, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode() for item in results]
    if args.compare_governed_bytes and len(set(encoded)) != 1:
        raise SystemExit("FAIL: governed replay bytes differ")
    print(json.dumps({"result": "PASS", "repeat": args.repeat, "compareGovernedBytes": args.compare_governed_bytes, "governedSha256": hashlib.sha256(encoded[0]).hexdigest(), "proof": results[0]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
