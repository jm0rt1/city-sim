#!/usr/bin/env python3
"""Calibrate one PLAY-099 South source with the bundled Pillow encoder."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import shutil
import struct
import sys
import tempfile
from pathlib import Path

import PIL
from PIL import Image


ROUTE_ID = "four-view-v4:play-099-industrial-pillow-calibration-v2"
ROUTE_SHA256 = "bbf50b385d0851db8655465310c21225eaa52573520af70163f95978a3f19886"
INPUT_HEAD = "f38646855354e9825473e5fd9f558c36d6b4a280"
BUNDLED_PYTHON = Path("/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3")
BUNDLED_PYTHON_SHA256 = "eb9d74b9c7cfdfb2c9b91614edb2c3607360ba46c5aa7fc4557b3a4a23e97cff"
PYTHON_VERSION = "3.12.13"
PILLOW_VERSION = "12.2.0"
ACCEPTED_FILE_SHA256 = "aa7df1b8a8d12fcd47cbf8299c93b57f00daec9b1a74f927dafe6fe7081527bb"
ACCEPTED_DECODED_SHA256 = "e7513c32699127353f851b1d249c624c9c8e17d859c914d5c8d38ffdf8339f15"
REJECTED_EVIDENCE_SHA256 = "0d55f259085bb4524f0a67d73a5996643224a8ecff6ea0c271b12fdf57a3e5eb"
BATCH_ROUTE_ID = "four-view-v8:play-099-industrial-south-batch-v1"
BATCH_ROUTE_SHA256 = "37b940d0d8107028d50b06870fc34336be0aff2a48c6698d3e7183a54f90da5"
BATCH_AUTHORITY = "b4ff93aaa48f70dae8a3df2c50876d2c36537886"
BATCH_RAW_INVENTORY_SHA256 = "c962ca72b3122adfa36696b58d77ab3e6c30ba91d010256531fe4c4bcad2525f"
BATCH_RAW_PROVENANCE_SHA256 = "1a4fb793edf4b5efa612c73d2e394fc6c8d1e779b36da085b5eb4bd4d19b7b26"
SOURCE_CANVAS = (1536, 1024)
GROUND_PIVOT = [768, 896]
SOUTH_SOCKET = [640, 832]
FOOTPRINT = [[768, 640], [1024, 768], [768, 896], [512, 768]]
CHROMA_THRESHOLD = 160
VISIBLE_ALPHA_OCCUPANCY_FLOOR = 0.10
IDENTITIES = {
    "industrial_l01": {
        "logicalId": "industrial_l01_v00",
        "raw": "raw/industrial_l01_v00-source-v01.png",
        "rawSha256": "7ca3e26234e7e15df9a46775a83f7132f89e1ea1f22d97c42ca6d3502099bbd2",
    }
}
BATCH_IDENTITIES = {
    "industrial_l01_v00": {"raw": "raw/industrial_l01_v00-source-v01.png", "rawSha256": "7ca3e26234e7e15df9a46775a83f7132f89e1ea1f22d97c42ca6d3502099bbd2"},
    "industrial_l01_v01": {"raw": "raw/industrial_l01_v01-source-v01.png", "rawSha256": "1c5132289691f74a6cbff9b9ad38fad2d0d92ebfe6560e73e886246be5a3ae9b"},
    "industrial_l01_v02": {"raw": "raw/industrial_l01_v02-source-v01.png", "rawSha256": "3da2842a0a36ae3aa27d00703572d16e094b49be2e15f36c63e7e1afece0caa5"},
    "industrial_l02_v00": {"raw": "raw/industrial_l02_v00-source-v01.png", "rawSha256": "294817873333d7ebb9d763f5932624a8f83cd7784cdddb9ab7b5c90d8a64574a"},
    "industrial_l02_v01": {"raw": "raw/industrial_l02_v01-source-v01.png", "rawSha256": "008c6ccf5785ef9be39db539a9a5b230292542c8ff269d8eeeaa9b18685e2912"},
    "industrial_l02_v02": {"raw": "raw/industrial_l02_v02-source-v01.png", "rawSha256": "94e8031146b34e8025b6045410480fd9a51e99770a4c651e48bcd0f7d68ec55b"},
    "industrial_l03_v00": {"raw": "raw/industrial_l03_v00-source-v01.png", "rawSha256": "22260fb870a981bf18b0f39f10d84f8c1bce594577756ce715bf0f130c31cea1"},
    "industrial_l03_v01": {"raw": "raw/industrial_l03_v01-source-v01.png", "rawSha256": "1f11174b58be21d640fdb122626d5c0f06452dda4f36706f34d51363f220fa72"},
    "industrial_l03_v02": {"raw": "raw/industrial_l03_v02-source-v01.png", "rawSha256": "4cde35c09d4d3ef86880133420d3f14872f4820fd8207c4c286b17092029c830"},
    "industrial_l04_v00": {"raw": "raw/industrial_l04_v00-source-v01.png", "rawSha256": "6c631be5f372c351fbeb6a9ac9f0343569a7c2a43cbf172bdb83512aef38cef1"},
    "industrial_l04_v01": {"raw": "raw/industrial_l04_v01-source-v01.png", "rawSha256": "81dd05f26b3b5dc0234bcf9cde55a0f961a6fa0b4f0f87e7cfc1065e3bcc240b"},
    "industrial_l04_v02": {"raw": "raw/industrial_l04_v02-source-v01.png", "rawSha256": "dcfda7c8f86192cd330fcdc9075e5b2583a1db8497da64d7b5ea99bfae8c55cb"},
}
LOD_SIZES = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
BEHAVIORAL_COMMAND = [
    str(BUNDLED_PYTHON),
    "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/calibrate_pillow_reference.py",
    "--identity",
    "industrial_l01",
    "--repeat",
    "2",
    "--isolated-roots",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def decoded_sha256(image: Image.Image) -> str:
    payload = image.mode.encode("ascii") + struct.pack(">II", *image.size) + image.tobytes()
    return hashlib.sha256(payload).hexdigest()


def normalize(raw_path: Path, output_path: Path) -> dict[str, object]:
    with Image.open(raw_path) as source:
        source.load()
        if source.size != SOURCE_CANVAS:
            raise ValueError(f"source canvas mismatch: {source.size}")
        rgba = source.convert("RGBA")

    pixels = bytearray(rgba.tobytes())
    keyed_count = 0
    for index in range(0, len(pixels), 4):
        distance = abs(pixels[index] - 255) + pixels[index + 1] + abs(pixels[index + 2] - 255)
        if distance <= CHROMA_THRESHOLD:
            pixels[index:index + 4] = b"\x00\x00\x00\x00"
            keyed_count += 1
        else:
            pixels[index + 3] = 255
    normalized = Image.frombytes("RGBA", SOURCE_CANVAS, bytes(pixels))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    normalized.save(output_path, format="PNG", optimize=False, compress_level=9)

    with Image.open(output_path) as reopened:
        reopened.load()
        if reopened.mode != "RGBA" or reopened.size != SOURCE_CANVAS:
            raise ValueError(f"encoded output mismatch: mode={reopened.mode} size={reopened.size}")
        decoded = reopened.tobytes()
        visible = 0
        hidden_rgb = 0
        visible_keyed = 0
        for index in range(0, len(decoded), 4):
            red, green, blue, alpha = decoded[index:index + 4]
            if alpha:
                visible += 1
                if abs(red - 255) + green + abs(blue - 255) <= CHROMA_THRESHOLD:
                    visible_keyed += 1
            elif red or green or blue:
                hidden_rgb += 1
        width, height = reopened.size
        edge_alpha = 0
        for x in range(width):
            edge_alpha += decoded[x * 4 + 3] != 0
            edge_alpha += decoded[((height - 1) * width + x) * 4 + 3] != 0
        for y in range(1, height - 1):
            edge_alpha += decoded[(y * width) * 4 + 3] != 0
            edge_alpha += decoded[(y * width + width - 1) * 4 + 3] != 0
        occupancy = visible / (width * height)
        result = {
            "mode": reopened.mode,
            "canvas": list(reopened.size),
            "fileSha256": sha256(output_path),
            "decodedSha256": decoded_sha256(reopened),
            "visibleAlphaPixels": visible,
            "visibleAlphaOccupancy": occupancy,
            "visibleAlphaOccupancyFloor": VISIBLE_ALPHA_OCCUPANCY_FLOOR,
            "visibleAlphaOccupancyAboveFloor": occupancy > VISIBLE_ALPHA_OCCUPANCY_FLOOR,
            "removedKeyedPixels": keyed_count,
            "visibleKeyedMagentaPixels": visible_keyed,
            "hiddenRgbPixels": hidden_rgb,
            "edgeAlphaPixels": edge_alpha,
            "pngMetadata": dict(reopened.info),
        }
    if not result["visibleAlphaOccupancyAboveFloor"]:
        raise ValueError(f"visible occupancy below frozen floor: {occupancy}")
    if result["visibleKeyedMagentaPixels"] or result["hiddenRgbPixels"] or result["edgeAlphaPixels"]:
        raise ValueError(f"alpha/chroma gate failed: {result}")
    return result


def inspect_png(path: Path, expected_size: tuple[int, int], require_floor: bool) -> dict[str, object]:
    with Image.open(path) as image:
        image.load()
        if image.mode != "RGBA" or image.size != expected_size:
            raise ValueError(f"PNG mismatch at {path}: mode={image.mode} size={image.size}")
        decoded = image.tobytes()
        visible = 0
        hidden_rgb = 0
        visible_keyed = 0
        for index in range(0, len(decoded), 4):
            red, green, blue, alpha = decoded[index:index + 4]
            if alpha:
                visible += 1
                if abs(red - 255) + green + abs(blue - 255) <= CHROMA_THRESHOLD:
                    visible_keyed += 1
            elif red or green or blue:
                hidden_rgb += 1
        width, height = image.size
        edge_alpha = 0
        for x in range(width):
            edge_alpha += decoded[x * 4 + 3] != 0
            edge_alpha += decoded[((height - 1) * width + x) * 4 + 3] != 0
        for y in range(1, height - 1):
            edge_alpha += decoded[(y * width) * 4 + 3] != 0
            edge_alpha += decoded[(y * width + width - 1) * 4 + 3] != 0
        occupancy = visible / (width * height)
        result = {
            "mode": image.mode,
            "canvas": list(image.size),
            "fileSha256": sha256(path),
            "decodedSha256": decoded_sha256(image),
            "visibleAlphaPixels": visible,
            "visibleAlphaOccupancy": occupancy,
            "visibleAlphaOccupancyFloor": VISIBLE_ALPHA_OCCUPANCY_FLOOR,
            "visibleAlphaOccupancyAboveFloor": occupancy > VISIBLE_ALPHA_OCCUPANCY_FLOOR,
            "visibleKeyedMagentaPixels": visible_keyed,
            "hiddenRgbPixels": hidden_rgb,
            "edgeAlphaPixels": edge_alpha,
            "pngMetadata": dict(image.info),
        }
    if require_floor and not result["visibleAlphaOccupancyAboveFloor"]:
        raise ValueError(f"visible occupancy below frozen floor: {path}")
    if result["visibleKeyedMagentaPixels"] or result["hiddenRgbPixels"] or result["edgeAlphaPixels"]:
        raise ValueError(f"alpha/chroma gate failed: {path}: {result}")
    return result


def encode_batch_identity(raw_path: Path, temporary_root: Path, logical_id: str) -> dict[str, object]:
    identity_root = temporary_root / logical_id
    source_path = identity_root / "source-rgba.png"
    source_result = normalize(raw_path, source_path)
    lod_results: dict[str, dict[str, object]] = {}
    with Image.open(source_path) as source:
        source.load()
        for name, size in LOD_SIZES.items():
            lod_path = identity_root / f"{name}.png"
            lod = source.resize(size, resample=Image.Resampling.LANCZOS)
            pixels = bytearray(lod.tobytes())
            for index in range(0, len(pixels), 4):
                distance = abs(pixels[index] - 255) + pixels[index + 1] + abs(pixels[index + 2] - 255)
                if pixels[index + 3] == 0 or distance <= CHROMA_THRESHOLD:
                    pixels[index:index + 3] = b"\x00\x00\x00"
                    if distance <= CHROMA_THRESHOLD:
                        pixels[index + 3] = 0
            Image.frombytes("RGBA", size, bytes(pixels)).save(
                lod_path, format="PNG", optimize=False, compress_level=9
            )
            lod_results[name] = inspect_png(lod_path, size, require_floor=False)
    return {"source": source_result, "lods": lod_results}


def round_half_even(numerator: int, denominator: int) -> int:
    quotient, remainder = divmod(numerator, denominator)
    if remainder * 2 < denominator:
        return quotient
    if remainder * 2 > denominator:
        return quotient + 1
    return quotient if quotient % 2 == 0 else quotient + 1


def mapped(point: list[int], size: tuple[int, int]) -> list[int]:
    return [
        round_half_even(point[0] * size[0], SOURCE_CANVAS[0]),
        round_half_even(point[1] * size[1], SOURCE_CANVAS[1]),
    ]


def verify_preserved_inputs(root: Path, repo_root: Path) -> None:
    inventory = root / "inventory/PLAY-099-industrial-raw-inventory.json"
    provenance = root / "provenance/PLAY-099-industrial-raw-provenance.json"
    if sha256(inventory) != BATCH_RAW_INVENTORY_SHA256 or sha256(provenance) != BATCH_RAW_PROVENANCE_SHA256:
        raise SystemExit("FAIL: raw inventory/provenance authority hash mismatch")
    provenance_data = json.loads(provenance.read_text())
    candidates = {item["logicalId"]: item["rawSha256"] for item in provenance_data["candidates"]}
    if candidates != {key: value["rawSha256"] for key, value in BATCH_IDENTITIES.items()}:
        raise SystemExit("FAIL: raw provenance identity/hash mismatch")
    accepted = root / "calibration/pillow-reference-v1/industrial_l01/source-rgba.png"
    if sha256(accepted) != ACCEPTED_FILE_SHA256:
        raise SystemExit("FAIL: accepted one-identity PNG changed")
    with Image.open(accepted) as image:
        image.load()
        if decoded_sha256(image) != ACCEPTED_DECODED_SHA256:
            raise SystemExit("FAIL: accepted one-identity decoded payload changed")
    rejected = repo_root / "docs/production/evidence/PLAY-099/coreimage-lanczos-rejected-attempt-v1.json"
    if sha256(rejected) != REJECTED_EVIDENCE_SHA256:
        raise SystemExit("FAIL: rejected CoreImage evidence changed")


def run_batch(root: Path, repo_root: Path, repeat: int) -> int:
    if repeat != 2:
        raise SystemExit("FAIL: batch route requires --repeat 2")
    verify_preserved_inputs(root, repo_root)
    batch_command = [
        str(BUNDLED_PYTHON),
        "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/calibrate_pillow_reference.py",
        "--all-identities",
        "--repeat",
        "2",
        "--isolated-roots",
    ]
    batch_root = root / "calibration/pillow-reference-batch-v1"
    receipts: list[dict[str, object]] = []
    canonical_source_hashes: list[str] = []
    canonical_lod_hashes: list[str] = []
    for logical_id, binding in BATCH_IDENTITIES.items():
        raw_path = root / str(binding["raw"])
        if sha256(raw_path) != binding["rawSha256"]:
            raise SystemExit(f"FAIL: raw hash mismatch for {logical_id}")
        runs: list[dict[str, object]] = []
        with tempfile.TemporaryDirectory(prefix=f"play099-{logical_id}-batch-run-1-") as first_root:
            first = encode_batch_identity(raw_path, Path(first_root), logical_id)
            with tempfile.TemporaryDirectory(prefix=f"play099-{logical_id}-batch-run-2-") as second_root:
                second = encode_batch_identity(raw_path, Path(second_root), logical_id)
                for kind in ["source", *LOD_SIZES]:
                    first_result = first[kind] if kind == "source" else first["lods"][kind]
                    second_result = second[kind] if kind == "source" else second["lods"][kind]
                    if first_result["fileSha256"] != second_result["fileSha256"] or first_result["decodedSha256"] != second_result["decodedSha256"]:
                        raise SystemExit(f"FAIL: isolated replay mismatch for {logical_id}/{kind}")
                runs = [first, second]
                canonical_root = batch_root / logical_id
                canonical_root.mkdir(parents=True, exist_ok=True)
                for name in ["source-rgba", *LOD_SIZES]:
                    source_file = Path(first_root) / logical_id / f"{name}.png"
                    destination = canonical_root / f"{name}.png"
                    if destination.exists() and destination.read_bytes() != source_file.read_bytes():
                        raise SystemExit(f"FAIL: existing batch output changed for {logical_id}/{name}")
                    if not destination.exists():
                        shutil.copyfile(source_file, destination)
        source_result = runs[0]["source"]
        lod_receipts = []
        canonical_source_hashes.append(source_result["fileSha256"])
        for name, size in LOD_SIZES.items():
            lod_result = runs[0]["lods"][name]
            canonical_lod_hashes.append(lod_result["fileSha256"])
            lod_receipts.append({
                "name": name,
                "canvas": list(size),
                "filter": "Pillow.Image.Resampling.LANCZOS",
                "rounding": "round-half-even source-coordinate receipts",
                "path": f"Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/calibration/pillow-reference-batch-v1/{logical_id}/{name}.png",
                "sha256": lod_result["fileSha256"],
                "decodedSha256": lod_result["decodedSha256"],
                "pivot": mapped(GROUND_PIVOT, size),
                "socket": mapped(SOUTH_SOCKET, size),
            })
        receipts.append({
            "schema": "PLAY-099-industrial-south-batch-receipt-v1",
            "task": "PLAY-099",
            "routeId": BATCH_ROUTE_ID,
            "routeCanonicalSha256": BATCH_ROUTE_SHA256,
            "authorityCommit": BATCH_AUTHORITY,
            "inputHead": INPUT_HEAD,
            "logicalId": logical_id,
            "direction": "south",
            "rawPath": str(binding["raw"]),
            "rawSha256": binding["rawSha256"],
            "rawBytesPreserved": True,
            "source": {"path": f"Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/calibration/pillow-reference-batch-v1/{logical_id}/source-rgba.png", **source_result},
            "lods": lod_receipts,
            "registration": {"sourceCanvas": list(SOURCE_CANVAS), "groundPivotSource": GROUND_PIVOT, "frontageSocketSource": SOUTH_SOCKET, "footprintPolygonSource": FOOTPRINT, "pixelDerivedGeometry": False},
            "runtime": {"command": batch_command, "pythonVersion": PYTHON_VERSION, "pythonExecutableSha256": BUNDLED_PYTHON_SHA256, "pillowVersion": PILLOW_VERSION},
            "runs": [{"run": index + 1, "isolatedRoot": True, "source": run["source"], "lods": run["lods"]} for index, run in enumerate(runs)],
            "candidateReadyForIndependentReview": True,
            "sourceReady": False,
            "integrationAdmitted": False,
            "rendererQuarantined": False,
            "productionSelected": False,
            "visualAcceptance": "not performed; frontier-owned",
        })
    if len(set(canonical_source_hashes)) != 12 or len(set(canonical_lod_hashes)) != 36:
        raise SystemExit("FAIL: batch normalized or LOD aliases")
    runtime = {"command": batch_command, "pythonVersion": PYTHON_VERSION, "pythonExecutableSha256": BUNDLED_PYTHON_SHA256, "pillowVersion": PILLOW_VERSION}
    provenance = {
        "schema": "PLAY-099-industrial-south-batch-provenance-v1",
        "task": "PLAY-099",
        "routeId": BATCH_ROUTE_ID,
        "routeCanonicalSha256": BATCH_ROUTE_SHA256,
        "authorityCommit": BATCH_AUTHORITY,
        "inputHead": INPUT_HEAD,
        "runtime": runtime,
        "rawInventorySha256": BATCH_RAW_INVENTORY_SHA256,
        "rawProvenanceSha256": BATCH_RAW_PROVENANCE_SHA256,
        "identityCount": 12,
        "direction": "south",
        "imageGenCalled": False,
        "candidateOnly": True,
        "productionSelected": False,
        "acceptedOneIdentityPngPreserved": True,
        "rejectedCoreImageEvidencePreserved": True,
    }
    evidence = {
        "schema": "PLAY-099-industrial-south-batch-evidence-v1",
        "task": "PLAY-099",
        "routeId": BATCH_ROUTE_ID,
        "routeCanonicalSha256": BATCH_ROUTE_SHA256,
        "identityCount": 12,
        "sourceCount": 12,
        "lodCount": 36,
        "uniqueSourceFileHashes": len(set(canonical_source_hashes)),
        "uniqueLodFileHashes": len(set(canonical_lod_hashes)),
        "deterministicRunsPerIdentity": 2,
        "runtime": runtime,
        "registration": {"sourceCanvas": list(SOURCE_CANVAS), "groundPivotSource": GROUND_PIVOT, "frontageSocketSource": SOUTH_SOCKET, "footprintPolygonSource": FOOTPRINT},
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "productionSelected": False,
        "visualAcceptance": "not performed; frontier-owned",
        "unrun": ["frontier visual acceptance", "Integration semantic admission", "aggregate/full gates", "runtime mapping"],
    }
    write_stable_json(batch_root / "batch-provenance-v1.json", provenance)
    write_stable_json(batch_root / "all-south-batch-receipts-v1.json", receipts)
    write_stable_json(repo_root / "docs/production/evidence/PLAY-099/south-batch-evidence-v1.json", evidence)
    print(json.dumps({"status": "PASS", "identityCount": 12, "sourceCount": 12, "lodCount": 36, "uniqueSources": 12, "uniqueLods": 36, "python": PYTHON_VERSION, "Pillow": PILLOW_VERSION}, sort_keys=True))
    return 0


def write_stable_json(path: Path, value: object) -> None:
    data = json.dumps(value, indent=2, sort_keys=True, separators=(",", ": ")) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == data:
        return
    path.write_text(data)


def main() -> int:
    parser = argparse.ArgumentParser()
    identities = parser.add_mutually_exclusive_group(required=True)
    identities.add_argument("--identity", choices=sorted(IDENTITIES))
    identities.add_argument("--all-identities", action="store_true")
    parser.add_argument("--repeat", required=True, type=int)
    parser.add_argument("--isolated-roots", required=True, action="store_true")
    args = parser.parse_args()
    if args.repeat != 2:
        raise SystemExit("FAIL: calibration route requires --repeat 2")

    invoked = Path(sys.executable)
    if invoked != BUNDLED_PYTHON or platform.python_version() != PYTHON_VERSION:
        raise SystemExit(f"FAIL: bundled Python mismatch: executable={invoked} version={platform.python_version()}")
    if sha256(invoked) != BUNDLED_PYTHON_SHA256 or PIL.__version__ != PILLOW_VERSION:
        raise SystemExit(f"FAIL: runtime hash/version mismatch: pythonSha256={sha256(invoked)} Pillow={PIL.__version__}")

    root = Path(__file__).resolve().parent
    repo_root = root.parents[5]
    if args.all_identities:
        return run_batch(root, repo_root, args.repeat)
    binding = IDENTITIES[args.identity]
    raw_path = root / str(binding["raw"])
    if sha256(raw_path) != binding["rawSha256"]:
        raise SystemExit("FAIL: raw source hash mismatch")
    canonical = root / "calibration/pillow-reference-v1" / args.identity / "source-rgba.png"
    if not canonical.exists() or sha256(canonical) != ACCEPTED_FILE_SHA256:
        raise SystemExit("FAIL: accepted calibration payload missing or changed")
    with Image.open(canonical) as accepted:
        accepted.load()
        if accepted.mode != "RGBA" or accepted.size != SOURCE_CANVAS or decoded_sha256(accepted) != ACCEPTED_DECODED_SHA256:
            raise SystemExit("FAIL: accepted calibration decoded payload changed")
    rejected_evidence = repo_root / "docs/production/evidence/PLAY-099/coreimage-lanczos-rejected-attempt-v1.json"
    if sha256(rejected_evidence) != REJECTED_EVIDENCE_SHA256:
        raise SystemExit("FAIL: rejected CoreImage evidence changed")

    runs: list[dict[str, object]] = []
    for run_number in range(1, args.repeat + 1):
        with tempfile.TemporaryDirectory(prefix=f"play099-{args.identity}-run-{run_number}-") as temporary:
            output = Path(temporary) / args.identity / "source-rgba.png"
            result = normalize(raw_path, output)
            if result["fileSha256"] != ACCEPTED_FILE_SHA256 or result["decodedSha256"] != ACCEPTED_DECODED_SHA256:
                raise SystemExit("FAIL: exact-runtime replay changed the accepted output")
            result["run"] = run_number
            result["isolatedRoot"] = True
            runs.append(result)

    if len({run["fileSha256"] for run in runs}) != 1 or len({run["decodedSha256"] for run in runs}) != 1:
        raise SystemExit("FAIL: isolated-root byte or decoded replay mismatch")

    runtime = {
        "behavioralCommand": BEHAVIORAL_COMMAND,
        "invokedExecutable": str(invoked),
        "resolvedExecutable": str(invoked.resolve()),
        "executableSha256": sha256(invoked),
        "pythonVersion": platform.python_version(),
        "pillowVersion": PIL.__version__,
    }
    receipt = {
        "schema": "PLAY-099-industrial-pillow-calibration-v2",
        "task": "PLAY-099",
        "inputHead": INPUT_HEAD,
        "routeId": ROUTE_ID,
        "routeCanonicalSha256": ROUTE_SHA256,
        "calibrationIdentity": args.identity,
        "sourceLogicalId": binding["logicalId"],
        "direction": "south",
        "raw": {"path": binding["raw"], "sha256": binding["rawSha256"], "bytesPreserved": True},
        "runtime": runtime,
        "encoder": {
            "script": "calibrate_pillow_reference.py",
            "scriptSha256": sha256(Path(__file__)),
            "format": "PNG RGBA",
            "compressLevel": 9,
            "optimize": False,
            "chromaDistanceThreshold": CHROMA_THRESHOLD,
        },
        "registration": {
            "sourceCanvas": list(SOURCE_CANVAS),
            "groundPivotSource": GROUND_PIVOT,
            "frontageSocketSource": SOUTH_SOCKET,
            "footprintPolygonSource": FOOTPRINT,
            "pixelDerivedGeometry": False,
        },
        "runs": runs,
        "replay": {
            "repeat": 2,
            "isolatedRoots": True,
            "byteIdentical": True,
            "decodedIdentical": True,
            "fileSha256": runs[0]["fileSha256"],
            "decodedSha256": runs[0]["decodedSha256"],
        },
        "preservation": {
            "acceptedPngSha256": ACCEPTED_FILE_SHA256,
            "acceptedDecodedSha256": ACCEPTED_DECODED_SHA256,
            "acceptedPayloadOverwritten": False,
            "rejectedEvidencePath": "docs/production/evidence/PLAY-099/coreimage-lanczos-rejected-attempt-v1.json",
            "rejectedEvidenceSha256": REJECTED_EVIDENCE_SHA256,
        },
        "disposition": {
            "calibrationPassed": True,
            "sourceReady": False,
            "integrationAdmitted": False,
            "productionSelected": False,
            "visualAcceptancePerformed": False,
            "remainingIdentitiesProcessed": 0,
        },
    }
    calibration_root = root / "calibration/pillow-reference-v1" / args.identity
    for run in runs:
        run_receipt = {
            "schema": "PLAY-099-industrial-pillow-calibration-run-v2",
            "routeId": ROUTE_ID,
            "routeCanonicalSha256": ROUTE_SHA256,
            "calibrationIdentity": args.identity,
            "sourceLogicalId": binding["logicalId"],
            "runtime": runtime,
            "result": run,
        }
        write_stable_json(calibration_root / f"run-{run['run']}-receipt.json", run_receipt)
    provenance = {
        "schema": "PLAY-099-industrial-pillow-runtime-provenance-v2",
        "task": "PLAY-099",
        "routeId": ROUTE_ID,
        "routeCanonicalSha256": ROUTE_SHA256,
        "inputHead": INPUT_HEAD,
        "calibrationIdentity": args.identity,
        "sourceLogicalId": binding["logicalId"],
        "runtime": runtime,
        "rawSha256": binding["rawSha256"],
        "acceptedFileSha256": ACCEPTED_FILE_SHA256,
        "acceptedDecodedSha256": ACCEPTED_DECODED_SHA256,
        "repeat": 2,
        "isolatedRoots": True,
        "imageGenCalled": False,
        "batchExpanded": False,
    }
    write_stable_json(calibration_root / "runtime-provenance-v2.json", provenance)
    write_stable_json(repo_root / "docs/production/evidence/PLAY-099/pillow-reference-calibration-v1.json", receipt)
    print(json.dumps({
        "status": "PASS",
        "identity": args.identity,
        "fileSha256": runs[0]["fileSha256"],
        "decodedSha256": runs[0]["decodedSha256"],
        "visibleAlphaOccupancy": runs[0]["visibleAlphaOccupancy"],
        "python": platform.python_version(),
        "Pillow": PIL.__version__,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
