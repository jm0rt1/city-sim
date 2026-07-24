#!/usr/bin/env python3
"""Compile deterministic road topology from the accepted road material source."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance


ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / "GeneratedV4"
SOURCE = GENERATED / "normalized" / "calibration" / "road_material" / "generated_v4_road_material_block.png"
OUTPUT = GENERATED / "compiled" / "calibration-network"
LODS = {"block": (512, 256), "neighborhood": (256, 128), "city": (128, 64)}
EDGES = ((384, 64), (384, 192), (128, 192), (128, 64))
AUTHORING_SIZE = (1536, 1024)
AUTHORING_MATERIAL_BOUNDS = (512, 640, 1024, 896)

def material_texture(
    material: Image.Image,
    box: tuple[int, int, int, int],
    contrast: float = 1.0,
    brightness: float = 1.0,
) -> Image.Image:
    """Build a socket-periodic texture from the retained authored material.

    The calibration source owns palette, grain, and wear. The topology compiler
    mirrors one quiet sample into a 256 x 128 period, matching the delta between
    reciprocal isometric sockets. Adjacent mask sprites therefore sample the
    same material pixels where they meet instead of exposing atlas-tile seams.
    The compiler only clips that material to deterministic road sockets; it
    never asks generated art to decide connectivity.
    """

    sample = material.crop(box).resize((128, 64), Image.Resampling.BICUBIC).convert("RGBA")
    sample = ImageEnhance.Contrast(sample).enhance(contrast)
    sample = ImageEnhance.Brightness(sample).enhance(brightness)
    sample.putalpha(255)

    period = Image.new("RGBA", (256, 128))
    period.paste(sample, (0, 0))
    period.paste(sample.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (128, 0))
    period.paste(sample.transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0, 64))
    period.paste(
        sample.transpose(Image.Transpose.FLIP_LEFT_RIGHT).transpose(Image.Transpose.FLIP_TOP_BOTTOM),
        (128, 64),
    )
    texture = Image.new("RGBA", LODS["block"])
    for y in range(0, LODS["block"][1], period.height):
        for x in range(0, LODS["block"][0], period.width):
            texture.paste(period, (x, y))
    return texture


def topology_mask(mask_value: int, width: int, offset: tuple[int, int] = (0, 0)) -> Image.Image:
    mask = Image.new("L", LODS["block"], 0)
    draw = ImageDraw.Draw(mask)
    center = (256 + offset[0], 128 + offset[1])
    endpoints = []
    for index in range(4):
        if not mask_value & (1 << index):
            continue
        socket_x = EDGES[index][0] + offset[0]
        socket_y = EDGES[index][1] + offset[1]
        dx = socket_x - center[0]
        dy = socket_y - center[1]
        endpoints.append((
            round(socket_x + dx * 0.008),
            round(socket_y + dy * 0.008),
        ))
    radius = width // 2
    if not endpoints:
        draw.ellipse(
            (center[0] - radius, center[1] - radius // 2,
             center[0] + radius, center[1] + radius // 2),
            fill=255,
        )
        return mask

    if len(endpoints) == 1:
        endpoint = endpoints[0]
        dx, dy = endpoint[0] - center[0], endpoint[1] - center[1]
        cap = (round(center[0] - dx * 0.34), round(center[1] - dy * 0.34))
        draw.line((endpoint, cap), fill=255, width=width)
        draw.ellipse(
            (cap[0] - radius, cap[1] - radius // 2,
             cap[0] + radius, cap[1] + radius // 2),
            fill=255,
        )
        return mask

    for endpoint in endpoints:
        draw.line((center, endpoint), fill=255, width=width)
    draw.ellipse(
        (center[0] - radius, center[1] - radius // 2,
         center[0] + radius, center[1] + radius // 2),
        fill=255,
    )
    return mask


def paste_material(image: Image.Image, texture: Image.Image, mask: Image.Image) -> None:
    image.paste(texture, (0, 0), mask)


def add_lane_language(image: Image.Image, mask_value: int, lod: str) -> None:
    if lod == "city":
        return
    draw = ImageDraw.Draw(image)
    center = (256, 128)
    endpoints = [EDGES[index] for index in range(4) if mask_value & (1 << index)]
    lane = (205, 164, 71, 205 if lod == "block" else 165)
    lane_width = 4 if lod == "block" else 3

    # Sparse center dashes preserve network direction without turning the
    # junction into the rejected ladder/arrow graffiti.
    for endpoint in endpoints:
        dx, dy = endpoint[0] - center[0], endpoint[1] - center[1]
        for start_fraction, end_fraction in ((0.48, 0.61), (0.70, 0.84)):
            draw.line(
                (
                    center[0] + dx * start_fraction,
                    center[1] + dy * start_fraction,
                    center[0] + dx * end_fraction,
                    center[1] + dy * end_fraction,
                ),
                fill=lane,
                width=lane_width,
            )

    if len(endpoints) >= 3:
        # One calm paired crossing per junction is enough to identify pedestrian
        # priority. Four crossings on every arm produced the rejected ladders.
        crossing_edges = [endpoints[0]]
        if len(endpoints) == 4:
            crossing_edges.append(endpoints[2])
        for endpoint in crossing_edges:
            dx, dy = endpoint[0] - center[0], endpoint[1] - center[1]
            length = max(abs(dx), abs(dy))
            ux, uy = dx / length, dy / length
            px, py = -uy, ux
            stripe_count = 3 if lod == "block" else 2
            for stripe in range(stripe_count):
                along = (stripe - (stripe_count - 1) / 2) * 11
                cx = center[0] + dx * 0.58 + ux * along
                cy = center[1] + dy * 0.58 + uy * along
                draw.line(
                    (cx - px * 22, cy - py * 22, cx + px * 22, cy + py * 22),
                    fill=(226, 218, 194, 210 if lod == "block" else 170),
                    width=5 if lod == "block" else 4,
                )

    if len(endpoints) == 1:
        endpoint = endpoints[0]
        dx, dy = endpoint[0] - center[0], endpoint[1] - center[1]
        cap = (center[0] - dx * 0.31, center[1] - dy * 0.31)
        # A restrained amber gate makes the authoritative terminus read as a
        # deliberate expansion edge, not a disconnected rounded paste-on.
        draw.line(
            (cap[0] - 12, cap[1] - 5, cap[0] + 12, cap[1] + 5),
            fill=(186, 115, 53, 220),
            width=4,
        )


def add_block_material_detail(image: Image.Image, mask_value: int) -> None:
    draw = ImageDraw.Draw(image)
    center = (256, 128)
    endpoints = [EDGES[index] for index in range(4) if mask_value & (1 << index)]
    for index, endpoint in enumerate(endpoints):
        dx, dy = endpoint[0] - center[0], endpoint[1] - center[1]
        length = max(abs(dx), abs(dy))
        ux, uy = dx / length, dy / length
        px, py = -uy, ux
        if index % 2 == 0:
            cx = center[0] + dx * 0.73 + px * 43
            cy = center[1] + dy * 0.73 + py * 43
            draw.line(
                (cx - px * 7, cy - py * 7, cx + px * 7, cy + py * 7),
                fill=(74, 72, 68, 170),
                width=2,
            )


def draw_mask(mask_value: int, material: Image.Image, lod: str) -> Image.Image:
    image = Image.new("RGBA", LODS["block"], (0, 0, 0, 0))
    # Sample only opaque interior pixels from the retained material diamond.
    # Pulling transparent authoring margins into an opaque texture created the
    # black per-tile wedges visible in the rejected first correction export.
    asphalt = material_texture(material, (224, 24, 288, 44), contrast=1.08, brightness=0.92)
    curb = material_texture(material, (58, 106, 232, 126), contrast=1.05, brightness=0.94)
    walk = material_texture(material, (280, 106, 454, 126), contrast=1.04, brightness=0.96)

    shadow = topology_mask(mask_value, 196, offset=(4, 5))
    shadow_alpha = shadow.point(lambda value: round(value * 0.18))
    image.paste((24, 29, 25, 0), (0, 0, *LODS["block"]))
    shadow_layer = Image.new("RGBA", LODS["block"], (15, 20, 18, 255))
    image.paste(shadow_layer, (0, 0), shadow_alpha)

    sidewalk_mask = topology_mask(mask_value, 188)
    curb_mask = topology_mask(mask_value, 156)
    asphalt_mask = topology_mask(mask_value, 124)
    paste_material(image, walk, sidewalk_mask)
    paste_material(image, curb, curb_mask)
    paste_material(image, asphalt, asphalt_mask)

    # A single quiet curb highlight integrates the authored material at normal
    # viewing distance while keeping reciprocal sockets byte-identical.
    curb_edge = ImageChops.subtract(curb_mask, asphalt_mask)
    highlight = Image.new("RGBA", LODS["block"], (225, 211, 179, 34 if lod == "city" else 58))
    image.paste(highlight, (0, 0), curb_edge.point(lambda value: value // 3))
    add_lane_language(image, mask_value, lod)
    if lod == "block":
        add_block_material_detail(image, mask_value)
    return image


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    scale_x = source.width / AUTHORING_SIZE[0]
    scale_y = source.height / AUTHORING_SIZE[1]
    material_bounds = (
        round(AUTHORING_MATERIAL_BOUNDS[0] * scale_x),
        round(AUTHORING_MATERIAL_BOUNDS[1] * scale_y),
        round(AUTHORING_MATERIAL_BOUNDS[2] * scale_x),
        round(AUTHORING_MATERIAL_BOUNDS[3] * scale_y),
    )
    material = source.crop(material_bounds).resize(LODS["block"], Image.Resampling.LANCZOS)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for mask_value in range(16):
        for lod, size in LODS.items():
            authored = draw_mask(mask_value, material, lod)
            image = authored if lod == "block" else authored.resize(size, Image.Resampling.LANCZOS)
            name = f"generated_v4_road_mask_{mask_value:02d}_{lod}.png"
            output = OUTPUT / name
            image.save(output, optimize=True)


if __name__ == "__main__":
    main()
