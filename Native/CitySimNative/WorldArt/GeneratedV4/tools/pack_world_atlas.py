#!/usr/bin/env python3
"""Deterministically pack generated-v4 semantic payloads into LOD pages.

The packer owns only byte layout. Source pixels, logical geometry, topology,
anchors, world sizes, and gameplay meaning remain authoritative inputs.
"""

from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image


PAGE_LIMIT = 2048
PADDING = 4
EXTRUSION = 2
DETAILS = ("city", "neighborhood", "block")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def power_of_two(value: int) -> int:
    return max(64, 1 << max(0, value - 1).bit_length())


@dataclass(frozen=True)
class Payload:
    key: str
    detail: str
    source: Path
    expected_sha256: str


@dataclass(frozen=True)
class Placement:
    key: str
    detail: str
    page_id: str
    page_file: str
    texture_rect_pixels: tuple[int, int, int, int]
    packed_rect_pixels: tuple[int, int, int, int]
    payload_sha256: str


def verify_payload(payload: Payload) -> Image.Image:
    if sha256(payload.source) != payload.expected_sha256:
        raise SystemExit(f"pack rejected: payload digest mismatch for {payload.key}")
    image = Image.open(payload.source)
    if image.mode != "RGBA":
        raise SystemExit(f"pack rejected: {payload.key} is not canonical RGBA")
    image.load()
    if image.width + PADDING * 2 > PAGE_LIMIT or image.height + PADDING * 2 > PAGE_LIMIT:
        raise SystemExit(f"pack rejected: {payload.key} exceeds {PAGE_LIMIT}px page limit")
    return image


def paste_with_extrusion(page: Image.Image, source: Image.Image, x: int, y: int) -> None:
    """Paste one payload with transparent gutter and two-pixel edge extrusion."""

    content_x = x + PADDING
    content_y = y + PADDING
    # Direct RGBA paste preserves the accepted payload bytes, including soft
    # alpha edge color. Alpha compositing onto a transparent page rewrites
    # those RGB channels and breaks exact source-to-page digest proof.
    page.paste(source, (content_x, content_y))

    left = source.crop((0, 0, 1, source.height)).resize((EXTRUSION, source.height))
    right = source.crop((source.width - 1, 0, source.width, source.height)).resize(
        (EXTRUSION, source.height)
    )
    top = source.crop((0, 0, source.width, 1)).resize((source.width, EXTRUSION))
    bottom = source.crop((0, source.height - 1, source.width, source.height)).resize(
        (source.width, EXTRUSION)
    )
    page.paste(left, (content_x - EXTRUSION, content_y))
    page.paste(right, (content_x + source.width, content_y))
    page.paste(top, (content_x, content_y - EXTRUSION))
    page.paste(bottom, (content_x, content_y + source.height))

    corners = (
        (0, 0, content_x - EXTRUSION, content_y - EXTRUSION),
        (source.width - 1, 0, content_x + source.width, content_y - EXTRUSION),
        (0, source.height - 1, content_x - EXTRUSION, content_y + source.height),
        (
            source.width - 1,
            source.height - 1,
            content_x + source.width,
            content_y + source.height,
        ),
    )
    for source_x, source_y, destination_x, destination_y in corners:
        corner = source.crop((source_x, source_y, source_x + 1, source_y + 1)).resize(
            (EXTRUSION, EXTRUSION)
        )
        page.paste(corner, (destination_x, destination_y))


