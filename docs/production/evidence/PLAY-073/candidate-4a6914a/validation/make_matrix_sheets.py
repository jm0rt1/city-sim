from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1] / "matrix"
BEFORE = ROOT / "before"
AFTER = ROOT / "after"
STATES = [
    "commercial-pressured-district-v2",
    "commercial-recovering-district-v2",
    "commercial-upgraded-district-v2",
    "commercial-terminal-district-v2",
    "industrial-pressured-district-v2",
    "industrial-recovering-district-v2",
    "industrial-upgraded-district-v2",
    "industrial-terminal-district-v2",
]
ROUTES = [
    ("regular", "city"),
    ("regular", "neighborhood"),
    ("regular", "block"),
    ("compact", "city"),
    ("compact", "neighborhood"),
    ("compact", "block"),
]


def fitted(image: Image.Image, width: int, height: int) -> Image.Image:
    copy = image.copy()
    copy.thumbnail((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (width, height), "#162019")
    canvas.paste(copy, ((width - copy.width) // 2, (height - copy.height) // 2))
    return canvas


def build_sheet(route: str, lod: str) -> None:
    cell_width = 560
    cell_height = 350
    label_height = 34
    sheet = Image.new(
        "RGB",
        (cell_width * 2, label_height + cell_height * len(STATES)),
        "#111713",
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=18)
    draw.text((12, 8), f"BEFORE e38059e · {route} · {lod}", fill="white", font=font)
    draw.text(
        (cell_width + 12, 8),
        f"AFTER 4a6914a · {route} · {lod}",
        fill="white",
        font=font,
    )
    for row, state in enumerate(STATES):
        y = label_height + row * cell_height
        for column, root in enumerate((BEFORE, AFTER)):
            image = Image.open(root / f"{state}-{route}-{lod}.png").convert("RGB")
            frame = fitted(image, cell_width, cell_height)
            sheet.paste(frame, (column * cell_width, y))
            draw.rectangle(
                (column * cell_width + 6, y + 6, column * cell_width + 365, y + 32),
                fill="#111713",
            )
            draw.text(
                (column * cell_width + 12, y + 10),
                state.replace("-district-v2", ""),
                fill="white",
                font=font,
            )
    sheet.save(ROOT / f"comparison-{route}-{lod}.png", optimize=True)


for route_name, lod_name in ROUTES:
    build_sheet(route_name, lod_name)
