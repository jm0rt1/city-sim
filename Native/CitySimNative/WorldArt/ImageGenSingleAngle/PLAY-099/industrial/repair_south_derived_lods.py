#!/usr/bin/env python3
"""Repair PLAY-099 South LODs from immutable source-rgba inputs.

The implementation uses only the Python standard library. It performs fixed
premultiplied-alpha bilinear resampling, emits deterministic RGBA PNGs, runs
two isolated fresh-root replays, and adopts bytes only after exact agreement.
"""

from __future__ import annotations

import binascii
import hashlib
import json
import shutil
import struct
import tempfile
import zlib
from pathlib import Path

from validate_raw_candidates import read_png


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[5]
NORMALIZED = ROOT / "normalized/south"
LODS = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
IDENTITIES = [f"industrial_l{level:02d}_v{variant:02d}" for level in range(1, 5) for variant in range(3)]
FILTER = "premultiplied-bilinear-v1"
PROTECTED_DRAFTS = {
    "docs/production/evidence/PLAY-101/industrial-l01-v0-family/FAMILY-ADMISSION-LEDGER.json": "934e9f8df2e284ed1cbe7c6d5f4ef002fb1f87874b729b5a2dddff6f617160ce",
    "docs/production/evidence/PLAY-101/industrial-l01-v0-family/JOIN-INVENTORY.json": "545883dfe4b2df252e9f104e633713afe58fd01ecbdc561f5ab4557505c1c280",
    "docs/production/evidence/PLAY-101/industrial-l01-v0-family/FAMILY-VALIDATION.json": "a4dc4251aa131eab7c561121f5386ce436a64c2652f887d7e787fa3ae4abf2fd",
    "docs/production/evidence/PLAY-101/industrial-l01-v0-family/tools/validate_family_admission.py": "3c05c6be187912a69f06eecd0c8c67127a4b33859b3ac4866d0a1c2f24e1bf36",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    crc = binascii.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)


def encode_png(width: int, height: int, pixels: bytes) -> bytes:
    rows = b"".join(b"\x00" + pixels[y * width * 4 : (y + 1) * width * 4] for y in range(height))
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(rows, 9))
        + png_chunk(b"IEND", b"")
    )


def axis_map(source: int, destination: int) -> list[tuple[int, int, int, int]]:
    denominator = 2 * destination
    mapped = []
    for index in range(destination):
        numerator = (2 * index + 1) * source - destination
        lower = numerator // denominator
        fraction = numerator - lower * denominator
        upper = lower + 1
        if lower < 0:
            lower = upper = 0
            fraction = 0
        elif upper >= source:
            lower = upper = source - 1
            fraction = 0
        mapped.append((lower, upper, denominator - fraction, fraction))
    return mapped


