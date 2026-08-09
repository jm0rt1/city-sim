#!/usr/bin/env python3
"""Repository-portable PLAY-104 route binding and PNG artifact replay.

This module deliberately uses only the Python standard library. It never
consults an Integration checkout, Git, a user-specific interpreter, or a
runtime helper outside this repository. The replay checks the committed
source candidate and its normalized payloads in two copied isolated roots.
It is an artifact/runtime replay, not visual acceptance or production
selection.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import struct
import tempfile
import zlib
from contextlib import ExitStack
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REPO = Path(__file__).resolve().parents[6]
EAST_ROOT = REPO / "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-104/east"
EVIDENCE_ROOT = REPO / "docs/production/evidence/PLAY-104"
EAST_REL = "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-104/east"
EVIDENCE_REL = "docs/production/evidence/PLAY-104"
V9_ROUTE_REL = f"{EAST_REL}/route-snapshot/MODEL-ROUTE-PLAY-104-EAST-PRODUCTION-V3.json"
V10_ROUTE_REL = f"{EAST_REL}/route-snapshot/MODEL-ROUTE-PLAY-104-EAST-PRODUCTION-REPAIR-V1.json"
V20_ROUTE_REL = f"{EAST_REL}/route-snapshot/MODEL-ROUTING-PLAY-104-EAST-CANDIDATE-PACKET-REPAIR-V1.json"
V9_ROUTE_FILE_SHA256 = "b49636b2c755911468514e51014378982495e59831c4f2a3622afad5f46678b0"
V9_ROUTE_CANONICAL_SHA256 = "14874e0506707961bf9f9ffa2131e35e2151f99d50b0be7e6f6d05adbc96ff33"
V9_ROUTE_ID = "four-view-v9:play-104-east-raw-anchor-authorized"
V10_ROUTE_FILE_SHA256 = "076b88049c75a178bd1ec0f22e1481456a6e4462299f703ceabaffa8c94c0601"
V10_ROUTE_CANONICAL_SHA256 = "ee102d1039ed2afc4daf3a0e1b6d075648902c19270ca4cb8a547e0b170f8b09"
V10_ROUTE_ID = "four-view-v10:play-104-east-production-repair-v1"
V20_ROUTE_FILE_SHA256 = "a52ace92a3281a0b85445f1a61d70badb568836e6edf086aa381544dd968de04"
V20_ROUTE_CANONICAL_SHA256 = "dce6865eb98c463974bfa13769c1ee5f939be46d468069381ce457d14bedb153"
V20_ROUTE_ID = "four-view-v20:play-104-east-candidate-packet-repair-v1"
V21_ROUTE_REL = f"{EAST_REL}/route-snapshot/MODEL-ROUTE-PLAY-104-EAST-HANDOFF-COHERENCE-REPAIR-V1.json"
V21_ROUTE_FILE_SHA256 = "19cec72052e65d692165992d6d6dfe1e910e1be3f09e96567a89df43c2226337"
V21_ROUTE_CANONICAL_SHA256 = "0739f6b36f0b208f219626a64b986d932c3c3f62c0a7c5e1f677a6d365947272"
V21_ROUTE_ID = "four-view-v21:play-104-east-handoff-coherence-repair-v1"
V23_ROUTE_REL = f"{EAST_REL}/route-snapshot/MODEL-ROUTE-PLAY-104-EAST-CONTRACT028-VISUAL-REPAIR-V1.json"
V23_ROUTE_FILE_SHA256 = "54a0d18277145a27ffca6589a9aa54434d15cde03a36243de889022bf49793d8"
V23_ROUTE_CANONICAL_SHA256 = "e27286f9cf90b0c0a90a4827f36075498b5ec8b33ea3eb6dd079cd690049fabe"
V23_ROUTE_ID = "four-view-v23:play-104-east-contract028-visual-repair-v1"
V24_ROUTE_REL = f"{EAST_REL}/route-snapshot/MODEL-ROUTE-PLAY-104-EAST-CONTACT-SHEET-REPAIR-V2.json"
V24_ROUTE_FILE_SHA256 = "4a60ea6ec4d96d99f94bff2b19f445c08f6b3505f19688d2258bcf4edb17ab45"
V24_ROUTE_CANONICAL_SHA256 = "48bf6b8907a664374d14296aa0d15fb361ff43eda132eac5fc4e83a1eb8f2a83"
V24_ROUTE_ID = "four-view-v24:play-104-east-contact-sheet-repair-v2"
V24_RESULT_HEAD = "0887dfadb34a30755376b7f859f2c71d9dd125be"
V26_ROUTE_ID = "four-view-v26:play-104-east-handoff-coherence-rebind-v1"
V26_ROUTE_CANONICAL_SHA256 = "4cbf877de594fcebf9841a8ca19a4fa89866e672b1eee34740ad83d003e21403"
V26_CARRIER = "c71d714aa64b8e8a50db985cdf2f6e626d4946a3"
AUTHORITY_COMMIT = "65825389d586a128ddf6feb5356c33661ba9a8e8"
V9_WORKER_HEAD = "51f6170adc659c169c15b5e4dac3f963f4988418"
V10_WORKER_HEAD = "be990d5a5b529c7fe5e0528b4b8549058ba45b9e"
V20_WORKER_HEAD = "8fd5848d6885b674e8642b69327d53c8a2d1ed34"
V21_WORKER_HEAD = "62ef05886e7eaf396bcc97b2d62abbb015511648"
V23_WORKER_HEAD = "2b404eb424d5b3ea8a80b5bfe29424a85bb5dd98"
V24_WORKER_HEAD = "a30469de60e12b66f9a2c7b65ac40f16c62a7fa7"
BRANCH = "codex/citysim-world-art-east-imagegen"
CANVAS = (1536, 1024)
LOD_SIZES = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
EXPECTED = (
    [(f"residential_l{level:02d}_v{variant}", "residential", f"residential_l{level:02d}_variant_{variant}") for level in range(1, 5) for variant in range(3)]
    + [(f"commercial_l{level:02d}_v{variant}", "commercial", f"commercial_l{level:02d}_v0{variant}") for level in range(1, 5) for variant in range(3)]
    + [(f"industrial_l{level:02d}_v{variant}", "industrial", f"industrial_l{level:02d}_v0{variant}") for level in range(1, 5) for variant in range(3)]
    + [(f"civic_{identity}_v0", "civic/service", identity) for identity in ("park", "power-plant", "water-tower", "fire-station", "police-station", "school", "city-hall")]
)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


@dataclass(frozen=True)
class PNGImage:
    width: int
    height: int
    mode: str
    data: bytes

    @property
    def channels(self) -> int:
        return 3 if self.mode == "RGB" else 4


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def read_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text())


def _paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left


def _unfilter(scanlines: bytes, width: int, height: int, channels: int) -> bytes:
    row_bytes = width * channels
    expected = height * (row_bytes + 1)
    if len(scanlines) != expected:
        raise ValueError(f"PNG scanline length mismatch: expected {expected}, got {len(scanlines)}")
    decoded = bytearray(height * row_bytes)
    source_offset = 0
    for row_index in range(height):
        filter_type = scanlines[source_offset]
        source_offset += 1
        filtered = scanlines[source_offset:source_offset + row_bytes]
        source_offset += row_bytes
        row_start = row_index * row_bytes
        previous_start = (row_index - 1) * row_bytes
        row = bytearray(row_bytes)
        for index, value in enumerate(filtered):
            left = row[index - channels] if index >= channels else 0
            above = decoded[previous_start + index] if row_index else 0
            upper_left = decoded[previous_start + index - channels] if row_index and index >= channels else 0
            if filter_type == 0:
                reconstructed = value
            elif filter_type == 1:
                reconstructed = value + left
            elif filter_type == 2:
                reconstructed = value + above
            elif filter_type == 3:
                reconstructed = value + ((left + above) // 2)
            elif filter_type == 4:
                reconstructed = value + _paeth(left, above, upper_left)
            else:
                raise ValueError(f"unsupported PNG filter type: {filter_type}")
            row[index] = reconstructed & 0xFF
        decoded[row_start:row_start + row_bytes] = row
    return bytes(decoded)


def decode_png(path: Path) -> PNGImage:
    payload = path.read_bytes()
    if not payload.startswith(PNG_SIGNATURE):
        raise ValueError(f"not a PNG: {path}")
    offset = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = None
    interlace = None
    idat = bytearray()
    saw_iend = False
    while offset < len(payload):
        if offset + 12 > len(payload):
            raise ValueError(f"truncated PNG chunk: {path}")
        length = struct.unpack(">I", payload[offset:offset + 4])[0]
        chunk_start = offset + 4
        chunk_end = chunk_start + 4 + length
        crc_end = chunk_end + 4
        if crc_end > len(payload):
            raise ValueError(f"truncated PNG payload: {path}")
        chunk_type = payload[chunk_start:chunk_start + 4]
        chunk_data = payload[chunk_start + 4:chunk_end]
        expected_crc = struct.unpack(">I", payload[chunk_end:crc_end])[0]
        actual_crc = zlib.crc32(chunk_type)
        actual_crc = zlib.crc32(chunk_data, actual_crc) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise ValueError(f"PNG CRC mismatch: {path}")
        offset = crc_end
        if chunk_type == b"IHDR":
            if len(chunk_data) != 13 or width is not None:
                raise ValueError(f"invalid PNG header: {path}")
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", chunk_data)
            if compression != 0 or filtering != 0:
                raise ValueError(f"unsupported PNG compression/filter: {path}")
        elif chunk_type == b"IDAT":
            idat.extend(chunk_data)
        elif chunk_type == b"IEND":
            saw_iend = True
            break
    if not saw_iend or width is None or height is None or bit_depth != 8 or interlace != 0:
        raise ValueError(f"unsupported PNG structure: {path}")
    if color_type == 2:
        mode, channels = "RGB", 3
    elif color_type == 6:
        mode, channels = "RGBA", 4
    else:
        raise ValueError(f"unsupported PNG color type {color_type}: {path}")
    try:
        scanlines = zlib.decompress(bytes(idat))
    except zlib.error as error:
        raise ValueError(f"PNG decompression failed: {path}: {error}") from error
    return PNGImage(width, height, mode, _unfilter(scanlines, width, height, channels))


def pixel_digest(image: PNGImage) -> str:
    digest = hashlib.sha256()
    digest.update(struct.pack(">II", image.width, image.height))
    digest.update(image.mode.encode())
    digest.update(image.data)
    return digest.hexdigest()


def is_keyed_magenta(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and red >= 180 and blue >= 150 and green <= 110 and red + blue >= 4 * green


def boundary_residual(pixel: tuple[int, int, int, int], neighbors: Iterable[tuple[int, int, int, int]]) -> bool:
    red, green, blue, alpha = pixel
    return 0 < alpha < 255 and any(neighbor[3] == 0 for neighbor in neighbors) and max(red, blue) >= 64 and red + blue - 2 * green >= 64


def validate_raw(path: Path) -> tuple[PNGImage, str]:
    image = decode_png(path)
    if (image.width, image.height) != CANVAS or image.mode != "RGB":
        raise ValueError(f"raw format mismatch: {path}")
    return image, sha256(path)


def validate_lod(path: Path, size: tuple[int, int]) -> tuple[PNGImage, str]:
    image = decode_png(path)
    if (image.width, image.height) != size or image.mode != "RGBA":
        raise ValueError(f"LOD format mismatch: {path}")
    pixels = [tuple(image.data[offset:offset + 4]) for offset in range(0, len(image.data), 4)]
    strict = residual = hidden = edge = 0
    for index, pixel in enumerate(pixels):
        red, green, blue, alpha = pixel
        if is_keyed_magenta(pixel):
            strict += 1
            raise ValueError(f"visible chroma in normalized output: {path}")
        if not alpha and (red or green or blue):
            hidden += 1
            raise ValueError(f"hidden RGB in transparent output: {path}")
        x, y = index % image.width, index // image.width
        neighbors = [pixels[next_y * image.width + next_x] for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)) if 0 <= next_x < image.width and 0 <= next_y < image.height]
        residual += boundary_residual(pixel, neighbors)
        edge += alpha > 0 and (x in (0, image.width - 1) or y in (0, image.height - 1))
    if residual:
        raise ValueError(f"boundary residual chroma in normalized output: {path}")
    width, height = image.width, image.height
    for x in range(width):
        for y in (0, height - 1):
            if image.data[(y * width + x) * 4 + 3]:
                raise ValueError(f"visible edge pixel in normalized output: {path}")
    for y in range(height):
        for x in (0, width - 1):
            if image.data[(y * width + x) * 4 + 3]:
                raise ValueError(f"visible edge pixel in normalized output: {path}")
    return image, sha256(path)


def _safe_relative(root: Path, relative: str) -> Path:
    candidate = (root / relative).resolve()
    if not candidate.is_relative_to(root.resolve()):
        raise ValueError(f"path escapes replay root: {relative}")
    return candidate


def preserved_artifact_manifest(root: Path, contact_sheet_hashes: dict[str, str] | None = None) -> tuple[dict[str, int], str]:
    east = _safe_relative(root, EAST_REL)
    evidence = _safe_relative(root, EVIDENCE_REL)
    specs = (
        ("raw", east / "raw", "*.png"),
        ("lod", east / "lod", "*.png"),
        ("contactSheets", east / "contact-sheets", "*.png"),
        ("prompts", east / "prompts", "*.md"),
        ("provenance", east / "provenance", "*.json"),
    )
    rows: list[tuple[str, str]] = []
    counts: dict[str, int] = {}
    for kind, base, pattern in specs:
        paths = sorted(base.rglob(pattern))
        counts[kind] = len(paths)
        for path in paths:
            key = f"{kind}/{path.relative_to(base).as_posix()}"
            digest = (contact_sheet_hashes or {}).get(key, sha256(path))
            rows.append((key, digest))
    return counts, hashlib.sha256(canonical_json(rows)).hexdigest()


def handoff_manifest(root: Path) -> tuple[int, str]:
    handoffs = _safe_relative(root, f"{EVIDENCE_REL}/handoffs")
    paths = sorted(handoffs.rglob("*.json"))
    rows = [
        (path.relative_to(handoffs).as_posix(), sha256(path))
        for path in paths
    ]
    return len(paths), hashlib.sha256(canonical_json(rows)).hexdigest()


def south_bindings(root: Path) -> dict[str, dict[str, str]]:
    bindings: dict[str, dict[str, str]] = {}
    residential_path = _safe_relative(root, "docs/production/evidence/PLAY-097/south-admission-v3-validation.json")
    for row in read_json(residential_path)["rows"]:
        south_id = row["identity"]
        bindings[south_id] = {
            "path": f"Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-097/residential/raw/{south_id}/source-v01.png",
            "sha256": row["rawSha256"],
        }
    commercial_path = _safe_relative(root, "docs/production/evidence/PLAY-098/south/south-admission-receipt.json")
    for south_id, raw_sha in read_json(commercial_path)["rawSha256"].items():
        bindings[south_id] = {
            "path": f"Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-098/commercial/raw/{south_id}-source-v01.png",
            "sha256": raw_sha,
        }
    industrial_path = _safe_relative(root, "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/inventory/PLAY-099-industrial-raw-inventory.json")
    for row in read_json(industrial_path)["candidates"]:
        bindings[row["logicalId"]] = {"path": row["rawPath"], "sha256": row["rawSha256"]}
    civic_path = _safe_relative(root, "docs/production/evidence/PLAY-100/south-handoff.json")
    for row in read_json(civic_path)["artifacts"]["receipts"]:
        bindings[row["identity"]] = {
            "path": f"Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-100/civic/raw/{row['identity']}-v01.png",
            "sha256": row["rawSha256"],
        }
    return bindings


def verify_route_snapshots(root: Path) -> dict[str, object]:
    v23_path = _safe_relative(root, V23_ROUTE_REL)
    if sha256(v23_path) != V23_ROUTE_FILE_SHA256:
        raise ValueError("published V23 route snapshot file hash drift")
    v23 = read_json(v23_path)
    if hashlib.sha256(canonical_json(v23)).hexdigest() != V23_ROUTE_CANONICAL_SHA256:
        raise ValueError("published V23 route canonical hash drift")
    if v23.get("schema") != 2 or v23.get("routeId") != V23_ROUTE_ID:
        raise ValueError("published V23 route identity drift")
    if v23.get("authority", {}).get("authorityCommit") != AUTHORITY_COMMIT:
        raise ValueError("repair V23 route authority drift")
    assignment = v23.get("assignment", {})
    if assignment.get("branch") != BRANCH or assignment.get("expectedHead") != V23_WORKER_HEAD:
        raise ValueError("repair V23 assignment drift")
    reference = v23.get("proofPolicy", {}).get("referenceImplementation", {})
    if reference.get("path") != "docs/production/decisions/CONTRACT-025-authored-four-view-2-5d-building-art.md":
        raise ValueError("repair V23 architecture reference drift")
    allowed = v23.get("pathPolicy", {}).get("claimOwnedRoots", [])
    if allowed != [EAST_REL, EVIDENCE_REL]:
        raise ValueError("repair V23 allowed roots drift")
    v24_path = _safe_relative(root, V24_ROUTE_REL)
    if sha256(v24_path) != V24_ROUTE_FILE_SHA256:
        raise ValueError("published V24 route snapshot file hash drift")
    v24 = read_json(v24_path)
    if hashlib.sha256(canonical_json(v24)).hexdigest() != V24_ROUTE_CANONICAL_SHA256:
        raise ValueError("published V24 route canonical hash drift")
    if v24.get("schema") != 2 or v24.get("routeId") != V24_ROUTE_ID:
        raise ValueError("published V24 route identity drift")
    if v24.get("authority", {}).get("authorityCommit") != AUTHORITY_COMMIT:
        raise ValueError("repair V24 route authority drift")
    v24_assignment = v24.get("assignment", {})
    if v24_assignment.get("branch") != BRANCH or v24_assignment.get("expectedHead") != V24_WORKER_HEAD:
        raise ValueError("repair V24 assignment drift")
    if v24.get("pathPolicy", {}).get("claimOwnedRoots", []) != [EAST_REL, EVIDENCE_REL]:
        raise ValueError("repair V24 allowed roots drift")
    return {"v23": v23, "v24": v24}


def scan_contact_sheet(path: Path, path_label: str | None = None) -> dict[str, object]:
    image = decode_png(path)
    if image.mode != "RGB" or (image.width, image.height) != (1024, 2156):
        raise ValueError(f"contact-sheet format mismatch: {path}")
    strict = 0
    for offset in range(0, len(image.data), 3):
        strict += is_keyed_magenta((image.data[offset], image.data[offset + 1], image.data[offset + 2], 255))
    if strict:
        raise ValueError(f"opaque/interior keyed magenta in contact sheet: {path}: {strict}")
    return {
        "path": path_label or path.as_posix(),
        "sha256": sha256(path),
        "dimensions": [image.width, image.height],
        "mode": image.mode,
        "strictKeyedMagentaPixels": strict,
    }


def _readiness(value: dict[str, object], label: str) -> None:
    if value.get("candidateReadyForIndependentReview") is not True:
        raise ValueError(f"{label} candidateReadyForIndependentReview must be true")
    expected = {
        "sourceReady": False,
        "integrationAdmitted": False,
        "rendererQuarantined": False,
        "productionSelected": False,
    }
    for key, expected_value in expected.items():
        if value.get(key) is not expected_value:
            raise ValueError(f"{label} readiness {key} must be false")


def replay(root: Path) -> dict[str, object]:
    v23 = verify_route_snapshots(root)
    bindings = south_bindings(root)
    if len(bindings) != len(EXPECTED):
        raise ValueError(f"South binding count mismatch: {len(bindings)}")
    aggregate_path = _safe_relative(root, f"{EVIDENCE_REL}/PLAY-104-EAST-PRODUCTION-HANDOFF-V3.json")
    aggregate = read_json(aggregate_path)
    if aggregate.get("routeId") != V24_ROUTE_ID or aggregate.get("routeFileSha256") != V24_ROUTE_FILE_SHA256 or aggregate.get("canonicalModelRouteSha256") != V24_ROUTE_CANONICAL_SHA256:
        raise ValueError("East aggregate V24 producer route binding drift")
    if aggregate.get("workerHead") != V24_RESULT_HEAD or aggregate.get("resultHead") != V24_RESULT_HEAD or aggregate.get("producerStartingHead") != V24_WORKER_HEAD or aggregate.get("authorityCommit") != AUTHORITY_COMMIT or aggregate.get("claim", {}).get("sha256") != "4e4311bdd3eed96a209a7b69958b468fc091c228db708783c6b8d813903a8583":
        raise ValueError("East aggregate result-head binding drift")
    aggregate_producer = aggregate.get("producerRoute", {})
    if aggregate_producer.get("routeId") != V24_ROUTE_ID or aggregate_producer.get("routeFileSha256") != V24_ROUTE_FILE_SHA256 or aggregate_producer.get("canonicalModelRouteSha256") != V24_ROUTE_CANONICAL_SHA256 or aggregate_producer.get("startingHead") != V24_WORKER_HEAD or aggregate_producer.get("resultHead") != V24_RESULT_HEAD:
        raise ValueError("East aggregate producer route projection drift")
    _readiness(aggregate, "aggregate")
    records = aggregate.get("records", [])
    if len(records) != len(EXPECTED):
        raise ValueError("aggregate identity count mismatch")
    record_by_identity = {record.get("identity"): record for record in records}
    if set(record_by_identity) != {identity for identity, _family, _south_id in EXPECTED}:
        raise ValueError("aggregate identity set mismatch")
    readiness = read_json(_safe_relative(root, f"{EVIDENCE_REL}/PLAY-104-EAST-PRODUCTION-READINESS-V3.json"))
    if readiness.get("routeId") != V24_ROUTE_ID or readiness.get("routeFileSha256") != V24_ROUTE_FILE_SHA256 or readiness.get("canonicalModelRouteSha256") != V24_ROUTE_CANONICAL_SHA256 or readiness.get("deterministicReplay") != "PASS":
        raise ValueError("readiness V24 route or replay binding drift")
    if readiness.get("resultHead") != V24_RESULT_HEAD or readiness.get("producerStartingHead") != V24_WORKER_HEAD or readiness.get("claim", {}).get("sha256") != "4e4311bdd3eed96a209a7b69958b468fc091c228db708783c6b8d813903a8583":
        raise ValueError("readiness result-head binding drift")
    _readiness(readiness, "readiness")
    repair = read_json(_safe_relative(root, f"{EVIDENCE_REL}/PLAY-104-EAST-CONTRACT028-VISUAL-REPAIR-V1.json"))
    if repair.get("routeId") != V23_ROUTE_ID or repair.get("canonicalModelRouteSha256") != V23_ROUTE_CANONICAL_SHA256:
        raise ValueError("repair receipt route binding drift")
    if repair.get("dispatchRouteSnapshot") != V23_ROUTE_REL:
        raise ValueError("repair receipt route snapshot paths drift")
    if repair.get("dispatchRouteFileSha256") != V23_ROUTE_FILE_SHA256:
        raise ValueError("repair receipt route snapshot hashes drift")
    if repair.get("pixelsPreserved") is not True:
        raise ValueError("repair receipt does not preserve pixels")
    if repair.get("counts") != {"identities": 43, "rawMasters": 43, "lodPayloads": 129, "handoffs": 43}:
        raise ValueError("repair receipt count binding drift")
    preserved_counts, preserved_manifest = preserved_artifact_manifest(root)
    if repair.get("preservedArtifactCounts") != preserved_counts:
        raise ValueError("preserved artifact count binding drift")
    if repair.get("preservedArtifactManifestSha256") != preserved_manifest:
        # V23 is retained as a historical receipt. V24 is authorized to
        # replace exactly its two derived literal sheets, so reconstruct the
        # historical manifest with their V1 proof hashes and require every
        # other artifact to remain byte-identical.
        proof_v1 = read_json(_safe_relative(root, f"{EVIDENCE_REL}/PLAY-104-EAST-LITERAL-SCALE-PROOF-V1.json"))
        old_sheet_hashes = {
            "contactSheets/east-literal-game-scale-color-contact-sheet.png": proof_v1.get("color", {}).get("sha256"),
            "contactSheets/east-literal-footprint-contact-sheet.png": proof_v1.get("footprint", {}).get("sha256"),
        }
        _old_counts, historical_manifest = preserved_artifact_manifest(root, old_sheet_hashes)
        if repair.get("preservedArtifactManifestSha256") != historical_manifest:
            raise ValueError("preserved artifact manifest drift")
    handoff_count, handoff_manifest_sha = handoff_manifest(root)
    if handoff_count != 43 or repair.get("repairedHandoffManifestAfterSha256") != handoff_manifest_sha:
        raise ValueError("repaired handoff manifest drift")
    coherence = repair.get("coherenceRebind", {})
    if coherence.get("routeId") != V26_ROUTE_ID or coherence.get("canonicalModelRouteSha256") != V26_ROUTE_CANONICAL_SHA256 or coherence.get("carrier") != V26_CARRIER or coherence.get("resultHead") != V24_RESULT_HEAD:
        raise ValueError("V26 coherence proof binding drift")
    _readiness(repair, "repair")
    focused_replay = repair.get("focusedReplay", {})
    if focused_replay.get("repeat") != 2 or focused_replay.get("isolatedRoots") != 2:
        raise ValueError("focused replay receipt shape drift")
    v24_proof = read_json(_safe_relative(root, f"{EVIDENCE_REL}/PLAY-104-EAST-LITERAL-SCALE-PROOF-V2.json"))
    if v24_proof.get("routeId") != V24_ROUTE_ID or v24_proof.get("routeCanonicalSha256") != V24_ROUTE_CANONICAL_SHA256 or v24_proof.get("routeFileSha256") != V24_ROUTE_FILE_SHA256 or v24_proof.get("producerStartingHead") != V24_WORKER_HEAD or v24_proof.get("resultHead") != V24_RESULT_HEAD or v24_proof.get("claimSha256") != "4e4311bdd3eed96a209a7b69958b468fc091c228db708783c6b8d813903a8583":
        raise ValueError("V24 literal proof route binding drift")
    proof_coherence = v24_proof.get("coherenceRebind", {})
    if proof_coherence.get("routeId") != V26_ROUTE_ID or proof_coherence.get("canonicalModelRouteSha256") != V26_ROUTE_CANONICAL_SHA256 or proof_coherence.get("carrier") != V26_CARRIER or proof_coherence.get("resultHead") != V24_RESULT_HEAD:
        raise ValueError("V24 proof coherence binding drift")
    color_scan = scan_contact_sheet(_safe_relative(root, f"{EAST_REL}/contact-sheets/east-literal-game-scale-color-contact-sheet.png"), f"{EAST_REL}/contact-sheets/east-literal-game-scale-color-contact-sheet.png")
    footprint_scan = scan_contact_sheet(_safe_relative(root, f"{EAST_REL}/contact-sheets/east-literal-footprint-contact-sheet.png"), f"{EAST_REL}/contact-sheets/east-literal-footprint-contact-sheet.png")
    for kind, scan in (("color", color_scan), ("footprint", footprint_scan)):
        proof_sheet = v24_proof.get(kind, {})
        if proof_sheet.get("path") != scan["path"] or proof_sheet.get("sha256") != scan["sha256"]:
            raise ValueError(f"V24 proof {kind} sheet hash drift")
    v24_receipt = read_json(_safe_relative(root, f"{EVIDENCE_REL}/PLAY-104-EAST-CONTACT-SHEET-REPAIR-V2.json"))
    if v24_receipt.get("routeId") != V24_ROUTE_ID or v24_receipt.get("canonicalModelRouteSha256") != V24_ROUTE_CANONICAL_SHA256:
        raise ValueError("V24 contact-sheet receipt route binding drift")
    if v24_receipt.get("dispatchRouteSnapshot") != V24_ROUTE_REL or v24_receipt.get("dispatchRouteFileSha256") != V24_ROUTE_FILE_SHA256:
        raise ValueError("V24 contact-sheet receipt route snapshot drift")
    if v24_receipt.get("workerHead") != V24_WORKER_HEAD or v24_receipt.get("producerStartingHead") != V24_WORKER_HEAD or v24_receipt.get("resultHead") != V24_RESULT_HEAD or v24_receipt.get("branch") != BRANCH:
        raise ValueError("V24 contact-sheet receipt worker binding drift")
    receipt_coherence = v24_receipt.get("coherenceRebind", {})
    if receipt_coherence.get("routeId") != V26_ROUTE_ID or receipt_coherence.get("canonicalModelRouteSha256") != V26_ROUTE_CANONICAL_SHA256 or receipt_coherence.get("carrier") != V26_CARRIER or receipt_coherence.get("resultHead") != V24_RESULT_HEAD:
        raise ValueError("V24 receipt coherence binding drift")
    if v24_receipt.get("contactSheetScan", {}).get("color", {}).get("strictKeyedMagentaPixels") != 0 or v24_receipt.get("contactSheetScan", {}).get("footprint", {}).get("strictKeyedMagentaPixels") != 0:
        raise ValueError("V24 contact-sheet receipt reports keyed magenta")
    if v24_receipt.get("after", {}).get("colorSha256") != color_scan["sha256"] or v24_receipt.get("after", {}).get("footprintSha256") != footprint_scan["sha256"]:
        raise ValueError("V24 contact-sheet receipt output hash drift")
    _readiness(v24_receipt, "V24 contact-sheet receipt")
    raw_hashes: list[str] = []
    lod_hashes: list[str] = []
    semantic = hashlib.sha256()
    semantic.update(V23_ROUTE_CANONICAL_SHA256.encode())
    for identity, family, south_id in EXPECTED:
        identity_record = record_by_identity[identity]
        raw_path = _safe_relative(root, f"{EAST_REL}/raw/{identity}/east-source-v01.png")
        raw_image, raw_sha = validate_raw(raw_path)
        raw_hashes.append(raw_sha)
        semantic.update(identity.encode())
        semantic.update(pixel_digest(raw_image).encode())
        binding = bindings.get(south_id)
        if not binding:
            raise ValueError(f"missing South binding: {south_id}")
        south_path = _safe_relative(root, binding["path"])
        if sha256(south_path) != binding["sha256"]:
            raise ValueError(f"South hash drift: {south_id}")
        if identity_record.get("rawSha256") != raw_sha:
            raise ValueError(f"aggregate raw hash drift: {identity}")
        prompt_path = _safe_relative(root, f"{EAST_REL}/prompts/{identity}/east-prompt.md")
        provenance_path = _safe_relative(root, f"{EAST_REL}/provenance/{identity}/east-provenance.json")
        handoff_path = _safe_relative(root, f"{EVIDENCE_REL}/handoffs/{identity}/east-handoff.json")
        prompt_text = prompt_path.read_text()
        provenance = read_json(provenance_path)
        handoff = read_json(handoff_path)
        if provenance.get("direction") != "east" or provenance.get("identity") != identity:
            raise ValueError(f"provenance identity binding drift: {identity}")
        if provenance.get("southReference", {}).get("sha256") != binding["sha256"]:
            raise ValueError(f"provenance South binding drift: {identity}")
        if provenance.get("promptSha256") != hashlib.sha256(prompt_text.rstrip("\n").encode()).hexdigest():
            raise ValueError(f"provenance prompt hash drift: {identity}")
        if provenance.get("rawSha256") != raw_sha:
            raise ValueError(f"provenance raw hash drift: {identity}")
        if provenance.get("siblingInputsConsumed") != [] or handoff.get("siblingInputsConsumed") != []:
            raise ValueError(f"sibling input contamination: {identity}")
        if handoff.get("routeId") != V24_ROUTE_ID or handoff.get("routeFileSha256") != V24_ROUTE_FILE_SHA256 or handoff.get("canonicalModelRouteSha256") != V24_ROUTE_CANONICAL_SHA256:
            raise ValueError(f"handoff V24 producer route binding drift: {identity}")
        if handoff.get("authorityCommit") != AUTHORITY_COMMIT or handoff.get("workerHead") != V24_RESULT_HEAD or handoff.get("resultHead") != V24_RESULT_HEAD or handoff.get("producerStartingHead") != V24_WORKER_HEAD:
            raise ValueError(f"handoff V24 result-head binding drift: {identity}")
        if handoff.get("claim", {}).get("sha256") != "4e4311bdd3eed96a209a7b69958b468fc091c228db708783c6b8d813903a8583":
            raise ValueError(f"handoff V24 claim binding drift: {identity}")
        _readiness(handoff, f"handoff {identity}")
        if handoff.get("provenance", {}).get("sha256") != sha256(provenance_path):
            raise ValueError(f"handoff provenance hash drift: {identity}")
        for lod, size in LOD_SIZES.items():
            destination = _safe_relative(root, f"{EAST_REL}/lod/{identity}/{lod}.png")
            lod_image, lod_sha = validate_lod(destination, size)
            lod_hashes.append(lod_sha)
            semantic.update(lod.encode())
            semantic.update(pixel_digest(lod_image).encode())
            provenance_lod = provenance.get("lods", {}).get(lod, {})
            handoff_lod = handoff.get("lods", {}).get(lod, {})
            if provenance_lod.get("sha256") != lod_sha or handoff_lod.get("sha256") != lod_sha:
                raise ValueError(f"LOD hash binding drift: {identity}/{lod}")
    if len(raw_hashes) != len(set(raw_hashes)):
        raise ValueError("raw aliases")
    if len(lod_hashes) != len(set(lod_hashes)):
        raise ValueError("LOD aliases")
    if len(raw_hashes) != 43 or len(lod_hashes) != 129:
        raise ValueError("payload count mismatch")
    return {
        "routeId": V23_ROUTE_ID,
        "routeCanonicalSha256": V23_ROUTE_CANONICAL_SHA256,
        "identities": len(raw_hashes),
        "rawMasters": len(raw_hashes),
        "lodPayloads": len(lod_hashes),
        "handoffs": len(records),
        "semanticReplaySha256": semantic.hexdigest(),
    }


def _copy_required_inputs(source_root: Path, destination_root: Path) -> None:
    east_source = source_root / EAST_REL
    evidence_source = source_root / EVIDENCE_REL
    shutil.copytree(east_source, destination_root / EAST_REL)
    shutil.copytree(evidence_source, destination_root / EVIDENCE_REL)
    metadata_paths = (
        "docs/production/evidence/PLAY-097/south-admission-v3-validation.json",
        "docs/production/evidence/PLAY-098/south/south-admission-receipt.json",
        "Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/inventory/PLAY-099-industrial-raw-inventory.json",
        "docs/production/evidence/PLAY-100/south-handoff.json",
    )
    bindings = south_bindings(source_root)
    relative_paths = set(metadata_paths)
    relative_paths.update(binding["path"] for binding in bindings.values())
    for relative in sorted(relative_paths):
        source = _safe_relative(source_root, relative)
        destination = _safe_relative(destination_root, relative)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)


def isolated_replays(source_root: Path = REPO) -> list[dict[str, object]]:
    results: list[dict[str, object]] = []
    with ExitStack() as stack:
        for _index in range(2):
            temporary = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="play-104-east-isolated-")))
            _copy_required_inputs(source_root, temporary)
            results.append(replay(temporary))
    if len({result["semanticReplaySha256"] for result in results}) != 1:
        raise ValueError("isolated replay semantic hashes differ")
    return results


if __name__ == "__main__":
    print(json.dumps({"source": replay(REPO), "isolated": isolated_replays(REPO)}, sort_keys=True))
