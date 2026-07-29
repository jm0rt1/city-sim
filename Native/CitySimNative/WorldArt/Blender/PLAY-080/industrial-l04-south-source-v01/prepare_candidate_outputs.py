#!/usr/bin/env python3
"""Candidate-neutral South postprocess surfaces with strict A/B/C joins."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path
from typing import Any

import run_production
from validate_source_outputs import decode_rgba_png, sha256_bytes


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
DEFAULT_CONTRACT = SOURCE_DIR / "runner-contract.json"
LOD_DIMENSIONS = {
    "city": (256, 171),
    "neighborhood": (512, 342),
    "block": (1024, 683),
}


class CandidatePreparationRejected(RuntimeError):
    def __init__(self, code: str, detail: Any):
        super().__init__(code)
        self.code = code
        self.detail = detail


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise CandidatePreparationRejected("INVALID_JSON_OBJECT", str(path))
    return value


def repo_path(value: str) -> Path:
    path = (REPOSITORY_ROOT / value).resolve()
    try:
        path.relative_to(REPOSITORY_ROOT)
    except ValueError as error:
        raise CandidatePreparationRejected("PATH_OUTSIDE_REPOSITORY", value) from error
    return path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def artifact(path: Path) -> dict[str, str]:
    return {
        "path": path.relative_to(REPOSITORY_ROOT).as_posix(),
        "sha256": sha256(path),
    }


def json_bytes(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def write_once(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open("xb") as handle:
            handle.write(content)
    except FileExistsError as error:
        raise CandidatePreparationRejected(
            "IMMUTABLE_CANDIDATE_OUTPUT_EXISTS",
            path.relative_to(REPOSITORY_ROOT).as_posix(),
        ) from error


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def encode_png(width: int, height: int, rgba: bytes) -> bytes:
    if len(rgba) != width * height * 4:
        raise CandidatePreparationRejected("INVALID_RGBA_LENGTH", len(rgba))
    stride = width * 4
    scanlines = b"".join(
        b"\x00" + rgba[row * stride : (row + 1) * stride]
        for row in range(height)
    )
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanlines, level=9))
        + png_chunk(b"IEND", b"")
    )


def resize_nearest(
    width: int, height: int, rgba: bytes, target_width: int, target_height: int
) -> bytes:
    result = bytearray(target_width * target_height * 4)
    for y in range(target_height):
        source_y = min(height - 1, (y * height + target_height // 2) // target_height)
        for x in range(target_width):
            source_x = min(width - 1, (x * width + target_width // 2) // target_width)
            source = (source_y * width + source_x) * 4
            target = (y * target_width + x) * 4
            result[target : target + 4] = rgba[source : source + 4]
    return bytes(result)


def require_exact_abc_products(contract: dict[str, Any]) -> dict[str, Any]:
    inventory = contract["outputInventory"]
    plan = contract["launchPlan"]
    missing: list[str] = []
    processes: dict[str, Any] = {}
    raw_hashes: set[str] = set()
    semantic_hashes: set[str] = set()
    invocation_ids: set[str] = set()
    for process in ("A", "B", "C"):
        paths = {
            "raw": repo_path(inventory["raw"][process]),
            "semantic": repo_path(inventory["semantic"][process]),
            "provenance": repo_path(inventory["provenance"][process]),
            "runnerReport": repo_path(inventory["runnerReport"][process]),
        }
        process_missing = [
            path.relative_to(REPOSITORY_ROOT).as_posix()
            for path in paths.values()
            if not path.is_file()
        ]
        missing.extend(process_missing)
        if process_missing:
            continue
        report = load_json(paths["runnerReport"])
        provenance = load_json(paths["provenance"])
        invocation = report.get("freshInvocation", {})
        expected = {
            "mode": process,
            "result": "RENDERED_PENDING_VALIDATION",
            "rawPath": inventory["raw"][process],
            "semanticPath": inventory["semantic"][process],
            "provenancePath": inventory["provenance"][process],
            "renderInvocations": 2,
            "pixelFiles": 2,
        }
        if any(report.get(key) != value for key, value in expected.items()):
            raise CandidatePreparationRejected(
                "PROCESS_REPORT_MISMATCH", {"process": process, "report": report}
            )
        if (
            invocation.get("processId") != process
            or invocation.get("exactlyOneFreshBlenderProcess") is not True
            or invocation.get("outputRoot")
            != plan["isolatedOutputRoots"][process]
            or invocation.get("evidenceRoot")
            != plan["isolatedEvidenceRoots"][process]
        ):
            raise CandidatePreparationRejected(
                "FRESH_INVOCATION_MISMATCH", {"process": process, "value": invocation}
            )
        invocation_id = f"{invocation.get('pid')}:{invocation.get('startedAtUtc')}"
        invocation_ids.add(invocation_id)
        raw = decode_rgba_png(paths["raw"])
        semantic = decode_rgba_png(paths["semantic"])
        raw_hash = sha256_bytes(raw[2])
        semantic_hash = sha256_bytes(semantic[2])
        if provenance.get("decodedRgbaSha256") != raw_hash or provenance.get(
            "semanticDecodedRgbaSha256"
        ) != semantic_hash:
            raise CandidatePreparationRejected(
                "PROVENANCE_PIXEL_HASH_MISMATCH", process
            )
        raw_hashes.add(raw_hash)
        semantic_hashes.add(semantic_hash)
        processes[process] = {
            "paths": paths,
            "report": report,
            "provenance": provenance,
            "rawDecodedRgbaSha256": raw_hash,
            "semanticDecodedRgbaSha256": semantic_hash,
        }
    if missing:
        raise CandidatePreparationRejected(
            "MISSING_ABC_PRODUCTS", sorted(set(missing))
        )
    if len(invocation_ids) != 3:
        raise CandidatePreparationRejected("FRESH_PROCESS_IDENTITY_FAILURE", sorted(invocation_ids))
    if len(raw_hashes) != 1 or len(semantic_hashes) != 1:
        raise CandidatePreparationRejected(
            "ABC_IDENTITY_FAILURE",
            {"raw": sorted(raw_hashes), "semantic": sorted(semantic_hashes)},
        )
    return processes


def normalization_paths(contract: dict[str, Any]) -> tuple[Path, Path]:
    root = repo_path(contract["candidatePlan"]["normalizedRoot"])
    receipt = repo_path(
        contract["candidatePlan"]["validationRoot"] + "normalization-repeat.json"
    )
    return root / "source.png", receipt


def command_normalize(contract: dict[str, Any], processes: dict[str, Any]) -> dict[str, Any]:
    output, receipt_path = normalization_paths(contract)
    selected = contract["candidatePlan"]["selectedProcess"]
    width, height, rgba = decode_rgba_png(processes[selected]["paths"]["raw"])
    first = encode_png(width, height, rgba)
    second = encode_png(width, height, rgba)
    if first != second:
        raise CandidatePreparationRejected("NORMALIZATION_REPEAT_MISMATCH", selected)
    write_once(output, first)
    receipt = {
        "schema": "citysim.play-080.normalization-repeat.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "selectedProcess": selected,
        "algorithm": "canonical-rgba-filter0-zlib9-v1",
        "firstSha256": sha256_bytes(first),
        "secondSha256": sha256_bytes(second),
        "repeatIdentity": True,
        "output": artifact(output),
        "result": "PASS",
    }
    write_once(receipt_path, json_bytes(receipt))
    return receipt


def command_lods(contract: dict[str, Any], processes: dict[str, Any]) -> dict[str, Any]:
    del processes
    normalized, normalization_receipt = normalization_paths(contract)
    if not normalized.is_file() or not normalization_receipt.is_file():
        raise CandidatePreparationRejected(
            "MISSING_NORMALIZATION_REPEAT",
            [str(normalized), str(normalization_receipt)],
        )
    width, height, rgba = decode_rgba_png(normalized)
    lod_root = repo_path(contract["candidatePlan"]["lodRoot"])
    lods: dict[str, Any] = {}
    pending: list[tuple[Path, bytes]] = []
    for name, dimensions in LOD_DIMENSIONS.items():
        resized = resize_nearest(width, height, rgba, *dimensions)
        content = encode_png(*dimensions, resized)
        path = lod_root / f"{name}.png"
        if path.exists():
            raise CandidatePreparationRejected("IMMUTABLE_CANDIDATE_OUTPUT_EXISTS", str(path))
        pending.append((path, content))
        lods[name] = {
            "path": path.relative_to(REPOSITORY_ROOT).as_posix(),
            "sha256": sha256_bytes(content),
            "decodedRgbaSha256": sha256_bytes(resized),
            "canvasPixels": list(dimensions),
        }
    receipt_path = repo_path(contract["candidatePlan"]["validationRoot"] + "lods.json")
    for path, content in pending:
        write_once(path, content)
    receipt = {
        "schema": "citysim.play-080.lods.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "algorithm": "nearest-center-v1",
        "lods": lods,
        "result": "PASS",
    }
    write_once(receipt_path, json_bytes(receipt))
    return receipt


def command_contact_sheet(
    contract: dict[str, Any], processes: dict[str, Any]
) -> dict[str, Any]:
    lod_root = repo_path(contract["candidatePlan"]["lodRoot"])
    inputs = [processes[name]["paths"]["raw"] for name in ("A", "B", "C")]
    inputs.extend(lod_root / f"{name}.png" for name in ("block", "neighborhood", "city"))
    missing = [str(path) for path in inputs if not path.is_file()]
    if missing:
        raise CandidatePreparationRejected("MISSING_CONTACT_SHEET_INPUTS", missing)
    canvas_width, canvas_height = 1024, 640
    canvas = bytearray(b"\x20\x20\x20\xff" * (canvas_width * canvas_height))
    panel_width, panel_height = 320, 213
    positions = [(8, 8), (352, 8), (696, 8), (8, 320), (352, 320), (696, 320)]
    for path, (origin_x, origin_y) in zip(inputs, positions):
        width, height, rgba = decode_rgba_png(path)
        panel = resize_nearest(width, height, rgba, panel_width, panel_height)
        for y in range(panel_height):
            for x in range(panel_width):
                source = (y * panel_width + x) * 4
                target = ((origin_y + y) * canvas_width + origin_x + x) * 4
                canvas[target : target + 4] = panel[source : source + 4]
    output = repo_path(contract["candidatePlan"]["contactSheet"])
    write_once(output, encode_png(canvas_width, canvas_height, bytes(canvas)))
    receipt_path = repo_path(
        contract["candidatePlan"]["validationRoot"] + "contact-sheet.json"
    )
    receipt = {
        "schema": "citysim.play-080.contact-sheet.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "panels": [
            "process-A",
            "process-B",
            "process-C",
            "block",
            "neighborhood",
            "city",
        ],
        "output": artifact(output),
        "result": "PASS",
    }
    write_once(receipt_path, json_bytes(receipt))
    return receipt


def require_artifacts(paths: list[Path]) -> None:
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise CandidatePreparationRejected("MISSING_CANDIDATE_ARTIFACTS", missing)


def command_parallel_receipt(
    contract: dict[str, Any], processes: dict[str, Any]
) -> dict[str, Any]:
    invocations = {
        process: value["report"]["freshInvocation"]
        for process, value in processes.items()
    }
    receipt = {
        "schema": "citysim.play-080.parallel-execution.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "frozenRunnerContractSha256": sha256(
            SOURCE_DIR / "runner-contract.json"
        ),
        "authorizedProcesses": ["A", "B", "C"],
        "maximumConcurrentDccProcesses": contract["launchPlan"][
            "maximumConcurrentDccProcesses"
        ],
        "isolatedOutputRoots": contract["launchPlan"]["isolatedOutputRoots"],
        "isolatedEvidenceRoots": contract["launchPlan"]["isolatedEvidenceRoots"],
        "invocations": invocations,
        "exactlyOneInvocationPerProcess": True,
        "actualOverlap": "derived_from_invocation_intervals",
        "assemblerIdentity": "prepare_candidate_outputs.py",
        "result": "PASS",
    }
    output = repo_path(contract["candidatePlan"]["parallelExecutionReceipt"])
    write_once(output, json_bytes(receipt))
    return receipt


def command_review_manifest(
    contract: dict[str, Any], processes: dict[str, Any]
) -> dict[str, Any]:
    del processes
    normalized, normalization_receipt = normalization_paths(contract)
    required = [
        normalized,
        normalization_receipt,
        repo_path(contract["candidatePlan"]["validationRoot"] + "lods.json"),
        repo_path(contract["candidatePlan"]["validationRoot"] + "contact-sheet.json"),
        repo_path(contract["candidatePlan"]["contactSheet"]),
        repo_path(contract["candidatePlan"]["parallelExecutionReceipt"]),
        repo_path(contract["candidatePlan"]["validationRoot"] + "source-output-validation.json"),
    ]
    require_artifacts(required)
    manifest = {
        "schema": "citysim.play-080.source-review-manifest.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "candidateNeutral": True,
        "artifacts": [artifact(path) for path in required],
        "candidateReadyForIndependentReview": False,
        "sourceReady": False,
        "productionSelected": False,
        "result": "PASS",
    }
    output = repo_path(contract["candidatePlan"]["reviewManifest"])
    write_once(output, json_bytes(manifest))
    return manifest


def command_assemble(contract: dict[str, Any], processes: dict[str, Any]) -> dict[str, Any]:
    required = [
        repo_path(contract["candidatePlan"]["reviewManifest"]),
        repo_path(contract["candidatePlan"]["parallelExecutionReceipt"]),
        repo_path(contract["candidatePlan"]["rejectedAttemptInventory"]),
        repo_path(contract["candidatePlan"]["validationRoot"] + "normalization-repeat.json"),
        repo_path(contract["candidatePlan"]["validationRoot"] + "lods.json"),
        repo_path(contract["candidatePlan"]["validationRoot"] + "contact-sheet.json"),
        repo_path(contract["candidatePlan"]["validationRoot"] + "source-output-validation.json"),
    ]
    require_artifacts(required)
    receipt = {
        "schema": "citysim.play-080.candidate-neutral-assembly.v1",
        "taskId": "PLAY-080",
        "direction": "south",
        "selectedProcess": contract["candidatePlan"]["selectedProcess"],
        "processes": {
            process: {
                "raw": artifact(value["paths"]["raw"]),
                "semantic": artifact(value["paths"]["semantic"]),
                "provenance": artifact(value["paths"]["provenance"]),
                "freshInvocationReceipt": artifact(value["paths"]["runnerReport"]),
            }
            for process, value in processes.items()
        },
        "artifacts": [artifact(path) for path in required],
        "nextStage": "assemble_source_candidate_v2_after_content_commit",
        "candidateReadyForIndependentReview": False,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "result": "PASS",
    }
    output = repo_path(contract["candidatePlan"]["assemblyReceipt"])
    write_once(output, json_bytes(receipt))
    return receipt


COMMANDS = {
    "normalize-repeat": command_normalize,
    "lods": command_lods,
    "contact-sheet": command_contact_sheet,
    "parallel-receipt": command_parallel_receipt,
    "review-manifest": command_review_manifest,
    "assemble": command_assemble,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=tuple(COMMANDS), required=True)
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    args = parser.parse_args()
    try:
        contract = load_json(args.contract)
        run_production.validate_contract_shape(contract)
        if contract.get("state") != "appearance_lock_bound":
            raise CandidatePreparationRejected(
                "RUNNER_NOT_APPEARANCE_LOCK_BOUND", contract.get("state")
            )
        processes = require_exact_abc_products(contract)
        result = COMMANDS[args.mode](contract, processes)
    except (
        CandidatePreparationRejected,
        run_production.GuardRejected,
        OSError,
        ValueError,
    ) as error:
        code = getattr(error, "code", type(error).__name__)
        detail = getattr(error, "detail", getattr(error, "details", str(error)))
        print(json.dumps({"result": "REJECTED", "code": code, "detail": detail}, sort_keys=True))
        return 2
    print(json.dumps({"result": "PASS", "mode": args.mode, "receipt": result}, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
