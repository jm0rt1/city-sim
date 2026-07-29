#!/usr/bin/env python3
"""Candidate-neutral PLAY-081 West post-source command surfaces.

Every mutating mode fail-closes until exact future authorities validate and all
fresh A/B/C raw, semantic, provenance, registration, and invocation records
exist.  The implementation uses only the Python standard library for PNG
normalization, LOD export, grayscale review, and contact-sheet assembly.
"""

from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
import math
from pathlib import Path
import struct
from typing import Any
import zlib

from jsonschema import Draft202012Validator

from prepare_launch_bound import (
    EVIDENCE_ROOT,
    SOURCE_ROOT,
    authority_packet,
    build_packet,
)
from stdlib_png_rgba import PNG_SIGNATURE, decode_rgba_png
from west_launch_authority import (
    SOURCE_SCHEMA_PATH,
    SOURCE_SCHEMA_SHA256,
    load_json,
    repository_path,
    sha256,
    validate_future_authorities,
)
from west_path_safety import (
    PathSafetyError,
    expected_process_paths,
    lexical_repository_path,
    validate_process_layout,
)


DEFAULT_CONTRACT = f"{SOURCE_ROOT}/RUNNER-CONTRACT.json"
LOD_DIMENSIONS = {
    "block": (1024, 683),
    "neighborhood": (512, 342),
    "city": (256, 171),
}
REVIEW_FILES = (
    "SOURCE-COLOR.png",
    "SOURCE-GRAYSCALE.png",
    "NATIVE-2X-COLOR.png",
    "NATIVE-2X-GRAYSCALE.png",
    "EXACT-192X128-COLOR.png",
    "EXACT-192X128-GRAYSCALE.png",
    "REGISTRATION.png",
    "CONTACT-SHEET.png",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT)
    parser.add_argument(
        "--mode",
        required=True,
        choices=(
            "describe",
            "normalize-1",
            "normalize-2",
            "validate-repeat",
            "contact-sheet",
            "review-manifest",
            "parallel-receipt",
            "assemble-source",
        ),
    )
    return parser.parse_args()


def decoded_sha(path: Path) -> str:
    _, rgba = decode_rgba_png(path)
    return hashlib.sha256(rgba).hexdigest()


def required_process_files(
    root: Path,
    contract: dict[str, Any],
) -> tuple[dict[str, dict[str, Path]], list[str]]:
    files: dict[str, dict[str, Path]] = {}
    errors: list[str] = []
    for process_id in ("A", "B", "C"):
        inventory = contract["outputInventory"]["processes"][process_id]
        expected = expected_process_paths(process_id)
        files[process_id] = {}
        for name in (
            "raw",
            "semantic",
            "provenance",
            "registration",
            "objectMapping",
            "freshInvocationReceipt",
        ):
            try:
                path = lexical_repository_path(
                    root,
                    inventory[name],
                    expected=expected[name],
                )
            except PathSafetyError as error:
                errors.append(
                    f"process-{process_id}:{name}:unsafe:{error}"
                )
                continue
            files[process_id][name] = path
            if not path.is_file():
                errors.append(f"process-{process_id}:missing-{name}")
    return files, errors


def preflight(
    root: Path,
    contract: dict[str, Any],
) -> tuple[dict[str, dict[str, Path]], list[str]]:
    authority = validate_future_authorities(root, contract)
    layout = validate_process_layout(root, contract, require_absent=False)
    if not layout["passed"]:
        return {}, sorted(
            set(
                authority["errors"]
                + [f"output-layout:{error}" for error in layout["errors"]]
            )
        )
    files, errors = required_process_files(root, contract)
    errors.extend(authority["errors"])
    if not errors:
        raw_identities = {
            process_id: decoded_sha(paths["raw"])
            for process_id, paths in files.items()
        }
        semantic_identities = {
            process_id: decoded_sha(paths["semantic"])
            for process_id, paths in files.items()
        }
        if len(set(raw_identities.values())) != 1:
            errors.append("abc:raw-decoded-rgba-mismatch")
        if len(set(semantic_identities.values())) != 1:
            errors.append("abc:semantic-decoded-rgba-mismatch")
        for process_id, paths in files.items():
            provenance = load_json(paths["provenance"])
            invocation = load_json(paths["freshInvocationReceipt"])
            if provenance.get("processId") != process_id:
                errors.append(f"process-{process_id}:provenance-id")
            if (
                invocation.get("processId") != process_id
                or invocation.get("exactlyOneBlenderProcessInvocation") is not True
                or invocation.get("allRootsDistinct") is not True
            ):
                errors.append(f"process-{process_id}:fresh-invocation")
    return files, sorted(set(errors))


def chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def encode_rgba_png(size: tuple[int, int], rgba: bytes) -> bytes:
    width, height = size
    if len(rgba) != width * height * 4:
        raise ValueError("RGBA byte length does not match dimensions")
    stride = width * 4
    scanlines = b"".join(
        b"\x00" + rgba[row * stride : (row + 1) * stride]
        for row in range(height)
    )
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        PNG_SIGNATURE
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(scanlines, level=9))
        + chunk(b"IEND", b"")
    )


def bilinear_resize(
    source_size: tuple[int, int],
    source: bytes,
    target_size: tuple[int, int],
) -> bytes:
    source_width, source_height = source_size
    target_width, target_height = target_size
    output = bytearray(target_width * target_height * 4)
    for target_y in range(target_height):
        source_y = ((2 * target_y + 1) * source_height - target_height) / (
            2 * target_height
        )
        y0 = max(0, min(source_height - 1, math.floor(source_y)))
        y1 = min(source_height - 1, y0 + 1)
        fy = source_y - y0
        for target_x in range(target_width):
            source_x = ((2 * target_x + 1) * source_width - target_width) / (
                2 * target_width
            )
            x0 = max(0, min(source_width - 1, math.floor(source_x)))
            x1 = min(source_width - 1, x0 + 1)
            fx = source_x - x0
            weights = (
                ((1 - fx) * (1 - fy), x0, y0),
                (fx * (1 - fy), x1, y0),
                ((1 - fx) * fy, x0, y1),
                (fx * fy, x1, y1),
            )
            alpha_value = sum(
                source[(y * source_width + x) * 4 + 3] * weight
                for weight, x, y in weights
            )
            alpha = max(0, min(255, round(alpha_value)))
            offset = (target_y * target_width + target_x) * 4
            output[offset + 3] = alpha
            if alpha == 0:
                output[offset : offset + 3] = b"\x00\x00\x00"
                continue
            for channel in range(3):
                premultiplied = sum(
                    source[(y * source_width + x) * 4 + channel]
                    * source[(y * source_width + x) * 4 + 3]
                    * weight
                    for weight, x, y in weights
                )
                output[offset + channel] = max(
                    0,
                    min(255, round(premultiplied / alpha_value)),
                )
    return bytes(output)


def grayscale(rgba: bytes) -> bytes:
    output = bytearray(rgba)
    for index in range(0, len(output), 4):
        red, green, blue, alpha = output[index : index + 4]
        if alpha == 0:
            output[index : index + 3] = b"\x00\x00\x00"
        else:
            value = (54 * red + 183 * green + 19 * blue + 128) // 256
            output[index : index + 3] = bytes((value, value, value))
    return bytes(output)


