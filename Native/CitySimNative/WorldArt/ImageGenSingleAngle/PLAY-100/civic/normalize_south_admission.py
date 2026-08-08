#!/usr/bin/env python3
"""Deterministic, task-local CONTRACT-026 South admission pipeline."""

from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
REPO = next(parent for parent in ROOT.parents if (parent / ".git").exists())
RAW_ROOT = ROOT / "raw"
PROVENANCE = ROOT / "provenance" / "RAW-PROVENANCE.json"
PROFILE = REPO / "docs/production/decisions/CONTRACT-026-registration-profiles-v1.json"
CLAIM = REPO / "docs/production/claims/PLAY-100.world-art-civic.md"
CONTRACT = REPO / "docs/production/decisions/CONTRACT-026-authored-four-view-registration.md"
EVIDENCE_ROOT = REPO / "docs/production/evidence/PLAY-100"
NORMALIZED_ROOT = ROOT / "normalized"

SOURCE_SIZE = (1536, 1024)
LOD_SIZES = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
EXPECTED_IDS = ["park", "power-plant", "water-tower", "fire-station", "police-station", "school", "city-hall"]
ROUTE_ID = "four-view-v4:play-100-south-admission-repair"
ROUTE_SHA256 = "fe585feeb286a7e0efd030877ab946af479276bd4406053b6e1c944c8016db34"
WORKER_HEAD = "f956b54685707b7ecbb34d30c96aef2242e9f375"
AUTHORITY_COMMIT = "65825389d586a128ddf6feb5356c33661ba9a8e8"
PUBLISHED_BASE = "a61ab80101f596f56ffc1dd7e37b32bd1b220357"
CLAIM_SHA256 = "0c4bce350a2538a768e5e3b51baa76c3e6b0a81a27f31ca4d640e8e844d05a2d"
CONTRACT_SHA256 = "4781de72429a1f691b9226f7f7668b170b278a4ccd171ac4ea02f5e1df9176eb"
PROFILE_SHA256 = "6663482339e953bdcbcb86bcfc876676989fbcb7f74a91f3f1b480d124fe3bd8"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rel(path: Path) -> str:
    value = path.resolve().relative_to(REPO.resolve()).as_posix()
    if value.startswith("/") or ".." in Path(value).parts:
        raise ValueError(f"non-repository path: {path}")
    return value


def assert_repo_relative(value: object) -> None:
    if isinstance(value, dict):
        for child in value.values():
            assert_repo_relative(child)
    elif isinstance(value, list):
        for child in value:
            assert_repo_relative(child)
    elif isinstance(value, str) and (value.startswith("/") or "generated_images" in value):
        raise ValueError(f"path-dependent artifact value: {value}")