def rounded(numerator: int, denominator: int) -> int:
    return (numerator + denominator // 2) // denominator


def resize_rgba(pixels: bytes, sw: int, sh: int, dw: int, dh: int) -> bytes:
    xmap = axis_map(sw, dw)
    ymap = axis_map(sh, dh)
    output = bytearray(dw * dh * 4)
    denominator = (2 * dw) * (2 * dh)
    for y, (y0, y1, wy0, wy1) in enumerate(ymap):
        for x, (x0, x1, wx0, wx1) in enumerate(xmap):
            samples = (
                ((y0 * sw + x0) * 4, wx0 * wy0),
                ((y0 * sw + x1) * 4, wx1 * wy0),
                ((y1 * sw + x0) * 4, wx0 * wy1),
                ((y1 * sw + x1) * 4, wx1 * wy1),
            )
            alpha_number = sum(pixels[offset + 3] * weight for offset, weight in samples)
            out = (y * dw + x) * 4
            output_alpha = min(255, rounded(alpha_number, denominator))
            if output_alpha == 0:
                output[out : out + 4] = b"\x00\x00\x00\x00"
                continue
            output[out + 3] = output_alpha
            for channel in range(3):
                premultiplied = sum(
                    pixels[offset + channel] * pixels[offset + 3] * weight
                    for offset, weight in samples
                )
                output[out + channel] = min(255, rounded(premultiplied, alpha_number))
    return bytes(output)


def verify_protected() -> None:
    for relative, expected in PROTECTED_DRAFTS.items():
        path = REPO / relative
        if not path.is_file() or sha(path) != expected:
            raise RuntimeError(f"protected draft drift: {relative}")


def source_receipts() -> list[dict]:
    receipts = json.loads((ROOT / "receipts/south/all-south-receipts.json").read_text())
    if [item["logicalId"] for item in receipts] != IDENTITIES:
        raise RuntimeError("receipt identity coverage/order")
    for receipt in receipts:
        source = ROOT / receipt["normalizedPath"]
        if not source.is_file() or sha(source) != receipt["normalizedSha256"]:
            raise RuntimeError(f"immutable source-rgba drift: {receipt['logicalId']}")
    return receipts


def build(output_root: Path, receipts: list[dict]) -> dict[str, dict[str, str]]:
    hashes: dict[str, dict[str, str]] = {}
    for receipt in receipts:
        logical_id = receipt["logicalId"]
        source = ROOT / receipt["normalizedPath"]
        width, height, channels, _, pixels = read_png(source)
        if (width, height, channels) != (1536, 1024, 4):
            raise RuntimeError(f"source-rgba encoding drift: {logical_id}")
        hashes[logical_id] = {}
        for name, (target_width, target_height) in LODS.items():
            encoded = encode_png(
                target_width,
                target_height,
                resize_rgba(pixels, width, height, target_width, target_height),
            )
            path = output_root / logical_id / f"{name}.png"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(encoded)
            hashes[logical_id][name] = hashlib.sha256(encoded).hexdigest()
    return hashes


def update_records(receipts: list[dict], hashes: dict[str, dict[str, str]], replay_digest: str) -> None:
    by_id = {item["logicalId"]: item for item in receipts}
    for receipt in receipts:
        for lod in receipt["lods"]:
            lod["sha256"] = hashes[receipt["logicalId"]][lod["name"]]
            lod["filter"] = FILTER
        receipt["normalization"] = "full-canvas immutable source-rgba; dependency-free premultiplied bilinear derived LODs"
        path = ROOT / "receipts/south" / f"{receipt['logicalId']}.json"
        path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    (ROOT / "receipts/south/all-south-receipts.json").write_text(
        json.dumps(receipts, indent=2, sort_keys=True) + "\n"
    )

    for relative, key in (
        ("provenance/south-admission-provenance-v3.json", "candidates"),
        ("handoff/PLAY-099-industrial-south-admission-v3.json", "identities"),
    ):
        path = ROOT / relative
        record = json.loads(path.read_text())
        record[key] = [
            {**item, "lods": by_id[item["logicalId"]]["lods"]}
            for item in record[key]
        ]
        record["tool"] = "dependency-free premultiplied bilinear derived-LOD repair; no ImageGen call"
        if "lodMapping" in record:
            record["lodMapping"]["filter"] = FILTER
        record["derivedLodRepair"] = {
            "tool": "repair_south_derived_lods.py",
            "toolSha256": sha(Path(__file__)),
            "filter": FILTER,
            "isolatedReplayCount": 2,
            "replayDigestSha256": replay_digest,
            "byteIdentical": True,
        }
        path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")

    process_path = ROOT / "process/south/normalizer-build.json"
    process = json.loads(process_path.read_text())
    process.update({
        "normalizer": "repair_south_derived_lods.py",
        "normalizerSha256": sha(Path(__file__)),
        "compiler": "python3 standard library only",
        "filter": FILTER,
        "sourceTransform": "immutable full-canvas source-rgba; premultiplied-alpha bilinear resize only",
        "isolatedReplayCount": 2,
        "replayDigestSha256": replay_digest,
        "byteIdentical": True,
    })
    process_path.write_text(json.dumps(process, indent=2, sort_keys=True) + "\n")

    report_path = REPO / "docs/production/evidence/PLAY-099/south-admission-report-v3.json"
    report = json.loads(report_path.read_text())
    report["derivedLodRepair"] = {
        "filter": FILTER,
        "lodCount": 36,
        "uniqueLodFileHashes": 36,
        "isolatedReplayCount": 2,
        "replayDigestSha256": replay_digest,
        "byteIdentical": True,
    }
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")

    batch_path = REPO / "docs/production/evidence/PLAY-099/south-batch-evidence-v1.json"
    batch = json.loads(batch_path.read_text())
    batch["runtime"] = {
        "command": ["python3", "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/repair_south_derived_lods.py"],
        "dependency": "Python standard library only",
        "filter": FILTER,
    }
    batch["deterministicRunsPerIdentity"] = 2
    batch["uniqueLodFileHashes"] = 36
    batch["replayDigestSha256"] = replay_digest
    batch_path.write_text(json.dumps(batch, indent=2, sort_keys=True) + "\n")


def main() -> int:
    verify_protected()
    receipts = source_receipts()
    with tempfile.TemporaryDirectory(prefix="play-099-south-repair-a-") as first_name, tempfile.TemporaryDirectory(prefix="play-099-south-repair-b-") as second_name:
        first = Path(first_name)
        second = Path(second_name)
        first_hashes = build(first, receipts)
        second_hashes = build(second, receipts)
        if first_hashes != second_hashes:
            raise RuntimeError("isolated replay hash mismatch")
        payload = json.dumps(first_hashes, sort_keys=True, separators=(",", ":")).encode()
        replay_digest = hashlib.sha256(payload).hexdigest()
        for logical_id in IDENTITIES:
            for name in LODS:
                left = first / logical_id / f"{name}.png"
                right = second / logical_id / f"{name}.png"
                if left.read_bytes() != right.read_bytes():
                    raise RuntimeError(f"isolated replay byte mismatch: {logical_id}/{name}")
                destination = NORMALIZED / logical_id / f"{name}.png"
                shutil.copyfile(left, destination)
        update_records(receipts, first_hashes, replay_digest)
    verify_protected()
    print(json.dumps({
        "result": "PASS",
        "identities": 12,
        "lodPayloads": 36,
        "uniqueLodFileHashes": len({value for lods in first_hashes.values() for value in lods.values()}),
        "isolatedReplayCount": 2,
        "replayDigestSha256": replay_digest,
        "filter": FILTER,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
