#!/usr/bin/env python3
"""Build the accepted generated-v4 calibration sources into production pages."""

from __future__ import annotations

import argparse
import copy
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
REPOSITORY = PACKAGE.parent.parent
CANONICAL_ATLAS = PACKAGE / "Sources" / "CitySimNative" / "Resources" / "WorldAssets.atlas"
MANIFEST_TEMPLATE = CANONICAL_ATLAS / "generated-v4-manifest.json"
STYLE = ROOT / "GateA" / "golden_district_imagegen_source-v2.png"
PLAY027 = ROOT / "OfflineScene" / "PLAY-027"
PLAY028_SELECTION = GENERATED / "catalog" / "play-028-residential-directions.json"
PLAY060_SELECTION = GENERATED / "catalog" / "play-060-commercial-directions.json"
PLAY062_SELECTION = GENERATED / "catalog" / "play-062-industrial-l1-directions.json"
PLAY101_SELECTION = GENERATED / "catalog" / "play-101-industrial-l1-directions.json"
PLAY101_RESIDENTIAL_VARIANT_ONE = (
    ROOT / "ImageGenFourView" / "PLAY-101" / "residential_l01_v1"
)
PLAY097_RESIDENTIAL_VARIANT_TWO = (
    ROOT / "ImageGenFourView" / "PLAY-101" / "residential_l01_v2"
)
PLAY097_RESIDENTIAL_VARIANT_TWO_V02 = PLAY097_RESIDENTIAL_VARIANT_TWO / "visual-repair-v02"
PLAY097_RESIDENTIAL_VARIANT_TWO_V03 = PLAY097_RESIDENTIAL_VARIANT_TWO / "normalized-v03"
PLAY097_RESIDENTIAL_VARIANT_TWO_SELECTION = (
    GENERATED / "catalog" / "play-097-residential-l01-v2-directions.json"
)
PLAY098_COMMERCIAL_L01_VARIANT_ZERO = (
    ROOT / "ImageGenFourView" / "PLAY-101" / "commercial_l01_v0"
)
PLAY098_COMMERCIAL_L01_VARIANT_ZERO_SELECTION = (
    GENERATED / "catalog" / "play-098-commercial-l01-v0-directions.json"
)
PLAY113_CIVIC_L01_VARIANT_ZERO = (
    ROOT / "ImageGenFourView" / "PLAY-101" / "civic_l01_v0"
)
PLAY113_CIVIC_L01_VARIANT_ZERO_SELECTION = (
    GENERATED / "catalog" / "play-113-civic-l01-v0-directions.json"
)
PLAY073_INDUSTRIAL_L2_SELECTION = (
    GENERATED / "catalog" / "play-073-industrial-l2-directions.json"
)
PLAY073_INDUSTRIAL_L3_SELECTION = (
    GENERATED / "catalog" / "play-073-industrial-l3-directions.json"
)
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
PLAY101_RUNTIME_REGISTRATION_OFFSETS = {
    "north": 0,
    "east": 15,
    "south": 0,
    "west": 43,
}
WORLD_HALF_TILE = (36.0, 18.0)
PLAY101_RESIDENTIAL_VARIANT_ONE_COMMIT = (
    "3f129be25d4557dd6002cc7e11df065e962ff50c"
)
PLAY101_RESIDENTIAL_VARIANT_ONE_RECEIPT_SHA256 = (
    "9d8360f997bee2125e8223de36c709f2bc7f79ab68a63b5f2cac138134a7e95b"
)
PLAY101_RESIDENTIAL_VARIANT_ONE_ADMISSION_SHA256 = (
    "1bb0dc7e624c7daf926d057df091677f1b06463a812886b6b86d901743ff309b"
)
PLAY097_RESIDENTIAL_VARIANT_TWO_RECEIPT_SHA256 = (
    "377a8faf199f6958becc61ce5b745f1c4e42e4d3c2d42f3c8bea51ef903ed01d"
)
PLAY097_RESIDENTIAL_VARIANT_TWO_VALIDATION_SHA256 = (
    "548ee9f79214993d0f013d5fe7f9da944488826a9dd2ad2b900724a718f6c959"
)
PLAY097_RESIDENTIAL_VARIANT_TWO_DISPOSITION_SHA256 = (
    "46aa74373700c87101c04296e17f7bfed14e7108d542237f1c2da32dfecb10e3"
)
PLAY097_RESIDENTIAL_VARIANT_TWO_COMMIT = "9d83bd87339f169d888fce8a56eb574fb85aa6e1"
PLAY097_RESIDENTIAL_VARIANT_TWO_V03_NORMALIZATION_SHA256 = "219878c2a4a3d3a38f94a88b050555b6196f49d0ebcb5450a55e5dfd9bef8bef"
PLAY097_RESIDENTIAL_VARIANT_TWO_V03_VALIDATION_SHA256 = "e3c11faca1b1b49d6706e2a2384772eaf9ceca7a369ae6247fa316c09437db1e"
PLAY097_RESIDENTIAL_VARIANT_TWO_V03_ADMISSION_SHA256 = "f481c9f87fde4d1922b3852bc32b73433fb02a248c4248dbef54997a460a8669"
PLAY097_RESIDENTIAL_VARIANT_TWO_V03_COMMIT = "514d14746076d67170a0ce37b584381c8c00a3c0"
PLAY098_COMMERCIAL_L01_VARIANT_ZERO_NORMALIZATION_SHA256 = "fee98cce9a9285a5140721cd588bd6136ec6efced0daf807697d5b8fb3e9133f"
PLAY098_COMMERCIAL_L01_VARIANT_ZERO_ADMISSION_SHA256 = "7f129e06aa5a2c60b79f5c8e2d40ff41d089e065c190ff7768b51fcac1102812"
PLAY098_COMMERCIAL_L01_VARIANT_ZERO_COMMIT = "846fffe4146ae355d154dcae37a657ece4a62d49"
PLAY113_CIVIC_L01_VARIANT_ZERO_HANDOFF_SHA256 = "120db6f50010cdca691c619c92b47bac133635b91973c5fca73a3267584ce105"
PLAY113_CIVIC_L01_VARIANT_ZERO_VALIDATION_SHA256 = "c10674bcb6ef4403cb04c5655ae8b20c109e1a57d223d22f2833bf616d16d76d"
PLAY113_CIVIC_L01_VARIANT_ZERO_ADMISSION_SHA256 = "4efe5d9c7fe2dd67afe2a41c39c3e74496f9779e7e783334ece882ca0503eb5a"
PLAY113_CIVIC_L01_VARIANT_ZERO_COMMIT = "307094c65a595602cbbb7ddd5e8a434399dbb0cc"


