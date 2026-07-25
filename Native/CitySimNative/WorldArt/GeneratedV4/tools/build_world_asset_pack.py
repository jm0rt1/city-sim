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
PLAY027 = ROOT / "OfflineScene" / "PLAY-027"
PLAY028_SELECTION = GENERATED / "catalog" / "play-028-residential-directions.json"
PLAY060_SELECTION = GENERATED / "catalog" / "play-060-commercial-directions.json"
RAW_CANVAS = (1536, 1024)
GROUND_PIVOT = (768, 896)
WORLD_POINTS_PER_RAW_PIXEL = 72 / 512
PLACEMENT_OFFSET = (0.0, -18.0)
DIRECTION_SOCKET_WORLD = {
    "north": (18.0, 9.0),
    "east": (18.0, -9.0),
    "south": (-18.0, -9.0),
    "west": (-18.0, 9.0),
}
WORLD_HALF_TILE = (36.0, 18.0)


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


def repository_path(relative: str) -> Path:
    path = PACKAGE.parent / relative
    if not path.is_file():
        raise SystemExit(f"build rejected: repository input is missing: {relative}")
    return path


def normalized_path(asset: dict[str, object], detail: str) -> Path:
    return repository_path(asset["lods"][detail]["normalized_file"])


def rounded(value: float) -> float:
    return round(value, 8)


def source_point_to_world(point: list[float]) -> tuple[float, float]:
    return (
        rounded((float(point[0]) - GROUND_PIVOT[0]) * WORLD_POINTS_PER_RAW_PIXEL),
        rounded(
            PLACEMENT_OFFSET[1]
            + (GROUND_PIVOT[1] - float(point[1])) * WORLD_POINTS_PER_RAW_PIXEL
        ),
    )


def entrance_exclusion_rect(
    socket_source: list[float],
    door_base_source: list[list[float]],
) -> list[float]:
    points = [
        source_point_to_world(socket_source),
        *(source_point_to_world(point) for point in door_base_source),
    ]
    padding = 2.0
    minimum_x = max(-WORLD_HALF_TILE[0], min(point[0] for point in points) - padding)
    maximum_x = min(WORLD_HALF_TILE[0], max(point[0] for point in points) + padding)
    minimum_y = max(-WORLD_HALF_TILE[1], min(point[1] for point in points) - padding)
    maximum_y = min(WORLD_HALF_TILE[1], max(point[1] for point in points) + padding)
    return [
        rounded(minimum_x),
        rounded(minimum_y),
        rounded(maximum_x - minimum_x),
        rounded(maximum_y - minimum_y),
    ]


