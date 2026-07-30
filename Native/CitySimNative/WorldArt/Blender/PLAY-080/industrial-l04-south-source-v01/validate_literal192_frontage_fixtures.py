#!/usr/bin/env python3
"""Validate South literal-192/frontage fixtures with fail-closed replay I/O."""

from __future__ import annotations

import argparse
import copy
from dataclasses import dataclass
import errno
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import tempfile
from typing import Any, Callable


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
SOURCE_ROOT = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
    "industrial-l04-south-source-v01"
)
EVIDENCE_ROOT = (
    "docs/production/evidence/PLAY-080/industrial-l04-south-source-v01"
)
FIXTURE_PATH = f"{SOURCE_ROOT}/literal192-frontage-adversarial-fixtures-v01.json"
VALIDATOR_PATH = f"{SOURCE_ROOT}/validate_literal192_frontage_fixtures.py"
OUTPUT_PATH = (
    f"{EVIDENCE_ROOT}/"
    "LITERAL-192-FRONTAGE-REPLAY-SAFETY-VALIDATION.json"
)
BRANCH = "codex/citysim-world-art-south"
PUBLISHED_MASTER = "94ae73a99abe64f59bb052582fcaba1d9725319d"
PUBLISHED_MASTER_TREE = "36aa7551607689e2193783e4ac14a0fc1c0424ff"
CLAIM_PATH = "docs/production/claims/PLAY-080.world-art-south.md"
CLAIM_SHA256 = "6ccd0313c078b24fc1b1a42806434480f46fd9fe705dd51c26015b174be95973"
CLAIM_BLOB_OID = "f58988aeeba6f034cc74b4a13a3336782eedaacb"
SCENE_PATH = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
    "industrial-l04-south-predesign-v01.scene.json"
)
SCENE_SHA256 = "e0c8dd02f261844daa3d78ba05c482acbbe9b08eac835a0f863621f48010b07d"
SCENE_BLOB_OID = "d04d7630436430907caaeb4eaa9c2d04304190ad"
MATERIALS_PATH = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
    "industrial-l04-south-predesign-v01.materials.json"
)
MATERIALS_SHA256 = (
    "624b34f10354c79e0ced914ed55cf4dcb05468997d4efb679f881477984244fb"
)
MATERIALS_BLOB_OID = "3a11708434c1df4e85e699b84bcf7a88fbf439e9"

HEX_12 = re.compile(r"^[0-9a-f]{12}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")

EXPECTED_AUTHORITIES = {
    "acceptedSouthMaterials": {
        "authorityCommit": PUBLISHED_MASTER,
        "blobOid": MATERIALS_BLOB_OID,
        "path": MATERIALS_PATH,
        "role": "acceptedSouthMaterials",
        "sha256": MATERIALS_SHA256,
    },
    "acceptedSouthScene": {
        "authorityCommit": PUBLISHED_MASTER,
        "blobOid": SCENE_BLOB_OID,
        "path": SCENE_PATH,
        "role": "acceptedSouthScene",
        "sha256": SCENE_SHA256,
    },
    "claim": {
        "authorityCommit": PUBLISHED_MASTER,
        "blobOid": CLAIM_BLOB_OID,
        "path": CLAIM_PATH,
        "role": "claim",
        "sha256": CLAIM_SHA256,
    },
    "publishedMaster": {
        "commit": PUBLISHED_MASTER,
        "role": "publishedMaster",
        "treeOid": PUBLISHED_MASTER_TREE,
    },
}
EXPECTED_INPUT_BINDINGS = [
    {
        "path": SCENE_PATH,
        "role": "acceptedSouthScene",
        "sha256": SCENE_SHA256,
    },
    {
        "path": MATERIALS_PATH,
        "role": "acceptedSouthMaterials",
        "sha256": MATERIALS_SHA256,
    },
    {
        "path": f"{SOURCE_ROOT}/runner-contract.json",
        "role": "runnerContract",
        "sha256": "bc74613e9fdcc5b7c378488b0a5c3b5404087fb231da2b528b719597a1df03a2",
    },
    {
        "path": f"{EVIDENCE_ROOT}/LITERAL-192-SEMANTIC-PROOF.json",
        "role": "literal192Proof",
        "sha256": "64805d0352c776daebd1e12c7412f690bad1f1b74d76f1fd55f6cb53d99f1da8",
    },
    {
        "path": f"{EVIDENCE_ROOT}/PARALLEL-SOUTH-V2-ZERO-PIXEL-HANDOFF.json",
        "role": "zeroPixelHandoff",
        "sha256": "cb74072724e2d93b52183e64785662b65376f5beb2f24fd2d7521524f6664c32",
    },
]
EXPECTED_CASES = {
    "south-socket-drift": (
        "SOUTH_SOCKET_DRIFT",
        "/registration/canonicalCitySimSouthSocket",
        "semantic",
    ),
    "registration-error-above-0.001": (
        "REGISTRATION_ERROR_ABOVE_TOLERANCE",
        "/registration/maximumErrorSourcePixels",
        "semantic",
    ),
    "portal-occlusion": (
        "PORTAL_OCCLUSION",
        "/literal192/processOcclusionPixels",
        "semantic",
    ),
    "insufficient-silhouette-structure": (
        "INSUFFICIENT_SILHOUETTE_STRUCTURE",
        "/literal192/silhouetteBreaks",
        "semantic",
    ),
    "wrong-bridge-basis": (
        "WRONG_BRIDGE_BASIS",
        "/bridgeBasis/matrixRows",
        "semantic",
    ),
    "malformed-toolchain-fingerprint": (
        "MALFORMED_TOOLCHAIN_FINGERPRINT",
        "/toolchainFingerprint/blenderExecutableSha256",
        "semantic",
    ),
    "claim-authority-substitution": (
        "CLAIM_AUTHORITY_MISMATCH",
        "/authorities/claim/sha256",
        "document",
    ),
    "published-base-substitution": (
        "PUBLISHED_BASE_AUTHORITY_MISMATCH",
        "/authorities/publishedMaster/commit",
        "document",
    ),
    "input-role-substitution": (
        "INPUT_ROLE_BINDING_MISMATCH",
        "/inputBindings/0/role",
        "document",
    ),
    "fixture-path-substitution": (
        "FIXTURE_PATH_MISMATCH",
        "/paths/fixture",
        "document",
    ),
    "output-path-substitution": (
        "OUTPUT_PATH_MISMATCH",
        "/paths/output",
        "document",
    ),
}


