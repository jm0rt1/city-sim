#!/usr/bin/env python3
"""Register the nine normalized PLAY-022 calibration sources for SwiftPM shipping."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / "GeneratedV4"
PACKAGE = ROOT.parent
ATLAS = PACKAGE / "Sources" / "CitySimNative" / "Resources" / "WorldAssets.atlas"
CATALOG_PATH = GENERATED / "catalog" / "calibration-assets.json"
TEMPLATES_PATH = GENERATED / "templates" / "registration-templates.json"
STYLE_PATH = ROOT / "GateA" / "golden_district_imagegen_source-v2.png"
LODS = ("city", "neighborhood", "block")
ROAD_LODS = {"block": [512, 256], "neighborhood": [256, 128], "city": [128, 64]}
WORLD_POINTS_PER_AUTHORING_PIXEL = 72 / 512
TRIM_PADDING_WORLD = 0.5
PLACEMENT_OFFSET_WORLD = (0.0, -18.0)
DEPTH_ROLE_VALUES = {
    "ground": -4.0,
    "network": 2.0,
    "frontage": 3.0,
    "baked-shadow": 4.0,
    "structure": 5.0,
    "vegetation": 8.0,
    "props": 10.0,
}
SHIPPING_TRANSFORM_COMMAND = (
    "python3 Native/CitySimNative/WorldArt/GeneratedV4/tools/build_calibration_pack.py"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def lod_geometry(source_pixels: list[int], source_bbox: list[int], scale: float) -> dict[str, object]:
    pixel_width, pixel_height = source_pixels
    x0 = max(0, math.floor(source_bbox[0] * pixel_width / 1536) - 1)
    y0 = max(0, math.floor(source_bbox[1] * pixel_height / 1024) - 1)
    x1 = min(pixel_width, math.ceil(source_bbox[2] * pixel_width / 1536) + 1)
    y1 = min(pixel_height, math.ceil(source_bbox[3] * pixel_height / 1024) + 1)
    width = x1 - x0
    height = y1 - y0
    pivot_x = 768 * pixel_width / 1536
    pivot_y = 896 * pixel_height / 1024
    anchor_x = (pivot_x - x0) / width
    anchor_y = (y1 - pivot_y) / height
    world_size = [
        (source_bbox[2] - source_bbox[0]) * WORLD_POINTS_PER_AUTHORING_PIXEL * scale + TRIM_PADDING_WORLD,
        (source_bbox[3] - source_bbox[1]) * WORLD_POINTS_PER_AUTHORING_PIXEL * scale + TRIM_PADDING_WORLD,
    ]
    return {
        "pixels": [width, height],
        "trim_rect_pixels": [0, 0, width, height],
        "source_pixels": list(source_pixels),
        "source_trim_rect_pixels": [x0, y0, width, height],
        "anchor": [round(anchor_x, 8), round(anchor_y, 8)],
        "world_size": [round(value, 4) for value in world_size],
        "decoded_byte_estimate": width * height * 4,
    }


def physical_geometry(asset: dict[str, object], normalization: dict[str, object]) -> dict[str, object]:
    scale = float(asset["world_scale"])
    bbox = normalization["source_bbox"]
    world_width = (bbox[2] - bbox[0]) * WORLD_POINTS_PER_AUTHORING_PIXEL * scale
    world_height = (bbox[3] - bbox[1]) * WORLD_POINTS_PER_AUTHORING_PIXEL * scale
    anchor_x = (768 - bbox[0]) / (bbox[2] - bbox[0])
    anchor_y = (bbox[3] - 896) / (bbox[3] - bbox[1])
    min_x = PLACEMENT_OFFSET_WORLD[0] - anchor_x * world_width
    min_y = PLACEMENT_OFFSET_WORLD[1] - anchor_y * world_height
    max_x = min_x + world_width
    max_y = min_y + world_height
    inset = float(asset["ground_contact_inset"])
    half_width = 36.0 - inset
    half_height = 18.0 - inset / 2
    return {
        "placement_offset_world": list(PLACEMENT_OFFSET_WORLD),
        "ground_contact_polygon_world": [
            [0.0, half_height],
            [half_width, 0.0],
            [0.0, -half_height],
            [-half_width, 0.0],
        ],
        "opaque_bounds_world": [round(min_x, 4), round(min_y, 4), round(max_x, 4), round(max_y, 4)],
        "shadow_bounds_world": [round(min_x, 4), round(min_y, 4), round(max_x, 4), round(max_y, 4)],
        "allowed_overhang_world": [
            round(max(0.0, -36.0 - min_x), 4),
            round(max(0.0, max_x - 36.0), 4),
            round(max(0.0, -18.0 - min_y), 4),
            round(max(0.0, max_y - 18.0), 4),
        ],
        "entrance_socket_world": [0.0, -14.0],
        "road_setback_points": 4.0,
        "prop_exclusion_rects_world": [[-8.0, -18.0, 16.0, 11.0]],
    }


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
        lods = {}
        shipping_outputs = []
        decoded_byte_estimate = 0
        for lod in LODS:
            source = GENERATED / "normalized" / "calibration" / asset_id / f"generated_v4_{asset_id}_{lod}.png"
            destination = ATLAS / source.name
            normalization_output = next(item for item in normalization["outputs"] if item["lod"] == lod)
            source_pixels = normalization_output["pixels"]
            normalized_digest = sha256(source)
            if normalized_digest != normalization_output["sha256"]:
                raise SystemExit(f"registration rejected: normalized hash mismatch for {asset_id}.{lod}")
            geometry = lod_geometry(source_pixels, normalization["source_bbox"], float(asset["world_scale"]))
            source_x, source_y, width, height = geometry["source_trim_rect_pixels"]
            with Image.open(source) as image:
                if image.mode != "RGBA":
                    raise SystemExit(f"registration rejected: normalized source is not RGBA for {asset_id}.{lod}")
                if list(image.size) != source_pixels:
                    raise SystemExit(
                        f"registration rejected: normalized pixel mismatch for {asset_id}.{lod}: "
                        f"{image.size} != {tuple(source_pixels)}"
                    )
                payload = image.crop((source_x, source_y, source_x + width, source_y + height))
                payload.save(destination, format="PNG", compress_level=9, optimize=False)
            digest = sha256(destination)
            decoded_byte_estimate += int(geometry["decoded_byte_estimate"])
            lods[lod] = {
                "file": destination.name,
                "sha256": digest,
                "normalized_sha256": normalized_digest,
                **geometry,
            }
            inventory.append({
                "file": destination.name,
                "sha256": digest,
                "pixels": geometry["pixels"],
                "decoded_byte_estimate": geometry["decoded_byte_estimate"],
            })
            shipping_outputs.append({
                "lod": lod,
                "normalized_file": str(source.relative_to(PACKAGE.parent)),
                "normalized_sha256": normalized_digest,
                "source_pixels": source_pixels,
                "source_trim_rect_pixels": geometry["source_trim_rect_pixels"],
                "shipping_file": str(destination.relative_to(PACKAGE.parent)),
                "shipping_sha256": digest,
                "shipping_pixels": geometry["pixels"],
                "decoded_byte_estimate": geometry["decoded_byte_estimate"],
            })

        provenance["shipping_transform"] = {
            "command": SHIPPING_TRANSFORM_COMMAND,
            "operation": (
                "deterministic lossless physical crop of the immutable normalized LOD canvas to its "
                "registered source trim; anchor and world size remain authoritative manifest metadata"
            ),
            "raw_and_normalized_sources_mutated": False,
            "outputs": shipping_outputs,
        }
        provenance_path.write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")

        geometry = physical_geometry(asset, normalization)

        manifest_assets.append({
            "logical_id": asset_id,
            "family": asset["family"],
            "variant": 0,
            "level": 1 if "l01" in asset_id else 0,
            "state": "maintained",
            "authoring_template": template_id,
            "source_canvas_pixels": catalog["canvas_pixels"],
            "source_footprint_tiles": asset["source_footprint"],
            "footprint_tiles": asset["presentation_footprint"],
            "supported_orientation": asset["orientation"],
            "ground_pivot_source": catalog["ground_pivot"],
            "frontage_edge": asset["frontage_edge"],
            "depth_roles": {role: DEPTH_ROLE_VALUES[role] for role in asset["depth_roles"]},
            "residency_id": f"generated-v4/{asset['family']}/{asset_id}",
            "padding": 24,
            "filtering": "linear",
            "mipmap": False,
            "decoded_byte_estimate": decoded_byte_estimate,
            "source_sha256": sha256(raw_path),
            "prompt_sha256": sha256(prompt_path),
            "reference_sha256": [style_hash, template["sha256"]],
            "provenance_file": str(provenance_path.relative_to(PACKAGE.parent)),
            "lods": lods,
            **geometry,
        })

    for mask_value in range(16):
        for lod, pixels in ROAD_LODS.items():
            path = ATLAS / f"generated_v4_road_mask_{mask_value:02d}_{lod}.png"
            if not path.exists():
                raise SystemExit(f"registration rejected: missing compiled network texture {path}")
            inventory.append({
                "file": path.name,
                "sha256": sha256(path),
                "pixels": pixels,
                "decoded_byte_estimate": pixels[0] * pixels[1] * 4,
            })

    manifest = {
        "schema": 4,
        "pack_id": catalog["pack_id"],
        "generator_version": "PLAY-022-production-geometry-2-physical-trim",
        "production_selection": True,
        "projection": catalog["projection"],
        "world_tile_points": catalog["world_tile_points"],
        "color_space": catalog["color_space"],
        "light_direction": catalog["light_direction"],
        "page_limit": {"active": 4, "maximum_pixels": [2048, 2048]},
        "assets": manifest_assets,
        "inventory": sorted(inventory, key=lambda item: item["file"]),
        "compiled_network": {
            "source_logical_id": "road_material",
            "compiler": "WorldArt/GeneratedV4/tools/compile_calibration_network.py",
            "connection_masks": 16,
            "lods": {
                lod: {
                    "pixels": pixels,
                    "world_size": [74.0, 37.0],
                    "decoded_bytes_per_texture": pixels[0] * pixels[1] * 4,
                }
                for lod, pixels in ROAD_LODS.items()
            },
            "topology_authority": "RoadConnectionMask",
        },
    }
    (ATLAS / "generated-v4-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
