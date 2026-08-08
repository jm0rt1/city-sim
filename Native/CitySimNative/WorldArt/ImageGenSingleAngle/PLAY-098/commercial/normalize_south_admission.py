#!/usr/bin/env python3
"""Task-local CONTRACT-026 South normalization and deterministic receipts.

The source canvas is never cropped, trimmed, or fit to occupied pixels. The
only derived raster sizes are whole-canvas LOD resizes. This module is
mechanical admission support; it does not select or visually accept art.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from collections import deque
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parents[5]
RAW_ROOT = ROOT / "raw"
CANVAS = (1536, 1024)
GROUND_PIVOT_SOURCE = (768, 896)
FOOTPRINT_POLYGON_SOURCE = ((768, 640), (1024, 768), (768, 896), (512, 768))
FRONTAGE_SOCKETS_SOURCE = {
    "north": (896, 704),
    "east": (896, 832),
    "south": (640, 832),
    "west": (640, 704),
}
LODS = {
    "block": {"canvas": (1024, 683), "filter": "lanczos", "rounding": "round-half-even"},
    "neighborhood": {"canvas": (512, 342), "filter": "lanczos", "rounding": "round-half-even"},
    "city": {"canvas": (256, 171), "filter": "lanczos", "rounding": "round-half-even"},
}
EXPECTED = tuple(f"commercial_l{level:02d}_v{variant:02d}" for level in range(1, 5) for variant in range(3))
MAGENTA = (255, 0, 255)
ROUTE_BINDING = {
    "routeId": "four-view-v5:play-098-admission-repair",
    "routeSha256": "3f16ebf3e310afd0351e7db5524e49b96b8967b512d2b0b3532fcd5de4f55319",
    "claim": {
        "path": "docs/production/claims/PLAY-098.world-art-commercial.md",
        "sha256": "4e10676b16b40d4492ca27ce525d67c74462f16bf5755be91bdbe05984ed2517",
    },
    "authorityCommit": "65825389d586a128ddf6feb5356c33661ba9a8e8",
    "baseCommit": "a61ab80101f596f56ffc1dd7e37b32bd1b220357",
}


def pil_image_module():
    from PIL import Image

    return Image


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def round_half_even(numerator: int, denominator: int) -> int:
    """Round a non-negative rational without floating-point dependence."""
    if denominator <= 0 or numerator < 0:
        raise ValueError("round_half_even requires non-negative numerator and positive denominator")
    quotient, remainder = divmod(numerator, denominator)
    twice = remainder * 2
    if twice < denominator:
        return quotient
    if twice > denominator:
        return quotient + 1
    return quotient if quotient % 2 == 0 else quotient + 1


def map_coordinate(point: tuple[int, int], destination: tuple[int, int]) -> list[int]:
    return [
        round_half_even(point[0] * destination[0], CANVAS[0]),
        round_half_even(point[1] * destination[1], CANVAS[1]),
    ]


def registration_profile() -> dict[str, object]:
    """Return only code-owned coordinates from CONTRACT-026."""
    return {
        "sourceCanvas": list(CANVAS),
        "groundPivotSource": list(GROUND_PIVOT_SOURCE),
        "footprintPolygonSource": [list(point) for point in FOOTPRINT_POLYGON_SOURCE],
        "frontageSocketSource": {key: list(value) for key, value in FRONTAGE_SOCKETS_SOURCE.items()},
        "lods": {
            lod: {
                **profile,
                "canvas": list(profile["canvas"]),
                "groundPivot": map_coordinate(GROUND_PIVOT_SOURCE, profile["canvas"]),
                "footprintPolygon": [map_coordinate(point, profile["canvas"]) for point in FOOTPRINT_POLYGON_SOURCE],
                "frontageSockets": {key: map_coordinate(value, profile["canvas"]) for key, value in FRONTAGE_SOCKETS_SOURCE.items()},
            }
            for lod, profile in LODS.items()
        },
        "coordinateRule": "exact rational source coordinate multiplied by destination dimension divided by source dimension, independently rounded half to even",
        "forbidden": [
            "occupied-bbox-crop",
            "occupied-bbox-resize",
            "pixel-derived-pivot",
            "pixel-derived-scale",
            "pixel-derived-frontage",
            "clamping",
            "runtime-mirroring",
            "runtime-rotation",
            "fallback",
            "alias",
        ],
    }


def is_matte(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and red >= 180 and blue >= 150 and green <= 110 and red + blue >= green * 4


def remove_border_matte(image: Image.Image) -> Image.Image:
    """Remove border-connected matte while retaining the full source canvas."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not is_matte(pixels[x, y]):
            continue
        seen.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
            elif red > green * 1.35 and blue > green * 1.25:
                spill = min(red, blue) - green
                pixels[x, y] = (max(green, red - spill), green, max(green, blue - spill), alpha)
            if is_matte(pixels[x, y]):
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def zero_hidden_rgb(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def clear_residual_matte(image: Image.Image) -> Image.Image:
    rgba = zero_hidden_rgb(image)
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            if is_matte(pixels[x, y]):
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def verify_mechanical_boundaries(image: Image.Image, expected_size: tuple[int, int]) -> dict[str, object]:
    rgba = zero_hidden_rgb(image)
    if rgba.size != expected_size:
        raise ValueError(f"unexpected canvas: {rgba.size}, expected {expected_size}")
    pixels = rgba.load()
    hidden_rgb = 0
    residual_matte = 0
    for y in range(rgba.height):
        for x in range(rgba.width):
            pixel = pixels[x, y]
            if pixel[3] == 0 and pixel[:3] != (0, 0, 0):
                hidden_rgb += 1
            if is_matte(pixel):
                residual_matte += 1
    if hidden_rgb or residual_matte:
        raise ValueError(f"hidden_rgb={hidden_rgb}, residual_matte={residual_matte}")
    edge_alpha = [pixels[x, 0][3] for x in range(rgba.width)]
    edge_alpha += [pixels[x, rgba.height - 1][3] for x in range(rgba.width)]
    edge_alpha += [pixels[0, y][3] for y in range(1, rgba.height - 1)]
    edge_alpha += [pixels[rgba.width - 1, y][3] for y in range(1, rgba.height - 1)]
    if any(edge_alpha):
        raise ValueError("non-transparent frame-edge pixels")
    return {"canvas": list(expected_size), "hiddenRgbPixels": 0, "residualMattePixels": 0, "frameEdgeOpaquePixels": 0}


def require_png_header(path: Path) -> tuple[int, int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("invalid PNG signature")
    if data[12:16] != b"IHDR":
        raise ValueError("missing IHDR")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", data[16:26])
    if (width, height, bit_depth, color_type) != (CANVAS[0], CANVAS[1], 8, 2):
        raise ValueError("source must be non-interlaced 8-bit RGB 1536x1024")
    return width, height, color_type


def normalize_source(source: Path) -> Image.Image:
    Image = pil_image_module()
    require_png_header(source)
    image = Image.open(source)
    image.load()
    if image.size != CANVAS or image.mode != "RGB":
        raise ValueError(f"source must be RGB {CANVAS}, got {image.mode} {image.size}")
    return remove_border_matte(image)


def whole_canvas_lods(registered: Image.Image) -> Iterable[tuple[str, Image.Image]]:
    Image = pil_image_module()
    for lod, profile in LODS.items():
        width, height = profile["canvas"]
        yield lod, clear_residual_matte(registered.resize((width, height), Image.Resampling.LANCZOS))


def repo_relative(path: Path) -> str:
    return str(path.resolve().relative_to(REPO_ROOT))


def write_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def raw_provenance() -> dict[str, object]:
    path = REPO_ROOT / "docs" / "production" / "evidence" / "PLAY-098" / "commercial" / "RAW-PROVENANCE.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("task") != "PLAY-098" or data.get("family") != "commercial":
        raise ValueError("raw provenance task/family mismatch")
    if data.get("sourceContract", {}).get("authoringCanvas") != list(CANVAS):
        raise ValueError("raw provenance canvas mismatch")
    return data


def decoded_sha256(image: Image.Image) -> str:
    return sha256_bytes(image.convert("RGBA").tobytes())


def build_identity_record(
    logical_id: str,
    source: Path,
    output_dir: Path,
    provenance: dict[str, object],
) -> dict[str, object]:
    Image = pil_image_module()
    raw_bytes = source.read_bytes()
    source_image = Image.open(source)
    source_image.load()
    raw_decoded_hash = decoded_sha256(source_image)
    registered = normalize_source(source)
    registered_checks = verify_mechanical_boundaries(registered, CANVAS)
    identity_dir = output_dir / logical_id
    identity_dir.mkdir(parents=True, exist_ok=True)
    registered_path = identity_dir / f"{logical_id}-south-registered.png"
    registered.save(registered_path, optimize=True)
    lod_paths: dict[str, Path] = {}
    lod_records: dict[str, dict[str, object]] = {}
    for lod, image in whole_canvas_lods(registered):
        checks = verify_mechanical_boundaries(image, tuple(LODS[lod]["canvas"]))
        path = identity_dir / f"{logical_id}-south-{lod}.png"
        image.save(path, optimize=True)
        lod_paths[lod] = path
        lod_records[lod] = {
            "path": repo_relative(path),
            "sha256": sha256(path),
            "decodedSha256": decoded_sha256(image),
            "canvas": list(LODS[lod]["canvas"]),
            "format": "RGBA",
            "fullCanvas": True,
            "filter": LODS[lod]["filter"],
            "rounding": LODS[lod]["rounding"],
            "checks": checks,
        }
    provenance_record = next((item for item in provenance["records"] if item["logicalId"] == logical_id), None)
    if not isinstance(provenance_record, dict) or not provenance_record.get("identityBrief") or not provenance_record.get("toolArtifactPath"):
        raise ValueError(f"incomplete provenance for {logical_id}")
    return {
        "logicalId": logical_id,
        "routeBinding": ROUTE_BINDING,
        "direction": "south",
        "rotation": 0,
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "source": {
            "path": repo_relative(source),
            "sha256": sha256_bytes(raw_bytes),
            "bytes": len(raw_bytes),
            "canvas": list(CANVAS),
            "decodedSha256": raw_decoded_hash,
        },
        "promptProvenance": {
            "tool": provenance["tool"],
            "model": provenance["model"],
            "promptTemplate": provenance["promptTemplate"],
            "identityBrief": provenance_record["identityBrief"],
            "toolArtifactProvenanceRef": f"docs/production/evidence/PLAY-098/commercial/RAW-PROVENANCE.json#records[{logical_id}].toolArtifactPath",
            "referenceHashes": [item["sha256"] for item in provenance["references"]],
        },
        "registration": registration_profile(),
        "registered": {
            "path": repo_relative(registered_path),
            "sha256": sha256(registered_path),
            "decodedSha256": decoded_sha256(registered),
            "canvas": list(CANVAS),
            "format": "RGBA",
            "fullCanvas": True,
            "checks": registered_checks,
        },
        "lods": lod_records,
        "rawPreservedByteForByte": True,
        "fallback": False,
        "alias": False,
        "visualAcceptance": "not_performed",
        "candidateDisposition": "mechanical_only_pending_frontier_review",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", action="store_true", help="normalize all twelve Commercial South anchors")
    parser.add_argument("--output-dir", type=Path, help="task-local normalized output directory")
    parser.add_argument("--receipt-dir", type=Path, help="PLAY-098 evidence receipt directory")
    parser.add_argument("--repeat", type=int, default=1, help="deterministic replay count; South route requires 2")
    args = parser.parse_args()
    if not args.batch:
        parser.error("the published route requires --batch")
    if args.repeat != 2:
        parser.error("the published South admission route requires --repeat 2")
    if not args.output_dir or not args.receipt_dir:
        parser.error("--batch requires --output-dir and --receipt-dir")
    output_dir = args.output_dir.resolve()
    receipt_dir = args.receipt_dir.resolve()
    if not output_dir.is_relative_to(ROOT) or not receipt_dir.is_relative_to(REPO_ROOT / "docs" / "production" / "evidence" / "PLAY-098"):
        raise SystemExit("path outside claimed roots")
    provenance = raw_provenance()
    raw_before = {logical_id: sha256(RAW_ROOT / f"{logical_id}-source-v01.png") for logical_id in EXPECTED}
    replay_manifests = []
    for replay in range(args.repeat):
        records = [build_identity_record(logical_id, RAW_ROOT / f"{logical_id}-source-v01.png", output_dir, provenance) for logical_id in EXPECTED]
        manifest = {"replay": replay + 1, "records": records}
        replay_manifests.append(manifest)
    raw_after = {logical_id: sha256(RAW_ROOT / f"{logical_id}-source-v01.png") for logical_id in EXPECTED}
    if raw_before != raw_after:
        raise SystemExit("raw source changed during normalization")
    canonical_replays = [json.dumps(item["records"], sort_keys=True, separators=(",", ":")) for item in replay_manifests]
    replay_hashes = [sha256_bytes(item.encode("utf-8")) for item in canonical_replays]
    if canonical_replays[0] != canonical_replays[1]:
        raise SystemExit("deterministic replay mismatch")
    artifacts = []
    for record in replay_manifests[-1]["records"]:
        artifacts.append(record["registered"])
        artifacts.extend(record["lods"].values())
    file_hashes = [item["sha256"] for item in artifacts]
    decoded_hashes = [item["decodedSha256"] for item in artifacts]
    if len(file_hashes) != len(set(file_hashes)) or len(decoded_hashes) != len(set(decoded_hashes)):
        raise SystemExit("normalized artifact alias detected")
    for record in replay_manifests[-1]["records"]:
        write_json(receipt_dir / f"{record['logicalId']}-south-record.json", record)
    write_json(receipt_dir / "south-admission-profile.json", {"task": "PLAY-098", "routeBinding": ROUTE_BINDING, "direction": "south", "rotation": 0, "productionSelected": False, "candidateReadyForIndependentReview": True, "sourceReady": False, "integrationAdmitted": False, "rendererQuarantined": False, "registration": registration_profile()})
    write_json(receipt_dir / "south-admission-receipt.json", {
        "task": "PLAY-098",
        "routeBinding": ROUTE_BINDING,
        "family": "commercial",
        "direction": "south",
        "rotation": 0,
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "identityCount": len(EXPECTED),
        "lodsPerIdentity": len(LODS),
        "rawPreservedByteForByte": True,
        "rawSha256": raw_after,
        "replayCount": args.repeat,
        "replaySha256": replay_hashes,
        "replaysIdentical": True,
        "uniqueNormalizedFileSha256": len(set(file_hashes)),
        "uniqueNormalizedDecodedSha256": len(set(decoded_hashes)),
        "visualAcceptance": "not_performed",
        "records": [record["logicalId"] for record in replay_manifests[-1]["records"]],
    })
    print(json.dumps({"status": "PASS", "identities": len(EXPECTED), "lods": len(EXPECTED) * len(LODS), "replays": args.repeat, "replaysIdentical": True, "productionSelected": False}, indent=2))


if __name__ == "__main__":
    main()
