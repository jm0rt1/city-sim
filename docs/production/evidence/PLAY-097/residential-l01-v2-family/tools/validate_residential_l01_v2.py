#!/usr/bin/env python3
"""Focused deterministic candidate-family validator for residential_l01_v2."""

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
PIPELINE_PATH = FAMILY / "tools/build_residential_l01_v2.py"
BASELINE = "f978602eaa3e9cf7abf11f845a206976bb9ff7a1"
BRANCH = "codex/citysim-world-art-residential-l01-v2-current88ea"
ALLOWED_PREFIXES = (
    "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/residential_l01_v2/",
    "docs/production/evidence/PLAY-097/residential-l01-v2-family/",
    "docs/production/completed/PLAY-097.residential-l01-v2-family.md",
)
CONTRACTS = {
    "docs/production/decisions/CONTRACT-025-authored-four-view-2-5d-building-art.md": "4e8ab63173d67581332e7d27730b97315906fda4e29b999969456441809479ed",
    "docs/production/decisions/CONTRACT-026-registration-profiles-v1.json": "6663482339e953bdcbcb86bcfc876676989fbcb7f74a91f3f1b480d124fe3bd8",
    "docs/production/decisions/CONTRACT-028-alpha-aware-lod-chroma.md": "f8b80a98b07029a51b8e61701c85017bd82c8bb0b6c967da6d1fa7fae631da7d",
    "docs/production/claims/PLAY-097.world-art-residential-l01-v2-current88ea.md": "c9e58426ab4b8b88b87a9ba1cb7b55286c27bb9396f762e8e64afcde6039bdf4",
}
RAW_HASHES = {
    "south": "984aeffd2cee62634ebc78055b3ef15953cf0df139b56d8346fcddac1750fed3",
    "north": "3ec18582da6857745c30a2fdc1f6493433923fff32561083f98d4b7c55a58287",
    "east": "b21f38755f9d90c1b0b77967e0411d92d874cfe6b39c91ef8a5d2e9f698533d1",
    "west": "6582215392012f504ff603d769338097eee8a698744460c96ee3076ea0282caf",
}
PRIOR_FAMILY_RAW_HASHES = {
    "a808c5da11450418afa26505261cac196480d7d98578e2e8ac796288c7ee0e57",
    "ef1dab1277f0c2dd6cd3a37a1e459e94c417b013fadda5f4f46b6b21187e3577",
    "ec8da7e13befac3abd5e3f242168649fb91b3cc59061a0e9122596329f97b1f3",
    "1661eeebe01dbfeb0bf5b443ebe61f1ed850e5650258917b09b24d2de03bdab2",
    "49657d70488a1478b384c035c73b7551653ffb1f2549fcf20134bed55f622386",
}
BUILD_RECEIPT_SHA256 = "0fab7d130646cbc5e21131976373987067f3a36ff07c321e2c3e81f31b45180c"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=REPO, check=True, capture_output=True, text=True
    ).stdout.strip()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load_pipeline():
    spec = importlib.util.spec_from_file_location("residential_l01_v2_pipeline", PIPELINE_PATH)
    if spec is None or spec.loader is None:
        raise ValueError("pipeline import failed")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check() -> dict:
    require(git("branch", "--show-current") == BRANCH, "branch mismatch")
    require(git("rev-parse", "HEAD") == BASELINE, "baseline HEAD mismatch")
    require(git("merge-base", "--is-ancestor", BASELINE, "HEAD") == "", "baseline ancestry mismatch")
    for relative, expected in CONTRACTS.items():
        require(sha256(REPO / relative) == expected, f"authority hash mismatch: {relative}")

    status_paths = []
    for line in git("status", "--porcelain", "--untracked-files=all").splitlines():
        artifact_path = line[3:]
        if " -> " in artifact_path:
            artifact_path = artifact_path.split(" -> ", 1)[1]
        status_paths.append(artifact_path)
    unexpected = [
        artifact_path for artifact_path in status_paths
        if not artifact_path.startswith(ALLOWED_PREFIXES)
    ]
    require(not unexpected, f"unexpected dirty path: {unexpected[0] if unexpected else ''}")

    pipeline = load_pipeline()
    receipt_path = FAMILY / "BUILD-RECEIPT.json"
    require(sha256(receipt_path) == BUILD_RECEIPT_SHA256, "build receipt hash mismatch")
    receipt = load(receipt_path)
    require(receipt["schema"] == "citysim.play-097.residential-l01-v2.build.v1", "receipt schema mismatch")
    require(receipt["family"] == "residential_l01_v2", "receipt family mismatch")
    require(receipt["directions"] == ["south", "north", "east", "west"], "direction order mismatch")
    observed_raw = {direction: row["sha256"] for direction, row in receipt["rawSources"].items()}
    require(observed_raw == RAW_HASHES, "raw hash inventory mismatch")
    require(len(set(observed_raw.values())) == 4, "raw alias or duplicate")
    require(not (set(observed_raw.values()) & PRIOR_FAMILY_RAW_HASHES), "raw reused from variant zero or one")

    lod_hashes: list[str] = []
    for direction in ("south", "north", "east", "west"):
        for lod, size in pipeline.LOD_SIZES.items():
            row = receipt["lods"][direction][lod]
            path = FAMILY / row["path"]
            require(path.is_file() and sha256(path) == row["sha256"], f"{direction} {lod} hash mismatch")
            width, height, channels, pixels = pipeline.decode_png(path)
            require((width, height, channels) == (*size, 4), f"{direction} {lod} shape mismatch")
            metrics = pipeline.rgba_metrics(size, pixels)
            for key in (
                "hiddenRgbPixels",
                "keyedMagentaPixels",
                "boundaryResidualChromaPixels",
                "frameEdgeOpaquePixels",
            ):
                require(metrics[key] == 0, f"{direction} {lod} {key}={metrics[key]}")
            require(metrics["visiblePixels"] > 0 and metrics["nonzeroRgbPixels"] > 0, f"{direction} {lod} empty")
            lod_hashes.append(row["sha256"])
    require(len(lod_hashes) == 12 and len(set(lod_hashes)) == 12, "LOD alias or duplicate")

    for direction in ("south", "north", "east", "west"):
        provenance = load(FAMILY / f"provenance/{direction}.json")
        require(provenance["family"] == "residential_l01_v2", f"{direction} provenance family mismatch")
        require(provenance["direction"] == direction, f"{direction} provenance direction mismatch")
        require(provenance["raw"]["sha256"] == RAW_HASHES[direction], f"{direction} provenance hash mismatch")
        require(provenance["siblingInputsConsumed"] == [] and provenance["transformations"] == [], f"{direction} alias boundary mismatch")
        require(provenance["candidateReadyForIndependentReview"] is True, f"{direction} candidate flag missing")
        for flag in ("sourceReady", "integrationAdmitted", "rendererQuarantined", "productionSelected"):
            require(provenance[flag] is False, f"{direction} packet advanced {flag}")
    for direction in ("north", "east", "west"):
        require((FAMILY / f"prompts/{direction}-prompt-v01.md").is_file(), f"{direction} prompt missing")

    rejected = load(FAMILY / "REJECTED-ATTEMPTS.json")
    require(rejected["rejectedAttempts"] == [] and rejected["boundedRepairConsumed"] is False, "rejection ledger mismatch")
    normalization = load(FAMILY / "NORMALIZATION-RECEIPT.json")
    require(normalization["buildReceipt"]["sha256"] == BUILD_RECEIPT_SHA256, "normalization receipt binding mismatch")
    require(normalization["lodPayloads"] == 12 and normalization["uniqueLodPayloads"] == 12, "normalization count mismatch")
    for key in ("hiddenRgbPixels", "keyedMagentaPixels", "frameEdgeOpaquePixels"):
        require(normalization[key] == 0, f"normalization {key} mismatch")

    selection = load(EVIDENCE / "MATRIX-SELECTION.json")
    require(selection["selection"]["result"] == "MATERIALLY_DISTINCT", "matrix distinctness missing")
    registration = load(EVIDENCE / "REGISTRATION-REPORT.json")
    require(registration["result"] == "PASS", "registration report did not pass")
    require(registration["canvas"] == [1536, 1024] and registration["pivot"] == [768, 896], "registration profile mismatch")
    require(
        {name: row["dimensions"] for name, row in registration["lodRegistration"].items()}
        == {"block": [1024, 683], "city": [256, 171], "neighborhood": [512, 342]},
        "registration LOD dimensions mismatch",
    )
    review = load(EVIDENCE / "VISUAL-DISPOSITION.json")
    require(review["decision"] == "PASS_CANDIDATE_FAMILY", "visual disposition did not pass")
    require(review["sourceAdmitted"] is False, "worker self-admitted source family")
    for sheet in review["sheets"].values():
        require(sha256(REPO / sheet["path"]) == sheet["sha256"], "visual sheet hash mismatch")
    for flag in ("integrationAdmitted", "rendererQuarantined", "productionSelected"):
        require(review[flag] is False, f"visual disposition advanced {flag}")

    with tempfile.TemporaryDirectory(prefix="citysim-play097-residential-l01-v2-") as temp:
        replay_root = Path(temp)
        replay = pipeline.build_outputs(replay_root)
        require(replay["generatedFiles"] == receipt["generatedFiles"], "replay file inventory mismatch")
        for relative in receipt["generatedFiles"]:
            require(
                sha256(replay_root / relative) == sha256(FAMILY / relative),
                f"deterministic replay mismatch: {relative}",
            )

    return {
        "schema": "citysim.play-097.residential-l01-v2.validation.v1",
        "result": "PASS",
        "baselineCommit": BASELINE,
        "branch": BRANCH,
        "family": "residential_l01_v2",
        "counts": {"rawSources": 4, "directions": 4, "lodPayloads": 12, "uniqueLodPayloads": 12},
        "gates": {
            "authorityAndScope": "PASS",
            "rawProvenance": "PASS",
            "independentDirectionHashes": "PASS",
            "dimensionsAndModes": "PASS",
            "registrationProfile": "PASS",
            "contract028ChromaAndAlpha": "PASS",
            "deterministicReplay": "PASS",
            "nonAliasAndPriorVariantUniqueness": "PASS",
            "literalScaleVisualDisposition": "PASS",
            "candidateOnlyBoundary": "PASS"
        },
        "sourceAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "buildReceiptSha256": BUILD_RECEIPT_SHA256,
    }


def main() -> int:
    result = check()
    output = EVIDENCE / "VALIDATION-RESULT.json"
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
