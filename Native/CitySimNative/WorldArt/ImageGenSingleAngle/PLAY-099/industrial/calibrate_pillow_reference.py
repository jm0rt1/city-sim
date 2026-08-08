#!/usr/bin/env python3
"""Calibrate one PLAY-099 South source with the bundled Pillow encoder."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
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


def write_stable_json(path: Path, value: object) -> None:
    data = json.dumps(value, indent=2, sort_keys=True, separators=(",", ": ")) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == data:
        return
    path.write_text(data)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--identity", required=True, choices=sorted(IDENTITIES))
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
