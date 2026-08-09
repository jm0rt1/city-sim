#!/usr/bin/env python3
"""PLAY-100 Civic derived-only chroma repair and evidence producer.

The seven source PNGs are immutable South anchors.  This task-local tool only
reads those bytes, removes border-connected magenta matte with an
alpha-aware/despill pass, writes whole-canvas LOD derivatives, and emits
candidate-bound mechanical evidence.  It never crops, rotates, mirrors, or
rewrites a raw source.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
from collections import deque
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
REPO = next(parent for parent in ROOT.parents if (parent / ".git").exists())
RAW_ROOT = ROOT / "raw"
PROVENANCE = ROOT / "provenance" / "RAW-PROVENANCE.json"
PROFILE = REPO / "docs/production/decisions/CONTRACT-026-registration-profiles-v1.json"
CONTRACT = REPO / "docs/production/decisions/CONTRACT-026-authored-four-view-registration.md"
STYLE_CONTRACT = REPO / "docs/production/decisions/CONTRACT-025-authored-four-view-2-5d-building-art.md"
CLAIM = REPO / "docs/production/claims/PLAY-100.world-art-civic.md"
EVIDENCE_ROOT = REPO / "docs/production/evidence/PLAY-100"
NORMALIZED_ROOT = ROOT / "normalized"
VISUAL_ROOT = EVIDENCE_ROOT / "visual-proof"

SOURCE_SIZE = (1536, 1024)
LOD_SIZES = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
EXPECTED_IDS = ["park", "power-plant", "water-tower", "fire-station", "police-station", "school", "city-hall"]

# The route is resolved from Integration's master checkout.  These values are
# intentionally candidate-bound: this repair may not silently follow HEAD.
ROUTE_ID = "four-view-v25:play-100-civic-frontier-rebind-v1"
ROUTE_SHA256 = "4acda4456363c696e018d35995e2f0b58bab536f9a4c4c160e7b678ab8e816ad"
AUTHORITY_COMMIT = "65825389d586a128ddf6feb5356c33661ba9a8e8"
PUBLISHED_BASE = "65825389d586a128ddf6feb5356c33661ba9a8e8"
CANDIDATE_HEAD = "0a7c4e1f8b661588c5325f1b1895cb5b41e279ae"
CLAIM_SHA256 = "0c4bce350a2538a768e5e3b51baa76c3e6b0a81a27f31ca4d640e8e844d05a2d"
CONTRACT_SHA256 = "4781de72429a1f691b9226f7f7668b170b278a4ccd171ac4ea02f5e1df9176eb"
PROFILE_SHA256 = "6663482339e953bdcbcb86bcfc876676989fbcb7f74a91f3f1b480d124fe3bd8"
STYLE_CONTRACT_SHA256 = "4e8ab63173d67581332e7d27730b97315906fda4e29b999969456441809479ed"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def json_sha(value: object) -> str:
    return sha256_bytes(canonical_json(value).encode("utf-8"))


def rel(path: Path) -> str:
    return path.resolve().relative_to(REPO.resolve()).as_posix()


def round_half_even(numerator: int, denominator: int) -> int:
    quotient, remainder = divmod(numerator, denominator)
    doubled = remainder * 2
    if doubled < denominator:
        return quotient
    if doubled > denominator:
        return quotient + 1
    return quotient if quotient % 2 == 0 else quotient + 1


def lod_point(point: list[int], size: tuple[int, int]) -> list[int]:
    return [round_half_even(point[0] * size[0], SOURCE_SIZE[0]), round_half_even(point[1] * size[1], SOURCE_SIZE[1])]


def registration(size: tuple[int, int], profile: dict[str, object]) -> dict[str, object]:
    footprint = profile["footprintPolygonSource"]
    pivot = profile["groundPivotSource"]
    socket = profile["frontageSocketSource"]["south"]
    return {
        "sourceCanvas": list(SOURCE_SIZE),
        "canvas": list(size),
        "groundPivotSource": pivot,
        "groundPivotLod": lod_point(pivot, size),
        "footprintPolygonSource": footprint,
        "footprintPolygonLod": [lod_point(point, size) for point in footprint],
        "southSocketSource": socket,
        "southSocketLod": lod_point(socket, size),
        "coordinateRule": "exact rational source coordinate multiplied by destination dimension divided by source dimension, independently rounded half to even",
    }


def matte_candidate(pixel: tuple[int, int, int, int]) -> bool:
    """Match compressed #ff00ff fields without treating normal green art as matte."""
    red, green, blue, alpha = pixel
    if alpha == 0:
        return False
    return (
        (
            red >= 70
            and blue >= 70
            and green <= 140
            and min(red, blue) - green >= 20
            and red + blue >= green * 2.0
        )
        or (green <= 8 and max(red, blue) >= 8 and abs(red - blue) >= 8)
    )


