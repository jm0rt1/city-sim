#!/usr/bin/env python3
"""Deterministically normalize and register the PLAY-098 Commercial L1 sources."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


FAMILY = Path(__file__).resolve().parents[1]
REPO = next(parent for parent in FAMILY.parents if (parent / ".git").exists())
RAW = FAMILY / "raw"
LIVE_OUTPUT = FAMILY / "normalized"
LIVE_EVIDENCE = REPO / "docs/production/evidence/PLAY-098/commercial-l01-v0-admission"
LOGICAL_NORMALIZED_ROOT = "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/commercial_l01_v0/normalized"
LOGICAL_EVIDENCE_ROOT = "docs/production/evidence/PLAY-098/commercial-l01-v0-admission"
DIRECTIONS = ("north", "east", "south", "west")
RAW_SIZE = (1254, 1254)
CANVAS = (1536, 1024)
FIT_SIZE = (768, 768)
FIT_ORIGIN = (384, 128)
PIVOT = [768, 896]
FOOTPRINT = [[768, 640], [1024, 768], [768, 896], [512, 768]]
SOCKETS = {"north": [768, 704], "east": [896, 768], "south": [768, 832], "west": [640, 768]}
LOD_SIZES = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
CLAIM_PATH = "docs/production/claims/PLAY-098.commercial-l01-v0-admission-currente298.md"
CLAIM_SHA256 = "0b105ec9cb07df1e740b409ab7f14dda3c0ebed176efbd5d8f1b288ad30087cf"
RAW_SHA256 = {
    "north": "3d0f771f72525740dace420163de67f124f7f84adbcd4c2b7c34375a8f4b2fa0",
    "east": "ed3ae1e4c4b6198a98a3f917ad844c42e9c92c1efc9fc97af290bc6eb2bc36a8",
    "south": "7fb0044d1b1ae46110528cb1ee8ad82c64d755e984564e1017c91d0f54bfb51e",
    "west": "b28311c8c958e2e35e4999e2b5b3de200bdc6430c7a30fc40b64aa362e514b00",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_png(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def is_keyed_field(red: int, green: int, blue: int) -> bool:
    return red >= 210 and green <= 40 and blue >= 200 and red - green >= 180 and blue - green >= 180


def source_to_rgba(path: Path) -> Image.Image:
    with Image.open(path) as source:
        if source.mode != "RGB" or source.size != RAW_SIZE:
            raise ValueError(f"{path.name}: expected opaque RGB {RAW_SIZE}, got {source.mode} {source.size}")
        pixels = []
        for red, green, blue in source.get_flattened_data():
            if is_keyed_field(red, green, blue):
                pixels.append((0, 0, 0, 0))
                continue
            if red * 100 > green * 135 and blue * 100 > green * 125:
                spill = max(0, min(red, blue) - green)
                red = max(green, red - spill)
                blue = max(green, blue - spill)
            pixels.append((red, green, blue, 255))
    image = Image.new("RGBA", RAW_SIZE)
    image.putdata(pixels)
    return image


def remove_keyed_residuals(image: Image.Image) -> Image.Image:
    """Zero chroma remnants introduced by interpolation without altering opaque art."""
    cleaned = []
    for red, green, blue, alpha in image.get_flattened_data():
        if alpha == 0 or (alpha > 0 and is_keyed_field(red, green, blue)):
            cleaned.append((0, 0, 0, 0))
        else:
            cleaned.append((red, green, blue, alpha))
    result = Image.new("RGBA", image.size)
    result.putdata(cleaned)
    return result


def metrics(image: Image.Image) -> dict[str, object]:
    if image.mode != "RGBA":
        raise ValueError(f"expected RGBA, got {image.mode}")
    width, height = image.size
    pixels = list(image.get_flattened_data())
    visible = [pixel for pixel in pixels if pixel[3] > 0]
    hidden_rgb = sum(1 for red, green, blue, alpha in pixels if alpha == 0 and (red or green or blue))
    keyed = sum(1 for red, green, blue, alpha in pixels if alpha > 0 and is_keyed_field(red, green, blue))
    frame = []
    for x in range(width):
        frame.extend((pixels[x], pixels[(height - 1) * width + x]))
    for y in range(1, height - 1):
        frame.extend((pixels[y * width], pixels[y * width + width - 1]))
    bbox = image.getbbox()
    return {
        "visiblePixels": len(visible),
        "nonzeroRgbPixels": sum(1 for red, green, blue, alpha in visible if red or green or blue),
        "hiddenRgbPixels": hidden_rgb,
        "keyedMagentaPixels": keyed,
        "frameEdgeOpaquePixels": sum(1 for pixel in frame if pixel[3] > 0),
        "opaqueBounds": list(bbox) if bbox else None,
    }


def checker_composite(image: Image.Image, grayscale: bool = False) -> Image.Image:
    width, height = image.size
    background = Image.new("RGB", (width, height))
    pixels = background.load()
    for y in range(height):
        for x in range(width):
            pixels[x, y] = (235, 239, 232) if ((x // 16) + (y // 16)) % 2 == 0 else (202, 210, 201)
    foreground = image.convert("L").convert("RGBA") if grayscale else image
    background.paste(foreground, (0, 0), foreground)
    return background


def normalized_for(direction: str) -> tuple[Image.Image, dict[str, object]]:
    raw_path = RAW / f"{direction}-source-v01.png"
    observed = sha256(raw_path)
    if observed != RAW_SHA256[direction]:
        raise ValueError(f"{direction}: immutable raw hash mismatch")
    fitted = remove_keyed_residuals(source_to_rgba(raw_path).resize(FIT_SIZE, Image.Resampling.LANCZOS))
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.alpha_composite(fitted, FIT_ORIGIN)
    canvas = remove_keyed_residuals(canvas)
    return canvas, {
        "path": f"{LOGICAL_NORMALIZED_ROOT}/source/{direction}.png",
        "dimensions": list(CANVAS),
        "mode": "RGBA",
        **metrics(canvas),
    }


def source_sheet(output_root: Path, normalized: dict[str, Image.Image]) -> dict[str, object]:
    tile = (768, 512)
    sheet = Image.new("RGB", (1536, 1024), "white")
    draw = ImageDraw.Draw(sheet)
    for index, direction in enumerate(DIRECTIONS):
        x = (index % 2) * tile[0]
        y = (index // 2) * tile[1]
        view = checker_composite(normalized[direction].resize(tile, Image.Resampling.LANCZOS))
        sheet.paste(view, (x, y))
        draw.rectangle((x, y, x + tile[0] - 1, y + tile[1] - 1), outline=(20, 64, 67), width=4)
        draw.text((x + 18, y + 18), direction.upper(), fill="white", stroke_width=2, stroke_fill=(20, 64, 67))
    path = output_root / "contact-sheets/family-source-four-view.png"
    write_png(path, sheet)
    return {"path": f"{LOGICAL_NORMALIZED_ROOT}/contact-sheets/family-source-four-view.png", "sha256": sha256(path), "dimensions": list(sheet.size)}


def game_scale_sheet(output_root: Path, lods: dict[str, dict[str, Image.Image]]) -> dict[str, object]:
    cell = (288, 220)
    sheet = Image.new("RGB", (cell[0] * 4, cell[1] * 3), "white")
    draw = ImageDraw.Draw(sheet)
    for row, lod in enumerate(("block", "neighborhood", "city")):
        for column, direction in enumerate(DIRECTIONS):
            view = lods[direction][lod]
            preview = checker_composite(view)
            preview.thumbnail((cell[0] - 20, cell[1] - 20), Image.Resampling.LANCZOS)
            x = column * cell[0] + (cell[0] - preview.width) // 2
            y = row * cell[1] + (cell[1] - preview.height) // 2
            sheet.paste(preview, (x, y))
            draw.rectangle((column * cell[0], row * cell[1], (column + 1) * cell[0] - 1, (row + 1) * cell[1] - 1), outline=(20, 64, 67), width=3)
            draw.text((column * cell[0] + 10, row * cell[1] + 10), f"{direction.upper()} {lod.upper()}", fill="white", stroke_width=2, stroke_fill=(20, 64, 67))
    path = output_root / "contact-sheets/family-game-scale-lods.png"
    write_png(path, sheet)
    return {"path": f"{LOGICAL_NORMALIZED_ROOT}/contact-sheets/family-game-scale-lods.png", "sha256": sha256(path), "dimensions": list(sheet.size)}


def build_outputs(output_root: Path = LIVE_OUTPUT, evidence_root: Path = LIVE_EVIDENCE) -> dict[str, object]:
    output_root.mkdir(parents=True, exist_ok=True)
    evidence_root.mkdir(parents=True, exist_ok=True)
    normalized_images: dict[str, Image.Image] = {}
    normalized_records: dict[str, dict[str, object]] = {}
    lod_images: dict[str, dict[str, Image.Image]] = {}
    lod_records: dict[str, dict[str, dict[str, object]]] = {}
    raw_records = {}

    for direction in DIRECTIONS:
        raw_path = RAW / f"{direction}-source-v01.png"
        with Image.open(raw_path) as raw_image:
            raw_records[direction] = {
                "path": raw_path.relative_to(REPO).as_posix(), "sha256": sha256(raw_path),
                "dimensions": list(raw_image.size), "mode": raw_image.mode,
            }
        normalized, record = normalized_for(direction)
        normalized_path = output_root / "source" / f"{direction}.png"
        write_png(normalized_path, normalized)
        record["sha256"] = sha256(normalized_path)
        normalized_images[direction] = normalized
        normalized_records[direction] = record
        lod_images[direction] = {}
        lod_records[direction] = {}
        for lod, size in LOD_SIZES.items():
            image = remove_keyed_residuals(normalized.resize(size, Image.Resampling.LANCZOS))
            path = output_root / "lod" / direction / f"{lod}.png"
            write_png(path, image)
            lod_images[direction][lod] = image
            lod_records[direction][lod] = {
                "path": f"{LOGICAL_NORMALIZED_ROOT}/lod/{direction}/{lod}.png",
                "sha256": sha256(path), "dimensions": list(size), "mode": "RGBA", **metrics(image),
            }

    sheets = {"sourceFourView": source_sheet(output_root, normalized_images), "gameScaleLods": game_scale_sheet(output_root, lod_images)}
    receipt = {
        "schema": "citysim.play-098.commercial-l01-v0.admission.v1",
        "task": "PLAY-098", "family": "commercial_l01_v0", "candidateOnly": True,
        "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA256},
        "directions": list(DIRECTIONS), "rawSources": raw_records,
        "normalizedSources": normalized_records, "lods": lod_records, "contactSheets": sheets,
        "geometry": {"rawInputCanvas": list(RAW_SIZE), "canvas": list(CANVAS), "fitContent": list(FIT_SIZE), "fitOrigin": list(FIT_ORIGIN), "pivot": PIVOT, "footprint": FOOTPRINT, "sockets": SOCKETS},
        "derivation": "fixed template: keyed RGB -> alpha-safe RGBA -> 768x768 fit at 384,128 in 1536x1024 canvas -> deterministic LOD resizes",
        "sourceAdmitted": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False,
    }
    write_json(output_root / "NORMALIZATION-RECEIPT.json", receipt)
    write_json(output_root / "PROVENANCE.json", {
        "task": "PLAY-098", "family": "commercial_l01_v0", "candidateOnly": True,
        "rawSources": raw_records, "normalizedSources": normalized_records, "lods": lod_records,
        "mirrored": False, "rotated": False, "copiedPixels": False, "sourceAdmitted": False,
        "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False,
    })
    handoff = {
        "schema": "citysim.play-098.commercial-l01-v0.renderer-handoff.v1", "result": "PASS_CANDIDATE_SOURCE_HANDOFF",
        "candidateOnly": True, "task": "PLAY-098", "family": "commercial_l01_v0",
        "normalizationReceipt": {"path": f"{LOGICAL_NORMALIZED_ROOT}/NORMALIZATION-RECEIPT.json", "sha256": sha256(output_root / "NORMALIZATION-RECEIPT.json")},
        "rawSources": raw_records, "normalizedSources": normalized_records, "lods": lod_records, "contactSheets": sheets,
        "sourceAdmitted": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False,
    }
    write_json(evidence_root / "RENDERER-HANDOFF.json", handoff)
    write_json(evidence_root / "REGISTRATION-REPORT.json", {"result": "PASS", "canvas": list(CANVAS), "pivot": PIVOT, "footprint": FOOTPRINT, "sockets": SOCKETS, "method": "fixed template; no pixel-derived registration"})
    write_json(evidence_root / "ADMISSION-MATRIX.json", {"result": "PASS_CANDIDATE_SOURCE_HANDOFF", "directions": list(DIRECTIONS), "rawCount": 4, "normalizedCount": 4, "lodCount": 12, "uniqueRaw": len({row["sha256"] for row in raw_records.values()}), "uniqueNormalized": len({row["sha256"] for row in normalized_records.values()}), "uniqueLod": len({row["sha256"] for rows in lod_records.values() for row in rows.values()}), "candidateOnly": True})
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", type=Path, default=LIVE_OUTPUT)
    parser.add_argument("--evidence-root", type=Path, default=LIVE_EVIDENCE)
    args = parser.parse_args()
    receipt = build_outputs(args.output_root, args.evidence_root)
    print(json.dumps({"result": "PASS", "normalized": len(receipt["normalizedSources"]), "lods": sum(len(rows) for rows in receipt["lods"].values())}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
