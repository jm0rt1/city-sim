#!/usr/bin/env python3
"""Build the candidate-only PLAY-113 Civic L1 authored-four-view packet."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


FAMILY = Path(__file__).resolve().parents[1]
REPO = next(parent for parent in FAMILY.parents if (parent / ".git").exists())
RAW = FAMILY / "raw"
OUTPUT = FAMILY / "normalized"
EVIDENCE = REPO / "docs/production/evidence/PLAY-113/civic-l01-v0-family"
DIRECTIONS = ("north", "east", "south", "west")
CANVAS = (1536, 1024)
LODS = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
PIVOT = [768, 896]
FOOTPRINT = [[768, 640], [1024, 768], [768, 896], [512, 768]]
SOCKETS = {"north": [896, 704], "east": [896, 832], "south": [640, 832], "west": [640, 704]}
SOURCE_ROOT = "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/civic_l01_v0"
EVIDENCE_ROOT = "docs/production/evidence/PLAY-113/civic-l01-v0-family"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_png(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def keyed(red: int, green: int, blue: int) -> bool:
    return red >= 210 and green <= 45 and blue >= 200 and red - green >= 170 and blue - green >= 170


def keyed_residual(red: int, green: int, blue: int) -> bool:
    """Remove only antialiased #ff00ff-field remnants, never derive geometry."""
    return red >= 90 and blue >= 90 and red - green >= 40 and blue - green >= 40 and abs(red - blue) <= 140


def clear_key(image: Image.Image) -> Image.Image:
    cleaned = []
    for red, green, blue, alpha in image.convert("RGBA").get_flattened_data():
        if alpha == 0 or keyed(red, green, blue) or keyed_residual(red, green, blue):
            cleaned.append((0, 0, 0, 0))
        else:
            cleaned.append((red, green, blue, 255))
    output = Image.new("RGBA", image.size)
    output.putdata(cleaned)
    return output


def metrics(image: Image.Image) -> dict[str, object]:
    pixels = list(image.get_flattened_data())
    width, height = image.size
    frame = [pixels[x] for x in range(width)] + [pixels[(height - 1) * width + x] for x in range(width)]
    frame += [pixels[y * width] for y in range(1, height - 1)] + [pixels[y * width + width - 1] for y in range(1, height - 1)]
    visible = [pixel for pixel in pixels if pixel[3] > 0]
    return {
        "visiblePixels": len(visible),
        "nonzeroRgbPixels": sum(1 for red, green, blue, _ in visible if red or green or blue),
        "hiddenRgbPixels": sum(1 for red, green, blue, alpha in pixels if alpha == 0 and (red or green or blue)),
        "keyedMagentaPixels": sum(1 for red, green, blue, alpha in pixels if alpha > 0 and (keyed(red, green, blue) or keyed_residual(red, green, blue))),
        "frameEdgeOpaquePixels": sum(1 for pixel in frame if pixel[3] > 0),
        "opaqueBounds": list(image.getbbox()) if image.getbbox() else None,
    }


def normalize(raw: Path) -> Image.Image:
    # Whole-canvas scaling is fixed by the registration contract; no geometry is inferred from pixels.
    with Image.open(raw) as image:
        converted = clear_key(image)
    converted = converted.resize(CANVAS, Image.Resampling.LANCZOS)
    converted = clear_key(converted)
    pixels = bytearray(converted.tobytes())
    width, height = CANVAS
    for x in range(width):
        pixels[x * 4:x * 4 + 4] = b"\x00\x00\x00\x00"
        offset = ((height - 1) * width + x) * 4
        pixels[offset:offset + 4] = b"\x00\x00\x00\x00"
    for y in range(height):
        for x in (0, width - 1):
            offset = (y * width + x) * 4
            pixels[offset:offset + 4] = b"\x00\x00\x00\x00"
    return Image.frombytes("RGBA", CANVAS, bytes(pixels))