def relative_to_package(path: Path) -> str:
    try:
        return str(path.relative_to(PACKAGE.parent))
    except ValueError:
        return str(path.relative_to(REPOSITORY))


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
    for root in (PACKAGE.parent, REPOSITORY):
        path = root / relative
        if path.is_file():
            return path
    raise SystemExit(f"build rejected: repository input is missing: {relative}")


def normalized_path(asset: dict[str, object], detail: str) -> Path:
    return repository_path(asset["lods"][detail]["normalized_file"])


def rounded(value: float) -> float:
    return round(value, 8)


def source_point_to_world(
    point: list[float],
    ground_pivot: list[float] | tuple[float, float] = GROUND_PIVOT,
) -> tuple[float, float]:
    return (
        rounded((float(point[0]) - float(ground_pivot[0])) * WORLD_POINTS_PER_RAW_PIXEL),
        rounded(
            PLACEMENT_OFFSET[1]
            + (float(ground_pivot[1]) - float(point[1])) * WORLD_POINTS_PER_RAW_PIXEL
        ),
    )


def entrance_exclusion_rect(
    socket_source: list[float],
    door_base_source: list[list[float]],
    ground_pivot: list[float] | tuple[float, float] = GROUND_PIVOT,
) -> list[float]:
    points = [
        source_point_to_world(socket_source, ground_pivot),
        *(source_point_to_world(point, ground_pivot) for point in door_base_source),
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


def validate_explicit_source_binding(
    selection: dict[str, object],
    provenance_data: dict[str, object],
    scene_data: dict[str, object],
    logical_id: str,
) -> None:
    """Reject accepted explicit sources whose descriptor or provenance drifted."""
    if selection.get("enforce_descriptor_binding") is not True:
        return

    revision = selection.get("source_revision")
    material_file = selection.get("material_library_file")
    material_sha256 = selection.get("material_library_sha256")
    scene_material = scene_data.get("materialLibrary", {})
    if not isinstance(scene_material, dict):
        raise SystemExit(
            f"build rejected: descriptor material binding is missing for {logical_id}"
        )
    if scene_data.get("sourceRevision") != revision:
        raise SystemExit(
            f"build rejected: descriptor source revision mismatch for {logical_id}"
        )
    if (
        scene_material.get("file") != material_file
        or scene_material.get("sha256") != material_sha256
    ):
        raise SystemExit(
            f"build rejected: descriptor material binding mismatch for {logical_id}"
        )
    if (
        provenance_data.get("materialLibraryFile") != material_file
        or provenance_data.get("materialLibrarySHA256") != material_sha256
    ):
        raise SystemExit(
            f"build rejected: provenance material binding mismatch for {logical_id}"
        )


def directional_building_assets(
    selection_path: Path,
    family: str,
    task: str,
    levels: tuple[int, ...] = (1, 2, 3, 4),
) -> list[dict[str, object]]:
    catalog = json.loads(selection_path.read_text(encoding="utf-8"))
    selections = catalog.get("selections", [])
    expected = {
        (level, direction)
        for level in levels
        for direction in ("north", "east", "south", "west")
    }
    actual = {(item.get("level"), item.get("direction")) for item in selections}
    expected_count = len(expected)
    if (
        catalog.get("schema") != 1
        or catalog.get("task") != task
        or actual != expected
        or len(selections) != expected_count
    ):
        raise SystemExit(
            f"build rejected: {task} {family} selection is not the exact "
            f"{'/'.join(f'L{level}' for level in levels)} N/E/S/W matrix"
        )
    if len({item["raw_sha256"] for item in selections}) != expected_count:
        raise SystemExit(f"build rejected: {task} {family} raw sources are aliased")
    normalized_hashes = [
        item["normalized_sha256"][detail]
        for item in selections
        for detail in DETAILS
    ]
    if len(set(normalized_hashes)) != expected_count * len(DETAILS):
        raise SystemExit(f"build rejected: {task} {family} normalized LODs are aliased")

    assets: list[dict[str, object]] = []
    for selection in sorted(selections, key=lambda item: (item["level"], item["direction"])):
        level = int(selection["level"])
        direction = str(selection["direction"])
        revision = str(selection["source_revision"])
        source_id = f"{family}_l{level:02d}"
        logical_id = f"{source_id}_v0_{direction}"
        relative_base = "CitySimNative/WorldArt/OfflineScene/PLAY-027/"
        explicit_files = "raw_file" in selection
        if explicit_files:
            raw_file = str(selection["raw_file"])
            provenance_file = str(selection["provenance_file"])
            normalization_file = str(selection["normalization_record_file"])
            scene_file = str(selection["scene_descriptor_file"])
        else:
            raw_file = (
                f"{relative_base}raw/{source_id}/variant-0/{direction}/{revision}.png"
            )
            provenance_file = (
                f"{relative_base}provenance/{source_id}/variant-0/{direction}/{revision}.json"
            )
            if task == "PLAY-028" and level == 1:
                normalization_name = f"{revision}-normalization.json"
            elif task == "PLAY-062":
                normalization_name = f"normalization-{revision}-native-tool.json"
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
        validate_explicit_source_binding(
            selection,
            provenance_data,
            scene_data,
            logical_id,
        )
        if sha256(raw) != selection["raw_sha256"]:
            raise SystemExit(f"build rejected: raw digest mismatch for {logical_id}")
        if explicit_files:
            if (
                selection.get("contract") not in (None, "CONTRACT-018")
                or not selection.get("source_key")
                or sha256(provenance) != selection.get("provenance_sha256", sha256(provenance))
                or sha256(normalization)
                != selection.get("normalization_record_sha256", sha256(normalization))
                or sha256(scene) != selection["scene_descriptor_sha256"]
            ):
                raise SystemExit(
                    f"build rejected: immutable source authority mismatch for {logical_id}"
                )
            normalization_data = json.loads(normalization.read_text(encoding="utf-8"))
            output_hashes = {
                item.get("lod"): item.get("sha256")
                for item in normalization_data.get("outputs", [])
            }
            if (
                normalization_data.get("productionSelected") is not False
                or normalization_data.get("source_sha256") != selection["raw_sha256"]
                or output_hashes != selection["normalized_sha256"]
            ):
                raise SystemExit(
                    f"build rejected: normalization authority mismatch for {logical_id}"
                )
            source_key = str(selection["source_key"])
        else:
            if (
                provenance_data.get("sourceKey")
                != f"{source_id}/variant-0/{direction}/{revision}"
                or provenance_data.get("logicalBuildingID") != source_id
                or provenance_data.get("viewDirection") != direction
                or provenance_data.get("level") != level
                or provenance_data.get("orientationTransform") != "none"
                or provenance_data.get("authoredIndependently") is not True
            ):
                raise SystemExit(
                    f"build rejected: provenance identity mismatch for {logical_id}"
                )
            source_key = str(provenance_data["sourceKey"])
        derivation = scene_data.get("derivation", {})
        if (
            scene_data.get("logicalBuildingID") != source_id
            or scene_data.get("viewDirection") != direction
            or scene_data.get("level") != level
            or (
                (
                    not explicit_files
                    or selection.get("enforce_descriptor_binding") is True
                )
                and scene_data.get("sourceRevision") != revision
            )
            or scene_data.get("productionSelected") is not False
            or derivation.get("mirror") is not False
            or derivation.get("rotationDegrees") != 0
            or derivation.get("transform") != "none"
        ):
            raise SystemExit(f"build rejected: scene identity/transform mismatch for {logical_id}")
        registration = scene_data.get("registration", {})
        frontage_socket_source = registration.get("frontageSocketSource")
        door_base_source = registration.get("doorBaseSource")
        registration_offset_y = (
            PLAY101_RUNTIME_REGISTRATION_OFFSETS[direction]
            if task == "PLAY-101" and family == "industrial" and level == 1
            else 0
        )
        ground_pivot_source = [
            GROUND_PIVOT[0],
            GROUND_PIVOT[1] + registration_offset_y,
        ]
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
        frontage_socket_source = [
            frontage_socket_source[0],
            frontage_socket_source[1] + registration_offset_y,
        ]
        door_base_source = [
            [point[0], point[1] + registration_offset_y]
            for point in door_base_source
        ]
        entrance_socket = source_point_to_world(frontage_socket_source, ground_pivot_source)
        expected_socket = DIRECTION_SOCKET_WORLD[direction]
        if any(
            abs(actual - expected) > 0.000_001
            for actual, expected in zip(entrance_socket, expected_socket)
        ):
            raise SystemExit(f"build rejected: frontage socket drift for {logical_id}")
        exclusion_rect = entrance_exclusion_rect(
            frontage_socket_source,
            door_base_source,
            ground_pivot_source,
        )

        lods: dict[str, dict[str, object]] = {}
        block_registration: tuple[float, float, list[float], list[float]] | None = None
        for detail in DETAILS:
            normalized_file = (
                str(selection["normalized_files"][detail])
                if explicit_files
                else (
                    f"{relative_base}normalized/{source_id}/variant-0/{direction}/{revision}/"
                    f"generated_v4_{source_id}_{detail}.png"
                )
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
                pivot_x = ground_pivot_source[0] * image.width / RAW_CANVAS[0]
                pivot_y = ground_pivot_source[1] * image.height / RAW_CANVAS[1]
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

        material_file = (
            str(selection["material_library_file"])
            if explicit_files
            else provenance_data["materialLibraryFile"].replace("Native/", "", 1)
        )
        material = repository_path(material_file)
        if explicit_files and sha256(material) != selection["material_library_sha256"]:
            raise SystemExit(f"build rejected: material authority mismatch for {logical_id}")
        assets.append(
            {
                "logical_id": logical_id,
                "source_key": source_key,
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
                "ground_pivot_source": ground_pivot_source,
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


def residential_variant_one_assets(
    manifest: dict[str, object],
) -> list[dict[str, object]]:
    """Bind the exact admitted four-view variant-one family to generated-v4."""

    receipt_path = PLAY101_RESIDENTIAL_VARIANT_ONE / "BUILD-RECEIPT.json"
    admission_path = (
        REPOSITORY
        / "docs/production/evidence/PLAY-101/residential-l01-v1-family/FAMILY-ADMISSION.json"
    )
    if (
        sha256(receipt_path) != PLAY101_RESIDENTIAL_VARIANT_ONE_RECEIPT_SHA256
        or sha256(admission_path) != PLAY101_RESIDENTIAL_VARIANT_ONE_ADMISSION_SHA256
    ):
        raise SystemExit("build rejected: residential L1 variant-one authority drift")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    admission = json.loads(admission_path.read_text(encoding="utf-8"))
    directions = ("north", "east", "south", "west")
    if (
        receipt.get("schema") != "citysim.play-101.residential-l01-v1.build.v1"
        or receipt.get("family") != "residential_l01_v1"
        or set(receipt.get("directions", [])) != set(directions)
        or admission.get("decision") != "ADMIT_SOURCE_FAMILY"
        or admission.get("sourceAdmitted") is not True
    ):
        raise SystemExit("build rejected: residential L1 variant-one admission mismatch")

    raw_hashes = {
        direction: receipt["rawSources"][direction]["sha256"]
        for direction in directions
    }
    lod_hashes = [
        receipt["lods"][direction][detail]["sha256"]
        for direction in directions
        for detail in DETAILS
    ]
    if len(set(raw_hashes.values())) != 4 or len(set(lod_hashes)) != 12:
        raise SystemExit("build rejected: residential L1 variant-one source alias")

    templates = {
        asset["view_direction"]: asset
        for asset in manifest["assets"]
        if asset.get("family") == "residential"
        and asset.get("level") == 1
        and asset.get("variant") == 0
        and asset.get("view_direction") in directions
    }
    if set(templates) != set(directions):
        raise SystemExit("build rejected: residential L1 registration templates missing")

    assets: list[dict[str, object]] = []
    for direction in directions:
        source = receipt["rawSources"][direction]
        raw = REPOSITORY / source["path"]
        if sha256(raw) != source["sha256"]:
            raise SystemExit(
                f"build rejected: residential L1 variant-one raw drift for {direction}"
            )

        asset = copy.deepcopy(templates[direction])
        template_world_size = list(asset["lods"]["block"]["world_size"])
        logical_id = f"residential_l01_v1_{direction}"
        asset.update(
            {
                "logical_id": logical_id,
                "source_key": f"residential_l01/variant-1/{direction}/source-v01",
                "source_revision": "source-v01",
                "variant": 1,
                "state": "maintained",
                "residency_id": f"generated-v4/residential/{logical_id}",
                "source_sha256": source["sha256"],
                "raw_source_file": source["path"].replace("Native/", "", 1),
                "provenance_file": relative_to_package(receipt_path),
                "provenance_sha256": PLAY101_RESIDENTIAL_VARIANT_ONE_RECEIPT_SHA256,
                "normalization_record_file": relative_to_package(receipt_path),
                "normalization_record_sha256": PLAY101_RESIDENTIAL_VARIANT_ONE_RECEIPT_SHA256,
                "reference_sha256": [
                    PLAY101_RESIDENTIAL_VARIANT_ONE_ADMISSION_SHA256,
                    PLAY101_RESIDENTIAL_VARIANT_ONE_RECEIPT_SHA256,
                ],
                "source_packet_file": relative_to_package(receipt_path),
                "source_packet_commit": PLAY101_RESIDENTIAL_VARIANT_ONE_COMMIT,
            }
        )
        for key in (
            "prompt_file",
            "scene_descriptor_file",
            "scene_descriptor_sha256",
            "material_library_file",
            "material_library_sha256",
        ):
            asset.pop(key, None)

        lods: dict[str, dict[str, object]] = {}
        block_registration: tuple[float, float, list[float], list[float]] | None = None
        for detail in DETAILS:
            row = receipt["lods"][direction][detail]
            normalized = PLAY101_RESIDENTIAL_VARIANT_ONE / row["path"]
            if sha256(normalized) != row["sha256"]:
                raise SystemExit(
                    f"build rejected: residential L1 variant-one LOD drift for "
                    f"{direction}.{detail}"
                )
            with Image.open(normalized) as image:
                if image.mode != "RGBA" or list(image.size) != row["dimensions"]:
                    raise SystemExit(
                        f"build rejected: residential L1 variant-one LOD shape for "
                        f"{direction}.{detail}"
                    )
                alpha_bounds = image.getchannel("A").getbbox()
                if alpha_bounds is None:
                    raise SystemExit(
                        f"build rejected: empty residential L1 variant-one LOD "
                        f"{direction}.{detail}"
                    )
                left, top, right, bottom = alpha_bounds
                width = right - left
                height = bottom - top
                pivot_x = GROUND_PIVOT[0] * image.width / RAW_CANVAS[0]
                pivot_y = GROUND_PIVOT[1] * image.height / RAW_CANVAS[1]
                anchor = [
                    rounded((pivot_x - left) / width),
                    rounded((bottom - pivot_y) / height),
                ]
                if detail == "block":
                    points_per_pixel = min(
                        template_world_size[0] / width,
                        template_world_size[1] / height,
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
                "normalized_file": relative_to_package(normalized),
                "normalized_sha256": row["sha256"],
                "pixels": [width, height],
                "source_pixels": row["dimensions"],
                "source_trim_rect_pixels": [left, top, width, height],
                "trim_rect_pixels": [0, 0, width, height],
                "anchor": anchor,
                "world_size": [],
                "decoded_byte_estimate": width * height * 4,
                "padding_pixels": 4,
                "extrusion_pixels": 2,
            }
        if block_registration is None:
            raise SystemExit(
                f"build rejected: residential L1 variant-one registration missing for {direction}"
            )
        anchor_x, anchor_y, world_size, opaque_bounds = block_registration
        for detail in DETAILS:
            lods[detail]["anchor"] = [anchor_x, anchor_y]
            lods[detail]["world_size"] = world_size
        asset["lods"] = lods
        asset["opaque_bounds_world"] = opaque_bounds
        asset["shadow_bounds_world"] = opaque_bounds
        asset["allowed_overhang_world"] = [
            rounded(max(0.0, -36.0 - opaque_bounds[0])),
            rounded(max(0.0, opaque_bounds[2] - 36.0)),
            rounded(max(0.0, -18.0 - opaque_bounds[1])),
            rounded(max(0.0, opaque_bounds[3] - 18.0)),
        ]
        asset["decoded_byte_estimate"] = sum(
            int(lod["decoded_byte_estimate"]) for lod in lods.values()
        )
        assets.append(asset)
    return assets


def residential_variant_two_assets(
    manifest: dict[str, object],
) -> list[dict[str, object]]:
    """Bind the exact PLAY-097 residential variant-two family."""
    receipt_path = PLAY097_RESIDENTIAL_VARIANT_TWO_V03 / "NORMALIZATION-RECEIPT.json"
    validation_path = (
        REPOSITORY
        / "docs/production/evidence/PLAY-097/residential-l01-v2-family/VALIDATION-RESULT-V03.json"
    )
    admission_path = (
        REPOSITORY
        / "docs/production/evidence/PLAY-097/residential-l01-v2-family/SOURCE-ADMISSION-RECEIPT-V03.json"
    )
    if (
        sha256(receipt_path) != PLAY097_RESIDENTIAL_VARIANT_TWO_V03_NORMALIZATION_SHA256
        or sha256(validation_path) != PLAY097_RESIDENTIAL_VARIANT_TWO_V03_VALIDATION_SHA256
        or sha256(admission_path) != PLAY097_RESIDENTIAL_VARIANT_TWO_V03_ADMISSION_SHA256
    ):
        raise SystemExit("build rejected: residential L1 variant-two authority drift")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    validation = json.loads(validation_path.read_text(encoding="utf-8"))
    admission = json.loads(admission_path.read_text(encoding="utf-8"))
    selection = json.loads(PLAY097_RESIDENTIAL_VARIANT_TWO_SELECTION.read_text(encoding="utf-8"))
    directions = ("north", "east", "south", "west")
    rows = {item["direction"]: item for item in selection.get("selections", [])}
    if (
        selection.get("schema") != 1
        or selection.get("task") != "PLAY-097"
        or selection.get("family") != "residential_l01_v2"
        or set(rows) != set(directions)
        or receipt.get("schema") != "citysim.play-097.residential-l01-v2.normalization-v03.v1"
        or receipt.get("family") != "residential_l01_v2"
        or set(receipt.get("directions", [])) != set(directions)
        or validation.get("result") != "PASS"
        or validation.get("result") != "PASS"
        or admission.get("candidateOnly") is not True
    ):
        raise SystemExit("build rejected: residential L1 variant-two selection mismatch")
    raw_hashes = {direction: receipt["rawSources"][direction]["sha256"] for direction in directions}
    lod_hashes = [receipt["lods"][direction][detail]["sha256"] for direction in directions for detail in DETAILS]
    if len(set(raw_hashes.values())) != 4 or len(set(lod_hashes)) != 12:
        raise SystemExit("build rejected: residential L1 variant-two source alias")
    templates = {
        asset["view_direction"]: asset
        for asset in manifest["assets"]
        if asset.get("family") == "residential"
        and asset.get("level") == 1
        and asset.get("variant") == 0
        and asset.get("view_direction") in directions
    }
    if set(templates) != set(directions):
        raise SystemExit("build rejected: residential L1 variant-two templates missing")
    assets: list[dict[str, object]] = []
    for direction in directions:
        row = rows[direction]
        source = receipt["rawSources"][direction]
        raw = REPOSITORY / source["path"]
        if sha256(raw) != source["sha256"] or row["raw_sha256"] != source["sha256"]:
            raise SystemExit(f"build rejected: residential L1 variant-two raw drift for {direction}")
        asset = copy.deepcopy(templates[direction])
        logical_id = f"residential_l01_v2_{direction}"
        asset.update({
            "logical_id": logical_id,
            "source_key": f"residential_l01/variant-2/{direction}/source-v03",
            "source_revision": "source-v03",
            "variant": 2,
            "state": "maintained",
            "residency_id": f"generated-v4/residential/{logical_id}",
            "source_sha256": source["sha256"],
            "raw_source_file": source["path"].replace("Native/", "", 1),
            "provenance_file": relative_to_package(receipt_path),
            "provenance_sha256": PLAY097_RESIDENTIAL_VARIANT_TWO_V03_NORMALIZATION_SHA256,
            "normalization_record_file": relative_to_package(receipt_path),
            "normalization_record_sha256": PLAY097_RESIDENTIAL_VARIANT_TWO_V03_NORMALIZATION_SHA256,
            "reference_sha256": [PLAY097_RESIDENTIAL_VARIANT_TWO_V03_VALIDATION_SHA256, PLAY097_RESIDENTIAL_VARIANT_TWO_V03_ADMISSION_SHA256, PLAY097_RESIDENTIAL_VARIANT_TWO_V03_NORMALIZATION_SHA256],
            "source_packet_file": relative_to_package(receipt_path),
            "source_packet_commit": PLAY097_RESIDENTIAL_VARIANT_TWO_V03_COMMIT,
            "frontage_edge": direction,
            "view_direction": direction,
            "supported_orientation": f"{direction}-facing-authored",
            "entrance_socket_world": list(DIRECTION_SOCKET_WORLD[direction]),
            "ground_pivot_source": list(GROUND_PIVOT),
            "placement_offset_world": list(PLACEMENT_OFFSET),
        })
        for key in ("prompt_file", "prompt_sha256", "scene_descriptor_file", "scene_descriptor_sha256", "material_library_file", "material_library_sha256"):
            asset.pop(key, None)
        lods: dict[str, dict[str, object]] = {}
        block_registration = None
        for detail in DETAILS:
            row = receipt["lods"][direction][detail]
            normalized = REPOSITORY / row["path"]
            if sha256(normalized) != row["sha256"] or row["sha256"] != selection["selections"][directions.index(direction)]["normalized_sha256"][detail]:
                raise SystemExit(f"build rejected: residential L1 variant-two LOD drift for {direction}.{detail}")
            with Image.open(normalized) as image:
                if image.mode != "RGBA" or list(image.size) != row["dimensions"]:
                    raise SystemExit(f"build rejected: residential L1 variant-two LOD shape for {direction}.{detail}")
                alpha_bounds = image.getchannel("A").getbbox()
                if alpha_bounds is None:
                    raise SystemExit(f"build rejected: empty residential L1 variant-two LOD {direction}.{detail}")
                left, top, right, bottom = alpha_bounds
                width, height = right - left, bottom - top
                pivot_x = GROUND_PIVOT[0] * image.width / RAW_CANVAS[0]
                pivot_y = GROUND_PIVOT[1] * image.height / RAW_CANVAS[1]
                anchor = [rounded((pivot_x - left) / width), rounded((bottom - pivot_y) / height)]
                if detail == "block":
                    points_per_pixel = min(WORLD_POINTS_PER_RAW_PIXEL * RAW_CANVAS[0] / image.width, WORLD_POINTS_PER_RAW_PIXEL * RAW_CANVAS[1] / image.height)
                    world_size = [rounded(width * points_per_pixel), rounded(height * points_per_pixel)]
                    opaque_bounds = [rounded((left - pivot_x) * points_per_pixel), rounded(PLACEMENT_OFFSET[1] - (bottom - pivot_y) * points_per_pixel), rounded((right - pivot_x) * points_per_pixel), rounded(PLACEMENT_OFFSET[1] + (pivot_y - top) * points_per_pixel)]
                    block_registration = (anchor[0], anchor[1], world_size, opaque_bounds)
            lods[detail] = {"file": f"generated_v4_{logical_id}_{detail}.png", "normalized_file": relative_to_package(normalized), "normalized_sha256": row["sha256"], "pixels": [width, height], "source_pixels": row["dimensions"], "source_trim_rect_pixels": [left, top, width, height], "trim_rect_pixels": [0, 0, width, height], "anchor": anchor, "world_size": [], "decoded_byte_estimate": width * height * 4, "padding_pixels": 4, "extrusion_pixels": 2}
        if block_registration is None:
            raise SystemExit(f"build rejected: residential L1 variant-two registration missing for {direction}")
        anchor_x, anchor_y, world_size, opaque_bounds = block_registration
        for detail in DETAILS:
            lods[detail]["anchor"] = [anchor_x, anchor_y]
            lods[detail]["world_size"] = world_size
        asset["lods"] = lods
        asset["opaque_bounds_world"] = opaque_bounds
        asset["shadow_bounds_world"] = opaque_bounds
        asset["allowed_overhang_world"] = [rounded(max(0.0, -36.0 - opaque_bounds[0])), rounded(max(0.0, opaque_bounds[2] - 36.0)), rounded(max(0.0, -18.0 - opaque_bounds[1])), rounded(max(0.0, opaque_bounds[3] - 18.0))]
        asset["decoded_byte_estimate"] = sum(int(lod["decoded_byte_estimate"]) for lod in lods.values())
        assets.append(asset)
    return assets


def commercial_l01_variant_zero_assets(
    manifest: dict[str, object],
) -> list[dict[str, object]]:
    """Bind the admitted PLAY-098 Commercial L1 v0 family to the existing selector."""
    receipt_path = PLAY098_COMMERCIAL_L01_VARIANT_ZERO / "normalized" / "NORMALIZATION-RECEIPT.json"
    admission_path = (
        REPOSITORY
        / "docs/production/evidence/PLAY-098/commercial-l01-v0-admission/INTEGRATION-ADMISSION.json"
    )
    if (
        sha256(receipt_path) != PLAY098_COMMERCIAL_L01_VARIANT_ZERO_NORMALIZATION_SHA256
        or sha256(admission_path) != PLAY098_COMMERCIAL_L01_VARIANT_ZERO_ADMISSION_SHA256
    ):
        raise SystemExit("build rejected: commercial L1 v0 authority drift")

    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    admission = json.loads(admission_path.read_text(encoding="utf-8"))
    selection = json.loads(
        PLAY098_COMMERCIAL_L01_VARIANT_ZERO_SELECTION.read_text(encoding="utf-8")
    )
    directions = ("north", "east", "south", "west")
    rows = {item["direction"]: item for item in selection.get("selections", [])}
    if (
        selection.get("schema") != 1
        or selection.get("task") != "PLAY-098"
        or selection.get("family") != "commercial_l01_v0"
        or set(rows) != set(directions)
        or receipt.get("schema") != "citysim.play-098.commercial-l01-v0.admission.v1"
        or receipt.get("family") != "commercial_l01_v0"
        or set(receipt.get("directions", [])) != set(directions)
        or admission.get("disposition") != "ADMIT_SOURCE_FAMILY"
        or admission.get("sourceAdmitted") is not True
        or admission.get("integrationAdmitted") is not True
        or admission.get("productionSelected") is not False
    ):
        raise SystemExit("build rejected: commercial L1 v0 admission mismatch")

    templates = {
        asset["view_direction"]: asset
        for asset in manifest["assets"]
        if asset.get("family") == "commercial"
        and asset.get("level") == 1
        and asset.get("variant") == 0
        and asset.get("view_direction") in directions
    }
    if set(templates) != set(directions):
        raise SystemExit("build rejected: commercial L1 v0 registration templates missing")

    assets: list[dict[str, object]] = []
    for direction in directions:
        source = receipt["rawSources"][direction]
        raw = REPOSITORY / source["path"]
        if (
            sha256(raw) != source["sha256"]
            or rows[direction]["raw_sha256"] != source["sha256"]
        ):
            raise SystemExit(f"build rejected: commercial L1 v0 raw drift for {direction}")

        asset = copy.deepcopy(templates[direction])
        template_world_size = list(asset["lods"]["block"]["world_size"])
        logical_id = f"commercial_l01_v0_{direction}"
        asset.update({
            "logical_id": logical_id,
            "source_key": f"commercial_l01/variant-0/{direction}/source-v01",
            "source_revision": "source-v01",
            "state": "maintained",
            "residency_id": f"generated-v4/commercial/{logical_id}",
            "source_sha256": source["sha256"],
            "raw_source_file": source["path"].replace("Native/", "", 1),
            "provenance_file": relative_to_package(receipt_path),
            "provenance_sha256": PLAY098_COMMERCIAL_L01_VARIANT_ZERO_NORMALIZATION_SHA256,
            "normalization_record_file": relative_to_package(receipt_path),
            "normalization_record_sha256": PLAY098_COMMERCIAL_L01_VARIANT_ZERO_NORMALIZATION_SHA256,
            "reference_sha256": [
                PLAY098_COMMERCIAL_L01_VARIANT_ZERO_ADMISSION_SHA256,
                PLAY098_COMMERCIAL_L01_VARIANT_ZERO_NORMALIZATION_SHA256,
            ],
            "source_packet_file": relative_to_package(receipt_path),
            "source_packet_commit": PLAY098_COMMERCIAL_L01_VARIANT_ZERO_COMMIT,
        })
        for key in (
            "prompt_file",
            "scene_descriptor_file",
            "scene_descriptor_sha256",
            "material_library_file",
            "material_library_sha256",
        ):
            asset.pop(key, None)

        lods: dict[str, dict[str, object]] = {}
        block_registration: tuple[float, float, list[float], list[float]] | None = None
        for detail in DETAILS:
            row = receipt["lods"][direction][detail]
            normalized = REPOSITORY / row["path"]
            expected_sha = rows[direction]["normalized_sha256"][detail]
            if sha256(normalized) != row["sha256"] or row["sha256"] != expected_sha:
                raise SystemExit(
                    f"build rejected: commercial L1 v0 normalized drift for {direction}.{detail}"
                )
            with Image.open(normalized) as image:
                if image.mode != "RGBA" or list(image.size) != row["dimensions"]:
                    raise SystemExit(
                        f"build rejected: commercial L1 v0 LOD shape for {direction}.{detail}"
                    )
                alpha_bounds = image.getchannel("A").getbbox()
                if alpha_bounds is None:
                    raise SystemExit(
                        f"build rejected: empty commercial L1 v0 LOD {direction}.{detail}"
                    )
                left, top, right, bottom = alpha_bounds
                width, height = right - left, bottom - top
                pivot_x = GROUND_PIVOT[0] * image.width / RAW_CANVAS[0]
                pivot_y = GROUND_PIVOT[1] * image.height / RAW_CANVAS[1]
                anchor = [
                    rounded((pivot_x - left) / width),
                    rounded((bottom - pivot_y) / height),
                ]
                if detail == "block":
                    points_per_pixel = min(
                        template_world_size[0] / width,
                        template_world_size[1] / height,
                    )
                    world_size = [
                        rounded(width * points_per_pixel),
                        rounded(height * points_per_pixel),
                    ]
                    opaque_bounds = [
                        rounded((left - pivot_x) * points_per_pixel),
                        rounded(PLACEMENT_OFFSET[1] - (bottom - pivot_y) * points_per_pixel),
                        rounded((right - pivot_x) * points_per_pixel),
                        rounded(PLACEMENT_OFFSET[1] + (pivot_y - top) * points_per_pixel),
                    ]
                    block_registration = (
                        anchor[0], anchor[1], world_size, opaque_bounds
                    )
            lods[detail] = {
                "file": f"generated_v4_{logical_id}_{detail}.png",
                "normalized_file": relative_to_package(normalized),
                "normalized_sha256": expected_sha,
                "pixels": [width, height],
                "source_pixels": row["dimensions"],
                "source_trim_rect_pixels": [left, top, width, height],
                "trim_rect_pixels": [0, 0, width, height],
                "anchor": anchor,
                "world_size": [],
                "decoded_byte_estimate": width * height * 4,
                "padding_pixels": 4,
                "extrusion_pixels": 2,
            }
        if block_registration is None:
            raise SystemExit(f"build rejected: commercial L1 v0 registration missing for {direction}")
        anchor_x, anchor_y, world_size, opaque_bounds = block_registration
        for detail in DETAILS:
            lods[detail]["anchor"] = [anchor_x, anchor_y]
            lods[detail]["world_size"] = world_size
        asset["lods"] = lods
        asset["opaque_bounds_world"] = opaque_bounds
        asset["shadow_bounds_world"] = opaque_bounds
        asset["allowed_overhang_world"] = [
            rounded(max(0.0, -36.0 - opaque_bounds[0])),
            rounded(max(0.0, opaque_bounds[2] - 36.0)),
            rounded(max(0.0, -18.0 - opaque_bounds[1])),
            rounded(max(0.0, opaque_bounds[3] - 18.0)),
        ]
        asset["decoded_byte_estimate"] = sum(
            int(lod["decoded_byte_estimate"]) for lod in lods.values()
        )
        assets.append(asset)
    return assets


def civic_l01_variant_zero_assets(
    manifest: dict[str, object],
) -> list[dict[str, object]]:
    """Bind the Integration-admitted PLAY-113 civic quartet to generated-v4."""
    handoff_path = (
        REPOSITORY
        / "docs/production/evidence/PLAY-113/civic-l01-v0-family/RENDERER-HANDOFF.json"
    )
    validation_path = (
        REPOSITORY
        / "docs/production/evidence/PLAY-113/civic-l01-v0-family/VALIDATION-RESULT.json"
    )
    admission_path = (
        REPOSITORY
        / "docs/production/evidence/INTEGRATION/PLAY-113-CIVIC-L01-V0-SOURCE-ADMISSION-CURRENT8AC.json"
    )
    if (
        sha256(handoff_path) != PLAY113_CIVIC_L01_VARIANT_ZERO_HANDOFF_SHA256
        or sha256(validation_path) != PLAY113_CIVIC_L01_VARIANT_ZERO_VALIDATION_SHA256
        or sha256(admission_path) != PLAY113_CIVIC_L01_VARIANT_ZERO_ADMISSION_SHA256
    ):
        raise SystemExit("build rejected: civic L1 v0 authority drift")

    handoff = json.loads(handoff_path.read_text(encoding="utf-8"))
    validation = json.loads(validation_path.read_text(encoding="utf-8"))
    admission = json.loads(admission_path.read_text(encoding="utf-8"))
    selection = json.loads(
        PLAY113_CIVIC_L01_VARIANT_ZERO_SELECTION.read_text(encoding="utf-8")
    )
    directions = ("north", "east", "south", "west")
    rows = {item["direction"]: item for item in selection.get("selections", [])}
    immutable = admission.get("immutablePacket", {})
    handoff_binding = immutable.get("handoff", {}) if isinstance(immutable, dict) else {}
    if (
        selection.get("schema") != 1
        or selection.get("task") != "PLAY-113"
        or selection.get("family") != "civic_l01_v0"
        or set(rows) != set(directions)
        or handoff.get("schema") != "citysim.play-113.civic-l01-v0.renderer-handoff.v1"
        or handoff.get("result") != "PASS_CANDIDATE_SOURCE_HANDOFF"
        or handoff.get("family") != "civic_l01_v0"
        or validation.get("result") != "PASS"
        or admission.get("disposition") != "ADMIT_SOURCE_FAMILY"
        or admission.get("integrationAdmitted") is not True
        or admission.get("candidateOnlyHistoricalPacket") is not True
        or handoff_binding.get("sha256") != PLAY113_CIVIC_L01_VARIANT_ZERO_HANDOFF_SHA256
    ):
        raise SystemExit("build rejected: civic L1 v0 admission mismatch")

    template = next(
        (
            asset
            for asset in manifest["assets"]
            if asset.get("family") == "civic"
            and asset.get("logical_id") == "city_hall_l01"
            and asset.get("level") == 1
        ),
        None,
    )
    if template is None:
        raise SystemExit("build rejected: civic L1 v0 registration template missing")
    template_world_size = list(template["lods"]["block"]["world_size"])
    raw_hashes = []
    lod_hashes = []
    assets: list[dict[str, object]] = []
    for direction in directions:
        source = handoff["rawSources"][direction]
        raw = REPOSITORY / source["path"]
        if sha256(raw) != source["sha256"] or rows[direction]["raw_sha256"] != source["sha256"]:
            raise SystemExit(f"build rejected: civic L1 v0 raw drift for {direction}")
        raw_hashes.append(source["sha256"])

        asset = copy.deepcopy(template)
        logical_id = f"civic_l01_v0_{direction}"
        asset.update(
            {
                "logical_id": logical_id,
                "source_key": f"civic_l01/variant-0/{direction}/source-v01",
                "source_revision": "source-v01",
                "variant": 0,
                "state": "maintained",
                "residency_id": f"generated-v4/civic/{logical_id}",
                "source_sha256": source["sha256"],
                "raw_source_file": source["path"].replace("Native/", "", 1),
                "provenance_file": relative_to_package(handoff_path),
                "provenance_sha256": PLAY113_CIVIC_L01_VARIANT_ZERO_HANDOFF_SHA256,
                "normalization_record_file": relative_to_package(handoff_path),
                "normalization_record_sha256": PLAY113_CIVIC_L01_VARIANT_ZERO_HANDOFF_SHA256,
                "reference_sha256": [
                    PLAY113_CIVIC_L01_VARIANT_ZERO_ADMISSION_SHA256,
                    PLAY113_CIVIC_L01_VARIANT_ZERO_VALIDATION_SHA256,
                    PLAY113_CIVIC_L01_VARIANT_ZERO_HANDOFF_SHA256,
                ],
                "source_packet_file": relative_to_package(handoff_path),
                "source_packet_commit": PLAY113_CIVIC_L01_VARIANT_ZERO_COMMIT,
                "frontage_edge": direction,
                "view_direction": direction,
                "supported_orientation": f"{direction}-facing-authored",
                "entrance_socket_world": list(DIRECTION_SOCKET_WORLD[direction]),
                "ground_pivot_source": list(GROUND_PIVOT),
                "placement_offset_world": list(PLACEMENT_OFFSET),
                "road_setback_points": 0.0,
            }
        )
        for key in (
            "prompt_file",
            "prompt_sha256",
            "scene_descriptor_file",
            "scene_descriptor_sha256",
            "material_library_file",
            "material_library_sha256",
        ):
            asset.pop(key, None)

        lods: dict[str, dict[str, object]] = {}
        block_registration: tuple[float, float, list[float], list[float]] | None = None
        for detail in DETAILS:
            row = handoff["lods"][direction][detail]
            normalized = REPOSITORY / row["path"]
            expected_sha = rows[direction]["normalized_sha256"][detail]
            if sha256(normalized) != row["sha256"] or row["sha256"] != expected_sha:
                raise SystemExit(
                    f"build rejected: civic L1 v0 normalized drift for {direction}.{detail}"
                )
            lod_hashes.append(row["sha256"])
            with Image.open(normalized) as image:
                if image.mode != "RGBA" or list(image.size) != row["dimensions"]:
                    raise SystemExit(
                        f"build rejected: civic L1 v0 LOD shape for {direction}.{detail}"
                    )
                alpha_bounds = image.getchannel("A").getbbox()
                if alpha_bounds is None:
                    raise SystemExit(
                        f"build rejected: empty civic L1 v0 LOD {direction}.{detail}"
                    )
                left, top, right, bottom = alpha_bounds
                width, height = right - left, bottom - top
                pivot_x = GROUND_PIVOT[0] * image.width / RAW_CANVAS[0]
                pivot_y = GROUND_PIVOT[1] * image.height / RAW_CANVAS[1]
                anchor = [
                    rounded((pivot_x - left) / width),
                    rounded((bottom - pivot_y) / height),
                ]
                if detail == "block":
                    points_per_pixel = min(
                        template_world_size[0] / width,
                        template_world_size[1] / height,
                    )
                    world_size = [
                        rounded(width * points_per_pixel),
                        rounded(height * points_per_pixel),
                    ]
                    opaque_bounds = [
                        rounded((left - pivot_x) * points_per_pixel),
                        rounded(PLACEMENT_OFFSET[1] - (bottom - pivot_y) * points_per_pixel),
                        rounded((right - pivot_x) * points_per_pixel),
                        rounded(PLACEMENT_OFFSET[1] + (pivot_y - top) * points_per_pixel),
                    ]
                    block_registration = (anchor[0], anchor[1], world_size, opaque_bounds)
            lods[detail] = {
                "file": f"generated_v4_{logical_id}_{detail}.png",
                "normalized_file": relative_to_package(normalized),
                "normalized_sha256": expected_sha,
                "pixels": [width, height],
                "source_pixels": row["dimensions"],
                "source_trim_rect_pixels": [left, top, width, height],
                "trim_rect_pixels": [0, 0, width, height],
                "anchor": anchor,
                "world_size": [],
                "decoded_byte_estimate": width * height * 4,
                "padding_pixels": 4,
                "extrusion_pixels": 2,
            }
        if block_registration is None:
            raise SystemExit(f"build rejected: civic L1 v0 registration missing for {direction}")
        anchor_x, anchor_y, world_size, opaque_bounds = block_registration
        for detail in DETAILS:
            lods[detail]["anchor"] = [anchor_x, anchor_y]
            lods[detail]["world_size"] = world_size
        asset["lods"] = lods
        asset["opaque_bounds_world"] = opaque_bounds
        asset["shadow_bounds_world"] = opaque_bounds
        asset["allowed_overhang_world"] = [
            rounded(max(0.0, -36.0 - opaque_bounds[0])),
            rounded(max(0.0, opaque_bounds[2] - 36.0)),
            rounded(max(0.0, -18.0 - opaque_bounds[1])),
            rounded(max(0.0, opaque_bounds[3] - 18.0)),
        ]
        asset["decoded_byte_estimate"] = sum(
            int(lod["decoded_byte_estimate"]) for lod in lods.values()
        )
        assets.append(asset)
    if len(set(raw_hashes)) != 4 or len(set(lod_hashes)) != 12:
        raise SystemExit("build rejected: civic L1 v0 source alias")
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
        if asset.get("source_packet_file"):
            inventory.extend(
                (
                    repository_record(
                        repository_path(asset["raw_source_file"]),
                        "accepted-raw-master",
                    ),
                    repository_record(
                        repository_path(asset["source_packet_file"]),
                        "admitted-source-packet",
                    ),
                )
            )
        elif asset.get("scene_descriptor_file"):
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
        + [
            asset
            for asset in directional_building_assets(
                PLAY060_SELECTION,
                "commercial",
                "PLAY-060",
            )
            if asset["level"] != 1
        ]
        + directional_building_assets(
            PLAY101_SELECTION,
            "industrial",
            "PLAY-101",
            levels=(1,),
        )
        + directional_building_assets(
            PLAY073_INDUSTRIAL_L2_SELECTION,
            "industrial",
            "PLAY-073",
            levels=(2,),
        )
        + directional_building_assets(
            PLAY073_INDUSTRIAL_L3_SELECTION,
            "industrial",
            "PLAY-073",
            levels=(3,),
        )
        + residential_variant_one_assets(manifest)
        + residential_variant_two_assets(manifest)
        + commercial_l01_variant_zero_assets(manifest)
        + civic_l01_variant_zero_assets(manifest)
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

    manifest["generator_version"] = "PLAY-097-residential-l01-v2-atomic-activation-1"
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
        "algorithm": "stable-detail-best-short-side-v3",
        "sort": "detail then descending padded area, height, width, semantic key",
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
