#!/usr/bin/env python3
"""Build deterministic PLAY-022 Round 1D color-vision contact sheets."""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
LIVE = ROOT / "live"
HARNESS = ROOT / "harness"
PRODUCT = "8433621760ba169995aa1a5dc81cac27c380d746"
PANEL_W, IMAGE_H, PANEL_H = 300, 180, 210

PANELS = [
    ("DEFAULT", LIVE / "default-city.jpeg"),
    ("CITY LOD", LIVE / "regular-city-lod.jpeg"),
    ("NEIGHBORHOOD LOD", LIVE / "regular-neighborhood-lod.jpeg"),
    ("BLOCK LOD", LIVE / "regular-block-lod.jpeg"),
    ("COMPACT", LIVE / "compact-900x600.jpeg"),
    ("KEYBOARD SELECTION", LIVE / "compact-keyboard-selection.jpeg"),
    ("INVALID", LIVE / "compact-invalid-placement.jpeg"),
    ("VALID", LIVE / "compact-valid-placement.jpeg"),
    ("UTILITY OVERLAY", LIVE / "compact-utility-overlay.jpeg"),
    ("POINTER SELECTION", LIVE / "regular-pointer-selection.jpeg"),
    ("CONSTRUCTION 0", HARNESS / "construction-00.png"),
    ("CONSTRUCTION 25", HARNESS / "construction-25.png"),
    ("CONSTRUCTION 50", HARNESS / "construction-50.png"),
    ("CONSTRUCTION 75", HARNESS / "construction-75.png"),
    ("CONSTRUCTION 100", HARNESS / "construction-100.png"),
    ("REDUCE MOTION", LIVE / "compact-reduce-motion-a.jpeg"),
]

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


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def matrix_filter(matrix: tuple[tuple[float, ...], ...]) -> str:
    names = ("rr", "rg", "rb", "gr", "gg", "gb", "br", "bg", "bb")
    values = [value for row in matrix for value in row]
    return "colorchannelmixer=" + ":".join(
        f"{name}={value:.6f}" for name, value in zip(names, values)
    )


def dimensions(ffprobe: str, path: Path) -> tuple[int, int]:
    result = subprocess.run(
        [
            ffprobe,
            "-v",
            "error",
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


def main() -> None:
    ffmpeg = shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    if not ffmpeg or not ffprobe:
        raise RuntimeError("ffmpeg and ffprobe are required")
    missing = [str(path) for _, path in PANELS if not path.is_file()]
    if missing:
        raise RuntimeError("Missing source frames: " + ", ".join(missing))

    font = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
    command = [ffmpeg, "-hide_banner", "-loglevel", "error", "-y"]
    for _, path in PANELS:
        command.extend(["-i", str(path)])

    filters = []
    for index, (label, _) in enumerate(PANELS):
        filters.append(
            f"[{index}:v]scale={PANEL_W}:{IMAGE_H}:"
            "force_original_aspect_ratio=decrease:flags=lanczos,"
            f"pad={PANEL_W}:{IMAGE_H}:(ow-iw)/2:(oh-ih)/2:color=0x101820,"
            f"pad={PANEL_W}:{PANEL_H}:0:0:color=0x172330,"
            f"drawtext=fontfile='{font}':text='{label}':fontcolor=white:"
            f"fontsize=15:x=(w-text_w)/2:y={IMAGE_H + 7}[p{index}]"
        )
    layout = "|".join(
        f"{(index % 4) * PANEL_W}_{(index // 4) * PANEL_H}"
        for index in range(len(PANELS))
    )
    inputs = "".join(f"[p{index}]" for index in range(len(PANELS)))
    filters.append(f"{inputs}xstack=inputs=16:layout={layout}:fill=0x101820[grid]")

    outputs = []
    for mode, matrix in TRANSFORMS.items():
        output = HERE / f"{mode}-contact-sheet.png"
        mode_command = command + [
            "-filter_complex",
            ";".join(filters + [f"[grid]{matrix_filter(matrix)}[out]"]),
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
        subprocess.run(mode_command, check=True)
        width, height = dimensions(ffprobe, output)
        outputs.append(
            {
                "mode": mode,
                "path": output.name,
                "sha256": digest(output),
                "width": width,
                "height": height,
            }
        )

    manifest = {
        "schema": "citysim.play022.round1d.supporting-evidence.v1",
        "product_commit": PRODUCT,
        "generation": "deterministic; no timestamps or random inputs",
        "generator": {
            "path": Path(__file__).name,
            "sha256": digest(Path(__file__)),
            "ffmpeg": subprocess.run(
                [ffmpeg, "-version"], check=True, capture_output=True, text=True
            ).stdout.splitlines()[0],
        },
        "sources": [
            {
                "label": label,
                "path": str(path.relative_to(ROOT)),
                "sha256": digest(path),
                "dimensions": dimensions(ffprobe, path),
            }
            for label, path in PANELS
        ],
        "outputs": outputs,
        "transforms": TRANSFORMS,
    }
    (HERE / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
