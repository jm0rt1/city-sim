#!/usr/bin/env python3
"""Generate deterministic PLAY-022 Round 1B color-vision evidence sheets."""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
from pathlib import Path


HERE = Path(__file__).resolve().parent
LIVE_DIR = HERE.parent / "live-fc8b838"
CANDIDATE_COMMIT = "fc8b838d6d33ee8091ce6c54c125ea0cee279f5b"
PANEL_WIDTH = 360
PANEL_HEIGHT = 270
IMAGE_HEIGHT = 230
GRID_COLUMNS = 5
GRID_ROWS = 4
HEADER_HEIGHT = 70
SHEET_WIDTH = PANEL_WIDTH * GRID_COLUMNS
SHEET_HEIGHT = PANEL_HEIGHT * GRID_ROWS + HEADER_HEIGHT

PANELS = [
    ("default", "normal", "default-shipping-paused.jpeg", 0, 0),
    ("default", "selection", "default-pointer-selection-cityhall-12-12.jpeg", 1, 0),
    ("default", "valid", "default-valid-residential-16-14.jpeg", 2, 0),
    ("default", "overlay", "default-selection-road-14-13-utilities-overlay.jpeg", 3, 0),
    ("compact", "normal", "compact-900x600-shipping-paused.jpeg", 0, 1),
    ("compact", "selection", "compact-pointer-selection-cityhall-12-12.jpeg", 1, 1),
    ("compact", "valid", "compact-valid-residential-16-14.jpeg", 2, 1),
    ("compact", "invalid", "compact-invalid-residential-no-road-15-15.jpeg", 3, 1),
    ("compact", "overlay", "compact-utilities-overlay.jpeg", 4, 1),
    ("construction", "0 percent", "construction-00-residential-16-14.jpeg", 0, 2),
    ("construction", "25 percent", "construction-25-residential-16-14.jpeg", 1, 2),
    ("construction", "50 percent", "construction-50-residential-16-14.jpeg", 2, 2),
    ("construction", "75 percent", "construction-75-residential-16-14.jpeg", 3, 2),
    ("construction", "100 percent", "construction-100-residential-16-14.jpeg", 4, 2),
    ("reduce motion", "sample a", "compact-reduce-motion-a.jpeg", 0, 3),
    ("reduce motion", "sample b", "compact-reduce-motion-b.jpeg", 1, 3),
]

# Machado et al. severity-1 matrices, applied deterministically to normalized
# sRGB channel values. Grayscale uses Rec. 709 luma weights.
TRANSFORMS = {
    "grayscale": (
        (0.2126, 0.7152, 0.0722),
        (0.2126, 0.7152, 0.0722),
        (0.2126, 0.7152, 0.0722),
    ),
    "protanopia": (
        (0.152286, 1.052583, -0.204868),
        (0.114503, 0.786281, 0.099216),
        (-0.003882, -0.048116, 1.051998),
    ),
    "deuteranopia": (
        (0.367322, 0.860646, -0.227968),
        (0.280085, 0.672501, 0.047413),
        (-0.011820, 0.042940, 0.968881),
    ),
    "tritanopia": (
        (1.255528, -0.076749, -0.178779),
        (-0.078411, 0.930809, 0.147602),
        (0.004733, 0.691367, 0.303900),
    ),
}

