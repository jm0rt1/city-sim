#!/usr/bin/env python3
"""Focused deterministic family admission validator for residential_l01_v1."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import tempfile
from pathlib import Path


EVIDENCE = Path(__file__).resolve().parents[1]
REPO = next(parent for parent in EVIDENCE.parents if (parent / ".git").exists())
FAMILY = REPO / "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/residential_l01_v1"
PIPELINE_PATH = FAMILY / "tools/build_residential_l01_v1.py"
BASELINE = "69a82cfbf2145fc4ff0f81a8bcec8903d016bc01"
BRANCH = "codex/citysim-world-art-next-tranche-current69a8"
ALLOWED_ROOTS = (
    "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/residential_l01_v1/",
    "docs/production/evidence/PLAY-101/residential-l01-v1-family/",
)
CONTRACTS = {
    "docs/production/decisions/CONTRACT-025-authored-four-view-2-5d-building-art.md": "4e8ab63173d67581332e7d27730b97315906fda4e29b999969456441809479ed",
    "docs/production/decisions/CONTRACT-026-registration-profiles-v1.json": "6663482339e953bdcbcb86bcfc876676989fbcb7f74a91f3f1b480d124fe3bd8",
    "docs/production/decisions/CONTRACT-028-alpha-aware-lod-chroma.md": "f8b80a98b07029a51b8e61701c85017bd82c8bb0b6c967da6d1fa7fae631da7d",
}
RAW_HASHES = {
    "south": "ef1dab1277f0c2dd6cd3a37a1e459e94c417b013fadda5f4f46b6b21187e3577",
    "north": "1661eeebe01dbfeb0bf5b443ebe61f1ed850e5650258917b09b24d2de03bdab2",
    "east": "ec8da7e13befac3abd5e3f242168649fb91b3cc59061a0e9122596329f97b1f3",
    "west": "49657d70488a1478b384c035c73b7551653ffb1f2549fcf20134bed55f622386",
}
BUILD_RECEIPT_SHA256 = "9d8360f997bee2125e8223de36c709f2bc7f79ab68a63b5f2cac138134a7e95b"


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
    spec = importlib.util.spec_from_file_location("residential_l01_v1_pipeline", PIPELINE_PATH)
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
        require(sha256(REPO / relative) == expected, f"contract hash mismatch: {relative}")

    status_paths = []
    for line in git("status", "--porcelain", "--untracked-files=all").splitlines():
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        status_paths.append(path)
    unexpected = [path for path in status_paths if not path.startswith(ALLOWED_ROOTS)]
    require(not unexpected, f"unexpected dirty path: {unexpected[0] if unexpected else ''}")

    pipeline = load_pipeline()
    receipt_path = FAMILY / "BUILD-RECEIPT.json"
    require(sha256(receipt_path) == BUILD_RECEIPT_SHA256, "build receipt hash mismatch")
    receipt = load(receipt_path)
    require(receipt["family"] == "residential_l01_v1", "receipt family mismatch")
    require(receipt["directions"] == ["south", "north", "east", "west"], "direction order mismatch")
    observed_raw = {direction: row["sha256"] for direction, row in receipt["rawSources"].items()}
    require(observed_raw == RAW_HASHES, "raw hash inventory mismatch")
    require(len(set(observed_raw.values())) == 4, "raw alias or duplicate")

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

    for direction in ("north", "east", "west"):
        provenance = load(FAMILY / f"provenance/{direction}.json")
        require(provenance["family"] == "residential_l01_v1", f"{direction} provenance family mismatch")
        require(provenance["direction"] == direction, f"{direction} provenance direction mismatch")
        require(provenance["raw"]["sha256"] == RAW_HASHES[direction], f"{direction} provenance hash mismatch")
        require(provenance["siblingInputsConsumed"] == [] and provenance["transformations"] == [], f"{direction} alias boundary mismatch")
        require(provenance["candidateReadyForIndependentReview"] is True, f"{direction} candidate flag missing")
        for flag in ("sourceReady", "integrationAdmitted", "rendererQuarantined", "productionSelected"):
            require(provenance[flag] is False, f"{direction} direction packet advanced {flag}")

    review = load(EVIDENCE / "VISUAL-REVIEW.json")
    require(review["decision"] == "PASS", "visual review did not pass")
    for sheet in review["sheets"].values():
        require(sha256(REPO / sheet["path"]) == sheet["sha256"], "visual sheet hash mismatch")
    admission = load(EVIDENCE / "FAMILY-ADMISSION.json")
    require(admission["decision"] == "ADMIT_SOURCE_FAMILY", "source admission decision mismatch")
    require(admission["sourceAdmitted"] is True, "source family not admitted")
    for flag in ("integrationAdmitted", "rendererQuarantined", "productionSelected", "runtimeSelectorReady"):
        require(admission[flag] is False, f"family boundary advanced {flag}")

    with tempfile.TemporaryDirectory(prefix="citysim-play101-residential-l01-v1-") as temp:
        replay_root = Path(temp)
        replay = pipeline.build_outputs(replay_root)
        require(replay["generatedFiles"] == receipt["generatedFiles"], "replay file inventory mismatch")
        for relative in receipt["generatedFiles"]:
            require(
                sha256(replay_root / relative) == sha256(FAMILY / relative),
                f"deterministic replay mismatch: {relative}",
            )

    return {
        "schema": "citysim.play-101.residential-l01-v1.validation.v1",
        "result": "PASS",
        "baselineCommit": BASELINE,
        "branch": BRANCH,
        "family": "residential_l01_v1",
        "counts": {"rawSources": 4, "directions": 4, "lodPayloads": 12, "uniqueLodPayloads": 12},
        "gates": {
            "authorityAndScope": "PASS",
            "rawProvenance": "PASS",
            "independentDirectionHashes": "PASS",
            "dimensionsAndModes": "PASS",
            "contract028ChromaAndAlpha": "PASS",
            "deterministicReplay": "PASS",
            "nonAlias": "PASS",
            "visualReview": "PASS",
            "sourceFamilyAdmission": "PASS",
        },
        "rendererQuarantined": False,
        "productionSelected": False,
        "runtimeSelectorReady": False,
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