def layout_pages(payloads: Iterable[Payload]) -> list[list[tuple[Payload, int, int, Image.Image]]]:
    """Stable best-short-side packing with no rotation and fixed padding."""

    pages: list[list[tuple[Payload, int, int, Image.Image]]] = []
    free_rectangles: list[list[tuple[int, int, int, int]]] = []

    def intersects_rect(
        left: tuple[int, int, int, int],
        right: tuple[int, int, int, int],
    ) -> bool:
        return not (
            left[0] + left[2] <= right[0]
            or right[0] + right[2] <= left[0]
            or left[1] + left[3] <= right[1]
            or right[1] + right[3] <= left[1]
        )

    def contains_rect(
        outer: tuple[int, int, int, int],
        inner: tuple[int, int, int, int],
    ) -> bool:
        return (
            outer[0] <= inner[0]
            and outer[1] <= inner[1]
            and outer[0] + outer[2] >= inner[0] + inner[2]
            and outer[1] + outer[3] >= inner[1] + inner[3]
        )

    def split_free_rectangles(
        rectangles: list[tuple[int, int, int, int]],
        occupied: tuple[int, int, int, int],
    ) -> list[tuple[int, int, int, int]]:
        occupied_x, occupied_y, occupied_width, occupied_height = occupied
        occupied_right = occupied_x + occupied_width
        occupied_bottom = occupied_y + occupied_height
        candidates: list[tuple[int, int, int, int]] = []
        for rectangle in rectangles:
            if not intersects_rect(rectangle, occupied):
                candidates.append(rectangle)
                continue
            x, y, width, height = rectangle
            right = x + width
            bottom = y + height
            if occupied_x > x:
                candidates.append((x, y, occupied_x - x, height))
            if occupied_right < right:
                candidates.append((occupied_right, y, right - occupied_right, height))
            if occupied_y > y:
                candidates.append((x, y, width, occupied_y - y))
            if occupied_bottom < bottom:
                candidates.append((x, occupied_bottom, width, bottom - occupied_bottom))

        nonempty = sorted(
            {item for item in candidates if item[2] > 0 and item[3] > 0},
            key=lambda item: (item[1], item[0], item[2], item[3]),
        )
        return [
            item
            for index, item in enumerate(nonempty)
            if not any(
                index != other_index and contains_rect(other, item)
                for other_index, other in enumerate(nonempty)
            )
        ]

    verified = [(payload, verify_payload(payload)) for payload in payloads]
    for payload, image in sorted(
        verified,
        key=lambda item: (
            -(item[1].width + PADDING * 2) * (item[1].height + PADDING * 2),
            -item[1].height,
            -item[1].width,
            item[0].key,
        ),
    ):
        width = image.width + PADDING * 2
        height = image.height + PADDING * 2
        if width > PAGE_LIMIT or height > PAGE_LIMIT:
            raise SystemExit(f"pack rejected: {payload.key} cannot fit a page")

        choices: list[tuple[int, int, int, int, int, int]] = []
        for page_index, rectangles in enumerate(free_rectangles):
            for rectangle_index, (x, y, free_width, free_height) in enumerate(rectangles):
                if width <= free_width and height <= free_height:
                    choices.append(
                        (
                            min(free_width - width, free_height - height),
                            max(free_width - width, free_height - height),
                            page_index,
                            y,
                            x,
                            rectangle_index,
                        )
                    )
        if choices:
            _, _, page_index, y, x, _ = min(choices)
        else:
            page_index = len(pages)
            pages.append([])
            free_rectangles.append([(0, 0, PAGE_LIMIT, PAGE_LIMIT)])
            x = 0
            y = 0

        occupied = (x, y, width, height)
        pages[page_index].append((payload, x, y, image))
        free_rectangles[page_index] = split_free_rectangles(
            free_rectangles[page_index],
            occupied,
        )

    return pages


def write_pages(
    detail: str,
    payloads: Iterable[Payload],
    output_atlas: Path,
) -> tuple[list[dict[str, object]], dict[str, Placement]]:
    page_records: list[dict[str, object]] = []
    placements: dict[str, Placement] = {}
    page_directory = output_atlas / "pages" / detail
    page_directory.mkdir(parents=True, exist_ok=True)

    for page_index, items in enumerate(layout_pages(payloads)):
        used_width = max(x + image.width + PADDING * 2 for _, x, _, image in items)
        used_height = max(y + image.height + PADDING * 2 for _, _, y, image in items)
        page_width = power_of_two(used_width)
        page_height = power_of_two(used_height)
        if page_width > PAGE_LIMIT or page_height > PAGE_LIMIT:
            raise SystemExit(f"pack rejected: {detail} page exceeds limit after layout")

        page = Image.new("RGBA", (page_width, page_height), (0, 0, 0, 0))
        page_id = f"{detail}-{page_index:02d}"
        relative_file = f"pages/{detail}/page-{page_index:02d}.png"
        for payload, x, y, image in items:
            paste_with_extrusion(page, image, x, y)
            placements[payload.key] = Placement(
                key=payload.key,
                detail=detail,
                page_id=page_id,
                page_file=relative_file,
                texture_rect_pixels=(
                    x + PADDING,
                    y + PADDING,
                    image.width,
                    image.height,
                ),
                packed_rect_pixels=(
                    x,
                    y,
                    image.width + PADDING * 2,
                    image.height + PADDING * 2,
                ),
                payload_sha256=payload.expected_sha256,
            )

        destination = output_atlas / relative_file
        page.save(destination, format="PNG", compress_level=9, optimize=False)
        page_records.append(
            {
                "id": page_id,
                "lod": detail,
                "file": relative_file,
                "sha256": sha256(destination),
                "pixels": [page_width, page_height],
                "decoded_byte_estimate": page_width * page_height * 4,
                "entry_count": len(items),
                "padding_pixels": PADDING,
                "extrusion_pixels": EXTRUSION,
                "rotation": False,
            }
        )

    return page_records, placements


def write_manifest(path: Path, manifest: dict[str, object]) -> None:
    path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True, separators=(",", ": ")) + "\n",
        encoding="utf-8",
    )
