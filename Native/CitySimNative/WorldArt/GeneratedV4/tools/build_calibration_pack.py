#!/usr/bin/env python3
"""Register the nine normalized PLAY-022 calibration sources for SwiftPM shipping."""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / "GeneratedV4"
PACKAGE = ROOT.parent
ATLAS = PACKAGE / "Sources" / "CitySimNative" / "Resources" / "WorldAssets.atlas"
CATALOG_PATH = GENERATED / "catalog" / "calibration-assets.json"
TEMPLATES_PATH = GENERATED / "templates" / "registration-templates.json"
STYLE_PATH = ROOT / "GateA" / "golden_district_imagegen_source-v2.png"
LODS = ("city", "neighborhood", "block")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    templates = json.loads(TEMPLATES_PATH.read_text(encoding="utf-8"))
    template_by_id = {item["id"]: item for item in templates["templates"]}
    style_hash = sha256(STYLE_PATH)
    manifest_assets = []
    inventory = []

    for asset in catalog["assets"]:
        asset_id = asset["logical_id"]
        template_id = asset["template"]
        template = template_by_id[template_id]
        prompt_path = GENERATED / "ImageGen" / "prompts" / "calibration" / f"{asset_id}.md"
        raw_path = GENERATED / "ImageGen" / "raw" / "calibration" / asset_id / "source-v01.png"
        normalization_path = GENERATED / "ImageGen" / "provenance" / "calibration" / f"{asset_id}-normalization.json"
        normalization = json.loads(normalization_path.read_text(encoding="utf-8"))
        provenance_path = GENERATED / "ImageGen" / "provenance" / "calibration" / f"{asset_id}.json"
        provenance = {
            "schema": 1,
            "asset_id": asset_id,
            "tool": "OpenAI built-in ImageGen",
            "model": "built-in/model-not-exposed",
            "generated_date": "2026-07-21",
            "complete_prompt": prompt_path.read_text(encoding="utf-8"),
            "prompt_file": str(prompt_path.relative_to(PACKAGE.parent)),
            "prompt_sha256": sha256(prompt_path),
            "references": [
                {"role": "provisional appearance reference only", "file": str(STYLE_PATH.relative_to(PACKAGE.parent)), "sha256": style_hash},
                {"role": f"authoritative {template_id} geometry and registration", "file": str((GENERATED / "templates" / f"registration-{template_id}.png").relative_to(PACKAGE.parent)), "sha256": template["sha256"]}
            ],
            "raw_source": str(raw_path.relative_to(PACKAGE.parent)),
            "raw_source_sha256": sha256(raw_path),
            "chroma_key": "#ff00ff",
            "cleanup_command": normalization["cleanup_command"],
            "normalization": normalization["normalization"],
            "registration": normalization["registration"],
            "intended_gameplay_meaning": asset["meaning"],
            "geometry_authority": "deterministic repository template and renderer; generated pixels are appearance only",
            "reviewer": "world-rendering lane ingestion authority",
            "disposition": "accepted for PLAY-022 calibration candidate after deterministic normalization and registration",
            "rejection_reasons": []
        }
        provenance_path.write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")

        lods = {}
        for lod in LODS:
            source = GENERATED / "normalized" / "calibration" / asset_id / f"generated_v4_{asset_id}_{lod}.png"
            destination = ATLAS / source.name
            shutil.copyfile(source, destination)
            pixels = next(item["pixels"] for item in normalization["outputs"] if item["lod"] == lod)
            digest = sha256(destination)
            lods[lod] = {"file": destination.name, "pixels": pixels, "sha256": digest}
            inventory.append({"file": destination.name, "sha256": digest})

        manifest_assets.append({
            "logical_id": asset_id,
            "family": asset["family"],
            "variant": 0,
            "level": 1 if "l01" in asset_id else 0,
            "state": "maintained",
            "footprint": asset["footprint"],
            "anchor": [0.5, 0.125],
            "ground_pivot": [768, 896],
            "world_size": [216, 144],
            "padding": 24,
            "filtering": "linear",
            "mipmap": False,
            "decoded_byte_estimate": sum(item["pixels"][0] * item["pixels"][1] * 4 for item in normalization["outputs"]),
            "source_sha256": sha256(raw_path),
            "prompt_sha256": sha256(prompt_path),
            "reference_sha256": [style_hash, template["sha256"]],
            "provenance_file": str(provenance_path.relative_to(PACKAGE.parent)),
            "lods": lods
        })

    manifest = {
        "schema": 4,
        "pack_id": catalog["pack_id"],
        "generator_version": "PLAY-022-calibration-2",
        "production_selection": True,
        "projection": catalog["projection"],
        "world_tile_points": catalog["world_tile_points"],
        "color_space": catalog["color_space"],
        "light_direction": catalog["light_direction"],
        "page_limit": {"active": 4, "maximum_pixels": [2048, 2048]},
        "assets": manifest_assets,
        "inventory": sorted(inventory, key=lambda item: item["file"])
    }
    (ATLAS / "generated-v4-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
