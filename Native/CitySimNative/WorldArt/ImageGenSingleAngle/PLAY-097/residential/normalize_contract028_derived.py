#!/usr/bin/env python3
"""Bounded PLAY-097 Contract-028 derived-only normalizer.

This helper reads one preserved South source-v01 and the Integration-owned
Contract-028 from an explicit authority checkout.  It never calls ImageGen,
copies source-v02, or touches an existing raw/normalized/evidence byte.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from collections import deque
from pathlib import Path
from typing import Any

try:
    from PIL import Image
except ModuleNotFoundError:  # Use the bundled runtime dependency without changing the worker.
    _bundled = Path("/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/lib/python3.12/site-packages")
    if _bundled.is_dir():
        sys.path.insert(0, str(_bundled))
    from PIL import Image


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parents[5]
IDENTITY = "residential_l01_variant_0"
RAW_REL = f"Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/{IDENTITY}/source-v01.png"
RAW_PATH = REPO_ROOT / RAW_REL
OUTPUT_REL = f"Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/normalized-contract-028/{IDENTITY}"
OUTPUT_BASE_ROOT = REPO_ROOT / "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/normalized-contract-028"
OUTPUT_ROOT = REPO_ROOT / OUTPUT_REL
EVIDENCE_REL = "docs/production/evidence/PLAY-097/contract-028"
EVIDENCE_ROOT = REPO_ROOT / EVIDENCE_REL
OLD_NORMALIZED_ROOT = ROOT / "normalized"
OLD_EVIDENCE_ROOT = REPO_ROOT / "docs/production/evidence/PLAY-097"

ROUTE_ID = "four-view-v33:play-097-south-residential-contract028-derived-only-v4"
ROUTE_SHA256 = "cc2634d2195c0940aa413aff106b493bc63db758fec14b74605e8c17c83d7672"
AUTHORITY_COMMIT = "65825389d586a128ddf6feb5356c33661ba9a8e8"
AUTHORITY_HEAD = "fd080ee936cbdba95bcf48d8997aa0b2c396d8a4"
BASE_COMMIT = "a61ab80101f596f56ffc1dd7e37b32bd1b220357"
EXPECTED_HEAD = "f85de10c120ffba6dd2e7fd129b0b66674174b73"
CLAIM_REL = "docs/production/claims/PLAY-097.world-art-residential.md"
CLAIM_SHA256 = "816acffd9e8cb7cc76ad068b7c6b6ff9fed4015b1646c37ac68c148714901126"
CONTRACT_REL = "docs/production/decisions/CONTRACT-028-alpha-aware-lod-chroma.md"
CONTRACT_SHA256 = "f8b80a98b07029a51b8e61701c85017bd82c8bb0b6c967da6d1fa7fae631da7d"
HANDOFF_REL = "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/handoff/source-v02-chroma-failure.json"
HANDOFF_SHA256 = "7f8686f0bdb9026d176ed4a7a793da615c6f4082ef2dc663453da82184903878"
DOCS_RECEIPT_REL = "docs/production/evidence/PLAY-097/residential-source-v02-chroma-failure.json"
DOCS_RECEIPT_SHA256 = "7a5f4732cfe2ff95753a3e0c718395710f135bb52295646f80d729a367e79de9"
SOURCE_SHA256 = "a808c5da11450418afa26505261cac196480d7d98578e2e8ac796288c7ee0e57"
CONTRACT028 = {"path": CONTRACT_REL, "sha256": CONTRACT_SHA256}
LODS = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
CANVAS = (1536, 1024)
PIVOT = (768, 896)
FOOTPRINT = ((768, 640), (1024, 768), (768, 896), (512, 768))
SOCKET = (640, 832)


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha(path: Path) -> str:
    return sha_bytes(path.read_bytes())


def json_sha(value: Any) -> str:
    return sha_bytes(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode())


def repo_path(path: Path) -> str:
    return path.resolve().relative_to(REPO_ROOT).as_posix()


def authority_path(root: Path, value: str) -> Path:
    candidate = (root / value).resolve()
    if not candidate.is_relative_to(root.resolve()):
        raise RuntimeError(f"authority path escapes root: {value}")
    return candidate


def git(root: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def digest_tree(root: Path) -> dict[str, str]:
    if not root.exists():
        return {}
    return {str(path.relative_to(root)): sha(path) for path in sorted(root.rglob("*")) if path.is_file()}


def baseline_snapshot() -> dict[str, str]:
    paths: dict[str, str] = {}
    for root in (ROOT / "raw", OLD_NORMALIZED_ROOT, ROOT / "receipts", ROOT / "registrations", ROOT / "handoff"):
        for rel, value in digest_tree(root).items():
            paths[f"worker/{root.name}/{rel}"] = value
    for rel, value in digest_tree(OLD_EVIDENCE_ROOT).items():
        if not rel.startswith("contract-028/"):
            paths[f"evidence/{rel}"] = value
    return paths


def require_authority(authority_root: Path, contract_path: str, contract_sha: str) -> None:
    if authority_root.resolve() != Path("/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim").resolve():
        raise RuntimeError("authority-root is not the published Integration checkout")
    if git(authority_root, "rev-parse", "HEAD") != AUTHORITY_HEAD:
        raise RuntimeError("authority-root HEAD is not the V33 published authority")
    if contract_path != CONTRACT_REL or contract_sha != CONTRACT_SHA256:
        raise RuntimeError("Contract-028 path/hash binding mismatch")
    resolved = authority_path(authority_root, contract_path)
    if not resolved.is_file() or sha(resolved) != CONTRACT_SHA256:
        raise RuntimeError("Contract-028 authority bytes mismatch")


def require_worker() -> None:
    if git(REPO_ROOT, "branch", "--show-current") != "codex/citysim-world-art-residential":
        raise RuntimeError("worker branch mismatch")
    if git(REPO_ROOT, "rev-parse", "HEAD") != EXPECTED_HEAD:
        raise RuntimeError("worker HEAD mismatch")
    claim = REPO_ROOT / CLAIM_REL
    if not claim.is_file() or sha(claim) != CLAIM_SHA256:
        raise RuntimeError("claim bytes mismatch")


def require_receipts() -> None:
    handoff = REPO_ROOT / HANDOFF_REL
    docs = REPO_ROOT / DOCS_RECEIPT_REL
    if sha(handoff) != HANDOFF_SHA256 or sha(docs) != DOCS_RECEIPT_SHA256:
        raise RuntimeError("repaired receipt bytes mismatch")
    handoff_data = json.loads(handoff.read_text(encoding="utf-8"))
    docs_data = json.loads(docs.read_text(encoding="utf-8"))
    if docs_data.get("receiptSha256") != HANDOFF_SHA256:
        raise RuntimeError("docs receipt does not bind repaired handoff SHA")
    artifact = handoff_data.get("artifact", {})
    if artifact.get("repoCopy") is not False or handoff_data.get("failureIdentity") != IDENTITY:
        raise RuntimeError("preserved failure receipt identity/repo-copy mismatch")
    if handoff_data.get("readiness", {}).get("sourceReady") is not False:
        raise RuntimeError("preserved failure receipt advanced source readiness")


def preflight(authority_root: Path, contract_path: str, contract_sha: str, *, allow_existing: bool = False) -> dict[str, str]:
    require_worker()
    require_authority(authority_root, contract_path, contract_sha)
    require_receipts()
    if not RAW_PATH.is_file() or sha(RAW_PATH) != SOURCE_SHA256:
        raise RuntimeError("source-v01 bytes mismatch")
    with Image.open(RAW_PATH) as source:
        source.load()
        if source.mode != "RGB" or source.size != CANVAS:
            raise RuntimeError("source-v01 must be RGB 1536x1024")
    if not allow_existing and OUTPUT_BASE_ROOT.exists() and any(OUTPUT_BASE_ROOT.rglob("*")):
        raise RuntimeError("derived output root is not empty")
    if not allow_existing and EVIDENCE_ROOT.exists() and any(EVIDENCE_ROOT.rglob("*")):
        raise RuntimeError("derived evidence root is not empty")
    return baseline_snapshot()


def is_matte(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and red >= 180 and blue >= 150 and green <= 110 and red + blue >= 4 * green


def boundary_residual(pixel: tuple[int, int, int, int], neighbors: tuple[tuple[int, int, int, int], ...]) -> bool:
    red, green, blue, alpha = pixel
    return 1 <= alpha <= 254 and any(item[3] == 0 for item in neighbors) and max(red, blue) >= 64 and red + blue - 2 * green >= 64


def remove_border_matte(image: Any) -> Any:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not is_matte(pixels[x, y]):
            continue
        seen.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
            elif red > green * 1.35 and blue > green * 1.25:
                spill = min(red, blue) - green
                pixels[x, y] = (max(green, red - spill), green, max(green, blue - spill), alpha)
            if is_matte(pixels[x, y]):
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def cleanup_lod(image: Any) -> Any:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            pixel = pixels[x, y]
            neighbors = (
                pixels[x - 1, y] if x else (0, 0, 0, 0),
                pixels[x + 1, y] if x + 1 < width else (0, 0, 0, 0),
                pixels[x, y - 1] if y else (0, 0, 0, 0),
                pixels[x, y + 1] if y + 1 < height else (0, 0, 0, 0),
            )
            if boundary_residual(pixel, neighbors) or is_matte(pixel):
                red, green, blue, alpha = pixel
                limit = min(255, green + 31)
                pixels[x, y] = (min(red, limit), green, min(blue, limit), alpha)
    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def metrics(image: Any, expected: tuple[int, int]) -> dict[str, Any]:
    rgba = image.convert("RGBA")
    if rgba.size != expected:
        raise RuntimeError(f"canvas mismatch: {rgba.size} != {expected}")
    pixels = rgba.load()
    strict = boundary = hidden = frame = 0
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            pixel = pixels[x, y]
            if pixel[3] == 0 and pixel[:3] != (0, 0, 0):
                hidden += 1
            if is_matte(pixel):
                strict += 1
            neighbors = (
                pixels[x - 1, y] if x else (0, 0, 0, 0),
                pixels[x + 1, y] if x + 1 < width else (0, 0, 0, 0),
                pixels[x, y - 1] if y else (0, 0, 0, 0),
                pixels[x, y + 1] if y + 1 < height else (0, 0, 0, 0),
            )
            if boundary_residual(pixel, neighbors):
                boundary += 1
    frame = sum(pixels[x, 0][3] > 0 for x in range(width)) + sum(pixels[x, height - 1][3] > 0 for x in range(width))
    frame += sum(pixels[0, y][3] > 0 for y in range(1, height - 1)) + sum(pixels[width - 1, y][3] > 0 for y in range(1, height - 1))
    return {"canvas": list(expected), "strictKeyedMattePixels": strict, "boundaryResidualChromaPixels": boundary, "hiddenRgbPixels": hidden, "frameEdgeOpaquePixels": frame}


def decoded_sha(image: Any) -> str:
    return sha_bytes(image.convert("RGBA").tobytes())


def profile() -> dict[str, Any]:
    return {
        "sourceCanvas": list(CANVAS),
        "groundPivotSource": list(PIVOT),
        "footprintPolygonSource": [list(point) for point in FOOTPRINT],
        "frontageSocketSource": list(SOCKET),
        "coordinateRule": "CONTRACT-026 source coordinates retained; no pixel-derived crop/pivot/scale/frontage",
        "forbidden": ["occupied-bbox-crop", "pixel-derived-pivot", "pixel-derived-scale", "pixel-derived-frontage", "runtime-mirroring", "runtime-rotation", "fallback", "alias"],
    }


def output_path(destination: Path, name: str) -> Path:
    return destination / IDENTITY / f"{IDENTITY}-{name}.png"


def build_once(destination: Path) -> tuple[dict[str, Any], dict[str, str]]:
    destination.mkdir(parents=True, exist_ok=True)
    with Image.open(RAW_PATH) as source:
        source.load()
        registered = remove_border_matte(source)
    registered_path = output_path(destination, "registered")
    registered_path.parent.mkdir(parents=True, exist_ok=True)
    registered.save(registered_path, format="PNG", optimize=False, compress_level=9)
    registered_checks = metrics(registered, CANVAS)
    if any(registered_checks[key] for key in ("strictKeyedMattePixels", "boundaryResidualChromaPixels", "hiddenRgbPixels", "frameEdgeOpaquePixels")):
        raise RuntimeError(f"registered Contract-028 gate failed: {registered_checks}")
    lod_records: dict[str, Any] = {}
    files: dict[str, str] = {"registered": sha(registered_path)}
    for lod, canvas in LODS.items():
        image = cleanup_lod(registered.resize(canvas, Image.Resampling.LANCZOS))
        checks = metrics(image, canvas)
        if any(checks[key] for key in ("strictKeyedMattePixels", "boundaryResidualChromaPixels", "hiddenRgbPixels", "frameEdgeOpaquePixels")):
            raise RuntimeError(f"{lod} Contract-028 gate failed: {checks}")
        path = output_path(destination, lod)
        image.save(path, format="PNG", optimize=False, compress_level=9)
        files[lod] = sha(path)
        lod_records[lod] = {"path": f"{OUTPUT_REL}/{IDENTITY}-{lod}.png", "sha256": files[lod], "decodedSha256": decoded_sha(image), "canvas": list(canvas), "format": "RGBA", "fullCanvas": True, "filter": "lanczos", "rounding": "round-half-even", "checks": checks}
    record: dict[str, Any] = {
        "schema": "citysim.play-097.residential-contract028-record.v1",
        "task": "PLAY-097",
        "logicalId": IDENTITY,
        "direction": "south",
        "routeBinding": {"routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256, "expectedHead": EXPECTED_HEAD, "authorityCommit": AUTHORITY_COMMIT, "baseCommit": BASE_COMMIT, "claimSha256": CLAIM_SHA256},
        "contract028": CONTRACT028,
        "source": {"path": RAW_REL, "sha256": SOURCE_SHA256, "canvas": list(CANVAS), "mode": "RGB", "rawPreservedByteForByte": True},
        "repairedFailureReceipts": {"handoffPath": HANDOFF_REL, "handoffSha256": HANDOFF_SHA256, "docsMirrorPath": DOCS_RECEIPT_REL, "docsMirrorSha256": DOCS_RECEIPT_SHA256},
        "registration": profile(),
        "registered": {"path": f"{OUTPUT_REL}/{IDENTITY}-registered.png", "sha256": files["registered"], "decodedSha256": decoded_sha(registered), "canvas": list(CANVAS), "format": "RGBA", "fullCanvas": True, "checks": registered_checks},
        "lods": lod_records,
        "derivedOnly": True,
        "sourceAuthority": False,
        "rawSourceAdmission": "RETURN_HARD_BLOCKER",
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "visualAcceptance": "not_performed_worker_cannot_self_accept",
        "sourceCopy": False,
        "imageGenCalls": 0,
    }
    record["recordSha256"] = json_sha(record)
    return record, files


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--identity", required=True)
    parser.add_argument("--source-raw", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--receipt-dir", type=Path)
    parser.add_argument("--authority-root", required=True, type=Path)
    parser.add_argument("--contract-path", required=True)
    parser.add_argument("--contract-sha256", required=True)
    parser.add_argument("--repeat", type=int, default=2)
    parser.add_argument("--no-imagegen", action="store_true")
    parser.add_argument("--no-source-copy", action="store_true")
    parser.add_argument("--no-retries", action="store_true")
    parser.add_argument("--internal-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.identity != IDENTITY or args.source_raw != RAW_REL:
        raise RuntimeError("identity/source binding mismatch")
    if not (args.no_imagegen and args.no_source_copy and args.no_retries):
        raise RuntimeError("V33 is derived-only: no-imagegen/no-source-copy/no-retries are required")
    if args.repeat < 1 or args.repeat > 2:
        raise RuntimeError("repeat must be 1 or 2")
    snapshot = preflight(args.authority_root.resolve(), args.contract_path, args.contract_sha256, allow_existing=args.internal_run)
    destination = args.output_dir.resolve()
    if args.internal_run:
        record, files = build_once(destination)
        print(json.dumps({"status": "PASS", "recordSha256": record["recordSha256"], "files": files}, sort_keys=True))
        return 0
    if args.repeat != 2 or args.receipt_dir is None:
        raise RuntimeError("published V33 requires --repeat 2 and --receipt-dir")
    if destination != OUTPUT_BASE_ROOT.resolve() or args.receipt_dir.resolve() != EVIDENCE_ROOT.resolve():
        raise RuntimeError("output/evidence roots do not match V33 claim roots")
    with tempfile.TemporaryDirectory(prefix="play-097-contract028-") as temp:
        temp_root = Path(temp)
        runs = [build_once(temp_root / f"run-{index + 1}") for index in range(args.repeat)]
        canonical = [json.dumps(item[0], sort_keys=True, separators=(",", ":"), ensure_ascii=False) for item in runs]
        if canonical[0] != canonical[1] or runs[0][1] != runs[1][1]:
            raise RuntimeError("deterministic replay mismatch")
        source_tree = temp_root / "run-2"
        for path in sorted(source_tree.rglob("*")):
            if path.is_file():
                target = destination / path.relative_to(source_tree)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)
        record = runs[1][0]
        write_json(args.receipt_dir.resolve() / f"{IDENTITY}-contract028-record.json", record)
        write_json(args.receipt_dir.resolve() / "normalizer-replay-receipt.json", {"schema": "citysim.play-097.contract028-normalizer-replay.v1", "routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256, "expectedHead": EXPECTED_HEAD, "repeat": args.repeat, "replaysIdentical": True, "recordSha256": [item[0]["recordSha256"] for item in runs], "authorityRoot": str(args.authority_root.resolve()), "contract028": CONTRACT028, "imageGenCalls": 0, "sourceCopy": False})
    if baseline_snapshot() != snapshot:
        raise RuntimeError("raw/old normalized/old evidence bytes changed")
    print(json.dumps({"status": "PASS", "identity": IDENTITY, "derivedFiles": 4, "repeat": args.repeat, "replaysIdentical": True, "candidateReadyForIndependentReview": True, "sourceReady": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
