#!/usr/bin/env python3
"""Render candidate-bound PLAY-062 packed-atlas comparison sheets."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat


REPO = Path(__file__).resolve().parents[6]
ATLAS = REPO / "Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas"
MANIFEST_PATH = ATLAS / "generated-v4-manifest.json"
OUTPUT = Path(__file__).resolve().parents[1] / "matrix"
DIRECTIONS = ("north", "east", "south", "west")
LODS = ("city", "neighborhood", "block")
CELL = (320, 270)
BACKGROUND = (34, 42, 39, 255)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def packed_asset(manifest: dict, logical_id: str, lod: str) -> Image.Image:
    entry = next(asset for asset in manifest["assets"] if asset["logical_id"] == logical_id)
    descriptor = entry["lods"][lod]
    x, y, width, height = descriptor["texture_rect_pixels"]
    page = Image.open(ATLAS / descriptor["page_file"]).convert("RGBA")
    return page.crop((x, y, x + width, y + height))


def fit(asset: Image.Image, maximum: tuple[int, int]) -> Image.Image:
    result = asset.copy()
    result.thumbnail(maximum, Image.Resampling.LANCZOS)
    return result


def sheet(
    manifest: dict,
    rows: list[tuple[str, list[tuple[str, str, str]]]],
    path: Path,
) -> None:
    header = 54
    row_height = CELL[1]
    canvas = Image.new("RGBA", (CELL[0] * 4, header + row_height * len(rows)), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    for column, direction in enumerate(DIRECTIONS):
        draw.text((column * CELL[0] + 12, 18), direction.upper(), fill=(235, 239, 227, 255), font=font)
    for row_index, (row_label, identities) in enumerate(rows):
        top = header + row_index * row_height
        draw.text((12, top + 10), row_label, fill=(235, 239, 227, 255), font=font)
        for column, (logical_id, lod, caption) in enumerate(identities):
            image = fit(packed_asset(manifest, logical_id, lod), (CELL[0] - 30, CELL[1] - 58))
            left = column * CELL[0] + (CELL[0] - image.width) // 2
            image_top = top + 28 + (CELL[1] - 58 - image.height)
            canvas.alpha_composite(image, (left, image_top))
            draw.text(
                (column * CELL[0] + 12, top + CELL[1] - 20),
                caption,
                fill=(190, 205, 195, 255),
                font=font,
            )
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(path, optimize=True)


def normalized_comparison_image(image: Image.Image) -> Image.Image:
    background = Image.new("RGBA", (300, 260), BACKGROUND)
    fitted = fit(image, (270, 220))
    background.alpha_composite(fitted, ((300 - fitted.width) // 2, 30 + 220 - fitted.height))
    return background.convert("RGB")


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    direction_rows = []
    for lod in LODS:
        direction_rows.append(
            (
                lod.upper(),
                [
                    (f"industrial_l01_v0_{direction}", lod, f"Industrial L1 · {lod}")
                    for direction in DIRECTIONS
                ],
            )
        )
    color_path = OUTPUT / "industrial-l1-production-4x3-color.png"
    sheet(manifest, direction_rows, color_path)
    grayscale_path = OUTPUT / "industrial-l1-production-4x3-grayscale.png"
    Image.open(color_path).convert("L").convert("RGB").save(grayscale_path, optimize=True)

    family_ids = (
        "residential_l01_v0_south",
        "commercial_l01_v0_south",
        "industrial_l01_v0_south",
    )
    family_assets = [packed_asset(manifest, logical_id, "block") for logical_id in family_ids]
    family_canvas = Image.new("RGBA", (CELL[0] * 3, CELL[1]), BACKGROUND)
    family_draw = ImageDraw.Draw(family_canvas)
    font = ImageFont.load_default()
    for index, (logical_id, asset) in enumerate(zip(family_ids, family_assets)):
        fitted = fit(asset, (CELL[0] - 30, CELL[1] - 48))
        left = index * CELL[0] + (CELL[0] - fitted.width) // 2
        top = 25 + (CELL[1] - 48 - fitted.height)
        family_canvas.alpha_composite(fitted, (left, top))
        family_draw.text(
            (index * CELL[0] + 10, CELL[1] - 18),
            logical_id,
            fill=(235, 239, 227, 255),
            font=font,
        )
    family_color = OUTPUT / "l1-family-south-color.png"
    family_canvas.convert("RGB").save(family_color, optimize=True)
    family_gray = OUTPUT / "l1-family-south-grayscale.png"
    family_canvas.convert("L").convert("RGB").save(family_gray, optimize=True)

    normalized = [normalized_comparison_image(asset) for asset in family_assets]
    comparisons = {}
    for left_index, right_index in ((0, 2), (1, 2)):
        left_id = family_ids[left_index]
        right_id = family_ids[right_index]
        color_difference = ImageStat.Stat(
            ImageChops.difference(normalized[left_index], normalized[right_index])
        ).rms
        grayscale_difference = ImageStat.Stat(
            ImageChops.difference(
                normalized[left_index].convert("L"),
                normalized[right_index].convert("L"),
            )
        ).rms[0]
        comparisons[f"{left_id}__vs__{right_id}"] = {
            "color_rms": [round(value, 6) for value in color_difference],
            "grayscale_rms": round(grayscale_difference, 6),
        }

    report = {
        "candidate_product": "02612e414912fdabcab858b0ca97e1f5edbc2757",
        "manifest": str(MANIFEST_PATH.relative_to(REPO)),
        "manifest_sha256": sha256(MANIFEST_PATH),
        "source": "packed texture_rect_pixels from committed generated-v4 atlas pages",
        "directions": list(DIRECTIONS),
        "lods": list(LODS),
        "family_comparisons": comparisons,
        "outputs": {
            path.name: sha256(path)
            for path in (color_path, grayscale_path, family_color, family_gray)
        },
    }
    (OUTPUT / "matrix-report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
