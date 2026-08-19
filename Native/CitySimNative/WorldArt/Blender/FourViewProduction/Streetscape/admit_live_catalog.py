#!/usr/bin/env python3
"""Admit validated camNE road renders into the SwiftPM live resource catalog."""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
NATIVE = HERE.parents[3]
OUTPUT = NATIVE / "Sources" / "CitySimNative" / "Resources" / "FourViewRoadAssets"
CONFIG = json.loads((HERE / "pipeline.json").read_text())
VALIDATION = HERE / "validation" / "validator-output.txt"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    if not VALIDATION.is_file() or not VALIDATION.read_text().startswith(
        "STREETSCAPE_FOUR_VIEW_VALIDATION_PASS"
    ):
        raise RuntimeError("VALIDATED_STREETSCAPE_REQUIRED")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    roads = []
    for mask in CONFIG["masks"]:
        asset_id = mask["assetId"]
        source = HERE / asset_id / "renders" / f"{asset_id}_camNE.png"
        destination = OUTPUT / source.name
        shutil.copyfile(source, destination)
        roads.append(
            {
                "connectionMask": mask["rawValue"],
                "assetID": asset_id,
                "file": destination.name,
                "sha256": sha256(destination),
            }
        )

    manifest = {
        "schema": "citysim.native-four-view-roads.v1",
        "camera": "camNE",
        "cameraAzimuthDegrees": 45,
        "cameraElevationDegrees": 30,
        "projectedTilePixels": [88, 44],
        "canvas": {
            "width": 384,
            "height": 384,
            "footprintPivotPixel": [192, 300],
        },
        "postRenderCompensation": "none",
        "roads": roads,
    }
    (OUTPUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2, separators=(",", ": ")) + "\n"
    )
    print(f"FOUR_VIEW_ROAD_ADMISSION_PASS masks={len(roads)} output={OUTPUT}")


if __name__ == "__main__":
    main()
