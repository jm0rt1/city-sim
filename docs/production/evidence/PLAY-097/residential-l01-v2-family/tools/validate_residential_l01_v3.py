#!/usr/bin/env python3
"""PLAY-097 v03 source-admission, geometry, and deterministic replay validator."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import tempfile
from pathlib import Path


EVIDENCE = Path(__file__).resolve().parents[1]
REPO = next(parent for parent in EVIDENCE.parents if (parent / ".git").exists())
FAMILY = REPO / "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/residential_l01_v2"
PIPELINE_PATH = FAMILY / "tools/build_residential_l01_v3.py"
OUTPUT = FAMILY / "normalized-v03"
BRANCH = "codex/citysim-world-art-residential-l01-v2-current88ea"
HEAD = "514d14746076d67170a0ce37b584381c8c00a3c0"
CLAIM_PATH = "docs/production/claims/PLAY-097.world-art-residential-l01-v2-current88ea.md"
CLAIM_SHA = "c9e58426ab4b8b88b87a9ba1cb7b55286c27bb9396f762e8e64afcde6039bdf4"
ALLOWED_PREFIXES = (
    "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/residential_l01_v2/",
    "docs/production/evidence/PLAY-097/residential-l01-v2-family/",
    "docs/production/completed/PLAY-097.residential-l01-v2-family.md",
)
DIRECTIONS = ("south", "north", "east", "west")
LOD_SIZES = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
CANVAS = (1536, 1024)
RAW_SIZE = (1774, 887)
PIVOT = [768, 896]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=REPO, check=True, capture_output=True, text=True).stdout.strip()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load_pipeline():
    spec = importlib.util.spec_from_file_location("residential_l01_v3_pipeline", PIPELINE_PATH)
    if spec is None or spec.loader is None:
        raise ValueError("v03 pipeline import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def api_smoke() -> dict:
    pipeline = load_pipeline()
    normalized_path = OUTPUT / "source/north.png"
    require(normalized_path.is_file(), f"missing normalized smoke input: {normalized_path}")
    width, height, channels, pixels = pipeline.BASE.decode_png(normalized_path)
    require((width, height, channels) == (*CANVAS, 4), "pipeline decoder smoke shape mismatch")
    metrics = pipeline.BASE.rgba_metrics(CANVAS, pixels)
    require(metrics["visiblePixels"] > 0 and metrics["nonzeroRgbPixels"] > 0, "pipeline metrics smoke empty")
    return {"result": "PASS", "decoder": "pipeline.BASE.decode_png", "metrics": "pipeline.BASE.rgba_metrics"}


def snapshot_live_paths() -> dict[str, str]:
    paths = {}
    for root in (OUTPUT, EVIDENCE):
        for path in root.rglob("*"):
            if path.is_file():
                paths[path.relative_to(REPO).as_posix()] = sha256(path)
    return paths


def replay_interface_smoke() -> dict:
    pipeline = load_pipeline()
    before = snapshot_live_paths()
    with tempfile.TemporaryDirectory(prefix="citysim-play097-v03-direction-a-") as first_temp, tempfile.TemporaryDirectory(prefix="citysim-play097-v03-direction-b-") as second_temp:
        first = pipeline.build_direction("south", Path(first_temp))
        second = pipeline.build_direction("south", Path(second_temp))
        require(first["generatedFiles"] == second["generatedFiles"], "direction replay logical IDs mismatch")
        require(first["normalized"]["path"] == second["normalized"]["path"] and first["normalized"]["sha256"] == second["normalized"]["sha256"], "direction replay normalized mismatch")
        for lod in LOD_SIZES:
            require(first["lods"][lod]["path"] == second["lods"][lod]["path"] and first["lods"][lod]["sha256"] == second["lods"][lod]["sha256"], f"direction replay LOD mismatch: {lod}")
    require(snapshot_live_paths() == before, "direction replay changed live candidate paths")
    return {"result": "PASS", "direction": "south", "generatedFiles": first["generatedFiles"]}


def canonical_generated_ids(pipeline, generated_files: list[str]) -> list[str]:
    prefix = f"{pipeline.LOGICAL_NORMALIZED_ROOT}/"
    canonical = []
    for generated_file in generated_files:
        canonical.append(generated_file if generated_file.startswith(prefix) else prefix + generated_file)
    return sorted(canonical)


def check() -> dict:
    require(git("branch", "--show-current") == BRANCH, "branch mismatch")
    require(git("rev-parse", "HEAD") == HEAD, "starting HEAD mismatch")
    require(sha256(REPO / CLAIM_PATH) == CLAIM_SHA, "claim hash mismatch")
    status_paths = []
    for line in git("status", "--porcelain", "--untracked-files=all").splitlines():
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        status_paths.append(path)
    unexpected = [path for path in status_paths if not path.startswith(ALLOWED_PREFIXES)]
    require(not unexpected, f"path outside claim: {unexpected[0] if unexpected else ''}")

    pipeline = load_pipeline()
    receipt_path = OUTPUT / "NORMALIZATION-RECEIPT.json"
    provenance_path = OUTPUT / "PROVENANCE.json"
    admission_path = EVIDENCE / "SOURCE-ADMISSION-RECEIPT-V03.json"
    matrix_path = EVIDENCE / "MATRIX-SELECTION-V03.json"
    registration_path = EVIDENCE / "REGISTRATION-REPORT-V03.json"
    for path in (receipt_path, provenance_path, admission_path, matrix_path, registration_path):
        require(path.is_file(), f"missing evidence: {path}")
    receipt = load(receipt_path)
    provenance = load(provenance_path)
    admission = load(admission_path)
    matrix = load(matrix_path)
    registration = load(registration_path)
    require(receipt["claim"]["sha256"] == CLAIM_SHA, "receipt claim binding mismatch")
    require(receipt["baseHead"] == HEAD, "receipt base mismatch")
    require(receipt["directions"] == list(DIRECTIONS), "direction order mismatch")
    require(admission["normalizationReceipt"]["sha256"] == sha256(receipt_path), "admission receipt mismatch")
    require(admission["candidateOnly"] is True and admission["sourceAdmitted"] is False, "admission boundary advanced")
    require(matrix["rawCount"] == 4 and matrix["normalizedCount"] == 4 and matrix["lodCount"] == 12, "matrix counts mismatch")
    require(matrix["uniqueRaw"] == 4 and matrix["uniqueNormalized"] == 4 and matrix["uniqueLod"] == 12, "matrix uniqueness mismatch")
    require(registration["result"] == "PASS" and tuple(registration["canvas"]) == CANVAS and registration["pivot"] == PIVOT, "registration geometry mismatch")

    source_candidate = load(FAMILY / "visual-repair-v03/SOURCE-CANDIDATE-PROVENANCE.json")
    raw_hashes = {}
    for direction in DIRECTIONS:
        raw = receipt["rawSources"][direction]
        raw_path = REPO / raw["path"]
        require(raw_path.is_file(), f"missing raw source: {direction}")
        require(tuple(raw["dimensions"]) == RAW_SIZE and raw["mode"] == "RGB", f"raw shape mismatch: {direction}")
        observed = sha256(raw_path)
        require(observed == raw["sha256"], f"raw hash mismatch: {direction}")
        require(observed == source_candidate["rawMasters"][direction]["sha256"], f"raw provenance mismatch: {direction}")
        raw_hashes[direction] = observed
    require(len(set(raw_hashes.values())) == 4, "raw alias or duplicate")

    normalized_hashes = []
    lod_hashes = []
    for direction in DIRECTIONS:
        normalized = receipt["normalizedSources"][direction]
        normalized_path = REPO / normalized["path"]
        require(normalized_path.is_file() and sha256(normalized_path) == normalized["sha256"], f"normalized hash mismatch: {direction}")
        width, height, channels, pixels = pipeline.BASE.decode_png(normalized_path)
        require((width, height, channels) == (*CANVAS, 4), f"normalized shape mismatch: {direction}")
        metrics = pipeline.BASE.rgba_metrics(CANVAS, pixels)
        for key in ("hiddenRgbPixels", "keyedMagentaPixels", "boundaryResidualChromaPixels", "frameEdgeOpaquePixels"):
            require(metrics[key] == 0, f"normalized {direction} {key}={metrics[key]}")
        require(metrics["visiblePixels"] > 0 and metrics["nonzeroRgbPixels"] > 0, f"normalized empty: {direction}")
        normalized_hashes.append(normalized["sha256"])
        for lod, size in LOD_SIZES.items():
            row = receipt["lods"][direction][lod]
            path = REPO / row["path"]
            require(path.is_file() and sha256(path) == row["sha256"], f"LOD hash mismatch: {direction}/{lod}")
            lod_width, lod_height, lod_channels, lod_pixels = pipeline.BASE.decode_png(path)
            require((lod_width, lod_height, lod_channels) == (*size, 4), f"LOD shape mismatch: {direction}/{lod}")
            lod_metrics = pipeline.BASE.rgba_metrics(size, lod_pixels)
            for key in ("hiddenRgbPixels", "keyedMagentaPixels", "boundaryResidualChromaPixels", "frameEdgeOpaquePixels"):
                require(lod_metrics[key] == 0, f"LOD {direction}/{lod} {key}={lod_metrics[key]}")
            require(lod_metrics["visiblePixels"] > 0 and lod_metrics["nonzeroRgbPixels"] > 0, f"LOD empty: {direction}/{lod}")
            lod_hashes.append(row["sha256"])
    require(len(set(normalized_hashes)) == 4, "normalized alias or duplicate")
    require(len(lod_hashes) == 12 and len(set(lod_hashes)) == 12, "LOD alias or duplicate")

    for key, row in receipt["contactSheets"].items():
        path = REPO / row["path"]
        require(path.is_file() and sha256(path) == row["sha256"], f"contact sheet mismatch: {key}")
    require(provenance["candidateOnly"] is True and provenance["sourceAdmitted"] is False, "provenance boundary advanced")
    require(provenance["mirrored"] is False and provenance["rotated"] is False and provenance["copiedPixels"] is False, "provenance transform boundary failed")

    with tempfile.TemporaryDirectory(prefix="citysim-play097-v03-replay-") as temp:
        replay_root = Path(temp)
        replay = pipeline.build_outputs(replay_root)
        expected_generated = canonical_generated_ids(pipeline, receipt["generatedFiles"])
        require(replay["generatedFiles"] == expected_generated, "replay inventory mismatch")
        prefix = f"{pipeline.LOGICAL_NORMALIZED_ROOT}/"
        for logical_id in expected_generated:
            require(logical_id.startswith(prefix), f"replay logical ID outside normalized root: {logical_id}")
            relative = logical_id[len(prefix):]
            current = OUTPUT / relative
            replay_path = replay_root / relative
            require(sha256(current) == sha256(replay_path), f"deterministic replay mismatch: {relative}")

    result = {
        "schema": "citysim.play-097.residential-l01-v2.validation-v03.v1",
        "result": "PASS",
        "branch": BRANCH,
        "head": HEAD,
        "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA},
        "counts": {"rawSources": 4, "normalizedSources": 4, "lodPayloads": 12, "uniqueLodPayloads": 12},
        "gates": {"identity": "PASS", "rawHashes": "PASS", "normalization": "PASS", "geometry": "PASS", "alphaChroma": "PASS", "uniqueness": "PASS", "deterministicReplay": "PASS", "candidateOnlyBoundary": "PASS"},
        "sourceAdmitted": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }
    (EVIDENCE / "VALIDATION-RESULT-V03.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    print(json.dumps(check(), indent=2, sort_keys=True))
