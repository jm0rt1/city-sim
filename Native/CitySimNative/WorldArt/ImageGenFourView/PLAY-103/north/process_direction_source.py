#!/usr/bin/env python3
"""Deterministic PLAY-103 North source packaging for industrial_l01_v0."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parent
REPO = next(parent for parent in ROOT.parents if (parent / ".git").exists())
RAW = ROOT / "raw/industrial_l01_v0/north-v01.png"
SOURCE_SIZE = (1536, 1024)
PIVOT = (768, 896)
SOCKET = (896, 704)
FOOTPRINT = ((768, 640), (1024, 768), (768, 896), (512, 768))
LODS = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
SOUTH_PATH = "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l01_v00-source-v01.png"
SOUTH_SHA256 = "7ca3e26234e7e15df9a46775a83f7132f89e1ea1f22d97c42ca6d3502099bbd2"
ROUTE = {
    "path": "/private/tmp/PLAY-103-INDUSTRIAL-L01-V0-NORTH-ROUTE-V3.json",
    "routeId": "north-v3:play-103-currentd3be-industrial-l01-v0-recent-image-v1",
    "routeFileSha256": "4225e9191762673af82bf42e673634b1b5df83f191a821a02c1b02553a67482b",
    "routeCanonicalSha256": "daceb1161d9153a6ec0bb85dd8542e11ee6816a6e775a3c0a60078a4f624ff6a",
    "dispatchPath": "/private/tmp/PLAY-103-INDUSTRIAL-L01-V0-NORTH-DISPATCH-V3.json",
    "dispatchFileSha256": "625a8855423e0e6f7042428355f5a05ea0648f3de3975c08de22994ea1cbc20f",
    "dispatchCanonicalSha256": "81cef20a6b5081e5d3d95272328d2ea151fa047eec00d83b65f992ce4dab9a63",
    "authorityCommit": "d3bed770eb3bf79194df7b15737a19bddafdcd42",
    "baseCommit": "cf3e27f75d033fcd5880b19337ada95030b5e1db",
    "startingHead": "d3bed770eb3bf79194df7b15737a19bddafdcd42",
    "classification": "LUNA_IMPLEMENTATION",
    "model": "gpt-5.6-luna",
    "effort": "high",
}
CLAIM_PATH = "docs/production/claims/PLAY-103.world-art-north-industrial-l01-v0-currentcf3.md"
CLAIM_SHA256 = "cf3c3a80946f755476595819b4eaaa142208a84195fdf6acd6446692b8affd76"
CONTRACT_PATH = "docs/production/decisions/CONTRACT-025-authored-four-view-2-5d-building-art.md"
CONTRACT_SHA256 = "4e8ab63173d67581332e7d27730b97315906fda4e29b999969456441809479ed"
PROFILE_PATH = "docs/production/decisions/CONTRACT-026-registration-profiles-v1.json"
PROFILE_SHA256 = "6663482339e953bdcbcb86bcfc876676989fbcb7f74a91f3f1b480d124fe3bd8"
SEMANTIC_VALIDATOR = "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-096/four_view_harness.py"
HANDOFF_SCHEMA = "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-096/schemas/direction-handoff.schema.json"
TRANSPORT = "central_view_image_recent_image_bridge"
GENERATED_ORIGIN = "/Users/James/.codex/generated_images/019fe85c-8a34-7fb2-9128-cbf05ab837b0/exec-f14799e6-d7e6-4559-a728-3e0180384c6d.png"
GENERATED_OUTPUT = GENERATED_ORIGIN
GENERATED_SHA256 = "81b1770d6e85f5f92a6a619ac55ddff29bab36358c074a6bbd57a6e434a151a7"
PROMPT = """Use case: stylized-concept. Asset type: CitySim authored four-view 2.5D source sprite. Input image: Image 1 is the immutable canonical South raw identity reference for industrial_l01_v0; use it only to preserve identity, variant, materials, massing, roofline, props, gameplay meaning, and scale. Primary request: create exactly one independently authored North sibling view of the same industrial_l01_v0 building, with the visible road-facing frontage and service/loading access facing North. Author new pixels for the North view; do not mirror, bitmap-rotate, copy, alias, or transform the South pixels. Scene/backdrop: a perfectly flat solid #ff00ff chroma-key field filling the entire 1536x1024 canvas, with no gradient, texture, floor plane, reflection, or background shadow. Subject: the same industrial L1 variant identity, preserving its exact massing, roofline, industrial materials, colors, windows, tanks, pipes, gantries, condition, silhouette, gameplay meaning, and full-canvas scale. Style/medium: richly detailed, realistic hand-painted city-builder 2.5D orthographic 2:1 isometric art, not voxel, toy, flat-vector, or raw 3D-render appearance. Composition/framing: full 1536x1024 canvas, code-owned ground pivot [768,896], no crop, no trim, no inferred geometry, no extra buildings or roads. Lighting/mood: frozen northwest key light with a contained southeast contact shadow; no long dark lower-left cast shadow. Constraints: preserve identity and variant; author a believable North-facing entrance/loading/service frontage; keep the full coordinate system and padding; no text, labels, UI, watermark, selection marks, agents, or false simulation state. Avoid: mirror, rotate pixels, raster transform, synthetic substitute, sibling reuse, fallback, alias, extra structures, perspective camera, clipped roofline, cropped canvas, hard background shadow, long lower-left shadow, green or nonuniform background."""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical(value: object) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def rel(path: Path, output_root: Path) -> str:
    return path.resolve().relative_to(output_root.resolve()).as_posix()