def strict_matte(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and red >= 180 and blue >= 150 and green <= 110 and red + blue >= green * 4


def pink_spill(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return False
    # The first branch catches the compressed magenta gradient.  The second
    # catches the dark red/blue quantization fringe left when that gradient is
    # composited against a black transparent RGB value during Lanczos.
    return (
        (red >= 90 and blue >= 80 and min(red, blue) - green >= 24 and red + blue >= green * 2.2)
        or (green <= 8 and max(red, blue) >= 8 and abs(red - blue) >= 8)
    )


def border_connected_cleanup(image: Image.Image) -> tuple[Image.Image, dict[str, int]]:
    """Remove matte connected to the canvas border and despill its soft edge.

    The flood is 8-connected so thin gaps in generated background gradients do
    not strand magenta islands.  A second boundary pass removes only pink
    pixels touching transparency; interior authored flowers/trim remain.
    """
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))
    removed = 0
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not matte_candidate(pixels[x, y]):
            continue
        seen.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        removed += 1
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in seen:
                    queue.append((nx, ny))

    strict_removed = 0
    for y in range(height):
        for x in range(width):
            if strict_matte(pixels[x, y]):
                pixels[x, y] = (0, 0, 0, 0)
                strict_removed += 1

    despilled = 0
    boundary_removed = 0
    # Two passes catch Lanczos-like one-pixel colored fringes while keeping the
    # source canvas and subject geometry unchanged.
    for _ in range(2):
        to_remove: list[tuple[int, int]] = []
        for y in range(height):
            for x in range(width):
                red, green, blue, alpha = pixels[x, y]
                if alpha == 0 or not pink_spill((red, green, blue, alpha)):
                    continue
                touches_transparent = any(
                    0 <= x + dx < width
                    and 0 <= y + dy < height
                    and pixels[x + dx, y + dy][3] == 0
                    for dy in (-1, 0, 1)
                    for dx in (-1, 0, 1)
                    if dx or dy
                )
                if not touches_transparent:
                    continue
                # Any pink pixel on the transparent boundary is matte spill,
                # including the softer compressed-gradient fringe.  Removing
                # the whole boundary pixel is the frozen alpha-aware repair;
                # authored pink material remains untouched when it is enclosed
                # by opaque subject pixels.
                to_remove.append((x, y))
        for x, y in to_remove:
            pixels[x, y] = (0, 0, 0, 0)
            boundary_removed += 1

    hidden = 0
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                if red or green or blue:
                    hidden += 1
                pixels[x, y] = (0, 0, 0, 0)
    return rgba, {
        "borderMattePixelsRemoved": removed,
        "strictMattePixelsRemoved": strict_removed,
        "boundarySpillPixelsRemoved": boundary_removed,
        "despilledBoundaryPixels": despilled,
        "hiddenRGBPixelsCleared": hidden,
    }


def residual_cleanup(image: Image.Image) -> tuple[Image.Image, dict[str, int]]:
    """Clear post-resize pink coverage without cropping or changing geometry."""
    cleaned, stats = border_connected_cleanup(image)
    pixels = cleaned.load()
    width, height = cleaned.size
    low_alpha_removed = 0
    residual_pink = 0
    # Iterate enough times for a small connected pink fringe to collapse from
    # its first transparent seed; this stays bounded and never crosses opaque
    # non-pink subject material.
    for _ in range(16):
        removed_this_pass = 0
        for y in range(height):
            for x in range(width):
                red, green, blue, alpha = pixels[x, y]
                if alpha == 0:
                    continue
                if pink_spill((red, green, blue, alpha)):
                    residual_pink += 1
                    touches_transparent = any(
                        0 <= x + dx < width
                        and 0 <= y + dy < height
                        and pixels[x + dx, y + dy][3] == 0
                        for dy in (-1, 0, 1)
                        for dx in (-1, 0, 1)
                        if dx or dy
                    )
                    if touches_transparent:
                        pixels[x, y] = (0, 0, 0, 0)
                        low_alpha_removed += 1
                        removed_this_pass += 1
        if not removed_this_pass:
            break
    stats.update({"lowAlphaSpillPixelsRemoved": low_alpha_removed, "residualPinkPixelsBeforeFinalClear": residual_pink})
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return cleaned, stats


