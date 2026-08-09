#!/usr/bin/env python3
"""Focused validator for the PLAY-097 Contract-028 derived-only packet.

The validator consumes Contract-028 read-only from the explicit Integration
authority checkout, verifies the worker's four RGBA outputs and receipts, and
performs two fresh isolated normalizer replays.  It never calls ImageGen,
copies source-v02, or changes any pre-existing raw/normalized/evidence bytes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

import normalize_contract028_derived as normalizer


IDENTITY = normalizer.IDENTITY
ROUTE_ID = normalizer.ROUTE_ID
ROUTE_SHA256 = normalizer.ROUTE_SHA256
EXPECTED_HEAD = normalizer.EXPECTED_HEAD
AUTHORITY_COMMIT = normalizer.AUTHORITY_COMMIT
BASE_COMMIT = normalizer.BASE_COMMIT
CLAIM_SHA256 = normalizer.CLAIM_SHA256
CONTRACT028 = normalizer.CONTRACT028
SOURCE_SHA256 = normalizer.SOURCE_SHA256
HANDOFF_SHA256 = normalizer.HANDOFF_SHA256
DOCS_RECEIPT_SHA256 = normalizer.DOCS_RECEIPT_SHA256
RAW_REL = normalizer.RAW_REL
OUTPUT_ROOT = normalizer.OUTPUT_ROOT
EVIDENCE_ROOT = normalizer.EVIDENCE_ROOT


def canonical_sha(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def file_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def require_args(args: argparse.Namespace) -> None:
    if args.identity != IDENTITY or args.source_raw != RAW_REL:
        raise RuntimeError("identity/source binding mismatch")
    if args.contract_path != normalizer.CONTRACT_REL or args.contract_sha256 != normalizer.CONTRACT_SHA256:
        raise RuntimeError("Contract-028 path/hash binding mismatch")
    if args.repeat != 2 or not args.isolated_roots:
        raise RuntimeError("V33 validator requires repeat=2 and isolated roots")
    if not (args.no_imagegen and args.no_source_copy):
        raise RuntimeError("V33 validator requires --no-imagegen and --no-source-copy")


def verify_png(path: Path, expected_sha: str, expected_canvas: tuple[int, int]) -> dict[str, Any]:
    if not path.is_file():
        raise RuntimeError(f"missing derived PNG: {path}")
    if file_sha(path) != expected_sha:
        raise RuntimeError(f"derived PNG SHA mismatch: {path}")
    with normalizer.Image.open(path) as image:
        image.load()
        if image.mode != "RGBA" or image.size != expected_canvas:
            raise RuntimeError(f"derived PNG mode/canvas mismatch: {path}")
        checks = normalizer.metrics(image, expected_canvas)
    residual_keys = (
        "strictKeyedMattePixels",
        "boundaryResidualChromaPixels",
        "hiddenRgbPixels",
        "frameEdgeOpaquePixels",
    )
    if any(checks[key] != 0 for key in residual_keys):
        raise RuntimeError(f"Contract-028 residual gate failed: {path}: {checks}")
    return checks


def verify_record() -> tuple[dict[str, Any], dict[str, str]]:
    record_path = EVIDENCE_ROOT / f"{IDENTITY}-contract028-record.json"
    replay_path = EVIDENCE_ROOT / "normalizer-replay-receipt.json"
    if not record_path.is_file() or not replay_path.is_file():
        raise RuntimeError("normalizer evidence receipts are missing")
    record = json.loads(record_path.read_text(encoding="utf-8"))
    record_sha = record.get("recordSha256")
    without_sha = dict(record)
    without_sha.pop("recordSha256", None)
    if record_sha != canonical_sha(without_sha):
        raise RuntimeError("recordSha256 does not match canonical record")
    if record.get("schema") != "citysim.play-097.residential-contract028-record.v1":
        raise RuntimeError("record schema mismatch")
    if record.get("logicalId") != IDENTITY or record.get("direction") != "south":
        raise RuntimeError("record identity/direction mismatch")
    route = record.get("routeBinding", {})
    expected_route = {
        "routeId": ROUTE_ID,
        "routeSha256": ROUTE_SHA256,
        "expectedHead": EXPECTED_HEAD,
        "authorityCommit": AUTHORITY_COMMIT,
        "baseCommit": BASE_COMMIT,
        "claimSha256": CLAIM_SHA256,
    }
    if route != expected_route:
        raise RuntimeError(f"record route binding mismatch: {route}")
    if record.get("contract028") != CONTRACT028:
        raise RuntimeError("record Contract-028 binding mismatch")
    source = record.get("source", {})
    if source.get("path") != RAW_REL or source.get("sha256") != SOURCE_SHA256 or source.get("canvas") != list(normalizer.CANVAS) or source.get("mode") != "RGB" or source.get("rawPreservedByteForByte") is not True:
        raise RuntimeError("record source binding mismatch")
    receipts = record.get("repairedFailureReceipts", {})
    if receipts.get("handoffSha256") != HANDOFF_SHA256 or receipts.get("docsMirrorSha256") != DOCS_RECEIPT_SHA256:
        raise RuntimeError("record repaired receipt binding mismatch")
    required_flags = {
        "derivedOnly": True,
        "sourceAuthority": False,
        "rawSourceAdmission": "RETURN_HARD_BLOCKER",
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "sourceCopy": False,
        "imageGenCalls": 0,
    }
    for key, expected in required_flags.items():
        if record.get(key) != expected:
            raise RuntimeError(f"record flag mismatch: {key}={record.get(key)!r}")
    registered = record.get("registered", {})
    hashes = {"registered": registered.get("sha256")}
    checks: dict[str, Any] = {}
    checks["registered"] = verify_png(OUTPUT_ROOT / f"{IDENTITY}-registered.png", registered.get("sha256", ""), tuple(normalizer.CANVAS))
    lods = record.get("lods")
    if not isinstance(lods, dict) or set(lods) != set(normalizer.LODS):
        raise RuntimeError("record LOD set mismatch")
    for lod, canvas in normalizer.LODS.items():
        item = lods[lod]
        expected_path = f"{normalizer.OUTPUT_REL}/{IDENTITY}-{lod}.png"
        if item.get("path") != expected_path or item.get("format") != "RGBA" or item.get("fullCanvas") is not True:
            raise RuntimeError(f"record {lod} path/format mismatch")
        hashes[lod] = item.get("sha256")
        checks[lod] = verify_png(OUTPUT_ROOT / f"{IDENTITY}-{lod}.png", item.get("sha256", ""), tuple(canvas))
        if item.get("checks") != checks[lod]:
            raise RuntimeError(f"record {lod} metrics mismatch")
    if len(list(OUTPUT_ROOT.glob("*.png"))) != 4:
        raise RuntimeError("derived output root contains an unexpected PNG")
    replay = json.loads(replay_path.read_text(encoding="utf-8"))
    if replay.get("routeId") != ROUTE_ID or replay.get("routeSha256") != ROUTE_SHA256 or replay.get("expectedHead") != EXPECTED_HEAD or replay.get("repeat") != 2 or replay.get("replaysIdentical") is not True or replay.get("contract028") != CONTRACT028 or replay.get("imageGenCalls") != 0 or replay.get("sourceCopy") is not False:
        raise RuntimeError("normalizer replay receipt mismatch")
    receipt_records = replay.get("recordSha256")
    if not isinstance(receipt_records, list) or len(receipt_records) != 2 or receipt_records[0] != record_sha or receipt_records[1] != record_sha:
        raise RuntimeError("normalizer replay record hashes mismatch")
    return record, checks


def run_isolated_replays(authority_root: Path, contract_path: str, contract_sha: str) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="play-097-contract028-validate-") as temp:
        temp_root = Path(temp)
        for index in (1, 2):
            destination = temp_root / f"run-{index}"
            command = [
                sys.executable,
                str(normalizer.ROOT / "normalize_contract028_derived.py"),
                "--identity",
                IDENTITY,
                "--source-raw",
                RAW_REL,
                "--output-dir",
                str(destination),
                "--authority-root",
                str(authority_root),
                "--contract-path",
                contract_path,
                "--contract-sha256",
                contract_sha,
                "--repeat",
                "1",
                "--no-imagegen",
                "--no-source-copy",
                "--no-retries",
                "--internal-run",
            ]
            completed = subprocess.run(command, cwd=normalizer.REPO_ROOT, capture_output=True, text=True)
            if completed.returncode != 0:
                raise RuntimeError(f"isolated replay {index} failed: {completed.stderr.strip() or completed.stdout.strip()}")
            try:
                result = json.loads(completed.stdout.strip().splitlines()[-1])
            except (json.JSONDecodeError, IndexError) as exc:
                raise RuntimeError(f"isolated replay {index} did not return JSON") from exc
            if result.get("status") != "PASS" or result.get("recordSha256") is None:
                raise RuntimeError(f"isolated replay {index} returned invalid result")
            files = {str(path.relative_to(destination)): file_sha(path) for path in sorted(destination.rglob("*.png"))}
            if len(files) != 4:
                raise RuntimeError(f"isolated replay {index} output count mismatch")
            results.append({"recordSha256": result["recordSha256"], "files": files})
    if results[0] != results[1]:
        raise RuntimeError("isolated replay outputs differ")
    return results


def write_contact_proof(record: dict[str, Any]) -> dict[str, Any]:
    city_path = OUTPUT_ROOT / f"{IDENTITY}-city.png"
    color_path = EVIDENCE_ROOT / "contact-sheets" / f"{IDENTITY}-city-color.png"
    gray_path = EVIDENCE_ROOT / "contact-sheets" / f"{IDENTITY}-city-grayscale.png"
    color_path.parent.mkdir(parents=True, exist_ok=True)
    with normalizer.Image.open(city_path) as city:
        city.load()
        if city.mode != "RGBA" or city.size != normalizer.LODS["city"]:
            raise RuntimeError("city output is not literal-scale RGBA 256x171")
        color = city.copy()
        grayscale = city.convert("L").convert("RGBA")
    color.save(color_path, format="PNG", optimize=False, compress_level=9)
    grayscale.save(gray_path, format="PNG", optimize=False, compress_level=9)
    return {
        "schema": "citysim.play-097.contract028-contact-proof.v1",
        "identity": IDENTITY,
        "literalScale": True,
        "tileCanvas": list(normalizer.LODS["city"]),
        "color": {"path": f"{normalizer.EVIDENCE_REL}/contact-sheets/{color_path.name}", "sha256": file_sha(color_path), "canvas": list(normalizer.LODS["city"]), "scale": 1.0, "mode": "RGBA"},
        "grayscale": {"path": f"{normalizer.EVIDENCE_REL}/contact-sheets/{gray_path.name}", "sha256": file_sha(gray_path), "canvas": list(normalizer.LODS["city"]), "scale": 1.0, "mode": "RGBA"},
        "visualAcceptance": "not_performed_worker_cannot_self_accept",
        "sourceRecordSha256": record["recordSha256"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--identity", required=True)
    parser.add_argument("--source-raw", required=True)
    parser.add_argument("--authority-root", required=True, type=Path)
    parser.add_argument("--contract-path", required=True)
    parser.add_argument("--contract-sha256", required=True)
    parser.add_argument("--repeat", type=int, default=2)
    parser.add_argument("--isolated-roots", action="store_true")
    parser.add_argument("--no-imagegen", action="store_true")
    parser.add_argument("--no-source-copy", action="store_true")
    args = parser.parse_args()
    require_args(args)
    authority_root = args.authority_root.resolve()
    before = normalizer.baseline_snapshot()
    normalizer.require_worker()
    normalizer.require_authority(authority_root, args.contract_path, args.contract_sha256)
    normalizer.require_receipts()
    if not normalizer.RAW_PATH.is_file() or normalizer.sha(normalizer.RAW_PATH) != SOURCE_SHA256:
        raise RuntimeError("source-v01 bytes mismatch")
    record, checks = verify_record()
    replays = run_isolated_replays(authority_root, args.contract_path, args.contract_sha256)
    if replays[0]["recordSha256"] != record["recordSha256"]:
        raise RuntimeError("isolated replay record differs from committed record")
    contact = write_contact_proof(record)
    write_json(EVIDENCE_ROOT / "contract-028-contact-proof.json", contact)
    validation = {
        "schema": "citysim.play-097.residential-contract028-validation.v1",
        "task": "PLAY-097",
        "logicalId": IDENTITY,
        "routeBinding": {"routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256, "expectedHead": EXPECTED_HEAD, "authorityCommit": AUTHORITY_COMMIT, "baseCommit": BASE_COMMIT, "claimSha256": CLAIM_SHA256},
        "contract028": CONTRACT028,
        "sourceSha256": SOURCE_SHA256,
        "handoffSha256": HANDOFF_SHA256,
        "docsMirrorSha256": DOCS_RECEIPT_SHA256,
        "recordSha256": record["recordSha256"],
        "metrics": checks,
        "replays": {"repeat": 2, "isolated": True, "identical": True, "recordSha256": [item["recordSha256"] for item in replays], "fileSha256": [item["files"] for item in replays]},
        "contactProof": contact,
        "derivedOnly": True,
        "sourceAuthority": False,
        "rawSourceAdmission": "RETURN_HARD_BLOCKER",
        "candidateReadyForIndependentReview": True,
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
        "imageGenCalls": 0,
        "sourceCopy": False,
        "visualAcceptance": "not_performed_worker_cannot_self_accept",
        "result": "PASS",
    }
    write_json(EVIDENCE_ROOT / "contract-028-validation.json", validation)
    if normalizer.baseline_snapshot() != before:
        raise RuntimeError("raw/old normalized/old evidence bytes changed")
    print(json.dumps({"status": "PASS", "routeId": ROUTE_ID, "routeSha256": ROUTE_SHA256, "identity": IDENTITY, "replays": 2, "metricsZero": True, "literalScaleContactProof": True, "candidateReadyForIndependentReview": True, "sourceReady": False, "integrationAdmitted": False, "rendererQuarantined": False, "productionSelected": False}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