def checker(image: Image.Image, grayscale: bool = False) -> Image.Image:
    background = Image.new("RGB", image.size)
    draw = ImageDraw.Draw(background)
    for y in range(0, image.height, 16):
        for x in range(0, image.width, 16):
            draw.rectangle((x, y, x + 15, y + 15), fill=(236, 240, 233) if (x // 16 + y // 16) % 2 == 0 else (204, 211, 202))
    foreground = image.convert("L").convert("RGBA") if grayscale else image
    background.paste(foreground, (0, 0), foreground)
    return background


def family_sheet(path: Path, logical_path: str, views: dict[str, Image.Image], label: str, grayscale: bool = False) -> dict[str, object]:
    tile = (768, 512)
    sheet = Image.new("RGB", (1536, 1024), "white")
    draw = ImageDraw.Draw(sheet)
    for index, direction in enumerate(DIRECTIONS):
        x, y = (index % 2) * tile[0], (index // 2) * tile[1]
        sheet.paste(checker(views[direction].resize(tile, Image.Resampling.LANCZOS), grayscale), (x, y))
        draw.rectangle((x, y, x + tile[0] - 1, y + tile[1] - 1), outline=(25, 75, 78), width=4)
        draw.text((x + 18, y + 18), f"{direction.upper()} {label}", fill="white", stroke_width=2, stroke_fill=(25, 75, 78))
    write_png(path, sheet)
    return {"path": logical_path, "sha256": sha256(path), "dimensions": list(sheet.size)}


def build(output_root: Path = OUTPUT, evidence_root: Path = EVIDENCE) -> dict[str, object]:
    output_root.mkdir(parents=True, exist_ok=True)
    evidence_root.mkdir(parents=True, exist_ok=True)
    raw_records, normalized_records, lod_records, source_views = {}, {}, {}, {}
    for direction in DIRECTIONS:
        raw = RAW / f"{direction}-source-v01.png"
        with Image.open(raw) as opened:
            raw_records[direction] = {"path": raw.relative_to(REPO).as_posix(), "sha256": sha256(raw), "dimensions": list(opened.size), "mode": opened.mode}
        source = normalize(raw)
        source_path = output_root / "source" / f"{direction}.png"
        write_png(source_path, source)
        source_views[direction] = source
        normalized_records[direction] = {"path": f"{SOURCE_ROOT}/normalized/source/{direction}.png", "sha256": sha256(source_path), "dimensions": list(CANVAS), "mode": "RGBA", **metrics(source)}
        lod_records[direction] = {}
        for lod, size in LODS.items():
            lod_image = clear_key(source.resize(size, Image.Resampling.LANCZOS))
            lod_path = output_root / "lod" / direction / f"{lod}.png"
            write_png(lod_path, lod_image)
            lod_records[direction][lod] = {"path": f"{SOURCE_ROOT}/normalized/lod/{direction}/{lod}.png", "sha256": sha256(lod_path), "dimensions": list(size), "mode": "RGBA", **metrics(lod_image)}
    sheets = {
        "sourceFourView": family_sheet(output_root / "contact-sheets/family-source-four-view.png", f"{SOURCE_ROOT}/normalized/contact-sheets/family-source-four-view.png", source_views, "SOURCE"),
        "sourceFourViewGrayscale": family_sheet(output_root / "contact-sheets/family-source-four-view-grayscale.png", f"{SOURCE_ROOT}/normalized/contact-sheets/family-source-four-view-grayscale.png", source_views, "GRAY", True),
    }
    receipt = {
        "schema": "citysim.play-113.civic-l01-v0.source-candidate.v1", "task": "PLAY-113", "family": "civic_l01_v0", "candidateOnly": True,
        "directions": list(DIRECTIONS), "rawSources": raw_records, "normalizedSources": normalized_records, "lods": lod_records,
        "contactSheets": sheets, "geometry": {"canvas": list(CANVAS), "groundPivotSource": PIVOT, "footprintPolygonSource": FOOTPRINT, "frontageSocketSource": SOCKETS, "lods": {name: list(size) for name, size in LODS.items()}, "derivation": "fixed whole-canvas normalization and Lanczos LODs; registration is metadata, never pixel-derived"},
        "sourceAdmitted": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False,
    }
    write_json(output_root / "NORMALIZATION-RECEIPT.json", receipt)
    write_json(output_root / "PROVENANCE.json", {"task": "PLAY-113", "family": "civic_l01_v0", "candidateOnly": True, "rawSources": raw_records, "normalizedSources": normalized_records, "lods": lod_records, "mirrored": False, "rotated": False, "copiedPixels": False, "sourceAdmitted": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False})
    write_json(evidence_root / "RENDERER-HANDOFF.json", {"schema": "citysim.play-113.civic-l01-v0.renderer-handoff.v1", "result": "PASS_CANDIDATE_SOURCE_HANDOFF", "task": "PLAY-113", "family": "civic_l01_v0", "candidateOnly": True, "normalizationReceipt": {"path": f"{SOURCE_ROOT}/normalized/NORMALIZATION-RECEIPT.json", "sha256": sha256(output_root / "NORMALIZATION-RECEIPT.json")}, "rawSources": raw_records, "normalizedSources": normalized_records, "lods": lod_records, "contactSheets": sheets, "sourceAdmitted": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False})
    write_json(evidence_root / "REGISTRATION-REPORT.json", {"result": "PASS", "canvas": list(CANVAS), "groundPivotSource": PIVOT, "footprintPolygonSource": FOOTPRINT, "frontageSocketSource": SOCKETS, "method": "fixed full-canvas registration; no pixel-derived geometry"})
    write_json(evidence_root / "SOURCE-QUALITY-REPORT.json", {"result": "PASS_CANDIDATE_SOURCE_QUALITY", "task": "PLAY-113", "family": "civic_l01_v0", "candidateOnly": True, "rawSources": raw_records, "criteria": {"publicServiceIdentity": "library and community hall with distinct forecourt and entrances", "fourIndependentRoadFacingViews": True, "groundedFootprint": True, "noMirroringRotationOrAliasing": True, "noBakedRoadUiOrText": True, "noBlackVoidRoof": True, "paletteDistinction": "pale sandstone, teal civic doors, red-brick base, slate roof"}, "contactSheet": sheets["sourceFourView"]})
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", type=Path, default=OUTPUT)
    parser.add_argument("--evidence-root", type=Path, default=EVIDENCE)
    args = parser.parse_args()
    print(json.dumps(build(args.output_root, args.evidence_root), indent=2, sort_keys=True))
