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
    """Stable tall-first shelf packing with no rotation and fixed padding."""

    pages: list[list[tuple[Payload, int, int, Image.Image]]] = []
    current: list[tuple[Payload, int, int, Image.Image]] = []
    x = 0
    y = 0
    row_height = 0

    verified = [(payload, verify_payload(payload)) for payload in payloads]
    # Tall-first rows materially reduce fragmentation from mixed skyline
    # heights while retaining a complete deterministic tie break. Source
    # pixels are never rotated or transformed.
    for payload, image in sorted(
        verified,
        key=lambda item: (
            -item[1].height,
            -item[1].width,
            item[0].key,
        ),
    ):
        width = image.width + PADDING * 2
        height = image.height + PADDING * 2
        if x > 0 and x + width > PAGE_LIMIT:
            x = 0
            y += row_height
            row_height = 0
        if y > 0 and y + height > PAGE_LIMIT:
            pages.append(current)
            current = []
            x = 0
            y = 0
            row_height = 0
        if width > PAGE_LIMIT or height > PAGE_LIMIT:
            raise SystemExit(f"pack rejected: {payload.key} cannot fit a page")
        current.append((payload, x, y, image))
        x += width
        row_height = max(row_height, height)

    if current:
        pages.append(current)
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