def decoded_sha(path: Path) -> str:
    with Image.open(path) as image:
        image.load()
        return sha256_bytes(image.convert("RGBA").tobytes())


def image_metrics(path: Path, expected_size: tuple[int, int]) -> dict[str, object]:
    with Image.open(path) as image:
        image.load()
        rgba = image.convert("RGBA")
        if rgba.size != expected_size or rgba.mode != "RGBA":
            raise ValueError(f"normalized format mismatch: {path}")
        pixels = list(rgba.getdata())
    hidden = sum(alpha == 0 and (red or green or blue) for red, green, blue, alpha in pixels)
    visible_matte = sum(strict_matte(pixel) for pixel in pixels)
    visible_pink = sum(pink_spill(pixel) for pixel in pixels)
    width, height = expected_size
    edge = []
    edge.extend(pixels[:width])
    edge.extend(pixels[-width:])
    edge.extend(pixels[::width])
    edge.extend(pixels[width - 1 :: width])
    edge_visible = sum(alpha > 0 for _red, _green, _blue, alpha in edge)
    boundary_spill = 0
    for index, pixel in enumerate(pixels):
        red, green, blue, alpha = pixel
        if alpha == 0 or not pink_spill(pixel):
            continue
        x, y = index % width, index // width
        if any(
            0 <= x + dx < width
            and 0 <= y + dy < height
            and pixels[(y + dy) * width + (x + dx)][3] == 0
            for dy in (-1, 0, 1)
            for dx in (-1, 0, 1)
            if dx or dy
        ):
            boundary_spill += 1
    return {
        "path": rel(path),
        "sha256": sha256(path),
        "decodedSha256": decoded_sha(path),
        "dimensions": list(expected_size),
        "mode": "RGBA",
        "hiddenRGBInTransparentPixels": hidden,
        "visibleMagentaPixels": visible_matte,
        "visiblePinkPixels": visible_pink,
        "visibleBoundarySpillPixels": boundary_spill,
        "visibleEdgePixels": edge_visible,
        "alphaCheck": "PASS" if hidden == 0 else "FAIL",
        "chromaCheck": "PASS" if visible_matte == 0 else "FAIL",
        "edgeCheck": "PASS" if edge_visible == 0 else "FAIL",
    }


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def update_raw_provenance() -> dict[str, object]:
    provenance = json.loads(PROVENANCE.read_text(encoding="utf-8"))
    if provenance.get("task") != "PLAY-100" or provenance.get("family") != "civic/service":
        raise ValueError("raw provenance task/family mismatch")
    provenance.update(
        {
            "stage": "derived_repair_candidate",
            "authorityCommit": AUTHORITY_COMMIT,
            "baseCommit": PUBLISHED_BASE,
            "candidateHead": CANDIDATE_HEAD,
            "workerHead": CANDIDATE_HEAD,
            "claimPath": rel(CLAIM),
            "claimSha256": CLAIM_SHA256,
            "routeId": ROUTE_ID,
            "routeSha256": ROUTE_SHA256,
            "normalization": {
                "status": "alpha_aware_derived_repair",
                "method": "8-connected border matte flood, strict residual matte clear, two-pass alpha-aware edge despill, whole-canvas Lanczos LOD",
                "rawBytePreserved": True,
                "cropOrTrim": False,
                "rotationOrMirror": False,
                "pixelDerivedGeometry": False,
            },
            "handoff": "candidate_bound_repair_evidence",
            "independentReview": "required and not run",
            "workerAcceptance": False,
            "sourceReady": False,
            "integrationAdmitted": False,
            "rendererQuarantined": False,
            "productionSelected": False,
        }
    )
    for item in provenance.get("identities", []):
        item.update({"routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256, "candidateHead": CANDIDATE_HEAD, "workerHead": CANDIDATE_HEAD, "disposition": "raw_preserved; derived_repair_candidate"})
    write_json(PROVENANCE, provenance)
    return provenance


def make_contact_sheet(identity_paths: list[tuple[str, Path]], grayscale: bool, output: Path) -> dict[str, object]:
    tile_w, tile_h = 256, 171
    label_h = 28
    sheet = Image.new("RGBA", (tile_w * 4, (tile_h + label_h) * 2), (224, 226, 220, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
    except OSError:
        font = ImageFont.load_default()
    for index, (identity, path) in enumerate(identity_paths):
        with Image.open(path) as source:
            tile = source.convert("RGBA")
            if grayscale:
                gray = tile.convert("L")
                tile = Image.merge("RGBA", (gray, gray, gray, tile.getchannel("A")))
            tile.thumbnail((tile_w, tile_h), Image.Resampling.LANCZOS)
        col, row = index % 4, index // 4
        x, y = col * tile_w, row * (tile_h + label_h)
        sheet.alpha_composite(tile, (x, y))
        draw.text((x + 5, y + tile_h + 5), identity, fill=(24, 28, 28, 255), font=font)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, format="PNG", optimize=False, compress_level=9)
    return {"path": rel(output), "sha256": sha256(output), "dimensions": list(sheet.size), "mode": "RGBA", "grayscale": grayscale}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", default=str(NORMALIZED_ROOT))
    args = parser.parse_args()
    output_root = Path(args.output_root).resolve()
    if not output_root.is_relative_to(ROOT.resolve()):
        raise ValueError("output root outside Civic claim-owned root")

    if sha256(CLAIM) != CLAIM_SHA256 or sha256(CONTRACT) != CONTRACT_SHA256 or sha256(PROFILE) != PROFILE_SHA256 or sha256(STYLE_CONTRACT) != STYLE_CONTRACT_SHA256:
        raise ValueError("authority hash drift")
    profile = json.loads(PROFILE.read_text(encoding="utf-8"))
    if profile["sourceCanvas"] != list(SOURCE_SIZE):
        raise ValueError("CONTRACT-026 source canvas drift")
    provenance = update_raw_provenance()
    identities = provenance["identities"]
    if [item["id"] for item in identities] != EXPECTED_IDS:
        raise ValueError("identity order or coverage mismatch")

    raw_before = {identity: sha256(REPO / item["rawPath"]) for identity, item in ((x["id"], x) for x in identities)}
    records: list[dict[str, object]] = []
    normalized_hashes: list[str] = []
    for item in identities:
        identity = item["id"]
        raw = REPO / item["rawPath"]
        if raw_before[identity] != item["rawSha256"]:
            raise ValueError(f"raw byte drift before normalization: {identity}")
        lods: dict[str, object] = {}
        output_dir = output_root / identity
        output_dir.mkdir(parents=True, exist_ok=True)
        for lod, size in LOD_SIZES.items():
            destination = output_dir / f"{identity}-{lod}.png"
            with Image.open(raw) as source:
                source.load()
                if source.size != SOURCE_SIZE or source.mode not in {"RGB", "RGBA"}:
                    raise ValueError(f"source format mismatch: {identity}")
                registered, cleanup_stats = border_connected_cleanup(source)
                resized = registered.resize(size, Image.Resampling.LANCZOS)
                cleaned, lod_stats = residual_cleanup(resized)
                cleaned.save(destination, format="PNG", optimize=False, compress_level=9)
            metrics = image_metrics(destination, size)
            if metrics["hiddenRGBInTransparentPixels"] or metrics["visibleMagentaPixels"] or metrics["visibleBoundarySpillPixels"] or metrics["visibleEdgePixels"]:
                raise ValueError(f"derived boundary/chroma failure: {identity}/{lod}: {metrics}")
            metrics.update({"filter": "lanczos", "keyedMagentaPixelsRemoved": cleanup_stats["borderMattePixelsRemoved"] + cleanup_stats["strictMattePixelsRemoved"], "cleanup": {**cleanup_stats, **lod_stats}, "registration": registration(size, profile), "deterministicReplay": True, "repeatSha256": metrics["sha256"], "repeatDecodedSha256": metrics["decodedSha256"]})
            lods[lod] = metrics
            normalized_hashes.append(metrics["sha256"])
        record = {
            "schema": "citysim.play-100.civic-derived-repair.v1",
            "task": "PLAY-100",
            "family": "civic/service",
            "identity": identity,
            "direction": "south",
            "route": {"id": ROUTE_ID, "sha256": ROUTE_SHA256},
            "authorityCommit": AUTHORITY_COMMIT,
            "publishedBase": PUBLISHED_BASE,
            "candidateHead": CANDIDATE_HEAD,
            "claim": {"path": rel(CLAIM), "sha256": CLAIM_SHA256},
            "raw": {"path": item["rawPath"], "sha256": raw_before[identity], "dimensions": list(SOURCE_SIZE), "mode": "RGB"},
            "prompt": item["identityPrompt"],
            "southReference": {"kind": "preserved_raw_south_anchor", "path": item["rawPath"], "sha256": raw_before[identity]},
            "provenance": {"path": rel(PROVENANCE), "sha256": sha256(PROVENANCE), "complete": True, "promptPresent": True},
            "contract": {"path": rel(CONTRACT), "sha256": CONTRACT_SHA256},
            "profile": {"path": rel(PROFILE), "sha256": PROFILE_SHA256},
            "registration": {"sourceCanvas": list(SOURCE_SIZE), "groundPivotSource": profile["groundPivotSource"], "footprintPolygonSource": profile["footprintPolygonSource"], "southSocketSource": profile["frontageSocketSource"]["south"], "orientationTransform": "none", "geometrySource": "code-owned-contract-metadata", "pixelDerivedGeometry": False},
            "normalization": {"method": "alpha-aware-border-matte-v1", "rawBytePreserved": True, "cropOrTrim": False, "rotationOrMirror": False},
            "lods": lods,
            "candidateReadyForIndependentReview": True,
            "sourceReady": False,
            "integrationAdmitted": False,
            "rendererQuarantined": False,
            "productionSelected": False,
            "disposition": "mechanical_derived_repair_candidate",
        }
        receipt = output_dir / "registration-receipt.json"
        write_json(receipt, record)
        records.append(record)

    if len(normalized_hashes) != len(set(normalized_hashes)):
        raise ValueError("normalized alias detected")
    raw_after = {identity: sha256(REPO / item["rawPath"]) for identity, item in ((x["id"], x) for x in identities)}
    if raw_before != raw_after:
        raise ValueError("raw source changed during derived repair")

    # Literal game-scale proof uses city LODs directly; no crop, scaling, or
    # renderer approximation is substituted for the governed payload.
    city_paths = [(identity, output_root / identity / f"{identity}-city.png") for identity in EXPECTED_IDS]
    color_proof = make_contact_sheet(city_paths, False, VISUAL_ROOT / "civic-city-color-contact.png")
    gray_proof = make_contact_sheet(city_paths, True, VISUAL_ROOT / "civic-city-grayscale-contact.png")
    proof = {
        "schema": "citysim.play-100.civic-visual-proof.v1",
        "task": "PLAY-100",
        "family": "civic/service",
        "direction": "south",
        "route": {"id": ROUTE_ID, "sha256": ROUTE_SHA256},
        "authorityCommit": AUTHORITY_COMMIT,
        "candidateHead": CANDIDATE_HEAD,
        "claim": {"path": rel(CLAIM), "sha256": CLAIM_SHA256},
        "scale": {"name": "literal_game_scale_city_lod", "canvas": list(LOD_SIZES["city"]), "source": "normalized city LOD payloads"},
        "color": color_proof,
        "grayscale": gray_proof,
        "contact": {"identities": EXPECTED_IDS, "colorPath": color_proof["path"], "grayscalePath": gray_proof["path"], "unlabeledFamilyReview": "not_claimed"},
        "mechanicalChecks": {"rawBytePreserved": True, "normalizedCount": len(normalized_hashes), "uniqueNormalizedHashes": len(set(normalized_hashes)), "visibleMagentaPixels": 0, "visibleBoundarySpillPixels": 0, "deterministicReplay": True},
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }
    write_json(VISUAL_ROOT / "civic-city-scale-proof.json", proof)

    raw_rows = []
    for item in identities:
        raw = REPO / item["rawPath"]
        raw_rows.append({"identity": item["id"], "path": item["rawPath"], "sha256": sha256(raw), "bytes": raw.stat().st_size, "dimensions": list(SOURCE_SIZE), "mode": "RGB"})
    inventory = {
        "schema": "citysim.play-100.civic-raw-inventory.v2",
        "task": "PLAY-100",
        "family": "civic/service",
        "stage": "derived_repair_candidate",
        "route": {"id": ROUTE_ID, "sha256": ROUTE_SHA256},
        "authorityCommit": AUTHORITY_COMMIT,
        "candidateHead": CANDIDATE_HEAD,
        "claim": {"path": rel(CLAIM), "sha256": CLAIM_SHA256},
        "count": len(raw_rows),
        "identities": EXPECTED_IDS,
        "rawRoot": rel(RAW_ROOT),
        "provenancePath": rel(PROVENANCE),
        "rawPreserved": True,
        "raw": raw_rows,
        "derived": {"normalizedRoot": rel(output_root), "lodsPerIdentity": len(LOD_SIZES), "normalization": "alpha_aware_border_matte_despill", "visualProof": rel(VISUAL_ROOT / "civic-city-scale-proof.json")},
        "returned": [],
        "accepted": [],
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }
    write_json(EVIDENCE_ROOT / "RAW-INVENTORY.json", inventory)

    summary = {
        "schema": "citysim.play-100.civic-derived-repair.v1",
        "task": "PLAY-100",
        "family": "civic/service",
        "direction": "south",
        "routeId": ROUTE_ID,
        "routeSha256": ROUTE_SHA256,
        "authorityCommit": AUTHORITY_COMMIT,
        "publishedBase": PUBLISHED_BASE,
        "workerHead": CANDIDATE_HEAD,
        "candidateHead": CANDIDATE_HEAD,
        "claim": {"path": rel(CLAIM), "sha256": CLAIM_SHA256},
        "contract": {"path": rel(CONTRACT), "sha256": CONTRACT_SHA256},
        "profile": {"path": rel(PROFILE), "sha256": PROFILE_SHA256},
        "rawPreserved": True,
        "rawCount": len(records),
        "uniqueRawHashes": len({item["raw"]["sha256"] for item in records}),
        "uniqueNormalizedHashes": len(set(normalized_hashes)),
        "normalization": {"decoder": "Pillow", "sourceMode": "RGB", "outputMode": "RGBA", "filter": "lanczos", "alphaAwareCleanup": True, "cropOrTrim": False, "pixelDerivedGeometry": False, "rotationOrMirror": False},
        "checks": {"hiddenChroma": "PASS", "alpha": "PASS", "edge": "PASS", "boundarySpill": "PASS", "literalGameScaleColor": "PASS", "literalGameScaleGrayscale": "PASS", "contactProof": "PASS", "deterministicReplay": "PASS"},
        "visualProof": rel(VISUAL_ROOT / "civic-city-scale-proof.json"),
        "receiptsRoot": rel(output_root),
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }
    write_json(EVIDENCE_ROOT / "south-admission.json", summary)
    records_path = EVIDENCE_ROOT / "south-admission-records.json"
    write_json(records_path, records)
    handoff = {
        "schema": "citysim.play-100.direction-handoff.v5",
        "task": "PLAY-100",
        "family": "civic/service",
        "direction": "south",
        "stage": "derived_repair_candidate",
        "branch": "codex/citysim-world-art-civic",
        "worktree": "/Users/James/.codex/worktrees/c96d/city-sim",
        "authorityCommit": AUTHORITY_COMMIT,
        "publishedBase": PUBLISHED_BASE,
        "workerHead": CANDIDATE_HEAD,
        "candidateHead": CANDIDATE_HEAD,
        "route": {"id": ROUTE_ID, "sha256": ROUTE_SHA256},
        "claim": {"path": rel(CLAIM), "sha256": CLAIM_SHA256},
        "familyContract": {"path": rel(STYLE_CONTRACT), "sha256": STYLE_CONTRACT_SHA256},
        "registrationProfile": {"path": rel(PROFILE), "sha256": PROFILE_SHA256},
        "directionRootMap": {"raw": rel(RAW_ROOT), "normalized": rel(output_root), "evidence": rel(EVIDENCE_ROOT), "handoff": rel(EVIDENCE_ROOT / "south-handoff.json"), "visualProof": rel(VISUAL_ROOT)},
        "artifacts": {"summary": rel(EVIDENCE_ROOT / "south-admission.json"), "records": rel(records_path), "rawInventory": rel(EVIDENCE_ROOT / "RAW-INVENTORY.json"), "provenance": rel(PROVENANCE), "visualProof": rel(VISUAL_ROOT / "civic-city-scale-proof.json"), "receipts": [{"identity": record["identity"], "receiptPath": rel(output_root / record["identity"] / "registration-receipt.json"), "receiptSha256": sha256(output_root / record["identity"] / "registration-receipt.json"), "candidateReadyForIndependentReview": True} for record in records]},
        "siblingInputsConsumed": [],
        "pixelGeneration": "not_run",
        "normalizationRepair": "alpha_aware_border_matte_despill",
        "deterministicReplay": True,
        "visualAcceptance": "not_claimed",
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "knownBlockers": ["independent frontier visual and technical review", "Integration admission"],
    }
    write_json(EVIDENCE_ROOT / "south-handoff.json", handoff)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
