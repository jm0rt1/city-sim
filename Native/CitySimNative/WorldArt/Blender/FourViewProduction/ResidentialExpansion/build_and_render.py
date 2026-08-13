#!/usr/bin/env python3
"""Build CitySim's original Brickline Rowhouse four-view source asset."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import os
import sys
from pathlib import Path

import bpy


HERE = Path(__file__).resolve().parent
PRODUCTION_DIR = HERE.parent
BLENDER_DIR = PRODUCTION_DIR.parent
CANONICAL_DIR = BLENDER_DIR / "FourViewPipeline"
KIT_PATH = PRODUCTION_DIR / "ResidentialCivic" / "build_and_render.py"
OUT = Path(os.environ.get("CITYSIM_OUTPUT_DIR", HERE))
ASSET_ID = "brickline_rowhouse_apartments"
ASSET_DIR = OUT / ASSET_ID
RENDER_DIR = ASSET_DIR / "renders"

sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL_DIR))
from png_canonical import canonicalize_png, decode_rgba_png, encode_rgba_png  # noqa: E402


def load_kit():
    spec = importlib.util.spec_from_file_location("citysim_residential_kit", KIT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("RESIDENTIAL_KIT_IMPORT_FAILED")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


kit = load_kit()
CONFIG = json.loads((CANONICAL_DIR / "pipeline.json").read_text(encoding="utf-8"))


def apartment(root) -> None:
    m = {
        "lot": kit.material("BricklineLotSage", (.29, .38, .27, 1)),
        "walk": kit.material("BricklineWarmPaver", (.68, .58, .43, 1)),
        "stone": kit.material("BricklineSandstone", (.70, .58, .42, 1)),
        "brick": kit.material("BricklineWarmBrick", (.56, .23, .14, 1)),
        "brick_dark": kit.material("BricklineDarkBrick", (.38, .14, .10, 1)),
        "cream": kit.material("BricklineWindowCream", (.91, .78, .55, 1)),
        "roof": kit.material("BricklineMansardSlate", (.12, .25, .30, 1), .54),
        "glass": kit.material("BricklineWindowGlass", (.19, .43, .52, 1), .30),
        "door": kit.material("BricklineJuniperDoor", (.09, .27, .25, 1)),
        "metal": kit.material("BricklineWarmIron", (.13, .12, .11, 1), .40, .30),
        "green": kit.material("BricklinePlanterGreen", (.17, .38, .15, 1)),
        "leaf": kit.material("BricklineLeafHighlight", (.36, .53, .19, 1)),
        "flower": kit.material("BricklineFlower", (.72, .22, .25, 1)),
    }

    lot = kit.box(root, "LotDiamond", (0, 0, -.11), (4, 4, .22), m["lot"], edge=.07)
    lot["worldFootprintTiles"] = [2, 2]
    kit.box(root, "FrontWalk", (0, -1.52, .035), (3.50, .72, .07), m["walk"], edge=.025)
    kit.box(root, "StonePlinth", (0, .16, .20), (3.36, 2.72, .40), m["stone"], edge=.055)
    kit.box(root, "ApartmentBody", (0, .20, 1.91), (3.12, 2.46, 3.38), m["brick"], edge=.055)
    kit.box(root, "GroundRustication", (0, -.985, .86), (3.18, .13, 1.14), m["stone"], edge=.025)

    # A stepped cornice and mansard-like upper mass create a strong silhouette.
    kit.box(root, "SecondFloorBelt", (0, .20, 1.72), (3.22, 2.53, .16), m["cream"], edge=.022)
    kit.box(root, "MainCornice", (0, .20, 3.53), (3.30, 2.60, .22), m["cream"], edge=.028)
    for x in (-1.30, -.87, -.43, 0, .43, .87, 1.30):
        kit.box(root, f"CorniceDentil{x}", (x, -1.135, 3.48), (.25, .18, .26), m["cream"], edge=.016)
    kit.box(root, "UpperRoofMass", (0, .24, 3.80), (2.72, 2.12, .48), m["brick_dark"], edge=.04)
    kit.prism(root, "MansardCap", (0, .24, 4.03), 3.04, 2.44, .13, .68, m["roof"])
    kit.roof_seams(root, "MansardCap", (0, .24, 4.03), 3.04, 2.44, .13, .68, m["roof"])

    # Three window bays on front and rear, repeated through three floors.
    for side_name, y, normal in (("Front", -1.045, -1), ("Rear", 1.445, 1)):
        for floor, z in enumerate((1.13, 2.21, 3.06), start=1):
            for bay, x in enumerate((-.91, 0, .91), start=1):
                dims = (.52, .07, .62 if floor < 3 else .52)
                kit.window(root, f"{side_name}Window{floor}_{bay}", (x, y, z), dims, m["cream"], m["glass"])
                if floor == 2 and bay in (1, 3):
                    kit.box(root, f"{side_name}FlowerBox{bay}", (x, y + normal * .09, z - .40), (.64, .20, .16), m["stone"], edge=.025)
                    for index, offset in enumerate((-.18, 0, .18)):
                        kit.sphere(root, f"{side_name}Flower{bay}_{index}", (x + offset, y + normal * .13, z - .24), (.09, .09, .11), m["flower"])

    # Side facades stay authored and recognizable in camNE/camSW views.
    for side_name, x, normal in (("East", 1.595, 1), ("West", -1.595, -1)):
        for floor, z in enumerate((1.15, 2.23, 3.06), start=1):
            for bay, y in enumerate((-.42, .54), start=1):
                kit.window(root, f"{side_name}Window{floor}_{bay}", (x, y, z), (.07, .53, .60 if floor < 3 else .50), m["cream"], m["glass"])
        for edge_index, y in enumerate((-.89, 1.27), start=1):
            kit.box(root, f"{side_name}CornerQuoin{edge_index}", (x + normal * .025, y, 2.05), (.16, .16, 3.06), m["brick_dark"], edge=.022)
        for floor, z in enumerate((1.72, 2.80), start=1):
            kit.box(root, f"{side_name}WindowBelt{floor}", (x + normal * .03, .08, z), (.10, 1.76, .11), m["cream"], edge=.014)

    # Central entry, stoop, bay canopy, and iron railing establish street frontage.
    kit.box(root, "EntryRecess", (0, -1.075, .93), (.72, .12, 1.38), m["brick_dark"], edge=.025)
    kit.box(root, "DoubleEntryDoor", (0, -1.15, .94), (.60, .08, 1.30), m["door"], edge=.025)
    kit.box(root, "DoorSplit", (0, -1.20, .94), (.035, .035, 1.18), m["cream"], edge=.006)
    kit.box(root, "Transom", (0, -1.19, 1.47), (.46, .035, .20), m["glass"], edge=.010)
    kit.box(root, "EntryStoop", (0, -1.33, .31), (1.10, .72, .18), m["stone"], edge=.025)
    kit.box(root, "EntryStep", (0, -1.60, .16), (1.38, .28, .14), m["stone"], edge=.020)
    kit.box(root, "EntryCanopy", (0, -1.36, 1.74), (1.20, .65, .13), m["roof"], rotation=(math.radians(-7), 0, 0), edge=.022)
    for x in (-.50, .50):
        kit.box(root, f"CanopyPost{x}", (x, -1.55, .94), (.07, .07, 1.38), m["metal"], edge=.010)
        kit.box(root, f"StoopRail{x}", (x, -1.51, .61), (.05, .52, .60), m["metal"], edge=.008)

    # Two roof dormers, chimney pots, and mechanical vent add roof readability.
    for index, x in enumerate((-.72, .72), start=1):
        kit.box(root, f"DormerWall{index}", (x, -1.01, 4.31), (.66, .38, .62), m["brick_dark"], edge=.032)
        kit.prism(root, f"DormerRoof{index}", (x, -1.10, 4.55), .86, .66, .09, .42, m["roof"])
        kit.window(root, f"DormerWindow{index}", (x, -1.355, 4.34), (.38, .05, .40), m["cream"], m["glass"])
    for index, x in enumerate((-1.02, 1.02), start=1):
        kit.box(root, f"Chimney{index}", (x, .72, 4.77), (.30, .34, .84), m["brick_dark"], edge=.030)
        kit.box(root, f"ChimneyCap{index}", (x, .72, 5.21), (.40, .44, .10), m["cream"], edge=.020)
    kit.cylinder(root, "RoofVent", (0, .55, 4.85), .13, .58, m["metal"], vertices=20)
    kit.cylinder(root, "RoofVentCap", (0, .55, 5.16), .19, .08, m["metal"], vertices=20)

    # Dense but restrained landscaping and street furniture ground the lot.
    for index, (x, y, scale) in enumerate(((-1.42, -1.40, .24), (1.42, -1.40, .24), (-1.42, 1.40, .28), (1.42, 1.40, .28))):
        kit.box(root, f"Planter{index}", (x, y, .28), (.42, .42, .32), m["stone"], edge=.035)
        kit.sphere(root, f"Shrub{index}", (x, y, .60), (scale, scale, scale * 1.25), m["green"])
        kit.sphere(root, f"ShrubHighlight{index}", (x - .07, y - .05, .72), (scale * .55, scale * .50, scale * .60), m["leaf"])
    kit.box(root, "BenchSeat", (-1.02, -1.65, .45), (.70, .25, .09), m["metal"], edge=.018)
    for x in (-1.27, -.77):
        kit.box(root, f"BenchLeg{x}", (x, -1.65, .29), (.06, .18, .27), m["metal"], edge=.008)
    kit.cylinder(root, "EntryLampPost", (1.14, -1.62, .71), .045, 1.22, m["metal"], vertices=12)
    kit.cylinder(root, "EntryLamp", (1.14, -1.62, 1.38), .15, .22, m["cream"], vertices=16)

    root["assetFamily"] = "medium-residential"
    root["worldFootprintTiles"] = [2, 2]


def rgba_hash(path: Path) -> tuple[int, int, str]:
    width, height, rgba = decode_rgba_png(path)
    return width, height, hashlib.sha256(rgba).hexdigest()


def alpha_composite(destination: bytearray, dw: int, dh: int, source: bytes, sw: int, sh: int, left: int, top: int) -> None:
    for sy in range(sh):
        dy = top + sy
        if dy < 0 or dy >= dh:
            continue
        for sx in range(sw):
            dx = left + sx
            if dx < 0 or dx >= dw:
                continue
            si = (sy * sw + sx) * 4
            alpha = source[si + 3]
            if alpha == 0:
                continue
            di = (dy * dw + dx) * 4
            inverse = 255 - alpha
            for channel in range(3):
                destination[di + channel] = (source[si + channel] * alpha + destination[di + channel] * inverse + 127) // 255
            destination[di + 3] = 255


def preview(source_path: Path) -> Path:
    width, height = 900, 600
    canvas = bytearray(width * height * 4)
    for y in range(height):
        color = (34 - y * 12 // height, 44 - y * 15 // height, 46 - y * 15 // height, 255)
        canvas[y * width * 4:(y + 1) * width * 4] = bytes(color) * width
    sw, sh, rgba = decode_rgba_png(source_path)
    alpha_composite(canvas, width, height, rgba, sw, sh, width // 2 - 192, height // 2 - 215)
    path = ASSET_DIR / f"{ASSET_ID}_preview_900x600.png"
    encode_rgba_png(path, width, height, bytes(canvas))
    return path


def artifact(path: Path) -> dict:
    item = {
        "path": path.relative_to(OUT).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }
    if path.suffix.lower() == ".png":
        width, height, rgba_sha = rgba_hash(path)
        item.update(dimensions=[width, height], decodedRgbaSha256=rgba_sha)
    return item


def main() -> None:
    actual = ".".join(map(str, bpy.app.version))
    if actual != CONFIG["toolchain"]["blenderVersion"]:
        raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    RENDER_DIR.mkdir(parents=True, exist_ok=True)

    scene = kit.reset()
    kit.configure(scene)
    root = kit.root_for(ASSET_ID, "Original three-story warm-brick rowhouse apartment with four authored facades")
    apartment(root)
    cameras = kit.rig()
    scene.camera = cameras[0]

    blend_path = ASSET_DIR / f"{ASSET_ID}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), check_existing=False)
    render_paths = kit.render(scene, cameras, ASSET_ID, RENDER_DIR)
    original_here = kit.HERE
    try:
        kit.HERE = ASSET_DIR
        contact_path = kit.contact_sheet(render_paths, ASSET_ID)
    finally:
        kit.HERE = original_here
    preview_path = preview(render_paths[0])

    paths = [blend_path, *render_paths, contact_path, preview_path]
    manifest = {
        "schema": "citysim.four-view-production.v1",
        "assetId": ASSET_ID,
        "assetFamily": "medium-residential",
        "status": "source-only-not-live",
        "originalGeometry": True,
        "sourcePixelsReused": False,
        "cedarMarketReused": False,
        "liveAsset": False,
        "pipelineSchema": CONFIG["schema"],
        "projectedTilePixels": CONFIG["grid"]["projectedTilePixels"],
        "worldFootprintTiles": [2, 2],
        "canvas": CONFIG["canvas"],
        "cameraOrder": [view["name"] for view in CONFIG["cameraRig"]["views"]],
        "cameraAzimuthDegrees": {view["name"]: view["azimuthDegrees"] for view in CONFIG["cameraRig"]["views"]},
        "elevationDegrees": CONFIG["grid"]["elevationDegrees"],
        "lightingConvention": CONFIG["lighting"],
        "postRenderCompensation": "none",
        "artifacts": [artifact(path) for path in paths],
    }
    (ASSET_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("RESIDENTIAL_EXPANSION_RENDER_PASS")


if __name__ == "__main__":
    main()
