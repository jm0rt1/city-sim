#!/usr/bin/env python3
"""Validate PLAY-027 reference hashes and deterministic contact registration."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


REPOSITORY_ROOT = Path(__file__).resolve().parents[6]
EXPECTED_DIRECTIONS = ["north", "east", "south", "west"]
EXPECTED_CANVAS = [1536, 1024]
EXPECTED_FOOTPRINT = [
    [768, 640],
    [1024, 768],
    [768, 896],
    [512, 768],
]
EXPECTED_PIVOT = [768, 896]
EXPECTED_BACKGROUND = (255, 0, 255)
EXPECTED_TARGET = (42, 236, 116)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def midpoint(a: list[int], b: list[int]) -> list[float]:
    return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    failures: list[str] = []
    template_results = []
    seen_hashes: set[str] = set()

    if manifest.get("productionSelected") is not False:
        failures.append("reference treatment must remain non-shipping")
    if manifest.get("rejectedPixelsUsed") is not False:
        failures.append("reference treatment may not use rejected pixels")
    if manifest.get("canvasPixels") != EXPECTED_CANVAS:
        failures.append("manifest canvas differs from 1536x1024")
    if manifest.get("groundPivotSource") != EXPECTED_PIVOT:
        failures.append("manifest pivot differs from 768x896")

    templates = manifest.get("templates", [])
    if [item.get("viewDirection") for item in templates] != EXPECTED_DIRECTIONS:
        failures.append("direction inventory/order must be north,east,south,west")

    for record in templates:
        direction = record["viewDirection"]
        path = REPOSITORY_ROOT / record["file"]
        digest = sha256(path)
        image = Image.open(path).convert("RGB")
        edge = record["frontageEdgeSource"]
        socket = record["frontageSocketSource"]
        door = record["doorBaseSource"]
        edge_midpoint = midpoint(edge[0], edge[1])
        door_midpoint = midpoint(door[0], door[1])
        sample = tuple(record["targetEdgePixelSample"])
        corners = [
            image.getpixel((0, 0)),
            image.getpixel((image.width - 1, 0)),
            image.getpixel((0, image.height - 1)),
            image.getpixel((image.width - 1, image.height - 1)),
        ]
        result_failures = []
        if digest != record["sha256"]:
            result_failures.append("sha256 mismatch")
        if digest in seen_hashes:
            result_failures.append("template hash aliases another direction")
        seen_hashes.add(digest)
        if list(image.size) != EXPECTED_CANVAS:
            result_failures.append("canvas mismatch")
        if record["footprintPolygonSource"] != EXPECTED_FOOTPRINT:
            result_failures.append("footprint polygon mismatch")
        if record["groundPivotSource"] != EXPECTED_PIVOT:
            result_failures.append("ground pivot mismatch")
        if record["orientationTransform"] != "none":
            result_failures.append("orientationTransform is not none")
        if record["productionSelected"] is not False:
            result_failures.append("template marked production selected")
        if socket != edge_midpoint:
            result_failures.append("frontage socket is not the edge midpoint")
        if door_midpoint != edge_midpoint:
            result_failures.append("door base is not centered on the frontage socket")
        if any(pixel != EXPECTED_BACKGROUND for pixel in corners):
            result_failures.append("canvas corner is not flat #ff00ff")
        if image.getpixel(sample) != EXPECTED_TARGET:
            result_failures.append("declared target edge sample is not target green")
        failures.extend(f"{direction}: {item}" for item in result_failures)
        template_results.append(
            {
                "viewDirection": direction,
                "file": record["file"],
                "sha256": digest,
                "frontageEdgeSource": edge,
                "frontageSocketSource": socket,
                "doorBaseSource": door,
                "groundPivotSource": record["groundPivotSource"],
                "cornerRGB": [list(pixel) for pixel in corners],
                "targetEdgePixelSample": list(sample),
                "targetEdgePixelRGB": list(image.getpixel(sample)),
                "failures": result_failures,
            }
        )

    board_record = manifest["materialScaleBoard"]
    board_path = REPOSITORY_ROOT / board_record["file"]
    board_digest = sha256(board_path)
    board = Image.open(board_path).convert("RGB")
    board_failures = []
    if board_digest != board_record["sha256"]:
        board_failures.append("material board sha256 mismatch")
    if list(board.size) != EXPECTED_CANVAS:
        board_failures.append("material board canvas mismatch")
    if board_record["cameraCompositionAuthority"] is not False:
        board_failures.append("material board claims camera authority")
    if board_record["registrationAuthority"] is not False:
        board_failures.append("material board claims registration authority")
    if board_record["orientationTransform"] != "none":
        board_failures.append("material board orientationTransform is not none")
    if board_record["productionSelected"] is not False:
        board_failures.append("material board marked production selected")
    source_anchor = REPOSITORY_ROOT / board_record["sourceFamilyAnchorFile"]
    if sha256(source_anchor) != board_record["sourceFamilyAnchorSHA256"]:
        board_failures.append("source family anchor sha256 mismatch")
    failures.extend(f"material board: {item}" for item in board_failures)

    report = {
        "schema": 1,
        "task": "PLAY-027",
        "treatmentID": manifest["treatmentID"],
        "manifestFile": str(args.manifest),
        "manifestSHA256": sha256(args.manifest),
        "templates": template_results,
        "materialScaleBoard": {
            "file": board_record["file"],
            "sha256": board_digest,
            "sourceFamilyAnchorSHA256": board_record["sourceFamilyAnchorSHA256"],
            "failures": board_failures,
        },
        "uniqueTemplateHashes": len(seen_hashes),
        "expectedTemplateHashes": len(EXPECTED_DIRECTIONS),
        "failures": failures,
        "passed": not failures,
        "productionSelected": False,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if failures:
        raise SystemExit("\n".join(failures))


if __name__ == "__main__":
    main()