UNAVAILABLE_CROSS_SIZE_VARIANTS = [
    "default invalid-placement frame",
    "default Reduce Motion A/B frames",
    "compact 0/25/50/75/100 construction sequence",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def probe_dimensions(ffprobe: str, path: Path) -> tuple[int, int]:
    result = subprocess.run(
        [
            ffprobe,
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height",
            "-of",
            "json",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    stream = json.loads(result.stdout)["streams"][0]
    return int(stream["width"]), int(stream["height"])


def matrix_filter(matrix: tuple[tuple[float, ...], ...]) -> str:
    values = [value for row in matrix for value in row]
    names = ("rr", "rg", "rb", "gr", "gg", "gb", "br", "bg", "bb")
    return "colorchannelmixer=" + ":".join(
        f"{name}={value:.6f}" for name, value in zip(names, values)
    )


def font_path() -> Path:
    candidates = (
        Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf"),
        Path("/System/Library/Fonts/Supplemental/Arial.ttf"),
        Path("/System/Library/Fonts/Helvetica.ttc"),
    )
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise RuntimeError("No deterministic system font candidate was found")


def create_sheet(ffmpeg: str, mode: str, font: Path) -> Path:
    output = HERE / f"{mode}-contact-sheet.png"
    command = [ffmpeg, "-hide_banner", "-loglevel", "error", "-y"]
    for _, _, filename, _, _ in PANELS:
        command.extend(["-i", str(LIVE_DIR / filename)])

    filter_parts: list[str] = []
    transform = matrix_filter(TRANSFORMS[mode])
    labels_by_cell: dict[tuple[int, int], str] = {}
    for index, (group, state, _, column, row) in enumerate(PANELS):
        labels_by_cell[(column, row)] = f"p{index}"
        label = f"{group.upper()} / {state.upper()}"
        filter_parts.append(
            f"[{index}:v]format=rgb24,{transform},"
            f"scale={PANEL_WIDTH}:{IMAGE_HEIGHT}:force_original_aspect_ratio=decrease:flags=lanczos,"
            f"pad={PANEL_WIDTH}:{IMAGE_HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=0x0d131b,"
            f"pad={PANEL_WIDTH}:{PANEL_HEIGHT}:0:40:color=0x182230,"
            f"drawtext=fontfile='{font}':text='{label}':fontcolor=white:fontsize=20:"
            f"x=(w-text_w)/2:y=10[p{index}]"
        )

    stack_labels: list[str] = []
    layout: list[str] = []
    blank_index = 0
    for row in range(GRID_ROWS):
        for column in range(GRID_COLUMNS):
            label = labels_by_cell.get((column, row))
            if label is None:
                label = f"blank{blank_index}"
                blank_index += 1
                filter_parts.append(
                    f"color=c=0x10161f:s={PANEL_WIDTH}x{PANEL_HEIGHT}:d=1[{label}]"
                )
            stack_labels.append(f"[{label}]")
            layout.append(f"{column * PANEL_WIDTH}_{row * PANEL_HEIGHT}")

    filter_parts.append(
        "".join(stack_labels)
        + f"xstack=inputs={GRID_COLUMNS * GRID_ROWS}:layout={'|'.join(layout)}:fill=0x10161f[grid]"
    )
    title = f"PLAY-022 ROUND 1B / FC8B838 / {mode.upper()}"
    subtitle = "EXACT STAGED SOURCES / LABELS IDENTIFY WINDOW AND STATE"
    filter_parts.append(
        f"[grid]pad={SHEET_WIDTH}:{SHEET_HEIGHT}:0:{HEADER_HEIGHT}:color=0x0a1018,"
        f"drawtext=fontfile='{font}':text='{title}':fontcolor=white:fontsize=30:x=28:y=13,"
        f"drawtext=fontfile='{font}':text='{subtitle}':fontcolor=0xa8bacd:fontsize=17:x=29:y=47[out]"
    )

    command.extend(
        [
            "-filter_complex",
            ";".join(filter_parts),
            "-map",
            "[out]",
            "-frames:v",
            "1",
            "-compression_level",
            "9",
            "-map_metadata",
            "-1",
            str(output),
        ]
    )
    subprocess.run(command, check=True)
    return output


def main() -> None:
    ffmpeg = shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    if ffmpeg is None or ffprobe is None:
        raise RuntimeError("ffmpeg and ffprobe are required")

    missing = sorted(
        filename for _, _, filename, _, _ in PANELS if not (LIVE_DIR / filename).is_file()
    )
    if missing:
        raise RuntimeError("Missing expected exact-candidate sources: " + ", ".join(missing))

    sources = []
    for group, state, filename, column, row in PANELS:
        source = LIVE_DIR / filename
        width, height = probe_dimensions(ffprobe, source)
        sources.append(
            {
                "group": group,
                "state": state,
                "source": f"../live-fc8b838/{filename}",
                "sha256": sha256(source),
                "width": width,
                "height": height,
                "sheet_cell": {"column": column, "row": row},
            }
        )

    font = font_path()
    outputs = []
    for mode in TRANSFORMS:
        output = create_sheet(ffmpeg, mode, font)
        width, height = probe_dimensions(ffprobe, output)
        outputs.append(
            {
                "mode": mode,
                "path": output.name,
                "sha256": sha256(output),
                "width": width,
                "height": height,
            }
        )

    ffmpeg_version = subprocess.run(
        [ffmpeg, "-version"], check=True, capture_output=True, text=True
    ).stdout.splitlines()[0]
    manifest = {
        "schema": "citysim.play022.round1b.supporting-evidence.v1",
        "candidate_product_commit": CANDIDATE_COMMIT,
        "source_packet": "../live-fc8b838",
        "generation": "deterministic; no timestamps or random inputs",
        "generator": {
            "path": Path(__file__).name,
            "sha256": sha256(Path(__file__)),
            "ffmpeg": ffmpeg_version,
            "font": str(font),
            "layout": {
                "sheet_width": SHEET_WIDTH,
                "sheet_height": SHEET_HEIGHT,
                "panel_width": PANEL_WIDTH,
                "panel_height": PANEL_HEIGHT,
                "image_height": IMAGE_HEIGHT,
            },
        },
        "transforms": {
            mode: {
                "matrix": matrix,
                "channel_space": "normalized sRGB values through ffmpeg colorchannelmixer",
                "reference": (
                    "Rec. 709 luma coefficients"
                    if mode == "grayscale"
                    else "Machado et al. severity-1 color-vision-deficiency matrix"
                ),
            }
            for mode, matrix in TRANSFORMS.items()
        },
        "sources": sources,
        "outputs": outputs,
        "required_source_count": len(PANELS),
        "required_sources_missing": [],
        "unavailable_cross_size_variants_not_fabricated": UNAVAILABLE_CROSS_SIZE_VARIANTS,
    }
    manifest_path = HERE / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    validation = [
        "# PLAY-022 Round 1B supporting-sheet validation",
        "",
        f"- **Candidate product commit:** `{CANDIDATE_COMMIT}`",
        f"- **Expected exact-candidate sources:** {len(PANELS)}/{len(PANELS)} present and decoded",
        "- **Required source gates missing:** none",
        f"- **Generated sheets:** {len(outputs)}/{len(TRANSFORMS)} at `{SHEET_WIDTH} x {SHEET_HEIGHT}`",
        "- **Transforms:** Rec. 709 grayscale plus Machado severity-1 protanopia, deuteranopia, and tritanopia matrices",
        "- **Determinism:** fixed source order, matrices, Lanczos scaling, padding, labels, system font path, PNG compression, and no timestamp/random input",
        "- **Truth boundary:** transforms change pixels only; no state labels, gameplay facts, topology, or source captures were invented",
        "",
        "## Coverage",
        "",
        "| Evidence class | Exact source coverage |",
        "|---|---|",
        "| Default | normal, selection, valid placement, utilities overlay |",
        "| Compact | normal 900 x 600 content, selection, valid placement, invalid placement, utilities overlay |",
        "| Construction | 0%, 25%, 50%, 75%, 100% at residential coordinate 16,14 |",
        "| Reduce Motion | compact samples A and B |",
        "",
        "## Unavailable cross-size variants",
        "",
        "These variants were not present in the exact live packet and were not fabricated:",
        "",
    ]
    validation.extend(f"- {item}" for item in UNAVAILABLE_CROSS_SIZE_VARIANTS)
    validation.extend(
        [
            "",
            "The requested source mapping itself has no missing gate: each evidence class is represented where an exact source frame exists.",
            "",
            "## Output hashes",
            "",
        ]
    )
    validation.extend(f"- `{item['sha256']}`  `{item['path']}`" for item in outputs)
    validation.append("")
    validation_path = HERE / "VALIDATION.md"
    validation_path.write_text("\n".join(validation), encoding="utf-8")

    checksum_paths = [Path(__file__), manifest_path, validation_path] + [
        HERE / item["path"] for item in outputs
    ]
    checksum_lines = [f"{sha256(path)}  {path.name}" for path in sorted(checksum_paths)]
    (HERE / "SHA256SUMS").write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
