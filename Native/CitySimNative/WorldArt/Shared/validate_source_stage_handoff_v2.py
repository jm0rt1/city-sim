#!/usr/bin/env python3
"""Fail-closed semantic validation for an Industrial L4 direction handoff."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path
from typing import Any

from accepted_master_non_alias_v1 import (
    FORBIDDEN_SET_SHA256,
    INPUT_SHA256,
    load_forbidden_decoded_rgba,
)

try:
    from jsonschema import Draft202012Validator
except ImportError as error:  # pragma: no cover - deliberately fail closed
    raise SystemExit(f"MISSING_JSONSCHEMA: {error}") from error


SCHEMA_ID = "citysim://integration/industrial-l04-source-stage-handoff-v2"
HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
DIRECTION_PROFILE = {
    "north": {
        "task": "PLAY-027",
        "branch": "codex/citysim-world-art",
        "logical": "industrial_l04_v0_north",
        "socket": [896, 704],
        "processes": ["B", "C"],
        "sourceRoots": [
            "Native/CitySimNative/WorldArt/Blender/PLAY-027",
            "Native/CitySimNative/WorldArt/OfflineScene/PLAY-027",
        ],
        "evidenceRoot": "docs/production/evidence/PLAY-027",
    },
    "east": {
        "task": "PLAY-079",
        "branch": "codex/citysim-world-art-east",
        "logical": "industrial_l04_v0_east",
        "socket": [896, 832],
        "processes": ["A", "B", "C"],
        "sourceRoots": ["Native/CitySimNative/WorldArt/Blender/PLAY-079"],
        "evidenceRoot": "docs/production/evidence/PLAY-079",
    },
    "south": {
        "task": "PLAY-080",
        "branch": "codex/citysim-world-art-south",
        "logical": "industrial_l04_v0_south",
        "socket": [640, 832],
        "processes": ["A", "B", "C"],
        "sourceRoots": ["Native/CitySimNative/WorldArt/Blender/PLAY-080"],
        "evidenceRoot": "docs/production/evidence/PLAY-080",
    },
    "west": {
        "task": "PLAY-081",
        "branch": "codex/citysim-world-art-west",
        "logical": "industrial_l04_v0_west",
        "socket": [640, 704],
        "processes": ["A", "B", "C"],
        "sourceRoots": ["Native/CitySimNative/WorldArt/Blender/PLAY-081"],
        "evidenceRoot": "docs/production/evidence/PLAY-081",
    },
}
LOD_DIMENSIONS = {
    "block": [1024, 683],
    "neighborhood": [512, 342],
    "city": [256, 171],
}


class HandoffError(ValueError):
    """A stable, machine-readable validation failure."""

    def __init__(self, code: str, detail: str) -> None:
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


def fail(code: str, detail: str) -> None:
    raise HandoffError(code, detail)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def strict_json(data: str, label: str) -> Any:
    def reject_constant(value: str) -> None:
        fail("NONFINITE_JSON_NUMBER", f"{label}: {value}")

    def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                fail("DUPLICATE_JSON_KEY", f"{label}: {key}")
            result[key] = value
        return result

    return json.loads(
        data,
        parse_constant=reject_constant,
        object_pairs_hook=unique_object,
    )


def require_sha(value: Any, label: str) -> str:
    if not isinstance(value, str) or HEX_64.fullmatch(value) is None:
        fail("INVALID_SHA256", label)
    return value


def safe_path(repo: Path, value: Any, label: str, *, file: bool = True) -> Path:
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        fail("INVALID_REPOSITORY_PATH", f"{label}: {value!r}")
    if any(part in {".", ".."} for part in value.split("/")):
        fail("PATH_TRAVERSAL", f"{label}: {value}")
    resolved = (repo / value).resolve()
    try:
        resolved.relative_to(repo)
    except ValueError:
        fail("PATH_OUTSIDE_REPOSITORY", f"{label}: {value}")
    if file and not resolved.is_file():
        fail("MISSING_REFERENCED_FILE", f"{label}: {value}")
    return resolved


def verify_artifact(repo: Path, value: Any, label: str) -> Path:
    if not isinstance(value, dict) or set(value) != {"path", "sha256"}:
        fail("INVALID_ARTIFACT", label)
    path = safe_path(repo, value["path"], f"{label}.path")
    expected = require_sha(value["sha256"], f"{label}.sha256")
    actual = sha256_file(path)
    if actual != expected:
        fail("ARTIFACT_SHA_DRIFT", f"{label}: {actual} != {expected}")
    return path


def decode_rgba_png(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail("INVALID_PNG", str(path))
    cursor = 8
    compressed = bytearray()
    width = height = 0
    while cursor < len(data):
        length = struct.unpack(">I", data[cursor : cursor + 4])[0]
        kind = data[cursor + 4 : cursor + 8]
        chunk = data[cursor + 8 : cursor + 8 + length]
        cursor += length + 12
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
            if (depth, color, compression, filtering, interlace) != (8, 6, 0, 0, 0):
                fail("UNSUPPORTED_PNG_FORMAT", str(path))
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break
    packed = zlib.decompress(bytes(compressed))
    stride = width * 4
    rows: list[bytearray] = []
    offset = 0

    def paeth(left: int, above: int, upper_left: int) -> int:
        estimate = left + above - upper_left
        left_distance = abs(estimate - left)
        above_distance = abs(estimate - above)
        upper_left_distance = abs(estimate - upper_left)
        if left_distance <= above_distance and left_distance <= upper_left_distance:
            return left
        if above_distance <= upper_left_distance:
            return above
        return upper_left

    for _ in range(height):
        filter_type = packed[offset]
        offset += 1
        source = packed[offset : offset + stride]
        offset += stride
        row = bytearray(stride)
        previous = rows[-1] if rows else bytearray(stride)
        for index, byte in enumerate(source):
            left = row[index - 4] if index >= 4 else 0
            above = previous[index]
            upper_left = previous[index - 4] if index >= 4 else 0
            predictors = {
                0: 0,
                1: left,
                2: above,
                3: (left + above) // 2,
                4: paeth(left, above, upper_left),
            }
            if filter_type not in predictors:
                fail("UNSUPPORTED_PNG_FILTER", str(filter_type))
            row[index] = (byte + predictors[filter_type]) & 0xFF
        rows.append(row)
    return width, height, b"".join(rows)


def verify_raster(
    repo: Path,
    value: Any,
    label: str,
    native_records: dict[str, dict[str, Any]],
) -> tuple[Path, dict[str, Any]]:
    if not isinstance(value, dict) or set(value) != {
        "path",
        "sha256",
        "decodedRgbaSha256",
    }:
        fail("INVALID_RASTER", label)
    path = safe_path(repo, value["path"], f"{label}.path")
    if sha256_file(path) != require_sha(value["sha256"], f"{label}.sha256"):
        fail("ARTIFACT_SHA_DRIFT", label)
    record = native_records.get(str(path))
    if record is None:
        fail("MISSING_CANONICAL_RGBA_RECORD", str(path))
    if record["fileSha256"] != value["sha256"]:
        fail("CANONICAL_FILE_SHA_DRIFT", label)
    if record["decodedRgbaSha256"] != require_sha(
        value["decodedRgbaSha256"], f"{label}.decodedRgbaSha256"
    ):
        fail("DECODED_RGBA_SHA_DRIFT", label)
    return path, record


def canonical_rgba_records(
    repo: Path,
    paths: list[Path],
    d4_path: Path,
) -> dict[str, dict[str, Any]]:
    tool = repo / "Native/CitySimNative/WorldArt/Shared/canonical_rgba_v1.swift"
    with tempfile.TemporaryDirectory(prefix="citysim-rgba-v1-") as temporary:
        binary = Path(temporary) / "canonical-rgba-v1"
        compile_result = subprocess.run(
            [
                "/usr/bin/xcrun",
                "swiftc",
                "-O",
                "-warnings-as-errors",
                "-module-cache-path",
                str(Path(temporary) / "module-cache"),
                str(tool),
                "-framework",
                "CoreGraphics",
                "-framework",
                "ImageIO",
                "-framework",
                "CryptoKit",
                "-o",
                str(binary),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if compile_result.returncode:
            fail("CANONICAL_DECODER_COMPILE_FAILURE", compile_result.stderr.strip())
        run_result = subprocess.run(
            [
                str(binary),
                "--d4-path",
                str(d4_path),
                *[str(path) for path in paths],
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if run_result.returncode:
            fail("CANONICAL_DECODER_RUNTIME_FAILURE", run_result.stderr.strip())
    payload = strict_json(run_result.stdout, "canonicalDecoder")
    if payload.get("schema") != "citysim.canonical-rgba.v1":
        fail("CANONICAL_DECODER_SCHEMA_DRIFT", repr(payload.get("schema")))
    records = payload.get("records")
    if not isinstance(records, list) or len(records) != len(paths):
        fail("CANONICAL_DECODER_RECORD_COUNT", repr(len(records or [])))
    mapped = {record["path"]: record for record in records}
    if set(mapped) != {str(path) for path in paths}:
        fail("CANONICAL_DECODER_PATH_MISMATCH", repr(sorted(mapped)))
    return mapped


def git_commit(repo: Path, commit: Any, label: str) -> str:
    if not isinstance(commit, str) or HEX_40.fullmatch(commit) is None:
        fail("INVALID_COMMIT", label)
    result = subprocess.run(
        ["git", "-C", str(repo), "cat-file", "-e", f"{commit}^{{commit}}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode:
        fail("MISSING_COMMIT", f"{label}: {commit}")
    return commit


def require_ancestor(repo: Path, older: str, newer: str, label: str) -> None:
    result = subprocess.run(
        ["git", "-C", str(repo), "merge-base", "--is-ancestor", older, newer],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode:
        fail("ANCESTRY_MISMATCH", f"{label}: {older} !<= {newer}")


def require_file_at_commit(
    repo: Path,
    commit: str,
    relative_path: str,
    expected_sha256: str,
    label: str,
) -> None:
    result = subprocess.run(
        ["git", "-C", str(repo), "show", f"{commit}:{relative_path}"],
        check=False,
        capture_output=True,
    )
    if result.returncode:
        fail("AUTHORITY_FILE_NOT_IN_COMMIT", f"{label}: {commit}:{relative_path}")
    if sha256_bytes(result.stdout) != expected_sha256:
        fail("AUTHORITY_COMMIT_CONTENT_DRIFT", label)


def png_dimensions(path: Path) -> list[int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        fail("INVALID_PNG", str(path))
    width, height = struct.unpack(">II", data[16:24])
    return [width, height]


def d4_fingerprints(width: int, height: int, rgba: bytes) -> dict[str, str]:
    def digest(coordinates: Any) -> str:
        result = hashlib.sha256()
        for x, y in coordinates:
            offset = (y * width + x) * 4
            result.update(rgba[offset : offset + 4])
        return result.hexdigest()

    horizontal = lambda: (
        (x, y) for y in range(height) for x in range(width)
    )
    rotate90 = lambda: (
        (x, y) for x in range(width) for y in range(height - 1, -1, -1)
    )
    rotate180 = lambda: (
        (x, y)
        for y in range(height - 1, -1, -1)
        for x in range(width - 1, -1, -1)
    )
    rotate270 = lambda: (
        (x, y) for x in range(width - 1, -1, -1) for y in range(height)
    )
    mirror_x = lambda: (
        (x, y) for y in range(height) for x in range(width - 1, -1, -1)
    )
    mirror_y = lambda: (
        (x, y) for y in range(height - 1, -1, -1) for x in range(width)
    )
    mirror_diagonal = lambda: (
        (x, y) for x in range(width) for y in range(height)
    )
    mirror_anti = lambda: (
        (x, y)
        for x in range(width - 1, -1, -1)
        for y in range(height - 1, -1, -1)
    )
    return {
        "identity": digest(horizontal()),
        "rotate90": digest(rotate90()),
        "rotate180": digest(rotate180()),
        "rotate270": digest(rotate270()),
        "mirrorX": digest(mirror_x()),
        "mirrorY": digest(mirror_y()),
        "mirrorDiagonal": digest(mirror_diagonal()),
        "mirrorAntiDiagonal": digest(mirror_anti()),
    }


def verify_authority_artifacts(repo: Path, authorities: dict[str, Any]) -> None:
    fixed = {
        "contract010": ("path", "sha256"),
        "contract021": ("path", "sha256"),
        "nonAliasInput": ("path", "sha256"),
        "nonAliasLoader": ("path", "sha256"),
        "semanticValidator": ("path", "sha256"),
        "canonicalDecoder": ("path", "sha256"),
    }
    for name, (path_key, sha_key) in fixed.items():
        value = authorities[name]
        path = safe_path(repo, value[path_key], f"authorities.{name}.{path_key}")
        expected = require_sha(value[sha_key], f"authorities.{name}.{sha_key}")
        if sha256_file(path) != expected:
            fail("AUTHORITY_SHA_DRIFT", name)
    bridge = authorities["directionBridge"]
    bridge_path = safe_path(repo, bridge["documentPath"], "directionBridge.documentPath")
    if sha256_file(bridge_path) != bridge["documentSha256"]:
        fail("AUTHORITY_SHA_DRIFT", "directionBridge")
    for name in ("appearanceLock", "lockedMaterialMapping", "sourceProductionProfile"):
        value = authorities[name]
        key = "documentPath" if name == "appearanceLock" else "path"
        path = safe_path(repo, value[key], f"authorities.{name}.{key}")
        expected = value["documentSha256"] if name == "appearanceLock" else value["sha256"]
        if sha256_file(path) != expected:
            fail("AUTHORITY_SHA_DRIFT", name)
        if "commit" in value:
            commit = git_commit(repo, value["commit"], f"authorities.{name}.commit")
            require_ancestor(repo, commit, "origin/master", f"{name} publication")
            require_file_at_commit(repo, commit, value[key], expected, name)
        if not value[key].startswith("docs/production/evidence/INTEGRATION/"):
            fail("UNPUBLISHED_SOURCE_AUTHORITY", f"{name}: {value[key]}")

    profile_path = safe_path(
        repo,
        authorities["sourceProductionProfile"]["path"],
        "sourceProductionProfile.path",
    )
    profile = strict_json(profile_path.read_text(encoding="utf-8"), "sourceProductionProfile")
    required = {
        "schema",
        "familyIdentity",
        "appearanceLock",
        "lockedMaterialMapping",
        "sourceStageSchema",
        "directionProcesses",
        "computeEnvelope",
        "grants",
    }
    if not isinstance(profile, dict) or set(profile) != required:
        fail("SOURCE_PROFILE_SCHEMA_DRIFT", repr(sorted(profile) if isinstance(profile, dict) else profile))
    if profile["schema"] != "citysim.integration.world-art-source-production-profile.v1":
        fail("SOURCE_PROFILE_SCHEMA_DRIFT", str(profile["schema"]))
    if profile["familyIdentity"] != {
        "family": "industrial",
        "level": 4,
        "variant": 0,
    }:
        fail("SOURCE_PROFILE_FAMILY_DRIFT", repr(profile["familyIdentity"]))
    if profile["appearanceLock"] != authorities["appearanceLock"]:
        fail("SOURCE_PROFILE_APPEARANCE_LOCK_DRIFT", "profile does not bind handoff lock")
    if profile["lockedMaterialMapping"] != authorities["lockedMaterialMapping"]:
        fail("SOURCE_PROFILE_MATERIAL_DRIFT", "profile does not bind material mapping")
    if profile["directionProcesses"] != {
        "north": ["B", "C"],
        "east": ["A", "B", "C"],
        "south": ["A", "B", "C"],
        "west": ["A", "B", "C"],
    }:
        fail("SOURCE_PROFILE_PROCESS_DRIFT", repr(profile["directionProcesses"]))
    envelope = profile["computeEnvelope"]
    if (
        not isinstance(envelope, dict)
        or set(envelope) != {"maximumConcurrentDccProcesses", "exceptionOwner"}
        or not isinstance(envelope["maximumConcurrentDccProcesses"], int)
        or envelope["maximumConcurrentDccProcesses"] < 1
        or envelope["exceptionOwner"] != "Integration"
    ):
        fail("SOURCE_PROFILE_COMPUTE_ENVELOPE_DRIFT", repr(envelope))
    if profile["grants"] != {
        "sourceAcceptance": False,
        "rendererAdmission": False,
        "productionSelection": False,
        "shippingActivation": False,
    }:
        fail("SOURCE_PROFILE_AUTHORITY_ESCALATION", repr(profile["grants"]))


def verify_identity(payload: dict[str, Any]) -> dict[str, Any]:
    identity = payload["identity"]
    direction = identity["direction"]
    if direction not in DIRECTION_PROFILE:
        fail("DIRECTION_MISMATCH", str(direction))
    profile = DIRECTION_PROFILE[direction]
    expected = {
        "taskId": profile["task"],
        "branch": profile["branch"],
        "logicalID": profile["logical"],
    }
    for key, value in expected.items():
        if identity[key] != value:
            fail("DIRECTION_IDENTITY_MISMATCH", f"{key}: {identity[key]} != {value}")
    if f"/{direction}/" not in identity["sourceKey"]:
        fail("SOURCE_KEY_DIRECTION_MISMATCH", identity["sourceKey"])
    return profile


def verify_owned_paths(repo: Path, payload: dict[str, Any]) -> None:
    identity = payload["identity"]
    profile = DIRECTION_PROFILE[identity["direction"]]
    source_root = safe_path(
        repo, identity["sourceRoot"], "identity.sourceRoot", file=False
    )
    evidence_root = safe_path(
        repo, identity["evidenceRoot"], "identity.evidenceRoot", file=False
    )
    canonical_source_roots = tuple(
        safe_path(repo, value, "canonicalSourceRoot", file=False)
        for value in profile["sourceRoots"]
    )
    canonical_evidence_root = safe_path(
        repo, profile["evidenceRoot"], "canonicalEvidenceRoot", file=False
    )
    if not any(
        source_root == root or root in source_root.parents
        for root in canonical_source_roots
    ):
        fail("NONCANONICAL_DIRECTION_SOURCE_ROOT", identity["sourceRoot"])
    if not (
        evidence_root == canonical_evidence_root
        or canonical_evidence_root in evidence_root.parents
    ):
        fail("NONCANONICAL_DIRECTION_EVIDENCE_ROOT", identity["evidenceRoot"])
    roots = (source_root, evidence_root)

    def walk(value: Any, label: str) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                if key in {"path", "outputRoot"} and isinstance(child, str):
                    resolved = safe_path(repo, child, f"{label}.{key}", file=False)
                    if not any(
                        resolved == root or root in resolved.parents for root in roots
                    ):
                        fail("PATH_OUTSIDE_DIRECTION_OWNERSHIP", f"{label}.{key}: {child}")
                elif key == "isolatedOutputRoots" and isinstance(child, dict):
                    for process_id, process_root in child.items():
                        resolved = safe_path(
                            repo,
                            process_root,
                            f"{label}.{key}.{process_id}",
                            file=False,
                        )
                        if not any(
                            resolved == root or root in resolved.parents for root in roots
                        ):
                            fail(
                                "PATH_OUTSIDE_DIRECTION_OWNERSHIP",
                                f"{label}.{key}.{process_id}: {process_root}",
                            )
                else:
                    walk(child, f"{label}.{key}")
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, f"{label}[{index}]")

    for section in ("inputs", "launch", "completion"):
        if payload[section] is not None:
            walk(payload[section], section)


def verify_processes(
    repo: Path,
    payload: dict[str, Any],
    forbidden: frozenset[str],
    native_records: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    completion = payload["completion"]
    launch = payload["launch"]
    profile = DIRECTION_PROFILE[payload["identity"]["direction"]]
    if launch["authorizedProcesses"] != profile["processes"]:
        fail("PROCESS_AUTHORITY_MISMATCH", repr(launch["authorizedProcesses"]))
    roots = launch["isolatedOutputRoots"]
    resolved_roots = {
        process_id: safe_path(
            repo,
            value,
            f"launch.isolatedOutputRoots.{process_id}",
            file=False,
        )
        for process_id, value in roots.items()
    }
    if set(roots) != set(profile["processes"]) or len(set(resolved_roots.values())) != len(roots):
        fail("PROCESS_ROOT_ISOLATION_FAILURE", repr(roots))

    processes = completion["processes"]
    raw_file_hashes: set[str] = set()
    raw_pixel_hashes: set[str] = set()
    semantic_pixel_hashes: set[str] = set()
    for process_id in ("A", "B", "C"):
        process = processes[process_id]
        if process["processId"] != process_id:
            fail("PROCESS_ID_MISMATCH", process_id)
        # North process A is the frozen appearance authority; B/C are launch roots.
        if process_id in roots and process["outputRoot"] != roots[process_id]:
            fail("PROCESS_ROOT_MISMATCH", process_id)
        raw_path, raw_record = verify_raster(
            repo,
            process["raw"],
            f"processes.{process_id}.raw",
            native_records,
        )
        verify_raster(
            repo,
            process["semantic"],
            f"processes.{process_id}.semantic",
            native_records,
        )
        verify_artifact(
            repo, process["freshInvocationReceipt"], f"processes.{process_id}.freshInvocationReceipt"
        )
        verify_artifact(repo, process["provenance"], f"processes.{process_id}.provenance")
        if [raw_record["width"], raw_record["height"]] != [1536, 1024]:
            fail("RAW_DIMENSION_MISMATCH", process_id)
        raw_file_hashes.add(process["raw"]["sha256"])
        raw_pixel_hashes.add(process["raw"]["decodedRgbaSha256"])
        semantic_pixel_hashes.add(process["semantic"]["decodedRgbaSha256"])
    if len(raw_file_hashes) != 1 or len(raw_pixel_hashes) != 1:
        fail("ABC_RAW_IDENTITY_FAILURE", "A/B/C raw identities differ")
    if len(semantic_pixel_hashes) != 1:
        fail("ABC_SEMANTIC_IDENTITY_FAILURE", "A/B/C semantic identities differ")
    candidate = completion["source"]["decodedRgbaSha256"]
    if candidate != next(iter(raw_pixel_hashes)) or candidate in forbidden:
        fail("SOURCE_NON_ALIAS_FAILURE", candidate)
    selected = completion["selectedSource"]
    selected_process = completion["selectedProcess"]
    if selected != processes[selected_process]["raw"]:
        fail("SELECTED_SOURCE_MISMATCH", selected_process)
    selected_path = safe_path(repo, selected["path"], "selectedSource.path")
    selected_record = native_records[str(selected_path)]
    computed_d4 = selected_record["d4"]
    if completion["transformFingerprints"] != computed_d4:
        fail("D4_RECOMPUTATION_MISMATCH", selected_process)
    if len(set(computed_d4.values())) != 8:
        fail("D4_TRANSFORM_ALIAS", "fingerprints are not unique")
    intersection = set(computed_d4.values()) & forbidden
    if intersection:
        fail("D4_ACCEPTED_MASTER_ALIAS", repr(sorted(intersection)))
    if payload["identity"]["direction"] == "north":
        lock = payload["authorities"]["appearanceLock"]
        process_a = processes["A"]["raw"]
        if (
            process_a["sha256"] != lock["northProcessASourceSha256"]
            or process_a["decodedRgbaSha256"]
            != lock["northProcessADecodedRgbaSha256"]
        ):
            fail("NORTH_PROCESS_A_LOCK_MISMATCH", repr(process_a))
    return selected_record


def bind_owned_artifacts_to_content_commit(
    repo: Path,
    payload: dict[str, Any],
    content_commit: str,
) -> None:
    bindings: set[tuple[str, str]] = set()

    def walk(value: Any) -> None:
        if isinstance(value, dict):
            if (
                isinstance(value.get("path"), str)
                and isinstance(value.get("sha256"), str)
                and HEX_64.fullmatch(value["sha256"]) is not None
            ):
                bindings.add((value["path"], value["sha256"]))
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    for section in ("inputs", "launch", "completion"):
        walk(payload[section])
    for path, expected_sha in sorted(bindings):
        require_file_at_commit(
            repo,
            content_commit,
            path,
            expected_sha,
            f"contentArtifact:{path}",
        )


def verify_lods(
    repo: Path,
    completion: dict[str, Any],
    forbidden: frozenset[str],
    native_records: dict[str, dict[str, Any]],
) -> None:
    decoded: set[str] = set()
    for name, dimensions in LOD_DIMENSIONS.items():
        lod = completion["lods"][name]
        raster = {key: lod[key] for key in ("path", "sha256", "decodedRgbaSha256")}
        _, record = verify_raster(repo, raster, f"lods.{name}", native_records)
        if lod["canvasPixels"] != dimensions or [
            record["width"],
            record["height"],
        ] != dimensions:
            fail("LOD_DIMENSION_MISMATCH", name)
        pixel_hash = require_sha(lod["decodedRgbaSha256"], f"lods.{name}.decodedRgbaSha256")
        if pixel_hash in forbidden:
            fail("LOD_NON_ALIAS_FAILURE", name)
        decoded.add(pixel_hash)
    if len(decoded) != 3:
        fail("LOD_UNIQUENESS_FAILURE", repr(sorted(decoded)))


def validate(repo: Path, schema_path: Path, expected_schema_sha: str, handoff: Path) -> dict[str, Any]:
    if sha256_file(schema_path) != require_sha(expected_schema_sha, "expectedSchemaSha256"):
        fail("SCHEMA_SHA_DRIFT", str(schema_path))
    schema = strict_json(schema_path.read_text(encoding="utf-8"), "schema")
    if schema.get("$id") != SCHEMA_ID:
        fail("SCHEMA_ID_MISMATCH", str(schema.get("$id")))
    Draft202012Validator.check_schema(schema)
    payload = strict_json(handoff.read_text(encoding="utf-8"), "handoff")
    errors = sorted(Draft202012Validator(schema).iter_errors(payload), key=lambda error: list(error.path))
    if errors:
        error = errors[0]
        fail("JSON_SCHEMA_REJECTION", f"{list(error.path)}: {error.message}")

    profile = verify_identity(payload)
    verify_owned_paths(repo, payload)
    baseline = git_commit(repo, payload["lineage"]["publishedBaseline"], "publishedBaseline")
    content = git_commit(repo, payload["lineage"]["cellContentCommit"], "cellContentCommit")
    require_ancestor(repo, baseline, content, "published baseline to content")
    require_ancestor(repo, content, "HEAD", "content to current HEAD")
    branch = subprocess.run(
        ["git", "-C", str(repo), "branch", "--show-current"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if branch != payload["identity"]["branch"]:
        fail("ACTUAL_BRANCH_MISMATCH", f"{branch} != {payload['identity']['branch']}")
    if payload["stage"] == "source_candidate":
        if payload["completion"]["contentCommit"] != content:
            fail("CONTENT_COMMIT_MISMATCH", content)
        if not payload["candidateReadyForIndependentReview"]:
            fail("CANDIDATE_READINESS_MISMATCH", "source candidate is not review-ready")
        status = subprocess.run(
            ["git", "-C", str(repo), "status", "--porcelain"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        if status:
            fail("SOURCE_CANDIDATE_WORKTREE_DIRTY", status.strip())
    if any(payload[key] for key in ("sourceReady", "integrationAdmitted", "rendererQuarantined", "productionSelected")):
        fail("WORKER_AUTHORITY_ESCALATION", "worker set an Integration/Renderer state")

    verify_authority_artifacts(repo, payload["authorities"])
    source_profile = strict_json(
        safe_path(
            repo,
            payload["authorities"]["sourceProductionProfile"]["path"],
            "sourceProductionProfile.path",
        ).read_text(encoding="utf-8"),
        "sourceProductionProfile",
    )
    if source_profile["sourceStageSchema"] != {
        "path": str(schema_path.relative_to(repo)),
        "sha256": expected_schema_sha,
    }:
        fail("SOURCE_PROFILE_SCHEMA_BINDING_DRIFT", repr(source_profile["sourceStageSchema"]))
    if payload["authorities"]["nonAliasInput"]["sha256"] != INPUT_SHA256:
        fail("NON_ALIAS_INPUT_DRIFT", payload["authorities"]["nonAliasInput"]["sha256"])
    if payload["authorities"]["nonAliasInput"]["forbiddenSetSha256"] != FORBIDDEN_SET_SHA256:
        fail("NON_ALIAS_SET_DRIFT", payload["authorities"]["nonAliasInput"]["forbiddenSetSha256"])
    forbidden = load_forbidden_decoded_rgba(repo)

    for name, value in payload["inputs"].items():
        if name != "outputRoot":
            verify_artifact(repo, value, f"inputs.{name}")
    verify_artifact(repo, payload["launch"]["guardReceipt"], "launch.guardReceipt")
    verify_artifact(
        repo, payload["launch"]["outputRootIsolationReceipt"], "launch.outputRootIsolationReceipt"
    )
    if payload["stage"] == "source_candidate":
        bind_owned_artifacts_to_content_commit(repo, payload, content)
        completion = payload["completion"]
        raster_paths = {
            safe_path(repo, process[kind]["path"], f"processes.{process_id}.{kind}.path")
            for process_id, process in completion["processes"].items()
            for kind in ("raw", "semantic")
        }
        raster_paths.update(
            safe_path(repo, lod["path"], f"lods.{name}.path")
            for name, lod in completion["lods"].items()
        )
        selected_path = safe_path(
            repo, completion["selectedSource"]["path"], "selectedSource.path"
        )
        native_records = canonical_rgba_records(
            repo,
            sorted(raster_paths),
            selected_path,
        )
        selected_record = verify_processes(repo, payload, forbidden, native_records)
        verify_lods(repo, completion, forbidden, native_records)
        registration = payload["completion"]["registration"]
        if registration["frontageSocketSource"] != profile["socket"]:
            fail("FRONTAGE_SOCKET_MISMATCH", repr(registration["frontageSocketSource"]))
        bounds = registration["occupiedBounds"]
        if bounds["maxX"] < bounds["minX"] or bounds["maxY"] < bounds["minY"]:
            fail("OCCUPIED_BOUNDS_INVERTED", repr(bounds))
        if bounds != selected_record["occupiedBounds"]:
            fail(
                "OCCUPIED_BOUNDS_RECOMPUTATION_MISMATCH",
                f"{bounds!r} != {selected_record['occupiedBounds']!r}",
            )
        _, _, straight_rgba = decode_rgba_png(
            safe_path(repo, completion["selectedSource"]["path"], "selectedSource.path")
        )
        nonzero = hidden = near_chroma = 0
        for index in range(0, len(straight_rgba), 4):
            red, green, blue, alpha = straight_rgba[index : index + 4]
            if alpha:
                nonzero += 1
                if red >= 230 and green <= 25 and blue >= 230:
                    near_chroma += 1
            elif red or green or blue:
                hidden += 1
        expected_alpha = {
            "nonzeroPixelCount": nonzero,
            "hiddenRgbPixelCount": hidden,
            "nearChromaPixelCount": near_chroma,
        }
        if registration["alpha"] != expected_alpha:
            fail(
                "ALPHA_METRIC_RECOMPUTATION_MISMATCH",
                f"{registration['alpha']!r} != {expected_alpha!r}",
            )
        polygon = registration["groundContactPolygonWorld"]
        if len({tuple(point) for point in polygon}) != 4:
            fail("DEGENERATE_CONTACT_POLYGON", repr(polygon))
        area = sum(
            polygon[index][0] * polygon[(index + 1) % 4][1]
            - polygon[(index + 1) % 4][0] * polygon[index][1]
            for index in range(4)
        )
        if abs(area) <= 1e-9:
            fail("DEGENERATE_CONTACT_POLYGON", repr(polygon))
        if not all(
            math.isfinite(float(component))
            for point in polygon
            for component in point
        ):
            fail("NONFINITE_GEOMETRY", repr(polygon))
        for name in ("validation",):
            verify_artifact(repo, payload["completion"][name]["receipt"], f"completion.{name}.receipt")
        verify_artifact(repo, payload["completion"]["reviewManifest"], "completion.reviewManifest")
        verify_artifact(
            repo,
            payload["completion"]["rejectedAttemptInventory"],
            "completion.rejectedAttemptInventory",
        )
        verify_artifact(
            repo,
            payload["completion"]["parallelExecutionReceipt"],
            "completion.parallelExecutionReceipt",
        )

    return {
        "schema": SCHEMA_ID,
        "result": "PASS",
        "stage": payload["stage"],
        "taskId": payload["identity"]["taskId"],
        "direction": payload["identity"]["direction"],
        "contentCommit": content,
        "forbiddenDecodedRgbaSha256Count": len(forbidden),
        "forbiddenSetSha256": FORBIDDEN_SET_SHA256,
    }


def main() -> int:
    default_repo = Path(__file__).resolve().parents[4]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("handoff", type=Path)
    parser.add_argument("--repo-root", type=Path, default=default_repo)
    parser.add_argument(
        "--schema",
        type=Path,
        default=Path(
            "docs/production/evidence/INTEGRATION/"
            "industrial-l04-source-stage-handoff-schema-v2.json"
        ),
    )
    parser.add_argument("--expected-schema-sha256", required=True)
    args = parser.parse_args()
    repo = args.repo_root.resolve()
    schema_path = args.schema if args.schema.is_absolute() else repo / args.schema
    handoff = args.handoff if args.handoff.is_absolute() else repo / args.handoff
    try:
        result = validate(repo, schema_path.resolve(), args.expected_schema_sha256, handoff.resolve())
    except (HandoffError, json.JSONDecodeError, OSError) as error:
        print(json.dumps({"result": "FAIL", "error": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