def is_keyed_magenta(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = pixel
    return green <= 100 and red >= 150 and blue >= 120 and red >= green * 3 and blue >= green * 2


def normalize(source: Path, destination: Path, size: tuple[int, int]) -> dict[str, object]:
    with Image.open(source) as opened:
        opened.load()
        if opened.size != SOURCE_SIZE or opened.mode not in {"RGB", "RGBA"}:
            raise ValueError(f"source format mismatch: {source}")
        image = opened.convert("RGBA")

    pixels = list(image.get_flattened_data())
    keyed = 0
    hidden_alpha = 0
    transformed: list[tuple[int, int, int, int]] = []
    for pixel in pixels:
        red, green, blue, alpha = pixel
        if is_keyed_magenta(pixel):
            keyed += 1
            transformed.append((0, 0, 0, 0))
        else:
            if alpha == 0 and (red or green or blue):
                hidden_alpha += 1
            transformed.append(pixel)
    if hidden_alpha:
        raise ValueError(f"hidden RGB in source alpha: {source}")
    keyed_image = Image.new("RGBA", SOURCE_SIZE)
    keyed_image.putdata(transformed)
    resized = keyed_image.resize(size, Image.Resampling.LANCZOS)
    resized_pixels = list(resized.get_flattened_data())
    post_keyed = 0
    cleaned: list[tuple[int, int, int, int]] = []
    for pixel in resized_pixels:
        red, green, blue, alpha = pixel
        if alpha == 0 or is_keyed_magenta(pixel):
            if is_keyed_magenta(pixel):
                post_keyed += 1
            cleaned.append((0, 0, 0, 0))
        else:
            cleaned.append(pixel)
    cleaned_image = Image.new("RGBA", size)
    cleaned_image.putdata(cleaned)
    cleaned_image.save(destination, format="PNG", optimize=False, compress_level=9)

    with Image.open(destination) as written:
        written.load()
        if written.mode != "RGBA" or written.size != size:
            raise ValueError(f"normalized RGBA/size mismatch: {destination}")
        output = list(written.get_flattened_data())
    visible = sum(1 for _r, _g, _b, alpha in output if alpha)
    transparent = sum(1 for red, green, blue, alpha in output if not alpha and (red or green or blue))
    hidden_chroma = sum(1 for pixel in output if pixel[3] and is_keyed_magenta(pixel))
    edge_pixels = []
    width, height = size
    for x in range(width):
        edge_pixels.extend([output[x], output[(height - 1) * width + x]])
    for y in range(height):
        edge_pixels.extend([output[y * width], output[y * width + width - 1]])
    edge_visible = sum(1 for _r, _g, _b, alpha in edge_pixels if alpha)
    if transparent or hidden_chroma or edge_visible:
        raise ValueError(f"normalized alpha/chroma/edge failure: {destination}")
    destination_path = None
    try:
        destination_path = rel(destination)
    except ValueError:
        pass
    return {
        "path": destination_path,
        "sha256": sha256(destination),
        "dimensions": list(size),
        "mode": "RGBA",
        "filter": "lanczos",
        "keyedMagentaPixelsRemoved": keyed + post_keyed,
        "visiblePixels": visible,
        "transparentPixels": len(output) - visible,
        "hiddenChromaPixels": hidden_chroma,
        "hiddenRGBInTransparentPixels": transparent,
        "visibleEdgePixels": edge_visible,
        "alphaCheck": "PASS",
        "chromaCheck": "PASS",
        "edgeCheck": "PASS",
    }


def assert_artifact_semantics(records: list[dict[str, object]], raw_hashes: list[str], normalized_hashes: list[str]) -> None:
    if len(raw_hashes) != len(set(raw_hashes)) or len(normalized_hashes) != len(set(normalized_hashes)):
        raise ValueError("raw or normalized alias detected")
    if set(raw_hashes) & set(normalized_hashes):
        raise ValueError("raw/normalized hash alias detected")
    if len(records) != len(EXPECTED_IDS) or [record["identity"] for record in records] != EXPECTED_IDS:
        raise ValueError("identity coverage mismatch")
    for record in records:
        if record["direction"] != "south" or record["registration"]["orientationTransform"] != "none":
            raise ValueError("direction or orientation semantic mismatch")
        if record["sourceReady"] or record["integrationAdmitted"] or record["rendererQuarantined"] or record["productionSelected"]:
            raise ValueError("readiness boundary advanced")
        assert_repo_relative(record)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", default=str(NORMALIZED_ROOT))
    args = parser.parse_args()
    output_root = Path(args.output_root).resolve()

    profile = json.loads(PROFILE.read_text())
    provenance = json.loads(PROVENANCE.read_text())
    if profile["sourceCanvas"] != list(SOURCE_SIZE):
        raise ValueError("CONTRACT-026 source canvas drift")
    if sha256(CLAIM) != CLAIM_SHA256 or sha256(CONTRACT) != CONTRACT_SHA256 or sha256(PROFILE) != PROFILE_SHA256:
        raise ValueError("authority hash drift")
    identities = provenance["identities"]
    if [item["id"] for item in identities] != EXPECTED_IDS:
        raise ValueError("identity order or coverage mismatch")

    output_root.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    raw_hashes: list[str] = []
    normalized_hashes: list[str] = []
    with tempfile.TemporaryDirectory(prefix="play-100-south-repair-replay-") as replay_dir:
        replay_root = Path(replay_dir)
        for item in identities:
            identity = item["id"]
            raw = REPO / item["rawPath"]
            raw_hash = sha256(raw)
            if raw_hash != item["rawSha256"]:
                raise ValueError(f"raw byte drift: {identity}")
            raw_hashes.append(raw_hash)
            lods: dict[str, object] = {}
            for lod, size in LOD_SIZES.items():
                destination = output_root / identity / f"{identity}-{lod}.png"
                replay_destination = replay_root / identity / destination.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                replay_destination.parent.mkdir(parents=True, exist_ok=True)
                first = normalize(raw, destination, size)
                second = normalize(raw, replay_destination, size)
                if first["sha256"] != second["sha256"]:
                    raise ValueError(f"deterministic replay mismatch: {identity}/{lod}")
                first["repeatSha256"] = second["sha256"]
                first["deterministicReplay"] = True
                first["registration"] = {
                    "groundPivot": [
                        round_half_even(profile["groundPivotSource"][0] * size[0], SOURCE_SIZE[0]),
                        round_half_even(profile["groundPivotSource"][1] * size[1], SOURCE_SIZE[1]),
                    ],
                    "footprint": [
                        [round_half_even(point[0] * size[0], SOURCE_SIZE[0]), round_half_even(point[1] * size[1], SOURCE_SIZE[1])]
                        for point in profile["footprintPolygonSource"]
                    ],
                    "southSocket": [
                        round_half_even(profile["frontageSocketSource"]["south"][0] * size[0], SOURCE_SIZE[0]),
                        round_half_even(profile["frontageSocketSource"]["south"][1] * size[1], SOURCE_SIZE[1]),
                    ],
                }
                lods[lod] = first
                normalized_hashes.append(first["sha256"])
            record = {
                "task": "PLAY-100",
                "family": "civic/service",
                "identity": identity,
                "direction": "south",
                "raw": {"path": item["rawPath"], "sha256": raw_hash, "dimensions": list(SOURCE_SIZE), "mode": "RGB"},
                "prompt": item["identityPrompt"],
                "southReference": {"kind": "preserved_raw_south_anchor", "path": item["rawPath"], "sha256": raw_hash},
                "provenance": {"path": rel(PROVENANCE), "complete": True, "promptPresent": bool(item["identityPrompt"])},
                "profile": {"path": rel(PROFILE), "sha256": PROFILE_SHA256},
                "registration": {
                    "sourceCanvas": list(SOURCE_SIZE),
                    "groundPivotSource": profile["groundPivotSource"],
                    "footprintPolygonSource": profile["footprintPolygonSource"],
                    "southSocketSource": profile["frontageSocketSource"]["south"],
                    "orientationTransform": "none",
                    "geometrySource": "code-owned-contract-metadata",
                    "pixelDerivedGeometry": False,
                },
                "lods": lods,
                "disposition": "mechanically_registered_candidate",
                "candidateReadyForIndependentReview": True,
                "sourceReady": False,
                "integrationAdmitted": False,
                "rendererQuarantined": False,
                "productionSelected": False,
            }
            assert_repo_relative(record)
            receipt_path = output_root / identity / "registration-receipt.json"
            receipt_path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
            records.append(record)

    assert_artifact_semantics(records, raw_hashes, normalized_hashes)
    receipt_entries = []
    for record in records:
        receipt_path = output_root / record["identity"] / "registration-receipt.json"
        receipt_entries.append({
            "identity": record["identity"],
            "rawSha256": record["raw"]["sha256"],
            "receiptPath": rel(receipt_path),
            "receiptSha256": sha256(receipt_path),
            "candidateReadyForIndependentReview": True,
        })

    summary = {
        "schema": "citysim.play-100.south-admission-repair.v4",
        "task": "PLAY-100",
        "family": "civic/service",
        "direction": "south",
        "routeId": ROUTE_ID,
        "routeSha256": ROUTE_SHA256,
        "workerHead": WORKER_HEAD,
        "authorityCommit": AUTHORITY_COMMIT,
        "publishedBase": PUBLISHED_BASE,
        "claim": {"path": rel(CLAIM), "sha256": CLAIM_SHA256},
        "contract": {"path": rel(CONTRACT), "sha256": CONTRACT_SHA256},
        "profile": {"path": rel(PROFILE), "sha256": PROFILE_SHA256},
        "rawPreserved": True,
        "rawCount": len(records),
        "uniqueRawHashes": len(set(raw_hashes)),
        "uniqueNormalizedHashes": len(set(normalized_hashes)),
        "identities": [record["identity"] for record in records],
        "normalization": {
            "decoder": "Pillow",
            "sourceMode": "RGB",
            "outputMode": "RGBA",
            "keyedMagentaRemoval": True,
            "filter": "lanczos",
            "cropOrTrim": False,
            "pixelDerivedGeometry": False,
            "rotationOrMirror": False,
        },
        "checks": {"hiddenChroma": "PASS", "alpha": "PASS", "edge": "PASS", "semanticArtifacts": "PASS", "deterministicReplay": "PASS"},
        "receiptsRoot": rel(output_root),
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }
    assert_repo_relative(summary)
    EVIDENCE_ROOT.mkdir(parents=True, exist_ok=True)
    summary_path = EVIDENCE_ROOT / "south-admission.json"
    records_path = EVIDENCE_ROOT / "south-admission-records.json"
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    records_path.write_text(json.dumps(records, indent=2, sort_keys=True) + "\n")

    handoff = {
        "schema": "citysim.play-100.direction-handoff.v4",
        "task": "PLAY-100",
        "family": "civic/service",
        "direction": "south",
        "stage": "south_admission_candidate",
        "branch": "codex/citysim-world-art-civic",
        "worktree": ".",
        "authorityCommit": AUTHORITY_COMMIT,
        "publishedBase": PUBLISHED_BASE,
        "workerHead": WORKER_HEAD,
        "route": {"id": ROUTE_ID, "sha256": ROUTE_SHA256},
        "claim": {"path": rel(CLAIM), "sha256": CLAIM_SHA256},
        "familyContract": {"path": rel(CONTRACT), "sha256": CONTRACT_SHA256},
        "registrationProfile": {"path": rel(PROFILE), "sha256": PROFILE_SHA256},
        "directionRootMap": {
            "raw": rel(RAW_ROOT),
            "normalized": rel(output_root),
            "evidence": rel(EVIDENCE_ROOT),
            "handoff": rel(EVIDENCE_ROOT / "south-handoff.json"),
        },
        "artifacts": {"summary": rel(summary_path), "records": rel(records_path), "receipts": receipt_entries},
        "siblingInputsConsumed": [],
        "pixelGeneration": "not_run",
        "deterministicReplay": True,
        "visualAcceptance": "not_claimed",
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "knownBlockers": ["independent frontier visual and technical review", "Integration admission"],
    }
    assert_repo_relative(handoff)
    (EVIDENCE_ROOT / "south-handoff.json").write_text(json.dumps(handoff, indent=2, sort_keys=True) + "\n")
    return 0


def round_half_even(numerator: int, denominator: int) -> int:
    quotient, remainder = divmod(numerator, denominator)
    doubled = remainder * 2
    if doubled < denominator:
        return quotient
    if doubled > denominator:
        return quotient + 1
    return quotient if quotient % 2 == 0 else quotient + 1


if __name__ == "__main__":
    raise SystemExit(main())