def directional_building_assets(
    selection_path: Path,
    family: str,
    task: str,
) -> list[dict[str, object]]:
    catalog = json.loads(selection_path.read_text(encoding="utf-8"))
    selections = catalog.get("selections", [])
    expected = {
        (level, direction)
        for level in range(1, 5)
        for direction in ("north", "east", "south", "west")
    }
    actual = {(item.get("level"), item.get("direction")) for item in selections}
    if catalog.get("schema") != 1 or actual != expected or len(selections) != 16:
        raise SystemExit(
            f"build rejected: {task} {family} selection is not the exact L1-L4 N/E/S/W matrix"
        )
    if len({item["raw_sha256"] for item in selections}) != 16:
        raise SystemExit(f"build rejected: {task} {family} raw sources are aliased")
    normalized_hashes = [
        item["normalized_sha256"][detail]
        for item in selections
        for detail in DETAILS
    ]
    if len(set(normalized_hashes)) != 48:
        raise SystemExit(f"build rejected: {task} {family} normalized LODs are aliased")

    assets: list[dict[str, object]] = []
    for selection in sorted(selections, key=lambda item: (item["level"], item["direction"])):
        level = int(selection["level"])
        direction = str(selection["direction"])
        revision = str(selection["source_revision"])
        source_id = f"{family}_l{level:02d}"
        logical_id = f"{source_id}_v0_{direction}"
        relative_base = (
            f"CitySimNative/WorldArt/OfflineScene/PLAY-027/"
        )
        raw_file = (
            f"{relative_base}raw/{source_id}/variant-0/{direction}/{revision}.png"
        )
        provenance_file = (
            f"{relative_base}provenance/{source_id}/variant-0/{direction}/{revision}.json"
        )
        if task == "PLAY-028" and level == 1:
            normalization_name = f"{revision}-normalization.json"
        elif family == "commercial" and level > 1:
            normalization_name = f"normalization-{revision}-native-tool.json"
        else:
            normalization_name = f"normalization-{revision}-raw-tool.json"
        normalization_file = (
            f"{relative_base}provenance/{source_id}/variant-0/{direction}/"
            f"{normalization_name}"
        )
        scene_file = (
            f"{relative_base}scenes/{source_id}/variant-0/{direction}/scene.json"
        )
        raw = repository_path(raw_file)
        provenance = repository_path(provenance_file)
        normalization = repository_path(normalization_file)
        scene = repository_path(scene_file)
        provenance_data = json.loads(provenance.read_text(encoding="utf-8"))
        scene_data = json.loads(scene.read_text(encoding="utf-8"))
        if sha256(raw) != selection["raw_sha256"]:
            raise SystemExit(f"build rejected: raw digest mismatch for {logical_id}")
        if (
            provenance_data.get("sourceKey")
            != f"{source_id}/variant-0/{direction}/{revision}"
            or provenance_data.get("logicalBuildingID") != source_id
            or provenance_data.get("viewDirection") != direction
            or provenance_data.get("level") != level
            or provenance_data.get("orientationTransform") != "none"
            or provenance_data.get("authoredIndependently") is not True
        ):
            raise SystemExit(f"build rejected: provenance identity mismatch for {logical_id}")
        derivation = scene_data.get("derivation", {})
        if (
            scene_data.get("logicalBuildingID") != source_id
            or scene_data.get("viewDirection") != direction
            or scene_data.get("level") != level
            or scene_data.get("sourceRevision") != revision
            or scene_data.get("productionSelected") is not False
            or derivation.get("mirror") is not False
            or derivation.get("rotationDegrees") != 0
            or derivation.get("transform") != "none"
        ):
            raise SystemExit(f"build rejected: scene identity/transform mismatch for {logical_id}")
        registration = scene_data.get("registration", {})
        frontage_socket_source = registration.get("frontageSocketSource")
        door_base_source = registration.get("doorBaseSource")
        if (
            registration.get("tileBasisPoints") != [72, 36]
            or registration.get("groundPivotSource") != list(GROUND_PIVOT)
            or registration.get("orientationTransform") != "none"
            or not isinstance(frontage_socket_source, list)
            or len(frontage_socket_source) != 2
            or not isinstance(door_base_source, list)
            or len(door_base_source) != 2
            or any(not isinstance(point, list) or len(point) != 2 for point in door_base_source)
        ):
            raise SystemExit(f"build rejected: directional registration mismatch for {logical_id}")
        entrance_socket = source_point_to_world(frontage_socket_source)
        expected_socket = DIRECTION_SOCKET_WORLD[direction]
        if any(
            abs(actual - expected) > 0.000_001
            for actual, expected in zip(entrance_socket, expected_socket)
        ):
            raise SystemExit(f"build rejected: frontage socket drift for {logical_id}")
        exclusion_rect = entrance_exclusion_rect(
            frontage_socket_source,
            door_base_source,
        )

        lods: dict[str, dict[str, object]] = {}
        block_registration: tuple[float, float, list[float], list[float]] | None = None
        for detail in DETAILS:
            normalized_file = (
                f"{relative_base}normalized/{source_id}/variant-0/{direction}/{revision}/"
                f"generated_v4_{source_id}_{detail}.png"
            )
            normalized = repository_path(normalized_file)
            expected_sha = selection["normalized_sha256"][detail]
            if sha256(normalized) != expected_sha:
                raise SystemExit(
                    f"build rejected: normalized digest mismatch for {logical_id}.{detail}"
                )
            with Image.open(normalized) as image:
                if image.mode != "RGBA":
                    raise SystemExit(
                        f"build rejected: normalized source is not RGBA for {logical_id}.{detail}"
                    )
                alpha_bounds = image.getchannel("A").getbbox()
                if alpha_bounds is None:
                    raise SystemExit(f"build rejected: empty normalized source {logical_id}.{detail}")
                left, top, right, bottom = alpha_bounds
                width = right - left
                height = bottom - top
                source_pixels = list(image.size)
                pivot_x = GROUND_PIVOT[0] * image.width / RAW_CANVAS[0]
                pivot_y = GROUND_PIVOT[1] * image.height / RAW_CANVAS[1]
                anchor = [
                    rounded((pivot_x - left) / width),
                    rounded((bottom - pivot_y) / height),
                ]
                if detail == "block":
                    points_per_pixel = (
                        WORLD_POINTS_PER_RAW_PIXEL * RAW_CANVAS[0] / image.width
                    )
                    world_size = [
                        rounded(width * points_per_pixel),
                        rounded(height * points_per_pixel),
                    ]
                    opaque_bounds = [
                        rounded((left - pivot_x) * points_per_pixel),
                        rounded(
                            PLACEMENT_OFFSET[1]
                            - (bottom - pivot_y) * points_per_pixel
                        ),
                        rounded((right - pivot_x) * points_per_pixel),
                        rounded(
                            PLACEMENT_OFFSET[1]
                            + (pivot_y - top) * points_per_pixel
                        ),
                    ]
                    block_registration = (
                        anchor[0],
                        anchor[1],
                        world_size,
                        opaque_bounds,
                    )
            lods[detail] = {
                "file": f"generated_v4_{logical_id}_{detail}.png",
                "normalized_file": normalized_file,
                "normalized_sha256": expected_sha,
                "pixels": [width, height],
                "source_pixels": source_pixels,
                "source_trim_rect_pixels": [left, top, width, height],
                "trim_rect_pixels": [0, 0, width, height],
                "anchor": anchor,
                "world_size": [],
                "decoded_byte_estimate": width * height * 4,
                "padding_pixels": 4,
                "extrusion_pixels": 2,
            }
        if block_registration is None:
            raise SystemExit(f"build rejected: block registration missing for {logical_id}")
        anchor_x, anchor_y, world_size, opaque_bounds = block_registration
        for detail in DETAILS:
            lods[detail]["anchor"] = [anchor_x, anchor_y]
            lods[detail]["world_size"] = world_size

        material_file = provenance_data["materialLibraryFile"].replace(
            "Native/", "", 1
        )
        material = repository_path(material_file)
        assets.append(
            {
                "logical_id": logical_id,
                "source_key": provenance_data["sourceKey"],
                "source_revision": revision,
                "view_direction": direction,
                "family": family,
                "variant": 0,
                "level": level,
                "state": "maintained",
                "authoring_template": "1x1",
                "source_canvas_pixels": list(RAW_CANVAS),
                "source_footprint_tiles": [1, 1],
                "footprint_tiles": [1, 1],
                "supported_orientation": f"{direction}-facing-authored",
                "placement_offset_world": list(PLACEMENT_OFFSET),
                "ground_pivot_source": list(GROUND_PIVOT),
                "ground_contact_polygon_world": [
                    [0.0, 13.5],
                    [27.0, 0.0],
                    [0.0, -13.5],
                    [-27.0, 0.0],
                ],
                "opaque_bounds_world": opaque_bounds,
                "shadow_bounds_world": opaque_bounds,
                "allowed_overhang_world": [
                    rounded(max(0.0, -36.0 - opaque_bounds[0])),
                    rounded(max(0.0, opaque_bounds[2] - 36.0)),
                    rounded(max(0.0, -18.0 - opaque_bounds[1])),
                    rounded(max(0.0, opaque_bounds[3] - 18.0)),
                ],
                "frontage_edge": direction,
                "entrance_socket_world": list(entrance_socket),
                "road_setback_points": 0.0,
                "prop_exclusion_rects_world": [exclusion_rect],
                "depth_roles": {
                    "baked-shadow": 4.0,
                    "structure": 5.0,
                    "vegetation": 8.0,
                },
                "residency_id": f"generated-v4/{family}/{logical_id}",
                "decoded_byte_estimate": sum(
                    int(lod["decoded_byte_estimate"]) for lod in lods.values()
                ),
                "filtering": "linear",
                "mipmap": True,
                "padding": 24,
                "source_sha256": selection["raw_sha256"],
                "raw_source_file": raw_file,
                "provenance_file": provenance_file,
                "provenance_sha256": sha256(provenance),
                "normalization_record_file": normalization_file,
                "normalization_record_sha256": sha256(normalization),
                "scene_descriptor_file": scene_file,
                "scene_descriptor_sha256": sha256(scene),
                "material_library_file": material_file,
                "material_library_sha256": sha256(material),
                "reference_sha256": [
                    scene_data["styleAnchor"]["sha256"],
                    sha256(material),
                ],
                "lods": lods,
            }
        )
    return assets


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
            normalized = normalized_path(asset, detail)
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
            if "sha256" not in lod:
                lod["sha256"] = digest
            elif digest != lod["sha256"]:
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
        if asset.get("scene_descriptor_file"):
            inventory.extend(
                (
                    repository_record(
                        repository_path(asset["raw_source_file"]),
                        "accepted-raw-master",
                    ),
                    repository_record(
                        repository_path(asset["provenance_file"]),
                        "provenance",
                    ),
                    repository_record(
                        repository_path(asset["normalization_record_file"]),
                        "normalization-record",
                    ),
                    repository_record(
                        repository_path(asset["scene_descriptor_file"]),
                        "offline-scene-descriptor",
                    ),
                    repository_record(
                        repository_path(asset["material_library_file"]),
                        "material-library",
                    ),
                )
            )
        else:
            prompt = (
                GENERATED / "ImageGen" / "prompts" / "calibration" / f"{logical_id}.md"
            )
            raw = (
                GENERATED
                / "ImageGen"
                / "raw"
                / "calibration"
                / logical_id
                / "source-v01.png"
            )
            provenance = (
                GENERATED
                / "ImageGen"
                / "provenance"
                / "calibration"
                / f"{logical_id}.json"
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
            normalized = normalized_path(asset, detail)
            inventory.append(repository_record(normalized, f"normalized-{detail}"))
            asset["lods"][detail]["normalized_file"] = relative_to_package(normalized)
    for source in sorted(
        (GENERATED / "compiled" / "calibration-network").glob("generated_v4_road_mask_*.png")
    ):
        inventory.append(repository_record(source, "compiled-network-payload"))
    unique = {
        (item["file"], item["role"]): item
        for item in inventory
    }
    return sorted(unique.values(), key=lambda item: (item["file"], item["role"]))


def build(output_atlas: Path) -> None:
    manifest = json.loads(MANIFEST_TEMPLATE.read_text(encoding="utf-8"))
    if manifest.get("schema") != 4 or manifest.get("pack_id") != "generated-v4-calibration":
        raise SystemExit("build rejected: canonical manifest template is not generated-v4 schema 4")
    directional_assets = (
        directional_building_assets(
            PLAY028_SELECTION,
            "residential",
            "PLAY-028",
        )
        + directional_building_assets(
            PLAY060_SELECTION,
            "commercial",
            "PLAY-060",
        )
    )
    directional_ids = {asset["logical_id"] for asset in directional_assets}
    manifest["assets"] = [
        asset for asset in manifest["assets"] if asset.get("logical_id") not in directional_ids
    ] + directional_assets
    manifest["assets"] = sorted(manifest["assets"], key=lambda item: item["logical_id"])

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
            normalized = normalized_path(asset, detail)
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

    manifest["generator_version"] = "PLAY-060-directional-commercial-production-1"
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
        "algorithm": "stable-detail-tall-first-shelf-v2",
        "sort": "detail then descending height, descending width, semantic key",
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