class FixtureRejected(RuntimeError):
    """A fail-closed fixture, authority, or replay-path rejection."""

    def __init__(self, code: str, details: Any = None):
        super().__init__(code)
        self.code = code
        self.details = details


@dataclass(frozen=True)
class CapturedFile:
    raw: bytes
    identity: tuple[int, int, int, int, int]


def reject(code: str, details: Any = None) -> None:
    raise FixtureRejected(code, details)


def reject_nonfinite(value: str) -> None:
    reject("NONFINITE_JSON_NUMBER", value)


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("DUPLICATE_JSON_KEY", key)
        result[key] = value
    return result


def load_json_bytes(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=reject_duplicate_keys,
            parse_constant=reject_nonfinite,
        )
    except UnicodeDecodeError as error:
        reject("INVALID_UTF8", {"label": label, "error": str(error)})
    except json.JSONDecodeError as error:
        reject("MALFORMED_JSON", {"label": label, "error": str(error)})
    if not isinstance(value, dict):
        reject("JSON_ROOT_NOT_OBJECT", label)
    return value


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical_bytes(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def require_exact_keys(
    value: dict[str, Any], expected: set[str], label: str
) -> None:
    actual = set(value)
    if actual != expected:
        reject(
            "OBJECT_KEYS_MISMATCH",
            {
                "label": label,
                "missing": sorted(expected - actual),
                "extra": sorted(actual - expected),
            },
        )


def parse_safe_relative_path(relative_path: str, code: str) -> PurePosixPath:
    if not isinstance(relative_path, str):
        reject(code, relative_path)
    pure = PurePosixPath(relative_path)
    if (
        pure.is_absolute()
        or not pure.parts
        or any(part in {"", ".", ".."} for part in pure.parts)
    ):
        reject(code, relative_path)
    return pure


def open_parent_descriptor(
    root: Path, relative_path: str, unsafe_code: str
) -> tuple[int, str]:
    pure = parse_safe_relative_path(relative_path, unsafe_code)
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    try:
        descriptor = os.open(root, flags)
    except OSError as error:
        reject(unsafe_code, {"path": str(root), "errno": error.errno})
    try:
        for part in pure.parts[:-1]:
            try:
                child = os.open(part, flags, dir_fd=descriptor)
            except OSError as error:
                reject(
                    unsafe_code,
                    {"path": relative_path, "component": part, "errno": error.errno},
                )
            os.close(descriptor)
            descriptor = child
        return descriptor, pure.parts[-1]
    except BaseException:
        os.close(descriptor)
        raise


def file_identity(value: os.stat_result) -> tuple[int, int, int, int, int]:
    return (
        value.st_dev,
        value.st_ino,
        value.st_mode,
        value.st_size,
        value.st_mtime_ns,
    )


def read_descriptor_bytes(descriptor: int) -> bytes:
    chunks: list[bytes] = []
    while True:
        chunk = os.read(descriptor, 1024 * 1024)
        if not chunk:
            return b"".join(chunks)
        chunks.append(chunk)


def capture_regular_at(
    root: Path,
    relative_path: str,
    *,
    after_read: Callable[[], None] | None = None,
) -> CapturedFile:
    parent_descriptor, name = open_parent_descriptor(
        root, relative_path, "INPUT_UNSAFE_PARENT"
    )
    descriptor = -1
    try:
        try:
            descriptor = os.open(
                name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent_descriptor
            )
        except OSError as error:
            if error.errno in {errno.ELOOP, errno.EMLINK}:
                reject("INPUT_SYMLINK", relative_path)
            if error.errno == errno.ENOENT:
                reject("INPUT_MISSING", relative_path)
            reject("INPUT_OPEN_FAILED", {"path": relative_path, "errno": error.errno})
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            reject("INPUT_NOT_REGULAR", relative_path)
        raw = read_descriptor_bytes(descriptor)
        if after_read is not None:
            after_read()
        after = os.fstat(descriptor)
        try:
            entry = os.stat(name, dir_fd=parent_descriptor, follow_symlinks=False)
        except FileNotFoundError:
            reject("INPUT_REPLACED", relative_path)
        if (
            file_identity(before) != file_identity(after)
            or before.st_dev != entry.st_dev
            or before.st_ino != entry.st_ino
            or not stat.S_ISREG(entry.st_mode)
        ):
            reject("INPUT_REPLACED", relative_path)
        return CapturedFile(raw=raw, identity=file_identity(after))
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        os.close(parent_descriptor)


def capture_repo_file(relative_path: str) -> CapturedFile:
    return capture_regular_at(REPOSITORY_ROOT, relative_path)


def write_exclusive_at(root: Path, relative_path: str, raw: bytes) -> None:
    parent_descriptor, name = open_parent_descriptor(
        root, relative_path, "OUTPUT_UNSAFE_PARENT"
    )
    descriptor = -1
    try:
        try:
            descriptor = os.open(
                name,
                os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                0o644,
                dir_fd=parent_descriptor,
            )
        except OSError as error:
            if error.errno == errno.EEXIST:
                reject("OUTPUT_EXISTS", relative_path)
            reject(
                "OUTPUT_EXCLUSIVE_OPEN_FAILED",
                {"path": relative_path, "errno": error.errno},
            )
        before = os.fstat(descriptor)
        offset = 0
        while offset < len(raw):
            offset += os.write(descriptor, raw[offset:])
        os.fsync(descriptor)
        os.lseek(descriptor, 0, os.SEEK_SET)
        captured = read_descriptor_bytes(descriptor)
        after = os.fstat(descriptor)
        try:
            entry = os.stat(name, dir_fd=parent_descriptor, follow_symlinks=False)
        except FileNotFoundError:
            reject("OUTPUT_REPLACED", relative_path)
        if (
            before.st_dev != after.st_dev
            or before.st_ino != after.st_ino
            or after.st_dev != entry.st_dev
            or after.st_ino != entry.st_ino
            or not stat.S_ISREG(entry.st_mode)
            or captured != raw
        ):
            reject("OUTPUT_REPLACED", relative_path)
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        os.close(parent_descriptor)


def write_exclusive_repo_file(relative_path: str, raw: bytes) -> None:
    write_exclusive_at(REPOSITORY_ROOT, relative_path, raw)


def git_output(*arguments: str) -> str:
    result = subprocess.run(
        ["/usr/bin/git", "-C", str(REPOSITORY_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        env={
            "GIT_CONFIG_NOSYSTEM": "1",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin",
        },
    )
    if result.returncode != 0:
        reject(
            "GIT_AUTHORITY_CHECK_FAILED",
            {
                "arguments": list(arguments),
                "returnCode": result.returncode,
                "stderr": result.stderr.strip(),
            },
        )
    return result.stdout.strip()


def validate_git_authorities() -> tuple[dict[str, Any], dict[str, tuple[int, ...]]]:
    branch = git_output("branch", "--show-current")
    if branch != BRANCH:
        reject("BRANCH_MISMATCH", {"expected": BRANCH, "actual": branch})
    commit = git_output("rev-parse", f"{PUBLISHED_MASTER}^{{commit}}")
    if commit != PUBLISHED_MASTER:
        reject(
            "PUBLISHED_BASE_AUTHORITY_MISMATCH",
            {"expected": PUBLISHED_MASTER, "actual": commit},
        )
    tree = git_output("rev-parse", f"{PUBLISHED_MASTER}^{{tree}}")
    if tree != PUBLISHED_MASTER_TREE:
        reject(
            "PUBLISHED_BASE_AUTHORITY_MISMATCH",
            {"expectedTree": PUBLISHED_MASTER_TREE, "actualTree": tree},
        )
    git_output("merge-base", "--is-ancestor", PUBLISHED_MASTER, "HEAD")

    blob_checks = [
        ("claim", CLAIM_PATH, CLAIM_BLOB_OID),
        ("acceptedSouthScene", SCENE_PATH, SCENE_BLOB_OID),
        ("acceptedSouthMaterials", MATERIALS_PATH, MATERIALS_BLOB_OID),
    ]
    blob_results: list[dict[str, str]] = []
    for role, path, expected_blob in blob_checks:
        actual_blob = git_output("rev-parse", f"{PUBLISHED_MASTER}:{path}")
        if actual_blob != expected_blob:
            reject(
                "GIT_BLOB_AUTHORITY_MISMATCH",
                {"role": role, "expected": expected_blob, "actual": actual_blob},
            )
        blob_results.append(
            {
                "blobOid": actual_blob,
                "path": path,
                "role": role,
            }
        )

    claim = capture_repo_file(CLAIM_PATH)
    claim_sha = sha256_bytes(claim.raw)
    if claim_sha != CLAIM_SHA256:
        reject(
            "CLAIM_AUTHORITY_MISMATCH",
            {"expected": CLAIM_SHA256, "actual": claim_sha},
        )
    return (
        {
            "branch": branch,
            "claim": EXPECTED_AUTHORITIES["claim"],
            "publishedMaster": EXPECTED_AUTHORITIES["publishedMaster"],
            "publishedMasterBlobAuthorities": blob_results,
            "runtimeHeadPolicy": "published-master-is-ancestor",
        },
        {"claim": claim.identity},
    )


def require_number(value: Any, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        reject("INVALID_NUMBER", label)
    number = float(value)
    if not math.isfinite(number):
        reject("NONFINITE_NUMBER", label)
    return number


def require_vector(value: Any, expected: list[float], code: str) -> None:
    if (
        not isinstance(value, list)
        or len(value) != len(expected)
        or any(
            require_number(actual, code) != expected[index]
            for index, actual in enumerate(value)
        )
    ):
        reject(code, {"expected": expected, "actual": value})


def derive_baseline(inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    runner = inputs["runnerContract"]
    proof = inputs["literal192Proof"]
    handoff = inputs["zeroPixelHandoff"]
    bridge = runner["coordinateBridge"]
    registration = runner["invariants"]["registration"]
    render = runner["invariants"]["render"]
    metrics = proof["metrics"]
    thresholds = proof["thresholds"]
    camera = handoff["cameraAndSocket"]

    return {
        "boundary": {
            "blenderProcessLaunches": proof["blenderProcessLaunches"],
            "blenderRenderApiCalls": proof["blenderRenderApiCalls"],
            "contactSheetInvocations": proof["contactSheetInvocations"],
            "imageGenInvocations": proof["imageGenInvocations"],
            "normalizerInvocations": proof["normalizerInvocations"],
            "pixelFiles": proof["pixelFiles"],
            "processA": proof["processA"],
            "processB": proof["processB"],
            "processC": proof["processC"],
            "productionSelected": proof["productionSelected"],
            "renderInvocations": proof["renderInvocations"],
            "sourceReady": proof["sourceReady"],
        },
        "bridgeBasis": {
            "axisOrder": bridge["citysimToBlenderAxisOrder"],
            "axisSigns": bridge["citysimToBlenderAxisSigns"],
            "determinant": bridge["determinant"],
            "formula": bridge["formula"],
            "matrixRows": bridge["matrixRows"],
            "sourceOrder": bridge["sourceOrder"],
        },
        "direction": runner["direction"],
        "literal192": {
            "frameMinimumThicknessPixels": metrics[
                "frameMinimumThicknessPixels"
            ],
            "freightOpeningMinimumWidthPixels": thresholds[
                "literal192FreightOpeningMinimumWidthPixels"
            ],
            "freightOpeningWidthsPixels": metrics[
                "freightOpeningWidthsPixels"
            ],
            "maximumProcessOcclusionPixels": thresholds[
                "maximumProcessOcclusionPixels"
            ],
            "minimumSilhouetteBreaks": thresholds["minimumSilhouetteBreaks"],
            "primaryPortalMinimumPixels": thresholds[
                "literal192PrimaryPortalMinimumPixels"
            ],
            "primaryPortalPixels": metrics["primaryPortalPixels"],
            "processOcclusionPixels": metrics["processOcclusionPixels"],
            "requiredFrameMinimumThicknessPixels": thresholds[
                "literal192FrameMinimumThicknessPixels"
            ],
            "silhouetteBreaks": metrics["silhouetteBreaks"],
        },
        "registration": {
            "blenderNativeSouthSocket": bridge[
                "blenderNativeDirectionalSocket"
            ],
            "canonicalCitySimSouthSocket": bridge[
                "canonicalCitySimSouthSocket"
            ],
            "expectedSourceSocketPixels": registration[
                "sourceProjectionObservation"
            ]["socketPixels"],
            "maximumErrorSourcePixels": camera["maximumDeltaSourcePixels"],
            "observedSourceSocketPixels": camera["actualSourceSocketPixels"],
            "toleranceSourcePixels": camera["toleranceSourcePixels"],
        },
        "toolchainFingerprint": {
            "adaptiveSampling": render["adaptiveSampling"],
            "blenderBuildHash": render["blenderBuildHash"],
            "blenderExecutableSha256": render["blenderExecutableSha256"],
            "blenderVersion": render["blenderVersion"],
            "denoising": render["denoising"],
            "device": render["device"],
            "engine": render["engine"],
            "motionBlur": render["motionBlur"],
            "threads": render["threads"],
            "threadsMode": render["threadsMode"],
            "transparentFilm": render["transparentFilm"],
        },
    }


def validate_candidate(candidate: dict[str, Any]) -> None:
    require_exact_keys(
        candidate,
        {
            "boundary",
            "bridgeBasis",
            "direction",
            "literal192",
            "registration",
            "toolchainFingerprint",
        },
        "candidate",
    )
    if candidate["direction"] != "south":
        reject("WRONG_DIRECTION", candidate["direction"])

    registration = candidate["registration"]
    require_vector(
        registration.get("canonicalCitySimSouthSocket"),
        [0, 0, 28],
        "SOUTH_SOCKET_DRIFT",
    )
    require_vector(
        registration.get("blenderNativeSouthSocket"),
        [28, 0, 0],
        "SOUTH_SOCKET_DRIFT",
    )
    require_vector(
        registration.get("expectedSourceSocketPixels"),
        [640, 832],
        "SOUTH_SOCKET_DRIFT",
    )
    error = require_number(
        registration.get("maximumErrorSourcePixels"),
        "maximumErrorSourcePixels",
    )
    tolerance = require_number(
        registration.get("toleranceSourcePixels"),
        "toleranceSourcePixels",
    )
    if tolerance != 0.001 or error > tolerance:
        reject(
            "REGISTRATION_ERROR_ABOVE_TOLERANCE",
            {"error": error, "tolerance": tolerance},
        )
    observed = registration.get("observedSourceSocketPixels")
    expected = registration.get("expectedSourceSocketPixels")
    if not isinstance(observed, list) or len(observed) != 2:
        reject("REGISTRATION_MEASUREMENT_MALFORMED", observed)
    measured_error = max(
        abs(
            require_number(observed[index], "observedSourceSocketPixels")
            - expected[index]
        )
        for index in range(2)
    )
    if not math.isclose(measured_error, error, abs_tol=1e-15):
        reject(
            "REGISTRATION_MEASUREMENT_INCONSISTENT",
            {"declared": error, "measured": measured_error},
        )

    bridge = candidate["bridgeBasis"]
    expected_bridge = {
        "axisOrder": [2, 0, 1],
        "axisSigns": [1, 1, 1],
        "determinant": 1,
        "formula": "B(CitySim[x,y,z])=Blender[z,x,y]",
        "matrixRows": [[0, 0, 1], [1, 0, 0], [0, 1, 0]],
        "sourceOrder": [0, 1, 2, 3],
    }
    if bridge != expected_bridge:
        reject("WRONG_BRIDGE_BASIS", {"expected": expected_bridge, "actual": bridge})

    literal = candidate["literal192"]
    portal = literal.get("primaryPortalPixels")
    portal_minimum = literal.get("primaryPortalMinimumPixels")
    if (
        not isinstance(portal, list)
        or not isinstance(portal_minimum, list)
        or len(portal) != 2
        or len(portal_minimum) != 2
        or any(
            require_number(portal[index], "primaryPortalPixels")
            < require_number(portal_minimum[index], "primaryPortalMinimumPixels")
            for index in range(2)
        )
    ):
        reject("PRIMARY_PORTAL_SCALE_INSUFFICIENT", portal)
    freight = literal.get("freightOpeningWidthsPixels")
    freight_minimum = require_number(
        literal.get("freightOpeningMinimumWidthPixels"),
        "freightOpeningMinimumWidthPixels",
    )
    if (
        not isinstance(freight, list)
        or len(freight) != 3
        or min(
            require_number(value, "freightOpeningWidthsPixels")
            for value in freight
        )
        < freight_minimum
    ):
        reject("FREIGHT_OPENING_SCALE_INSUFFICIENT", freight)
    if require_number(
        literal.get("frameMinimumThicknessPixels"),
        "frameMinimumThicknessPixels",
    ) < require_number(
        literal.get("requiredFrameMinimumThicknessPixels"),
        "requiredFrameMinimumThicknessPixels",
    ):
        reject("PORTAL_FRAME_SCALE_INSUFFICIENT")
    if require_number(
        literal.get("processOcclusionPixels"), "processOcclusionPixels"
    ) > require_number(
        literal.get("maximumProcessOcclusionPixels"),
        "maximumProcessOcclusionPixels",
    ):
        reject("PORTAL_OCCLUSION", literal.get("processOcclusionPixels"))
    if require_number(
        literal.get("silhouetteBreaks"), "silhouetteBreaks"
    ) < require_number(
        literal.get("minimumSilhouetteBreaks"), "minimumSilhouetteBreaks"
    ):
        reject(
            "INSUFFICIENT_SILHOUETTE_STRUCTURE",
            literal.get("silhouetteBreaks"),
        )

    fingerprint = candidate["toolchainFingerprint"]
    if (
        not isinstance(fingerprint, dict)
        or not HEX_12.fullmatch(str(fingerprint.get("blenderBuildHash", "")))
        or not HEX_64.fullmatch(
            str(fingerprint.get("blenderExecutableSha256", ""))
        )
    ):
        reject("MALFORMED_TOOLCHAIN_FINGERPRINT", fingerprint)
    expected_fingerprint = {
        "adaptiveSampling": False,
        "blenderBuildHash": "84afd5f785f7",
        "blenderExecutableSha256": (
            "8485107307b16bd0899f3c259261494b0"
            "c80e383db239c04e2c9fcd14d305fb4"
        ),
        "blenderVersion": "4.5.12 LTS",
        "denoising": False,
        "device": "CPU",
        "engine": "CYCLES",
        "motionBlur": False,
        "threads": 1,
        "threadsMode": "FIXED",
        "transparentFilm": True,
    }
    if fingerprint != expected_fingerprint:
        reject(
            "TOOLCHAIN_FINGERPRINT_MISMATCH",
            {"expected": expected_fingerprint, "actual": fingerprint},
        )

    expected_boundary = {
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "contactSheetInvocations": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "pixelFiles": 0,
        "processA": "not_run",
        "processB": "not_run",
        "processC": "not_run",
        "productionSelected": False,
        "renderInvocations": 0,
        "sourceReady": False,
    }
    if candidate["boundary"] != expected_boundary:
        reject("ZERO_PIXEL_BOUNDARY_VIOLATION", candidate["boundary"])


def validate_fixture_identity(fixture: dict[str, Any]) -> None:
    require_exact_keys(
        fixture,
        {
            "adversarialCases",
            "authorities",
            "baseline",
            "direction",
            "inputBindings",
            "mode",
            "paths",
            "schema",
            "taskId",
        },
        "fixture",
    )
    if (
        fixture["schema"]
        != "citysim.play-080.literal192-frontage-adversarial-fixtures.v2"
        or fixture["taskId"] != "PLAY-080"
        or fixture["direction"] != "south"
        or fixture["mode"] != "pure-data-zero-pixel"
    ):
        reject("FIXTURE_IDENTITY_MISMATCH")
    authorities = fixture["authorities"]
    if not isinstance(authorities, dict):
        reject("AUTHORITY_BINDINGS_MALFORMED")
    if authorities.get("publishedMaster") != EXPECTED_AUTHORITIES["publishedMaster"]:
        reject(
            "PUBLISHED_BASE_AUTHORITY_MISMATCH",
            authorities.get("publishedMaster"),
        )
    if authorities.get("claim") != EXPECTED_AUTHORITIES["claim"]:
        reject("CLAIM_AUTHORITY_MISMATCH", authorities.get("claim"))
    if authorities.get("acceptedSouthScene") != EXPECTED_AUTHORITIES[
        "acceptedSouthScene"
    ]:
        reject("SCENE_AUTHORITY_MISMATCH", authorities.get("acceptedSouthScene"))
    if authorities.get("acceptedSouthMaterials") != EXPECTED_AUTHORITIES[
        "acceptedSouthMaterials"
    ]:
        reject(
            "MATERIALS_AUTHORITY_MISMATCH",
            authorities.get("acceptedSouthMaterials"),
        )
    if fixture["paths"].get("fixture") != FIXTURE_PATH:
        reject("FIXTURE_PATH_MISMATCH", fixture["paths"].get("fixture"))
    if fixture["paths"].get("output") != OUTPUT_PATH:
        reject("OUTPUT_PATH_MISMATCH", fixture["paths"].get("output"))
    if fixture["inputBindings"] != EXPECTED_INPUT_BINDINGS:
        reject("INPUT_ROLE_BINDING_MISMATCH", fixture["inputBindings"])


def apply_mutation(value: dict[str, Any], mutation: dict[str, Any]) -> dict[str, Any]:
    require_exact_keys(mutation, {"path", "value"}, "mutation")
    pointer = mutation["path"]
    if not isinstance(pointer, str) or not pointer.startswith("/"):
        reject("INVALID_MUTATION_PATH", pointer)
    parts = pointer[1:].split("/")
    if not parts or any(not part or part in {".", ".."} for part in parts):
        reject("INVALID_MUTATION_PATH", pointer)
    candidate: Any = copy.deepcopy(value)
    target: Any = candidate
    for part in parts[:-1]:
        if isinstance(target, dict) and part in target:
            target = target[part]
        elif isinstance(target, list) and part.isdigit():
            index = int(part)
            if index >= len(target):
                reject("INVALID_MUTATION_PATH", pointer)
            target = target[index]
        else:
            reject("INVALID_MUTATION_PATH", pointer)
    last = parts[-1]
    if isinstance(target, dict) and last in target:
        target[last] = mutation["value"]
    elif isinstance(target, list) and last.isdigit() and int(last) < len(target):
        target[int(last)] = mutation["value"]
    else:
        reject("INVALID_MUTATION_PATH", pointer)
    return candidate


def expect_rejection(
    case_id: str, expected_code: str, operation: Callable[[], None]
) -> dict[str, str]:
    try:
        operation()
    except FixtureRejected as error:
        if error.code != expected_code:
            reject(
                "WRONG_REJECTION_CODE",
                {
                    "case": case_id,
                    "expected": expected_code,
                    "actual": error.code,
                },
            )
    else:
        reject("ADVERSARIAL_CASE_FAILED_OPEN", case_id)
    return {
        "id": case_id,
        "rejectionCode": expected_code,
        "result": "PASS_FAIL_CLOSED",
    }


def run_io_adversaries() -> list[dict[str, str]]:
    results: list[dict[str, str]] = []
    with tempfile.TemporaryDirectory(prefix="play080-replay-safety-") as temporary:
        root = Path(temporary)

        target = root / "target.json"
        target.write_bytes(b"{}\n")
        (root / "target-link.json").symlink_to(target.name)
        results.append(
            expect_rejection(
                "symlink-substitution",
                "INPUT_SYMLINK",
                lambda: capture_regular_at(root, "target-link.json"),
            )
        )

        captured = root / "captured.json"
        replacement = root / "replacement.json"
        captured.write_bytes(b'{"value":"original"}\n')
        replacement.write_bytes(b'{"value":"replacement"}\n')

        def replace_after_read() -> None:
            os.replace(replacement, captured)

        results.append(
            expect_rejection(
                "replacement-substitution",
                "INPUT_REPLACED",
                lambda: capture_regular_at(
                    root, "captured.json", after_read=replace_after_read
                ),
            )
        )

        existing = root / "evidence.json"
        existing.write_bytes(b'{"immutable":true}\n')
        results.append(
            expect_rejection(
                "overwrite-substitution",
                "OUTPUT_EXISTS",
                lambda: write_exclusive_at(root, "evidence.json", b"replacement\n"),
            )
        )
        if existing.read_bytes() != b'{"immutable":true}\n':
            reject("OVERWRITE_CHANGED_EXISTING_BYTES")
    return results


def validate_fixture_bytes(
    fixture_raw: bytes,
) -> tuple[dict[str, Any], dict[str, tuple[int, ...]]]:
    fixture = load_json_bytes(fixture_raw, FIXTURE_PATH)
    validate_fixture_identity(fixture)
    authority_results, identities = validate_git_authorities()

    loaded: dict[str, dict[str, Any]] = {}
    binding_results: list[dict[str, Any]] = []
    for binding in EXPECTED_INPUT_BINDINGS:
        captured = capture_repo_file(binding["path"])
        actual_sha = sha256_bytes(captured.raw)
        if actual_sha != binding["sha256"]:
            reject(
                "INPUT_HASH_MISMATCH",
                {
                    "role": binding["role"],
                    "expected": binding["sha256"],
                    "actual": actual_sha,
                },
            )
        identities[binding["role"]] = captured.identity
        if binding["role"] not in {
            "acceptedSouthScene",
            "acceptedSouthMaterials",
        }:
            loaded[binding["role"]] = load_json_bytes(
                captured.raw, binding["path"]
            )
        binding_results.append(copy.deepcopy(binding))

    derived = derive_baseline(loaded)
    if fixture["baseline"] != derived:
        reject(
            "BASELINE_DOES_NOT_MATCH_BOUND_SOUTH_EVIDENCE",
            {"expected": derived, "actual": fixture["baseline"]},
        )
    validate_candidate(fixture["baseline"])

    cases = fixture["adversarialCases"]
    if not isinstance(cases, list) or len(cases) != len(EXPECTED_CASES):
        reject("ADVERSARIAL_CASE_SET_MISMATCH")
    seen: set[str] = set()
    case_results: list[dict[str, str]] = []
    for case in cases:
        if not isinstance(case, dict):
            reject("ADVERSARIAL_CASE_MALFORMED", case)
        require_exact_keys(
            case, {"expectedRejection", "id", "mutation"}, "adversarialCase"
        )
        case_id = case["id"]
        if case_id not in EXPECTED_CASES or case_id in seen:
            reject("ADVERSARIAL_CASE_SET_MISMATCH", case_id)
        seen.add(case_id)
        expected_code, expected_path, scope = EXPECTED_CASES[case_id]
        if (
            case["expectedRejection"] != expected_code
            or case["mutation"].get("path") != expected_path
        ):
            reject("ADVERSARIAL_CASE_CONTRACT_MISMATCH", case_id)
        if scope == "semantic":
            operation = lambda case=case: validate_candidate(
                apply_mutation(fixture["baseline"], case["mutation"])
            )
        else:
            operation = lambda case=case: validate_fixture_identity(
                apply_mutation(fixture, case["mutation"])
            )
        result = expect_rejection(case_id, expected_code, operation)
        result["mutationPath"] = expected_path
        case_results.append(result)
    if seen != set(EXPECTED_CASES):
        reject("ADVERSARIAL_CASE_SET_MISMATCH", sorted(seen))
    case_results.extend(run_io_adversaries())

    return (
        {
            "adversarialCases": case_results,
            "authorityBindings": authority_results,
            "baseline": {
                "literal192": fixture["baseline"]["literal192"],
                "registration": fixture["baseline"]["registration"],
                "result": "PASS",
            },
            "inputBindings": binding_results,
            "ioControls": {
                "committedEvidenceMode": "read-only-verify",
                "fixturePath": FIXTURE_PATH,
                "inputCapture": "parent-descriptor-openat-nofollow-with-restat",
                "outputCreation": "parent-descriptor-openat-nofollow-exclusive",
                "outputPath": OUTPUT_PATH,
                "overwrite": "rejected",
                "replacement": "rejected",
            },
        },
        identities,
    )


def build_report() -> bytes:
    first_fixture = capture_repo_file(FIXTURE_PATH)
    first_validator = capture_repo_file(VALIDATOR_PATH)
    first, first_identities = validate_fixture_bytes(first_fixture.raw)
    first_identities["fixture"] = first_fixture.identity
    first_identities["validator"] = first_validator.identity

    second_fixture = capture_repo_file(FIXTURE_PATH)
    second_validator = capture_repo_file(VALIDATOR_PATH)
    second, second_identities = validate_fixture_bytes(second_fixture.raw)
    second_identities["fixture"] = second_fixture.identity
    second_identities["validator"] = second_validator.identity

    first_bytes = canonical_bytes(first)
    second_bytes = canonical_bytes(second)
    first_sha = sha256_bytes(first_bytes)
    second_sha = sha256_bytes(second_bytes)
    if (
        first_fixture.raw != second_fixture.raw
        or first_validator.raw != second_validator.raw
        or first_identities != second_identities
    ):
        reject("INPUT_REPLACED_BETWEEN_REPLAYS")
    if first_bytes != second_bytes:
        reject(
            "NONDETERMINISTIC_REPLAY",
            {"firstSha256": first_sha, "secondSha256": second_sha},
        )

    report = {
        "activity": {
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "contactSheetInvocations": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "pixelFiles": 0,
            "renderInvocations": 0,
            "sourcePackets": 0,
        },
        "direction": "south",
        "fixture": {
            "path": FIXTURE_PATH,
            "sha256": sha256_bytes(first_fixture.raw),
        },
        "grants": {
            "admissionAuthorized": False,
            "pixelProductionAuthorized": False,
            "productionReceiptAuthorized": False,
            "productionSelected": False,
            "sourceReady": False,
        },
        "mode": "pure-data-zero-pixel-replay-safety",
        "replay": {
            "identical": True,
            "payloadSha256": [first_sha, second_sha],
            "runs": 2,
            "stableFileIdentityAcrossRuns": True,
        },
        "result": "PASS",
        "schema": (
            "citysim.play-080.literal192-frontage-"
            "replay-safety-validation.v2"
        ),
        "taskId": "PLAY-080",
        "validation": first,
        "validator": {
            "path": VALIDATOR_PATH,
            "sha256": sha256_bytes(first_validator.raw),
        },
    }
    return canonical_bytes(report)


def require_cli_paths(fixtures: str, output: str) -> None:
    if fixtures != FIXTURE_PATH:
        reject("FIXTURE_PATH_MISMATCH", fixtures)
    if output != OUTPUT_PATH:
        reject("OUTPUT_PATH_MISMATCH", output)


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--verify", action="store_true")
    mode.add_argument("--write", action="store_true")
    parser.add_argument("--fixtures", default=FIXTURE_PATH)
    parser.add_argument("--output", default=OUTPUT_PATH)
    args = parser.parse_args()

    try:
        require_cli_paths(args.fixtures, args.output)
        report = build_report()
        report_sha = sha256_bytes(report)
        if args.write:
            write_exclusive_repo_file(OUTPUT_PATH, report)
            action = "WROTE_EXCLUSIVE"
            report_written = True
        elif args.verify:
            committed = capture_repo_file(OUTPUT_PATH)
            if committed.raw != report:
                reject(
                    "COMMITTED_EVIDENCE_MISMATCH",
                    {
                        "expectedSha256": report_sha,
                        "actualSha256": sha256_bytes(committed.raw),
                    },
                )
            action = "VERIFIED_READ_ONLY"
            report_written = False
        else:
            action = "DRY_RUN"
            report_written = False
        print(
            json.dumps(
                {
                    "action": action,
                    "adversarialCases": 14,
                    "outputPath": OUTPUT_PATH,
                    "outputSha256": report_sha,
                    "replayIdentical": True,
                    "reportWritten": report_written,
                    "result": "PASS",
                },
                sort_keys=True,
            )
        )
        return 0
    except FixtureRejected as error:
        print(
            json.dumps(
                {
                    "code": error.code,
                    "details": error.details,
                    "reportWritten": False,
                    "result": "REJECTED",
                },
                sort_keys=True,
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
