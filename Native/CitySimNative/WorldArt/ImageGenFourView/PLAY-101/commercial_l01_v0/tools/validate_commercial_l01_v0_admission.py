#!/usr/bin/env python3
"""Validate immutable Commercial L1 inputs and deterministic admission outputs."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path


FAMILY = Path(__file__).resolve().parents[1]
REPO = next(parent for parent in FAMILY.parents if (parent / ".git").exists())
EVIDENCE = REPO / "docs/production/evidence/PLAY-098/commercial-l01-v0-admission"
PIPELINE_PATH = FAMILY / "tools/build_commercial_l01_v0_admission.py"
OUTPUT = FAMILY / "normalized"
BRANCH = "codex/citysim-world-art-commercial-l01-v0-admission-currente298"
START_HEAD = "fcc19a44e35db00df2a4b7eeb3154bf5f64a3f15"
CLAIM_PATH = "docs/production/claims/PLAY-098.commercial-l01-v0-admission-currente298.md"
CLAIM_SHA256 = "0b105ec9cb07df1e740b409ab7f14dda3c0ebed176efbd5d8f1b288ad30087cf"
RAW_SHA256 = {"north": "3d0f771f72525740dace420163de67f124f7f84adbcd4c2b7c34375a8f4b2fa0", "east": "ed3ae1e4c4b6198a98a3f917ad844c42e9c92c1efc9fc97af290bc6eb2bc36a8", "south": "7fb0044d1b1ae46110528cb1ee8ad82c64d755e984564e1017c91d0f54bfb51e", "west": "b28311c8c958e2e35e4999e2b5b3de200bdc6430c7a30fc40b64aa362e514b00"}
DIRECTIONS = ("north", "east", "south", "west")
LOD_SIZES = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
CANVAS = (1536, 1024)
ALLOWED_PREFIXES = ("Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/commercial_l01_v0/normalized/", "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/commercial_l01_v0/tools/build_commercial_l01_v0_admission.py", "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/commercial_l01_v0/tools/validate_commercial_l01_v0_admission.py", "docs/production/evidence/PLAY-098/commercial-l01-v0-admission/", "docs/production/completed/PLAY-098.commercial-l01-v0-admission.md")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=REPO, check=True, capture_output=True, text=True).stdout.strip()


def load_pipeline():
    spec = importlib.util.spec_from_file_location("commercial_l01_v0_admission", PIPELINE_PATH)
    if spec is None or spec.loader is None:
        raise ValueError("pipeline import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def files(root: Path) -> dict[str, str]:
    return {path.relative_to(root).as_posix(): sha256(path) for path in sorted(root.rglob("*")) if path.is_file()}


def verify_live_outputs(pipeline) -> dict:
    receipt = load(OUTPUT / "NORMALIZATION-RECEIPT.json")
    require(receipt["claim"]["sha256"] == CLAIM_SHA256, "receipt claim binding mismatch")
    require(receipt["directions"] == list(DIRECTIONS), "direction ordering mismatch")
    require(receipt["geometry"]["canvas"] == list(CANVAS), "registered canvas mismatch")
    raw_hashes, normalized_hashes, lod_hashes = [], [], []
    for direction in DIRECTIONS:
        raw = receipt["rawSources"][direction]
        raw_path = REPO / raw["path"]
        require(raw_path.is_file() and sha256(raw_path) == RAW_SHA256[direction] == raw["sha256"], f"immutable raw mismatch: {direction}")
        raw_hashes.append(raw["sha256"])
        normalized = receipt["normalizedSources"][direction]
        normalized_path = REPO / normalized["path"]
        require(normalized_path.is_file() and sha256(normalized_path) == normalized["sha256"], f"normalized hash mismatch: {direction}")
        with Image.open(normalized_path) as image:
            require(image.mode == "RGBA" and image.size == CANVAS, f"normalized dimensions mismatch: {direction}")
            observed_metrics = pipeline.metrics(image)
        for key in ("hiddenRgbPixels", "keyedMagentaPixels", "frameEdgeOpaquePixels"):
            require(observed_metrics[key] == 0, f"normalized {direction} {key}={observed_metrics[key]}")
        require(observed_metrics["visiblePixels"] > 0 and observed_metrics["nonzeroRgbPixels"] > 0, f"normalized empty: {direction}")
        normalized_hashes.append(normalized["sha256"])
        for lod, size in LOD_SIZES.items():
            row = receipt["lods"][direction][lod]
            path = REPO / row["path"]
            require(path.is_file() and sha256(path) == row["sha256"], f"lod hash mismatch: {direction}/{lod}")
            with Image.open(path) as image:
                require(image.mode == "RGBA" and image.size == size, f"lod dimensions mismatch: {direction}/{lod}")
                lod_metrics = pipeline.metrics(image)
            for key in ("hiddenRgbPixels", "keyedMagentaPixels", "frameEdgeOpaquePixels"):
                require(lod_metrics[key] == 0, f"lod {direction}/{lod} {key}={lod_metrics[key]}")
            lod_hashes.append(row["sha256"])
    require(len(set(raw_hashes)) == 4 and len(set(normalized_hashes)) == 4 and len(set(lod_hashes)) == 12, "family identity alias detected")
    handoff = load(EVIDENCE / "RENDERER-HANDOFF.json")
    require(handoff["candidateOnly"] is True and handoff["sourceAdmitted"] is False and handoff["productionSelected"] is False, "handoff boundary advanced")
    return receipt


def check() -> dict:
    from PIL import Image  # imported here so a missing dependency yields a focused error
    globals()["Image"] = Image
    require(git("branch", "--show-current") == BRANCH, "branch mismatch")
    require(git("rev-parse", "HEAD") == START_HEAD, "starting HEAD mismatch")
    require(sha256(REPO / CLAIM_PATH) == CLAIM_SHA256, "claim hash mismatch")
    for line in git("status", "--porcelain", "--untracked-files=all").splitlines():
        path = line[3:].split(" -> ")[-1]
        require(path.startswith(ALLOWED_PREFIXES), f"path outside claim: {path}")
    pipeline = load_pipeline()
    receipt = verify_live_outputs(pipeline)
    with tempfile.TemporaryDirectory(prefix="citysim-play098-commercial-a-") as first_temp, tempfile.TemporaryDirectory(prefix="citysim-play098-commercial-b-") as second_temp:
        first_root, second_root = Path(first_temp), Path(second_temp)
        for root in (first_root, second_root):
            subprocess.run([sys.executable, str(PIPELINE_PATH), "--output-root", str(root / "normalized"), "--evidence-root", str(root / "evidence")], cwd=REPO, check=True, capture_output=True, text=True)
        require(files(first_root) == files(second_root), "two-root deterministic replay mismatch")
        require(files(OUTPUT) == files(first_root / "normalized"), "live normalization differs from replay")
        expected_evidence = {name: digest for name, digest in files(first_root / "evidence").items()}
        observed_evidence = {name: digest for name, digest in files(EVIDENCE).items() if name != "VALIDATION-RESULT.json"}
        require(observed_evidence == expected_evidence, "live evidence differs from replay")
    result = {"schema": "citysim.play-098.commercial-l01-v0.admission-validation.v1", "result": "PASS", "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA256}, "counts": {"raw": 4, "normalized": 4, "lods": 12}, "gates": {"immutableRaw": "PASS", "registration": "PASS", "alphaChromaFrame": "PASS", "distinctDirections": "PASS", "deterministicReplay": "PASS", "rendererBoundary": "PASS"}, "normalizationReceipt": {"path": "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/commercial_l01_v0/normalized/NORMALIZATION-RECEIPT.json", "sha256": sha256(OUTPUT / "NORMALIZATION-RECEIPT.json")}, "candidateOnly": True, "sourceAdmitted": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False}
    (EVIDENCE / "VALIDATION-RESULT.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    print(json.dumps(check(), indent=2, sort_keys=True))
