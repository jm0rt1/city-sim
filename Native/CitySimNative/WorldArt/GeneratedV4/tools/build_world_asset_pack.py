#!/usr/bin/env python3
"""Build the accepted generated-v4 calibration sources into production pages."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tempfile
from pathlib import Path

from PIL import Image

from pack_world_atlas import DETAILS, Payload, sha256, write_manifest, write_pages


ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / "GeneratedV4"
PACKAGE = ROOT.parent
CANONICAL_ATLAS = PACKAGE / "Sources" / "CitySimNative" / "Resources" / "WorldAssets.atlas"
MANIFEST_TEMPLATE = CANONICAL_ATLAS / "generated-v4-manifest.json"
STYLE = ROOT / "GateA" / "golden_district_imagegen_source-v2.png"


def relative_to_package(path: Path) -> str:
    return str(path.relative_to(PACKAGE.parent))


def repository_record(path: Path, role: str) -> dict[str, object]:
    return {
        "role": role,
        "file": relative_to_package(path),
        "sha256": sha256(path),
        "bytes": path.stat().st_size,
    }


def pixel_sha256(path: Path) -> str:
    with Image.open(path) as image:
        return hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()


def materialize_asset_payloads(
    manifest: dict[str, object],
    temporary: Path,
) -> tuple[list[Payload], dict[tuple[str, str], Path]]:
    payloads: list[Payload] = []
    paths: dict[tuple[str, str], Path] = {}
    for asset in manifest["assets"]:
        logical_id = asset["logical_id"]
        for detail in DETAILS:
            lod = asset["lods"][detail]
            normalized = (
                GENERATED
                / "normalized"
                / "calibration"
                / logical_id
                / f"generated_v4_{logical_id}_{detail}.png"
            )
            if sha256(normalized) != lod["normalized_sha256"]:
                raise SystemExit(
                    f"build rejected: normalized digest mismatch for {logical_id}.{detail}"
                )
            with Image.open(normalized) as source:
                if source.mode != "RGBA":
                    raise SystemExit(
                        f"build rejected: normalized source is not RGBA for {logical_id}.{detail}"
                    )
                x, y, width, height = lod["source_trim_rect_pixels"]
                payload = source.crop((x, y, x + width, y + height))
                destination = temporary / detail / f"asset-{logical_id}.png"
                destination.parent.mkdir(parents=True, exist_ok=True)
                payload.save(destination, format="PNG", compress_level=9, optimize=False)
            digest = sha256(destination)
            if digest != lod["sha256"]:
                raise SystemExit(
                    f"build rejected: accepted payload digest drift for {logical_id}.{detail}"
                )
            key = f"asset:{logical_id}"
            payloads.append(Payload(key, detail, destination, digest))
            paths[(key, detail)] = destination
    return payloads, paths


def materialize_network_payloads(
    manifest: dict[str, object],
) -> tuple[list[Payload], dict[tuple[str, str], Path]]:
    inventory = {item["file"]: item for item in manifest["inventory"]}
    payloads: list[Payload] = []
    paths: dict[tuple[str, str], Path] = {}
    for detail in DETAILS:
        for mask in range(16):
            filename = f"generated_v4_road_mask_{mask:02d}_{detail}.png"
            source = GENERATED / "compiled" / "calibration-network" / filename
            existing_texture = (
                manifest.get("compiled_network", {})
                .get("lods", {})
                .get(detail, {})
                .get("textures", {})
                .get(str(mask))
            )
            expected = (
                existing_texture["payload_sha256"]
                if existing_texture is not None
                else inventory[filename]["sha256"]
            )
            key = f"road:{mask:02d}"
            payloads.append(Payload(key, detail, source, expected))
            paths[(key, detail)] = source
    return payloads, paths


def provenance_inventory(manifest: dict[str, object]) -> list[dict[str, object]]:
    inventory = [repository_record(STYLE, "accepted-style-anchor")]
    for asset in sorted(manifest["assets"], key=lambda item: item["logical_id"]):
        logical_id = asset["logical_id"]
        prompt = GENERATED / "ImageGen" / "prompts" / "calibration" / f"{logical_id}.md"
        raw = GENERATED / "ImageGen" / "raw" / "calibration" / logical_id / "source-v01.png"
        provenance = (
            GENERATED / "ImageGen" / "provenance" / "calibration" / f"{logical_id}.json"
        )
        normalization = (
            GENERATED
            / "ImageGen"
            / "provenance"
            / "calibration"
            / f"{logical_id}-normalization.json"
        )
        inventory.extend(
            (
                repository_record(prompt, "prompt"),
                repository_record(raw, "accepted-raw-master"),
                repository_record(provenance, "provenance"),
                repository_record(normalization, "normalization-record"),
            )
        )
        asset["prompt_file"] = relative_to_package(prompt)
        asset["raw_source_file"] = relative_to_package(raw)
        asset["provenance_file"] = relative_to_package(provenance)
        asset["normalization_record_file"] = relative_to_package(normalization)
        asset["provenance_sha256"] = sha256(provenance)
        asset["normalization_record_sha256"] = sha256(normalization)
        for detail in DETAILS:
            normalized = (
                GENERATED
                / "normalized"
                / "calibration"
                / logical_id
                / f"generated_v4_{logical_id}_{detail}.png"
            )
            inventory.append(repository_record(normalized, f"normalized-{detail}"))
            asset["lods"][detail]["normalized_file"] = relative_to_package(normalized)
    for source in sorted(
        (GENERATED / "compiled" / "calibration-network").glob("generated_v4_road_mask_*.png")
    ):
        inventory.append(repository_record(source, "compiled-network-payload"))
    return sorted(inventory, key=lambda item: (item["file"], item["role"]))


def build(output_atlas: Path) -> None:
    manifest = json.loads(MANIFEST_TEMPLATE.read_text(encoding="utf-8"))
    if manifest.get("schema") != 4 or manifest.get("pack_id") != "generated-v4-calibration":
        raise SystemExit("build rejected: canonical manifest template is not generated-v4 schema 4")

    output_atlas.mkdir(parents=True, exist_ok=True)
    pages_directory = output_atlas / "pages"
    if pages_directory.exists():
        shutil.rmtree(pages_directory)

    with tempfile.TemporaryDirectory(prefix="citysim-generated-v4-payloads-") as directory:
        temporary = Path(directory)
        asset_payloads, _ = materialize_asset_payloads(manifest, temporary)
        network_payloads, _ = materialize_network_payloads(manifest)
        all_payloads = asset_payloads + network_payloads
        pages: list[dict[str, object]] = []
        placements = {}
        for detail in DETAILS:
            detail_pages, detail_placements = write_pages(
                detail,
                (payload for payload in all_payloads if payload.detail == detail),
                output_atlas,
            )
            pages.extend(detail_pages)
            placements.update(
                {(key, detail): value for key, value in detail_placements.items()}
            )

    for asset in manifest["assets"]:
        logical_id = asset["logical_id"]
        authoritative_anchor = list(asset["lods"]["block"]["anchor"])
        for detail in DETAILS:
            placement = placements[(f"asset:{logical_id}", detail)]
            lod = asset["lods"][detail]
            lod["anchor"] = authoritative_anchor
            lod["page"] = placement.page_id
            lod["page_file"] = placement.page_file
            lod["texture_rect_pixels"] = list(placement.texture_rect_pixels)
            lod["packed_rect_pixels"] = list(placement.packed_rect_pixels)
            x, y, width, height = lod["source_trim_rect_pixels"]
            normalized = (
                GENERATED
                / "normalized"
                / "calibration"
                / logical_id
                / f"generated_v4_{logical_id}_{detail}.png"
            )
            with Image.open(normalized) as source:
                payload = source.convert("RGBA").crop((x, y, x + width, y + height))
                lod["payload_pixel_sha256"] = hashlib.sha256(payload.tobytes()).hexdigest()
            lod["padding_pixels"] = 4
            lod["extrusion_pixels"] = 2

    for detail in DETAILS:
        descriptor = manifest["compiled_network"]["lods"][detail]
        descriptor["textures"] = {
            str(mask): {
                "page": placements[(f"road:{mask:02d}", detail)].page_id,
                "page_file": placements[(f"road:{mask:02d}", detail)].page_file,
                "texture_rect_pixels": list(
                    placements[(f"road:{mask:02d}", detail)].texture_rect_pixels
                ),
                "packed_rect_pixels": list(
                    placements[(f"road:{mask:02d}", detail)].packed_rect_pixels
                ),
                "payload_sha256": placements[
                    (f"road:{mask:02d}", detail)
                ].payload_sha256,
                "payload_pixel_sha256": pixel_sha256(
                    GENERATED
                    / "compiled"
                    / "calibration-network"
                    / f"generated_v4_road_mask_{mask:02d}_{detail}.png"
                ),
                "padding_pixels": 4,
                "extrusion_pixels": 2,
            }
            for mask in range(16)
        }

    manifest["generator_version"] = "PLAY-023-generated-v4-production-1"
    manifest["pages"] = sorted(pages, key=lambda item: item["id"])
    manifest["inventory"] = [
        {
            "file": page["file"],
            "sha256": page["sha256"],
            "pixels": page["pixels"],
            "decoded_byte_estimate": page["decoded_byte_estimate"],
        }
        for page in manifest["pages"]
    ]
    manifest["source_inventory"] = provenance_inventory(manifest)
    manifest["packing"] = {
        "algorithm": "stable-detail-key-shelf-v1",
        "sort": "detail then semantic key",
        "rotation": False,
        "padding_pixels": 4,
        "extrusion_pixels": 2,
        "maximum_page_pixels": [2048, 2048],
        "png": "RGBA8 sRGB-compatible; metadata stripped; compress_level=9; optimize=false",
    }
    manifest["rollback"] = {
        "production_pack_id": "generated-v4-calibration",
        "debug_pack_id": "legacy-v2",
        "environment_key": "CITYSIM_WORLD_ASSET_PACK",
        "save_or_simulation_contract_change": False,
    }
    manifest["build"] = {
        "command": (
            "python3 Native/CitySimNative/WorldArt/GeneratedV4/tools/"
            "build_world_asset_pack.py --output-atlas <path>"
        ),
        "absolute_development_paths": False,
        "image_generation": False,
        "source_mutation": False,
    }
    write_manifest(output_atlas / "generated-v4-manifest.json", manifest)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-atlas", required=True, type=Path)
    args = parser.parse_args()
    build(args.output_atlas.resolve())


if __name__ == "__main__":
    main()
