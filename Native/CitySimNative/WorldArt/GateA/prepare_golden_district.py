#!/usr/bin/env python3
"""Prepare deterministic cleaned LOD exports from the retained Gate A master."""

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).with_name("golden_district_imagegen_source-v2.png")
ATLAS = ROOT / "Sources" / "CitySimNative" / "Resources" / "WorldAssets.atlas"
EXPORTS = {
    "golden_district_block.png": (1536, 1024),
    "golden_district_neighborhood.png": (1024, 683),
    "golden_district_city.png": (512, 341),
}
MANIFEST = ATLAS / "manifest.json"


def isolate_master(source: Image.Image) -> Image.Image:
    rgba = source.convert("RGBA")
    cleaned = []
    for red, green, blue, _ in rgba.get_flattened_data():
        # The built-in image generator produced a compressed magenta field
        # rather than one exact key. Remove only saturated low-green magenta;
        # warm brick, copper, flowers, and skin tones remain opaque.
        if (
            red >= 120
            and blue >= 110
            and green <= 80
            and red - green >= 70
            and blue - green >= 70
        ):
            cleaned.append((0, 0, 0, 0))
            continue
        cleaned.append((red, green, blue, 255))
    rgba.putdata(cleaned)
    return rgba


def update_manifest() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    manifest["schema"] = 3
    manifest["title"] = "CitySim Living Strategy World Atlas with Gate A Golden District"
    manifest["authoring"] = (
        "Original deterministic Pillow geometry plus an isolated, art-directed "
        "ImageGen district with deterministic LOD exports"
    )
    manifest["external_sources"] = [
        {
            "tool": "OpenAI built-in ImageGen",
            "role": "Gate A golden-district authoring master",
            "retained_source": "Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png",
            "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            "shipping": False,
        }
    ]
    golden_names = {Path(name).stem for name in EXPORTS}
    manifest["assets"] = [
        asset for asset in manifest["assets"] if asset["name"] not in golden_names
    ]
    for name in sorted(EXPORTS):
        path = ATLAS / name
        manifest["assets"].append(
            {
                "name": path.stem,
                "file": path.name,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "pixels": list(Image.open(path).size),
                "source": "WorldArt/GateA/prepare_golden_district.py",
            }
        )
    manifest["assets"] = sorted(manifest["assets"], key=lambda asset: asset["name"])
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    master = isolate_master(Image.open(SOURCE))
    ATLAS.mkdir(parents=True, exist_ok=True)
    for name, size in EXPORTS.items():
        image = master if master.size == size else master.resize(size, Image.Resampling.LANCZOS)
        image.save(ATLAS / name, optimize=True)
        print(f"wrote {name} {image.width}x{image.height}")
    update_manifest()
    print("updated manifest.json")


if __name__ == "__main__":
    main()
