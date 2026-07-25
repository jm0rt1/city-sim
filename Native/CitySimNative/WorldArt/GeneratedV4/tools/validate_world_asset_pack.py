#!/usr/bin/env python3
"""Validate generated-v4 pages, registration, digests, seams, and staging."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageChops


DETAILS = ("city", "neighborhood", "block")
TARGET_BYTES = 96 * 1024 * 1024
HARD_BYTES = 128 * 1024 * 1024


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def is_power_of_two(value: int) -> bool:
    return value > 0 and value & (value - 1) == 0


def intersects(left: list[int], right: list[int]) -> bool:
    return not (
        left[0] + left[2] <= right[0]
        or right[0] + right[2] <= left[0]
        or left[1] + left[3] <= right[1]
        or right[1] + right[3] <= left[1]
    )


def crop(page: Image.Image, rect: list[int]) -> Image.Image:
    x, y, width, height = rect
    return page.crop((x, y, x + width, y + height))


def validate_extrusion(
    page: Image.Image,
    texture_rect: list[int],
    packed_rect: list[int],
    extrusion: int,
) -> bool:
    x, y, width, height = texture_rect
    packed_x, packed_y, packed_width, packed_height = packed_rect
    if packed_x + packed_width < x + width or packed_y + packed_height < y + height:
        return False
    content = crop(page, texture_rect)
    left = content.crop((0, 0, 1, height)).resize((extrusion, height))
    right = content.crop((width - 1, 0, width, height)).resize((extrusion, height))
    top = content.crop((0, 0, width, 1)).resize((width, extrusion))
    bottom = content.crop((0, height - 1, width, height)).resize((width, extrusion))
    comparisons = (
        (left, page.crop((x - extrusion, y, x, y + height))),
        (right, page.crop((x + width, y, x + width + extrusion, y + height))),
        (top, page.crop((x, y - extrusion, x + width, y))),
        (bottom, page.crop((x, y + height, x + width, y + height + extrusion))),
    )
    return all(ImageChops.difference(expected, actual).getbbox() is None for expected, actual in comparisons)


def validate_pack(atlas: Path, staged_atlas: Path | None) -> dict[str, object]:
    failures: list[str] = []
    manifest_path = atlas / "generated-v4-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    pages = {item["id"]: item for item in manifest.get("pages", [])}
    inventory = {item["file"]: item for item in manifest.get("inventory", [])}
    page_images: dict[str, Image.Image] = {}
    rectangles: dict[str, list[tuple[str, list[int]]]] = defaultdict(list)
    payload_checks = 0
    extrusion_checks = 0
    anchor_positions: dict[str, list[tuple[str, float, float]]] = defaultdict(list)

    if manifest.get("schema") != 4:
        failures.append("manifest schema is not 4")
    if manifest.get("pack_id") != "generated-v4-calibration":
        failures.append("manifest pack ID is not generated-v4-calibration")
    if manifest.get("production_selection") is not True:
        failures.append("generated-v4 is not the production selection")
    if len(pages) > 4:
        failures.append("pack contains more than four pages")
    if set(item["file"] for item in pages.values()) != set(inventory):
        failures.append("page inventory differs from declared pages")

    directional_residential = [
        asset
        for asset in manifest.get("assets", [])
        if asset.get("family") == "residential"
        and asset.get("view_direction") is not None
    ]
    expected_directional_ids = {
        f"residential_l{level:02d}_v0_{direction}"
        for level in range(1, 5)
        for direction in ("north", "east", "south", "west")
    }
    if {asset.get("logical_id") for asset in directional_residential} != expected_directional_ids:
        failures.append("directional residential selection is not the exact L1-L4 N/E/S/W matrix")
    if len({asset.get("source_key") for asset in directional_residential}) != 16:
        failures.append("directional residential source keys are missing or aliased")
    if len({asset.get("source_sha256") for asset in directional_residential}) != 16:
        failures.append("directional residential raw sources are missing or aliased")
    directional_normalized_hashes = {
        asset.get("lods", {}).get(detail, {}).get("normalized_sha256")
        for asset in directional_residential
        for detail in DETAILS
    }
    if None in directional_normalized_hashes or len(directional_normalized_hashes) != 48:
        failures.append("directional residential normalized LODs are missing or aliased")
    direction_sockets = {
        "north": [18.0, 9.0],
        "east": [18.0, -9.0],
        "south": [-18.0, -9.0],
        "west": [-18.0, 9.0],
    }
    for asset in directional_residential:
        direction = asset.get("view_direction")
        logical_id = asset.get("logical_id")
        level = asset.get("level")
        if (
            direction not in direction_sockets
            or level not in range(1, 5)
            or asset.get("variant") != 0
            or asset.get("frontage_edge") != direction
            or asset.get("supported_orientation") != f"{direction}-facing-authored"
            or asset.get("entrance_socket_world") != direction_sockets.get(direction)
        ):
            failures.append(f"{logical_id} has inconsistent level/frontage registration")
        for field in (
            "source_key",
            "source_revision",
            "source_sha256",
            "provenance_file",
            "provenance_sha256",
            "normalization_record_file",
            "normalization_record_sha256",
            "scene_descriptor_file",
            "scene_descriptor_sha256",
        ):
            if not asset.get(field):
                failures.append(f"{logical_id} is missing {field}")

    actual_pages = {
        str(path.relative_to(atlas))
        for path in (atlas / "pages").glob("*/*.png")
    }
    if actual_pages != set(inventory):
        failures.append("packed page directory contains missing or orphan files")

    for page_id, descriptor in sorted(pages.items()):
        path = atlas / descriptor["file"]
        if not path.exists():
            failures.append(f"missing page {page_id}")
            continue
        if sha256(path) != descriptor["sha256"]:
            failures.append(f"page digest mismatch {page_id}")
        image = Image.open(path)
        image.load()
        page_images[page_id] = image
        if image.mode != "RGBA":
            failures.append(f"page is not RGBA {page_id}")
        if list(image.size) != descriptor["pixels"]:
            failures.append(f"page dimensions mismatch {page_id}")
        if not all(is_power_of_two(value) and value <= 2048 for value in image.size):
            failures.append(f"page is not bounded power-of-two {page_id}")
        if descriptor["padding_pixels"] < 4 or descriptor["extrusion_pixels"] < 2:
            failures.append(f"page padding/extrusion is insufficient {page_id}")
        item = inventory.get(descriptor["file"])
        if item is None or item["sha256"] != descriptor["sha256"]:
            failures.append(f"page inventory digest mismatch {page_id}")

    def validate_payload(
        key: str,
        detail: str,
        descriptor: dict[str, object],
        payload_pixel_sha256: str,
    ) -> None:
        nonlocal payload_checks, extrusion_checks
        page_id = descriptor["page"]
        page = pages.get(page_id)
        image = page_images.get(page_id)
        if page is None or image is None:
            failures.append(f"{key}.{detail} references missing page")
            return
        if page["lod"] != detail:
            failures.append(f"{key}.{detail} crosses LOD pages")
        texture_rect = descriptor["texture_rect_pixels"]
        packed_rect = descriptor["packed_rect_pixels"]
        if len(texture_rect) != 4 or len(packed_rect) != 4:
            failures.append(f"{key}.{detail} has incomplete packed registration")
            return
        if texture_rect[0] < 0 or texture_rect[1] < 0:
            failures.append(f"{key}.{detail} has negative texture origin")
        if texture_rect[0] + texture_rect[2] > image.width or texture_rect[1] + texture_rect[3] > image.height:
            failures.append(f"{key}.{detail} exceeds page bounds")
            return
        rectangles[page_id].append((f"{key}.{detail}", packed_rect))
        payload = crop(image, texture_rect)
        if hashlib.sha256(payload.tobytes()).hexdigest() != payload_pixel_sha256:
            failures.append(f"{key}.{detail} payload digest changed after packing")
        payload_checks += 1
        if not validate_extrusion(
            image,
            texture_rect,
            packed_rect,
            int(descriptor["extrusion_pixels"]),
        ):
            failures.append(f"{key}.{detail} edge extrusion is invalid")
        extrusion_checks += 1

    for asset in sorted(manifest.get("assets", []), key=lambda item: item["logical_id"]):
        logical_id = asset["logical_id"]
        if not Path(asset["raw_source_file"]).is_absolute() and not Path(
            asset["provenance_file"]
        ).is_absolute():
            pass
        else:
            failures.append(f"{logical_id} contains an absolute development path")
        for detail in DETAILS:
            descriptor = asset["lods"][detail]
            validate_payload(
                logical_id,
                detail,
                descriptor,
                descriptor["payload_pixel_sha256"],
            )
            anchor_positions[logical_id].append(
                (
                    detail,
                    float(descriptor["anchor"][0]) * float(descriptor["world_size"][0]),
                    float(descriptor["anchor"][1]) * float(descriptor["world_size"][1]),
                )
            )

    network = manifest.get("compiled_network", {})
    if network.get("connection_masks") != 16:
        failures.append("compiled network does not declare 16 masks")
    for detail in DETAILS:
        lod = network.get("lods", {}).get(detail, {})
        textures = lod.get("textures", {})
        if set(textures) != {str(value) for value in range(16)}:
            failures.append(f"compiled network {detail} does not contain masks 0...15")
        for mask, descriptor in sorted(textures.items(), key=lambda item: int(item[0])):
            validate_payload(
                f"road-{int(mask):02d}",
                detail,
                descriptor,
                descriptor["payload_pixel_sha256"],
            )

    overlap_checks = 0
    for page_id, entries in rectangles.items():
        for index, (left_key, left) in enumerate(entries):
            for right_key, right in entries[index + 1 :]:
                overlap_checks += 1
                if intersects(left, right):
                    failures.append(f"packed rectangles overlap: {left_key} / {right_key} on {page_id}")

    anchor_drift: dict[str, float] = {}
    for logical_id, positions in anchor_positions.items():
        xs = [position[1] for position in positions]
        ys = [position[2] for position in positions]
        drift = max(max(xs) - min(xs), max(ys) - min(ys))
        anchor_drift[logical_id] = drift
        if drift > 0.5:
            failures.append(f"{logical_id} anchor drifts {drift:.4f} world points across LOD")

    decoded_by_detail = {
        detail: sum(
            int(page["decoded_byte_estimate"])
            for page in pages.values()
            if page["lod"] == detail
        )
        for detail in DETAILS
    }
    next_detail = {"city": "neighborhood", "neighborhood": "block", "block": "neighborhood"}
    active_plus_next = {
        detail: decoded_by_detail[detail] + decoded_by_detail[next_detail[detail]]
        for detail in DETAILS
    }
    for detail, decoded in active_plus_next.items():
        if decoded > HARD_BYTES:
            failures.append(f"{detail} active-plus-next pages exceed 128 MiB")

    rollback = manifest.get("rollback", {})
    if rollback.get("debug_pack_id") != "legacy-v2":
        failures.append("legacy-v2 rollback pack is not declared")
    for filename in ("manifest.json", "terrain_grass_0.png"):
        if not (atlas / filename).exists():
            failures.append(f"rollback resource missing: {filename}")

    staged_matches = None
    if staged_atlas is not None:
        staged_matches = True
        staged_manifest = staged_atlas / "generated-v4-manifest.json"
        if not staged_manifest.exists() or staged_manifest.read_bytes() != manifest_path.read_bytes():
            failures.append("staged manifest differs from source manifest")
            staged_matches = False
        for descriptor in pages.values():
            staged_page = staged_atlas / descriptor["file"]
            if not staged_page.exists() or sha256(staged_page) != descriptor["sha256"]:
                failures.append(f"staged page differs: {descriptor['file']}")
                staged_matches = False

    report = {
        "schema": 1,
        "pack_id": manifest.get("pack_id"),
        "manifest_sha256": sha256(manifest_path),
        "page_count": len(pages),
        "page_digests": {page_id: page["sha256"] for page_id, page in sorted(pages.items())},
        "page_decoded_bytes": decoded_by_detail,
        "active_plus_next_decoded_bytes": active_plus_next,
        "payload_digest_checks": payload_checks,
        "extrusion_checks": extrusion_checks,
        "packed_overlap_checks": overlap_checks,
        "anchor_drift_world": anchor_drift,
        "source_inventory_count": len(manifest.get("source_inventory", [])),
        "directional_residential_count": len(directional_residential),
        "directional_residential_raw_hash_count": len(
            {asset.get("source_sha256") for asset in directional_residential}
        ),
        "directional_residential_normalized_hash_count": len(
            directional_normalized_hashes
        ),
        "staged_matches_source": staged_matches,
        "fallback_policy": "explicit bounded diagnostic; production proof requires zero",
        "rollback_pack_id": rollback.get("debug_pack_id"),
        "failures": failures,
        "passed": not failures,
    }
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--atlas", required=True, type=Path)
    parser.add_argument("--staged-atlas", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = validate_pack(args.atlas.resolve(), args.staged_atlas.resolve() if args.staged_atlas else None)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    if not report["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