def repo_rel(path: Path) -> str:
    return path.resolve().relative_to(REPO.resolve()).as_posix()


def resize_point(point: tuple[int, int], size: tuple[int, int]) -> list[int]:
    return [round(point[0] * size[0] / SOURCE_SIZE[0]), round(point[1] * size[1] / SOURCE_SIZE[1])]


def normalize_raw(source: Path) -> Image.Image:
    with Image.open(source) as opened:
        opened.load()
        if opened.size != SOURCE_SIZE or opened.mode != "RGB":
            raise ValueError("raw source must be RGB 1536x1024")
        rgb = np.asarray(opened, dtype=np.uint8).copy()
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    chroma = (red >= 180) & (blue >= 150) & (green <= 110) & ((red + blue) >= (green * 4))
    spill = (~chroma) & (red * 100 > green * 135) & (blue * 100 > green * 125)
    amount = np.maximum(np.minimum(red, blue) - green, 0)
    red[spill] = np.maximum(green[spill], red[spill] - amount[spill])
    blue[spill] = np.maximum(green[spill], blue[spill] - amount[spill])
    alpha = np.where(chroma, 0, 255).astype(np.uint8)
    rgba = np.zeros((SOURCE_SIZE[1], SOURCE_SIZE[0], 4), dtype=np.uint8)
    rgba[:, :, :3] = np.stack((red, green, blue), axis=2).astype(np.uint8)
    rgba[:, :, 3] = alpha
    rgba[alpha == 0, :3] = 0
    return Image.fromarray(rgba, "RGBA")