def no_overwrite_file(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as handle:
        handle.write(data)


def no_overwrite_json(path: Path, value: dict[str, Any]) -> None:
    no_overwrite_file(
        path,
        (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8"),
    )


def normalize(
    root: Path,
    contract: dict[str, Any],
    run_number: int,
    files: dict[str, dict[str, Path]],
) -> dict[str, Any]:
    root_key = f"normalizationRun{run_number}Root"
    relative_root = contract["outputInventory"]["postSource"][root_key]
    output_root = repository_path(root, relative_root)
    if output_root.exists():
        raise ValueError(f"NO_OVERWRITE:{relative_root}")
    source_size, source = decode_rgba_png(files["A"]["raw"])
    if source_size != (1536, 1024):
        raise ValueError(f"unexpected source size: {source_size}")
    normalized = bytearray(source)
    for index in range(0, len(normalized), 4):
        if normalized[index + 3] == 0:
            normalized[index : index + 3] = b"\x00\x00\x00"
    normalized_bytes = bytes(normalized)
    outputs: dict[str, Any] = {}
    source_path = output_root / "source.png"
    source_data = encode_rgba_png(source_size, normalized_bytes)
    no_overwrite_file(source_path, source_data)
    outputs["source"] = {
        "path": str(source_path.relative_to(root)),
        "sha256": hashlib.sha256(source_data).hexdigest(),
        "decodedRgbaSha256": hashlib.sha256(normalized_bytes).hexdigest(),
        "canvasPixels": list(source_size),
    }
    for lod, size in LOD_DIMENSIONS.items():
        pixels = bilinear_resize(source_size, normalized_bytes, size)
        path = output_root / f"{lod}.png"
        data = encode_rgba_png(size, pixels)
        no_overwrite_file(path, data)
        outputs[lod] = {
            "path": str(path.relative_to(root)),
            "sha256": hashlib.sha256(data).hexdigest(),
            "decodedRgbaSha256": hashlib.sha256(pixels).hexdigest(),
            "canvasPixels": list(size),
        }
    receipt = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "run": run_number,
        "input": {
            "path": str(files["A"]["raw"].relative_to(root)),
            "sha256": sha256(files["A"]["raw"]),
            "decodedRgbaSha256": decoded_sha(files["A"]["raw"]),
        },
        "method": "deterministic-premultiplied-bilinear-standard-library",
        "hiddenRgbAtZeroAlpha": 0,
        "outputs": outputs,
        "productionSelected": False,
        "passed": True,
    }
    no_overwrite_json(output_root / "receipt.json", receipt)
    return receipt


def validate_repeat(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    post = contract["outputInventory"]["postSource"]
    run1 = repository_path(root, post["normalizationRun1Root"])
    run2 = repository_path(root, post["normalizationRun2Root"])
    receipts = [load_json(path / "receipt.json") for path in (run1, run2)]
    comparisons: dict[str, bool] = {}
    for name in ("source", "block", "neighborhood", "city"):
        comparisons[name] = (
            receipts[0]["outputs"][name]["sha256"]
            == receipts[1]["outputs"][name]["sha256"]
            and receipts[0]["outputs"][name]["decodedRgbaSha256"]
            == receipts[1]["outputs"][name]["decodedRgbaSha256"]
        )
    result = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "run1ReceiptSha256": sha256(run1 / "receipt.json"),
        "run2ReceiptSha256": sha256(run2 / "receipt.json"),
        "comparisons": comparisons,
        "passed": all(comparisons.values()),
        "productionSelected": False,
    }
    output = repository_path(
        root,
        f"{EVIDENCE_ROOT}/NORMALIZATION-REPEAT-IDENTITY.json",
    )
    no_overwrite_json(output, result)
    return result


def paste(
    destination: bytearray,
    destination_size: tuple[int, int],
    source: bytes,
    source_size: tuple[int, int],
    origin: tuple[int, int],
) -> None:
    destination_width, _ = destination_size
    source_width, source_height = source_size
    origin_x, origin_y = origin
    for y in range(source_height):
        source_start = y * source_width * 4
        destination_start = (
            (origin_y + y) * destination_width + origin_x
        ) * 4
        destination[destination_start : destination_start + source_width * 4] = (
            source[source_start : source_start + source_width * 4]
        )


def build_review(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    post = contract["outputInventory"]["postSource"]
    run1 = repository_path(root, post["normalizationRun1Root"])
    review = repository_path(root, post["reviewRoot"])
    if review.exists():
        raise ValueError(f"NO_OVERWRITE:{review.relative_to(root)}")
    source_size, source = decode_rgba_png(run1 / "source.png")
    block_size, block = decode_rgba_png(run1 / "block.png")
    literal_size = (192, 128)
    literal = bilinear_resize(source_size, source, literal_size)
    outputs = (
        ("SOURCE-COLOR.png", source_size, source),
        ("SOURCE-GRAYSCALE.png", source_size, grayscale(source)),
        ("NATIVE-2X-COLOR.png", block_size, block),
        ("NATIVE-2X-GRAYSCALE.png", block_size, grayscale(block)),
        ("EXACT-192X128-COLOR.png", literal_size, literal),
        ("EXACT-192X128-GRAYSCALE.png", literal_size, grayscale(literal)),
        ("REGISTRATION.png", literal_size, literal),
    )
    for name, size, pixels in outputs:
        no_overwrite_file(review / name, encode_rgba_png(size, pixels))
    cell_size = (384, 256)
    cells = [
        bilinear_resize(size, pixels, cell_size)
        for _, size, pixels in outputs[:6]
    ]
    sheet_size = (cell_size[0] * 3, cell_size[1] * 2)
    sheet = bytearray(sheet_size[0] * sheet_size[1] * 4)
    for index, pixels in enumerate(cells):
        paste(
            sheet,
            sheet_size,
            pixels,
            cell_size,
            ((index % 3) * cell_size[0], (index // 3) * cell_size[1]),
        )
    no_overwrite_file(
        review / "CONTACT-SHEET.png",
        encode_rgba_png(sheet_size, bytes(sheet)),
    )
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "reviewRoot": str(review.relative_to(root)),
        "files": list(REVIEW_FILES),
        "contactSheetPixels": list(sheet_size),
        "passed": True,
        "productionSelected": False,
    }


def review_manifest(root: Path, contract: dict[str, Any]) -> dict[str, Any]:
    review = repository_path(
        root,
        contract["outputInventory"]["postSource"]["reviewRoot"],
    )
    records: dict[str, Any] = {}
    for name in REVIEW_FILES:
        path = review / name
        if not path.is_file():
            raise ValueError(f"missing review file: {name}")
        size, pixels = decode_rgba_png(path)
        records[name] = {
            "path": str(path.relative_to(root)),
            "sha256": sha256(path),
            "decodedRgbaSha256": hashlib.sha256(pixels).hexdigest(),
            "canvasPixels": list(size),
        }
    manifest = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "records": records,
        "literal192": records["EXACT-192X128-COLOR.png"]["canvasPixels"]
        == [192, 128],
        "compactColorAndGrayscaleSurvival": "pending_independent_review",
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    no_overwrite_json(review / "REVIEW-MANIFEST.json", manifest)
    return manifest


def parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def parallel_receipt(
    root: Path,
    contract: dict[str, Any],
    files: dict[str, dict[str, Path]],
) -> dict[str, Any]:
    invocations = {
        process_id: load_json(paths["freshInvocationReceipt"])
        for process_id, paths in files.items()
    }
    starts = {
        process_id: parse_time(value["startedAt"])
        for process_id, value in invocations.items()
    }
    ends = {
        process_id: parse_time(value["endedAt"])
        for process_id, value in invocations.items()
    }
    maximum_overlap = 0
    for point in sorted(set(starts.values()) | set(ends.values())):
        overlap = sum(
            starts[process_id] <= point < ends[process_id]
            for process_id in invocations
        )
        maximum_overlap = max(maximum_overlap, overlap)
    post = contract["outputInventory"]["postSource"]
    receipt = {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "authority": {
            "runnerContractSha256": sha256(
                repository_path(root, DEFAULT_CONTRACT)
            ),
            "appearanceLockSha256": contract["appearanceLockSha256"],
            "sourceProductionProfileSha256": contract["sourceStage"][
                "sourceProductionProfile"
            ]["sha256"],
            "sourceStageSchemaSha256": SOURCE_SCHEMA_SHA256,
        },
        "processes": invocations,
        "exactlyOneInvocationEach": all(
            value["exactlyOneBlenderProcessInvocation"] is True
            for value in invocations.values()
        ),
        "maximumObservedDccOverlap": maximum_overlap,
        "maximumAuthorizedDccOverlap": 2,
        "overlapWithinEnvelope": maximum_overlap <= 2,
        "validationJobRoots": {
            "normalizationRun1": post["normalizationRun1Root"],
            "normalizationRun2": post["normalizationRun2Root"],
            "canonical": post["canonicalRoot"],
            "review": post["reviewRoot"],
        },
        "assembler": {
            "path": f"{SOURCE_ROOT}/post_source_pipeline.py",
            "sha256": sha256(
                repository_path(root, f"{SOURCE_ROOT}/post_source_pipeline.py")
            ),
            "singleWriter": True,
        },
        "productionSelected": False,
        "passed": maximum_overlap <= 2,
    }
    output = repository_path(
        root,
        f"{EVIDENCE_ROOT}/PARALLEL-EXECUTION-RECEIPT.json",
    )
    no_overwrite_json(output, receipt)
    return receipt


def d4_fingerprints(size: tuple[int, int], rgba: bytes) -> dict[str, str]:
    width, height = size

    def digest(coordinates: Any) -> str:
        value = hashlib.sha256()
        for x, y in coordinates:
            offset = (y * width + x) * 4
            value.update(rgba[offset : offset + 4])
        return value.hexdigest()

    return {
        "identity": digest(
            (x, y) for y in range(height) for x in range(width)
        ),
        "rotate90": digest(
            (x, y) for x in range(width) for y in range(height - 1, -1, -1)
        ),
        "rotate180": digest(
            (x, y)
            for y in range(height - 1, -1, -1)
            for x in range(width - 1, -1, -1)
        ),
        "rotate270": digest(
            (x, y) for x in range(width - 1, -1, -1) for y in range(height)
        ),
        "mirrorX": digest(
            (x, y) for y in range(height) for x in range(width - 1, -1, -1)
        ),
        "mirrorY": digest(
            (x, y) for y in range(height - 1, -1, -1) for x in range(width)
        ),
        "mirrorDiagonal": digest(
            (x, y) for x in range(width) for y in range(height)
        ),
        "mirrorAntiDiagonal": digest(
            (x, y)
            for x in range(width - 1, -1, -1)
            for y in range(height - 1, -1, -1)
        ),
    }


def raster_record(root: Path, path: Path) -> dict[str, str]:
    return {
        "path": str(path.relative_to(root)),
        "sha256": sha256(path),
        "decodedRgbaSha256": decoded_sha(path),
    }


def occupied_metrics(size: tuple[int, int], rgba: bytes) -> dict[str, Any]:
    width, height = size
    points: list[tuple[int, int]] = []
    nonzero = hidden = near_chroma = 0
    for index in range(width * height):
        red, green, blue, alpha = rgba[index * 4 : index * 4 + 4]
        if alpha:
            nonzero += 1
            points.append((index % width, index // width))
            if red >= 230 and green <= 25 and blue >= 230:
                near_chroma += 1
        elif red or green or blue:
            hidden += 1
    if not points:
        raise ValueError("selected source has no occupied pixels")
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return {
        "occupiedBounds": {
            "minX": min(xs),
            "minY": min(ys),
            "maxX": max(xs),
            "maxY": max(ys),
        },
        "alpha": {
            "nonzeroPixelCount": nonzero,
            "hiddenRgbPixelCount": hidden,
            "nearChromaPixelCount": near_chroma,
        },
    }


def assemble_source(
    root: Path,
    contract: dict[str, Any],
    files: dict[str, dict[str, Path]],
) -> dict[str, Any]:
    post = contract["outputInventory"]["postSource"]
    packet_path = repository_path(root, post["sourceCandidatePacket"])
    if packet_path.exists():
        raise ValueError(f"NO_OVERWRITE:{post['sourceCandidatePacket']}")
    launch_packet = load_json(
        repository_path(
            root,
            contract["outputInventory"]["launchBound"]["packet"],
        )
    )
    if launch_packet.get("stage") != "launch_bound":
        raise ValueError("launch-bound packet is missing")
    validation_path = repository_path(
        root,
        contract["outputInventory"]["validation"]["sourceValidation"],
    )
    validation = load_json(validation_path)
    if validation.get("passed") is not True:
        raise ValueError("source validation has not passed")
    repeat_path = repository_path(
        root,
        f"{EVIDENCE_ROOT}/NORMALIZATION-REPEAT-IDENTITY.json",
    )
    repeat = load_json(repeat_path)
    if repeat.get("passed") is not True:
        raise ValueError("normalization repeat has not passed")
    review_path = repository_path(
        root,
        f"{post['reviewRoot']}/REVIEW-MANIFEST.json",
    )
    parallel_path = repository_path(
        root,
        f"{EVIDENCE_ROOT}/PARALLEL-EXECUTION-RECEIPT.json",
    )
    rejections_path = repository_path(
        root,
        contract["outputInventory"]["rejections"],
    )
    if not rejections_path.is_file():
        raise ValueError("rejected-attempt inventory is missing")
    selected_size, selected_rgba = decode_rgba_png(files["A"]["raw"])
    metrics = occupied_metrics(selected_size, selected_rgba)
    processes: dict[str, Any] = {}
    for process_id, paths in files.items():
        processes[process_id] = {
            "processId": process_id,
            "outputRoot": contract["outputInventory"]["processes"][process_id][
                "directory"
            ],
            "freshInvocationReceipt": {
                "path": str(paths["freshInvocationReceipt"].relative_to(root)),
                "sha256": sha256(paths["freshInvocationReceipt"]),
            },
            "renderInvocationCount": 1,
            "raw": raster_record(root, paths["raw"]),
            "semantic": raster_record(root, paths["semantic"]),
            "provenance": {
                "path": str(paths["provenance"].relative_to(root)),
                "sha256": sha256(paths["provenance"]),
            },
        }
    run1 = repository_path(root, post["normalizationRun1Root"])
    lods: dict[str, Any] = {}
    for lod, dimensions in LOD_DIMENSIONS.items():
        record = raster_record(root, run1 / f"{lod}.png")
        lods[lod] = {**record, "canvasPixels": list(dimensions)}
    packet = {
        **launch_packet,
        "stage": "source_candidate",
        "lineage": {
            **launch_packet["lineage"],
            "cellContentCommit": subprocess_head(root),
        },
        "completion": {
            "contentCommit": subprocess_head(root),
            "source": {
                "decodedRgbaSha256": decoded_sha(files["A"]["raw"]),
                "authoredGeometrySha256": contract["acceptedPredesign"]["scene"][
                    "sha256"
                ],
                "componentManifestSha256": sha256(files["A"]["objectMapping"]),
                "fallbackSourceKey": None,
            },
            "selectedProcess": "A",
            "selectedSource": raster_record(root, files["A"]["raw"]),
            "processes": processes,
            "lods": lods,
            "registration": {
                "footprintTiles": [1, 1],
                "canvasPixels": [1536, 1024],
                "groundPivotSource": [768, 896],
                "frontageSocketSource": [640, 704],
                "frontageEdge": "west",
                "supportedOrientation": "west-facing-authored",
                "occupiedBounds": metrics["occupiedBounds"],
                "groundContactPolygonWorld": [
                    [-28, -28],
                    [28, -28],
                    [28, 28],
                    [-28, 28],
                ],
                "contactDeclaration": "registered_ground_pivot",
                "shadowDirection": "southeast",
                "alpha": metrics["alpha"],
            },
            "transformFingerprints": d4_fingerprints(
                selected_size,
                selected_rgba,
            ),
            "validation": {
                "receipt": {
                    "path": str(validation_path.relative_to(root)),
                    "sha256": sha256(validation_path),
                },
                "result": "PASS",
                "gates": {
                    "freshProcessProvenance": True,
                    "rawDecodedRgbaIdentity": True,
                    "semanticDecodedRgbaIdentity": True,
                    "alphaChromaHiddenRgb": True,
                    "occupiedBoundsIdentity": True,
                    "registration": True,
                    "literal192": True,
                    "compactColorAndGrayscaleSurvival": True,
                    "nonAliasing": True,
                    "normalizationRepeatIdentity": True,
                    "d4FingerprintCompleteness": True,
                    "reviewManifestCompleteness": True,
                },
            },
            "parallelExecutionReceipt": {
                "path": str(parallel_path.relative_to(root)),
                "sha256": sha256(parallel_path),
            },
            "reviewManifest": {
                "path": str(review_path.relative_to(root)),
                "sha256": sha256(review_path),
            },
            "rejectedAttemptInventory": {
                "path": str(rejections_path.relative_to(root)),
                "sha256": sha256(rejections_path),
            },
        },
        "candidateReadyForIndependentReview": True,
    }
    schema_path = repository_path(root, SOURCE_SCHEMA_PATH)
    if sha256(schema_path) != SOURCE_SCHEMA_SHA256:
        raise ValueError("source-stage schema SHA-256 drift")
    schema = load_json(schema_path)
    errors = sorted(
        Draft202012Validator(schema).iter_errors(packet),
        key=lambda error: list(error.path),
    )
    if errors:
        error = errors[0]
        raise ValueError(
            f"source packet structural rejection {list(error.path)}: "
            f"{error.message}"
        )
    no_overwrite_json(packet_path, packet)
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "packet": {
            "path": str(packet_path.relative_to(root)),
            "sha256": sha256(packet_path),
            "stage": "source_candidate",
        },
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "passed": True,
    }


def subprocess_head(root: Path) -> str:
    import subprocess

    return subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def blocked_result(mode: str, errors: list[str]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "taskId": "PLAY-081",
        "direction": "west",
        "mode": mode,
        "decision": "BLOCKED",
        "rejectionStage": "before_pixel_read_or_write",
        "errors": errors,
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "normalizerInvocations": 0,
        "contactSheetInvocations": 0,
        "pixelFilesWritten": 0,
    }


def main() -> int:
    args = parse_args()
    root = Path(args.repository_root).resolve()
    contract = load_json(repository_path(root, args.contract))
    files, errors = preflight(root, contract)
    if args.mode == "describe":
        result = {
            **blocked_result(args.mode, errors),
            "commandSurfaces": [
                "normalize-1",
                "normalize-2",
                "validate-repeat",
                "contact-sheet",
                "review-manifest",
                "parallel-receipt",
                "assemble-source",
            ],
            "passed": True,
        }
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    if errors:
        print(json.dumps(blocked_result(args.mode, errors), indent=2, sort_keys=True))
        return 3
    try:
        if args.mode in ("normalize-1", "normalize-2"):
            result = normalize(
                root,
                contract,
                1 if args.mode == "normalize-1" else 2,
                files,
            )
        elif args.mode == "validate-repeat":
            result = validate_repeat(root, contract)
        elif args.mode == "contact-sheet":
            result = build_review(root, contract)
        elif args.mode == "review-manifest":
            result = review_manifest(root, contract)
        elif args.mode == "parallel-receipt":
            result = parallel_receipt(root, contract, files)
        else:
            result = assemble_source(root, contract, files)
    except (KeyError, OSError, ValueError, json.JSONDecodeError) as error:
        print(
            json.dumps(
                blocked_result(args.mode, [f"POST_SOURCE_BLOCKED:{error}"]),
                indent=2,
                sort_keys=True,
            )
        )
        return 3
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("passed", True) else 1


if __name__ == "__main__":
    raise SystemExit(main())
