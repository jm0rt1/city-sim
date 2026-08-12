#!/usr/bin/env python3
"""Validate the isolated PLAY-113 Civic L1 source packet and replay it twice."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image


FAMILY = Path(__file__).resolve().parents[1]
REPO = next(parent for parent in FAMILY.parents if (parent / ".git").exists())
OUTPUT = FAMILY / "normalized"
EVIDENCE = REPO / "docs/production/evidence/PLAY-113/civic-l01-v0-family"
PIPELINE = FAMILY / "tools/build_civic_l01_v0.py"
DIRECTIONS = ("north", "east", "south", "west")
LODS = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
CANVAS = (1536, 1024)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files(root: Path) -> dict[str, str]:
    return {path.relative_to(root).as_posix(): sha256(path) for path in sorted(root.rglob("*")) if path.is_file()}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load_pipeline():
    spec = importlib.util.spec_from_file_location("civic_pipeline", PIPELINE)
    if spec is None or spec.loader is None:
        raise ValueError("pipeline import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate() -> dict[str, object]:
    pipeline = load_pipeline()
    receipt = json.loads((OUTPUT / "NORMALIZATION-RECEIPT.json").read_text())
    require(receipt["directions"] == list(DIRECTIONS), "direction order mismatch")
    raw_hashes, normalized_hashes, lod_hashes = [], [], []
    for direction in DIRECTIONS:
        raw = receipt["rawSources"][direction]
        raw_path = REPO / raw["path"]
        require(raw_path.is_file() and sha256(raw_path) == raw["sha256"], f"raw hash mismatch: {direction}")
        with Image.open(raw_path) as image:
            rgb = image.convert("RGB")
            edge = [rgb.getpixel((x, y)) for x, y in [(0, 0), (rgb.width - 1, 0), (0, rgb.height - 1), (rgb.width - 1, rgb.height - 1)]]
        require(all(pipeline.keyed(*pixel) for pixel in edge), f"raw chroma frame mismatch: {direction}")
        raw_hashes.append(raw["sha256"])
        source = receipt["normalizedSources"][direction]
        source_path = REPO / source["path"]
        require(source_path.is_file() and sha256(source_path) == source["sha256"], f"normalized hash mismatch: {direction}")
        with Image.open(source_path) as image:
            require(image.mode == "RGBA" and image.size == CANVAS, f"normalized canvas mismatch: {direction}")
            report = pipeline.metrics(image)
        require(report["visiblePixels"] > 0 and report["nonzeroRgbPixels"] > 0, f"normalized empty: {direction}")
        require(all(report[key] == 0 for key in ("hiddenRgbPixels", "keyedMagentaPixels", "frameEdgeOpaquePixels")), f"normalized alpha/chroma/frame defect: {direction}")
        normalized_hashes.append(source["sha256"])
        for lod, size in LODS.items():
            row = receipt["lods"][direction][lod]
            path = REPO / row["path"]
            require(path.is_file() and sha256(path) == row["sha256"], f"lod hash mismatch: {direction}/{lod}")
            with Image.open(path) as image:
                require(image.mode == "RGBA" and image.size == size, f"lod dimensions mismatch: {direction}/{lod}")
                report = pipeline.metrics(image)
            require(report["visiblePixels"] > 0 and report["nonzeroRgbPixels"] > 0, f"lod empty: {direction}/{lod}")
            require(all(report[key] == 0 for key in ("hiddenRgbPixels", "keyedMagentaPixels", "frameEdgeOpaquePixels")), f"lod alpha/chroma/frame defect: {direction}/{lod}")
            lod_hashes.append(row["sha256"])
    require(len(set(raw_hashes)) == 4, "raw identity alias")
    require(len(set(normalized_hashes)) == 4, "normalized direction alias")
    require(len(set(lod_hashes)) == 12, "lod identity alias")
    with tempfile.TemporaryDirectory(prefix="citysim-play113-civic-a-") as first, tempfile.TemporaryDirectory(prefix="citysim-play113-civic-b-") as second:
        roots = [Path(first), Path(second)]
        for root in roots:
            subprocess.run([sys.executable, str(PIPELINE), "--output-root", str(root / "normalized"), "--evidence-root", str(root / "evidence")], cwd=REPO, check=True, capture_output=True, text=True)
        require(files(roots[0]) == files(roots[1]), "isolated replay mismatch")
        require(files(OUTPUT) == files(roots[0] / "normalized"), "live normalization differs from replay")
        require(files(EVIDENCE) == {name: digest for name, digest in files(roots[0] / "evidence").items()} | ({"VALIDATION-RESULT.json": sha256(EVIDENCE / "VALIDATION-RESULT.json")} if (EVIDENCE / "VALIDATION-RESULT.json").is_file() else {}), "live evidence differs from replay")
    result = {"schema": "citysim.play-113.civic-l01-v0.validation.v1", "result": "PASS", "task": "PLAY-113", "family": "civic_l01_v0", "counts": {"raw": 4, "normalized": 4, "lods": 12}, "gates": {"fourIndependentRoadFacingViews": "PASS", "fixedRegistration": "PASS", "alphaChromaFrame": "PASS", "directionDistinctness": "PASS", "isolatedDeterministicReplay": "PASS", "rendererBoundary": "PASS"}, "candidateOnly": True, "sourceAdmitted": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False}
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "VALIDATION-RESULT.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    return result


if __name__ == "__main__":
    print(json.dumps(validate(), indent=2, sort_keys=True))