def clean_resized(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    red = rgba[:, :, 0].astype(np.int16)
    green = rgba[:, :, 1].astype(np.int16)
    blue = rgba[:, :, 2].astype(np.int16)
    alpha = rgba[:, :, 3]
    matte = (alpha > 0) & (red >= 180) & (blue >= 150) & (green <= 110) & ((red + blue) >= (green * 4))
    alpha[matte] = 0
    transparent = alpha == 0
    neighbor_zero = np.zeros_like(transparent, dtype=bool)
    neighbor_zero[1:, :] |= transparent[:-1, :]
    neighbor_zero[:-1, :] |= transparent[1:, :]
    neighbor_zero[:, 1:] |= transparent[:, :-1]
    neighbor_zero[:, :-1] |= transparent[:, 1:]
    residual = (alpha > 0) & (alpha < 255) & neighbor_zero & (np.maximum(red, blue) >= 64) & ((red + blue - 2 * green) >= 64)
    red[residual] = np.minimum(red[residual], green[residual] + 31)
    blue[residual] = np.minimum(blue[residual], green[residual] + 31)
    rgba[:, :, :3] = np.stack((red, green, blue), axis=2).astype(np.uint8)
    rgba[:, :, 3] = alpha
    rgba[alpha == 0, :3] = 0
    rgba[0, :, :] = 0
    rgba[-1, :, :] = 0
    rgba[:, 0, :] = 0
    rgba[:, -1, :] = 0
    return Image.fromarray(rgba, "RGBA")


def metrics(image: Image.Image) -> dict[str, int]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    alpha = rgba[:, :, 3]
    red, green, blue = (rgba[:, :, i].astype(np.int16) for i in range(3))
    hidden = int(np.count_nonzero((alpha == 0) & np.any(rgba[:, :, :3] != 0, axis=2)))
    keyed = (alpha > 0) & (red >= 180) & (blue >= 150) & (green <= 110) & ((red + blue) >= (green * 4))
    transparent = alpha == 0
    neighbor_zero = np.zeros_like(transparent, dtype=bool)
    neighbor_zero[1:, :] |= transparent[:-1, :]
    neighbor_zero[:-1, :] |= transparent[1:, :]
    neighbor_zero[:, 1:] |= transparent[:, :-1]
    neighbor_zero[:, :-1] |= transparent[:, 1:]
    residual = (alpha > 0) & (alpha < 255) & neighbor_zero & (np.maximum(red, blue) >= 64) & ((red + blue - 2 * green) >= 64)
    edge = np.concatenate((alpha[0, :], alpha[-1, :], alpha[1:-1, 0], alpha[1:-1, -1]))
    result = {
        "visiblePixels": int(np.count_nonzero(alpha)),
        "transparentPixels": int(alpha.size - np.count_nonzero(alpha)),
        "hiddenRgbPixels": hidden,
        "keyedMagentaPixels": int(np.count_nonzero(keyed)),
        "boundaryResidualChromaPixels": int(np.count_nonzero(residual)),
        "frameEdgeOpaquePixels": int(np.count_nonzero(edge)),
    }
    if any(result[key] for key in ("hiddenRgbPixels", "keyedMagentaPixels", "boundaryResidualChromaPixels", "frameEdgeOpaquePixels")):
        raise ValueError(f"Contract-025/006 pixel gate failed: {result}")
    return result


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def sheet(path: Path, image: Image.Image, label: str, grayscale: bool = False) -> None:
    canvas = Image.new("RGB", (768, 600), (28, 31, 36))
    thumb = image.convert("RGBA")
    if grayscale:
        gray = ImageOps.grayscale(thumb)
        thumb = Image.merge("RGBA", (gray, gray, gray, thumb.getchannel("A")))
    thumb.thumbnail((720, 500), Image.Resampling.LANCZOS)
    checker = Image.new("RGB", thumb.size, (72, 75, 80))
    checker.paste(thumb, mask=thumb.getchannel("A"))
    canvas.paste(checker, ((768 - thumb.width) // 2, 24))
    ImageDraw.Draw(canvas).text((24, 550), label, fill=(242, 244, 247), font=ImageFont.load_default())
    save(canvas, path)


def artifact_entries(output_root: Path, paths: list[Path]) -> list[dict[str, str]]:
    return [{"path": rel(path, output_root), "sha256": sha256(path)} for path in sorted(paths, key=lambda item: rel(item, output_root))]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", default=str(ROOT))
    args = parser.parse_args()
    output_root = Path(args.output_root).resolve()
    if not RAW.is_file() or sha256(RAW) != GENERATED_SHA256:
        raise ValueError("closed Integration-direct North raw is missing or hash-mismatched")
    if sha256(REPO / SOUTH_PATH) != SOUTH_SHA256:
        raise ValueError("canonical South anchor hash drift")

    registered = normalize_raw(RAW)
    lods: dict[str, object] = {}
    generated: list[Path] = []
    for name, size in LODS.items():
        image = clean_resized(registered.resize(size, Image.Resampling.LANCZOS))
        destination = output_root / f"normalized/industrial_l01_v0/{name}/north-v01.png"
        save(image, destination)
        gate = metrics(image)
        lods[name] = {
            "path": rel(destination, output_root),
            "sha256": sha256(destination),
            "dimensions": list(size),
            "mode": "RGBA",
            "filter": "lanczos",
            "registration": {
                "groundPivot": resize_point(PIVOT, size),
                "northFrontageSocket": resize_point(SOCKET, size),
                "footprint": [resize_point(point, size) for point in FOOTPRINT],
            },
            **gate,
        }
        generated.append(destination)

    prompt_path = output_root / "prompts/industrial_l01_v0-north.json"
    provenance_path = output_root / "provenance/industrial_l01_v0-north.json"
    handoff_path = output_root / "handoff/industrial_l01_v0-north-handoff.json"
    manifest_path = output_root / "process/industrial_l01_v0-north-manifest.json"
    prompt_record = {
        "schema": "citysim.play-103.north-industrial-l01-v0.prompt.v1",
        "task": "PLAY-103",
        "logicalId": "industrial_l01_v0",
        "direction": "north",
        "prompt": PROMPT,
        "reference": {"role": "immutable_canonical_south_identity_anchor", "path": SOUTH_PATH, "sha256": SOUTH_SHA256},
        "forbidden": ["mirror", "bitmap-rotation", "pixel-transform", "alias", "sibling-copy", "fallback"],
        "transport": TRANSPORT,
    }
    provenance_record = {
        "schema": "citysim.play-103.north-industrial-l01-v0.provenance.v1",
        "task": "PLAY-103",
        "logicalId": "industrial_l01_v0",
        "direction": "north",
        "stage": "source",
        "tool": {"name": "OpenAI built-in ImageGen", "model": "built-in/model-not-exposed", "calls": 1},
        "transport": TRANSPORT,
        "generatedOrigin": GENERATED_ORIGIN,
        "closedOutput": {"path": GENERATED_OUTPUT, "sha256": GENERATED_SHA256, "dimensions": [1536, 1024], "mode": "RGB"},
        "reference": {"role": "immutable_canonical_south_identity_anchor", "path": SOUTH_PATH, "sha256": SOUTH_SHA256},
        "promptPath": rel(prompt_path, output_root),
        "rawNorth": {"path": repo_rel(RAW), "sha256": sha256(RAW), "dimensions": list(SOURCE_SIZE), "mode": "RGB"},
        "siblingInputsConsumed": [],
        "disposition": "source_candidate",
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }
    write_json(prompt_path, prompt_record)
    write_json(provenance_path, provenance_record)
    generated.extend([prompt_path, provenance_path])

    block = Image.open(output_root / lods["block"]["path"])
    sheets = [
        output_root / "output/contact-sheets/north-industrial_l01_v0-source.png",
        output_root / "output/contact-sheets/north-industrial_l01_v0-game-scale.png",
        output_root / "output/contact-sheets/north-industrial_l01_v0-grayscale.png",
    ]
    sheet(sheets[0], registered, "industrial_l01_v0 North source 1536x1024")
    sheet(sheets[1], block, "industrial_l01_v0 North block LOD 1024x683")
    sheet(sheets[2], block, "industrial_l01_v0 North block LOD grayscale", grayscale=True)
    generated.extend(sheets)

    artifacts = artifact_entries(output_root, generated)
    manifest = {
        "schema": "citysim.play-103.north-industrial-l01-v0.manifest.v1",
        "task": "PLAY-103",
        "logicalId": "industrial_l01_v0",
        "family": "industrial",
        "direction": "north",
        "stage": "source",
        "route": ROUTE,
        "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA256},
        "contract025": {"path": CONTRACT_PATH, "sha256": CONTRACT_SHA256},
        "sourceCanvas": list(SOURCE_SIZE),
        "groundPivotSource": list(PIVOT),
        "northFrontageSocketSource": list(SOCKET),
        "orientationTransform": "none",
        "pixelDerivedGeometry": False,
        "raw": {"path": repo_rel(RAW), "sha256": sha256(RAW), "dimensions": list(SOURCE_SIZE), "mode": "RGB"},
        "southReference": {"path": SOUTH_PATH, "sha256": SOUTH_SHA256},
        "lods": lods,
        "contactSheets": [{"path": rel(path, output_root), "sha256": sha256(path)} for path in sheets],
        "artifacts": artifacts,
        "artifactTreeSha256": canonical(artifacts),
        "siblingInputsConsumed": [],
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "visualAcceptance": "not_performed_worker_cannot_self_accept",
    }
    write_json(manifest_path, manifest)
    write_json(handoff_path, {
        "schema": "citysim.play-103.north-industrial-l01-v0.handoff.v1",
        "task": "PLAY-103",
        "logicalId": "industrial_l01_v0",
        "family": "industrial",
        "direction": "north",
        "stage": "source",
        "branch": "codex/citysim-world-art-play103-industrial-l01-v0-north",
        "baseAuthority": ROUTE["baseCommit"],
        "startingHead": ROUTE["startingHead"],
        "route": ROUTE,
        "claim": {"path": CLAIM_PATH, "sha256": CLAIM_SHA256},
        "familyContract": {"path": CONTRACT_PATH, "sha256": CONTRACT_SHA256},
        "sourceRevision": "north-v01",
        "directionRootMap": {
            "prompt": rel(prompt_path.parent, output_root),
            "provenance": rel(provenance_path.parent, output_root),
            "raw": repo_rel(RAW.parent),
            "normalized": rel((output_root / "normalized/industrial_l01_v0"), output_root),
            "process": rel((output_root / "process"), output_root),
            "output": rel((output_root / "output"), output_root),
            "evidence": "docs/production/evidence/PLAY-103/industrial-l01-v0",
            "handoff": rel(handoff_path.parent, output_root),
        },
        "parallelExecutionReceipt": None,
        "raw": {"path": repo_rel(RAW), "sha256": sha256(RAW), "dimensions": list(SOURCE_SIZE), "mode": "RGB"},
        "normalizedLods": lods,
        "contactSheets": [{"path": rel(path, output_root), "sha256": sha256(path)} for path in sheets],
        "prompt": prompt_record,
        "provenance": provenance_record,
        "manifest": {"path": rel(manifest_path, output_root), "sha256": sha256(manifest_path), "artifactTreeSha256": manifest["artifactTreeSha256"]},
        "siblingInputsConsumed": [],
        "disposition": "source_candidate",
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "visualAcceptance": "pending_independent_frontier_review",
        "knownBlockers": ["Independent technical and literal-scale review; Integration admission; Renderer quarantine; atomic 4/4 selection"],
        "handoffSchema": {"path": HANDOFF_SCHEMA, "sha256": sha256(REPO / HANDOFF_SCHEMA)},
        "semanticValidator": {"path": SEMANTIC_VALIDATOR, "sha256": sha256(REPO / SEMANTIC_VALIDATOR)},
        "registrationProfile": {"path": PROFILE_PATH, "sha256": PROFILE_SHA256},
    })
    print(json.dumps({"result": "PASS", "logicalId": "industrial_l01_v0", "direction": "north", "lodCount": 3, "artifactTreeSha256": manifest["artifactTreeSha256"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
